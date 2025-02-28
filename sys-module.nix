{ lib, config, ... }:
let
  inherit (lib)
    filterAttrs
    mapAttrs
    mapAttrsToList
    listToAttrs
    flatten
    attrNames
    splitString
    head
    ;
  cfg = config.services.syncthing-wrapper;
  hostname = config.networking.hostName;
  folders = filterAttrs() cfg.folders

  rawdevFolders = filterAttrs (
    n: v: v.devices ? ${hostname} && v.user == null && v.group == null
  ) cfg.folders;
  toHostnameUsernamePair = devicename: splitString "-" devicename;
  toHostname = devicename: head (toHostnameUsernamePair devicename);
  userFolders = filterAttrs (
    n: v: (toHostname v.devices) ? ${hostname} && v.user != null && v.group == null
  ) cfg.folders;
  groupFolders = filterAttrs (
    n: v: (toHostname v.devices) ? ${hostname} && v.user == null && v.group != null
  ) cfg.folders;
  devFolders = if !cfg.isServer then rawdevFolders else rawdevFolders // userFolders;
  devices = listToAttrs (
    flatten (
      mapAttrsToList (
        _: folder: mapAttrsToList (name: value: { inherit name value; }) folder.devices
      ) devFolders
    )
  );
in
{
  config = lib.mkIf cfg.enable {
    services.syncthing = {
      enable = true;
      settings = {
        folders = mapAttrs (
          n: v:
          {
            path = v.path.${hostname};
            devices = attrNames v.devices;
          }
          // v.freeformSettings
        ) devFolders;
        devices = mapAttrs (
          name: value:
          {
            id = value."-system";
          }
          // (
            if (cfg.extraDevicesfreeformSettings ? "${name}-system") then
              cfg.extraDevicesfreeformSettings."${name}-system"
            else
              { }
          )
        ) devices;
      };
      cert = cfg.secrets.certFunction { inherit hostname; };
      key = cfg.secrets.keyFunction { inherit hostname; };
    };
  };
}
