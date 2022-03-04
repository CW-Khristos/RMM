''JDC_MSP_POSTBACKUP.VBS
''DESIGNED TO RESTART SAGE DATABASE AND SERVICES
''CUSTOMIZED FOR JOHNSON DRUG CUSTOMER SETUP ONLY
''WRITTEN BY : CJ BLEDSOE / CJ<@>THECOMPUTERWARRIORS.COM
on error resume next
''SCRIPT VARIABLES
dim strVER, errRET, strIN
dim strREPO, strBRCH, strDIR
''SCRIPT OBJECTS
dim objIN, objOUT, objARG
dim objWSH, objFSO, objLOG
dim objHOOK, objEXEC, objHTTP, objXML
''VERSION FOR SCRIPT UPDATE , JDC_MSP_POSTBACKUP.VBS , REF #2 , REF #50
strVER = 6
strREPO = "scripts"
strBRCH = "master"
strDIR = "MSP Backups"
''DEFAULT FAIL
errRET = 5
''STDIN / STDOUT
set objIN = wscript.stdin
set objOUT = wscript.stdout
set objARG = wscript.arguments
''CREATE SCRIPTING SHELL & FILE SYSTEM OBJECTS
set objOUT = wscript.stdout
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
if (objFSO.fileexists("C:\temp\MSP_POSTBACKUP")) then       ''LOGFILE EXISTS
  objFSO.deletefile "C:\temp\MSP_POSTBACKUP", true
  set objLOG = objFSO.createtextfile("C:\temp\MSP_POSTBACKUP")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\MSP_POSTBACKUP", 8)
else                                                        ''LOGFILE NEEDS TO BE CREATED
  set objLOG = objFSO.createtextfile("C:\temp\MSP_POSTBACKUP")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\MSP_POSTBACKUP", 8)
end if
''READ PASSED COMMANDLINE ARGUMENTS
if (wscript.arguments.count > 0) then                       ''ARGUMENTS WERE PASSED
  for x = 0 to (wscript.arguments.count - 1)
    objOUT.write vbnewline & now & vbtab & " - ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
    objLOG.write vbnewline & now & vbtab & " - ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
  next 
  if (wscript.arguments.count > 0) then                     ''SET PASSED ARG7UMENTS
  else                                                      ''NOT ENOUGH ARGUMENTS PASSED, END SCRIPT
    'errRET = 1
    'call CLEANUP()
  end if
else                                                        ''NO ARGUMENTS PASSED, END SCRIPT
  'errRET = 1
  'call CLEANUP()
end if

''------------
''BEGIN SCRIPT
objOUT.write vbnewline & vbnewline & now & vbtab & " - EXECUTING JDC_MSP_POSTBACKUP" & vbnewline
objLOG.write vbnewline & vbnewline & now & vbtab & " - EXECUTING JDC_MSP_POSTBACKUP" & vbnewline
''AUTOMATIC UPDATE, JDC_MSP_PREBACKUP.VBS, REF #2 , REF #69 , REF #68 , FIXES #50
objOUT.write vbnewline & now & vbtab & vbtab & " - CHECKING FOR UPDATE : JDC_MSP_POSTBACKUP : " & strVER
objLOG.write vbnewline & now & vbtab & vbtab & " - CHECKING FOR UPDATE : JDC_MSP_POSTBACKUP : " & strVER
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
  ''INITIATE SERVICE STARTS
  call STARTPSQL()
end if
''END SCRIPT, RETURN EXIT CODE
call CLEANUP()
''END SCRIPT
''------------

''SUB-ROUTINES
sub STARTPSQL()                                             ''START PERVASIVE SQL SERVICE
  objOUT.write vbnewline & vbnewline & "STARTING PERVASIVE SQL SERVICE : " & now
  objLOG.write vbnewline & vbnewline & "STARTING PERVASIVE SQL SERVICE : " & now
  ''START PERVASIVE SQL SERVICE
  call HOOK("net start " & chr(34) & "psqlWGE" & chr(34))
  wscript.sleep 5000
  if (errRET <> 0) then                                     ''ERROR RETURNED
    if (errRET = 2) then                                    ''SERVICE ALREADY STARTED
      objOUT.write vbnewline & retSTOP & vbtab & "SERVICE ALREADY STARTED : psqlWGE : " & now
      objLOG.write vbnewline & retSTOP & vbtab & "SERVICE ALREADY STARTED : psqlWGE : " & now
      errRET = 0
      err.clear
    elseif (errRET <> 2) then                               ''ANY OTHER ERROR
      objOUT.write vbnewline & errRET & vbtab & "ERROR STARTING : psqlWGE : " & now
      objLOG.write vbnewline & errRET & vbtab & "ERROR STARTING : psqlWGE : " & now
      call LOGERR(4)
    end if
  end if
  ''START SAGE SERVICES
  call STARTSAGE()
