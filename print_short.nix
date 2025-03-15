#this file is for debugging purposes
#usage: load a nix repl with the example config
# > :l print_short.nix
# > f = meta inputs
# now you are ready to start the :lf and eval cycle ;)
# > :lf .
# > f.bindfs nixosConfigurations
# FAQ: why dont we add cfg as an argument of meta -> :lf won't update the cfg parameter
{
  meta =
    inputs:
    let
      lib = inputs.nixpkgs.lib;
      inherit (lib) mapAttrsToList concatStringsSep;
    in
    {
      bindfs =
        cfg:
        lib.mapAttrsToList (
          n: v:
          "${n} \t ${v.source} \t ${concatStringsSep "" (mapAttrsToList (n: v: "${n}-${v}") v.map.userGroup)}"
        ) cfg.pcA.config.bindfs.folders;
      syncf = cfg: cfg.pcA.config.services.syncthing.settings.folders;
      syncwf = cfg: cfg.pcA.config.services.syncthing-wrapper.folders;
      syncd = cfg: cfg.pcA.config.services.syncthing.settings.devices;

    };
}
