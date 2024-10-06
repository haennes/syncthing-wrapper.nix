{
  description =
    "A simple to use syncthing wrapper. Declare folders once roll out to all automagically";

  inputs = { nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"; };
  outputs = { nixpkgs, self, ... }: {
    nixosModules = rec {
      syncthing-wrapper = import ./syncthing-wrapper.nix;
      default = syncthing-wrapper;
    };
    nixosConfigurations.pcA = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./example/example.nix self.nixosModules.syncthing-wrapper ];
    };
  };

}
