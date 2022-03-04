'on error resume next
''REGISTRY CONSTANTS
const HKCR = &H80000000
const HKLM = &H80000002
''SCRIPT VARIABLES
dim strOS, strBIT
dim strZIP, strPATH, strKEY, uVAL
dim objWMI, objNET, objNAME, objREG
dim objSHELL, objTGT, objHTTP
dim objIN, objOUT, objARG, objWSH, objFSO, objLOG
''STDIN / STDOUT
set objIN = wscript.stdin
set objOUT = wscript.stdout
set objARG = wscript.arguments
''OBJECTS FOR LOCATING FOLDERS
strPATH = "C:\temp\"
set objWSH = createobject("wscript.shell")
set objFSO = createobject("scripting.filesystemobject")
''OBJECTS FOR CONNECTING TO REGISTRY PROVIDER
Set objWMI = createObject("WbemScripting.SWbemLocator")
Set objNET = createObject("WScript.Network")
''CONNECT TO REGISTRY PROVIDER
Set objNAME = objWMI.ConnectServer(objNET.ComputerName, "root\default")
Set objREG = objNAME.Get("StdRegProv")
''CHECK EXECUTION METHOD OF SCRIPT
strIN = lcase(mid(wscript.fullname, instrrev(wscript.fullname, "\") + 1))
if (strIN <> "cscript.exe") Then
  objOUT.write vbnewline & "SCRIPT LAUNCHED VIA EXPLORER, EXECUTING SCRIPT VIA CSCRIPT..."
  objWSH.run "cscript.exe //nologo " & chr(34) & Wscript.ScriptFullName & chr(34)
  wscript.quit
end if
''PREPARE LOGFILE
if (objFSO.fileexists("C:\temp\meltspec")) then      ''LOGFILE EXISTS
  objFSO.deletefile "C:\temp\meltspec", true
  set objLOG = objFSO.createtextfile("C:\temp\meltspec")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\meltspec", 8)
else                                                  ''LOGFILE NEEDS TO BE CREATED
  set objLOG = objFSO.createtextfile("C:\temp\meltspec")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\meltspec", 8)
end if
objOUT.write vbnewline & now & " - STARTING MELTSPEC" & vbnewline
objLOG.write vbnewline & now & " - STARTING MELTSPEC" & vbnewline
''PREREQ CHECK
objOUT.write vbnewline & now & vbtab & " - CHECKING PRE-REQUISITES"
objLOG.write vbnewline & now & vbtab & " - CHECKING PRE-REQUISITES"
''.NET CHECK
objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & " - CHECKING .NET PRE-REQ"
objLOG.write vbnewline & vbnewline & now & vbtab & vbtab & " - CHECKING .NET PRE-REQ"
strKEY = "SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full"
objREG.getdwordvalue HKLM, strKEY, "Release", uVAL
if (uVAL >= 461308) then
   'return "4.7.1 or later";
elseif (uVAL >= 460798) then
   'return "4.7";
elseif (uVAL >= 394802) then
   'return "4.6.2";
elseif (uVAL >= 394254) then
   'return "4.6.1";
elseif (uVAL >= 393295) then
   'return "4.6";
elseif (uVAL >= 379893) then
   'return "4.5.2";
else
  objOUT.write vbnewline & now & vbtab & vbtab & " - .NET PRE-REQ NOT MET."
  objLOG.write vbnewline & now & vbtab & vbtab & " - .NET PRE-REQ NOT MET."
end if
''OS CHECK
objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & " - CHECKING OS PRE-REQ"
objLOG.write vbnewline & vbnewline & now & vbtab & vbtab & " - CHECKING OS PRE-REQ"
strCMD = "systeminfo" ''| findstr /B /C:" & chr(34) & "OS Name" & chr(34) & " /C:" & chr(34) & "OS Version" & chr(34) & " /C:" & chr(34) & "System Type" & chr(34)
set objHOOK = objWSH.exec(strCMD)
while (not objHOOK.stdout.atendofstream)
  strIN = objHOOK.stdout.readline
  if (strIN <> vbnullstring) then
    if (instr(1, strIN, "OS Name")) then
      strOS = trim(split(strIN,":")(1))
    elseif (instr(1, strIN, "OS Version")) then
    elseif (instr(1, strIN, "System Type")) then
      strBIT = trim(split(strIN,":")(1))
    end if
  end if
  strIN = vbnullstring
wend
wscript.sleep 10
set objHOOK = nothing
if (err.number <> 0) then
  objOUT.write vbnewline & now & vbtab & vbtab & err.number & vbtab & err.description
  objLOG.write vbnewline & now & vbtab & vbtab & err.number & vbtab & err.description
end if
objOUT.write vbnewline & now & vbtab & vbtab & vbtab & " - DETECTED : " & strOS
objLOG.write vbnewline & now & vbtab & vbtab & vbtab & " - DETECTED : " & strOS
objOUT.write vbnewline & now & vbtab & vbtab & vbtab & " - DETECTED : " & strBIT
objLOG.write vbnewline & now & vbtab & vbtab & vbtab & " - DETECTED : " & strBIT
''INSTALL WMF5.1
objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & " - INSTALLING WMF5.1"
objLOG.write vbnewline & vbnewline & now & vbtab & vbtab & " - INSTALLING WMF5.1"
''WINDOWS 7
if instr(1, strOS, "Windows 7") then
  if instr(1, lcase(strBIT), "x86") then
    call FILEDL("http://download638.mediafire.com/9vev9v5cvarg/96ml7zcan6eytmx/Win7-KB3191566-x86.msu", "WIN7x86-WMF5.1.msu")
    'call FILEDL("https://go.microsoft.com/fwlink/?linkid=839522", "WIN7x86-WMF5.1.zip")
    'call UZIP(strPATH & "WIN7x86-WMF5.1.zip", strPATH & "WIN7x86-WMF5.1")
    call HOOK("wusa " & chr(34) & strPATH & "WIN7x86-WMF5.1.msu" & chr(34) & "/quiet /norestart")
  elseif instr(1, lcase(strBIT), "x64") then
    call FILEDL("http://download2086.mediafire.com/17jr7ac2mzxg/0balt6tlhtdw7ii/Win7AndW2K8R2-KB3191566-x64.msu", "SRV2008WIN7x64-WMF5.1.msu")
    'call UZIP(strPATH & "SRV2008WIN7x64-WMF5.1.zip", strPATH & "SRV2008WIN7x64-WMF5.1")
    call HOOK("wusa " & chr(34) & strPATH & "SRV2008WIN7x64-WMF5.1.msu" & chr(34) & "/quiet /norestart")
  end if
''WINDOWS 8
elseif instr(1, strOS, "Windows 8.1") then
  if instr(1, lcase(strBIT), "x86") then
    call FILEDL("http://download1412.mediafire.com/4j2nv97mgzwg/e14qa7bc81dbv6f/Win8.1-KB3191564-x86.msu", "WIN8SRV2012R2x86-WMF5.1.msu")
    'call FILEDL("https://go.microsoft.com/fwlink/?linkid=839521", "WIN8SRV2012R2x86-WMF5.1.msu")
    call HOOK("wusa " & chr(34) & strPATH & "WIN8SRV2012R2x86-WMF5.1.msu" & chr(34) & "/quiet /norestart")
  elseif instr(1, lcase(strBIT), "x64") then
    call FILEDL("http://download2263.mediafire.com/7adpx2t9d4hg/m5257dlazs5m9zw/Win8.1AndW2K12R2-KB3191564-x64.msu", "WIN8SRV2012R2x64-WMF5.1.msu")
    call HOOK("wusa " & chr(34) & strPATH & "WIN8SRV2012R2x64-WMF5.1.msu" & chr(34) & "/quiet /norestart")
  end if
''SERVER 2012
elseif instr(1, strOS, "Windows Server 2012") then
  if instr(1, strOS, "2012 R2") then
    call FILEDL("http://download2263.mediafire.com/7adpx2t9d4hg/m5257dlazs5m9zw/Win8.1AndW2K12R2-KB3191564-x64.msu", "WIN8SRV2012R2x64-WMF5.1.msu")
    'call FILEDL("https://go.microsoft.com/fwlink/?linkid=839516", "WIN8SRV2012R2x64-WMF5.1.msu")
    call HOOK("wusa " & chr(34) & strPATH & "WIN8SRV2012R2x64-WMF5.1.msu" & chr(34) & "/quiet /norestart")
  else
    call FILEDL("http://download825.mediafire.com/y9bv7px6jrxg/s687a4i2wbwkxdl/W2K12-KB3191565-x64.msu", "SRV2012x64-WMF5.1.msu")
    'call FILEDL("https://go.microsoft.com/fwlink/?linkid=839513", "SRV2012x64-WMF5.1.msu")
    call HOOK("wusa " & chr(34) & strPATH & "SRV2012x64-WMF5.1.msu" & chr(34) & "/quiet /norestart")
  end if
''SERVER 2008
elseif instr(1, strOS, "Windows Server 2008 R2") then
  call FILEDL("http://download2086.mediafire.com/17jr7ac2mzxg/0balt6tlhtdw7ii/Win7AndW2K8R2-KB3191566-x64.msu", "SRV2008WIN7x64-WMF5.1.msu")
  'call UZIP(strPATH & "SRV2008WIN7x64-WMF5.1.zip", strPATH & "SRV2008WIN7x64-WMF5.1")
  call HOOK("wusa " & chr(34) & strPATH & "SRV2008WIN7x64-WMF5.1.msu" & chr(34) & "/quiet /norestart")
end if
objOUT.write vbnewline & now & vbtab & vbtab & " - WMF5.1 INSTALLED"
objLOG.write vbnewline & now & vbtab & vbtab & " - WMF5.1 INSTALLED"
''DOWNLOAD 'SPECULATIONCONTROL' POWERSHELL MODULE
''https://gallery.technet.microsoft.com/scriptcenter/Speculation-Control-e36f0050/file/190138/1/SpeculationControl.zip
objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & " - DOWNLOADING 'SPECULATIONCONTROL' POWERSHELL MODULE"
objLOG.write vbnewline & vbnewline & now & vbtab & vbtab & " - DOWNLOADING 'SPECULATIONCONTROL' POWERSHELL MODULE"
blnDL = false
call FILEDL("http://download1466.mediafire.com/0e6j1nhp06eg/mrmv676e7dhhhkd/SpeculationControl.zip", "SpeculationControl.zip")
while (blnDL = false)
  wscript.sleep 1000
wend
wscript.sleep 1000
''UNZIP 'SPECULATIONCONTROL' POWERSHELL MODULE
call UZIP(strPATH & "SpeculationControl.zip", strPATH & "SpeculationControl")
''CHECK FOR EXTRACTED FOLDER
if (objFSO.folderexists("C:\temp\SpeculationControl")) then
  ''CREATE 'MELTSPEC.PS1' POWERSHELL SCRIPT
  set objTGT = nothing
  set objTGT = objFSO.createtextfile("c:\temp\SpeculationControl\meltspec.ps1")
  objTGT.write "# Save the current execution policy so it can be reset" & vbnewline & "$SaveExecutionPolicy = Get-ExecutionPolicy" & vbnewline & _
    "Set-ExecutionPolicy RemoteSigned -Scope Currentuser" & vbnewline & "Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -force -confirm:$false" & vbnewline & _
    "CD " & chr(34) & "C:\temp\SpeculationControl" & chr(34) & vbnewline & "Install-Module SpeculationControl -force -confirm:$false" & vbnewline & _
    "Import-Module SpeculationControl.psd1" & vbnewline & "Import-Module SpeculationControl.psm1" & vbnewline & "Get-SpeculationControlSettings" & vbnewline & _
    "# Reset the execution policy to the original state" & vbnewline & "Set-ExecutionPolicy $SaveExecutionPolicy -Scope Currentuser"
  objTGT.close
  set objTGT = nothing
  ''RUN POWERSHELL, INSTALL 'SPECULATIONCONTROL' MODULE, RUN SPECULATIONCONTROL CHECKS
  objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & " - INSTALLING 'SPECULATIONCONTROL' POWERSHELL MODULE, RUNNING SPECULATIONCONTROL CHECK" & vbnewline
  objLOG.write vbnewline & vbnewline & now & vbtab & vbtab & " - INSTALLING 'SPECULATIONCONTROL' POWERSHELL MODULE, RUNNING SPECULATIONCONTROL CHECK" & vbnewline
  call HOOK("powershell -executionpolicy bypass -windowstyle hidden -file " & chr(34) & "c:\temp\SpeculationControl\meltspec.ps1" & chr(34))
end if
''END SCRIPT
call CLEANUP()

''SUB-ROUTINES
sub UZIP(strZIP, strFOL)
'on error resume next
  dim objSRC, objDST
  intOPT = 4
  objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & vbtab & " - EXTRACTING " & strZIP
  objLOG.write vbnewline & vbnewline & now & vbtab & vbtab & vbtab & " - EXTRACTING " & strZIP
  set objSHELL = createobject("Shell.Application")
  set objSRC = objSHELL.NameSpace(strZIP).items()
  set objDST = objSHELL.NameSpace(strPATH)
  ''CHECK FOR EXTRACTED FOLDER, DELETE TO PREVENT OVERWRITE HANG
  if (objFSO.folderexists(strFOL)) then
    objFSO.deletefolder strFOL, true
  end if
  objDST.CopyHere objSRC, intOPT
  ''CHECK FOR EXTRACTED FOLDER
  if (objFSO.folderexists(strFOL)) then
    objOUT.write vbnewline & now & vbtab & vbtab & vbtab & " - " & strZIP & " EXTRACTED"
    objLOG.write vbnewline & now & vbtab & vbtab & vbtab & " - " & strZIP & " EXTRACTED"
  end if
  set objSRC = nothing
  set objDST = nothing
end sub

sub FILEDL(strURL, strFILE)                           ''CALL HOOK TO DOWNLOAD FILE FROM URL
  strSAV = vbnullstring
  ''SET DOWNLOAD PATH
  strSAV = strPATH & strFILE
  objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "HTTPDOWNLOAD-------------DOWNLOAD : " & strURL & " : SAVE AS :  " & strSAV
  objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "HTTPDOWNLOAD-------------DOWNLOAD : " & strURL & " : SAVE AS :  " & strSAV
  ''CREATE HTTP OBJECT
  set objHTTP = createobject( "WinHttp.WinHttpRequest.5.1" )
  ''DOWNLOAD FROM URL
  objHTTP.open "GET", strURL, false
  objHTTP.send
  ''DOWNLOAD FROM URL
  objHTTP.open "GET", strURL, false
  objHTTP.send
  if objFSO.fileexists(strSAV) then
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
  if objFSO.fileexists(strSAV) then
    objOUT.write vbnewline & now & vbtab & vbtab & vbtab & " - DOWNLOAD : " & strSAV & " : SUCCESSFUL"
    objLOG.write vbnewline & now & vbtab & vbtab & vbtab & " - DOWNLOAD : " & strSAV & " : SUCCESSFUL"
    if (strFILE = "SpeculationControl.zip") then
      blnDL = true
    end if
  end if
  set objHTTP = nothing
end sub

sub HOOK(strCMD)                                      ''CALL HOOK TO MONITOR OUTPUT OF CALLED COMMAND
  on error resume next
  strIN = vbnullstring
  'comspec = objWSH.ExpandEnvironmentStrings("%comspec%")
  set objHOOK = objWSH.exec(strCMD)
  'while (objHOOK.status = 0)
    while (not objHOOK.stdout.atendofstream)
      strIN = objHOOK.stdout.readline
      if (strIN <> vbnullstring) then
        objOUT.write vbnewline & now & vbtab & vbtab & vbtab & strIN 
        objLOG.write vbnewline & now & vbtab & vbtab & vbtab & strIN 
      end if
    wend
    wscript.sleep 10
  'wend
  strIN = objHOOK.stdout.readall
  if (strIN <> vbnullstring) then
    objOUT.write vbnewline & now & vbtab & vbtab & vbtab & strIN 
    objLOG.write vbnewline & now & vbtab & vbtab & vbtab & strIN 
  end if
  'retSTOP = objHOOK.exitcode
  set objHOOK = nothing
  if (err.number <> 0) then
    objOUT.write vbnewline & now & vbtab & vbtab & vbtab & err.number & vbtab & err.description
    objLOG.write vbnewline & now & vbtab & vbtab & vbtab & err.number & vbtab & err.description
  end if
end sub

sub CLEANUP()                                         ''SCRIPT CLEANUP
  objOUT.write vbnewline & vbnewline & now & " - MELTSPEC COMPLETE." & vbnewline
  objLOG.write vbnewline & vbnewline & now & " - MELTSPEC COMPLETE." & vbnewline
  objLOG.close
  ''EMPTY OBJECTS
  set objSHELL = nothing
  set objLOG = nothing
  set objFSO = nothing
  set objWSH = nothing
  set objARG = nothing
  set objOUT = nothing
  set objIN = nothing
  ''END SCRIPT, RETURN ERROR NUMBER
  wscript.quit err.number
end sub