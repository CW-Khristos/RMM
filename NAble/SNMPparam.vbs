''SNMPPARAM.VBS
''DESIGNED TO CONFIGURE / MONITOR SNMP CONFIGURATIONS
''ACCEPTS 3 PARAMETERS, REQUIRES 3 PARAMETERS
''REQUIRED PARAMETER : 'STRMOD', STRING TO SET SCRIPT 'MODE', THIS MUST BE THE FIRST PARAMETER PASSED
''REQUIRED PARAMETER : 'STRSNMP', STRING TO SET SNMP COMMUNITY STRING, THIS MUST BE THE SECOND PARAMETER PASSED
''REQUIRED PARAMETER : 'STRTRP', STRING TO SET SNMP TRAP AGENT, THIS MUST BE THE THIRD PARAMETER PASSED, SEPARATE MULTIPLE TRAP DESTINATIONS WITH A ','
''WRITTEN BY : CJ BLEDSOE / CJ<@>THECOMPUTERWARRIORS.COM
on error resume next
''SCRIPT VARIABLES
dim errRET, strVER
''VARIABLES ACCEPTING PARAMETERS - CONFIGURES SNMP TRAP AND COMMUNITY STRING
dim strMOD, strTRP, strSNMP
''SCRIPT OBJECTS
dim objFSO, objLOG, objHOOK
dim objIN, objOUT, objARG, objWSH
''VERSION FOR SCRIPT UPDATE, SNMPPARAM.VBS, REF #2 , REF #68 , REF #69
strVER = 8
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
if (objFSO.fileexists("C:\temp\snmpparam")) then            ''LOGFILE EXISTS
  objFSO.deletefile "C:\temp\snmpparam", true
  set objLOG = objFSO.createtextfile("C:\temp\snmpparam")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\snmpparam", 8)
else                                                        ''LOGFILE NEEDS TO BE CREATED
  set objLOG = objFSO.createtextfile("C:\temp\snmpparam")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\snmpparam", 8)
end if
''READ PASSED COMMANDLINE ARGUMENTS - REQUIRES (AT LEAST) 3 ARGUMENTS
if (wscript.arguments.count > 0) then                       ''ARGUMENTS WERE PASSED
  for x = 0 to (wscript.arguments.count - 1)
    objOUT.write vbnewline & now & vbtab & "ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
  next
  ''SCRIPT MODE OF OPERATION
  if (wscript.arguments.count > 2) then
    strMOD = objARG.item(0)
    strSNMP = objARG.item(1)
    strTRP = objARG.item(2)
  elseif (wscript.arguments.count < 1) then                 ''NOT ENOUGH ARGUMENTS PASSED , END SCRIPT , 'ERRRET'=1
    call LOGERR(1)
  end if
elseif (wscript.arguments.count = 0) then                   ''NO ARGUMENTS PASSED , END SCRIPT , 'ERRRET'=1
  'call LOGERR(1)
end if

