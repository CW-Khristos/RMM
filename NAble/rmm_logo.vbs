''RMM_LOGO.VBS
''DESIGNED TO AUTOMATE CW RMMTECH USER ACCOUNT LOGO
''WRITTEN BY : CJ BLEDSOE / CJ<@>THECOMPUTERWARRIORS.COM
'on error resume next
''SCRIPT VARIABLES
dim errRET, strVER, strSEL
''VARIABLES ACCEPTING PARAMETERS - CONFIGURES SNMP TRAP AND COMMUNITY STRING
dim colUSR(), colSID(), arrUSR(), arrSID()
dim strCW, strPUB, strRMM, strSID, arrIMG(6)
''SCRIPT OBJECTS
dim objLOG, objHOOK, objHTTP, objXML
dim objIN, objOUT, objARG, objWSH, objFSO
''VERSION FOR SCRIPT UPDATE, RMM_LOGO.VBS, REF #2 , REF #39
strVER = 1
''DEFAULT SUCCESS
errRET = 0
''SET 'IMAGE' STRINGS
strCW = "cw-logo"
''PUBLIC USER ACCOUNT PICTURE IMAGE NAMES
arrIMG(0) = "Image192"
arrIMG(1) = "Image240"
arrIMG(2) = "Image32"
arrIMG(3) = "Image40"
arrIMG(4) = "Image448"
arrIMG(5) = "Image48"
arrIMG(6) = "Image96"
''USER ACCOUNT PICTURE DIRECTORIES
strPUB = "C:\Users\Public\AccountPictures\"
strRMM = "C:\Users\RMMTech\AppData\Roaming\Microsoft\Windows\AccountPictures\"
''STDIN / STDOUT
set objIN = wscript.stdin
set objOUT = wscript.stdout
set objARG = wscript.arguments
''OBJECTS FOR LOCATING FOLDERS
set objWSH = createobject("wscript.shell")
set objFSO = createobject("scripting.filesystemobject")
''PREPARE LOGFILE
if (objFSO.fileexists("C:\temp\RMM_LOGO")) then              ''LOGFILE EXISTS
  objFSO.deletefile "C:\temp\RMM_LOGO", true
  set objLOG = objFSO.createtextfile("C:\temp\RMM_LOGO")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\RMM_LOGO", 8)
else                                                        ''LOGFILE NEEDS TO BE CREATED
  set objLOG = objFSO.createtextfile("C:\temp\RMM_LOGO")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\RMM_LOGO", 8)
