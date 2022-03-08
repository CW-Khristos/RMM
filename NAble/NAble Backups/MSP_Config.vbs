''MSP_CONFIG.VBS
''DESIGNED TO UPDATE THE MSP BACKUP 'CONFIG.INI' FILE IN AN AUTOMATED FASHION
''ACCEPTS 4 PARAMETERS , REQUIRES 3 PARAMETER
''REQUIRED PARAMETER : 'STRHDR' , STRING TO IDENTIFY SECTION OF 'CONFIG.INI' FILE TO MODIFY
''REQUIRED PARAMETER : 'STRCHG' , STRING TO SET INTERNAL STRING TO INJECT INTO 'CONFIG.INI' FILE
''REQUIRED PARAMETER : 'STRVAL' , STRING TO SET INTERNAL STRING VALUE TO INJECT INTO 'CONFIG.INI' FILE
''OPTIONAL PARAMETER : 'BLNFORCE' , BOLLEAN TO FLAG TO FORCE MODIFY VALUE INTO 'CONFIG.INI' FILE
''WRITTEN BY : CJ BLEDSOE / CBLEDSOE<@>IPMCOMPUTERS.COM
''SCRIPT VARIABLES
dim errRET, strVER, strIN
dim blnHDR, blnINJ, blnMOD
dim strREPO, strBRCH, strDIR
''VARIABLES ACCEPTING PARAMETERS
dim arrIN, strSAV, strCMD
dim strHDR, strCHG, strVAL, blnFORCE
''SCRIPT OBJECTS
dim objFSO, objLOG, objCFG
dim objIN, objOUT, objARG, objWSH
''SET 'ERRRET' CODE
errRET = 0
''VERSION FOR SCRIPT UPDATE , MSP_CONFIG.VBS , REF #2 , FIXES #25
strVER = 8
strREPO = "scripts"
strBRCH = "master"
strDIR = "MSP Backups"
''SET 'BLNHDR' FLAG
blnHDR = false
''SET 'BLNINJ' FLAG
blnINJ = false
''SET 'BLNMOD' FLAG
blnMOD = true
''SET 'BLNFORCE' FLAG
blnFORCE = false
''STDIN / STDOUT
set objIN = wscript.stdin
set objOUT = wscript.stdout
set objARG = wscript.arguments
''OBJECTS FOR LOCATING FOLDERS
strTMP = "C:\temp\"
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
''CHECK EXECUTION METHOD OF SCRIPT
strIN = lcase(mid(wscript.fullname, instrrev(wscript.fullname, "\") + 1))
if (strIN <> "cscript.exe") Then
  objOUT.write vbnewline & "SCRIPT LAUNCHED VIA EXPLORER, EXECUTING SCRIPT VIA CSCRIPT..."
  objWSH.run "cscript.exe //nologo " & chr(34) & Wscript.ScriptFullName & chr(34)
  wscript.quit
end if
''PREPARE LOGFILE
if (objFSO.fileexists("C:\temp\MSP_CONFIG")) then                     ''LOGFILE EXISTS
  objFSO.deletefile "C:\temp\MSP_CONFIG", true
  set objLOG = objFSO.createtextfile("C:\temp\MSP_CONFIG")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\MSP_CONFIG", 8)
else                                                                  ''LOGFILE NEEDS TO BE CREATED
  set objLOG = objFSO.createtextfile("C:\temp\MSP_CONFIG")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\MSP_CONFIG", 8)
end if
''MSP BACKUP MANAGER CONFIG.INI FILE
if (objFSO.fileexists("C:\Program Files\Backup Manager\config.ini")) then
  set objCFG = objFSO.opentextfile("C:\Program Files\Backup Manager\config.ini")
elseif (not objFSO.fileexists("C:\Program Files\Backup Manager\config.ini")) then
  call LOGERR(1)                                                      ''CONFIG.INI NOT PRESENT, END SCRIPT, 'ERRRET'=1
end if
''READ PASSED COMMANDLINE ARGUMENTS
if (wscript.arguments.count <= 2) then                                ''NO ARGUMENTS PASSED, END SCRIPT, 'ERRRET'=2
  call LOGERR(2)
elseif (wscript.arguments.count > 0) then                             ''ARGUMENTS WERE PASSED
  for x = 0 to (wscript.arguments.count - 1)
    objOUT.write vbnewline & now & vbtab & " - ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
    objLOG.write vbnewline & now & vbtab & " - ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
  next 
  strHDR = objARG.item(0)                                             ''SET STRING 'STRHDR', TARGET 'HEADER'
  if (wscript.arguments.count > 2) then
    strCHG = objARG.item(1)                                           ''SET STRING 'STRCHG', TARGET STRING TO INSERT
    strVAL = objARG.item(2)                                           ''SET STRING 'STRVAL', TARGET VALUE TO INSERT
    if (wscript.arguments.count > 3) then
      blnFORCE = objARG.item(3)                                       ''SET BOOLEAN 'BLNFORCE', FLAG TO FORCE MODIFY VALUE
    end if
  elseif (wscript.arguments.count <= 2) then                          ''NO ARGUMENTS PASSED, END SCRIPT, 'ERRRET'=2
    call LOGERR(2) 
  end if
end if

''------------
''BEGIN SCRIPT
if (errRET = 0) then
  objOUT.write vbnewline & vbnewline & now & " - EXECUTING MSP_CONFIG" & vbnewline
  objLOG.write vbnewline & vbnewline & now & " - EXECUTING MSP_CONFIG" & vbnewline
  ''AUTOMATIC UPDATE, MSP_CONFIG.VBS, REF #2 , REF #69 , REF #68 , FIXES #25
  objOUT.write vbnewline & now & vbtab & vbtab & " - CHECKING FOR UPDATE : MSP_CONFIG : " & strVER
  objLOG.write vbnewline & now & vbtab & vbtab & " - CHECKING FOR UPDATE : MSP_CONFIG : " & strVER
  ''DOWNLOAD CHKAU.VBS SCRIPT, REF #2 , REF #69 , REF #68
  call FILEDL("https://raw.githubusercontent.com/CW-Khristos/scripts/master/chkAU.vbs", "C:\IT\Scripts", "chkAU.vbs")
  ''EXECUTE CHKAU.VBS SCRIPT, REF #69
  intRET = objWSH.run ("cmd.exe /C " & chr(34) & "cscript.exe " & chr(34) & "C:\temp\chkAU.vbs" & chr(34) & " " & _
    chr(34) & strREPO & chr(34) & " " & chr(34) & strBRCH & chr(34) & " " & chr(34) & strDIR & chr(34) & " " & _
    chr(34) & wscript.scriptname & chr(34) & " " & chr(34) & strVER & chr(34) & " " & _
    chr(34) & strHDR & "|" & strCHG & "|" & strVAL & "|" & blnFORCE & chr(34) & chr(34), 0, true)
  ''CHKAU RETURNED - NO UPDATE FOUND , REF #2 , REF #69 , REF #68
  objOUT.write vbnewline & "errRET='" & intRET & "'"
  objLOG.write vbnewline & "errRET='" & intRET & "'"
  intRET = (intRET - vbObjectError)
  objOUT.write vbnewline & "errRET='" & intRET & "'"
  objLOG.write vbnewline & "errRET='" & intRET & "'"
  if ((intRET = 4) or (intRET = 10) or (intRET = 11) or (intRET = 1) or (intRET = 2147221505) or (intRET = 2147221517)) then
    objOUT.write vbnewline & now & vbtab & vbtab & " - NO UPDATE FOUND : MSP_CONFIG : " & strVER
    objLOG.write vbnewline & now & vbtab & vbtab & " - NO UPDATE FOUND : MSP_CONFIG : " & strVER
    ''PARSE CONFIG.INI FILE
    objOUT.write vbnewline & now & vbtab & " - CURRENT CONFIG.INI"
    objLOG.write vbnewline & now & vbtab & " - CURRENT CONFIG.INI"
    strIN = objCFG.readall
    arrIN = split(strIN, vbnewline)
    for intIN = 0 to ubound(arrIN)                                        ''CHECK CONFIG.INI LINE BY LINE
      objOUT.write vbnewline & vbtab & vbtab & arrIN(intIN)
      objLOG.write vbnewline & vbtab & vbtab & arrIN(intIN)
      if (arrIN(intIN) = strHDR) then                                     ''FOUND SPECIFIED 'HEADER' IN CONFIG.INI
        blnHDR = true
      end if
      if (instr(1, arrIN(intIN), strCHG)) then                            ''STRING TO INJECT ALREADY IN CONFIG.INI
        blnINJ = false
        blnMOD = false
        if (strVAL = split(arrIN(intIN), "=")(1)) then                    ''PASSED VALUE 'STRVAL' MATCHES INTERNAL STRING VALUE
          blnINJ = false
          blnMOD = false
        elseif (strVAL <> split(arrIN(intIN), "=")(1)) then               ''PASSED VALUE 'STRVAL' DOES NOT MATCH INTERNAL STRING VALUE
          if (not blnFORCE) then
            blnINJ = false
            blnMOD = false
          elseif (blnFORCE) then
            blnINJ = true
            blnMOD = false
            arrIN(intIN) = strCHG & "=" & strVAL
            'exit for
          end if  
        end if
        'exit for
      end if
      if ((blnHDR) and (blnMOD) and (arrIN(intIN) = vbnullstring)) then   ''STRING TO INJECT NOT FOUND, INJECT UNDER CURRENT 'HEADER'
        blnINJ = true
        blnHDR = false
        arrIN(intIN) = strCHG & "=" & strVAL & vbCrlf
      end if
    next
    objCFG.close
    set objCFG = nothing
    strIN = vbnullstring
    ''REPLACE CONFIG.INI FILE
    if (blnINJ) then                                                      ''SPECIFIED 'HEADER' FOUND, 'STRING', AND 'STRVAL'
      objOUT.write vbnewline & vbnewline & now & vbtab & " - NEW CONFIG.INI"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - NEW CONFIG.INI"
      set objCFG = objFSO.opentextfile("C:\Program Files\Backup Manager\config.ini", 2)
      for intIN = 0 to ubound(arrIN)                                      ''RE-BUILD CONFIG.INI LINE BY LINE
        if (arrIN(intIN) <> vbnullstring) then
          if ((intIN = 0) or (instr(1, arrIN(intIN), "[") = 0)) then
            strIN = strIN & arrIN(intIN) & vbCrlf
            objOUT.write vbnewline & vbtab & vbtab & arrIN(intIN)
            objLOG.write vbnewline & vbtab & vbtab & arrIN(intIN)
          elseif ((intIN > 0) and (instr(1, arrIN(intIN), "["))) then
            strIN = strIN & vbCrlf & arrIN(intIN) & vbCrlf
            objOUT.write vbnewline & vbtab & vbtab & arrIN(intIN)
            objLOG.write vbnewline & vbtab & vbtab & arrIN(intIN)
          end if
        end if
      next
      objCFG.write strIN
      objCFG.close
      set objCFG = nothing
    end if
    if ((not blnHDR) and (blnFORCE)) then                                 ''SPECIFIED 'HEADER' NOT FOUND, INJECT 'HEADER', 'STRING', AND 'STRVAL'
      objOUT.write vbnewline & vbnewline & now & vbtab & " - NEW CONFIG.INI"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - NEW CONFIG.INI"
      set objCFG = objFSO.opentextfile("C:\Program Files\Backup Manager\config.ini", 2)
      for intIN = 0 to ubound(arrIN)                                      ''RE-BUILD CONFIG.INI LINE BY LINE
        if (arrIN(intIN) <> vbnullstring) then
          if ((intIN = 0) or (instr(1, arrIN(intIN), "[") = 0)) then
            strIN = strIN & arrIN(intIN) & vbCrlf
            objOUT.write vbnewline & vbtab & vbtab & arrIN(intIN)
            objLOG.write vbnewline & vbtab & vbtab & arrIN(intIN)
          elseif ((intIN > 0) and (instr(1, arrIN(intIN), "["))) then
            strIN = strIN & vbCrlf & arrIN(intIN) & vbCrlf
            objOUT.write vbnewline & vbtab & vbtab & arrIN(intIN)
            objLOG.write vbnewline & vbtab & vbtab & arrIN(intIN)
          end if
        end if
      next
      strIN = strIN & vbCrlf & strHDR & vbCrlf & strCHG & "=" & strVAL & vbCrlf
      objOUT.write vbnewline & vbtab & vbtab & strHDR & vbCrlf & strCHG & "=" & strVAL & vbCrlf
      objLOG.write vbnewline & vbtab & vbtab & strHDR & vbCrlf & strCHG & "=" & strVAL & vbCrlf
      objCFG.write strIN
      objCFG.close
      set objCFG = nothing
    end if
  elseif (intRET <> 0) then
    call LOGERR(intRET)
  end if
elseif (errRET <> 0) then
  call LOGERR(errRET)
end if
''CLEANUP
call CLEANUP()
''END SCRIPT
''------------

''SUB-ROUTINES
sub FILEDL(strURL, strDL, strFILE)                                    ''CALL HOOK TO DOWNLOAD FILE FROM URL , 'ERRRET'=11
  strSAV = vbnullstring
  ''SET DOWNLOAD PATH
  strSAV = strDL & "\" & strFILE
  objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "HTTPDOWNLOAD-------------DOWNLOAD : " & strURL & " : SAVE AS :  " & strSAV
  objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "HTTPDOWNLOAD-------------DOWNLOAD : " & strURL & " : SAVE AS :  " & strSAV
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
  if ((err.number <> 0) and (err.number <> 58)) then                  ''ERROR RETURNED DURING DOWNLOAD , 'ERRRET'=11
    call LOGERR(11)
  end if
end sub

sub HOOK(strCMD)                                                      ''CALL HOOK TO MONITOR OUTPUT OF CALLED COMMAND , 'ERRRET'=12
  on error resume next
  objOUT.write vbnewline & now & vbtab & vbtab & " - EXECUTING : HOOK(" & strCMD & ")"
  objLOG.write vbnewline & now & vbtab & vbtab & " - EXECUTING : HOOK(" & strCMD & ")"
  set objHOOK = objWSH.exec(strCMD)
  if (instr(1, strCMD, "takeown /F ") = 0) then                       ''SUPPRESS 'TAKEOWN' SUCCESS MESSAGES
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
  if (err.number <> 0) then                                           ''ERROR RETURNED DURING UPDATE CHECK , 'ERRRET'=12
    call LOGERR(12)
  end if
end sub

sub LOGERR(intSTG)                                                    ''CALL HOOK TO MONITOR OUTPUT OF CALLED COMMAND
  errRET = intSTG
  if (err.number <> 0) then
    objOUT.write vbnewline & now & vbtab & vbtab & vbtab & err.number & vbtab & err.description & vbnewline
    objLOG.write vbnewline & now & vbtab & vbtab & vbtab & err.number & vbtab & err.description & vbnewline
		err.clear
  end if
  ''CUSTOM ERROR CODES
  select case intSTG
    case 1                                                            '' 'ERRRET'=1 - CONFIG.INI NOT PRESENT, END SCRIPT, 'ERRRET'=1
      objOUT.write vbnewline & vbnewline & now & vbtab & " - MSP_CONFIG - CONFIG.INI NOT PRESENT, END SCRIPT"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - MSP_CONFIG - CONFIG.INI NOT PRESENT, END SCRIPT"
    case 2                                                            '' 'ERRRET'=2 - NOT ENOUGH ARGUMENTS
      objOUT.write vbnewline & vbnewline & now & vbtab & " - MSP_CONFIG - NO ARGUMENTS PASSED, END SCRIPT"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - MSP_CONFIG - NO ARGUMENTS PASSED, END SCRIPT"
    case 11                                                           ''MSP_CONFIG - CALL FILEDL() , 'ERRRET'=11
      objOUT.write vbnewline & vbnewline & now & vbtab & " - MSP_CONFIG - CALL FILEDL() : " & strSAV
      objLOG.write vbnewline & vbnewline & now & vbtab & " - MSP_CONFIG - CALL FILEDL() : " & strSAV
    case 12                                                           ''MSP_CONFIG - CALL HOOK() , 'ERRRET'=12
      objOUT.write vbnewline & vbnewline & now & vbtab & " - MSP_CONFIG - CALL HOOK('STRCMD') : " & strCMD & " : FAILED"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - MSP_CONFIG - CALL HOOK('STRCMD') : " & strCMD & " : FAILED"
  end select
end sub

sub CLEANUP()                                 			                  ''SCRIPT CLEANUP
  on error resume next
  if (errRET = 0) then         											                  ''MSP_CONFIG COMPLETED SUCCESSFULLY
    objOUT.write vbnewline & vbnewline & now & vbtab & "MSP_CONFIG SUCCESSFUL : " & now
    objLOG.write vbnewline & vbnewline & now & vbtab & "MSP_CONFIG SUCCESSFUL : " & now
    err.clear
  elseif (errRET <> 0) then    											                  ''MSP_CONFIG FAILED
    objOUT.write vbnewline & vbnewline & now & vbtab & "MSP_CONFIG FAILURE : " & now & " : " & errRET
    objLOG.write vbnewline & vbnewline & now & vbtab & "MSP_CONFIG FAILURE : " & now & " : " & errRET
    ''RAISE CUSTOMIZED ERROR CODE, ERROR CODE WILL BE DEFINE RESTOP NUMBER INDICATING WHICH SECTION FAILED
    call err.raise(vbObjectError + errRET, "MSP_CONFIG", "FAILURE")
  end if
  objOUT.write vbnewline & vbnewline & now & " - MSP_CONFIG COMPLETE" & vbnewline
  objLOG.write vbnewline & vbnewline & now & " - MSP_CONFIG COMPLETE" & vbnewline
  objLOG.close
  ''EMPTY OBJECTS
  set objCFG = nothing
  set objLOG = nothing
  set objFSO = nothing
  set objWSH = nothing
  set objARG = nothing
  set objOUT = nothing
  set objIN = nothing
  ''END SCRIPT, RETURN ERROR NUMBER
  wscript.quit err.number
end sub