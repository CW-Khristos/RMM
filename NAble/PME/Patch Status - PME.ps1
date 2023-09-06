<#*****************************************************************************************************
    
    Name: Get-PMEServices-AMP.ps1
    Version: 0.2.2.9 (15/11/2021)
    Author: Prejay Shah (Doherty Associates)
    Thanks To: Ashley How
    Purpose:    Get/Reset PME Service Details
    Pre-Reqs:    PowerShell 2.0 (PowerShell 4.0+ for Connectivity Tests)
    Version History:    0.1.0.0 - Initial Release.
                                + Improved Detection for PME Services being missing on a device
                                + Improved Detection of Latest PME Version
                                + Improved Detection and error handling for latest Public PME Version when PME 1.1 is installed or PME is not installed on a device
                                + Improved Compatibility of PME Version Check
                                + Updated to include better PME 1.2.x Latest Versioncheck
                                + Updated for better PS 2.0 Compatibility
                        0.1.5.0 + Added PME Profile Detection, and Diagnostics information courtesy of Ashley How's Repair-PME
                        0.1.5.0a + N-Central AMP Variant using AMP Input Parameter to control Forcing of Diagnostics Mode (Disabled by Default)	
                        0.1.5.1 + Improved TLS Support, Updated Error Message for PME connectivity Test not working on Windows 7
                        0.1.5.2 + PME 1.2.4 has been made GA for the default stream so have had to alter detection methods
                        0.1.5.3 + Improved Compatibility with Server 2008 R2
                        0.1.5.4 + Updated 'Test-PMEConnectivity' function to fix a message typo. Thanks for Clint Conner for finding. 
                        0.1.6.0 + Have Added in PME Installer Log Analysis for use when PME is not up to date
                        0.1.6.1 + Have added date analysis of log file/detection/installation proceedings
                        0.1.6.2 + Fixed Detection Logic for when there has been no PME Scan on a device, and missing components
                        0.1.6.3 + Added Reading in of PME Config for Cache settings
                        0.1.6.4 + Added in better x86/x64 compatability because apparently there are still 32-bit OS devices out there.
                        0.1.6.5 + Fixed Typo
                        0.1.6.6 + [Ashley How] migrated code from my Repair-PME script giving it the abilty to no longer consider a pending update of PME a failure.
                                  Please Note: By default the grace period has been set at 2 days but can be changed by changing the $PendingUpdateDays in settings section.
                                + Various updates to functions and parts of the script to be closer in-line with Repair-PME script.
                                + Updated Validate-PME function to account for pending update, this will report a status of 0. Renamed status messages to make it eaiser to theshold in an AMP service.
                                + Fixed minor issues with date-time parsing, valid PS/OS detection, URL Querying 
                        0.1.6.7 + Added Offine Scanning Detection
                        0.1.6.8 + Updated Cache Size variable extraction from XML Config File (Thanks to Clayton Murphy for identifying this)
                        0.1.6.9 + Upated Cache Fallback detection from XML file as I found that some devices semeed to have corrupted XML config files.
                        0.1.6.10 + Updated Profile Options to Default/Insiders as it seems that SW have retired the alpha moniker.
                        0.1.6.11 + Improved Logging method for when PME installation Details cannot be found.
                        0.1.6.12 + Updated PME OS Requirement Checks to cater for older OS not being supported                       
                        0.1.7.0 + [Ashley How] Updated Get-PMESetupDetails function to be in line with latest Repair-PME script.
                                + [Ashley How] Removed Get-PMEConfigurationDetails function, code merged into Get-PMESetupDetails function.   
                                + [Ashley How] Updated Confirm-PMEInstalled function to be in line with latest Repair-PME script.
                                + [Ashley How] Updated Confirm-PMEUpdatePending function to be in line with latest Repair-PME script.
                                + [Ashley How] Updated Get-PMEConfigMisconfigurations function to be in line with latest Repair-PME script.
                                + [Ashley How] Fixed issue in Get-PMEAnalysis function where match comparision operators would not return $true or $false against the $PMEQueryLogContent variable.
                                + [Ashley How] Fixed some minor spacing issues in output. Updated script title formatting so it is more prominent. 
                                + [Ashley How] Changed date formating to dd/MM/yyyy for $Version variable and release notes.
                                + [Ashley How] Updated Get-PMEProfile function for more consistent formatting. Offline scanning enablement will no longer report if PME is not installed.         
                        0.1.7.1 + Updated PME Insider version detection string, Have changed 64bit OS detection method       
                        0.2.0.0 + Updated for Unexpected PME 2.0 release; Cleaned up registry application detection method
                        0.2.0.1 + Slight Tweaks for PMe 1.3.1 Compatibility
                        0.2.0.2 + Tweak Expectation for Insider Profile as versions no longer match up
                        0.2.0.3 + Tweak Cache XML Config parsing for PMe 2.0
                        0.2.1.0 + Modified Status Message Output to include timestamps
                        0.2.1.1 + Updated Placeholder for PME 2.0.1 
                        0.2.2.0 + Using Community XML as data source for PME Information instead of placeholder while we wait to see if anything can be done with official SW sources
                        0.2.2.1 + Cleanup Formatting and Typo's
                        0.2.2.2 + Update for compatibility with version expectation when using legacy PME
                        0.2.2.3 + Update OS Compatibility Output, Status/Version Output
                        0.2.2.4 + Changed Legacy PME Detection Method
                        0.2.2.5 + Converted from Throw to write-output for AMP compatibility, Hardcoded Legacy PME Release Date for devices that cannot access the website
                        0.2.2.6 + Updating 32-bit OS compatibility with Legacy and 2.x PME
                        0.2.2.7 + Updated for PME 2.1 Testing and minor information output improvements. Pending Update Fix courtesy of Ashley How
                        0.2.2.8 + Updated Parameter comment to help those who try to throw this script directly into AM's "Run Powershell Script" object
                        0.2.2.9 + Updated for better Windows 11 Detection/compatibility


    Examples: 
    Diagnostics Input: False
    Runs Normally and only engages diagnostcs for connectibity testing if PME is not up to date or missing a service.
    
    Diagnostics Input: True
    Force Diagnostics Mode to be enabled on the run regardless of PME Status
    *****************************************************************************************************#>

<#
Param (
        [Parameter(Mandatory=$false,Position=1)]
        [switch] $Diagnostics
    )