end if
''READ PASSED COMMANDLINE ARGUMENTS
if (wscript.arguments.count > 0) then                       ''ARGUMENTS WERE PASSED
  for x = 0 to (wscript.arguments.count - 1)
    objOUT.write vbnewline & now & vbtab & " - ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
    objLOG.write vbnewline & now & vbtab & " - ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
  next 
  if (wscript.arguments.count > 0) then                     ''REQUIRED ARGUMENTS PASSED
    strUSR = objARG.item(0)                                 ''SET REQUIRED PARAMETER 'STRUSR' ; TARGET USER FOR SERVICE LOGON PERMISSIONS
    if (instr(1, strUSR, "\")) then                         ''INPUT VALIDATION FOR 'STRUSR'
      strUSR = split(strUSR, "\")(1)                        ''STRIP WORKGROUP / DOMAIN FROM PASSED VARIABLE TO ENSURE WE HAVE USER NAME ONLY
    end if
  end if
else                                                        ''NO ARGUMENTS PASSED , END SCRIPT , 'ERRRET'=1
  call LOGERR(1)
end if

''------------
''BEGIN SCRIPT
if (errRET = 0) then
  objOUT.write vbnewline & vbnewline & now & vbtab & " - EXECUTING RMM_LOGO"
  objLOG.write vbnewline & vbnewline & now & vbtab & " - EXECUTING RMM_LOGO"
	''AUTOMATIC UPDATE, RMM_LOGO.VBS, REF #2 , REF #69 , REF #68 , FIXES #9
  objOUT.write vbnewline & now & vbtab & vbtab & " - CHECKING FOR UPDATE : RMM_LOGO : " & strVER
  objLOG.write vbnewline & now & vbtab & vbtab & " - CHECKING FOR UPDATE : RMM_LOGO : " & strVER
  ''DOWNLOAD CHKAU.VBS SCRIPT, REF #2 , REF #69 , REF #68
  call FILEDL("https://raw.githubusercontent.com/CW-Khristos/scripts/master/chkAU.vbs", "C:\IT\Scripts", "chkAU.vbs")
  ''EXECUTE CHKAU.VBS SCRIPT, REF #69
  intRET = objWSH.run ("cmd.exe /C " & chr(34) & "cscript.exe " & chr(34) & "C:\IT\Scripts\chkAU.vbs" & chr(34) & " " & _
    chr(34) & strREPO & chr(34) & " " & chr(34) & strBRCH & chr(34) & " " & chr(34) & strDIR & chr(34) & " " & _
    chr(34) & wscript.scriptname & chr(34) & " " & chr(34) & strVER & chr(34) & " " & _
    chr(34) & strUSR & chr(34) & chr(34), 0, true)
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
          arrSID(intSID) = trim(replace(colSID(intUSR), vbcrlf, vbnullstring))
          intSID = intSID + 1
          objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "MARKED : " & colUSR(intUSR) & " : " & arrSID(intSID - 1)
          objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "MARKED : " & colUSR(intUSR) & " : " & arrSID(intSID - 1)
        end if
      ''HANDLE WITHOUT '\' IN PASSED TARGET USERNAME 'STRUSR' , REF #37
      elseif (instr(1, lcase(strUSR), "\") = 0) then
        if (instr(1, lcase(colUSR(intUSR)), lcase(strUSR))) then
          redim preserve arrSID(intSID + 1)
          arrSID(intSID) = trim(replace(colSID(intUSR), vbcrlf, vbnullstring))
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
    ''ENUMERATE THROUGH EACH USER COLLECTED MATCHING 'STRUSR' TARGET USER , REF #2 , REF #39
    ''THIS ALLOWS FOR TARGETING BOTH LOCAL AND DOMAIN USER VARIANTS
    for intSID = 0 to ubound(arrSID)
      objOUT.write vbnewline & vbtab & vbtab & arrSID(intSID)
    next
    for intSID = 0 to ubound(arrSID)
      if (arrSID(intSID) <> vbnullstring) then
        ''CREATE RMMTECH SID KEY
        set objUFOL = objFSO.getfolder("C:\Users")
        set colFOL = objUFOL.subfolders
        for each sFOL in colFOL
          if (instr(1, lcase(sFOL.name), "rmmtech")) then
            if (not (objFSO.folderexists(sFOL.path & "\AppData\Roaming\Microsoft\Windows\AccountPictures"))) then
              objFSO.createfolder(sFOL.path & "\AppData\Roaming\Microsoft\Windows\AccountPictures")
            end if
            call FILEDL("https://github.com/CW-Khristos/scripts/blob/dev/CW%20Logo/cw-logo.accountpicture-ms?raw=true", sFOL.path & "\AppData\Roaming\Microsoft\Windows\AccountPictures\", "cw-logo.accountpicture-ms")
            wscript.sleep 1000
          end if
        next
        objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "ADDING : HKLM\SOFTWARE\MICROSOFT\WINDOWS\CURRENTVERSION\ACCOUNTPICTURE KEYS"
        objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "ADDING : HKLM\SOFTWARE\MICROSOFT\WINDOWS\CURRENTVERSION\ACCOUNTPICTURE KEYS"
        call HOOK("reg add " & chr(34) & "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AccountPicture\Users\" & arrSID(intSID) & chr(34) & _
          " /f /ve /t REG_SZ /reg:32")
        call HOOK("reg add " & chr(34) & "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AccountPicture\Users\" & arrSID(intSID) & chr(34) & _
          " /f /ve /t REG_SZ /reg:64")
        ''ADD PUBLIC USER ACCOUNT PICTURE REGISTRY KEYS
        if (not (objFSO.folderexists(strPUB & arrSID(intSID)))) then
          'errRET = objFSO.createfolder(chr(34) & strPUB & arrSID(intSID) & chr(34))
          'objOUT.write vbnewline & vbtab & errRET
          strRCMD = "mkdir " & chr(34) & "C:\Users\Public\AccountPictures\" & arrSID(intSID) & chr(34)
          call HOOK("CMD /C " & strRCMD)
          wscript.sleep 1000
        end if
        for intIMG = 0 to ubound(arrIMG)
          call FILEDL("https://github.com/CW-Khristos/scripts/raw/dev/CW%20Logo/pub/" & strCW & "-" & arrIMG(intIMG) & ".jpg", "c:\temp\", strCW & "-" & arrIMG(intIMG) & ".jpg")
          strRCMD = "copy " & chr(34) & "c:\temp\" & strCW & "-" & arrIMG(intIMG) & ".jpg" & chr(34) & " " & chr(34) & strPUB & arrSID(intSID) & "\" & strCW & "-" & arrIMG(intIMG) & ".jpg" & chr(34) & " /Y"
          call HOOK("CMD /C " & chr(34) & strRCMD & chr(34))
          wscript.sleep 1000
          ''ADD PUBLIC USER ACCOUNT PICTURE REGISTRY VALUES
          objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "ADDING : HKLM\SOFTWARE\MICROSOFT\WINDOWS\CURRENTVERSION\ACCOUNTPICTURE VALUES"
          objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "ADDING : HKLM\SOFTWARE\MICROSOFT\WINDOWS\CURRENTVERSION\ACCOUNTPICTURE VALUES"
          call HOOK("reg add " & chr(34) & "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AccountPicture\Users\" & arrSID(intSID) & chr(34) & _
            " /f /v " & chr(34) & arrIMG(intIMG) & chr(34) & " /t REG_SZ /d " & chr(34) & strPUB & arrSID(intSID) & "\" & strCW & "-" & arrIMG(intIMG) & ".jpg" & chr(34) & " /reg:32")
          call HOOK("reg add " & chr(34) & "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AccountPicture\Users\" & arrSID(intSID) & chr(34) & _
            " /f /v " & chr(34) & arrIMG(intIMG) & chr(34) & " /t REG_SZ /d " & chr(34) & strPUB & arrSID(intSID) & "\" & strCW & "-" & arrIMG(intIMG) & ".jpg" & chr(34) & "  /reg:64")
          wscript.sleep 1000
        next
        ''ADD RMMTECH USER ACCOUNT PICTURE REGISTRY KEYS
        objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "ADDING : HKU\SOFTWARE\MICROSOFT\WINDOWS\CURRENTVERSION\ACCOUNTPICTURE KEYS"
        objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "ADDING : HKU\SOFTWARE\MICROSOFT\WINDOWS\CURRENTVERSION\ACCOUNTPICTURE KEYS"
        strRCMD = "reg add " & chr(34) & "HKU\" & arrSID(intSID) & "\SOFTWARE\Microsoft\Windows\CurrentVersion\AccountPicture" & chr(34) & _
            " /f /ve /t REG_SZ /reg:32"
        call HOOK("CMD /C " & chr(34) & strRCMD & chr(34))
        wscript.sleep 1000
        strRCMD = "reg add " & chr(34) & "HKU\" & arrSID(intSID) & "\SOFTWARE\Microsoft\Windows\CurrentVersion\AccountPicture" & chr(34) & _
            " /f /ve /t REG_SZ /reg:64"
        call HOOK("CMD /C " & chr(34) & strRCMD & chr(34))
        wscript.sleep 1000
        ''ADD RMMTECH USER ACCOUNT PICTURE REGISTRY VALUES
        objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "ADDING : HKU\SOFTWARE\MICROSOFT\WINDOWS\CURRENTVERSION\ACCOUNTPICTURE VALUES"
        objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "ADDING : HKU\SOFTWARE\MICROSOFT\WINDOWS\CURRENTVERSION\ACCOUNTPICTURE VALUES"
        strRCMD = "reg add " & chr(34) & "HKU\" & arrSID(intSID) & "\SOFTWARE\Microsoft\Windows\CurrentVersion\AccountPicture" & chr(34) & _
            " /f /v SourceId /t REG_SZ /d " & chr(34) & strCW & chr(34) & " /reg:32"
        call HOOK("CMD /C " & chr(34) & strRCMD & chr(34))
        wscript.sleep 1000
        strRCMD = "reg add " & chr(34) & "HKU\" & arrSID(intSID) & "\SOFTWARE\Microsoft\Windows\CurrentVersion\AccountPicture" & chr(34) & _
            " /f /v SourceId /t REG_SZ /d " & chr(34) & strCW & chr(34) & " /reg:64"
        call HOOK("CMD /C " & chr(34) & strRCMD & chr(34))
        wscript.sleep 1000
        ''ADD RMMTECH USER ACCOUNT STATE REGISTRY KEYS
        objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "ADDING : HKU\SOFTWARE\MICROSOFT\WINDOWS\CURRENTVERSION\ACCOUNTSTATE KEYS"
        objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "ADDING : HKU\SOFTWARE\MICROSOFT\WINDOWS\CURRENTVERSION\ACCOUNTSTATE KEYS"
        strRCMD = "reg add " & chr(34) & "HKU\" & arrSID(intSID) & "\SOFTWARE\Microsoft\Windows\CurrentVersion\AccountState" & chr(34) & _
            " /f /ve /t REG_SZ /reg:32"
        call HOOK("CMD /C " & chr(34) & strRCMD & chr(34))
        wscript.sleep 1000
        strRCMD = "reg add " & chr(34) & "HKU\" & arrSID(intSID) & "\SOFTWARE\Microsoft\Windows\CurrentVersion\AccountState" & chr(34) & _
            " /f /ve /t REG_SZ /reg:64"
        call HOOK("CMD /C " & chr(34) & strRCMD & chr(34))
        wscript.sleep 1000
      end if
    next
  end if
elseif (errRET <> 0) then
  call LOGERR(errRET)
end if
''END SCRIPT
call CLEANUP()
''END SCRIPT
''------------

''SUB-ROUTINES
sub FILEDL(strURL, strPATH, strFILE)                        ''CALL HOOK TO DOWNLOAD FILE FROM URL , 'ERRRET'=2
  strSAV = vbnullstring
  ''SET DOWNLOAD PATH
  strSAV = strPATH & strFILE
  objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & vbtab & "HTTPDOWNLOAD-------------DOWNLOAD : " & strURL & " : SAVE AS :  " & strSAV
  objLOG.write vbnewline & vbnewline & now & vbtab & vbtab & vbtab & "HTTPDOWNLOAD-------------DOWNLOAD : " & strURL & " : SAVE AS :  " & strSAV
  ''CREATE HTTP OBJECT
  set objHTTP = createobject( "WinHttp.WinHttpRequest.5.1" )
  ''DOWNLOAD FROM URL
  objHTTP.open "GET", strURL, false
  objHTTP.send
  ''CHECK IF FILE ALREADY EXISTS
  if (objFSO.fileexists(strSAV)) then
    ''DELETE FILE FOR OVERWRITE
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

sub HOOK(strCMD)                                            ''CALL HOOK TO MONITOR OUTPUT OF CALLED COMMAND , 'ERRRET'=3
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
end sub

sub CLEANUP()                                               ''SCRIPT CLEANUP
  if (errRET = 0) then         												      ''RMM_LOGO COMPLETED SUCCESSFULLY
    objOUT.write vbnewline & "RMM_LOGO SUCCESSFUL : " & now
    err.clear
  elseif (errRET <> 0) then    												      ''RMM_LOGO FAILED
    objOUT.write vbnewline & "RMM_LOGO FAILURE : " & errRET & " : " & now
    ''RAISE CUSTOMIZED ERROR CODE, ERROR CODE WILL BE DEFINE RESTOP NUMBER INDICATING WHICH SECTION FAILED
    call err.raise(vbObjectError + errRET, "RMM_LOGO", "FAILURE")
  end if
  objOUT.write vbnewline & vbnewline & now & " - RMM_LOGO COMPLETE. PLEASE LOGOUT AND LOGIN AGAIN" & vbnewline
  objLOG.write vbnewline & vbnewline & now & " - RMM_LOGO COMPLETE. PLEASE LOGOUT AND LOGIN AGAIN" & vbnewline
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