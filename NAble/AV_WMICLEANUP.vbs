''AV_WMICLEANUP.VBS
''DESIGNED TO CLEANUP AV WMI DATA
''ACCEPTS 1 PARAMETERS , REQUIRES 1 PARAMETERS
''OPTIONAL PARAMETER : 'STRAVP' , STRING FOR TARGET AV / FW PRODUCT TO REMOVE FROM WMI
''WRITTEN BY : CJ BLEDSOE / CBLEDSOE<@>IPMCOMPUTERS.COM
on error resume next
''SCRIPT VARIABLES
dim errRET, strVER
dim strREPO, strBRCH, strDIR
''VARIABLES ACCEPTING PARAMETERS
dim strIN, strOUT, strAVP, blnFND
''SCRIPT OBJECTS
dim objIN, objOUT, objARG, objWSH, objFSO
dim objNET, objWMI, objLOG, objEXEC, objHOOK
''VERSION FOR SCRIPT UPDATE, AV_WMICLEANUP.VBS, REF #2 , REF #68 , REF #69 , FIXES #21 , FIXES #31
strVER = 1
strREPO = "scripts"
strBRCH = "dev"
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
''OBJECTS FOR CONNECTING TO REGISTRY PROVIDER
Set objNET = createObject("WScript.Network")
Set objWMI = createObject("WbemScripting.SWbemLocator")
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
if (objFSO.fileexists("C:\temp\AV_WMICLEANUP")) then        ''LOGFILE EXISTS
  objFSO.deletefile "C:\temp\AV_WMICLEANUP", true
  set objLOG = objFSO.createtextfile("C:\temp\AV_WMICLEANUP")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\AV_WMICLEANUP", 8)
else                                                        ''LOGFILE NEEDS TO BE CREATED
  set objLOG = objFSO.createtextfile("C:\temp\AV_WMICLEANUP")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\AV_WMICLEANUP", 8)
end if
''READ PASSED COMMANDLINE ARGUMENTS
if (wscript.arguments.count > 0) then                       ''ARGUMENTS WERE PASSED
  ''ARGUMENT OUTPUT DISABLED TO SANITIZE
  for x = 0 to (wscript.arguments.count - 1)
    objOUT.write vbnewline & now & vbtab & " - ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
    objLOG.write vbnewline & now & vbtab & " - ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
  next 
  if (wscript.arguments.count >= 1) then                    ''REQUIRED ARGUMENTS PASSED
    strAVP = objARG.item(0)                                 ''SET OPTIONAL PARAMETER 'STRAVP', TARGET AV / FW PRODUCT TO REMOVE FROM WMI
  else                                                      ''NOT ENOUGH ARGUMENTS PASSED , END SCRIPT , 'ERRRET'=1
    'call LOGERR(1)
  end if
elseif (wscript.arguments.count = 0) then                   ''NO ARGUMENTS PASSED , END SCRIPT , 'ERRRET'=1
  'call LOGERR(1)
end if

