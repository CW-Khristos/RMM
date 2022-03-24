<# 
.SYNOPSIS 

.DESCRIPTION 

.NOTES

.CHANGELOG

.TODO

#> 

#REGION ----- DECLARATIONS ----
  $disks = @{}
#ENDREGION ----- DECLARATIONS ----

#REGION ----- FUNCTIONS ----

#ENDREGION ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
#First Clear any variables
Remove-Variable * -ErrorAction SilentlyContinue
#Start script execution time calculation
$ScrptStartTime = (Get-Date).ToString('dd-MM-yyyy hh:mm:ss')
$sw = [Diagnostics.Stopwatch]::StartNew()

$ldisks = Get-CimInstance 'Win32_PerfFormattedData_PerfDisk_LogicalDisk' | where Name -match ":"

foreach ($disk in $ldisks) {
  write-host "`r`nPOLLING DISK : $($disk.name)`r`n"
  $dque = $disk.CurrentDiskQueueLength
  write-host ("Current Disk Queue : $($dque)").toupper()
  $daque = $disk.AvgDiskQueueLength
  $daque
  write-host ("Avg. Disk Queue : $($daque)").toupper()
  $darque = $disk.AvgDiskReadQueueLength
  write-host ("Avg. Disk Read Queue : $($darque)").toupper()
  $dawque = $disk.AvgDiskWriteQueueLength
  write-host ("Avg. Disk Write Queue : $($dawque)").toupper()

  $dtime = $disk.PercentDiskTime
  write-host ("Disk Time (%) : $($dtime)%").toupper()
  $drtime = $disk.PercentDiskReadTime
  write-host ("Disk Read Time (%) : $($dque ) %").toupper()
  $dwtime = $disk.PercentDiskWriteTime
  write-host ("Disk Write Time (%) : $($dwtime) %").toupper()
  $didle = $disk.PercentIdleTime
  write-host ("Idle Time (%) : $($didle) %").toupper()
  $dio = $disk.SplitIOPerSec
  write-host ("Split IO/Sec : $($dio)").toupper()

  $drsec = $disk.DiskReadsPersec
  write-host ("Disk Reads/sec : $($drsec)").toupper()
  $dasr = $disk.AvgDisksecPerRead
  write-host ("Avg. Disk sec/Read : $($dasr)").toupper()
  $dabr = ($disk.AvgDiskBytesPerRead / 1024)
  write-host ("Avg. Disk Bytes/Read : $($dabr)").toupper()

  $dwsec = $disk.DiskWritesPersec
  write-host ("Disk Writes/sec : $($dwsec)").toupper()
  $dasw = $disk.AvgDisksecPerWrite
  write-host ("Avg. Disk sec/Write : $($dasw)").toupper()
  $dabw = ($disk.AvgDiskBytesPerWrite / 1024)
  write-host ("Avg. Disk Bytes/Write : $($dabw)").toupper()

  $dbsec = ($disk.DiskBytesPersec / 1024)
  write-host ("Disk Bytes/sec : $($dbsec)").toupper()
  $drbs = ($disk.DiskReadBytesPersec / 1024)
  write-host ("Disk Read Bytes/sec : $($drbs)").toupper()
  $dwbs = ($disk.DiskWriteBytesPersec / 1024)
  write-host ("Disk Write Bytes/sec: $($dwbs)").toupper()

  $dtsec = $disk.DiskTransfersPersec
  write-host ("Disk Transfers/sec : $($dtsec)").toupper()
  $dast = $disk.AvgDisksecPerTransfer
  write-host ("Avg. Disk sec/Transfer : $($dast)").toupper()
  $dabt = ($disk.AvgDiskBytesPerTransfer / 1024)
  write-host ("Avg. Disk Bytes/Transfer : $($dabt)").toupper()
}

#Stop script execution time calculation
$sw.Stop()
$Days = $sw.Elapsed.Days
$Hours = $sw.Elapsed.Hours
$Minutes = $sw.Elapsed.Minutes
$Seconds = $sw.Elapsed.Seconds
$Milliseconds = $sw.Elapsed.Milliseconds
$ScriptStopTime = (Get-Date).ToString('dd-MM-yyyy hh:mm:ss')
$total = ((((($Hours * 60) + $Minutes) * 60) + $Seconds) * 1000) + $Milliseconds
$average = (($total / 1) / 1000)
$mill = [string]$average
$mill = $mill.split(".")[1]
$mill = $mill.SubString(0,[math]::min(3,$mill.length) )
write-host "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds"
write-host "Avg. Execution Time - $([math]::round($average / 60)) Minutes : $([math]::round($average)) Seconds : $($mill) Milliseconds per Call"