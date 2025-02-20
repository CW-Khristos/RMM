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
    $ScriptStopTime = (Get-Date).ToString('yyyy-MM-dd hh:mm:ss')
    $total = ((((($Hours * 60) + $Minutes) * 60) + $Seconds) * 1000) + $Milliseconds
    $mill = [string]($total / 1000)
    $mill = $mill.split(".")[1]
    $mill = $mill.SubString(0,[math]::min(3,$mill.length))
    $script:diag += "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
    write-output "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
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
  #QUERY FOR 'RpcAuthnLevelPrivacy' REGISTRY KEY VALUE
  $hkeyVals = get-itemproperty -path "$($RegPath)"
  write-output "$($strLineSeparator)`r`n`tCHECKING 'RpcAuthnLevelPrivacy' REGISTRY KEY VALUE"
  $script:diag += "$($strLineSeparator)`r`n`tCHECKING 'RpcAuthnLevelPrivacy' REGISTRY KEY VALUE`r`n"
  try {
      if ([string]$hkeyVals.RpcAuthnLevelPrivacyEnabled) {
        write-output "`t`tRpcAuthnLevelPrivacy : $($hkeyVals.RpcAuthnLevelPrivacyEnabled)"
        $script:diag += "`t`tRpcAuthnLevelPrivacy : $($hkeyVals.RpcAuthnLevelPrivacyEnabled)"
        if ($hkeyVals.RpcAuthnLevelPrivacyEnabled -eq 0) {
          $script:blnWARN = $true
          write-output "`t`tTHIS MEANS PRINTNIGHTMARE PROTECTIONS ARE DISABLED!"
          $script:diag += "`r`n`t`tTHIS MEANS PRINTNIGHTMARE PROTECTIONS ARE DISABLED!`r`n"
        }
      } elseif (-not [string]$hkeyVals.RpcAuthnLevelPrivacyEnabled) {
        write-output "`t`tRpcAuthnLevelPrivacy : NOT PRESENT"
        $script:diag += "`t`tRpcAuthnLevelPrivacy : NOT PRESENT`r`n"
      }
  } catch {  
    $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
    write-output "`t`tERROR : $($err)"
    $script:diag += "`t`tERROR : $($err)"
  }
  write-output "`t$($strLineSeparator)"
  $script:diag += "`r`n`t$($strLineSeparator)"
} catch {
  $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
  write-output "`t`tERROR : $($err)"
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