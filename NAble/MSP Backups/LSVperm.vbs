''LSVPERM.VBS
''DESIGNED TO RESTRICT LSV PERMISSIONS TO PASSED USER ONLY AND UPDATE BACKUP SERVICE CONTROLLER SERVICE LOGON
''SCRIPT WILL CHECK STATUS OF BACKUPS PRIOR TO EXECUTION; IF BACKUPS ARE IN PROGRESS, SCRIPT WILL NOT PROCEED
''ACCEPTS 4 PARAMETERS , REQUIRES 4 PARAMETER
''REQUIRED PARAMETER : 'STRLSV' , STRING TO IDENTIFY 'ROOT' LSV BACKUP DESTINATION PATH
''REQUIRED PARAMETER : 'STRUSR' , STRING TO SET TARGET USER FOR LSV PERMISSIONS AND SERVICE LOGON; 'LOCAL' - PASS 'USERNAME' ONLY; AND 'DOMAIN' - 'DOMAIN\USER' DOMAIN LOGON
''REQUIRED PARAMETER : 'STRPWD' , STRING TO SET TARGET USER PASSWORD
''REQUIRED PARAMETER : 'STROPT' , STRING TO SET TARGET NETWORK TYPE 'LOCAL / DOMAIN'
''WRITTEN BY : CJ BLEDSOE / CJ<@>THECOMPUTERWARRIORS.COM
on error resume next
''SCRIPT VARIABLES
dim strVER, errRET
dim strREPO, strBRCH, strDIR
dim strORG, strREP, strSID, strDMN
dim strIN, strOUT, colUSR(), colSID()
''VARIABLES ACCEPTING PARAMETERS
dim strSAV, strCMD
dim strLSV, strUSR, strPWD, strOPT
''SCRIPT OBJECTS
dim objLOG, objEXEC, objHOOK
dim objIN, objOUT, objARG, objWSH, objFSO
''VERSION FOR SCRIPT UPDATE , LSVPERM.VBS , REF #2 , REF #68 , REF #69 , FIXES #32 , REF #71
strVER = 12
strREPO = "scripts"
strBRCH = "master"
strDIR = "MSP Backups"
''DEFAULT SUCCESS
errRET = 0
''STDIN / STDOUT
set objIN = wscript.stdin
set objOUT = wscript.stdout
set objARG = wscript.arguments
''CREATE SCRIPTING OBJECTS
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
if (objFSO.fileexists("C:\temp\LSVperm")) then                              ''LOGFILE EXISTS
  objFSO.deletefile "C:\temp\LSVperm", true
  set objLOG = objFSO.createtextfile("C:\temp\LSVperm")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\LSVperm", 8)
else                                                                        ''LOGFILE NEEDS TO BE CREATED
  set objLOG = objFSO.createtextfile("C:\temp\LSVperm")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\LSVperm", 8)
end if
''CHECK FOR MSP BACKUP MANAGER CLIENTTOOL , REF #76
if (objFSO.fileexists("C:\Program Files\Backup Manager\clienttool.exe")) then
  call LOGERR(0)                                                            ''CLIENTTOOL.EXE PRESENT, CONTINUE SCRIPT, 'ERRRET'=0
elseif (not objFSO.fileexists("C:\Program Files\Backup Manager\clienttool.exe")) then
  call LOGERR(1)                                                            ''CLIENTTOOL.EXE NOT PRESENT, END SCRIPT, 'ERRRET'=1
