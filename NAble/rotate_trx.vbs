on error resume next
''DEFINE VARIABLES
dim errRET, lngSIZ, retDEL, strDLM, intDIFF
dim objIN, objOUT, objARG, objWSH, objFSO, objTRX, colFOL, objFOL
''DEFAULT SUCCESS
errRET = 0
''FILESIZE COUNTER
lngSIZ = 0
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
''READ PASSED COMMANDLINE ARGUMENTS
if (wscript.arguments.count > 0) then        ''ARGUMENTS WERE PASSED
  for x = 0 to (wscript.arguments.count - 1)
    objOUT.write vbnewline & now & vbtab & "ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
  next 
  ''ARGUMENT 0 - FOLDER PATH
  strIN = objARG.item(0)
  ''ARGUMENT 1 (OPTIONAL) - TARGET FILE AGE / DATE LAST MODIFIED
  if (wscript.arguments.count > 1) then
    intAGE = objARG.item(1)
  end if
else                                         ''NO ARGUMENTS PASSED, END SCRIPT
  objOUT.write vbnewline & now & vbtab & "SCRIPT REQUIRES PATH TO LOCAL TRX BACKUP DESTINATION"
  call CLEANUP
end if
''RETRIEVE TRX BACKUPSET FOLDER
set objTRX = objFSO.getfolder(strIN)
''CHECK THROUGH ALL SUB-FOLDERS IN TRX BACKUPSET FOLDER
''THIS NEEDS TO BE THE COMPLETE PATH THAT TRX BACKUPS WRITE TO I.E. "D:\app\Administrator\flash_recovery_area\trx\BACKUPSET"
set colFOL = objTRX.subfolders
for each objFOL in colFOL                    ''ENUMERATE EACH SUB-FOLDER
  ''DEFAULT FAIL
  retDEL = 1
  if (intAGE = vbnullstring) then            ''CUSTOM AGE ARGUMENT NOT PASSED, SET "DATE" RETENTION
    intAGE = 30
  end if
  ''RETRIEVE SUB-FOLDER LAST DATE MODIFIED
  strDLM = objFOL.datelastmodified
  ''CALCULATE DATE DIFFERENCE (BY VALUE "D"AYS)
  if (intDIFF > cint(intAGE)) then           ''FOLDER HAS NOT BEEN MODIFIED IN TARGET AGE
    filSIZ = round((objFOL.size / 1024), 2)		 ''RECORD FOLDERSIZE (KB)
    objOUT.write vbnewline & vbnewline & objFOL.path
    objOUT.write vbnewline & vbtab & "LAST MODIFIED : " & objFOL.DateLastModified
    ''DELETE FOLDER, INCLUDING CONTENT
    retDEL = objFSO.deletefolder(objFOL.path, true)
    if (retDEL = 0) then						 ''NO ERROR RETURNED
	  lngSIZ = (lngSIZ + filSIZ)				 ''INCREMENT TOTAL FOLDERSIZE (KB)
      objOUT.write vbnewline & vbtab & "DELETED : " & objFOL.path
	elseif (retDEL <> 0) then                    ''ERROR RETURNED
      errRET = retDEL
      objOUT.write vbnewline & vbtab & Now() & " : ERROR DELETING : " & objFOL.path
    end if
  else                                       ''FOLDER HAS BEEN MODIFIED MORE RECENT THAN TARGET AGE
    retDEL = 0
  end if
next
''END SCRIPT
call CLEANUP

''SUB-ROUTINES
sub CLEANUP()                                ''SCRIPT CLEANUP
  if (errRET = 0) then                       ''NO ERROR RETURNED
    err.clear
	lngSIZ = round((lngSIZ / 1024),2)		 ''TOTAL FOLDERSIZE MB CONVERSION
	lngSIZ = round((lngSIZ / 1024),2)		 ''TOTAL FOLDERSIZE GB CONVERSION
    objOUT.write vbnewline & vbtab & "ROTATE TRX BACKUPSET : COMPLETE :  CLEARED : " & lngSIZ & "GB : " & Now()
  elseif (errRET <> 0) then                  ''ERROR RETURNED
    objOUT.write vbnewline & vbtab & "ROTATE TRX BACKUPSET : ERROR : " & Now()
    ''RAISE CUSTOMIZED ERROR CODE, ERROR CODE WILL BE DEFINE RESTOP NUMBER INDICATING WHICH SECTION FAILED
    call err.raise(vbObjectError + errRET,"ROTATE TRX BACKUPSET", "FAIL")
  end if
  ''EMPTY OBJECTS
  set objFOL = nothing
  set colFOL = nothing
  set objTRX = nothing
  set objFSO = nothing
  set objWSH = nothing
  ''END SCRIPT, RETURN ERROR
  wscript.quit err.number
end sub