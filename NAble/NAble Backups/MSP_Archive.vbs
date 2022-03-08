''MSP_ARCHIVE.VBS
''DESIGNED TO AUTOMATICALLY CONFIGURE CW 'DEFAULT' MSP BACKUP ARCHIVE SCHEDULE; 1ST & 15TH, 10PM
''ACCEPTS 6 PARAMETERS , REQUIRES 6 PARAMETERS
''REQUIRED PARAMETER : 'STRNAM' , STRING TO SET ARCHIVE SCHEDULE 'NAME'
''REQUIRED PARAMETER : 'STRACT' , STRING TO SET ARCHIVE SCHEDULE AS ACTIVE
''REQUIRED PARAMETER : 'STRDAT' , STRING TO SET ARCHIVE SCHEDULE 'DATASOURCES'
''REQUIRED PARAMETER : 'STRDAY' , STRING TO SET SCHEDULED DAYS OF MONTH FOR ARCHIVE SCHEDULE
''REQUIRED PARAMETER : 'STRMON' , STRING TO SET SCHEDULED MONTHS FOR ARCHIVE SCHEDULE
''REQUIRED PARAMETER : 'STRTIM' , STRING TO SET SCHEDULED TIME FOR ARCHIVE SCHEDULE
''WRITTEN BY : CJ BLEDSOE / CJ<@>THECOMPUTERWARRIORS.COM
'on error resume next
''ALWAYS RIGHT-CLICK SCRIPT, CHOOSE "PROPERTIES", CLICK "UNBLOCK"
''SCRIPT VARIABLES
dim blnRUN
dim strVER, errRET
dim strREPO, strBRCH, strDIR
dim strIDL, strTMP, arrTMP, strIN
''VARIABLES ACCEPTING PARAMETERS
dim strNUL, strSEL
dim strRUN, strARC
dim strNAM, strACT, strDAT
dim strDAY, strMON, strTIM
''SCRIPT OBJECTS
dim objIN, objOUT, objARG, objWSH
dim objFSO, objLOG, objHOOK, objHTTP, objXML
''SET 'ERRRET' CODE
errRET = 0
''VERSION FOR SCRIPT UPDATE, MSP_ARCHIVE.VBS, REF #2 , REF $68 , REF #69
strVER = 7
strREPO = "scripts"
strBRCH = "master"
strDIR = "MSP Backups"
''DEFAULT 'BLNRUN' FLAG - RESTART BACKUPS IF WRITERS ARE STABLE
blnRUN = false
''SET EXECUTION FLAG
strRUN = "false"
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
if (objFSO.fileexists("C:\temp\MSP_ARCHIVE")) then          ''LOGFILE EXISTS
  objFSO.deletefile "C:\temp\MSP_ARCHIVE", true
  set objLOG = objFSO.createtextfile("C:\temp\MSP_ARCHIVE")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\MSP_ARCHIVE", 8)
else                                                        ''LOGFILE NEEDS TO BE CREATED
  set objLOG = objFSO.createtextfile("C:\temp\MSP_ARCHIVE")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\MSP_ARCHIVE", 8)
end if
''CHECK FOR MSP BACKUP MANAGER CLIENTTOOL , REF #76
if (objFSO.fileexists("C:\Program Files\Backup Manager\clienttool.exe")) then
  call LOGERR(0)                                            ''CLIENTTOOL.EXE PRESENT, CONTINUE SCRIPT, 'ERRRET'=0
elseif (not objFSO.fileexists("C:\Program Files\Backup Manager\clienttool.exe")) then
  call LOGERR(1)                                            ''CLIENTTOOL.EXE NOT PRESENT, END SCRIPT, 'ERRRET'=1