#>
# Settings
# *****************************************************************************************************
# Change this variable to number of days (must be a number!) to consider a new version of PME as pending an update. Default is 2.
$PendingUpdateDays = "2"
# *****************************************************************************************************

#ddMMyy
$Version = '0.2.2.9 (15/11/2021)'
$EventLogCompanyName ="Doherty Associates"
$winbuild = $null
$osvalue = $null
$osbuildversion = $null
$RecheckStartup = $Null
$RecheckStatus = $Null
$request = $null
$Latestversion = $Null
$pmeprofile = $null
$diagnosticserrorint = $null
$pmeinstalllogcontent = $null
$PMEExpectationSetting = $False

$legacyPMEReleaseDate = "2021.01.27"
$legacyPME = $null

# $NAblePMESetup_detailsURIHTTPS = 'https://api.us-west-2.prd.patch.system-monitor.com/api/v1/pme/version/default'
# N-Able URL doens't include individual component versions or release data so we use own own URL instead

$CommunityPMESetup_detailsURIHTTP = "http://raw.githubusercontent.com/N-able/CustomMonitoring/master/N-Central%20PME%20Services/Community_PMESetup_details.xml"
$CommunityPMESetup_detailsURIHTTPS = "https://raw.githubusercontent.com/N-able/CustomMonitoring/master/N-Central%20PME%20Services/Community_PMESetup_details.xml"
$LegacyPMESetup_detailsURIHTTPS = "https://sis.n-able.com/Components/MSP-PME/latest/PMESetup_details.xml"
$LegacyPMESetup_detailsURIHTTP = "http://sis.n-able.com/Components/MSP-PME/latest/PMESetup_details.xml"

write-output ""
write-output "Get-PMEServices $Version"
write-output ""

if ($Diagnostics -eq 'True'){
    write-output "Diagnostics Mode Enabled"
}

#region Functions

Function Test-PMERequirement {
$winbuild = (Get-WmiObject -class Win32_OperatingSystem).Version
# [string]$WinBuild=[System.Environment]::OSVersion.Version
$UBR = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name UBR).UBR
$OSBuildVersion = $winbuild + "." + $UBR 
write-output "Windows Build Version: " -nonewline; write-output "$osbuildversion"

$OSName = (Get-WmiObject Win32_OperatingSystem).Caption
write-output "OS: " -nonewline; write-output "$OSName"
    if (($osname -match "XP") -or ($osname -match "Vista")  -or ($osname -match "Home") -or ($osname -match "2003") -or (($osname -match "2008") -and ($osname -notmatch "2008 R2")) ) {
        
        $Continue = $False
        $PMECacheStatus = "N/A - N-Central PME does not support OS"
        $PMEAgentStatus = "N/A - N-Central PME does not support OS"
        $PMERpcServerStatus = "N/A - N-Central PME does not support OS"
        $PMECacheVersion = '0.0'
        $PMEAgentVersion = '0.0'
        $PMERpcServerVersion = '0.0'
        pmeprofile = 'Default'
        $diagnosticserrorint = '2'
        $OverallStatus = '2'
        $StatusMessage = "$(Get-Date) - Error: The OS running on this device ($OSName $osbuildversion) is not supported by N-Central PME."
        $installernotes = $StatusMessage

        write-output "$StatusMessage"

    }
    else {
        $statusmessage = "$(Get-Date) - Information: The OS running on this device ($OSName $osbuildversion) is supported by N-Central PME"
        $installernotes = $statusmessage
        write-output "$statusmessage"
        write-output ""
        $Continue = $True

        # See: https://chocolatey.org/docs/installation#completely-offline-install
         # Attempt to set highest encryption available for SecurityProtocol.
        # PowerShell will not set this by default (until maybe .NET 4.6.x). This
        # will typically produce a message for PowerShell v2 (just an info message though)
        try {
            # Set TLS 1.2 (3072), then TLS 1.1 (768), then TLS 1.0 (192), finally SSL 3.0 (48)
            # Use integers because the enumeration values for TLS 1.2 and TLS 1.1 won't
            # exist in .NET 4.0, even though they are addressable if .NET 4.5+ is
            # installed (.NET 4.5 is an in-place upgrade).
            [System.Net.ServicePointManager]::SecurityProtocol = 3072 -bor 768 -bor 192 -bor 48

            #Hardcoding usage of TLS 1.2
            #[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        } 
        catch {
            write-output 'Unable to set PowerShell to use TLS 1.2 and TLS 1.1 due to old .NET Framework installed. If you see underlying connection closed or trust errors, you may need to upgrade to .NET Framework 4.5+ and PowerShell v3+.'
        }

        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

        }  
}  

