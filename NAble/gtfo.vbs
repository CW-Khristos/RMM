''GTFO.VBS
''DESIGNED TO AUTOMATE LEAVING DOMAIN AND SETTING IP / DNS TO AUTOMATIC
''WRITTEN BY : CJ BLEDSOE / CJ<@>THECOMPUTERWARRIORS.COM
on error resume next
''SCRIPT VARIABLES
dim errRET, strVER
dim arrNET(), intNET
''VARIABLES ACCEPTING PARAMETERS
dim strIN, strOUT, strRCMD
dim strCID, strCNM, strSVR
''SCRIPT OBJECTS
dim objLOG, objEXEC, objHOOK, objHTTP
dim objIN, objOUT, objARG, objWSH, objFSO
''INITIALIZE ARRNET()
intNET = 0
redim arrNET(0)
''DEFAULT SUCCESS
errRET = 0
''VERSION FOR SCRIPT UPDATE , GTFO.VBS , REF #2 , REF #68 , REF #69
strVER = 1
strREPO = "scripts"
strBRCH = "master"
strDIR = vbnullstring
''STDIN / STDOUT
set objIN = wscript.stdin
set objOUT = wscript.stdout
set objARG = wscript.arguments
''OBJECTS FOR LOCATING FOLDERS
set objWSH = createobject("wscript.shell")
set objFSO = createobject("scripting.filesystemobject")
''PREPARE LOGFILE
if (objFSO.fileexists("C:\temp\gtfo")) then                 ''LOGFILE EXISTS
  objFSO.deletefile "C:\temp\gtfo", true
  set objLOG = objFSO.createtextfile("C:\temp\gtfo")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\gtfo", 8)
else                                                        ''LOGFILE NEEDS TO BE CREATED
  set objLOG = objFSO.createtextfile("C:\temp\gtfo")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\gtfo", 8)
end if
''READ PASSED COMMANDLINE ARGUMENTS
if (wscript.arguments.count > 0) then                       ''ARGUMENTS WERE PASSED
  for x = 0 to (wscript.arguments.count - 1)
    objOUT.write vbnewline & now & vbtab & " - ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
    objLOG.write vbnewline & now & vbtab & " - ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
  next 
  if (wscript.arguments.count > 0) then                     ''SET REQUIRED VARIABLES ACCEPTING ARGUMENTS
    if (wscript.arguments.count = 1) then                   ''NO OPTIONAL ARGUMENTS PASSED
    elseif (wscript.arguments.count = 2) then               ''OPTIONAL ARGUMENTS PASSED
      end if
    end if
  else                                                      ''NOT ENOUGH ARGUMENTS PASSED , END SCRIPT , 'ERRRET'=1
    'call LOGERR(1)
  end if
end if

