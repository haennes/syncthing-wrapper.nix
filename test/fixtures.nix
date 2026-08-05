# Shared test fixtures: a realistic multi-device setup similar to example/example.nix.
#
# Exports:
#   ids      device-id strings for each device
#   mkHost   a NixOS module for a given hostname, exercising every path
#            resolution rule:
#
#     userDirFolderMap (highest)  alice on alice__Downloads -> /home/alice/sdaolnwoD
#     userDirMap                  bob   on bob__Notes       -> /home/bobby/Notes
#     defaultUserDir              a, b on Passwords         -> /users/<user>/Passwords
#                                 alice on alice__Pictures  -> /users/alice/Pictures
#                                 charlie on Public         -> /users/charlie/Public
#     system DirFolderMap         alice__Downloads          -> /phys-mapped/Downloads
#     hostname filter             bob__Documents is not defined on pcA
{ lib }:
let
  inherit (lib)
    splitString
    head
    tail
    concatStringsSep
    optional
    ;
  splitStringOnce = sep: str: let sp = splitString sep str; in [ (head sp) ] ++ optional (sp != [ ]) (concatStringsSep sep (tail sp));

  ids = {
    pcA = "AAAAAAAAA-AAAAAA-AAAAAA-AAAAAA-AAAAAA-AAAAAA-AAAAAA-AAAAAAAAA";
    pcB = "BBBBBBBBB-BBBBBB-BBBBBB-BBBBBB-BBBBBB-BBBBBB-BBBBBB-BBBBBBBBB";
    mobile = "CCCCCCCCC-CCCCCC-CCCCCC-CCCCCC-CCCCCC-CCCCCC-CCCCCC-CCCCCCCCC";
    serverA = "DDDDDDDDD-DDDDDD-DDDDDD-DDDDDD-DDDDDD-DDDDDD-DDDDDD-DDDDDDDDD";
    tabula = "EEEEEEEEE-EEEEEE-EEEEEE-EEEEEE-EEEEEE-EEEEEE-EEEEEE-EEEEEEEEE";
  };

  mkHost = hostname: { config, lib, ... }: {
    networking.hostName = hostname;
    boot.isContainer = true;

    services.syncthing = {
      dataDir = "/tmp";
    };

    services.syncthing-wrapper = {
      enable = true;
      servers = [
        "serverA"
        "tabula"
      ];
      pseudoGroups.family = [
        "a"
        "b"
      ];
      paths = {
        basePath.path = "/base";
        users.defaultUserDir.path = "/users";
        users.userDirMap.Notes.path = "/home/bobby";
        users.userDirFolderMap.alice.Downloads.path = "/home/alice/sdaolnwoD";
        physicalPath = "/phys";
        system.DirFolderMap."alice__Downloads" = "/phys-mapped/Downloads";
      };
      secrets = {
        keyFunction = hostname: ./secrets/${hostname}/key.pem;
        certFunction = hostname: ./secrets/${hostname}/cert.pem;
      };
      defaultVersioning.simple.params.keep = 5;
      legacyIDMap."bob__Notes" = "NotesH";
      idToOptionalUserName = folderId:
        let
          v = head (splitStringOnce "__" folderId);
        in
        if v == (config.services.syncthing-wrapper.idToTargetName folderId) then null else v;
      folders = {
        Passwords = {
          devices = {
            pcA = ids.pcA;
            pcB = ids.pcB;
            mobile = ids.mobile;
            serverA = ids.serverA;
            tabula = ids.tabula;
          };
          pseudoGroups = [ "family" ];
          versioning.type.simple.params.keep = 10;
        };
        alice__Downloads = {
          devices = {
            pcA = ids.pcA;
            pcB = ids.pcB;
            serverA = ids.serverA;
          };
        };
        alice__Pictures = {
          devices = {
            pcA = ids.pcA;
            pcB = ids.pcB;
          };
        };
        bob__Notes = {
          devices = {
            pcA = ids.pcA;
            serverA = ids.serverA;
          };
        };
        Public = {
          devices = {
            pcA = ids.pcA;
            tabula = ids.tabula;
          };
          users = [ "charlie" ];
        };
        bob__Documents = {
          devices = {
            pcB = ids.pcB;
            serverA = ids.serverA;
            tabula = ids.tabula;
          };
          users = [ "bob" ];
        };
      };
    };
  };
in
{
  inherit ids mkHost;
}
