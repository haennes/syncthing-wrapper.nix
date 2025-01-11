{ config, lib, pkgs, ... }:
with lib;
with lib.lists;
with lib.types;
let
  settingsFormat = pkgs.formats.json { }; # COPIED
  cfg_s = config.services.syncthing;
  cfg = config.services.syncthing_wrapper;
  dev_name = cfg.dev_name;
  take_last_n = n: l: reverseList (take 2 (reverseList l));
  dev_id_list_to_attr = l: {
    name = head l;
    value = { id = (last l); };
  }; # [$device $id] -> $device = $id

  ungroup = set:
    collect isList
    (mapAttrsRecursiveCond (as: !(isString as)) (vals: name: vals ++ [ name ])
      set); # evals to a list of groups
  devices_in_given_group = group_list:
    listToAttrs (map (l: dev_id_list_to_attr (take_last_n 2 l)) group_list);
  devices_in_group = group_list: name:
    devices_in_given_group (filter (v: elem name v)
      group_list); # input is ungrouped returns a group list
  all_devices = devices_in_given_group (ungroup cfg.devices);

  devices_type_folders = anything;

  ensureDirsExistsBaseType = {
    type = nullOr (enum [ "chown" "setfacl" ]);
    description = lib.mdDoc ''
      generate the dir with appropiate permissions
      chown: changes once, subsequent writes will be as the syncthing Users
      setfacl: changes are also made to all files when written
    '';
  };
  DirUsersGroupsBaseType = user_group: user_group_name: {
    type = nullOr (listOf (types.passwdEntry types.str));
    description = lib.mdDoc ''
      the ${user_group}s who owns the directory
      only takes effect if  ensureDirsExists is enabled
    '';
    apply = l:
      map (x:
        assert (stringLength x < 32 || abort
          "${user_group_name} '${x}' is longer than 31 characters which is not allowed!");
        x) l;
  };
  DirUsersBaseType = (DirUsersGroupsBaseType "Users" "Username");

  DirGroupsBaseType = (DirUsersGroupsBaseType "group" "Group name");
  folderToPathFuncBase = {
    type = nullOr (functionTo str);
    default = { folder_name, DirUsers, DirGroups }:
      "${cfg_s.dataDir}/${folder_name}";
  };

  def_val_folders = {
    ensureDirExists = cfg.ensureDirsExistsDefault;
    DirUsers = cfg.DirUsersDefault;
    DirGroups = cfg.DirGroupsDefault;
    folderToPathFunc = cfg.folderToPathFuncDefault;
  };
