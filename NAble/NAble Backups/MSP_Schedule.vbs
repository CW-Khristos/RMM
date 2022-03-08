''MSP_SCHEDULE.VBS
''DESIGNED TO AUTOMATE CONFIGURATION OF BACKUP SCHEDULES IN MSP BACKUP VIA CLIENTTOOL
''ACCEPTS 7 PARAMETERS , REQUIRES 1 PARAMETERS , 7TH PARAMETER 'INTID' REQUIRED BY 'MODIFY' OPTION
''REQUIRED PARAMETER 'STROPT' ; STRING VALUE TO INDICATE ACTION TO PERFORM ; "ADD","MODIFY","DELETE","LIST"
''OPTIONAL PARAMETER 'STRNAME' ; STRING VALUE TO NAME THE SCHEDULE ; CANNOT BE EMPTY
''OPTIONAL PARAMETER 'STRDATA' ; STRING VALUE TO DATASOURCES TO BACKUP ; SEPARATE MULTIPLE SOURCES VIA ","
''Possible values are Exchange, FileSystem, MySql, NetworkShares, Oracle, SystemState, VMware, VssHyperV, VssMsSql, VssSharePoint and All. Default value is All.
''OPTIONAL PARAMETER 'STRDAYS' ; STRING VALUE TO SET DAYS WHEN SCHEDULE IS ACTIVE ; SEPARATE MULTIPLE DAYS VIA ","
''Possible values are Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday and All. Default value is All.
''OPTIONAL PARAMETER 'STRTIME' ; STRING VALUE TO SET TIME FOR BACKUP ; MUST BE IN FORMAT HH:MM ; Default value is 00:00
''OPTIONAL PARAMETER 'BLNACT' ; BOOLEAN VALUE TO INDICATE IF SCHEDULE IS ACTIVE
''Possible values are 0 (not active) or 1 (active). Default value is False(0).
''OPTIONAL PARAMETER 'INTID' ; INTEGER VALUE TO INDICATE IF SCHEDULE ID ; REQUIRED BY 'MODIFY' OPTION
''WRITTEN BY : CJ BLEDSOE / CBLEDSOE<@>IPMCOMPUTERS.COM
on error resume next
''SCRIPT VARIABLES
dim errRET, strVER
dim strREPO, strBRCH, strDIR
''VARIABLES ACCEPTING PARAMETERS
dim strOPT, strNAME, strDATA
dim strDAYS, strTIME, blnACT, intID
dim strIN, strOUT, strRCMD, strSAV
''SCRIPT OBJECTS
dim objIN, objOUT, objARG, objWSH, objFSO
dim objLOG, objEXEC, objHOOK, objHTTP, objXML
''VERSION FOR SCRIPT UPDATE , MSP_SCHEDULE.VBS , REF #2 , REF #68 , REF #69
strVER = 1
strREPO = "scripts"
strBRCH = "dev"
strDIR = "MSP Backups"
''DEFAULT SUCCESS
errRET = 0
''STDIN / STDOUT
set objIN = wscript.stdin
set objOUT = wscript.stdout
set objARG = wscript.arguments
''OBJECTS FOR LOCATING FOLDERS
set objWSH = createobject("wscript.shell")
set objFSO = createobject("scripting.filesystemobject")
''CHECK 'PERSISTENT' FOLDERS , REF #2 , REF #73
if (not (objFSO.folderexists("c:\temp"))) then
  objFSO.createfolder("c:\temp")
