''CHKAU.VBS
''DESIGNED TO AUTOMATE UPDATING AND RE-EXECUTION OF CW SCRIPTS
''CHECKS FOR UPDATE TO PASSED SCRIPT; BASED ON PASSED 'BRANCH','SCRIPT','VERSION'
''HANDLES PASSING OF ANY 'ARGUMENTS' GIVEN TO ORIGINAL SCRIPT TO UPDATED COPY
''ACCEPTS 6 PARAMETERS , REQUIRES 5 PARAMETERS
''REQUIRED PARAMETER 'STRREPO' ; STRING VALUE TO HOLD PASSED 'REPO' ; TARGET GITHUB REPOSITORY
''REQUIRED PARAMETER 'STRBRCH' ; STRING VALUE TO HOLD PASSED 'BRANCH' ; TARGET GITHUB BRANCH
''REQUIRED PARAMETER 'STRDIR' ; STRING VALUE TO HOLD PASSED 'DIRECTORY' ; TARGET GITHUB SCRIPT DIRECTORY
''REQUIRED PARAMETER 'STRSCR' ; STRING VALUE TO HOLD PASSED 'SCRIPTNAME' ; WSCRIPT.SCRIPTNAME
''REQUIRED PARAMETER 'STRSVER' ; STRING VALUE TO HOLD PASSED 'VERSION' ; 'STRVER'
''OPTIONAL PARAMETER 'STRARG' ; STRING VALUE TO HOLD PASSED 'ARGUMENTS' ; SEPARATE MULTIPLE 'ARGUMENTS' VIA '|'
''WRITTEN BY : CJ BLEDSOE / CJ<@>THECOMPUTERWARRIORS.COM
on error resume next
''SCRIPT VARIABLES
dim errRET, strVER
''VARIABLES ACCEPTING PARAMETERS
dim strARG, arrARG
dim strSCR, strSVER
dim strREPO, strBRCH, strDIR
dim strIN, strOUT, strOPT, strRCMD
''SCRIPT OBJECTS
dim objIN, objOUT, objARG, objWSH, objFSO
dim objLOG, objEXEC, objHOOK, objHTTP, objXML
''VERSION FOR SCRIPT UPDATE , CHKAU.VBS , REF #2 , REF #69 , FIXES #68
strVER = 9
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
if (objFSO.fileexists("C:\temp\CHKAU")) then                  ''LOGFILE EXISTS
  objFSO.deletefile "C:\temp\CHKAU", true
  set objLOG = objFSO.createtextfile("C:\temp\CHKAU")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\CHKAU", 8)
else                                                          ''LOGFILE NEEDS TO BE CREATED
  set objLOG = objFSO.createtextfile("C:\temp\CHKAU")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\CHKAU", 8)
end if
''READ PASSED COMMANDLINE ARGUMENTS
if (wscript.arguments.count > 4) then                         ''ARGUMENTS WERE PASSED
  ''ARGUMENT OUTPUT DISABLED TO SANITIZE
  'for x = 0 to (wscript.arguments.count - 1)
  '  objOUT.write vbnewline & now & vbtab & " - ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
  '  objLOG.write vbnewline & now & vbtab & " - ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
  'next 
  if (wscript.arguments.count > 4) then                       ''SET VARIABLES ACCEPTING ARGUMENTS
    strREPO = objARG.item(0)                                  ''SET REQUIRED PARAMETER 'STRREPO' , TARGET 'REPO' TO UPDATE FROM ON GITHUB
    strBRCH = objARG.item(1)                                  ''SET REQUIRED PARAMETER 'STRBRCH' , TARGET 'BRANCH' TO UPDATE FROM ON GITHUB
    strDIR = objARG.item(2)                                   ''SET REQUIRED PARAMETER 'STRDIR' , TARGET 'DIRECTORY' TO UPDATE FROM ON GITHUB
    strSCR = objARG.item(3)                                   ''SET REQUIRED PARAMETER 'STRSCR' , TARGET 'SCRIPTNAME' TO UPDATE
    strSVER = objARG.item(4)                                  ''SET REQUIRED PARAMETER 'STRSVER' , REQUESTING SCRIPT 'VERSION' TO COMPARE
    if (wscript.arguments.count > 5) then                     ''SET OPTIONAL PARAMETERS
      strARG = objARG.item(5)                                 ''SET OPTIONAL PARAMETER 'STRARG' , ORIGINAL 'ARGUMENTS' FROM REQUESTING SCRIPT ; SEPARATE MULTIPLE 'ARGUMENTS' VIA '|'
      ''FILL 'ARRARG' ORIGINAL 'ARGUMENTS'
      objOUT.write vbnewline & vbtab & strARG
      if (instr(1, strARG, "|")) then
        arrARG = split(strARG, "|")
        for intTMP = 0 to ubound(arrARG)
          objOUT.write vbnewline & vbtab & ubound(arrARG) & vbtab & arrARG(intTMP)
        next
      end if
    end if
  end if