''------------
''BEGIN SCRIPT
blnFND = false
if (errRET = 0) then                                        ''NO ERRORS DURING INITIAL START
  objOUT.write vbnewline & vbnewline & now & vbtab & " - EXECUTING AV_WMICLEANUP"
  objLOG.write vbnewline & vbnewline & now & vbtab & " - EXECUTING AV_WMICLEANUP"
	''AUTOMATIC UPDATE, AV_WMICLEANUP.VBS, REF #2 , REF #69 , REF #68 , FIXES #21
  objOUT.write vbnewline & now & vbtab & vbtab & " - CHECKING FOR UPDATE : AV_WMICLEANUP : " & strVER
  objLOG.write vbnewline & now & vbtab & vbtab & " - CHECKING FOR UPDATE : AV_WMICLEANUP : " & strVER
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
    ''CONNECT TO REGISTRY PROVIDER
    set objSEC = objWMI.ConnectServer(objNET.ComputerName, "root\SecurityCenter")
    set AVS = objSEC.execquery("Select * from AntiVirusProduct")
    set FWS = objSEC.execquery("Select * from FirewallProduct")
    ''ENUMERATE EACH AV INSTANCE
    for each AV in AVS
      if (strAVP <> vbnullstring) then
        if (instr(1, ucase(AV.displayname), ucase(strAVP))) then
          objOUT.write vbnewline & now & vbtab & vbtab & " - FOUND TARGET : " & AV.displayname
          objLOG.write vbnewline & now & vbtab & vbtab & " - FOUND TARGET : " & AV.displayname
          call delWMI(AV)
          blnFND = true
        end if
      elseif (strAVP = vbnullstring) then
        if ((instr(1, ucase(AV.displayname), "SOPHOS") = 0) and (instr(1, ucase(AV.displayname), "AV DEFENDER") = 0) and (instr(1, ucase(AV.displayname), "WINDOWS DEFENDER") = 0)) then
          objOUT.write vbnewline & now & vbtab & vbtab & " - FOUND TARGET : " & AV.displayname
          objLOG.write vbnewline & now & vbtab & vbtab & " - FOUND TARGET : " & AV.displayname
          call delWMI(AV)
          blnFND = true
        end if
      end if
    next
    ''ENUMERATE EACH FW INSTANCE
    for each FW in FWS
      if (strAVP <> vbnullstring) then
        if (instr(1, ucase(FW.displayname), ucase(strAVP))) then
          objOUT.write vbnewline & now & vbtab & vbtab & " - FOUND TARGET : " & FW.displayname
          objLOG.write vbnewline & now & vbtab & vbtab & " - FOUND TARGET : " & FW.displayname
          call delWMI(FW)
          blnFND = true
        end if
      elseif (strAVP = vbnullstring) then
        if ((instr(1, ucase(FW.displayname), "SOPHOS") = 0) and (instr(1, ucase(FW.displayname), "AV DEFENDER") = 0) and (instr(1, ucase(FW.displayname), "WINDOWS DEFENDER") = 0)) then
          objOUT.write vbnewline & now & vbtab & vbtab & " - FOUND TARGET : " & FW.displayname
          objLOG.write vbnewline & now & vbtab & vbtab & " - FOUND TARGET : " & FW.displayname
          call delWMI(FW)
          blnFND = true
        end if
      end if
    next
    ''CONNECT TO REGISTRY PROVIDER
    set objSEC = objWMI.ConnectServer(objNET.ComputerName, "root\SecurityCenter2")
    set AVS = objSEC.execquery("Select * from AntiVirusProduct")
    set FWS = objSEC.execquery("Select * from FirewallProduct")
    ''ENUMERATE EACH AV INSTANCE
    for each AV in AVS
      if (strAVP <> vbnullstring) then
        if (instr(1, ucase(AV.displayname), ucase(strAVP))) then
          objOUT.write vbnewline & now & vbtab & vbtab & " - FOUND TARGET : " & AV.displayname
          objLOG.write vbnewline & now & vbtab & vbtab & " - FOUND TARGET : " & AV.displayname
          call delWMI(AV)
          blnFND = true
        end if
      elseif (strAVP = vbnullstring) then
        if ((instr(1, ucase(AV.displayname), "SOPHOS") = 0) and (instr(1, ucase(AV.displayname), "AV DEFENDER") = 0) and (instr(1, ucase(AV.displayname), "WINDOWS DEFENDER") = 0)) then
          objOUT.write vbnewline & now & vbtab & vbtab & " - FOUND TARGET : " & AV.displayname
          objLOG.write vbnewline & now & vbtab & vbtab & " - FOUND TARGET : " & AV.displayname
          call delWMI(AV)
          blnFND = true
        end if
      end if
    next
    ''ENUMERATE EACH FW INSTANCE
    for each FW in FWS
      if (strAVP <> vbnullstring) then
        if (instr(1, ucase(FW.displayname), ucase(strAVP))) then
          objOUT.write vbnewline & now & vbtab & vbtab & " - FOUND TARGET : " & FW.displayname
          objLOG.write vbnewline & now & vbtab & vbtab & " - FOUND TARGET : " & FW.displayname
          call delWMI(FW)
          blnFND = true
        end if
      elseif (strAVP = vbnullstring) then
        if ((instr(1, ucase(FW.displayname), "SOPHOS") = 0) and (instr(1, ucase(FW.displayname), "AV DEFENDER") = 0) and (instr(1, ucase(FW.displayname), "WINDOWS DEFENDER") = 0)) then
          objOUT.write vbnewline & now & vbtab & vbtab & " - FOUND TARGET : " & FW.displayname
          objLOG.write vbnewline & now & vbtab & vbtab & " - FOUND TARGET : " & FW.displayname
          call delWMI(FW)
          blnFND = true
        end if
      end if
    next
    ''PROVIDE INFORMATIONAL OUTPUT IF NO INSTANCES FOUND
    if (not blnFND) then
      objOUT.write vbnewline & now & vbtab & vbtab & " - NO TARGET FOUND"
      objLOG.write vbnewline & now & vbtab & vbtab & " - NO TARGET FOUND"
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
sub delWMI(objPROD)                                         ''CALL HOOK TO DELETE WMI INSTANCE AND CHECK FOR ERROR , 'ERRRET'=13
  objPROD.delete_
  if (err.number = 0) then
    objOUT.write vbnewline & now & vbtab & vbtab & vbtab & " - CLEANUP OF " & ucase(objPROD.displayname) & " : SUCCESSFUL"
    objLOG.write vbnewline & now & vbtab & vbtab & vbtab & " - CLEANUP OF " & ucase(objPROD.displayname) & " : SUCCESSFUL"
  elseif (err.number <> 0) then
    objOUT.write vbnewline & now & vbtab & vbtab & vbtab & " - CLEANUP OF " & ucase(objPROD.displayname) & " : UNSUCCESSFUL"
    objLOG.write vbnewline & now & vbtab & vbtab & vbtab & " - CLEANUP OF " & ucase(objPROD.displayname) & " : UNSUCCESSFUL"
    call LOGERR(13)                                         ''ERROR RETURNED DURING WMI INSTANCE DELETE , 'ERRRET'=13
  end if
