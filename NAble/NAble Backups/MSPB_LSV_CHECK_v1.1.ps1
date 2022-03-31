<# 
.SYNOPSIS 
    MSPB Local Speed Vault(LSV) monitoring

.DESCRIPTION 
    Retrieve MSP Backup(MSPB) Local Speed Vault(LSV) monitoring information via status file parsing 
 
.NOTES
    Version        : 1.0 
    Creation Date  : 15 May 2019
    Purpose/Change : Provide LSV Sync status
    File Name      : MSPB_LSV_check_<version_info>.ps1 
    Author         : Jason Roger - jason.roger@solarwinds.com 
    Requires       : PowerShell Version 2.0+ installed
                   : MSPB installed
#> 

#---------------------------------------------------------[Initialisations]--------------------------------------------------------
#set error action to Silently Continue
$ErrorActionPreference = "SilentlyContinue"
#debug options
$old_VerbosePreference = $VerbosePreference
$VerbosePreference = "Continue"
$DebugPreference = "Continue"
#----------------------------------------------------------[Declarations]----------------------------------------------------------
$serviceStatusLegend = "0-normal,1-warning,2-failure"

$MSPB_truePath = $null
$runTimeException = 0

$LSV_EnabledMessage = "Unknown"
$LSV_EnabledStatus = 2

$LSVSyncMessage = "Unknown"
$LSVSyncStatus = 0

$LSVLocation = "Unknown"

$MSPB_cloudSyncMessage = "Unknown"
#$MSPB_cloudSyncStatus = 2

$MSPB_logPath = "Unknown"

#$LocalSpeedVaultUnavailabilityTimeoutInDays_Default = 14
#$LocalSpeedVaultDaysSinceSelfHealingTrigger = $LocalSpeedVaultUnavailabilityTimeoutInDays_Default
$LSV_SelfHealingCountdownTrigger = $false

$MSPB_configINIfileLocation = "C:/Program Files/Backup Manager/config.ini"


$agentVersion = "default"
$agentCDPVersionMin = "12.1.0.744"

$propertyName1 = "MSPB_selfHealingTriggerDate"
$propertyName1_value = "not triggered"

$ncentralServer = $i_ncentralServer
$ncentralUserName = $i_ncentralUserName
$ncentralPassword = $i_ncentralPassword

$origPropertyValue = $null

$bindingURL = $null
$nws = $null



#-----------------------------------------------------------[Functions]------------------------------------------------------------

Function Get-TimeStamp {
    return "{0:MM/dd/yy} {0:HH:mm tt}" -f (Get-Date)
}

Function getDeviceID
{
	Param()
	Try 
	{
		Write-Debug "Starting getDeviceId"
		#get the object type
		$namespace = $nws.getType().namespace
		
	    # get appliance id
	    $ApplianceConfig = ("{0}\N-able Technologies\Windows Agent\config\ApplianceConfig.xml" -f ${Env:ProgramFiles(x86)})
	    $xml = [xml](Get-Content -Path $ApplianceConfig)
	    $applianceID = $xml.ApplianceConfig.ApplianceID
        
        # create Key Pairs
        $keyPairs = @()
        $keyPair = New-Object($namespace + ".tKeyPair")
	    $keyPair.Key = 'applianceID'
	    $keyPair.Value = $applianceID
	    $keyPairs += $keyPair

        #API call
		$deviceList = $nws.deviceGet($ncentralUserName, $ncentralPassword, $keyPairs)
        
        #How many issues were found:
        #Write-Host $rc.count "issues found" `r`n
        
        #Array to hold the filtered data
        [System.Collections.ArrayList]$collection = New-Object System.Collections.ArrayList($null)
        
		#Put the returned data into a hash table 
		if ($deviceList -is [system.array])  # take only the initial object
		{
			$device = $deviceList[0]
			$deviceInfo = @{}
			foreach ($item in $device.Info) {
				$deviceInfo[$item.Key] = $item.Value
			}
			$deviceHash = New-Object psobject -Property $deviceInfo
		}
		$deviceHash
	}
	Finally
	{
		Write-Debug "Exiting getDeviceID"
	}
}

Function getDeviceProperties
{
	param(
		[array]$deviceIds = $null
	)
	PROCESS
	{
		Try 
		{
			Write-Debug "Starting getDeviceProperties"
			$nws.devicePropertyList($ncentralUserName, $ncentralPassword, $deviceIds, $null, $null, $null, $false)
		}
		Finally
		{
			Write-Debug "Exiting getDeviceProperties"
		}
	}
} 

