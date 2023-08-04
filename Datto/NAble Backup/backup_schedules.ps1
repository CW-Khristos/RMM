#region ----- DECLARATIONS ----
  #BELOW PARAM() MUST BE COMMENTED OUT FOR USE WITHIN DATTO RMM
  #UNCOMMENT BELOW PARAM() AND RENAME '$env:var' TO '$var' TO UTILIZE IN CLI
  #Param (
  #)
  #VERSION FOR SCRIPT UPDATE
  $strSCR           = "Backup_Schedules"
  $strVER           = [version]"0.1.1"
  $strREPO          = "RMM"
  $strBRCH          = "dev"
  $strDIR           = "Datto"
  $script:diag      = $null
  $script:blnWARN   = $false
  $script:blnBREAK  = $false
  $hashMsg          = $null
  $curArchives      = $env:UDF_19
  $hashArchives     = $env:UDF_20
  $udfArchives      = $env:udfArchives
  $curSchedules     = $env:UDF_17
  $hashSchedules    = $env:UDF_18
  $udfSchedules     = $env:udfSchedules
  $strLineSeparator = "---------"
#endregion ----- DECLARATIONS ----

#region ----- FUNCTIONS ----
  function write-DRMMDiag ($messages) {
    write-host "<-Start Diagnostic->"
    foreach ($message in $messages) {$message}
    write-host "<-End Diagnostic->"
  } ## write-DRMMDiag
  
  function write-DRMMAlert ($message) {
    write-host "<-Start Result->"
    write-host "Alert=$($message)"
    write-host "<-End Result->"
  } ## write-DRMMAlert

  function logERR($intSTG, $strModule, $strErr) {
    $script:blnWARN = $true
    #CUSTOM ERROR CODES
    switch ($intSTG) {
      1 {                                                         #'ERRRET'=1 - NOT ENOUGH ARGUMENTS, END SCRIPT
        $script:blnBREAK = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - Backup_Schedules - NO ARGUMENTS PASSED, END SCRIPT`r`n`r`n"
        write-host "$($strLineSeparator)`r`n$($(get-date)) - Backup_Schedules - NO ARGUMENTS PASSED, END SCRIPT`r`n" -foregroundcolor red
      }
      2 {                                                         #'ERRRET'=2 - END SCRIPT
        $script:blnBREAK = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - Backup_Schedules - ($($strModule)) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n"
        write-host "$($strLineSeparator)`r`n$($(get-date)) - Backup_Schedules - ($($strModule)) :" -foregroundcolor red
        write-host "$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n" -foregroundcolor red
      }
      3 {                                                         #'ERRRET'=3
        $script:blnWARN = $false
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - Backup_Schedules - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
        write-host "$($strLineSeparator)`r`n$($(get-date)) - Backup_Schedules - $($strModule) :" -foregroundcolor yellow
        write-host "$($strLineSeparator)`r`n`t$($strErr)" -foregroundcolor yellow
      }
      default {                                                   #'ERRRET'=4+
        $script:blnBREAK = $false
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - Backup_Schedules - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
        write-host "$($strLineSeparator)`r`n$($(get-date)) - Backup_Schedules - $($strModule) :" -foregroundcolor yellow
        write-host "$($strLineSeparator)`r`n`t$($strErr)" -foregroundcolor red
      }
    }
  }

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
    $mill = [string]($total / 1000)
    $mill = $mill.split(".")[1]
    $mill = $mill.SubString(0,[math]::min(3,$mill.length))
    $script:diag += "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
    write-host "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
  }
