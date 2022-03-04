''MD5.VBS
''DESIGNED TO AUTOMATE DOWNLOAD AND EXECUTION OF MD5 TOOL TO PRODUCE MD5 FOR PASSED FILE
''WRITTEN BY : CJ BLEDSOE / CJ<@>THECOMPUTERWARRIORS.COM
on error resume next
''SCRIPT VARIABLES
dim errRET, strVER, strIN
''VARIABLES ACCEPTING PARAMETERS
dim strPATH
''SCRIPT OBJECTS
dim objIN, objOUT, objARG, objWSH, objFSO
dim objLOG, objHOOK, objEXEC, objHTTP, objXML
''VERSION FOR SCRIPT UPDATE, MD5.VBS, REF #2
strVER = 1
''DEFAULT SUCCESS
errRET = 0
''STDIN / STDOUT
set objIN = wscript.stdin
set objOUT = wscript.stdout
set objARG = wscript.arguments
''OBJECTS FOR LOCATING FOLDERS
set objWSH = createobject("wscript.shell")
Set objAPP = createobject("shell.application")
set objFSO = createobject("scripting.filesystemobject")
''PREPARE LOGFILE
if (objFSO.fileexists("C:\temp\MD5")) then               ''LOGFILE EXISTS
  objFSO.deletefile "C:\temp\MD5", true
  set objLOG = objFSO.createtextfile("C:\temp\MD5")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\MD5", 8)
else                                                          ''LOGFILE NEEDS TO BE CREATED
  set objLOG = objFSO.createtextfile("C:\temp\MD5")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\MD5", 8)
end if
''READ PASSED COMMANDLINE ARGUMENTS
if (wscript.arguments.count > 0) then                         ''ARGUMENTS WERE PASSED
  for x = 0 to (wscript.arguments.count - 1)
    objOUT.write vbnewline & now & vbtab & " - ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
    objLOG.write vbnewline & now & vbtab & " - ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
  next 
  if (wscript.arguments.count > 0) then                       ''REQUIRED ARGUMENTS PASSED
    strPATH = objARG.item(0)
  end if
else                                                          ''NO ARGUMENTS PASSED , END SCRIPT , 'ERRRET'=1
  call LOGERR(1)
  err.clear
end if

''------------
''BEGIN SCRIPT
if (errRET = 0) then
  objOUT.write vbnewline & vbnewline & now & vbtab & " - EXECUTING MD5"
  objLOG.write vbnewline & vbnewline & now & vbtab & " - EXECUTING MD5"
  ''AUTOMATIC UPDATE , 'ERRRET'=10 , MD5.VBS , REF #2
  call CHKAU()
  call FILEDL("https://github.com/CW-Khristos/scripts/raw/dev/MD5/md5.exe")
  if (objFSO.fileexists("c:\temp\md5.exe")) then
    call HOOK("c:\temp\md5.exe -l " & strPATH)
  else
    call LOGERR(2)
  end if
elseif (errRET <> 0) then
  call CLEANUP()
end if
''END SCRIPT
call CLEANUP()
''END SCRIPT
''------------

''SUB-ROUTINES
sub CHKAU()																					                                    ''CHECK FOR SCRIPT UPDATE, 'ERRRET'=10 , MD5.VBS , REF #2
  ''NO LONGER REQUIRED WITH NCENTRAL 2021; SCRIPTS ARE PLACED IN INDIVIDUAL 'TASK' DIRECTORIES
  ''REMOVE WINDOWS AGENT CACHED VERSION OF SCRIPT
  'if (objFSO.fileexists("C:\Program Files (x86)\N-Able Technologies\Windows Agent\cache\" & wscript.scriptname)) then
  '  objFSO.deletefile "C:\Program Files (x86)\N-Able Technologies\Windows Agent\cache\" & wscript.scriptname, true
  'end if
  ''ADD WINHTTP SECURE CHANNEL TLS REGISTRY KEYS
  call HOOK("reg add " & chr(34) & "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp" & chr(34) & _
    " /f /v DefaultSecureProtocols /t REG_DWORD /d 0x00000A00 /reg:32")
  call HOOK("reg add " & chr(34) & "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp" & chr(34) & _
    " /f /v DefaultSecureProtocols /t REG_DWORD /d 0x00000A00 /reg:64")
  ''SCRIPT OBJECT FOR PARSING XML
  set objXML = createobject("Microsoft.XMLDOM")
  ''FORCE SYNCHRONOUS
  objXML.async = false
  ''LOAD SCRIPT VERSIONS DATABASE XML
  if objXML.load("https://github.com/CW-Khristos/scripts/raw/dev/version.xml") then
    set colVER = objXML.documentelement
    for each objSCR in colVER.ChildNodes
      ''LOCATE CURRENTLY RUNNING SCRIPT
      if (lcase(objSCR.nodename) = lcase(wscript.scriptname)) then
        ''CHECK LATEST VERSION
        objOUT.write vbnewline & now & vbtab & " - MD5 :  " & strVER & " : GitHub : " & objSCR.text & vbnewline
        objLOG.write vbnewline & now & vbtab & " - MD5 :  " & strVER & " : GitHub : " & objSCR.text & vbnewline
        if (cint(objSCR.text) > cint(strVER)) then
          objOUT.write vbnewline & now & " - UPDATING " & objSCR.nodename & " : " & objSCR.text & vbnewline
          objLOG.write vbnewline & now & " - UPDATING " & objSCR.nodename & " : " & objSCR.text & vbnewline
          ''DOWNLOAD LATEST VERSION OF SCRIPT
          call FILEDL("https://github.com/CW-Khristos/scripts/raw/dev/MD5.vbs", wscript.scriptname)
          ''RUN LATEST VERSION
          if (wscript.arguments.count > 0) then                                         ''ARGUMENTS WERE PASSED
            for x = 0 to (wscript.arguments.count - 1)
              strTMP = strTMP & " " & chr(34) & objARG.item(x) & chr(34)
            next
            objOUT.write vbnewline & now & vbtab & " - RE-EXECUTING  " & objSCR.nodename & " : " & objSCR.text & vbnewline
            objLOG.write vbnewline & now & vbtab & " - RE-EXECUTING  " & objSCR.nodename & " : " & objSCR.text & vbnewline
            objWSH.run "cscript.exe //nologo " & chr(34) & "c:\temp\" & wscript.scriptname & chr(34) & strTMP, 0, false
          elseif (wscript.arguments.count = 0) then                                     ''NO ARGUMENTS WERE PASSED
            objOUT.write vbnewline & now & vbtab & " - RE-EXECUTING  " & objSCR.nodename & " : " & objSCR.text & vbnewline
            objLOG.write vbnewline & now & vbtab & " - RE-EXECUTING  " & objSCR.nodename & " : " & objSCR.text & vbnewline
            objWSH.run "cscript.exe //nologo " & chr(34) & "c:\temp\" & wscript.scriptname & chr(34), 0, false
          end if
          ''END SCRIPT
          call CLEANUP()
        end if
      end if
    next
  end if
  set colVER = nothing
  set objXML = nothing
  if (err.number <> 0) then                                                             ''ERROR RETURNED DURING UPDATE CHECK , 'ERRRET'=10
    call LOGERR(10)
  end if
