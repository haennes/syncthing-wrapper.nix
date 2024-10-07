{ config, lib, ... }:
let ids = import ./ids.nix;
in {
  networking.hostName = "pcA"; # alternatively set dev_name in syncthing_wrapper
  boot.isContainer = true; # Hack to have an easy time building
  services.syncthing_wrapper = rec {
    ensureDirsExistsDefault = "setfacl";
    enable = true;
    DirUsersDefault = [ "commonuser" ];
    folderToPathFunc = { folder_name, DirUsers, DirGroups }:
      "${config.services.syncthing.dataDir}/${
        lib.lists.head DirUsers
      }/${folder_name}";
    default_versioning = {
      type = "simple";
      params.keep = "10";
    };
    devices = rec {
      all_pcs = {
        pcA = ids.pcA;
        pcB = ids.pcB;
      };
      all_mobiles = {
        mobile = ids.mobile;

      };
      servers = { serverA = ids.serverA; };
      all_servers = servers // { tabula = ids.tabula; };

    };
    folders = with devices; {
      Family = {
        devices = (all_pcs // servers);
        paths = {
          pcA = "/home/Family";
          pcB = "/home/Family";
        };
        ensureDirExists = null;
        DirGroups = [ "family" "syncthing" ];
      };
      Passwords = {
        devices = (all_pcs // all_mobiles // servers);
        versioning = {
          type = "simple";
          params.keep = "100";
        };
        ensureDirExists = "chown";
      };
      Documents = [ (all_pcs // servers) ];
      subdir = {
        devices = [ all_pcs "pcA" ];
        paths = rec {
          pcA = "/home/user/Documents/subdir";
          pcB = pcA;
        };
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
    # some values just to make eval happy :)
    key = "/tmp/key";
    cert = "/tmp/cert";
    # this is how have it in my config, all hosts import a the same module !!
    #key = lib.mkIf (config.services.syncthing.enable)
    #  config.age.secrets."syncthing_key_${config.networking.hostName}".path;
    #cert = lib.mkIf (config.services.syncthing.enable)
    #  config.age.secrets."syncthing_cert_${config.networking.hostName}".path;
  };
}
