''TASKKILL_FORCE.VBS
''DESIGNED TO REPLACE 'KILLPROCESS' TASK WHICH INTERFACES WMI AND PROVIDES NO LOGGING OR RETURN CODES
''THIS WILL UTILIZE 'TASKKILL' CMD IN INTERNAL WINDOWS CMD TO KILL TARGET PROCESS
''SCRIPT CAN 'TASKKILL' ALL PROCESSES BY /IM PROCESS NAME : 'SAMPLE.EXE'
''ALTERNATELY, SCRIPT CAN 'TASKKILL' ALL PROCESSES FILTERED BY A SPECIFIC USER, IF A USERNAME IS PASSED
''ACCEPTS 3 PARAMETERS , REQUIRES 1 PARAMETER
''REQUIRED PARAMETER : 'STRPROC' , STRING TO SET TARGET PROCESS TO KILL
''OPTIONAL PARAMETER : 'STRUSR' , STRING TO SET USERNAME TO FILTER 'TASKKILL' TARGET BY
''OPTIONAL PARAMETER : 'BLNPSK' , BOOLEAN TO D/L 'PSKILL' AND USE THIS INSTEAD, DOES NOT ACCEPT ADDITIONAL PARAMETERS CURRENTLY
''WRITTEN BY : CJ BLEDSOE / CBLEDSOE<@>IPMCOMPUTERS.COM
on error resume next
''SCRIPT VARIABLES
dim errRET, strVER, strSEL
dim strIN, strOUT, strORG, strREP
''VARIABLES ACCEPTING PARAMETERS
dim strPROC, strUSR, blnPSK
''SCRIPT OBJECTS
dim objIN, objOUT, objARG, objWSH, objFSO
dim objLOG, objEXEC, objHOOK, objSIN, objSOUT
''VERSION FOR SCRIPT UPDATE, TASKKILL_FORCE.VBS , REF #2 , REF #68 , REF #69
strVER = 4
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
if (not (objFSO.folderexists("C:\IT\"))) then
  objFSO.createfolder("C:\IT\")
end if
if (not (objFSO.folderexists("C:\IT\Scripts\"))) then
  objFSO.createfolder("C:\IT\Scripts\")
end if
''PREPARE LOGFILE
if (objFSO.fileexists("C:\temp\TASKKILL_FORCE")) then       ''LOGFILE EXISTS
  objFSO.deletefile "C:\temp\TASKKILL_FORCE", true
  set objLOG = objFSO.createtextfile("C:\temp\TASKKILL_FORCE")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\TASKKILL_FORCE", 8)
else                                                        ''LOGFILE NEEDS TO BE CREATED
  set objLOG = objFSO.createtextfile("C:\temp\TASKKILL_FORCE")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\TASKKILL_FORCE", 8)
end if
''READ PASSED COMMANDLINE ARGUMENTS
if (wscript.arguments.count > 0) then                       ''ARGUMENTS WERE PASSED
  for x = 0 to (wscript.arguments.count - 1)
    objOUT.write vbnewline & now & vbtab & " - ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
    objLOG.write vbnewline & now & vbtab & " - ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
  next 
  if (wscript.arguments.count > 0) then                     ''REQUIRED ARGUMENTS PASSED
    strPROC = objARG.item(0)                                ''SET REQUIRED PARAMETER 'STRPROC' ; TARGET PROCESS TO 'TASKKILL'
    if (wscript.arguments.count > 1) then                   ''OPTIONAL ARGUMENTS PASSED
      strUSR = objARG.item(1)                               ''SET OPTIONAL PARAMETER 'STRUSR' ; USERNAME TO FILTER 'TASKKILL' TARGET BY
      blnPSK = objARG.item(2)                               ''SET OPTIONAL PARAMETER 'BLNPSK' ; BOOLEAN TO D/L 'PSKILL' AND USE THIS INSTEAD
    end if
  end if
else                                                        ''NO ARGUMENTS PASSED , END SCRIPT , 'ERRRET'=1
  call LOGERR(1)
end if

''------------
''BEGIN SCRIPT
if (errRET = 0) then
  objOUT.write vbnewline & vbnewline & now & vbtab & " - EXECUTING TASKKILL_FORCE"
  objLOG.write vbnewline & vbnewline & now & vbtab & " - EXECUTING TASKKILL_FORCE"
	''AUTOMATIC UPDATE, TASKKILL_FORCE.VBS, REF #2 , REF #69 , REF #68
  objOUT.write vbnewline & now & vbtab & vbtab & " - CHECKING FOR UPDATE : TASKKILL_FORCE : " & strVER
  objLOG.write vbnewline & now & vbtab & vbtab & " - CHECKING FOR UPDATE : TASKKILL_FORCE : " & strVER
  ''DOWNLOAD CHKAU.VBS SCRIPT, REF #2 , REF #69 , REF #68
  call FILEDL("https://raw.githubusercontent.com/CW-Khristos/scripts/master/chkAU.vbs", "C:\IT\Scripts", "chkAU.vbs")
  ''EXECUTE CHKAU.VBS SCRIPT, REF #69
  intRET = objWSH.run ("cmd.exe /C " & chr(34) & "cscript.exe " & chr(34) & "C:\IT\Scripts\chkAU.vbs" & chr(34) & " " & _
    chr(34) & strREPO & chr(34) & " " & chr(34) & strBRCH & chr(34) & " " & chr(34) & strDIR & chr(34) & " " & _
    chr(34) & wscript.scriptname & chr(34) & " " & chr(34) & strVER & chr(34) & " " & _
    chr(34) & strUSR & "|" & blnPSK & "|" & chr(34) & chr(34), 0, true)
  ''CHKAU RETURNED - NO UPDATE FOUND , REF #2 , REF #69 , REF #68
  objOUT.write vbnewline & "errRET='" & intRET & "'"
  objLOG.write vbnewline & "errRET='" & intRET & "'"
  intRET = (intRET - vbObjectError)
  objOUT.write vbnewline & "errRET='" & intRET & "'"
  objLOG.write vbnewline & "errRET='" & intRET & "'"
  if ((intRET = 4) or (intRET = 10) or (intRET = 11) or (intRET = 1) or (intRET = 2147221505) or (intRET = 2147221517)) then
    ''DOWNLOAD 'PSKILL', DOES NOT ACCEPT ADDITIONAL PARAMETERS CURRENTLY
    if (blnPSK) then
      call FILEDL("https://raw.githubusercontent.com/CW-Khristos/scripts/dev/PSTools/pskill.exe", "pskill.exe")
      call HOOK("c:\temp\pskill.exe -accepteula -t " & strPROC)
    ''CALL 'TASKKILL /F /FI 'USERNAME EQ USER' /IM 'PROCESS' /T'
    elseif (not blnPSK) then
      if (strUSR = vbnullstring) then                           ''OPTIONAL 'STRUSR' USERNAME WAS NOT PASSED
        call HOOK("taskkill /F /IM " & strPROC & " /T")
      elseif (strUSR <> vbnullstring) then                      ''OPTIONAL 'STRUSR' USERNAME TO FILTER 'TASKKILL' TARGET WAS PASSED
        call HOOK("taskkill /F /FI " & chr(34) & "USERNAME eq " & strUSR & chr(34) & " /IM " & strPROC & " /T")
      end if
    end if
  end if
elseif (errRET <> 0) then
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

sub LOGERR(intSTG)                                            ''CALL HOOK TO MONITOR OUTPUT OF CALLED COMMAND
  errRET = intSTG
  if (err.number <> 0) then
    objOUT.write vbnewline & now & vbtab & vbtab & vbtab & err.number & vbtab & err.description & vbnewline
    objLOG.write vbnewline & now & vbtab & vbtab & vbtab & err.number & vbtab & err.description & vbnewline
		err.clear
  end if
  ''CUSTOM ERROR CODES
  select case intSTG
    case 1                                                  '' 'ERRRET'=1 - NOT ENOUGH ARGUMENTS
      'objOUT.write vbnewline & vbnewline & now & vbtab & " - SCRIPT REQUIRES USER TO GRANT SERVICE LOGON"
      'objLOG.write vbnewline & vbnewline & now & vbtab & " - SCRIPT REQUIRES USER TO GRANT SERVICE LOGON"
  end select
end sub

sub CLEANUP()                                               ''SCRIPT CLEANUP
  on error resume next
  if (errRET = 0) then                                      ''SCRIPT COMPLETED SUCCESSFULLY
    objOUT.write vbnewline & vbnewline & now & vbtab & " - TASKKILL_FORCE COMPLETE : " & now
    objLOG.write vbnewline & vbnewline & now & vbtab & " - TASKKILL_FORCE COMPLETE : " & now
    err.clear
  elseif (errRET <> 0) then                                 ''SCRIPT FAILED
    objOUT.write vbnewline & vbnewline & now & vbtab & " - TASKKILL_FORCE FAILURE : " & errRET & " : " & now
    objLOG.write vbnewline & vbnewline & now & vbtab & " - TASKKILL_FORCE FAILURE : " & errRET & " : " & now
    ''RAISE CUSTOMIZED ERROR CODE , ERROR CODE WILL BE DEFINED RESTOP NUMBER INDICATING WHICH SECTION FAILED
    call err.raise(vbObjectError + errRET, "TASKKILL_FORCE", "fail")
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