# Deploys IPERF command line utility to C:\IT\iperf for testing internet / network connection performance
# Modifications : Christopher Bledsoe - cbledsoe@ipmcomputers.com

#region ----- DECLARATIONS ----
  $script:diag = $null
  $script:blnWARN = $false
  $script:blnBREAK = $false
  $logPath = "C:\IT\Log\IPERF"
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
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - IPERF - NO ARGUMENTS PASSED, END SCRIPT`r`n`r`n"
        write-host "$($strLineSeparator)`r`n$($(get-date)) - IPERF - NO ARGUMENTS PASSED, END SCRIPT`r`n" -foregroundcolor red
      }
      2 {                                                         #'ERRRET'=2 - END SCRIPT
        $script:blnBREAK = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - IPERF - ($($strModule)) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n"
        write-host "$($strLineSeparator)`r`n$($(get-date)) - IPERF - ($($strModule)) :" -foregroundcolor red
        write-host "$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n" -foregroundcolor red
      }
      3 {                                                         #'ERRRET'=3
        $script:blnWARN = $false
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - IPERF - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
        write-host "$($strLineSeparator)`r`n$($(get-date)) - IPERF - $($strModule) :" -foregroundcolor yellow
        write-host "$($strLineSeparator)`r`n`t$($strErr)" -foregroundcolor yellow
      }
      default {                                                   #'ERRRET'=4+
        $script:blnBREAK = $false
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - IPERF - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
        write-host "$($strLineSeparator)`r`n$($(get-date)) - IPERF - $($strModule) :" -foregroundcolor yellow
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
    if (-not (test-path -path "C:\IT\IPERF")) {
      new-item -path "C:\IT\IPERF" -itemtype directory -force | out-string
    }
  }

  function run-Deploy () {
    #CHECK 'PERSISTENT' FOLDERS
    dir-Check
    # install the executable somewhere we can bank on its presence
    move-item cygwin1.dll "C:\IT\IPERF" -force
    move-item iperf3.exe "C:\IT\IPERF" -force
    # inform the user
    write-host "- IPERF has been deployed and can be used in location : 'C:\IT\IPERF'"
    $script:diag += "- IPERF has been deployed and can be used in location : 'C:\IT\IPERF'`r`n"
  }

  function run-Monitor () {
    #CHECK PATH EXISTENCE
    $result = test-path -path "C:\IT\IPERF"
    if (-not $result) {                 #PATH DOES NOT EXIST, DEPLOY IPERF
      run-Deploy
    } elseif ($result) {                #PATH EXISTS
      #CHECK EXECUTABLE AND DLL
      $result = test-path -path "C:\IT\IPERF\iperf3.exe"
      if (-not $result) {               #FILE DOES NOT EXIST, DEPLOY EXECUTABLE
        move-item iperf3.exe "C:\IT\IPERF" -force
      } elseif ($result) {              #FILE EXISTS
      }
      $result = test-path -path "C:\IT\IPERF\cygwin1.dll"
      if (-not $result) {               #FILE EXISTS
        move-item cygwin1.dll "C:\IT\IPERF" -force
      } elseif ($result) {              #FILE EXISTS
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
    #CHECK IF IPERF IS RUNNING
    $process = tasklist | findstr /B "iperf3"
    if ($process) {                   #IPERF RUNNING
      $running = $true
      $result = taskkill /IM "iperf3" /F
    } elseif (-not $process) {        #IPERF NOT RUNNING
      $running = $false
    }
    #REMOVE FILES
    write-host "Removing IPERF Files"
    $script:diag += "Removing IPERF Files`r`n"
    try {
      remove-item -path "C:\IT\IPERF" -recurse -force -erroraction stop
    } catch {
      if ($_.exception -match "ItemNotFoundException") {
        write-host "NOT PRESENT : C:\IT\IPERF"
        $script:diag += "NOT PRESENT : C:\IT\IPERF"
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
#CHECK 'PERSISTENT' FOLDERS
dir-Check
if ($env:strTask -eq "DEPLOY") {
  write-host "Deploying IPERF Files`r`n$($strLineSeparator)"
  $script:diag += "Deploying IPERF Files`r`n$($strLineSeparator)`r`n"
  try {
    run-Deploy -erroraction stop
    
  } catch {
    
  }
} elseif ($env:strTask -eq "MONITOR") {
  write-host "Monitoring IPERF Files`r`n$($strLineSeparator)"
  $script:diag += "Monitoring IPERF Files`r`n$($strLineSeparator)`r`n"
  try {
    run-Monitor -erroraction stop
    
  } catch {
    
  }
} elseif ($env:strTask -eq "UPGRADE") {
  write-host "Replacing IPERF Files`r`n$($strLineSeparator)"
  $script:diag += "Replacing IPERF Files`r`n$($strLineSeparator)`r`n"
  try {
    run-Upgrade -erroraction stop
    
  } catch {
    
  }
} elseif ($env:strTask -eq "REMOVE") {
  write-host "Removing IPERF Files`r`n$($strLineSeparator)"
  $script:diag += "Removing IPERF Files`r`n$($strLineSeparator)`r`n"
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
if (-not $script:blnBREAK) {
  if (-not $script:blnWARN) {
    #WRITE TO LOGFILE
    $finish = "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))"
    $enddiag = "Execution Successful : $($finish)"
    logERR 3 "IPERF" "$($enddiag)"
    "$($script:diag)" | add-content $logPath -force
    write-DRMMAlert "IPERF : Successful : Diagnostics - $($logPath) : $($finish)"
    write-DRMMDiag "$($script:diag)"
    exit 0
  } elseif ($script:blnWARN) {
    #WRITE TO LOGFILE
    $finish = "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))"
    $enddiag = "Execution Completed with Warnings : $($finish)"
    logERR 3 "IPERF" "$($enddiag)"
    "$($script:diag)" | add-content $logPath -force
    write-DRMMAlert "IPERF : Warning : Diagnostics - $($logPath) : $($finish)"
    write-DRMMDiag "$($script:diag)"
    exit 1
  }
} elseif ($script:blnBREAK) {
  #WRITE TO LOGFILE
  $finish = "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))"
  $enddiag = "Execution Failed : $($finish)"
  logERR 4 "IPERF" "$($enddiag)"
  "$($script:diag)" | add-content $logPath -force
  write-DRMMAlert "IPERF : Failure : Diagnostics - $($logPath) : $($finish)"
  write-DRMMDiag "$($script:diag)"
  $script:diag = $null
  exit 1
}
#END SCRIPT
#------------