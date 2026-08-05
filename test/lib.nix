# Test harness for the syncthing-wrapper module.
#
# Evaluates the wrapper module against the full NixOS module set so that
# `services.syncthing`, `bindfs`, `systemd`, ... all exist, then runs
# pure-eval assertions on the resulting config.
{
  nixpkgs,
  bindfs,
  pkgs,
}:
let
  inherit (pkgs) lib;

  # `nixpkgs`/`bindfs` are flake inputs when used from flake.nix, but plain
  # store paths when used standalone. Normalize bindfs into the shape
  # `module.nix` expects (an attrset with `nixosModules.default`).
  bindfsInput =
    if builtins.isAttrs bindfs then
      bindfs
    else
      {
        nixosModules.default = import "${bindfs}/module.nix";
      };

  module = import ../module.nix {
    inherit nixpkgs;
    bindfs = bindfsInput;
  };

  # Evaluate the wrapper module + the given extra modules against the full
  # NixOS module list, returning the resulting `config`.
  evalConfig =
    extraModules:
    (lib.evalModules {
      modules =
        (import "${nixpkgs}/nixos/modules/module-list.nix")
        ++ [
          { _module.args.pkgs = pkgs; }
          module
        ]
        ++ extraModules;
      specialArgs = { inherit pkgs; };
    }).config;

  runTest =
    {
      name,
      expr,
      expected,
    }:
    {
      inherit name expected;
      result = builtins.deepSeq expr expr;
      ok = builtins.deepSeq expr (expr == expected);
    };

  runTests = tests: map runTest tests;
in
{
  inherit
    lib
    evalConfig
    runTest
    runTests
    ;

  showFailures = results: builtins.filter (r: !r.ok) results;
  allPassed = results: results == [ ] || (builtins.all (r: r.ok) results);
}