Function Set-PMEExpectations {

#$OSArch = (Get-WmiObject Win32_OperatingSystem).OSArchitecture
$64bitOS = [System.Environment]::Is64BitOperatingSystem
if ($64bitOS -eq $true) {
    write-output "64-Bit OS Detected"
    $OSArch = "64-bit"
    $UninstallRegLocation = "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
}
else {
    write-output "32-Bit OS Detected"
    $OSArch = "32-Bit"
    $UninstallRegLocation = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
}


    if (test-path $env:programdata\MspPlatform\PME\log) {
        $MSPPlatformCoreLogSize = (get-item "$env:programdata\MspPlatform\PME\log\core.log").length
        }
        
        if ($MSPPlatformCoreLogSize -gt '0') {
        $legacyPME = $false
        # N-Able have pre-announced PME via https://status.n-able.com/release-notes/ although there is no direct category for it
        write-output "Warning: PME 2.x Detected - Artificially setting version and release date expectation via Community XML"
        #$PMEExpectationSetting = $True

        #write-output "PME Latest Version: $PME20LatestVersionPlaceholder"
        #write-output "PME Release Date: $PME20ReleaseDatePlaceholder"

        $PMEProgramDataFolder = "$env:programdata\MspPlatform\PME"
        If ($64bitOS -eq $true) {
        $PMEProgramFilesFolder = "${Env:ProgramFiles(x86)}\MspPlatform"
        }
        else {
            $PMEProgramFilesFolder = "$Env:ProgramFiles\MspPlatform"
        }
        $PMEAgentExe = "PME\PME.Agent.exe"  
        $PMECacheExe = "FileCacheServiceAgent\FileCacheServiceAgent.exe"
        $PMERPCExe = "RequestHandlerAgent\RequestHandlerAgent.exe"
        $PMEAgentServiceName = "PME.Agent.PmeService"
        $PMECacheServiceName = "SolarWinds.MSP.CacheService"
        $PMERPCServiceName = "SolarWinds.MSP.RpcServerService"

        $PMEAgentAppName =  "Patch Management Service Controller"
        $PMECacheAppName = "File Cache Service Agent"
        $PMERPCAppName = "Request Handler Agent"

        $CacheServiceConfigFile = "$env:programdata\MspPlatform\Filecacheserviceagent\config\FileCacheServiceAgent.xml"
        $PMESetup_detailsURI = $CommunityPMESetup_detailsURIHTTPS
        
    }
    else {
        $legacyPME = $true
        $PMEProgramDataFolder = "$env:programdata\SolarWinds MSP\PME"
        If ($64bitOS -eq $true) {
        $PMEProgramFilesFolder = "${Env:ProgramFiles(x86)}\SolarWinds MSP"
        }
        else {
            $PMEProgramFilesFolder = "$Env:ProgramFiles\SolarWinds MSP"            
        }
        $PMEAgentExe = "PME\SolarWinds.MSP.PME.Agent.exe"
        $PMECacheExe = "CacheService\SolarWinds.MSP.CacheService.exe"
        $PMERPCExe = "RpcServer\SolarWinds.MSP.RpcServerService.exe"
        
        $PMEAgentServiceName = "SolarWinds.MSP.PME.Agent.PmeService"
        $PMECacheServiceName = "SolarWinds.MSP.CacheService"
        $PMERPCServiceName = "SolarWinds.MSP.RpcServerService"

        $PMEAgentAppName = "SolarWinds MSP Patch Management Engine"
        $PMECacheAppName = "SolarWinds MSP Cache Service"
        $PMERPCAppName = "Solarwinds MSP RPC Server"

        $CacheServiceConfigFile = "$env:programdata\SolarWinds MSP\PME\SolarWinds.MSP.CacheService\config\CacheService.xml"
        $PMESetup_detailsURI = $LegacyPMESetup_detailsURIHTTPS
    }


    
        If ($64bitOS -eq $true) {
            $SolarWindsMSPCacheLocation = "$PMEProgramFilesFolder\$PMECacheExe"
            $SolarWindsMSPPMEAgentLocation = "$PMEProgramFilesFolder\$PMEAgentExe"
            $SolarWindsMSPRpcServerLocation = "$PMEProgramFilesFolder\$PMERPCExe"
            $NCentralLog = "c:\Program Files (x86)\N-able Technologies\Windows Agent\log"
        }
        else {
            $SolarWindsMSPCacheLocation = "$PMEProgramFilesFolder\$PMECacheExe"
            $SolarWindsMSPPMEAgentLocation = "$PMEProgramFilesFolder\$PMEAgentExe"
            $SolarWindsMSPRpcServerLocation = "$PMEProgramFilesFolder\$PMERPCExe"
            $NCentralLog = "c:\Program Files\N-able Technologies\Windows Agent\log"
        }
}

Function Get-PMEServicesStatus {
$PMEAgentStatus = (get-service $PMEAgentServiceName -ErrorAction SilentlyContinue).Status
$PMECacheStatus = (get-service $PMECacheServiceName -ErrorAction SilentlyContinue).Status
$PMERpcServerStatus = (get-service $PMERPCServiceName -ErrorAction SilentlyContinue).status
}

