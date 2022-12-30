#region ----- DECLARATIONS ----
  #BELOW PARAM() MUST BE COMMENTED OUT FOR USE WITHIN DATTO RMM
  #UNCOMMENT BELOW PARAM() AND RENAME '$env:var' TO '$var' TO UTILIZE IN CLI
  #VERSION FOR SCRIPT UPDATE
  $strSCR           = "Monitor_FileCanaries"
  $strVER           = [version]"0.1.0"
  $strREPO          = "RMM"
  $strBRCH          = "dev"
  $strDIR           = "Datto"
  $script:diag      = $null
  $script:blnWARN   = $false
  $script:blnBREAK  = $false
  $strLineSeparator = "---------"
  $logPath          = "C:\IT\Log\Monitor_FileCanaries"
  $CreateLocations  = @('AllDesktops', 'AllDocuments', 'AllDrives')
  $FileContent      = "This file is a special file created by your IT provider. For more information contact the IT Support desk."
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
        write-host "$($strLineSeparator)`r`n$((get-date).ToString('dd-MM-yyyy hh:mm:ss'))`t - Monitor_FileCanaries - ERROR DELETING FILE / FOLDER`r`n$($strErr)`r`n$($strLineSeparator)`r`n"
        $script:diag += "$($strLineSeparator)`r`n$((get-date).ToString('dd-MM-yyyy hh:mm:ss'))`t - Monitor_FileCanaries - ERROR DELETING FILE / FOLDER`r`n$($strErr)`r`n$($strLineSeparator)`r`n`r`n"
      }
      2 {                                                                             #'ERRRET'=2 - NOT ENOUGH ARGUMENTS, END SCRIPT
        write-host "$($strLineSeparator)`r`n$((get-date).ToString('dd-MM-yyyy hh:mm:ss'))`t - Monitor_FileCanaries - NO ARGUMENTS PASSED, END SCRIPT`r`n$($strErr)`r`n$($strLineSeparator)`r`n"
        $script:diag += "$($strLineSeparator)`r`n$((get-date).ToString('dd-MM-yyyy hh:mm:ss'))`t - Monitor_FileCanaries - NO ARGUMENTS PASSED, END SCRIPT`r`n$($strErr)`r`n$($strLineSeparator)`r`n`r`n"
      }
      default {                                                                       #'ERRRET'=3+
        write-host "$($strLineSeparator)`r`n$((get-date).ToString('dd-MM-yyyy hh:mm:ss'))`t - Monitor_FileCanaries - $($strErr)`r`n$($strLineSeparator)`r`n"
        $script:diag += "$($strLineSeparator)`r`n$((get-date).ToString('dd-MM-yyyy hh:mm:ss'))`t - Monitor_FileCanaries - $($strErr)`r`n$($strLineSeparator)`r`n`r`n"
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
    $ScriptStopTime = (get-date).ToString('dd-MM-yyyy hh:mm:ss')
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
clear-host
#Start script execution time calculation
$ScrptStartTime = (Get-Date).ToString('dd-MM-yyyy hh:mm:ss')
$script:sw = [Diagnostics.Stopwatch]::StartNew()
#PREPARE DRIVE EXCLUSIONS
if (($null -ne $env:ExcludedDrives) -and ($env:ExcludedDrives -ne "")) {
  $Excludes = $env:ExcludedDrives.split("|",[System.StringSplitOptions]::RemoveEmptyEntries)
}
#COLLECT ALL DRIVES / PARTITIONS FOR MATCHING CANARY PATHS TO DRIVE EXCLUSIONS
$pDisks = Get-WmiObject -Class Win32_DiskDrive | Select DeviceID, Caption
$dPartitions = Get-WmiObject -Class Win32_DiskDriveToDiskPartition
$lPartitions = Get-WmiObject -Class Win32_LogicalDiskToPartition

$CanaryStatus = foreach ($Locations in $CreateLocations) {
  $AllLocations = switch ($Locations) {
    "AllDesktops" { (Get-ChildItem "C:\Users\" -Recurse -Force -Filter 'Desktop' -Depth 3).FullName }
    "AllDocuments" { (Get-ChildItem "C:\Users\" -Recurse -Force -Filter 'Documents' -Depth 3).fullname }
    "AllDrives" { ([System.IO.DriveInfo]::getdrives() | Where-Object { $_.DriveType -eq 'Fixed' }).Name }
    default { $Locations }
  }
  foreach ($Location in $AllLocations) {
    $script:blnBREAK = $false
    if (($null -ne $Excludes) -and ($Excludes -ne "")) {
      $localdrive = $location.split(":")[0] + ":"
      $localdrive = $lPartitions | where {$_.dependent -match $localdrive}
      $localdrive = $dPartitions | where {$_.dependent -like $localdrive.antecedent}
      $localdrive = $pDisks | where {$localdrive.antecedent -match $_.deviceid.replace("\", "").replace(".", "")}
    }
    foreach ($exclude in $Excludes) {
      if (($localdrive.model -like "*$($exclude)*") -or ($localdrive.caption -like "*$($exclude)*")) {
        $script:blnBREAK = $true
        write-host "TRIGGERED EXCLUDE FOR DRIVE :" $location
      }
    }
    if (-not $script:blnBREAK) {
      if ((Test-Path "$($Location)\CanaryFile.pdf") -eq $false) {
        $File = New-Item $Location -Name "CanaryFile.pdf" -Value $FileContent
        $file.LastWriteTime = $(Get-Date).AddHours(-1)
        $file.Attributes = 'hidden'
      } else {
        $ExistingFile = Get-Item "$($Location)\CanaryFile.pdf" -Force
        if ($ExistingFile.LastWriteTime -gt (Get-Date).AddHours(-1)) { "$($Location)\CanaryFile.pdf is unhealthy. The LastWriteTime was $($ExistingFile.LastWriteTime)" }
        $ExistingFileContents = Get-Content $ExistingFile -Force
        if ($ExistingFileContents -ne $FileContent) { "$($Location)\CanaryFile.pdf is unhealthy. The contents do not match. This is a sign the file has most likely been encrypted" }
      }
    }
  }
}
$script:diag += $CanaryStatus
#Stop script execution time calculation
StopClock
#WRITE LOGFILE
if ($blnLOG) {$script:diag | out-file $logPath}
#DATTO OUTPUT
if (!$CanaryStatus) {
  write-DRMMAlert "Healthy - No Canary files edited"
  write-DRMMDiag "$($script:diag)"
  exit 0
} else {
  write-DRMMAlert "Canary file edited in the last hour"
  write-DRMMDiag "$($script:diag)"
  exit 1
}
#END SCRIPT
#------------