Function pushDeviceProperties
{
	param(
		[array]$devicesPropertyArray
	)

	PROCESS
	{
		Try 
		{
			#$devicesPropertyArray
			Write-Debug "Starting Save_NC_Device"
			if ($devicesPropertyArray -ne $null -and $devicesPropertyArray.Length -gt 0)
			{
				$nws.devicePropertyModify($ncentralUserName, $ncentralPassword, $devicesPropertyArray)
			}
			else
			{
				Write-Debug "INFO:Nothing to save"
			}
		}
		Finally
		{
			Write-Debug "Exiting Save_NC_Device"
		}
	}
}

Function Update-CDPs(){
	Try
	{
		Write-Debug ("Starting Update-CDPs ")
        #Get-NCentralSvr
        #Get-webservice
        $bindingURL = "https://" + $ncentralServer + "/dms2/services2/ServerEI2?wsdl"
        
        $secpasswd = ConvertTo-SecureString $ncentralPassword -AsPlainText -Force
        #create the webservice to access the NCentral server
        $creds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ncentralUserName, $secpasswd
        $nws = new-webserviceproxy $bindingURL -credential $creds 
        $nws.Timeout = 300000 #added/changed in 2018 as script began timing out with the default 100s

        $device = getDeviceID
		$deviceId = $device.'device.deviceid'
		Write-Debug ("DeviceID: $deviceId")
		if ($deviceId -eq $null){
			throw [System.NullReferenceException] "DeviceId cannot be determined"
		}
		$devicePropertyList = getDeviceProperties -deviceId ([array]$deviceId)
        #Update Properties
        $propertyName1_value = Get-TimeStamp
		foreach($device in $devicePropertyList)
		{
			Write-Debug ("Device Name: {0}" -f $device.deviceName)
			foreach($property in $device.properties)
			{
				$origPropertyValue = $property.value 
				switch($property.label)
				{
					$propertyName1 {
                        If ( ($property.value -eq 'not triggered') -and ($LSV_SelfHealingCountdownTrigger -eq $True) ){ 
                            $property.value = $propertyName1_value 
                        }
                        #retreive the value to update the timing/timer
                        ElseIf($LSV_SelfHealingCountdownTrigger -eq $False){
                            $propertyName1_value = "not triggered"
                            $property.value = $propertyName1_value
                        }
                        #retrieve the MSPB_selfHealingTriggerDate property if it's already set, to calculate the updated days since metric
                        Else{
                            $propertyName1_value = $property.value
                        }
                    }
				}
				
                if ( ($property.value -ne $origPropertyValue) -and ($property.value -ne $null) )
				{
					Write-Debug ("Property: {0}, Orig = {1}, New = {2}" -f $property.label, $origPropertyValue, $property.value)
				}
				else
				{
					Write-Debug ("Property: {0}, Orig = {1}, NO CHANGE" -f $property.label, $property.value)
				}
                
			}
		}
        #save new properties to N-central device
		pushDeviceProperties -devicesPropertyArray $devicePropertyList
		$errorCode = 0
	}
	Catch
	{
		$errorCode = -1
		throw "EXCEPTION - unknown error, error code: $errorCode"
	}
	Finally
	{
		Write-Debug ("Exiting Main Script")
	}
}



Function CheckLSVsync {
	Param ([xml]$StatusReport)
	
	#Get Data for LocalSpeedVaultSynchronizationStatus
	$LSVSync = $StatusReport.Statistics.LocalSpeedVaultSynchronizationStatus
	Write-Host "ready"
    #Report results
	If($LSVSync -match ".*(f|F)ailed.*") {
      $LSVSyncMessage = "error, $LSVSync"
      $LSVSyncStatus = 0
	} 
  Elseif($LSVSync -match ".*(s|S)ynchronized.*") {
      $LSVSyncMessage = $LSVSync
      $LSVSyncStatus = 100
	} 
  Elseif( ($LSVSync -match ".*(s|S)ynchronizing.*") -or ($LSVSync -match ".*%.*") ){
      $LSVSyncMessage = $LSVSync
      If($LSVSync.indexof(".") -ne -1) {
        $stat = Split-StringOnLiteralString $LSVSync "."
        $LSVSyncStatus = $stat[0]
      }
      Elseif($LSVSync.indexof(".") -eq -1) {
        $LSVSyncStatus = $LSVSync
      }
	} 
    Else {
        $LSVSyncMessage = "error, data Invalid or Not Found"
        $LSVSyncStatus = 0
	}
}

