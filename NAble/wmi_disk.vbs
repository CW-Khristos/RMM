on error resume next
''DEFINE VARIABLES
dim strCOMP, colDISK
dim objIN, objOUT, objWSH, objWMI, objREF
''CREATE SCRIPTING OBJECTS
strCOMP = "."
set objIN = wscript.stdin
set objOUT = wscript.stdout
set objWSH = createobject("wscript.shell")
Set objWMI = GetObject("winmgmts:" & "{impersonationLevel=impersonate}!\\" & strCOMP & "\root\cimv2")
set objREF = CreateObject("WbemScripting.SWbemRefresher")
''CHECK EXECUTION METHOD OF SCRIPT
strIN = lcase(mid(wscript.fullname, instrrev(wscript.fullname, "\") + 1))
if (strIN <> "cscript.exe") Then
  objOUT.write vbnewline & "SCRIPT LAUNCHED VIA EXPLORER, EXECUTING SCRIPT VIA CSCRIPT..."
  objWSH.run "cscript.exe //nologo " & chr(34) & Wscript.ScriptFullName & chr(34)
  wscript.quit
end if
''ENUMERATE DISK I/O STATISTICS
set colDISK = objREF.AddEnum (objWMI, "win32_perfformatteddata_perfdisk_logicaldisk").objectSet
objREF.Refresh
objOUT.write vbnewline & "ENUMERATING DISK I/O STATISTICS : " & now
For Each objDISK in colDISK
        objOUT.write vbnewline & vbnewline & "Disk Name: " & vbtab & vbtab & vbTab &  objDISK.name
        objOUT.write vbnewline & vbTab & "Average Disk Queue Length: " & vbTab &  objDISK.AvgDiskQueueLength
        objOUT.write vbnewline & vbTab & "Current Disk Queue Length: " & vbTab &  objDISK.CurrentDiskQueueLength
        objOUT.write vbnewline & vbTab & "Disk Read Times (%): " & vbtab & vbTab &  objDISK.PercentDiskReadTime
        objOUT.write vbnewline & vbTab & "Average Disk Read (per Sec.): " & vbTab &  objDISK.AvgDiskSecPerRead
        objOUT.write vbnewline & vbTab & "Disk Write Time (%): " & vbtab & vbTab &  objDISK.PercentDiskWriteTime
        objOUT.write vbnewline & vbTab & "Average Disk Write (per Sec.): " & vbTab &  objDISK.AvgDiskSecPerWrite
        objOUT.write vbnewline & vbTab & "Disk Idle Time (%): " & vbTab & vbtab &  objDISK.PercentIdleTime
Next
objOUT.write vbnewline & "COMPLETED ENUMERATING DISK I/O STATISTICS : " & now

''SCRIPT CLEANUP
if (err.number <> 0) then
  objOUT.write vbnewline & vbnewline & "ERROR : " & err.number & " : " & err.description
end if
set objDSIK = nothing
set colDISK = nothing
set objREF = nothing
set objWMI = nothing
set objWSH = nothing
set objOUT = nothing
set objIN = nothing
wscript.quit err.number

''WMI COMMANDS
''systeminfo
''Set colDISK = objREF.AddEnum (objWMI, "win32_logicaldisk").objectSet
''wmic logicaldisk get caption,description,drivetype,providername,volumename
''wmic diskdrive list /format:list
'DISK STATUS - wmic /node:. /namespace:\\root\cimv2 path win32_perfformatteddata_perfdisk_logicaldisk get /all
'SMART STATUS - wmic /node:. /namespace:\\root\wmi path MSStorageDriver_FailurePredictStatus get /all