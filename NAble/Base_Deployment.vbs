''BASE_DEPLOYMENT.VBS
''DESIGNED TO DOWNLOAD AND INSTALL PROGRAMS FOR A "BASELINE DEPLOYMENT"
''WRITTEN BY : CJ BLEDSOE / CBLEDSOE<@>IPMCOMPUTERS.COM
on error resume next
''SCRIPT VARIABLES
dim strREPO, strBRCH, strDIR
dim errRET, strVER, strSEL, strIN
''VARIABLES ACCEPTING PARAMETERS
''SCRIPT OBJECTS
dim objIN, objOUT, objARG, objWSH, objFSO
dim objLOG, objEXEC, objHOOK, objSIN, objSOUT
''VERSION FOR SCRIPT UPDATE, BASE_DEPLOYMENT.VBS, REF #2 , REF #68 , REF #69 , FIXES #21 , FIXES #31
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
if (objFSO.fileexists("C:\temp\BASE_DEPLOYMENT")) then              ''LOGFILE EXISTS
  objFSO.deletefile "C:\temp\BASE_DEPLOYMENT", true
  set objLOG = objFSO.createtextfile("C:\temp\BASE_DEPLOYMENT")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\BASE_DEPLOYMENT", 8)
else                                                                ''LOGFILE NEEDS TO BE CREATED
  set objLOG = objFSO.createtextfile("C:\temp\BASE_DEPLOYMENT")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\BASE_DEPLOYMENT", 8)
end if
''READ PASSED COMMANDLINE ARGUMENTS
if (wscript.arguments.count > 0) then                               ''ARGUMENTS WERE PASSED
  ''ARGUMENT OUTPUT DISABLED TO SANITIZE
  'for x = 0 to (wscript.arguments.count - 1)
  '  objOUT.write vbnewline & now & vbtab & " - ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
  '  objLOG.write vbnewline & now & vbtab & " - ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
  'next 
  if (wscript.arguments.count > 1) then                             ''REQUIRED ARGUMENTS PASSED
  else                                                              ''NOT ENOUGH ARGUMENTS PASSED , END SCRIPT , 'ERRRET'=1
    'call LOGERR(1)
  end if
elseif (wscript.arguments.count = 0) then                           ''NO ARGUMENTS PASSED , END SCRIPT , 'ERRRET'=1
  'call LOGERR(1)
end if

