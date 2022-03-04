''CODEDROP_FIX.VBS
''SCRIPT IS DESIGNED TO DOWNLOAD AND AUTOMATE 'CODEDROP' FIX FROM SOLARWINDS FOR SELF-HEAL AND COPY/PASTE ISSUES, REF #2 , REF #1
''WRITTEN BY : CJ BLEDSOE / CJ<@>THECOMPUTERWARRIORS.COM
'on error resume next
dim strFIX
''SCRIPT VARIABLES
dim errRET, strVER, strIN, strCDD
''SCRIPT OBJECTS
dim objIN, objOUT, objARG, objWSH
dim objFSO, objLOG, objHOOK, objHTTP, objXML
''SET 'ERRRET' CODE
errRET = 0
''VERSION FOR SCRIPT UPDATE, CODEDROP_FIX.VBS, REF #2 , REF #68 , REF #69
strVER = 8
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
''PREPARE LOGFILE
if (objFSO.fileexists("C:\temp\CODEDROP_FIX")) then		               ''LOGFILE EXISTS
  objFSO.deletefile "C:\temp\CODEDROP_FIX", true
  set objLOG = objFSO.createtextfile("C:\temp\CODEDROP_FIX")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\CODEDROP_FIX", 8)
else                                                                 ''LOGFILE NEEDS TO BE CREATED
  set objLOG = objFSO.createtextfile("C:\temp\CODEDROP_FIX")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\CODEDROP_FIX", 8)
