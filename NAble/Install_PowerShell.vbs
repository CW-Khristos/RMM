''INSTALL_POWERSHELL.VBS
''INSTALLS WMF5.1 & PS7.1
''WRITTEN BY : CJ BLEDSOE / CBLEDSOE<@>IPMCOMPUTERS.COM
on error resume next
''SCRIPT VARIABLES
dim errRET, strVER, strIN
dim strREPO, strBRCH, strDIR
''VARIABLES ACCEPTING PARAMETERS
dim psURL, wmfURL, blnCOM
''SCRIPT OBJECTS
dim objIN, objOUT, objARG, objWSH, objFSO
dim objNET, objWMI, objLOG, objEXEC, objHOOK
''VERSION FOR SCRIPT UPDATE, INSTALL_POWERSHELL.VBS, REF #2 , REF #68 , REF #69 , FIXES #21 , FIXES #31
strVER = 1
strREPO = "scripts"
strBRCH = "dev"
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
''OBJECTS FOR CONNECTING TO REGISTRY PROVIDER
Set objNET = createObject("WScript.Network")
Set objWMI = createObject("WbemScripting.SWbemLocator")
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
if (objFSO.fileexists("C:\temp\INSTALL_POWERSHELL")) then   ''LOGFILE EXISTS
  objFSO.deletefile "C:\temp\INSTALL_POWERSHELL", true
  set objLOG = objFSO.createtextfile("C:\temp\INSTALL_POWERSHELL")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\INSTALL_POWERSHELL", 8)
else                                                        ''LOGFILE NEEDS TO BE CREATED
  set objLOG = objFSO.createtextfile("C:\temp\INSTALL_POWERSHELL")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\INSTALL_POWERSHELL", 8)
end if
''READ PASSED COMMANDLINE ARGUMENTS
if (wscript.arguments.count > 0) then                       ''ARGUMENTS WERE PASSED
  for x = 0 to (wscript.arguments.count - 1)
    objOUT.write vbnewline & now & vbtab & " - ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
    objLOG.write vbnewline & now & vbtab & " - ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
  next 
  if (wscript.arguments.count > 1) then                     ''REQUIRED ARGUMENTS PASSED
  else                                                      ''NOT ENOUGH ARGUMENTS PASSED , END SCRIPT , 'ERRRET'=1
    'call LOGERR(1)
  end if
elseif (wscript.arguments.count = 0) then                   ''NO ARGUMENTS PASSED , END SCRIPT , 'ERRRET'=1
  'call LOGERR(1)
end if

