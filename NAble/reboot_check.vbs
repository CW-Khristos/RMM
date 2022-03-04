on error resume next
''ALWAYS RIGHT-CLICK SCRIPT, CHOOSE "PROPERTIES", CLICK "UNBLOCK"
''REGISTRY CONSTANTS
const HKCR = &H80000000
const HKLM = &H80000002
''SCRIPT VARIABLES
dim strCBS, strWUAU, strFRO
dim strCOMP, strIN, strNUL, strSEL, strRUN
dim objCCM, objCCMcu, objRBT, objPARAM, objREG
dim objIN, objOUT, objARG, objWSH, objFSO, objNET, objWMI, objLOG, objHOOK
''STDIN / STDOUT
set objIN = wscript.stdin
set objOUT = wscript.stdout
set objARG = wscript.arguments
''OBJECTS FOR LOCATING FOLDERS
set objWSH = createobject("wscript.shell")
set objFSO = createobject("scripting.filesystemobject")
''WMI OBJECTS
set objNET = createObject("WScript.Network")
set objWMI = createObject("WbemScripting.SWbemLocator")
''WMI OBJECTS FOR QUERYING REBOOT STATUS
strCOMP = "."
set objCCM = GetObject("winmgmts:\\" & strCOMP & "\root\ccm\ClientSDK")
set objCCMcu = objCCM.Get("CCM_ClientUtilities")
set objRBT = objCCMcu.Methods_("DetermineIfRebootPending").InParameters
set objPARAM = objCCMcu.ExecMethod_("DetermineIfRebootPending", objRBT)
''WMI OBJECTS FOR CONNECTING TO REGISTRY PROVIDER
Set objREG = GetObject("winmgmts:{impersonationLevel=impersonate}!\\" & strCOMP & "\root\default:StdRegProv")
''SYSINFO OBJECT
set objSysInfo = CreateObject("Microsoft.Update.SystemInfo")
''PREPARE LOGFILE
if (objFSO.fileexists("C:\temp\reboot_check")) then       ''LOGFILE EXISTS
  objFSO.deletefile "C:\temp\reboot_check", true
  set objLOG = objFSO.createtextfile("C:\temp\reboot_check")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\reboot_check", 8)
else                                                        ''LOGFILE NEEDS TO BE CREATED
  set objLOG = objFSO.createtextfile("C:\temp\reboot_check")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\reboot_check", 8)
end if
''SET EXECUTION FLAG
strRUN = "false"
''EXECUTE REBOOT_CHECK
objOUT.write vbnewline & vbnewline & now & " - STARTING REBOOT_CHECK" & vbnewline
objLOG.write vbnewline & vbnewline & now & " - STARTING REBOOT_CHECK" & vbnewline
''CHECK WMI FOR PENDING REBOOTS
objOUT.write vbnewline & vbnewline & now & vbtab & " - CHECKING WMI FOR PENDING REBOOTS"
objLOG.write vbnewline & vbnewline & now & vbtab & " - CHECKING WMI FOR PENDING REBOOTS"
call chkWMI()
''CHECK REGISTRY FOR PENDING REBOOTS
objOUT.write vbnewline & vbnewline & now & vbtab & " - CHECKING REGISTRY FOR PENDING REBOOTS"
objLOG.write vbnewline & vbnewline & now & vbtab & " - CHECKING REGISTRY FOR PENDING REBOOTS"
call chkREG()
''CHECK SYSINFO FOR PENDING REBOOTS
objOUT.write vbnewline & vbnewline & now & vbtab & " - CHECKING SYSINFO FOR PENDING REBOOTS"
objLOG.write vbnewline & vbnewline & now & vbtab & " - CHECKING SYSINFO FOR PENDING REBOOTS"
call chkSYS()
''EXECUTE FORCED SHUTDOWN
if (strRUN = "true") then
  objOUT.write vbnewline & vbnewline & now & vbtab & " - EXECUTING SHUTDOWN"
  objLOG.write vbnewline & vbnewline & now & vbtab & " - EXECUTING SHUTDOWN"
  'call HOOK("shutdown -r -t 1800 -c " & chr(34) & "This is a message from The ComputerWarriors, your system has been scheduled for a required reboot to maintain stability." & vbnewline & _
  '  "Please save all work and close all programs prior to the scheduled reboot time." & chr(34))
end if
''END SCRIPT
call CLEANUP()

