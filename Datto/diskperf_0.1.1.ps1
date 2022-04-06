<# 
.SYNOPSIS
    All-Inclusive Disk Performance Monitor

.DESCRIPTION
    Collects Disk Performance Statistics for all connected drives with at least 1 partition with a drive letter assigned
    Performance Statistics for each drive are queried and collected separately

.NOTES
    Version        : 0.1.1 (28 March 2022)
    Creation Date  : 24 March 2022
    Purpose/Change : Provide Primary AV Product Status and Report Possible AV Conflicts
    File Name      : diskperf_0.1.1.ps1 
    Author         : Christopher Bledsoe - cbledsoe@ipmcomputers.com
    Thanks         : Chris Taylor (christaylor.codes ) for objectively providing the best answer

.CHANGELOG
    0.1.0 Initial Release
    0.1.1 Added configurable thresholds
          Switch to populated Disk Performance Warnings in hashtable

.TODO

#>

#REGION ----- DECLARATIONS ----
  $script:disks = @{}
  $script:diag = $null
  $script:blnADD = $false
  $script:blnWMI = $false
  $script:blnWARN = $false
  $script:diskWARN = $false
#ENDREGION ----- DECLARATIONS ----

#REGION ----- FUNCTIONS ----
  function write-DRMMDiag ($messages) {
    write-host  '<-Start Diagnostic->'
    foreach ($Message in $Messages) {$Message}
    write-host '<-End Diagnostic->'
  } ## write-DRMMDiag
  
  function write-DRRMAlert ($message) {
    write-host '<-Start Result->'
    write-host "Alert=$($message)"
    write-host '<-End Result->'
  } ## write-DRRMAlert

  function Pop-Warnings {
    param (
      $dest, $disk, $warn
    )
    #POPULATE DISK WARNINGS DATA INTO NESTED HASHTABLE FORMAT FOR LATER USE
    try {
      if (($disk -ne $null) -and ($disk -ne "")) {
        if ($dest.containskey($disk)) {
          $new = [System.Collections.ArrayList]@()
          $prev = [System.Collections.ArrayList]@()
          $script:blnADD = $true
          $prev = $dest[$disk]
          $prev = $prev.split("`r`n",[System.StringSplitOptions]::RemoveEmptyEntries)
          if ($prev -contains $warn) {
            $script:blnADD = $false
          }
          if ($script:blnADD) {
            foreach ($itm in $prev) {
              $new.add("$($itm)`r`n")
            }
            $new.add("$($warn)`r`n")
            $dest.remove($disk)
            $dest.add($disk, $new)
            $script:blnWARN = $true
            $script:diskWARN = $true
          }
        } elseif (-not $dest.containskey($disk)) {
          $new = [System.Collections.ArrayList]@()
          $new = "$($warn)`r`n"
          $dest.add($disk, $new)
          $script:blnWARN = $true
          $script:diskWARN = $true
        }
      }
    } catch {
      $warndiag = "Disk Performance : Error populating warnings for $($disk)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n"
      write-host "Disk Performance : Error populating warnings for $($disk)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n"
      write-host $_.scriptstacktrace
      write-host $_
      $script:diag += "$($warndiag)"
      $warndiag = $null
    }
  } ## Pop-Warnings

  function chkPERF ($objDRV) {
    if (($objDRV.CurrentDiskQueueLength -ne $null) -and ($objDRV.CurrentDiskQueueLength -gt $env:varCurrentDiskQueueLength)) {Pop-Warnings $script:disks $objDRV.name "  - CurrentDiskQueueLength (Current Threshold : $($env:varCurrentDiskQueueLength))`r`n"}
    if (($objDRV.AvgDiskQueueLength -ne $null) -and ($objDRV.AvgDiskQueueLength -gt $env:varAvgDiskQueueLength)) {Pop-Warnings $script:disks $objDRV.name "  - AvgDiskQueueLength (Current Threshold : $($env:varAvgDiskQueueLength))`r`n"}
    if (($objDRV.AvgDiskReadQueueLength -ne $null) -and ($objDRV.AvgDiskReadQueueLength -gt $env:varAvgDiskReadQueueLength)) {Pop-Warnings $script:disks $objDRV.name "  - AvgDiskReadQueueLength (Current Threshold : $($env:varAvgDiskReadQueueLength))`r`n"}
    if (($objDRV.AvgDiskWriteQueueLength -ne $null) -and ($objDRV.AvgDiskWriteQueueLength -gt $env:varAvgDiskWriteQueueLength)) {Pop-Warnings $script:disks $objDRV.name "  - AvgDiskWriteQueueLength (Current Threshold : $($env:varAvgDiskWriteQueueLength))`r`n"}

    if (($objDRV.PercentDiskTime -ne $null) -and ($objDRV.PercentDiskTime -ge $env:varPercentDiskTime)) {Pop-Warnings $script:disks $objDRV.name "  - PercentDiskTime (Current Threshold : $($env:varPercentDiskTime))`r`n"}
    if (($objDRV.PercentDiskReadTime -ne $null) -and ($objDRV.PercentDiskReadTime -ge $env:varPercentDiskReadTime)) {Pop-Warnings $script:disks $objDRV.name "  - PercentDiskReadTime (Current Threshold : $($env:varPercentDiskReadTime))`r`n"}
    if (($objDRV.PercentDiskWriteTime -ne $null) -and ($objDRV.PercentDiskWriteTime -ge $env:varPercentDiskWriteTime)) {Pop-Warnings $script:disks $objDRV.name "  - PercentDiskWriteTime (Current Threshold : $($env:varPercentDiskWriteTime))`r`n"}
    if (($objDRV.PercentIdleTime -ne $null) -and ($objDRV.PercentIdleTime -le $env:varPercentIdleTime)) {Pop-Warnings $script:disks $objDRV.name "  - PercentIdleTime (Current Threshold : $($env:varPercentIdleTime))`r`n"}
    if (($objDRV.SplitIOPerSec -ne $null) -and ($objDRV.SplitIOPerSec -gt $env:varSplitIOPerSec)) {Pop-Warnings $script:disks $objDRV.name "  - SplitIOPerSec (Current Threshold : $($env:varSplitIOPerSec))`r`n"}

    if (($objDRV.DiskReadsPersec -ne $null) -and ($objDRV.DiskReadsPersec -gt $env:varDiskReadsPersec)) {Pop-Warnings $script:disks $objDRV.name "  - DiskReadsPersec (Current Threshold : $($env:varDiskReadsPersec))`r`n"}
    #if (($objDRV.AvgDisksecPerRead -ne $null) -and ($objDRV.AvgDisksecPerRead -gt $env:varAvgDisksecPerRead)) {Pop-Warnings $script:disks $objDRV.name "  - AvgDisksecPerRead (Current Threshold : $($env:varAvgDisksecPerRead))`r`n"}
    if (($objDRV.AvgDiskBytesPerRead -ne $null) -and ($objDRV.AvgDiskBytesPerRead -gt $env:varAvgDiskBytesPerRead)) {Pop-Warnings $script:disks $objDRV.name "  - AvgDiskBytesPerRead (Current Threshold : $($env:varAvgDiskBytesPerRead))`r`n"}

    if (($objDRV.DiskWritesPersec -ne $null) -and ($objDRV.DiskWritesPersec -gt $env:varDiskWritesPersec)) {Pop-Warnings $script:disks $objDRV.name "  - DiskWritesPersec (Current Threshold : $($env:varDiskWritesPersec))`r`n"}
    #if (($objDRV.AvgDisksecPerWrite -ne $null) -and ($objDRV.AvgDisksecPerWrite -gt $env:varAvgDisksecPerWrite)) {Pop-Warnings $script:disks $objDRV.name "  - AvgDisksecPerWrite (Current Threshold : $($env:varAvgDisksecPerWrite))`r`n"}
    if (($objDRV.AvgDiskBytesPerWrite -ne $null) -and ($objDRV.AvgDiskBytesPerWrite -gt $env:varAvgDiskBytesPerWrite)) {Pop-Warnings $script:disks $objDRV.name "  - AvgDiskBytesPerWrite (Current Threshold : $($env:varAvgDiskBytesPerWrite))`r`n"}

    if (($objDRV.DiskBytesPersec -ne $null) -and ($objDRV.DiskBytesPersec -gt $env:varDiskBytesPersec)) {Pop-Warnings $script:disks $objDRV.name "  - DiskBytesPersec (Current Threshold : $($env:varDiskBytesPersec))`r`n"}
    if (($objDRV.DiskReadBytesPersec -ne $null) -and ($objDRV.DiskReadBytesPersec -gt $env:varDiskReadBytesPersec)) {Pop-Warnings $script:disks $objDRV.name "  - DiskReadBytesPersec (Current Threshold : $($env:varDiskReadBytesPersec))`r`n"}
    if (($objDRV.DiskWriteBytesPersec -ne $null) -and ($objDRV.DiskWriteBytesPersec -gt $env:varDiskWriteBytesPersec)) {Pop-Warnings $script:disks $objDRV.name "  - DiskWriteBytesPersec (Current Threshold : $($env:varDiskWriteBytesPersec))`r`n"}

    if (($objDRV.DiskTransfersPersec -ne $null) -and ($objDRV.DiskTransfersPersec -gt $env:varDiskTransfersPersec)) {Pop-Warnings $script:disks $objDRV.name "  - DiskTransfersPersec (Current Threshold : $($env:varDiskTransfersPersec))`r`n"}
    #if (($objDRV.AvgDisksecPerTransfer -ne $null) -and ($objDRV.AvgDisksecPerTransfer -gt $env:varAvgDisksecPerTransfer)) {Pop-Warnings $script:disks $objDRV.name "  - AvgDisksecPerTransfer (Current Threshold : $($env:varAvgDisksecPerTransfer))`r`n"}
    if (($objDRV.AvgDiskBytesPerTransfer -ne $null) -and ($objDRV.AvgDiskBytesPerTransfer -gt $env:varAvgDiskBytesPerTransfer)) {Pop-Warnings $script:disks $objDRV.name "  - AvgDiskBytesPerTransfer (Current Threshold : $($env:varAvgDiskBytesPerTransfer))`r`n"}
  } ## chkSMART
