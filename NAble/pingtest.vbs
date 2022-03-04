''PINGTEST.VBS
''AUTOMATICALLY RUNS PING TO TARGET IP IN AN INFINITE LOOP
''AUTOMATICALLY RUNS NSLOOKUP TO TARGET IP AND IPCONFIG /FLUSHDNS
''WRITTEN BY : CJ BLEDSOE / CBLEDSOE<@>IPMCOMPUTERS.COM
''ACCEPTS 1 PARAMETERS , REQUIRES 1 PARAMETERS
''REQUIRED PARAMETER 'STRIP' ; STRING VALUE TO HOLD PASSED IP ADDRESS ; TARGET IP TO PERFORM NSLOOKUP
on error resume next
''SCRIPT VARIABLES
dim strIDL, strTMP, arrTMP, strIN, strIP
dim errRET, strVER, blnRUN, blnSUP, strPath
''SCRIPT OBJECTS
dim objIN, objOUT, objARG, objWSH
dim objFSO, objLOG, objHOOK, objHTTP, objXML
''VSS WRITER FLAGS
dim blnIIS, blnNPS, blnTSG
dim blnAHS, blnBIT, blnCSVC, blnRDP
dim blnSQL, blnTSK, blnVSS, blnWMI, blnWSCH
''SET 'ERRRET' CODE
errRET = 0
''VERSION FOR SCRIPT UPDATE, REF #2 , REF #68 , REF #69
strVER = 3
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
if (objFSO.fileexists("C:\temp\PINGTEST")) then             ''LOGFILE EXISTS
  objFSO.deletefile "C:\temp\PINGTEST", true
  set objLOG = objFSO.createtextfile("C:\temp\PINGTEST")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\PINGTEST", 8)
else                                                        ''LOGFILE NEEDS TO BE CREATED
  set objLOG = objFSO.createtextfile("C:\temp\PINGTEST")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\PINGTEST", 8)
end if
''READ PASSED COMMANDLINE ARGUMENTS
if (wscript.arguments.count > 0) then                       ''ARGUMENTS WERE PASSED
  for x = 0 to (wscript.arguments.count - 1)
    objOUT.write vbnewline & now & vbtab & " - ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
    objLOG.write vbnewline & now & vbtab & " - ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
  next 
  if (wscript.arguments.count >= 1) then                     ''SET REQUIRED VARIABLES ACCEPTING ARGUMENTS
    strIP = objARG.item(0)                                   ''SET REQUIRED PARAMETER 'STRIP' , TARGET IP ADDRESS TO PING
  else                                                       ''NOT ENOUGH ARGUMENTS PASSED , END SCRIPT , 'ERRRET'=1
    call LOGERR(1)
  end if
else                                                         ''NOT ENOUGH ARGUMENTS PASSED , END SCRIPT , 'ERRRET'=1
    call LOGERR(1)
end if

''------------
''BEGIN SCRIPT
if (errRET = 0) then                                          ''ARGUMENTS PASSED, CONTINUE SCRIPT
  objOUT.write vbnewline & now & " - STARTING PINGTEST - " & strIP & vbnewline
  objLOG.write vbnewline & now & " - STARTING PINGTEST - " & strIP & vbnewline
	''AUTOMATIC UPDATE, PINGTEST.VBS, REF #2 , REF #69 , REF #68
  objOUT.write vbnewline & now & vbtab & vbtab & " - CHECKING FOR UPDATE : PINGTEST : " & strVER
  objLOG.write vbnewline & now & vbtab & vbtab & " - CHECKING FOR UPDATE : PINGTEST : " & strVER
  ''DOWNLOAD CHKAU.VBS SCRIPT, REF #2 , REF #69 , REF #68
  call FILEDL("https://raw.githubusercontent.com/CW-Khristos/scripts/master/chkAU.vbs", "C:\IT\Scripts", "chkAU.vbs")
  ''EXECUTE CHKAU.VBS SCRIPT, REF #69
  intRET = objWSH.run ("cmd.exe /C " & chr(34) & "cscript.exe " & chr(34) & "C:\IT\Scripts\chkAU.vbs" & chr(34) & " " & _
    chr(34) & strREPO & chr(34) & " " & chr(34) & strBRCH & chr(34) & " " & chr(34) & strDIR & chr(34) & " " & _
    chr(34) & wscript.scriptname & chr(34) & " " & chr(34) & strVER & chr(34) & " " & _
    chr(34) & strIP & chr(34) & chr(34), 0, true)
  ''CHKAU RETURNED - NO UPDATE FOUND , REF #2 , REF #69 , REF #68
  objOUT.write vbnewline & "errRET='" & intRET & "'"
  objLOG.write vbnewline & "errRET='" & intRET & "'"
  intRET = (intRET - vbObjectError)
  objOUT.write vbnewline & "errRET='" & intRET & "'"
  objLOG.write vbnewline & "errRET='" & intRET & "'"
  if ((intRET = 4) or (intRET = 10) or (intRET = 11) or (intRET = 1) or (intRET = 2147221505) or (intRET = 2147221517)) then
    objOUT.write vbnewline & now & vbtab & " - LOOPING"
    objLOG.write vbnewline & now & vbtab & " - LOOPING"
    ''INFITIE LOOP
    while (strLOOP = vbnullstring)
      objOUT.write vbnewline & now & vbtab & vbtab & " - PINGTEST : " & strIP
      objLOG.write vbnewline & now & vbtab & vbtab & " - PINGTEST : " & strIP
      set objEXEC = objWSH.exec("%SystemRoot%\system32\ping.exe -n 5 " & strIP)
      while (not objEXEC.stdout.atendofstream)
        wscript.sleep 10
        strIN = objEXEC.stdout.readline
        if (strIN <> vbnullstring) then
          objOUT.write vbnewline & now & vbtab & vbtab & vbtab & strIN
          objLOG.write vbnewline & now & vbtab & vbtab & vbtab & strIN
        end if
      wend
      strIN = objEXEC.stdout.readall
      set objEXEC = nothing
      if ((instr(1, strIN, "Destination host unreachable")) or (instr(1, strIN, "Request timed out")) or (instr(1, strIN, "could not find host"))) then'
        call HOOK("nslookup " & strIP)
        call HOOK("tracert -d -w 200 -h 10 " & strIP)
        call HOOK("ipconfig /flushdns")
      end if
      wscript.sleep 100
    wend
  end if
