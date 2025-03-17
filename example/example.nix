{ config, lib, ... }:
let
  ids = import ./ids.nix;
  devices = rec {
    all_pcs = {
      pcA = {
        id = ids.pcA;
        autoAcceptFolders = true;
      };
      pcB = ids.pcB;
    };
    all_mobiles = {
      mobile = ids.mobile;

    };
    servers = {
      serverA = ids.serverA;
    };
    all_servers = servers // {
      tabula = ids.tabula;
    };
  };
in
{
  networking.hostName = "pcA";
  boot.isContainer = true; # Hack to have an easy time building
  services.syncthing-wrapper = {
    enable = true;
    defaultVersioning.simple.params.keep = 10;
    pseudoGroups = {
      "family" = [
        "a"
        "b"
        "c"
      ];
    };
    servers = lib.attrNames devices.all_servers;
    idToOptionalUserName =
      folderId:
      let
        inherit (lib)
          head
          tail
          concatStringsSep
          optional
          splitString
          ;
        cfg = config.services.syncthing-wrapper;

        splitStringOnce =
          sep: str:
          let
            sp = (splitString sep str);
            first = head sp;
            second = (concatStringsSep sep (tail sp));
          in
          [ first ] ++ optional (second != "") second;
        v = head (splitStringOnce "__" folderId);
      in
      if v == (cfg.idToTargetName folderId) then null else v;
    paths = {
      basePath = {
        path = "/tmp/sync";
        #ensure = {
        #  DirExists = true;
        #  owner = {
        #    owner = true;
        #    name = "syncthing";
        #    recursive = false;
        #  };
        #  group = {
        #    group = true;
        #    name = "syncthingg";
        #    recursive = false;
        #  };
        #};
      };
      users.defaultUserDir = {
        path = "/tmp/syncusers";

        #ensure = {
        #  DirExists = true;
        #  owner = {
        #    owner = true;
        #    name = "syncthingtoo";
        #    recursive = false;
        #  };
        #  group = {
        #    group = true;
        #    name = "syncthingtoog";
        #    recursive = false;
        #  };
        #};
      };
      physicalPath = "/tmp/syncthing";
      system = {
        DirFolderMap.Passwords = "/syncs/PasswordsCustom";
        pathFunc =
          {
            folderName,
            folderID,
            hostname,
            physicalPath,
            systemDirFolderMapped,
          }:
          let
            cfg = config.services.syncthing-wrapper;
            cfg_s = config.services.syncthing;
            optionalUser = cfg.idToOptionalUserName folderID;
            middle = lib.optionalString (optionalUser != null) "/${optionalUser}";
            legacyID = cfg_s.settings.folders.${folderID}.id;
          in
          "${physicalPath}${middle}/${legacyID}";
      };
    };
    secrets = {
      keyFunction = hostname: ./key;
      certFunction = hostname: ./cert;
    };
    legacyIDMap = {
      "hannses__Documents" = "DocumentsH";
    };
    folders = with devices; {
      Family = {
        devices = all_pcs // servers;
        users = [ "hannses" ];
      };
      Passwords = {
        devices = (all_pcs // all_mobiles // servers);
        pseudoGroups = [ "family" ];
        freeformSettings.versioning = {
          type = "simple";
          params.keep = "100";
        };
      };
      hannses__Documents = {
        devices = (all_pcs // servers);
        #users = [ "hannses" ];
        versioning.type.simple.params.keep = 10;
      };
    };
    fsNotifyWatches = 20480;
    defaultEnsure = {
      DirExists = true;
      owner = {
        owner = true;
        recursive = true;
      };
      group = {
        group = true;
        recursive = true;
      };
      permissions = {
        permissions = "g+rw";
        recursive = true;
      };
    };
  };

  services.syncthing = {
    openDefaultPorts = true;
    dataDir = "/tmp";
    settings = {
      options = {
        urAccepted = -1; # do not send reports
        relaysEnabled = true;
      };
    };
  };
}
