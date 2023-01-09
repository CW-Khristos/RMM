#region ----- DECLARATIONS ----
  #BELOW PARAM() MUST BE COMMENTED OUT FOR USE WITHIN DATTO RMM
  #UNCOMMENT BELOW PARAM() AND RENAME '$env:var' TO '$var' TO UTILIZE IN CLI
  #Param (
  #)
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
cd "C:\Program Files\Backup Manager"
#Start script execution time calculation
$ScrptStartTime = (Get-Date).ToString('dd-MM-yyyy hh:mm:ss')
$script:sw = [Diagnostics.Stopwatch]::StartNew()
#QUERY BACKUP SCHEDULES
try {
  $schedule = .\clienttool.exe control.schedule.list
  $schedule = $schedule | where {$_ -like "* yes *"}
  write-host "$($strLineSeparator)`r`nSCHEDULE :`r`n$($strLineSeparator)`r`n`t$($schedule)`r`n$($strLineSeparator)"
  $script:diag += "$($strLineSeparator)`r`nSCHEDULE :`r`n$($strLineSeparator)`r`n`t$($schedule)`r`n$($strLineSeparator)"
  $array = $schedule.split(" ", [StringSplitOptions]::RemoveEmptyEntries)
  write-host "$($strLineSeparator)`r`nARRAY SPLIT :`r`n$($strLineSeparator)"
  $script:diag += "$($strLineSeparator)`r`nARRAY SPLIT :`r`n$($strLineSeparator)`r`n"
  foreach ($item in $array) {
    write-host "`t$($item)"
    $script:diag += "`t$($item)`r`n"
  }
  if ($array.count -lt 11) {
    $scheduleset = "$($array[2])-$($array[4]) : $($array[7])-$($array[5]) - $($array[6])"
  } elseif ($array.count -ge 11) {
    while ($i -lt (($array.count / 10) - 1)) {
      $i += 1
      if ($i -eq 0) {
        $scheduleset = "$($array[2])-$($array[4]) : $($array[7])-$($array[5]) - $($array[6]) | "
      } elseif ($i -gt 0) {
        $scheduleset += "`r`n$($array[(($i * 10) + 2)])-$($array[(($i * 10) + 4)]) : $($array[(($i * 10) + 7)])-$($array[(($i * 10) + 5)]) - $($array[(($i * 10) + 6)]) | "
      }
    }
  }
  $scheduleset = $scheduleset.replace("FileSystem","FS").replace("NetworkShares","NS").replace("SystemState","SS").replace("Exchange","EXCH").replace("VMWare","VM").replace("HyperV","HV")
  $scheduleset = $scheduleset.replace("Monday","M").replace("Tuesday","T").replace("Wednesday","W").replace("Thursday","Th").replace("Friday","F").replace("Saturday","Sa").replace("Sunday","S")
  write-host "$($strLineSeparator)`r`nFINAL SCHEDULE :`r`n$($strLineSeparator)`r`n`t$($scheduleset)`r`n$($strLineSeparator)"
  $script:diag += "$($strLineSeparator)`r`nFINAL SCHEDULE :`r`n$($strLineSeparator)`r`n`t$($scheduleset)`r`n$($strLineSeparator)`r`n"
  new-itemproperty -path "HKLM:\Software\Centrastage" -name "Custom14" -value "$($scheduleset)" -force
} catch {
  $script:blnWARN = $true
  write-host "ERROR ENCOUNTERED"
  $script:diag += "`r`nERROR ENCOUNTERED`r`n"
}
#QUERY ARCHIVE SCHEDULES
try {
  $archive = .\clienttool.exe control.archiving.list
  $archive = $archive | where {$_ -like "* yes *"}
  write-host "$($strLineSeparator)`r`nARCHIVE :`r`n$($strLineSeparator)`r`n`t$($archive)`r`n$($strLineSeparator)"
  $script:diag += "$($strLineSeparator)`r`nARCHIVE :`r`n$($strLineSeparator)`r`n`t$($archive)`r`n$($strLineSeparator)`r`n"
  $array = $archive.split(" ", [StringSplitOptions]::RemoveEmptyEntries)
  write-host "$($strLineSeparator)`r`nARRAY SPLIT :`r`n$($strLineSeparator)"
  $script:diag += "$($strLineSeparator)`r`nARRAY SPLIT :`r`n$($strLineSeparator)`r`n"
  foreach ($item in $array) {
    write-host "`t$($item)"
    $script:diag += "`t$($item)`r`n"
  }
  $archiveset = "$($array[2]) - $($array[4]) - Datasources : $($array[5]) - Archive Time : $($array[6]) - Archive Months : $($array[7]) - Archive Days : $($array[8])"
  $archiveset = $archiveset.replace("FileSystem","FS").replace("NetworkShares","NS").replace("SystemState","SS").replace("Exchange","EXCH").replace("VMWare","VM").replace("HyperV","HV")
  $archiveset = $archiveset.replace("Monday","M").replace("Tuesday","T").replace("Wednesday","W").replace("Thursday","Th").replace("Friday","F").replace("Saturday","Sa").replace("Sunday","S")
  write-host "$($strLineSeparator)`r`nFINAL ARCHIVE :`r`n$($strLineSeparator)`r`n`t$($archiveset)`r`n$($strLineSeparator)"
  $script:diag += "$($strLineSeparator)`r`nFINAL ARCHIVE :`r`n$($strLineSeparator)`r`n`t$($archiveset)`r`n$($strLineSeparator)`r`n"
  new-itemproperty -path "HKLM:\Software\Centrastage" -name "Custom15" -value "$($archiveset)" -force
} catch {
  $script:blnWARN = $true
  write-host "ERROR ENCOUNTERED"
  $script:diag += "`r`nERROR ENCOUNTERED`r`n"
}
#Stop script execution time calculation
StopClock
#DATTO OUTPUT
if ($script:blnWARN) {
  write-DRMMAlert "Backup_Schedules : Execution Completed with Warnings : See Diagnostics"
  write-DRMMDiag "$($script:diag)"
  exit 1
} elseif (-not $script:blnWARN) {
  write-DRMMAlert "Backup_Schedules : Completed Execution"
  write-DRMMDiag "$($script:diag)"
  exit 0
}
#END SCRIPT
#------------