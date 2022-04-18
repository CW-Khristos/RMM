<#
#DO NOT COMMIT TO GITHUB - HAS 'SECURE' STRING SIGNING SCRIPT AS 'SAFE'#
.SYNOPSIS 
    Assists you in finding machines that have ran dangerous commands such as invoke-expression, often used for attacks called 'Living off-the-Land'
    Related blog: https://www.cyberdrain.com/monitoring-with-powershell-preventing-powershell-based-attacks-lolbas/

.DESCRIPTION 
    Assists you in finding machines that have ran dangerous commands such as invoke-expression, often used for attacks called 'Living off-the-Land'
 
.NOTES
    Version        : 0.1.3 (18 April 2022)
    Creation Date  : 14 May 2020
    Purpose/Change : Assists you in finding machines that have ran dangerous commands
    File Name      : PS_Events_0.1.3.ps1
    Author         : Kelvin Tegelaar - https://www.cyberdrain.com
    Modifications  : Christopher Bledsoe - cbledsoe@ipmcomputers.com
    Supported OS   : Server 2012R2 and higher
    Requires       : PowerShell Version 2.0+ installed

.CHANGELOG
    0.1.0 Modified original code from DattoRMM to actually be functional and report events properly to diagnostic output in DattoRMM
          After speaking with Kelvin; this was apparently mostly due to a known write-host race condition with table formatted data that PowerShell outputs that later than other results
          Regardless; I feel the modifications I made were warranted as noted below :
            Removal of the 'DRMMDiag' call for Script Block Logging is appropriate since it will call 'DRMMAlert' if not enabled, reporting it being enabled to diagnostic is unnecessary
            The advised fix for the 'DRMMDiag' call to log detected dangerous commands is to use 'write-DRMMDiag $PowerShellLogs | Select-Object TriggeredCommand, TimeCreated | format-list'
            The above change will prevent the write-host race condition with table formatted data; regardless I've switched it to a nested hashtable now XD
    0.1.1 Removed duplicate "Invoke-RestMethod" from '$DangerousCommands' array
          After a short inquiry with Prejay; added 'start-bitstransfer'
          Attempting some basic syntax matching with the items in the '$DangerousCommands' array to prevent unnecessary "false" Alerts
          As of this version I have reviewed over 15k lines of output and verified the "detected" code using commands in '$DangerousCommands' was 100% accurate! (ALL of it ws my own code XD)
          Script will track the number of instances of '$DangerousCommands' were detected and how many Script Blocks were detected
    0.1.2 Modtly just output formatting
    