''------------
''BEGIN SCRIPT
if (errRET = 0) then                                                ''NO ERRORS DURING INITIAL START
  objOUT.write vbnewline & vbnewline & now & vbtab & " - EXECUTING BASE_DEPLOYMENT"
  objLOG.write vbnewline & vbnewline & now & vbtab & " - EXECUTING BASE_DEPLOYMENT"
	''AUTOMATIC UPDATE, BASE_DEPLOYMENT.VBS, REF #2 , REF #69 , REF #68
  objOUT.write vbnewline & now & vbtab & vbtab & " - CHECKING FOR UPDATE : BASE_DEPLOYMENT : " & strVER
  objLOG.write vbnewline & now & vbtab & vbtab & " - CHECKING FOR UPDATE : BASE_DEPLOYMENT : " & strVER
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
    ''CHANGE ACTIVE POWER PLAN
    objOUT.write vbnewline & now & vbtab & " - SETTING ACTIVE POWER PLAN : HIGH PERFORMANCE" & vbnewline
    objLOG.write vbnewline & now & vbtab & " - SETTING ACTIVE POWER PLAN : HIGH PERFORMANCE" & vbnewline
    call HOOK("powercfg.exe /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c")
    ''DISABLE HIBERNATION
    objOUT.write vbnewline & now & vbtab & " - DISABLING HIBERNATION" & vbnewline
    objLOG.write vbnewline & now & vbtab & " - DISABLING HIBERNATION" & vbnewline
    call HOOK("powercfg –h off")
    ''SAMSUNG MAGICIAN SETUP - CANNOT BE INSTALLED IN SILENT MODE
    objOUT.write vbnewline & now & vbtab & vbtab & " - DOWNLOADING SAMSUNG MAGICIAN"
    objLOG.write vbnewline & now & vbtab & vbtab & " - DOWNLOADING SAMSUNG MAGICIAN"
    call FILEDL("https://raw.githubusercontent.com/CW-Khristos/scripts/" & strBRCH & "/SamsungMagician/Samsung_Magician_installer.exe", "C:\IT", "SamsungMagicianSetup.exe")
    objOUT.write vbnewline & now & vbtab & vbtab & " - INSTALLING SAMSUNG MAGICIAN"
    objLOG.write vbnewline & now & vbtab & vbtab & " - INSTALLING SAMSUNG MAGICIAN"
    call HOOK("C:\IT\SamsungMagicianSetup.exe")
    ''JAVA SETUP - SILENT REQUIRES ALTERNATE INSTALLS
    objOUT.write vbnewline & now & vbtab & vbtab & " - DOWNLOADING JAVA"
    objLOG.write vbnewline & now & vbtab & vbtab & " - DOWNLOADING JAVA"
    call FILEDL("https://javadl.oracle.com/webapps/download/AutoDL?BundleId=245029_d3c52aa6bfa54d3ca74e617f18309292", "C:\IT", "JavaSetup.exe")
    objOUT.write vbnewline & now & vbtab & vbtab & " - INSTALLING JAVA"
    objLOG.write vbnewline & now & vbtab & vbtab & " - INSTALLING JAVA"
    call HOOK("C:\IT\JavaSetup.exe")
    ''CLASSIC SHELL SETUP - BLOCKED BY SOPHOS
    objOUT.write vbnewline & now & vbtab & vbtab & " - DOWNLOADING CLASSIC SHELL"
    objLOG.write vbnewline & now & vbtab & vbtab & " - DOWNLOADING CLASSIC SHELL"
    call FILEDL("https://raw.githubusercontent.com/CW-Khristos/scripts/" & strBRCH & "/ClassicShell/ClassicShellSetup.exe", "C:\IT", "ClassicShellSetup.exe")
    objOUT.write vbnewline & now & vbtab & vbtab & " - INSTALLING CLASSIC SHELL"
    objLOG.write vbnewline & now & vbtab & vbtab & " - INSTALLING CLASSIC SHELL"
    call HOOK("C:\IT\ClassicShellSetup.exe")
    ''CHROME SETUP - NO ARGUMENTS / NO SILENT
    objOUT.write vbnewline & now & vbtab & vbtab & " - DOWNLOADING CHROME"
    objLOG.write vbnewline & now & vbtab & vbtab & " - DOWNLOADING CHROME"
    call FILEDL("https://raw.githubusercontent.com/CW-Khristos/scripts/" & strBRCH & "/Chrome/ChromeSetup.exe", "C:\IT", "ChromeSetup.exe")
    objOUT.write vbnewline & now & vbtab & vbtab & " - INSTALLING CHROME"
    objLOG.write vbnewline & now & vbtab & vbtab & " - INSTALLING CHROME"
    call HOOK("C:\IT\ChromeSetup.exe")
    ''FIREFOX SETUP - NO ARGUMENTS / NO SILENT
    objOUT.write vbnewline & now & vbtab & vbtab & " - DOWNLOADING FIREFOX"
    objLOG.write vbnewline & now & vbtab & vbtab & " - DOWNLOADING FIREFOX"
    call FILEDL("https://download.mozilla.org/?product=firefox-stub&os=win&lang=en-US&attribution_code=c291cmNlPXd3dy5nb29nbGUuY29tJm1lZGl1bT1yZWZlcnJhbCZjYW1wYWlnbj0obm90IHNldCkmY29udGVudD0obm90IHNldCkmZXhwZXJpbWVudD0obm90IHNldCkmdmFyaWF0aW9uPShub3Qgc2V0KSZ1YT1jaHJvbWUmdmlzaXRfaWQ9KG5vdCBzZXQp&attribution_sig=3466763a646381f4d23891a79de5b2c5da57cff9698bd5c185e938b48ed303e6", "C:\IT", "FireFoxSetup.exe")
    objOUT.write vbnewline & now & vbtab & vbtab & " - INSTALLING FIREFOX"
    objLOG.write vbnewline & now & vbtab & vbtab & " - INSTALLING FIREFOX"
    call HOOK("C:\IT\FireFoxSetup.exe")
    ''ADOBE READER SETUP - NO ARGUMENTS / NO SILENT
    objOUT.write vbnewline & now & vbtab & vbtab & " - DOWNLOADING ADOBE READER"
    objLOG.write vbnewline & now & vbtab & vbtab & " - DOWNLOADING ADOBE READER"
    call FILEDL("https://raw.githubusercontent.com/CW-Khristos/scripts/" & strBRCH & "/Adobe/readerdc_en_xa_crd_install.exe", "C:\IT", "readerdc_en_xa_crd_install.exe")
    objOUT.write vbnewline & now & vbtab & vbtab & " - INSTALLING ADOBE READER"
    objLOG.write vbnewline & now & vbtab & vbtab & " - INSTALLING ADOBE READER"
    call HOOK("C:\IT\readerdc_en_xa_crd_install.exe")
  end if
