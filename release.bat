@echo off

rmdir "release\wand_dbg" /s

mkdir "release\wand_dbg"
mkdir "release\wand_dbg\files"

xcopy /s "files" "release\wand_dbg\files"

xcopy "init.lua" "release\wand_dbg\"
xcopy "compatibility.lua" "release\wand_dbg\"
xcopy "mod.xml" "release\wand_dbg\"
xcopy "mod_id.txt" "release\wand_dbg\"

pushd "release"
7z a -r "wand_dbg_"%1".zip" "wand_dbg\"

gh release create %1 -t %1 "wand_dbg_"%1".zip" -n %2
popd

pushd "..\..\"
noita_dev.exe -workshop_upload wand_dbg -workshop_upload_change_notes %2
popd
