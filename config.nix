{ lib, config, ... }:
let
  inherit (lib)
    filterAttrs
    mapAttrs
    mapAttrsToList
    listToAttrs
    flatten
    attrNames
    head
    remove
    ;
  cfg = config.services.syncthing-wrapper;
  cfg_s = config.services.syncthing;
  hostname = config.networking.hostName;
  folders = filterAttrs (n: v: v.devices ? "${hostname}") cfg.folders;
  devices = listToAttrs (
    flatten (
      mapAttrsToList (
        _: folder: mapAttrsToList (name: value: { inherit name value; }) folder.devices
      ) folders
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
            path = (v.path.${hostname}).system;
            id = lib.mkIf (cfg.legacyIDMap ? ${n}) cfg.legacyIDMap.${n};
            devices = remove hostname (attrNames v.devices);
            versioning = lib.mkIf (v.versioning != null) (
              let
                type = head (attrNames v.versioning.type);
                inheritNotNull = set: name: {
                  ${name} = lib.mkIf (set ? ${name} && set.${name} != null) set.${name};
                };
                inheritNotNullVers = inheritNotNull v.versioning.type.${type};
              in
              {
                inherit type;
              }
              // (inheritNotNullVers "fsPath")
              // (inheritNotNullVers "fsType")
              // (inheritNotNullVers "cleanupIntervalS")
              // (
                let
                  params = v.versioning.type.${type}.params;
                in
                {
                  params = lib.mkIf (params != null) (
                    (inheritNotNull params "cleanoutDays")
                    // (inheritNotNull params "keep")
                    // (inheritNotNull params "maxAge")
                    // (inheritNotNull params "command")
                  );
                }
              )
            );
          }
          // v.freeformSettings
        ) folders;
        devices = removeAttrs devices [ hostname ];
      };
      cert = cfg.secrets.certFunction hostname;
      key = cfg.secrets.keyFunction hostname;
    };

    bindfs = lib.mkIf (!cfg.isServer) {
      enable = true;
      folders = listToAttrs (
        flatten (
          mapAttrsToList (
            _: v:
            let
              system_paths = v.path.${hostname};
              target_paths = removeAttrs system_paths [ "system" ];
            in
            mapAttrsToList (username: target_path: {
              name = target_path;
              value = {
                source = system_paths.system;
                map.userGroup = {
                  "${cfg_s.user}" = username;
                };
              };
            }) target_paths
          ) folders
        )
      );

    };

    boot.kernel.sysctl = lib.mkIf (cfg.fsNotifyWatches != null) {
      "fs.inotify.max_user_watches" = cfg.fsNotifyWatches;
    };
  };
}