#ENDREGION ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
#Start script execution time calculation
$ScrptStartTime = (Get-Date).ToString('dd-MM-yyyy hh:mm:ss')
$sw = [Diagnostics.Stopwatch]::StartNew()
#DOUBLE-CHECK PASSED THRESHOLDS
if (($env:varCurrentDiskQueueLength -eq $null) -or ($env:varCurrentDiskQueueLength -eq "")) {$env:varCurrentDiskQueueLength = 2}
if (($env:varAvgDiskQueueLength -eq $null) -or ($env:varAvgDiskQueueLength -eq "")) {$env:varAvgDiskQueueLength = 2}
if (($env:varAvgDiskReadQueueLength -eq $null) -or ($env:varAvgDiskReadQueueLength -eq "")) {$env:varAvgDiskReadQueueLength = 2}
if (($env:varAvgDiskWriteQueueLength -eq $null) -or ($env:varAvgDiskWriteQueueLength -eq "")) {$env:varAvgDiskWriteQueueLength = 2}

if (($env:varPercentDiskTime -eq $null) -or ($env:varPercentDiskTime -eq "")) {$env:varPercentDiskTime = 25}
if (($env:varPercentDiskReadTime -eq $null) -or ($env:varPercentDiskReadTime -eq "")) {$env:varPercentDiskReadTime = 75}
if (($env:varPercentDiskWriteTime -eq $null) -or ($env:varPercentDiskWriteTime -eq "")) {$env:varPercentDiskWriteTime = 75}
if (($env:varPercentIdleTime -eq $null) -or ($env:varPercentIdleTime -eq "")) {$env:varPercentIdleTime = 25}
if (($env:varSplitIOPerSec -eq $null) -or ($env:varSplitIOPerSec -eq "")) {$env:varSplitIOPerSec = 100}