end if
''READ PASSED COMMANDLINE ARGUMENTS
if (wscript.arguments.count > 0) then                                       ''ARGUMENTS WERE PASSED
  ''ARGUMENT OUTPUT DISABLED TO SANITIZE
  'for x = 0 to (wscript.arguments.count - 1)
  '  objOUT.write vbnewline & now & vbtab & " - ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
  '  objLOG.write vbnewline & now & vbtab & " - ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
  'next
  if (wscript.arguments.count > 3) then                                     ''REQUIRED ARGUMENTS PASSED
    strLSV = objARG.item(0)                                                 ''SET REQUIRED PARAMETER 'STRLSV' ; TARGET LSV FOLDER PATH
    strUSR = objARG.item(1)                                                 ''SET REQUIRED PARAMETER 'STRUSR' ; TARGET USER FOR SERVICE LOGON PERMISSIONS
    strPWD = objARG.item(2)                                                 ''SET REQUIRED PARAMETER 'STRPWD' ; TARGET USER CREDENTIALS
    strOPT = objARG.item(3)                                                 ''SET REQUIRED PARAMETER 'STROPT' ; TARGET TARGET NETWORK TYPE 'LOCAL / DOMAIN'
  elseif (wscript.arguments.count <= 1) then                                ''NOT ENOUGH ARGUMENTS PASSED ; END SCRIPT , 'ERRRET'=1
    call LOGERR(2)
  end if
elseif (wscript.arguments.count = 0) then                                   ''NO ARGUMENTS PASSED , END SCRIPT , 'ERRRET'=1
  call LOGERR(2)
end if

