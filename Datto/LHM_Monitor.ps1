<# CPU temperature monitor :: redux III :: build 3/seagull
   uses LibreHardwareMonitor to gather data
   user variables: usrThreshold    [INT] || temperature after which point alerts will be posted, for any core :: check for decimals
                   usrPreferSensor [STR] || exact name of a sensor to use readout from
                   usrScale        [SEL] || usrThreshold is given in terms of celsius or fahrenheit
                   usrAlertOnNull  [BOO] || raise an alert if no result is given from LHM
#>
# Modifications : Christopher Bledsoe - cbledsoe@ipmcomputers.com

#region ----- DECLARATIONS ----
  $script:diag        = $null
  $script:blnWARN     = $false
  $script:blnBREAK    = $false
  $script:varAlertMsg = $null
  $strOpt             = $env:strTask
  $strScale           = $env:usrScale
  $intThreshold       = $env:usrThreshold
  $blnNullAlert       = $env:usrAlertOnNull
  $logPath            = "C:\IT\Log\LHM_Monitor"
  $cfgDefault         = "C:\IT\LHM\LibreHardwareMonitor.config"
  $strLineSeparator   = "----------------------------------"
  $srcLHM             = "https://github.com/CW-Khristos/scripts/raw/master/LHM/LHM.zip"
  $lhmConfig          = "`r`n<?xml version=`"1.0`" encoding=`"utf-8`"?>`r`n<configuration>`r`n"
  $lhmConfig          += "`t<appSettings>`r`n`t`t`t<add key=`"startMinMenuItem`" value=`"true`" />`r`n`t</appSettings>`r`n"
  $lhmConfig          += "`t<startup>`r`n`t`t<supportedRuntime version=`"v4.0`" sku=`".NETFramework,Version=v4.7.2`" />"
  $lhmConfig          += "`r`n`t`t</startup>`r`n</configuration>"
#endregion ----- DECLARATIONS ----

#region ----- FUNCTIONS ----
#================= FUNCTION COMPUNCTION =================#
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
  
  function StopClock {
    #Stop script execution time calculation
    $script:sw.Stop()
    $Days = $sw.Elapsed.Days
    $Hours = $sw.Elapsed.Hours
    $Minutes = $sw.Elapsed.Minutes
    $Seconds = $sw.Elapsed.Seconds
    $Milliseconds = $sw.Elapsed.Milliseconds
    $ScriptStopTime = (get-date -format "yyyy-MM-dd HH:mm:ss").ToString()
    write-output "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
    $script:diag += "`r`n`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
  }

  function logERR ($intSTG, $strModule, $strErr) {
    $script:blnWARN = $true
    #CUSTOM ERROR CODES
    switch ($intSTG) {
      1 {                                                         #'ERRRET'=1 - NOT ENOUGH ARGUMENTS, END SCRIPT
        $script:blnBREAK = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - LHM - NO ARGUMENTS PASSED, END SCRIPT`r`n`r`n"
        write-output "$($strLineSeparator)`r`n$($(get-date)) - LHM - NO ARGUMENTS PASSED, END SCRIPT`r`n"
      }
      2 {                                                         #'ERRRET'=2 - END SCRIPT
        $script:blnBREAK = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - LHM - ($($strModule)) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n"
        write-output "$($strLineSeparator)`r`n$($(get-date)) - LHM - ($($strModule)) :"
        write-output "$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n"
      }
      3 {                                                         #'ERRRET'=3
        $script:blnWARN = $false
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - LHM - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
        write-output "$($strLineSeparator)`r`n$($(get-date)) - LHM - $($strModule) :"
        write-output "$($strLineSeparator)`r`n`t$($strErr)"
      }
      default {                                                   #'ERRRET'=4+
        $script:blnBREAK = $false
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - LHM - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
        write-output "$($strLineSeparator)`r`n$($(get-date)) - LHM - $($strModule) :"
        write-output "$($strLineSeparator)`r`n`t$($strErr)"
      }
    }
  }

  function dir-Check () {
  #CHECK 'PERSISTENT' FOLDERS
    if (-not (test-path -path "C:\temp")) {new-item -path "C:\temp" -itemtype directory -force}
    if (-not (test-path -path "C:\IT")) {new-item -path "C:\IT" -itemtype directory -force}
    if (-not (test-path -path "C:\IT\Log")) {new-item -path "C:\IT\Log" -itemtype directory -force}
    if (-not (test-path -path "C:\IT\Scripts")) {new-item -path "C:\IT\Scripts" -itemtype directory -force}
    if (-not (test-path -path "C:\IT\LHM")) {new-item -path "C:\IT\LHM" -itemtype directory -force | out-string}
  }

  function run-Deploy () {
    #CHECK 'PERSISTENT' FOLDERS
    dir-Check
    #CHECK IF LHM IS RUNNING
    $varAttempts = 0
    $running = get-process "LibreHardwareMonitor.exe" -erroraction silentlycontinue
    while (($running) -and ($varAttempts -lt 3)) {
      $varAttempts++
      $result = taskkill /IM "LibreHardwareMonitor.exe" /F
      start-sleep -seconds 5
      $result = get-process "LibreHardwareMonitor.exe" -erroraction silentlycontinue
      if ($result) {                   #LHM STILL RUNNING
        $running = $true
      } elseif (-not $result) {        #LHM NO LONGER RUNNING
        $running = $false
      }
    }
    if (-not $running) {
      try {
        if (test-path -path "C:\IT\LHM.zip") {remove-item "C:\IT\LHM.zip" -force -erroraction continue}
        #move-item LHM.zip "C:\IT" -force     #DISABLE FOR 'Monitor' COMPONENT - 'Monitor' Components can't have files attached
        #DOWNLOAD LHM.ZIP FROM GITHUB
        if (-not (test-path -path "C:\IT\LHM.zip")) {
          try {
            $depdiag = "DOWNLOADING LHM`r`n$($strLineSeparator)"
            logERR 3 "run-Deploy" "$($depdiag)"
            start-bitstransfer -source $srcLHM -destination "C:\IT\LHM.zip" -erroraction stop
          } catch {
            try {
              $web = new-object system.net.webclient
              $web.downloadfile($srcLHM, "C:\IT\LHM.zip")
            } catch {
              $depdiag = "FAILED TO DOWNLOAD LHM`r`n$($strLineSeparator)"
              logERR 2 "run-Deploy" "$($depdiag)"
            }
          }
        }
        if (-not $script:blnBREAK) {
          $shell = New-Object -ComObject Shell.Application
          $zip = $shell.Namespace("C:\IT\LHM.zip")
          $items = $zip.items()
          $shell.Namespace("C:\IT\LHM").CopyHere($items, 1556)
          $depdiag = " - LHM EXTRACTED`r`n$($strLineSeparator)"
          logERR 3 "run-Deploy" "$($depdiag)"
          start-sleep -seconds 2
          remove-item -path "C:\IT\LHM.zip" -force -erroraction continue
        }
      } catch {
        $depdiag = "FAILED TO EXTRACT LHM`r`n$($strLineSeparator)"
        logERR 2 "run-Deploy" "$($depdiag)"
      }
      if (-not $script:blnBREAK) {
        #pre-assemble a settings file to start minimised
        try {
          set-content "$($cfgDefault)" -value "$($lhmConfig)" -force
          $depdiag = " - LHM CONFIG SET`r`n$($strLineSeparator)"
          logERR 3 "run-Deploy" "$($depdiag)"
        } catch {
          $depdiag = "FAILED TO CONFIGURE LHM`r`n$($strLineSeparator)"
          logERR 3 "run-Deploy" "$($depdiag)"
        }
        # inform the user
        $depdiag = "DEPLOY LHM COMPLETED - LHM has been deployed`r`n"
        $depdiag += "`tLHM Location : 'C:\IT\LHM'`r`n$($strLineSeparator)"
        logERR 3 "run-Deploy" "$($depdiag)"
      }
    } elseif ($running) {
      $depdiag = " - LHM is already running and could not be stopped to deploy files`r`n$($strLineSeparator)"
      logERR 2 "run-Deploy" "$($depdiag)"
    }
  }

  function run-Monitor () {
    #CHECK PATH EXISTENCE
    $result = test-path -path "C:\IT\LHM"
    if (-not $result) {                 #PATH DOES NOT EXIST, DEPLOY LHM
      run-Deploy
    } elseif ($result) {                #PATH EXISTS
      #CHECK EXECUTABLE
      $result = test-path -path "C:\IT\LHM\LibreHardwareMonitor.exe"
      if (-not $result) {               #FILE DOES NOT EXIST
        $lhmExists = $false
      } elseif ($result) {              #FILE EXISTS
        $lhmExists = $true
      }
      #CHECK LHM CONFIG FILE 'LIBREHARDWAREMONITOR.CONFIG'
      $result = test-path -path "$($cfgDefault)"
      if (-not $result) {               #FILE DOES NOT EXIST, DEPLOY LHM CONFIG
        $cfgExists = $false
        set-content "$($cfgDefault)" -value "$($lhmConfig)" -force
      } elseif ($result) {              #FILE EXISTS, COMPARE LHM CONFIG
        $cfgExists = $true
        $cfgCompare = "C:\IT\LHM\compare.config"
        set-content "$($cfgCompare)" -value "$($lhmConfig)" -force
        #COMPARE COMPONENT ATTACHED 'DEFAULT.BGI' FILE AS 'COMPARE.BGI' TO 'DEFAULT.BGI' FILE IN PATH
        if (Compare-Object -ReferenceObject $(Get-Content $cfgDefault) -DifferenceObject $(Get-Content $cfgCompare)) {
          $mondiag = "Files are different - Replacing LHM Config`r`n$($strLineSeparator)`r`n"
          logERR 3 "run-Monitor" "$($mondiag)"
          set-content "$($cfgDefault)" -value "$($lhmConfig)" -force
        } else {
          $mondiag = "Files are same - Continuing`r`n$($strLineSeparator)`r`n"
          logERR 3 "run-Monitor" "$($mondiag)"
        }
      }
      #CHECK IF LHM IS ALREADY RUNNING
      $running = tasklist | findstr /B "LibreHardwareMonitor.exe"
      if ($running) {                   #LHM ALREADY RUNNING
      } elseif (-not $running) {        #LHM NOT RUNNING
        $timestanp = (get-date -format "yyyy-MM-dd HH:mm:ss").ToString()
        $mondiag = "LibreHardwareMonitor Not Running : $($timestanp)`r`n$($strLineSeparator)"
        logERR 3 "run-Monitor" "$($mondiag)"
      }
      #IF LHM EXE DOES NOT EXIST, RE-DEPLOY LHM
      if (-not ($lhmExists)) {
        run-Deploy
      }
      #if lhm isn't running, start it
      $mondiag = "CHECKING LHM MONITORING DATA`r`n$($strLineSeparator)"
      logERR 3 "run-Monitor" "$($mondiag)"
      while (!(Get-Process LibreHardwareMonitor)) {
        $varAttempts++
        start-process -filepath "C:\IT\LHM\LibreHardwareMonitor.exe" -passthru -nonewwindow
        start-sleep -Seconds 15
        if ($varAttempts -eq 3) {
          $mondiag = "ERROR! LibreHardwareMonitor is not running`r`n"
          $mondiag += "This device may need its .NET Framework repaired. http://dat.to/ahcdl`r`n$($strLineSeparator)"
          logERR 2 "run-Monitor" "$($mondiag)"
        }
      }
      if (-not $script:blnBREAK) {
        #populate a hash table :: if we have a CPU package measurement, use that; otherwise, grab the cores
        $arrSensors=@{}
        if ((Get-WmiObject -Namespace "Root\LibreHardwareMonitor" -Query "SELECT * FROM Sensor WHERE Sensortype='Temperature'" | ? {$_.Name -match 'CPU Package'}).value) {
          Get-WmiObject -Namespace "Root\LibreHardwareMonitor" -Query "SELECT * FROM Sensor WHERE Sensortype='Temperature'" | ? {$_.Name -Match "CPU Package"} | % {$arrSensors[$_.Name]=$_.Value}
        } else {
          Get-WmiObject -Namespace "Root\LibreHardwareMonitor" -Query "SELECT * FROM Sensor WHERE Sensortype='Temperature'" | ? {$_.Identifier -match 'cpu/'} | % {$arrSensors[$_.Name]=$_.Value}
        }

        #check to see if we actually got any results; throw if configured to do so
        if ($arrSensors.count -eq 0) {
          $mondiag = "ERROR! No data reported from LibreHardwareMonitor`r`n$($strLineSeparator)"
          if ($blnNullAlert -match 'true') {
            $mondiag = "Alert on Null : False`r`n`t$($mondiag)`r`n$($strLineSeparator)"
            logERR 2 "run-Monitor" "$($mondiag)"
          } elseif ($blnNullAlert -match 'false') {
            $mondiag = "Alert on Null : False`r`n`t$($mondiag)`r`n$($strLineSeparator)"
            logERR 3 "run-Monitor" "$($mondiag)"
          }
        }

        #if our threshold figure has decimals, throw it
        if ($intThreshold -notmatch '^[0-9]*$') {
          $mondiag = "ERROR! Threshold figure is not an integer`r`n"
          $mondiag += "No spaces, measurements, decimal points etc. Please reconfigure`r`n$($strLineSeparator)"
          logERR 2 "run-Monitor" "$($mondiag)"
        }
        if (-not $script:blnBREAK) {
          #if we've been given figures in fahrenheit, convert them to celsius
          if ($strScale -eq 'F') {
            $varThreshold = $intThreshold - 32
            $varThreshold = $varThreshold / 1.8
          } elseif ($strScale -eq 'C') {
            $varThreshold = $intThreshold
          }

          #did the user opt to pick a sensor?
          if (($usrPreferSensor -as [string]).Length -eq 0) {
            $usrPreferSensor='.*' #if no preference was set, set the "prefer string" to "anything"
          }

          #retrieve CPU load
          $blnIdle = $false
          $cpu = Get-CimInstance win32_processor | Measure-Object -Property LoadPercentage -Average
          $cpuload = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue
          if (($cpu.Average -le 50) -and ($cpuload -le 50)) {
            $blnIdle = $true
          } elseif (($cpu.Average -gt 50) -or ($cpuload -gt 50)) {
            $blnIdle = $false
          }
          #populate our alert message
          $mondiag = "No Sensors reporting over Threshold $($intThreshold)($($strScale))"
          foreach ($sensor in $arrSensors.getEnumerator()) {
            if ($blnIdle) {
              $evalThreshold = [math]::round(($varThreshold - 10))
              if ($sensor.value -gt $evalThreshold) {
                $mondiag = "Idle Temp Warning (Warn : $($evalThreshold)C): $($sensor.name) node @ $($sensor.value)C!"
                $script:varAlertMsg += "$($mondiag)"
                write-output "`t$($mondiag)"
                $script:diag += "`r`n`t$($mondiag)`r`n"
              }
            } elseif (-not $blnIdle) {
              $evalThreshold = [math]::round(($varThreshold))
              if ($sensor.value -gt $evalThreshold) {
                $mondiag = "Full-Load Temp Warning (Warn : $($evalThreshold)C): $($sensor.name) node @ $($sensor.value)C!"
                $script:varAlertMsg += "$($mondiag)"
                write-output "`t$($mondiag)"
                $script:diag += "`r`n`t$($mondiag)`r`n"
              }
            }
          }
          logERR 3 "run-Monitor" "$($mondiag)`r`n$($strLineSeparator)"
        }
      }
    }
  }

  function run-Upgrade () {
    try {
      run-Remove
    } catch {
      $taskdiag = "ERROR`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
      $taskdiag += "Failed to Remove LHM Files`r`n$($strLineSeparator)"
      logERR 3 "run-Upgrade" "$($taskdiag) "
    }
    try {
      run-Deploy
    } catch {
      $taskdiag = "ERROR`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
      $taskdiag += "Failed to Deploy LHM`r`n$($strLineSeparator)"
      logERR 3 "run-Upgrade" "$($taskdiag) "
    }
  }

  function run-Remove () {
    #CHECK IF LHM IS RUNNING
    $process = tasklist | findstr /B "LibreHardwareMonitor.exe"
    if ($process) {                   #LHM RUNNING
      $running = $true
      $result = taskkill /IM "LibreHardwareMonitor.exe" /F
    } elseif (-not $process) {        #LHM NOT RUNNING
      $running = $false
    }
    #REMOVE FILES
    try {
      $remdiag = "Removing LHM Files`r`n$($strLineSeparator)"
      logERR 3 "run-Remove" "$($remdiag)"
      remove-item -path "C:\IT\LHM" -recurse -force -erroraction continue
      remove-item -path "C:\IT\LHM.zip" -force -erroraction silentlycontinue
    } catch {
      if ($_.exception -match "ItemNotFoundException") {
        $remdiag = "NOT PRESENT : 'C:\IT\LHM\$($_.fullname)'`r`n$($strLineSeparator)"
        logERR 3 "run-Remove" "$($remdiag)"
      } elseif ($_.exception -notmatch "ItemNotFoundException") {
        $remdiag = "ERROR`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
        logERR 4 "run-Remove" "$($remdiag)"
      }
    }
  }