elseif (wscript.arguments.count <= 4) then                    ''NOT ENOUGH ARGUMENTS PASSED , END SCRIPT , 'ERRRET'=1
  call LOGERR(1)
end if

''------------
''BEGIN SCRIPT
strTMP = vbnullstring
if (errRET = 0) then                                          ''ARGUMENTS PASSED, CONTINUE SCRIPT
	objOUT.write vbnewline & vbnewline & now & vbtab & " - EXECUTING CHKAU : " & strVER
	objLOG.write vbnewline & vbnewline & now & vbtab & " - EXECUTING CHKAU : " & strVER
	''AUTOMATIC UPDATE, CHKAU.VBS, REF #2 , REF #69 , REF #68
	'call CHKAU(wscript.scriptname, strVER, _
  '  strREPO & "|" & strBRCH & "|" & strDIR & "|" & strSCR & "|" & strSVER & "|" & strARG)
  'if (blnCHKAU = true) then
  '  objOUT.write vbnewline & vbnewline & now & vbtab & " - CHKAU UPDATED - RE-EXECUTED : " & wscript.scriptname & " : " & _
  '    strREPO & "|" & strBRCH & "|" & strDIR & "|" & strSCR & "|" & strSVER & "|" & strARG
  '  objLOG.write vbnewline & vbnewline & now & vbtab & " - CHKAU UPDATED - RE-EXECUTED : " & wscript.scriptname & " : " & _ 
  '    strREPO & "|" & strBRCH & "|" & strDIR & "|" & strSCR & "|" & strSVER & "|" & strARG
  'elseif (blnCHKAU = false) then
  '  objOUT.write vbnewline & vbnewline & now & vbtab & " - CHKAU NO UPDATE - EXITING : CHKAU : SELF-UPDATE"
  '  objLOG.write vbnewline & vbnewline & now & vbtab & " - CHKAU NO UPDATE - EXITING : CHKAU : SELF-UPDATE"
  'end if
  ''AUTOMATIC UPDATE, REQUESTING SCRIPT 'STRSCR', REF #2 , REF #69 , FIXES #68
  if (CHKAU(strSCR, strSVER, strARG)) then                    ''CHKAU - UPDATE SUCCESSFUL
    call LOGERR(3)
    objOUT.write vbnewline & now & vbtab & " - CHKAU UPDATED - RE-EXECUTED : " & strSCR & " " & strARG
    objLOG.write vbnewline & now & vbtab & " - CHKAU UPDATED - RE-EXECUTED : " & strSCR & " " & strARG
  else                                                        ''CHKAU - NO UPDATE / UPDATE FAILED
    call LOGERR(4)
    objOUT.write vbnewline & now & vbtab & " - CHKAU NO UPDATE - EXITING : " & strSCR & " " & strARG
    objLOG.write vbnewline & now & vbtab & " - CHKAU NO UPDATE - EXITING : " & strSCR & " " & strARG
  end if
