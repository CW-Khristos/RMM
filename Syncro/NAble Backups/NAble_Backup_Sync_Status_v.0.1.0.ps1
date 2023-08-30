<#
.SYNOPSIS 
    # ----- About: ----
    # SolarWinds Backup LocalSpeed Check
    # Revision v12 - 2020-08-17
    # Authors: Dion Jones & Eric Harless, Head Backup Nerd - SolarWinds 
    # Twitter @Backup_Nerd  Email:eric.harless@solarwinds.com
    # Modifications: Christopher Bledsoe, Tier II Tech - IPM Computers
    # Email: cbledsoe@ipmcomputers.com
# -----------------------------------------------------------

.DESCRIPTION
<# ----- Behavior: ----
    # Add to SolarWinds RMM as a ScriptCheck
    # Monitors Standalone and Integrated Backup deployments
    # Reads Status.xml file for LSV status and device information.
# -----------------------------------------------------------

.NOTES
    Version        : 0.1.0 (17 March 2022)
    Creation Date  : 17 August 2020
    Purpose/Change : Assists you in finding machines that have ran dangerous commands
    File Name      : NAble_Backup_Sync_Status_v.0.1.0.ps1
    Authors        : Dion Jones & Eric Harless, Head Backup Nerd - SolarWinds 
    Twitter        : @Backup_Nerd  Email:eric.harless@solarwinds.com
    Modifications  : Christopher Bledsoe - cbledsoe@ipmcomputers.com
    Supported OS   : Server 2012R2 and higher
    Requires       : PowerShell Version 2.0+ installed
    
<# ----- Legal: ----
    # Sample scripts are not supported under any SolarWinds support program or service.
    # The sample scripts are provided AS IS without warranty of any kind.
    # SolarWinds expressly disclaims all implied warranties including, warranties
    # of merchantability or of fitness for a particular purpose. 
    # In no event shall SolarWinds or any other party be liable for damages arising
    # out of the use of or inability to use the sample scripts.
# -----------------------------------------------------------

.CHANGELOG
    0.1.0 Modified original code from DattoRMM to function within SyncroRMM
    
.TODO

#>

#REGION ----- DECLARATIONS ----
  Import-Module $env:SyncroModule
  $script:diag = $null
  $script:lsv = $null
  $script:remote = $null
  $script:blnWARN = $false
#ENDREGION ----- DECLARATIONS ----

#REGION ----- FUNCTIONS ----
  function Convert-FromUnixDate ($UnixDate) {
     [timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($UnixDate))
  }

  function CheckSync {
    Param ([xml]$StatusReport)
    #Get Data for BackupServerSynchronizationStatus
    $BackupServSync = $StatusReport.Statistics.BackupServerSynchronizationStatus
    #Report results
    if ($BackupServSync -eq "Failed") {
      write-output "Remote Synchronization Failed"
      $script:remote = "Remote Sync : Failed"
      $script:diag += "Remote Synchronization Failed`r`n"
      $script:blnWARN = $true
    } elseif ($BackupServSync -eq "Synchronized") {
      write-output "Remote Synchronized"
      $script:remote = "Remote Sync : 100%"
      $script:diag += "Remote Synchronized`r`n"
    } elseif ($BackupServSync -like '*%') {
      write-output "Remote Synchronization: $($BackupServSync)"
      $script:remote = "Remote Sync : $($BackupServSync)"
      $script:diag += "Remote Synchronization: $($BackupServSync)`r`n"
    } else {
      write-output "Remote Synchronization Data Invalid or Not Found"
      $script:remote = "Remote Sync : Data Invalid or Not Found"
      $script:diag += "Remote Synchronization Data Invalid or Not Found`r`n"
      $script:blnWARN = $true
    }
    
    #Get Data for LocalSpeedVaultSynchronizationStatus
    if ($LSV_Enabled -eq "Enabled") {
      $LSVSync = $StatusReport.Statistics.LocalSpeedVaultSynchronizationStatus
      #Report results
      if ($LSVSync -eq "Failed") {
        write-output "LocalSpeedVault Synchronization Failed"
        $script:lsv = "LSV Sync : Failed"
        $script:diag += "LocalSpeedVault Synchronization Failed`r`n"
        $script:blnWARN = $true
      } elseif ($LSVSync -eq "Synchronized") {
        write-output "LocalSpeedVault Synchronized"
        $script:lsv = "LSV Sync : 100%"
        $script:diag += "LocalSpeedVault Synchronized`r`n"
      } elseif ($LSVSync -like '*%') {
        write-output "LocalSpeedVault Synchronization: $($LSVSync)"
        $script:lsv = "LSV Sync : $($LSVSync)"
        $script:diag += "LocalSpeedVault Synchronization: $($LSVSync)`r`n"
      } else {
        write-output "LocalSpeedVault Synchronization Data Invalid or Not Found"
        $script:lsv = "LSV Sync : Data Invalid or Not Found"
        $script:diag += "LocalSpeedVault Synchronization Data Invalid or Not Found`r`n"
        $script:blnWARN = $true
      }
    } elseif ($LSV_Enabled -eq "Disabled") {
      $script:lsv = "LSV Sync : N/A"
    }
  }
