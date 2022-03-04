''AVD_REMOVAL.VBS
''THIS SCRIPT IS DESIGNED TO DOWNLOAD AND EXECUTE AV DEFENDER REMOVAL TOOL
''SCRIPT WILL THEN REMOVE LEFT-OVER REGISTRY KEYS AND FOLDERS FROM AV DEFENDER INSTALLATIONS
''THE NRC AV DEFENDER REMOVAL TOOL SHOULD BE RUN PRIOR TO RUNNING THIS SCRIPT, AND THEN AFTER RUNNING THE SCRIPT
''ACCEPTS 2 PARAMETERS , REQUIRES 1 PARAMETER
''REQUIRED PARAMETER : 'STRUVER' , STRING TO SET TARGET UNINSTALL VERSION
''OPTIONAL PARAMETER : 'STRSLT' , STRING TO SET SILENT UNINSTALL BOOLEAN
''WRITTEN BY : CJ BLEDSOE / CJ<@>THECOMPUTERWARRIORS.COM
on error resume next
''SCRIPT VARIABLES
const HKLM = &H80000002
dim errRET, strVER, strIN, strOUT
dim sPATH, lngRC, intFOL, colFOL(2)
''VARIABLES ACCEPTING PARAMETERS
dim strUVER, strSLT, blnSLT
''SCRIPT OBJECTS
dim objLOG, objEXEC, objHOOK
dim objWMI, objNET, objNAME, objREG
dim objIN, objOUT, objARG, objWSH, objFSO
''VERSION FOR SCRIPT UPDATE, AVD_REMOVAL.VBS, REF #2
strVER = 1
''DEFAULT SUCCESS
errRET = 0
''DEFAULT SILENT UNINSTALL
blnSLT = true
''STDIN / STDOUT
set objIN = wscript.stdin
set objOUT = wscript.stdout
set objARG = wscript.arguments
''OBJECTS FOR LOCATING FOLDERS
set objWSH = createobject("wscript.shell")
set objFSO = createobject("scripting.filesystemobject")
''OBJECTS FOR CONNECTING TO REGISTRY PROVIDER
Set objNET = createObject("WScript.Network")
Set objWMI = createObject("WbemScripting.SWbemLocator")
''CONNECT TO REGISTRY PROVIDER
Set objNAME = objWMI.ConnectServer(objNET.ComputerName, "root\default")
Set objREG = objNAME.Get("StdRegProv")
''PREPARE LOGFILE
if (objFSO.fileexists("C:\temp\AVD_REMOVAL")) then          ''LOGFILE EXISTS
  objFSO.deletefile "C:\temp\AVD_REMOVAL", true
  set objLOG = objFSO.createtextfile("C:\temp\AVD_REMOVAL")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\AVD_REMOVAL", 8)
else                                                        ''LOGFILE NEEDS TO BE CREATED
  set objLOG = objFSO.createtextfile("C:\temp\AVD_REMOVAL")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\AVD_REMOVAL", 8)
end if
''READ PASSED COMMANDLINE ARGUMENTS
if (wscript.arguments.count > 0) then                       ''ARGUMENTS WERE PASSED
  for x = 0 to (wscript.arguments.count - 1)
    objOUT.write vbnewline & now & vbtab & " - ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
    objLOG.write vbnewline & now & vbtab & " - ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
  next 
  if (wscript.arguments.count > 0) then                     ''REQUIRED ARGUMENTS PASSED
    strUVER = objARG.item(0)                                ''SET REQUIRED PARAMETER 'STRUVER' , STRING TO SET TARGET UNINSTALL VERSION
    if (wscript.arguments.count > 1) then                   ''OPTIONAL ARGUMENTS PASSED
      strSLT = objARG.item(1)                               ''SET OPTIONAL PARAMETER 'STRSLT' , STRING TO SET SILENT UNINSTALL BOOLEAN
      if (strSLT <> vbnullstring) then
        if (((left(lcase(strSLT), 1) = "y") or (lcase(strSLT) = "yes")) or _
          ((left(lcase(strSLT), 1) = "t") or (lcase(strSLT) = "true"))) then
            blnSLT = true
        elseif (((left(lcase(strSLT), 1) = "n") or (lcase(strSLT) = "no")) or _
          ((left(lcase(strSLT), 1) = "f") or (lcase(strSLT) = "false"))) then
            blnSLT = false
        end if
      end if
      'strSVC = objARG.item(2)                               ''SET OPTIONAL PARAMETER 'STRSVC' , TARGET SERVICE FOR USER CREDENTIALS
    end if
  end if
