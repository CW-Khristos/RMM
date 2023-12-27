#region ----- DECLARATIONS ----
  #BELOW PARAM() MUST BE COMMENTED OUT FOR USE WITHIN DATTO RMM
  #UNCOMMENT BELOW PARAM() AND RENAME '$env:var' TO '$var' TO UTILIZE IN CLI
  #Param(
  #)
  $script:diag                  = $null
  $script:finish                = $null
  $script:blnFAIL               = $false
  $script:blnWARN               = $false
  $blnFix                       = $env:blnFix
  $strLineSeparator             = "---------"
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

  function StopClock {
    #Stop script execution time calculation
    $script:sw.Stop()
    $Days = $sw.Elapsed.Days
    $Hours = $sw.Elapsed.Hours
    $Minutes = $sw.Elapsed.Minutes
    $Seconds = $sw.Elapsed.Seconds
    $Milliseconds = $sw.Elapsed.Milliseconds
    $total = ((((($Hours * 60) + $Minutes) * 60) + $Seconds) * 1000) + $Milliseconds
    $mill = [string]($total / 1000)
    $mill = $mill.split(".")[1]
    $mill = $mill.SubString(0,[math]::min(3,$mill.length))
    $script:finish = (Get-Date).ToString('yyyy-MM-dd hh:mm:ss')
    $script:diag += "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
    write-host "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
  }
#endregion ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
clear-host
#Start script execution time calculation
$ScrptStartTime = (Get-Date).ToString('yyyy-MM-dd hh:mm:ss')
$script:sw = [Diagnostics.Stopwatch]::StartNew()

$SMB1 = (Get-WindowsOptionalFeature -Online -FeatureName "SMB1Protocol").State
$script:diag += "$($SMB1)`r`n"
if ($SMB1 -eq "Enabled") {
  $script:blnWARN = $true
  if ($blnFix -eq 'False') {
    write-output "SMBv1 is enabled, automatic fix not set, exiting…"
    $script:diag += "SMBv1 is enabled, automatic fix not set, exiting…`r`n"
  } elseif ($blnFix -eq 'True') {
    write-output "SMBv1 is enabled, disabling…"
    $script:diag += "SMBv1 is enabled, disabling…`r`n"
    Disable-WindowsOptionalFeature -Online -FeatureName smb1protocol -NoRestart
    write-output "SMBv1 disabled, will need reboot to finalize"
    $script:diag += "SMBv1 disabled, will need reboot to finalize`r`n"
  }
} else {
  $script:blnWARN = $false
  write-output "SMBv1 is NOT enabled!"
  $script:diag += "SMBv1 is NOT enabled!`r`n"
}

#Stop script execution time calculation
StopClock
#DATTO RMM OUTPUT
if ($script:blnWARN) {
  if ($blnFix -eq 'False') {
    write-DRMMAlert "Monitor_SMBv1 : UnHealthy : See Diagnostics : $($script:finish)"
    write-DRMMDiag "$($script:diag)"
    exit 1
  }
} elseif (-not ($script:blnWARN)) {
  write-DRMMAlert "Monitor_SMBv1 : Healthy : $($script:finish)"
  write-DRMMDiag "$($script:diag)"
  exit 0
}
#END SCRIPT
#------------