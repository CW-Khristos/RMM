<#
.SYNOPSIS 
    Monitors SolarWinds MSP/IASO Backup using the generated log.
    Related blog: https://www.cyberdrain.com/378/

.DESCRIPTION 
    Monitors SolarWinds MSP/IASO Backup using the generated log.
 
.NOTES
    Version        : 0.1.0 (17 March 2022)
    Creation Date  : 17 March 2022
    Purpose/Change : Assists you in finding machines that have ran dangerous commands
    File Name      : NAble_Backup_Status_v.0.1.0.ps1
    Author         : Kelvin Tegelaar - https://www.cyberdrain.com
    Modifications  : Christopher Bledsoe - cbledsoe@ipmcomputers.com
    Supported OS   : Server 2012R2 and higher
    Requires       : PowerShell Version 2.0+ installed

.CHANGELOG
    0.1.0 Modified original code from DattoRMM to function within SyncroRMM
    
.TODO

#>

#REGION ----- DECLARATIONS ----
  Import-Module $env:SyncroModule
  $global:bitarch = $null
  $global:OSCaption = $null
  $global:OSVersion = $null
  $global:producttype = $null
  $global:computername = $env:computername
#ENDREGION ----- DECLARATIONS ----

#REGION ----- FUNCTIONS ----
  function Get-OSArch {                                                                             #Determine Bit Architecture & OS Type
    #OS Bit Architecture
    $osarch = (get-wmiobject win32_operatingsystem).osarchitecture
    if ($osarch -like '*64*') {
      $global:bitarch = "bit64"
    } elseif ($osarch -like '*32*') {
      $global:bitarch = "bit32"
    }
    #OS Type & Version
    $global:OSCaption = (Get-WmiObject Win32_OperatingSystem).Caption
    $global:OSVersion = (Get-WmiObject Win32_OperatingSystem).Version
    $osproduct = (Get-WmiObject -class Win32_OperatingSystem).Producttype
    Switch ($osproduct) {
      "1" {$global:producttype = "Workstation"}
      "2" {$global:producttype = "DC"}
      "3" {$global:producttype = "Server"}
    }
  } ## Get-OSArch
#ENDREGION ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
#DETERMINE OS TYPE SINCE OUR BACKUP SCHEDULES DIFFER
Get-OSArch
if ($global:producttype -eq "Workstation") {
  $Date = (get-date).AddHours(-8)
} elseif ($global:producttype -ne "Workstation") {
  $Date = (get-date).AddHours(-24)
}
#RETRIEVE SESSION LIST FROM WITHIN ELECTED TIME RANGE ABOVE AND ONLY RETURN 'FAILED' BACKUPS
$SessionsList = & "C:\Program Files\Backup Manager\clienttool.exe" -machine-readable control.session.list  -delimiter "," | convertfrom-csv -Delimiter "," | where-object { $_.state -ne "Completed" -and [datetime]$_.start -gt $Date }
$FailedBackups = foreach ($session in $SessionsList) {
  if ($Session.state -eq 'InProcess' -and $session.START -lt $Date) { "Backup has been running for over 23 hours. Backup Started at $($session.START)" }
  if ($Session.state -eq 'CompletedwithErrors') { "Backup has completed with an error. Backup Started at $($session.START)" }
  if ($Session.state -eq 'Failed') { "Backup has failed with an error. Backup Started at $($session.START)" }
  if ($Session.state -eq 'Skipped') { "Backup has been skipped as previous job was still running. Backup Started at $($session.START)" }
}
#SYNCRO OUTPUT
write-host 'SYNCRO OUTPUT :'
if ($FailedBackups) {
  $alert = $FailedBackups, $SessionsList | Out-String
  Rmm-Alert -Category "SolarWinds MSP Backup Status : Warning" -Body "$($alert)"
  Log-Activity -Message "SolarWinds MSP Backup Status : Warning" -EventName "SolarWinds MSP Backup Status : Warning"
} else {
  Log-Activity -Message "SolarWinds MSP Backup Status : Healthy" -EventName "SolarWinds MSP Backup Status : Healthy"
}
#END SCRIPT
#------------