end if
''READ PASSED COMMANDLINE ARGUMENTS
if (wscript.arguments.count > 0) then                       ''ARGUMENTS WERE PASSED
  for x = 0 to (wscript.arguments.count - 1)
    objOUT.write vbnewline & now & vbtab & "ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & objARG.item(x)
    objLOG.write vbnewline & now & vbtab & "ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & objARG.item(x)
  next
  ''SET SERVICE / CONFIGURATION OPTIONS
  if (wscript.arguments.count = 7) then                     ''ALL ARGUMENTS PASSED
    strNAM = objARG.item(0)                                 ''SET ARCHIVE SCHEDULE NAME
    strACT = objARG.item(1)                                 ''SET ARCHIVE SCHEDULE ACTIVE
    strDAT = objARG.item(2)                                 ''SET ARCHIVE DATASOURCES
    strDAY = objARG.item(3)                                 ''SET ARCHIVE DAYS OF MONTH
    strMON = objARG.item(4)                                 ''SET ARCHIVE MONTHS
    strTIM = objARG.item(5)                                 ''SET ARCHIVE TIME
    strRUN = objARG.item(6)                                 ''SET SCRIPT RUN LEVEL
    if (strRUN = "true") then
      strARC = "Y"                                          ''SET SCRIPT RUN LEVEL
    end if
  elseif (wscript.arguments.count <= 6) then                ''NOT ENOUGH ARGUMENTS PASSED , 'ERRRET'=2
    call LOGERR(2)
  end if
elseif (wscript.arguments.count = 0) then                   ''NO ARGUMENTS PASSED , 'ERRRET'=3
  call LOGERR(2)
end if

''------------
''BEGIN SCRIPT
if ((errRET = 0) or (errRET = 2)) then
  objOUT.write vbnewline & now & " - STARTING MSP_ARCHIVE" & vbnewline
  objLOG.write vbnewline & now & " - STARTING MSP_ARCHIVE" & vbnewline
	''AUTOMATIC UPDATE, MSP_ARCHIVE.VBS, REF #2 , REF #69 , REF #68
  objOUT.write vbnewline & now & vbtab & vbtab & " - CHECKING FOR UPDATE : MSP_ARCHIVE : " & strVER
  objLOG.write vbnewline & now & vbtab & vbtab & " - CHECKING FOR UPDATE : MSP_ARCHIVE : " & strVER
  ''DOWNLOAD CHKAU.VBS SCRIPT, REF #2 , REF #69 , REF #68
  call FILEDL("https://raw.githubusercontent.com/CW-Khristos/scripts/master/chkAU.vbs", "C:\IT\Scripts", "chkAU.vbs")
  ''EXECUTE CHKAU.VBS SCRIPT, REF #69
  intRET = objWSH.run ("cmd.exe /C " & chr(34) & "cscript.exe " & chr(34) & "C:\IT\Scripts\chkAU.vbs" & chr(34) & " " & _
    chr(34) & strREPO & chr(34) & " " & chr(34) & strBRCH & chr(34) & " " & chr(34) & strDIR & chr(34) & " " & _
    chr(34) & wscript.scriptname & chr(34) & " " & chr(34) & strVER & chr(34) & " " & _
    chr(34) & strNAM & "|" & strACT & "|" & strDAT & "|" & strDAY & "|" & strMON & "|" & strTIM & "|" & strRUN & chr(34) & chr(34), 0, true)
  ''CHKAU RETURNED - NO UPDATE FOUND , REF #2 , REF #69 , REF #68
  objOUT.write vbnewline & "errRET='" & intRET & "'"
  objLOG.write vbnewline & "errRET='" & intRET & "'"
  intRET = (intRET - vbObjectError)
  objOUT.write vbnewline & "errRET='" & intRET & "'"
  objLOG.write vbnewline & "errRET='" & intRET & "'"
  if ((intRET = 4) or (intRET = 10) or (intRET = 11) or (intRET = 1) or (intRET = 2147221505) or (intRET = 2147221517)) then
    ''ENTER CALL VERIFY LOOP
    call VERIFY()
  end if
elseif (errRET <> 0) then
  call LOGERR(errRET)
end if
''END SCRIPT
call CLEANUP()
''END SCRIPT
''------------

