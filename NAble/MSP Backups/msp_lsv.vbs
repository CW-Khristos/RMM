''MSP_LSV.VBS
''NO REQUIRED PARAMETERS / DOES NOT ACCEPT PARAMETERS
''SCRIPT IS DESIGNED TO SIMPLY EXPORT MSP BACKUP SETTINGS USING CLIENTTOOL.EXE UTILITY
''EXPORTS MSP BACKUP SETTINGS TO C:\IT\SCRIPTS\LSV.TXT
''MUST BE USED IN CONJUNCTION WITH MSP BACKUP SYNCHRONIZATION - LSV SYNCHRONIZATION.AMP CUSTOM SERVICE
''WRITTEN BY : CJ BLEDSOE / CJ<@>THECOMPUTERWARRIORS.COM
on error resume next
''SCRIPT VARIABLES
dim strVER, errRET
dim strREPO, strBRCH, strDIR
dim strDLM, intDIFF, retDEL
''SCRIPT OBJECTS
dim objIN, objOUT, objARG
dim objHOOK, objHTTP, objXML
dim objWSH, objFSO, objLOG, objLSV
''DEFAULT SUCCESS
errRET = 0
''VERSION FOR SCRIPT UPDATE, MSP_LSV.VBS, REF #2 , REF #68 , REF #69
strVER = 8
strREPO = "scripts"
strBRCH = "master"
strDIR = "MSP Backups"
''STDIN / STDOUT
set objIN = wscript.stdin
set objOUT = wscript.stdout
set objARG = wscript.arguments
''CREATE SCRIPTING OBJECTS
set objWSH = createobject("wscript.shell")
set objFSO = createobject("scripting.filesystemobject")
''CHECK 'PERSISTENT' FOLDERS
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
if (objFSO.fileexists("c:\temp\msp_lsv")) then                ''PREVIOUS LOGFILE EXISTS
  objFSO.deletefile "c:\temp\msp_lsv", true
  set objLOG = objFSO.createtextfile("c:\temp\msp_lsv")
  objLOG.close
  set objLOG = objFSO.opentextfile("c:\temp\msp_lsv", 8)
else                                                        	''LOGFILE NEEDS TO BE CREATED
  set objLOG = objFSO.createtextfile("c:\temp\msp_lsv")
  objLOG.close
  set objLOG = objFSO.opentextfile("c:\temp\msp_lsv", 8)
end if
''CHECK FOR MSP BACKUP MANAGER CLIENTTOOL , REF #76
if (objFSO.fileexists("C:\Program Files\Backup Manager\clienttool.exe")) then
  call LOGERR(0)                                            	''CLIENTTOOL.EXE PRESENT, CONTINUE SCRIPT, 'ERRRET'=0
elseif (not objFSO.fileexists("C:\Program Files\Backup Manager\clienttool.exe")) then
  call LOGERR(1)                                            	''CLIENTTOOL.EXE NOT PRESENT, END SCRIPT, 'ERRRET'=1
end if
''CHECK BACKUP SERVICE CONTROLLER SERVICE IS STARTED
set objHOOK = objWSH.exec("sc query " & chr(34) & "Backup Service Controller" & chr(34))
while (not objHOOK.stdout.atendofstream)
  strIN = objHOOK.stdout.readline
  if (strIN <> vbnullstring) then
    if (instr(1, strIN, "RUNNING")) then
      blnSVC = true
    elseif (instr(1, strIN, "STOPPED")) then
      blnSVC = false
    end if
  end if
wend
if (blnSVC = false) then
  call LOGERR(2)
end if
''PREPARE MONITOR FILE
if (objFSO.fileexists("C:\IT\Scripts\lsv.txt")) then        ''PREVIOUS LOGFILE EXISTS
  objFSO.deletefile "C:\IT\Scripts\lsv.txt", true
  set objLSV = objFSO.createtextfile("C:\IT\Scripts\lsv.txt")
  objLSV.close
  set objLSV = objFSO.opentextfile("C:\IT\Scripts\lsv.txt", 8)
else                                                        ''LOGFILE NEEDS TO BE CREATED
  set objLSV = objFSO.createtextfile("C:\IT\Scripts\lsv.txt")
  objLSV.close
  set objLSV = objFSO.opentextfile("C:\IT\Scripts\lsv.txt", 8)
