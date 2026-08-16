# Aggregates and runs all unit tests.
#
# Usage (from the flake):   import ./test/all.nix { inherit nixpkgs bindfs pkgs; }
{
  nixpkgs,
  bindfs,
  system ? builtins.currentSystem,
  pkgs ? import nixpkgs { inherit system; },
}:
let
  harness = import ./lib.nix { inherit nixpkgs bindfs pkgs; };
  fixtures = import ./fixtures.nix { inherit (pkgs) lib; };

  tests =
    (import ./path-tests.nix { inherit harness fixtures; })
    ++ (import ./config-tests.nix { inherit harness fixtures; });

  results = harness.runTests tests;
  failures = harness.showFailures results;
  allPassed = harness.allPassed results;
in
{
  inherit results failures allPassed;
  json = builtins.toJSON {
    inherit allPassed;
    inherit failures;
    inherit results;
  };
}
