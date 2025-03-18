{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    listToAttrs
    splitString
    head
    tail
    last
    elem
    unique
    concatStringsSep
    attrByPath
    optional
    flatten
    map
    assertMsg
    isString
    mapAttrs
    ;
  cfg = config.services.syncthing-wrapper;
  cfg_s = config.services.syncthing;
  hostname = config.networking.hostName;
  mapListToAttrs = f: l: listToAttrs (map f l);
  expandPseudoGroup = group: cfg.pseudoGroups.${group}; # Recursion??
  splitStringOnce =
    sep: str:
    let
      sp = (splitString sep str);
      first = head sp;
      second = (concatStringsSep sep (tail sp));
    in
    [ first ] ++ optional (second != "") second;

  nullOrOpt =
    { type, ... }@inputs:
    (
      lib.mkOption {
        type = lib.types.nullOr type;
        default = null;
      }
      // (lib.removeAttrs inputs [ "type" ])
    );
  pathEnsureOptSubmoduleOptions = needs_user_group_name: description: {
    path = lib.mkOption {
      type = lib.types.path;
      inherit description;
    };
    ensure =
      let
        recursiveOption = {
          recursive = lib.mkEnableOption ''
            wether to do so recursively
          '';
        };
        recursiveEnableOption =
          key: description:
          {
            ${key} = lib.mkEnableOption description;
          }
          // (
            if needs_user_group_name then
              {
                name = lib.mkOption {
                  type = lib.types.str;
                  description = ''the target group / user'';
                };
              }
            else
              { }
          )
          // recursiveOption;
      in
      {
        DirExists = lib.mkEnableOption ''
          create the directory with mkdir -p if it doesnt exist
        '';
        owner = recursiveEnableOption "owner" ''
          chown the directory to the correct owner
        '';
        group = recursiveEnableOption "group" ''
          chown the directory to the correct group
        '';
        permissions = {
          permissions = nullOrOpt {
            type = lib.types.str;
            description = ''
              if not null set permissions using chmod $this_string
            '';
          };
        } // recursiveOption;

      };
  };

  pathEnsureOptType =
    needs_user_group_name: description:
    lib.types.either lib.types.path (
      lib.types.submodule (
        { ... }:
        {
          options = pathEnsureOptSubmoduleOptions needs_user_group_name description;
        }
      )
    );
  pathEnsureApply =
    custom_ensure_default: description: x:
    if lib.isAttrs x then
      x
    else
      {
        path = x;
        ensure =
          if custom_ensure_default == null then
            lib.mapAttrsRecursiveCond (as: !(as ? "_type" && as._type == "option")) (_: v: v) cfg.defaultEnsure
          else
            custom_ensure_default;
      };
  pathEnsureOpt =
    allow_null: custom_ensure_default: needs_user_group_name:
    { description, ... }@inputs:
    let
      type = pathEnsureOptType needs_user_group_name description;
    in
    lib.mkOption {
      type = if allow_null then lib.types.nullOr type else type;
      apply = pathEnsureApply custom_ensure_default description;
    }
    // inputs;
