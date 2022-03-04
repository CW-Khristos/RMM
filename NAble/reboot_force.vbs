''REBOOT_FORCE.VBS
''DESIGNED TO FORCE REBOOT USING SHUTDOWN COMMAND
''ACCEPTS PARAMETERS FOR CUSTOMIZING SHUTDOWN / REBOOT OPTIONS
''WRITTEN BY : CJ BLEDSOE / CJ<@>THECOMPUTERWARRIORS.COM
on error resume next
''ALWAYS RIGHT-CLICK SCRIPT, CHOOSE "PROPERTIES", CLICK "UNBLOCK"
''SCRIPT VARIABLES
dim strMOD, strDLY, strCMT, strRUN
dim objIN, objOUT, objARG, objWSH, objFSO, objLOG, objHOOK
''STDIN / STDOUT
set objIN = wscript.stdin
set objOUT = wscript.stdout
set objARG = wscript.arguments
''OBJECTS FOR LOCATING FOLDERS
set objWSH = createobject("wscript.shell")
set objFSO = createobject("scripting.filesystemobject")
''PREPARE LOGFILE
if (objFSO.fileexists("C:\temp\reboot_force")) then       ''LOGFILE EXISTS
  objFSO.deletefile "C:\temp\reboot_force", true
  set objLOG = objFSO.createtextfile("C:\temp\reboot_force")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\reboot_force", 8)
else                                                        ''LOGFILE NEEDS TO BE CREATED
  set objLOG = objFSO.createtextfile("C:\temp\reboot_force")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\reboot_force", 8)
end if
''READ PASSED COMMANDLINE ARGUMENTS - REQUIRES (AT LEAST) 2 ARGUMENTS
if (wscript.arguments.count > 0) then                 ''ARGUMENTS WERE PASSED
  for x = 0 to (wscript.arguments.count - 1)
    objOUT.write vbnewline & now & vbtab & "ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
    objLOG.write vbnewline & now & vbtab & "ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
  next
  ''SCRIPT MODE OF OPERATION
  strMOD = objARG.item(0)
  if (wscript.arguments.count > 3) then
    strRUN = objARG.item(1)
    strDLY = objARG.item(2)
    strCMT = objARG.item(3)
  else
    ''END SCRIPT
    call CLEANUP()
  end if
else
  objOUT.write vbnewline & vbnewline & now & " - NOT ENOUGH ARGUMENTS PASSED" & vbnewline
  objLOG.write vbnewline & vbnewline & now & " - NOT ENOUGH ARGUMENTS PASSED" & vbnewline
  ''RAISE CUSTOMIZED ERROR CODE, ERROR CODE WILL BE DEFINE RESTOP NUMBER INDICATING WHICH SECTION FAILED
  call err.raise(vbObjectError + 1, "REBOOT_FORCE", "NOT ENOUGH ARGUMENTS")
  ''END SCRIPT
  call CLEANUP()
end if
''SET EXECUTION FLAG
if (lcase(strRUN) <> "true") then
  strRUN = "false"
end if
''EXECUTE REBOOT_FORCE
objOUT.write vbnewline & vbnewline & now & " - STARTING REBOOT_FORCE" & vbnewline
objLOG.write vbnewline & vbnewline & now & " - STARTING REBOOT_FORCE" & vbnewline

''EXECUTE FORCED SHUTDOWN
if (strRUN = "true") then
  objOUT.write vbnewline & vbnewline & now & vbtab & " - EXECUTING SHUTDOWN"
  objLOG.write vbnewline & vbnewline & now & vbtab & " - EXECUTING SHUTDOWN"
  if (strCMT = vbnullstring) then
    strCMT = "This is a message from your Administrators, your system has been scheduled for a required reboot to maintain stability." & vbnewline & _
      "Please save all work and close all programs prior to the scheduled reboot time."
  end if
  call HOOK("shutdown -" & strMOD & " -t " & strDLY & " -c " & chr(34) & strCMT & chr(34))
end if
''END SCRIPT
call CLEANUP()

''SUB-ROUTINES
sub HOOK(strCMD)                                            ''CALL HOOK TO MONITOR OUTPUT OF CALLED COMMAND
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

sub CLEANUP()                                               ''SCRIPT CLEANUP
  objOUT.write vbnewline & vbnewline & now & " - REBOOT_FORCE COMPLETE" & vbnewline
  objLOG.write vbnewline & vbnewline & now & " - REBOOT_FORCE COMPLETE" & vbnewline
  objLOG.close
  ''EMPTY OBJECTS
  set objLOG = nothing
  set objFSO = nothing
  set objWSH = nothing
  set objARG = nothing
  set objOUT = nothing
  set objIN = nothing
  ''END SCRIPT, RETURN ERROR NUMBER
  wscript.quit err.number
end sub