''SUB-ROUTINES
sub chkWMI()''WMI REBOOT PENDING CHECK
  'wscript.echo objPARAM.DisableHideTime
  'wscript.echo objPARAM.InGracePeriod
  'wscript.echo objPARAM.IsHardRebootPending
  'wscript.echo objPARAM.NotifyUI
  'wscript.echo objPARAM.RebootDeadline
  objOUT.write vbnewline & vbtab & vbtab & " - WMI REBOOT REQUIRED : " & objPARAM.RebootPending
  objLOG.write vbnewline & vbtab & vbtab & " - WMI REBOOT REQUIRED : " & objPARAM.RebootPending
  'wscript.echo objPARAM.ReturnValue
  if (lcase(objPARAM.RebootPending) = "true") then
    objOUT.write " : SETTING EXECUTE REBOOT FLAG TO 'TRUE'"
    objLOG.write " : SETTING EXECUTE REBOOT FLAG TO 'TRUE'"
    strRUN = "true"
  end if
end sub

sub chkREG()
  dim arrVAL, keyVAL
  on error resume next
  ''REGISTRY CHECK - COMPONENT BASED SERVICING PENDING REBOOT
  ''ENUMERATE ALL VALUES AT COMPONENT BASED SERVICING KEY
  strCBS = "Software\Microsoft\Windows\CurrentVersion\Component Based Servicing"
  objOUT.write vbnewline & vbtab & vbtab & " - SEARCHING : [" & HKLM & "\" & strCBS & "]"
  objLOG.write vbnewline & vbtab & vbtab & " - SEARCHING : [" & HKLM & "\" & strCBS & "]"
  objREG.EnumKey HKLM, strCBS, arrVAL
  if (not isnull(arrVAL)) then
    for each keyVAL in arrVAL                                 ''SEARCH ALL VALUES AT COMPONENT BASED SERVICING KEY
      ''UNCOMMENT BELOW LINE TO OUTPUT ALL KEYS / VALUES
      'objOUT.write vbnewline & keyVAL
      if (keyVAL = "RebootPending") then
        objOUT.write " : SETTING EXECUTE REBOOT FLAG TO 'TRUE'"
        objLOG.write " : SETTING EXECUTE REBOOT FLAG TO 'TRUE'"
        objOUT.write vbnewline & now & vbtab & vbtab & " - 'RebootPending' found in [" & HKLM & "\" & strCBS & "]"
        objLOG.write vbnewline & now & vbtab & vbtab & " - 'RebootPending' found in [" & HKLM & "\" & strCBS & "]"
        ''SET SCRIPT TO EXECUTE REBOOT
        strRUN = "true"
      end if
    next
  end if
  set keyVAL = nothing
  set arrVAL = nothing
  ''REGISTRY CHECK - WINDOWS UPDATES PENDING REBOOT
  ''ENUMERATE ALL VALUES AT WINDOWS UPDATE KEY
  strWUAU = "SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update"
  objOUT.write vbnewline & vbtab & vbtab & " - SEARCHING : [" & HKLM & "\" & strWUAU & "]"
  objLOG.write vbnewline & vbtab & vbtab & " - SEARCHING : [" & HKLM & "\" & strWUAU & "]"
  objREG.EnumKey HKLM, strWUAU, arrVAL
  if (not isnull(arrVAL)) then
    for each keyVAL in arrVAL                                 ''SEARCH ALL VALUES AT WINDOWS UPDATES KEY
      ''UNCOMMENT BELOW LINE TO OUTPUT ALL KEYS / VALUES
      'objOUT.write vbnewline & keyVAL
      if (keyVAL = "RebootRequired") then
        objOUT.write " : SETTING EXECUTE REBOOT FLAG TO 'TRUE'"
        objLOG.write " : SETTING EXECUTE REBOOT FLAG TO 'TRUE'"
        objOUT.write vbnewline & now & vbtab & vbtab & " - 'RebootRequired' found in [" & HKLM & "\" & strWUAU & "]"
        objLOG.write vbnewline & now & vbtab & vbtab & " - 'RebootRequired' found in [" & HKLM & "\" & strWUAU & "]"
        ''SET SCRIPT TO EXECUTE REBOOT
        strRUN = "true"
      end if
    next
  end if
  set keyVAL = nothing
  set arrVAL = nothing
  ''REGISTRY CHECK - FILE RENAME OPERATIONS PENDING REBOOT
  ''ENUMERATE ALL VALUES AT FILE RENAME OPERATIONS KEY
  strFRO = "SYSTEM\CurrentControlSet\Control\Session Manager"
  objOUT.write vbnewline & vbtab & vbtab & " - SEARCHING : [" & HKLM & "\" & strFRO & "]"
  objLOG.write vbnewline & vbtab & vbtab & " - SEARCHING : [" & HKLM & "\" & strFRO & "]"
  objREG.EnumKey HKLM, strFRO, arrVAL
  if (not isnull(arrVAL)) then
    for each keyVAL in arrVAL                                 ''SEARCH ALL VALUES AT FILE RENAME OPERATIONS KEY
      ''UNCOMMENT BELOW LINE TO OUTPUT ALL KEYS / VALUES
      'objOUT.write vbnewline & keyVAL
      if (keyVAL = "RebootRequired") then
        objOUT.write " : SETTING EXECUTE REBOOT FLAG TO 'TRUE'"
        objLOG.write " : SETTING EXECUTE REBOOT FLAG TO 'TRUE'"
        objOUT.write vbnewline & now & vbtab & vbtab & " - 'RebootRequired' found in [" & HKLM & "\" & strFRO & "]"
        objLOG.write vbnewline & now & vbtab & vbtab & " - 'RebootRequired' found in [" & HKLM & "\" & strFRO & "]"
        ''SET SCRIPT TO EXECUTE REBOOT
        strRUN = "true"
      elseif (keyVAL = "FileRenameOperations") then
        objOUT.write " : SETTING EXECUTE REBOOT FLAG TO 'TRUE'"
        objLOG.write " : SETTING EXECUTE REBOOT FLAG TO 'TRUE'"
        objOUT.write vbnewline & now & vbtab & vbtab & " - 'FileRenameOperations' found in [" & HKLM & "\" & strFRO & "]"
        objLOG.write vbnewline & now & vbtab & vbtab & " - 'FileRenameOperations' found in [" & HKLM & "\" & strFRO & "]"
        ''SET SCRIPT TO EXECUTE REBOOT
        strRUN = "true"
      end if
    next
  end if
  set keyVAL = nothing
  set arrVAL = nothing
