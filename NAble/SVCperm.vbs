''SVCPERM.VBS
''DESIGNED TO GRANTING SERVICE LOGON PERMISSIONS
''ACCEPTS 4 PARAMETERS , REQUIRES 2 PARAMETERS
''REQUIRED PARAMETER : 'STRUSR' , STRING TO SET USER; 'LOCAL' - PASS 'USERNAME' ONLY; AND 'DOMAIN' - 'DOMAIN\USER' DOMAIN LOGON
''REQUIRED PARAMETER : 'STROPT' , STRING TO SET NETWORK TYPE 'LOCAL / DOMAIN'
''OPTIONAL PARAMETER : 'STRPWD' , STRING TO SET PASSWORD
''OPTIONAL PARAMETER : 'STRSVC' , STRING TO SET TARGET SERVICE TO MODIFY
''WRITTEN BY : CJ BLEDSOE / CJ<@>THECOMPUTERWARRIORS.COM
on error resume next
''SCRIPT VARIABLES
dim errRET, strVER, strSEL
dim strREPO, strBRCH, strDIR
dim strIN, strOUT, strORG, strREP
dim colUSR(), colSID(), arrUSR(), arrSID()
''VARIABLES ACCEPTING PARAMETERS
dim strUSR, strOPT, strPWD, strSVC
''SCRIPT OBJECTS
dim objIN, objOUT, objARG, objWSH, objFSO
dim objLOG, objEXEC, objHOOK, objSIN, objSOUT
''VERSION FOR SCRIPT UPDATE, SVCPERM.VBS, REF #2 , REF #68 , REF #69 , FIXES #21 , FIXES #31
strVER = 20
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
if (objFSO.fileexists("C:\temp\SVCperm")) then              ''LOGFILE EXISTS
  objFSO.deletefile "C:\temp\SVCperm", true
  set objLOG = objFSO.createtextfile("C:\temp\SVCperm")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\SVCperm", 8)
else                                                        ''LOGFILE NEEDS TO BE CREATED
  set objLOG = objFSO.createtextfile("C:\temp\SVCperm")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\SVCperm", 8)
end if
''READ PASSED COMMANDLINE ARGUMENTS
if (wscript.arguments.count > 0) then                       ''ARGUMENTS WERE PASSED
  ''ARGUMENT OUTPUT DISABLED TO SANITIZE
  'for x = 0 to (wscript.arguments.count - 1)
  '  objOUT.write vbnewline & now & vbtab & " - ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
  '  objLOG.write vbnewline & now & vbtab & " - ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
  'next 
  if (wscript.arguments.count > 1) then                     ''REQUIRED ARGUMENTS PASSED
    strUSR = objARG.item(0)                                 ''SET REQUIRED PARAMETER 'STRUSR' ; TARGET USER FOR SERVICE LOGON PERMISSIONS
    strOPT = objARG.item(1)                                 ''SET REQUIRED PARAMETER 'STROPT' ; TARGET LOCAL / DOMAIN LOGON , REF #71
    if (wscript.arguments.count > 2) then                   ''OPTIONAL ARGUMENTS PASSED
      strPWD = objARG.item(2)                               ''SET OPTIONAL PARAMETER 'STRPWD', TARGET USER CREDENTIALS
      strSVC = objARG.item(3)                               ''SET OPTIONAL PARAMETER 'STRSVC', TARGET SERVICE FOR USER CREDENTIALS
    end if
  else                                                      ''NOT ENOUGH ARGUMENTS PASSED , END SCRIPT , 'ERRRET'=1
    call LOGERR(1)
  end if
elseif (wscript.arguments.count = 0) then                   ''NO ARGUMENTS PASSED , END SCRIPT , 'ERRRET'=1
  call LOGERR(1)
end if

