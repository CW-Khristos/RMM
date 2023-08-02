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

  function logERR($intSTG, $strErr) {
    $script:blnWARN = $true
    #CUSTOM ERROR CODES
    switch ($intSTG) {
      1 {                                                                             #'ERRRET'=1 - ERROR DELETING FILE / FOLDER
        $script:diag += "$($strLineSeparator)`r`n$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - Backup_Schedules - ERROR DELETING FILE / FOLDER`r`n$($strErr)`r`n$($strLineSeparator)`r`n`r`n"
        write-host "$($strLineSeparator)`r`n$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - Backup_Schedules - ERROR DELETING FILE / FOLDER`r`n$($strErr)`r`n$($strLineSeparator)`r`n"
      }
      2 {                                                                             #'ERRRET'=2 - NOT ENOUGH ARGUMENTS, END SCRIPT
        $script:diag += "$($strLineSeparator)`r`n$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - Backup_Schedules - NO ARGUMENTS PASSED, END SCRIPT`r`n$($strErr)`r`n$($strLineSeparator)`r`n`r`n"
        write-host "$($strLineSeparator)`r`n$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - Backup_Schedules - NO ARGUMENTS PASSED, END SCRIPT`r`n$($strErr)`r`n$($strLineSeparator)`r`n"
      }
      default {                                                                       #'ERRRET'=3+
        write-host "$($strLineSeparator)`r`n$((get-date).ToString('dd-MM-yyyy hh:mm:ss'))`t - Backup_Schedules - $($strErr)`r`n$($strLineSeparator)`r`n"
        $script:diag += "$($strLineSeparator)`r`n$((get-date).ToString('dd-MM-yyyy hh:mm:ss'))`t - Backup_Schedules - $($strErr)`r`n$($strLineSeparator)`r`n`r`n"
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
write-host "Cached Archive Hash (UDF20) : $($hashArchives)"
$script:diag += "Cached Archive Hash (UDF20) : $($hashArchives)`r`n"
write-host "Cached Schedule Hash (UDF18) : $($hashSchedules)`r`n"
$script:diag += "Cached Schedule Hash (UDF18) : $($hashSchedules)`r`n`r`n"
cd "C:\Program Files\Backup Manager"
#Start script execution time calculation
$ScrptStartTime = (Get-Date).ToString('dd-MM-yyyy hh:mm:ss')
$script:sw = [Diagnostics.Stopwatch]::StartNew()
#QUERY BACKUP SCHEDULES
try {
  $scheduleset = $null
  $schedule = .\clienttool.exe control.schedule.list
  $schedule = $schedule | where {$_ -like "* yes *"} | out-string
  $array = $schedule.split([Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries)
  write-host "$($strLineSeparator)`r`nSCHEDULE :`r`n$($strLineSeparator)"
  $script:diag += "$($strLineSeparator)`r`nSCHEDULE :`r`n$($strLineSeparator)`r`n"
  foreach ($line in $array) {write-host "`t$($line)"; $script:diag += "`t$($line)`r`n"}
  write-host "$($strLineSeparator)"
  $script:diag += "`r`n$($strLineSeparator)`r`n"
  #$chunk = $schedule.split(" ", [StringSplitOptions]::RemoveEmptyEntries)
  #write-host "$($strLineSeparator)`r`nARRAY SPLIT :`r`n$($strLineSeparator)"
  #$script:diag += "$($strLineSeparator)`r`nARRAY SPLIT :`r`n$($strLineSeparator)`r`n"
  #foreach ($item in $chunk) {write-host "`t$($item)"; $script:diag += "`t$($item)`r`n"}
  foreach ($line in $array) {
    $chunk = $line.split(" ", [StringSplitOptions]::RemoveEmptyEntries)
    $scheduleset += "$($chunk[2])-$($chunk[4]) : $($chunk[7])-$($chunk[5]) - $($chunk[6]) | `r`n"
  }
  $scheduleset = $scheduleset.replace("FileSystem","FS").replace("NetworkShares","NS").replace("SystemState","SS").replace("Exchange","EXCH").replace("VMWare","VM").replace("HyperV","HV")
  $scheduleset = $scheduleset.replace("Monday","M").replace("Tuesday","T").replace("Wednesday","W").replace("Thursday","Th").replace("Friday","F").replace("Saturday","Sa").replace("Sunday","S")
  $array = $scheduleset.split([Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries)
  write-host "$($strLineSeparator)`r`nFINAL SCHEDULE :`r`n$($strLineSeparator)"
  $script:diag += "$($strLineSeparator)`r`nFINAL SCHEDULE :`r`n$($strLineSeparator)`r`n"
  foreach ($line in $array) {write-host "`t$($line)"; $script:diag += "`t$($line)`r`n"}
  write-host "$($strLineSeparator)"
  $script:diag += "$($strLineSeparator)`r`n"
  if (($null -eq $curSchedules) -or ($curSchedules -eq "") -or (-not $curSchedules)) {
    new-itemproperty -path "HKLM:\Software\Centrastage" -name "Custom$($udfSchedules)" -value "$($scheduleset)" -force
  }
  #COMPUTE SCHEDULE HASH
  $utf8 = new-object -TypeName System.Text.UTF8Encoding
  $md5 = new-object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
  $hash = [System.BitConverter]::ToString($md5.ComputeHash($utf8.GetBytes($scheduleset)))
  write-host "$($strLineSeparator)`r`nCOMPUTED SCHEDULE HASH :`r`n$($strLineSeparator)`r`n`t$($hash)`r`n$($strLineSeparator)"
  $script:diag += "$($strLineSeparator)`r`nCOMPUTED SCHEDULE HASH :`r`n$($strLineSeparator)`r`n`t$($hash)`r`n$($strLineSeparator)`r`n"
  #COMPARE SCHEDULE HASH
  if ($hashSchedules) {
    if (Compare-Object -ReferenceObject $hashSchedules -DifferenceObject $hash) {
      $scheduleMsg = "| Schedule Hashes are different |"
    } else {
      $scheduleMsg = "| Schedule Hashes are same |"
    }
    write-host "`t$($scheduleMsg)`r`n$($strLineSeparator)`r`nPREV SCHEDULE :`r`n$($strLineSeparator)`r`n`t$($curSchedules)`r`n$($strLineSeparator)"
    $script:diag += "`t$($scheduleMsg)`r`n$($strLineSeparator)`r`nPREV SCHEDULE :`r`n$($strLineSeparator)`r`n`t$($curSchedules)`r`n$($strLineSeparator)`r`n"
  } elseif (-not $hashSchedules) {
    new-itemproperty -path "HKLM:\Software\Centrastage" -name "Custom18" -value "$($hash)" -force
  }
} catch {
  $script:blnWARN = $true
  $err = "$($_.scriptstacktrace)`r`n$($_.Exception)`r`n$($_)`r`n"
  write-host "ERROR ENCOUNTERED`r`n$($err)"
  $script:diag += "`r`nERROR ENCOUNTERED`r`n$($err)`r`n"
}
#QUERY ARCHIVE SCHEDULES
try {
  $archive = .\clienttool.exe control.archiving.list
  $archive = $archive | where {$_ -like "* yes *"} | out-string
  $array = $archive.split([Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries)
  write-host "$($strLineSeparator)`r`nARCHIVE :`r`n$($strLineSeparator)"
  $script:diag += "$($strLineSeparator)`r`nARCHIVE :`r`n$($strLineSeparator)`r`n"
  foreach ($line in $array) {write-host "`t$($line)"; $script:diag += "`t$($line)`r`n"}
  write-host "$($strLineSeparator)"
  $script:diag += "`r`n$($strLineSeparator)`r`n"
  #$chunk = $archive.split(" ", [StringSplitOptions]::RemoveEmptyEntries)
  #write-host "$($strLineSeparator)`r`nARRAY SPLIT :`r`n$($strLineSeparator)"
  #$script:diag += "$($strLineSeparator)`r`nARRAY SPLIT :`r`n$($strLineSeparator)`r`n"
  #foreach ($item in $chunk) {write-host "`t$($item)"; $script:diag += "`t$($item)`r`n"}
  foreach ($line in $array) {
    $chunk = $line.split(" ", [StringSplitOptions]::RemoveEmptyEntries)
    $archiveset += "$($chunk[2]) - $($chunk[4]) - Datasources : $($chunk[5]) - Archive Time : $($chunk[6]) - Archive Months : $($chunk[7]) - Archive Days : $($chunk[8]) | `r`n"
  }
  $archiveset = "$($chunk[2]) - $($chunk[4]) - Datasources : $($chunk[5]) - Archive Time : $($chunk[6]) - Archive Months : $($chunk[7]) - Archive Days : $($chunk[8])"
  $archiveset = $archiveset.replace("FileSystem","FS").replace("NetworkShares","NS").replace("SystemState","SS").replace("Exchange","EXCH").replace("VMWare","VM").replace("HyperV","HV")
  $archiveset = $archiveset.replace("Monday","M").replace("Tuesday","T").replace("Wednesday","W").replace("Thursday","Th").replace("Friday","F").replace("Saturday","Sa").replace("Sunday","S")
  $array = $archiveset.split([Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries)
  write-host "$($strLineSeparator)`r`nFINAL ARCHIVE :`r`n$($strLineSeparator)"
  $script:diag += "$($strLineSeparator)`r`nFINAL ARCHIVE :`r`n$($strLineSeparator)`r`n"
  foreach ($line in $array) {write-host "`t$($line)"; $script:diag += "`t$($line)`r`n"}
  write-host "$($strLineSeparator)"
  $script:diag += "$($strLineSeparator)`r`n"
  if (($null -eq $curArchives) -or ($curArchives -eq "") -or (-not $curArchives)) {
    new-itemproperty -path "HKLM:\Software\Centrastage" -name "Custom$($udfArchives)" -value "$($archiveset)" -force
  }
  #COMPUTE ARCHIVE HASH
  $utf8 = new-object -TypeName System.Text.UTF8Encoding
  $md5 = new-object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
  $hash = [System.BitConverter]::ToString($md5.ComputeHash($utf8.GetBytes($archiveset)))
  write-host "$($strLineSeparator)`r`nCOMPUTED ARCHIVE HASH :`r`n$($strLineSeparator)`r`n`t$($hash)`r`n$($strLineSeparator)"
  $script:diag += "$($strLineSeparator)`r`nCOMPUTED ARCHIVE HASH :`r`n$($strLineSeparator)`r`n`t$($hash)`r`n$($strLineSeparator)`r`n"
  #COMPARE ARCHIVE HASH
  if ($hashArchives) {
    if (Compare-Object -ReferenceObject $hashArchives -DifferenceObject $hash) {
      $archiveMsg = "| Archive Hashes are different |"
    } else {
      $archiveMsg = "| Archive Hashes are same |"
    }
    write-host "`t$($archiveMsg)`r`n$($strLineSeparator)`r`nPREV ARCHIVE :`r`n$($strLineSeparator)`r`n`t$($curArchives)`r`n$($strLineSeparator)"
    $script:diag += "`t$($archiveMsg)`r`n$($strLineSeparator)`r`nPREV ARCHIVE :`r`n$($strLineSeparator)`r`n`t$($curArchives)`r`n$($strLineSeparator)`r`n"
  } elseif (-not $hashArchives) {
    new-itemproperty -path "HKLM:\Software\Centrastage" -name "Custom20" -value "$($hash)" -force
  }
} catch {
  $script:blnWARN = $true
  $err = "$($_.scriptstacktrace)`r`n$($_.Exception)`r`n$($_)`r`n"
  write-host "ERROR ENCOUNTERED`r`n$($err)"
  $script:diag += "`r`nERROR ENCOUNTERED`r`n$($err)`r`n"
}
#Stop script execution time calculation
StopClock
#DATTO OUTPUT
$finish = "$((Get-Date).ToString('yyyy-MM-dd hh:mm:ss'))"
if (($scheduleMsg -match "Hashes are same") -and ($archiveMsg -match "Hashes are same")) {
  $hashMsg = "All Hashes Match"
} elseif (($scheduleMsg -match "Hashes are different") -or ($archiveMsg -match "Hashes are different")) {
  $hashMsg = "Detected Hash Change"
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