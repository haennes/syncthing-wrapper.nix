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
        in
        {
          unit = pkgs.runCommand "syncthing-wrapper-unit-tests" { } ''
            set -euo pipefail
            result=$(${pkgs.nix}/bin/nix-instantiate --eval --strict --json -E '
              let
                nixpkgs = builtins.storePath ${builtins.toJSON (toString nixpkgs)};
                bindfs = builtins.storePath ${builtins.toJSON (toString bindfs)};
                pkgs = import nixpkgs { system = ${builtins.toJSON system}; };
              in import ./test/all.nix { inherit nixpkgs bindfs pkgs; }
            ' 2>/dev/null) || {
              echo "unit test evaluation failed" >&2
              exit 1
            }
            ${pkgs.jq}/bin/jq -e '.allPassed' >/dev/null <<<"$result" || {
              echo "unit test failures:" >&2
              ${pkgs.jq}/bin/jq -r '.failures[] | "- " + .name + "\n  expected: " + (.expected | tostring) + "\n  got:      " + (.result | tostring)' <<<"$result" >&2
              exit 1
            }
            touch $out
          '';
          vm = import ./test/vm-test.nix {
            inherit nixpkgs bindfs pkgs;
          };
        }
      );
    };
}
