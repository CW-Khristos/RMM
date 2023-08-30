<# 
.SYNOPSIS
    All-Inclusive Disk Performance Monitor

.DESCRIPTION
    Collects Disk Performance Statistics for all connected drives with at least 1 partition with a drive letter assigned
    Performance Statistics for each drive are queried and collected separately

.NOTES
    Version        : 0.1.2 (13 June 2022)
    Creation Date  : 24 March 2022
    Purpose/Change : Provide Primary AV Product Status and Report Possible AV Conflicts
    File Name      : diskperf_0.1.2.ps1 
    Author         : Christopher Bledsoe - cbledsoe@ipmcomputers.com
    Thanks         : Chris Taylor (christaylor.codes ) for objectively providing the best answer

.CHANGELOG
    0.1.0 Initial Release
    0.1.1 Added configurable thresholds
          Switch to populated Disk Performance Warnings in hashtable

.TODO
#>

#REGION ----- DECLARATIONS ----
  $idisks = 0
  $script:disks = @{}
  $script:diag = $null
  $script:blnADD = $false
  $script:blnWMI = $false
  $script:blnWARN = $false
  $script:diskWARN = $false
#ENDREGION ----- DECLARATIONS ----

#REGION ----- FUNCTIONS ----
  function write-DRMMDiag ($messages) {
    write-output "<-Start Diagnostic->"
    foreach ($Message in $Messages) {$Message}
    write-output "<-End Diagnostic->"
  } ## write-DRMMDiag
  
  function write-DRRMAlert ($message) {
    write-output "<-Start Result->"
    write-output "Alert=$($message)"
    write-output "<-End Result->"
  } ## write-DRRMAlert

  function StopClock {
    #Stop script execution time calculation
    $script:sw.Stop()
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
    write-output "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds"
    write-output "Avg. Execution Time - $([math]::round($average / 60)) Minutes : $([math]::round($average)) Seconds : $($mill) Milliseconds per Call`r`n"
  }

  function pop-Warnings {
    param (
      $dest, $disk, $warn
    )
    #POPULATE DISK WARNINGS DATA INTO NESTED HASHTABLE FORMAT FOR LATER USE
    try {
      if (($null -ne $disk) -and ($disk -ne "")) {
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
      write-output "Disk Performance : Error populating warnings for $($disk)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n"
      write-output $_.scriptstacktrace
      write-output $_
      $script:diag += "$($warndiag)"
      $warndiag = $null
    }
  } ## pop-Warnings

  function write-PERF ($objPERF, $objDISK) {
    $dque = $objPERF.CurrentDiskQueueLength
    $diskdiag += ("Current Disk Queue : $($dque)`r`n").toupper()
    $daque = $objPERF.AvgDiskQueueLength
    $diskdiag += ("Avg. Disk Queue : $($daque)`r`n").toupper()
    $darque = $objPERF.AvgDiskReadQueueLength
    $diskdiag += ("Avg. Disk Read Queue : $($darque)`r`n").toupper()
    $dawque = $objPERF.AvgDiskWriteQueueLength
    $diskdiag += ("Avg. Disk Write Queue : $($dawque)`r`n").toupper()

    $dtime = $objPERF.PercentDiskTime
    $diskdiag += ("Disk Time (%) : $($dtime) %`r`n").toupper()
    $drtime = $objPERF.PercentDiskReadTime
    $diskdiag += ("Disk Read Time (%) : $($dque ) %`r`n").toupper()
    $dwtime = $objPERF.PercentDiskWriteTime
    $diskdiag += ("Disk Write Time (%) : $($dwtime) %`r`n").toupper()
    $didle = $objPERF.PercentIdleTime
    $diskdiag += ("Idle Time (%) : $($didle) %`r`n").toupper()
    $dio = $objPERF.SplitIOPerSec
    $diskdiag += ("Split IO/Sec : $($dio)`r`n").toupper()

    $drsec = $objPERF.DiskReadsPersec
    $diskdiag += ("Disk Reads/sec : $($drsec)`r`n").toupper()
    $dasr = $objPERF.AvgDisksecPerRead
    $diskdiag += ("Avg. Disk sec/Read : $($dasr)`r`n").toupper()
    $dabr = ($objPERF.AvgDiskBytesPerRead / 1024)
    $diskdiag += ("Avg. Disk Bytes/Read (KB) : $($dabr)`r`n").toupper()

    $dwsec = $objPERF.DiskWritesPersec
    $diskdiag += ("Disk Writes/sec : $($dwsec)`r`n").toupper()
    $dasw = $objPERF.AvgDisksecPerWrite
    $diskdiag += ("Avg. Disk sec/Write : $($dasw)`r`n").toupper()
    $dabw = ($objPERF.AvgDiskBytesPerWrite / 1024)
    $diskdiag += ("Avg. Disk Bytes/Write (KB) : $($dabw)`r`n").toupper()

    $dbsec = ($objPERF.DiskBytesPersec / 1024)
    $diskdiag += ("Disk Bytes/sec (KB) : $($dbsec)`r`n").toupper()
    $drbs = ($objPERF.DiskReadBytesPersec / 1024)
    $diskdiag += ("Disk Read Bytes/sec (KB) : $($drbs)`r`n").toupper()
    $dwbs = ($objPERF.DiskWriteBytesPersec / 1024)
    $diskdiag += ("Disk Write Bytes/sec (KB) : $($dwbs)`r`n").toupper()

    $dtsec = $objPERF.DiskTransfersPersec
    $diskdiag += ("Disk Transfers/sec : $($dtsec)`r`n").toupper()
    $dast = $objPERF.AvgDisksecPerTransfer
    $diskdiag += ("Avg. Disk sec/Transfer : $($dast)`r`n").toupper()
    $dabt = ($objPERF.AvgDiskBytesPerTransfer / 1024)
    $diskdiag += ("Avg. Disk Bytes/Transfer (KB) : $($dabt)`r`n").toupper()
    #CHECK DRIVE PERFORMANCE VALUES
    check-PERF $objPERF $objDISK
    write-output "$($diskdiag)--------------------------------------"
    write-output " - DRIVE REPORT : $($objPERF.name)" -ForegroundColor yellow
    $diskdiag += "--------------------------------------`r`n"
    $diskdiag += " - DRIVE REPORT $($objPERF.name):`r`n"
    if (-not $script:diskWARN) {
      write-output "  - All Drive Performance values passed checks" -ForegroundColor green
      $diskdiag += "  - All Drive Performance values passed checks`r`n"
    } elseif ($script:diskWARN) {
      write-output "  - The following Drive Performance values did not pass :" -ForegroundColor red
      $diskdiag += "  - The following Drive Performance values did not pass :`r`n"
      foreach ($warn in $script:disks[$objPERF.name]) {
        write-output "$($warn)" -ForegroundColor red
        $diskdiag += "$($warn)"
      }
      $script:diskWARN = $false
    }
    write-output "--------------------------------------"
    $script:diag += "--------------------------------------`r`n$($diskdiag)"
    $script:diag += "--------------------------------------`r`n"
    $diskdiag = $null
  }

  function check-PERF ($objPERF, $objDISK) {
    #DOUBLE-CHECK PASSED THRESHOLDS
    if ($objDISK.mediatype -ne "SSD") {
        if (($env:varCurrentDiskQueueLength -eq $null) -or ($env:varCurrentDiskQueueLength -eq "")) {$env:varCurrentDiskQueueLength = 5}
        if (($env:varAvgDiskQueueLength -eq $null) -or ($env:varAvgDiskQueueLength -eq "")) {$env:varAvgDiskQueueLength = 5}
        if (($env:varAvgDiskReadQueueLength -eq $null) -or ($env:varAvgDiskReadQueueLength -eq "")) {$env:varAvgDiskReadQueueLength = 5}
        if (($env:varAvgDiskWriteQueueLength -eq $null) -or ($env:varAvgDiskWriteQueueLength -eq "")) {$env:varAvgDiskWriteQueueLength = 5}

        if (($env:varPercentDiskTime -eq $null) -or ($env:varPercentDiskTime -eq "")) {$env:varPercentDiskTime = 90}
        if (($env:varPercentDiskReadTime -eq $null) -or ($env:varPercentDiskReadTime -eq "")) {$env:varPercentDiskReadTime = 90}
        if (($env:varPercentDiskWriteTime -eq $null) -or ($env:varPercentDiskWriteTime -eq "")) {$env:varPercentDiskWriteTime = 90}
        if (($env:varPercentIdleTime -eq $null) -or ($env:varPercentIdleTime -eq "")) {$env:varPercentIdleTime = 10}
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
    } elseif ($objDISK.mediatype -eq "SSD") {
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
    }
    #CHECK DRIVE PERFORMANCE
    if (($objPERF.CurrentDiskQueueLength -ne $null) -and ($objPERF.CurrentDiskQueueLength -gt $env:varCurrentDiskQueueLength)) {pop-Warnings $script:disks $objPERF.name "  - CurrentDiskQueueLength (Current Threshold : $($env:varCurrentDiskQueueLength))`r`n"}
    if (($objPERF.AvgDiskQueueLength -ne $null) -and ($objPERF.AvgDiskQueueLength -gt $env:varAvgDiskQueueLength)) {pop-Warnings $script:disks $objPERF.name "  - AvgDiskQueueLength (Current Threshold : $($env:varAvgDiskQueueLength))`r`n"}
    if (($objPERF.AvgDiskReadQueueLength -ne $null) -and ($objPERF.AvgDiskReadQueueLength -gt $env:varAvgDiskReadQueueLength)) {pop-Warnings $script:disks $objPERF.name "  - AvgDiskReadQueueLength (Current Threshold : $($env:varAvgDiskReadQueueLength))`r`n"}
    if (($objPERF.AvgDiskWriteQueueLength -ne $null) -and ($objPERF.AvgDiskWriteQueueLength -gt $env:varAvgDiskWriteQueueLength)) {pop-Warnings $script:disks $objPERF.name "  - AvgDiskWriteQueueLength (Current Threshold : $($env:varAvgDiskWriteQueueLength))`r`n"}

    if (($objPERF.PercentDiskTime -ne $null) -and ($objPERF.PercentDiskTime -ge $env:varPercentDiskTime)) {pop-Warnings $script:disks $objPERF.name "  - PercentDiskTime (Current Threshold : $($env:varPercentDiskTime))`r`n"}
    if (($objPERF.PercentDiskReadTime -ne $null) -and ($objPERF.PercentDiskReadTime -ge $env:varPercentDiskReadTime)) {pop-Warnings $script:disks $objPERF.name "  - PercentDiskReadTime (Current Threshold : $($env:varPercentDiskReadTime))`r`n"}
    if (($objPERF.PercentDiskWriteTime -ne $null) -and ($objPERF.PercentDiskWriteTime -ge $env:varPercentDiskWriteTime)) {pop-Warnings $script:disks $objPERF.name "  - PercentDiskWriteTime (Current Threshold : $($env:varPercentDiskWriteTime))`r`n"}
    if (($objPERF.PercentIdleTime -ne $null) -and ($objPERF.PercentIdleTime -le $env:varPercentIdleTime)) {pop-Warnings $script:disks $objPERF.name "  - PercentIdleTime (Current Threshold : $($env:varPercentIdleTime))`r`n"}
    if (($objPERF.SplitIOPerSec -ne $null) -and ($objPERF.SplitIOPerSec -gt $env:varSplitIOPerSec)) {pop-Warnings $script:disks $objPERF.name "  - SplitIOPerSec (Current Threshold : $($env:varSplitIOPerSec))`r`n"}

    if (($objPERF.DiskReadsPersec -ne $null) -and ($objPERF.DiskReadsPersec -gt $env:varDiskReadsPersec)) {pop-Warnings $script:disks $objPERF.name "  - DiskReadsPersec (Current Threshold : $($env:varDiskReadsPersec))`r`n"}
    #if (($objPERF.AvgDisksecPerRead -ne $null) -and ($objPERF.AvgDisksecPerRead -gt $env:varAvgDisksecPerRead)) {pop-Warnings $script:disks $objPERF.name "  - AvgDisksecPerRead (Current Threshold : $($env:varAvgDisksecPerRead))`r`n"}
    if (($objPERF.AvgDiskBytesPerRead -ne $null) -and ($objPERF.AvgDiskBytesPerRead -gt $env:varAvgDiskBytesPerRead)) {pop-Warnings $script:disks $objPERF.name "  - AvgDiskBytesPerRead (Current Threshold : $($env:varAvgDiskBytesPerRead))`r`n"}

    if (($objPERF.DiskWritesPersec -ne $null) -and ($objPERF.DiskWritesPersec -gt $env:varDiskWritesPersec)) {pop-Warnings $script:disks $objPERF.name "  - DiskWritesPersec (Current Threshold : $($env:varDiskWritesPersec))`r`n"}
    #if (($objPERF.AvgDisksecPerWrite -ne $null) -and ($objPERF.AvgDisksecPerWrite -gt $env:varAvgDisksecPerWrite)) {pop-Warnings $script:disks $objPERF.name "  - AvgDisksecPerWrite (Current Threshold : $($env:varAvgDisksecPerWrite))`r`n"}
    if (($objPERF.AvgDiskBytesPerWrite -ne $null) -and ($objPERF.AvgDiskBytesPerWrite -gt $env:varAvgDiskBytesPerWrite)) {pop-Warnings $script:disks $objPERF.name "  - AvgDiskBytesPerWrite (Current Threshold : $($env:varAvgDiskBytesPerWrite))`r`n"}

    if (($objPERF.DiskBytesPersec -ne $null) -and ($objPERF.DiskBytesPersec -gt $env:varDiskBytesPersec)) {pop-Warnings $script:disks $objPERF.name "  - DiskBytesPersec (Current Threshold : $($env:varDiskBytesPersec))`r`n"}
    if (($objPERF.DiskReadBytesPersec -ne $null) -and ($objPERF.DiskReadBytesPersec -gt $env:varDiskReadBytesPersec)) {pop-Warnings $script:disks $objPERF.name "  - DiskReadBytesPersec (Current Threshold : $($env:varDiskReadBytesPersec))`r`n"}
    if (($objPERF.DiskWriteBytesPersec -ne $null) -and ($objPERF.DiskWriteBytesPersec -gt $env:varDiskWriteBytesPersec)) {pop-Warnings $script:disks $objPERF.name "  - DiskWriteBytesPersec (Current Threshold : $($env:varDiskWriteBytesPersec))`r`n"}

    if (($objPERF.DiskTransfersPersec -ne $null) -and ($objPERF.DiskTransfersPersec -gt $env:varDiskTransfersPersec)) {pop-Warnings $script:disks $objPERF.name "  - DiskTransfersPersec (Current Threshold : $($env:varDiskTransfersPersec))`r`n"}
    #if (($objPERF.AvgDisksecPerTransfer -ne $null) -and ($objPERF.AvgDisksecPerTransfer -gt $env:varAvgDisksecPerTransfer)) {pop-Warnings $script:disks $objPERF.name "  - AvgDisksecPerTransfer (Current Threshold : $($env:varAvgDisksecPerTransfer))`r`n"}
    if (($objPERF.AvgDiskBytesPerTransfer -ne $null) -and ($objPERF.AvgDiskBytesPerTransfer -gt $env:varAvgDiskBytesPerTransfer)) {pop-Warnings $script:disks $objPERF.name "  - AvgDiskBytesPerTransfer (Current Threshold : $($env:varAvgDiskBytesPerTransfer))`r`n"}
  } ## check-PERF
#ENDREGION ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
#Start script execution time calculation
$ScrptStartTime = (Get-Date).ToString('dd-MM-yyyy hh:mm:ss')
$sw = [Diagnostics.Stopwatch]::StartNew()
try {
  Get-CimInstance Win32_DiskDrive -erroraction stop | ForEach-Object {
    $ddisk = $_
    $partitions = "ASSOCIATORS OF {Win32_DiskDrive.DeviceID='$($ddisk.DeviceID)'} WHERE AssocClass = Win32_DiskDriveToDiskPartition"
    Get-CimInstance -Query $partitions -erroraction stop | ForEach-Object {
      $dpartition = $_
      $drives = "ASSOCIATORS OF {Win32_DiskPartition.DeviceID='$($dpartition.DeviceID)'} WHERE AssocClass = Win32_LogicalDiskToPartition"
      Get-CimInstance -Query $drives -erroraction stop | ForEach-Object {
        $pdrive = $_
        write-output "--------------------------------------`r`n"
        write-output "POLLING DISK : $($ddisk.name)`r`n" -foregroundcolor yellow
        write-output "--------------------------------------"
        write-output "$($pdrive.DeviceID) - $($ddisk.name) - $($ddisk.serialnumber)"
        write-output "--------------------------------------"
        $script:diag += "--------------------------------------`r`n`r`n"
        $script:diag += "POLLING DISK : $($ddisk.name)`r`n`r`n"
        $script:diag += "--------------------------------------`r`n"
        $script:diag += "$($pdrive.DeviceID) - $($ddisk.name) - $($ddisk.serialnumber)`r`n"
        $pdisk = Get-PhysicalDisk -erroraction stop | Select-Object | where-object {$_.SerialNumber -match "$($ddisk.serialnumber)"}
        $ldisk = Get-CimInstance 'Win32_PerfFormattedData_PerfDisk_LogicalDisk' -erroraction stop | where-object {$_.Name -match "$($pdrive.DeviceID)"}
        write-PERF $ldisk $pdisk
        $idisks += 1
      }
    }
  }
} catch {
  try {
    $script:blnWMI = $true
    $script:diag += "Unable to poll Drive Statistics via CIM`r`nAttempting to use WMI instead`r`n"
    Get-WmiObject Win32_DiskDrive -erroraction stop | ForEach-Object {
      $ddisk = $_
      $partitions = "ASSOCIATORS OF {Win32_DiskDrive.DeviceID='$($ddisk.DeviceID)'} WHERE AssocClass = Win32_DiskDriveToDiskPartition"
      Get-WmiObject -Query $partitions -erroraction stop | ForEach-Object {
        $dpartition = $_
        $drives = "ASSOCIATORS OF {Win32_DiskPartition.DeviceID='$($dpartition.DeviceID)'} WHERE AssocClass = Win32_LogicalDiskToPartition"
        Get-WmiObject -Query $drives -erroraction stop | ForEach-Object {
          $pdrive = $_
          write-output "--------------------------------------"
          write-output "POLLING DISK : $($ddisk.name)`r`n" -foregroundcolor yellow
          write-output "--------------------------------------"
          write-output "$($pdrive.DeviceID) - $($ddisk.name) - $($ddisk.serialnumber)"
          write-output "--------------------------------------"
          $script:diag += "--------------------------------------`r`n`r`n"
          $script:diag += "POLLING DISK : $($ddisk.name)`r`n`r`n"
          $script:diag += "--------------------------------------`r`n"
          $script:diag += "$($pdrive.DeviceID) - $($ddisk.name) - $($ddisk.serialnumber)`r`n"
          $pdisk = Get-PhysicalDisk -erroraction stop | Select-Object | where-object {$_.SerialNumber -match "$($ddisk.serialnumber)"}
          $ldisk = Get-WmiObject 'Win32_PerfFormattedData_PerfDisk_LogicalDisk' -erroraction stop | where-object {$_.Name -match "$($pdrive.DeviceID)"}
          write-PERF $ldisk $pdisk
          $idisks += 1
        }
      }
    }
  } catch {
    $script:diag += "Unable to query Drive Statistics via CIM or WMI`r`n"
    $script:diag += "$($_.Exception)`r`n"
    $script:diag += "$($_.scriptstacktrace)`r`n"
    $script:diag += "$($_)`r`n"
    write-output $_.Exception
    write-output $_.scriptstacktrace
    write-output $_
    write-DRRMAlert "Warning : Monitoring Failure"
    write-DRMMDiag "$($script:diag)"
    $script:diag = $null
    exit 1
  }
}
#Stop script execution time calculation
StopClock
#DATTO OUTPUT
write-output  "DATTO OUTPUT :"
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
write-output $script:diag
#END SCRIPT
#------------