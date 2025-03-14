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
    paths = {
      basePath = "/tmp/sync";
      users.defaultUserDir = "/tmp/syncusers";
      physicalPath = "/tmp/syncthing";
    };
    secrets = {
      keyFunction = hostname: ./key;
      certFunction = hostname: ./cert;
    };
    legacyIDMap = {
      "hannses__Documents" = "Documents";
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
        users = [ "hannses" ];
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