Function CheckLSVselfHealingStatus {
	Param ([xml]$StatusReport)
    #Get Data for BackupServerSynchronizationStatus
    $MSPB_cloudSyncStatusMessage = $StatusReport.Statistics.BackupServerSynchronizationStatus
    
    If ( ($MSPB_cloudSyncStatusMessage -notmatch ".*(s|S)ynchronized.*") -and ($LSVSyncStatus -eq 2) ) {
        $LSV_SelfHealingCountdownTrigger = $True
        [string]$now = Get-Date
        $propertyName1_value = $now
        #JRremoved to reduce complexity and handle with service thresholds        
        <#
        #check for a LocalSpeedVaultUnavailabilityTimeoutInDays entry in config.ini, otherwise use default (14d, set by var)
        $configFile = Get-Content $MSPB_configINIfileLocation
        $configFileParse = $configFile | Select-String -Pattern '^LocalSpeedVaultUnavailabilityTimeoutInDays=\d{1,}' -ErrorAction SilentlyContinue
        If($configFileParse){
            $configFileParseSplit = $configFileParse -split '='
            $LocalSpeedVaultUnavailabilityTimeoutInDays_Default = $configFileParseSplit[1]
        }
        Else {
            $LocalSpeedVaultDaysSinceSelfHealingTrigger = $LocalSpeedVaultUnavailabilityTimeoutInDays_Default
        }
        #>
    }
    Else{
        $LSV_SelfHealingCountdownTrigger = $False
        $propertyName1_value = "not triggered"
    }
        #check NC CDP support via Agent version, assumes Agents are up-to-date
	    $ApplianceConfig = ("{0}\N-able Technologies\Windows Agent\config\ApplianceConfig.xml" -f ${Env:ProgramFiles(x86)})
	    $xml = [xml](Get-Content -Path $ApplianceConfig)
        $agentVersion = $xml.ApplianceConfig.ApplianceVersion
        #$agentVersioncompare = $agentVersion
        #$agentCDPVersionMinCompare = $agentCDPVersionMin
        If ([System.Version]$agentVersion -ge [System.Version]$agentCDPVersionMin){
            $useAMPout2CDPs = $True
            Write-Debug "Using AMP CDP mappings"
        }
        Else{
            Update-CDPs
        }
        If ($propertyName1_value -ne "not triggered"){
            [datetime]$start = $propertyName1_value
            $LSV_daysSinceSelfHealingTrigger = New-TimeSpan -Start $start -End $now
            $LocalSpeedVaultDaysSinceSelfHealingTrigger = $LSV_daysSinceSelfHealingTrigger.Days 
            #do the math to see how much time is left
            $LSV_SelfHealingCountdownTrigger = $True
        }
        Else{
            $LocalSpeedVaultDaysSinceSelfHealingTrigger = -1
            $LSV_daysSinceSelfHealingTrigger = "not triggered"
        }
}

function Split-StringOnLiteralString {
  trap {
    Write-Error "An error occurred using the Split-StringOnLiteralString function. This was most likely caused by the arguments supplied not being strings"
  }

  if ($args.Length -ne 2) {
    Write-Error "Split-StringOnLiteralString was called without supplying two arguments. The first argument should be the string to be split, and the second should be the string or character on which to split the string."
  }
  else {
    if (($args[0]).GetType().Name -ne "String") {
      Write-Warning "The first argument supplied to Split-StringOnLiteralString was not a string. It will be attempted to be converted to a string. To avoid this warning, cast arguments to a string before calling Split-StringOnLiteralString."
      $strToSplit = [string]$args[0]
    }
    else {
      $strToSplit = $args[0]
    }

    if ((($args[1]).GetType().Name -ne "String") -and (($args[1]).GetType().Name -ne "Char")) {
      Write-Warning "The second argument supplied to Split-StringOnLiteralString was not a string. It will be attempted to be converted to a string. To avoid this warning, cast arguments to a string before calling Split-StringOnLiteralString."
      $strSplitter = [string]$args[1]
    }
    elseif (($args[1]).GetType().Name -eq "Char") {
      $strSplitter = [string]$args[1]
    }
    else {
      $strSplitter = $args[1]
    }

    $strSplitterInRegEx = [regex]::Escape($strSplitter)
    [regex]::Split($strToSplit, $strSplitterInRegEx)
  }
}