''------------
''BEGIN SCRIPT
if (errRET = 0) then                                        ''NO ERRORS DURING INITIAL START
  objOUT.write vbnewline & vbnewline & now & vbtab & " - EXECUTING SVCPERM"
  objLOG.write vbnewline & vbnewline & now & vbtab & " - EXECUTING SVCPERM"
	''AUTOMATIC UPDATE, SVCPERM.VBS, REF #2 , REF #69 , REF #68 , FIXES #21
  objOUT.write vbnewline & now & vbtab & vbtab & " - CHECKING FOR UPDATE : SVCPERM : " & strVER
  objLOG.write vbnewline & now & vbtab & vbtab & " - CHECKING FOR UPDATE : SVCPERM : " & strVER
  ''DOWNLOAD CHKAU.VBS SCRIPT, REF #2 , REF #69 , REF #68
  call FILEDL("https://raw.githubusercontent.com/CW-Khristos/scripts/master/chkAU.vbs", "C:\IT\Scripts", "chkAU.vbs")
  ''EXECUTE CHKAU.VBS SCRIPT, REF #69
  intRET = objWSH.run ("cmd.exe /C " & chr(34) & "cscript.exe " & chr(34) & "C:\IT\Scripts\chkAU.vbs" & chr(34) & " " & _
    chr(34) & strREPO & chr(34) & " " & chr(34) & strBRCH & chr(34) & " " & chr(34) & strDIR & chr(34) & " " & _
    chr(34) & wscript.scriptname & chr(34) & " " & chr(34) & strVER & chr(34) & " " & _
    chr(34) & strUSR & "|" & strOPT & "|" & strPWD & "|" & strSVC & chr(34) & chr(34), 0, true)
  ''CHKAU RETURNED - NO UPDATE FOUND , REF #2 , REF #69 , REF #68
  objOUT.write vbnewline & "errRET='" & intRET & "'"
  objLOG.write vbnewline & "errRET='" & intRET & "'"
  intRET = (intRET - vbObjectError)
  objOUT.write vbnewline & "errRET='" & intRET & "'"
  objLOG.write vbnewline & "errRET='" & intRET & "'"
  if ((intRET = 4) or (intRET = 10) or (intRET = 11) or (intRET = 1) or (intRET = 2147221505) or (intRET = 2147221517)) then
    ''GET SIDS OF ALL USERS , 'ERRRET'=2
    intUSR = 0
    intSID = 0
    objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & " - ENUMERATING USERNAMES AND SIDS, THIS MAY TAKE A FEW MOMENTS"
    objLOG.write vbnewline & vbnewline & now & vbtab & vbtab & " - ENUMERATING USERNAMES AND SIDS, THIS MAY TAKE A FEW MOMENTS"
    set objEXEC = objWSH.exec("wmic useraccount get name,sid /format:csv")
    while (not objEXEC.stdout.atendofstream)
      strIN = objEXEC.stdout.readline
      'objOUT.write vbnewline & now & vbtab & vbtab & strIN
      'objLOG.write vbnewline & now & vbtab & vbtab & strIN
      if ((trim(strIN) <> vbnullstring) and (instr(1, strIN, ","))) then
        if ((trim(split(strIN, ",")(1)) <> vbnullstring) and (trim(split(strIN, ",")(1)) <> "Name")) then
          redim preserve colUSR(intUSR + 1)
          redim preserve colSID(intSID + 1)
          colUSR(intUSR) = trim(split(strIN, ",")(1))
          colSID(intSID) = trim(split(strIN, ",")(2))
          intUSR = (intUSR + 1)
          intSID = (intSID + 1)
        end if
      end if
      if (err.number <> 0) then
        call LOGERR(2)
      end if
    wend
    set objEXEC = nothing
    err.clear
    ''VALIDATE COLLECTED USERNAMES AND SIDS
    intUSR = 0
    intSID = 0
    objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & " - COLLECTED USERNAMES AND SIDS"
    objLOG.write vbnewline & vbnewline & now & vbtab & vbtab & " - COLLECTED USERNAMES AND SIDS"
    for intUSR = 0 to ubound(colUSR)
      ''FIND USER/S MATCHING PASSED 'STRUSR' TARGET USER
      ''HANDLE '\' IS PASSED TARGET USERNAME 'STRUSR' , REF #37
      if (instr(1, lcase(strUSR), "\")) then
        if (instr(1, lcase(colUSR(intUSR)), lcase(split(strUSR, "\")(1)))) then
          redim preserve arrSID(intSID + 1)
          arrSID(intSID) = colSID(intUSR)
          intSID = intSID + 1
          objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "MARKED : " & colUSR(intUSR) & " : " & arrSID(intSID - 1)
          objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "MARKED : " & colUSR(intUSR) & " : " & arrSID(intSID - 1)
        end if
      ''HANDLE WITHOUT '\' IN PASSED TARGET USERNAME 'STRUSR' , REF #37
      elseif (instr(1, lcase(strUSR), "\") = 0) then
        if (instr(1, lcase(colUSR(intUSR)), lcase(strUSR))) then
          redim preserve arrSID(intSID + 1)
          arrSID(intSID) = colSID(intUSR)
          intSID = intSID + 1
          objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "MARKED : " & colUSR(intUSR) & " : " & arrSID(intSID - 1)
          objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "MARKED : " & colUSR(intUSR) & " : " & arrSID(intSID - 1)
        end if
      end if
      objOUT.write vbnewline & now & vbtab & vbtab & vbtab & colUSR(intUSR) & " : " & colSID(intUSR)
      objLOG.write vbnewline & now & vbtab & vbtab & vbtab & colUSR(intUSR) & " : " & colSID(intUSR)
    next
    ''GRANT 'LOGON AS A SERVICE' TO TARGET USER
    intUSR = 0
    intSID = 0
    ''EXPORT CURRENT SECURITY DATABASE CONFIGS , 'ERRRET'=3
    call HOOK("secedit /export /cfg c:\temp\config.inf")
    if (errRET <> 0) then
      call LOGERR(3)
    end if
    ''ENUMERATE THROUGH EACH USER COLLECTED MATCHING 'STRUSR' TARGET USER , REF#2 , FIXES #31
    ''THIS ALLOWS FOR TARGETING BOTH LOCAL AND DOMAIN USER VARIANTS
    'for intSID = 0 to ubound(arrSID)
    '  objOUT.write vbnewline & vbtab & vbtab & arrSID(intSID)
    'next
    strIN = vbnullstring
    for intSID = 0 to ubound(arrSID)
      'objOUT.write vbnewline & vbtab & arrSID(intSID)
      objOUT.write vbnewline & now & vbtab & vbtab & " - GRANT LOGON AS SERVICE : " & strUSR & " : " & arrSID(intSID)
      objLOG.write vbnewline & now & vbtab & vbtab & " - GRANT LOGON AS SERVICE : " & strUSR & " : " & arrSID(intSID)
      strORG = "SeServiceLogonRight = "
      ''READ CURRENT EXPORTED SECURITY DATABASE CONFIGS
      set objSIN = objFSO.opentextfile("c:\temp\config.inf", 1, 1, -1)
      strIN = objSIN.readall
      objSIN.close
      set objSIN = nothing
      ''WRITE SECURITY DATABASE CONFIGS WITH 'SetServiceLogonRight' FOR TARGET USER , 'ERRRET'=4
      set objSOUT = objFSO.opentextfile("c:\temp\config.inf", 2, 1, -1)
      if (arrSID(intSID) <> vbnullstring) then              ''MATCHING USER SID FOUND
        trim(objSOUT.write (replace(strIN, strORG, "SeServiceLogonRight = *" & arrSID(intSID) & ",")))
      elseif (arrSID(intSID) = vbnullstring) then           ''NO MATCHING USER SID FOUND , USE 'PLAINTEXT' USER NAME
        trim(objSOUT.write (replace(strIN, strORG, "SeServiceLogonRight = " & strUSR & ",")))
      end if
      objSOUT.close
      set objSOUT = nothing
      if (err.number <> 0) then
        call LOGERR(4)
      end if
    next
    ''APPLY NEW SECURITY DATABASE CONFIGS , 'ERRRET'=5
    call HOOK("secedit /import /db secedit.sdb /cfg c:\temp\config.inf")
    call HOOK("secedit /configure /db secedit.sdb")
    'call HOOK("echo N | gpupdate /force")
    if (errRET <> 0) then
      call LOGERR(5)
    end if
    ''REMOVE TEMP FILES
    'objFSO.deletefile("c:\temp\config.inf") 
    objOUT.write vbnewline & now & vbtab & vbtab & " - LOGON AS SERVICE GRANTED : " & strUSR
    objLOG.write vbnewline & now & vbtab & vbtab & " - LOGON AS SERVICE GRANTED : " & strUSR
    if ((strPWD <> vbnullstring) and (strSVC <> vbnullstring)) then
      ''UPDATE SERVICE LOGON CREDENTIALS USING 'SC CONFIG' CMD , 'ERRRET'=6
      objOUT.write vbnewline & now & vbtab & vbtab & " - UPDATING SERVICE LOGON : " & strSVC
      objLOG.write vbnewline & now & vbtab & vbtab & " - UPDATING SERVICE LOGON : " & strSVC
      if (ucase(strOPT) = "LOCAL") then                     ''LOCAL DEVICE CONFIGURATION , REF #71
        call HOOK("sc config " & chr(34) & strSVC & chr(34) & " obj= " & chr(34) & ".\" & strUSR & chr(34) & " password= " & chr(34) & strPWD & chr(34))
      elseif (ucase(strOPT) = "DOMAIN") then                ''DOMAIN NETWORK CONFIGURATION , REF #71
        call HOOK("sc config " & chr(34) & strSVC & chr(34) & " obj= " & chr(34) & strUSR & chr(34) & " password= " & chr(34) & strPWD & chr(34))
      end if
      if (errRET <> 0) then
        call LOGERR(6)
      end if
      ''STOP AND RESTART SERVICE TO UPDATE SERVICE LOGON CREDENTIALS , 'ERRRET'=7
      call HOOK("sc stop " & chr(34) & strSVC & chr(34))
      wscript.sleep 90000
      call HOOK("sc start " & chr(34) & strSVC & chr(34))
      objOUT.write vbnewline & now & vbtab & vbtab & " - SERVICE LOGON UPDATED : " & strSVC
      objLOG.write vbnewline & now & vbtab & vbtab & " - SERVICE LOGON UPDATED : " & strSVC
      if (errRET <> 0) then
        call LOGERR(7)
      end if
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
  if ((err.number <> 0) and (err.number <> 58)) then        ''ERROR RETURNED DURING DOWNLOAD , 'ERRRET'=11
    call LOGERR(11)
  end if
end sub

sub HOOK(strCMD)                                            ''CALL HOOK TO MONITOR OUTPUT OF CALLED COMMAND , 'ERRRET'=12
  on error resume next
  ''ARGUMENT OUTPUT DISABLED TO SANITIZE
  objOUT.write vbnewline & now & vbtab & vbtab & " - EXECUTING : HOOK" ' & strCMD
  objLOG.write vbnewline & now & vbtab & vbtab & " - EXECUTING : HOOK" ' & strCMD
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
      objOUT.write vbnewline & vbnewline & now & vbtab & " - SCRIPT REQUIRES USER TO GRANT SERVICE LOGON"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - SCRIPT REQUIRES USER TO GRANT SERVICE LOGON"
  end select
end sub

sub CLEANUP()                                               ''SCRIPT CLEANUP
  on error resume next
  if (errRET = 0) then                                      ''SCRIPT COMPLETED SUCCESSFULLY
    objOUT.write vbnewline & vbnewline & now & vbtab & " - SVCPERM SUCCESSFUL : " & now
    objLOG.write vbnewline & vbnewline & now & vbtab & " - SVCPERM SUCCESSFUL : " & now
    err.clear
  elseif (errRET <> 0) then                                 ''SCRIPT FAILED
    objOUT.write vbnewline & vbnewline & now & vbtab & " - SVCPERM FAILURE : " & errRET & " : " & now
    objLOG.write vbnewline & vbnewline & now & vbtab & " - SVCPERM FAILURE : " & errRET & " : " & now
    ''RAISE CUSTOMIZED ERROR CODE , ERROR CODE WILL BE DEFINED RESTOP NUMBER INDICATING WHICH SECTION FAILED
    call err.raise(vbObjectError + errRET, "SVCPERM", "fail")
  end if
  objOUT.write vbnewline & vbnewline & now & " - SVCPERM COMPLETE" & vbnewline
  objLOG.write vbnewline & vbnewline & now & " - SVCPERM COMPLETE" & vbnewline
  objLOG.close
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