on error resume next
''SCRIPT VARIABLES
dim strIN, strOUT, blnREM, retSTOP
dim objIN, objOUT, objARG, objWSH, objFSO, objLOG, objEXEC, objHOOK
dim strCID, strCNAM, strRIP, strRUSR, strRPWD, strSIP, strSPTH, strSUSR, strSPWD, strPPTH
''DEFAULT FAIL
retSTOP = 1
''REMOVAL FLAG
blnREM = false
''STDIN / STDOUT
set objIN = wscript.stdin
set objOUT = wscript.stdout
set objARG = wscript.arguments
''CREATE SCRIPTING OBJECTS
set objWSH = createobject("wscript.shell")
set objFSO = createobject("scripting.filesystemobject")
''PREPARE LOGFILE
if (objFSO.fileexists("C:\temp\agent_psexec")) then              ''LOGFILE EXISTS
  objFSO.deletefile "C:\temp\agent_psexec", true
  set objLOG = objFSO.createtextfile("C:\temp\agent_psexec")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\agent_psexec", 8)
else                                                        ''LOGFILE NEEDS TO BE CREATED
  set objLOG = objFSO.createtextfile("C:\temp\agent_psexec")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\agent_psexec", 8)
end if
''READ PASSED COMMANDLINE ARGUMENTS
if (wscript.arguments.count > 0) then                       ''ARGUMENTS WERE PASSED
  for x = 0 to (wscript.arguments.count - 1)
    objOUT.write vbnewline & now & vbtab & " - ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
    objLOG.write vbnewline & now & vbtab & " - ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
  next 
  if (wscript.arguments.count > 9) then                     ''SET RMMTECH LOGON ARGUMENTS FOR UPDATING 'BACKUP SERVICE CONTROLLER' LOGON
    strCID = objARG.item(0)           ''CUSTOMER ID
    strCNAM = objARG.item(1)          ''CUSTOMER NAME
    strRIP = objARG.item(2)           ''REMOTE IP
    strRUSR = objARG.item(3)          ''REMOTE USER
    strRPWD = objARG.item(4)          ''REMOTE PASSWORD
    strSIP = objARG.item(5)           ''SHARE IP
    strSPTH = objARG.item(6)          ''SHARE PATH
    strSUSR = objARG.item(7)          ''SHARE USER
    strSPWD = objARG.item(8)          ''SHARE PASSWORD
    strPPTH = objARG.item(9)          ''PSEXEC PATH
    strRUSR = strRIP & "\" & strRUSR  ''REMOTE IP + REMOTE USER
    strSUSR = strSIP & "\" & strSUSR  ''SHARE IP + SHARE USER
  else                                                      ''NOT ENOUGH ARGUMENTS PASSED, END SCRIPT
    retSTOP = 1
    call CLEANUP
  end if
else                                                        ''NO ARGUMENTS PASSED, END SCRIPT
  'objOUT.write vbnewline & vbnewline & now & vbtab & " - SCRIPT REQUIRES PATH TO MSP LSV DESTINATION"
  'objLOG.write vbnewline & vbnewline & now & vbtab & " - SCRIPT REQUIRES PATH TO MSP LSV DESTINATION"
  retSTOP = 1
  call CLEANUP
end if

