<# ----- About: ----
    # Monitor_PrintNightmare
    # Description : Monitors PrintNightmare Registry Settings
    # Author: Christopher Bledsoe, Tier II Tech - IPM Computers
    # Email: cbledsoe@ipmcomputers.com
    # https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2021-1678
    # https://msrc.microsoft.com/update-guide/vulnerability/CVE-2021-1678
    # https://support.microsoft.com/en-us/topic/september-14-2021-kb5005569-os-build-10240-19060-0de156d8-d616-49bb-ad8d-3cf352611ca4
# -----------------------------------------------------------#>  ## About

#region ----- DECLARATIONS ----
  #BELOW PARAM() MUST BE COMMENTED OUT FOR USE WITHIN DATTO RMM
  #UNCOMMENT BELOW PARAM() AND RENAME '$env:var' TO '$var' TO UTILIZE IN CLI
  #Param(
  #)
  $script:diag                  = $null
  $script:blnFAIL               = $false
  $script:blnWARN               = $false
  $RpcAuthnLevelPrivacy         = $null
  $strLineSeparator             = "---------"
  $RegPath                      = "HKLM:\System\CurrentControlSet\Control\Print"
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
    $ScriptStopTime = (Get-Date).ToString('yyyy-MM-dd hh:mm:ss')
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
$ScrptStartTime = (Get-Date).ToString('yyyy-MM-dd hh:mm:ss')
$script:sw = [Diagnostics.Stopwatch]::StartNew()

# open / connect to the registry / read the subkeys
try {
  $hkeySubkeys = get-childitem -path "$($RegPath)" -recurse
  write-host "$($strLineSeparator)`r`nCHECKING $($subKey) REGISTRY KEY VALUES`r`n$($strLineSeparator)"
  $script:diag += "`r`n$($strLineSeparator)`r`nCHECKING $($subKey) REGISTRY KEY VALUES`r`n$($strLineSeparator)`r`n"

  #QUERY FOR 'RpcAuthnLevelPrivacy' REGISTRY KEY VALUE
  write-host "`t$($strLineSeparator)`r`n`tCHECKING 'RpcAuthnLevelPrivacy' REGISTRY KEY VALUE"
  $script:diag += "`t$($strLineSeparator)`r`n`tCHECKING 'RpcAuthnLevelPrivacy' REGISTRY KEY VALUE`r`n"
  $RpcAuthnLevelPrivacy = get-itemproperty -path ("HKU:\\$($subKey)\$($AuthPath)") -name "RpcAuthnLevelPrivacy" -erroraction silentlycontinue
  if ($RpcAuthnLevelPrivacy) {
    write-host "`t`tRpcAuthnLevelPrivacy : $($RpcAuthnLevelPrivacy.RpcAuthnLevelPrivacy)"
    $script:diag += "`t`tRpcAuthnLevelPrivacy : $($RpcAuthnLevelPrivacy.RpcAuthnLevelPrivacy)"
    if ($RpcAuthnLevelPrivacy.RpcAuthnLevelPrivacy -eq 0) {$script:blnWARN = $true; write-host "`t`tTHIS MEANS PRINTNIGHTMARE PROTECTIONS ARE DISABLED!"; $script:diag += "`r`n`t`tTHIS MEANS PRINTNIGHTMARE PROTECTIONS ARE DISABLED!"}
  } elseif (-not $RpcAuthnLevelPrivacy) {write-host "`t`tRpcAuthnLevelPrivacy : NOT PRESENT"; $script:diag += "`t`tRpcAuthnLevelPrivacy : NOT PRESENT"}
  write-host "`t$($strLineSeparator)"
  $script:diag += "`r`n`t$($strLineSeparator)"
} catch {
  $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
  write-host "`t`tERROR : $($err)"
  $script:diag += "`t`tERROR : $($err)"
}

#DATTO OUTPUT
#Stop script execution time calculation
StopClock
$finish = (get-date -format "yyyy-MM-dd HH:mm:ss").ToString()
if ($script:blnWARN) {
  write-DRMMAlert "Monitor_PrintNightmare : Protections Disabled : See Diagnostics : $($finish)"
  write-DRMMDiag "$($script:diag)"
  $script:diag = $null
  exit 1
} elseif (-not $script:blnWARN) {
  write-DRMMAlert "Monitor_PrintNightmare : Healthy : $($finish)"
  write-DRMMDiag "$($script:diag)"
  $script:diag = $null
  exit 0
}
#END SCRIPT
#------------