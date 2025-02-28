{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg_s = config.services.syncthing;
  cfg = config.services.syncthing-wrapper;
  hostname = config.networking.hostName;
in
{
  options.services.syncthing-wrapper =
    let
      inherit (lib) mkEnableOption mkOption types;
      freefromType = (pkgs.formats.json { }).type;
    in
    {
      enable = mkEnableOption "Wether to enable syncthing-wrapper.nix";
      enableHM = mkEnableOption "Enable running syncthing per user, if hm declared for user";
      createHM = mkEnableOption ''
        If enableHM is set create new user entries for home-manager,
        otherwise fails if a new home-manager user would be created
      '';

      groups = mkOption {
        type = types.attrsOf types.submodule (
          { ... }:
          {
            options = {
              users = mkOption {
                type = types.listOf types.str;
                default = [ ];
              };
            };
          }
        );
      };
      paths = {
        basePath = mkOption {
          type = types.path;
          description = ''
            represents to common component of all paths that should be derived by a rule
            basePath argument to pathFunc
          '';
        };
        pathFunc = mkOption {
          type = types.functionTo types.path;
          description = ''
            a function that returns a path where the folder is to be synced to.

            defaults of arguments:
            grouopDir: if it is a user owned folder (user==null) then groupDir is null
            userDir: if it is a group owned folder (user==null) then userDir is null
          '';
          example =
            {
              hostname,
              basePath,
              user ? null,
              group ? null,
              folderName,
              defaultGroupDir,
              groupDir,
              defaultUserDir,
              userDir,
            }:
            let
              subdir = if user != null then user else group;
            in
            "${basePath}/${subdir}/${folderName}";

          default =
            {
              hostname,
              basePath,
              user, # 1
              group, # 2
              folderName,
              defaultGroupDir,
              groupDir, # 3
              defaultUserDir,
              userDir, # 4
            }:

            if (user == null && group == null) then
              "${basePath}/${folderName}"
            else if (user == null && group != null) then
              (
                if (groupDir != null) then
                  "${groupDir}/${folderName}"
                else
                  "${defaultGroupDir}/${group}/${folderName}"
              )
            else if (user != null && group == null) then
              (
                if (userDir != null) then "${userDir}/${folderName}" else "${defaultUserDir}/${user}/${folderName}"
              )
            # user != null && group != null
            else
              throw "syncthing-wrapper: invalid config for folder ${folderName}: specify either group or user";
        };
        groups = {
          defaultGroupDir = mkOption {
            type = types.path;
            default = "";
            description = ''
              The Base directory for folders that only have a group
            '';
          };
          groupDirMap = mkOption {
            type = types.attrsOf types.path;
            default = { };
            description = ''
              group to path map, SHOULD overwrite groupDir
            '';
          };
        };
        users = {
          defaultUserDir = mkOption {
            type = types.path;
            description = ''
              The Base directory for folders that only have a group
            '';
          };
          userDirMap = mkOption {
            type = types.attrsOf types.path;
            default = { };
            description = ''
              user to path map, SHOULD overwrite groupDir
            '';
          };
        };
      };
      secrets = {
        keyFunction = mkOption {
          type = types.functionTo types.path;
          description = ''
            {hostname, user ? null, group ? null} -> path
          '';
        };
        certFunction = mkOption {
          type = types.functionTo types.path;
          description = ''
            {hostname, user ? null, group ? null} -> path
          '';
        };
      };

      folders = mkOption {
        type = types.attrsOf (
          types.submodule (
            { name, ... }:
            {
              options = {
                user = mkOption {
                  type = types.nullOr types.str;
                  default = null; # shared folder
                  description = ''
                    name of the owner of the directory
                  '';
                };
                group = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = ''
                    Set to the name of a group that owns this folder
                  '';
                };
                devices = mkOption {
                  type = types.attrsOf types.submodule (
                    { config, ... }:
                    {
                      options = {
                        ids = {
                          user = mkOption {
                            type = types.attrOf types.str;
                            default = { };
                            description = ''
                              map of username to id
                            '';
                          };
                          system = mkOption {
                            type = types.str;
                            default = { };
                            description = ''
                              id of the system
                            '';
                          };
                        };
                        isServer = mkOption {
                          type = types.bool;
                          default = config.ids.user == { };
                          description = ''
                            if the system is a server share directly to the server id, otherwise share to the user id
                          '';
                        };

                      };
                    }
                  );
                  example = {
                    "hostname" = {
                      "-system" = "SOME-ID";
                      "username" = "SOME-ID2";
                      "username2" = "SOME-ID2";
                    };
                    "hostname3" = {
                      "-system" = "SOME-ID";
                      "username" = "SOME-ID2";
                      "username2" = "SOME-ID2";
                    };
                  };
                };
                # eg: paths.${hostname}
                path = mkOption {
                  type = types.attrsOf types.path;
                  default =
                    let
                      folder = cfg.folders.${name};
                      inherit (folder) group user;
                      key =
                        if user == null && group == null then
                          hostname
                        else if user == null then
                          "${hostname}-${group}"
                        else
                          "${hostname}-${user}";
                    in
                    {
                      ${key} =
                        let
                          folderName = name;
                          hostname = config.networking.hostName;
                        in
                        cfg.paths.pathFunc {
                          inherit folderName hostname;
                          inherit (cfg.paths) basePath;
                          inherit (cfg.paths.groups) defaultGroupDir;
                          inherit (cfg.paths.users) defaultUserDir;
                          inherit (cfg.folders.${name}) user group;
                          userDir =
                            let
                              umap = cfg.paths.users.userDirMap;
                            in
                            if umap ? ${name} then umap.${name} else null;
                          groupDir =
                            let
                              gmap = cfg.paths.users.groupDirMap;
                            in
                            if gmap ? ${name} then gmap.${name} else null;
                        };
                    };
                };
                freeformSettings = mkOption {
                  type = freefromType;
                  default = { };
                  description = ''
                    extra settings to add to the each settings.folders.\$\{name} config
                    will be merged with the options generated from this module
                    options set here take precedence
                  '';
                };
              };
            }
          )
        );
      };

      extraDevicesfreeformSettings = mkOption {
        type = types.attrsOf freefromType;
        default = { };
        description = ''
          extra settings to add to the each settings.devices.\$\{name} config
          will be merged with the options generated from this module
          options set here take precedence
        '';
      };
    };

  imports = [
    import
    ./hm-module.nix
    import
    ./sys-module.nix
  ];
}
