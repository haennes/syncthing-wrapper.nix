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

  nodes.machine = { lib, ... }: {
    imports = [
      module
      ../example/example.nix
    ];
    # example.nix sets boot.isContainer to speed up local builds, but the VM
    # wants real systemd/boot behaviour so that the bindfs mounts actually
    # get created.
    boot.isContainer = lib.mkForce false;
    boot.kernelModules = [ "fuse" ];
    services.fuse.enable = true;
  };

  testScript = ''
    expected_id = "${ids.pcA}"

    machine.wait_for_unit("syncthing.service")
    machine.wait_until_succeeds("test -S /run/syncthing/syncthing.sock")

    # secrets are in place, owned by syncthing and not world readable
    machine.succeed("stat -c '%U %G %a' /run/secrets/syncthing/pcA/cert.pem | grep -qx 'syncthing syncthing 400'")
    machine.succeed("stat -c '%U %G %a' /run/secrets/syncthing/pcA/key.pem  | grep -qx 'syncthing syncthing 400'")

    # syncthing derives its own device id from the provided certificate
    machine.wait_until_succeeds(
        f"grep -q '<device id=\"{expected_id}\"' /var/lib/syncthing/config.xml"
    )

    # the wrapper's folders show up in the generated config
    machine.wait_until_succeeds("grep -q '/syncs/PasswordsCustom' /var/lib/syncthing/config.xml")
    machine.wait_until_succeeds("grep -q '/tmp/syncthing/hannses/DocumentsH' /var/lib/syncthing/config.xml")

    # bindfs mounts user paths on top of the physical paths
    machine.wait_for_unit("local-fs.target")
    machine.succeed("mountpoint -q /tmp/syncthing/a/Passwords")
    machine.succeed("mountpoint -q /tmp/syncthing/b/Passwords")
    machine.succeed("mountpoint -q /tmp/syncthing/c/Passwords")
    machine.succeed("mountpoint -q /tmp/syncthing/hannses/DocumentsH")
  '';
}
