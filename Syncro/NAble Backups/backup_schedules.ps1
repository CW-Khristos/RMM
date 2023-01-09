#region ----- DECLARATIONS ----
  #BELOW PARAM() MUST BE COMMENTED OUT FOR USE WITHIN DATTO RMM
  #UNCOMMENT BELOW PARAM() AND RENAME '$env:var' TO '$var' TO UTILIZE IN CLI
  #Param (
  #)
  Import-Module $env:SyncroModule
  #VERSION FOR SCRIPT UPDATE
  $strSCR           = "Backup_Schedules"
  $strVER           = [version]"0.1.0"
  $strREPO          = "RMM"
  $strBRCH          = "dev"
  $strDIR           = "Datto"
  $script:diag      = $null
  $script:blnWARN   = $false
  $script:blnBREAK  = $false
  $strLineSeparator = "---------"
#endregion ----- DECLARATIONS ----

#region ----- FUNCTIONS ----
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
cd "C:\Program Files\Backup Manager"
#Start script execution time calculation
$ScrptStartTime = (Get-Date).ToString('dd-MM-yyyy hh:mm:ss')
$script:sw = [Diagnostics.Stopwatch]::StartNew()
#QUERY BACKUP SCHEDULES
try {
  $schedule = .\clienttool.exe control.schedule.list
  $schedule = $schedule | where {$_ -like "* yes *"}
  $array = $schedule.split(" ", [StringSplitOptions]::RemoveEmptyEntries)
  if ($array.count -lt 11) {
    $scheduleset = "$($array[2]) - $($array[4]) : $($array[7]) - $($array[5]) - $($array[6])"
  } elseif ($array.count -ge 11) {
    while ($i -le ($array.count / 10)) {
      $i += 1
      if ($i -eq 0) {
        $scheduleset = "$($array[2]) - $($array[4]) : $($array[7]) - $($array[5]) - $($array[6])"
      } elseif ($i -gt 0) {
        $scheduleset += "`r`n$($array[(($i * 10) + 2)]) - $($array[(($i * 10) + 4)]) : $($array[(($i * 10) + 7)]) - $($array[(($i * 10) + 5)]) - $($array[(($i * 10) + 6)])"
      }
    }
  }
  $scheduleset = $scheduleset.replace("FileSystem","FS").replace("NetworkShares","NS").replace("SystemState","SS")
  $scheduleset = $scheduleset.replace("Monday","Mon").replace("Tuesday","Tue").replace("Wednesday","Wed").replace("Thursday","Thu").replace("Friday","Fri").replace("Saturday","Sat").replace("Sunday","Sun")
} catch {
  $script:blnWARN = $true
  write-host "ERROR ENCOUNTERED"
  $script:diag += "`r`nERROR ENCOUNTERED`r`n"
}
#QUERY ARCHIVE SCHEDULES
try {
  $archive = .\clienttool.exe control.archiving.list
  $archive = $archive | where {$_ -like "* yes *"}
  $array = $archive.split(" ", [StringSplitOptions]::RemoveEmptyEntries)
  $archiveset = "$($array[2]) - $($array[3]) - Datasrouces : $($array[4]) - Archive Time : $($array[5]) - Archive Months : $($array[6]) - Archive Days : $($array[7])"
  $archiveset = $archiveset.replace("FileSystem","FS").replace("NetworkShares","NS").replace("SystemState","SS")
  $archiveset = $archiveset.replace("Monday","Mon").replace("Tuesday","Tue").replace("Wednesday","Wed").replace("Thursday","Thu").replace("Friday","Fri").replace("Saturday","Sat").replace("Sunday","Sun")
} catch {
  $script:blnWARN = $true
  write-host "ERROR ENCOUNTERED"
  $script:diag += "`r`nERROR ENCOUNTERED`r`n"
}
#Stop script execution time calculation
StopClock
#SYNCRO OUTPUT
if ($script:blnWARN) {
  Log-Activity -Message "Backup_Schedules : Execution Completed with Warnings : See Diagnostics" -EventName "Backup_Schedules : Warning"
  Rmm-Alert -Category "Backup_Schedules : Warning" -Body "$($script:diag)"
  exit 1
} elseif (-not $script:blnWARN) {
  Set-Asset-Field -Subdomain 'ipmcomputers' -Name "Backup Schedule" -Value "$($scheduleset)"
  Set-Asset-Field -Subdomain 'ipmcomputers' -Name "Backup Archiving" -Value "$($archiveset)"
  Log-Activity -Message "Backup_Schedules : Completed Execution" -EventName "Backup_Schedules : Completed Execution"
  exit 0
}
#END SCRIPT
#------------