''ACCTCLEAN.VBS
''DESIGNED TO AUTOMATE IDENTIFYING AND REMOVING ALL UNNECESSARY LOCAL USER ACCOUNTS FROM A TARGET DEVICE
''ACCEPTS 1 PARAMETER
''OPTIONAL PARAMETER : 'STRUSR' , STRING TO OF USER TO LEAVE INTACT
''WRITTEN BY : CJ BLEDSOE / CJ<@>THECOMPUTERWARRIORS.COM
on error resume next
''SCRIPT VARIABLES
dim errRET, strVER
dim strIN, strOUT, strSEL
''VARIABLES ACCEPTING PARAMETERS
dim strUSR
''SCRIPT OBJECTS
dim colUSR(), arrUSR(), arrFOL()
dim objIN, objOUT, objARG, objWSH, objFSO
dim objLOG, objEXEC, objHOOK, objSIN, objSOUT
''VERSION FOR SCRIPT UPDATE, ACCTCLEAN.VBS, REF #2 , FIXES #57
strVER = 2
''DEFAULT SUCCESS
errRET = 0
''STDIN / STDOUT
set objIN = wscript.stdin
set objOUT = wscript.stdout
set objARG = wscript.arguments
''OBJECTS FOR LOCATING FOLDERS
set objWSH = createobject("wscript.shell")
set objFSO = createobject("scripting.filesystemobject")
''PREPARE LOGFILE
if (objFSO.fileexists("C:\temp\AcctClean")) then              ''LOGFILE EXISTS
  objFSO.deletefile "C:\temp\AcctClean", true
  set objLOG = objFSO.createtextfile("C:\temp\AcctClean")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\AcctClean", 8)
else                                                        ''LOGFILE NEEDS TO BE CREATED
  set objLOG = objFSO.createtextfile("C:\temp\AcctClean")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\AcctClean", 8)
end if
''READ PASSED COMMANDLINE ARGUMENTS
if (wscript.arguments.count > 0) then                       ''ARGUMENTS WERE PASSED
  for x = 0 to (wscript.arguments.count - 1)
    objOUT.write vbnewline & now & vbtab & " - ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
    objLOG.write vbnewline & now & vbtab & " - ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
  next 
  if (wscript.arguments.count > 0) then                     ''REQUIRED ARGUMENTS PASSED
    strUSR = objARG.item(0)
    if (wscript.arguments.count > 1) then                   ''OPTIONAL ARGUMENTS PASSED
    end if
  end if
else                                                        ''NO ARGUMENTS PASSED , END SCRIPT , 'ERRRET'=1
  call LOGERR(1)
end if

