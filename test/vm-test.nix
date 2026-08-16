# NixOS VM test for the syncthing-wrapper module.
#
# Boots a real machine with the example configuration (minus the
# `boot.isContainer` build hack) and asserts that:
#  - the syncthing service starts and derives its device id from the
#    certificate installed via systemd-tmpfiles
#  - the secrets land at the expected runtime paths with the expected
#    ownership/permissions
#  - the generated syncthing config contains the wrapper's folders
#  - the bindfs user-path mounts are in place
{
  nixpkgs,
  bindfs,
  pkgs,
}:
let
  bindfsInput =
    if builtins.isAttrs bindfs then
      bindfs
    else
      {
        nixosModules.default = import "${bindfs}/module.nix";
      };

  module = import ../module.nix {
    inherit nixpkgs;
    bindfs = bindfsInput;
  };

  ids = import ../example/ids.nix;
in
pkgs.testers.runNixOSTest {
  name = "syncthing-wrapper";

  nodes.machine = {
    lib,
    ...
  }: {
    imports = [
      module
      ../example/example.nix
    ];
    # example.nix sets boot.isContainer to speed up local builds, but the VM
    # wants real systemd/boot behaviour so that the bindfs mounts actually
    # get created.
    boot.isContainer = lib.mkForce false;
    boot.kernelModules = [ "fuse" ];
    programs.fuse.enable = true;
    # the example's dataDir=/tmp is a container build hack; with
    # PrivateTmp=true the config would be invisible to the config-updater
    services.syncthing.dataDir = lib.mkForce "/var/lib/syncthing";
    systemd.tmpfiles.rules = [
      "d /var/lib/syncthing 0700 syncthing syncthing -"
    ];
  };

  testScript = ''
    expected_id = "${ids.pcA}"
    config_xml = "/var/lib/syncthing/.config/syncthing/config.xml"

    machine.wait_for_unit("syncthing.service")

    # syncthing's API is listening
    machine.wait_until_succeeds("exec 3<>/dev/tcp/127.0.0.1/8384")

    # secrets are in place, owned by syncthing and not world readable
    machine.succeed("stat -c '%U %G %a' /run/secrets/syncthing/pcA/cert.pem | grep -qx 'syncthing syncthing 400'")
    machine.succeed("stat -c '%U %G %a' /run/secrets/syncthing/pcA/key.pem  | grep -qx 'syncthing syncthing 400'")

    # syncthing derives its own device id from the provided certificate
    machine.wait_until_succeeds(
        f"grep -q '<device id=\"{expected_id}\"' {config_xml}"
    )

    # the wrapper's folders show up in the generated config
    machine.wait_until_succeeds(f"grep -q '/syncs/PasswordsCustom' {config_xml}")
    machine.wait_until_succeeds(f"grep -q '/tmp/syncthing/hannses/DocumentsH' {config_xml}")

    # bindfs mounts user paths on top of the physical paths
    machine.wait_for_unit("local-fs.target")
    machine.succeed("mountpoint -q /tmp/syncusers/a/Passwords")
    machine.succeed("mountpoint -q /tmp/syncusers/b/Passwords")
    machine.succeed("mountpoint -q /tmp/syncusers/c/Passwords")
    machine.succeed("mountpoint -q /tmp/syncusers/hannses/Documents")
  '';
}
