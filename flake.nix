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
    }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" ];
      pkgsForSystem = system: (import nixpkgs { inherit system; });
    in
    {
      nixosModules = rec {
        syncthing-wrapper = import ./module.nix;
        default = syncthing-wrapper;
      };
      nixosConfigurations.pcA = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./example/example.nix
          self.nixosModules.syncthing-wrapper
          bindfs.nixosModules.bindfs
        ];
      };
      formatter = forAllSystems (
        system:
        let
          pkgs = (pkgsForSystem system);
        in
        pkgs.nixfmt-rfc-style
      );
    };
}