end if
''CHECK EXECUTION METHOD OF SCRIPT
strIN = lcase(mid(wscript.fullname, instrrev(wscript.fullname, "\") + 1))
if (strIN <> "cscript.exe") Then
	''needs to save and pass arguments
  objOUT.write vbnewline & "SCRIPT LAUNCHED VIA EXPLORER, EXECUTING SCRIPT VIA CSCRIPT..."
  objWSH.run "cscript.exe //nologo " & chr(34) & Wscript.ScriptFullName & chr(34)
  wscript.quit
end if
''READ PASSED COMMANDLINE ARGUMENTS
if (wscript.arguments.count > 0) then                                 ''ARGUMENTS WERE PASSED
  for x = 0 to (wscript.arguments.count - 1)
    objOUT.write vbnewline & now & vbtab & " - ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
    objLOG.write vbnewline & now & vbtab & " - ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
  next 
  strFIX = objARG.item(0)                                             ''SET STRING 'STRFIX', CODE DROP FIX SELECTION
elseif (wscript.arguments.count = 0) then                             ''NO ARGUMENTS PASSED , END SCRIPT , 'ERRRET'=1
  call LOGERR(1)
end if

''------------
''BEGIN SCRIPT
if (errRET = 0) then                                                  ''NO ERRORS DURING INITIAL START
  objOUT.write vbnewline & now & " - STARTING CODEDROP_FIX" & vbnewline
  objLOG.write vbnewline & now & " - STARTING CODEDROP_FIX" & vbnewline
  ''AUTOMATIC UPDATE, CODEDROP_FIX.VBS, REF #1 , REF #2 , REF #69 , REF #68
  objOUT.write vbnewline & now & vbtab & vbtab & " - CHECKING FOR UPDATE : CODEDROP_FIX : " & strVER
  objLOG.write vbnewline & now & vbtab & vbtab & " - CHECKING FOR UPDATE : CODEDROP_FIX : " & strVER
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
    ''STOP WINDOWS AGENT SERVICES
    objOUT.write vbnewline & now & vbtab & " - STOPPING WINDOWS AGENT SERVICES"
    objLOG.write vbnewline & now & vbtab & " - STOPPING WINDOWS AGENT SERVICES"
    call HOOK("net stop " & chr(34) & "Windows Agent Maintenance Service" & chr(34))
    wscript.sleep 5000
    call HOOK("net stop " & chr(34) & "Windows Agent Service" & chr(34))
    wscript.sleep 5000
    ''DOWNLOAD CODEDROP 'FIX' FILES
    objOUT.write vbnewline & now & vbtab & " - DOWNLOADING CODEDROP 'FIX' FILES"
    objLOG.write vbnewline & now & vbtab & " - DOWNLOADING CODEDROP 'FIX' FILES"
    if (ucase(strFIX) = "SELFHEAL") then
      ''WINDOWS AGENT CODEDROP Directory
      strCDD = "C:\Program Files (x86)\N-able Technologies\Windows Agent\bin"
      objOUT.write vbnewline & now & vbtab & " - DOWNLOADING CODEDROP 'SELF-HEAL' FILES"
      objLOG.write vbnewline & now & vbtab & " - DOWNLOADING CODEDROP 'SELF-HEAL' FILES"
      call FILEDL("https://raw.githubusercontent.com/CW-Khristos/scripts/master/CodeDrop/selfheal/codedrop_APR2_NCI-15758/agent.exe", "C:\IT", "agent.exe")
      call FILEDL("https://raw.githubusercontent.com/CW-Khristos/scripts/master/CodeDrop/selfheal/codedrop_APR2_NCI-15758/CodeDropMeta.xml", "C:\IT", "CodeDropMeta.xml")
      'call FILEDL("https://raw.githubusercontent.com/CW-Khristos/scripts/master/CodeDrop/selfheal/codedrop_MAR17_NCI-15758/agent.exe", "C:\IT", "agent.exe")
      'call FILEDL("https://raw.githubusercontent.com/CW-Khristos/scripts/master/CodeDrop/selfheal/codedrop_MAR17_NCI-15758/CodeDropMeta.xml", "C:\IT", "CodeDropMeta.xml")
      wscript.sleep 5000
      ''RENAME 'OLD' CODEDROP FILES
      objOUT.write vbnewline & now & vbtab & " - RENAMING 'OLD' CODEDROP FILES"
      objLOG.write vbnewline & now & vbtab & " - RENAMING 'OLD' CODEDROP FILES"
      if objFSO.fileexists(strCDD & "\agent.exe") then
        call HOOK("cmd.exe /C move /y " & chr(34) & strCDD & "\agent.exe" & chr(34) & " " & chr(34) & strCDD & "\agent.old" & chr(34))
      end if
      'if objFSO.fileexists(strSAV) then
      '  call HOOK("cmd.exe /C move /y " & chr(34) & strCDD & "\CodeDropMeta.xml" & chr(34) & " " & chr(34) & strCDD & "\CodeDropMeta.old" & chr(34))
      'end if
      ''MOVE CODEDROP 'FIX' FILES TO APPROPRIATE LOCATION
      objOUT.write vbnewline & now & vbtab & " - MOVING CODEDROP 'FIX' FILES TO APPROPRIATE LOCATION"
      objLOG.write vbnewline & now & vbtab & " - MOVING CODEDROP 'FIX' FILES TO APPROPRIATE LOCATION"
      ''CHECK THAT FILE EXISTS
      if objFSO.fileexists("C:\IT\agent.exe") then
        call HOOK("cmd.exe /C move /y " & chr(34) & "C:\IT\agent.exe" & chr(34) & " " & chr(34) & strCDD & chr(34))
        'objFSO.copyfile "C:\IT\agent.exe", strCDD & "\agent.exe", true
      end if
      ''CHECK THAT FILE EXISTS
      if objFSO.fileexists("C:\IT\CodeDropMeta.xml") then
        call HOOK("cmd.exe /C move /y " & chr(34) & "C:\IT\CodeDropMeta.xml" & chr(34) & " " & chr(34) & strCDD & chr(34))
        'objFSO.copyfile "C:\IT\CodeDropMeta.xml", strCDD & "\CodeDropMeta.xml", true
      end if
    elseif (ucase(strFIX) = "COPYPASTE") then
      strCDD = "C:\Program Files (x86)\N-Able Technologies\Reactive\bin"
      objOUT.write vbnewline & now & vbtab & " - DOWNLOADING CODEDROP 'COPY/PASTE' FILES"
      objLOG.write vbnewline & now & vbtab & " - DOWNLOADING CODEDROP 'COPY/PASTE' FILES"
      call FILEDL("https://raw.githubusercontent.com/CW-Khristos/scripts/master/CodeDrop/copypaste/ConsoleAPIWrapper32_64/ConsoleAPIWrapper32.dll", "C:\IT", "ConsoleAPIWrapper32.dll")
      call FILEDL("https://raw.githubusercontent.com/CW-Khristos/scripts/master/CodeDrop/copypaste/ConsoleAPIWrapper32_64/ConsoleAPIWrapper64.dll", "C:\IT", "ConsoleAPIWrapper64.dll")
      wscript.sleep 5000
      ''RENAME 'OLD' CODEDROP FILES
      objOUT.write vbnewline & now & vbtab & " - RENAMING 'OLD' CODEDROP FILES"
      objLOG.write vbnewline & now & vbtab & " - RENAMING 'OLD' CODEDROP FILES"
      if objFSO.fileexists(strCDD & "\ConsoleAPIWrapper32.dll") then
        call HOOK("cmd.exe /C move /y " & chr(34) & strCDD & "\ConsoleAPIWrapper32.dll" & chr(34) & " " & chr(34) & strCDD & "\ConsoleAPIWrapper32.old" & chr(34))
      end if
      if objFSO.fileexists(strCDD & "\ConsoleAPIWrapper64.dll") then
        call HOOK("cmd.exe /C move /y " & chr(34) & strCDD & "\ConsoleAPIWrapper64.dll" & chr(34) & " " & chr(34) & strCDD & "\ConsoleAPIWrapper64.old" & chr(34))
      end if
      ''MOVE CODEDROP 'FIX' FILES TO APPROPRIATE LOCATION
      objOUT.write vbnewline & now & vbtab & " - MOVING CODEDROP 'FIX' FILES TO APPROPRIATE LOCATION"
      objLOG.write vbnewline & now & vbtab & " - MOVING CODEDROP 'FIX' FILES TO APPROPRIATE LOCATION"
      ''CHECK THAT FILE EXISTS
      if objFSO.fileexists("C:\IT\ConsoleAPIWrapper32.dll") then
        call HOOK("cmd.exe /C move /y " & chr(34) & "C:\IT\ConsoleAPIWrapper32.dll" & chr(34) & " " & chr(34) & strCDD & chr(34))
        'objFSO.copyfile "C:\IT\ConsoleAPIWrapper32.dll", strCDD & "\ConsoleAPIWrapper32.dll", true
      end if
      ''CHECK THAT FILE EXISTS
      if objFSO.fileexists("C:\IT\ConsoleAPIWrapper64.dll") then
        call HOOK("cmd.exe /C move /y " & chr(34) & "C:\IT\ConsoleAPIWrapper64.dll" & chr(34) & " " & chr(34) & strCDD & chr(34))
        'objFSO.copyfile "C:\IT\ConsoleAPIWrapper64.dll", strCDD & "\ConsoleAPIWrapper64.dll", true
      end if
    end if
    ''RESTART WINDOWS AGENT SERVICES
    objOUT.write vbnewline & now & vbtab & " - RESTARTING WINDOWS AGENT SERVICES"
    objLOG.write vbnewline & now & vbtab & " - RESTARTING WINDOWS AGENT SERVICES"
    wscript.sleep 5000
    call HOOK("net start " & chr(34) & "Windows Agent Maintenance Service" & chr(34))
    wscript.sleep 5000
    call HOOK("net start " & chr(34) & "Windows Agent Service" & chr(34))
    wscript.sleep 5000
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
  objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & vbtab & "HTTPDOWNLOAD-------------DOWNLOAD : " & strURL & " : SAVE AS :  " & strSAV
  objLOG.write vbnewline & vbnewline & now & vbtab & vbtab & vbtab & "HTTPDOWNLOAD-------------DOWNLOAD : " & strURL & " : SAVE AS :  " & strSAV
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
  ''CHECK FOR ERRORS
  errRET = objHOOK.exitcode
  set objHOOK = nothing
  if ((not blnSUP) and (err.number <> 0)) then
    objOUT.write vbnewline & now & vbtab & vbtab & vbtab & err.number & vbtab & err.description
    objLOG.write vbnewline & now & vbtab & vbtab & vbtab & err.number & vbtab & err.description
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
      objOUT.write vbnewline & vbnewline & now & vbtab & " - SCRIPT REQUIRES CODE DROP FIX SELECTION : SELFHEAL / COPYPASTE"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - SCRIPT REQUIRES CODE DROP FIX SELECTION : SELFHEAL / COPYPASTE"
  end select
end sub

sub CLEANUP()                                 			        ''SCRIPT CLEANUP
  on error resume next
  if (errRET = 0) then         											        ''CODEDROP_FIX COMPLETED SUCCESSFULLY
    objOUT.write vbnewline & vbnewline & now & vbtab & " - CODEDROP_FIX SUCCESSFUL : " & now
    objLOG.write vbnewline & vbnewline & now & vbtab & " - CODEDROP_FIX SUCCESSFUL : " & now
    err.clear
  elseif (errRET <> 0) then    											        ''CODEDROP_FIX FAILED
    objOUT.write vbnewline & vbnewline & now & vbtab & " - CODEDROP_FIX FAILURE : " & errRET & " : " & now
    objLOG.write vbnewline & vbnewline & now & vbtab & " - CODEDROP_FIX FAILURE : " & errRET & " : " & now
    ''RAISE CUSTOMIZED ERROR CODE, ERROR CODE WILL BE DEFINE RESTOP NUMBER INDICATING WHICH SECTION FAILED
    call err.raise(vbObjectError + errRET, "CODEDROP_FIX", "FAILURE")
  end if
  objOUT.write vbnewline & vbnewline & now & " - CODEDROP_FIX COMPLETE" & vbnewline
  objLOG.write vbnewline & vbnewline & now & " - CODEDROP_FIX COMPLETE" & vbnewline
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