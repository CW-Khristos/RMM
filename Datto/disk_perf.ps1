<# 
.SYNOPSIS
    All-Inclusive Disk Performance Monitor

.DESCRIPTION
    Collects Disk Performance Statistics for all connected drives with at least 1 partition with a drive letter assigned
    Performance Statistics for each drive are queried and collected separately

.NOTES
    Version        : 0.1.0 (24 March 2022)
    Creation Date  : 24 March 2022
    Purpose/Change : Provide Primary AV Product Status and Report Possible AV Conflicts
    File Name      : diskper_0.1.0.ps1 
    Author         : Christopher Bledsoe - cbledsoe@ipmcomputers.com
    Thanks         : Chris Taylor (christaylor.codes ) for objectively providing the best answer

.CHANGELOG

.TODO
    Current plans are to test overall execution performance of using array vs. hashtable for collecting and returning statistics to Datto

#> 

#REGION ----- DECLARATIONS ----
  $global:diag = $null
  $global:blnADD = $false
  $global:blnWARN = $false
  $global:disks = @{}
  $global:arrWARN = [System.Collections.ArrayList]@()
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
          $array = @()
          $global:blnADD = $true
          $array = $dest[$disk]
          $array = $array.split("`r`n",[System.StringSplitOptions]::RemoveEmptyEntries)
          if ($array -contains $warn) {
            $global:blnADD = $false
          }
          if ($global:blnADD) {
            $array += "$warn`r`n"
            $dest.remove($disk)
            $dest.add($disk, $array)
            $global:blnWARN = $true
          }
        } elseif (-not $dest.containskey($disk)) {
          $array = @()
          $array = "$warn`r`n"
          $dest.add($disk, $array)
          $global:blnWARN = $true
        }
      }
    } catch {
      $warndiag = "Disk Performance : Error populating warnings for $($disk)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n"
      write-host "Disk Performance : Error populating warnings for $($disk)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n"
      write-host $_.scriptstacktrace
      write-host $_
      $global:diag += "$($warndiag)"
      $warndiag = $null
    }
  } ## Pop-Warnings

  function chkPERF ($objDRV) {
    if (($objDRV.CurrentDiskQueueLength -ne $null) -and ($objDRV.CurrentDiskQueueLength -gt 2)) {$global:blnWARN = $true; $global:arrWARN.add("  - $($objDRV.name) - CurrentDiskQueueLength`r`n")}
    if (($objDRV.AvgDiskQueueLength -ne $null) -and ($objDRV.AvgDiskQueueLength -gt 2)) {$global:blnWARN = $true; $global:arrWARN.add("  - $($objDRV.name) - AvgDiskQueueLength`r`n")}
    if (($objDRV.AvgDiskReadQueueLength -ne $null) -and ($objDRV.AvgDiskReadQueueLength -gt 2)) {$global:blnWARN = $true; $global:arrWARN.add("  - $($objDRV.name) - AvgDiskReadQueueLength`r`n")}
    if (($objDRV.AvgDiskWriteQueueLength -ne $null) -and ($objDRV.AvgDiskWriteQueueLength -gt 2)) {$global:blnWARN = $true; $global:arrWARN.add("  - $($objDRV.name) - AvgDiskWriteQueueLength`r`n")}

    if (($objDRV.PercentDiskTime -ne $null) -and ($objDRV.PercentDiskTime -ge 25)) {$global:blnWARN = $true; $global:arrWARN.add("  - $($objDRV.name) - PercentDiskTime`r`n")}
    if (($objDRV.PercentDiskReadTime -ne $null) -and ($objDRV.PercentDiskReadTime -ge 75)) {$global:blnWARN = $true; $global:arrWARN.add("  - $($objDRV.name) - PercentDiskReadTime`r`n")}
    if (($objDRV.PercentDiskWriteTime -ne $null) -and ($objDRV.PercentDiskWriteTime -ge 75)) {$global:blnWARN = $true; $global:arrWARN.add("  - $($objDRV.name) - PercentDiskWriteTime`r`n")}
    if (($objDRV.PercentIdleTime -ne $null) -and ($objDRV.PercentIdleTime -le 25)) {$global:blnWARN = $true; $global:arrWARN.add("  - $($objDRV.name) - PercentIdleTime`r`n")}
    if (($objDRV.SplitIOPerSec -ne $null) -and ($objDRV.SplitIOPerSec -gt 100)) {$global:blnWARN = $true; $global:arrWARN.add("  - $($objDRV.name) - SplitIOPerSec`r`n")}

    if (($objDRV.DiskReadsPersec -ne $null) -and ($objDRV.DiskReadsPersec -gt 100)) {$global:blnWARN = $true; $global:arrWARN.add("  - $($objDRV.name) - DiskReadsPersec`r`n")}
    #if (($objDRV.AvgDisksecPerRead -ne $null) -and ($objDRV.AvgDisksecPerRead -gt 100)) {$global:blnWARN = $true; $global:arrWARN.add("  - $($objDRV.name) - AvgDisksecPerRead`r`n")}
    if (($objDRV.AvgDiskBytesPerRead -ne $null) -and ($objDRV.AvgDiskBytesPerRead -gt 1073741824)) {$global:blnWARN = $true; $global:arrWARN.add("  - $($objDRV.name) - AvgDiskBytesPerRead`r`n")}

    if (($objDRV.DiskWritesPersec -ne $null) -and ($objDRV.DiskWritesPersec -gt 100)) {$global:blnWARN = $true; $global:arrWARN.add("  - $($objDRV.name) - DiskWritesPersec`r`n")}
    #if (($objDRV.AvgDisksecPerWrite -ne $null) -and ($objDRV.AvgDisksecPerWrite -gt 50)) {$global:blnWARN = $true; $global:arrWARN.add("  - $($objDRV.name) - AvgDisksecPerWrite`r`n")}
    if (($objDRV.AvgDiskBytesPerWrite -ne $null) -and ($objDRV.AvgDiskBytesPerWrite -gt 1073741824)) {$global:blnWARN = $true; $global:arrWARN.add("  - $($objDRV.name) - AvgDiskBytesPerWrite`r`n")}

    if (($objDRV.DiskBytesPersec -ne $null) -and ($objDRV.DiskBytesPersec -gt 1073741824)) {$global:blnWARN = $true; $global:arrWARN.add("  - $($objDRV.name) - DiskBytesPersec`r`n")}
    if (($objDRV.DiskReadBytesPersec -ne $null) -and ($objDRV.DiskReadBytesPersec -gt 1073741824)) {$global:blnWARN = $true; $global:arrWARN.add("  - $($objDRV.name) - DiskReadBytesPersec`r`n")}
    if (($objDRV.DiskWriteBytesPersec -ne $null) -and ($objDRV.DiskWriteBytesPersec -gt 1073741824)) {$global:blnWARN = $true; $global:arrWARN.add("  - $($objDRV.name) - DiskWriteBytesPersec`r`n")}

    if (($objDRV.DiskTransfersPersec -ne $null) -and ($objDRV.DiskTransfersPersec -gt 100)) {$global:blnWARN = $true; $global:arrWARN.add("  - $($objDRV.name) - DiskTransfersPersec`r`n")}
    #if (($objDRV.AvgDisksecPerTransfer -ne $null) -and ($objDRV.AvgDisksecPerTransfer -gt 50)) {$global:blnWARN = $true; $global:arrWARN.add("  - $($objDRV.name) - AvgDisksecPerTransfer`r`n")}
    if (($objDRV.AvgDiskBytesPerTransfer -ne $null) -and ($objDRV.AvgDiskBytesPerTransfer -gt 1073741824)) {$global:blnWARN = $true; $global:arrWARN.add("  - $($objDRV.name) - AvgDiskBytesPerTransfer`r`n")}
    #Pop-Warnings $global:arrWARN $objDRV.name "Disk Performance - $($Status)`r`n"
  } ## chkSMART
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
  #CHECK DRIVE PERFORMANCE VALUES
  chkPERF $disk
  write-host " - DRIVE REPORT : $($disk.name)" -ForegroundColor yellow
  $global:diag += " - DRIVE REPORT $($disk.name):`r`n"
  if ($global:arrWARN.length -eq 0) {
    write-host "  - All Drive Performance values passed checks`r`n" -ForegroundColor green
    $global:diag += "  - All Drive Performance values passed checks`r`n"
  } elseif ($global:arrWARN.length -gt 0) {
    write-host "  - The following Drive Performance values did not pass :`r`n" -ForegroundColor red
    $global:diag += "  - The following Drive Performance values did not pass :`r`n"
    foreach ($warn in $global:arrWARN) {
      write-host "$($warn)" -ForegroundColor red
      $global:diag += "$($warn)"
    }
    $global:arrWARN.clear()
  }
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
$mill = $mill.SubString(0,[math]::min(3,$mill.length))
$global:diag += "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
$global:diag += "Avg. Execution Time - $([math]::round($average / 60)) Minutes : $([math]::round($average)) Seconds : $($mill) Milliseconds per Call`r`n"
write-host "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds"
write-host "Avg. Execution Time - $([math]::round($average / 60)) Minutes : $([math]::round($average)) Seconds : $($mill) Milliseconds per Call"
#DATTO OUTPUT
write-host 'DATTO OUTPUT :'
if ($global:blnWARN) {
  write-DRRMAlert "Disk Performance : Warning"
  write-DRMMDiag "$($global:diag)"
  $global:diag = $null
  exit 1
} elseif (-not $global:blnWARN) {
  write-DRRMAlert "Disk Performance : Healthy"
  write-DRMMDiag "$($global:diag)"
  $global:diag = $null
  exit 0
}
#END SCRIPT
#------------