''------------
''BEGIN SCRIPT
objOUT.write vbnewline & vbnewline & now & vbtab & " - EXECUTING AGENT_PSEXEC"
objLOG.write vbnewline & vbnewline & now & vbtab & " - EXECUTING AGENT_PSEXEC"
''AUTOMATIC UPDATE, AGENT_PSEXEC.VBS, REF #2
call CHKAU()
''DOWNLOAD REAGENT.VBS SCRIPT TO PREPARE FOR TRANSFER TO REMOTE DEVICE
call FILEDL("https://github.com/CW-Khristos/CW_MSI/raw/master/reagent.vbs", "reagent.vbs")
''SHARE DIRECTORY CONTAINING WINDOWS AGENT MSI AND PSEXEC
call HOOK("net share Agent=" & chr(34) & strSPTH & chr(34) & " /grant:" & strSUSR & ",FULL")
''LAUNCH PSEXEC
objOUT.write vbnewline & vbnewline & now & vbtab & " - EXECUTING PSEXEC CONNECTION : " & strRIP
objLOG.write vbnewline & vbnewline & now & vbtab & " - EXECUTING PSEXEC CONNECTION : " & strRIP
''COPY WINDOWS AGENT FROM SHARE DIRECTORY
'set objEXEC = objWSH.exec(chr(34) & strPPTH & "\PsExec.exe" & chr(34) & " \\" & strRIP & " -u " & strRUSR & " -p " & chr(34) & strRPWD & chr(34) & " -h -accepteula cmd")
'objExec.stdin.write "copy " & chr(34) & "\\" & strRIP & "\Agent\Windows Agent.msi" & chr(34) & " " & chr(34) & "c:\temp" & chr(34) & vbcrlf
'objExec.stdin.write "msiexec /x " & chr(34) & "c:\temp\windows agent.msi" & chr(34) & " /qb /l*v c:\temp\uninstall.log ALLUSERS=2" & vbcrlf
'objExec.stdin.write "tasklist | findstr /i basupsrvc" & vbcrlf
''CONNECT TO REMOTE DEVICE WITH PSEXEC
set objEXEC = objWSH.exec(chr(34) & strPPTH & "\PsExec.exe" & chr(34) & " \\" & strRIP & " -u " & strRUSR & " -p " & chr(34) & strRPWD & chr(34) & " -h -accepteula cmd")
''COPY REAGENT.VBS SCRIPT FROM SOURCE TO REMOTE DEVICE
'objExec.stdin.write "copy " & chr(34) & "\\" & strSIP & "\Agent\reagent.vbs" & chr(34) & " " & chr(34) & "c:\temp" & chr(34) & vbcrlf
''EXECUTE REAGENT.VBS
'objExec.stdin.write "cscript.exe //nologo " & chr(34) & "c:\temp\reagent.vbs" & chr(34) & " " & chr(34) & strCID & chr(34) & " " & chr(34) & strCNAM & chr(34) & vbcrlf
while (not objEXEC.stdout.atendofstream)
  objOUT.write objEXEC.stdout
wend
''CLEANUP
call CLEANUP()
''END SCRIPT
''------------