if (($env:varDiskReadsPersec -eq $null) -or ($env:varDiskReadsPersec -eq "")) {$env:varDiskReadsPersec = 100}
#if (($env:varAvgDisksecPerRead -eq $null) -or ($env:varAvgDisksecPerRead -eq "")) {$env:varAvgDisksecPerRead = 2}
if (($env:varAvgDiskBytesPerRead -eq $null) -or ($env:varAvgDiskBytesPerRead -eq "")) {$env:varAvgDiskBytesPerRead = 1073741824}

if (($env:varDiskWritesPersec -eq $null) -or ($env:varDiskWritesPersec -eq "")) {$env:varDiskWritesPersec = 100}
#if (($env:varAvgDisksecPerWrite -eq $null) -or ($env:varAvgDisksecPerWrite -eq "")) {$env:varAvgDisksecPerWrite = 2}
if (($env:varAvgDiskBytesPerWrite -eq $null) -or ($env:varAvgDiskBytesPerWrite -eq "")) {$env:varAvgDiskBytesPerWrite = 1073741824}

if (($env:varDiskBytesPersec -eq $null) -or ($env:varDiskBytesPersec -eq "")) {$env:varDiskBytesPersec = 1073741824}
if (($env:varDiskReadBytesPersec -eq $null) -or ($env:varDiskReadBytesPersec -eq "")) {$env:varDiskReadBytesPersec = 1073741824}
if (($env:varDiskWriteBytesPersec -eq $null) -or ($env:varDiskWriteBytesPersec -eq "")) {$env:varDiskWriteBytesPersec = 1073741824}

