#import "@preview/cheq:0.2.0": checklist

#show link: underline
#show link: set text(blue)
#show: checklist

= New structure
- enable
- enableHM: enable setting hm module options, if hm declared for user
- createHM: create hm for user, if it doesnt exist
- pathFunc: {hostname, user ? null, group ? null, folder_name, base_path, wrapper-config} -> path
- groups attrsOf listOf str
- groupDir:
  Directory where shared folders should go #sym.arrow \${groupDir}/\${groupName}/\${folderName}
- secrets
  - keyFunction: {hostname, user ? null, group ? null} -> path
  - certFunction: {hostname, user ? null, group ? null} -> path
  - upstream opts
- folders.\<name\>
  - user (=group)
    - null: system-service
    - hm_user
  - group (=null)
  - devices:
    - key: device hostname
    - value:
      - key: \$\{user\} bzw "-system"
      - value: device definition ( \{id = ...\}...)
  - settings (upsream opts) (freeform type) (directly sets the entire upstream option)


= Note
- is server #sym.arrow.double.l.r folders.devices.value only contains "-system" key

= groups and users
- each group used shall be declared in groups
  - groups.grn1.users = ["arbitraty" "usernames"];
  - for group folders: check if user is in group then should have the folder in his hm config