end sub

sub chkSYS()
  objOUT.write vbnewline & vbtab & vbtab & " - SYSINFO REBOOT REQUIRED : " & objSysInfo.RebootRequired
  objLOG.write vbnewline & vbtab & vbtab & " - SYSINFO REBOOT REQUIRED : " & objSysInfo.RebootRequired
  if (lcase(objSysInfo.RebootRequired) = "true") then
    objOUT.write " : SETTING EXECUTE REBOOT FLAG TO 'TRUE'"
    objLOG.write " : SETTING EXECUTE REBOOT FLAG TO 'TRUE'"
    strRUN = "true"
  end if
end sub

sub HOOK(strCMD)                                            ''CALL HOOK TO MONITOR OUTPUT OF CALLED COMMAND
  on error resume next
  'comspec = objWSH.ExpandEnvironmentStrings("%comspec%")
  set objHOOK = objWSH.exec(strCMD)
  'while (objHOOK.status = 0)
    while (not objHOOK.stdout.atendofstream)
      strIN = objHOOK.stdout.readline
      if (strIN <> vbnullstring) then
        objOUT.write vbnewline & now & vbtab & vbtab & strIN 
        objLOG.write vbnewline & now & vbtab & vbtab & strIN 
      end if
    wend
    wscript.sleep 10
  'wend
  strIN = objHOOK.stdout.readall
  if (strIN <> vbnullstring) then
    objOUT.write vbnewline & now & vbtab & vbtab & strIN 
    objLOG.write vbnewline & now & vbtab & vbtab & strIN 
  end if
  'retSTOP = objHOOK.exitcode
  set objHOOK = nothing
  if (err.number <> 0) then
    objOUT.write vbnewline & now & vbtab & vbtab & err.number & vbtab & err.description
    objLOG.write vbnewline & now & vbtab & vbtab & err.number & vbtab & err.description
  end if
end sub

sub CLEANUP()                                               ''SCRIPT CLEANUP
  objOUT.write vbnewline & vbnewline & now & " - REBOOT_CHECK COMPLETE" & vbnewline
  objLOG.write vbnewline & vbnewline & now & " - REBOOT_CHECK COMPLETE" & vbnewline
  objLOG.close
  ''EMPTY OBJECTS
  set objSysInfo = nothing
  set objREG = nothing
  set objPARAM = nothing
  set objRBT = nothing
  set objCCMcu = nothing
  set objCCM = nothing
  set objLOG = nothing
  set objWMI = nothing
  set objNET = nothing
  set objFSO = nothing
  set objWSH = nothing
  set objARG = nothing
  set objOUT = nothing
  set objIN = nothing
  ''END SCRIPT, RETURN ERROR NUMBER
  wscript.quit err.number
end sub