end sub

sub STARTSAGE()                                             ''START SAGE SERVICES
  objOUT.write vbnewline & "STARTING SAGE SERVICES : " & now
  objLOG.write vbnewline & "STARTING SAGE SERVICES : " & now
  ''START SAGE 50 SMARTPOSTING SERVICE
  call HOOK("net start " & chr(34) & "Sage 50 SmartPosting 2021" & chr(34))
  wscript.sleep 5000
  if (errRET <> 0) then                                     ''ERROR RETURNED
    if (errRET = 2) then                                    ''SERVICE ALREADY STARTED
      objOUT.write vbnewline & retSTOP & vbtab & "SERVICE ALREADY STARTED : Sage SmartPosting 2021 : " & now
      objLOG.write vbnewline & retSTOP & vbtab & "SERVICE ALREADY STARTED : Sage SmartPosting 2021 : " & now
      errRET = 0
      err.clear
    elseif (errRET <> 2) then                               ''ANY OTHER ERROR
      objOUT.write vbnewline & errRET & vbtab & "ERROR STARTING : Sage 50 SmartPosting 2021 : " & now
      objLOG.write vbnewline & errRET & vbtab & "ERROR STARTING : Sage 50 SmartPosting 2021 : " & now
      call LOGERR(5)
    end if
  end if
  ''START SAGE AUTOUPDATE MANAGER SERVICE
  call HOOK("net start " & chr(34) & "Sage AutoUpdate Manager Service" & chr(34))
  wscript.sleep 5000
  if (errRET <> 0) then                                     ''ERROR RETURNED
    if (errRET = 2) then                                    ''SERVICE ALREADY STARTED
      objOUT.write vbnewline & retSTOP & vbtab & "SERVICE ALREADY STARTED : Sage AutoUpdate Manager Service : " & now
      errRET = 0
      err.clear
    elseif (errRET <> 2) then                               ''ANY OTHER ERROR
      objOUT.write vbnewline & errRET & vbtab & "ERROR STARTING : Sage AutoUpdate Manager Service : " & now
      call LOGERR(6)
    end if
  end if
end sub

sub FILEDL(strURL, strDL, strFILE)                          ''CALL HOOK TO DOWNLOAD FILE FROM URL , 'ERRRET'=11
  strSAV = vbnullstring
  ''SET DOWNLOAD PATH
  strSAV = strDL & "\" & strFILE
  objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "HTTPDOWNLOAD-------------DOWNLOAD : " & strURL & " : SAVE AS :  " & strSAV
  objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "HTTPDOWNLOAD-------------DOWNLOAD : " & strURL & " : SAVE AS :  " & strSAV
  ''CHECK IF FILE ALREADY EXISTS
  if objFSO.fileexists(strSAV) then
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
  if objFSO.fileexists(strSAV) then
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
  end select
end sub

sub CLEANUP()                                               ''SCRIPT CLEANUP
  on error resume next
  if (errRET = 0) then                                      ''POST-BACKUP COMPLETED SUCCESSFULLY
    objOUT.write vbnewline & vbnewline & now & vbtab & " - MSP_POST-BACKUP COMPLETE : " & now
    objLOG.write vbnewline & vbnewline & now & vbtab & " - MSP_POST-BACKUP COMPLETE : " & now
    err.clear
  elseif (errRET <> 0) then                                 ''POST-BACKUP FAILED
    objOUT.write vbnewline & vbnewline & now & vbtab & " - MSP_POST-BACKUP FAILURE : " & errRET & " : " & now
    objLOG.write vbnewline & vbnewline & now & vbtab & " - MSP_POST-BACKUP FAILURE : " & errRET & " : " & now
    ''RAISE CUSTOMIZED ERROR CODE, ERROR CODE WILL BE DEFINE RESTOP NUMBER INDICATING WHICH SECTION FAILED
    call err.raise(vbObjectError + errRET, "MSP_POST-BACKUP", "FAIL")
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