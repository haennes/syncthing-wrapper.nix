#set page(width: auto, height: auto)
#let invalid = table.cell(fill: red)[]
#let base_foldername ="${basePath}/${folderName}"
#let defgroupdir_group = "${defaultGroupDir}/${group}/${folderName}"
#let defuserdir_user = "${defaultUserDir}/${user}/${folderName}"
#let groupdir = "${groupDir}/${folderName}";
#let userdir = "${userDir}/${folderName}";
#let _01 = invalid
#let _02 = userdir
#let _03 = groupdir
#let _04 = base_foldername
#let _05 = invalid
#let _06 = userdir
#let _07 = defgroupdir_group
#let _08 = base_foldername
#let _09 = invalid
#let _10 = defuserdir_user
#let _11 = groupdir
#let _12 = base_foldername
#let _13 = invalid
#let _14 = defuserdir_user
#let _15 = defgroupdir_group
#let _16 = base_foldername
#table(columns: 6,
 table.cell(colspan: 2)[ ],                              table.cell(colspan: 2)[ user ], table.cell(colspan: 2)[ #overline[user] ],
 table.cell(colspan: 2)[ ],                                                    [group], [#overline[group]],    [group], [#overline[group]],
 table.cell(rowspan: 2)[userDir],            [groupDir],                       _01,     _02,                   _03,     _04,
                                             [#overline[groupDir]],            _05,     _06,                   _07,     _08,
 table.cell(rowspan: 2)[#overline[userDir]], [groupDir],                       _09,     _10,                   _11,     _12,
                                             [#overline[groupDir]],            _13,     _14,                   _15,     _16,
)