#-----------------------------------------------------------[Execution]------------------------------------------------------------
Try{
    #Paths of both RMM & NC/Standalone MSPB Status Report file
    
    $CLI_path = "$env:PROGRAMFILES\Backup Manager\clienttool.exe"
    $MOB_rootPath = "$env:ALLUSERSPROFILE\Managed Online Backup\Backup Manager"
    $SA_rootPath = "$env:ALLUSERSPROFILE\MXB\Backup Manager"
    $MOB_path = $MOB_rootPath + "\StatusReport.xml"
    $SA_path = $SA_rootPath + "\StatusReport.xml"
    
    #$MOB_path = "$env:ALLUSERSPROFILE\Managed Online Backup\Backup Manager\StatusReport.xml"
    #$SA_path = "$env:ALLUSERSPROFILE\MXB\Backup Manager\StatusReport.xml"

    
    #Boolean file exists check
    $test_CLI = Test-Path "$CLI_path"
    $test_MOB = Test-Path "$MOB_rootPath\StatusReport.xml"
    $test_SA = Test-Path "$SA_rootPath\StatusReport.xml"
    
    #If both paths exist, use the most recent
    #Use path information to assign MOB type
    If ($test_MOB -eq $True -And $test_SA -eq $True) {
    	$lm_MOB = [datetime](Get-ItemProperty -Path $MOB_path -Name LastWriteTime).lastwritetime
    	$lm_SA =  [datetime](Get-ItemProperty -Path $SA_path -Name LastWriteTime).lastwritetime
    	If ((Get-Date $lm_MOB) -gt (Get-Date $lm_SA)) {
    		$MSPB_truePath = $MOB_path
            $MSPB_logPath = "$MOB_rootPath\logs\BackupFP"
    	} 
        Else {
    		$MSPB_truePath = $SA_path
            $MSPB_logPath = "$SA_rootPath\logs\BackupFP"
    	}
    } 
    Elseif ($test_SA -eq $True) {
    	$MSPB_truePath = $SA_path
        $MSPB_logPath = "$SA_rootPath\logs\BackupFP"

    } 
    Elseif ($test_MOB -eq $True) {
    	$MSPB_truePath = $MOB_path
        $MSPB_logPath = "$MOB_rootPath\logs\BackupFP"
    }
    
	#get Data for LSV synchronization
    [xml]$StatusReport = Get-Content $MSPB_truePath
    CheckLSVsync -StatusReport $StatusReport
    CheckLSVselfHealingStatus -StatusReport $StatusReport
    #get LSV Location from ClientTool
    $test = & cmd.exe /c `"$CLI_path`" control.setting.list
    $test = [String]$test
    $items = Split-StringOnLiteralString $test "LocalSpeedVaultLocation "
    $items = Split-StringOnLiteralString $items[1] "LocalSpeedVaultPassword "
    $LSVLocation = $items[0]

    if ($LSV_SelfHealingCountdownTrigger -eq $True){
        $LSV_SelfHealingCountdownTrigger = "True"
    }
    Else{
        $LSV_SelfHealingCountdownTrigger = "not triggered"
    }   
        
    #return metric data to policy/service
    $o_statusLegend = $serviceStatusLegend
    $o_LSVSyncMessage = $LSVSyncMessage
    $o_LSVSyncStatus = $LSVSyncStatus
    $o_LSVselfHealingTrigger = $LSV_SelfHealingCountdownTrigger
    $o_LSVdaysSinceSelfHealingTrigger = $LocalSpeedVaultDaysSinceSelfHealingTrigger
    $o_LSVLocation = $LSVLocation

    Write-Debug "LSV_SyncMessage: $o_LSVSyncMessage"
    Write-Debug "LSV_SyncStatus : $o_LSVSyncStatus"
    Write-Debug "LSV_SelfHealingTrigger : $o_LSVselfHealingTrigger"
    Write-Debug "LSV_daysSinceSelfHealingTrigger : $o_LSVdaysSinceSelfHealingTrigger"
    Write-Debug "LSV_Location: $o_LSVLocation"
}
Catch{
    $runTimeException = 1
    Write-Host "EXCEPTION - script halting"
}
Finally{
    Write-Host "End Check"
}
