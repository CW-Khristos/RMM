''DISK_USAGE.VBS
''DESIGNED TO AUTOMATE ANALYSIS AND REPORTING OF DISK USAGE STATISTICS USING X.ROBOT CMD UTILITY
''WRITTEN BY : CJ BLEDSOE / CJ<@>THECOMPUTERWARRIORS.COM
on error resume next
''SCRIPT VARIABLES
dim errRET, strVER, strIN, intOPT
''SCRIPT OBJECTS
dim objIN, objOUT, objARG, objWSH, objFSO
dim objLOG, objHOOK, objEXEC, objHTTP, objXML
''VERSION FOR SCRIPT UPDATE, DISK_USAGE.VBS, REF #2 , REF #68 , REF #69 , FIXES #45
strVER = 4
strREPO = "scripts"
strBRCH = "master"
strDIR = vbnullstring
''DEFAULT SUCCESS
errRET = 0
''ZIP ARCHIVE OPTIONS
intOPT = 256
''STDIN / STDOUT
set objIN = wscript.stdin
set objOUT = wscript.stdout
set objARG = wscript.arguments
''OBJECTS FOR LOCATING FOLDERS
set objWSH = createobject("wscript.shell")
Set objAPP = createobject("shell.application")
set objFSO = createobject("scripting.filesystemobject")
''CHECK 'PERSISTENT' FOLDERS , REF #2 , REF #73
if (not (objFSO.folderexists("C:\IT\"))) then
  objFSO.createfolder("C:\IT\")
end if
if (not (objFSO.folderexists("C:\IT\Scripts\"))) then
  objFSO.createfolder("C:\IT\Scripts\")
end if
''PREPARE LOGFILE
if (objFSO.fileexists("C:\temp\DISK_USAGE")) then             ''LOGFILE EXISTS
  objFSO.deletefile "C:\temp\DISK_USAGE", true
  set objLOG = objFSO.createtextfile("C:\temp\DISK_USAGE")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\DISK_USAGE", 8)
else                                                          ''LOGFILE NEEDS TO BE CREATED
  set objLOG = objFSO.createtextfile("C:\temp\DISK_USAGE")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\DISK_USAGE", 8)
end if
''READ PASSED COMMANDLINE ARGUMENTS
if (wscript.arguments.count > 0) then                         ''ARGUMENTS WERE PASSED
  for x = 0 to (wscript.arguments.count - 1)
    objOUT.write vbnewline & now & vbtab & " - ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
    objLOG.write vbnewline & now & vbtab & " - ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
  next 
  if (wscript.arguments.count > 0) then                       ''REQUIRED ARGUMENTS PASSED
    strPATH = objARG.item(0)                                  ''PATH TO OUTPUT X.ROBOT DISK USAGE REPORT
    strFORM = objARG.item(1)                                  ''FORMAT OF X.ROBOT DISK USAGE REPORT; CURRENTLY SUPPORTS 'HTM' OR 'CSV'
  end if
else                                                          ''NO ARGUMENTS PASSED , END SCRIPT , 'ERRRET'=1
  call LOGERR(1)
  err.clear
end if

''------------
''BEGIN SCRIPT
if (errRET = 1) then                                          ''NO ARGUMENTS PASSED
  strFORM = "HTM"
  strPATH = "C:\IT\Scripts"
  objOUT.write vbnewline & vbnewline & now & vbtab & " - EXECUTING DISK_USAGE"
  objLOG.write vbnewline & vbnewline & now & vbtab & " - EXECUTING DISK_USAGE"
	''AUTOMATIC UPDATE, DISK_USAGE.VBS, REF #2 , REF #69 , REF #68
  objOUT.write vbnewline & now & vbtab & vbtab & " - CHECKING FOR UPDATE : DISK_USAGE : " & strVER
  objLOG.write vbnewline & now & vbtab & vbtab & " - CHECKING FOR UPDATE : DISK_USAGE : " & strVER
  ''DOWNLOAD CHKAU.VBS SCRIPT, REF #2 , REF #68 , REF #69 , FIXES #45
  call FILEDL("https://raw.githubusercontent.com/CW-Khristos/scripts/master/chkAU.vbs", "C:\IT\Scripts", "chkAU.vbs")
  ''EXECUTE CHKAU.VBS SCRIPT, REF #69
  intRET = objWSH.run ("cmd.exe /C " & chr(34) & "cscript.exe " & chr(34) & "C:\IT\Scripts\chkAU.vbs" & chr(34) & " " & _
    chr(34) & strREPO & chr(34) & " " & chr(34) & strBRCH & chr(34) & " " & chr(34) & strDIR & chr(34) & " " & _
    chr(34) & wscript.scriptname & chr(34) & " " & chr(34) & strVER & chr(34) & " " & _
    chr(34) & strPATH & "|" & strFORM & chr(34) & chr(34), 0, true)
  ''CHKAU RETURNED - NO UPDATE FOUND , REF #2 , REF #68 , REF #69
  objOUT.write vbnewline & "errRET='" & intRET & "'"
  objLOG.write vbnewline & "errRET='" & intRET & "'"
  intRET = (intRET - vbObjectError)
  objOUT.write vbnewline & "errRET='" & intRET & "'"
  objLOG.write vbnewline & "errRET='" & intRET & "'"
  if ((intRET = 4) or (intRET = 10) or (intRET = 11) or (intRET = 1) or (intRET = 2147221505) or (intRET = 2147221517)) then
    ''CHECK FOR X.ROBOT.EXE IN C:\TEMP\X.ROBOT32
    if (not objFSO.fileexists("c:\IT\X.Robot32\x.robot.exe")) then
      call FILEDL("https://raw.githubusercontent.com/CW-Khristos/scripts/master/XRobot/X.Robot32.zip", "C:\IT", "X.Robot32.zip")
      wscript.sleep 5000
      ''CHECK FOR X.ROBOT32.ZIP IN C:\TEMP, REF #46
      if (not objFSO.fileexists("c:\IT\X.Robot32.zip")) then
        call FILEDL("https://raw.githubusercontent.com/CW-Khristos/scripts/master/XRobot/X.Robot32.zip", "C:\IT", "X.Robot32.zip")
      end if
      if (objFSO.fileexists("C:\IT\X.Robot32.zip")) then
        ''EXTRACT X.ROBOT32.ZIP TO C:\TEMP\XROBOT
        set objSRC = objAPP.namespace("C:\IT\X.Robot32.zip").items()
        set objTGT = objAPP.namespace("C:\IT")
        objTGT.copyhere objSRC, intOPT
      end if
    end if
    if (objFSO.fileexists("c:\IT\X.Robot32\x.robot.exe")) then
      strRCMD = "c:\IT\x.robot32\x.robot.exe " & chr(34) & strPATH & chr(34)
      if (ucase(strFORM) = "HTM") then
        strRCMD = strRCMD & " /HTM{111111111120};c:\IT\robot.htm"
      elseif (ucase(strFORM) = "CSV") then
        strRCMD = strRCMD & " /CSV{113};c:\IT\robot.csv"
      end if
      call HOOK("CMD /C " & chr(34) & strRCMD & chr(34))
      ''DISABLED ZIP ARCHIVE CALLS
      'wscript.sleep 5000
      if (ucase(strFORM) = "HTM") then
        call FILEDL("https://raw.githubusercontent.com/CW-Khristos/scripts/master/XRobot/SavePage.exe", "C:\IT", "savepage.exe")
        strRCMD = "c:\IT\savepage.exe " & chr(34) & "XRobot - Report" & chr(34) & " " & chr(34) & "file://c:/IT/robot.htm" & chr(34) & " " & chr(34) & "C:\IT\" & chr(34)
        call HOOK("CMD /C " & chr(34) & strRCMD & chr(34))
      '  call makZIP("c:\temp\robot.htm", "c:\temp\robot.zip")
      '  wscript.sleep 1000
      '  call makZIP("c:\temp\data", "c:\temp\robot.zip")
      end if
    end if
  end if
elseif (errRET = 0) then                                      ''ARGUMENTS PASSED
  objOUT.write vbnewline & vbnewline & now & vbtab & " - EXECUTING DISK_USAGE"
  objLOG.write vbnewline & vbnewline & now & vbtab & " - EXECUTING DISK_USAGE"
	''AUTOMATIC UPDATE, DISK_USAGE.VBS, REF #2 , REF #68 , REF #69 , FIXES #45
  ''DOWNLOAD CHKAU.VBS SCRIPT, REF #2 , REF #68 , REF #69
  call FILEDL("https://raw.githubusercontent.com/CW-Khristos/scripts/master/chkAU.vbs", "C:\IT\Scripts", "chkAU.vbs")
  ''EXECUTE CHKAU.VBS SCRIPT, REF #69
  objOUT.write vbnewline & now & vbtab & vbtab & " - CHECKING FOR UPDATE : DISK_USAGE : " & strVER
  objLOG.write vbnewline & now & vbtab & vbtab & " - CHECKING FOR UPDATE : DISK_USAGE : " & strVER
  intRET = objWSH.run ("cmd.exe /C " & chr(34) & "cscript.exe " & chr(34) & "C:\IT\Scripts\chkAU.vbs" & chr(34) & " " & _
    chr(34) & strREPO & chr(34) & " " & chr(34) & strBRCH & chr(34) & " " & chr(34) & strDIR & chr(34) & " " & _
    chr(34) & wscript.scriptname & chr(34) & " " & chr(34) & strVER & chr(34) & " " & _
    chr(34) & strPATH & "|" & strFORM & chr(34) & chr(34), 0, true)
  ''CHKAU RETURNED - NO UPDATE FOUND , REF #2 , REF #69 , REF #68
  objOUT.write vbnewline & "errRET='" & intRET & "'"
  objLOG.write vbnewline & "errRET='" & intRET & "'"
  intRET = (intRET - vbObjectError)
  objOUT.write vbnewline & "errRET='" & intRET & "'"
  objLOG.write vbnewline & "errRET='" & intRET & "'"
  if ((intRET = 4) or (intRET = 10) or (intRET = 11) or (intRET = 1) or (intRET = 2147221505) or (intRET = 2147221517)) then
    ''CHECK FOR X.ROBOT.EXE IN C:\TEMP\X.ROBOT32
    if (not objFSO.fileexists("c:\IT\X.Robot32\x.robot.exe")) then
      call FILEDL("https://raw.githubusercontent.com/CW-Khristos/scripts/master/XRobot/X.Robot32.zip", "C:\IT", "X.Robot32.zip")
      wscript.sleep 5000
      ''CHECK FOR X.ROBOT32.ZIP IN C:\TEMP, REF #46
      if (not objFSO.fileexists("c:\IT\X.Robot32.zip")) then
        call FILEDL("https://raw.githubusercontent.com/CW-Khristos/scripts/master/XRobot/X.Robot32.zip", "C:\IT", "X.Robot32.zip")
      end if
      if (objFSO.fileexists("C:\IT\X.Robot32.zip")) then
        ''EXTRACT X.ROBOT32.ZIP TO C:\TEMP\XROBOT
        set objSRC = objAPP.namespace("C:\IT\X.Robot32.zip").items()
        set objTGT = objAPP.namespace("C:\IT")
        objTGT.copyhere objSRC, intOPT
      end if
    end if
    ''CHECK FOR EXTRACTED X.ROBOT
    if (objFSO.fileexists("c:\IT\X.Robot32\x.robot.exe")) then
      strRCMD = "c:\IT\x.robot32\x.robot.exe " & chr(34) & strPATH & chr(34)
      if (ucase(strFORM) = "HTM") then
        strRCMD = strRCMD & " /HTM{111111111120};c:\IT\robot.htm"
      elseif (ucase(strFORM) = "CSV") then
        strRCMD = strRCMD & " /CSV{113};c:\IT\robot.csv"
      end if
      ''EXECUTE X.ROBOT
      call HOOK("CMD /C " & chr(34) & strRCMD & chr(34))
      ''DISABLED ZIP ARCHIVE CALLS
      'wscript.sleep 5000
      ''CONVERT TO HTM FORMAT
      if (ucase(strFORM) = "HTM") then
        call FILEDL("https://raw.githubusercontent.com/CW-Khristos/scripts/master/XRobot/SavePage.exe", "C:\IT", "savepage.exe")
        strRCMD = "c:\IT\savepage.exe " & chr(34) & "XRobot - Report" & chr(34) & " " & chr(34) & "C:/IT/robot.htm" & chr(34) & " " & chr(34) & "C:\IT\" & chr(34)
        call HOOK("CMD /C " & chr(34) & strRCMD & chr(34))
        ''ARCHIVE HTM REPORT DATA
      '  call makZIP("c:\temp\data", "c:\temp\robot.zip")
      '  wscript.sleep 1000
      '  call makZIP("c:\temp\robot.htm", "c:\temp\robot.zip")
      end if
    end if
    if (objFSO.folderexists("C:\Windows\CSC")) then
      set objFOL = objFSO.getfolder("C:\Windows\CSC")
      intSIZ = (objFOL.size / 1048576)  ''CONVERT TO MB
      objOUT.write vbnewline & now & vbtab & vbtab & "CSC CACHE SIZE (MB) : " & intSIZ
      objLOG.write vbnewline & now & vbtab & vbtab & "CSC CACHE SIZE (MB) : " & intSIZ
    end if
  end if
end if
''END SCRIPT
call CLEANUP()
''END SCRIPT
''------------

''FUNCTIONS
function makZIP(strSRC, strZIP)                                                       ''MAKE ZIP ARCHIVE , 'ERRRET'=60
  strSRC = objFSO.getabsolutepathname(strSRC)
  strZIP = objFSO.getabsolutepathname(strZIP)
  if (not objFSO.fileexists(strZIP)) then                                             ''MAKE NEW ZIP ARCHIVE IF ARCHIVE DOES NOT EXIST , 'ERRRET'=61
    call newZIP(strZIP)
  end if
  ''ENUMERATE FILES
  sDupe = false
  aFileName = split(strSRC, "\")
  sFileName = (aFileName(ubound(aFileName)))
  sZipFileCount = objAPP.namespace(strZIP).items.count
  if (sZipFileCount > 0) then                                                         ''CHECK FOR DUPLICATES
    for each strZIPFILE in objAPP.namespace(strZIP).items
      if lcase(sFileName) = lcase(strZIPFILE) then                                    ''DUPLICATE FOUND
        sDupe = true
        exit for
      end if
    next
  end if
  if (not sDupe) then                                                                 ''DUPLICATE NOT FOUND
    objAPP.namespace(strZIP).copyhere objAPP.namespace(strSRC).items, 16
    ''CHECK FOR COMPLETION OF COMPRESSION
    intLOOP = 0
    do until (sZipFileCount < objAPP.namespace(strZIP).items.count)
      wscript.sleep 500
      objOUT.write "."
      intLOOP = intLOOP + 1
    loop
    objOUT.write vbnewline & vbtab & vbtab & "ZIP COMPLETED" & vbnewline
  end if
  set objZIP = nothing
  if (err.number <> 0) then                                                           ''ERROR RETURNED DURING ZIP ARCHIVE CREATION , 'ERRRET'=61
    call LOGERR(60)
  end if
end function

''SUB-ROUTINES
sub newZIP(strNZIP)                                                                   ''PREPARE NEW ZIP ARCHIVE , 'ERRRET'=61
  Set objNFIL = objFSO.createtextfile(strNZIP)
  objNFIL.write chr(80) & chr(75) & chr(5) & chr(6) & string(18, 0)
  objNFIL.close
  set objNFIL = nothing
  wscript.sleep 500
  if (err.number <> 0) then                                                           ''ERROR CREATING NEW ZIP ARCHIVE , 'ERRRET'=61
    call LOGERR(61)
  end if
end sub

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

sub HOOK(strCMD)                                              ''CALL HOOK TO MONITOR OUTPUT OF CALLED COMMAND
  on error resume next
  objOUT.write vbnewline & now & vbtab & vbtab & "EXECUTING : " & strCMD
  objLOG.write vbnewline & now & vbtab & vbtab & "EXECUTING : " & strCMD
  set objHOOK = objWSH.exec(strCMD)
  if (instr(1, strCMD, "takeown /F ") = 0) then               ''SUPPRESS 'TAKEOWN' SUCCESS MESSAGES
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
  if (err.number <> 0) then
    errRET = 3
    objOUT.write vbnewline & now & vbtab & vbtab & vbtab & err.number & vbtab & err.description
    objLOG.write vbnewline & now & vbtab & vbtab & vbtab & err.number & vbtab & err.description
    err.clear
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

sub CLEANUP()                                                 ''SCRIPT CLEANUP
  if (errRET = 0) then                                        ''SCRIPT COMPLETED SUCCESSFULLY
    objOUT.write vbnewline & vbnewline & now & vbtab & " - DISK_USAGE COMPLETE : " & now
    objLOG.write vbnewline & vbnewline & now & vbtab & " - DISK_USAGE COMPLETE : " & now
    err.clear
  elseif (errRET <> 0) then                                   ''SCRIPT FAILED
    objOUT.write vbnewline & vbnewline & now & vbtab & " - DISK_USAGE FAILURE : " & errRET & " : " & now
    objLOG.write vbnewline & vbnewline & now & vbtab & " - DISK_USAGE FAILURE : " & errRET & " : " & now
    ''RAISE CUSTOMIZED ERROR CODE, ERROR CODE WILL BE DEFINED RESTOP NUMBER INDICATING WHICH SECTION FAILED
    call err.raise(vbObjectError + errRET, "DISK_USAGE", "fail")
  end if
  ''EMPTY OBJECTS
  set objFPD = nothing
  set objWMI = nothing
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