in with lib; {
  options.services.syncthing_wrapper = {
    enable = mkEnableOption "syncting_wrapper";
    dev_name = mkOption {
      type = types.str;
      default = config.networking.hostName;
    };
    folderToPathFuncDefault = mkOption folderToPathFuncBase;
    ensureServiceOwnerShip = mkEnableOption
      "ensures using setfacl that the service can access all folders and that they exist";
    ensureDirsExistsDefault =
      mkOption (ensureDirsExistsBaseType // { default = null; });
    DirUsersDefault =
      mkOption (DirUsersBaseType // { default = [ cfg_s.user ]; });
    DirGroupsDefault =
      mkOption (DirGroupsBaseType // { default = [ cfg_s.group ]; });
    devices = mkOption {
      #type = types.attrsOf (either
      #(types.attrsOf str) #grouped
      #str  # not grouped
      #);
      apply = old: { all = old; };
      description = lib.mdDoc ''
        add devices under n layerss of groups
        all devices are **automatically** added to the **all**-group as well as to the **group** of thier **own name**
      '';
      example = {
        "devicea" = "ida";
        groupa = {
          "deviceb" = "idb";
          "devicec" = "idc";
          groupc = { deviced = "idd"; };
        };
      };
    };
    folders = mkOption { # THIS IS COPIED FROM THE SYNCTHING MODULE
      type = types.attrsOf (either (types.submodule ({ name, ... }: {
        freeformType = settingsFormat.type;
        options = {
          path = mkOption {
            # TODO for release 23.05: allow relative paths again and set
            # working directory to cfg.dataDir
            type = types.str // {
              check = x:
                types.str.check x
                && (substring 0 1 x == "/" || substring 0 2 x == "~/");
              description = types.str.description + " starting with / or ~/";
            };
            default = "${cfg_s.dataDir}/${name}";
            description = lib.mdDoc ''
              The path to the folder which should be shared.
              Only absolute paths (starting with `/`) and paths relative to
              the [user](#opt-services.syncthing.user)'s home directory
              (starting with `~/`) are allowed.
            '';
          };

          id = mkOption {
            type = types.str;
            default = name;
            description = lib.mdDoc ''
              The ID of the folder. Must be the same on all devices.
            '';
          };

          label = mkOption {
            type = types.str;
            default = name;
            description = lib.mdDoc ''
              The label of the folder.
            '';
          };

          devices = mkOption {
            type = devices_type_folders;
            #supports attrset (see device group) or list of (attrset or string)
            apply = old: if isAttrs old then [ old ] else old;
            default = [ ];
            description = mdDoc ''
              The devices this folder should be shared with. Each device must
              be defined in the [devices](#opt-services.syncthing.settings.devices) option.
            '';
          };

          versioning = mkOption {
            default = cfg.default_versioning;
            description = mdDoc ''
              How to keep changed/deleted files with Syncthing.
              There are 4 different types of versioning with different parameters.
              See <https://docs.syncthing.net/users/versioning.html>.
            '';
            example = literalExpression ''
              [
                {
                  versioning = {
                    type = "simple";
                    params.keep = "10";
                  };
                }
                {
                  versioning = {
                    type = "trashcan";
                    params.cleanoutDays = "1000";
                  };
                }
                {
                  versioning = {
                    type = "staggered";
                    fsPath = "/syncthing/backup";
                    params = {
                      cleanInterval = "3600";
                      maxAge = "31536000";
                    };
                  };
                }
                {
                  versioning = {
                    type = "external";
                    params.versionsPath = pkgs.writers.writeBash "backup" '''
                      folderpath="$1"
                      filepath="$2"
                      rm -rf "$folderpath/$filepath"
                    ''';
                  };
                }
              ]
            '';
            type = with types;
              nullOr (submodule {
                freeformType = settingsFormat.type;
                options = {
                  type = mkOption {
                    type = enum [ "external" "simple" "staggered" "trashcan" ];
                    description = mdDoc ''
                      The type of versioning.
                      See <https://docs.syncthing.net/users/versioning.html>.
                    '';
                  };
                };
              });
          };

          copyOwnershipFromParent = mkOption {
            type = types.bool;
            default = false;
            description = mdDoc ''
              On Unix systems, tries to copy file/folder ownership from the parent directory (the directory it’s located in).
              Requires running Syncthing as a privileged user, or granting it additional capabilities (e.g. CAP_CHOWN on Linux).
            '';
          };

          ensureDirExists = mkOption (ensureDirsExistsBaseType // {
            default = cfg.ensureDirsExistsDefault;
          });

          DirUsers =
            mkOption (DirUsersBaseType // { default = cfg.DirUsersDefault; });
          DirGroups =
            mkOption (DirGroupsBaseType // { default = cfg.DirGroupsDefault; });
          folderToPathFunc = mkOption (folderToPathFuncBase // {
            default = cfg.folderToPathFuncDefault;
          });
        };
      })) devices_type_folders);
      apply = old:
        (mapAttrs (name: value:
          let
            val = def_val_folders // (if isList value then {
              devices = value;
              versioning = cfg.default_versioning;
            } else
              value);
            def_path = val.folderToPathFunc {
              folder_name = name;
              inherit (val) DirUsers DirGroups;
            };
          in val // {
            devices = flatten (map (dev:
              if isString dev then
                lib.attrNames (devices_in_group (ungroup cfg.devices) dev)
              else
                lib.attrNames (devices_in_given_group (ungroup dev)))
              val.devices);
            path = if ((val ? paths) && (val.paths ? "${dev_name}")) then
              val.paths."${dev_name}"
            else
              def_path;
          }) old);
    };

    default_versioning = mkOption {
      default = null;
      description = mdDoc ''
        How to keep changed/deleted files with Syncthing.
        There are 4 different types of versioning with different parameters.
        See <https://docs.syncthing.net/users/versioning.html>.
      '';
      example = literalExpression ''
        [
          {
            default_versioning = {
              type = "simple";
              params.keep = "10";
            };
          }
          {
            default_versioning = {
              type = "trashcan";
              params.cleanoutDays = "1000";
            };
          }
          {
            default_versioning = {
              type = "staggered";
              fsPath = "/syncthing/backup";
              params = {
                cleanInterval = "3600";
                maxAge = "31536000";
              };
            };
          }
          {
            default_versioning = {
              type = "external";
              params.versionsPath = pkgs.writers.writeBash "backup" '''
                folderpath="$1"
                filepath="$2"
                rm -rf "$folderpath/$filepath"
              ''';
            };
          }
        ]
      '';
      type = with types;
        nullOr (submodule {
          freeformType = settingsFormat.type;
          options = {
            type = mkOption {
              type = enum [ "external" "simple" "staggered" "trashcan" ];
              description = mdDoc ''
                The type of versioning.
                See <https://docs.syncthing.net/users/versioning.html>.
              '';
            };
          };
        });
    };
  };
  config = let setfacl_mid = prefix: mid: map (x: "${prefix}:${x}:rwX") mid; #X sets the sticky bit afai understand
  in mkIf cfg.enable {
    systemd.tmpfiles.rules = lib.mkIf cfg.ensureServiceOwnerShip (
      flatten (mapAttrsToList(_: v: [
        "A+ ${v.path} - - - - user:${cfg_s.user}:rw"
        "A+ ${v.path} - - - - group:${cfg_s.group}:rw"
      ]) cfg_s.settings.folders)
    );
    #system.activationScripts = {
    #  ensure-syncthing-dir-ownership.text = lib.mkIf cfg.ensureServiceOwnerShip
    #    (concatStringsSep "\n" (mapAttrsToList (n: v: ''
    #      mkdir -p ${v.path}
    #      ${pkgs.acl}/bin/setfacl -R -m ${
    #        concatStringsSep "," ((setfacl_mid "u" [ cfg_s.user ])
    #          ++ (setfacl_mid "g" [ cfg_s.group ]))
    #      } ${v.path}'') cfg_s.settings.folders));
    #  ensure-syncthing-dir-permissions.text = concatStringsSep "\n"
    #    (mapAttrsToList (n: v:
    #      let
    #        chown_cmd = user: group: "chown -R ${user}:${group} ${v.path}";
    #        cmd = if v.ensureDirExists == "setfacl" then ''
    #          ${pkgs.acl}/bin/setfacl -R -m ${
    #            concatStringsSep ","
    #            ((setfacl_mid "u" v.DirUsers) ++ (setfacl_mid "g" v.DirGroups))
    #          } ${v.path}'' else if v.ensureDirExists == "setfacl" then
    #          let
    #            user = assert (length v.DirUsers < 2); (head v.DirUsers);
    #            group = assert (length v.DirGroups < 2); (head v.DirGroups);
    #          in chown_cmd user group else "";
    #      in ''
    #        mkdir -p ${v.path}
    #        ${cmd}'')
    #      (filterAttrs (n: v: v.ensureDirExists != null && cfg_s.settings.folders ? "${n}") cfg.folders));
    #};
    services.syncthing = let
      all_shared_to_devices =
        flatten (mapAttrsToList (n: v: v.devices) cfg_s.settings.folders);
    in {
      enable = true;
      # override options are set. Use mkForce to override
      overrideDevices = true;
      overrideFolders = true;
      openDefaultPorts = true;
      settings = {
        devices = filterAttrs (n: _: elem n all_shared_to_devices) all_devices;
        folders = filterAttrs (n: v: elem dev_name v.devices) (mapAttrs
          (n: v: removeAttrs v ([ "paths" ] ++ (attrNames def_val_folders)))
          cfg.folders);
      };
    };
  };

}
