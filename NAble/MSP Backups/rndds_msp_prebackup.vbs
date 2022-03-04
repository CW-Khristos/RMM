''RNDDS_MSP_PREBACKUP.VBS
''DESIGNED TO STOP EAGLESOFT SERVICES AND DATABASE TO ALLOW FOR FILE COPY TO 'OFFLINE' DIRECTORY
''SCRIPT UTILIZES ROBOCOPY TO 'MIRROR' SOURCE TO DESTINATION EXACTLY
''MSP BACKUPS EXCLUDE 'ONLINE' EAGLESOFT DIRECTORY AND INCLUDE 'OFFLINE' DIRECTORY
''CUSTOMIZED FOR ROBERT NYBERG DDS CUSTOMER SETUP ONLY
''WRITTEN BY : CJ BLEDSOE / CJ<@>THECOMPUTERWARRIORS.COM
on error resume next
''SCRIPT VARIABLES
dim strVER, errRET, strIN
dim strREPO, strBRCH, strDIR
''SCRIPT OBJECTS
dim objIN, objOUT, objARG, objWSH, objFSO
dim objLOG, objHOOK, objEXEC, objHTTP, objXML
''VERSION FOR SCRIPT UPDATE , RNDDS_MSP_PREBACKUP.VBS , REF #2 , REF #50
strVER = 7
strREPO = "scripts"
strBRCH = "master"
strDIR = "MSP Backups"
''DEFAULT FAIL
errRET = 13
''STDIN / STDOUT
set objIN = wscript.stdin
set objOUT = wscript.stdout
set objARG = wscript.arguments
''CREATE SCRIPTING SHELL & FILE SYSTEM OBJECTS
set objOUT = wscript.stdout
set objWSH = createobject("wscript.shell")
set objFSO = createobject("scripting.filesystemobject")
''CHECK 'PERSISTENT' FOLDERS , REF #2 , REF #73
if (not (objFSO.folderexists("C:\IT\"))) then
  objFSO.createfolder("C:\IT\")
end if
if (not (objFSO.folderexists("C:\IT\Scripts\"))) then
  objFSO.createfolder("C:\IT\Scripts\")
end if
''PREPARE LOGFILE
if (objFSO.fileexists("C:\temp\MSP_PREBACKUP")) then        ''LOGFILE EXISTS
  objFSO.deletefile "C:\temp\MSP_PREBACKUP", true
  set objLOG = objFSO.createtextfile("C:\temp\MSP_PREBACKUP")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\MSP_PREBACKUP", 8)
else                                                        ''LOGFILE NEEDS TO BE CREATED
  set objLOG = objFSO.createtextfile("C:\temp\MSP_PREBACKUP")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\MSP_PREBACKUP", 8)
end if
''READ PASSED COMMANDLINE ARGUMENTS
if (wscript.arguments.count > 0) then                       ''ARGUMENTS WERE PASSED
  for x = 0 to (wscript.arguments.count - 1)
    objOUT.write vbnewline & now & vbtab & " - ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
    objLOG.write vbnewline & now & vbtab & " - ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
  next 
  if (wscript.arguments.count > 0) then                     ''SET PASSED ARG7UMENTS
  else                                                      ''NOT ENOUGH ARGUMENTS PASSED, END SCRIPT
    'errRET = 1
    'call CLEANUP()
  end if
else                                                        ''NO ARGUMENTS PASSED, END SCRIPT
  'errRET = 1
  'call CLEANUP()
end if

''------------
''BEGIN SCRIPT
objOUT.write vbnewline & vbnewline & now & vbtab & " - EXECUTING RNDDS_MSP_PREBACKUP" & vbnewline
objLOG.write vbnewline & vbnewline & now & vbtab & " - EXECUTING RNDDS_MSP_PREBACKUP" & vbnewline
''AUTOMATIC UPDATE, RNDDS_MSP_PREBACKUP.VBS, REF #2 , REF #69 , REF #68 , FIXES #50
objOUT.write vbnewline & now & vbtab & vbtab & " - CHECKING FOR UPDATE : RNDDS_MSP_PREBACKUP : " & strVER
objLOG.write vbnewline & now & vbtab & vbtab & " - CHECKING FOR UPDATE : RNDDS_MSP_PREBACKUP : " & strVER
''DOWNLOAD CHKAU.VBS SCRIPT, REF #2 , REF #69 , REF #68
call FILEDL("https://raw.githubusercontent.com/CW-Khristos/scripts/master/chkAU.vbs", "C:\IT\Scripts", "chkAU.vbs")
''EXECUTE CHKAU.VBS SCRIPT, REF #69
intRET = objWSH.run ("cmd.exe /C " & chr(34) & "cscript.exe " & chr(34) & "C:\IT\Scripts\chkAU.vbs" & chr(34) & " " & _
  chr(34) & strREPO & chr(34) & " " & chr(34) & strBRCH & chr(34) & " " & chr(34) & strDIR & chr(34) & " " & _
  chr(34) & wscript.scriptname & chr(34) & " " & chr(34) & strVER & chr(34) & chr(34), 0, true)
''CHKAU RETURNED - NO UPDATE FOUND , REF #2 , REF #69 , REF #68
objOUT.write vbnewline & "errRET='" & intRET & "'"
objLOG.write vbnewline & "errRET='" & intRET & "'"
intRET = (intRET - vbObjectError)
objOUT.write vbnewline & "errRET='" & intRET & "'"
objLOG.write vbnewline & "errRET='" & intRET & "'"
if ((intRET = 4) or (intRET = 10) or (intRET = 11) or (intRET = 1) or (intRET = 2147221505) or (intRET = 2147221517)) then
  ''INITIATE STOP SERVICES
  call STOPEAGLE()
end if
''RESTART EAGLESOFT DB AND SERVICES
call STARTDB()
''END SCRIPT, RETURN EXIT CODE
call CLEANUP()
''END SCRIPT
''------------

''SUB-ROUTINES
sub STOPEAGLE()                                             ''STOP EAGLESOFT SERVICES
  objOUT.write vbnewline & vbnewline & "STOPPING EAGLESOFT SERVICES : " & now
  objLOG.write vbnewline & vbnewline & "STOPPING EAGLESOFT SERVICES : " & now
  ''STOP PATTERSON APP SERVICE
  ''DEFAULT FAIL
  errRET = 13
  call HOOK("net stop " & chr(34) & "PattersonAppService" & chr(34))
  wscript.sleep 5000
  if (errRET <> 0) then                                     ''ERROR RETURNED
    if (errRET = 2) then                                    ''SERVICE ALREADY STOPPED
      objOUT.write vbnewline & errRET & vbtab & "SERVICE ALREADY STOPPED : PattersonAppService : " & now
      objLOG.write vbnewline & errRET & vbtab & "SERVICE ALREADY STOPPED : PattersonAppService : " & now
      errRET = 0
      err.clear
    elseif (errRET <> 2) then                               ''ANY OTHER ERROR RETURNED
      objOUT.write vbnewline & errRET & vbtab & "ERROR STOPPING : PattersonAppService : " & now
      objLOG.write vbnewline & errRET & vbtab & "ERROR STOPPING : PattersonAppService : " & now
      call LOGERR(4)
    end if
  end if
  ''STOP EAGLESOFT DATABASE
  call STOPDB()
end sub

sub STARTEAGLE()                                            ''START EAGLESOFT SERVICES
  objOUT.write vbnewline & vbnewline & "STARTING EAGLESOFT SERVICES : " & now
  objLOG.write vbnewline & vbnewline & "STARTING EAGLESOFT SERVICES : " & now
  ''START PATTERSON APP SERVICE
  call HOOK("net start " & chr(34) & "PattersonAppService" & chr(34))
  wscript.sleep 5000
  if (errRET <> 0) then                                     ''ERROR RETURNED
    if (errRET = 2) then                                    ''SERVICE ALREADY STARTED
      objOUT.write vbnewline & retSTOP & vbtab & "SERVICE ALREADY STARTED : PattersonAppService : " & now
      objLOG.write vbnewline & retSTOP & vbtab & "SERVICE ALREADY STARTED : PattersonAppService : " & now
      errRET = 0
      err.clear
    elseif (errRET <> 2) then                               ''ANY OTHER ERROR
      objOUT.write vbnewline & errRET & vbtab & "ERROR STARTING : PattersonAppService : " & now
      objLOG.write vbnewline & errRET & vbtab & "ERROR STARTING : PattersonAppService : " & now
      call LOGERR(8)
    end if
  end if
end sub

sub STOPDB()                                                ''STOP EAGLESOFT DATABASE
  objOUT.write vbnewline & vbnewline & "STOPPING EAGLESOFT DATABASE : " & now
  objLOG.write vbnewline & vbnewline & "STOPPING EAGLESOFT DATABASE : " & now
  ''CALL PATTERSONSERVERSTATUS.EXE UTILITY WITH 'STOP' SWITCH
  ''DEFAULT FAIL
  errRET = 13
  call HOOK(chr(34) & "C:\EagleSoft\Shared Files\PattersonServerStatus.exe" & chr(34) & " -stop")
  wscript.sleep 5000
  if (errRET = 0) then                                      ''DATABASE SUCCESSFULLY STOPPED
    objOUT.write vbnewline & vbtab & "EAGLESOFT DATABASE : STOPPED : " & now
    objLOG.write vbnewline & vbtab & "EAGLESOFT DATABASE : STOPPED : " & now
    ''COPY EAGLESOFT DATA
    call DBCOPY()
  elseif (errRET <> 0) then                                 ''ERROR RETURNED
    objOUT.write vbnewline & errRET & vbtab & "EAGLESOFT DATABASE : ERROR STOPPING: " & now
    objLOG.write vbnewline & errRET & vbtab & "EAGLESOFT DATABASE : ERROR STOPPING: " & now
    call LOGERR(5)
    ''END SCRIPT, RETURN EXIT CODE
    'call CLEANUP()
  end if
end sub

sub STARTDB()                                               ''START EAGLESOFT DATABASE
  objOUT.write vbnewline & vbnewline & "STARTING EAGLESOFT DATABASE : " & now
  objLOG.write vbnewline & vbnewline & "STARTING EAGLESOFT DATABASE : " & now
  ''CALL PATTERSONSERVERSTATUS.EXE WITH 'START' SWITCH, DO NOT MONITOR, PROCESS DOES NOT EXIT
  errRET = objWSH.run(chr(34) & "C:\EagleSoft\Shared Files\PattersonServerStatus.exe" & chr(34) & " -start", 0, false)
  wscript.sleep 5000
  if (errRET = 0) then                                      ''DATABASE SUCCESSFULLY STARTED
    objOUT.write vbnewline & errRET & vbtab & "EAGLESOFT DATABASE STARTED : " & now
    objLOG.write vbnewline & errRET & vbtab & "EAGLESOFT DATABASE STARTED : " & now
  elseif (errRET <> 0) then                                 ''ERROR RETURNED
    objOUT.write vbnewline & errRET & vbtab & "ERROR STARTING EAGLESOFT DATABASE : " & now
    objLOG.write vbnewline & errRET & vbtab & "ERROR STARTING EAGLESOFT DATABASE : " & now
    call LOGERR(7)
    ''END SCRIPT, RETURN EXIT CODE
    'call CLEANUP()
  end if
  ''START EAGLESOFT SERVICES
  call STARTEAGLE()
end sub

sub DBCOPY()                                                ''COPY EAGLESOFT DATA FOLDER
  objOUT.write vbnewline & vbnewline & "COPYING EAGLESOFT DATA : " & now
  objLOG.write vbnewline & vbnewline & "COPYING EAGLESOFT DATA : " & now
  ''USE ROBOCOPY TO COPY C:\EAGLESOFT\DATA FOLDER, OLVERWRITE ALL FILES IN DESTINATION , RNDDS_MSP_PREBACKUP.VBS , REF #2 , REF #49
  ''DEFAULT FAIL
  errRET = 13
  call HOOK("robocopy " & chr(34) & "C:\EagleSoft\Data" & chr(34) & " " & chr(34) & "E:\Backup" & chr(34) & " /e /COPYALL /DCOPY:T /MIR /z /w:5 /r:3 /mt /v")
  if (errRET > 4) then                                      ''SUCCESSFULLY COPIED DATA
    objOUT.write vbnewline & "COPY EAGLESOFT DATA COMPLETE : " & now
    objLOG.write vbnewline & "COPY EAGLESOFT DATA COMPLETE : " & now
    errRET = 0
    err.clear
  elseif (errRET < 5) then                                  ''ERROR RETURNED
    objOUT.write vbnewline & errRET & vbtab & "ERROR : ROBOCOPY C:\EAGLESOFT\DATA E:\BACKUP : " & now
    objLOG.write vbnewline & errRET & vbtab & "ERROR : ROBOCOPY C:\EAGLESOFT\DATA E:\BACKUP : " & now
    call LOGERR(6)
  end if
end sub

sub FILEDL(strURL, strDL, strFILE)                          ''CALL HOOK TO DOWNLOAD FILE FROM URL , 'ERRRET'=11
  strSAV = vbnullstring
  ''SET DOWNLOAD PATH
  strSAV = strDL & "\" & strFILE
  objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "HTTPDOWNLOAD-------------DOWNLOAD : " & strURL & " : SAVE AS :  " & strSAV
  objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "HTTPDOWNLOAD-------------DOWNLOAD : " & strURL & " : SAVE AS :  " & strSAV
  ''CHECK IF FILE ALREADY EXISTS
  if objFSO.fileexists(strSAV) then
    ''DELETE FILE FOR OVERWRITE
    objFSO.deletefile(strSAV)
  end if
  ''CREATE HTTP OBJECT
  set objHTTP = createobject( "WinHttp.WinHttpRequest.5.1" )
  ''DOWNLOAD FROM URL
  objHTTP.open "GET", strURL, false
  objHTTP.send
  if (objHTTP.status = 200) then
    dim objStream
    set objStream = createobject("ADODB.Stream")
    with objStream
      .Type = 1 'adTypeBinary
      .Open
      .Write objHTTP.ResponseBody
      .SaveToFile strSAV
      .Close
    end with
    set objStream = nothing
  end if
  ''CHECK THAT FILE EXISTS
  if objFSO.fileexists(strSAV) then
    objOUT.write vbnewline & now & vbtab & vbtab & " - DOWNLOAD : " & strSAV & " : SUCCESSFUL"
    objLOG.write vbnewline & now & vbtab & vbtab & " - DOWNLOAD : " & strSAV & " : SUCCESSFUL"
  end if
	set objHTTP = nothing
  if ((err.number <> 0) and (err.number <> 58)) then        ''ERROR RETURNED DURING DOWNLOAD , 'ERRRET'=11
    call LOGERR(11)
  end if
end sub

sub HOOK(strCMD)                                            ''CALL HOOK TO MONITOR OUTPUT OF CALLED COMMAND , 'ERRRET'=12
  on error resume next
  objOUT.write vbnewline & now & vbtab & vbtab & "EXECUTING : " & strCMD
  objLOG.write vbnewline & now & vbtab & vbtab & "EXECUTING : " & strCMD
  set objHOOK = objWSH.exec(strCMD)
  if (instr(1, strCMD, "takeown /F ") = 0) then             ''SUPPRESS 'TAKEOWN' SUCCESS MESSAGES
    while (not objHOOK.stdout.atendofstream)
      strIN = objHOOK.stdout.readline
      if (strIN <> vbnullstring) then
        objOUT.write vbnewline & now & vbtab & vbtab & vbtab & strIN 
        objLOG.write vbnewline & now & vbtab & vbtab & vbtab & strIN 
      end if
    wend
    wscript.sleep 10
    strIN = objHOOK.stdout.readall
    if (strIN <> vbnullstring) then
      objOUT.write vbnewline & now & vbtab & vbtab & vbtab & strIN 
      objLOG.write vbnewline & now & vbtab & vbtab & vbtab & strIN 
    end if
  end if
  set objHOOK = nothing
  if (err.number = 0) then                                  ''NO ERROR RETURNED, SET RETURN 'ERRRET'=0
    call LOGERR(0)
  elseif (err.number <> 0) then                             ''ERROR RETURNED DURING UPDATE CHECK , 'ERRRET'=12
    call LOGERR(12)
  end if
end sub

sub LOGERR(intSTG)                                          ''CALL HOOK TO MONITOR OUTPUT OF CALLED COMMAND
  errRET = intSTG
  if (err.number <> 0) then
    objOUT.write vbnewline & now & vbtab & vbtab & vbtab & err.number & vbtab & err.description & vbnewline
    objLOG.write vbnewline & now & vbtab & vbtab & vbtab & err.number & vbtab & err.description & vbnewline
		err.clear
  end if
  ''CUSTOM ERROR CODES
  select case intSTG
    case 1                                                  '' 'ERRRET'=1 - NOT ENOUGH ARGUMENTS
  end select
end sub

sub CLEANUP()                                               ''SCRIPT CLEANUP
  on error resume next
  if (errRET = 0) then                                      ''PRE-BACKUP COMPLETED SUCCESSFULLY
    objOUT.write vbnewline & vbnewline & now & vbtab & " - MSP_PRE-BACKUP COMPLETE : " & now
    objLOG.write vbnewline & vbnewline & now & vbtab & " - MSP_PRE-BACKUP COMPLETE : " & now
    err.clear
  elseif (errRET <> 0) then                                 ''PRE-BACKUP FAILED
    objOUT.write vbnewline & vbnewline & now & vbtab & " - MSP_PRE-BACKUP FAILURE : " & errRET & " : " & now
    objLOG.write vbnewline & vbnewline & now & vbtab & " - MSP_PRE-BACKUP FAILURE : " & errRET & " : " & now
    ''RAISE CUSTOMIZED ERROR CODE, ERROR CODE WILL BE DEFINE RESTOP NUMBER INDICATING WHICH SECTION FAILED
    call err.raise(vbObjectError + errRET, "MSP_PRE-BACKUP", "FAIL")
  end if
  ''EMPTY OBJECTS
  set objEXEC = nothing
  set objLOG = nothing
  set objFSO = nothing
  set objWSH = nothing
  set objARG = nothing
  set objOUT = nothing
  set objIN = nothing
  ''END SCRIPT, RETURN ERROR
  wscript.quit err.number
end sub