else                                                        ''NO ARGUMENTS PASSED , END SCRIPT , 'ERRRET'=1
  'call LOGERR(1)
end if

''------------
''BEGIN SCRIPT
if (errRET <> 0) then
elseif (errRET = 0) then
  objOUT.write vbnewline & vbnewline & now & vbtab & " - EXECUTING AVD_REMOVAL"
  objLOG.write vbnewline & vbnewline & now & vbtab & " - EXECUTING AVD_REMOVAL"
  ''AUTOMATIC UPDATE , 'ERRRET'=10 , AVD_REMOVAL.VBS , REF #2
  call CHKAU()
  objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & " - DOWNLOADING AVD_REMOVAL TOOL"
  objLOG.write vbnewline & vbnewline & now & vbtab & vbtab & " - DOWNLOADING AVD_REMOVAL TOOL"
  ''NON-SILENT UNINSTALL
  if (not blnSLT) then
    ''DOWNLOAD Uninstall_Tool_6.6.2.49 VERSION OF SCRIPT
    if (strUVER = "662") then
      strUVER = "Uninstall_Tool_6.6.2.49.exe"
      call FILEDL("https://github.com/CW-Khristos/scripts/raw/dev/AVD_Latest_Removal_Tool/Uninstall_Tool_6.6.2.49.exe", "Uninstall_Tool_6.6.2.49.exe")
    ''DOWNLOAD Uninstall_Tool_6.4.2.79 VERSION OF SCRIPT
    elseif (strUVER = "642") then
      strUVER = "Uninstall_Tool_6.4.2.79.exe"
      call FILEDL("https://github.com/CW-Khristos/scripts/raw/dev/AVD_Latest_Removal_Tool/Uninstall_Tool_6.4.2.79.exe", "Uninstall_Tool_6.4.2.79.exe")
    ''DOWNLOAD Uninstall_Tool_6.6.10.148 VERSION OF SCRIPT
    elseif (strUVER = "6610") then
      strUVER = "Uninstall_Tool_6.6.10.148.exe"
      call FILEDL("https://github.com/CW-Khristos/scripts/raw/dev/AVD_Latest_Removal_Tool/Uninstall_Tool_6.6.10.148.exe", "Uninstall_Tool_6.6.10.148.exe")
    end if
  ''SILENT UNINSTALL
  elseif (blnSLT) then
    ''DOWNLOAD UninstallToolSilent6.6.2.49 VERSION OF SCRIPT
    if (strUVER = "662") then
      strUVER = "UninstallToolSilent6.6.2.49.exe"
      call FILEDL("https://github.com/CW-Khristos/scripts/raw/dev/AVD_Latest_Removal_Tool/UninstallToolSilent6.6.2.49.exe", "UninstallToolSilent6.6.2.49.exe")
    ''DOWNLOAD UninstallToolSilent6.4.2.79 VERSION OF SCRIPT
    elseif (strUVER = "642") then
      strUVER = "UninstallToolSilent6.4.2.79.exe"
      call FILEDL("https://github.com/CW-Khristos/scripts/raw/dev/AVD_Latest_Removal_Tool/UninstallToolSilent6.4.2.79.exe", "UninstallToolSilent6.4.2.79.exe")
    ''DOWNLOAD UninstallToolSilent_6.6.11.164 VERSION OF SCRIPT
    elseif (strUVER = "6610") then
      strUVER = "UninstallToolSilent_6.6.11.164.exe"
      call FILEDL("https://github.com/CW-Khristos/scripts/raw/dev/AVD_Latest_Removal_Tool/UninstallToolSilent_6.6.11.164.exe", "UninstallToolSilent_6.6.11.164.exe")
    end if
  end if
  ''RUN REMOVAL TOOL AND WAIT FOR COMPLETION
  objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & " - EXECUTING AVD_REMOVAL TOOL : SILENT : " & blnSLT
  objLOG.write vbnewline & vbnewline & now & vbtab & vbtab & " - EXECUTING AVD_REMOVAL TOOL : SILENT : " & blnSLT
  call HOOK("c:\temp\" & strUVER)
  wscript.sleep 3000
  ''FOLDER PATHS TO REMOVE
  colFOL(0) = "C:\Program Data\N-Able Technologies"
  colFOL(1) = "C:\Program Files\N-able Technologies\AVDefender"
  colFOL(2) = "C:\Program Files(x86)\N-able Technologies\Windows Agent\AVDefender"
  ''DELETE FOLDERS
  intFOL = 0
  objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & " - REMOVING AVDEFENDER PROGRAM FOLDERS"
  objLOG.write vbnewline & vbnewline & now & vbtab & vbtab & " - REMOVING AVDEFENDER PROGRAM FOLDERS"
  objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & " - IF YOU ENCOUNTER PERMISSION DENIED AS ADMIN, CHECK FOR ANY PROCESSES RELATED TO AVDEFENDER IN TASK MANAGER"
  objLOG.write vbnewline & vbnewline & now & vbtab & vbtab & " - IF YOU ENCOUNTER PERMISSION DENIED AS ADMIN, CHECK FOR ANY PROCESSES RELATED TO AVDEFENDER IN TASK MANAGER"
  while (intFOL < 3)
    if (objFSO.folderexists(colFOL(intFOL))) then
      objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & vbtab & " - REMOVING FOLDER: " & colFOL(intFOL)
      objLOG.write vbnewline & vbnewline & now & vbtab & vbtab & vbtab & " - REMOVING FOLDER: " & colFOL(intFOL)
      call HOOK ("takeown /F " & chr(34) & colFOL(intFOL) & chr(34) & " /R /D Y")
      objFSO.deletefolder colFOL(intFOL), true
    else
      objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & vbtab & " - NON-EXISTENT: " & colFOL(intFOL)
      objLOG.write vbnewline & vbnewline & now & vbtab & vbtab & vbtab & " - NON-EXISTENT: " & colFOL(intFOL)
    end if
    intFOL = (intFOL + 1)
  wend
  ''DELETE TARGET KEYS
  sPATH = "SOFTWARE\AVDefender"
  objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & " - REMOVING KEY: " & sPATH
  objLOG.write vbnewline & vbnewline & now & vbtab & vbtab & " - REMOVING KEY: " & sPATH
  lngRC = delREG(HKLM, sPATH)
  sPATH = "SOFTWARE\BitDefender"
  objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & " - REMOVING KEY: " & sPATH
  objLOG.write vbnewline & vbnewline & now & vbtab & vbtab & " - REMOVING KEY: " & sPATH
  lngRC = delREG(HKLM, sPATH)
  sPATH = "SOFTWARE\N-Able Technologies\AVDefender"
  objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & " - REMOVING KEY: " & sPATH
  objLOG.write vbnewline & vbnewline & now & vbtab & vbtab & " - REMOVING KEY: " & sPATH
  lngRC = delREG(HKLM, sPATH)
  sPATH = "SYSTEM\CurrentControlSet\Services\EPProtectedService"
  objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & " - REMOVING KEY: " & sPATH
  objLOG.write vbnewline & vbnewline & now & vbtab & vbtab & " - REMOVING KEY: " & sPATH
  lngRC = delREG(HKLM, sPATH)
  ''RUN REMOVAL TOOL AGAIN
  objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & " - AVDEFENDER REMOVAL WILL LAUNCH AGAIN, PLEASE RUN AND COMPLETE REMOVAL BEFORE REBOOTING"
  objLOG.write vbnewline & vbnewline & now & vbtab & vbtab & " - AVDEFENDER REMOVAL WILL LAUNCH AGAIN, PLEASE RUN AND COMPLETE REMOVAL BEFORE REBOOTING"
  ''RUN REMOVAL TOOL AND WAIT FOR COMPLETION
  objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & " - EXECUTING AVD_REMOVAL TOOL : SILENT : " & blnSLT
  objLOG.write vbnewline & vbnewline & now & vbtab & vbtab & " - EXECUTING AVD_REMOVAL TOOL : SILENT : " & blnSLT
  call HOOK("c:\temp\" & strUVER)
  wscript.sleep 3000
  objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & " - AVDEFENDER REMOVAL COMPLETE, PLEASE REBOOT NOW"
  objLOG.write vbnewline & vbnewline & now & vbtab & vbtab & " - AVDEFENDER REMOVAL COMPLETE, PLEASE REBOOT NOW"
end if
''END SCRIPT
call CLEANUP()
''END SCRIPT
''------------

''FUNCTIONS
function delREG(sHive, sEnumPath)               ''ACTUAL FUNCTION CALLED TO DELETE KEYS
  ''ATTEMPT TO DELETE REGISTRY KEY, IF THIS FAILS, ENUMERATE SUB-KEYS
  lngRC = objREG.DeleteKey(sHive, sEnumPath)

  ''ENUMERATE SUB-KEYS
  if (lngRC <> 0) then
    on error resume next
    lngRC = objREG.EnumKey(HKLM, sEnumPath, sNames)

    for each subKEY In sNames
      if (err.number <> 0) then
        exit for
        lngRC = delREG(sHive, sEnumPath & "\" & sKeyName)
      end if
    next

    on error goto 0
    ''ATTEMPT TO DELETE TARGET REGISTRY KEY AGAIN
    lngRC = objREG.DeleteKey(sHive, sEnumPath)
  end if
end function

''SUB-ROUTINES
sub delFOL()                                    ''DELETE FOLDERS SUB-ROUTINE
  on error resume next
  intFOL = 0
  ''ENUMERATE THROUGH ALL ASSIGNED FOLDERS
  while (intFOL <= ubound(colFOL))
    if (colFOL(intFOL) <> vbnullstring) then
      objOUT.write vbnewline & now & vbtab & vbtab & "REMOVING : " & colFOL(intFOL)
      objLOG.write vbnewline & now & vbtab & vbtab & "REMOVING : " & colFOL(intFOL)
      if (objFSO.folderexists(colFOL(intFOL))) then
        if (blnACT) then                        ''PERFORM ACTION IF BLNACT IS TRUE
          call HOOK("takeown /f " & chr(34) & colFOL(intFOL) & chr(34) & " /a /r")
          objFSO.deletefolder colFOL(intFOL), true
        end if
        if (err.number <> 0) then               ''ERROR DELETING FOLDER
          objOUT.write vbnewline & now & vbtab & vbtab & "CANNOT DELETE - " & err.number & " " & err.description & " : " & colFOL(intFOL)
          objLOG.write vbnewline & now & vbtab & vbtab & "CANNOT DELETE - " & err.number & " " & err.description & " : " & colFOL(intFOL)
        end if
      else                                      ''NON-EXISTENT FOLDER
        objOUT.write vbnewline & now & vbtab & vbtab & "NON-EXISTENT : " & colFOL(intFOL)
        objLOG.write vbnewline & now & vbtab & vbtab & "NON-EXISTENT : " & colFOL(intFOL)
      end if
    end if
    intFOL = (intFOL + 1)
  wend
end sub

''REGISTRY SUB-ROUTINES
sub msiKEY(strHIVE, strKEY, strFIND)            ''SEARCH FOR MSIEXEC INSTALL / UNINSTALL GUID
  on error resume next
  objREG.EnumKey strHIVE, strKEY, subkeys
  if (not isnull(subkeys)) then
    for each sk in subkeys
      keyname = vbnullstring
      keyname = wshshell.RegRead(strHIVE & "\" & strMSI & "\" & sk & "\DisplayName")
      if instr(1, keyname, strFIND) then        ''REGISTRY ENTRY FOUND
        if (blnACT) then                        ''PERFORM ACTION IF BLNACT IS TRUE
          objOUT.write vbnewline & vbnewline & now & vbtab & "GUID FOR " & sk & " FOUND, RUNNING MSIEXEC UNINSTALL..."
          objLOG.write vbnewline & vbnewline & now & vbtab & "GUID FOR " & sk & " FOUND, RUNNING MSIEXEC UNINSTALL..."
          call HOOK("msiexec.exe /qn /norestart /x " & sk)
        end if
      end if
    next
  end if
end sub

sub seekKEY(strHIVE, strKEY, strFIND)           ''SEARCH REGISTRY SUB-ROUTINE
  on error resume next
  ''UNCOMMENT LINE BELOW FOR DEBUG OUTPUT - THIS SHOULD ONLY BE DONE FOR TROUBLESHOOTING SCRIPT, OUTPUT WILL BE ENORMOUS
  'objOUT.write vbnewline & vbtab & vbtab & "SEARCHING : [" & strHive & "\" & strKEY & "]"
  'objLOG.write vbnewline & vbtab & vbtab & "SEARCHING : [" & strHive & "\" & strKEY & "]"
  ''ENUMERATE ALL VALUES AT CURRENT KEY
  objREG.EnumValues strHIVE, strKEY, arrVAL, arrTYPE
  for each keyVAL in arrVAL                     ''SEARCH ALL VALUES AT CURRENT KEY
    strDATA = vbnullstring
    rc = objREG.GetStringValue(strHIVE, strKEY, keyVAL, strDATA)
    if (not isnull(strDATA)) then
      ''UNCOMMENT LINE BELOW FOR DEBUG OUTPUT - THIS SHOULD ONLY BE DONE FOR TROUBLESHOOTING SCRIPT, OUTPUT WILL BE ENORMOUS
      'objOUT.write vbnewline & vbtab & vbtab & "'" & keyVAL & "'='" & strDATA & "'"
      'objLOG.write vbnewline & vbtab & vbtab & "'" & keyVAL & "'='" & strDATA & "'"
      if (instr(1, strDATA, strFIND)) then      ''REGISTRY ENTRY FOUND
        ''RECORD REGISTRY KEY IN REGINI / CREATE BACKUP OF KEY
        objOUT.write vbnewline & now & vbtab & vbtab & "'" & strFIND & "' found in [" & strHIVE & "\" & strKEY & "], rc=" & rc
        objLOG.write vbnewline & now & vbtab & vbtab & "'" & strFIND & "' found in [" & strHIVE & "\" & strKEY & "], rc=" & rc
        call bakKEY(strHIVE, strKEY)
        ''ASSIGN REGISTRY OWNERSHIP / PERMISSIONS WITH REGINI
        if (blnACT) then                        ''PERFORM ACTION IF BLNACT IS TRUE 
          objOUT.write vbnewline & now & vbtab & vbtab & "UPDATING REGISTRY PERMISSIONS FOR REMOVAL..." & vbnewline
          objLOG.write vbnewline & now & vbtab & vbtab & "UPDATING REGISTRY PERMISSIONS FOR REMOVAL..." & vbnewline
          call HOOK("regini " & chr(34) & strREG & chr(34))
          call delKEY(strHIVE, strKEY)
        end if
        exit sub
      end if
    end if
  next
  ''REGISTRY ENTRY NOT FOUND, CHECK SUBKEYS
  objREG.EnumKey strHIVE, strKEY, subkeys
  if (not isnull(subkeys)) then
    for each sk in subkeys
      ''UNCOMMENT LINE BELOW FOR DEBUG OUTPUT - THIS SHOULD ONLY BE DONE FOR TROUBLESHOOTING SCRIPT, OUTPUT WILL BE ENORMOUS
      'objOUT.write vbnewline & vbtab & vbtab & "SEARCHING : [" & strHive & "\" & strKEY & "\" & sk & "]"
      'objLOG.write vbnewline & vbtab & vbtab & "SEARCHING : [" & strHive & "\" & strKEY & "\" & sk & "]"
      seekKEY strHIVE, strKEY & "\" & sk, strFIND
    next
  end if
end sub

sub bakKEY(strHIVE, strKEY)                     ''BACKUP TARGET KEY SUB-ROUTINE
  ''OPEN REGINI FILE FOR WRITING
  set objTXT = objFSO.opentextfile(strREG, 2)
  if (strHIVE = HKLM) then                      ''HKEY_LOCAL_MACHINE
    ''RECORD REGISTRY ENTRY IN REGINI FILE
    objTXT.writeline "\Registry\machine\" & strKEY & " [4 5 10 17]"
    ''CREATE BACKUP OF REGISTRY KEY
    objOUT.write vbnewline & now & vbtab & vbtab & "CREATING BACKUP : " & chr(34) & strBAK & "\" & replace(strKEY, "\", "_") & ".reg" & chr(34)
    objLOG.write vbnewline & now & vbtab & vbtab & "CREATING BACKUP : " & chr(34) & strBAK & "\" & replace(strKEY, "\", "_") & ".reg" & chr(34)
    call HOOK("reg.exe export " & chr(34) & "HKLM\" & strKEY & chr(34) & " " & chr(34) & strBAK & "\" & replace(strKEY, "\", "_") & ".reg" & chr(34) & " /Y")
  elseif (strHIVE = HKCR) then                  ''HKEY_CLASSES_ROOT
    ''RECORD MSSE REGISTRY ENTRY IN REGINI FILE
    objTXT.writeline "\Registry\machine\software\classes\" & strKEY & " [4 5 10 17]"
    ''CREATE BACKUP OF REGISTRY KEY
    objOUT.write vbnewline & now & vbtab & vbtab & "CREATING BACKUP : " & chr(34) & strBAK & "\" & replace(strKEY, "\", "_") & ".reg" & chr(34)
    objLOG.write vbnewline & now & vbtab & vbtab & "CREATING BACKUP : " & chr(34) & strBAK & "\" & replace(strKEY, "\", "_") & ".reg" & chr(34)
    call HOOK("reg.exe export " & chr(34) & "HKCR\" & strKEY & chr(34) & " " & chr(34) & strBAK & "\" & replace(strKEY, "\", "_") & ".reg" & chr(34) & " /Y")
  end if
  ''SAVE RECORDED REGISTRIES FOR PERMISSIONS UPDATE IN REGINI FILE
  objTXT.close
  set objTXT = nothing
  if (err.number <> 0) then
    objOUT.write vbnewline & vbtab & now & vbtab & vbtab & err.number & vbtab & err.description
  end if
end sub

sub delREG(strHIVE, arrKEY())                   ''DELETE TARGET KEYS SUB-ROUTINE
  on error resume next
  intKEY = 0
  while (intKEY <= ubound(arrKEY))
    if (arrKEY(intKEY) <> vbnullstring) then
      lngRC = objWSH.regread(strHIVE & "\" & arrKEY(intKey))
      if (lngRC = 0) then
        call bakKEY(strHIVE, arrKEY(intKEY))
        ''PERFORM ACTION IF BLNACT IS TRUE 
        if (blnACT) then
          objOUT.write vbnewline & now & vbtab & vbtab & "REMOVING : " & arrKEY(intKEY)
          objLOG.write vbnewline & now & vbtab & vbtab & "REMOVING : " & arrKEY(intKEY)
          lngRC = delKEY(strHIVE, arrKEY(intKEY))
        end if
        if (lngRC <> 0) then
          objOUT.write vbnewline & now & vbtab & vbtab & "ERROR : " & lngRC & " : " & arrKY(intKEY)
          objLOG.write vbnewline & now & vbtab & vbtab & "ERROR : " & lngRC & " : " & arrKY(intKEY)
        end if
      end if
    end if
    intKEY = (intKEY + 1)
  wend
end sub

sub delKEY(strHIVE, strPATH)                    ''DELETE KEY SUB-ROUTINE
  on error resume next
  ''ATTEMPT TO DELETE REGISTRY KEY, IF THIS FAILS, ENUMERATE SUB-KEYS
  objOUT.write vbnewline & now & vbtab & vbtab & "REMOVING : " & strHIVE & "\" & strPATH & " : "
  objLOG.write vbnewline & now & vbtab & vbtab & "REMOVING : " & strHIVE & "\" & strPATH & " : "
  lngRC = objREG.DeleteKey(strHIVE, strPATH)
  if (lngRC <> 0) then                          ''ERROR DELETING KEY
    intERR = intERR + 1
    objOUT.write "ERROR" & vbnewline
    objLOG.write "ERROR" & vbnewline
    objOUT.write vbtab & vbtab & vbtab & vbtab & "DELETING SUB-KEYS" & vbnewline
    objLOG.write vbtab & vbtab & vbtab & vbtab & "DELETING SUB-KEYS" & vbnewline
    ''ENUMERATE SUB-KEYS
    lngRC = objREG.EnumKey(strHIVE, strPATH, sNames)
    if (not isnull(sNames)) then
      for each subKEY In sNames
        if (lngRC <> 0) then exit for
        call delKEY(strHIVE, strPATH & "\" & subKEY)
      next
    end if
    on error goto 0
    ''ATTEMPT TO DELETE TARGET REGISTRY KEY AGAIN, ONLY TRY TWICE THEN ASSUME KEY CANNOT BE DELETED
    lngRC = objREG.DeleteKey(strHIVE, strPATH)
    if (lngRC <> 0) then                        ''ERROR DELETING KEY
	  objOUT.write "ERROR : KEY CANNOT BE DELETED : "  & strHIVE & "\" & strPATH & vbnewline
	  objLOG.write "ERROR : KEY CANNOT BE DELETED : "  & strHIVE & "\" & strPATH & vbnewline
      exit sub
    else                                        ''SUCCESS DELETING KEY
    objOUT.write "SUCCESS" & vbnewline
    objLOG.write "SUCCESS" & vbnewline
    end if
  else                                          ''SUCCESS DELETING KEY
    objOUT.write "SUCCESS" & vbnewline
    objLOG.write "SUCCESS" & vbnewline
  end if
end sub

''SCRIPT UPDATE AND FILE D/L SUB-ROUTINES
sub CHKAU()																					        ''CHECK FOR SCRIPT UPDATE , 'ERRRET'=10 , AVD_REMOVAL.VBS , REF #2
  ''REMOVE WINDOWS AGENT CACHED VERSION OF SCRIPT
  if (objFSO.fileexists("C:\Program Files (x86)\N-Able Technologies\Windows Agent\cache\" & wscript.scriptname)) then
    objFSO.deletefile "C:\Program Files (x86)\N-Able Technologies\Windows Agent\cache\" & wscript.scriptname, true
  end if
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
        objOUT.write vbnewline & now & vbtab & " - AVD_REMOVAL :  " & strVER & " : GitHub : " & objSCR.text & vbnewline
        objLOG.write vbnewline & now & vbtab & " - AVD_REMOVAL :  " & strVER & " : GitHub : " & objSCR.text & vbnewline
				if (cint(objSCR.text) > cint(strVER)) then
					objOUT.write vbnewline & now & " - UPDATING " & objSCR.nodename & " : " & objSCR.text & vbnewline
					objLOG.write vbnewline & now & " - UPDATING " & objSCR.nodename & " : " & objSCR.text & vbnewline
					''DOWNLOAD LATEST VERSION OF SCRIPT
					call FILEDL("https://github.com/CW-Khristos/scripts/raw/dev/avd_removal.vbs", wscript.scriptname)
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
  objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "HTTPDOWNLOAD-------------DOWNLOAD : " & strURL & " : SAVE AS :  " & strSAV
  objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "HTTPDOWNLOAD-------------DOWNLOAD : " & strURL & " : SAVE AS :  " & strSAV
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

''SCRIPT LOGGING AND CLEANUP
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
      'objOUT.write vbnewline & vbnewline & now & vbtab & " - SCRIPT REQUIRES USER TO GRANT SERVICE LOGON"
      'objLOG.write vbnewline & vbnewline & now & vbtab & " - SCRIPT REQUIRES USER TO GRANT SERVICE LOGON"
  end select
end sub

sub CLEANUP()                                   ''SCRIPT CLEANUP
  objOUT.write vbnewline & vbnewline & now & " - REMOVAL COMPLETE. PLEASE REBOOT." & vbnewline
  objLOG.write vbnewline & vbnewline & now & " - REMOVAL COMPLETE. PLEASE REBOOT." & vbnewline
  objLOG.close
  ''EMPTY OBJECTS
  set objLOG = nothing
  set objREG = nothing
  set objNAME = nothing
  set objNET = nothing
  set objWMI = nothing
  set objFSO = nothing
  set objWSH = nothing
  set objARG = nothing
  set objOUT = nothing
  set objIN = nothing
  ''END SCRIPT, RETURN DEFAULT NO ERROR
  wscript.quit err.number
end sub