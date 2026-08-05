# Unit tests for the generated syncthing settings, bindfs mounts,
# activation script and tmpfiles rules.
{ harness, fixtures }:
let
  inherit (harness) lib;

  cfgA = harness.evalConfig [ (fixtures.mkHost "pcA") ];
  cfgServer = harness.evalConfig [ (fixtures.mkHost "serverA") ];

  sA = cfgA.services.syncthing;
  wA = cfgA.services.syncthing-wrapper;

  cfgEnsure = harness.evalConfig [
    (fixtures.mkHost "pcA")
    {
      services.syncthing-wrapper.defaultEnsure = {
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
    }
  ];
  ensureLines = lib.splitString "\n" cfgEnsure.system.activationScripts.syncthing-wrapper-ensure;

  tmpfileCopies =
    kind:
    lib.any (
      r:
      lib.hasPrefix "C /run/secrets/syncthing/pcA/${kind}.pem 0400 syncthing syncthing - " r
      && lib.hasSuffix "${kind}.pem" r
    ) cfgA.systemd.tmpfiles.rules;
in
[
  {
    name = "pcA: folder devices exclude the host itself";
    expr = sA.settings.folders.Passwords.devices;
    expected = [
      "mobile"
      "pcB"
      "serverA"
      "tabula"
    ];
  }
  {
    name = "pcA: folders not shared on this host are dropped";
    expr = lib.attrNames sA.settings.folders;
    expected = [
      "Passwords"
      "Public"
      "alice__Downloads"
      "alice__Pictures"
      "bob__Notes"
    ];
  }
  {
    name = "pcA: devices are inferred from all shared folders";
    expr = lib.attrNames sA.settings.devices;
    expected = [
      "mobile"
      "pcB"
      "serverA"
      "tabula"
    ];
  }
  {
    name = "pcA: device ids are looked up from the folders";
    expr = sA.settings.devices.serverA.id;
    expected = fixtures.ids.serverA;
  }
  {
    name = "pcA: folder system path is written to the syncthing settings";
    expr = sA.settings.folders."alice__Downloads".path;
    expected = "/phys-mapped/Downloads";
  }
  {
    name = "pcA: defaultVersioning is applied to every folder";
    expr = sA.settings.folders.Public.versioning;
    expected = {
      type = "simple";
      params = {
        keep = "5";
      };
    };
  }
  {
    name = "pcA: folder-local versioning overrides the default";
    expr = sA.settings.folders.Passwords.versioning;
    expected = {
      type = "simple";
      params = {
        keep = "10";
      };
    };
  }
  {
    name = "pcA: legacyIDMap is applied as the folder id";
    expr = sA.settings.folders."bob__Notes".id;
    expected = "NotesH";
  }
  {
    name = "pcA: folders without a legacy id keep their name";
    expr = sA.settings.folders.Passwords.id;
    expected = "Passwords";
  }
  {
    name = "pcA: cert points to a runtime string path";
    expr = sA.cert;
    expected = "/run/secrets/syncthing/pcA/cert.pem";
  }
  {
    name = "pcA: key points to a runtime string path";
    expr = sA.key;
    expected = "/run/secrets/syncthing/pcA/key.pem";
  }
  {
    name = "pcA: tmpfiles creates the secrets directory";
    expr = lib.any (
      r: r == "d /run/secrets/syncthing/pcA 0700 syncthing syncthing -"
    ) cfgA.systemd.tmpfiles.rules;
    expected = true;
  }
  {
    name = "pcA: tmpfiles copies the cert from its store path";
    expr = tmpfileCopies "cert";
    expected = true;
  }
  {
    name = "pcA: tmpfiles copies the key from its store path";
    expr = tmpfileCopies "key";
    expected = true;
  }
  {
    name = "pcA: bindfs is enabled on a non-server host";
    expr = cfgA.bindfs.enable;
    expected = true;
  }
  {
    name = "pcA: bindfs maps the system path to the user path";
    expr = cfgA.bindfs.folders."/home/alice/sdaolnwoD".source;
    expected = "/phys-mapped/Downloads";
  }
  {
    name = "pcA: bindfs maps the syncthing user to the folder owner";
    expr = cfgA.bindfs.folders."/home/alice/sdaolnwoD".map.userGroup;
    expected = {
      syncthing = "alice";
    };
  }
  {
    name = "pcA: one bindfs folder is created per user path";
    expr = lib.attrNames cfgA.bindfs.folders;
    expected = [
      "/home/alice/sdaolnwoD"
      "/home/bobby/Notes"
      "/users/a/Passwords"
      "/users/alice/Pictures"
      "/users/b/Passwords"
      "/users/charlie/Public"
    ];
  }
  {
    name = "pcA: activation script creates the physical path";
    expr = lib.elem "mkdir -p /phys" ensureLines;
    expected = true;
  }
  {
    name = "pcA: activation script chowns the physical path to syncthing";
    expr = lib.elem "chown -R syncthing /phys" ensureLines;
    expected = true;
  }
  {
    name = "pcA: activation script chowns the physical path group";
    expr = lib.elem "chown -R :syncthing /phys" ensureLines;
    expected = true;
  }
  {
    name = "pcA: activation script applies permissions";
    expr = lib.elem "chmod -R g+rw /phys" ensureLines;
    expected = true;
  }
  {
    name = "pcA: activation script chowns user folders to their owners";
    expr = lib.elem "chown -R alice /home/alice/sdaolnwoD" ensureLines;
    expected = true;
  }
  {
    name = "pcA: activation script chowns system folders to syncthing";
    expr = lib.elem "chown -R syncthing /phys-mapped/Downloads" ensureLines;
    expected = true;
  }
  {
    name = "pcA: activation script chowns system folders group";
    expr = lib.elem "chown -R :syncthing /phys-mapped/Downloads" ensureLines;
    expected = true;
  }
  {
    name = "serverA: isServer is set for hosts in servers";
    expr = cfgServer.services.syncthing-wrapper.isServer;
    expected = true;
  }
  {
    name = "serverA: bindfs is disabled on a server host";
    expr = cfgServer.bindfs.enable;
    expected = false;
  }
  {
    name = "serverA: all folders shared on the server are present";
    expr = lib.attrNames cfgServer.services.syncthing.settings.folders;
    expected = [
      "Passwords"
      "alice__Downloads"
      "bob__Documents"
      "bob__Notes"
    ];
  }
  {
    name = "serverA: folder devices exclude the host itself";
    expr = cfgServer.services.syncthing.settings.folders."bob__Documents".devices;
    expected = [
      "pcB"
      "tabula"
    ];
  }
  {
    name = "serverA: devices are inferred across all folders";
    expr = lib.attrNames cfgServer.services.syncthing.settings.devices;
    expected = [
      "mobile"
      "pcA"
      "pcB"
      "tabula"
    ];
  }
]