end sub

sub FILEDL(strURL, strFILE)                   			                                    ''CALL HOOK TO DOWNLOAD FILE FROM URL , 'ERRRET'=11
  strSAV = vbnullstring
  ''SET DOWNLOAD PATH
  strSAV = "C:\temp\" & strFILE
  objOUT.write vbnewline & now & vbtab & vbtab & "HTTPDOWNLOAD-------------DOWNLOAD : " & strURL & " : SAVE AS :  " & strSAV
  objLOG.write vbnewline & now & vbtab & vbtab & "HTTPDOWNLOAD-------------DOWNLOAD : " & strURL & " : SAVE AS :  " & strSAV
  ''CREATE HTTP OBJECT
  set objHTTP = createobject( "WinHttp.WinHttpRequest.5.1" )
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
  if (err.number <> 0) then                                                             ''ERROR RETURNED , 'ERRRET'=11
    call LOGERR(11)
  end if
end sub

sub HOOK(strCMD)                                                                        ''CALL HOOK TO MONITOR OUTPUT OF CALLED COMMAND , 'ERRRET'=12
  on error resume next
  set objHOOK = objWSH.exec(strCMD)
  if (instr(1, strCMD, "takeown /F ") = 0) then                                         ''SUPPRESS 'TAKEOWN' SUCCESS MESSAGES
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
  if (err.number <> 0) then                                                             ''ERROR RETURNED , 'ERRRET'=12
    call LOGERR(12)
  end if
end sub

sub LOGERR(intSTG)                                                                      ''CALL HOOK TO LOG AND SET ERRORS
  if (err.number <> 0) then
    objOUT.write vbnewline & now & vbtab & vbtab & vbtab & err.number & vbtab & err.description & vbnewline
    objLOG.write vbnewline & now & vbtab & vbtab & vbtab & err.number & vbtab & err.description & vbnewline
    errRET = intSTG
    err.clear
  end if
  select case intSTG
    case 1                                                                              '' 'ERRRET'=1 - NOT ENOUGH ARGUMENTS
      objOUT.write vbnewline & vbnewline & now & vbtab & " - NOT ENOUGH ARGUMENTS"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - NOT ENOUGH ARGUMENTS"
  end select
end sub

sub CLEANUP()                                                                           ''SCRIPT CLEANUP
  if (errRET = 0) then                                                                  ''SCRIPT COMPLETED SUCCESSFULLY
    objOUT.write vbnewline & vbnewline & now & vbtab & " - MD5 COMPLETE : " & errRET & " : " & now
    objLOG.write vbnewline & vbnewline & now & vbtab & " - MD5 COMPLETE : " & errRET & " : " & now
    err.clear
  elseif (errRET <> 0) then                                                             ''SCRIPT FAILED
    objOUT.write vbnewline & vbnewline & now & vbtab & " - MD5 FAILURE : " & errRET & " : " & now
    objLOG.write vbnewline & vbnewline & now & vbtab & " - MD5 FAILURE : " & errRET & " : " & now
    ''RAISE CUSTOMIZED ERROR CODE, ERROR CODE WILL BE DEFINED RESTOP NUMBER INDICATING WHICH SECTION FAILED
    call err.raise(vbObjectError + errRET, "MD5", "FAILURE")
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