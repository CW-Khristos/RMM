<#
.SYNOPSIS 
    PS conversion of AV_WMICleanup VBS Script

.DESCRIPTION 
    PS conversion of AV_WMICleanup VBS Script
    Removes All / Specified AV from WMI AVProduct and FWProduct
 
.NOTES
    Version        : 0.1.0 (09 September 2022)
    Creation Date  : 09 September 2022
    Purpose/Change : PS conversion of AV_WMICleanup VBS Script
    File Name      : AV_WMICleanup_0.1.0.ps1
    Author         : Christopher Bledsoe - cbledsoe@ipmcomputers.com
    Requires       : PowerShell Version 2.0+ installed

.CHANGELOG
    0.1.0 Initial Release
    
To Do:

#>

#First Clear any variables
#Remove-Variable * -ErrorAction SilentlyContinue
  
#REGION ----- DECLARATIONS ----
  #BELOW PARAM() MUST BE COMMENTED OUT FOR USE WITHIN DATTO RMM
  #UNCOMMENT BELOW PARAM() AND RENAME '$env:var' TO '$var' TO UTILIZE IN CLI
  #Param (
  #  [Parameter(Mandatory=$false)]$strAVP
  #)
  $script:diag      = $null
  $script:blnFND    = $false
  $script:blnWARN   = $false
  $script:blnFAIL   = $false
  $strLineSeparator = "---------"
  $script:logPath   = "C:\IT\Log\AV_WMICLEANUP"
#ENDREGION ----- DECLARATIONS ----