''------------
''BEGIN SCRIPT
if (errRET = 0) then                                        ''NO ERRORS DURING INITIAL START
  objOUT.write vbnewline & vbnewline & now & vbtab & " - STARTING SNMPPARAM" & vbnewline
  objLOG.write vbnewline & vbnewline & now & vbtab & " - STARTING SNMPPARAM" & vbnewline
	''AUTOMATIC UPDATE, SNMPARAM.VBS, REF #2 , REF #69 , REF #68 , FIXES #9
  objOUT.write vbnewline & now & vbtab & vbtab & " - CHECKING FOR UPDATE : SNMPARAM : " & strVER
  objLOG.write vbnewline & now & vbtab & vbtab & " - CHECKING FOR UPDATE : SNMPARAM : " & strVER
  ''DOWNLOAD CHKAU.VBS SCRIPT, REF #2 , REF #69 , REF #68
  call FILEDL("https://raw.githubusercontent.com/CW-Khristos/scripts/master/chkAU.vbs", "C:\IT\Scripts", "chkAU.vbs")
  ''EXECUTE CHKAU.VBS SCRIPT, REF #69
  intRET = objWSH.run ("cmd.exe /C " & chr(34) & "cscript.exe " & chr(34) & "C:\IT\Scripts\chkAU.vbs" & chr(34) & " " & _
    chr(34) & strREPO & chr(34) & " " & chr(34) & strBRCH & chr(34) & " " & chr(34) & strDIR & chr(34) & " " & _
    chr(34) & wscript.scriptname & chr(34) & " " & chr(34) & strVER & chr(34) & " " & _
    chr(34) & strMOD & "|" & strSNMP & "|" & strTRP & chr(34) & chr(34), 0, true)
  ''CHKAU RETURNED - NO UPDATE FOUND , REF #2 , REF #69 , REF #68
  objOUT.write vbnewline & "errRET='" & intRET & "'"
  objLOG.write vbnewline & "errRET='" & intRET & "'"
  intRET = (intRET - vbObjectError)
  objOUT.write vbnewline & "errRET='" & intRET & "'"
  objLOG.write vbnewline & "errRET='" & intRET & "'"
  if ((intRET = 4) or (intRET = 10) or (intRET = 11) or (intRET = 1) or (intRET = 2147221505) or (intRET = 2147221517)) then
    ''SELECT MODE "QUERY" / "MODIFY"
    select case lcase(strMOD)
      ''QUERY
      case vbnullstring
        ''QUERY SNMP REGISTRY VALUES
        objOUT.write vbnewline & now & vbtab & vbtab & " - QUERYING SNMP CONFIGURATIONS"
        objLOG.write vbnewline & now & vbtab & vbtab & " - QUERYING SNMP CONFIGURATIONS"
        call HOOK("reg query " & chr(34) & "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\SNMP\Parameters" & chr(34) & " /s")
      ''CLEAR
      case "clear"
          ''CLEAR PREVIOUS SNMP CONFIGURATIONS
        objOUT.write vbnewline & now & vbtab & vbtab & " - REMOVING PREVIOUS SNMP CONFIGURATIONS"
        objLOG.write vbnewline & now & vbtab & vbtab & " - REMOVING PREVIOUS SNMP CONFIGURATIONS"    
        call HOOK("reg delete " & chr(34) & "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\SNMP\Parameters" & chr(34) & " /va /f")
      ''MODIFY
      case "modify"
        ''MODIFY SNMP REGISTRY VALUES
        objOUT.write vbnewline & now & vbtab & vbtab & " - CHECKING SNMP STATUS"
        objLOG.write vbnewline & now & vbtab & vbtab & " - CHECKING SNMP STATUS"
        ''OLD FORMAT
        set objDSM = objWSH.exec("DISM /online /get-features /format:table") ''RESULTS INVALIDATED BY COMMAND CHANGE
        ''set objDSM = objWSH.exec("powershell get-windowscapability -online -name " & chr(34) & "SNMP*" & chr(34))
        while (not objDSM.stdout.atendofstream)
          strRET = objDSM.stdout.readline  ''OLD FORMAT LINE-BY-LINE PARSING
          if (strRET <> vbnullstring) then
            if (instr(1,strRET,"SNMP") and instr(1,strRET,"Disabled")) then ''RESULTS INVALIDATED BY COMMAND CHANGE
            ''if (instr(1, strRET, "SNMP") and (instr(1, strRET, "Disabled") or (instr(1, strRET, "NotPresent")))) then
              objOUT.write vbnewline & now & vbtab & vbtab & " - SNMP NOT INSTALLED, INSTALLING"
              objLOG.write vbnewline & now & vbtab & vbtab & " - SNMP NOT INSTALLED, INSTALLING"
              ''INSTALL SNMP
              call HOOK("DISM /online /enable-feature /featurename:SNMP")   ''COMMAND DOESN'T WORK ON EVERY OS - KNOWN TO WORK ON SERVER 2019 STD
              call HOOK("DISM /online /add-capability /capabilityname:SNMP.Client~~~~0.0.1.0")  ''NEW COMMAND PER https://theitbros.com/snmp-service-on-windows-10/
              ''call HOOK("powershell Install-WindowsFeature " & chr(34) & "RSAT-SNMP" & chr(34)) ''NOT NECESSARY
              objOUT.write vbnewline & now & vbtab & vbtab & " - SNMP INSTALLED"
              objLOG.write vbnewline & now & vbtab & vbtab & " - SNMP INSTALLED"
            end if
            strRET = vbnullstring
          end if
        wend
        set objDSM = nothing
        ''NEW FORMAT
        ''set objDSM = objWSH.exec("DISM /online /get-features /format:table") ''RESULTS INVALIDATED BY COMMAND CHANGE
        set objDSM = objWSH.exec("powershell get-windowscapability -online -name " & chr(34) & "SNMP*" & chr(34))
        while (not objDSM.stdout.atendofstream)
          strRET = objDSM.stdout.readall  ''NEW FORMAT DOES NOT ALLOW LINE-BY-LINE PARSING
          if (strRET <> vbnullstring) then
            ''if (instr(1,strRET,"SNMP") and instr(1,strRET,"Disabled")) then ''RESULTS INVALIDATED BY COMMAND CHANGE
            if (instr(1, strRET, "SNMP") and (instr(1, strRET, "Disabled") or (instr(1, strRET, "NotPresent")))) then
              objOUT.write vbnewline & now & vbtab & vbtab & " - SNMP NOT INSTALLED, INSTALLING"
              objLOG.write vbnewline & now & vbtab & vbtab & " - SNMP NOT INSTALLED, INSTALLING"
              ''INSTALL SNMP
              call HOOK("DISM /online /enable-feature /featurename:SNMP")   ''COMMAND DOESN'T WORK ON EVERY OS - KNOWN TO WORK ON SERVER 2019 STD
              call HOOK("DISM /online /add-capability /capabilityname:SNMP.Client~~~~0.0.1.0")  ''NEW COMMAND PER https://theitbros.com/snmp-service-on-windows-10/
              ''call HOOK("powershell Install-WindowsFeature " & chr(34) & "RSAT-SNMP" & chr(34)) ''NOT NECESSARY
              objOUT.write vbnewline & now & vbtab & vbtab & " - SNMP INSTALLED"
              objLOG.write vbnewline & now & vbtab & vbtab & " - SNMP INSTALLED"            
            end if
            strRET = vbnullstring
          end if
        wend
        set objDSM = nothing
        ''ADD SNMP REGISTRY VALUES
        objOUT.write vbnewline & now & vbtab & vbtab & " - ADDING SNMP CONFIGURATIONS"
        objLOG.write vbnewline & now & vbtab & vbtab & " - ADDING SNMP CONFIGURATIONS"
        call HOOK("reg add " & chr(34) & "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\SNMP\Parameters" & chr(34) & " /v EnableAuthenticationTraps /t REG_DWORD /d 0 /f")
        call HOOK("reg add " & chr(34) & "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\TrapConfiguration" & chr(34) & " /f")
        call HOOK("reg add " & chr(34) & "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\TrapConfiguration\" & strSNMP & chr(34) & " /f")
        call HOOK("reg add " & chr(34) & "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\SNMP\Parameters\ValidCommunities" & chr(34) & " /v " & strSNMP & " /t REG_DWORD /d 4 /f")
        if (instr(1, strTRP, ",")) then                     ''HANDLE MULTIPLE SNMP TRAP AGENTS
          arrTRP = split(strTRP, ",")
          for intTRP = 0 to ubound(arrTRP)
            if (arrTRP(intTRP) <> vbnullstring) then
              wscript.echo "reg add " & chr(34) & "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\SNMP\Parameters\PermittedManagers" & chr(34) & " /v " & (intTRP + 1) & " /t REG_SZ /d " & arrTRP(intTRP) & " /f"
              call HOOK("reg add " & chr(34) & "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\SNMP\Parameters\PermittedManagers" & chr(34) & " /v " & (intTRP + 1) & " /t REG_SZ /d " & arrTRP(intTRP) & " /f")
              call HOOK("reg add " & chr(34) & "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\SNMP\Parameters\PermittedManagers" & chr(34) & " /v " & (intTRP + 1) & " /t REG_SZ /d " & arrTRP(intTRP) & " /f")
              call HOOK("reg add " & chr(34) & "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\SNMP\Parameters\TrapConfiguration\" & strSNMP & chr(34) & " /v " & (intTRP + 1) & " /t REG_SZ /d " & arrTRP(intTRP) & " /f")
            end if
          next
        elseif (instr(1, strTRP, ",") = 0) then             ''HANDLE SINGLE SNMP TRAP AGENT
          call HOOK("reg add " & chr(34) & "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\SNMP\Parameters\PermittedManagers" & chr(34) & " /v 1 /t REG_SZ /d " & strTRP & " /f")
          call HOOK("reg add " & chr(34) & "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\SNMP\Parameters\PermittedManagers" & chr(34) & " /v 2 /t REG_SZ /d " & strTRP & " /f")
          call HOOK("reg add " & chr(34) & "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\SNMP\Parameters\TrapConfiguration\" & strSNMP & chr(34) & " /v 1 /t REG_SZ /d " & strTRP & " /f")
        end if
        objOUT.write vbnewline & now & vbtab & vbtab & " - SNMP CONFIGURATIONS COMPLETED"
        objLOG.write vbnewline & now & vbtab & vbtab & " - SNMP CONFIGURATIONS COMPLETED"
        objOUT.write vbnewline & vbnewline & now & vbtab & " - PLEASE REVIEW SNMP CONFIGURATIONS :"
        objLOG.write vbnewline & vbnewline & now & vbtab & " - PLEASE REVIEW SNMP CONFIGURATIONS :"    
        call HOOK("reg query " & chr(34) & "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\SNMP\Parameters" & chr(34) & " /s")
        wscript.sleep 5000
        call HOOK("sc stop " & chr(34) & "SNMP" & chr(34))
        wscript.sleep 5000
        call HOOK("sc start " & chr(34) & "SNMP" & chr(34))
    end select
    if (err.number <> 0) then
      errRET = 1
      objOUT.write vbnewline & now & vbtab & "KEY NOT FOUND / ACCESS DENIED"
      objLOG.write vbnewline & now & vbtab & "KEY NOT FOUND / ACCESS DENIED"
      err.clear
    end if
  end if
elseif (errRET <> 0) then                                   ''ERRORS ENCOUNTERED DURING INITIAL START
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
  objOUT.write vbnewline & now & vbtab & vbtab & " - EXECUTING : HOOK(" & strCMD & ")"
  objLOG.write vbnewline & now & vbtab & vbtab & " - EXECUTING : HOOK(" & strCMD & ")"
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
  on error resume next
  if (errRET = 0) then         															''SNMPPARAM COMPLETED SUCCESSFULLY
    objOUT.write vbnewline & vbnewline & now & vbtab & " - SNMPPARAM SUCCESSFUL : " & now
    objLOG.write vbnewline & vbnewline & now & vbtab & " - SNMPPARAM SUCCESSFUL : " & now
    err.clear
  elseif (errRET <> 0) then    															''SNMPPARAM FAILED
    objOUT.write vbnewline & vbnewline & now & vbtab & " - SNMPPARAM FAILURE : " & errRET & " : " & now
    objLOG.write vbnewline & vbnewline & now & vbtab & " - SNMPPARAM FAILURE : " & errRET & " : " & now
    ''RAISE CUSTOMIZED ERROR CODE, ERROR CODE WILL BE DEFINE RESTOP NUMBER INDICATING WHICH SECTION FAILED
    call err.raise(vbObjectError + errRET, "SNMPPARAM", "FAILURE")
  end if
  objOUT.write vbnewline & vbnewline & now & " - SNMPPARAM COMPLETE. PLEASE VERIFY ALL MONITORING AND SERVICES!" & vbnewline
  objLOG.write vbnewline & vbnewline & now & " - SNMPPARAM COMPLETE. PLEASE VERIFY ALL MONITORING AND SERVICES!" & vbnewline
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