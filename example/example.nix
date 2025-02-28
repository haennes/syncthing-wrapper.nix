{ config, lib, ... }:
let
  ids = import ./ids.nix;
  devices = rec {
    all_pcs = {
      pcA = ids.pcA;
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
  services.syncthing-wrapper = rec {
    enable = true;
    enableHM = true;
    createHM = true;
    #TODO default_versioning
    #default_versioning = {
    #  type = "simple";
    #  params.keep = "10";
    #};
    paths = {
      basePath = "/tmp/sync";
      users.defaultUserDir = "/tmp/syncusers";
    };
    secrets = {
      keyFunction =
        {
          hostname,
          user ? null,
          group ? null,
        }:
        ./key; # TODO make more advanced and check if it still works
      certFunction =
        {
          hostname,
          user ? null,
          group ? null,
        }:
        ./cert; # TODO make more advanced and check if it still works
    };
    folders = with devices; {
      Family = {
        devices = all_pcs // servers;
      };
      Passwords = {
        devices = (all_pcs // all_mobiles // servers);
        freeformSettings.versioning = {
          type = "simple";
          params.keep = "100";
        };
      };
      Documents = {
        devices = (all_pcs // servers);
        user = "hannses";
      };
      subdir = {
        devices = all_pcs // {
          inherit (all_pcs) pcA;
        };
        path.pcA-hannses = "/home/user/Documents/subdir";
        user = "hannses";

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
    # this is how have it in my config, all hosts import a the same module !!
    #key = lib.mkIf (config.services.syncthing.enable)
    #  config.age.secrets."syncthing_key_${config.networking.hostName}".path;
    #cert = lib.mkIf (config.services.syncthing.enable)
    #  config.age.secrets."syncthing_cert_${config.networking.hostName}".path;
  };
}