''SUB-ROUTINES
sub VERIFY()                                                ''CALL HOOK TO VERIFY SCRIPT CONFIGURATIONS, RUNS IN A LOOP UNTIL EXECUTION / TERMINATION
  if (wscript.arguments.count = 0) then                     ''SCRIPT NOT PRE-CONFIGURED
    strSEL = vbnullstring
    ''ENABLE MSP BACKUP ARCHIVES, REQUIRES INPUT
    if (strARC = vbnullstring) then
      objOUT.write vbnewline & vbtab & "ENABLE MSP BACKUP ARCHIVES (Y / N)?"
      objLOG.write vbnewline & vbtab & "ENABLE MSP BACKUP ARCHIVES (Y / N)?"
      strSEL = objIN.readline
      strARC = strSEL
      if (ucase(strSEL) = "Y") then
        objOUT.write vbnewline & vbtab & "ENABLE MSP BACKUP ARCHIVES : " & strARC
        objLOG.write vbnewline & vbtab & "ENABLE MSP BACKUP ARCHIVES : " & strARC
      end if
    elseif (strARC <> vbnullstring) then
      objOUT.write vbnewline & vbtab & "ENABLE MSP BACKUP ARCHIVES : " & strARC
      objLOG.write vbnewline & vbtab & "ENABLE MSP BACKUP ARCHIVES : " & strARC
    end if
    strSEL = vbnullstring
  elseif (wscript.arguments.count > 0) then                 ''SCRIPT PRE-CONFIGURED
    ''PLACEHOLDER
  end if
  ''EXECUTION CHECK, REQUIRES INPUT
  if (lcase(strRUN) <> "true") then
    objOUT.write vbnewline & vbnewline & vbtab & "EXECUTE SCRIPT WITH CONFIGURED SETTINGS (Y / N)"
    objLOG.write vbnewline & vbnewline & vbtab & "EXECUTE SCRIPT WITH CONFIGURED SETTINGS (Y / N)"
    strSEL = objIN.readline
    if (ucase(strSEL) = "Y") then
      strRUN = "true"
      objOUT.write vbnewline & vbnewline & now & " - EXECUTING MSP_ARCHIVE SCRIPT" & vbnewline
      objLOG.write vbnewline & vbnewline & now & " - EXECUTING MSP_ARCHIVE SCRIPT" & vbnewline
      ''EXIT VERIFY LOOP, RUN SCRIPT EXECUTION
      call EXECUTE()
    elseif (ucase(strSEL) = "N") then
      strRUN = "false"
      objOUT.write vbnewline & vbnewline & now & " - SKIPPING SCRIPT EXECUTION" & vbnewline
      objLOG.write vbnewline & vbnewline & now & " - SKIPPING SCRIPT EXECUTION" & vbnewline
      ''RETURN CALL TO VERIFY LOOP, REQUIRES INPUT
      call VERIFY()
    end if
  elseif (lcase(strRUN) = "true") then
    ''EXIT VERIFY LOOP, RUN SCRIPT EXECUTION
    call EXECUTE()
  end if
end sub