if (($env:varDiskTransfersPersec -eq $null) -or ($env:varDiskTransfersPersec -eq "")) {$env:varDiskTransfersPersec = 100}
#if (($env:varAvgDisksecPerTransfer -eq $null) -or ($env:varAvgDisksecPerTransfer -eq "")) {$env:varAvgDisksecPerTransfer = 2}
if (($env:varAvgDiskBytesPerTransfer -eq $null) -or ($env:varAvgDiskBytesPerTransfer -eq "")) {$env:varAvgDiskBytesPerTransfer = 1073741824}

try {
  $ldisks = Get-CimInstance 'Win32_PerfFormattedData_PerfDisk_LogicalDisk' -erroraction stop | where-object Name -match ":"
} catch {
  try {
    $script:blnWMI = $true
    $script:diag += "Unable to poll Drive Statistics via CIM`r`nAttempting to use WMI instead`r`n"
    $ldisks = Get-WMIObject 'Win32_PerfFormattedData_PerfDisk_LogicalDisk' -erroraction stop | where-object Name -match ":"
  } catch {
    $script:diag += "Unable to query Drive Statistics via CIM or WMI`r`n"
    write-DRRMAlert "Warning : Monitoring Failure"
    write-DRMMDiag "$($script:diag)"
    $script:diag = $null
    exit 1
  }
}

