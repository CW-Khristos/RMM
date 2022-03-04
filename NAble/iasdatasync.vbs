''SCRIPT VARIABLES
dim objIN, objOUT, objWSH, objFSO, objLOG, strCMD
''STDIN / STDOUT
set objIN = wscript.stdin
set objOUT = wscript.stdout
''CREATE SCRIPTING OBJECTS
set objWSH = createobject("wscript.shell")
set objFSO = createobject("scripting.filesystemobject")
''IASDATASYC COMMAND
strCMD = chr(34) & "c:\Program Files (x86)\IAS DataSync\DataAcquisitionRemote.exe" & chr(34) & " " & chr(34) & "runmode=4" & chr(34)
''PREPARE LOGFILE
if (objFSO.fileexists("c:\Program Files (x86)\IAS DataSync\execution.log")) then              ''LOGFILE EXISTS
  objFSO.deletefile "c:\Program Files (x86)\IAS DataSync\execution.log", true
  set objLOG = objFSO.createtextfile("c:\Program Files (x86)\IAS DataSync\execution.log")
  objLOG.close
  set objLOG = objFSO.opentextfile("c:\Program Files (x86)\IAS DataSync\execution.log", 8)
else                                                                                          ''LOGFILE NEEDS TO BE CREATED
  set objLOG = objFSO.createtextfile("c:\Program Files (x86)\IAS DataSync\execution.log")
  objLOG.close
  set objLOG = objFSO.opentextfile("c:\Program Files (x86)\IAS DataSync\execution.log", 8)
end if
''IASDATASYNC EXECUTION
objLOG.write vbnewline & now & " - RUNNING : " & strCMD
objWSH.run "cmd.exe /C " & chr(34) & strCMD & chr(34), 0, true
objLOG.write vbnewline & now & " - COMPLETE : " & strCMD
''SCRIPT CLEANUP
objLOG.close
set objLOG = nothing
set objFSO = nothing
set objWSH = nothing