''PROTECTED USER ACCOUNTS
redim arrUSR(14)
arrUSR(0) = "rmmtech"
arrUSR(1) = "admin"
arrUSR(2) = "administrator"
arrUSR(3) = "owner"
arrUSR(4) = "cloud"
arrUSR(6) = "Guest"
arrUSR(7) = "Public"
arrUSR(8) = "All Users"
arrUSR(9) = "__sbs_netsetup__"
arrUSR(10) = "Default"
arrUSR(11) = "Default User"
arrUSR(12) = "DefaultAccount"
arrUSR(13) = "WDAGUtilityAccount"
arrUSR(14) = "UpdatusUser"
''------------
''BEGIN SCRIPT
if (errRET <> 0) then
elseif (errRET = 0) then
  objOUT.write vbnewline & vbnewline & now & vbtab & " - EXECUTING ACCTCLEAN"
  objLOG.write vbnewline & vbnewline & now & vbtab & " - EXECUTING ACCTCLEAN"
  ''AUTOMATIC UPDATE , 'ERRRET'=10 , ACCTCLEAN.VBS , REF #2 , FIXES #57
  call CHKAU()
  ''GET ALL USERS , 'ERRRET'=2
  intUSR = 0
  objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & " - ENUMERATING USERNAMES, THIS MAY TAKE A FEW MOMENTS"
  objLOG.write vbnewline & vbnewline & now & vbtab & vbtab & " - ENUMERATING USERNAMES, THIS MAY TAKE A FEW MOMENTS"
  set objEXEC = objWSH.exec("wmic useraccount get name,sid /format:csv")
  while (not objEXEC.stdout.atendofstream)
    strIN = objEXEC.stdout.readline
    'objOUT.write vbnewline & now & vbtab & vbtab & strIN
    'objLOG.write vbnewline & now & vbtab & vbtab & strIN
    if ((trim(strIN) <> vbnullstring) and (instr(1, strIN, ","))) then
      if ((trim(split(strIN, ",")(1)) <> vbnullstring) and (trim(split(strIN, ",")(1)) <> "Name")) then
        redim preserve colUSR(intUSR + 1)
        colUSR(intUSR) = trim(split(strIN, ",")(1))
        intUSR = (intUSR + 1)
      end if
    end if
    if (err.number <> 0) then
      call LOGERR(2)
    end if
  wend
  set objEXEC = nothing
  err.clear
  ''VALIDATE COLLECTED USERNAMES
  intUSR = 0
  objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & " - COLLECTED USERNAMES"
  objLOG.write vbnewline & vbnewline & now & vbtab & vbtab & " - COLLECTED USERNAMES"
  for intUSR = 0 to ubound(colUSR)
    intCOL = 0
    blnFND = false
    if (colUSR(intUSR) <> vbnullstring) then
      ''ENUMERATRE THROUGH AND MAKE SURE THIS ISN'T ONE OF THE 'PROTECTED' USER ACCOUNTS
      for intCOL = 0 to ubound(arrUSR)
        blnFND = false
        ''ENUMERATED USER ACCOUNT MATCHES 'PRTOTECTED' USER ACCOUNT 'ARRUSR'
        if (lcase(colUSR(intUSR)) = lcase(arrUSR(intCOL))) then
          objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "PROTECTED : " & colUSR(intUSR)
          objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "PROTECTED : " & colUSR(intUSR)
          ''MARK 'PROTECTED'
          blnFND = true
          exit for
        end if
      next
      ''NO MATCH FOUND IN 'PROTECTED' USER ACCOUNTS 'ARRUSR'
      if (not blnFND) then
        ''A 'PROTECTED' USER ACCOUNT WAS PASSED TO 'STRUSR'
        if (strUSR <> vbnullstring) then
          ''FIND USER/S MATCHING PASSED 'STRUSR' TARGET USER
          ''HANDLE '\' IS PASSED TARGET USERNAME 'STRUSR'
          if (instr(1, strUSR, "\")) then
            ''MATCHES PASSED 'PROTECTED' USER 'STRUSR'
            if (instr(1, lcase(colUSR(intUSR)), lcase(split(strUSR, "\")(1)))) then
              objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "PROTECTED : " & colUSR(intUSR)
              objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "PROTECTED : " & colUSR(intUSR)
              ''MARK 'PROTECTED'
              blnFND = true        
            ''DOES NOT MATCH PASSED 'PROTECTED' USER 'STRUSR'
            elseif (instr(1, lcase(colUSR(intUSR)), lcase(split(strUSR, "\")(1))) = 0) then
              objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "TARGET FOR REMOVAL : " & colUSR(intUSR)
              objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "TARGET FOR REMOVAL : " & colUSR(intUSR)
              ''MARK FOR REMOVAL
              blnFND = false
            end if
          ''HANDLE WITHOUT '\' IN PASSED TARGET USERNAME 'STRUSR'
          elseif (instr(1, strUSR, "\") = 0) then
            ''MATCHES PASSED 'PROTECTED' USER 'STRUSR'
            if (instr(1, lcase(colUSR(intUSR)), lcase(strUSR))) then
              objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "PROTECTED : " & colUSR(intUSR)
              objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "PROTECTED : " & colUSR(intUSR)
              ''MARK 'PROTECTED'
              blnFND = true
            ''DOES NOT MATCH PASSED 'PROTECTED' USER 'STRUSR'
            elseif (instr(1, lcase(colUSR(intUSR)), lcase(strUSR)) = 0) then
              objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "TARGET FOR REMOVAL : " & colUSR(intUSR)
              objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "TARGET FOR REMOVAL : " & colUSR(intUSR)
              ''MARK FOR REMOVAL
              blnFND = false
            end if
          end if
        ''NO 'PROTECTED' USER ACCOUNT PASSED TO 'STRUSR'
        elseif (strUSR = vbnullstring) then
          for intCOL = 0 to ubound(arrUSR)
            blnFND = false
            ''SET 'STRUSR' TARGET USER TO 'ARRUSR' 'PROTECTED' USER ACCOUNT
            strUSR = arrUSR(intCOL)
            if (strUSR <> vbnullstring) then
              ''HANDLE '\' IS PASSED TARGET USERNAME 'STRUSR'
              if (instr(1, strUSR, "\")) then
                ''MATCHES PASSED 'PROTECTED' USER 'STRUSR'
                if (instr(1, lcase(colUSR(intUSR)), lcase(split(strUSR, "\")(1)))) then
                  objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "PROTECTED : " & colUSR(intUSR)
                  objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "PROTECTED : " & colUSR(intUSR)
                  ''MARK 'PROTECTED'
                  blnFND = true
                  exit for
                ''DOES NOT MATCH PASSED 'PROTECTED' USER 'STRUSR'
                elseif (instr(1, lcase(colUSR(intUSR)), lcase(split(strUSR, "\")(1))) = 0) then
                  objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "TARGET FOR REMOVAL : " & colUSR(intUSR)
                  objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "TARGET FOR REMOVAL : " & colUSR(intUSR)
                  ''MARK FOR REMOVAL
                  blnFND = false
                end if
              ''HANDLE WITHOUT '\' IN PASSED TARGET USERNAME 'STRUSR'
              elseif (instr(1, strUSR, "\") = 0) then
                ''MATCHES PASSED 'PROTECTED' USER 'STRUSR'
                if (instr(1, lcase(colUSR(intUSR)), lcase(strUSR))) then
                  objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "PROTECTED : " & colUSR(intUSR)
                  objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "PROTECTED : " & colUSR(intUSR)
                  ''MARK 'PROTECTED'
                  blnFND = true
                  exit for
                ''DOES NOT MATCH PASSED 'PROTECTED' USER 'STRUSR'
                elseif (instr(1, lcase(colUSR(intUSR)), lcase(strUSR)) = 0) then
                  objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "TARGET FOR REMOVAL : " & colUSR(intUSR)
                  objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "TARGET FOR REMOVAL : " & colUSR(intUSR)
                  ''MARK FOR REMOVAL
                  blnFND = false
                end if
              end if
            end if
          next
          ''CLEAR 'STRUSR' TARGET USER FOR NEXT VALUE
          strUSR = vbnullstring
        end if
      end if
      ''NO MATCH TO 'PROTECTED' USER ACCOUNTS, REMOVE USER ACCOUNT
      if (not blnFND) then
        objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "REMOVING : " & colUSR(intUSR)
        objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "REMOVING : " & colUSR(intUSR)
        ''REMOVE USER ACCOUNT
        call HOOK("net user " & colUSR(intUSR) & " /delete /y")
        blnFND = false
      end if
    end if
  next
  ''FINAL PASS OF 'C:\USERS' TO CHECK FOR FOLDERS OF NON-EXISTENT USERS
  objOUT.write vbnewline & now & vbtab & vbtab & " - CHECKING USER FOLDERS"
  objLOG.write vbnewline & now & vbtab & vbtab & " - CHECKING USER FOLDERS"
  set objFOL = objFSO.getfolder("C:\Users")
  set colFOL = objFOL.subfolders
  ''ENUMERATE 'C:\USERS' SUB-FOLDERS
  intFOL = 0
  for each subFOL in colFOL
    redim preserve arrFOL(intFOL + 1)
    arrFOL(intFOL) = subFOL.path
    intFOL = intFOL + 1
  next
  set colFOL = nothing
  set objFOL = nothing
  intFOL = 0
  for intFOL = 0 to ubound(arrFOL)
    intCOL = 0
    blnFND = false
    strFOL = arrFOL(intFOL)
    if (strFOL <> vbnullstring) then
      ''ENUMERATRE THROUGH AND MAKE SURE THIS ISN'T ONE OF THE 'PROTECTED' USER ACCOUNTS
      for intCOL = 0 to ubound(arrUSR)
        blnFND = false
        if (arrUSR(intCOL) <> vbnullstring) then
          '' 'PRTOTECTED' USER ACCOUNT 'ARRUSR' FOUND IN FOLDER PATH
          if (instr(1, lcase(strFOL), lcase(arrUSR(intCOL)))) then
            objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "PROTECTED : " & arrUSR(intCOL)
            objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "PROTECTED : " & arrUSR(intCOL)
            ''MARK 'PROTECTED'
            blnFND = true
            exit for
          end if
        end if
        ''A 'PROTECTED' USER ACCOUNT WAS PASSED TO 'STRUSR'
        if (wscript.arguments.count > 0) then
          '' PASSED 'PRTOTECTED' USER ACCOUNT 'ARRUSR'
          if (instr(1, lcase(strFOL), lcase(objARG.item(0)))) then
            objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "PROTECTED : " & objARG.item(0)
            objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "PROTECTED : " & objARG.item(0)
            ''MARK 'PROTECTED'
            blnFND = true
            exit for
          end if          
        end if
      next
      ''NO MATCH TO 'PROTECTED' USER ACCOUNTS
      if (not blnFND) then
        ''CHECK FOR USER FOLDER
        if (objFSO.folderexists(strFOL)) then
          objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "REMOVING : " & strFOL
          objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "REMOVING : " & strFOL
          ''REMOVE FOLDER
          call HOOK("takeown /f " & chr(34) & strFOL & chr(34))
          wscript.sleep 1000
          call HOOK("cmd /c rmdir /s /q " & chr(34) & strFOL & chr(34))
          blnFND = false
        end if
      end if
    end if
  next
end if
''END SCRIPT
call CLEANUP()
''END SCRIPT
''------------

''SUB-ROUTINES
sub CHKAU()																					        ''CHECK FOR SCRIPT UPDATE , 'ERRRET'=10 , ACCTCLEAN.VBS , REF #2 , FIXES #57
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
        objOUT.write vbnewline & now & vbtab & " - AcctClean :  " & strVER & " : GitHub : " & objSCR.text & vbnewline
        objLOG.write vbnewline & now & vbtab & " - AcctClean :  " & strVER & " : GitHub : " & objSCR.text & vbnewline
				if (cint(objSCR.text) > cint(strVER)) then
					objOUT.write vbnewline & now & " - UPDATING " & objSCR.nodename & " : " & objSCR.text & vbnewline
					objLOG.write vbnewline & now & " - UPDATING " & objSCR.nodename & " : " & objSCR.text & vbnewline
					''DOWNLOAD LATEST VERSION OF SCRIPT
					call FILEDL("https://github.com/CW-Khristos/scripts/raw/dev/AcctClean.vbs", wscript.scriptname)
					''RUN LATEST VERSION
					if (wscript.arguments.count > 0) then             ''ARGUMENTS WERE PASSED
						for x = 0 to (wscript.arguments.count - 1)
							strTMP = strTMP & " " & chr(34) & objARG.item(x) & chr(34)
						next
            objOUT.write vbnewline & now & vbtab & " - RE-EXECUTING  " & objSCR.nodename & " : " & objSCR.text & vbnewline
            objLOG.write vbnewline & now & vbtab & " - RE-EXECUTING  " & objSCR.nodename & " : " & objSCR.text & vbnewline
						objWSH.run "cscript.exe //nologo " & chr(34) & "c:\temp\" & wscript.scriptname & chr(34) & strTMP, 0, false
					elseif (wscript.arguments.count = 0) then         ''NO ARGUMENTS WERE PASSED
            objOUT.write vbnewline & now & vbtab & " - RE-EXECUTING  " & objSCR.nodename & " : " & objSCR.text & vbnewline
            objLOG.write vbnewline & now & vbtab & " - RE-EXECUTING  " & objSCR.nodename & " : " & objSCR.text & vbnewline
						objWSH.run "cscript.exe //nologo " & chr(34) & "c:\temp\" & wscript.scriptname & chr(34), 0, false
					end if
          if (err.number <> 0) then
            call LOGERR(10)
          end if
					''END SCRIPT
					call CLEANUP()
				end if
			end if
		next
	end if
	set colVER = nothing
	set objXML = nothing
  if (err.number <> 0) then                                 ''ERROR RETURNED DURING UPDATE CHECK , 'ERRRET'=10
    call LOGERR(10)
  end if
end sub

sub FILEDL(strURL, strFILE)                                 ''CALL HOOK TO DOWNLOAD FILE FROM URL , 'ERRRET'=11
  strSAV = vbnullstring
  ''SET DOWNLOAD PATH
  strSAV = "C:\temp\" & strFILE
  objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & vbtab & "HTTPDOWNLOAD-------------DOWNLOAD : " & strURL & " : SAVE AS :  " & strSAV
  objLOG.write vbnewline & vbnewline & now & vbtab & vbtab & vbtab & "HTTPDOWNLOAD-------------DOWNLOAD : " & strURL & " : SAVE AS :  " & strSAV
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
  if (err.number <> 0) then                                 ''ERROR RETURNED DURING UPDATE CHECK , 'ERRRET'=11
    call LOGERR(11)
  end if
end sub

sub HOOK(strCMD)                                            ''CALL HOOK TO MONITOR OUTPUT OF CALLED COMMAND , 'ERRRET'=12
  on error resume next
  objOUT.write vbnewline & now & vbtab & vbtab & "EXECUTING : " & strCMD
  objLOG.write vbnewline & now & vbtab & vbtab & "EXECUTING : " & strCMD
  set objHOOK = objWSH.exec(strCMD)
  ''SUPPRESS 'TAKEOWN' SUCCESS MESSAGES & LACK OF OUTPUT ON 'RMDIR /S /Q'
  if ((instr(1, strCMD, "rmdir /s /q") = 0) and (instr(1, strCMD, "takeown /F ") = 0)) then
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
  if (err.number <> 0) then
    objOUT.write vbnewline & now & vbtab & vbtab & vbtab & err.number & vbtab & err.description & vbnewline
    objLOG.write vbnewline & now & vbtab & vbtab & vbtab & err.number & vbtab & err.description & vbnewline
		errRET = intSTG
		err.clear
  end if
  ''CUSTOM ERROR CODES
  select case intSTG
  end select
end sub

sub CLEANUP()                                               ''SCRIPT CLEANUP
  if (errRET = 0) then                                      ''SCRIPT COMPLETED SUCCESSFULLY
    objOUT.write vbnewline & vbnewline & now & vbtab & " - ACCTCLEAN COMPLETE : " & now
    objLOG.write vbnewline & vbnewline & now & vbtab & " - ACCTCLEAN COMPLETE : " & now
    err.clear
  elseif (errRET <> 0) then                                 ''SCRIPT FAILED
    objOUT.write vbnewline & vbnewline & now & vbtab & " - ACCTCLEAN FAILURE : " & errRET & " : " & now
    objLOG.write vbnewline & vbnewline & now & vbtab & " - ACCTCLEAN FAILURE : " & errRET & " : " & now
    ''RAISE CUSTOMIZED ERROR CODE , ERROR CODE WILL BE DEFINED RESTOP NUMBER INDICATING WHICH SECTION FAILED
    call err.raise(vbObjectError + errRET, "ACCTCLEAN", "fail")
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