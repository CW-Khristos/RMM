#REGION ----- DECLARATIONS ----
  #BELOW PARAM() MUST BE COMMENTED OUT FOR USE WITHIN DATTO RMM
  #UNCOMMENT BELOW PARAM() AND RENAME '$env:var' TO '$var' TO UTILIZE IN CLI
  #Param (
  #  [Parameter]$i_blnAlertErr
  #)
  #servicename - Passportal - "C:\Program Files\N-able\Passportal Agent\Passportal.exe"
  $script:diag = $null
  $script:blnWARN = $false
  $script:strERR = $null
  $script:svcPP = $null
#ENDREGION ----- DECLARATIONS ----

#REGION ----- FUNCTIONS ----
  function write-DRMMDiag ($messages) {
    write-output  "<-Start Diagnostic->"
    foreach ($message in $messages) {$message}
    write-output "<-End Diagnostic->"
  } ## write-DRMMDiag
  
  function write-DRRMAlert ($message) {
    write-output "<-Start Result->"
    write-output "Alert=$($message)"
    write-output "<-End Result->"
  } ## write-DRRMAlert

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
    write-output "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
  }
#ENDREGION ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
if ($env:blnAlertErr -eq "True") {
  $env:blnAlertErr = $true
} elseif ($env:blnAlertErr -eq "False") {
  $env:blnAlertErr = $false
}
#Start script execution time calculation
$ScrptStartTime = (Get-Date).ToString('dd-MM-yyyy hh:mm:ss')
$script:sw = [Diagnostics.Stopwatch]::StartNew()
#CHECK 'PERSISTENT' FOLDERS
if (-not (test-path -path "C:\temp")) {
  new-item -path "C:\temp" -itemtype directory
}
if (-not (test-path -path "C:\IT")) {
  new-item -path "C:\IT" -itemtype directory
}
if (-not (test-path -path "C:\IT\Log")) {
  new-item -path "C:\IT\Log" -itemtype directory
}
if (-not (test-path -path "C:\IT\Scripts")) {
  new-item -path "C:\IT\Scripts" -itemtype directory
}
#CHECK PASSPORTAL SERVICE
$script:diag += "`r`n--------------------------------------`r`n"
$script:diag += "POLLING PASSPORTAL SERVICE`r`n"
$script:diag += "--------------------------------------`r`n"
write-output "--------------------------------------" -foregroundcolor yellow
write-output "POLLING PASSPORTAL SERVICE" -foregroundcolor yellow
write-output "--------------------------------------" -foregroundcolor yellow
try {
  $script:svcPP = get-service -name passportal -erroraction stop
  $script:diag += "$($script:svcPP.name) - $($script:svcPP.status)`r`n"
  if ($script:svcPP.status -eq "Running") {
    write-output $script:svcPP -foregroundcolor green
  } elseif ($script:svcPP.status -ne "Running") {
    $script:blnWARN = $true
    write-output $script:svcPP -foregroundcolor red
  }
} catch {
  $script:blnWARN = $true
  $script:diag += "Passportal Service Not Found!`r`n"
  $script:diag += "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n"
  write-output "Passportal Service Not Found!" -foregroundcolor red
  write-output $_.Exception
  write-output $_.scriptstacktrace
  write-output $_
}
$script:diag += "--------------------------------------`r`n"
write-output "--------------------------------------" -foregroundcolor yellow
#CHECK PASSPORTAL LOGS
$script:diag += "`r`n--------------------------------------`r`n"
$script:diag += "PARSING PASSPORTAL LOGS`r`n"
$script:diag += "--------------------------------------`r`n"
write-output "--------------------------------------" -foregroundcolor yellow
write-output "PARSING PASSPORTAL LOGS" -foregroundcolor yellow
write-output "--------------------------------------" -foregroundcolor yellow
try {
  foreach ($line in get-content "C:\Program Files\N-able\Passportal Agent\Logs\pserv.log" -erroraction stop) {
    if ($line -match "ERROR - ") {
      if ($env:blnAlertErr) {
        $script:blnWARN = $true
      }
      $script:diag += "$($line)`r`n"
      write-output "$($line)" -foregroundcolor red
    }
  }
} catch {
  $script:blnWARN = $true
  $script:diag += "Passportal 'pserv' Logfile Not Found!`r`n"
  $script:diag += "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n"
  write-output "Passportal 'pserv' Logfile Not Found!" -foregroundcolor red
  write-output $_.Exception
  write-output $_.scriptstacktrace
  write-output $_
}
$script:diag += "--------------------------------------`r`n"
write-output "--------------------------------------" -foregroundcolor yellow
#DATTO OUTPUT
StopClock
if ($script:blnWARN) {
  write-DRRMAlert "PassPortal Monitoring : Warning : See Diagnostics"
  write-DRMMDiag "$($script:diag)"
  exit 1
} elseif (-not $script:blnWARN) {
  write-DRRMAlert "PassPortal Monitoring : Healthy"
  write-DRMMDiag "$($script:diag)"
  exit 0
}
#END SCRIPT
#------------