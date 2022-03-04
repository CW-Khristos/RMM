''CCLUTTER.VBS
''DO NOT RUN UNDER 'USER' CONTEXT; THIS WILL TARGET THE USER'S 'APPDATA\LOCAL\TEMP' FOLDER
''DESIGNED TO CLEAR SPECIFIC TEMP, LOG, AND PROGRAM DATA DIRECTORIES AS A MINIMAL DISK CLEANUP ROUTINE
''ACCEPTS 2 PARAMETERS
''OPTIONAL PARAMETER : 'BLNLOG' , BOOLEAN TO SET LOGGING
''OPTIONAL PARAMETER : 'STRFOL' , STRING TO SET TARGET FOLDER FOR CLEANUP
''WRITTEN BY : CJ BLEDSOE / CBLEDSOE<@>IPMCOMPUTERS.COM
on error resume next
''SCRIPT VARIABLES
dim strVER, errRET
dim strREPO, strBRCH, strDIR, strNEW
dim colFOL(49), blnLOG, lngSIZ, strFOL
''SCRIPT OBJECTS
dim objLOG, objHOOK, objHTTP
dim objIN, objOUT, objARG, objWSH, objFSO, objFOL
''VERSION FOR SCRIPT UPDATE, CCLUTTER.VBS, REF #2 , REF #68 , REF #69 , REF #72
strVER = 10
strREPO = "scripts"
strBRCH = "master"
strDIR = vbnullstring
''DEFAULT SUCCESS
errRET = 0
''STDIN / STDOUT
set objIN = wscript.stdin
set objOUT = wscript.stdout
set objARG = wscript.arguments
''OBJECTS FOR LOCATING FOLDERS
set objWSH = createobject("wscript.shell")
set objFSO = createobject("scripting.filesystemobject")
''ENVIRONMENT VARIABLES
strWFOL = objWSH.expandenvironmentstrings("%windir%")
strTFOL = objWSH.expandenvironmentstrings("%temp%")
strPDFOL = objWSH.expandenvironmentstrings("%programdata%")
strPFFOL = objWSH.expandenvironmentstrings("%programfiles%")
str86FOL = objWSH.expandenvironmentstrings("%programfiles(x86)%")
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
''FILESIZE COUNTER
lngSIZ = 0
''SET BLNLOG TO 'TRUE' TO ENABLE A TEXT LOG
''THIS SHOULD ONLY BE USED IF NEEDED
''PREFERRABLY USING CSCRIPT.EXE CCLUTTER.VBS FROM COMMAND-LINE
blnLOG = true
''CHECK EXECUTION METHOD OF SCRIPT
strIN = lcase(mid(wscript.fullname, instrrev(wscript.fullname, "\") + 1))
if (strIN <> "cscript.exe") Then
  objOUT.write vbnewline & "SCRIPT LAUNCHED VIA EXPLORER, EXECUTING SCRIPT VIA CSCRIPT..."
  objWSH.run "cscript.exe //nologo " & chr(34) & Wscript.ScriptFullName & chr(34)
  wscript.quit
end if
''COLLECTION OF FOLDERS TO CHECK
''THESE FOLDERS REQUIRE RETRIEVAL FROM ENVIRONMENTAL VARIABLES
''PROGRAMDATA
colFOL(0) = strTFOL
colFOL(1) = strWFOL & "\Logs\CBS"
colFOL(2) = strWFOL & "\SoftwareDistribution"
colFOL(3) = strPDFOL & "\Sentinel\logs"
colFOL(4) = strPDFOL & "\MXB\Backup Manager\logs"
colFOL(5) = strPDFOL & "\GetSupportService\logs"
colFOL(6) = strPDFOL & "\GetSupportService_N-Central\logs"
colFOL(7) = strPDFOL & "\GetSupportService_N-Central\Updates"
colFOL(8) = strPDFOL & "\MspPlatform\FileCacheServiceAgent\cache"
colFOL(9) = strPDFOL & "\MspPlatform\FileCacheServiceAgent\log"
colFOL(10) = strPDFOL & "\MspPlatform\PME\log"
colFOL(11) = strPDFOL & "\MspPlatform\PME.Agent.PmeService\log"
colFOL(12) = strPDFOL & "\MspPlatform\RequestHandlerAgent\log"
colFOL(13) = strPDFOL & "\MspPlatform\SolarWinds.MSP.CacheService\log"
colFOL(14) = strPDFOL & "\MspPlatform\SolarWinds.MSP.RpcServerService\log"
colFOL(15) = strPDFOL & "\N-Able Technologies\AVDefender\Logs"
colFOL(16) = strPDFOL & "\N-able Technologies\AutomationManager\Logs"
colFOL(17) = strPDFOL & "\N-able Technologies\AutomationManager\temp"
colFOL(18) = strPDFOL & "\N-able Technologies\AutomationManager\ScriptResults"
colFOL(19) = strPDFOL & "\SolarWinds MSP\AutomationManager\Logs"
colFOL(20) = strPDFOL & "\SolarWinds MSP\Ecosystem Agent\log"
colFOL(21) = strPDFOL & "\SolarWinds MSP\PME\log"
colFOL(22) = strPDFOL & "\SolarWinds MSP\SolarWinds.MSP.Diagnostics\Logs"
colFOL(23) = strPDFOL & "\SolarWinds MSP\SolarWinds.MSP.CacheService\log"
colFOL(24) = strPDFOL & "\SolarWinds MSP\SolarWinds.MSP.PME.Agent.PmeService\log"
colFOL(25) = strPDFOL & "\SolarWinds MSP\SolarWinds.MSP.RpcServerService\log"
''PROGRAM FILES (X86)
colfol(26) = str86FOL & "\N-able Technologies\Reactive\Log"
colfol(27) = str86FOL & "\N-able Technologies\Tools\Log"
colfol(28) = str86FOL & "\N-able Technologies\Windows Agent\Log"
colfol(29) = str86FOL & "\N-able Technologies\Windows Software Probe\Log"
colfol(30) = str86FOL & "\N-able Technologies\Windows Software Probe\syslog\Log"
''THESE FOLDERS ARE NORMAL FOLDER PATHS
colFOL(31) =  "C:\temp"
colFOL(32) = "C:\inetpub\logs\LogFiles\W3SVC2"
colfol(33) = "C:\inetpub\logs\LogFiles\W3SVC1"
''EXCHANGE LOGGING FOLDERS
if (objFSO.folderexists(strPFFOL & "\Microsoft\Exchange Server")) then
  colFOL(34) = strPFFOL & "\Microsoft\Exchange Server\V15\Logging\Diagnostics\AnalyzerLogs"
  colFOL(35) = strPFFOL & "\Microsoft\Exchange Server\V15\Logging\Diagnostics\CertificateLogs"
  colFOL(36) = strPFFOL & "\Microsoft\Exchange Server\V15\Logging\Diagnostics\CosmosLog"
  colFOL(37) = strPFFOL & "\Microsoft\Exchange Server\V15\Logging\Diagnostics\DailyPerformanceLogs"
  colFOL(38) = strPFFOL & "\Microsoft\Exchange Server\V15\Logging\Diagnostics\Dumps"
  colFOL(39) = strPFFOL & "\Microsoft\Exchange Server\V15\Logging\Diagnostics\EtwTraces"
  colFOL(40) = strPFFOL & "\Microsoft\Exchange Server\V15\Logging\Diagnostics\Poison"
  colFOL(41) = strPFFOL & "\Microsoft\Exchange Server\V15\Logging\Diagnostics\ServiceLogs"
  colFOL(42) = strPFFOL & "\Microsoft\Exchange Server\V15\Logging\Diagnostics\Watermarks"
  colFOL(43) = strPFFOL & "\Microsoft\Exchange Server\V15\Logging\MailboxAssistantsLog"
  colFOL(44) = strPFFOL & "\Microsoft\Exchange Server\V15\Logging\MailboxAssociationLog"
  colFOL(45) = strPFFOL & "\Microsoft\Exchange Server\V15\Logging\MigrationMonitorLogs"
  colFOL(46) = strPFFOL & "\Microsoft\Exchange Server\V15\Logging\RpcHttp\W3SVC1"
  colFOL(47) = strPFFOL & "\Microsoft\Exchange Server\V15\Logging\RpcHttp\W3SVC2"
  colFOL(48) = strPFFOL & "\Microsoft\Exchange Server\V15\Logging\HttpProxy\RpcHttp"
end if

''------------
''BEGIN SCRIPT
if (errRET = 0) then
  ''CREATE LOGFILE, IF ENABLED
  if (wscript.arguments.count > 0) then                                             ''CHECK LOGGING ARGUMENT
    blnLOG = objARG.item(0)
  elseif (wscript.arguments.count = 0) then                                         ''LOGGING ARGUMENT NOT PASSED
    blnLOG = false
  end if
  if (blnLOG) then
    if (objFSO.fileexists("C:\temp\cclutter.txt")) then                             ''LOGFILE EXISTS
      objFSO.deletefile "C:\temp\cclutter.txt", true
      set objLOG = objFSO.createtextfile("C:\temp\cclutter.txt")
      objLOG.close
      set objLOG = objFSO.opentextfile("C:\temp\cclutter.txt", 8)
    else                                                                            ''LOGFILE NEEDS TO BE CREATED
      set objLOG = objFSO.createtextfile("C:\temp\cclutter.txt")
      objLOG.close
      set objLOG = objFSO.opentextfile("C:\temp\cclutter.txt", 8)
    end if
  end if
  ''READ PASSED COMMANDLINE ARGUMENTS
  if (wscript.arguments.count > 0) then                                             ''ARGUMENTS WERE PASSED
    for x = 0 to (wscript.arguments.count - 1)
      objOUT.write vbnewline & "ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
      objLOG.write vbnewline & "ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
    next
    if (wscript.arguments.count > 1) then                                           ''SET REQUIRED ARGUMENTS
      blnLOG = objARG.item(0)
      strFOL = objARG.item(1)
    elseif (wscript.arguments.count <= 1) then                                      ''NOT ENOUGH ARGUMENTS PASSED, DO NOT CREATE LOGFILE, NO CUSTOM DESTINATION
      blnLOG = objARG.item(0)
    end if
  elseif (wscript.arguments.count = 0) then                                         ''NO ARGUMENTS PASSED, DO NOT CREATE LOGFILE, NO CUSTOM DESTINATION
    blnLOG = false
  end if
	objOUT.write vbnewline & vbnewline & now & vbtab & " - EXECUTING CCLUTTER"
	objLOG.write vbnewline & vbnewline & now & vbtab & " - EXECUTING CCLUTTER"
  ''AUTOMATIC UPDATE, CCLUTTER.VBS, REF #2 , REF #69 , REF #68 , REF #72
  objOUT.write vbnewline & now & vbtab & vbtab & " - CHECKING FOR UPDATE : CCLUTTER : " & strVER
  objLOG.write vbnewline & now & vbtab & vbtab & " - CHECKING FOR UPDATE : CCLUTTER : " & strVER
  ''DOWNLOAD CHKAU.VBS SCRIPT, REF #2 , REF #69 , REF #68
  call FILEDL("https://raw.githubusercontent.com/CW-Khristos/scripts/master/chkAU.vbs", "C:\IT\Scripts", "chkAU.vbs")
  ''EXECUTE CHKAU.VBS SCRIPT, REF #69
  intRET = objWSH.run ("cmd.exe /C " & chr(34) & "cscript.exe " & chr(34) & "C:\IT\Scripts\chkAU.vbs" & chr(34) & " " & _
    chr(34) & strREPO & chr(34) & " " & chr(34) & strBRCH & chr(34) & " " & chr(34) & strDIR & chr(34) & " " & _
    chr(34) & wscript.scriptname & chr(34) & " " & chr(34) & strVER & chr(34) & " " & _
    chr(34) & blnLOG & "|" & strFOL & chr(34) & chr(34), 0, true)
  ''CHKAU RETURNED - NO UPDATE FOUND , REF #2 , REF #69 , REF #68
  objOUT.write vbnewline & "errRET='" & intRET & "'"
  objLOG.write vbnewline & "errRET='" & intRET & "'"
  intRET = (intRET - vbObjectError)
  objOUT.write vbnewline & "errRET='" & intRET & "'"
  objLOG.write vbnewline & "errRET='" & intRET & "'"
  if ((intRET = 4) or (intRET = 10) or (intRET = 11) or (intRET = 1) or (intRET = 2147221505) or (intRET = 2147221517)) then
    objOUT.write vbnewline & now & vbtab & vbtab & " - NO UPDATE FOUND : CCLUTTER : " & strVER
    objLOG.write vbnewline & now & vbtab & vbtab & " - NO UPDATE FOUND : CCLUTTER : " & strVER
    ''USE ICACLS TO 'RESET' PERMISSIONS ON C:\WINDOWS\TEMP
    call HOOK("cmd.exe /C icacls C:\Windows\Temp /grant administrators:f")
    ''USE ICACLS TO 'RESET' PERMISSIONS ON C:\PROGRAMDATA\SENTINEL\LOGS
    call HOOK("cmd.exe /C icacls C:\ProgramData\Sentinel\logs /grant administrators:f")
    ''ENUMERATE THROUGH FOLDER COLLECTION
    for x = 0 to ubound(colFOL)
      if (colFOL(x) <> vbnullstring) then                                         ''ENSURE COLFOL(X) IS NOT EMPTY
        if (objFSO.folderexists(colFOL(x))) then                                  ''ENSURE FOLDER EXISTS BEFORE CLEARING
          set objFOL = objFSO.getfolder(colFOL(x))
          strNEW = vbnewline & "CLEARING : " & objFOL.path
          objOUT.write strNEW
          if (blnLOG) then                                                        ''WRITE TO LOGFILE, IF ENABLED
            objLOG.write strNEW
          end if
          ''CLEAR NORMAL FOLDERS
          if (objFOL.path <> strWFOL & "\SoftwareDistribution") then
            strNEW = vbnewline & "CLEARING : " & objFOL.path
            objOUT.write strNEW
            if (blnLOG) then                                                      ''WRITE TO LOGFILE, IF ENABLED
              objLOG.write strNEW
            end if
            call cFolder(objFOL)
          ''CLEARING WINDOWS UPDATES
          elseif (objFOL.path = strWFOL & "\SoftwareDistribution") then
            ''CHECK FOR 'PENDING.XML IF CLEARING SOFTWAREDISTRIBUTION
            if (objFSO.fileexists(strWFOL & "\WinSxS\pending.xml")) then
              strNEW = vbnewline & "'PENDING.XML' FOUND : SKIPPING : " & objFOL.path
              objOUT.write strNEW
              if (blnLOG) then                                                    ''WRITE TO LOGFILE, IF ENABLED
                objLOG.write strNEW
              end if
            elseif (not (objFSO.fileexists(strWFOL & "\WinSxS\pending.xml"))) then
              strNEW = vbnewline & "'PENDING.XML' NOT FOUND : CLEARING : " & objFOL.path
              objOUT.write strNEW
              if (blnLOG) then                                                    ''WRITE TO LOGFILE, IF ENABLED
                objLOG.write strNEW
              end if
              ''STOP WINDOWS UPDATE SERVICE TO CLEAR WINDOWS UPDATE FOLDER
              call HOOK("net stop wuauserv /y")
              call cFolder(objFOL)
              ''RESTART WINDOWS UPDATE SERVICE
              call HOOK("net start wuauserv")
            end if
          end if
        else                                                                      ''NON-EXISTENT FOLDER
          strNEW = vbnewline & "NON-EXISTENT : " & colFOL(x)
          objOUT.write strNEW
          if (blnLOG) then                                                        ''WRITE TO LOGFILE, IF ENABLED
            objLOG.write strNEW
          end if
        end if
      end if
    next
    ''FINAL CLEANUP OF NCENTRAL PROGRAM LOGS
    objOUT.write vbnewline & now & vbtab & vbtab & " - FINAL CLEANUP : "
    objLOG.write vbnewline & now & vbtab & vbtab & " - FINAL CLEANUP : "
    call HOOK("cmd.exe /c " & chr(34) & "DIR " & chr(34) & "C:\ProgramData\*.bdinstall.bin" & chr(34) & chr(34))
    call HOOK("cmd.exe /c " & chr(34) & "DEL /S /Q " & chr(34) & "C:\ProgramData\*.bdinstall.bin" & chr(34) & chr(34))
    ''ENUMERATE THROUGH PASSED FOLDER PATH
    'if (strFOL <> vbnullstring) then
    '  if (objFSO.folderexists(strFOL)) then                                      ''ENSURE FOLDER EXISTS BEFORE CLEARING
    '    set objFOL = objFSO.getfolder(strFOL)
    '    strNEW = vbnewline & "CLEARING : " & objFOL.path
    '    objOUT.write strNEW
    '    ''WRITE TO LOGFILE, IF ENABLED
    '    if (blnLOG) then
    '      objLOG.write strNEW
    '    end if
    '    ''CLEAR CONTENTS OF FOLDER
    '    call cFolder(objFOL)
    '  else                                                                       ''NON-EXISTENT FOLDER
    '    strNEW = vbnewline & "NON-EXISTENT : " & colFOL(x)
    '    objOUT.write strNEW
    '    ''WRITE TO LOGFILE, IF ENABLED
    '    if (blnLOG) then
    '      objLOG.write strNEW
    '    end if
    '  end if
    'end if
  end if
elseif (errRET <> 0) then
  call LOGERR(errRET)
end if
''END SCRIPT
call CLEANUP()
''END SCRIPT
''------------

''SUB-ROUTINES
sub cFolder (ByVal Folder)                                                        ''SUB-ROUTINE TO CLEAR CONTENTS OF FOLDER
  ''SUB-ROUTINE IS RECURSIVE, WILL CLEAR FOLDER AND SUB-FOLDERS!
  on error resume next
  dim colFIL, colFOL
  ''DELETE FILES
  set colFIL = Folder.files
  for each objFIL in colFIL                                                       ''ENUMERATE EACH FILE
    filSIZ = round((objFIL.size / 1024), 2)
    strFIL = objFIL.path
    if (instr(strFIL, "lsv.txt") = 0) then
      objFIL.delete(True)
      if (err.number = 0) then                                                    ''SUCCESSFULLY DELETED FILE
        lngSIZ = (lngSIZ + filSIZ)
        strNEW = vbnewline & "DELETED FILE: " & strFIL
        'objOUT.write strNEW
        if (blnLOG) then                                                          ''WRITE TO LOGFILE, IF ENABLED
          objLOG.write strNEW
        end if
      elseif (err.number <> 0) then                                               ''ERROR ENCOUNTERED DELETING FILE
        strNEW = vbnewline & "ERROR : " &  err.number & vbtab & err.description & vbtab & strFIL
        objOUT.write strNEW
        if (blnLOG) then                                                          ''WRITE TO LOGFILE, IF ENABLED
          objLOG.write strNEW
        end if
      end if
    end if
  next
  ''EMPTY AND DELETE SUB-FOLDERS
  set colFOL = Folder.SubFolders
  for each subFOL in colFOL                                                       ''ENUMERATE EACH SUB-FOLDER
    strFOL = subFOL.path
    call cFolder(subFOL)
    subFOL.delete(True)
    if (err.number = 0 ) then                                                     ''SUCCESSFULLY DELETED FOLDER
      strNEW = vbnewline & "REMOVED FOLDER : " & strFOL
      objOUT.write strNEW
      if (blnLOG) then                                                            ''WRITE TO LOGFILE, IF ENABLED
        objLOG.write strNEW
      end if
    elseif (err.number <> 0) then                                                 ''ENCOUNTERED ERROR TRYING TO DELETE FOLDER
      strNEW = vbnewline & "ERROR : " &  err.number & vbtab & err.description & vbtab & strFOL
      objOUT.write strNEW
      if (blnLOG) then                                                            ''WRITE TO LOGFILE, IF ENABLED
        objLOG.write strNEW
      end if
    end if
  next
end sub

sub FILEDL(strURL, strDL, strFILE)                                                ''CALL HOOK TO DOWNLOAD FILE FROM URL , 'ERRRET'=11
  strSAV = vbnullstring
  ''SET DOWNLOAD PATH
  strSAV = strDL & "\" & strFILE
  objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & " - HTTPDOWNLOAD-------------DOWNLOAD : " & strURL & " : SAVE AS :  " & strSAV
  objLOG.write vbnewline & vbnewline & now & vbtab & vbtab & " - HTTPDOWNLOAD-------------DOWNLOAD : " & strURL & " : SAVE AS :  " & strSAV
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
    objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & " - DOWNLOAD : " & strSAV & " : SUCCESSFUL"
    objLOG.write vbnewline & vbnewline & now & vbtab & vbtab & " - DOWNLOAD : " & strSAV & " : SUCCESSFUL"
    set objHTTP = nothing
  end if
  if ((err.number <> 0) and (err.number <> 58)) then                              ''ERROR RETURNED DURING DOWNLOAD , 'ERRRET'=11
    call LOGERR(11)
  end if
end sub

sub HOOK(strCMD)                                                                  ''CALL HOOK TO MONITOR OUTPUT OF CALLED COMMAND , 'ERRRET'=12
  on error resume next
  objOUT.write vbnewline & now & vbtab & vbtab & " - EXECUTING : HOOK(" & strCMD & ")"
  objLOG.write vbnewline & now & vbtab & vbtab & " - EXECUTING : HOOK(" & strCMD & ")"
  set objHOOK = objWSH.exec(strCMD)
  while (not objHOOK.stdout.atendofstream)
    if (instr(1, strCMD, "takeown /F ") = 0) then                                 ''SUPPRESS 'TAKEOWN' SUCCESS MESSAGES
      strIN = objHOOK.stdout.readline
      if (strIN <> vbnullstring) then
        objOUT.write vbnewline & now & vbtab & vbtab & vbtab & strIN 
        objLOG.write vbnewline & now & vbtab & vbtab & vbtab & strIN 
      end if
    end if
  wend
  wscript.sleep 10
  if (instr(1, strCMD, "takeown /F ") = 0) then                                   ''SUPPRESS 'TAKEOWN' SUCCESS MESSAGES
    strIN = objHOOK.stdout.readall
    if (strIN <> vbnullstring) then
      objOUT.write vbnewline & now & vbtab & vbtab & vbtab & strIN 
      objLOG.write vbnewline & now & vbtab & vbtab & vbtab & strIN 
    end if
  end if
  set objHOOK = nothing
  if (err.number <> 0) then                                                       ''ERROR RETURNED , 'ERRRET'=12
    call LOGERR(12)
  end if
end sub

sub LOGERR(intSTG)                                                                ''CALL HOOK TO LOG AND SET ERRORS
  errRET = intSTG
  if (err.number <> 0) then
    objOUT.write vbnewline & now & vbtab & vbtab & vbtab & err.number & vbtab & err.description & vbnewline
    objLOG.write vbnewline & now & vbtab & vbtab & vbtab & err.number & vbtab & err.description & vbnewline
    err.clear
  end if
  select case intSTG
    case 1                                                                        '' 'ERRRET'=1 - NOT ENOUGH ARGUMENTS
  end select
end sub

sub CLEANUP()                                                                     ''SCRIPT CLEANUP
  if (errRET = 0) then         															                      ''CCLUTTER COMPLETED SUCCESSFULLY
    objOUT.write vbnewline & vbnewline & now & vbtab & " - CCLUTTER SUCCESSFUL : " & errRET & " : " & now
    objLOG.write vbnewline & vbnewline & now & vbtab & " - CCLUTTER SUCCESSFUL : " & errRET & " : " & now
    err.clear
  elseif (errRET <> 0) then    															                      ''CCLUTTER FAILED
    objOUT.write vbnewline & vbnewline & now & vbtab & " - CCLUTTER FAILURE : " & errRET & " : " & now
    objLOG.write vbnewline & vbnewline & now & vbtab & " - CCLUTTER FAILURE : " & errRET & " : " & now
    ''RAISE CUSTOMIZED ERROR CODE, ERROR CODE WILL BE DEFINE RESTOP NUMBER INDICATING WHICH SECTION FAILED
    call err.raise(vbObjectError + errRET, "CCLUTTER", "FAILURE")
  end if
  strNEW = vbnewline & " - CCLUTTER COMPLETE : CLEARED " & round((lngSIZ / 1024),2) & " MB"
  objOUT.write strNEW
  if (blnLOG) then                                                                ''LOGFILE CLEANUP, IF ENABLED
    objLOG.write strNEW
    objLOG.close
    ''UNCOMMENT LINES BELOW TO CAUSE LOGFILE TO OPEN AUTOMATICALLY
    'objWSH.run "C:\cclutter.txt", 1
    'wscript.sleep 1000
    ''UNCOMMENT THE FOLLOWING LINE TO DELETE LOGFILE AFTER EXECUTION
    'objFSO.deletefile "C:\cclutter.txt", true
  end if
  ''SCRIPT / OBJECT CLEANUP
  set objLOG = nothing
  set objFOL = nothing
  set objFSO = nothing
  set objOUT = nothing
  set objWSH = nothing
  ''END SCRIPT, RETURN DEFAULT NO ERROR
  wscript.quit err.number
end sub