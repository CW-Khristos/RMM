<# 
.SYNOPSIS 
    Assists you in finding machines that have ran dangerous commands such as invoke-expression, often used for attacks called 'Living off-the-Land'
    Related blog: https://www.cyberdrain.com/monitoring-with-powershell-preventing-powershell-based-attacks-lolbas/

.DESCRIPTION 
    Assists you in finding machines that have ran dangerous commands such as invoke-expression, often used for attacks called 'Living off-the-Land'
 
.NOTES
    Version        : 0.1.0 (11 March 2022)
    Creation Date  : ???
    Purpose/Change : Assists you in finding machines that have ran dangerous commands
    File Name      : PS_Events_0.1.0.ps1 
    Modifications  : Christopher Bledsoe - cbledsoe@ipmcomputers.com
    Supported OS   : Server 2012R2 and higher
    Requires       : PowerShell Version 2.0+ installed

.CHANGELOG
    0.1.0 Modified original code from DattoRMM to actually be functional and report events properly to diagnostic output in DattoRMM
    
To Do:


#>

#REGION ----- DECLARATIONS ----
  $global:cmds = 0
  $global:diag = $null
  $global:hashCMD = @{}
  $DangerousCommands = @("iwr", "irm", "curl", "saps","sal", "iex","set-alias", "Invoke-Expression", "Invoke-RestMethod", "Invoke-WebRequest", "Invoke-RestMethod")
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
    if ($Event.Message -like "*$Command*" -and $Event.Message -notlike "*DangerousCommands*") {
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