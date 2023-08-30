#region ----- DECLARATIONS ----
  $script:diag = $null
  $script:blnWARN = $false
  $script:blnBREAK = $false
  $strLineSeparator = "----------------------------------"
  $Backups = @{}
  $DataSources = @(
    "FileSystem",
    "SystemState",
    "Exchange",
    "NetworkShares",
    "VssHyperV",
    "VssMsSql",
    "MySql",
    "Oracle",
    "VssSharePoint",
    "VMWare"
  )
#endregion ----- DECLARATIONS ----

#region ----- FUNCTIONS ----
  function write-DRMMDiag ($messages) {
    write-output "<-Start Diagnostic->"
    foreach ($message in $messages) {$message}
    write-output "<-End Diagnostic->"
  } ## write-DRMMDiag
  
  function write-DRMMAlert ($message) {
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
    $ScriptStopTime = (get-date).ToString('yyyy-MM-dd hh:mm:ss')
    write-output "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds"
    $script:diag += "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
  }

  function logERR ($intSTG, $strModule, $strErr) {
    $script:blnWARN = $true
    #CUSTOM ERROR CODES
    switch ($intSTG) {
      1 {                                                         #'ERRRET'=1 - NOT ENOUGH ARGUMENTS, END SCRIPT
        $script:blnBREAK = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - MSPBackup_Status - NO ARGUMENTS PASSED, END SCRIPT`r`n$($strLineSeparator)`r`n"
        write-output "$($strLineSeparator)`r`n$($(get-date)) - MSPBackup_Status - NO ARGUMENTS PASSED, END SCRIPT`r`n$($strLineSeparator)`r`n" -foregroundcolor red
      }
      2 {                                                         #'ERRRET'=2 - END SCRIPT
        $script:blnBREAK = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - ($($strModule)) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n$($strLineSeparator)`r`n"
        write-output "$($strLineSeparator)`r`n$($(get-date)) - ($($strModule)) :" -foregroundcolor red
        write-output "$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n$($strLineSeparator)`r`n" -foregroundcolor red
      }
      3 {                                                         #'ERRRET'=3
        $script:blnWARN = $false
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)`r`n$($strLineSeparator)`r`n"
        write-output "$($strLineSeparator)`r`n$($(get-date)) - $($strModule) :" -foregroundcolor yellow
        write-output "$($strLineSeparator)`r`n`t$($strErr)`r`n$($strLineSeparator)`r`n" -foregroundcolor yellow
      }
      default {                                                   #'ERRRET'=4+
        $script:blnBREAK = $false
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)`r`n$($strLineSeparator)`r`n"
        write-output "$($strLineSeparator)`r`n$($(get-date)) - $($strModule) :" -foregroundcolor yellow
        write-output "$($strLineSeparator)`r`n`t$($strErr)`r`n$($strLineSeparator)`r`n" -foregroundcolor red
      }
    }
  }
#endregion ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
$Date = (get-date).AddHours(-24)
#Start script execution time calculation
$script:sw = [Diagnostics.Stopwatch]::StartNew()
$ScrptStartTime = (get-date).ToString('yyyy-MM-dd hh:mm:ss')
#RETRIEVE SESSION LIST FROM WITHIN ELECTED TIME RANGE ABOVE AND ONLY RETURN 'FAILED' BACKUPS
logERR 3 "MSPBackup_Status" "Querying Backup Sessions"
try {
  $SessionsList = & "C:\Program Files\Backup Manager\clienttool.exe" -machine-readable control.session.list  -delimiter "," | convertfrom-csv -Delimiter "," | 
    where { [datetime]$_.start -gt $Date } | sort -property start -descending

  $Backups = foreach ($source in $DataSources) {
    $Session = $SessionsList | where {$_.DSRC -eq $source} | sort -property start -descending | select -first 1
    $State = switch ($Session.state) {
      'Failed' {"Backup has failed with an error. Backup Started at $($session.start)"}
      'Skipped' {"Backup has been skipped as previous job was still running. Backup Started at $($session.start)"}
      'InProcess' {if ($session.start -lt $Date) {"Backup has been running for over 23 hours. Backup Started at $($session.start)"}}
      'Interrupted' {"Backup has been interrupted. Backup Started at $($session.start)"}
      'CompletedwithErrors' {"Backup has completed with an error. Backup Started at $($session.start)"}
    }
    [pscustomobject] @{
      'DataSource'  = $source
      'State'       = $session.state
      'Message'     = $State
      'Start'       = $session.start
      'End'         = $session.end
    }
  }
} catch {
  $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
  logERR 2 "MSPBackup_Status" "Failed to Query Backup Sessions`r`n$($err)"
}
#DATTO OUTPUT
$AllSessions = $SessionsList | out-string
$FailedBackups = $Backups | where {(($null -ne $_.state) -and 
  ((($_.state -eq "Failed") -or ($_.state -eq "CompletedWithErrors")) -or 
  (($_.state -eq "InProcess" -and $_.start -lt $Date))))} | out-string
$UncertainBackups = $Backups | where {(($null -ne $_.state) -and 
  ((($_.state -ne "Failed") -and ($_.state -ne "CompletedWithErrors") -and 
  ($_.state -ne "Completed") -and ($_.state -ne "InProcess")) -or 
  (($_.state -eq "InProcess" -and $_.start -lt $Date))))} | out-string
logERR 3 "MSPBackup_Status" "Failed:`r`n$($FailedBackups)"
logERR 3 "MSPBackup_Status" "UnCertain:`r`n$($UncertainBackups)"
logERR 3 "MSPBackup_Status" "Sessions:`r`n$($AllSessions)"
if (-not $SessionsList) {
  logERR 4 "MSPBackup_Status" "No Backups in past 24 Hours"
} elseif ($FailedBackups) {
  $script:blnWARN = $true
  logERR 4 "MSPBackup_Status" "Failed Backups Detected"
}
if ($UncertainBackups) {
  $script:blnWARN = $true
  logERR 4 "MSPBackup_Status" "UnCertain Backups Detected"
}
#Stop script execution time calculation
StopClock
$finish = "$((get-date).ToString('yyyy-MM-dd hh:mm:ss'))"
if (-not $script:blnBREAK) {
  if (-not $script:blnWARN) {
    write-DRMMAlert "MSPBackup_Status : Healthy. No Issues Found : $($finish)"
    write-DRMMDiag "$($script:diag)"
    exit 0
  } elseif ($script:blnWARN) {
    write-DRMMAlert "MSPBackup_Status : Issues Found. Please Check Diagnostics : $($finish)"
    write-DRMMDiag "$($script:diag)"
    exit 1
  }
} elseif ($script:blnBREAK) {
  write-DRMMAlert "MSPBackup_Status : Execution Failed : $($finish)"
  write-DRMMDiag "$($script:diag)"
  exit 1
}
#END SCRIPT
#------------