elseif (errRET <> 0) then                                     ''NO ARGUMENTS PASSED, END SCRIPT , 'ERRRET'=1
  call LOGERR(errRET)
end if
''END SCRIPT
call CLEANUP()
''END SCRIPT
''------------

''CHKAU FUNCTIONS
function CHKAU(strSCR, strSVER, strSARG)                      ''CHECK FOR SCRIPT UPDATE , 'ERRRET'=10 , CHKAU.VBS , REF #2 , REF #69 , FIXES #68
  on error resume next
  ''NO LONGER REQUIRED WITH NCENTRAL 2021; SCRIPTS ARE PLACED IN INDIVIDUAL 'TASK' DIRECTORIES
  ''REMOVE WINDOWS AGENT CACHED VERSION OF SCRIPT, CHKAU.VBS , REF #2 , REF #68 , FIXES #69
  'if (objFSO.fileexists("C:\Program Files (x86)\N-Able Technologies\Windows Agent\Temp\Script\" & strSCR)) then
  '  objFSO.deletefile "C:\Program Files (x86)\N-Able Technologies\Windows Agent\Temp\Script\" & strSCR, true
  'end if
  ''NEW LOCATION FOR CACHED SCRIPTS
  ''"cscript.exe" //B //nologo "C:\Program Files\N-able Technologies\Windows Agent\Temp\Script\Task--2137133615\MSP_Filter.vbs" "local"
  ''SCRIPT OBJECT FOR PARSING XML
  set objXML = createobject("Microsoft.XMLDOM")
  ''FORCE SYNCHRONOUS
  objXML.async = false
  ''LOAD SCRIPT VERSIONS DATABASE XML
  if objXML.load("https://raw.githubusercontent.com/CW-Khristos/scripts/" & strBRCH & "/version.xml") then
    set colVER = objXML.documentelement
    for each objSCR in colVER.ChildNodes
      ''LOCATE ORIGINAL RUNNING SCRIPT
      if (ucase(objSCR.nodename) = ucase(strSCR)) then
        if (ucase(strSCR) <> "CHKAU.VBS") then                ''REQUESTING SCRIPT IS NOT 'CHKAU.VBS' , UPDATE CW SCRIPT , RE-EXECUTE WITH ORIGINAL 'ARGUMENTS'
          ''CHECK LATEST VERSION
          objOUT.write vbnewline & now & vbtab & " - CHKAU :  " & strSVER & " : GitHub - " & strBRCH & " : " & objSCR.text & vbnewline
          objLOG.write vbnewline & now & vbtab & " - CHKAU :  " & strSVER & " : GitHub - " & strBRCH & " : " & objSCR.text & vbnewline
          if (cint(objSCR.text) > cint(strSVER)) then
            objOUT.write vbnewline & now & vbtab & " - UPDATING " & objSCR.nodename & " : " & objSCR.text & vbnewline
            objLOG.write vbnewline & now & vbtab & " - UPDATING " & objSCR.nodename & " : " & objSCR.text & vbnewline
            ''DOWNLOAD LATEST VERSION OF ORIGINAL SCRIPT
            if (strDIR = vbnullstring) then
              strURL = "https://raw.githubusercontent.com/CW-Khristos/scripts/" & strREPO & "/" & strBRCH & "/" & strSCR
            elseif (strDIR <> vbnullstring) then
              strURL = "https://raw.githubusercontent.com/CW-Khristos/scripts/" & strREPO & "/" & strBRCH & "/" & strDIR & "/" & strSCR
            end if
            call FILEDL(strURL, "C:\IT\Scripts", strSCR)
            if (intRET <> 0) then                             ''ERROR DOWNLOADING REQUESTING SCRIPT UPDATE, 'ERRRET'=101
              call LOGERR(101)
              CHKAU = false
              exit for
            end if
            wscript.sleep 3000
            ''RUN LATEST VERSION OF ORIGINAL SCRIPT
            if (ubound(arrARG) > 0) then                      ''ARGUMENTS WERE PASSED
              strTMP = vbnullstring
              for x = 0 to (ubound(arrARG))
                if (arrARG(x) <> vbnullstring) then
                  strTMP = strTMP & " " & chr(34) & arrARG(x) & chr(34)
                end if
              next
              objOUT.write vbnewline & now & vbtab & " - RE-EXECUTING " & objSCR.nodename & " : " & objSCR.text & vbnewline
              objLOG.write vbnewline & now & vbtab & " - RE-EXECUTING  " & objSCR.nodename & " : " & objSCR.text & vbnewline
              intRET = objWSH.run("cmd.exe /C " & chr(34) & "cscript.exe //nologo " & chr(34) & "C:\IT\Scripts\" & strSCR & chr(34) & strTMP & chr(34), 0, true)
              if (intRET = 0) then                            ''NO ERROR RETURNED
                CHKAU = true
              end if
            elseif (ubound(arrARG) = 0) then                  ''NO ARGUMENTS WERE PASSED
              objOUT.write vbnewline & now & vbtab & " - RE-EXECUTING  " & objSCR.nodename & " : " & objSCR.text & vbnewline
              objLOG.write vbnewline & now & vbtab & " - RE-EXECUTING  " & objSCR.nodename & " : " & objSCR.text & vbnewline
              intRET = objWSH.run("cmd.exe /C " & chr(34) & "cscript.exe //nologo " & chr(34) & "C:\IT\Scripts\" & strSCR & chr(34) & chr(34), 0, true)
              if (intRET = 0) then                            ''NO ERROR RETURNED
                CHKAU = true
              end if
            end if
            if (intRET <> 0) then                             ''ERROR EXECUTING REQUESTING SCRIPT, 'ERRRET'=102
              call LOGERR(102)
              CHKAU = false
            end if
            ''END SCRIPT
            'call CLEANUP()
          elseif (cint(objSCR.text) <= cint(strSVER)) then    ''NO UPDATE AVAILABLE, 'ERRRET'=103
            call LOGERR(103)
            CHKAU = false
          end if
          exit for
        elseif (ucase(strSCR) = "CHKAU.VBS") then             ''REQUESTING SCRIPT IS 'CHKAU.VBS', UPDATE 'CHKAU.VBS' , RE-EXECUTE WITH ORIGINAL 'ARGUMENTS'
          ''CHECK LATEST VERSION
          objOUT.write vbnewline & now & vbtab & " - CHKAU :  " & strSVER & " : GitHub - " & strBRCH & " : " & objSCR.text & vbnewline
          objLOG.write vbnewline & now & vbtab & " - CHKAU :  " & strSVER & " : GitHub - " & strBRCH & " : " & objSCR.text & vbnewline
          if (cint(objSCR.text) > cint(strSVER)) then
            objOUT.write vbnewline & now & vbtab & " - UPDATING " & objSCR.nodename & " : " & objSCR.text & vbnewline
            objLOG.write vbnewline & now & vbtab & " - UPDATING " & objSCR.nodename & " : " & objSCR.text & vbnewline
            ''DOWNLOAD LATEST VERSION OF ORIGINAL SCRIPT
            if (strDIR = vbnullstring) then
              strURL = "https://raw.githubusercontent.com/CW-Khristos/scripts/" & strREPO & "/" & strBRCH & "/" & strSCR
            elseif (strDIR <> vbnullstring) then
              strURL = "https://raw.githubusercontent.com/CW-Khristos/scripts/" & strREPO & "/" & strBRCH & "/" & strDIR & "/" & strSCR
            end if
            call FILEDL(strURL, "C:\IT\Scripts", strSCR)
            if (errRET <> 0) then                             ''ERROR CHKAU SCRIPT UPDATE, 'ERRRET'=104
              call LOGERR(104)
              blnCHKAU = false
              exit for
            end if
            ''RUN LATEST VERSION OF ORIGINAL SCRIPT
            if (ubound(arrARG) > 0) then                      ''ARGUMENTS WERE PASSED
              strTMP = vbnullstring
              for x = 0 to (ubound(arrARG))
                if (arrARG(x) <> vbnullstring) then
                  strTMP = strTMP & " " & chr(34) & arrARG(x) & chr(34)
                end if
              next
              objOUT.write vbnewline & now & vbtab & " - RE-EXECUTING " & objSCR.nodename & " : " & objSCR.text & vbnewline
              objLOG.write vbnewline & now & vbtab & " - RE-EXECUTING  " & objSCR.nodename & " : " & objSCR.text & vbnewline
              intRET = objWSH.run("cmd.exe /C " & chr(34) & "cscript.exe //nologo " & chr(34) & "C:\IT\Scripts\" & strSCR & chr(34) & strTMP & chr(34), 0, false)
              if (intRET = 0) then
                CHKAU = true
              end if
            elseif (wscript.arguments.count = 0) then         ''NO ARGUMENTS WERE PASSED
              objOUT.write vbnewline & now & vbtab & " - RE-EXECUTING  " & objSCR.nodename & " : " & objSCR.text & vbnewline
              objLOG.write vbnewline & now & vbtab & " - RE-EXECUTING  " & objSCR.nodename & " : " & objSCR.text & vbnewline
              intRET = objWSH.run("cmd.exe /C " & chr(34) & "cscript.exe //nologo " & chr(34) & "C:\IT\Scripts\" & strSCR & chr(34) & chr(34), 0, false)
              if (intRET = 0) then
                CHKAU = true
              end if
            end if
            if (err.number <> 0) then                         ''ERROR EXECUTING UPDATED CHKAU SCRIPT, 'ERRRET'=105
              call LOGERR(105)
              blnCHKAU = false
            end if
            ''END SCRIPT
            'call CLEANUP()
          elseif (cint(objSCR.text) <= cint(strSVER)) then    ''NO UPDATE AVAILABLE, 'ERRRET'=106
            call LOGERR(106)
            CHKAU = false
          end if
          exit for
        end if
      end if
    next
  else
    call LOGERR(10)
    objOUT.write vbnewline & now & vbtab & " - CHKAU : XML ERROR" & vbnewline
    objLOG.write vbnewline & now & vbtab & " - CHKAU : XML ERROR" & vbnewline
  end if
  set colVER = nothing
  set objXML = nothing
  if (err.number <> 0) then                                   ''ERROR RETURNED DURING UPDATE CHECK , 'ERRRET'=10
    call LOGERR(10)
    CHKAU = false
  end if
end function

''SUB-ROUTINES
sub FILEDL(strURL, strDL, strFILE)                            ''CALL HOOK TO DOWNLOAD FILE FROM URL , 'ERRRET'=11
  strSAV = vbnullstring
  ''SET DOWNLOAD PATH
  strSAV = strDL & "\" & strFILE
  objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & " - HTTPDOWNLOAD-------------DOWNLOAD : " & strURL & " : SAVE AS :  " & strSAV
  objLOG.write vbnewline & vbnewline & now & vbtab & vbtab & " - HTTPDOWNLOAD-------------DOWNLOAD : " & strURL & " : SAVE AS :  " & strSAV
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
    objOUT.write vbnewline & vbnewline & now & vbtab & " - DOWNLOAD : " & strSAV & " : SUCCESSFUL"
    objLOG.write vbnewline & vbnewline & now & vbtab & " - DOWNLOAD : " & strSAV & " : SUCCESSFUL"
  end if
	set objHTTP = nothing
  if ((err.number <> 0) and (err.number <> 58)) then          ''ERROR RETURNED DURING UPDATE CHECK , 'ERRRET'=11
    call LOGERR(11)
  end if
end sub

sub HOOK(strCMD)                                              ''CALL HOOK TO MONITOR OUTPUT OF CALLED COMMAND , 'ERRRET'=12
  on error resume next
  objOUT.write vbnewline & now & vbtab & vbtab & " - EXECUTING : HOOK" '& strCMD
  objLOG.write vbnewline & now & vbtab & vbtab & " - EXECUTING : HOOK" '& strCMD
  set objHOOK = objWSH.exec(strCMD)
  while (not objHOOK.stdout.atendofstream)
		strIN = objHOOK.stdout.readline
		if (strIN <> vbnullstring) then
			objOUT.write vbnewline & now & vbtab & vbtab & strIN 
			objLOG.write vbnewline & now & vbtab & vbtab & strIN 
		end if
	wend
	wscript.sleep 10
  strIN = objHOOK.stdout.readall
  if (strIN <> vbnullstring) then
    objOUT.write vbnewline & now & vbtab & vbtab & strIN 
    objLOG.write vbnewline & now & vbtab & vbtab & strIN 
  end if
  set objHOOK = nothing
  if (err.number <> 0) then                                   ''ERROR RETURNED , 'ERRRET'=12
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
  select case intSTG
    case 1                                                    ''NOT ENOUGH ARGUMENTS , 'ERRRET'=1
      objOUT.write vbnewline & vbnewline & now & vbtab & " - NOT ENOUGH ARGUMENTS PASSED"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - NOT ENOUGH ARGUMENTS PASSED"
    case 3                                                    ''CHKAU - UPDATE SUCCESSFUL , 'ERRRET'=3
      objOUT.write vbnewline & vbnewline & now & vbtab & " - CHKAU UPDATED - RE-EXECUTED : " & strSCR & " " & strARG
      objLOG.write vbnewline & vbnewline & now & vbtab & " - CHKAU UPDATED - RE-EXECUTED : " & strSCR & " " & strARG
    case 4                                                    ''CHKAU - NO UPDATE / UPDATE FAILED , 'ERRRET'=4
      objOUT.write vbnewline & vbnewline & now & vbtab & " - CHKAU NO UPDATE - EXITING : " & strSCR & " " & strARG
      objLOG.write vbnewline & vbnewline & now & vbtab & " - CHKAU NO UPDATE - EXITING : " & strSCR & " " & strARG
    case 11                                                   ''CHKAU - FILE DOWNLOAD FAILED , 'ERRRET'=11
      objOUT.write vbnewline & vbnewline & now & vbtab & " - DOWNLOAD : " & strSAV & " : FAILED"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - DOWNLOAD : " & strSAV & " : FAILED"
    case 12                                                   ''CHKAU - CALL HOOK('STRCMD') FAILED , 'ERRRET'=12
      objOUT.write vbnewline & vbnewline & now & vbtab & " - CALL HOOK('STRCMD') : " & strCMD & " : FAILED"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - CALL HOOK('STRCMD') : " & strCMD & " : FAILED"
    case 101                                                  ''CHKAU - REQUESTING SCRIPT DOWNLOAD FAILED , 'ERRRET'=101
      objOUT.write vbnewline & vbnewline & now & vbtab & " - UPDATE DOWNLOAD : " & strSCR & " : FAILED"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - UPDATE DOWNLOAD : " & strSCR & " : FAILED"
    case 102                                                  ''CHKAU - REQUESTING SCRIPT RE-EXECUTION FAILED , 'ERRRET'=102
      objOUT.write vbnewline & vbnewline & now & vbtab & " - RE-EXECUTE : " & strSCR & " : FAILED"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - RE-EXECUTE : " & strSCR & " : FAILED"
    case 103                                                  ''CHKAU - NO UPDATE FOR REQUESTING SCRIPT , 'ERRRET'=103
      objOUT.write vbnewline & vbnewline & now & vbtab & " - UPDATE DOWNLOAD : NO UPDATE AVAILABLE : " & strSCR & " : FAILED"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - UPDATE DOWNLOAD : NO UPDATE AVAILABLE : " & strSCR & " : FAILED"
    case 104                                                  ''CHKAU - CHKAU SCRIPT DOWNLOAD FAILED , 'ERRRET'=104
      objOUT.write vbnewline & vbnewline & now & vbtab & " - UPDATE DOWNLOAD : " & strSCR & " : FAILED"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - UPDATE DOWNLOAD : " & strSCR & " : FAILED"
    case 105                                                  ''CHKAU - UPDATED CHKAU SCRIPT RE-EXECUTION FAILED , 'ERRRET'=105
      objOUT.write vbnewline & vbnewline & now & vbtab & " - RE-EXECUTE : " & strSCR & " : FAILED"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - RE-EXECUTE : " & strSCR & " : FAILED"
    case 106                                                  ''CHKAU - NO UPDATE FOR CHKAU SCRIPT , 'ERRRET'=106
      objOUT.write vbnewline & vbnewline & now & vbtab & " - UPDATE DOWNLOAD : NO UPDATE AVAILABLE : " & strSCR & " : FAILED"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - UPDATE DOWNLOAD : NO UPDATE AVAILABLE : " & strSCR & " : FAILED"
  end select
end sub

sub CLEANUP()                                                 ''SCRIPT CLEANUP
  on error resume next
  if (errRET = 0) then         															  ''CHKAU COMPLETED SUCCESSFULLY
    objOUT.write vbnewline & vbnewline & now & vbtab & " - CHKAU SUCCESSFUL : " & errRET & " : " & now
    objLOG.write vbnewline & vbnewline & now & vbtab & " - CHKAU SUCCESSFUL : " & errRET & " : " & now
    err.clear
  elseif (errRET = 3) then    															  ''CHKAU SUCCESSFUL; RE-EXECUTED REQUESTING SCRIPT
    objOUT.write vbnewline & vbnewline & now & vbtab & " - CHKAU SUCCESSFUL : " & errRET & " : " & now
    objLOG.write vbnewline & vbnewline & now & vbtab & " - CHKAU SUCCESSFUL : " & errRET & " : " & now
    ''RAISE CUSTOMIZED ERROR CODE, ERROR CODE WILL BE DEFINE RESTOP NUMBER INDICATING WHICH SECTION FAILED
    call err.raise(vbObjectError + errRET, "CHKAU", "SUCCESSFUL")
  elseif (errRET = 4) then    															  ''CHKAU SUCCESSFUL; NO UPDATE
    objOUT.write vbnewline & vbnewline & now & vbtab & " - CHKAU SUCCESSFUL : " & errRET & " : " & now
    objLOG.write vbnewline & vbnewline & now & vbtab & " - CHKAU SUCCESSFUL : " & errRET & " : " & now
    ''RAISE CUSTOMIZED ERROR CODE, ERROR CODE WILL BE DEFINE RESTOP NUMBER INDICATING WHICH SECTION FAILED
    call err.raise(vbObjectError + errRET, "CHKAU", "SUCCESSFUL")
  elseif (errRET <> 0) then    															  ''CHKAU FAILED
    objOUT.write vbnewline & vbnewline & now & vbtab & " - CHKAU FAILURE : " & errRET & " : " & now
    objLOG.write vbnewline & vbnewline & now & vbtab & " - CHKAU FAILURE : " & errRET & " : " & now
    ''RAISE CUSTOMIZED ERROR CODE, ERROR CODE WILL BE DEFINE RESTOP NUMBER INDICATING WHICH SECTION FAILED
    call err.raise(vbObjectError + errRET, "CHKAU", "FAILURE")
  end if
  objOUT.write vbnewline & now & " - CHKAU COMPLETE" & vbnewline
  objLOG.write vbnewline & now & " - CHKAU COMPLETE" & vbnewline
  objLOG.close
  ''EMPTY OBJECTS
  erase arrARG
  set objLOG = nothing
  set objFSO = nothing
  set objWSH = nothing
  set objARG = nothing
  set objOUT = nothing
  set objIN = nothing
  ''END SCRIPT, RETURN ERROR NUMBER
  wscript.quit err.number
end sub