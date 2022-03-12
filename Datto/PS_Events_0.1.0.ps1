<# 
.SYNOPSIS 
    Assists you in finding machines that have ran dangerous commands such as invoke-expression, often used for attacks called 'Living off-the-Land'
    Related blog: https://www.cyberdrain.com/monitoring-with-powershell-preventing-powershell-based-attacks-lolbas/

.DESCRIPTION 
    Assists you in finding machines that have ran dangerous commands such as invoke-expression, often used for attacks called 'Living off-the-Land'
 
.NOTES
    Version        : 0.1.1 (11 March 2022)
    Creation Date  : 14 May 2020
    Purpose/Change : Assists you in finding machines that have ran dangerous commands
    File Name      : PS_Events_0.1.1.ps1
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
      Attempting some basic syntax matching with the items in the '$DangerousCommands' array to prevent unnecessary "false" Alerts
    
To Do:
    Script still has undesired behavior of "detecting" dangerous commands being used; even when they are not
    An example of this would be if the word "confirm" where contained in  ascript (Prejay's 'Get-PMEServices' script was one I personally came across)
    The above example would still cause an Alert due to the matching of 'irm' Alias in conf*irm*; this has the potential to cause a continual false "Alerts" in an RMM
    While it is expected that techs would need to review the content of the Alert for confirmation; this would be highly in-efficient

#>

#REGION ----- DECLARATIONS ----
  $global:cmds = 0
  $global:diag = $null
  $global:hashCMD = @{}
  $DangerousCommands = @("Get-WinEvent", "iwr", "irm", "curl", "saps","sal", "iex","set-alias", "Invoke-Expression", "Invoke-RestMethod", "Invoke-WebRequest")
#ENDREGION ----- DECLARATIONS ----

#REGION ----- FUNCTIONS ----
  function write-DRMMDiag ($messages) {
    write-host  '<-Start Diagnostic->'
    foreach ($Message in $Messages) { $Message }
    write-host '<-End Diagnostic->'
  }

  function write-DRRMAlert ($message) {
    write-host '<-Start Result->'
    write-host "Alert=$message"
    write-host '<-End Result->'
  }
#ENDREGION ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
$version = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentVersion
if ($Version -lt "6.2") {
  write-DRRMAlert "Unsupported OS. Only Server 2012R2 and up are supported."
  exit 1
}

$ScriptBlockLogging = get-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging"
if ($ScriptBlockLogging.EnableScriptBLockLogging -ne 1) { 
  write-DRRMAlert  "Error - Script Block Logging is not enabled"
  exit 1
} else {
  write-host "Healthy - Script Block Logging is enabled" 
}

$logInfo = @{ 
  ProviderName = "Microsoft-Windows-PowerShell"
  StartTime    = (get-date).AddHours(-2)
  EndTime      = (get-date).AddMinutes(-5)
}
$PowerShellEvents = Get-WinEvent -FilterHashtable $logInfo -ErrorAction SilentlyContinue | Select-Object TimeCreated, message
$PowerShellLogs = foreach ($Event in $PowerShellEvents) {
  foreach ($command in $DangerousCommands) {
    #if ($Event.Message -like "*$Command*" -and $Event.Message -notlike "*DangerousCommands*") {
    if ((($Event.Message -like "*$Command -*") -or 
      ($Event.Message -like "*$Command '*") -or 
      ($Event.Message -like "*$Command \`"*")) -and 
      ($Event.Message -notlike "*DangerousCommands*")) {
        $global:cmds = $global:cmds + 1
        $hash = @{
          TimeCreated      = $event.TimeCreated
          EventMessage     = $Event.message
          TriggeredCommand = $command
        }
        $global:hashCMD.add($global:cmds, $hash)
    }
  }
}
#DATTO OUTPUT
if ($global:cmds -eq 0) {
  write-DRRMAlert "Powershell Events : Healthy"
  exit 0
} else {
  write-DRRMAlert "Powershell Events : Not Healthy - Dangerous commands found in logs."
  foreach ($cmd in $global:hashCMD.Keys) {
    $global:diag += "`r`nTriggered Command : $($global:hashCMD[$cmd].TriggeredCommand)`r`nTimestamp : $($global:hashCMD[$cmd].TimeCreated)`r`nDetails : $($global:hashCMD[$cmd].EventMessage)`r`n`r`n"
  }
  write-DRMMDiag ($global:diag)
  exit 1
}
#END SCRIPT
#------------