end sub

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
  ''ARGUMENT OUTPUT DISABLED TO SANITIZE
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
  end select
end sub

sub CLEANUP()                                               ''SCRIPT CLEANUP
  on error resume next
  if (errRET = 0) then                                      ''SCRIPT COMPLETED SUCCESSFULLY
    objOUT.write vbnewline & vbnewline & now & vbtab & " - AV_WMICLEANUP SUCCESSFUL : " & now
    objLOG.write vbnewline & vbnewline & now & vbtab & " - AV_WMICLEANUP SUCCESSFUL : " & now
    err.clear
  elseif (errRET <> 0) then                                 ''SCRIPT FAILED
    objOUT.write vbnewline & vbnewline & now & vbtab & " - AV_WMICLEANUP FAILURE : " & errRET & " : " & now
    objLOG.write vbnewline & vbnewline & now & vbtab & " - AV_WMICLEANUP FAILURE : " & errRET & " : " & now
    ''RAISE CUSTOMIZED ERROR CODE , ERROR CODE WILL BE DEFINED RESTOP NUMBER INDICATING WHICH SECTION FAILED
    call err.raise(vbObjectError + errRET, "AV_WMICLEANUP", "fail")
  end if
  objOUT.write vbnewline & vbnewline & now & " - AV_WMICLEANUP COMPLETE" & vbnewline
  objLOG.write vbnewline & vbnewline & now & " - AV_WMICLEANUP COMPLETE" & vbnewline
  objLOG.close
  ''EMPTY OBJECTS
  set objEXEC = nothing
  set objWMI = nothing
  set objNET = nothing
  set objLOG = nothing
  set objFSO = nothing
  set objWSH = nothing
  set objARG = nothing
  set objOUT = nothing
  set objIN = nothing
  ''END SCRIPT , RETURN ERROR
  wscript.quit err.number
end sub