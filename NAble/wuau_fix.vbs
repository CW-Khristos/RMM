''SCRIPT VARIABLES
dim objIN, objOUT, objWSH, objFSO, objHOOK, objLOG, strIN
''STDIN / STDOUT
set objIN = wscript.stdin
set objOUT = wscript.stdout
''OBJECTS FOR LOCATING FOLDERS
set objWSH = createobject("wscript.shell")
set objFSO = createobject("scripting.filesystemobject")
''PREPARE LOGFILE
if (objFSO.fileexists("C:\wu_output")) then     ''LOGFILE EXISTS
  objFSO.deletefile "C:\wu_output", true
  set objLOG = objFSO.createtextfile("C:\wu_output")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\wu_output", 8)
else                                            ''LOGFILE NEEDS TO BE CREATED
  set objLOG = objFSO.createtextfile("C:\wu_output")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\wu_output", 8)
end if
objOUT.write vbnewline & now & " - STARTING WUAU_FIX" & vbnewline
objLOG.write vbnewline & now & " - STARTING WUAU_FIX" & vbnewline
''START WUAUSERV
objOUT.write vbnewline & vbnewline & now & " - STARTING WUAUSERV" & vbnewline
objLOG.write vbnewline & vbnewline & now & " - STARTING WUAUSERV" & vbnewline
call HOOK("sc start wuauserv")
''QUERY TRIGGERINFO
objOUT.write vbnewline & vbnewline & now & " - CHECKING WUAUSERV TRIGGERS" & vbnewline
objLOG.write vbnewline & vbnewline & now & " - CHECKING WUAUSERV TRIGGERS" & vbnewline
call HOOK("sc qtriggerinfo wuauserv")
''REMOVE SERVICE TRIGGERS
objOUT.write vbnewline & vbnewline & now & " - REMOVING WUAUSERV TRIGGERS" & vbnewline
objLOG.write vbnewline & vbnewline & now & " - REMOVING WUAUSERV TRIGGERS" & vbnewline
call HOOK("sc triggerinfo wuauserv delete")
''SET SERVICE AS OWN PROCESS
objOUT.write vbnewline & vbnewline & now & " - SETTING WUAUSERV AS OWN PROCESS" & vbnewline
objLOG.write vbnewline & vbnewline & now & " - SETTING WUAUSERV AS OWN PROCESS" & vbnewline
call HOOK("sc config wuauserv type= own start= auto")
''SCRIPT CLEANUP
call CLEANUP

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
  end if
end sub

sub CLEANUP()                                   ''SCRIPT CLEANUP
  objOUT.write vbnewline & vbnewline & now & " - WUAU_FIX COMPLETE." & vbnewline
  objLOG.write vbnewline & vbnewline & now & " - WUAU_FIX COMPLETE." & vbnewline
  objLOG.close
  ''EMPTY OBJECTS
  set objLOG = nothing
  set objFSO = nothing
  set objWSH = nothing
  set objOUT = nothing
  set objIN = nothing
  ''END SCRIPT, RETURN DEFAULT NO ERROR
  wscript.quit 0
end sub