#REGION ----- FUNCTIONS ----
  function write-DRMMDiag ($messages) {
    write-host  "<-Start Diagnostic->"
    foreach ($message in $messages) {$message}
    write-host "<-End Diagnostic->"
  }

  function write-DRRMAlert ($message) {
    write-host "<-Start Result->"
    write-host "Alert=$($message)"
    write-host "<-End Result->"
  }

  function logERR ($intSTG, $strModule, $strErr) {
    $script:blnWARN = $true
    #CUSTOM ERROR CODES
    switch ($intSTG) {
      1 {                                                         #'ERRRET'=1 - NOT ENOUGH ARGUMENTS, END SCRIPT
        $script:blnFAIL = $true
        $script:diag += "`r`n$($(get-date))`t - AV_WMICLEANUP - NO ARGUMENTS PASSED, END SCRIPT`r`n`r`n"
        write-host "$($(get-date))`t - AV_WMICLEANUP - NO ARGUMENTS PASSED, END SCRIPT`r`n"
      }
      2 {                                                         #'ERRRET'=2 - INSTALL / IMPORT MODULE FAILURE, END SCRIPT
        $script:blnFAIL = $true
        $script:diag += "`r`n$($(get-date))`t - AV_WMICLEANUP - ($($strModule))`r`n$($strErr), END SCRIPT`r`n`r`n"
        write-host "$($(get-date))`t - AV_WMICLEANUP - ($($strModule))`r`n$($strErr), END SCRIPT`r`n"
      }
      default {                                                   #'ERRRET'=3+
        $script:diag += "`r`n$($(get-date))`t - AV_WMICLEANUP - $($strModule) : $($strErr)`r`n`r`n"
        write-host "$($(get-date))`t - AV_WMICLEANUP - $($strModule) : $($strErr)`r`n"
      }
    }
  }

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
#ENDREGION ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
clear-host
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
write-host "$($strLineSeparator)"
write-host "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - EXECUTING AV_WMICLEANUP"
$script:diag += "$($strLineSeparator)`r`n"
$script:diag += "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - EXECUTING AV_WMICLEANUP`r`n"
if (($null -eq $env:strAVP) -or ($env:strAVP -eq "")) {
  $fwQuery = "Select * from FirewallProduct"
  $avQuery = "Select * from AntiVirusProduct"
} elseif (($null -ne $env:strAVP) -and ($env:strAVP -ne "")) {
  $fwQuery = "Select * from FirewallProduct WHERE displayName LIKE '%$($env:strAVP)%'"
  $avQuery = "Select * from AntiVirusProduct WHERE displayName LIKE '%$($env:strAVP)%'"
}
$wmiCheck = get-wmiobject -Namespace root/SecurityCenter -Query "Select * from AntiVirusProduct" -erroraction silentlycontinue
if (($null -eq $wmiCheck) -or ($wmiCheck -eq "")) {
  #CONNECT TO REGISTRY PROVIDER
  $fws = get-wmiobject -Namespace root/SecurityCenter2 -Query $fwQuery
  $avs = get-wmiobject -Namespace root/SecurityCenter2 -Query $avQuery
} elseif (($null -ne $wmiCheck) -and ($wmiCheck -ne "")) {
  #CONNECT TO REGISTRY PROVIDER
  $fws = get-wmiobject -Namespace root/SecurityCenter -Query $fwQuery
  $avs = get-wmiobject -Namespace root/SecurityCenter -Query $avQuery
}
#ENUMERATE EACH AV INSTANCE
write-host "$($strLineSeparator)"
write-host "ENUMERATING AV INSTANCES"
write-host "$($strLineSeparator)"
$script:diag += "$($strLineSeparator)`r`n"
$script:diag += "ENUMERATING AV INSTANCES`r`n"
$script:diag += "$($strLineSeparator)`r`n"
foreach ($av in $avs) {
  if (($null -eq $env:strAVP) -or ($env:strAVP -eq "")) {
    if (($av.displayName).toupper() -ne "WINDOWS DEFENDER") {
      write-host "$(get-date)`t`t - FOUND TARGET : $($av.displayName)"
      $script:diag += "$(get-date)`t`t - FOUND TARGET : $($av.displayName)`r`n"
      try {
        $av | remove-wmiobject -erroraction stop
        write-host "$($av.displayName) REMOVED SUCCESSFULLY"
        $script:diag += "$($av.displayName) REMOVED SUCCESSFULLY`r`n"
      } catch {
        $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
        logERR 3 "AV : $($av.displayName)" $err
      }
      $script:blnFND = $true
    }
  } elseif (($null -ne $env:strAVP) -and ($env:strAVP -ne "")) {
    if (($av.displayName).toupper() -eq $env:strAVP.toupper()) {
      write-host "$(get-date)`t`t - FOUND TARGET : $($fw.displayName)"
      $script:diag += "$(get-date)`t`t - FOUND TARGET : $($fw.displayName)`r`n"
      try {
        $av | remove-wmiobject -erroraction stop
        write-host "$($av.displayName) REMOVED SUCCESSFULLY"
        $script:diag += "$($av.displayName) REMOVED SUCCESSFULLY`r`n"
      } catch {
        $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
        logERR 4 "AV : $($av.displayName)" $err
      }
      $script:blnFND = $true
    }
  }
}
#ENUMERATE EACH FW INSTANCE
write-host "$($strLineSeparator)"
write-host "ENUMERATING FW INSTANCES"
write-host "$($strLineSeparator)"
$script:diag += "$($strLineSeparator)`r`n"
$script:diag += "ENUMERATING FW INSTANCES`r`n"
$script:diag += "$($strLineSeparator)`r`n"
foreach ($fw in $fws) {
  if (($null -eq $env:strAVP) -or ($env:strAVP -eq "")) {
    if (($fw.displayName).toupper() -ne "WINDOWS DEFENDER") {
      write-host "$(get-date)`t`t - FOUND TARGET : $($fw.displayName)"
      $script:diag += "$(get-date)`t`t - FOUND TARGET : $($fw.displayName)`r`n"
      try {
        $fw | remove-wmiobject -erroraction stop
        write-host "$($fw.displayName) REMOVED SUCCESSFULLY"
        $script:diag += "$($fw.displayName) REMOVED SUCCESSFULLY`r`n"
      } catch {
        $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
        logERR 5 "FW : $($av.displayName)" $err
      }
      $script:blnFND = $true
    }
  } elseif (($null -ne $env:strAVP) -and ($env:strAVP -ne "")) {
    if (($fw.displayName).toupper() -eq $env:strAVP.toupper()) {
      write-host "$(get-date)`t`t - FOUND TARGET : $($fw.displayName)"
      $script:diag += "$(get-date)`t`t - FOUND TARGET : $($fw.displayName)`r`n"
      try {
        $fw | remove-wmiobject -erroraction stop
        write-host "$($fw.displayName) REMOVED SUCCESSFULLY"
        $script:diag += "$($fw.displayName) REMOVED SUCCESSFULLY`r`n"
      } catch {
        $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
        logERR 6 "FW : $($av.displayName)" $err
      }
      $script:blnFND = $true
    }
  }
}
#PROVIDE INFORMATIONAL OUTPUT IF NO INSTANCES FOUND
if (-not $script:blnFND) {
  write-host "$(get-date)`t - NO TARGET FOUND"
  $script:diag += "$(get-date)`t - NO TARGET FOUND`r`n"
}
write-host "$($strLineSeparator)"
write-host "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss')) - AV_WMICLEANUP COMPLETE"
write-host "$($strLineSeparator)"
$script:diag += "$($strLineSeparator)`r`n"
$script:diag += "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss')) - AV_WMICLEANUP COMPLETE`r`n"
$script:diag += "$($strLineSeparator)`r`n"
#Stop script execution time calculation
StopClock
#WRITE LOGFILE
$script:diag | out-file $logPath
#DATTO OUTPUT
if ($script:blnWARN) {
  write-DRRMAlert "AV_WMICLEANUP : Execution Failure : See Diagnostics"
  write-DRMMDiag "$($script:diag)"
  exit 1
} elseif (-not $script:blnWARN) {
  write-DRRMAlert "AV_WMICLEANUP : Completed Execution"
  write-DRMMDiag "$($script:diag)"
  exit 0
}
#END SCRIPT
#------------