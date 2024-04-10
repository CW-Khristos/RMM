# Deploys BlueScreenView utility to C:\IT\BlueScreenView for monitoring BSODs
# https://www.nirsoft.net/utils/blue_screen_view.html
# https://www.nirsoft.net/utils/bluescreenview.zip
# https://www.nirsoft.net/utils/bluescreenview-x64.zip
# Modifications : Christopher Bledsoe - cbledsoe@ipmcomputers.com

#region ----- DECLARATIONS ----
  $script:diag = $null
  $script:bitarch = $null
  $script:blnWARN = $false
  $script:blnBREAK = $false
  $script:BSODFilter = $null
  $exePath = "$($env:strPath)"
  $logPath = "C:\IT\Log\BSOD_Monitor"
  $strLineSeparator = "----------------------------------"
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
  } ## write-DRMMAlert

  function Get-OSArch {
    #Determine Bit Architecture & OS Type
    $osarch = (get-wmiobject win32_operatingsystem).osarchitecture
    if ($osarch -like '*64*') {
      $script:bitarch = "bit64"
    } elseif ($osarch -like '*32*') {
      $script:bitarch = "bit32"
    }
  } ## Get-OSArch

  function StopClock {
    #Stop script execution time calculation
    $script:sw.Stop()
    $Days = $sw.Elapsed.Days
    $Hours = $sw.Elapsed.Hours
    $Minutes = $sw.Elapsed.Minutes
    $Seconds = $sw.Elapsed.Seconds
    $Milliseconds = $sw.Elapsed.Milliseconds
    $ScriptStopTime = (Get-Date).ToString('dd-MM-yyyy hh:mm:ss')
    write-output "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds"
    $script:diag += "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
  }

  function logERR ($intSTG, $strModule, $strErr) {
    $script:blnWARN = $true
    #CUSTOM ERROR CODES
    switch ($intSTG) {
      1 {                                                         #'ERRRET'=1 - NOT ENOUGH ARGUMENTS, END SCRIPT
        $script:blnBREAK = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - BSOD_Monitor - NO ARGUMENTS PASSED, END SCRIPT`r`n`r`n"
        write-output "$($strLineSeparator)`r`n$($(get-date)) - BSOD_Monitor - NO ARGUMENTS PASSED, END SCRIPT`r`n"
        break
      }
      2 {                                                         #'ERRRET'=2 - END SCRIPT
        $script:blnBREAK = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - BSOD_Monitor - ($($strModule)) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n"
        write-output "$($strLineSeparator)`r`n$($(get-date)) - BSOD_Monitor - ($($strModule)) :"
        write-output "$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n"
        break
      }
      3 {                                                         #'ERRRET'=3
        $script:blnWARN = $false
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - BSOD_Monitor - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
        write-output "$($strLineSeparator)`r`n$($(get-date)) - BSOD_Monitor - $($strModule) :"
        write-output "$($strLineSeparator)`r`n`t$($strErr)"
        break
      }
      default {                                                   #'ERRRET'=4+
        $script:blnBREAK = $false
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - BSOD_Monitor - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
        write-output "$($strLineSeparator)`r`n$($(get-date)) - BSOD_Monitor - $($strModule) :"
        write-output "$($strLineSeparator)`r`n`t$($strErr)"
        break
      }
    }
  }

  function dir-Check () {
  #CHECK 'PERSISTENT' FOLDERS
    if (-not (test-path -path "C:\temp")) {
      new-item -path "C:\temp" -itemtype directory -force
    }
    if (-not (test-path -path "C:\IT")) {
      new-item -path "C:\IT" -itemtype directory -force
    }
    if (-not (test-path -path "C:\IT\Log")) {
      new-item -path "C:\IT\Log" -itemtype directory -force
    }
    if (-not (test-path -path "C:\IT\Scripts")) {
      new-item -path "C:\IT\Scripts" -itemtype directory -force
    }
    if (-not (test-path -path "$($exePath)")) {
      new-item -path "$($exePath)" -itemtype directory -force | out-string
    }
  }

  function run-Deploy () {
    #CHECK 'PERSISTENT' FOLDERS
    dir-Check
    #CHECK IF BLUESCREENVIEW IS RUNNING
    $varAttempts = 0
    $running = get-process "BlueScreenView.exe" -erroraction silentlycontinue
    while (($running) -and ($varAttempts -lt 3)) {
      $varAttempts++
      $result = taskkill /IM "BlueScreenView.exe" /F
      start-sleep -seconds 5
      $result = get-process "BlueScreenView.exe" -erroraction silentlycontinue
      #BLUESCREENVIEW STILL RUNNING
      if ($result) {
        $running = $true
      #BLUESCREENVIEW NO LONGER RUNNING
      } elseif (-not $result) {
        $running = $false
      }
    }
    if (-not $running) {
      try {
        if (test-path -path "C:\IT\BlueScreenView.zip") {remove-item "C:\IT\BlueScreenView.zip" -force -erroraction continue}
        if ($script:bitarch -eq "bit32") {
          $srcBSV = "https://www.nirsoft.net/utils/bluescreenview.zip"
        } elseif ($script:bitarch -eq "bit64") {
          $srcBSV = "https://www.nirsoft.net/utils/bluescreenview-x64.zip"
        }
        #DOWNLOAD BLUESCREENVIEW.ZIP FROM NIRSOFT
        if (-not (test-path -path "C:\IT\BlueScreenView.zip")) {
          try {
            start-bitstransfer -source $srcBSV -destination "C:\IT\BlueScreenView.zip" -erroraction stop
          } catch {
            try {
              $web = new-object system.net.webclient
              $web.downloadfile($srcBSV, "C:\IT\BlueScreenView.zip")
            } catch {
              logERR 2 "run-Deploy" "FAILED TO DOWNLOAD BLUESCREENVIEW"
            }
          }
        }
        if (-not $script:blnBREAK) {
          $shell = New-Object -ComObject Shell.Application
          $zip = $shell.Namespace("C:\IT\BlueScreenView.zip")
          $items = $zip.items()
          $shell.Namespace("$($exePath)").CopyHere($items, 1556)
          logERR 3 "run-Deploy" "BLUESCREENVIEW EXTRACTED`r`n"
          start-sleep -seconds 2
          remove-item -path "C:\IT\BlueScreenView.zip" -force -erroraction continue
        }
        # inform the user
        $depdiag = "DEPLOY BLUESCREENVIEW COMPLETED - BlueScreenView has been deployed`r`n"
        $depdiag += "`tBlueScreenView Location : '$($exePath)'`r`n$($strLineSeparator)"
        logERR 3 "run-Deploy" "$($depdiag)"
      } catch {
        logERR 2 "run-Deploy" "FAILED TO EXTRACT BLUESCREENVIEW"
      }
    }
  }

  function run-Monitor () {
    #CHECK PATH EXISTENCE
    $result = test-path -path "$($exePath)"
    #PATH DOES NOT EXIST, DEPLOY BlueScreenView
    if (-not $result) {
      run-Deploy
    #PATH EXISTS
    } elseif ($result) {
      #CHECK EXECUTABLE AND DLL
      $exeFile = test-path -path "$($exePath)\BlueScreenView.exe"
      $chmFile = test-path -path "$($exePath)\BlueScreenView.chm"
      $txtFile = test-path -path "$($exePath)\readme.txt"
      if ((-not $exeFile) -or (-not $chmFile) -or (-not $txtFile)) {run-Deploy}
      try {
        Start-Process -FilePath "$($exePath)\Bluescreenview.exe" -ArgumentList "/scomma `"$($exePath)\Export.csv`"" -Wait
      } catch {
        $exportFile = "$($exePath)\Export.csv"
        if (Get-Item -Path $exportFile) {
          #Do nothing and move on. Process call has executed correctly and csv is generated for assessment.
        } else {
          $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
          logERR 2 "run-Monitor" "BSODView Command has Failed: $($err)"
        }
      }
      $script:BSODs = get-content "$($exePath)\Export.csv" | 
        ConvertFrom-Csv -Delimiter ',' -Header Dumpfile, Timestamp, Reason, Errorcode, Parameter1, Parameter2, Parameter3, Parameter4, CausedByDriver | 
          foreach-object {$_.Timestamp = [datetime]::Parse($_.timestamp, [System.Globalization.CultureInfo]::CurrentCulture); $_}
      Remove-item "$($exePath)\Export.csv" -Force
      $script:BSODFilter = $script:BSODs | where-object {$_.Timestamp -gt ((get-date).addhours(-12))}
    }
  }

  function run-Upgrade () {
    try {
      run-Remove
    } catch {
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
      logERR 2 "run-Upgrade" "Error during Remove :`r`n$($err)"
    }
    try {
      run-Deploy
    } catch {
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
      logERR 2 "run-Upgrade" "Error during Deploy :`r`n$($err)"
    }
  }

  function run-Remove () {
    #CHECK IF BLUESCREENVIEW IS RUNNING
    logERR 3 "run-Remove" "Checking if BlueScreenView is Running`r`n$($strLineSeparator)"
    $process = tasklist | findstr /B "BlueScreenView"
    #BLUESCREENVIEW RUNNING
    if ($process) {
      $running = $true
      logERR 3 "run-Remove" "Terminating BlueScreenView`r`n$($strLineSeparator)"
      $result = taskkill /IM "BlueScreenView" /F
      logERR 3 "run-Remove" "$($result)`r`n$($strLineSeparator)"
    #BLUESCREENVIEW NOT RUNNING
    } elseif (-not $process) {
      $running = $false
    }
    logERR 3 "run-Remove" "`tStatus : $($running)`r`n$($strLineSeparator)"
    #REMOVE FILES
    try {
      logERR 3 "run-Remove" "Removing BlueScreenView Files`r`n$($strLineSeparator)"
      remove-item -path "$($exePath)" -recurse -force -erroraction continue
    } catch {
      if ($_.exception -match "ItemNotFoundException") {
        logERR 3 "run-Remove" "NOT PRESENT : $($_.fullname)`r`n$($strLineSeparator)"
      } elseif ($_.exception -notmatch "ItemNotFoundException") {
        $script:blnWARN = $true
        $err = "ERROR :`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
        logERR 4 "run-Remove" "$($err)"
      }
    }
  }
#endregion ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
clear-host
#Start script execution time calculation
$ScrptStartTime = (get-date).ToString('dd-MM-yyyy hh:mm:ss')
$script:sw = [Diagnostics.Stopwatch]::StartNew()
#GET BIT ARCHITECTURE
Get-OSArch
#CHECK 'PERSISTENT' FOLDERS
dir-Check
if ($env:strTask -eq "DEPLOY") {
  try {
    logERR 3 "Mode : $($env:strTask)" "Deploying BlueScreenView Files`r`n$($strLineSeparator)"
    run-Deploy -erroraction stop
    
  } catch {
    $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
    logERR 2 "Mode : $($env:strTask)" "Error during Deploy :`r`n$($err)"
  }
} elseif ($env:strTask -eq "MONITOR") {
  try {
    logERR 3 "Mode : $($env:strTask)" "Monitoring BlueScreenView Files`r`n$($strLineSeparator)"
    run-Monitor 
    
  } catch {
    $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
    logERR 2 "Mode : $($env:strTask)" "Error during Monitoring :`r`n$($err)"
  }
} elseif ($env:strTask -eq "UPGRADE") {
  try {
    logERR 3 "Mode : $($env:strTask)" "Replacing BlueScreenView Files`r`n$($strLineSeparator)"
    run-Upgrade -erroraction stop
    
  } catch {
    $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
    logERR 2 "Mode : $($env:strTask)" "Error during Upgrade :`r`n$($err)"
  }
} elseif ($env:strTask -eq "REMOVE") {
  try {
    logERR 3 "Mode : $($env:strTask)" "Removing BlueScreenView Files`r`n$($strLineSeparator)"
    run-Remove -erroraction stop
    
  } catch {
    $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
    logERR 2 "Mode : $($env:strTask)" "Error during Remove :`r`n$($err)"
  }
}
#DATTO OUTPUT
#Stop script execution time calculation
StopClock
#CLEAR LOGFILE
$null | set-content $logPath -force
$finish = "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))"
if (-not $script:blnBREAK) {
  if (-not $script:blnWARN) {
    $result = "$($env:strTask) : Execution Successful : $($finish)"
    $enddiag = "$($result)`r`n$($strLineSeparator)`r`n"
  } elseif ($script:blnWARN) {
    $result = "$($env:strTask) : Execution Completed with Warnings : $($finish)"
    $enddiag = "$($result)`r`n$($strLineSeparator)`r`n"
  }
  if (-not $script:BSODFilter) {
    if ($env:strTask -eq "DEPLOY") {
      $alert = "- BSODView Files Deployed"
      $enddiag += "`t- BSODView Files Deployed`r`n$($strLineSeparator)"
    } elseif ($env:strTask -eq "MONITOR") {
      $alert = "- Healthy - No BSODs found in the last 12 hours"
      $enddiag += "`t- Healthy - No BSODs found in the last 12 hours`r`n$($strLineSeparator)"
    } elseif ($env:strTask -eq "UPGRADE") {
      $alert = "- BSODView Files Replaced"
      $enddiag += "`t- BSODView Files Replaced`r`n$($strLineSeparator)"
    } elseif ($env:strTask -eq "REMOVE") {
      $alert = "- BSODView Files Removed"
      $enddiag += "`t- BSODView Files Removed`r`n$($strLineSeparator)"
    }
    #WRITE TO LOGFILE
    logERR 3 "BSOD_Monitor" "$($enddiag)"
    "$($script:diag)" | add-content $logPath -force
    write-DRMMAlert "BSOD_Monitor $($alert) : $($result)"
    write-DRMMDiag "$($script:diag)`r`n$($enddiag)"
    exit 0
  } elseif ($script:BSODFilter) {
    if ($env:strTask -eq "DEPLOY") {
      $alert = "- BSODView Files Deployed"
      $enddiag += "`t- BSODView Files Deployed`r`n$($strLineSeparator)"
    } elseif ($env:strTask -eq "MONITOR") {
      $alert = "- Unhealthy - BSOD found : Diagnostics - $($logPath)"
      $enddiag += "`t- Unhealthy - BSOD found : Diagnostics - $($logPath)`r`n$($strLineSeparator)"
    } elseif ($env:strTask -eq "UPGRADE") {
      $alert = "- BSODView Files Replaced"
      $enddiag += "`t- BSODView Files Replaced`r`n$($strLineSeparator)"
    } elseif ($env:strTask -eq "REMOVE") {
      $alert = "- BSODView Files Removed"
      $enddiag += "`t- BSODView Files Removed`r`n$($strLineSeparator)"
    }
    #WRITE TO LOGFILE
    logERR 3 "BSOD_Monitor" "$($enddiag)"
    "$($script:diag)" | add-content $logPath -force
    write-DRMMAlert "BSOD_Monitor $($alert) : $($result)"
    write-DRMMDiag "$($script:diag)`r`n$($enddiag)"
    exit 1
  }
} elseif ($script:blnBREAK) {
  #WRITE TO LOGFILE
  $result = "$($env:strTask) : Execution Failed : $($finish)"
  $enddiag = "$($result)`r`n$($strLineSeparator)`r`n"
  logERR 4 "BSOD_Monitor" "$($enddiag)"
  "$($script:diag)" | add-content $logPath -force
  write-DRMMAlert "BSOD_Monitor : $($result) : Diagnostics - $($logPath)"
  write-DRMMDiag "$($script:diag)"
  exit 1
}
#END SCRIPT
#------------