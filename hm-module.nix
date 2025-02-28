{ lib, config, ... }:
let
  inherit (lib)
    filterAttrs
    filter
    mapAttrsToList
    listToAttrs
    mapAttrs
    attrNames
    splitString
    head
    flatten
    any
    ;
  cfg = config.services.syncthing-wrapper;
  hostname = config.networking.hostName;
  toHostnameUsernamePair = devicename: splitString "-" devicename;
  toHostname = devicename: head (toHostnameUsernamePair devicename);
  userFolders =
    user:
    filterAttrs (
      n: v:
      any(iv: (toHostname iv)  == hostname) (attrNames v.devices)  &&
      v.user == user && v.group == null
    ) cfg.folders;
  groupFolders =
    group:
    filterAttrs (
      n: v: any(iv: (toHostname iv) == hostname) (attrNames v.devices) && v.user != null && v.group == group
    ) cfg.folders;
  usersWithFolders = filter (v: v != null) (mapAttrsToList (n: v: v.user) cfg.folders);
  groupsWithFolders = filter (v: v != null) (mapAttrsToList (n: v: v.group) cfg.folders);
  mapListToAttrs = lambda: l: listToAttrs (map lambda l);
  devices = userFolders: listToAttrs (flatten (mapAttrsToList (_: folder: mapAttrsToList (name: value: {inherit name value;} ) folder.devices) userFolders));

  mapDevicesToId = devices: flatten (mapAttrsToList(n: v: lib.mapAttrToList(ni: _: "${n}-${ni}")) devices);
in
{
  imports = [
  (_: {
    config = lib.mkIf cfg.createHM {
    home-manager.users = mapListToAttrs(user: {
      name = user;
      value = {
        home.stateVersion = lib.mkDefault "24.11";
      };
     }
    ) (usersWithFolders ++ groupsWithFolders);
    };
  })
  (_: {
  config = lib.mkIf (cfg.enableHM && !cfg.isServer) {
    home-manager.users = mapListToAttrs (user: {
      name = user;
      value = {
        services.syncthing = {
          enable = true;
          settings = {
            folders = mapAttrs (
              n: v:
              {
                path = v.path."${hostname}-${user}";
                devices = mapDevicesToId v.devices;
              }
              // v.freeformSettings
            ) (userFolders user);
            devices = mapAttrs (name: value:
          { id = value;} // (
              if (cfg.extraDevicesfreeformSettings ? ${name}) then
                cfg.extraDevicesfreeformSettings.${name}
              else
                { }
            )
        ) (devices (userFolders user));
          };
          cert = cfg.secrets.certFunction { inherit hostname user; };
          key = cfg.secrets.keyFunction { inherit hostname user; };
        };
      };
    }) usersWithFolders;
  };
 })
 (_: {
  config = lib.mkIf (cfg.enableHM && !cfg.isServer) {
    home-manager.users = mapListToAttrs (group: {
      name = group;
      value = {
        services.syncthing = {
          enable = true;
          settings = {
            folders = mapAttrs (
              n: v:
              {
                path = v.path."${hostname}-${group}";
                devices = mapDevicesToId v.devices;
              }
              // v.freeformSettings
            ) (userFolders group);
            devices = lib.mapAttrs(name: value:
                { id = value;}
                // (
                  if (cfg.extraDevicesfreeformSettings ? ${name}) then
                    cfg.extraDevicesfreeformSettings.${name}
                  else
                    { }
                )
            ) (devices (groupFolders group));
          };
          cert = cfg.secrets.certFunction { inherit hostname group; };
          key = cfg.secrets.keyFunction { inherit hostname group; };
        };
      };
    }) groupsWithFolders;
  };
    })
    ];
}