''------------
''BEGIN SCRIPT
if (errRET = 0) then                                        ''NO ERRORS DURING INITIAL START
  blnCOM = false
  psURL = vbnullstring
  wmfURL = vbnullstring
  objOUT.write vbnewline & vbnewline & now & vbtab & " - EXECUTING INSTALL_POWERSHELL"
  objLOG.write vbnewline & vbnewline & now & vbtab & " - EXECUTING INSTALL_POWERSHELL"
	''AUTOMATIC UPDATE, INSTALL_POWERSHELL.VBS, REF #2 , REF #69 , REF #68
  objOUT.write vbnewline & now & vbtab & vbtab & " - CHECKING FOR UPDATE : INSTALL_POWERSHELL : " & strVER
  objLOG.write vbnewline & now & vbtab & vbtab & " - CHECKING FOR UPDATE : INSTALL_POWERSHELL : " & strVER
  ''DOWNLOAD CHKAU.VBS SCRIPT, REF #2 , REF #69 , REF #68
  call FILEDL("https://raw.githubusercontent.com/CW-Khristos/scripts/master/chkAU.vbs", "C:\IT\Scripts", "chkAU.vbs")
  ''EXECUTE CHKAU.VBS SCRIPT, REF #69
  intRET = objWSH.run ("cmd.exe /C " & chr(34) & "cscript.exe " & chr(34) & "C:\IT\Scripts\chkAU.vbs" & chr(34) & " " & _
    chr(34) & strREPO & chr(34) & " " & chr(34) & strBRCH & chr(34) & " " & chr(34) & strDIR & chr(34) & " " & _
    chr(34) & wscript.scriptname & chr(34) & " " & chr(34) & strVER & chr(34) & chr(34), 0, true)
  ''CHKAU RETURNED - NO UPDATE FOUND , REF #2 , REF #69 , REF #68
  objOUT.write vbnewline & "errRET='" & intRET & "'"
  objLOG.write vbnewline & "errRET='" & intRET & "'"
  intRET = (intRET - vbObjectError)
  objOUT.write vbnewline & "errRET='" & intRET & "'"
  objLOG.write vbnewline & "errRET='" & intRET & "'"
  if ((intRET = 4) or (intRET = 10) or (intRET = 11) or (intRET = 1) or (intRET = 2147221505) or (intRET = 2147221517)) then
    ''QUERY WMI
    objOUT.write vbnewline & now & vbtab & vbtab & " - QUERYING SYSTEM INFO :"
    objLOG.write vbnewline & now & vbtab & vbtab & " - QUERYING SYSTEM INFO :"
    set objWMIService = objWMI.connectserver(objNET.ComputerName, "root\cimv2")
    set colItems = objWMIService.execquery("Select * from Win32_OperatingSystem",,48)
    for each objItem in colItems
      strMsg = vbnewline & now & vbtab & vbtab & "Computer Name   : " & objItem.CSName & vbCrLf & _
               now & vbtab & vbtab & "Windows Version : " & objItem.Version & vbCrLf & _
               now & vbtab & vbtab & "ServicePack     : " & objItem.CSDVersion & vbCrLf & _
               now & vbtab & vbtab & "Product Type    : " & objItem.ProductType & vbCrLf & _
               now & vbtab & vbtab & "OSArchitecture  : " & objItem.OSArchitecture & vbCrLf 
      arch = objItem.osarchitecture
      productType = objItem.producttype
      ''Get the first two digits from the version string
      versionArray = split(objItem.version, ".", -1, 1)
      version = versionArray(0) & "." & versionArray(1)
    next
    ''WMI CLEANUP
    set objWMIService = nothing
    set colItems = nothing
    'On some OS OSArchitecture is not available so check the registry
    intArch = strcomp(arch, "64-bit", 1)
    if (intArch = -1) then
      intArch = strcomp(RegOSbits, "True", 1)
    end if
    ''DISPLAY WMI RESULTS
    objOUT.write strMSG
    objLOG.write strMSG
    ''SELECT INSTALLER BASED ON OS
    select case version
      ''WINDOWS 10 / SERVER 2019 / SERVER 2016
      case "10.0"
        blnCOM = true
        objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & "OS:Windows 10 / Server 2019 / Server 2016"
        if (intArch = 0) then                               ''64BIT
         psURL = "https://raw.githubusercontent.com/CW-Khristos/scripts/master/PowerShell/PowerShell-7.1.4-win-x64.msi"
        elseif (intArch <> 0) then                          ''32BIT
         psURL = "https://raw.githubusercontent.com/CW-Khristos/scripts/master/PowerShell/PowerShell-7.1.4-win-x86.msi"
        end if
      ''WINDOWS 8.1 / SERVER 2012R2
      case "6.3"
        blnCOM = true
        objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & "OS:Windows 8.1 / Server 2012R2"
        if (intArch = 0) then                               ''64BIT
         psURL = "https://raw.githubusercontent.com/CW-Khristos/scripts/master/PowerShell/PowerShell-7.1.4-win-x64.msi"
         wmfURL = "https://raw.githubusercontent.com/CW-Khristos/scripts/master/PowerShell/WMF/Win8.1AndW2K12R2-KB3191564-x64.msu"
         ucrURL = "https://raw.githubusercontent.com/CW-Khristos/scripts/master/PowerShell/WindowsUCRT/Windows8.1-KB3118401-x64.msu"
        elseif (intArch <> 0) then                          ''32BIT
         psURL = "https://raw.githubusercontent.com/CW-Khristos/scripts/master/PowerShell/PowerShell-7.1.4-win-x86.msi"
         wmfURL = "https://raw.githubusercontent.com/CW-Khristos/scripts/master/PowerShell/WMF/Win8.1-KB3191564-x86.msu"
         ucrURL = "https://raw.githubusercontent.com/CW-Khristos/scripts/master/PowerShell/WindowsUCRT/Windows8.1-KB3118401-x86.msu"
        end if
      ''WINDOWS 8 / SERVER 2012
      case "6.2"
        blnCOM = true
        objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & "OS:Windows 8 / Server 2012"
        if (intArch = 0) then                               ''64BIT
         psURL = "https://raw.githubusercontent.com/CW-Khristos/scripts/master/PowerShell/PowerShell-7.1.4-win-x64.msi"
         wmfURL = "https://raw.githubusercontent.com/CW-Khristos/scripts/master/PowerShell/WMF/W2K12-KB3191565-x64.msu"
         ucrURL = "https://raw.githubusercontent.com/CW-Khristos/scripts/master/PowerShell/WindowsUCRT/Windows8-RT-KB3118401-x64.msu"
        elseif (intArch <> 0) then                          ''32BIT
         psURL = "https://raw.githubusercontent.com/CW-Khristos/scripts/master/PowerShell/PowerShell-7.1.4-win-x86.msi"
         wmfURL = "https://raw.githubusercontent.com/CW-Khristos/scripts/master/PowerShell/WMF/Win8.1-KB3191564-x86.msu"
         ucrURL = "https://raw.githubusercontent.com/CW-Khristos/scripts/master/PowerShell/WindowsUCRT/Windows8-RT-KB3118401-x86.msu"
        end if
      ''WINDOWS 7 / SERVER 2008R2
      case "6.1"
        blnCOM = true
        objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & "OS:Windows 7 / Server 2008R2"
        if (intArch = 0) then                               ''64BIT
         psURL = "https://raw.githubusercontent.com/CW-Khristos/scripts/master/PowerShell/PowerShell-7.1.4-win-x64.msi"
         wmfURL = "https://raw.githubusercontent.com/CW-Khristos/scripts/master/PowerShell/WMF/Win7AndW2K8R2-KB3191566-x64.msu"
         ucrURL = "https://raw.githubusercontent.com/CW-Khristos/scripts/master/PowerShell/WindowsUCRT/Windows6.1-KB3118401-x64.msu"
        elseif (intArch <> 0) then                          ''32BIT
         psURL = "https://raw.githubusercontent.com/CW-Khristos/scripts/master/PowerShell/PowerShell-7.1.4-win-x86.msi"
         wmfURL = "https://raw.githubusercontent.com/CW-Khristos/scripts/master/PowerShell/WMF/Win7-KB3191566-x86.msu"
         ucrURL = "https://raw.githubusercontent.com/CW-Khristos/scripts/master/PowerShell/WindowsUCRT/Windows6.1-KB3118401-x86.msu"
        end if
      ''WINDOWS VISTA / SERVER 2008
      case "6.0"
        blnCOM = false
        if (strcomp(productType, "1", 1) = 0) then          ''VISTA
          objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & "OS:Vista"
          if (intArch = 0) then                             ''64BIT
           psURL = "https://raw.githubusercontent.com/CW-Khristos/scripts/master/PowerShell/PowerShell-7.1.4-win-x64.msi"
           ucrURL = "https://raw.githubusercontent.com/CW-Khristos/scripts/master/PowerShell/WindowsUCRT/Windows6.0-KB3118401-x64.msu"
          elseif (intArch <> 0) then                        ''32BIT
           psURL = "https://raw.githubusercontent.com/CW-Khristos/scripts/master/PowerShell/PowerShell-7.1.4-win-x86.msi"
           ucrURL = "https://raw.githubusercontent.com/CW-Khristos/scripts/master/PowerShell/WindowsUCRT/Windows6.0-KB3118401-x86.msu"
          end if
        elseif (strcomp(productType, "1", 1) <> 0) then     ''SERVER 2008
          objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & "OS:Server 2008"
          if (intArch = 0) then                             ''64BIT
           psURL = "https://raw.githubusercontent.com/CW-Khristos/scripts/master/PowerShell/PowerShell-7.1.4-win-x64.msi"
           ucrURL = "https://raw.githubusercontent.com/CW-Khristos/scripts/master/PowerShell/WindowsUCRT/Windows6.0-KB3118401-x64.msu"
          elseif (intArch <> 0) then                        ''32BIT
           psURL = "https://raw.githubusercontent.com/CW-Khristos/scripts/master/PowerShell/PowerShell-7.1.4-win-x86.msi"
           ucrURL = "https://raw.githubusercontent.com/CW-Khristos/scripts/master/PowerShell/WindowsUCRT/Windows6.0-KB3118401-x86.msu"
          end if
        end if
      ''OS NOT COMPATIBLE
      case else
        blnCOM = false
        call LOGGERR(2)
    end select
    if (blnCOM) then                                        ''OS COMPATIBLE
      ''CHECK UNIVERSAL C RUNTIME DEPENDENCY
      if (ucrURL <> vbnullstring) then
        objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & " - CHECKING UNIVERSAL C RUNTIME DEPENDENCY :"
        objLOG.write vbnewline & vbnewline & now & vbtab & vbtab & " - CHECKING UNIVERSAL C RUNTIME DEPENDENCY :"
        ''DOWNLOAD OS UCRT INSTALLER
        call FILEDL(ucrURL, "C:\IT", split(ucrURL, "/")(ubound(split(ucrURL, "/"))))
        ''RUN OS UCRT INSTALLER
        call HOOK("wusa.exe C:\IT\" & split(ucrURL, "/")(ubound(split(ucrURL, "/"))) & " /quiet /norestart /log:c:\temp\ucrinstall.log")      
      end if
      ''CHECK WMF5.1 DEPENDENCY
      if (wmfURL <> vbnullstring) then
        objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & " - CHECKING WMF-5.1 DEPENDENCY :"
        objLOG.write vbnewline & vbnewline & now & vbtab & vbtab & " - CHECKING WMF-5.1 DEPENDENCY :"
        ''DOWNLOAD WMF5.1 INSTALLER
        call FILEDL(wmfURL, "C:\IT", split(wmfURL, "/")(ubound(split(wmfURL, "/"))))
        ''RUN WMF INSTALLER
        call HOOK("wusa.exe C:\IT\" & split(wmfURL, "/")(ubound(split(wmfURL, "/"))) & " /quiet /norestart /log:c:\temp\wmfinstall.log")
      end if
      ''CHECK DOTNET DEPENDENCY
      objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & " - CHECKING .NET-4.5.2 DEPENDENCY :"
      objLOG.write vbnewline & vbnewline & now & vbtab & vbtab & " - CHECKING .NET-4.5.2 DEPENDENCY :"
      if (not CheckNET) then                                  ''DOTNET NOT INSTALLED
        ''DOWNLOAD DOTNET INSTALLER
        call FILEDL("https://raw.githubusercontent.com/CW-Khristos/scripts/master/PowerShell/WMF/dotNetFx45_Full_setup.exe", "C:\IT", "dotNetFx45_Full_setup.exe")
        ''RUN DOTNET INSTALLER
        call HOOK("C:\IT\dotNetFx45_Full_setup.exe /q /norestart /log C:\temp\dotnetinstall.log")
      end if
      ''DOWNLOAD POWERSHELL INSTALLER
      objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & " - INSTALLING POWERSHELL-7.1 :"
      objLOG.write vbnewline & vbnewline & now & vbtab & vbtab & " - INSTALLING POWERSHELL-7.1 :"
      call FILEDL(psURL, "C:\IT", split(psURL, "/")(ubound(split(psURL, "/"))))
      ''RUN POWERSHELL INSTALLER
      call HOOK("msiexec /i C:\IT\" & split(psURL, "/")(ubound(split(psURL, "/"))) & " /quiet /qn /norestart /l*v c:\temp\psinstall.log")
    elseif (not blnCOM) then                                ''OS NOT COMPATIBLE
      call LOGERR(2)
    end if
  end if
elseif (errRET <> 0) then                                   ''ERRORS ENCOUNTERED DURING INITIAL START
  call LOGERR(errRET)
end if
''END SCRIPT
call CLEANUP()
''END SCRIPT
''------------

''FUNCTIONS
function GetOSbits()
   if (objWSH.ExpandEnvironmentStrings("%PROCESSOR_ARCHITECTURE%") = "AMD64") then
      GetOSbits = 64
   else
      GetOSbits = 32
   end if
end function

function RegOSbits() 
  on error resume next
  objWSH.regead "HKLM\Software\Microsoft\Windows\CurrentVersion\ProgramFilesDir (x86)"
  if (err.number <> 0) then
    RegOSbits = "False"
  elseif (err.number = 0) then
    RegOSbits = "True"
  end if
end function

function CheckNET()
  on error resume next
  installed = objWSH.regread("HKLM\Software\Microsoft\NET Framework Setup\NDP\v4\Full\Install")
  if (err.number = 0) then
    release = objWSH.regread("HKLM\Software\Microsoft\NET Framework Setup\NDP\v4\Full\Release")
    if (err.number = 0) then
      if ((installed = "1") and (release >= "3783889")) then
        CheckNET = true
      elseif ((installed <> "1") or (release < "378389")) then
        CheckNET = false
      end if
    elseif (err.number <> 0) then
      CheckNET = false
    end if
  elseif (err.number <> 0) then
    CheckNET = false
  end if
end function

''SUB-ROUTINES
sub FILEDL(strURL, strDL, strFILE)                          ''CALL HOOK TO DOWNLOAD FILE FROM URL , 'ERRRET'=11
  strSAV = vbnullstring
  ''SET DOWNLOAD PATH
  strSAV = strDL & "\" & strFILE
  objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & vbtab & "HTTPDOWNLOAD-------------DOWNLOAD : " & strURL & " : SAVE AS :  " & strSAV
  objLOG.write vbnewline & vbnewline & now & vbtab & vbtab & vbtab & "HTTPDOWNLOAD-------------DOWNLOAD : " & strURL & " : SAVE AS :  " & strSAV
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
    objOUT.write vbnewline & now & vbtab & vbtab & " - DOWNLOAD : " & strSAV & " : SUCCESSFUL"
    objLOG.write vbnewline & now & vbtab & vbtab & " - DOWNLOAD : " & strSAV & " : SUCCESSFUL"
  end if
	set objHTTP = nothing
  if ((err.number <> 0) and (err.number <> 58)) then        ''ERROR RETURNED DURING DOWNLOAD , 'ERRRET'=11
    call LOGERR(11)
  end if
end sub

sub HOOK(strCMD)                                            ''CALL HOOK TO MONITOR OUTPUT OF CALLED COMMAND , 'ERRRET'=12
  on error resume next
  objOUT.write vbnewline & now & vbtab & vbtab & " - EXECUTING : HOOK(" & strCMD & ")"
  objLOG.write vbnewline & now & vbtab & vbtab & " - EXECUTING : HOOK(" & strCMD & ")"
  set objHOOK = objWSH.exec(strCMD)
  if (instr(1, strCMD, "takeown /F ") = 0) then             ''SUPPRESS 'TAKEOWN' SUCCESS MESSAGES
    while (not objHOOK.stdout.atendofstream)
      strIN = objHOOK.stdout.readline
      if (strIN <> vbnullstring) then
        objOUT.write vbnewline & now & vbtab & vbtab & vbtab & strIN 
        objLOG.write vbnewline & now & vbtab & vbtab & vbtab & strIN 
      end if
      wscript.sleep 10
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
    case 2                                                  '' 'ERRRET'=2 - OS NOT SUPPORTED
      objOUT.write vbewline & now & vbtab & vbtab & vbtab & "OS:NOT SUPPORTED"
      objLOG.write vbewline & now & vbtab & vbtab & vbtab & "OS:NOT SUPPORTED"
  end select
end sub

sub CLEANUP()                                               ''SCRIPT CLEANUP
  on error resume next
  if (errRET = 0) then                                      ''SCRIPT COMPLETED SUCCESSFULLY
    objOUT.write vbnewline & vbnewline & now & vbtab & " - INSTALL_POWERSHELL SUCCESSFUL : " & now
    objLOG.write vbnewline & vbnewline & now & vbtab & " - INSTALL_POWERSHELL SUCCESSFUL : " & now
    err.clear
  elseif (errRET <> 0) then                                 ''SCRIPT FAILED
    objOUT.write vbnewline & vbnewline & now & vbtab & " - INSTALL_POWERSHELL FAILURE : " & errRET & " : " & now
    objLOG.write vbnewline & vbnewline & now & vbtab & " - INSTALL_POWERSHELL FAILURE : " & errRET & " : " & now
    ''RAISE CUSTOMIZED ERROR CODE , ERROR CODE WILL BE DEFINED RESTOP NUMBER INDICATING WHICH SECTION FAILED
    call err.raise(vbObjectError + errRET, "INSTALL_POWERSHELL", "fail")
  end if
  objOUT.write vbnewline & vbnewline & now & " - INSTALL_POWERSHELL COMPLETE" & vbnewline
  objLOG.write vbnewline & vbnewline & now & " - INSTALL_POWERSHELL COMPLETE" & vbnewline
  objLOG.close
  ''EMPTY OBJECTS
  set objEXEC = nothing
  set objWMI = nothing
  set objNET = nothing
  set objLOG = nothing
  set objFSO = nothing
  set objWSH = nothing
  set objARG = nothing
  set objOUT = nothing
  set objIN = nothing
  ''END SCRIPT , RETURN ERROR
  wscript.quit err.number
end sub