end if
''CHECK EXECUTION METHOD OF SCRIPT
strIN = lcase(mid(wscript.fullname, instrrev(wscript.fullname, "\") + 1))
if (strIN <> "cscript.exe") Then                            ''LAUNCHED VIA WSCRIPT, RE-LAUNCH WITH CSCRIPT
  objOUT.write vbnewline & "SCRIPT LAUNCHED VIA EXPLORER, EXECUTING SCRIPT VIA CSCRIPT..."
  objWSH.run "cscript.exe //nologo " & chr(34) & Wscript.ScriptFullName & chr(34)
  wscript.quit
end if
''NO ARGUMENTS REQUIRED
''READ PASSED COMMANDLINE ARGUMENTS
'if (wscript.arguments.count > 0) then                      ''ARGUMENTS WERE PASSED
'  for x = 0 to (wscript.arguments.count - 1)
'    objOUT.write vbnewline & now & vbtab & "ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
'  next 
'end if

''------------
''BEGIN SCRIPT
if (errRET = 0) then                                        ''ARGUMENTS PASSED , CONTINUE SCRIPT
  objOUT.write vbnewline & vbnewline & now & vbtab & " - EXECUTING MSP_LSV"
  objLOG.write vbnewline & vbnewline & now & vbtab & " - EXECUTING MSP_LSV"
	''AUTOMATIC UPDATE, MSP_LSV.VBS, REF #2 , REF #69 , REF #68 , FIXES #32 , REF #71
  objOUT.write vbnewline & now & vbtab & vbtab & " - CHECKING FOR UPDATE : MSP_LSV : " & strVER
  objLOG.write vbnewline & now & vbtab & vbtab & " - CHECKING FOR UPDATE : MSP_LSV : " & strVER
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
  if ((intRET = 4) or (intRET = 10) or (intRET = 11) or (intRET = 1) or (intRET = 2147221517)) then
    objOUT.write vbnewline & now & vbtab & vbtab & " - NO UPDATE FOUND : MSP_LSV : " & strVER
    objLOG.write vbnewline & now & vbtab & vbtab & " - NO UPDATE FOUND : MSP_LSV : " & strVER
    ''EXPORT MSP BACKUP SETTINGS USING CLIENTTOOL UTILITY
    'call HOOK("C:\Program Files\Backup Manager\clienttool.exe control.setting.list > " & chr(34) & "C:\IT\Scripts" & chr(34))
    set objHOOK = objWSH.exec("C:\Program Files\Backup Manager\clienttool.exe control.setting.list")
    strIN = objHOOK.stdout.readall
    arrIN = split(strIN, vbnewline)
    ''WRITE SCRIPT LOGFILE
    for intIN = 0 to ubound(arrIN)
      ''CHECK SETTINGS LINE BY LINE, EXCLUDE THE 'C:\WINDOWS\TEMP' AND 'C:\TEMP' DIRECTORIES TO AVOID FALSE MONITOR ALERTS
      if ((instr(1, lcase(arrIN(intIN)), "c:\") = 0) and _
        (instr(1,lcase(arrIN(intIN)), "\temp") = 0)) then
          objOUT.write vbnewline & now & vbtab & arrIN(intIN)
          objLOG.write vbnewline & now & vbtab & arrIN(intIN)
      end if
    next
    intIN = 0
    ''WRITE MONITOR FILE
    for intIN = 0 to ubound(arrIN)
      ''CHECK SETTINGS LINE BY LINE, EXCLUDE THE 'C:\WINDOWS\TEMP' AND 'C:\TEMP' DIRECTORIES TO AVOID FALSE MONITOR ALERTS
      if ((instr(1, lcase(arrIN(intIN)), "c:\") = 0) and _
        (instr(1,lcase(arrIN(intIN)), "\temp") = 0)) then
          ''EXCLUDE ALL OUTPUT EXCEPT FOR LSV LOCATION
          if (instr(1, lcase(arrIN(intIN)),"localspeedvaultlocation")) then
            ''REMOVE LOCALSPEEDVAULTLOCATION 'LABEL', OUTPUT ONLY THE ACTUAL LSV DIRECTORY
            strTMP = split(lcase(arrIN(intIN)), "localspeedvaultlocation ")(1)
            objOUT.write vbnewline & now & vbtab & arrIN(intIN) & " - WRITTEN TO LSV.TXT"
            objLSV.write ucase(strTMP)
            exit for
          end if
      end if
    next
    set objHOOK = nothing
  end if
elseif (errRET <> 0) then
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
  objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "HTTPDOWNLOAD-------------DOWNLOAD : " & strURL & " : SAVE AS :  " & strSAV
  objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "HTTPDOWNLOAD-------------DOWNLOAD : " & strURL & " : SAVE AS :  " & strSAV
  if objFSO.fileexists(strSAV) then
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
  if objFSO.fileexists(strSAV) then
    objOUT.write vbnewline & now & vbtab & vbtab & " - DOWNLOAD : " & strSAV & " : SUCCESSFUL"
    objLOG.write vbnewline & now & vbtab & vbtab & " - DOWNLOAD : " & strSAV & " : SUCCESSFUL"
  end if
	set objHTTP = nothing
  if ((err.number <> 0) and (err.number <> 58)) then        ''ERROR RETURNED DURING UPDATE CHECK , 'ERRRET'=11
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
    case 0                                                  ''MSP_LSV - CLIENTTOOL CHECK PASSED, 'ERRRET'=0
      objOUT.write vbnewline & vbnewline & now & vbtab & " - MSP_LSV - CLIENTTOOL CHECK PASSED"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - MSP_LSV - CLIENTTOOL CHECK PASSED"
    case 1                                                  ''MSP_LSV - CLIENTTOOL CHECK FAILED, 'ERRRET'=1
      objOUT.write vbnewline & vbnewline & now & vbtab & " - MSP_LSV - CLIENTTOOL CHECK FAILED, ENDING MSP_LSV"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - MSP_LSV - CLIENTTOOL CHECK FAILED, ENDING MSP_LSV"
    case 2                                                  ''MSP_LSV - BACKUP SERVICE CONTROLLER NOT STARTED, 'ERRRET'=2
      objOUT.write vbnewline & vbnewline & now & vbtab & " - MSP_LSV - BACKUP SERVICE CONTROLLER NOT STARTED"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - MSP_LSV - BACKUP SERVICE CONTROLLER NOT STARTED"
    case 3                                                  ''MSP_LSV - NO / NOT ENOUGH ARGUMENTS PASSED, 'ERRRET'=3
      objOUT.write vbnewline & vbnewline & now & vbtab & " - MSP_LSV - NO / NOT ENOUGH ARGUMENTS PASSED"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - MSP_LSV - NO / NOT ENOUGH ARGUMENTS PASSED"
    case 11                                                 ''MSP_LSV - CALL FILEDL() , 'ERRRET'=11
      objOUT.write vbnewline & vbnewline & now & vbtab & " - MSP_LSV - CALL FILEDL() : " & strSAV
      objLOG.write vbnewline & vbnewline & now & vbtab & " - MSP_LSV - CALL FILEDL() : " & strSAV
    case 12                                                 ''MSP_LSV - 'VSS CHECKS' - MAX ITERATIONS REACHED , 'ERRRET'=12
      objOUT.write vbnewline & vbnewline & now & vbtab & " - MSP_LSV - CALL HOOK('STRCMD') : " & strCMD & " : FAILED"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - MSP_LSV - CALL HOOK('STRCMD') : " & strCMD & " : FAILED"
  end select
end sub

sub CLEANUP()                                 			        ''SCRIPT CLEANUP
  on error resume next
  if (errRET = 0) then         											        ''MSP_LSV COMPLETED SUCCESSFULLY
    objOUT.write vbnewline & vbnewline & now & vbtab & " - MSP_LSV SUCCESSFUL : " & now
    objLOG.write vbnewline & vbnewline & now & vbtab & " - MSP_LSV SUCCESSFUL : " & now
    err.clear
  elseif (errRET <> 0) then    											        ''MSP_LSV FAILED
    objOUT.write vbnewline & vbnewline & now & vbtab & " - MSP_LSV FAILURE : " & now & " : " & errRET
    objLOG.write vbnewline & vbnewline & now & vbtab & " - MSP_LSV FAILURE : " & now & " : " & errRET
    ''RAISE CUSTOMIZED ERROR CODE, ERROR CODE WILL BE DEFINE RESTOP NUMBER INDICATING WHICH SECTION FAILED
    call err.raise(vbObjectError + errRET, "MSP_LSV", "FAILURE")
  end if
  objOUT.write vbnewline & vbnewline & now & vbtab & " - MSP_LSV COMPLETE" & vbnewline
  objLOG.write vbnewline & vbnewline & now & vbtab & " - MSP_LSV COMPLETE" & vbnewline
  objLOG.close
  objLSV.close
  ''EMPTY OBJECTS
  set objLSV = nothing
  set objLOG = nothing
  set objFSO = nothing
  set objWSH = nothing
  set objARG = nothing
  set objOUT = nothing
  set objIN = nothing
  ''END SCRIPT, RETURN ERROR NUMBER
  wscript.quit err.number
end sub