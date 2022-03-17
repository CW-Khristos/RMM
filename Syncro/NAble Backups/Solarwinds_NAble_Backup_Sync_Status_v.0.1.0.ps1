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
    File Name      : Solarwinds_NAble_Backup_Sync_Status_v.0.1.0.ps1
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
  $global:diag = $null
  $global:lsv = $null
  $global:remote = $null
  $global:blnWARN = $false
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
      Write-Host "Remote Synchronization Failed"
      $global:remote = "Remote Sync : Failed"
      $global:diag += "Remote Synchronization Failed`r`n"
      $global:blnWARN = $true
    } elseif ($BackupServSync -eq "Synchronized") {
      Write-Host "Remote Synchronized"
      $global:remote = "Remote Sync : 100%"
      $global:diag += "Remote Synchronized`r`n"
    } elseif ($BackupServSync -like '*%') {
      Write-Host "Remote Synchronization: $($BackupServSync)"
      $global:remote = "Remote Sync : $($BackupServSync)"
      $global:diag += "Remote Synchronization: $($BackupServSync)`r`n"
    } else {
      Write-Host "Remote Synchronization Data Invalid or Not Found"
      $global:remote = "Remote Sync : Data Invalid or Not Found"
      $global:diag += "Remote Synchronization Data Invalid or Not Found`r`n"
      $global:blnWARN = $true
    }
    
    #Get Data for LocalSpeedVaultSynchronizationStatus
    if ($LSV_Enabled -eq "Enabled") {
      $LSVSync = $StatusReport.Statistics.LocalSpeedVaultSynchronizationStatus
      #Report results
      if ($LSVSync -eq "Failed") {
        Write-Host "LocalSpeedVault Synchronization Failed"
        $global:lsv = "LSV Sync : Failed"
        $global:diag += "LocalSpeedVault Synchronization Failed`r`n"
        $global:blnWARN = $true
      } elseif ($LSVSync -eq "Synchronized") {
        Write-Host "LocalSpeedVault Synchronized"
        $global:lsv = "LSV Sync : 100%"
        $global:diag += "LocalSpeedVault Synchronized`r`n"
      } elseif ($LSVSync -like '*%') {
        Write-Host "LocalSpeedVault Synchronization: $($LSVSync)"
        $global:lsv = "LSV Sync : $($LSVSync)"
        $global:diag += "LocalSpeedVault Synchronization: $($LSVSync)`r`n"
      } else {
        Write-Host "LocalSpeedVault Synchronization Data Invalid or Not Found"
        $global:lsv = "LSV Sync : Data Invalid or Not Found"
        $global:diag += "LocalSpeedVault Synchronization Data Invalid or Not Found`r`n"
        $global:blnWARN = $true
      }
    } elseif ($LSV_Enabled -eq "Disabled") {
      $global:lsv = "LSV Sync : N/A"
    }
  }

  function Split-StringOnLiteralString {
    trap {
      Write-Error "An error occurred using the Split-StringOnLiteralString function. This was most likely caused by the arguments supplied not being strings"
    }

    if ($args.Length -ne 2) {
      Write-Error "Split-StringOnLiteralString was called without supplying two arguments. The first argument should be the string to be split, and the second should be the string or character on which to split the string."
    } else {
      if (($args[0]).GetType().Name -ne "String") {
        Write-Warning "The first argument supplied to Split-StringOnLiteralString was not a string. It will be attempted to be converted to a string. To avoid this warning, cast arguments to a string before calling Split-StringOnLiteralString."
        $strToSplit = [string]$args[0]
      } else {
        $strToSplit = $args[0]
      }

      if ((($args[1]).GetType().Name -ne "String") -and (($args[1]).GetType().Name -ne "Char")) {
        Write-Warning "The second argument supplied to Split-StringOnLiteralString was not a string. It will be attempted to be converted to a string. To avoid this warning, cast arguments to a string before calling Split-StringOnLiteralString."
        $strSplitter = [string]$args[1]
      } elseif (($args[1]).GetType().Name -eq "Char") {
        $strSplitter = [string]$args[1]
      } else {
        $strSplitter = $args[1]
      }

      $strSplitterInRegEx = [regex]::Escape($strSplitter)
      [regex]::Split($strToSplit, $strSplitterInRegEx)
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
	Write-Host "StatusReport.xml Not Found"
  $global:diag += "StatusReport.xml Not Found`r`n"
  $global:blnWARN = $true
}

#If true_path is not null, get XML data
if ($true_path) {
  [xml]$StatusReport = Get-Content $true_path
  #Get data for LocalSpeedVaultEnabled
  $LSV_Enabled = $StatusReport.Statistics.LocalSpeedVaultEnabled
  #If LocalSpeedVaultEnabled is 0, report not enabled
  if ($LSV_Enabled -eq "0") {
    Write-Host "LocalSpeedVault is not Enabled`r`n"
    $global:diag += "LocalSpeedVault is not Enabled`r`n"
    $LSV_Enabled = "Disabled"
    $LSV_Location = "N/A"
    #If LocalSpeedVaultEnabled is 1, report enabled
  } elseIf ($LSV_Enabled -eq "1") {
    Write-Host "LocalSpeedVault is Enabled"
    $global:diag += "LocalSpeedVault is Enabled`r`n"
    $LSV_Enabled = "Enabled"
    #Retrieve the LSV Location from ClientTool
    $test = & cmd.exe /c `"$CLI_path`" control.setting.list
    $test = [String]$test
    $items = Split-StringOnLiteralString $test "LocalSpeedVaultLocation "
    $items = Split-StringOnLiteralString $items[1] "LocalSpeedVaultPassword "
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
  Write-Host "TimeStamp: $($TimeStamp) Local Device Time"
  $global:diag += "`r`nTimeStamp: $($TimeStamp) Local Device Time`r`n"
  Write-Host "PartnerName: $($PartnerName)"
  $global:diag += "PartnerName: $($PartnerName)`r`n"
  Write-Host "Account: $($Account)"
  $global:diag += "Account: $($Account)`r`n"
  Write-Host "MachineName: $($MachineName)"
  $global:diag += "MachineName: $($MachineName)`r`n"
  Write-Host "ClientVersion: $($ClientVersion)"
  $global:diag += "ClientVersion: $($ClientVersion)`r`n"
  Write-Host "OsVersion: $($OsVersion)"
  $global:diag += "OsVersion: $($OsVersion)`r`n"
  Write-Host "IpAddress: $($IpAddress)"
  $global:diag += "IpAddress: $($IpAddress)`r`n"
}
#SYNCRO OUTPUT
write-host 'SYNCRO OUTPUT :'
if ($global:blnWARN) {
  $alert = "MSP Backup Sync : Warning - $($global:remote) - LSV : $($LSV_Enabled) - $($global:lsv) - LSV Location : $($LSV_Location)"
  Rmm-Alert -Category "SolarWinds MSP Backup Sync Status" -Body "$($alert)"
  Log-Activity -Message "$($alert)" -EventName "SolarWinds MSP Backup Sync Status : Warning"
} elseif (-not $global:blnWARN) {
  $alert = "MSP Backup Sync : Healthy - $($global:remote) - LSV : $($LSV_Enabled) - $($global:lsv) - LSV Location : $($LSV_Location)"
  Log-Activity -Message "$($alert)" -EventName "Solarwinds MSP Backup Sync Status : Healthy"
}
#END SCRIPT
#------------