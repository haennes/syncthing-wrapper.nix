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
            path = (v.path.${hostname}).system.path;
            id = lib.mkIf (cfg.legacyIDMap ? ${n}) cfg.legacyIDMap.${n};
            devices = remove hostname (attrNames v.devices);
            versioning = lib.mkIf (v.versioning != null) (
              let
                type = head (attrNames v.versioning.type);
                inheritNotNull = set: name: {
                  ${name} = lib.mkIf (set ? ${name} && set.${name} != null) (toString set.${name});
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
              name = target_path.path;
              value = {
                source = system_paths.system.path;
                map.userGroup = {
                  "${cfg_s.user}" = username;
                };
              };
            }) target_paths
          ) folders
        )
      );

    };
    system.activationScripts.syncthing-wrapper-ensure =
      let
        inherit (lib) optional optionalString;
        ensureDirExistsGen =
          attr: optional (attr.ensure.DirExists && attr.path != null) "mkdir -p ${attr.path}";
        ensureOwner =
          attr: owner:
          let
            owner_opt = attr.ensure.owner;
          in
          optional (
            owner_opt.owner && attr.path != null
          ) "chown ${optionalString owner_opt.recursive "-R"} ${owner} ${attr.path}";
        ensureGroup =
          attr: group:
          let
            group_opt = attr.ensure.group;
          in
          optional (
            group_opt.group && attr.path != null
          ) "chown ${optionalString group_opt.recursive "-R"} :${group} ${attr.path}";
        ensurePermissions =
          attr:
          let
            permissions_opt = attr.ensure.permissions;
          in
          optional (permissions_opt.permissions != null && attr.path != null)
            "chmod ${optionalString permissions_opt.recursive "-R"} ${permissions_opt.permissions} ${attr.path}";
      in
      lib.concatLines (
        (ensureDirExistsGen cfg.paths.physicalPath)
        #exist
        ++ (ensureDirExistsGen cfg.paths.basePath)
        ++ (ensureDirExistsGen cfg.paths.users.defaultUserDir)
        ++ (flatten (
          mapAttrsToList (
            _: folder: mapAttrsToList (_: dir: ensureDirExistsGen dir) folder.path.${hostname}
          ) folders
        ))

        #owner & group
        ##physicalPath
        ++ (ensureOwner cfg.paths.physicalPath cfg_s.user)
        ++ (ensureGroup cfg.paths.physicalPath cfg_s.group)

        ##basePath
        ++ (ensureOwner cfg.paths.basePath cfg.paths.basePath.ensure.owner.name)
        ++ (ensureGroup cfg.paths.basePath cfg.paths.basePath.ensure.group.name)

        ##defaultUserDir
        ++ (ensureOwner cfg.paths.users.defaultUserDir cfg.paths.users.defaultUserDir.ensure.owner.name)
        ++ (ensureGroup cfg.paths.users.defaultUserDir cfg.paths.users.defaultUserDir.ensure.group.name)

        ##userFolders
        ++ (flatten (
          mapAttrsToList (
            _: v:
            let
              system_paths = v.path.${hostname};
              target_paths = removeAttrs system_paths [ "system" ];
            in
            mapAttrsToList (
              username: target_path:
              (ensureOwner target_path username)
              ++ lib.optionals (lib.hasAttrByPath [ username "group" ] config.users.users) (
                ensureGroup target_path config.users.users.${username}.group
              )
            ) target_paths
          ) folders
        ))

        ##physicalFolder
        ++ (flatten (
          mapAttrsToList (
            _: v:
            (ensureOwner v.path.${hostname}.system cfg_s.user)
            ++ (ensureGroup v.path.${hostname}.system cfg_s.group)
          ) folders
        ))
        #permissions
        ++ (ensurePermissions cfg.paths.physicalPath)
        ++ (ensurePermissions cfg.paths.basePath)
        ++ (ensurePermissions cfg.paths.users.defaultUserDir)
        ++ (flatten (
          mapAttrsToList (
            _: folder: mapAttrsToList (_: dir: ensurePermissions dir) folder.path.${hostname}
          ) folders
        ))

      );

    boot.kernel.sysctl = lib.mkIf (cfg.fsNotifyWatches != null) {
      "fs.inotify.max_user_watches" = cfg.fsNotifyWatches;
    };
  };
}
