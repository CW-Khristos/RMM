''WMI_FIX_RESTART.VBS
''DESIGNED TO EXECUTE WMI FIX PHASE 2 PROVIDED BY SOLARWINDS, THIS REQUIRES A REBOOT
''REBOOT IS NOT FORCED AND WILL BE LEFT TO BE EXECUTED AT NORMAL SCHEDULED WINDOWS
''WRITTEN BY : CJ BLEDSOE / CJ<@>THECOMPUTERWARRIORS.COM
on error resume next
''SCRIPT VARIABLES
dim errRET, strVER, strSEL
dim strIN, strOUT, strORG, strREP
''SCRIPT OBJECTS
dim objIN, objOUT, objARG, objWSH, objFSO
dim objLOG, objEXEC, objHOOK, objSIN, objSOUT
''VERSION FOR SCRIPT UPDATE, WMI_FIX_RESTART.VBS , REF #2 , REF #68 , REF #69
strVER = 4
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
''CHECK 'PERSISTENT' FOLDERS , REF #2 , REF #73
if (not (objFSO.folderexists("C:\IT\"))) then
  objFSO.createfolder("C:\IT\")
end if
if (not (objFSO.folderexists("C:\IT\Scripts\"))) then
  objFSO.createfolder("C:\IT\Scripts\")
end if
''PREPARE LOGFILE
if (objFSO.fileexists("C:\temp\WMI_FIX_RESTART")) then          ''LOGFILE EXISTS
  objFSO.deletefile "C:\temp\WMI_FIX_RESTART", true
  set objLOG = objFSO.createtextfile("C:\temp\WMI_FIX_RESTART")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\WMI_FIX_RESTART", 8)
else                                                            ''LOGFILE NEEDS TO BE CREATED
  set objLOG = objFSO.createtextfile("C:\temp\WMI_FIX_RESTART")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\WMI_FIX_RESTART", 8)
end if
''READ PASSED COMMANDLINE ARGUMENTS
if (wscript.arguments.count > 0) then                           ''ARGUMENTS WERE PASSED
  for x = 0 to (wscript.arguments.count - 1)
    objOUT.write vbnewline & now & vbtab & " - ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
    objLOG.write vbnewline & now & vbtab & " - ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
  next 
  if (wscript.arguments.count > 0) then                         ''REQUIRED ARGUMENTS PASSED
    if (wscript.arguments.count > 1) then                       ''OPTIONAL ARGUMENTS PASSED
    end if
  end if
else                                                            ''NO ARGUMENTS PASSED , END SCRIPT , 'ERRRET'=1
  'call LOGERR(1)
end if

''------------
''BEGIN SCRIPT
if (errRET = 0) then
  objOUT.write vbnewline & vbnewline & now & vbtab & " - EXECUTING WMI_FIX_RESTART"
  objLOG.write vbnewline & vbnewline & now & vbtab & " - EXECUTING WMI_FIX_RESTART"
	''AUTOMATIC UPDATE, WMI_FIX_RESTART.VBS, REF #2 , REF #69 , REF #68
  objOUT.write vbnewline & now & vbtab & vbtab & " - CHECKING FOR UPDATE : WMI_FIX_RESTART : " & strVER
  objLOG.write vbnewline & now & vbtab & vbtab & " - CHECKING FOR UPDATE : WMI_FIX_RESTART : " & strVER
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
    ''RESET WMI WEBM REPOSITORY
    call HOOK("sc config winmgmt start= disabled")
    call HOOK("net stop winmgmt /y")
    wscript.sleep 10000
    call HOOK("cmd.exe /C " & chr(34) & "ren %windir%\System32\wbem\repository repository.old" & chr(34))
    call HOOK("cmd.exe /C " & chr(34) & "Winmgmt /salvagerepository %windir%\System32\wbem" & chr(34)) 
    call HOOK("cmd.exe /C " & chr(34) & "Winmgmt /resetrepository %windir%\System32\wbem" & chr(34))
    call HOOK("sc config winmgmt start= auto")
    call HOOK("net start winmgmt")
    ''RESTART WMI DEPENDENT SERVICES, REF #19
    call CHKDEP()
    objOUT.write vbnewline & vbnewline & now & vbtab & " - WMI_FIX_RESTART APPLIED; PLEASE REBOOT"
    objLOG.write vbnewline & vbnewline & now & vbtab & " - WMI_FIX_RESTART APPLIED; PLEASE REBOOT"
  end if
elseif (errRET <> 0) then
  call LOGERR(errRET)
end if
''END SCRIPT
call CLEANUP()
''END SCRIPT
''------------

''SUB-ROUTINES
sub CHKDEP()                                                    ''RESTART WMI DEPENDENT SERVICES, REF #19
''DEPENDENT SERVICES WHICH MAY NEED RESTART AFTER RESTART OF WMI
  objOUT.write vbnewline & now & vbtab & vbtab & " - RESTARTING WMI DEPENDENT SERVICES"
  objLOG.write vbnewline & now & vbtab & vbtab & " - RESTARTING WMI DEPENDENT SERVICES"
  call HOOK("net start " & chr(34) & "Security Center" & chr(34))
  call HOOK("net start " & chr(34) & "System Update" & chr(34))
  call HOOK("net start " & chr(34) & "IP Helper" & chr(34))
  call HOOK("net start " & chr(34) & "VMware USB Arbitration Service" & chr(34))
  call HOOK("net start " & chr(34) & "Intel(R) Rapid Storage Technology" & chr(34))
  call HOOK("net start " & chr(34) & "Intel(R) PROSet/Wireless Event Log" & chr(34))
  call HOOK("net start " & chr(34) & "Intel(R) HD Graphics Control Panel Service" & chr(34))
  call HOOK("net start " & chr(34) & "Dell Foundation Services" & chr(34))
  call HOOK("net start " & chr(34) & "User Access Logging Service" & chr(34))
  call HOOK("net start " & chr(34) & "Background Intelligent Transfer Service" & chr(34))
  call HOOK("net start " & chr(34) & "System Event Notification Service" & chr(34))
end sub

sub FILEDL(strURL, strDL, strFILE)                            ''CALL HOOK TO DOWNLOAD FILE FROM URL , 'ERRRET'=11
  strSAV = vbnullstring
  ''SET DOWNLOAD PATH
  strSAV = strDL & "\" & strFILE
  objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & "HTTPDOWNLOAD-------------DOWNLOAD : " & strURL & " : SAVE AS :  " & strSAV
  objLOG.write vbnewline & vbnewline & now & vbtab & vbtab & "HTTPDOWNLOAD-------------DOWNLOAD : " & strURL & " : SAVE AS :  " & strSAV
  ''CHECK IF FILE ALREADY EXISTS
  if (objFSO.fileexists(strSAV)) then
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
  if (objFSO.fileexists(strSAV)) then
    objOUT.write vbnewline & vbnewline & now & vbtab & " - DOWNLOAD : " & strSAV & " : SUCCESSFUL"
    objLOG.write vbnewline & vbnewline & now & vbtab & " - DOWNLOAD : " & strSAV & " : SUCCESSFUL"
  end if
	set objHTTP = nothing
  if ((err.number <> 0) and (err.number <> 58)) then          ''ERROR RETURNED DURING UPDATE CHECK , 'ERRRET'=11
    call LOGERR(11)
  end if
end sub

sub HOOK(strCMD)                                                ''CALL HOOK TO MONITOR OUTPUT OF CALLED COMMAND , 'ERRRET'=12
  on error resume next
  objOUT.write vbnewline & now & vbtab & vbtab & "EXECUTING : " & strCMD
  objLOG.write vbnewline & now & vbtab & vbtab & "EXECUTING : " & strCMD
  set objHOOK = objWSH.exec(strCMD)
  if (instr(1, strCMD, "takeown /F ") = 0) then                 ''SUPPRESS 'TAKEOWN' SUCCESS MESSAGES
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
  if (err.number <> 0) then                                     ''ERROR RETURNED DURING UPDATE CHECK , 'ERRRET'=12
    call LOGERR(12)
  end if
end sub

sub LOGERR(intSTG)                                            ''CALL HOOK TO MONITOR OUTPUT OF CALLED COMMAND
  errRET = intSTG
  if (err.number <> 0) then
    objOUT.write vbnewline & now & vbtab & vbtab & vbtab & err.number & vbtab & err.description & vbnewline
    objLOG.write vbnewline & now & vbtab & vbtab & vbtab & err.number & vbtab & err.description & vbnewline
		err.clear
  end if
  ''CUSTOM ERROR CODES
  select case intSTG
    case 1                                                      '' 'ERRRET'=1 - NOT ENOUGH ARGUMENTS
      'objOUT.write vbnewline & vbnewline & now & vbtab & " - SCRIPT REQUIRES USER TO GRANT SERVICE LOGON"
      'objLOG.write vbnewline & vbnewline & now & vbtab & " - SCRIPT REQUIRES USER TO GRANT SERVICE LOGON"
  end select
end sub

sub CLEANUP()                                                   ''SCRIPT CLEANUP
  on error resume next
  if (errRET = 0) then                                          ''SCRIPT COMPLETED SUCCESSFULLY
    objOUT.write vbnewline & vbnewline & now & vbtab & " - WMI_FIX_RESTART COMPLETE : " & now
    objLOG.write vbnewline & vbnewline & now & vbtab & " - WMI_FIX_RESTART COMPLETE : " & now
    err.clear
  elseif (errRET <> 0) then                                     ''SCRIPT FAILED
    objOUT.write vbnewline & vbnewline & now & vbtab & " - WMI_FIX_RESTART FAILURE : " & errRET & " : " & now
    objLOG.write vbnewline & vbnewline & now & vbtab & " - WMI_FIX_RESTART FAILURE : " & errRET & " : " & now
    ''RAISE CUSTOMIZED ERROR CODE , ERROR CODE WILL BE DEFINED RESTOP NUMBER INDICATING WHICH SECTION FAILED
    call err.raise(vbObjectError + errRET, "WMI_FIX_RESTART", "fail")
  end if
  ''EMPTY OBJECTS
  set objEXEC = nothing
  set objLOG = nothing
  set objFSO = nothing
  set objWSH = nothing
  set objARG = nothing
  set objOUT = nothing
  set objIN = nothing
  ''END SCRIPT , RETURN ERROR
  wscript.quit err.number
end sub