elseif (errRET <> 0) then                                     ''NO ARGUMENTS PASSED, END SCRIPT , 'ERRRET'=1
  call LOGERR(errRET)
end if
''END SCRIPT
call CLEANUP()
''END SCRIPT
''------------

''SUB-ROUTINES
sub FILEDL(strURL, strDL, strFILE)                            ''CALL HOOK TO DOWNLOAD FILE FROM URL , 'ERRRET'=11
  strSAV = vbnullstring
  ''SET DOWNLOAD PATH
  strSAV = strDL & "\" & strFILE
  objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & "HTTPDOWNLOAD-------------DOWNLOAD : " & strURL & " : SAVE AS :  " & strSAV
  objLOG.write vbnewline & vbnewline & now & vbtab & vbtab & "HTTPDOWNLOAD-------------DOWNLOAD : " & strURL & " : SAVE AS :  " & strSAV
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

sub HOOK(strCMD)                                            ''CALL HOOK TO MONITOR OUTPUT OF CALLED COMMAND , 'ERRRET'=3
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
  ''CHECK FOR ERRORS
  errRET = objHOOK.exitcode
  set objHOOK = nothing
  if ((not blnSUP) and (err.number <> 0)) then
    objOUT.write vbnewline & now & vbtab & vbtab & vbtab & err.number & vbtab & err.description
    objLOG.write vbnewline & now & vbtab & vbtab & vbtab & err.number & vbtab & err.description
    call LOGERR(3)
  end if
end sub

sub LOGERR(intSTG)                                            ''CALL HOOK TO MONITOR OUTPUT OF CALLED COMMAND
  errRET = intSTG
  if (err.number <> 0) then
    objOUT.write vbnewline & now & vbtab & vbtab & vbtab & err.number & vbtab & err.description & vbnewline
    objLOG.write vbnewline & now & vbtab & vbtab & vbtab & err.number & vbtab & err.description & vbnewline
		err.clear
  end if
end sub

sub CLEANUP()                                 			        ''SCRIPT CLEANUP
  on error resume next
  if (errRET = 0) then         											        ''PINGTEST COMPLETED SUCCESSFULLY
    objOUT.write vbnewline & vbnewline & now & vbtab & " - PINGTEST SUCCESSFUL : " & now
    objLOG.write vbnewline & vbnewline & now & vbtab & " - PINGTEST SUCCESSFUL : " & now
    err.clear
  elseif (errRET <> 0) then    											        ''PINGTEST FAILED
    objOUT.write vbnewline & vbnewline & now & vbtab & " - PINGTEST FAILURE : " & errRET & " : " & now
    objLOG.write vbnewline & vbnewline & now & vbtab & " - PINGTEST FAILURE : " & errRET & " : " & now
    ''RAISE CUSTOMIZED ERROR CODE, ERROR CODE WILL BE DEFINE RESTOP NUMBER INDICATING WHICH SECTION FAILED
    call err.raise(vbObjectError + errRET, "PINGTEST", "FAILURE")
  end if
  objOUT.write vbnewline & vbnewline & now & " - PINGTEST COMPLETE" & vbnewline
  objLOG.write vbnewline & vbnewline & now & " - PINGTEST COMPLETE" & vbnewline
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