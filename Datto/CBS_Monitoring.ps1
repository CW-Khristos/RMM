#region ----- DECLARATIONS ----
  $script:diag = $null
  $script:blnWARN = $false
  $strLineSeparator = "---------"
  $cbsPath = "$([System.Environment]::ExpandEnvironmentVariables("%SystemRoot%"))\Logs\CBS"
#endregion ----- DECLARATIONS ----

#region ----- FUNCTIONS ----
  function write-DRMMDiag ($messages) {
    write-host "<-Start Diagnostic->"
    foreach ($message in $messages) {$message}
    write-host "<-End Diagnostic->"
  } ## write-DRMMDiag
  
  function write-DRRMAlert ($message) {
    write-host "<-Start Result->"
    write-host "Alert=$($message)"
    write-host "<-End Result->"
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
    write-host "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
  }
#endregion ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
clear-host
write-host "$($strLineSeparator)`r`nCOLLECTING CBS LOGS`r`n$($strLineSeparator)"
$script:diag += "$($strLineSeparator)`r`nCOLLECTING CBS LOGS`r`n$($strLineSeparator)`r`n"
get-childitem -path $cbsPath -recurse | foreach-object {
  $size = [math]::round((($_.Length / 1024) / 1024), 2)
  if ($_.Length -ge 1GB) {
    $script:blnWARN = $true
    if ($script:diag -notlike "*CBS_MONITOR : CBS Logs Above Threshold (1GB) :*") {
      write-host "CBS_MONITOR : CBS Logs Above Threshold (1GB) :"
      $script:diag += "CBS_MONITOR : CBS Logs Above Threshold (1GB) :`r`n"
    }
    write-host "`t$($size)MB  -  $($_.FullName)"
    $script:diag += "`t$($size)MB  -  $($_.FullName)`r`n"
  }
}
write-host "$($strLineSeparator)"
$script:diag += "$($strLineSeparator)`r`n"
#DATTO OUTPUT
if ($script:blnWARN) {
  write-host "CBS_MONITOR : CBS Logs Above Threshold (1GB) : See Diagnostics`r`n$($strLineSeparator)"
  #Stop script execution time calculation
  StopClock
  write-DRRMAlert "CBS_MONITOR : CBS Logs Above Threshold (1GB) : See Diagnostics"
  write-DRMMDiag "$($script:diag)"
  exit 1
} elseif (-not $script:blnWARN) {
  write-host "CBS_MONITOR : No Large CBS Logs Found`r`n$($strLineSeparator)"
  #Stop script execution time calculation
  StopClock
  write-DRRMAlert "CBS_MONITOR : No Large CBS Logs Found"
  write-DRMMDiag "$($script:diag)"
  exit 0
}
#END SCRIPT
#------------