end if
if (not (objFSO.folderexists("C:\IT\"))) then
  objFSO.createfolder("C:\IT\")
end if
if (not (objFSO.folderexists("C:\IT\Scripts\"))) then
  objFSO.createfolder("C:\IT\Scripts\")
end if
''PREPARE LOGFILE
if (objFSO.fileexists("C:\temp\MSP_SCHEDULE")) then                         ''LOGFILE EXISTS
  objFSO.deletefile "C:\temp\MSP_SCHEDULE", true
  set objLOG = objFSO.createtextfile("C:\temp\MSP_SCHEDULE")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\MSP_SCHEDULE", 8)
else                                                                        ''LOGFILE NEEDS TO BE CREATED
  set objLOG = objFSO.createtextfile("C:\temp\MSP_SCHEDULE")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\MSP_SCHEDULE", 8)
end if
''CHECK FOR MSP BACKUP MANAGER CLIENTTOOL , REF #76
if (objFSO.fileexists("C:\Program Files\Backup Manager\clienttool.exe")) then
  call LOGERR(0)                                                            ''CLIENTTOOL.EXE PRESENT, CONTINUE SCRIPT, 'ERRRET'=0
elseif (not objFSO.fileexists("C:\Program Files\Backup Manager\clienttool.exe")) then
  call LOGERR(1)                                                            ''CLIENTTOOL.EXE NOT PRESENT, END SCRIPT, 'ERRRET'=1
end if
''READ PASSED COMMANDLINE ARGUMENTS
if (wscript.arguments.count > 0) then                                       ''ARGUMENTS WERE PASSED
  for x = 0 to (wscript.arguments.count - 1)
    objOUT.write vbnewline & now & vbtab & " - ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
    objLOG.write vbnewline & now & vbtab & " - ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
  next 
  if (wscript.arguments.count >= 1) then                                    ''SET VARIABLES ACCEPTING ARGUMENTS
    strOPT = objARG.item(0)                                                 ''SET REQUIRED PARAMETER 'STROPT' ; INDICATE ACTION TO PERFORM ; "ADD","MODIFY","REMOVE","LIST"
    if (wscript.arguments.count = 2) then                                   ''NO OPTIONAL PARAMETERS PASSED , SET OPTIONAL PARAMETER 'DEFAULTS'
      strNAME = objARG.item(1)                                              ''SET OPTIONAL PARAMETER 'STRNAME' ; STRING VALUE TO NAME THE SCHEDULE ; CANNOT BE EMPTY
      strDATA = "All"                                                       ''SET OPTIONAL PARAMETER 'STRDATA' ; STRING VALUE TO DATASOURCES TO BACKUP ; SEPARATE MULTIPLE SOURCES VIA "," ; DEFAULT VALUE IS ALL
      strDAYS = "All"                                                       ''SET OPTIONAL PARAMETER 'STRDAYS' ; STRING VALUE TO SET DAYS WHEN SCHEDULE IS ACTIVE ; SEPARATE MULTIPLE DAYS VIA "," ; DEFAULT VALUE IS ALL
      strTIME = "00:00"                                                     ''SET OPTIONAL PARAMETER 'STRTIME' ; STRING VALUE TO SET TIME FOR BACKUP ; MUST BE IN FORMAT HH:MM ; DEFAULT VALUE IS 00:00
      blnACT = "false"                                                      ''SET OPTIONAL PARAMETER 'BLNACT' ; BOOLEAN VALUE TO INDICATE IF SCHEDULE IS ACTIVE ; DEFAULT VALUE IS FALSE(0)
    elseif (wscript.arguments.count > 2) then                               ''OPTIONAL PARAMETERS PASSED , SET OPTIONAL PARAMETERS
      strNAME = objARG.item(1)                                              ''SET OPTIONAL PARAMETER 'STRNAME' ; STRING VALUE TO NAME THE SCHEDULE ; CANNOT BE EMPTY
      strDATA = objARG.item(2)                                              ''SET OPTIONAL PARAMETER 'STRDATA' ; STRING VALUE TO DATASOURCES TO BACKUP ; SEPARATE MULTIPLE SOURCES VIA ","
      strDAYS = objARG.item(3)                                              ''SET OPTIONAL PARAMETER 'STRDAYS' ; STRING VALUE TO SET DAYS WHEN SCHEDULE IS ACTIVE ; SEPARATE MULTIPLE DAYS VIA ","
      strTIME = objARG.item(4)                                              ''SET OPTIONAL PARAMETER 'STRTIME' ; STRING VALUE TO SET TIME FOR BACKUP ; MUST BE IN FORMAT HH:MM
      blnACT = cbool(objARG.item(5))                                        ''SET OPTIONAL PARAMETER 'BLNACT' ; BOOLEAN VALUE TO INDICATE IF SCHEDULE IS ACTIVE
    end if
    if ((ucase(strOPT) = "MODIFY") or (ucase(strOPT) = "REMOVE") then       ''OPTION TO 'MODIFY' OR 'REMOVE' SCHEDULES REQUIRES KNOWING SCHEDULE ID
      if (wscript.arguments.count <= 6) then                                ''NOT ENOUGH OPTIONAL PARAMETERS PASSED , END SCRIPT , 'ERRRET'=2
        call LOGERR(2)
      elseif (wscript.arguments.count > 6) then                             ''ENOUGH OPTIONAL PARAMETERS PASSED , SET OPTIONAL PARAMETERS
        intID = objARG.item(6)                                              ''SET OPTIONAL PARAMETER 'INTID' ; INTEGER VALUE TO INDICATE IF SCHEDULE ID ; REQUIRED BY 'MODIFY' OPTION
      end if
    end if
    if wscript.arguments.count <= 6) then
      if (strNAME = vbnullstring) then                                      ''VALIDATE VALUE OF OPTIONAL PARAMETER 'STRNAME' IS NOT EMPTY , 'ERRRET'=3
        call LOGERR(3)
      end if
    elseif (wscript.arguments.count = 7) then
      if (intID = vbnullstring) then                                        ''VALIDATE VALUE OF OPTIONAL PARAMETER 'INTID' IS NOT EMPTY , 'ERRRET'=3
        call LOGERR(3)
      end if
    end if
  end if
elseif (wscript.arguments.count < 1) then                                   ''NOT ENOUGH ARGUMENTS PASSED , END SCRIPT , 'ERRRET'=2
  call LOGERR(2)
  call CLEANUP()
end if

''------------
''BEGIN SCRIPT
''TRANSLATE 'BLNACT' TO INSTEGER AS EXPECTED BY CLIENTTOOL
if (blnACT) then
  blnACT = 1
elseif (not blnACT) then
  blnACT = 0
end if
if (errRET = 0) then                                                        ''ARGUMENTS PASSED, CONTINUE SCRIPT
	objOUT.write vbnewline & vbnewline & now & vbtab & " - EXECUTING MSP_SCHEDULE"
	objLOG.write vbnewline & vbnewline & now & vbtab & " - EXECUTING MSP_SCHEDULE"
	''AUTOMATIC UPDATE, MSP_SCHEDULE.VBS, REF #2 , REF #69 , REF #68
  objOUT.write vbnewline & now & vbtab & vbtab & " - CHECKING FOR UPDATE : MSP_SCHEDULE : " & strVER
  objLOG.write vbnewline & now & vbtab & vbtab & " - CHECKING FOR UPDATE : MSP_SCHEDULE : " & strVER
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
    objOUT.write vbnewline & now & vbtab & vbtab & " - NO UPDATE FOUND : MSP_SCHEDULE : " & strVER
    objLOG.write vbnewline & now & vbtab & vbtab & " - NO UPDATE FOUND : MSP_SCHEDULE : " & strVER
    if (ucase(strOPT) = "LIST") then
      call HOOK("C:\Program Files\Backup Manager\clienttool.exe control.schedule.list")
    elseif (ucase(strOPT) = "ADD") then
      call HOOK("C:\Program Files\Backup Manager\clienttool.exe control.schedule.add -name " & chr(34) & strNAME & chr(34) & " -active " & chr(34) & blnACT & chr(34) & _
        " -datasources " & chr(34) & strDATA & chr(34) & " -days " & chr(34) & strDAYS & chr(34) & " -time " & chr(34) & strTIME & chr(34))
    elseif (ucase(strOPT) = "MODIFY") then
      call HOOK("C:\Program Files\Backup Manager\clienttool.exe control.schedule.modify -id " & chr(34) & intID & chr(34) & " -active " & chr(34) & blnACT & chr(34) & _
        " -datasources " & chr(34) & strDATA & chr(34) & " -days " & chr(34) & strDAYS & chr(34) & " -time " & chr(34) & strTIME & chr(34) & " -name " & chr(34) & strNAME & chr(34))
    elseif (ucase(strOPT) = "REMOVE") then
      call HOOK("C:\Program Files\Backup Manager\clienttool.exe control.schedule.remove -id " & chr(34) & strNAME & chr(34))
    end if
  end if
elseif (errRET <> 0) then                                                   ''NO ARGUMENTS PASSED, END SCRIPT , 'ERRRET'=1
  call LOGERR(errRET)
end if
''END SCRIPT
call CLEANUP()
''END SCRIPT
''------------

''SUB-ROUTINES
sub FILEDL(strURL, strDL, strFILE)                                          ''CALL HOOK TO DOWNLOAD FILE FROM URL , 'ERRRET'=11
  strSAV = vbnullstring
  ''SET DOWNLOAD PATH
  strSAV = strDL & "\" & strFILE
  objOUT.write vbnewline & now & vbtab & vbtab & " - HTTPDOWNLOAD-------------DOWNLOAD : " & strURL & " : SAVE AS :  " & strSAV
  objLOG.write vbnewline & now & vbtab & vbtab & " - HTTPDOWNLOAD-------------DOWNLOAD : " & strURL & " : SAVE AS :  " & strSAV
  ''ADD WINHTTP SECURE CHANNEL TLS REGISTRY KEYS
  call HOOK("reg add " & chr(34) & "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp" & chr(34) & _
    " /f /v DefaultSecureProtocols /t REG_DWORD /d 0x00000A00 /reg:32")
  call HOOK("reg add " & chr(34) & "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp" & chr(34) & _
    " /f /v DefaultSecureProtocols /t REG_DWORD /d 0x00000A00 /reg:64")
  ''CHECK IF FILE ALREADY EXISTS
  if (objFSO.fileexists(strSAV)) then
    ''DELETE FILE FOR OVERWRITE
    objFSO.deletefile(strSAV)
  end if
  ''CREATE HTTP OBJECT
  set objHTTP = createobject("WinHttp.WinHttpRequest.5.1")
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
  if (objFSO.fileexists(strSAV)) then
    objOUT.write vbnewline & now & vbtab & vbtab & " - DOWNLOAD : " & strSAV & " : SUCCESSFUL"
    objLOG.write vbnewline & now & vbtab & vbtab & " - DOWNLOAD : " & strSAV & " : SUCCESSFUL"
  end if
	set objHTTP = nothing
  if ((err.number <> 0) and (err.number <> 58)) then                        ''ERROR RETURNED DURING UPDATE CHECK , 'ERRRET'=11
    call LOGERR(11)
  end if
end sub

sub HOOK(strCMD)                                                            ''CALL HOOK TO MONITOR OUTPUT OF CALLED COMMAND , 'ERRRET'=12
  on error resume next
  objOUT.write vbnewline & now & vbtab & vbtab & " - EXECUTING : HOOK(" & strCMD & ")"
  objLOG.write vbnewline & now & vbtab & vbtab & " - EXECUTING : HOOK(" & strCMD & ")"
  set objHOOK = objWSH.exec(strCMD)
  if (instr(1, strCMD, "takeown /F ") = 0) then                             ''SUPPRESS 'TAKEOWN' SUCCESS MESSAGES
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
  if (err.number <> 0) then                                                 ''ERROR RETURNED DURING UPDATE CHECK , 'ERRRET'=12
    call LOGERR(12)
  end if
end sub

sub LOGERR(intSTG)                                                          ''CALL HOOK TO MONITOR OUTPUT OF CALLED COMMAND
  errRET = intSTG
  if (err.number <> 0) then
    objOUT.write vbnewline & now & vbtab & vbtab & vbtab & err.number & vbtab & err.description & vbnewline
    objLOG.write vbnewline & now & vbtab & vbtab & vbtab & err.number & vbtab & err.description & vbnewline
		err.clear
  end if
  select case intSTG
    case 0                                                                  ''MSP_SCHEDULE - CLIENTTOOL CHECK PASSED, 'ERRRET'=0
      objOUT.write vbnewline & vbnewline & now & vbtab & " - MSP_SCHEDULE - CLIENTTOOL CHECK PASSED"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - MSP_SCHEDULE - CLIENTTOOL CHECK PASSED"
    case 1                                                                  ''MSP_SCHEDULE - CLIENTTOOL CHECK FAILED, 'ERRRET'=1
      objOUT.write vbnewline & vbnewline & now & vbtab & " - MSP_SCHEDULE - CLIENTTOOL CHECK FAILED, ENDING MSP_SCHEDULE"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - MSP_SCHEDULE - CLIENTTOOL CHECK FAILED, ENDING MSP_SCHEDULE"
    case 2                                                                  ''MSP_SCHEDULE - NOT ENOUGH ARGUMENTS, 'ERRRET'=2
      objOUT.write vbnewline & vbnewline & now & vbtab & " - MSP_SCHEDULE - NO ARGUMENTS PASSED, END SCRIPT"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - MSP_SCHEDULE - NO ARGUMENTS PASSED, END SCRIPT"
    case 3                                                                  ''MSP_SCHEDULE - NOT ENOUGH ARGUMENTS, 'ERRRET'=2
      objOUT.write vbnewline & vbnewline & now & vbtab & " - MSP_SCHEDULE - 'STRNAME' / 'INTID' CANNOT BE EMPTY OR NULL, END SCRIPT"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - MSP_SCHEDULE - 'STRNAME' / 'INTID' CANNOT BE EMPTY OR NULL, END SCRIPT"
    case 11                                                                 ''MSP_SCHEDULE - CALL FILEDL() FAILED, 'ERRRET'=11
      objOUT.write vbnewline & vbnewline & now & vbtab & " - MSP_SCHEDULE - CALL FILEDL() : " & strSAV
      objLOG.write vbnewline & vbnewline & now & vbtab & " - MSP_SCHEDULE - CALL FILEDL() : " & strSAV
    case 12                                                                 ''MSP_SCHEDULE - 'CALL HOOK() FAILED, 'ERRRET'=12
      objOUT.write vbnewline & vbnewline & now & vbtab & " - MSP_SCHEDULE - CALL HOOK('STRCMD') : " & strRCMD & " : FAILED"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - MSP_SCHEDULE - CALL HOOK('STRCMD') : " & strRCMD & " : FAILED"
  end select
end sub

sub CLEANUP()                                                               ''SCRIPT CLEANUP
  on error resume next
  if (errRET = 0) then         															                ''MSP_SCHEDULE COMPLETED SUCCESSFULLY
    objOUT.write vbnewline & vbnewline & now & vbtab & " - MSP_SCHEDULE SUCCESSFUL : " & now
    objLOG.write vbnewline & vbnewline & now & vbtab & " - MSP_SCHEDULE SUCCESSFUL : " & now
    err.clear
  elseif (errRET <> 0) then    															                ''MSP_SCHEDULE FAILED
    objOUT.write vbnewline & vbnewline & now & vbtab & " - MSP_SCHEDULE FAILURE : " & errRET & " : " & now
    objLOG.write vbnewline & vbnewline & now & vbtab & " - MSP_SCHEDULE FAILURE : " & errRET & " : " & now
    ''RAISE CUSTOMIZED ERROR CODE, ERROR CODE WILL BE DEFINE RESTOP NUMBER INDICATING WHICH SECTION FAILED
    call err.raise(vbObjectError + errRET, "MSP_SCHEDULE", "FAILURE")
  end if
  objOUT.write vbnewline & vbnewline & now & " - MSP_SCHEDULE COMPLETE" & vbnewline
  objLOG.write vbnewline & vbnewline & now & " - MSP_SCHEDULE COMPLETE" & vbnewline
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