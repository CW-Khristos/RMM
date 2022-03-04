clear-host

<# # ----- About: ----
    # SolarWinds Backup LocalSpeed Check
    # Revision v12 - 2020-08-17
    # Authors: Dion Jones & Eric Harless, Head Backup Nerd - SolarWinds 
    # Twitter @Backup_Nerd  Email:eric.harless@solarwinds.com
# -----------------------------------------------------------#>

<# ----- Legal: ----
    # Sample scripts are not supported under any SolarWinds support program or service.
    # The sample scripts are provided AS IS without warranty of any kind.
    # SolarWinds expressly disclaims all implied warranties including, warranties
    # of merchantability or of fitness for a particular purpose. 
    # In no event shall SolarWinds or any other party be liable for damages arising
    # out of the use of or inability to use the sample scripts.
# -----------------------------------------------------------#>

<# ----- Behavior: ----
    # 
    # Add to SolarWinds RMM as a ScriptCheck
    # Monitors STandalone and Integrated Backup deployments
    # Reads Status.xml file for LSV status and device information.
    #

# -----------------------------------------------------------#>

$global:fail = $null

Function Convert-FromUnixDate ($UnixDate) {
   [timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($UnixDate))
}

function CheckSync {
	Param ([xml]$StatusReport)
	#Get Data for BackupServerSynchronizationStatus
	$BackupServSync = $StatusReport.Statistics.BackupServerSynchronizationStatus
	#Report results
	if($BackupServSync -eq "Failed") {
		Write-Host "Backup Synchronization Failed"
		$global:failed = 1
	} elseif ($BackupServSync -eq "Synchronized") {
		Write-Host "Backup Synchronized"
	} elseif ($BackupServSync -like '*%') {
		Write-Host "Backup Synchronization: $BackupServSync"
	} else {
		Write-Host "Backup Synchronization Data Invalid or Not Found"
		$global:failed = 1
	}
	
	#Get Data for LocalSpeedVaultSynchronizationStatus
	$LSVSync = $StatusReport.Statistics.LocalSpeedVaultSynchronizationStatus
	#Report results
	if($LSVSync -eq "Failed") {
		Write-Host "LocalSpeedVault Synchronization Failed"
		$global:failed = 1
	} elseif($LSVSync -eq "Synchronized") {
		Write-Host "LocalSpeedVault Synchronized"
	} elseif($LSVSync -like '*%') {
		Write-Host "LocalSpeedVault Synchronization: $LSVSync"
	} else {
		Write-Host "LocalSpeedVault Synchronization Data Invalid or Not Found"
		$global:failed = 1
	}
}

function Split-StringOnLiteralString {
  trap {
    Write-Error "An error occurred using the Split-StringOnLiteralString function. This was most likely caused by the arguments supplied not being strings"
  }

  if ($args.Length -ne 2) ` {
    Write-Error "Split-StringOnLiteralString was called without supplying two arguments. The first argument should be the string to be split, and the second should be the string or character on which to split the string."
  } `
  else ` {
    if (($args[0]).GetType().Name -ne "String") ` {
      Write-Warning "The first argument supplied to Split-StringOnLiteralString was not a string. It will be attempted to be converted to a string. To avoid this warning, cast arguments to a string before calling Split-StringOnLiteralString."
      $strToSplit = [string]$args[0]
    } `
    else ` {
      $strToSplit = $args[0]
    }

    if ((($args[1]).GetType().Name -ne "String") -and (($args[1]).GetType().Name -ne "Char")) ` {
      Write-Warning "The second argument supplied to Split-StringOnLiteralString was not a string. It will be attempted to be converted to a string. To avoid this warning, cast arguments to a string before calling Split-StringOnLiteralString."
      $strSplitter = [string]$args[1]
    } `
    elseif (($args[1]).GetType().Name -eq "Char") ` {
      $strSplitter = [string]$args[1]
    } `
    else ` {
      $strSplitter = $args[1]
    }

    $strSplitterInRegEx = [regex]::Escape($strSplitter)
    [regex]::Split($strToSplit, $strSplitterInRegEx)
  }
}

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
	$global:failed = 1
}

#If true_path is not null, get XML data
if ($true_path) {
	[xml]$StatusReport = Get-Content $true_path
	#Get data for LocalSpeedVaultEnabled
	$LSV_Enabled = $StatusReport.Statistics.LocalSpeedVaultEnabled
	#If LocalSpeedVaultEnabled is 0, report not enabled
	if ($LSV_Enabled -eq "0") {
		Write-Host "LocalSpeedVault is not Enabled"
		$global:failed = 1
	#If LocalSpeedVaultEnabled is 1, report enabled and go to CheckSync function
	} elseIf ($LSV_Enabled -eq "1") {
		Write-Host "LocalSpeedVault is Enabled"
		CheckSync -StatusReport $StatusReport
    #Retrieve the LSV Location from ClientTool
    #$test = Get-ProcessOutput -FileName "cmd.exe" -Args "/c `"$CLI_path`" control.setting.list"
    $test = & cmd.exe /c `"$CLI_path`" control.setting.list
    $test = [String]$test
    $items = Split-StringOnLiteralString $test "LocalSpeedVaultLocation "
    $items = Split-StringOnLiteralString $items[1] "LocalSpeedVaultPassword "
    $LSV_Location = $items[0]
	}
	
	#Return Generalized Data
  $TimeStamp = Convert-FromUnixDate $Statusreport.Statistics.TimeStamp
	$PartnerName = $StatusReport.Statistics.PartnerName
	$Account = $StatusReport.Statistics.Account
	$MachineName = $StatusReport.Statistics.MachineName
	$ClientVersion = $StatusReport.Statistics.ClientVersion
	$OsVersion = $StatusReport.Statistics.OsVersion
	$IpAddress = $StatusReport.Statistics.IpAddress
	Write-Host "TimeStamp: $TimeStamp Local Device Time"
	Write-Host "PartnerName: $PartnerName"
	Write-Host "Account: $Account"
	Write-Host "MachineName: $MachineName"
	Write-Host "ClientVersion: $ClientVersion"
	Write-Host "OsVersion: $OsVersion"
	Write-Host "IpAddress: $IpAddress"
}

#If $global:failed is 1, cause scriptcheck to fail in dashboard
if ($global:failed -eq 1) {
	Exit 1001
} else {
	Exit 0
}