elseif (errRET <> 0) then                                           ''ERRORS ENCOUNTERED DURING INITIAL START
  call LOGERR(errRET)
end if
''END SCRIPT
call CLEANUP()
''END SCRIPT
''------------

''SUB-ROUTINES
sub FILEDL(strURL, strDL, strFILE)                                  ''CALL HOOK TO DOWNLOAD FILE FROM URL , 'ERRRET'=11
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
  if ((err.number <> 0) and (err.number <> 58)) then                ''ERROR RETURNED DURING DOWNLOAD , 'ERRRET'=11
    call LOGERR(11)
  end if
end sub

sub HOOK(strCMD)                                                    ''CALL HOOK TO MONITOR OUTPUT OF CALLED COMMAND , 'ERRRET'=12
  on error resume next
  objOUT.write vbnewline & now & vbtab & vbtab & "EXECUTING : HOOK(" & strCMD & ")"
  objLOG.write vbnewline & now & vbtab & vbtab & "EXECUTING : HOOK(" & strCMD & ")"
  set objHOOK = objWSH.exec(strCMD)
  if (instr(1, strCMD, "takeown /F ") = 0) then                     ''SUPPRESS 'TAKEOWN' SUCCESS MESSAGES
    while (not objHOOK.stdout.atendofstream)
      strIN = objHOOK.stdout.readline
      if (strIN <> vbnullstring) then
        objOUT.write vbnewline & now & vbtab & vbtab & vbtab & strIN 
        objLOG.write vbnewline & now & vbtab & vbtab & vbtab & strIN 
      end if
      wscript.sleep 10
    wend
    wscript.sleep 10
    strIN = objHOOK.stdout.readall
    if (strIN <> vbnullstring) then
      objOUT.write vbnewline & now & vbtab & vbtab & vbtab & strIN 
      objLOG.write vbnewline & now & vbtab & vbtab & vbtab & strIN 
    end if
  end if
  set objHOOK = nothing
  if (err.number <> 0) then                                         ''ERROR RETURNED DURING UPDATE CHECK , 'ERRRET'=12
    call LOGERR(12)
  end if
end sub

sub LOGERR(intSTG)                                                  ''CALL HOOK TO MONITOR OUTPUT OF CALLED COMMAND
  errRET = intSTG
  if (err.number <> 0) then
    objOUT.write vbnewline & now & vbtab & vbtab & vbtab & err.number & vbtab & err.description & vbnewline
    objLOG.write vbnewline & now & vbtab & vbtab & vbtab & err.number & vbtab & err.description & vbnewline
		err.clear
  end if
  ''CUSTOM ERROR CODES
  select case intSTG
    case 1                                                          '' 'ERRRET'=1 - NOT ENOUGH ARGUMENTS
  end select
end sub

sub CLEANUP()                                                       ''SCRIPT CLEANUP
  on error resume next
  if (errRET = 0) then                                              ''SCRIPT COMPLETED SUCCESSFULLY
    objOUT.write vbnewline & vbnewline & now & vbtab & " - BASE_DEPLOYMENT SUCCESSFUL : " & now
    objLOG.write vbnewline & vbnewline & now & vbtab & " - BASE_DEPLOYMENT SUCCESSFUL : " & now
    err.clear
  elseif (errRET <> 0) then                                         ''SCRIPT FAILED
    objOUT.write vbnewline & vbnewline & now & vbtab & " - BASE_DEPLOYMENT FAILURE : " & errRET & " : " & now
    objLOG.write vbnewline & vbnewline & now & vbtab & " - BASE_DEPLOYMENT FAILURE : " & errRET & " : " & now
    ''RAISE CUSTOMIZED ERROR CODE , ERROR CODE WILL BE DEFINED RESTOP NUMBER INDICATING WHICH SECTION FAILED
    call err.raise(vbObjectError + errRET, "BASE_DEPLOYMENT", "fail")
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