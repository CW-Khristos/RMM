on error resume next
''DEFINE VARIABLES
dim objWSH, objFSO, objSAG, colFIL, objFIL
dim errRET, lngSIZ, retDEL, strDLM, intDIFF
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
if (wscript.arguments.count > 0) then          ''ARGUMENTS WERE PASSED
  for x = 0 to (wscript.arguments.count - 1)
    objOUT.write vbnewline & now & vbtab & "ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
  next 
  ''ARGUMENT 0 - FOLDER PATH
  strFOL = objARG.item(0)
  ''ARGUMENT 1 (OPTIONAL) - TARGET FILE AGE / DATE LAST MODIFIED
  if (wscript.arguments.count > 1) then
    intAGE = objARG.item(1)
  end if
else                                           ''NO ARGUMENTS PASSED, END SCRIPT
    objOUT.write vbnewline & now & vbtab & "SCRIPT REQUIRES PATH TO LOCAL SAGE / PEACHTREE BACKUP DESTINATION"
    call CLEANUP
end if
''RETRIEVE SAGE / PEACHTREE BACKUPSET FOLDER
set objSAG = objFSO.getfolder(strFOL)
''CHECK THROUGH ALL SUB-FOLDERS IN SAGE / PEACHTREE BACKUPSET FOLDER
''THIS NEEDS TO BE THE COMPLETE PATH THAT SAGE / PEACHTREE BACKUPS WRITE TO I.E. "C:\Sage\Peachtree\SageAutoBackups"
set colFOL = objSAG.subfolders
for each objFOL in colFOL                      ''ENUMERATE EACH SUB-FOLDER
  ''CHECK THROUGH ALL FILES IN SAGE / PEACHTREE BACKUPSET FOLDER
  set colFIL = objFOL.files
  for each objFIL in colFIL                    ''ENUMERATE EACH FILE
    ''DEFAULT FAIL
    retDEL = 1
    if (intAGE = vbnullstring) then            ''CUSTOM AGE ARGUMENT NOT PASSED, SET "DATE" RETENTION
      intAGE = 15
    end if
    ''RETRIEVE FILE LAST DATE MODIFIED
    strDLM = objFIL.datelastmodified
    ''CALCULATE DATE DIFFERENCE (BY VALUE "D"AYS)
    intDIFF = -(datediff("d", Now(), strDLM))
    if (intDIFF >= cint(intAGE)) then          ''FILE HAS NOT BEEN MODIFIED IN TARGET AGE
      filSIZ = round((objFIL.size / 1024), 2)		 ''RECORD FILESIZE (KB)
      objOUT.write vbnewline & vbnewline & objFIL.path & "\" & objFIL.name
      objOUT.write vbnewline & vbtab & "LAST MODIFIED : " & objFIL.DateLastModified
      ''DELETE FOLDER, INCLUDING CONTENT
	  retDEL = objFSO.deletefile(objFIL, true)
      if (retDEL = 0) then						   ''NO ERRO RETURNED
        lngSIZ = (lngSIZ + filSIZ)				   ''INCREMENT TOTAL FILESIZE (KB)
		objOUT.write vbnewline & vbtab & "DELETED : " & objFIL.path & "\" & objFIL.name
	  elseif (retDEL <> 0) then                    ''ERROR RETURNED
        errRET = retDEL
        objOUT.write vbnewline & vbtab & Now() & " : ERROR DELETING : " & objFIL.path & "\" & objFIL.name
      end if
    else                                       ''FILE HAS BEEN MODIFIED MORE RECENT THAN TARGET AGE
      retDEL = 0
    end if
  next
next
''END SCRIPT
call CLEANUP

''SUB-ROUTINES
sub CLEANUP()                                  ''SCRIPT CLEANUP
  if (errRET = 0) then                         ''NO ERROR RETURNED
    err.clear
	lngSIZ = round((lngSIZ / 1024),2)		 ''TOTAL FILESIZE MB CONVERSION
	lngSIZ = round((lngSIZ / 1024),2)		 ''TOTAL FILESIZE GB CONVERSION
    wscript.stdout.write vbnewline & vbtab & "ROTATE SAGE / PEACHTREE BACKUPSET : COMPLETE :  CLEARED : " & lngSIZ & "GB : " & Now()
  elseif (errRET <> 0) then                    ''ERROR RETURNED
    objOUT.write vbnewline & vbtab & "ROTATE SAGE / PEACHTREE BACKUPSET : ERROR : " & Now()
    ''RAISE CUSTOMIZED ERROR CODE, ERROR CODE WILL BE DEFINE RESTOP NUMBER INDICATING WHICH SECTION FAILED
    call err.raise(vbObjectError + errRET,"ROTATE SAGE / PEACHTREE BACKUPSET", "FAIL")
  end if
  ''EMPTY OBJECTS
  set objFIL = nothing
  set colFIL = nothing
  set objSAG = nothing
  set objFSO = nothing
  set objWSH = nothing
  ''END SCRIPT, RETURN ERROR
  wscript.quit err.number
end sub