''------------
''BEGIN SCRIPT
if (errRET = 0) then                                        ''ARGUMENTS PASSED, CONTINUE SCRIPT
	objOUT.write vbnewline & vbnewline & now & " - EXECUTING GTFO" & vbnewline
	objLOG.write vbnewline & vbnewline & now & " - EXECUTING GTFO" & vbnewline
	''AUTOMATIC UPDATE, GTFO.VBS, REF #2 , REF #69 , REF #68 , FIXES #9
  objOUT.write vbnewline & now & vbtab & vbtab & " - CHECKING FOR UPDATE : GTFO : " & strVER
  objLOG.write vbnewline & now & vbtab & vbtab & " - CHECKING FOR UPDATE : GTFO : " & strVER
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
    ''OBTAIN COMPUTERNAME
    set objEXEC = objWSH.exec("hostname")
    while (not objEXEC.stdout.atendofstream)
      strCMP = objEXEC.stdout.readline
      'objOUT.write vbnewline & now & vbtab & vbtab & strIN
      'objLOG.write vbnewline & now & vbtab & vbtab & strIN
      if (err.number <> 0) then
        call LOGERR(2)
      end if
    wend
    set objEXEC = nothing
    ''VERIFY NETWORK WORKGROUP / DOMAIN SETTINGS
    set objEXEC = objWSH.exec("net config workstation")
    while (not objEXEC.stdout.atendofstream)
      strIN = objEXEC.stdout.readline
      'objOUT.write vbnewline & now & vbtab & vbtab & strIN
      'objLOG.write vbnewline & now & vbtab & vbtab & strIN
      if ((trim(strIN) <> vbnullstring) and (instr(1, lcase(strIN), "logon domain"))) then
        objOUT.write vbnewline & now & vbtab & vbtab & strIN
        objLOG.write vbnewline & now & vbtab & vbtab & strIN
        strDMN = (split(strIN, " ")(ubound(split(strIN, " "))))
      end if
      if (err.number <> 0) then
        call LOGERR(3)
      end if
    wend
    set objEXEC = nothing
    ''LEAVE DOMAIN - REQUIRES CREDENTIALS
    objOUT.write vbnewline & now & vbtab & vbtab & " - LEAVING DOMAIN"
    objLOG.write vbnewline & now & vbtab & vbtab & " - LEAVING DOMAIN"
    call HOOK("netdom remove " & strCMP & " /domain:" & strDMN)
    ''RESET DNS
    objOUT.write vbnewline & now & vbtab & vbtab & " - RESETTING DNS"
    objLOG.write vbnewline & now & vbtab & vbtab & " - RESETTING DNS"
    set objEXEC = objWSH.exec("netsh interface show interface")
    while (not objEXEC.stdout.atendofstream)
      strIN = objEXEC.stdout.readline
      'objOUT.write vbnewline & now & vbtab & vbtab & strIN
      'objLOG.write vbnewline & now & vbtab & vbtab & strIN
      if ((strIN <> vbnullstring) and (instr(1, lcase(strIN), "enabled"))) then
        ''INCREMENT NETWORK ADAPTER COUNT, REDIM ARRNET()
        intNET = intNET + 1
        redim arrNET(intNET)
        objOUT.write vbnewline & now & vbtab & vbtab & strIN
        objLOG.write vbnewline & now & vbtab & vbtab & strIN
        arrNET(intNET - 1) = trim(split(strIN, " ")(ubound(split(strIN, " "))))
      end if
      if (err.number <> 0) then
        call LOGERR(5)
      end if
    wend
    set objEXEC = nothing
    ''ENUMERATE NETWORK ADDAPTERS, RESET DNS ON EACH
    for intNET = 0 to ubound(arrNET)
      if (arrNET(intNET) <> vbnullstring) then
        objOUT.write vbnewline & now & vbtab & vbtab & vbtab & " - " & arrNET(intNET)
        objLOG.write vbnewline & now & vbtab & vbtab & vbtab & " - " & arrNET(intNET)
        call HOOK("netsh interface ip set dns " & chr(34) & arrNET(intNET) & chr(34) & " dhcp")
        call HOOK("netsh interface ip set dnsservers name=" & chr(34) & arrNET(intNET) & chr(34) & " source=dhcp")
      end if
    next
  end if
elseif (errRET <> 0) then                                   ''NO ARGUMENTS PASSED, END SCRIPT , 'ERRRET'=1
  call LOGERR(errRET)
end if
''END SCRIPT
call CLEANUP()
''END SCRIPT
''------------

''SUB-ROUTINES
sub FILEDL(strURL, strDL, strFILE)                          ''CALL HOOK TO DOWNLOAD FILE FROM URL , 'ERRRET'=11
  strSAV = vbnullstring
  ''SET DOWNLOAD PATH
  strSAV = strDL & "\" & strFILE
  objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & vbtab & "HTTPDOWNLOAD-------------DOWNLOAD : " & strURL & " : SAVE AS :  " & strSAV
  objLOG.write vbnewline & vbnewline & now & vbtab & vbtab & vbtab & "HTTPDOWNLOAD-------------DOWNLOAD : " & strURL & " : SAVE AS :  " & strSAV
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
    case 1                                                  '' 'ERRRET'=1 - NOT ENOUGH ARGUMENTS
      objOUT.write vbnewline & vbnewline & now & vbtab & " - NOT ENOUGH ARGUMENTS"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - NOT ENOUGH ARGUMENTS"
  end select
end sub

sub CLEANUP()                                               ''SCRIPT CLEANUP
  if (errRET = 0) then         															''GTFO COMPLETED SUCCESSFULLY
    objOUT.write vbnewline & "GTFO SUCCESSFUL : " & errRET & " : " & now
    err.clear
  elseif (errRET <> 0) then    															''GTFO FAILED
    objOUT.write vbnewline & "GTFO FAILURE : " & errRET & " : " & now
    ''RAISE CUSTOMIZED ERROR CODE, ERROR CODE WILL BE DEFINE RESTOP NUMBER INDICATING WHICH SECTION FAILED
    call err.raise(vbObjectError + errRET, "GTFO", "FAILURE")
  end if
  objOUT.write vbnewline & vbnewline & now & " - GTFO COMPLETE" & vbnewline
  objLOG.write vbnewline & vbnewline & now & " - GTFO COMPLETE" & vbnewline
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