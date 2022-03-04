''!!! RUN SCRIPT WITH RENAMING COMMANDS COMMENTED OUT FIRST AND CHECK 'C:\PERCENT_RENAME.TXT' !!!''
''!!! USE CAUTION WHEN USING SCRIPT TO CHECK THE 'ROOT' DRIVE, THIS CAN CAUSE CRITICAL SYSTEM FILES TO BE RENAMED !!!''

'on error resume next
dim objWSH, objFSO, objLOG, objFOL, strFOL

set objWSH = createobject("wscript.shell")
set objFSO = createobject("scripting.filesystemobject")

if objFSO.fileexists("C:\percent_rename.txt") then
  set objLOG = objFSO.opentextfile("C:\percent_rename.txt", 8)
else
  set objLOG = objFSO.createtextfile("C:\percent_rename.txt")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\percent_rename.txt", 8)
end if

''!!! GETFOLDER DIRECTORY CAN BE CHANGED TO CHECK ANY DIRECTORY
''!!! SCRIPT WILL CHECK ALL SUB FOLDERS RECURSIVELY
strFOL = "C:\testthis"
set objFOL = objFSO.getfolder(strFOL)
call ProcessSubFolders(objFOL)

objLOG.close
set objLOG = nothing
set objFSO = nothing
set objWSH = nothing
wscript.quit


sub ProcessSubFolders (ByVal sfolder)
  'on error resume next
  if instr(1, sfolder.name, "%") then
    Dim strNEW

    strNEW = replace(sfolder.path, "%", "percent")
    wscript.echo "RENAMING DIRECTORY TO : " & strNEW
    objFSO.MoveFolder sfolder.path, strNEW
    set objFOL = objFSO.getfolder(strFOL)
    call ProcessSubFolders(objFOL)
    exit sub
  end if

  Dim Folder
  Dim Folders: Set Folders = sfolder.SubFolders

  call ProcessFolder(sfolder)

  for each Folder in Folders
    call ProcessSubFolders(Folder)
  next
end sub 


sub ProcessFolder (ByVal Folder)
  'on error resume next
  Dim File
  Dim Files: Set Files = Folder.Files

  for each File in Files
    ''CHECK FOR '%20', URI ENCODING FOR A SPACE''
    if instr(1, File.Name, "%20") > 0 then
      'objLOG.writeline file.path
      wscript.echo "RENAMING FILE TO : " & replace(File.Path, "%20" , " ")

      ''!!! UNCOMMENT THE LINE BELOW TO RENAME FILES !!!''
      File.move replace(File.Path, "%20", " ")
    end if

    ''CHECK FOR ANY '%' CHARACTER''
    if instr(1, File.Name, "%") > 0 then
      'objLOG.writeline file.path
      wscript.echo "RENAMING FILE TO : " & replace(File.Path, "%" , "percent")

      ''!!! UNCOMMENT THE LINE BELOW TO RENAME FILES !!!''
      File.move replace(File.Path, "%", "percent")
    end if
  next
end sub