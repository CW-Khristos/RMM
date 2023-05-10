# Deploys Speedtest CLI
# Author : Christopher Bledsoe - cbledsoe@ipmcomputers.com

#region ----- DECLARATIONS ----
  $script:diag = $null
  $script:blnWARN = $false
  $script:blnBREAK = $false
  $exePath = "$($env:strPath)"
  $logPath = "C:\IT\Log\SpeedtestCLI_Monitor"
  $strLineSeparator = "----------------------------------"
  $urlSpeedtest = "https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-win64.zip"
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

  function Get-ProcessOutput {
    Param (
      [Parameter(Mandatory=$true)]$FileName,
      $Args
    )
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo.WindowStyle = "Hidden"
    $process.StartInfo.CreateNoWindow = $true
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.RedirectStandardOutput = $true
    $process.StartInfo.RedirectStandardError = $true
    $process.StartInfo.FileName = $FileName
    if($Args) {$process.StartInfo.Arguments = $Args}
    $out = $process.Start()

    $StandardError = $process.StandardError.ReadToEnd()
    $StandardOutput = $process.StandardOutput.ReadToEnd()

    $output = New-Object PSObject
    $output | Add-Member -type NoteProperty -name StandardOutput -Value $StandardOutput
    $output | Add-Member -type NoteProperty -name StandardError -Value $StandardError
    return $output
  } ## Get-ProcessOutput

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
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - SpeedtestCLI_Monitor - NO ARGUMENTS PASSED, END SCRIPT`r`n`r`n"
        write-host "$($strLineSeparator)`r`n$($(get-date)) - SpeedtestCLI_Monitor - NO ARGUMENTS PASSED, END SCRIPT`r`n" -foregroundcolor red
      }
      2 {                                                         #'ERRRET'=2 - END SCRIPT
        $script:blnBREAK = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - SpeedtestCLI_Monitor - ($($strModule)) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n"
        write-host "$($strLineSeparator)`r`n$($(get-date)) - SpeedtestCLI_Monitor - ($($strModule)) :" -foregroundcolor red
        write-host "$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n" -foregroundcolor red
      }
      3 {                                                         #'ERRRET'=3
        $script:blnWARN = $false
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - SpeedtestCLI_Monitor - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
        write-host "$($strLineSeparator)`r`n$($(get-date)) - SpeedtestCLI_Monitor - $($strModule) :" -foregroundcolor yellow
        write-host "$($strLineSeparator)`r`n`t$($strErr)" -foregroundcolor yellow
      }
      default {                                                   #'ERRRET'=4+
        $script:blnBREAK = $false
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - SpeedtestCLI_Monitor - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
        write-host "$($strLineSeparator)`r`n$($(get-date)) - SpeedtestCLI_Monitor - $($strModule) :" -foregroundcolor yellow
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
    if (-not (test-path -path "$($exePath)")) {
      new-item -path "$($exePath)" -itemtype directory -force | out-string
    }
  }

  function run-Deploy () {
    #CHECK 'PERSISTENT' FOLDERS
    dir-Check
    #CHECK IF SPEEDTEST IS RUNNING
    $varAttempts = 0
    $running = get-process "speedtest.exe" -erroraction silentlycontinue
    while (($running) -and ($varAttempts -lt 3)) {
      $varAttempts++
      $result = taskkill /IM "speedtest.exe" /F
      start-sleep -seconds 5
      $result = get-process "speedtest.exe" -erroraction silentlycontinue
      if ($result) {                   #SPEEDTEST STILL RUNNING
        $running = $true
      } elseif (-not $result) {        #SPEEDTEST NO LONGER RUNNING
        $running = $false
      }
    }
    if (-not $running) {
      try {
        if (test-path -path "C:\IT\speedtest.zip") {remove-item "C:\IT\speedtest.zip" -force -erroraction continue}
        #DOWNLOAD SPEEDTEST.ZIP
        if (-not (test-path -path "C:\IT\speedtest.zip")) {
          try {
            start-bitstransfer -source $urlSpeedtest -destination "C:\IT\speedtest.zip" -erroraction stop
          } catch {
            try {
              $web = new-object system.net.webclient
              $web.downloadfile($urlSpeedtest, "C:\IT\speedtest.zip")
            } catch {
              $depdiag = "FAILED TO DOWNLOAD SPEEDTEST"
              logERR 2 "run-Deploy" "$($depdiag)"
            }
          }
        }
        if (-not $script:blnBREAK) {
          $shell = New-Object -ComObject Shell.Application
          $zip = $shell.Namespace("C:\IT\speedtest.zip")
          $items = $zip.items()
          $shell.Namespace("$($exePath)").CopyHere($items, 1556)
          write-host " - SPEEDTEST EXTRACTED"
          $script:diag += " - SPEEDTEST EXTRACTED`r`n"
          start-sleep -seconds 2
          remove-item -path "C:\IT\speedtest.zip" -force -erroraction continue
        }
        # inform the user
        $depdiag = "DEPLOY SPEEDTEST COMPLETED - SPEEDTEST has been deployed`r`n"
        $depdiag += "`tSPEEDTEST Location : '$($exePath)'`r`n$($strLineSeparator)"
        logERR 3 "run-Deploy" "$($depdiag)"
      } catch {
        $depdiag = "FAILED TO EXTRACT SPEEDTEST"
        logERR 2 "run-Deploy" "$($depdiag)"
      }
    }
  }

  function run-Monitor () {
    #CHECK PATH EXISTENCE
    $result = test-path -path "$($exePath)"
    if (-not $result) {                   #PATH DOES NOT EXIST, DEPLOY SPEEDTEST
      run-Deploy
    } elseif ($result) {                  #PATH EXISTS
      #CHECK EXECUTABLE
      $exeFile = test-path -path "$($exePath)\speedtest.exe"
      if (-not $exeFile) {
        run-Deploy
      }
      try {
        $out = Get-ProcessOutput -File "$($exePath)\speedtest.exe"
        write-host "`tSTDOUT :`r`n`t$($out.standardoutput)`r`n`tSTDERR :`r`n`t$($out.standarderror)`r`n$($strLineSeparator)"
        $script:diag += "`tSTDOUT :`r`n`t$($out.standardoutput)`r`n`tSTDERR :`r`n`t$($out.standarderror)`r`n$($strLineSeparator)`r`n"
      } catch {
        $mondiag = "Speedtest Command has Failed: $($_.Exception.Message)`r`n$($strLineSeparator)"
        logERR 2 "run-Monitor" "$($mondiag)"
      }
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
    #CHECK IF SPEEDTEST IS RUNNING
    $remdiag = "Checking if Speedtest is Running`r`n$($strLineSeparator)"
    logERR 3 "run-Remove" "$($remdiag)"
    $process = tasklist | findstr /B "speedtest"
    if ($process) {                   #SPEEDTEST RUNNING
      $running = $true
      $result = taskkill /IM "speedtest" /F
      $remdiag = "Terminating Speedtest`r`n$($strLineSeparator)"
      logERR 3 "run-Remove" "$($remdiag)"
      write-host "$($result)`r`n$($strLineSeparator)"
      $script:diag += "$($result)`r`n$($strLineSeparator)`r`n"
    } elseif (-not $process) {        #SPEEDTEST NOT RUNNING
      $running = $false
    }
    write-host "`tStatus : $($running)`r`n$($strLineSeparator)"
    $script:diag += "`r`n`tStatus : $($running)`r`n$($strLineSeparator)`r`n"
    #REMOVE FILES
    $remdiag = "Removing Speedtest Files`r`n$($strLineSeparator)"
    logERR 3 "run-Remove" "$($remdiag)"
    try {
      remove-item -path "$($exePath)" -recurse -force -erroraction continue
    } catch {
      if ($_.exception -match "ItemNotFoundException") {
        write-host "NOT PRESENT : $($_.fullname)`r`n$($strLineSeparator)"
        $script:diag += "NOT PRESENT : $($_.fullname)`r`n$($strLineSeparator)`r`n"
      } elseif ($_.exception -notmatch "ItemNotFoundException") {
        $script:blnWARN = $true
        write-host "ERROR`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
        $script:diag += "ERROR`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)`r`n"
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
#CHECK 'PERSISTENT' FOLDERS
dir-Check
if ($env:strTask -eq "DEPLOY") {
  write-host "$($strLineSeparator)`r`nDeploying Speedtest Files`r`n$($strLineSeparator)"
  $script:diag += "$($strLineSeparator)`r`nDeploying Speedtest Files`r`n$($strLineSeparator)`r`n"
  try {
    run-Deploy -erroraction stop
    
  } catch {
    write-host "ERROR`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
  }
} elseif ($env:strTask -eq "MONITOR") {
  write-host "$($strLineSeparator)`r`nMonitoring Speedtest Files`r`n$($strLineSeparator)"
  $script:diag += "$($strLineSeparator)`r`nMonitoring Speedtest Files`r`n$($strLineSeparator)`r`n"
  try {
    run-Monitor -erroraction stop
    
  } catch {
    
  }
} elseif ($env:strTask -eq "UPGRADE") {
  write-host "$($strLineSeparator)`r`nReplacing Speedtest Files`r`n$($strLineSeparator)"
  $script:diag += "$($strLineSeparator)`r`nReplacing Speedtest Files`r`n$($strLineSeparator)`r`n"
  try {
    run-Upgrade -erroraction stop
    
  } catch {
    
  }
} elseif ($env:strTask -eq "REMOVE") {
  write-host "$($strLineSeparator)`r`nRemoving Speedtest Files`r`n$($strLineSeparator)"
  $script:diag += "$($strLineSeparator)`r`nRemoving Speedtest Files`r`n$($strLineSeparator)`r`n"
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
$finish = (get-date -format "yyyy-MM-dd HH:mm:ss").ToString()
if (-not $script:blnBREAK) {
  if (-not $script:blnWARN) {
    $result = "$($env:strTask) : Execution Successful : $($finish)"
    $enddiag = "$($result)`r`n$($strLineSeparator)`r`n"
  } elseif ($script:blnWARN) {
    $result = "$($env:strTask) : Execution Completed with Warnings : $($finish)"
    $enddiag = "$($result)`r`n$($strLineSeparator)`r`n"
  }
  if ($env:strTask -eq "DEPLOY") {
    $alert = "- Speedtest Files Deployed"
    $enddiag += "`t- Speedtest Files Deployed`r`n$($strLineSeparator)"
  } elseif ($env:strTask -eq "MONITOR") {
    $alert = "- Healthy - Monitoring Speedtest"
    $enddiag += "`r`n$($strLineSeparator)"
  } elseif ($env:strTask -eq "UPGRADE") {
    $alert = "- Speedtest Files Replaced"
    $enddiag += "`t- Speedtest Files Replaced`r`n$($strLineSeparator)"
  } elseif ($env:strTask -eq "REMOVE") {
    $alert = "- Speedtest Files Removed"
    $enddiag += "`t- Speedtest Files Removed`r`n$($strLineSeparator)"
  }
  logERR 3 "SpeedtestCLI_Monitor" "$($enddiag)"
  #WRITE TO LOGFILE
  "$($script:diag)" | add-content $logPath -force
  write-DRMMAlert "SpeedtestCLI_Monitor : $($result) : $($alert)"
  write-DRMMDiag "$($script:diag)"
  exit 0
} elseif ($script:blnBREAK) {
  #WRITE TO LOGFILE
  $result = "$($env:strTask) : Execution Failed : $($finish)"
  $enddiag = "$($result)`r`n$($strLineSeparator)`r`n"
  logERR 4 "SpeedtestCLI_Monitor" "$($enddiag)"
  "$($script:diag)" | add-content $logPath -force
  write-DRMMAlert "SpeedtestCLI_Monitor : $($result) : Diagnostics - $($logPath)"
  write-DRMMDiag "$($script:diag)"
  exit 1
}
#END SCRIPT
#------------