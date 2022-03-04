on error resume next
''THIS SCRIPT IS DESIGNED TO REMOVE LEFT-OVER REGISTRY KEYS AND FOLDERS FROM AV INSTALLATIONS
''REGISTRY CONSTANTS
const HKCR = &H80000000
const HKLM = &H80000002
''SCRIPT VARIABLES
dim objIN, objOUT, objARG, objWSH, objFSO, objHOOK
dim objWMI, objNET, objNAME, objREG, objLOG, objTXT, blnACT
dim strIN, sPATH(12), lngRC, intFOL, colFOL(4), strMSI, strREG, strBAK, retREG
''STDIN / STDOUT
set objIN = wscript.stdin
set objOUT = wscript.stdout
set objARG = wscript.arguments
''PERFORM ACTION BOOLEAN
blnACT = false
''OBJECTS FOR LOCATING FOLDERS
set objWSH = createobject("wscript.shell")
set objFSO = createobject("scripting.filesystemobject")
''OBJECTS FOR CONNECTING TO REGISTRY PROVIDER
Set objWMI = createObject("WbemScripting.SWbemLocator")
Set objNET = createObject("WScript.Network")
''CONNECT TO REGISTRY PROVIDER
Set objNAME = objWMI.ConnectServer(objNET.ComputerName, "root\default")
Set objREG = objNAME.Get("StdRegProv")
''MSIEXEC UNINSTALL REGISTRY KEYS
strMSI = "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
''CHECK EXECUTION METHOD OF SCRIPT
strIN = lcase(mid(wscript.fullname, instrrev(wscript.fullname, "\") + 1))
if (strIN <> "cscript.exe") Then
  objOUT.write vbnewline & "SCRIPT LAUNCHED VIA EXPLORER, EXECUTING SCRIPT VIA CSCRIPT..."
  objWSH.run "cscript.exe //nologo " & chr(34) & Wscript.ScriptFullName & chr(34)
  wscript.quit
end if
''PREPARE LOGFILE
if (objFSO.fileexists("C:\temp\av_output")) then     ''LOGFILE EXISTS
  objFSO.deletefile "C:\temp\av_output", true
  set objLOG = objFSO.createtextfile("C:\temp\av_output")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\av_output", 8)
else                                            ''LOGFILE NEEDS TO BE CREATED
  set objLOG = objFSO.createtextfile("C:\temp\av_output")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\av_output", 8)
end if
''READ PASSED COMMANDLINE ARGUMENTS
if (wscript.arguments.count > 0) then           ''ARGUMENTS WERE PASSED
  for x = 0 to (wscript.arguments.count - 1)
    objOUT.write vbnewline & now & vbtab & "ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
    objLOG.write vbnewline & now & vbtab & "ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
  next
  ''SET TARGET AV TO REMOVE
  strIN = objARG.item(0)
  ''SET REMOVAL ARGUMENT, IF NONE PASSED SET REMOVAL TO FALSE
  if (wscript.arguments.count > 1) then
    blnACT = cbool(objARG.item(1))
  else
    blnACT = false
  end if
else                                            ''NO ARGUMENTS PASSED, REQUEST WHICH AV TO REMOVE
  objOUT.write vbnewline & "ENTER LISTED CODE TO SELECT AV TO REMOVE"
  objOUT.write vbnewline & vbtab & "AVD - AV DEFENDER (CLEAN REMOVAL)"
  objOUT.write vbnewline & vbtab & "AVG - AVG AV"
  objOUT.write vbnewline & vbtab & "MSSE - MICROSOFT SECURITY ESSENTIALS / ANTIMALWARE (NOT A CLEAN REMOVAL)"
  objOUT.write vbnewline & vbtab & "MCAFEE - MCAFEE AV"
  objOUT.write vbnewline & vbtab & "MWB - MALWAREBYTES"
  objOUT.write vbnewline & vbtab & "NOR - NORTON AV" & vbnewline
  ''READ INPUT - SCRIPT WILL WAIT FOR INPUT
  strIN = objIN.readline
  objOUT.write vbnewline & "SELECT SCRIPT MODE"
  objOUT.write vbnewline & vbtab & "1. (L)OG MODE - LOG OUTPUT AS NORMAL, NO REMOVAL ACTIONS"
  objOUT.write vbnewline & vbtab & "2. (R)EMOVAL MODE - PERFORM REMOVAL ACTIONS, LOG OUTPUT"
  strTMP = objIN.readline
  if ((strTMP = "1") or (strTMP = "L")) then
    blnACT = false
  elseif ((strTMP = "2") or (strTMP = "R")) then
    blnACT = true
  end if
end if
objOUT.write vbnewline & vbnewline & now & " - SELECTED : " & ucase(strIN) & vbnewline
objLOG.write vbnewline & vbnewline & now & " - SELECTED : " & ucase(strIN) & vbnewline
objOUT.write vbnewline & vbnewline & now & " - REMOVAL : " & blnACT & vbnewline
objLOG.write vbnewline & vbnewline & now & " - REMOVAL : " & blnACT & vbnewline
''CONFIGURE SCRIPT FOR REMOVAL OF SELECTED AV
select case ucase(strIN)
  case "AVD"                                    ''AV DEFENDER
    call remAVD
  case "AVG"                                    ''AVG AV
    call remAVG
  case "MSSE"                                   ''MICROSOFT SECURITY ESSENTIALS / ANTIMALWARE
    call remMSSE
  case "MCAFEE"                                 ''MCAFEE AV
    call remMCAFEE
  case "MWB"                                    ''MALWAREBYTES
    call remMWB
  case "NOR"                                    ''NORTON AV
    call remNOR
end select
''EMPTY VARIABLES / EXIT SCRIPT
call CLEANUP

''CONFIGURATION FUNCTIONS
function remAVD()                               ''AV DEFENDER
  objOUT.write vbnewline & now & " - RUNNING AV DEFENDER REMOVAL..." & vbnewline
  objLOG.write vbnewline & now & " - RUNNING AV DEFENDER REMOVAL..." & vbnewline
  ''PREPARE REGISTRY BACKUP DIRECTORY
  strBAK = "C:\avd_regs"
  if (objFSO.folderexists("C:\avd_regs") = false) then
    objFSO.createfolder("C:\avd_regs")
  end if
  ''RUN REMOVAL TOOL AND WAIT FOR COMPLETION - AV DEFENDER REMOVAL ONLY - SCRIPT WILL WAIT FOR REMOVAL TOOL
  objOUT.write vbnewline & now & vbtab & "RUNNING NRC UNINSTALLER (RUN 1)..." & vbnewline
  objLOG.write vbnewline & now & vbtab & "RUNNING NRC UNINSTALLER (RUN 1)..." & vbnewline
  'objWSH.run "UninstallTool.exe", , true
  ''RECORD / UPDATE / DELETE AVD REGISTRY ENTRIES
  ''HKEY_LOCAL_MACHINE
  ''CLEAR ASSIGNED REGISTRY KEYS
  intKEY = 0
  while (intKEY <= ubound(sPATH))
    if (sPATH(intKEY) <> vbnullstring) then
      sPATH(intKEY) = vbnullstring
    end if
    intKEY = (intKEY + 1)
  wend
  objOUT.write vbnewline & vbnewline & now & vbtab & "CHECKING HKEY_LOCAL_MACHINE..."
  objLOG.write vbnewline & vbnewline & now & vbtab & "CHECKING HKEY_LOCAL_MACHINE..."
  ''ASSIGN KEYS TO DELETE
  sPATH(0) = "SOFTWARE\AVDefender"
  sPATH(1) = "SOFTWARE\BitDefender"
  sPATH(2) = "SOFTWARE\N-Able Technologies\AVDefender"
  ''DELETE AVD REGISTRY KEYS
  call delREG(HKLM, sPATH)
  ''RUN REMOVAL TOOL AND WAIT FOR COMPLETION - AV DEFENDER REMOVAL ONLY - SCRIPT WILL WAIT FOR REMOVAL TOOL
  objOUT.write vbnewline & vbnewline & now & vbtab & "RUNNING NRC UNINSTALLER (RUN 2)..." & vbnewline
  objLOG.write vbnewline & vbnewline & now & vbtab & "RUNNING NRC UNINSTALLER (RUN 2)..." & vbnewline
  'objWSH.run "UninstallTool.exe", , true
  ''DELETE AVD INSTALLATION
  objOUT.write vbnewline & now & vbtab & "CHECKING FOLDERS..."
  objLOG.write vbnewline & now & vbtab & "CHECKING FOLDERS..."
  ''ASSIGN FOLDERS TO DELETE
  colFOL(0) = "C:\ProgramData\N-Able Technologies"
  colFOL(1) = "C:\Program Files\N-able Technologies\AVDefender"
  colFOL(2) = "C:\Program Files(x86)\N-able Technologies\Windows Agent\AVDefender"
  call delFOL()
end function

function remAVG()                               ''AVG AV
  objOUT.write vbnewline &  now & " - RUNNING AVG REMOVAL...AFTER REMOVAL PLEASE REBOOT AND RUN A SECOND TIME" & vbnewline
  objLOG.write vbnewline &  now & " - RUNNING AVG REMOVAL...AFTER REMOVAL PLEASE REBOOT AND RUN A SECOND TIME" & vbnewline
  ''PREPARE REGISTRY BACKUP DIRECTORY
  strBAK = "C:\avg_regs"
  if (objFSO.folderexists("C:\avg_regs") = false) then
    objFSO.createfolder("C:\avg_regs")
  end if
  ''CREATE REGINI FILE TO TAKE OWNERSHIP / ASSIGN FULL CONTROL
  strREG = "c:\avg_regs\avg_regini.txt"
  objFSO.createtextfile strREG, true
  ''ATTEMPT NORMAL UNINSTALL
  objOUT.write vbnewline & vbnewline & now & vbtab & "ATTEMPTING TO LOCATE MSI GUID..."
  objLOG.write vbnewline & vbnewline & now & vbtab & "ATTEMPTING TO LOCATE MSI GUID..."
  call msiKEY(HLM, strMSI, "AVG Anti")
  ''RECORD / UPDATE / DELETE AVG REGISTRY ENTRIES
  ''HKEY_LOCAL_MACHINE
  objOUT.write vbnewline & vbnewline & now & vbtab & "CHECKING HKEY_LOCAL_MACHINE..."
  objLOG.write vbnewline & vbnewline & now & vbtab & "CHECKING HKEY_LOCAL_MACHINE..."
  objREG.EnumKey HKLM, "", retHKLM
  for each subKEY in retHKLM
    call seekKEY(HKLM, subKEY, "AVG Anti")
  next
  ''HKEY_CLASSES_ROOT
  objOUT.write vbnewline & vbnewline & now & vbtab & "CHECKING HKEY_CLASSES_ROOT..."
  objLOG.write vbnewline & vbnewline & now & vbtab & "CHECKING HKEY_CLASSES_ROOT..."
  objREG.EnumKey HKCR, "", retHKCR
  for each subKEY in retHKCR
    call seekKEY(HKCR, subKEY, "AVG Anti")
  next
  ''DELETE AVG INSTALLATION FILES
  objOUT.write vbnewline & vbnewline & now & vbtab & "CHECKING FOLDERS...EXPECT PERMISSION DENIED ERRORS ON FIRST RUN"
  objLOG.write vbnewline & vbnewline & now & vbtab & "CHECKING FOLDERS...EXPECT PERMISSION DENIED ERRORS ON FIRST RUN"
  ''ASSIGN FOLDERS TO DELETE
  colFOL(0) = "C:\Program Files (x86)\AVG"
  colFOL(1) = "c:\Program Files\AVG Antivirus 2011"
  colFOL(2) = "c:\Documents and Settings\All Users\Start Menu\AVG Antivirus 2011"
  call delFOL
end function

function remMSSE()                              ''MICROSOFT SECURITY ESSENTIALS / ANTIMALWARE
  objOUT.write vbnewline &  now & " - RUNNING MICROSOFT AV REMOVAL...AFTER REMOVAL PLEASE REBOOT AND RUN A SECOND TIME" & vbnewline
  objLOG.write vbnewline &  now & " - RUNNING MICROSOFT AV REMOVAL...AFTER REMOVAL PLEASE REBOOT AND RUN A SECOND TIME" & vbnewline
  ''PREPARE REGISTRY BACKUP DIRECTORY
  strBAK = "C:\msse_regs"
  if (objFSO.folderexists("C:\msse_regs") = false) then
    objFSO.createfolder("C:\msse_regs")
  end if
  ''CREATE REGINI FILE TO TAKE OWNERSHIP / ASSIGN FULL CONTROL
  strREG = "c:\msse_regs\msse_regini.txt"
  objFSO.createtextfile strREG, true
  ''KILL MSSE PROCESSES
  objOUT.write vbnewline & now & vbtab & "TERMINATING MSSE PROCESSES AND SERVICES"
  objLOG.write vbnewline & now & vbtab & "TERMINATING MSSE PROCESSES AND SERVICES"
  objOUT.write vbnewline & now & vbtab & vbtab & "PROCESS : MsMpEng.exe"
  objLOG.write vbnewline & now & vbtab & vbtab & "PROCESS : MsMpEng.exe"
  call HOOK("TASKKILL /f /im " & chr(34) & "MsMpEng.exe" & chr(34))
  objOUT.write vbnewline & now & vbtab & vbtab & "PROCESS : msseces.exe"
  objLOG.write vbnewline & now & vbtab & vbtab & "PROCESS : msseces.exe"
  call HOOK("TASKKILL /f /im " & chr(34) & "msseces.exe" & chr(34))
  objOUT.write vbnewline & now & vbtab & vbtab & "PROCESS : MpCmdRun.exe"
  objLOG.write vbnewline & now & vbtab & vbtab & "PROCESS : MpCmdRun.exe"
  call HOOK("TASKKILL /f /im " & chr(34) & "MpCmdRun.exe" & chr(34))
  objOUT.write vbnewline & now & vbtab & vbtab & "SERVICE : MsMpSvc"
  objLOG.write vbnewline & now & vbtab & vbtab & "SERVICE : MsMpSvc"
  call HOOK("net stop " & chr(34) & "MsMpSvc" & chr(34))
  call HOOK("sc delete " & chr(34) & "MsMpSvc" & chr(34))
  ''ATTEMPT NORMAL UNINSTALL
  'objOUT.write vbnewline & vbnewline & now & vbtab & "ATTEMPTING TO LOCATE MSI GUID..."
  'objLOG.write vbnewline & vbnewline & now & vbtab & "ATTEMPTING TO LOCATE MSI GUID..."
  'call msiKEY(HLM, strMSI, "Microsoft Security Client")
  'call msiKEY(HLM, strMSI, "Microsoft Antimalware")
  ''RECORD / UPDATE / DELETE MSSE REGISTRY ENTRIES
  ''HKEY_LOCAL_MACHINE
  objOUT.write vbnewline & vbnewline & now & vbtab & "CHECKING HKEY_LOCAL_MACHINE..."
  objLOG.write vbnewline & vbnewline & now & vbtab & "CHECKING HKEY_LOCAL_MACHINE..."
  ''CLEAR ASSIGNED REGISTRY KEYS
  intKEY = 0
  while (intKEY <= ubound(sPATH))
    if (sPATH(intKEY) <> vbnullstring) then
      sPATH(intKEY) = vbnullstring
    end if
    intKEY = (intKEY + 1)
  wend
  ''ASSIGN KEYS TO DELETE
  sPATH(0) = "SYSTEM\CurrentControlSet\services\MsMpSvc"
  sPATH(1) = "SOFTWARE\Microsoft\Microsoft Antimalware"
  sPATH(2) = "SOFTWARE\Microsoft\Microsoft Security Client"
  sPATH(3) = "SOFTWARE\Policies\Microsoft\Microsoft Antimalware"
  sPATH(4) = "Software\Microsoft\Windows\Current Version\Run\MSC"
  sPATH(5) = "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Security Client"
  sPATH(6) = "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{774088D4-0777-4D78-904D-E435B318F5D2}"
  sPATH(7) = "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{77A776C4-D10F-416D-88F0-53F2D9DCD9B3}"
  sPATH(8) = "SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products\4C677A77F01DD614880F352F9DCD9D3B"
  sPATH(9) = "SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products\4D880477777087D409D44E533B815F2D"
  sPATH(10) = "SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UpgradeCodes\11BB99F8B7FD53D4398442FBBAEF050F"
  sPATH(11) = "SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UpgradeCodes\1F69ACF0D1CF2B7418F292F0E05EC20B"
  ''DELETE MSSE REGISTRY KEYS
  call delREG(HKLM, sPATH)
  'objREG.EnumKey HKLM, "", retHKLM
  'for each subKEY in retHKLM
  '  call seekKEY(HKLM, subKEY, "Microsoft Security Client")
  '  call seekKEY(HKLM, subKEY, "Microsoft Antimalware Service")
  'next
  ''HKEY_CLASSES_ROOT
  objOUT.write vbnewline & vbnewline & now & vbtab & "CHECKING HKEY_CLASSES_ROOT..."
  objLOG.write vbnewline & vbnewline & now & vbtab & "CHECKING HKEY_CLASSES_ROOT..."
  ''CLEAR ASSIGNED REGISTRY KEYS
  intKEY = 0
  while (intKEY <= ubound(sPATH))
    if (sPATH(intKEY) <> vbnullstring) then
      sPATH(intKEY) = vbnullstring
    end if
    intKEY = (intKEY + 1)
  wend
  ''ASSIGN KEYS TO DELETE
  sPATH(0) = "Installer\Products\4C677A77F01DD614880F352F9DCD9D3B"
  sPATH(1) = "Installer\Products\4D880477777087D409D44E533B815F2D"
  sPATH(2) = "Installer\UpgradeCodes\1F69ACF0D1CF2B7418F292F0E05EC20B"
  sPATH(3) = "Installer\UpgradeCodes\11BB99F8B7FD53D4398442FBBAEF050F"
  ''DELETE AVD REGISTRY KEYS
  call delREG(HKCR, sPATH)
  'objREG.EnumKey HKCR, "", retHKCR
  'for each subKEY in retHKCR
  '  call seekKEY(HKCR, subKEY, "Microsoft Security Client")
  '  call seekKEY(HKCR, subKEY, "Microsoft Antimalware")
  '  call seekKEY(HKCR, subKEY, "Microsoft Antimalware Service")
  'next
  ''DELETE MSSE INSTALLATION FILES
  objOUT.write vbnewline & vbnewline & now & vbtab & "CHECKING FOLDERS...EXPECT PERMISSION DENIED ERRORS ON FIRST RUN"
  objLOG.write vbnewline & vbnewline & now & vbtab & "CHECKING FOLDERS...EXPECT PERMISSION DENIED ERRORS ON FIRST RUN"
  ''ASSIGN FOLDERS TO DELETE
  colFOL(0) = "C:\Program Files\Microsoft Security Client"
  colFOL(1) = "C:\Program Files (x86)\Microsoft Security Client"
  colFOL(2) = "C:\ProgramData\Microsoft\Microsoft Antimalware"
  colFOL(3) = "C:\ProgramData\Microsoft\Microsoft Security Client"
  colFOL(4) = "C:\Windows\System32\wbem\Repository"
  call delFOL
end function

function remMCAFEE()                            ''MCAFEE AV
  objOUT.write vbnewline &  now & " - RUNNING MCAFEE REMOVAL...AFTER REMOVAL PLEASE REBOOT AND RUN A SECOND TIME" & vbnewline
  objLOG.write vbnewline &  now & " - RUNNING MCAFEE REMOVAL...AFTER REMOVAL PLEASE REBOOT AND RUN A SECOND TIME" & vbnewline
  ''PREPARE REGISTRY BACKUP DIRECTORY
  strBAK = "C:\mcafee_regs"
  if (objFSO.folderexists("C:\mcafee_regs") = false) then
    objFSO.createfolder("C:\mcafee_regs")
  end if
  ''CREATE REGINI FILE TO TAKE OWNERSHIP / ASSIGN FULL CONTROL
  strREG = "c:\mcafee_regs\mcafee_regini.txt"
  objFSO.createtextfile strREG, true
  ''ATTEMPT NORMAL UNINSTALL
  objOUT.write vbnewline & vbnewline & now & vbtab & "ATTEMPTING TO LOCATE MSI GUID..."
  objLOG.write vbnewline & vbnewline & now & vbtab & "ATTEMPTING TO LOCATE MSI GUID..."
  call msiKEY(HLM, strMSI, "McAfee")
  'call HOOK("mcpr.exe")
  ''RECORD / UPDATE / DELETE MSSE REGISTRY ENTRIES
  ''HKEY_LOCAL_MACHINE
  objOUT.write vbnewline & vbnewline & now & vbtab & "CHECKING HKEY_LOCAL_MACHINE..."
  objLOG.write vbnewline & vbnewline & now & vbtab & "CHECKING HKEY_LOCAL_MACHINE..."
  objREG.EnumKey HKLM, "", retHKLM
  for each subKEY in retHKLM
    call seekKEY(HKLM, subKEY, "McAfee")
  next
  ''HKEY_CLASSES_ROOT
  objOUT.write vbnewline & vbnewline & now & vbtab & "CHECKING HKEY_CLASSES_ROOT..."
  objLOG.write vbnewline & vbnewline & now & vbtab & "CHECKING HKEY_CLASSES_ROOT..."
  objREG.EnumKey HKCR, "", retHKCR
  for each subKEY in retHKCR
    call seekKEY(HKLM, subKEY, "McAfee")
  next
  ''DELETE MCAFEE INSTALLATION FILES
  objOUT.write vbnewline & vbnewline & now & vbtab & "CHECKING FOLDERS...EXPECT PERMISSION DENIED ERRORS ON FIRST RUN"
  objLOG.write vbnewline & vbnewline & now & vbtab & "CHECKING FOLDERS...EXPECT PERMISSION DENIED ERRORS ON FIRST RUN"
  ''ASSIGN FOLDERS TO DELETE
  colFOL(0) = "C:\Program Files\McAfee"
  colFOL(1) = "C:\Program Files (x86)\McAfee"
  colFOL(2) = "C:\Program Files\Common Files\McAfee"
  colFOL(3) = "C:\Program Files (x86)\Common Files\McAfee"
  call delFOL
end function

function remMWB()                               ''MALWAREBYTES
end function

function remNOR()                               ''NORTON AV
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