''------------
''BEGIN SCRIPT
if (errRET = 0) then                                                        ''ARGUMENTS PASSED , CONTINUE SCRIPT
  objOUT.write vbnewline & vbnewline & now & vbtab & " - EXECUTING LSVPERM"
  objLOG.write vbnewline & vbnewline & now & vbtab & " - EXECUTING LSVPERM"
	''AUTOMATIC UPDATE, LSVPERM.VBS, REF #2 , REF #69 , REF #68 , FIXES #32 , REF #71
  objOUT.write vbnewline & now & vbtab & vbtab & " - CHECKING FOR UPDATE : LSVPERM : " & strVER
  objLOG.write vbnewline & now & vbtab & vbtab & " - CHECKING FOR UPDATE : LSVPERM : " & strVER
  ''DOWNLOAD CHKAU.VBS SCRIPT, REF #2 , REF #69 , REF #68
  call FILEDL("https://raw.githubusercontent.com/CW-Khristos/scripts/master/chkAU.vbs", "C:\IT\Scripts", "chkAU.vbs")
  ''EXECUTE CHKAU.VBS SCRIPT, REF #69
  intRET = objWSH.run ("cmd.exe /C " & chr(34) & "cscript.exe " & chr(34) & "C:\IT\Scripts\chkAU.vbs" & chr(34) & " " & _
    chr(34) & strREPO & chr(34) & " " & chr(34) & strBRCH & chr(34) & " " & chr(34) & strDIR & chr(34) & " " & _
    chr(34) & wscript.scriptname & chr(34) & " " & chr(34) & strVER & chr(34) & " " & _
    chr(34) & strLSV & "|" & strUSR & "|" & strPWD & "|" & strOPT & chr(34) & chr(34), 0, true)
  ''CHKAU RETURNED - NO UPDATE FOUND , REF #2 , REF #69 , REF #68
  objOUT.write vbnewline & "errRET='" & intRET & "'"
  objLOG.write vbnewline & "errRET='" & intRET & "'"
  intRET = (intRET - vbObjectError)
  objOUT.write vbnewline & "errRET='" & intRET & "'"
  objLOG.write vbnewline & "errRET='" & intRET & "'"
  if ((intRET = 4) or (intRET = 10) or (intRET = 11) or (intRET = 1) or (intRET = 2147221505) or (intRET = 2147221517)) then
    objOUT.write vbnewline & now & vbtab & vbtab & " - NO UPDATE FOUND : LSVPERM : " & strVER
    objLOG.write vbnewline & now & vbtab & vbtab & " - NO UPDATE FOUND : LSVPERM : " & strVER
    ''CHECK MSP BACKUP STATUS VIA MSP BACKUP CLIENTTOOL UTILITY
    objOUT.write vbnewline & now & vbtab & " - CHECKING MSP BACKUP STATUS"
    objLOG.write vbnewline & now & vbtab & " - CHECKING MSP BACKUP STATUS"
    set objHOOK = objWSH.exec(chr(34) & "c:\Program Files\Backup Manager\ClientTool.exe" & chr(34) & " control.status.get")
    strIDL = objHOOK.stdout.readall
    objOUT.write vbnewline & now & vbtab & vbtab & vbtab & strIDL
    objLOG.write vbnewline & now & vbtab & vbtab & vbtab & strIDL
    set objHOOK = nothing
    ''BACKUPS NOT IN PROGRESS , CONTINUE SCRIPT
    if ((instr(1, strIDL, "Idle")) or (instr(1, strIDL, "RegSync")) or (instr(1, strIDL, "Suspended"))) then
      ''GET SIDS OF ALL USERS , 'ERRRET'=20
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
          call LOGERR(4)
        end if
      wend
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
          ''ENUMERATED USER ACCOUNT DOES NOT MATCH PASSED 'STRUSR'
          if (lcase(colUSR(intUSR)) <> lcase(split(strUSR, "\")(1))) then
            objOUT.write vbnewline & now & vbtab & vbtab & vbtab & colUSR(intUSR) & " : " & colSID(intUSR)
            objLOG.write vbnewline & now & vbtab & vbtab & vbtab & colUSR(intUSR) & " : " & colSID(intUSR)
          ''ENUMERATED USER ACCOUNT DOES MATCH PASSED 'STRUSR'
          elseif (lcase(colUSR(intUSR)) = lcase(split(strUSR, "\")(1))) then
            redim preserve arrSID(intSID + 1)
            arrSID(intSID) = colSID(intUSR)
            intSID = intSID + 1
            objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "MARKED : " & colUSR(intUSR) & " : " & arrSID(intSID - 1)
            objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "MARKED : " & colUSR(intUSR) & " : " & arrSID(intSID - 1)
          end if
        ''HANDLE WITHOUT '\' IN PASSED TARGET USERNAME 'STRUSR' , REF #37
        elseif (instr(1, lcase(strUSR), "\") = 0) then
          ''ENUMERATED USER ACCOUNT DOES NOT MATCH PASSED 'STRUSR'
          if (lcase(colUSR(intUSR)) <> lcase(strUSR)) then
            objOUT.write vbnewline & now & vbtab & vbtab & vbtab & colUSR(intUSR) & " : " & colSID(intUSR)
            objLOG.write vbnewline & now & vbtab & vbtab & vbtab & colUSR(intUSR) & " : " & colSID(intUSR)
          ''ENUMERATED USER ACCOUNT DOES MATCH PASSED 'STRUSR'
          elseif (lcase(colUSR(intUSR)) = lcase(strUSR)) then
            redim preserve arrSID(intSID + 1)
            arrSID(intSID) = colSID(intUSR)
            intSID = intSID + 1
            objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "MARKED : " & colUSR(intUSR) & " : " & arrSID(intSID - 1)
            objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "MARKED : " & colUSR(intUSR) & " : " & arrSID(intSID - 1)
          end if
        end if
      next
      ''STOP 'BACKUP SERVICE CONTROLLER' AND UPDATE ACCOUNT LOGON TO RMMTECH
      objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & " - UPDATING BACKUP SERVICE AND LSV PERMISSIONS"
      objLOG.write vbnewline & vbnewline & now & vbtab & vbtab & " - UPDATING BACKUP SERVICE AND LSV PERMISSIONS"
      call HOOK("sc.exe stop " & chr(34) & "Backup Service Controller" & chr(34))
      ''RESTRICT FILE-SYSTEM PERMISSIONS PRIOR TO APPLYING SERVICE LOGON AND RESTARTING SERVICE , 'ERRRET'=21 , REF #2 , REF #32
      ''TAKEOWN USING CURRENT USER, THIS SHOULD BE RMMTECH
      ''TAKEOWN REPLACED BY 'ICACLS /SETOWNER'
      objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & " - ASSIGNING " & strUSR & " OWNERSHIP"
      objLOG.write vbnewline & vbnewline & now & vbtab & vbtab & " - ASSIGNING " & strUSR & " OWNERSHIP"
      'call HOOK("takeown /F " & chr(34) & strLSV & chr(34) & " /R /D Y")
      call HOOK("icacls " & chr(34) & strLSV & chr(34) & " /setowner " & strUSR)
      if (errRET <> 0) then
        call LOGERR(21)
      end if
      ''ADD RMMTECH USER EXPLICIT FULL CONTROL , 'ERRRET'=22
      objOUT.write vbnewline & now & vbtab & vbtab & " - ASSIGNING " & strUSR & " FULL CONTROL"
      objLOG.write vbnewline & now & vbtab & vbtab & " - ASSIGNING " & strUSR & " FULL CONTROL"
      for intUSR = 0 to ubound(colUSR)
        intSID = intUSR
        if (instr(1, lcase(colUSR(intUSR)), strUSR)) then
          call HOOK("icacls " & chr(34) & strLSV & chr(34) & " /grant " & colUSR(intUSR) & ":(OI)(CI)F /T /C /Q")
          call HOOK("icacls " & chr(34) & strLSV & chr(34) & " /grant *" & colSID(intSID) & ":(OI)(CI)F /T /C /Q")
        end if
      next
      if (errRET <> 0) then
        call LOGERR(22)
      end if
      ''DISABLE INHERITANCE ON LSV DESTINATION, AND ONLY THE ROOT MSP BACKUP LSV DESTINATION , 'ERRRET'=23
      ''THIS MUST BE DONE LAST, BEFORE REMOVING ALL OTHER USER PERMISSIONS SO RMMTECH PERMISSIONS FULLY PROPAGATE TO ALL FILES / FOLDERS
      objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & " - REMOVING INHERITANCE ON LSV DESTINATION"
      objLOG.write vbnewline & vbnewline & now & vbtab & vbtab & " - REMOVING INHERITANCE ON LSV DESTINATION"
      call HOOK("icacls " & chr(34) & strLSV & chr(34) & " /inheritance:r /C")
      if (errRET <> 0) then
        call LOGERR(23)
      end if
      ''REMOVE USER PERMISSIONS, EXCLUDE RMMTECH FROM REMOVAL , 'ERRRET'=24
      objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & " - REMOVING ALL OTHER ENUMERATED USERS' PERMISSIONS"
      objLOG.write vbnewline & vbnewline & now & vbtab & vbtab & " - REMOVING ALL OTHER ENUMERATED USERS' PERMISSIONS"
      for intUSR = 0 to ubound(colUSR)
        intSID = intUSR
        if ((colUSR(intUSR) <> vbnullstring) and (instr(1, lcase(colUSR(intUSR)), strUSR) = 0)) then
          objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & vbtab & " - REMOVING " & colUSR(intUSR) & " : " & colSID(intSID)
          objLOG.write vbnewline & vbnewline & now & vbtab & vbtab & vbtab & " - REMOVING " & colUSR(intUSR) & " : " & colSID(intSID)
          call HOOK("icacls " & chr(34) & strLSV & chr(34) & " /remove:g " & colUSR(intUSR) & " /T /C /Q")
          call HOOK("icacls " & chr(34) & strLSV & chr(34) & " /remove:g *" & colSID(intSID) & " /T /C /Q")
        end if
      next
      if (errRET <> 0) then
        call LOGERR(24)
      end if
      ''DOWNLOAD SVCPERM.VBS SCRIPT TO GRANT USER SERVICE LOGON , 'ERRRET'=30 , REF #2 , FIXES #32 , REF #71
      objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & " - DOWNLOADING SERVICE LOGON SCRIPT : SVCPERM"
      objLOG.write vbnewline & vbnewline & now & vbtab & vbtab & " - DOWNLOADING SERVICE LOGON SCRIPT : SVCPERM"
      call FILEDL("https://raw.githubusercontent.com/CW-Khristos/scripts/master/SVCperm.vbs", "C:\IT\Scripts", "SVCperm.vbs")
      if (errRET <> 0) then
        call LOGERR(30)
      end if
      ''EXECUTE SERVICE LOGON SCRIPT : SVCPERM , 'ERRRET'=31 , REF #2 , FIXES #32 , REF #71
      if (objFSO.fileexists("c:\IT\Scripts\svcperm.vbs")) then                                  ''SVCPERM.VBS DOWNLOAD SUCCESSFUL
        objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & " - EXECUTING SERVICE LOGON SCRIPT : SVCPERM : THIS MAY TAKE A FEW MOMENTS"
        objLOG.write vbnewline & vbnewline & now & vbtab & vbtab & " - EXECUTING SERVICE LOGON SCRIPT : SVCPERM : THIS MAY TAKE A FEW MOMENTS"
        call HOOK("cscript.exe //nologo " & chr(34) & "c:\IT\Scripts\svcperm.vbs" & chr(34) & " " & chr(34) & strUSR & chr(34) & _
          " " & chr(34) & strOPT & chr(34) & " " & chr(34) & strPWD & chr(34) & " " & chr(34) & "Backup Service Controller" & chr(34))
      elseif (not objFSO.fileexists("c:\IT\Scripts\svcperm.vbs")) then                          ''SVCPERM.VBS DOWNLOAD UNSUCCESSFUL , 'ERRRET'=31
        call LOGERR(31)
      end if
      if (errRET = 0) then                                                                ''SERVICE PERMISSIONS UPDATE SUCCESSFUL
        objOUT.write vbnewline & now & vbtab & vbtab & " - LOGON AS SERVICE GRANTED : " & strUSR
        objLOG.write vbnewline & now & vbtab & vbtab & " - LOGON AS SERVICE GRANTED : " & strUSR
        objOUT.write vbnewline & now & vbtab & vbtab & " - BACKUP SERVICE CONTROLLER UPDATED"
        objLOG.write vbnewline & now & vbtab & vbtab & " - BACKUP SERVICE CONTROLLER UPDATED"
      elseif (errRET <> 0) then                                                           ''SERVICE PERMISSIONS UPDATE UNSUCCESFUL , 'ERRRET'=32
        call LOGERR(32)
      end if
    elseif ((instr(1, strIDL, "Idle") = 0) and (instr(1, strIDL, "RegSync") = 0)) then    ''BACKUPS IN PROGRESS , 'ERRRET'=2
      call LOGERR(3)
    end if
  end if
elseif (errRET <> 0) then                                                   ''NO ARGUMENTS PASSED , END SCRIPT , 'ERRRET'=1
  call LOGERR(errRET)
end if
''END SCRIPT
call CLEANUP()
''END SCRIPT
''------------

''SUB-ROUTINES
sub FILEDL(strURL, strDL, strFILE)                                          ''CALL HOOK TO DOWNLOAD FILE FROM URL , 'ERRRET'=11
  strSAV = vbnullstring
  ''SET DOWNLOAD PATH
  strSAV = strDL & "\" & strFILE
  objOUT.write vbnewline & now & vbtab & vbtab & "HTTPDOWNLOAD-------------DOWNLOAD : " & strURL & " : SAVE AS :  " & strSAV
  objLOG.write vbnewline & now & vbtab & vbtab & "HTTPDOWNLOAD-------------DOWNLOAD : " & strURL & " : SAVE AS :  " & strSAV
  ''CREATE HTTP OBJECT
  set objHTTP = createobject("WinHttp.WinHttpRequest.5.1")
  ''DOWNLOAD FROM URL
  objHTTP.open "GET", strURL, false
  objHTTP.send
  if (objFSO.fileexists(strSAV)) then
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
  if (objFSO.fileexists(strSAV)) then
    objOUT.write vbnewline & vbnewline & now & vbtab & " - DOWNLOAD : " & strSAV & " : SUCCESSFUL"
    objLOG.write vbnewline & vbnewline & now & vbtab & " - DOWNLOAD : " & strSAV & " : SUCCESSFUL"
    set objHTTP = nothing
  end if
  if ((err.number <> 0) and (err.number <> 58)) then                        ''ERROR RETURNED DURING DOWNLOAD , 'ERRRET'=11
    call LOGERR(11)
  end if
end sub

sub HOOK(strCMD)                                                            ''CALL HOOK TO MONITOR OUTPUT OF CALLED COMMAND , 'ERRRET'=12
  on error resume next
  objOUT.write vbnewline & now & vbtab & vbtab & "EXECUTING : HOOK" '& strCMD
  objLOG.write vbnewline & now & vbtab & vbtab & "EXECUTING : HOOK" '& strCMD
  set objHOOK = objWSH.exec(strCMD)
  while (not objHOOK.stdout.atendofstream)
    if (instr(1, strCMD, "takeown /F ") = 0) then                           ''SUPPRESS 'TAKEOWN' SUCCESS MESSAGES
      strIN = objHOOK.stdout.readline
      if (strIN <> vbnullstring) then
        objOUT.write vbnewline & now & vbtab & vbtab & vbtab & strIN 
        objLOG.write vbnewline & now & vbtab & vbtab & vbtab & strIN 
      end if
    end if
  wend
  wscript.sleep 10
  if (instr(1, strCMD, "takeown /F ") = 0) then                             ''SUPPRESS 'TAKEOWN' SUCCESS MESSAGES
    strIN = objHOOK.stdout.readall
    if (strIN <> vbnullstring) then
      objOUT.write vbnewline & now & vbtab & vbtab & vbtab & strIN 
      objLOG.write vbnewline & now & vbtab & vbtab & vbtab & strIN 
    end if
  end if
  set objHOOK = nothing
  if (err.number <> 0) then                                                 ''ERROR RETURNED , 'ERRRET'=12
    call LOGERR(12)
  end if
end sub

sub LOGERR(intSTG)                                                          ''CALL HOOK TO LOG AND SET ERRORS
  errRET = intSTG
  if (err.number <> 0) then
    objOUT.write vbnewline & now & vbtab & vbtab & vbtab & err.number & vbtab & err.description & vbnewline
    objLOG.write vbnewline & now & vbtab & vbtab & vbtab & err.number & vbtab & err.description & vbnewline
    err.clear
  end if
  select case intSTG
    case 0                                                                  ''LSVPERM - CLIENTTOOL CHECK PASSED, 'ERRRET'=0
      objOUT.write vbnewline & vbnewline & now & vbtab & " - LSVPERM - CLIENTTOOL CHECK PASSED"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - LSVPERM - CLIENTTOOL CHECK PASSED"
    case 1                                                                  ''LSVPERM - CLIENTTOOL CHECK FAILED, 'ERRRET'=1
      objOUT.write vbnewline & vbnewline & now & vbtab & " - LSVPERM - CLIENTTOOL CHECK FAILED, ENDING LSVPERM"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - LSVPERM - CLIENTTOOL CHECK FAILED, ENDING LSVPERM"
    case 2                                                                  ''LSVPERM - NOT ENOUGH ARGUMENTS, 'ERRRET'=2
      objOUT.write vbnewline & vbnewline & now & vbtab & " - LSVPERM - SCRIPT REQUIRES PATH TO MSP LSV DESTINATION, LSV USER, LSV PASSWORD"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - LSVPERM - SCRIPT REQUIRES PATH TO MSP LSV DESTINATION, LSV USER, LSV PASSWORD"
    case 3                                                                  ''LSVPERM - BACKUPS IN PROGRESS, 'ERRRET'=3
      objOUT.write vbnewline & vbnewline & now & vbtab & " - LSVPERM - BACKUPS IN PROGRESS, ENDING LSVPERM"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - LSVPERM - BACKUPS IN PROGRESS, ENDING LSVPERM"
    case 11                                                                 ''LSVPERM - CALL FILEDL() FAILED, 'ERRRET'=11
      objOUT.write vbnewline & vbnewline & now & vbtab & " - LSVPERM - CALL FILEDL() : " & strSAV
      objLOG.write vbnewline & vbnewline & now & vbtab & " - LSVPERM - CALL FILEDL() : " & strSAV
    case 12                                                                 ''LSVPERM - 'CALL HOOK() FAILED, 'ERRRET'=12
      objOUT.write vbnewline & vbnewline & now & vbtab & " - LSVPERM - CALL HOOK('STRCMD') : " & strCMD & " : FAILED"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - LSVPERM - CALL HOOK('STRCMD') : " & strCMD & " : FAILED"
    case 21                                                                 ''LSVPERM - ICACLS /SETOWNER FAILED, 'ERRRET'=21
      objOUT.write vbnewline & vbnewline & now & vbtab & " - LSVPERM - CALL HOOK('ICACLS /SETOWNER RMMTECH') FAILED"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - LSVPERM - CALL HOOK('ICACLS /SETOWNER RMMTECH') FAILED"
    case 22                                                                 ''LSVPERM - ICACLS /GRANT RMMTECH FAILED, 'ERRRET'=22
      objOUT.write vbnewline & vbnewline & now & vbtab & " - LSVPERM - CALL HOOK('ICACLS /GRANT RMMTECH') FAILED"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - LSVPERM - CALL HOOK('ICACLS /GRANT RMMTECH') FAILED"
    case 23                                                                 ''LSVPERM - ICACLS /INHERITANCE:R FAILED, 'ERRRET'=23
      objOUT.write vbnewline & vbnewline & now & vbtab & " - LSVPERM - CALL HOOK('ICACLS /INHERITANCE:R') FAILED"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - LSVPERM - CALL HOOK('ICACLS /INHERITANCE:R') FAILED"
    case 24                                                                 ''LSVPERM - ICACLS /REMOVE:G USERS FAILED, 'ERRRET'=24
      objOUT.write vbnewline & vbnewline & now & vbtab & " - LSVPERM - CALL HOOK('ICACLS /REMOVE:G USERS') FAILED"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - LSVPERM - CALL HOOK('ICACLS /REMOVE:G USERS') FAILED"
    case 30                                                                 ''LSVPERM - SVCPERM DOWNLOAD FAILED, 'ERRRET'=30
      objOUT.write vbnewline & vbnewline & now & vbtab & " - LSVPERM - SVCPERM DOWNLOAD FAILED"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - LSVPERM - SVCPERM DOWNLOAD FAILED"
    case 31                                                                 ''LSVPERM - SVCPERM NOT FOUND, 'ERRRET'=31
      objOUT.write vbnewline & vbnewline & now & vbtab & " - LSVPERM - SVCPERM NOT FOUND"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - LSVPERM - SVCPERM NOT FOUND"
    case 32                                                                 ''LSVPERM - SVCPERM EDXECUTION FAILED, 'ERRRET'=32
      objOUT.write vbnewline & vbnewline & now & vbtab & " - LSVPERM - SVCPERM EDXECUTION FAILED"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - LSVPERM - SVCPERM EDXECUTION FAILED"
  end select
end sub

sub CLEANUP()                                                               ''SCRIPT CLEANUP
  on error resume next
  if (errRET = 0) then                                                      ''SCRIPT COMPLETED SUCCESSFULLY
    objOUT.write vbnewline & vbnewline & now & vbtab & " - LSVPERM COMPLETE : " & errRET & " : " & now
    objLOG.write vbnewline & vbnewline & now & vbtab & " - LSVPERM COMPLETE : " & errRET & " : " & now
    err.clear
  elseif (errRET <> 0) then                                                 ''SCRIPT FAILED
    objOUT.write vbnewline & vbnewline & now & vbtab & " - LSVPERM FAILURE : " & errRET & " : " & now
    objLOG.write vbnewline & vbnewline & now & vbtab & " - LSVPERM FAILURE : " & errRET & " : " & now
    ''RAISE CUSTOMIZED ERROR CODE, ERROR CODE WILL BE DEFINED RESTOP NUMBER INDICATING WHICH SECTION FAILED
    call err.raise(vbObjectError + errRET, "LSVPERM", "FAILURE")
  end if
  objOUT.write vbnewline & vbnewline & now & " - LSVPERM COMPLETE" & vbnewline
  objLOG.write vbnewline & vbnewline & now & " - LSVPERM COMPLETE" & vbnewline
  objLOG.close
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