#endregion ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
clear-host
#Start script execution time calculation
$ScrptStartTime = (get-date -format "yyyy-MM-dd HH:mm:ss").ToString()
$script:sw = [Diagnostics.Stopwatch]::StartNew()
#CHECK 'PERSISTENT' FOLDERS
dir-Check
if ($strOpt.toupper() -eq "DEPLOY") {
  $taskdiag = "Deploying LHM Files`r`n$($strLineSeparator)"
  logERR 3 "run-Deploy" "$($taskdiag)"
  try {
    run-Deploy -erroraction stop
    
  } catch {
    $taskdiag = "ERROR`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
    $taskdiag += "Failed to Deploy LHM`r`n$($strLineSeparator)"
    logERR 2 "run-Deploy" "$($taskdiag) "
    Exit 1
  }
} elseif ($strOpt.toupper() -eq "MONITOR") {
  $taskdiag = "Monitoring LHM Files`r`n$($strLineSeparator)"
  logERR 3 "run-Monitor" "$($taskdiag)"
  try {
    run-Monitor
    
  } catch {
    $taskdiag = "ERROR`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
    $taskdiag += "Failed to Monitor LHM`r`n$($strLineSeparator)"
    logERR 2 "run-Monitor" "$($taskdiag) "
  }
} elseif ($strOpt.toupper() -eq "UPGRADE") {
  $taskdiag = "Replacing LHM Files`r`n$($strLineSeparator)"
  logERR 3 "run-Upgrade" "$($taskdiag)"
  try {
    run-Upgrade -erroraction stop
    
  } catch {
    $taskdiag = "ERROR`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
    $taskdiag += "Failed to Upgrade LHM`r`n$($strLineSeparator)"
    logERR 2 "run-Upgrade" "$($taskdiag) "
  }
} elseif ($strOpt.toupper() -eq "REMOVE") {
  $taskdiag = "Removing LHM Files`r`n$($strLineSeparator)"
  logERR 3 "run-Remove" "$($taskdiag)"
  try {
    run-Remove -erroraction stop
    
  } catch {
    $taskdiag = "ERROR`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
    $taskdiag += "Failed to Remove LHM`r`n$($strLineSeparator)"
    logERR 2 "run-Remove" "$($taskdiag) "
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
    $enddiag = "Execution Successful : $($finish)`r`n$($strLineSeparator)`r`n"
  } elseif ($script:blnWARN) {
    $enddiag = "Execution Completed with Warnings : $($finish)`r`n$($strLineSeparator)`r`n"
  }
  if ($script:varAlertMsg -match 'node') {
    $enddiag += "`t$($script:varAlertMsg)`r`n$($strLineSeparator)"
    logERR 3 "END" "$($enddiag)"
    #WRITE TO LOGFILE
    "$($script:diag)" | add-content $logPath -force
    write-DRMMAlert "$($strOpt) : $($script:varAlertMsg) : $($finish)"
    write-DRMMDiag "$($script:diag)"
    exit 1
  } else {
    $enddiag += "`tNo nodes reporting over threshold`r`n$($strLineSeparator)"
    logERR 3 "END" "$($enddiag)"
    #WRITE TO LOGFILE
    "$($script:diag)" | add-content $logPath -force
    write-DRMMAlert "$($strOpt) : No nodes reporting over threshold : $($finish)"
    write-DRMMDiag "$($script:diag)"
    exit 0
  }
} elseif ($script:blnBREAK) {
  #WRITE TO LOGFILE
  $enddiag += "Execution Failed : $($finish)`r`n$($strLineSeparator)"
  logERR 4 "END" "$($enddiag)"
  "$($script:diag)" | add-content $logPath -force
  write-DRMMAlert "$($strOpt) Failure : Diagnostics - $($logPath) : $($finish)"
  write-DRMMDiag "$($script:diag)"
  exit 1
}
#END SCRIPT
#------------