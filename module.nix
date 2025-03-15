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
    concatStringsSep
    attrByPath
    optional
    ;
  cfg_s = config.services.syncthing;
  cfg = config.services.syncthing-wrapper;
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
in
{
  options.services.syncthing-wrapper =
    let
      inherit (lib) mkEnableOption mkOption types;
      freefromType = (pkgs.formats.json { }).type;
      versioningType =
        default:
        let
          nullOrOpt =
            { type, ... }@inputs:
            (
              mkOption {
                type = types.nullOr type;
                default = null;
              }
              // (lib.removeAttrs inputs [ "type" ])
            );
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
      #https://github.com/hpfr/system/blob/a108a5ebf3ffcee75565176243936de6fd736142/profiles/system/gui-base.nix#L108

      #https://github.com/ckiee/nixfiles/blob/fad42a1724183f76424f81b9a8a14f5573a1a1d5/modules/bindfs.nix#L6

      #https://discourse.nixos.org/t/how-to-use-bindfs-on-nixos/32205

      #https://github.com/ckiee/nixfiles/blob/fad42a1724183f76424f81b9a8a14f5573a1a1d5/modules/services/soju.nix#L32

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
      paths = {
        physicalPath = mkOption {
          type = types.path;
          description = ''
            The path where the actual directories being synced will be created under
          '';
        };
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
          '';
          example =
            {
              hostname,
              basePath,
              user,
              pseudoGroup ? null,
              folderName,
              defaultUserDir,
              userDir,
              userDirFolder,
            }:
            "${basePath}/${user}/${folderName}";

          default =
            {
              hostname,
              basePath,
              user,
              folderName, # here folder label
              defaultUserDir,
              userDir, # defacto home of the user
              userDirFolder,
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
          defaultUserDir = mkOption {
            type = types.path;
            description = ''
              The Base directory for folders that are owned by a user
            '';
            example = "/home";
          };
          userDirMap = mkOption {
            type = types.attrsOf types.path;
            default = { };
            description = ''
              user to path map, SHOULD overwrite userDir
            '';
            example = {
              alice = "/home/alicia";
            };
          };
          userDirFolderMap = mkOption {
            type = types.attrsOf (types.attrsOf types.path);
            description = ''
              maps a specific folder (by name) to a different path
            '';
            example = {
              alice.Downloads = "/home/alice/sdaolnwoD";
            };
            default = { };
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
              inherit (lib) flatten map assertMsg;
              folderName = cfg.idToTargetName name;
              folderID = name;
            in
            {
              options = {
                users = mkOption {
                  type = types.listOf types.str;
                  default = flatten (map expandPseudoGroup cfg_inner.pseudoGroups);
                  apply =
                    x:
                    assert assertMsg (
                      x != [ ]
                    ) "users for folder ${name} is empty, set either the users option or the pseudoGroups option";
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
                  type = types.attrsOf types.str;
                  example = {
                    "hostname" = "SOME-ID";
                    "hostname3" = "SOME-ID";
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
                path = mkOption {
                  type = types.attrsOf (types.attrsOf types.path);
                  default =
                    let
                      folder = cfg.folders.${name};
                      #pseudo_groups_users = unique (flatten (map (gn: cfg.pseudoGroups.${gn}) folder.pseudoGroups));
                      hostname = config.networking.hostName;
                      inner_users =
                        #assert (assertMsg (cfg_inner.users != [ ]) "error");
                        cfg_inner.users;
                    in
                    {
                      ${hostname} =
                        {
                          # this is the defacto path where the directory will physically live. all other paths are bind-mounts of this.
                          system = "${cfg.paths.physicalPath}/${folderID}";
                        }
                        // (mapListToAttrs (user: {
                          name = user;
                          value = cfg.paths.pathFunc {
                            inherit folderName hostname; # TODO pass folderLabel here as well
                            inherit (cfg.paths) basePath;
                            inherit (cfg.paths.users) defaultUserDir;
                            userDirFolder = attrByPath [ user folderName ] null cfg.paths.users.userDirFolderMap;
                            #inherit (cfg.folders.${folderName}) user;
                            inherit user;
                            userDir = attrByPath [ folderName ] null cfg.paths.users.userDirMap;
                            #userDir =
                            #  let
                            #    umap = cfg.paths.users.userDirMap;
                            #  in
                            #  if umap ? ${folderName} then umap.${folderName} else null;
                          };
                        }) inner_users);
                    };
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
                  type = freefromType;
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

      extraDevicesfreeformSettings = mkOption {
        type = types.attrsOf freefromType;
        default = { };
        description = ''
          extra settings to add to the each settings.devices.\$\{name} config
          will be merged with the options generated from this module
          options set here take precedence
        '';
      };

      defaultVersioning = versioningType null;
    };

  imports = [
    ./sys-module.nix
  ];
}