$idisks = 0
foreach ($disk in $ldisks) {
  $idisks += 1
  write-host "`r`nPOLLING DISK : $($disk.name)`r`n" -foregroundcolor yellow
  $dque = $disk.CurrentDiskQueueLength
  $diskdiag += ("Current Disk Queue : $($dque)`r`n").toupper()
  $daque = $disk.AvgDiskQueueLength
  $diskdiag += ("Avg. Disk Queue : $($daque)`r`n").toupper()
  $darque = $disk.AvgDiskReadQueueLength
  $diskdiag += ("Avg. Disk Read Queue : $($darque)`r`n").toupper()
  $dawque = $disk.AvgDiskWriteQueueLength
  $diskdiag += ("Avg. Disk Write Queue : $($dawque)`r`n").toupper()

  $dtime = $disk.PercentDiskTime
  $diskdiag += ("Disk Time (%) : $($dtime) %`r`n").toupper()
  $drtime = $disk.PercentDiskReadTime
  $diskdiag += ("Disk Read Time (%) : $($dque ) %`r`n").toupper()
  $dwtime = $disk.PercentDiskWriteTime
  $diskdiag += ("Disk Write Time (%) : $($dwtime) %`r`n").toupper()
  $didle = $disk.PercentIdleTime
  $diskdiag += ("Idle Time (%) : $($didle) %`r`n").toupper()
  $dio = $disk.SplitIOPerSec
  $diskdiag += ("Split IO/Sec : $($dio)`r`n").toupper()

  $drsec = $disk.DiskReadsPersec
  $diskdiag += ("Disk Reads/sec : $($drsec)`r`n").toupper()
  $dasr = $disk.AvgDisksecPerRead
  $diskdiag += ("Avg. Disk sec/Read : $($dasr)`r`n").toupper()
  $dabr = ($disk.AvgDiskBytesPerRead / 1024)
  $diskdiag += ("Avg. Disk Bytes/Read (KB) : $($dabr)`r`n").toupper()

  $dwsec = $disk.DiskWritesPersec
  $diskdiag += ("Disk Writes/sec : $($dwsec)`r`n").toupper()
  $dasw = $disk.AvgDisksecPerWrite
  $diskdiag += ("Avg. Disk sec/Write : $($dasw)`r`n").toupper()
  $dabw = ($disk.AvgDiskBytesPerWrite / 1024)
  $diskdiag += ("Avg. Disk Bytes/Write (KB) : $($dabw)`r`n").toupper()

  $dbsec = ($disk.DiskBytesPersec / 1024)
  $diskdiag += ("Disk Bytes/sec (KB) : $($dbsec)`r`n").toupper()
  $drbs = ($disk.DiskReadBytesPersec / 1024)
  $diskdiag += ("Disk Read Bytes/sec (KB) : $($drbs)`r`n").toupper()
  $dwbs = ($disk.DiskWriteBytesPersec / 1024)
  $diskdiag += ("Disk Write Bytes/sec (KB) : $($dwbs)`r`n").toupper()

  $dtsec = $disk.DiskTransfersPersec
  $diskdiag += ("Disk Transfers/sec : $($dtsec)`r`n").toupper()
  $dast = $disk.AvgDisksecPerTransfer
  $diskdiag += ("Avg. Disk sec/Transfer : $($dast)`r`n").toupper()
  $dabt = ($disk.AvgDiskBytesPerTransfer / 1024)
  $diskdiag += ("Avg. Disk Bytes/Transfer (KB) : $($dabt)`r`n").toupper()
  #CHECK DRIVE PERFORMANCE VALUES
  chkPERF $disk
  write-host $diskdiag
  write-host " - DRIVE REPORT : $($disk.name)" -ForegroundColor yellow
  $diskdiag += " - DRIVE REPORT $($disk.name):`r`n"
  if (-not $script:diskWARN) {
    write-host "  - All Drive Performance values passed checks" -ForegroundColor green
    $diskdiag += "  - All Drive Performance values passed checks`r`n"
  } elseif ($script:diskWARN) {
    write-host "  - The following Drive Performance values did not pass :" -ForegroundColor red
    $diskdiag += "  - The following Drive Performance values did not pass :`r`n"
    foreach ($warn in $script:disks[$disk.name]) {
      write-host "$($warn)" -ForegroundColor red
      $diskdiag += "$($warn)"
    }
    $script:diskWARN = $false
  }
  $script:diag += "`r`nPOLLING DISK : $($disk.name)`r`n$($diskdiag)"
  $diskdiag = $null
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
$average = (($total / $idisks) / 1000)
$mill = [string]$average
$mill = $mill.split(".")[1]
$mill = $mill.SubString(0,[math]::min(3,$mill.length))
$script:diag += "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
$script:diag += "Avg. Execution Time - $([math]::round($average / 60)) Minutes : $([math]::round($average)) Seconds : $($mill) Milliseconds per Call`r`n"
#DATTO OUTPUT
write-host  "DATTO OUTPUT :"
if ($script:blnWARN) {
  write-DRRMAlert "Warning : $($script:disks.count) Disk(s) Exceeded Performance Thresholds"
  write-DRMMDiag "$($script:diag)"
  $script:diag = $null
  exit 1
} elseif (-not $script:blnWARN) {
  write-DRRMAlert "Healthy : $($idisks) Disk(s) Within Performance Thresholds"
  write-DRMMDiag "$($script:diag)"
  $script:diag = $null
  exit 0
}
write-host $script:diag
#END SCRIPT
#------------