To Do:
    Script still had undesired behavior of "detecting" dangerous commands being used; even when they are not
    An example of this would be if the word "confirm" where contained in  ascript (Prejay's 'Get-PMEServices' script was one I personally came across)
    The above example would still cause an Alert due to the matching of 'irm' Alias in conf*irm*; this has the potential to cause a continual false "Alerts" in an RMM
    While it is expected that techs would need to review the content of the Alert for confirmation; this would be highly in-efficient

#>

#First Clear any variables
#Remove-Variable * -ErrorAction SilentlyContinue
  
#REGION ----- DECLARATIONS ----
  $script:dcmds = 0
  $script:scmds = 0
  $script:dscripts = 0
  $script:sscripts = 0
  $script:diag = $null
  $script:hashDCMD = @{}
  $script:hashSCMD = @{}
  $script:slkey = @("##########")
  $arrSyntax = @(" `'", " `"", "(*)", " (*)", " -", " `$", "(`$)", " (`$)")
  $DangerousCommands = @("iwr", "irm", "curl", "saps","sal", "iex","set-alias", "Invoke-Expression", "Invoke-RestMethod", "Invoke-WebRequest", "DownloadString", "start-bitstransfer", "downloadfile")
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
$version = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentVersion
if ($Version -lt "6.2") {
  $script:diag += "Informational - Unsupported OS. Only Server 2012R2 and up are supported."
}

try {
  $ScriptBlockLogging = get-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging\" -erroraction stop
  if ($ScriptBlockLogging.EnableScriptBLockLogging -ne 1) {
    $script:diag += "  - Error - Script Block Logging is not enabled`r`n  - Enabling Script Block Logging`r`n"
    write-host "  - Error - Script Block Logging is not enabled`r`n  - Enabling Script Block Logging" -foregroundcolor red
    try {
      Set-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging\" -Name "EnableScriptBLockLogging" -Value 1
      $script:diag += "  - Information - Script Block Logging Enabled`r`n"
      write-host "  - Information - Script Block Logging Enabled" -foregroundcolor yellow
    } catch {
      $script:diag += "  - Error - Script Block Logging is not enabled`r`n  - Unable to Enable Script Block Logging`r`n"
      write-host "  - Error - Script Block Logging is not enabled`r`n  - Unable to Enable Script Block Logging" -foregroundcolor red
      Write-DRMMAlert "Error - Script Block Logging is not enabled"
      Write-DRMMDiag "$($script:diag)"
      exit 1
    }
  } else {
    $script:diag += "  - Information - Script Block Logging is enabled`r`n" 
    write-host "  - Information - Script Block Logging is enabled" -foregroundcolor yellow 
  }
} catch {
  $script:diag += "  - Error - Script Block Logging is not enabled`r`n  - Enabling Script Block Logging`r`n"
  write-host "  - Error - Script Block Logging is not enabled`r`n  - Enabling Script Block Logging" -foregroundcolor red
  try {
    New-Item -Path "HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows\PowerShell\" -Value "default value" -force
    New-Item -Path "HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging\" -Value "default value" -force
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging\" -Name "EnableScriptBLockLogging" -Value 1
    $script:diag += "  - Information - Script Block Logging Enabled`r`n"
    write-host "  - Information - Script Block Logging Enabled" -foregroundcolor yellow
  } catch {
    $script:diag += "  - Error - Script Block Logging is not enabled`r`n  - Unable to Enable Script Block Logging`r`n"
    write-host "  - Error - Script Block Logging is not enabled`r`n  - Unable to Enable Script Block Logging" -foregroundcolor red
    Write-DRMMAlert "Error - Script Block Logging is not enabled"
    Write-DRMMDiag "$($script:diag)"
    exit 1
  }
}

$log = Get-WinEvent -ListLog "Microsoft-Windows-PowerShell/Operational"
$log.MaximumSizeInBytes = 1gb
try{
  $log.SaveChanges()
  Get-WinEvent -ListLog "Microsoft-Windows-PowerShell/Operational" | Format-List -Property *
} catch [System.UnauthorizedAccessException] {
  $script:diag += "You do not have permission to configure this log!`r`n"
  $script:diag += "Try running this script with administrator privileges.`r`n"
  $script:diag += "$($_.Exception.Message)`r`n"
  Write-Error "$($script:diag)"
}
$logInfo = @{ 
  ProviderName = "Microsoft-Windows-PowerShell"
  StartTime    = (get-date).AddHours(-2)
  EndTime      = (get-date).AddMinutes(-2)
}
$PowerShellEvents = Get-WinEvent -FilterHashtable $logInfo -ErrorAction SilentlyContinue | Select-Object TimeCreated, message
$PowerShellLogs = foreach ($Event in $PowerShellEvents) {
  foreach ($command in $DangerousCommands) {
    foreach ($syntax in $arrSyntax) {
      if (($Event.Message -like "*$($command)$($syntax)*") -and ($Event.Message -notmatch ($slkey -join "|"))) { 
        $details = $($Event.Message) -split "ScriptBlock ID: "
        $details = $($details[1]) -split "Path: "
        $details[0] = $details[0].trim()
        $details[1] = $details[1].trim()
        if (($null -ne $details[1]) -and ($details[1] -ne "")) {
          $dcmds = $dcmds + 1
          if ($hashDCMD.containskey("$($details[0]) - $($details[1]) : $($command)$($syntax)")) {
            continue
          } elseif (-not $hashDCMD.containskey("$($details[0]) - $($details[1]) : $($command)$($syntax)")) {
            $hash = @{
              TimeCreated      = $Event.TimeCreated
              EventMessage     = $Event.message
              TriggeredCommand = "$($command)$($syntax)"
              ScriptBlockID    = $($details[0])
              Path             = $($details[1])
            }
            $dscripts = $dscripts + 1
            $hashDCMD.add("$($details[0]) - $($details[1]) : $($command)$($syntax)", $hash)
            $script:diag += "`r`n  - $($Event.TimeCreated)`r`n  - Dangerous Command : $($command)$($syntax) found in script block :`r`n"
            $script:diag += "    - ScriptBlock ID : $($details[0])`r`n    - Path : $($details[1])`r`n"
            write-host "`r`n  - $($Event.TimeCreated)`r`n  - Dangerous Command : $($command)$($syntax) found in script block :" -foregroundcolor red
            write-host "    - ScriptBlock ID : $($details[0])`r`n    - Path : $($details[1])" -foregroundcolor red
          }
        }
      } elseif (($Event.Message -like "*$($command)$($syntax)*") -and ($Event.Message -match ($slkey -join "|"))) { 
        $details = $($Event.Message) -split "ScriptBlock ID: "
        $details = $($details[1]) -split "Path: "
        $details[0] = $details[0].trim()
        $details[1] = $details[1].trim()
        if (($null -ne $details[1]) -and ($details[1] -ne "")) {
          $scmds = $scmds + 1
          if ($hashSCMD.containskey("$($details[0]) - $($details[1]) : $($command)$($syntax)")) {
            continue
          } elseif (-not $hashSCMD.containskey("$($details[0]) - $($details[1]) : $($command)$($syntax)")) {
            $hash = @{
              TimeCreated      = $Event.TimeCreated
              EventMessage     = $Event.message
              TriggeredCommand = "$($command)$($syntax)"
              ScriptBlockID    = $($details[0])
              Path             = $($details[1])
            }
            $sscripts = $sscripts + 1
            $hashSCMD.add("$($details[0]) - $($details[1]) : $($command)$($syntax)", $hash)
            $script:diag += "`r`n  - $($Event.TimeCreated)`r`n  - Dangerous Command : $($command)$($syntax) found in script block marked 'safe' :`r`n"
            $script:diag += "    - ScriptBlock ID : $($details[0])`r`n    - Path : $($details[1])`r`n"
            write-host "`r`n  - $($Event.TimeCreated)`r`n  - Dangerous Command : $($command)$($syntax) found in script block marked 'safe' :" -foregroundcolor yellow
            write-host "    - ScriptBlock ID : $($details[0])`r`n    - Path : $($details[1])" -foregroundcolor yellow
          }
        }
      }
    }
  }
}
#Stop script execution time calculation
StopClock
#DATTO OUTPUT
write-host "`r`nDATTO OUTPUT :" -foregroundcolor yellow
if ($dcmds -eq 0) {
  write-host "`r`n  - Powershell Events : Healthy - $($dcmds) Dangerous commands executed by $($dscripts) Scripts found in logs." -foregroundcolor green
  write-DRRMAlert "Powershell Events : Healthy - $($dcmds) Dangerous commands executed by $($dscripts) Scripts found in logs."
  write-DRMMDiag "$($script:diag)"
  exit 0
} elseif ($dcmds -gt 0) {
  write-host "`r`n  - Powershell Events : Warning - $($dcmds) Dangerous commands executed by $($dscripts) Scripts found in logs." -foregroundcolor red
  write-host "`r`nThe following Script Blocks contain dangerous commands :" -foregroundcolor yellow
  $script:diag += "`r`nThe following Script Blocks contain dangerous commands :"
  foreach ($cmd in $hashDCMD.keys) {
    $script:diag += "`r`n  - $($hashDCMD[$cmd].TimeCreated)`r`n  - Dangerous Command : $($hashDCMD[$cmd].TriggeredCommand) found in script block :`r`n"
    $script:diag += "    - ScriptBlock ID : $($hashDCMD[$cmd].ScriptBlockID)`r`n    - Path : $($hashDCMD[$cmd].Path)`r`n"
    $script:diag += "$($hashDCMD[$cmd].EventMessage)`r`n"
    write-host "  - $($hashDCMD[$cmd].TimeCreated)`r`n  - Dangerous Command : $($hashDCMD[$cmd].TriggeredCommand) found in script block :" -foregroundcolor red
    write-host "    - ScriptBlock ID : $($hashDCMD[$cmd].ScriptBlockID)`r`n    - Path : $($hashDCMD[$cmd].Path)" -foregroundcolor red
    write-host "$($hashDCMD[$cmd].EventMessage)`r`n" -foregroundcolor red
  }
  write-DRRMAlert "Powershell Events : Warning - $($dcmds) Dangerous commands executed by $($dscripts) Scripts found in logs."
  write-DRMMDiag "$($script:diag)"
  exit 1
}
#END SCRIPT
#------------