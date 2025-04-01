inputs: {
  imports = [
    ./options.nix
    ./config.nix
    inputs.bindfs.nixosModules.default
  ];
}
