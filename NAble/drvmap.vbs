'on error resume next
''SCRIPT VARIABLES
dim strDRV, strUNC, strUSR, strPWD
dim objIN, objOUT, objARG, objWSH, objFSO, objHOOK, objLOG
''STDIN / STDOUT
set objIN = wscript.stdin
set objOUT = wscript.stdout
set objARG = wscript.arguments
''OBJECTS FOR LOCATING FOLDERS
set objWSH = createobject("wscript.shell")
set objFSO = createobject("scripting.filesystemobject")
''PREPARE LOGFILE
if (objFSO.fileexists("C:\temp\drvmap_output")) then     ''LOGFILE EXISTS
  objFSO.deletefile "C:\temp\drvmap_output", true
  set objLOG = objFSO.createtextfile("C:\temp\drvmap_output")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\drvmap_output", 8)
else                                            ''LOGFILE NEEDS TO BE CREATED
  set objLOG = objFSO.createtextfile("C:\temp\drvmap_output")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\drvmap_output", 8)
end if
''READ PASSED COMMANDLINE ARGUMENTS
if (wscript.arguments.count > 0) then           ''ARGUMENTS WERE PASSED
  for x = 0 to (wscript.arguments.count - 1)
    objOUT.write vbnewline & now & vbtab & "ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & objARG.item(x)
    objLOG.write vbnewline & now & vbtab & "ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & objARG.item(x)
  next
  ''SET TARGET DRIVE LETTER
  strDRV = objARG.item(0)
  if (instr(1, strDRV, ":") = 0) then
    strDRV = strDRV & ":"
  end if
  ''SET NETWORK PATH AND CREDENTIALS
  if (wscript.arguments.count >= 2) then
    strUNC = objARG.item(1)
    strPWD = objARG.item(2)
    strUSR = objARG.item(3)
  else                                          ''NOT ENOUGH ARGUMENTS PASSED, END SCRIPT
    objOUT.write vbnewline & now & vbtab & "SCRIPT REQUIRES PATH TO NETWORK SHARE OR CREDENTIALS!"
    objLOG.write vbnewline & now & vbtab & "SCRIPT REQUIRES PATH TO NETWORK SHARE OR CREDENTIALS!"
    call CLEANUP
  end if
else                                            ''NO ARGUMENTS PASSED, END SCRIPT
  objOUT.write vbnewline & now & vbtab & "NO ARGUMENTS PASSED. SCRIPT REQUIRES DRIVE LETTER, PATH TO NETWORK SHARE, AND CREDENTIALS!"
  objLOG.write vbnewline & now & vbtab & "NO ARGUMENTS PASSED. SCRIPT REQUIRES DRIVE LETTER, PATH TO NETWORK SHARE, AND CREDENTIALS!"
  call CLEANUP
end if
objOUT.write vbnewline & now & " - STARTING DRVMAP" & vbnewline
objLOG.write vbnewline & now & " - STARTING DRVMAP" & vbnewline
''START DRVMAP
objOUT.write vbnewline & vbnewline & now & " - MAPPING PASSED DRIVE : " & objARG.item(0) & " - " & objARG.item(1) & vbnewline
objLOG.write vbnewline & vbnewline & now & " - MAPPING PASSED DRIVE : " & objARG.item(0) & " - " & objARG.item(1) & vbnewline
call HOOK("net use " & chr(34) & strDRV & chr(34) & " " & chr(34) & strUNC & chr(34) & " " & chr(34) & strPWD & chr(34) & " /user:" & strUSR & " /PERSISTENT:YES")
''SCRIPT CLEANUP
call CLEANUP()

''SUB-ROUTINES
sub HOOK(strCMD)                                ''CALL HOOK TO MONITOR OUTPUT OF CALLED COMMAND
  on error resume next
  'comspec = objWSH.ExpandEnvironmentStrings("%comspec%")
  set objHOOK = objWSH.exec(strCMD)
  'while (objHOOK.status = 0)
    while (not objHOOK.stdout.atendofstream)
      strIN = objHOOK.stdout.readline
      if (strIN <> vbnullstring) then
        objOUT.write vbnewline & now & vbtab & vbtab & strIN 
        objLOG.write vbnewline & now & vbtab & vbtab & strIN 
      end if
    wend
    wscript.sleep 10
  'wend
  strIN = objHOOK.stdout.readall
  if (strIN <> vbnullstring) then
    objOUT.write vbnewline & now & vbtab & vbtab & strIN 
    objLOG.write vbnewline & now & vbtab & vbtab & strIN 
  end if
  'retSTOP = objHOOK.exitcode
  set objHOOK = nothing
  if (err.number <> 0) then
    objOUT.write vbnewline & now & vbtab & vbtab & err.number & vbtab & err.description
    objLOG.write vbnewline & now & vbtab & vbtab & err.number & vbtab & err.description
  end if
end sub

sub CLEANUP()                                   ''SCRIPT CLEANUP
  objOUT.write vbnewline & vbnewline & now & " - DRVMAP COMPLETE." & vbnewline
  objLOG.write vbnewline & vbnewline & now & " - DRVMAP COMPLETE." & vbnewline
  objLOG.close
  ''EMPTY OBJECTS
  set objLOG = nothing
  set objFSO = nothing
  set objWSH = nothing
  set objARG = nothing
  set objOUT = nothing
  set objIN = nothing
  ''END SCRIPT, RETURN DEFAULT NO ERROR
  wscript.quit err.number
end sub