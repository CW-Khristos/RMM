'on error resume next
''DEFINE VARIABLES
dim strSRC, strDST, errRET
dim objIN, objOUT, objARG, objWSH
dim objFSO, objLOG, objSRC, objDST
''DEFAULT FAIL
errRET = 5
''STDIN / STDOUT
set objIN = wscript.stdin
set objOUT = wscript.stdout
set objARG = wscript.arguments
''CREATE OBJECTS
set objWSH = createobject("wscript.shell")
set objFSO = createobject("scripting.filesystemobject")
''CHECK EXECUTION METHOD OF SCRIPT
strIN = lcase(mid(wscript.fullname, instrrev(wscript.fullname, "\") + 1))
if (strIN <> "cscript.exe") Then
  objOUT.write vbnewline & "SCRIPT LAUNCHED VIA EXPLORER, EXECUTING SCRIPT VIA CSCRIPT..."
  objWSH.run "cscript.exe //nologo " & chr(34) & Wscript.ScriptFullName & chr(34)
  wscript.quit
end if
''PREPARE LOGFILE
if (objFSO.fileexists("C:\temp\fileback")) then     							      ''LOGFILE EXISTS
  objFSO.deletefile "C:\temp\fileback", true
  set objLOG = objFSO.createtextfile("C:\temp\fileback")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\fileback", 8)
else                                            										    ''LOGFILE NEEDS TO BE CREATED
  set objLOG = objFSO.createtextfile("C:\temp\fileback")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\fileback", 8)
end if
''READ PASSED COMMANDLINE ARGUMENTS
if (wscript.arguments.count > 0) then        												    ''ARGUMENTS WERE PASSED
  for x = 0 to (wscript.arguments.count - 1)
    objOUT.write vbnewline & now & " - ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
    objLOG.write vbnewline & now & " - ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
  next 
  ''ARGUMENT 0 - SOURCE FOLDER PATH
  strSRC = objARG.item(0)
  ''ARGUMENT 1 - DESTINATION FOLDER PATH
	strDST = objARG.item(1)
end if
if ((wscript.arguments.count = 0) or (strSRC = vbnullstring)) then      ''NO ARGUMENTS PASSED, END SCRIPT
  objOUT.write vbnewline & now & " - SCRIPT REQUIRES PATH TO SOURCE FOLDER"
  objLOG.write vbnewline & now & " - SCRIPT REQUIRES PATH TO SOURCE FOLDER"
elseif ((wscript.arguments.count = 1) or (strDST = vbnullstring)) then  ''NOT ENOUGH ARGUMENTS PASSED, END SCRIPT
  objOUT.write vbnewline & now & " - SCRIPT REQUIRES PATH TO DESTINATION FOLDER"
  objLOG.write vbnewline & now & " - SCRIPT REQUIRES PATH TO DESTINATION FOLDER"
end if
objOUT.write vbnewline & vbnewline & now & " - RUNNING FILEBACK : " & strSRC & " : " & strDST
objLOG.write vbnewline & vbnewline & now & " - RUNNING FILEBACK : " & strSRC & " : " & strDST
''CHECK SOURCE FOLDER EXISTS
objOUT.write vbnewline & vbnewline & now & " - CHECKING SOURCE FOLDER : " & strSRC & " : "
objLOG.write vbnewline & vbnewline & now & " - CHECKING SOURCE FOLDER : " & strSRC & " : "
if (objFSO.folderexists(strSRC)) then                                   ''SOURCE FOLDER EXISTS
  objOUT.write "SUCCESS"
  objLOG.write "SUCCESS"
  ''CHECK DESTINATION FOLDER EXISTS
  objOUT.write vbnewline & vbnewline & now & " - CHECKING DESTINATION FOLDER : " & strDST & " : "
  objLOG.write vbnewline & vbnewline & now & " - CHECKING DESTINATION FOLDER : " & strDST & " : "
  if (objFSO.folderexists(strDST)) then                                 ''DESTINATION FOLDER EXISTS
    objOUT.write "SUCCESS"
    objLOG.write "SUCCESS"
    ''COPY CONTENTS TO "DAY" FOLDERS
    objOUT.write vbnewline & vbnewline & now & " - COPYING SOURCE TO DESTINATION : "
    objLOG.write vbnewline & vbnewline & now & " - COPYING SOURCE TO DESTINATION : "
    strDATE = date()
    strDAY = datepart("w", strDATE)
    set objSRC = objFSO.getfolder(strSRC)
    set objDST = objFSO.getfolder(strDST)
    select case strDAY
        case 1 ''SUNDAY
          errRET = objFSO.copyfolder(objSRC.path, objDST.path & "\Sunday\", true)
        case 2 ''MONDAY
          errRET = objFSO.copyfolder(objSRC.path, objDST.path & "\Monday\", true)
        case 3 ''TUESDAY
          errRET = objFSO.copyfolder(objSRC.path, objDST.path & "\Tuesday\", true)
        case 4 ''WEDNESDAY
          errRET = objFSO.copyfolder(objSRC.path, objDST.path & "\Wednesday\", true)
        case 5 ''THURSDAY
          errRET = objFSO.copyfolder(objSRC.path, objDST.path & "\Thursday\", true)
        case 6 ''FRIDAY
          errRET = objFSO.copyfolder(objSRC.path, objDST.path & "\Friday\", true)
        case 7 ''SATURDAY
          errRET = objFSO.copyfolder(objSRC.path, objDST.path & "\Saturday\", true)
    end select
    if (errRET = 0) then                                                ''NO ERROR DURING COPY
      errRET = 0
      objOUT.write "SUCCESS"
      objLOG.write "SUCCESS"
    elseif (errRET <> 0) then                                           ''ERROR DURING COPY
      errRET = 3
      objOUT.write "FAILED"
      objLOG.write "FAILED"
    end if
  else                                                                  ''DESTINATION FOLDER DOES NOT EXIST
    errRET = 2
    objOUT.write "FAILED"
    objLOG.write "FAILED"
  end if
else                                                                    ''SOURCE FOLDER DOES NOT EXIST
  errRET = 1
  objOUT.write "FAILED"
  objLOG.write "FAILED"
end if
''END SCRIPT
call CLEANUP()

''SUB-ROUTINES
sub CLEANUP()                                												    ''SCRIPT CLEANUP
  if (errRET = 0) then                       												    ''NO ERROR RETURNED
    objOUT.write vbnewline & vbnewline & now & " - FILEBACK : COMPLETE : SUCCESS"
    objLOG.write vbnewline & vbnewline & now & " - FILEBACK : COMPLETE : SUCCESS"
    err.clear
  elseif (errRET <> 0) then                  												    ''ERROR RETURNED
    objOUT.write vbnewline & vbnewline & now & " - FILEBACK : COMPLETE : ERROR"
    objLOG.write vbnewline & vbnewline & now & " - FILEBACK : COMPLETE : ERROR"
    ''RAISE CUSTOMIZED ERROR CODE, ERROR CODE WILL BE DEFINE ERRRET NUMBER INDICATING WHICH SECTION FAILED
    call err.raise(vbObjectError + errRET, "FILEBACK", "FAIL")
  end if
  ''EMPTY OBJECTS
  set objFOL = nothing
  set colFOL = nothing
  set objMSP = nothing
  SET objLOG = nothing
  set objFSO = nothing
  set objWSH = nothing
  set objARG = nothing
  set objOUT = nothing
  set objIN = nothing
  ''END SCRIPT, RETURN ERROR
  wscript.quit err.number
end sub