sub EXECUTE()                                               ''CALL HOOK TO EXECUTE SCRIPT CHANGES
  if (strRUN = "true") then
    ''PAUSE TO ENABLE MSP BACKUP ARCHIVES
    if (lcase(strARC) = "y") then
      ''CHECK MSP BACKUP STATUS VIA MSP BACKUP CLIENTTOOL UTILITY AFTER RESTART
      for intLOOP = 0 to 10
        objOUT.write vbnewline & now & vbtab & " - CHECKING MSP BACKUP STATUS"
        objLOG.write vbnewline & now & vbtab & " - CHECKING MSP BACKUP STATUS"
        set objHOOK = objWSH.exec(chr(34) & "c:\Program Files\Backup Manager\ClientTool.exe" & chr(34) & " control.status.get")
        'strIDL = "Idle"
        strIDL = objHOOK.stdout.readall
        objOUT.write vbnewline & now & vbtab & vbtab & vbtab & strIDL
        objLOG.write vbnewline & now & vbtab & vbtab & vbtab & strIDL
        set objHOOK = nothing
        ''SERVICE NOT STARTED
        if (strIDL = vbnullstring) then
          objOUT.write vbnewline & now & vbtab & " - CLIENTTOOL NOT READY, RESTARTING BACKUP SERVICE"
          objLOG.write vbnewline & now & vbtab & " - CLIENTTOOL NOT READY, RESTARTING BACKUP SERVICE"
          call HOOK("net start " & chr(34) & "Backup Service Controller" & chr(34))
          wscript.sleep 60000
          set objHOOK = objWSH.exec(chr(34) & "c:\Program Files\Backup Manager\ClientTool.exe" & chr(34) & " control.status.get")
          strIDL = objHOOK.stdout.readall
          objOUT.write vbnewline & now & vbtab & vbtab & vbtab & strIDL
          objLOG.write vbnewline & now & vbtab & vbtab & vbtab & strIDL
          set objHOOK = nothing
        end if
        if ((instr(1, strIDL, "Idle")) or _
          (instr(1, strIDL, "RegSync")) or (instr(1, strIDL, "Backup"))) then     			      ''ACCEPTS BACKUPS IN PROGRESS
            ''FORCE RUN OF SYSTEM STATE
            blnRUN = true
            if (blnRUN) then														                                      ''ENABLE ARCHIVING
              ''ADDITIONAL DELAY TO GIVE SERVICE A BIT EXTRA Time
              wscript.sleep (60000)
              objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "CLIENTTOOL READY, ENABLING ARCHIVING"
              objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "CLIENTTOOL READY, ENABLING ARCHIVING"
              blnRUN = true
            end if
            exit for
        elseif ((strIDL = vbnullstring) or (instr(1, strIDL, "Idle") = 0) or _
          (instr(1, strIDL, "Backup") = 0) or (instr(1, strIDL, "RegSync") = 0) or _
          (instr(1, strIDL, "Suspended"))) then					                                      ''SERVICE NOT READY
            objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "BACKUPS IN PROGRESS, SERVICE NOT READY" 
            objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "BACKUPS IN PROGRESS, SERVICE NOT READY"
            blnRUN = false
        end if
        wscript.sleep 12000
      next
      if (not blnRUN) then                                                                    ''SERVICE DID NOT INITIALIZE , 'ERRRET'=1
        objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "SERVICE NOT READY, TERMINATING" 
        objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "SERVICE NOT READY, TERMINATING"
        call LOGERR(1)
      elseif (blnRUN) then
        ''SET DEFAULT 'CW_DEFAULT_MSPARCHIVE" ARCHIVING SCHEDULE
        objOUT.write vbnewline & vbnewline & now & vbtab & " - APPLYING MSP BACKUP ARCHIVE SCHEDULE '" & strNAM & "'"
        objLOG.write vbnewline & vbnewline & now & vbtab & " - APPLYING MSP BACKUP ARCHIVE SCHEDULE '" & strNAM & "'"
        call HOOK("C:\Program Files\Backup Manager\ClientTool.exe control.archiving.add -name " & chr(34) & strNAM & chr(34) & _
          " -active " & chr(34) & strACT & chr(34) & " -datasources " & chr(34) & strDAT & chr(34) & " -days-of-month " & chr(34) & strDAY & chr(34) & _
          " -months " & chr(34) & strMON & chr(34) & " -time " & chr(34) & strTIM & chr(34))
        ''STEP TO VERIFY MSP BACKUP ARCHIVING SCHEDULE
        objOUT.write vbnewline & vbnewline & now & vbtab & " - PLEASE VERIFY MSP BACKUP ARCHIVE SCHEDULE 'CW_DEFAULT_MSPARCHIVE'"
        objOUT.write vbnewline & now & vbtab & " - VIA N-CENTRAL>CONFIGURATION>BACKUP MANAGER>MSP BACKUPS>DASHBOARD>LAUNCH BACKUP CLIENT>PREFERENCES>ARCHIVING"
        objOUT.write vbnewline & now & vbtab & " - PRESS 'ENTER' WHEN READY"
        objLOG.write vbnewline & vbnewline & now & vbtab & " - PLEASE VERIFY MSP BACKUP ARCHIVE SCHEDULE 'CW_DEFAULT_MSPARCHIVE'"
        objLOG.write vbnewline & now & vbtab & " - VIA N-CENTRAL>CONFIGURATION>BACKUP MANAGER>MSP BACKUPS>DASHBOARD>LAUNCH BACKUP CLIENT>PREFERENCES>ARCHIVING"
        if (wscript.arguments.count <> 7) then                                                ''NOT ALL ARGUMENTS PASSED
          objLOG.write vbnewline & now & vbtab & " - PRESS 'ENTER' WHEN READY"
          strNUL = objIN.readline
        end if
      end if
    end if
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
  ''ERROR RETURNED
  if (err.number <> 0) then
    objOUT.write vbnewline & now & vbtab & vbtab & err.number & vbtab & err.description
    objLOG.write vbnewline & now & vbtab & vbtab & err.number & vbtab & err.description
    call LOGERR(11)
    err.clear
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
  if (err.number <> 0) then                                 ''ERROR RETURNED DURING UPDATE CHECK , 'ERRRET'=12
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
    case 0                                                  ''MSP_ARCHIVE - CLIENTTOOL CHECK PASSED, 'ERRRET'=0
      objOUT.write vbnewline & vbnewline & now & vbtab & " - MSP_ARCHIVE - CLIENTTOOL CHECK PASSED"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - MSP_ARCHIVE - CLIENTTOOL CHECK PASSED"
    case 1                                                  ''MSP_ARCHIVE - CLIENTTOOL CHECK FAILED, 'ERRRET'=1
      objOUT.write vbnewline & vbnewline & now & vbtab & " - MSP_ARCHIVE - CLIENTTOOL CHECK FAILED, ENDING MSP_ARCHIVE"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - MSP_ARCHIVE - CLIENTTOOL CHECK FAILED, ENDING MSP_ARCHIVE"
    case 2                                                  ''MSP_ARCHIVE - NO / NOT ENOUGH ARGUMENTS PASSED, 'ERRRET'=2
      objOUT.write vbnewline & vbnewline & now & vbtab & " - MSP_ARCHIVE - NO / NOT ENOUGH ARGUMENTS PASSED"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - MSP_ARCHIVE - NO / NOT ENOUGH ARGUMENTS PASSED"
      objOUT.write vbnewline & vbnewline & now & vbtab & " - MSP_ARCHIVE - NO ARGUMENTS PASSED. SCRIPT WILL REQUEST SETTINGS DURING EXECUTION"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - MSP_ARCHIVE - NO ARGUMENTS PASSED. SCRIPT WILL REQUEST SETTINGS DURING EXECUTION"
    case 11                                                 ''MSP_ARCHIVE - CALL FILEDL() , 'ERRRET'=11
      objOUT.write vbnewline & vbnewline & now & vbtab & " - MSP_ARCHIVE - CALL FILEDL() : " & strSAV
      objLOG.write vbnewline & vbnewline & now & vbtab & " - MSP_ARCHIVE - CALL FILEDL() : " & strSAV
    case 12                                                 ''MSP_ARCHIVE - 'VSS CHECKS' - MAX ITERATIONS REACHED , 'ERRRET'=12
      objOUT.write vbnewline & vbnewline & now & vbtab & " - MSP_ARCHIVE - CALL HOOK('STRCMD') : " & strCMD & " : FAILED"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - MSP_ARCHIVE - CALL HOOK('STRCMD') : " & strCMD & " : FAILED"
  end select