''SUB-ROUTINES
sub CHKAU()																									''CHECK FOR SCRIPT UPDATE, RE-AGENT.VBS, REF #2 , FIXES #8
  ''REMOVE WINDOWS AGENT CACHED VERSION OF SCRIPT
  if (objFSO.fileexists("C:\Program Files (x86)\N-Able Technologies\Windows Agent\cache\" & wscript.scriptname)) then
    objFSO.deletefile "C:\Program Files (x86)\N-Able Technologies\Windows Agent\cache\" & wscript.scriptname, true
  end if
	''ADD WINHTTP SECURE CHANNEL TLS REGISTRY KEYS
	call HOOK("reg add " & chr(34) & "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp" & chr(34) & _
		" /f /v DefaultSecureProtocols /t REG_DWORD /d 0x00000A00 /reg:32")
	call HOOK("reg add " & chr(34) & "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp" & chr(34) & _
		" /f /v DefaultSecureProtocols /t REG_DWORD /d 0x00000A00 /reg:64")
	''SCRIPT OBJECT FOR PARSING XML
	set objXML = createobject("Microsoft.XMLDOM")
	''FORCE SYNCHRONOUS
	objXML.async = false
	''LOAD SCRIPT VERSIONS DATABASE XML
	if objXML.load("https://github.com/CW-Khristos/scripts/raw/master/version.xml") then
		set colVER = objXML.documentelement
		for each objSCR in colVER.ChildNodes
			''LOCATE CURRENTLY RUNNING SCRIPT
			if (lcase(objSCR.nodename) = lcase(wscript.scriptname)) then
				''CHECK LATEST VERSION
				if (cint(objSCR.text) > cint(strVER)) then
					objOUT.write vbnewline & now & vbtab & " - UPDATING " & objSCR.nodename & " : " & objSCR.text & vbnewline
					objLOG.write vbnewline & now & vbtab & " - UPDATING " & objSCR.nodename & " : " & objSCR.text & vbnewline
					''DOWNLOAD LATEST VERSION OF SCRIPT
					call FILEDL("https://github.com/CW-Khristos/CW_MSI/raw/master/agent_psexec.vbs", wscript.scriptname)
					''RUN LATEST VERSION
					if (wscript.arguments.count > 0) then             ''ARGUMENTS WERE PASSED
						for x = 0 to (wscript.arguments.count - 1)
							strTMP = strTMP & " " & chr(34) & objARG.item(x) & chr(34)
						next
            objOUT.write vbnewline & now & vbtab & " - RE-EXECUTING " & objSCR.nodename & " : " & objSCR.text & vbnewline
            objLOG.write vbnewline & now & vbtab & " - RE-EXECUTING  " & objSCR.nodename & " : " & objSCR.text & vbnewline
						objWSH.run "cscript.exe //nologo " & chr(34) & "c:\temp\" & wscript.scriptname & chr(34) & strTMP, 0, false
					elseif (wscript.arguments.count = 0) then         ''NO ARGUMENTS WERE PASSED
            objOUT.write vbnewline & now & vbtab & " - RE-EXECUTING  " & objSCR.nodename & " : " & objSCR.text & vbnewline
            objLOG.write vbnewline & now & vbtab & " - RE-EXECUTING  " & objSCR.nodename & " : " & objSCR.text & vbnewline
						objWSH.run "cscript.exe //nologo " & chr(34) & "c:\temp\" & wscript.scriptname & chr(34), 0, false
					end if
					''END SCRIPT
					call CLEANUP()
				end if
			end if
		next
	end if
	set colVER = nothing
	set objXML = nothing
end sub

sub FILEDL(strURL, strFILE)                                 ''CALL HOOK TO DOWNLOAD FILE FROM URL
  strSAV = vbnullstring
  ''SET DOWNLOAD PATH
  strSAV = "C:\temp\" & strFILE
  objOUT.write vbnewline & now & vbtab & vbtab & "HTTPDOWNLOAD-------------DOWNLOAD : " & strURL & " : SAVE AS :  " & strSAV
  objLOG.write vbnewline & now & vbtab & vbtab & "HTTPDOWNLOAD-------------DOWNLOAD : " & strURL & " : SAVE AS :  " & strSAV
  ''CREATE HTTP OBJECT
  set objHTTP = createobject( "WinHttp.WinHttpRequest.5.1" )
  ''DOWNLOAD FROM URL
  objHTTP.open "GET", strURL, false
  objHTTP.send
  if objFSO.fileexists(strSAV) then
    objFSO.deletefile(strSAV)
  end if
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
    objOUT.write vbnewline & vbnewline & now & vbtab & " - DOWNLOAD : " & strSAV & " : SUCCESSFUL"
    objLOG.write vbnewline & vbnewline & now & vbtab & " - DOWNLOAD : " & strSAV & " : SUCCESSFUL"
  end if
	set objHTTP = nothing
  if (err.number <> 0) then
    errRET = 2
		err.clear
  end if
end sub

sub HOOK(strCMD)                                        ''CALL HOOK TO MONITOR OUTPUT OF CALLED COMMAND
  on error resume next
  'comspec = objWSH.ExpandEnvironmentStrings("%comspec%")
  objOUT.write vbnewline & now & vbtab & vbtab & "EXECUTING : " & strCMD
  objLOG.write vbnewline & now & vbtab & vbtab & "EXECUTING : " & strCMD
  set objHOOK = objWSH.exec(strCMD)
  if (instr(1, strCMD, "takeown /F ") = 0) then         ''SUPPRESS 'TAKEOWN' SUCCESS MESSAGES
    'while (objHOOK.status = 0)
    while (not objHOOK.stdout.atendofstream)
      strIN = objHOOK.stdout.readline
      if (strIN <> vbnullstring) then
        objOUT.write vbnewline & now & vbtab & vbtab & vbtab & strIN 
        objLOG.write vbnewline & now & vbtab & vbtab & vbtab & strIN 
      end if
    wend
    wscript.sleep 10
    'wend
    strIN = objHOOK.stdout.readall
    if (strIN <> vbnullstring) then
      objOUT.write vbnewline & now & vbtab & vbtab & vbtab & strIN 
      objLOG.write vbnewline & now & vbtab & vbtab & vbtab & strIN 
    end if
  end if
  'retSTOP = objHOOK.exitcode
  set objHOOK = nothing
  if (err.number <> 0) then
    retSTOP = 3
    objOUT.write vbnewline & now & vbtab & vbtab & vbtab & err.number & vbtab & err.description
    objLOG.write vbnewline & now & vbtab & vbtab & vbtab & err.number & vbtab & err.description
    err.clear
  end if
end sub

sub CLEANUP()                                           ''SCRIPT CLEANUP
  if (retSTOP = 0) then                                 ''SCRIPT COMPLETED SUCCESSFULLY
    objOUT.write vbnewline & vbnewline & now & vbtab & " - AGENT_PSEXEC COMPLETE : " & now
    objLOG.write vbnewline & vbnewline & now & vbtab & " - AGENT_PSEXEC COMPLETE : " & now
    err.clear
  elseif (retSTOP <> 0) then                            ''SCRIPT FAILED
    objOUT.write vbnewline & vbnewline & now & vbtab & " - AGENT_PSEXEC FAILURE : " & now
    objLOG.write vbnewline & vbnewline & now & vbtab & " - AGENT_PSEXEC FAILURE : " & now
    ''RAISE CUSTOMIZED ERROR CODE, ERROR CODE WILL BE DEFINED RESTOP NUMBER INDICATING WHICH SECTION FAILED
    call err.raise(vbObjectError + retSTOP, "AGENT_PSEXEC", "fail")
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