#endregion ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
$i = -1
clear-host
cd "C:\Program Files\Backup Manager"
$beginmsg = "Cached Archive Hash (UDF20) : $($hashArchives)`r`n"
$beginmsg += "`tCached Schedule Hash (UDF18) : $($hashSchedules)"
logERR 3 "BEGIN" "$($beginmsg)`r`n$($strLineSeparator)"
#Start script execution time calculation
$ScrptStartTime = (Get-Date).ToString('dd-MM-yyyy hh:mm:ss')
$script:sw = [Diagnostics.Stopwatch]::StartNew()
#QUERY BACKUP SCHEDULES
try {
  $scheduleset = $null
  $schedule = .\clienttool.exe control.schedule.list
  $schedule = $schedule | where {$_ -like "* yes *"} | out-string
  $array = $schedule.split([Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries)
  foreach ($line in $array) {$scheduleset += "`r`n`t$($line)"}
  logERR 3 "SCHEDULE" "SCHEDULE :`r`n`t$($strLineSeparator)$($scheduleset)`r`n$($strLineSeparator)"
  $scheduleset = $null
  foreach ($line in $array) {
    $chunk = $line.split(" ", [StringSplitOptions]::RemoveEmptyEntries)
    $scheduleset += "$($chunk[2])-$($chunk[4]) : $($chunk[7])-$($chunk[5]) - $($chunk[6]) | `r`n"
  }
  $scheduleset = $scheduleset.replace("FileSystem","FS").replace("NetworkShares","NS").replace("SystemState","SS").replace("Exchange","EXCH").replace("VMWare","VM").replace("HyperV","HV")
  $scheduleset = $scheduleset.replace("Monday","M").replace("Tuesday","T").replace("Wednesday","W").replace("Thursday","Th").replace("Friday","F").replace("Saturday","Sa").replace("Sunday","S")
  $array = $scheduleset.split([Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries)
  $scheduleset = $null
  foreach ($line in $array) {$scheduleset += "`r`n`t$($line)"}
  logERR 3 "SCHEDULE" "FINAL SCHEDULE :`r`n`t$($strLineSeparator)$($scheduleset)`r`n$($strLineSeparator)"
  #COMPUTE SCHEDULE HASH
  $utf8 = new-object -TypeName System.Text.UTF8Encoding
  $md5 = new-object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
  $hash = [System.BitConverter]::ToString($md5.ComputeHash($utf8.GetBytes($scheduleset)))
  logERR 3 "SCHEDULE" "COMPUTED SCHEDULE HASH :`r`n`t$($strLineSeparator)`r`n`t$($hash)`r`n$($strLineSeparator)"
  #COMPARE SCHEDULE HASH
  if ($hashSchedules) {
    if (Compare-Object -ReferenceObject $hashSchedules -DifferenceObject $hash) {
      $scheduleMsg = "| Schedule Hashes are different |"
    } else {
      $scheduleMsg = "| Schedule Hashes are same |"
    }
  } elseif (-not $hashSchedules) {
    new-itemproperty -path "HKLM:\Software\Centrastage" -name "Custom18" -value "$($hash)" -force
  }
  if ($curSchedules) {
    logERR 3 "SCHEDULE" "PREV SCHEDULE :`r`n`t$($strLineSeparator)`r`n`t$($curSchedules.replace('`r`n', '`r`n`t'))`r`n$($strLineSeparator)"
    if ($scheduleset.trim() -match $curSchedules.trim()) {
      $scheduleMsg += "| Schedule Strings are same |"
      logERR 3 "SCHEDULE" "$($scheduleMsg)`r`n$($strLineSeparator)"
    } elseif ($scheduleset.trim() -notmatch $curSchedules.trim()) {
      $scheduleMsg += "| Schedule Strings are different |"
      logERR 4 "SCHEDULE" "$($scheduleMsg)`r`n$($strLineSeparator)"
    }
  } elseif ((-not $curSchedules) -or ($null -eq $curSchedules) -or ($curSchedules -eq "")) {
    new-itemproperty -path "HKLM:\Software\Centrastage" -name "Custom$($udfSchedules)" -value "$($scheduleset.trim())" -force
  }
} catch {
  $script:blnWARN = $true
  $err = "$($_.scriptstacktrace)`r`n$($_.Exception)`r`n$($_)`r`n"
  logERR 4 "SCHEDULE" "ERROR ENCOUNTERED :`r`n$($err)`r`n$($strLineSeparator)"
}
#QUERY ARCHIVE SCHEDULES
try {
  $archiveset = $null
  $archive = .\clienttool.exe control.archiving.list
  $archive = $archive | where {$_ -like "* yes *"} | out-string
  $array = $archive.split([Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries)
  foreach ($line in $array) {$archiveset += "`r`n`t$($line)"}
  logERR 3 "ARCHIVE" "ARCHIVE :`r`n`t$($strLineSeparator)$($archiveset)`r`n$($strLineSeparator)"
  $archiveset = $null
  foreach ($line in $array) {
    $chunk = $line.split(" ", [StringSplitOptions]::RemoveEmptyEntries)
    $archiveset += "$($chunk[2]) - $($chunk[4]) - Datasources : $($chunk[5]) - Archive Time : $($chunk[6]) - Archive Months : $($chunk[7]) - Archive Days : $($chunk[8]) | `r`n"
  }
  $archiveset = "$($chunk[2]) - $($chunk[4]) - Datasources : $($chunk[5]) - Archive Time : $($chunk[6]) - Archive Months : $($chunk[7]) - Archive Days : $($chunk[8])"
  $archiveset = $archiveset.replace("FileSystem","FS").replace("NetworkShares","NS").replace("SystemState","SS").replace("Exchange","EXCH").replace("VMWare","VM").replace("HyperV","HV")
  $archiveset = $archiveset.replace("Monday","M").replace("Tuesday","T").replace("Wednesday","W").replace("Thursday","Th").replace("Friday","F").replace("Saturday","Sa").replace("Sunday","S")
  $array = $archiveset.split([Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries)
  $archiveset = $null
  foreach ($line in $array) {$archiveset += "`r`n`t$($line)"}
  logERR 3 "ARCHIVE" "FINAL ARCHIVE :`r`n`t$($strLineSeparator)$($archiveset)`r`n$($strLineSeparator)"
  #COMPUTE ARCHIVE HASH
  $utf8 = new-object -TypeName System.Text.UTF8Encoding
  $md5 = new-object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
  $hash = [System.BitConverter]::ToString($md5.ComputeHash($utf8.GetBytes($archiveset)))
  logERR 3 "ARCHIVE" "COMPUTED ARCHIVE HASH :`r`n`t$($strLineSeparator)`r`n`t$($hash)`r`n$($strLineSeparator)"
  #COMPARE ARCHIVE HASH
  if ($hashArchives) {
    if (Compare-Object -ReferenceObject $hashArchives -DifferenceObject $hash) {
      $archiveMsg = "| Archive Hashes are different |"
    } else {
      $archiveMsg = "| Archive Hashes are same |"
    }
  } elseif (-not $hashArchives) {
    new-itemproperty -path "HKLM:\Software\Centrastage" -name "Custom20" -value "$($hash)" -force
  }
  if ($curArchives) {
    logERR 3 "ARCHIVE" "PREV ARCHIVE :`r`n$($strLineSeparator)`r`n`t$($curArchives.replace('`r`n', '`r`n`t'))`r`n$($strLineSeparator)"
    if ($archiveset.trim() -match $curArchives.trim()) {
      $archiveMsg += "| Archive Strings are same |"
      logERR 3 "ARCHIVE" "$($archiveMsg)`r`n$($strLineSeparator)"
    } elseif ($archiveset.trim() -notmatch $curArchives.trim()) {
      $archiveMsg += "| Archive Strings are different |"
      logERR 4 "ARCHIVE" "$($archiveMsg)`r`n$($strLineSeparator)"
    }
  } elseif ((-not $curArchives) -or ($null -eq $curArchives) -or ($curArchives -eq "")) {
    new-itemproperty -path "HKLM:\Software\Centrastage" -name "Custom$($udfArchives)" -value "$($archiveset.trim())" -force
  }
} catch {
  $script:blnWARN = $true
  $err = "$($_.scriptstacktrace)`r`n$($_.Exception)`r`n$($_)`r`n"
  logERR 4 "ARCHIVE" "ERROR ENCOUNTERED :`r`n$($err)`r`n$($strLineSeparator)"
}
#Stop script execution time calculation
StopClock
#DATTO OUTPUT
$result = $null
$finish = "$((Get-Date).ToString('yyyy-MM-dd hh:mm:ss'))"
if ((($scheduleMsg -notmatch "are different") -and ($scheduleMsg -match "are same")) -and 
  (($archiveMsg -notmatch "are different") -and ($archiveMsg -match "are same"))) {
    $hashMsg = "No Changes Detected"
} elseif (($scheduleMsg -match "are different") -or ($archiveMsg -match "are different")) {
  $hashMsg = "Detected Changes"
  $script:blnWARN = $true
}
if ($script:blnWARN) {
  write-DRMMAlert "Backup_Schedules : Warning : $($hashMsg) : See Diagnostics : $($finish)"
  write-DRMMDiag "$($script:diag)"
  exit 1
} elseif (-not $script:blnWARN) {
  write-DRMMAlert "Backup_Schedules : Healthy : $($hashMsg) : $($finish)"
  write-DRMMDiag "$($script:diag)"
  exit 0
}
#END SCRIPT
#------------