'on error resume next
''DEFINE VARIABLES
dim colDISK, objDISK
dim errRET, strCOMP, strCST, strDEV, strIN
dim objIN, objOUT, objWSH, objWMI, objREF, objFSO, objLOG
''DEFAULT SUCCESS
errRET = 0
''STDIN / STDOUT
set objIN = wscript.stdin
set objOUT = wscript.stdout
''CREATE OBJECTS
strCOMP = "."
set objWSH = createobject("wscript.shell")
Set objWMI = GetObject("winmgmts:" & "{impersonationLevel=impersonate}!\\" & strCOMP & "\root\cimv2")
set objREF = CreateObject("WbemScripting.SWbemRefresher")
set objFSO = createobject("scripting.filesystemobject")
''CHECK EXECUTION METHOD OF SCRIPT
strIN = lcase(mid(wscript.fullname, instrrev(wscript.fullname, "\") + 1))
if (strIN <> "cscript.exe") Then
  'objOUT.write vbnewline & "SCRIPT LAUNCHED VIA EXPLORER, EXECUTING SCRIPT VIA CSCRIPT..."
  objWSH.run "cscript.exe //nologo " & chr(34) & Wscript.ScriptFullName & chr(34)
  wscript.quit
end if
strIN = vbnullstring
''SCRIPT CONFIGURATION
objOUT.write vbnewline & "PLEASE ENTER CUSTOMER NAME : "
strCST = objIN.readline
objOUT.write vbnewline & "PLEASE ENTER DEVICE NAME : "
strDEV = objIN.readline
''CREATE LOGFILE FOR OUTPUT
if (objFSO.fileexists(".\" & strCST & "_" & strDEV & "_sysnfo.txt")) then  ''LOGFILE EXISTS
  objFSO.deletefile "cclutter.txt", true
  set objLOG = objFSO.createtextfile(".\" & strCST & "_" & strDEV & "_sysnfo.txt")
  objLOG.close
  set objLOG = objFSO.opentextfile(".\" & strCST & "_" & strDEV & "_sysnfo.txt", 8)
else                                                                        ''LOGFILE NEEDS TO BE CREATED
  set objLOG = objFSO.createtextfile(".\" & strCST & "_" & strDEV & "_sysnfo.txt")
  objLOG.close
  set objLOG = objFSO.opentextfile(".\" & strCST & "_" & strDEV & "_sysnfo.txt", 8)
end if
err.clear
''ENUMERATE SYSTEM INFORMATION
objOUT.write vbnewline & "ENUMERATING SYSTEM INFORMATION : " & now
objLOG.write vbnewline & "ENUMERATING SYSTEM INFORMATION : " & now
call HOOK("wmic bios get serialnumber")
call HOOK("systeminfo")
objOUT.write vbnewline & "COMPLETED ENUMERATING SYSTEM INFORMATION : " & now
objLOG.write vbnewline & "COMPLETED ENUMERATING SYSTEM INFORMATION : " & now
''QUERY DISK INFORMATION
Set colDISK = objREF.AddEnum (objWMI, "win32_logicaldisk").objectSet
objREF.Refresh
''ENUMERATE DISK INFORMATION
objOUT.write vbnewline & vbnewline & "ENUMERATING DISK INFORMATION : " & now
objLOG.write vbnewline & vbnewline & "ENUMERATING DISK INFORMATION : " & now
For Each objDISK in colDISK                                                 ''ENUMERATE EACH DISK LAYOUT
  objOUT.write vbnewline & vbnewline & vbtab & "ENUMERATING DISK LAYOUT : " & now
  objLOG.write vbnewline & vbnewline & vbtab & "ENUMERATING DISK LAYOUT : " & now
  objOUT.write vbnewline & vbnewline & vbtab & vbtab & "Disk Name: " & vbtab & vbtab & vbTab &  objDISK.name	
  objLOG.write vbnewline & vbnewline & vbtab & vbtab & "Disk Name: " & vbtab & vbtab & vbTab &  objDISK.name	
  objOUT.write vbnewline & vbtab & vbtab & "Disk Caption: " & vbtab & vbtab & vbTab &  objDISK.caption
  objLOG.write vbnewline & vbtab & vbtab & "Disk Caption: " & vbtab & vbtab & vbTab &  objDISK.caption
  objOUT.write vbnewline & vbTab & vbtab & "DeviceID: "& vbTab &  objDISK.DeviceID
  objLOG.write vbnewline & vbTab & vbtab & "DeviceID: "& vbTab &  objDISK.DeviceID
  objOUT.write vbnewline & vbTab & vbtab & "Description: "& vbTab & objDISK.description
  objLOG.write vbnewline & vbTab & vbtab & "Description: "& vbTab & objDISK.description
  objOUT.write vbnewline & vbTab & vbtab & "Drive Type: "& vbTab & strDRV(objDISK.drivetype)
  objLOG.write vbnewline & vbTab & vbtab & "Drive Type: "& vbTab & strDRV(objDISK.drivetype)
  objOUT.write vbnewline & vbTab & vbtab & "Media Type: "& vbTab & strMTYP(objDISK.mediatype)
  objLOG.write vbnewline & vbTab & vbtab & "Media Type: "& vbTab & strMTYP(objDISK.mediatype)
  objOUT.write vbnewline & vbTab & vbtab & "Provider: "& vbTab &  objDISK.providername
  objLOG.write vbnewline & vbTab & vbtab & "Provider: "& vbTab &  objDISK.providername
  objOUT.write vbnewline & vbTab & vbtab & "Status: "& vbTab &  objDISK.Status
  objLOG.write vbnewline & vbTab & vbtab & "Status: "& vbTab &  objDISK.Status
  objOUT.write vbnewline & vbTab & vbtab & "Volume Name: "& vbTab & objDISK.volumename
  objLOG.write vbnewline & vbTab & vbtab & "Volume Name: "& vbTab & objDISK.volumename
  objOUT.write vbnewline & vbTab & vbtab & "File System: "& vbTab & objDISK.FileSystem
  objLOG.write vbnewline & vbTab & vbtab & "File System: "& vbTab & objDISK.FileSystem
  objOUT.write vbnewline & vbTab & vbtab & "Size: "& vbTab &  (((objDISK.Size / 1024) / 1024) / 1024) & "GB"
  objLOG.write vbnewline & vbTab & vbtab & "Size: "& vbTab &  (((objDISK.Size / 1024) / 1024) / 1024) & "GB"
  objOUT.write vbnewline & vbTab & vbtab & "Free Space: "& vbTab &  (((objDISK.FreeSpace / 1024) / 1024) / 1024) & "GB"
  objLOG.write vbnewline & vbTab & vbtab & "Free Space: "& vbTab &  (((objDISK.FreeSpace / 1024) / 1024) / 1024) & "GB"
  objOUT.write vbnewline & vbnewline & vbtab & "COMPLETED ENUMERATING DISK LAYOUT : " & now
  objLOG.write vbnewline & vbnewline & vbtab & "COMPLETED ENUMERATING DISK LAYOUT : " & now
Next
''ENUMERATE DISK PROPERTIES / CAPABILITIES
objOUT.write vbnewline & vbnewline & vbtab & "ENUMERATING DISK PROPERTIES : " & now
objLOG.write vbnewline & vbnewline & vbtab & "ENUMERATING DISK PROPERTIES : " & now
call HOOK("wmic diskdrive list /format:list")
objOUT.write vbnewline & vbtab & "COMPLETED ENUMERATING DISK PROPERTIES : " & now
objLOG.write vbnewline & vbtab & "COMPLETED ENUMERATING DISK PROPERTIES : " & now
objOUT.write vbnewline & "COMPLETED ENUMERATING DISK INFORMATION : " & now
objLOG.write vbnewline & "COMPLETED ENUMERATING DISK INFORMATION : " & now
''END SCRIPT
call CLEANUP

''FUNCTIONS TO TRANSLATE RETURN CODES TO READABLE FORMAT
function strDRV(intTYP)                                                     ''DRIVETYPE CODE
  select case intTYP
    case 0
	  strDRV = "Unknown (0)"
    case 1
	  strDRV = "No Root Directory (1)"  
    case 2
	  strDRV = "Removable Disk (2)"
    case 3
	  strDRV = "Local Disk (3)"
    case 4
	  strDRV = "Network Drive (4)"
    case 5
	  strDRV = "Compact Disc (5)"
    case 6
	  strDRV = "RAM Disk (6)"
  end select
end function

function strMTYP(intTYP)                                                    ''MEDIATYPE CODE
  select case intTYP
    case 0
	  strMTYP = "Unknown (0)"
    case 11
	  strMTYP = "Removable media other than floppy (11)"  
    case 12
	  strMTYP = "Fixed hard disk media (12)"
    case else
	  strMTYP = "WHY YOU USE FLOPPY?!"
  end select
end function

''SUB-ROUTINES
sub HOOK(strCMD)                                                            ''CALL HOOK TO MONITOR OUTPUT OF CALLED COMMAND
  on error resume next
  'comspec = objWSH.ExpandEnvironmentStrings("%comspec%")
  set objHOOK = objWSH.exec(strCMD)
  'while (objHOOK.status = 0)
    while (not objHOOK.stdout.atendofstream)                                ''STDOUT FROM CALLED COMMAND IS NOT EMPTY
      strIN = objHOOK.stdout.readline
      if (strIN <> vbnullstring) then                                       ''IF STDOUT.READLINE FROM CALL COMMAND IS NOT EMPTY
        objOUT.write vbnewline & vbtab & vbtab & strIN 
        objLOG.write vbnewline & vbtab & vbtab & strIN 
      end if
    wend
    wscript.sleep 10
  'wend
  strIN = objHOOK.stdout.readall
  if (strIN <> vbnullstring) then                                           ''IF STDOUT.READALL FROM CALL COMMAND IS NOT EMPTY
    objOUT.write vbnewline & vbtab & vbtab & strIN 
    objLOG.write vbnewline & vbtab & vbtab & strIN 
  end if
  'retSTOP = objHOOK.exitcode
  set objHOOK = nothing
  if (err.number <> 0) then                                                 ''ERROR RETURNED
    objOUT.write vbnewline & vbtab & now & vbtab & err.number & vbtab & err.description
	objLOG.write vbnewline & vbtab & now & vbtab & err.number & vbtab & err.description
  end if
end sub

sub CLEANUP()                                                               ''SCRIPT CLEANUP
  if (errRET = 0) then                                                      ''NO ERROR RETURNED
    err.clear
    objOUT.write vbnewline & vbnewline & "SYSNFO : COMPLETE : " & Now()
	objLOG.write vbnewline & vbnewline & "SYSNFO : COMPLETE : " & Now()
    objOUT.write vbnewline & "LOGFILE : C:\" & strCST & "_" & strDEV & "_sysnfo.txt : " & Now() & vbnewline
	objLOG.write vbnewline & "LOGFILE : C:\" & strCST & "_" & strDEV & "_sysnfo.txt : " & Now() & vbnewline
  elseif (errRET <> 0) then                                                 ''ERROR RETURNED
    objOUT.write vbnewline & vbnewline & "SYSNFO : ERROR : " & Now()
	objLOG.write vbnewline & vbnewline & "SYSNFO : ERROR : " & Now()
    objOUT.write vbnewline & "LOGFILE : C:\" & strCST & "_" & strDEV & "_sysnfo.txt : " & Now() & vbnewline
	objLOG.write vbnewline & "LOGFILE : C:\" & strCST & "_" & strDEV & "_sysnfo.txt : " & Now() & vbnewline
    ''RAISE CUSTOMIZED ERROR CODE, ERROR CODE WILL BE DEFINE RESTOP NUMBER INDICATING WHICH SECTION FAILED
    call err.raise(vbObjectError + errRET,"SYSNFO", "FAIL")
  end if
  ''EMPTY OBJECTS
  set objLOG = nothing
  set objFSO = nothing
  set objREF = nothing
  set objWMI = nothing
  set objWSH = nothing
  set objOUT = nothing
  set objIN = nothing
  ''END SCRIPT, RETURN ERROR
  wscript.quit err.number
end sub