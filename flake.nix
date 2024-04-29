{
  description =
    "A simple to use syncthing wrapper. Declare folders once roll out to all automagically";

  inputs = { nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"; };
  outputs = {...}:{
      nixosModules = rec {
        syncthing-wrapper = import ./syncthing-wrapper.nix;
        default = syncthing-wrapper;
      };
    };

}