Function Get-PMESetupDetails {
    <#
    if ($PMEExpectationSetting -eq $true) {
        $LatestVersion = $PME20LatestVersionPlaceholder
        $PMEReleaseDate = $PME20ReleaseDatePlaceholder
    }
    else {
    #>
    # Determine URI used for PMESetup_details.xml
        If ($Fallback -eq "Yes") {
            if ($legacyPME -eq $true) {
                $PMESetup_detailsURI = $LegacyPMESetup_detailsURIHTTP          
            }
            else {
                $PMESetup_detailsURI = $CommunityPMESetup_detailsURIHTTP
            }
        } Else {
            if ($legacyPME -eq $true) {
                $PMESetup_detailsURI = $LegacyPMESetup_detailsURIHTTPS
            }
            else {
                $PMESetup_detailsURI = $CommunityPMESetup_detailsURIHTTPS
            }
        }

        Try {
            $PMEDetails = $null
            $request = $null
            [xml]$request = ((New-Object System.Net.WebClient).DownloadString("$PMESetup_detailsURI") -split '<\?xml.*\?>')[-1]
            $PMEDetails = $request.ComponentDetails
            $LatestVersion = $request.ComponentDetails.Version
            if ($legacyPME -eq $false) {
                $PMEReleaseDate = $request.ComponentDetails.ReleaseDate
                if ($? -eq $true) {
                    write-output "Success reading from Community XML!"
                }
                write-output "Setting PME Component Version Expectation to individual PME Component Versions:"
                $LatestPMEAgentVersion = $request.ComponentDetails.PatchManagementServiceControllerVersion
                $LatestCacheServiceVersion = $request.ComponentDetails.FileCacheServiceAgentVersion
                $LatestRPCServerVersion = $request.ComponentDetails.RequestHandlerAgentVersion
            }

        } Catch [System.Net.WebException] {
            $overallstatus = '2'
            $diagnosticserrorint = '2'
            $message = "$(Get-Date) ERROR: Error fetching PMESetup_Details.xml, check the source URL $($PMESetup_detailsURI), aborting. Error: $($_.Exception.Message)"
            write-output $message
            $diagnosticsinfo = $diagnosticsinfo + "<br>$message"
        } Catch [System.Management.Automation.MetadataException] {
            $overallstatus = '2'
            $diagnosticserrorint = '2'
            $message = "$(Get-Date) ERROR: Error casting to XML, could not parse PMESetup_details.xml, aborting. Error: $($_.Exception.Message)"
            write-output "$message"
            $diagnosticsinfo = $diagnosticsinfo + "<br>$message"
        } Catch {
            $overallstatus = '2'
            $diagnosticserrorint = '2'
            $message = "$(Get-Date) ERROR: Error occurred attempting to obtain PMESetup_details.xml, aborting. Error: $($_.Exception.Message)"
            $diagnosticsinfo = $diagnosticsinfo + "<br>$message"
        }

        if ($legacyPME -eq $true) {
            write-output "Setting PME Component Version Expectation to match overall PME Version"
            $LatestPMEAgentVersion = $request.ComponentDetails.Version
            $LatestCacheServiceVersion = $request.ComponentDetails.Version
            $LatestRPCServerVersion = $request.ComponentDetails.Version
        Try {
            $webRequest = $null; $webResponse = $null
            $webRequest = [System.Net.WebRequest]::Create($PMESetup_detailsURI)
            $webRequest.Method = "HEAD"
            $WebRequest.AllowAutoRedirect = $true
            $WebRequest.KeepAlive = $false
            $WebRequest.Timeout = 10000
            $webResponse = $webRequest.GetResponse()
            $remoteLastModified = ($webResponse.LastModified) -as [DateTime]
            $PMEReleaseDate = $remoteLastModified | Get-Date -Format "yyyy.MM.dd"
            $webResponse.Close()
        } Catch [System.Net.WebException] {
            $overallstatus = '2'
            $diagnosticserrorint = '2'
            write-output "Error fetching header for PMESetup_Details.xml, check the source URL $($PMESetup_detailsURI), aborting. Error: $($_.Exception.Message)"
        } Catch {
            $overallstatus = '2'
            $diagnosticserrorint = '2'
            write-output "Error fetching header for PMESetup_Details.xml, aborting. Error: $($_.Exception.Message)"
        }
    }
  
    write-output "Latest PME Version: " -nonewline; write-output "$latestversion"
    write-output "Latest PME Release Date: " -nonewline; write-output "$PMEReleaseDate"
    write-output "Latest PME Agent Version: " -nonewline; write-output "$latestPMEAgentversion"
    write-output "Latest Cache Service Version: " -nonewline; write-output "$LatestCacheServiceVersion"
    write-output "Latest RPC Server Version: " -nonewline; write-output "$latestrpcserverversion"
    write-output ""
}

Function Get-LatestPMEVersion {
    
    if ($legacyPME -eq $true) {
        if (!($pmeprofile -eq 'insiders')) {
            . Get-PMESetupDetails
            . Confirm-PMEInstalled
            . Confirm-PMEUpdatePending 
        }
        else {
                write-output "PME Insiders Stream Detected"
                #$PMEWrapper = get-content "${Env:ProgramFiles(x86)}\N-able Technologies\Windows Agent\log\PMEWrapper.log"
                #$Latest = "Pme.GetLatestVersion result = LatestVersion"
                #$LatestVersion = $LatestMatch.Split(' ')[9].TrimEnd(',')
                $PMECore = get-content "$PMEProgramDataFolder\log\Core.log"
                $Latest = "Latest PMESetup Version is"
                $LatestMatch = ($PMECore -match $latest)[-1]
                #$LatestVersion = $LatestMatch.Split(' ')[10].Trim()
                $LatestVersion = ($LatestMatch -Split(' '))[10]
            }
    }

    if ($legacyPME -eq $false) {
        . Get-PMESetupDetails
        . Confirm-PMEInstalled
        . Confirm-PMEUpdatePending 
    }

}

Function Restore-Date {
    If ($InstallDate.Length -le 7) {
        $MMdd = $InstallDate.Substring(4, 3)
        $Year = $InstallDate.Substring(0, 4)
        $InstallDate = $($Year + "0" + $MMdd)
    }
}
    
Function Confirm-PMEInstalled {

# Check if PME Agent is currently installed
    # write-output "Checking if PME Agent is already installed..."
    $PATHS = @($UninstallRegLocation)
    $SOFTWARE = $PMEAgentAppName
    ForEach ($path in $PATHS) {
        $installed = Get-ChildItem -Path $path |
        ForEach-Object { Get-ItemProperty $_.PSPath } |
        Where-Object { $_.DisplayName -match $SOFTWARE } |
        Select-Object -Property DisplayName, DisplayVersion, InstallDate

        If ($null -ne $installed) {
            ForEach ($app in $installed) {
                If ($($app.DisplayName) -eq $PMEAgentAppName) {
                    $PMEAgentAppDisplayVersion = $($app.DisplayVersion)
                    $InstallDate = $($app.InstallDate)
                    If ($null -ne $InstallDate -and $InstallDate -ne "") {
                        . Restore-Date
                        $ConvertDateTime = [DateTime]::ParseExact($InstallDate, "yyyyMMdd", $null)
                        $InstallDateFormatted = $ConvertDateTime | Get-Date -Format "yyyy.MM.dd"
                    }
                    $IsPMEAgentInstalled = "Yes"
                    write-output "PME Agent Already Installed: Yes"
                    # Write-Output "Installed PME Agent Version: $PMEAgentAppDisplayVersion"
                    # Write-Output "Installed PME Agent Date: $InstallDateFormatted"
                }
            }
        } Else {
            $IsPMEAgentInstalled = "No"
            write-output "PME Agent Already Installed: No"
        }
    }


# Check if PME RPC Service is currently installed

    # write-output "Checking if PME RPC Server Service is already installed..."
    $PATHS = @($UninstallRegLocation)
    $SOFTWARE = $PMERPCAppName
    ForEach ($path in $PATHS) {
        $installed = Get-ChildItem -Path $path |
        ForEach-Object { Get-ItemProperty $_.PSPath } |
        Where-Object { $_.DisplayName -match $SOFTWARE } |
        Select-Object -Property DisplayName, DisplayVersion, InstallDate

        If ($null -ne $installed) {
            ForEach ($app in $installed) {
                If ($($app.DisplayName) -eq $PMERPCAppName) {
                    $PMERPCServerAppDisplayVersion = $($app.DisplayVersion) 
                    $InstallDate = $($app.InstallDate)
                    If ($null -ne $InstallDate -and $InstallDate -ne "") {
                        . Restore-Date
                        $ConvertDateTime = [DateTime]::ParseExact($InstallDate, "yyyyMMdd", $null)
                        $InstallDateFormatted = $ConvertDateTime | Get-Date -Format "yyyy.MM.dd"
                    }
                    $IsPMERPCServerServiceInstalled = "Yes"
                    write-output "PME RPC Server Service Already Installed: Yes"
                    # Write-Output "Installed PME RPC Server Service Version: $PMERPCServerAppDisplayVersion"
                    # Write-Output "Installed PME RPC Server Service Date: $InstallDateFormatted"
                }
            }
        } Else {
            $IsPMERPCServerServiceInstalled = "No"
            write-output "PME RPC Server Service Already Installed: No"
        }
    }
    

# Check if PME Cache Service is currently installed
    # write-output "Checking if PME RPC Server Service is already installed..."
    $PATHS = @($UninstallRegLocation)
    $SOFTWARE = $PMECacheAppName
    ForEach ($path in $PATHS) {
        $installed = Get-ChildItem -Path $path |
        ForEach-Object { Get-ItemProperty $_.PSPath } |
        Where-Object { $_.DisplayName -match $SOFTWARE } |
        Select-Object -Property DisplayName, DisplayVersion, InstallDate

        If ($null -ne $installed) {
            ForEach ($app in $installed) {
                If ($($app.DisplayName) -eq $PMECacheAppName) {
                    $PMECacheServiceAppDisplayVersion = $($app.DisplayVersion) 
                    $InstallDate = $($app.InstallDate)
                    If ($null -ne $InstallDate -and $InstallDate -ne "") {
                        . Restore-Date
                        $ConvertDateTime = [DateTime]::ParseExact($InstallDate, "yyyyMMdd", $null)
                        $InstallDateFormatted = $ConvertDateTime | Get-Date -Format "yyyy.MM.dd"
                    }
                    $IsPMECacheServiceInstalled = "Yes"
                    write-output "PME Cache Service Already Installed: Yes"
                    # Write-Output "Installed PME Cache Service Version: $PMECacheServiceAppDisplayVersion"
                    # Write-Output "Installed PME Cache Service Date: $InstallDateFormatted"
                }
            }
        } Else {
            $IsPMECacheServiceInstalled = "No"
            write-output "PME Cache Service Already Installed: No"
        }
    }

}
         
Function Confirm-PMEUpdatePending {
    # Check if PME is awaiting update for new release but has not updated yet (normally within 48 hours)
    write-output ""
    If ($IsPMEAgentInstalled -eq "Yes") {
        $Date = Get-Date -Format 'yyyy.MM.dd'
        if ($PMEReleaseDate -ne $null) {
            $ConvertPMEReleaseDate = Get-Date "$PMEReleaseDate"
        } 
        if (($legacyPME -eq $true) -and ($PMEReleaseDate -eq $null)){
            $Message = "$(Get-Date) INFO: Script was unable to read PME Release Date from Webpage. Falling back to hardset release date in Script"
            write-output $Mssage
            $StatusMessage = $StatusMessage + "<br>$message"
            $diagnosticsinfo = $diagnosticsinfo + "<br>$message"
            $ConvertPMEReleaseDate = [datetime]$legacyPMEReleaseDate
        }
        $SelfHealingDate = $ConvertPMEReleaseDate.AddDays($PendingUpdateDays).ToString('yyyy.MM.dd')
        write-output "INFO: Script considers a PME update to be pending for ($PendingUpdateDays) days after a new version of PME has been released" -BackgroundColor Black
        $DaysElapsed = (New-TimeSpan -Start $SelfHealingDate -End $Date).Days
        $DaysElapsedReversed = (New-TimeSpan -Start $ConvertPMEReleaseDate -End $Date).Days

        # Only run if current $Date is greater than or equal to $SelfHealingDate and $LatestVersion is greater than $app.DisplayVersion
        If (($Date -ge $SelfHealingDate) -and ([version]$LatestVersion -ge [version]$PMEAgentAppDisplayVersion)) {
            $UpdatePending = "No"
            write-output "Update Pending: " -nonewline; write-output "No (Last Update was released [$DaysElapsed] days since the grace period)"    
        } Else {
            $UpdatePending = "Yes"
            write-output "Update Pending: " -nonewline; write-output "Yes (New Update has been released and [$DaysElapsedReversed] days has elapsed since the grace period)"
        }
    }
}

Function Get-PMEServiceVersions {

    $PMEAgentVersion = (get-item $SolarWindsMSPPMEAgentLocation -ErrorAction SilentlyContinue).VersionInfo.ProductVersion
    $PMECacheVersion = (get-item $SolarWindsMSPCacheLocation -ErrorAction SilentlyContinue).VersionInfo.ProductVersion
    $PMERpcServerVersion = (get-item $SolarWindsMSPRpcServerLocation -ErrorAction SilentlyContinue).VersionInfo.ProductVersion

    if ($PMEAgentStatus -eq $null) { 
        write-output "PME Agent service is missing"
        $PMEAgentStatus = 'Service is Missing'
        $PMEAgentVersion = '0.0'
    }

    if ($PMECacheStatus -eq $null) {
        write-output "PME Cache service is missing"
        $PMECacheStatus = 'Service is Missing'
        $PMECacheVersion = '0.0'
    }

    if ($PMERpcServerStatus -eq $null) {
        write-output "PME RPC Server service is missing"
        $PMERpcServerStatus = 'Service is Missing'
        $PMERpcServerVersion = '0.0'
    }

}

Function Get-PMEProfile {
    $PMEconfigXML = "$PMEProgramDataFolder\config\PmeConfig.xml"
if ($PMEAgentStatus -ne $null) {
    if (test-path $pmeconfigxml) {
    $xml = [xml](Get-Content "$PMEConfigXML")
    $pmeprofile = $xml.Configuration.Profile 
    $pmeofflinescan = $xml.Configuration.OfflineScan   
    }
    else {
        $pmeprofile = 'N/A'
        $pmeofflinescan = 'N/A'
    }
}
else {
    $pmeprofile = 'Error - Agent is running but config file could not be found'
}
write-output "PME Profile: " -nonewline; write-output "$pmeprofile"
write-output "PME Offline Scanning: " -nonewline; write-output "$pmeofflinescan"
    if ($pmeofflinescan -eq '1') {
        $pmeofflinescanbool = $True
        write-output "INFO: PME Offline Scanning is enabled" -BackgroundColor Black
    }
    elseif ($pmeofflinescan -eq "N/A")  {
    }
    else {
        $pmeofflinescanbool = $False
        write-output "INFO: PME Offline Scanning is not enabled" -BackgroundColor Black
    }
    write-output ""
}

Function Test-PMEConnectivity {
    $DiagnosticsError = $null
    $diagnosticsinfo = $null
    # Performs connectivity tests to destinations required for PME
    $OSVersion = (Get-WmiObject Win32_OperatingSystem).Caption
    If (($PSVersionTable.PSVersion -ge "4.0") -and (!($OSVersion -match 'Windows 7')) -and (!($OSVersion -match '2008 R2')) -and (!($OSVersion -match 'Small Business Server 2011 Standard'))) {
        write-output "Performing HTTPS connectivity tests for PME required destinations..."
        $List1= @("sis.n-able.com")
        $HTTPSError = @()
        $List1 | ForEach-Object {
            $Test1 = Test-NetConnection $_ -port 443
            If ($Test1.tcptestsucceeded -eq $True) {
                $Message = "OK: Connectivity to https://$_ ($(($Test1).RemoteAddress.IpAddressToString)) established"
                write-output "$Message"
                $HTTPSError += "No" 
                $diagnosticsinfo = $diagnosticsinfo + '<br>' + $Message
            }
            Else {
                $Message = "ERROR: Unable to establish connectivity to https://$_ ($(($Test1).RemoteAddress.IpAddressToString))"
                write-output "$Message"
                $StatusMessage = $StatusMessage + "<br>$Message"
                $HTTPSError += "Yes"
                $diagnosticsinfo = $diagnosticsinfo + '<br>' + $Message
            }
        }

        write-output "Performing HTTP connectivity tests for PME required destinations..."
        $HTTPError = @()
        $List2= @("sis.n-able.com","download.windowsupdate.com","fg.ds.b1.download.windowsupdate.com")
        $List2 | ForEach-Object {
            $Test1 = Test-NetConnection $_ -port 80
            If ($Test1.tcptestsucceeded -eq $True) {
                $Message = "OK: Connectivity to http://$_ ($(($Test1).RemoteAddress.IpAddressToString)) established"
                write-output "$Message"
                $HTTPError += "No"
                $diagnosticsinfo = $diagnosticsinfo + '<br>' + $Message 
            }
            Else {
                $message = "ERROR: Unable to establish connectivity to http://$_ ($(($Test1).RemoteAddress.IpAddressToString))"
                write-output $message
                $StatusMessage = $StatusMessage + "<br>$Message"
                $HTTPError += "Yes"
                $diagnosticsinfo = $diagnosticsinfo + '<br>' + $Message 
            }
        }

        If (($HTTPError[0] -like "*Yes*") -and ($HTTPSError[0] -like "*Yes*")) {
            $Message = "ERROR: No connectivity to $($List2[0]) can be established"
            Write-EventLog -LogName Application -Source "Get-PMEServices" -EntryType Information -EventID 100 -Message "$Message, aborting.<br>Script: Get-PMEServices.ps1"  
            $diagnosticsinfo = $diagnosticsinfo + '<br>' + $Message
            write-output "ERROR: No connectivity to $($List2[0]) can be established, aborting"
        }
        ElseIf (($HTTPError[0] -like "*Yes*") -or ($HTTPSError[0] -like "*Yes*")) {
            $Message = "WARNING: Partial connectivity to $($List2[0]) established, falling back to HTTP."
            Write-EventLog -LogName Application -Source "Get-PMEServices" -EntryType Information -EventID 100 -Message "$Message<br>Script: Get-PMEServices.ps1"  
            write-output "$Message"
            $Fallback = "Yes"
            $diagnosticsinfo = $diagnosticsinfo + '<br>' + $Message
        }

        If ($HTTPError[1] -like "*Yes*") {
            $Message = "WARNING: No connectivity to $($List2[1]) can be established"
            Write-EventLog -LogName Application -Source "Get-PMEServices" -EntryType Information -EventID 100 -Message "$Message, you will be unable to download Microsoft Updates!<br>Script: Get-PMEServices.ps1"  
            write-output "$Message, you will be unable to download Microsoft Updates!"
            $diagnosticsinfo = $diagnosticsinfo + '<br>' + $Message
        }

        If ($HTTPError[2] -like "*Yes*") {
            $Message = "WARNING: No connectivity to $($List2[2]) can be established"
            Write-EventLog -LogName Application -Source "Get-PMEServices" -EntryType Information -EventID 100 -Message "$Message, you will be unable to download Windows Feature Updates!<br>Script: Get-PMEServices.ps1"  
            write-output "$Message, you will be unable to download Windows Feature Updates!"  
            $diagnosticsinfo = $diagnosticsinfo + '<br>' + $Message
    }
}
    Else {
        $Message = "Windows: $OSVersion<br>Powershell: $($PSVersionTable.PSVersion)<br>Skipping connectivity tests for PME required destinations as OS is Windows 7/ Server 2008 (R2)/ SBS 2011 and/or Powershell 4.0 or above is not installed"
        write-output $Message
        $Fallback = "Yes" 
        $diagnosticsinfo = $diagnosticsinfo + '<br>' + $Message  
    }
    $DiagnosticsError = $HTTPSError + $HTTPError
    if ($diagnosticsError -contains 'Yes' ){
        $diagnosticserrorInt = '1'
    }
    else {
        $diagnosticserrorInt = '0'
    }
}

Function Write-Status {
write-output ""
write-output "SolarWinds MSP PME Agent Status: $PMEAgentStatus ($PMEAgentVersion)"
write-output "SolarWinds MSP Cache Service Status: $PMECacheStatus ($PMECacheVersion)"
write-output "SolarWinds MSP RPC Server Status: $PMERpcServerStatus ($PMERpcServerVersion)"
write-output ""
}

Function Start-Services {
    if (($PMEAgentStatus -eq 'Running') -and ($PMECacheStatus -eq 'Running') -and ($PMERpcServerStatus -eq 'Running')) {
            write-output "$(Get-Date) - OK - All PME Services are in a Running State"
    }
    else {
        $RecheckStatus = $True
        if ($PMEAgentStatus -ne 'Running') {
            write-output "Starting SolarWinds MSP PME Agent"
            New-EventLog -LogName Application -Source $EventLogCompanyName -erroraction silentlycontinue
            Write-EventLog -LogName Application -Source $EventLogCompanyName -EntryType Information -EventID 100 -Message "Starting SolarWinds MSP PME Agent...<br>Source: Get-PMEServices.ps1"
            start-service -Name "SolarWinds.MSP.PME.Agent.PmeService" 
        }

        if ($PMERpcServerStatus -ne 'Running') {
            write-output "Starting SolarWinds MSP RPC Server"
            New-EventLog -LogName Application -Source $EventLogCompanyName -erroraction silentlycontinue
            Write-EventLog -LogName Application -Source $EventLogCompanyName -EntryType Information -EventID 100 -Message "Starting SolarWinds MSP RPC Server Service...<br>Source: Get-PMEServices.ps1"
            start-service -Name "SolarWinds MSP RPC Server" 
        }

        if ($PMECacheStatus -ne 'Running') {
            write-output "Starting SolarWinds MSP Cache Service Service"
            New-EventLog -LogName Application -Source $EventLogCompanyName -erroraction silentlycontinue
            Write-EventLog -LogName Application -Source $EventLogCompanyName -EntryType Information -EventID 100 -Message "Starting SolarWinds MSP Cache Service...<br>Source: Get-PMEServices.ps1"
            start-service -Name "SolarWinds MSP Cache Service Service" 
        }
    }
}   

Function Set-AutomaticStartup {
    if (($SolarWinds.MSP.PME.Agent.PmeServiceStartup -eq 'Auto') -and ($SolarWinds.MSP.CacheServiceStartup -eq 'Auto') -and ($SolarWinds.MSP.RpcServerServiceStartup -eq 'Auto')) {
            write-output "$(Get-Date) - OK - All PME Services are set to Automatic Startup"
    }
    else {
        $RecheckStatus = $True
        if ($SolarWinds.MSP.PME.Agent.PmeServiceStartup -ne 'Auto') {
            write-output "Changing SolarWinds MSP PME Agent to Automatic"
            New-EventLog -LogName Application -Source $EventLogCompanyName -erroraction silentlycontinue
            Write-EventLog -LogName Application -Source $EventLogCompanyName -EntryType Information -EventID 102 -Message "Setting SolarWinds MSP PME Agent to Automatic...<br>Source: Get-PMEServices.ps1"
            set-service -Name "SolarWinds.MSP.PME.Agent.PmeService" -StartupType Automatic
        }

        if ($SolarWinds.MSP.RpcServerServiceStartup -ne 'Auto') {
            write-output "Changing SolarWinds MSP RPC Server to Automatic"
            New-EventLog -LogName Application -Source $EventLogCompanyName -erroraction silentlycontinue
            Write-EventLog -LogName Application -Source $EventLogCompanyName -EntryType Information -EventID 102 -Message "Setting SolarWinds MSP RPC Server Service to Automatic...<br>Source: Get-PMEServices.ps1"
            set-service -Name "SolarWinds MSP RPC Server" -StartupType Automatic
        }

        if ($SolarWinds.MSP.CacheServiceStartup -ne 'Auto') {
            write-output "Changing SolarWinds MSP Cache Service Service to Automatic"
            New-EventLog -LogName Application -Source $EventLogCompanyName -erroraction silentlycontinue
            Write-EventLog -LogName Application -Source $EventLogCompanyName -EntryType Information -EventID 102 -Message "Setting SolarWinds MSP Cache Service to Automatic...<br>Source: Get-PMEServices.ps1"
            set-service -Name "SolarWinds MSP Cache Service Service" -StartupType Automatic 
        }
    }
}   

Function Validate-PME {
write-output ""
If ([version]$PMEAgentVersion -ge [version]$latestpmeagentversion) {
    write-output "PME Agent Version: " -nonewline; write-output "Up To Date ($PMEAgentVersion)"
}
else {
    write-output "PME Agent Version: " -nonewline; write-output "Not Up To Date ($PMEAgentVersion)"
}

If ([version]$PMECacheVersion -ge [version]$LatestCacheServiceVersion) {
    write-output "PME Cache Service Version: " -nonewline; write-output "Up To Date ($PMECacheVersion)"
}
else {
    write-output "PME Cache Service Version: " -nonewline; write-output "Not Up To Date ($PMECacheVersion)"
}

If ([version]$PMERpcServerVersion -ge [version]$latestrpcserverversion) {
    write-output "PME RPC Server Version: " -nonewline; write-output "Up To Date ($PMERpcServerVersion)"
}
else {
    write-output "PME RPC Server Version: " -nonewline; write-output "Not Up To Date ($PMERpcServerVersion)"
}


if (($PMECacheVersion -eq '0.0') -or ($PMEAgentVersion -eq '0.0') -or ($PMERpcServerVersion -eq '0.0')) {
    $OverallStatus = 1
    $StatusMessage = "$(Get-Date) - WARNING: PME is missing one or more application installs"
    write-output ""
    write-output "$StatusMessage"
}

elseif (([version]$PMECacheVersion -ge [version]$latestcacheserviceversion) -and ([version]$PMEAgentVersion -ge [version]$latestpmeagentversion) -and ([version]$PMERpcServerVersion -ge [version]$latestrpcserverversion)) {
    $OverallStatus = 0  
    $StatusMessage = "$(Get-Date) - OK: All PME Services are running the latest version<br>" + $StatusMessage  
    write-output ""
    write-output "$StatusMessage"
}
elseif ($UpdatePending -eq "Yes") {
    $OverallStatus = 0  
    $StatusMessage = "$(Get-Date) - OK: All PME Services are awaiting an update to the latest version<br>" + $StatusMessage 
    write-output ""  
    write-output "$StatusMessage"    
}
else {
    $OverallStatus = 2
    $StatusMessage = "$(Get-Date) - WARNING: One or more PME Services are not running the latest version<br>" + $StatusMessage 
    write-output ""
    write-output "$StatusMessage"
    write-output ""
}
if ($OverallStatus -eq "0") {
    write-output "PME Status: " -nonewline; write-output "$OverallStatus"
}
else {
    write-output "PME Status: " -nonewline; write-output "$OverallStatus"
}
write-output ""
}

Function Get-PMEAnalysis {
if (test-path "$NCentralLog\PME_Install_*.log") {
    $pmeinstalllog = ((get-childitem "$NCentralLog\PME_Install_*.log" | where-object {$_.name -like "*[0-9].log"})[-1]).VersionInfo.FileName
    [datetime]$pmeinstalllogdate = (Get-Content -Path $pmeinstalllog | Select-Object -First 1).substring(0,10)

    #$pmeinstalllogcontent = get-content $pmeinstalllog

    if ($pmeinstalllogdate -ne $null) {
        $dateexecute = get-date
        $installtimedifference = ($dateexecute - $pmeinstalllogdate).Days
        $PMEInstallTimeData = "The last PME install was carried out during a detection $installtimedifference Days ago."
    }
    else {
        $PMEInstallTimeData = "Error: The last PME install date was not found in the PME install log."
    }

    $PMEQueryLogContent = get-content "$PMEProgramDataFolder\log\QueryManager.log"
    $PMEScanDateFound = $PMEQueryLogContent -contains '===============================>>>>> Start scan <<<<<========================================'
    if (($PMEQueryLogContent -eq $null) -or ($PMESCanDateFound -eq $false)) {
        write-output "No PME Scan data was found"
        $lastdetectionlogdate = $null
        $PMELastScanData = "There has been no recent patch detection scan." 
    }
    else {
        write-output "PME Scan data was found"
    [datetime]$lastdetectionlogdate = (($PMEQueryLogContent -contains '===============================>>>>> Start scan <<<<<========================================')[-1]).Split(" ")[1]
    $detectiontimedifference = ($dateexecute - $lastdetectionlogdate).Days
    $PMELastScanData = "The last patch detection scan took place $detectiontimedifference Days ago"
    }

    if (($installtimedifference -gt $detectiontimedifference) -and ($PMEAgentVersion -ne $latestversion)) {
        $InstallProblem = "There was a problem with the automatic upgrade process. Recommend using Repair-PME to force upgrade of PME Agent"
    }
    else {
        $installproblem = $null
    }

    $PMEAnalysisMessage = "Installed PME Version: $PMEAgentVersion<br>Latest PME Version: $latestversion<br>$PMEInstallTimeData<br>$PMELastScanData<br>$InstallProblem"
    write-output "$PMEAnalysisMessage"

    $PMEInstallerExefromLog = [Regex]::Matches(($pmeinstalllogcontent -match "Original Setup EXE"),'[A-Z]:\\(?:[^\\\/:*?"<>|\r\n]+\\)*[^\\\/:*?"<>|\r\n]*$').value
    $startinglinecontent = "Installing SolarWinds.MSP.PME.Agent.exe windows service"
    
    $TotalLinesInFile = ($pmeinstalllogcontent | Measure-Object).count
    $startingLineNumber = ($pmeinstalllogcontent | select-string -pattern $startinglinecontent | select-object -expandproperty 'LineNumber') -2
    if ($startinglinenumber -ne '-2'){ 
        $relevantlines = $TotalLinesInFile - $startinglinenumber
        $UpgradeError = get-content $pmeinstalllog -last $relevantlines
        write-output ""
        write-output "Installer EXE: " -nonewline; write-output "$PMEInstallerExefromLog"
        if ($pmeInstallerExefromLog -ne "$PMEProgramDataFolder\PME\Archives\PMESetup_$LatestVersion.exe") {
            write-output "Incorrect Setup EXE is being used"
        }
        else {
            write-output "Correct Setup EXE is being used"
        }
        write-output ""
        write-output "Last Upgrade Results: "
        get-content $pmeinstalllog -last $relevantlines
        }
        else {
            $pmeinstalllog = 'Error: There was no successful upgrades detected'
            write-output $pmeinstalllog        
        }
    }
    else {
        $pmeinstalllog = 'Error: There was no successful upgrades detected'
        write-output $pmeinstalllog    
    }
    
}
    
Function Get-PMEConfigMisconfigurations {
    # Check PME Config and inform of possible misconfigurations
    write-output "PME Config Details:"
     Try {

        If (Test-Path "$CacheServiceConfigFile") {
            $xml = New-Object XML
            $xml.Load($CacheServiceConfigFile)
            $CacheServiceConfig = $xml.Configuration

            If ($null -ne $CacheServiceConfig) {
                If ($CacheServiceConfig.CanBypassProxyCacheService -eq "False") {
                    $CacheConfigMessage = "$(Get-Date) - WARNING: Patch profile doesn't allow PME to fallback to external sources, if probe is not reachable PME may not work!"
                    Write-Warning "$CacheConfigMessage"
                } ElseIf ($CacheServiceConfig.CanBypassProxyCacheService -eq "True") {
                    $CacheConfigMessage = "$(Get-Date) - INFO: Patch profile allows PME to fallback to external sources"
                    write-output "$CacheConfigMessage" -BackgroundColor Black
                } Else {
                    $CacheConfigMessage = "$(Get-Date) - WARNING: Unable to determine if patch profile allows PME to fallback to external sources"
                    Write-Warning "$CacheConfigMessage"
                }


                If ($CacheServiceConfig.CacheSizeInMB -eq 10240) {
                    $CacheConfigSizeMessage = "$(Get-Date) - INFO: Cache Service is set to default cache size of 10240 MB"
                    write-output "$CacheConfigSizeMessage" -BackgroundColor Black
                } Else {
                    $CacheSize = $CacheServiceConfig.CacheSizeInMB
                    $CacheConfigSizeMessage = "$(Get-Date) - WARNING: Cache Service is not set to default cache size of 10240 MB (currently $CacheSize MB), PME may not work at expected!"
                    Write-Warning "$CacheConfigSizeMessage"
                }
            }   
        }
    }    
    Catch {
        $CacheConfigMessage = "$(Get-Date) - WARNING: Unable to read Cache Service config file as a valid xml file, default cache size can't be checked"
        Write-Warning "$CacheConfigMessage"
    }   

$StatusMessage = $StatusMessage + "<br>" + $CacheConfigMessage + "<br>" + $CacheConfigSizeMessage
write-output ""
}

#endregion

. Test-PMERequirement
. Set-PMEExpectations

if ($continue -eq $true) {
    . Get-PMEServicesStatus
    . Get-PMEServiceVersions
    . Get-PMEProfile
    . Get-LatestPMEVersion
    . Validate-PME
    . Get-PMEConfigMisconfigurations

    if ($RecheckStartup -eq $True) {
    . Get-PMEServicesStartup   
    . Write-Startup
    }

    if ($RecheckStatus -eq $True) {
    . Get-PMEServicesStatus   
    . Write-Status
    }

    if (($OverallStatus -ne '0') -or ($Diagnostics -eq 'True')) {
        write-output "Error Detected. Running diagnostics..."
    . Test-PMEConnectivity
    # write-output "$DiagnosticsInfo<br>"
    # write-output "$DiagnosticsError"
    write-output "Diagnostics Error: " -nonewline; write-output "$DiagnosticsErrorInt"
    }

    if ($OverallStatus -ne '0') {
        . Get-PMEAnalysis
    }
}

$SolarWindsMSPPMEAgentStatus = $PMEAgentStatus
$SolarWindsMSPCacheStatus = $PMECacheStatus
$SolarWindsMSPRpcServerStatus = $PMERPCServerStatus