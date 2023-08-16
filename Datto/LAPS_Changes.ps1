#region ----- DECLARATIONS ----
  $strSCR           = "LAPS_Changes"
  $strVER           = [version]"0.1.0"
  $strREPO          = "RMM"
  $strBRCH          = "dev"
  $strDIR           = "Datto"
  $script:diag      = $null
  $script:blnWARN   = $false
  $strLineSeparator = "---------"
#endregion ----- DECLARATIONS ----

#region ----- FUNCTIONS ----
  function write-DRMMDiag ($messages) {
    write-host "<-Start Diagnostic->"
    foreach ($message in $messages) { $message }
    write-host "<-End Diagnostic->"
  }

  function write-DRRMAlert ($message) {
    write-host "<-Start Result->"
    write-host "Alert=$($message)"
    write-host "<-End Result->"
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
$version = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentVersion
if ($version -lt "6.3") {
  write-host "$($strLineSeparator)`r`nUnsupported OS. Only Server 2012R2 and up are supported.`r`n$($strLineSeparator)"
  $script:diag += "`r`n$($strLineSeparator)`r`nUnsupported OS. Only Server 2012R2 and up are supported.`r`n$($strLineSeparator)`r`n"
  #exit 1
}
#GRAB ACCOUNT CHANGES IN PAST 24 HOURS
$LastDay = (Get-Date).addhours(-24)
$AdminGroup = Get-LocalGroupMember -SID "S-1-5-32-544"
write-host "$($strLineSeparator)`r`nCollecting Admin Accounts....`r`n$($strLineSeparator)"
$script:diag += "`r`n$($strLineSeparator)`r`nCollecting Admin Accounts....`r`n$($strLineSeparator)`r`n"
$ChangedAdmins = foreach ($Admin in $AdminGroup) {
  get-localuser -ErrorAction SilentlyContinue -sid $admin.sid | Where-Object {$_.PasswordLastSet -gt $LastDay}
}
#CHECK FOR PASSWORD CHANGES FOR ANY ACCOUNTS EXCEPT FOR ".IPM" TECHCLIENT ACCOUNTS
foreach ($admin in $ChangedAdmins) {
  if (($admin.fullname -notlike "*.IPM*") -and ($admin.description -notlike "*account for support from IPMCom*")) {
    $script:blnWARN = $true
  } elseif (($admin.fullname -notlike "*.IPM*") -and ($admin.description -notlike "*account for support from IPMCom*")) {
    write-host "TechClient Account Detected : $($admin.fullname) : Ignoring"
    $script:diag += "`r`nTechClient Account Detected : $($admin.fullname) : Ignoring`r`n"
  }
}

#DATTO OUTPUT
if (-not $script:blnWARN) {
  write-host "`r`n$($strLineSeparator)`r`nNo Recent Password Changes Detected (Excluding TechClient Accounts)`r`n$($strLineSeparator)"
  write-host "`r`n$($strLineSeparator)`r`nRecent Password Changes (Including TechClient Accounts):`r`n$($strLineSeparator)"
  $ChangedAdmins | fl * | out-string
  write-host "$($strLineSeparator)"
  $script:diag += "`r`n$($strLineSeparator)`r`nNo Recent Password Changes Detected (Excluding TechClient Accounts)`r`n$($strLineSeparator)`r`n"
  $script:diag += "`r`n$($strLineSeparator)`r`nRecent Password Changes (Including TechClient Accounts):`r`n$($strLineSeparator)"
  $script:diag += $ChangedAdmins | fl * | out-string
  $script:diag += "$($strLineSeparator)`r`n"
  #Stop script execution time calculation
  StopClock
  write-DRRMAlert "Healthy"
  write-DRMMDiag "$($script:diag)"
  exit 0
} elseif ($script:blnWARN) {
  write-host "`r`n$($strLineSeparator)`r`nRecent Password Changes :`r`n$($strLineSeparator)"
  $ChangedAdmins | fl * | out-string
  write-host "$($strLineSeparator)"
  $script:diag += "`r`n$($strLineSeparator)`r`nRecent Password Changes :`r`n$($strLineSeparator)"
  $script:diag += $ChangedAdmins | fl * | out-string
  $script:diag += "$($strLineSeparator)`r`n"
  #Stop script execution time calculation
  StopClock
  write-DRRMAlert "Unhealthy. Please check diagnostics"
  write-DRMMDiag "$($script:diag)"
  exit 1
}
#END SCRIPT
#------------