{ lib, ... }:
let
  inherit (lib) attrNames removeAttrs flatten mapAttrsToList;
in
{
  isServer =
    deviceDef: deviceDef ? "-system" && (attrNames (removeAttrs [ "-system" ] deviceDef)) == [ ];

}