end sub

sub CLEANUP()                                 			        ''SCRIPT CLEANUP
  on error resume next
  if (errRET = 0) then         											        ''MSP_ARCHIVE COMPLETED SUCCESSFULLY
    objOUT.write vbnewline & vbnewline & now & vbtab & " - MSP_ARCHIVE SUCCESSFUL : " & now
    objLOG.write vbnewline & vbnewline & now & vbtab & " - MSP_ARCHIVE SUCCESSFUL : " & now
    err.clear
  elseif (errRET <> 0) then    											        ''MSP_ARCHIVE FAILED
    objOUT.write vbnewline & vbnewline & now & vbtab & " - MSP_ARCHIVE FAILURE : " & errRET & " : " & now
    objLOG.write vbnewline & vbnewline & now & vbtab & " - MSP_ARCHIVE FAILURE : " & errRET & " : " & now
    ''RAISE CUSTOMIZED ERROR CODE, ERROR CODE WILL BE DEFINE RESTOP NUMBER INDICATING WHICH SECTION FAILED
    call err.raise(vbObjectError + errRET, "MSP_ARCHIVE", "FAILURE")
  end if
  objOUT.write vbnewline & vbnewline & now & " - MSP_ARCHIVE COMPLETE" & vbnewline
  objLOG.write vbnewline & vbnewline & now & " - MSP_ARCHIVE COMPLETE" & vbnewline
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