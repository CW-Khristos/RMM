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
  $logPath = "C:\IT\Log\BSOD_Monitor"
  $exePath = "$($env:BlueScreenViewPath)"
  $strLineSeparator = "----------------------------------"
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

  function Get-OSArch {                                                                             #Determine Bit Architecture & OS Type
    #OS Bit Architecture
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
    write-host "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds"
    $script:diag += "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
  }

  function logERR ($intSTG, $strModule, $strErr) {
    $script:blnWARN = $true
    #CUSTOM ERROR CODES
    switch ($intSTG) {
      1 {                                                         #'ERRRET'=1 - NOT ENOUGH ARGUMENTS, END SCRIPT
        $script:blnBREAK = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - BSOD_Monitor - NO ARGUMENTS PASSED, END SCRIPT`r`n`r`n"
        write-host "$($strLineSeparator)`r`n$($(get-date)) - BSOD_Monitor - NO ARGUMENTS PASSED, END SCRIPT`r`n" -foregroundcolor red
      }
      2 {                                                         #'ERRRET'=2 - END SCRIPT
        $script:blnBREAK = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - BSOD_Monitor - ($($strModule)) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n"
        write-host "$($strLineSeparator)`r`n$($(get-date)) - BSOD_Monitor - ($($strModule)) :" -foregroundcolor red
        write-host "$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n" -foregroundcolor red
      }
      3 {                                                         #'ERRRET'=3
        $script:blnWARN = $false
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - BSOD_Monitor - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
        write-host "$($strLineSeparator)`r`n$($(get-date)) - BSOD_Monitor - $($strModule) :" -foregroundcolor yellow
        write-host "$($strLineSeparator)`r`n`t$($strErr)" -foregroundcolor yellow
      }
      default {                                                   #'ERRRET'=4+
        $script:blnBREAK = $false
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - BSOD_Monitor - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
        write-host "$($strLineSeparator)`r`n$($(get-date)) - BSOD_Monitor - $($strModule) :" -foregroundcolor yellow
        write-host "$($strLineSeparator)`r`n`t$($strErr)" -foregroundcolor red
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
    if (-not (test-path -path "C:\IT\BlueScreenView")) {
      new-item -path "C:\IT\BlueScreenView" -itemtype directory -force | out-string
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
      if ($result) {                   #BLUESCREENVIEW STILL RUNNING
        $running = $true
      } elseif (-not $result) {        #BLUESCREENVIEW NO LONGER RUNNING
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
            #IPM-Khristos
            start-bitstransfer -source $srcBSV -destination "C:\IT\BlueScreenView.zip" -erroraction stop
          } catch {
            try {
              #IPM-Khristos
              $web = new-object system.net.webclient
              $web.downloadfile($srcBSV, "C:\IT\BlueScreenView.zip")
            } catch {
              $depdiag = "FAILED TO DOWNLOAD BLUESCREENVIEW"
              logERR 2 "run-Deploy" "$($depdiag)"
            }
          }
        }
        if (-not $script:blnBREAK) {
          $shell = New-Object -ComObject Shell.Application
          $zip = $shell.Namespace("C:\IT\BlueScreenView.zip")
          $items = $zip.items()
          $shell.Namespace("$($exePath)").CopyHere($items, 1556)
          write-host " - BLUESCREENVIEW EXTRACTED"
          $script:diag += " - BLUESCREENVIEW EXTRACTED`r`n"
          start-sleep -seconds 2
          remove-item -path "C:\IT\BlueScreenView.zip" -force -erroraction continue
        }
        # inform the user
        $depdiag = "DEPLOY BLUESCREENVIEW COMPLETED - BlueScreenView has been deployed`r`n"
        $depdiag += "`tBlueScreenView Location : '$($exePath)'`r`n$($strLineSeparator)"
        logERR 3 "run-Deploy" "$($depdiag)"
      } catch {
        $depdiag = "FAILED TO EXTRACT BLUESCREENVIEW"
        logERR 2 "run-Deploy" "$($depdiag)"
      }
    }
  }

  function run-Monitor () {
    #CHECK PATH EXISTENCE
    $result = test-path -path "$($exePath)"
    if (-not $result) {                   #PATH DOES NOT EXIST, DEPLOY BlueScreenView
      run-Deploy
    } elseif ($result) {                  #PATH EXISTS
      #CHECK EXECUTABLE AND DLL
      $exeFile = test-path -path "$($exePath)\BlueScreenView.exe"
      $chmFile = test-path -path "$($exePath)\BlueScreenView.chm"
      $txtFile = test-path -path "$($exePath)\readme.txt"
      if ((-not $exeFile) -or (-not $chmFile) -or (-not $txtFile)) {
        run-Deploy
      }
      try {
        Start-Process -FilePath "$($exePath)\Bluescreenview.exe" -ArgumentList "/scomma `"$($exePath)\Export.csv`"" -Wait
      } catch {
        $exportFile = "$($exePath)\Export.csv"
        if (Get-Item -Path $exportFile) {
          #Do nothing and move on. Process call has executed correctly and csv is generated for assessment.
        } else {
          $mondiag = "BSODView Command has Failed: $($_.Exception.Message)`r`n$($strLineSeparator)"
          logERR 2 "run-Monitor" "$($mondiag)"
        }
      }
      $BSODs = get-content "$($exePath)\Export.csv" | 
        ConvertFrom-Csv -Delimiter ',' -Header Dumpfile, Timestamp, Reason, Errorcode, Parameter1, Parameter2, Parameter3, Parameter4, CausedByDriver | 
          foreach-object {$_.Timestamp = [datetime]::Parse($_.timestamp, [System.Globalization.CultureInfo]::CurrentCulture); $_}
      Remove-item "$($exePath)\Export.csv" -Force
      $BSODFilter = $BSODs | where-object {$_.Timestamp -gt ((get-date).addhours(-12))}
    }
  }

  function run-Upgrade () {
    try {
      run-Remove
    } catch {
      
    }
    try {
      run-Deploy
    } catch {
      
    }
  }

  function run-Remove () {
    #CHECK IF BLUESCREENVIEW IS RUNNING
    $process = tasklist | findstr /B "BlueScreenView"
    if ($process) {                   #BLUESCREENVIEW RUNNING
      $running = $true
      $result = taskkill /IM "BlueScreenView" /F
    } elseif (-not $process) {        #BLUESCREENVIEW NOT RUNNING
      $running = $false
    }
    #REMOVE FILES
    write-host "Removing BlueScreenView Files"
    $script:diag += "Removing BlueScreenView Files`r`n"
    try {
      remove-item -path "$($exePath)" -recurse -force -erroraction stop
    } catch {
      if ($_.exception -match "ItemNotFoundException") {
        write-host "NOT PRESENT : $($exePath)"
        $script:diag += "NOT PRESENT : $($exePath)"
      } elseif ($_.exception -notmatch "ItemNotFoundException") {
        write-host "ERROR`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
        $script:diag += "ERROR`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
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
  write-host "Deploying BlueScreenView Files`r`n$($strLineSeparator)"
  $script:diag += "Deploying BlueScreenView Files`r`n$($strLineSeparator)`r`n"
  try {
    run-Deploy -erroraction stop
    
  } catch {
    write-host "ERROR`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
  }
} elseif ($env:strTask -eq "MONITOR") {
  write-host "Monitoring BlueScreenView Files`r`n$($strLineSeparator)"
  $script:diag += "Monitoring BlueScreenView Files`r`n$($strLineSeparator)`r`n"
  try {
    run-Monitor -erroraction stop
    
  } catch {
    
  }
} elseif ($env:strTask -eq "UPGRADE") {
  write-host "Replacing BlueScreenView Files`r`n$($strLineSeparator)"
  $script:diag += "Replacing BlueScreenView Files`r`n$($strLineSeparator)`r`n"
  try {
    run-Upgrade -erroraction stop
    
  } catch {
    
  }
} elseif ($env:strTask -eq "REMOVE") {
  write-host "Removing BlueScreenView Files`r`n$($strLineSeparator)"
  $script:diag += "Removing BlueScreenView Files`r`n$($strLineSeparator)`r`n"
  try {
    run-Remove -erroraction stop
    
  } catch {
    
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
    $enddiag = "Execution Successful : $($finish)`r`n$($strLineSeparator)`r`n"
  } elseif ($script:blnWARN) {
    $enddiag = "Execution Completed with Warnings : $($finish)`r`n$($strLineSeparator)`r`n"
  }
  if (-not $BSODFilter) {
    $enddiag += "`tHealthy - No BSODs found in the last 12 hours`r`n$($strLineSeparator)"
    logERR 3 "BSOD_Monitor" "$($enddiag)"
    #WRITE TO LOGFILE
    "$($script:diag)" | add-content $logPath -force
    write-DRRMAlert "BSOD_Monitor : Healthy - No BSODs found in the last 12 hours : $($finish)"
    write-DRMMDiag "$($script:diag)"
    exit 0
  } elseif ($BSODFilter) {
    $enddiag += "`tUnhealthy - BSOD found. Check Diagnostics`r`n$($strLineSeparator)"
    logERR 3 "BSOD_Monitor" "$($enddiag)"
    #WRITE TO LOGFILE
    "$($script:diag)" | add-content $logPath -force
    write-DRRMAlert "BSOD_Monitor : Unhealthy - BSOD found. Check Diagnostics : $($finish)"
    write-DRMMDiag "$($script:diag)"
    exit 1
  }
} elseif ($script:blnBREAK) {
  #WRITE TO LOGFILE
  $enddiag = "Execution Failed : $($finish)`r`n$($strLineSeparator)`r`n"
  logERR 4 "BSOD_Monitor" "$($enddiag)"
  "$($script:diag)" | add-content $logPath -force
  write-DRMMAlert "BSOD_Monitor : Failure : Diagnostics - $($logPath) : $($finish)"
  write-DRMMDiag "$($script:diag)"
  exit 1
}
#END SCRIPT
#------------