in
{
  options.services.syncthing-wrapper =
    let
      inherit (lib) mkEnableOption mkOption types;
      freeformType = (pkgs.formats.json { }).type;
      versioningType =
        default:
        let
          fsType = nullOrOpt { type = types.str; };
          fsPath = nullOrOpt { type = types.path; };
          cleanupIntervalS = nullOrOpt { type = types.int; };
          params = {
            cleanoutDays = nullOrOpt { type = types.int; };
            keep = nullOrOpt { type = types.int; };
            maxAge = nullOrOpt { type = types.int; };
            command = nullOrOpt { type = types.str; };
          };
        in
        mkOption {
          inherit default;
          type = types.nullOr (
            types.attrTag {
              trashcan = mkOption {
                type = types.submodule (
                  { ... }:
                  {
                    options = {
                      inherit
                        fsType
                        fsPath
                        cleanupIntervalS
                        params
                        ;
                    };
                  }
                );
              };
              simple = mkOption {
                type = types.submodule {
                  options = {
                    inherit
                      fsType
                      fsPath
                      cleanupIntervalS
                      params
                      ;
                  };
                };
              };
              staggered = mkOption {
                type = types.submodule {
                  options = {
                    inherit
                      fsType
                      fsPath
                      cleanupIntervalS
                      params
                      ;
                  };
                };
              };
              external = mkOption {
                type = types.submodule {
                  options = {
                    inherit params;
                  };
                };
              };
            }
          );

        };
    in
    {
      enable = mkEnableOption "Wether to enable syncthing-wrapper.nix";
      servers = mkOption {
        type = types.listOf (types.str);
        default = [ ];
        description = ''
          list of hostnames for which isServer will be set to true
        '';
      };
      isServer = mkOption {
        type = types.bool;
        default = elem hostname cfg.servers;
        description = "If this device is a server (do not make bindfs mounts)";
      };
      fsNotifyWatches = nullOrOpt {
        type = types.int;
        description = ''
          number of maximal file watches.
          should exceed the total number of folders being shared,
          including any child folders
        '';
      };
      pseudoGroups = mkOption {
        type = types.attrsOf (types.listOf types.str);
        default = { };
        example = {
          "cryptobros" = [
            "alice"
            "bob"
          ];
        };
      };
      legacyIDMap = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = ''
          allows you to map your specified ids to another id.
          this is mainly useful, if you already have a syncthing setup
          and you want to keep the same ids
        '';
        example = {
          Alice__Downloads = "DownloadsAlice";
        };
      };
      idToTargetName = mkOption {
        type = types.functionTo types.str;
        description = ''
          the function will recieve the folder id as an input
          map a folder id: eg Alice__Downloads to the directory name -> Downloads
        '';
        default = folderId: last (splitStringOnce "__" folderId);
      };
      idToOptionalUserName = mkOption {
        type = types.functionTo (types.nullOr types.str);
        description = ''
          the function will recieve the folder id as an input
          map a folder id: eg Alice__Downloads to a user name, which will be added to users of the folder
          if this returns null dont add any user
        '';
        default = _: null;
        example =
          folderId:
          let
            v = head (splitStringOnce "__" folderId);
          in
          if v == (cfg.idToTargetName folderId) then null else v;
      };
      paths = {
        physicalPath = pathEnsureOpt false null false {
          description = ''
            The path where the actual directories being synced will be created under
          '';
          default = cfg_s.dataDir;
        };
        basePath =
          pathEnsureOpt true
            {
              DirExists = true;
              owner = {
                owner = false;
                name = "";
                recursive = false;
              };
              group = {
                group = false;
                name = "";
                recursive = false;
              };
              permissions = cfg.defaultEnsure.permissions;

            }
            true
            {
              description = ''
                represents to common component of all paths that should be derived by a rule
                basePath argument to pathFunc
              '';
              default = null;
            };
        pathFunc = mkOption rec {
          type = types.functionTo (pathEnsureOptType false description);
          description = ''
            a function that returns a path where the folder is to be synced to.
          '';
          example =
            {
              hostname,
              basePath,
              user,
              pseudoGroup ? null,
              folderName,
              folderID,
              defaultUserDir,
              userDir,
              userDirFolder,
            }:
            "${basePath}/${user}/${folderName}";

          default =
            {
              basePath,
              user,
              folderName, # here folder label
              defaultUserDir,
              userDir, # defacto home of the user
              userDirFolder,
              ...
            }:
            if (userDirFolder != null) then
              userDirFolder
            else if (userDir != null) then
              "${userDir}/${folderName}"
            else if defaultUserDir != null then
              "${defaultUserDir}/${user}/${folderName}"
            else
              "${basePath}/${user}/${folderName}";
        };
        users = {
          defaultUserDir =
            pathEnsureOpt false
              {
                DirExists = false;
                owner = {
                  owner = false;
                  name = "";
                  recursive = false;
                };
                group = {
                  group = false;
                  name = "";
                  recursive = false;
                };
                permissions = cfg.defaultEnsure.permissions;

              }
              true
              {
                description = ''
                  The Base directory for folders that are owned by a user
                '';
                example = "/home";
              };
          userDirMap = mkOption rec {
            type = types.attrsOf (pathEnsureOptType false description);
            default = { };
            description = ''
              user to path map, SHOULD overwrite userDir
            '';
            example = {
              alice = "/home/alicia";
            };
          };
          userDirFolderMap = mkOption rec {
            type = types.attrsOf (types.attrsOf (pathEnsureOptType false description));
            description = ''
              maps a specific folder (**by name**) to a different path
            '';
            example = {
              alice.Downloads = "/home/alice/sdaolnwoD";
            };
            default = { };
          };
        };
        system = {
          pathFunc = mkOption rec {
            type = types.functionTo (pathEnsureOptType false description);
            default =
              {
                folderID,
                systemDirFolderMapped,
                physicalPath,
                ...
              }:
              if systemDirFolderMapped == null then "${physicalPath}/${folderID}" else systemDirFolderMapped;
            example =
              {
                folderName,
                folderID,
                hostname,
                physicalPath,
                systemDirFolderMapped,
              }:
              "${physicalPath}/${folderID}/${folderName}";
            description = ''
              a function that returns a path where the folder is to be physically synced to.
            '';
          };
          DirFolderMap = mkOption rec {
            type = types.attrsOf (pathEnsureOptType false description);
            default = { };
            description = ''
              maps a specific folder (**by id**) to a different physical path
            '';
            example = {
              Alice__Downloads = "/path/syncthing/DownloadsAlice";
            };
          };
        };
      };
      secrets = {
        keyFunction = mkOption {
          type = types.functionTo types.path;
          description = ''
            hostname -> path
          '';
        };
        certFunction = mkOption {
          type = types.functionTo types.path;
          description = ''
            hostname -> path
          '';
        };
      };

      folders = mkOption {
        type = types.attrsOf (
          types.submodule (
            { name, ... }:
            let
              cfg_inner = cfg.folders.${name};
              folderName = cfg.idToTargetName name;
              folderID = name;
            in
            {
              options = {
                users = mkOption {
                  type = types.listOf types.str;
                  default =
                    let
                      optionalUser = cfg.idToOptionalUserName name;
                    in
                    unique (
                      (flatten (map expandPseudoGroup cfg_inner.pseudoGroups))
                      ++ optional (optionalUser != null) optionalUser
                    );
                  apply =
                    x:
                    assert assertMsg (x != [ ])
                      "users for folder ${name} is empty, set either the users option or the pseudoGroups option or ensure idToOptionalUserName does not evaluate to null";
                    x;
                  description = ''
                    name of the owner(s) of the directory
                  '';
                  example = [
                    "alice"
                    "bob"
                  ];
                };
                pseudoGroups = mkOption {
                  type = types.listOf types.str;
                  default = [ ];
                  description = ''
                    Set to the name of pseudoGroup that owns this folder
                  '';
                  example = [ "cryptobros" ];
                };
                devices = mkOption {
                  type = types.attrsOf (
                    types.either types.str (
                      types.submodule (
                        { name, ... }:
                        {
                          inherit freeformType;
                          options = {
                            name = mkOption {
                              type = types.str;
                              default = name;
                              description = ''
                                The name of the device.
                              '';
                              #not to self: do not use this in evaluations
                            };

                            id = mkOption {
                              type = types.str;
                              description = ''
                                The device ID. See <https://docs.syncthing.net/dev/device-ids.html>.
                              '';
                            };

                            autoAcceptFolders = mkOption {
                              type = types.bool;
                              default = false;
                              description = ''
                                Automatically create or share folders that this device advertises at the default path.
                                See <https://docs.syncthing.net/users/config.html?highlight=autoaccept#config-file-format>.
                              '';
                            };
                          };
                        }
                      )
                    )
                  );
                  apply =
                    def:
                    mapAttrs (
                      name: value:
                      if isString value then
                        {
                          id = value;
                        }
                      else
                        value
                    ) def;
                  example = {
                    "hostname" = "SOME-ID";
                    "hostname3" = "SOME-ID";
                    "hostcomplicated" = {
                      id = "SOME-ID";
                      autoAcceptFolders = true;

                    };
                  };
                };
                targetName = mkOption {
                  type = types.str;
                  description = ''
                    target folder name. This is useful if you have multiple owners sharing the same directories
                    by default uses the  idToTargetName to map a folder id
                    e.g. Downloads: Alice__Downloads to the directory name -> Downloads
                  '';
                  default = cfg.idToTargetName name;
                };
                # eg: paths.${hostname}.system
                path = mkOption rec {
                  type = types.attrsOf (types.attrsOf (pathEnsureOptType false description));
                  default = {
                    ${hostname} =
                      {
                        # this is the defacto path where the directory will physically live. all other paths are bind-mounts of this.
                        system = cfg.paths.system.pathFunc {
                          inherit folderName folderID hostname;
                          physicalPath = cfg.paths.physicalPath.path;
                          systemDirFolderMapped = attrByPath [
                            folderID
                            "path"
                          ] null cfg.paths.system.DirFolderMap;
                        };
                      }
                      // (mapListToAttrs (user: {
                        name = user;
                        value = cfg.paths.pathFunc {
                          inherit folderName folderID hostname;
                          basePath = cfg.paths.basePath.path;
                          defaultUserDir = attrByPath [ "defaultUserDir" "path" ] null cfg.paths.users;
                          userDirFolder = attrByPath [ user folderName "path" ] null cfg.paths.users.userDirFolderMap;
                          inherit user;
                          userDir = attrByPath [ folderName "path" ] null cfg.paths.users.userDirMap;
                        };
                      }) cfg_inner.users);
                  };
                  apply = x: mapAttrs (_: xi: mapAttrs (_: v: pathEnsureApply null description v) xi) x;
                  description = ''
                    By default you should not need to set this. This is the whole point of this flake :)
                    But you have the option to do so
                  '';
                  example = {
                    pcA = {
                      system = "/the/root/path/where/the/actual/files/live";
                      alice = "/home/alice/dir";
                      bob = "/home/bob/bobsdir";
                    };
                  };
                };
                versioning = {
                  type = versioningType cfg.defaultVersioning;
                  default = cfg.defaultVersioning;
                };
                freeformSettings = mkOption {
                  type = freeformType;
                  default = { };
                  description = ''
                    extra settings to add to the each settings.folders.\$\{name}.system config
                    will be merged with the options generated from this module
                    options set here take precedence
                  '';
                };
              };
            }
          )
        );
      };

      defaultVersioning = versioningType null;
      defaultEnsure = (pathEnsureOptSubmoduleOptions false "").ensure;
    };

}
