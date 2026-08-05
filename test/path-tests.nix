# Unit tests for the name-parsing and path-resolution logic.
{ harness, fixtures }:
let
  inherit (harness) lib;
  config = harness.evalConfig [ (fixtures.mkHost "pcA") ];
  w = config.services.syncthing-wrapper;
  folderPath = name: user: (w.folders.${name}.path.pcA.${user}).path;
in
[
  {
    name = "idToTargetName maps Alice__Downloads to Downloads";
    expr = w.idToTargetName "Alice__Downloads";
    expected = "Downloads";
  }
  {
    name = "idToTargetName leaves names without separator alone";
    expr = w.idToTargetName "Passwords";
    expected = "Passwords";
  }
  {
    name = "idToOptionalUserName extracts the owner prefix";
    expr = w.idToOptionalUserName "alice__Downloads";
    expected = "alice";
  }
  {
    name = "idToOptionalUserName is null without a prefix";
    expr = w.idToOptionalUserName "Passwords";
    expected = null;
  }
  {
    name = "system path uses physicalPath/folderID by default";
    expr = folderPath "Passwords" "system";
    expected = "/phys/Passwords";
  }
  {
    name = "system path honours DirFolderMap";
    expr = folderPath "alice__Downloads" "system";
    expected = "/phys-mapped/Downloads";
  }
  {
    name = "user path prefers userDirFolderMap";
    expr = folderPath "alice__Downloads" "alice";
    expected = "/home/alice/sdaolnwoD";
  }
  {
    name = "user path falls back to userDirMap";
    expr = folderPath "bob__Notes" "bob";
    expected = "/home/bobby/Notes";
  }
  {
    name = "user path falls back to defaultUserDir";
    expr = folderPath "Passwords" "a";
    expected = "/users/a/Passwords";
  }
  {
    name = "user path falls back to defaultUserDir for a second pseudoGroup member";
    expr = folderPath "Passwords" "b";
    expected = "/users/b/Passwords";
  }
  {
    name = "folder users are expanded from pseudoGroups";
    expr = w.folders.Passwords.users;
    expected = [
      "a"
      "b"
    ];
  }
  {
    name = "folder users include the idToOptionalUserName user";
    expr = w.folders.alice__Downloads.users;
    expected = [ "alice" ];
  }
  {
    name = "explicit folder users are kept as-is";
    expr = w.folders.Public.users;
    expected = [ "charlie" ];
  }
]
