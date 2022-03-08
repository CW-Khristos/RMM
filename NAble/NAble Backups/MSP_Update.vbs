''https://cdn.cloudbackup.management/maxdownloads/mxb-windows-x86_x64.exe
''MSP_UPDATE.VBS
''SCRIPT IS DESIGNED TO AUTOMATICALLY DOWNLOAD AND INSTALL MSP BACKUPS FROM DIRECT LINK
''SCRIPT WILL CHECK STATUS OF BACKUPS PRIOR TO UPDATE; IF BACKUPS ARE IN PROGRESS, UPDATE WILL NOT PROCEED
''WRITTEN BY : CJ BLEDSOE / CJ<@>THECOMPUTERWARRIORS.COM
on error resume next
''SCRIPT VARIABLES
dim errRET, strVER
dim strREPO, strBRCH, strDIR
''VARIABLES ACCEPTING PARAMETERS
dim strIDL, strIN
''SCRIPT OBJECTS
dim objFSO, objLOG, objHOOK
dim objIN, objOUT, objARG, objWSH
''VERSION FOR SCRIPT UPDATE, MSP_UPDATE.VBS, REF #2
strVER = 4
strREPO = "scripts"
strBRCH = "master"
strDIR = "MSP Backups"
''SET 'ERRRET' CODE
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
''CHECK EXECUTION METHOD OF SCRIPT
strIN = lcase(mid(wscript.fullname, instrrev(wscript.fullname, "\") + 1))
if (strIN <> "cscript.exe") Then
  objOUT.write vbnewline & "SCRIPT LAUNCHED VIA EXPLORER, EXECUTING SCRIPT VIA CSCRIPT..."
  objWSH.run "cscript.exe //nologo " & chr(34) & Wscript.ScriptFullName & chr(34)
  wscript.quit
end if
''PREPARE LOGFILE
if (objFSO.fileexists("C:\temp\MSP_UPDATE")) then                                                           ''LOGFILE EXISTS
  objFSO.deletefile "C:\temp\MSP_UPDATE", true
  set objLOG = objFSO.createtextfile("C:\temp\MSP_UPDATE")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\MSP_UPDATE", 8)
else                                                                                                        ''LOGFILE NEEDS TO BE CREATED
  set objLOG = objFSO.createtextfile("C:\temp\MSP_UPDATE")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\MSP_UPDATE", 8)
end if
''READ PASSED COMMANDLINE ARGUMENTS
if (wscript.arguments.count > 0) then                                                                       ''ARGUMENTS WERE PASSED
  for x = 0 to (wscript.arguments.count - 1)
    objOUT.write vbnewline & now & vbtab & " - ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
    objLOG.write vbnewline & now & vbtab & " - ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
  next 
else                                                                                                        ''NO ARGUMENTS PASSED, END SCRIPT
  objOUT.write vbnewline & vbnewline & now & vbtab & " - NO ARGUMENTS PASSED"
  objLOG.write vbnewline & vbnewline & now & vbtab & " - NO ARGUMENTS PASSED"
end if

''------------
''BEGIN SCRIPT
if (errRET = 0) then                                                                                        ''NO ERRORS DURING INITIAL START
  blnCOM = false
  psURL = vbnullstring
  wmfURL = vbnullstring
  objOUT.write vbnewline & vbnewline & now & vbtab & " - EXECUTING MSP_UPDATE"
  objLOG.write vbnewline & vbnewline & now & vbtab & " - EXECUTING MSP_UPDATE"
	''AUTOMATIC UPDATE, MSP_UPDATE.VBS, REF #2 , REF #69 , REF #68
  objOUT.write vbnewline & now & vbtab & vbtab & " - CHECKING FOR UPDATE : MSP_UPDATE : " & strVER
  objLOG.write vbnewline & now & vbtab & vbtab & " - CHECKING FOR UPDATE : MSP_UPDATE : " & strVER
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
    ''CHECK MSP BACKUP STATUS VIA MSP BACKUP CLIENTTOOL UTILITY
    objOUT.write vbnewline & now & vbtab & " - CHECKING MSP BACKUP STATUS"
    objLOG.write vbnewline & now & vbtab & " - CHECKING MSP BACKUP STATUS"
    set objHOOK = objWSH.exec(chr(34) & "c:\Program Files\Backup Manager\ClientTool.exe" & chr(34) & " control.status.get")
    strIDL = objHOOK.stdout.readall
    objOUT.write vbnewline & now & vbtab & vbtab & vbtab & strIDL
    objLOG.write vbnewline & now & vbtab & vbtab & vbtab & strIDL
    set objHOOK = nothing
    if (strIDL = vbnullstring) then
      objOUT.write vbnewline & now & vbtab & vbtab & " - CLIENTTOOL NOT AVAILABLE"
      objLOG.write vbnewline & now & vbtab & vbtab & " - CLIENTTOOL NOT AVAILABLE"
      call LOGERR(1)
      ''DOWNLOAD MSP BACKUP CLIENT
      objOUT.write vbnewline & now & vbtab & " - DOWNLOADING LATEST MSP BACKUP CLIENT"
      objLOG.write vbnewline & now & vbtab & " - DOWNLOADING LATEST MSP BACKUP CLIENT"
      call FILEDL("https://cdn.cloudbackup.management/maxdownloads/mxb-windows-x86_x64.exe", "C:\IT", "mxb-windows-x86_x64.exe")
      ''INSTALL MSP BACKUP MANAGER
      objOUT.write vbnewline & now & vbtab & " - INSTALLING LATEST MSP BACKUP CLIENT"
      objLOG.write vbnewline & now & vbtab & " - INSTALLING LATEST MSP BACKUP CLIENT"
      call HOOK("C:\IT\mxb-windows-x86_x64.exe")
    elseif ((instr(1, strIDL, "Idle") = 0) and (instr(1, strIDL, "RegSync") = 0)) then                          ''BACKUPS IN PROGRESS , 'ERRRET'=1
      objOUT.write vbnewline & now & vbtab & vbtab & " - BACKUPS IN PROGRESS, ENDING MSP_UPDATE"
      objLOG.write vbnewline & now & vbtab & vbtab & " - BACKUPS IN PROGRESS, ENDING MSP_UPDATE"
      call LOGERR(2)
    elseif (((instr(1, strIDL, "Idle")) or (instr(1, strIDL, "RegSync")) or (strIDL = vbnullstring))) then      ''BACKUPS NOT IN PROGRESS
      ''DOWNLOAD MSP BACKUP CLIENT
      objOUT.write vbnewline & now & vbtab & " - DOWNLOADING LATEST MSP BACKUP CLIENT"
      objLOG.write vbnewline & now & vbtab & " - DOWNLOADING LATEST MSP BACKUP CLIENT"
      call FILEDL("https://cdn.cloudbackup.management/maxdownloads/mxb-windows-x86_x64.exe", "C:\IT", "mxb-windows-x86_x64.exe")
      ''INSTALL MSP BACKUP MANAGER
      objOUT.write vbnewline & now & vbtab & " - INSTALLING LATEST MSP BACKUP CLIENT"
      objLOG.write vbnewline & now & vbtab & " - INSTALLING LATEST MSP BACKUP CLIENT"
      call HOOK("C:\IT\mxb-windows-x86_x64.exe")
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
sub FILEDL(strURL, strDL, strFILE)                                                                          ''CALL HOOK TO DOWNLOAD FILE FROM URL , 'ERRRET'=11
  strSAV = vbnullstring
  ''SET DOWNLOAD PATH
  strSAV = strDL & "\" & strFILE
  objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "HTTPDOWNLOAD-------------DOWNLOAD : " & strURL & " : SAVE AS :  " & strSAV
  objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "HTTPDOWNLOAD-------------DOWNLOAD : " & strURL & " : SAVE AS :  " & strSAV
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
  if ((err.number <> 0) and (err.number <> 58)) then                                                        ''ERROR RETURNED DURING DOWNLOAD , 'ERRRET'=11
    call LOGERR(11)
  end if
end sub

sub HOOK(strCMD)                                                                                            ''CALL HOOK TO MONITOR OUTPUT OF CALLED COMMAND , 'ERRRET'=12
  on error resume next
  objOUT.write vbnewline & now & vbtab & vbtab & " - EXECUTING : HOOK(" & strCMD & ")"
  objLOG.write vbnewline & now & vbtab & vbtab & " - EXECUTING : HOOK(" & strCMD & ")"
  set objHOOK = objWSH.exec(strCMD)
  if (instr(1, strCMD, "takeown /F ") = 0) then                                                             ''SUPPRESS 'TAKEOWN' SUCCESS MESSAGES
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
  if (err.number <> 0) then                                                                                 ''ERROR RETURNED DURING UPDATE CHECK , 'ERRRET'=12
    call LOGERR(12)
  end if
end sub

sub LOGERR(intSTG)                                                                                          ''CALL HOOK TO MONITOR OUTPUT OF CALLED COMMAND
  errRET = intSTG
  if (err.number <> 0) then
    objOUT.write vbnewline & now & vbtab & vbtab & vbtab & err.number & vbtab & err.description & vbnewline
    objLOG.write vbnewline & now & vbtab & vbtab & vbtab & err.number & vbtab & err.description & vbnewline
		err.clear
  end if
  ''CUSTOM ERROR CODES
  select case intSTG
    case 1                                                                                                  '' 'ERRRET'=1 - NOT ENOUGH ARGUMENTS
  end select
end sub

sub CLEANUP()                                                                                               ''SCRIPT CLEANUP
  if (errRET = 0) then         												                                                      ''MSP_UPDATE COMPLETED SUCCESSFULLY
    objOUT.write vbnewline & vbnewline & now & vbtab & " - MSP_UPDATE SUCCESSFUL : " & now
    objLOG.write vbnewline & vbnewline & now & vbtab & " - MSP_UPDATE SUCCESSFUL : " & now
    err.clear
  elseif (errRET <> 0) then    												                                                      ''MSP_UPDATE FAILED
    objOUT.write vbnewline & vbnewline & now & vbtab & " - MSP_UPDATE FAILURE : " & errRET & " : " & now
    objLOG.write vbnewline & vbnewline & now & vbtab & " - MSP_UPDATE FAILURE : " & errRET & " : " & now
    ''RAISE CUSTOMIZED ERROR CODE, ERROR CODE WILL BE DEFINE RESTOP NUMBER INDICATING WHICH SECTION FAILED
    call err.raise(vbObjectError + errRET, "MSP_UPDATE", "FAILURE")
  end if
  objOUT.write vbnewline & vbnewline & now & " - MSP_UPDATE COMPLETE" & vbnewline
  objLOG.write vbnewline & vbnewline & now & " - MSP_UPDATE COMPLETE" & vbnewline
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