#ENDREGION ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
clear-host
#Paths of both RMM & Standalone
$MOB_path = "$env:ALLUSERSPROFILE\Managed Online Backup\Backup Manager\StatusReport.xml"
$SA_path = "$env:ALLUSERSPROFILE\MXB\Backup Manager\StatusReport.xml"
$CLI_path = "$env:PROGRAMFILES\Backup Manager\clienttool.exe"

#Boolean vars to indicate if each exists
$test_MOB = Test-Path $MOB_path
$test_SA = Test-Path $SA_path
$test_CLI = Test-Path $CLI_path

#If they both exist, get last modified time and place path of most recent in true_path
If ($test_MOB -eq $True -And $test_SA -eq $True) {
    $lm_MOB = [datetime](Get-ItemProperty -Path $MOB_path -Name LastWriteTime).lastwritetime
	$lm_SA =  [datetime](Get-ItemProperty -Path $SA_path -Name LastWriteTime).lastwritetime
	if ((Get-Date $lm_MOB) -gt (Get-Date $lm_SA)) {
		$true_path = $MOB_path
	} else {
		$true_path = $SA_path
	}
#If one exists, place it in true_path
} elseif ($test_SA -eq $True) {
	$true_path = $SA_path
} elseif ($test_MOB -eq $True) {
	$true_path = $MOB_path
#If none exist, report & fail check
} else {
	write-output "StatusReport.xml Not Found"
  $script:diag += "StatusReport.xml Not Found`r`n"
  $script:blnWARN = $true
}

#If true_path is not null, get XML data
if ($true_path) {
  [xml]$StatusReport = Get-Content $true_path
  #Get data for LocalSpeedVaultEnabled
  $LSV_Enabled = $StatusReport.Statistics.LocalSpeedVaultEnabled
  #If LocalSpeedVaultEnabled is 0, report not enabled
  if ($LSV_Enabled -eq "0") {
    write-output "LocalSpeedVault is not Enabled`r`n"
    $script:diag += "LocalSpeedVault is not Enabled`r`n"
    $LSV_Enabled = "Disabled"
    $LSV_Location = "N/A"
    #If LocalSpeedVaultEnabled is 1, report enabled
  } elseIf ($LSV_Enabled -eq "1") {
    write-output "LocalSpeedVault is Enabled"
    $script:diag += "LocalSpeedVault is Enabled`r`n"
    $LSV_Enabled = "Enabled"
    #Retrieve the LSV Location from ClientTool
    $test = & cmd.exe /c `"$CLI_path`" control.setting.list
    $test = [String]$test
    $items = $test -split "LocalSpeedVaultLocation "
    $items = $items[1] -split "LocalSpeedVaultPassword "
    $LSV_Location = $items[0]
  }
  #Check Remote & LSV Sync Status
  CheckSync -StatusReport $StatusReport
  #Return Generalized Data
  $TimeStamp = Convert-FromUnixDate $Statusreport.Statistics.TimeStamp
  $PartnerName = $StatusReport.Statistics.PartnerName
  $Account = $StatusReport.Statistics.Account
  $MachineName = $StatusReport.Statistics.MachineName
  $ClientVersion = $StatusReport.Statistics.ClientVersion
  $OsVersion = $StatusReport.Statistics.OsVersion
  $IpAddress = $StatusReport.Statistics.IpAddress
  write-output "TimeStamp: $($TimeStamp) Local Device Time"
  $script:diag += "`r`nTimeStamp: $($TimeStamp) Local Device Time`r`n"
  write-output "PartnerName: $($PartnerName)"
  $script:diag += "PartnerName: $($PartnerName)`r`n"
  write-output "Account: $($Account)"
  $script:diag += "Account: $($Account)`r`n"
  write-output "MachineName: $($MachineName)"
  $script:diag += "MachineName: $($MachineName)`r`n"
  write-output "ClientVersion: $($ClientVersion)"
  $script:diag += "ClientVersion: $($ClientVersion)`r`n"
  write-output "OsVersion: $($OsVersion)"
  $script:diag += "OsVersion: $($OsVersion)`r`n"
  write-output "IpAddress: $($IpAddress)"
  $script:diag += "IpAddress: $($IpAddress)`r`n"
}
#SYNCRO OUTPUT
write-output 'SYNCRO OUTPUT :'
if ($script:blnWARN) {
  $alert = "MSP Backup Sync : Warning - $($script:remote) - LSV : $($LSV_Enabled) - $($script:lsv) - LSV Location : $($LSV_Location)"
  Rmm-Alert -Category "SolarWinds MSP Backup Sync Status" -Body "$($alert)"
  Log-Activity -Message "$($alert)" -EventName "SolarWinds MSP Backup Sync Status : Warning"
} elseif (-not $script:blnWARN) {
  $alert = "MSP Backup Sync : Healthy - $($script:remote) - LSV : $($LSV_Enabled) - $($script:lsv) - LSV Location : $($LSV_Location)"
  Log-Activity -Message "$($alert)" -EventName "Solarwinds MSP Backup Sync Status : Healthy"
}
#END SCRIPT
#------------