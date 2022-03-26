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
    Benefit to using hashtable for populating Disk information would be being able to report Disks with warnings in Alert text
    Plan to allow for passing of configurable thresholds

#> 

#REGION ----- DECLARATIONS ----
  $global:diag = $null
  $global:blnADD = $false
  $global:blnWMI = $false
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

try {
  $ldisks = Get-CimInstance 'Win32_PerfFormattedData_PerfDisk_LogicalDisk' -erroraction stop | where Name -match ":"
} catch {
  try {
    $global:blnWMI = $true
    $global:diag += "Unable to poll Drive Statistics via CIM`r`nAttempting to use WMI instead`r`n"
    $ldisks = Get-WMIObject 'Win32_PerfFormattedData_PerfDisk_LogicalDisk' -erroraction stop | where Name -match ":"
  } catch {
    $global:diag += "Unable to query Drive Statistics via CIM or WMI`r`n"
    write-DRRMAlert "Disk Performance : Warning : Monitoring Failure"
    write-DRMMDiag "$($global:diag)"
    $global:diag = $null
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
  $diskdiag += ("Avg. Disk Bytes/Read : $($dabr)`r`n").toupper()

  $dwsec = $disk.DiskWritesPersec
  $diskdiag += ("Disk Writes/sec : $($dwsec)`r`n").toupper()
  $dasw = $disk.AvgDisksecPerWrite
  $diskdiag += ("Avg. Disk sec/Write : $($dasw)`r`n").toupper()
  $dabw = ($disk.AvgDiskBytesPerWrite / 1024)
  $diskdiag += ("Avg. Disk Bytes/Write : $($dabw)`r`n").toupper()

  $dbsec = ($disk.DiskBytesPersec / 1024)
  $diskdiag += ("Disk Bytes/sec : $($dbsec)`r`n").toupper()
  $drbs = ($disk.DiskReadBytesPersec / 1024)
  $diskdiag += ("Disk Read Bytes/sec : $($drbs)`r`n").toupper()
  $dwbs = ($disk.DiskWriteBytesPersec / 1024)
  $diskdiag += ("Disk Write Bytes/sec: $($dwbs)`r`n").toupper()

  $dtsec = $disk.DiskTransfersPersec
  $diskdiag += ("Disk Transfers/sec : $($dtsec)`r`n").toupper()
  $dast = $disk.AvgDisksecPerTransfer
  $diskdiag += ("Avg. Disk sec/Transfer : $($dast)`r`n").toupper()
  $dabt = ($disk.AvgDiskBytesPerTransfer / 1024)
  $diskdiag += ("Avg. Disk Bytes/Transfer : $($dabt)`r`n").toupper()
  #CHECK DRIVE PERFORMANCE VALUES
  chkPERF $disk
  write-host $diskdiag
  write-host " - DRIVE REPORT : $($disk.name)" -ForegroundColor yellow
  $diskdiag += " - DRIVE REPORT $($disk.name):`r`n"
  if ($global:arrWARN.length -eq 0) {
    write-host "  - All Drive Performance values passed checks`r`n" -ForegroundColor green
    $diskdiag += "  - All Drive Performance values passed checks`r`n"
  } elseif ($global:arrWARN.length -gt 0) {
    write-host "  - The following Drive Performance values did not pass :`r`n" -ForegroundColor red
    $diskdiag += "  - The following Drive Performance values did not pass :`r`n"
    foreach ($warn in $global:arrWARN) {
      write-host "$($warn)" -ForegroundColor red
      $diskdiag += "$($warn)"
    }
    $global:arrWARN.clear()
  }
  $global:diag += "`r`nPOLLING DISK : $($disk.name)`r`n$($diskdiag)"
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
$global:diag += "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
$global:diag += "Avg. Execution Time - $([math]::round($average / 60)) Minutes : $([math]::round($average)) Seconds : $($mill) Milliseconds per Call`r`n"
#DATTO OUTPUT
write-host  "DATTO OUTPUT :"
if ($global:blnWARN) {
  write-DRRMAlert "Disk Performance : Warning"
  write-DRMMDiag "$($global:diag)"
  $global:diag = $null
  exit 1
} elseif (-not $global:blnWARN) {
  write-DRRMAlert "Disk Performance : Healthy : $($idisks) Disk(s) Within Performance Thresholds"
  write-DRMMDiag "$($global:diag)"
  $global:diag = $null
  exit 0
}
write-host $global:diag
#END SCRIPT
#------------