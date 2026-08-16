{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    bindfs.url = "github:haennes/bindfs.nix";
  };

  outputs =
    {
      nixpkgs,
      bindfs,
      self,
      ...
    }@inputs:
    let
      forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" ];
      pkgsForSystem = system: (import nixpkgs { inherit system; });
    in
    {
      nixosModules = rec {
        syncthing-wrapper = import ./module.nix inputs;
        default = syncthing-wrapper;
      };
      nixosConfigurations.pcA = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./example/example.nix
          self.nixosModules.syncthing-wrapper
        ];
      };
      formatter = forAllSystems (
        system:
        let
          pkgs = (pkgsForSystem system);
        in
        pkgs.nixfmt-rfc-style
      );
      checks = forAllSystems (
        system:
        let
          pkgs = (pkgsForSystem system);
          # Evaluate the unit tests purely; no nix-instantiate inside the
          # build, which is forbidden by the default build sandbox. Test
          # failures abort evaluation, failing the check at eval time.
          unitResult = import ./test/all.nix {
            inherit nixpkgs bindfs pkgs;
          };
          failures = unitResult.failures;
          failMsg = nixpkgs.lib.concatMapStringsSep "\n" (
            f:
            "- ${f.name}\n  expected: ${builtins.toJSON f.expected}\n  got:      ${builtins.toJSON f.result}"
          ) failures;
        in
        {
          unit = pkgs.runCommand "syncthing-wrapper-unit-tests" { } (
            if failures == [ ] then
              "touch $out"
            else
              abort "unit test failures:\n${failMsg}"
          );
          vm = import ./test/vm-test.nix {
            inherit nixpkgs bindfs pkgs;
          };
        }
      );
    };
}
