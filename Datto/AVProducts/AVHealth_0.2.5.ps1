<#
.SYNOPSIS 
    AV Health Monitoring
    This was based on "Get Installed Antivirus Information" by SyncroMSP
    But omits the Hex Conversions and utilization of WSC_SECURITY_PROVIDER , WSC_SECURITY_PRODUCT_STATE , WSC_SECURITY_SIGNATURE_STATUS
    https://mspscripts.com/get-installed-antivirus-information-2/

.DESCRIPTION 
    Provide Primary AV Product Status and Report Possible AV Conflicts
    Script is intended to be universal / as flexible as possible without being excessively complicated
    Script is intended to replace 'AV Status' VBS Monitoring Script
 
.NOTES
    Version        : 0.2.5 (27 January 2023)
    Creation Date  : 14 December 2021
    Purpose/Change : Provide Primary AV Product Status and Report Possible AV Conflicts
    File Name      : AVHealth_0.2.5.ps1 
    Author         : Christopher Bledsoe - cbledsoe@ipmcomputers.com
    Thanks         : Chris Reid (NAble) for the original 'AV Status' Script and sanity checks
                     Prejay Shah (Doherty Associates) for sanity checks and a second pair of eyes
                     Eddie for their patience and helping test and validate and assistance with Trend Micro and Windows Defender
                     Remco for helping test and validate and assistance with Symantec
    Requires       : PowerShell Version 2.0+ installed

.CHANGELOG
    0.1.0 Initial Release
    0.1.1 Switched to use of '-match' and 'notmatch' for accepting input of vendor / general AV name like 'Sophos'
          Switched to use and expanded AV Product 'Definition' XMLs to be vendor specific instead of product specific
    0.1.2 Optimized to reduced use of 'If' blocks for querying registry values
          Added support for monitoring on Servers using 'HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\' since WMI SecurityCenter2 Namespace does not exist on Server OSes
          Note : Obtaining AV Products from 'HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\' only works *if* the AV Product registers itself in that key!
            If the above registry check fails to find any registered AV Products; script will attempt to fallback to WMI "root\cimv2" Namespace and "Win32_Product" Class -filter "Name like '$i_PAV'"
    0.1.3 Correcting some bugs and adding better error handling
    0.1.4 Enhanced error handling a bit more to include $_.scriptstacktrace
          Switched to reading AV Product 'Definition' XML data into hashtable format to allow flexible and efficient support of Servers; plan to utilize this method for all devices vs. direcly pulling XML data on each check
          Replaced fallback to WMI "root\cimv2" Namespace and "Win32_Product" Class; per MS documentation this process also starts a consistency check of packages installed, verifying, and repairing the install
          Attempted to utilize 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\' as well but this produced inconsistent results with installed software / nomenclature of installed software
          Instead; Script will retrieve the specified Vendor's AV Products 'Definition' XML and attempt to validate each AV Product via their respective Registry Keys similar to original 'AV Status' Script
            If the Script is able to validate an AV Product for the specified Vendor; it will then write the AV Product name to 'HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\' for easy retrieval on subsequent runs
          Per MS documentation; fallback to WMI "root\cimv2" Namespace and "Win32reg_AddRemovePrograms" Class may serve as suitable replacement
            https://docs.microsoft.com/en-US/troubleshoot/windows-server/admin-development/windows-installer-reconfigured-all-applications
    0.1.5 Couple bugfixes and fixing a few issues when attempting to monitor 'Windows Defender' as the 'Primary AV Product'
    0.1.6 Bugfixes for monitoring 'Windows Defender' and 'Symantec Anti-Virus' and 'Symantect Endpoint Protection' and multiple AVs on Servers.
            These 2 'Symantec' AV Products are actually the same product; this is simply to deal with differing names in Registry Keys that cannot be changed with Symantec installed
          Adding placeholders for Real-Time Status, Infection Status, and Threats. Added Epoch Timestamp conversion for future use.
    0.1.7 Bugfixes for monitoring 'Trend Micro' and 'Worry-Free Business Security' and multiple AVs on Servers.
            These 2 'Trend Micro' AV Products are actually the same product; this is simply to deal with differing names in Registry Keys that cannot be changed with Trend Micro installed
    0.1.8 Optimization and more bugfixes
          Switched to allow passing of '$i_PAV' via command line; this must be disabled in the AMP code to function properly with NCentral
          Corrected issue where 'Windows Defender' would be populated twice in Competitor AV; this was caused because WMI may report multiple instances of the same AV Product causing competitor check to do multiple runs
          Switched to using a hashtable for storing detected AV Products; this was to prevent duplicate entires for the same AV Product caused by WMI
          Moved code to retrieve Vendor AV Product XMLs to 'Get-AVXML' function to allow dynamic loading of Vendor XMLs and fallback to validating each AV Product from each supported Vendor
          Began expansion of metrics to include 'Detection Types' and 'Active Detections' based on Sophos' infection status and detected threats registry keys
          Cleaned up formatting for legibility for CLI and within NCentral
    0.1.9 Optimization and more bugfixes
          Working on finalizing looping routines to check for each AV Product for each Vendor both on Servers and Workstations; plan to move this to a function to avoid duplicate code
          Finalizing moving away from using WMI calls to check status and only using it to check for installed AV Products
          'AV Product Status', 'Real-Time Scanning', and 'Definition Status' will now report how script obtained information; either from WMI '(WMI Check)' or from Registry '(REG Check)'
          Workstations will still report the Real-Time Scanning and Definitions status via WMI; but plan to remove this output entirely
          Began adding in checks for AV Components' Versions, Tamper Protection, Last Software Update Timestamp, Last Definition Update Timestamp, and Last Scan Timestamp
          Added '$script:ncxml<vendor>' variables for assigning static 'fallback' sources for AV Product XMLs; XMLs should be uploaded to NC Script Repository and URLs updated (Begin Ln165)
            The above 'Fallback' method is to allow for uploading AV Product XML files to NCentral Script Repository to attempt to support older OSes which cannot securely connect to GitHub (Requires using "Compatibility" mode for NC Network Security)
    0.2.0 Optimization and more bugfixes
          Forked script to implement 'AV Health' script into Datto RMM
          Planning to re-organize repo to account for implementation of scripts to multiple RMM platforms
    0.2.1 Optimization and more bugfixes; namely putting an end to populating the key '#comment' into Vendor AV Product and Product State hashtables due to how PS parses XML natively
          Copied and modified code to retrieve Vendor AV Product XML into 'Get-AVState' function to replace the hard-coded 'swtich' to interpret WMI AV Product States
            This implements similar XML method to interpret WMI AV Product States as with retrieving Vendor AV Product details
            This should facilitate easier community contributions to WMI AV Product States and with this change plan to leave the WMI checks in place
    0.2.2 Implementing unique hashtable for 'Trend Micro' in 'Get-AVXML' function to test producing more varied data structures to account for differences between the various AV Products
            Planning to allow for creation of Vendor-specific hashtables being built; this also will allow for a greater flexibility in accounting for instances when 'LCD' type logic simply will not suffice
            Hoping this will not lead down the same rabbit hole as the 'AV Status' VBS script faced with a multitude of differing 'branches' of code which could end up in a 'dead-end'
          Switched to target '\SOFTWARE\TrendMicro\PC-cillinNTCorp\CurrentVersion\HostedAgent\RUpdate\UpgradeVersion' for dtermining if 'Trend Micro' AV Product is up-to-date
            This is mostly due to 'Trend Micro' 'ClientUpgradeStatus' values being deemed unreliable for accurately determining if the AV Product itself is up-to-date and thus the need to use an completely different method from other AV Products
          Added retrieval for 'Trend Micro' 'VCVersion' and proper comparison to determine if both Core AV and VC components are up-to-date with their respective expected versions                                                                                                                                                                       
.TODO
    Still need more AV Product registry samples for identifying keys to monitor for relevant data
    Need to obtain Infection Status and Detected Threats; bonus for timestamps for these metrics - Partially Complete (Sophos - full support; Trend Micro - 'Active Detections Present / Count')
        Do other AVs report individual Threat information in the registry? Sophos does; but if others don't will we be able to use this metric?
        Still need to determine if timestamps are possible for detected threats
    Need to create a 'Get-AVProducts' function and move looped 'detection' code into a function to call
    Trend Micro continues to cause issues with properly evaluating if the core AV Client itself is up to date due to the number of 'duplicate' and inconsistent Registry Keys / Values that clutter their Registry Hive
    
#> 

#REGION ----- DECLARATIONS ----
  #BELOW PARAM() MUST BE COMMENTED OUT FOR USE WITHIN DATTO RMM
  #UNCOMMENT BELOW PARAM() AND RENAME '$env:i_PAV' TO '$i_PAV' TO UTILIZE IN CLI
  #Param(
  #  [Parameter(Mandatory=$true)]$i_PAV
  #)
  #VERSION FOR SCRIPT UPDATE
  $strSCR           = "AVHealth"
  $strVER           = [version]"0.2.5"
  $strREPO          = "RMM"
  $strBRCH          = "dev"
  $strDIR           = "Datto"
  $script:diag = $null
  $script:bitarch = $null
  $script:OSCaption = $null
  $script:OSVersion = $null
  $script:producttype = $null
  $script:computername = $null
  $script:blnWMI = $true
  $script:blnPAV = $false
  $script:blnAVXML = $false
  $script:blnPSXML = $false
  $script:blnWARN = $false
  $script:avs = @{}
  $script:pskey = @{}
  $script:avwarn = @{}
  $script:pavkey = @{}
  $script:vavkey = @{}
  $script:compkey = @{}
  $script:o_AVname = "Selected AV Product Not Found"
  $script:o_AVVersion = "Selected AV Product Not Found"
  $script:o_AVpath = "Selected AV Product Not Found"
  $script:o_AVStatus = "Selected AV Product Not Found"
  $script:rtstatus = "Unknown"
  $script:o_RTstate = "Unknown"
  $script:defstatus = "Unknown"
  $script:o_DefStatus = "Unknown"
  $script:o_Infect = $null
  $script:o_Threats = $null
  $script:o_AVcon = 0
  $script:o_CompAV = $null
  $script:o_CompPath = $null
  $script:o_CompState = $null
  $logPath = "C:\IT\Log\AV_Health_$($strVER).log"
  #SUPPORTED AV VENDORS
  $script:avVendors = @(
    "Sophos"
    "Symantec"
    "Trend Micro"
    "Windows Defender"
  )
  #AV PRODUCTS USING '0' FOR 'UP-TO-DATE' PRODUCT STATUS
  $script:zUpgrade = @(
    "Sophos Intercept X"
    "Symantec Endpoint Protection"
    "Trend Micro Security Agent"
    "Worry-Free Business Security"
    "Windows Defender"
  )
  #AV PRODUCTS USING '0' FOR 'REAL-TIME SCANNING' STATUS
  $script:zRealTime = @(
    "Symantec Endpoint Protection"
    "Windows Defender"
  )
  #AV PRODUCTS USING '0' FOR 'TAMPER PROTECTION' STATUS
  $script:zTamper = @(
    "Sophos Anti-Virus"
    "Symantec Endpoint Protection"
    "Windows Defender"
  )
  #AV PRODUCTS NOT SUPPORTING ALERTS DETECTIONS
  $script:zNoAlert = @(
    "Symantec Endpoint Protection"
    "Windows Defender"
  )
  #AV PRODUCTS NOT SUPPORTING INFECTION DETECTIONS
  $script:zNoInfect = @(
    "Symantec Endpoint Protection"
    "Windows Defender"
  )
  #AV PRODUCTS NOT SUPPORTING THREAT DETECTIONS
  $script:zNoThreat = @(
    "Symantec Endpoint Protection"
    "Trend Micro Security Agent"
    "Worry-Free Business Security"
    "Windows Defender"
  )
  #AV PRODUCT XML NC REPOSITORY URLS FOR FALLBACK - CHANGE THESE TO MATCH YOUR NCENTRAL URLS AFTER UPLOADING EACH XML TO REPO
  $script:ncxmlSOPHOS = "https://nableserver/download/repository/1639682702/sophos.xml"
  $script:ncxmlSYMANTEC = "https://nableserver/download/repository/1238159723/symantec.xml"
  $script:ncxmlTRENDMICRO = "https://nableserver/download/repository/308457410/trendmicro.xml"
  $script:ncxmlWINDEFEND = "https://nableserver/download/repository/968395355/windowsdefender.xml"
  $script:ncxmlPRODUCTSTATE = "https://nableserver/download/repository/968395355/productstate.xml"
  #SET TLS SECURITY FOR CONNECTING TO GITHUB
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12
#ENDREGION ----- DECLARATIONS ----

#REGION ----- FUNCTIONS ----
  function write-DRMMDiag ($messages) {
    write-host "<-Start Diagnostic->"
    foreach ($message in $messages) {$message}
    write-host "<-End Diagnostic->"
  } ## write-DRMMDiag
  
  function write-DRMMAlert ($message) {
    write-host "<-Start Result->"
    write-host "Alert=$($message)"
    write-host "<-End Result->"
  } ## write-DRMMAlert

  function Get-EpochDate ($epochDate, $opt) {                                                       #Convert Epoch Date Timestamps to Local Time
    switch ($opt) {
      "sec" {[timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($epochDate))}
      "msec" {[timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddMilliSeconds($epochDate))}
    }
  } ## Get-EpochDate

  function Get-OSArch {                                                                             #Determine Bit Architecture & OS Type
    #OS Bit Architecture
    $osarch = (get-wmiobject win32_operatingsystem).osarchitecture
    if ($osarch -like '*64*') {
      $script:bitarch = "bit64"
    } elseif ($osarch -like '*32*') {
      $script:bitarch = "bit32"
    }
    #OS Type & Version
    $script:computername = $env:computername
    $script:OSCaption = (Get-WmiObject Win32_OperatingSystem).Caption
    $script:OSVersion = (Get-WmiObject Win32_OperatingSystem).Version
    $osproduct = (Get-WmiObject -class Win32_OperatingSystem).Producttype
    Switch ($osproduct) {
      "1" {$script:producttype = "Workstation"}
      "2" {$script:producttype = "DC"}
      "3" {$script:producttype = "Server"}
    }
  } ## Get-OSArch

  function Get-AVState {                                                                            #DETERMINE ANTIVIRUS STATE
    param (
      $dest, $state
    )
    #$dest = @{}
    $xmldiag = $null
    if (-not $script:blnPSXML) {                                                                    #AV PRODUCT STATES NOT LOADED INTO HASHTABLE
      $xmldiag += "Loading : AV Product State XML`r`n"
      write-host "Loading : AV Product State XML" -foregroundcolor yellow
      if (test-path "C:\IT\Scripts\productstate.xml") {
        try {
          $script:blnPSXML = $true
          $psXML = New-Object System.Xml.XmlDocument
          $psXML.Load("C:\IT\Scripts\productstate.xml")
        } catch {
          $script:blnPSXML = $false
          $xmldiag += "XML.Load() - Could not open C:\IT\Scripts\productstate.xml`r`n"
          write-host "XML.Load() - Could not open C:\IT\Scripts\productstate.xml" -foregroundcolor red
          write-host $_.Exception
          write-host $_.scriptstacktrace
          write-host $_
        }
      }
      if (-not $script:blnPSXML) {
        #RETRIEVE AV PRODUCT STATE XML FROM GITHUB
        $srcAVP = "https://raw.githubusercontent.com/CW-Khristos/scripts/dev/AVProducts/productstate.xml"
        try {
          $script:blnPSXML = $true
          $psXML = New-Object System.Xml.XmlDocument
          $psXML.Load($srcAVP)
        } catch {
          $xmldiag += "XML.Load() - Could not open $($srcAVP)`r`n"
          write-host "XML.Load() - Could not open $($srcAVP)" -foregroundcolor red
          write-host $_.Exception
          write-host $_.scriptstacktrace
          write-host $_
          try {
            $web = new-object system.net.webclient
            [xml]$psXML = $web.DownloadString($srcAVP)
          } catch {
            $xmldiag += "Web.DownloadString() - Could not download $($srcAVP)`r`n"
            write-host "Web.DownloadString() - Could not download $($srcAVP)" -foregroundcolor red
            write-host $_.Exception
            write-host $_.scriptstacktrace
            write-host $_
            try {
              start-bitstransfer -erroraction stop -source $srcAVP -destination "C:\IT\Scripts\productstate.xml"
              [xml]$psXML = "C:\IT\Scripts\productstate.xml"
            } catch {
              $script:blnPSXML = $false
              $xmldiag += "BITS.Transfer() - Could not download $($srcAVP)`r`n"
              write-host "BITS.Transfer() - Could not download $($srcAVP)" -foregroundcolor red
              write-host $_.Exception
              write-host $_.scriptstacktrace
              write-host $_
            }
          }
        }
        #NABLE FALLBACK IF GITHUB IS NOT ACCESSIBLE
        if (-not $script:blnPSXML) {
          $xmldiag += "`r`nFailed : AV Product State XML Retrieval from GitHub; Attempting download from NAble Server`r`n"
          $xmldiag += "Loading : AV Product State XML`r`n"
          write-host "Failed : AV Product State XML Retrieval from GitHub; Attempting download from NAble Server" -foregroundcolor yellow
          write-host "Loading : AV Product State XML" -foregroundcolor yellow
          $srcAVP = $script:ncxmlPRODUCTSTATE
          $script:diag += "$($xmldiag)"
          try {
            $script:blnPSXML = $true
            $psXML = New-Object System.Xml.XmlDocument
            $psXML.Load($srcAVP)
          } catch {
            $xmldiag += "XML.Load() - Could not open $($srcAVP)`r`n"
            write-host "XML.Load() - Could not open $($srcAVP)" -foregroundcolor red
            write-host $_.Exception
            write-host $_.scriptstacktrace
            write-host $_
            try {
              $web = new-object system.net.webclient
              [xml]$psXML = $web.DownloadString($srcAVP)
            } catch {
              $xmldiag += "Web.DownloadString() - Could not download $($srcAVP)`r`n"
              write-host "Web.DownloadString() - Could not download $($srcAVP)" -foregroundcolor red
              write-host $_.Exception
              write-host $_.scriptstacktrace
              write-host $_
              try {
                start-bitstransfer -erroraction stop -source $srcAVP -destination "C:\IT\Scripts\productstate.xml"
                [xml]$psXML = "C:\IT\Scripts\productstate.xml"
              } catch {
                $script:blnPSXML = $false
                $xmldiag += "BITS.Transfer() - Could not download $($srcAVP)`r`n"
                write-host "BITS.Transfer() - Could not download $($srcAVP)" -foregroundcolor red
                $script:defstatus = "Definition Status : Unknown (WMI Check)`r`nUnable to download AV Product State XML"
                $script:rtstatus = "Real-Time Scanning : Unknown (WMI Check)`r`nUnable to download AV Product State XML"
                write-host $_.Exception
                write-host $_.scriptstacktrace
                write-host $_
              }
            }
          }
        }
        #READ AV PRODUCT STATE XML DATA INTO NESTED HASHTABLE FOR LATER USE
        try {
          if ($script:blnPSXML) {
            foreach ($itm in $psXML.NODE.ChildNodes) {
              if ($itm.name -notmatch "#comment") {                                                   #AVOID 'BUG' WITH A KEY AS '#comment'
                $hash = @{
                  defstatus = "$($itm.defstatus)"
                  displayval = "$($itm.rtstatus)"
                }
                if ($dest.containskey($itm.name)) {
                  continue
                } elseif (-not $dest.containskey($itm.name)) {
                  $dest.add($itm.name, $hash)
                }
              }
            }
            #IF FIRST CALL OF 'Get-AVState', STILL NEED TO INTERPRET PASSED PRODUCT STATE
            #CALL 'Get-AVState' AGAIN NOW THAT THE HASHTABLE IS POPULATED
            Get-AVState $dest $state
          }
        } catch {
          $script:blnPSXML = $false
          write-host $_.Exception
          write-host $_.scriptstacktrace
          write-host $_
        }
      }
    } elseif ($script:blnPSXML) {                                                                   #AV PRODUCT STATES ALREADY LOADED IN HASHTABLE
      #SET '$script:defstatus' AND '$script:rtstatus' TO INTERPRET PASSED PRODUCT STATE FROM POPULATED HASHTABLE
      try {
        $script:defstatus = "$($script:pskey["ps$($state)"].defstatus)"
        $script:rtstatus = "$($script:pskey["ps$($state)"].rtstatus)"
      } catch {
        $script:defstatus = "Unknown (WMI Check)`r`nAV Product State Unknown : $($state)"
        $script:rtstatus = "Unknown (WMI Check)`r`nAV Product State Unknown : $($state)"
      }
    }
    $script:diag += "$($xmldiag)"
    $xmldiag = $null
  } ## Get-AVState
  
  function Get-AVXML {                                                                              #RETRIEVE AV VENDOR XML FROM GITHUB
    param (
      $src, $dest
    )
    #$dest = @{}
    $xmldiag = $null
    if (-not $script:blnAVXML) {
      $xmldiag += "Loading : '$($src)' AV Product XML`r`n"
      write-host "Loading : '$($src)' AV Product XML" -foregroundcolor yellow
      if (test-path "C:\IT\Scripts\" + $src.replace(" ", "").replace("-", "").tolower() + ".xml") {
        try {
          $script:blnAVXML = $true
          $avXML = New-Object System.Xml.XmlDocument
          $avXML.Load("C:\IT\Scripts\" + $src.replace(" ", "").replace("-", "").tolower() + ".xml")
        } catch {
          $script:blnAVXML = $false
          $xmldiag += "XML.Load() - Could not open C:\IT\Scripts\" + $src.replace(" ", "").replace("-", "").tolower() + ".xml`r`n"
          write-host "XML.Load() - Could not open C:\IT\Scripts\" + $src.replace(" ", "").replace("-", "").tolower() + ".xml" -foregroundcolor red
          write-host $_.Exception
          write-host $_.scriptstacktrace
          write-host $_
        }
      }
      if (-not $script:blnAVXML) {
        #RETRIEVE AV VENDOR XML FROM GITHUB
        $srcAVP = "https://raw.githubusercontent.com/CW-Khristos/scripts/master/AVProducts/" + $src.replace(" ", "").replace("-", "").tolower() + ".xml"
        $script:diag += "$($xmldiag)"
        try {
          $script:blnAVXML = $true
          $avXML = New-Object System.Xml.XmlDocument
          $avXML.Load($srcAVP)
        } catch {
          $xmldiag += "XML.Load() - Could not open $($srcAVP)`r`n"
          write-host "XML.Load() - Could not open $($srcAVP)" -foregroundcolor red
          $script:diag += "$($xmldiag)"
          write-host $_.Exception
          write-host $_.scriptstacktrace
          write-host $_
          try {
            $web = new-object system.net.webclient
            [xml]$avXML = $web.DownloadString($srcAVP)
          } catch {
            $xmldiag += "Web.DownloadString() - Could not download $($srcAVP)`r`n"
            write-host "Web.DownloadString() - Could not download $($srcAVP)" -foregroundcolor red
            $script:diag += "$($xmldiag)"
            write-host $_.Exception
            write-host $_.scriptstacktrace
            write-host $_
            try {
              start-bitstransfer -erroraction stop -source $srcAVP -destination "C:\IT\Scripts\" + $src.replace(" ", "").replace("-", "").tolower() + ".xml"
              [xml]$avXML = "C:\IT\Scripts\" + $src.replace(" ", "").replace("-", "").tolower() + ".xml"
            } catch {
              $script:blnAVXML = $false
              $xmldiag += "BITS.Transfer() - Could not download $($srcAVP)`r`n"
              write-host "BITS.Transfer() - Could not download $($srcAVP)" -foregroundcolor red
              $script:diag += "$($xmldiag)"
              write-host $_.Exception
              write-host $_.scriptstacktrace
              write-host $_
            }
          }
        }
        #NABLE FALLBACK IF GITHUB IS NOT ACCESSIBLE
        if (-not $script:blnAVXML) {
          $xmldiag += "`r`nFailed : AV Product XML Retrieval from GitHub; Attempting download from NAble Server`r`n"
          $xmldiag += "Loading : '$($src)' AV Product XML`r`n"
          write-host "Failed : AV Product XML Retrieval from GitHub; Attempting download from NAble Server" -foregroundcolor yellow
          write-host "Loading : '$($src)' AV Product XML" -foregroundcolor yellow
          switch ($src) {
            "Sophos" {$srcAVP = $script:ncxmlSOPHOS}
            "Symantec" {$srcAVP = $script:ncxmlSYMANTEC}
            "Trend Micro" {$srcAVP = $script:ncxmlTRENDMICRO}
            "Windows Defender" {$srcAVP = $script:ncxmlWINDEFEND}
          }
          try {
            $script:blnAVXML = $true
            $avXML = New-Object System.Xml.XmlDocument
            $avXML.Load($srcAVP)
          } catch {
            $xmldiag += "XML.Load() - Could not open $($srcAVP)`r`n"
            write-host "XML.Load() - Could not open $($srcAVP)" -foregroundcolor red
            $script:diag += "$($xmldiag)"
            write-host $_.Exception
            write-host $_.scriptstacktrace
            write-host $_
            try {
              $web = new-object system.net.webclient
              [xml]$avXML = $web.DownloadString($srcAVP)
            } catch {
              $xmldiag += "Web.DownloadString() - Could not download $($srcAVP)`r`n"
              write-host "Web.DownloadString() - Could not download $($srcAVP)" -foregroundcolor red
              $script:diag += "$($xmldiag)"
              write-host $_.Exception
              write-host $_.scriptstacktrace
              write-host $_
              try {
                start-bitstransfer -erroraction stop -source $srcAVP -destination "C:\IT\Scripts\" + $src.replace(" ", "").replace("-", "").tolower() + ".xml"
                [xml]$avXML = "C:\IT\Scripts\" + $src.replace(" ", "").replace("-", "").tolower() + ".xml"
              } catch {
                $xmldiag += "BITS.Transfer() - Could not download $($srcAVP)`r`n"
                write-host "BITS.Transfer() - Could not download $($srcAVP)" -foregroundcolor red
                write-host $_.Exception
                write-host $_.scriptstacktrace
                write-host $_
                #Stop script execution time calculation
                StopClock
                #DATTO OUTPUT
                $script:diag += "$($xmldiag)"
                write-DRMMAlert "Could not download AV Product XML"
                write-DRMMDiag "$($script:diag)"
                $script:blnAVXML = $false
                $xmldiag = $null
                exit 1
              }
            }
          }
        }
      }
    }
    #READ PRIMARY AV PRODUCT VENDOR XML DATA INTO NESTED HASHTABLE FOR LATER USE
    try {
      if ($script:blnAVXML) {
        foreach ($itm in $avXML.NODE.ChildNodes) {
          if ($itm.name -notmatch "#comment") {                                                     #AVOID 'BUG' WITH A KEY AS '#comment'
            if ($env:i_PAV -match "Sophos") {                                                       #BUILD HASHTABLE FOR SOPHOS
              $hash = @{
                display = "$($itm.$script:bitarch.display)"
                displayval = "$($itm.$script:bitarch.displayval)"
                path = "$($itm.$script:bitarch.path)"
                pathval = "$($itm.$script:bitarch.pathval)"
                ver = "$($itm.$script:bitarch.ver)"
                verval = "$($itm.$script:bitarch.verval)"
                compver = "$($itm.$script:bitarch.compver)"
                compverval = "$($itm.$script:bitarch.compverval)"
                stat = "$($itm.$script:bitarch.stat)"
                statval = "$($itm.$script:bitarch.statval)"
                update = "$($itm.$script:bitarch.update)"
                updateval = "$($itm.$script:bitarch.updateval)"
                source = "$($itm.$script:bitarch.source)"
                sourceval = "$($itm.$script:bitarch.sourceval)"
                defupdate = "$($itm.$script:bitarch.defupdate)"
                defupdateval = "$($itm.$script:bitarch.defupdateval)"
                tamper = "$($itm.$script:bitarch.tamper)"
                tamperval = "$($itm.$script:bitarch.tamperval)"
                rt = "$($itm.$script:bitarch.rt)"
                rtval = "$($itm.$script:bitarch.rtval)"
                reboot = "$($itm.$script:bitarch.reboot)"
                rebootval1 = "$($itm.$script:bitarch.rebootval1)"
                rebootval2 = "$($itm.$script:bitarch.rebootval2)"
                scan = "$($itm.$script:bitarch.scan)"
                scantype = "$($itm.$script:bitarch.scantype)"
                scanval = "$($itm.$script:bitarch.scanval)"
                alert = "$($itm.$script:bitarch.alert)"
                alertval = "$($itm.$script:bitarch.alertval)"
                infect = "$($itm.$script:bitarch.infect)"
                infectval = "$($itm.$script:bitarch.infectval)"
                threat = "$($itm.$script:bitarch.threat)"
              }
            } elseif ($env:i_PAV -notmatch "Trend Micro") {                                                   #BUILD HASHTABLE FOR ALL AV PRODUCTS EXCEPT TREND MICRO
              $hash = @{
                display = "$($itm.$script:bitarch.display)"
                displayval = "$($itm.$script:bitarch.displayval)"
                path = "$($itm.$script:bitarch.path)"
                pathval = "$($itm.$script:bitarch.pathval)"
                ver = "$($itm.$script:bitarch.ver)"
                verval = "$($itm.$script:bitarch.verval)"
                compver = "$($itm.$script:bitarch.compver)"
                stat = "$($itm.$script:bitarch.stat)"
                statval = "$($itm.$script:bitarch.statval)"
                update = "$($itm.$script:bitarch.update)"
                updateval = "$($itm.$script:bitarch.updateval)"
                source = "$($itm.$script:bitarch.source)"
                sourceval = "$($itm.$script:bitarch.sourceval)"
                defupdate = "$($itm.$script:bitarch.defupdate)"
                defupdateval = "$($itm.$script:bitarch.defupdateval)"
                tamper = "$($itm.$script:bitarch.tamper)"
                tamperval = "$($itm.$script:bitarch.tamperval)"
                rt = "$($itm.$script:bitarch.rt)"
                rtval = "$($itm.$script:bitarch.rtval)"
                scan = "$($itm.$script:bitarch.scan)"
                scantype = "$($itm.$script:bitarch.scantype)"
                scanval = "$($itm.$script:bitarch.scanval)"
                alert = "$($itm.$script:bitarch.alert)"
                alertval = "$($itm.$script:bitarch.alertval)"
                infect = "$($itm.$script:bitarch.infect)"
                infectval = "$($itm.$script:bitarch.infectval)"
                threat = "$($itm.$script:bitarch.threat)"
              }
            } elseif ($env:i_PAV -match "Trend Micro") {                                                #BUILD HASHTABLE FOR CURSED TREND MICRO
              $hash = @{
                display = "$($itm.$script:bitarch.display)"
                displayval = "$($itm.$script:bitarch.displayval)"
                path = "$($itm.$script:bitarch.path)"
                pathval = "$($itm.$script:bitarch.pathval)"
                corever = "$($itm.$script:bitarch.corever)"
                coreverval = "$($itm.$script:bitarch.coreverval)"
                vcver = "$($itm.$script:bitarch.vcver)"
                vcverval = "$($itm.$script:bitarch.vcverval)"
                compver = "$($itm.$script:bitarch.compver)"
                compverval = "$($itm.$script:bitarch.compverval)"
                stat = "$($itm.$script:bitarch.stat)"
                statval = "$($itm.$script:bitarch.statval)"
                update = "$($itm.$script:bitarch.update)"
                updateval = "$($itm.$script:bitarch.updateval)"
                source = "$($itm.$script:bitarch.source)"
                sourceval = "$($itm.$script:bitarch.sourceval)"
                defupdate = "$($itm.$script:bitarch.defupdate)"
                defupdateval = "$($itm.$script:bitarch.defupdateval)"
                tamper = "$($itm.$script:bitarch.tamper)"
                tamperval = "$($itm.$script:bitarch.tamperval)"
                rt = "$($itm.$script:bitarch.rt)"
                rtval = "$($itm.$script:bitarch.rtval)"
                scan = "$($itm.$script:bitarch.scan)"
                scantype = "$($itm.$script:bitarch.scantype)"
                scanval = "$($itm.$script:bitarch.scanval)"
                alert = "$($itm.$script:bitarch.alert)"
                alertval = "$($itm.$script:bitarch.alertval)"
                infect = "$($itm.$script:bitarch.infect)"
                infectval = "$($itm.$script:bitarch.infectval)"
                threat = "$($itm.$script:bitarch.threat)"
              }
            }
            if ($dest.containskey($itm.name)) {
              continue
            } elseif (-not $dest.containskey($itm.name)) {
              $dest.add($itm.name, $hash)
            }
          }
        }
      }
    } catch {
      $xmldiag = "AV Health : Error reading AV XML : $($srcAVP)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n"
      write-host "AV Health : Error reading AV XML : $($srcAVP)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n"
      write-host $_.Exception
      write-host $_.scriptstacktrace
      write-host $_
      #Stop script execution time calculation
      StopClock
      #DATTO OUTPUT
      $script:diag += "$($xmldiag)"
      write-DRMMAlert "Error reading AV XML : $($srcAVP)"
      write-DRMMDiag "$($script:diag)"
      $xmldiag = $null
      exit 1
    }
  } ## Get-AVXML
  
  function Pop-Components {                                                                         #POPULATE AV COMPONENT VERSIONS
    param (
      $dest, $name, $version
    )
    #$dest = @{}
    #READ PRIMARY AV PRODUCT COMPONENTS DATA INTO NESTED HASHTABLE FORMAT FOR LATER USE
    try {
      if (($name -ne $null) -and ($name -ne "")) {
        if ($dest.containskey($name)) {
          continue
        } elseif (-not $dest.containskey($name)) {
          $dest.add($name, $version)
        }
      }
    } catch {
      $compdiag = "AV Health : Error reading AV Components`r`n$($_.scriptstacktrace)`r`n$($_)`r`n"
      write-host "AV Health : Error reading AV Components`r`n$($_.scriptstacktrace)`r`n$($_)`r`n"
      $script:diag += "$($compdiag)"
      $compdiag = $null
      write-host $_.Exception
      write-host $_.scriptstacktrace
      write-host $_
    }
  } ## Pop-Components
  
  function Pop-Warnings {
    param (
      $dest, $av, $warn
    )
    #POPULATE AV PRODUCT WARNINGS DATA INTO NESTED HASHTABLE FORMAT FOR LATER USE
    try {
      if (($av -ne $null) -and ($av -ne "")) {
        if ($dest.containskey($av)) {
          $new = [System.Collections.ArrayList]@()
          $prev = [System.Collections.ArrayList]@()
          $blnADD = $true
          $prev = $dest[$av]
          $prev = $prev.split("`r`n",[System.StringSplitOptions]::RemoveEmptyEntries)
          if ($prev -contains $warn) {
            $blnADD = $false
          }
          if ($blnADD) {
            foreach ($itm in $prev) {
              $new.add("$($itm)`r`n")
            }
            $new.add("$($warn)`r`n")
            $dest.remove($av)
            $dest.add($av, $new)
            $script:blnWARN = $true
          }
        } elseif (-not $dest.containskey($av)) {
          $new = [System.Collections.ArrayList]@()
          $new = "$($warn)`r`n"
          $dest.add($av, $new)
          $script:blnWARN = $true
        }
      }
    } catch {
      $warndiag = "AV Health : Error populating warnings for $($av)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n"
      write-host "AV Health : Error populating warnings for $($av)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n"
      $script:diag += "$($warndiag)"
      $warndiag = $null
      write-host $_.Exception
      write-host $_.scriptstacktrace
      write-host $_
    }
  } ## Pop-Warnings

  function SEP-Map {
    param (
      $intval
    )
    switch ($intval) {
      0 {return "(Severity 0) Viral"}
      1 {return "(Severity 1) Non-Viral Malicious"}
      2 {return "(Severity 2) Malicious"}
      3 {return "(Severity 3) Antivirus - Heuristic"}
      5 {return "(Severity 5) Hack Tool"}
      6 {return "(Severity 6) Spyware"}
      7 {return "(Severity 7) Trackware"}
      8 {return "(Severity 8) Dialer"}
      9 {return "(Severity 9) Remote Access"}
      10 {return "(Severity 10) Adware"}
      11 {return "(Severity 11) Jokeware"}
      12 {return "(Severity 12) Client Compliancy"}
      13 {return "(Severity 13) Generic Load Point"}
      14 {return "(Severity 14) Proactive Threat Scan - Heuristic"}
      15 {return "(Severity 15) Cookie"}
      9999 {return "No detections"}
    }
  } ## SEP-Map

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
#Start script execution time calculation
$ScrptStartTime = (Get-Date).ToString('dd-MM-yyyy hh:mm:ss')
$script:sw = [Diagnostics.Stopwatch]::StartNew()
Get-OSArch
write-host "Monitoring AV Product : $env:i_PAV"
$script:diag += "`r`nMonitoring AV Product : $env:i_PAV`r`n"
Get-AVXML $env:i_PAV $script:pavkey
if (-not ($script:blnAVXML)) {
  #AV DETAILS
  $script:o_AVname = "Selected AV Product Not Found`r`nUnable to download AV Vendor XML`r`n"
  $script:o_AVVersion = "Selected AV Product Not Found`r`nUnable to download AV Vendor XML`r`n"
  $script:o_AVpath = "Selected AV Product Not Found`r`nUnable to download AV Vendor XML`r`n"
  $script:o_AVStatus = "Selected AV Product Not Found`r`nUnable to download AV Vendor XML`r`n"
  #REAL-TIME SCANNING & DEFINITIONS
  $script:o_RTstate = "Selected AV Product Not Found`r`nUnable to download AV Vendor XML`r`n"
  $script:o_DefStatus = "Selected AV Product Not Found`r`nUnable to download AV Vendor XML`r`n"
  #THREATS
  $script:o_Infect = "Selected AV Product Not Found`r`nUnable to download AV Vendor XML`r`n"
  $script:o_Threats = "Selected AV Product Not Found`r`nUnable to download AV Vendor XML`r`n"
  #COMPETITOR AV
  $script:o_CompAV = "Selected AV Product Not Found`r`nUnable to download AV Vendor XML`r`n"
  $script:o_CompPath = "Selected AV Product Not Found`r`nUnable to download AV Vendor XML`r`n"
  $script:o_CompState = "Selected AV Product Not Found`r`nUnable to download AV Vendor XML`r`n"
  $script:diag += "Selected AV Product Not Found`r`nUnable to download AV Vendor XML`r`n"
  #Stop script execution time calculation
  StopClock
  #DATTO OUTPUT
  write-DRMMAlert "Selected AV Product Not Found`r`nUnable to download AV Vendor XML`r`n"
  write-DRMMDiag "$($script:diag)"
  exit 1
} elseif ($script:blnAVXML) {
  #QUERY WMI SECURITYCENTER NAMESPACE FOR AV PRODUCT DETAILS
  if ([system.version]$script:OSVersion -ge [system.version]'6.0.0.0') {
    write-verbose "OS Windows Vista/Server 2008 or newer detected."
    try {
      $AntiVirusProduct = get-wmiobject -Namespace "root\SecurityCenter2" -Class "AntiVirusProduct" -ComputerName "$($script:computername)" -ErrorAction Stop
    } catch {
      $script:blnWMI = $false
    }
  } elseif ([system.version]$script:OSVersion -lt [system.version]'6.0.0.0') {
    write-verbose "Windows 2000, 2003, XP detected" 
    try {
      $AntiVirusProduct = get-wmiobject -Namespace "root\SecurityCenter" -Class "AntiVirusProduct"  -ComputerName "$($script:computername)" -ErrorAction Stop
    } catch {
      $script:blnWMI = $false
    }
  }
  if (-not $script:blnWMI) {                                                                        #FAILED TO RETURN WMI SECURITYCENTER NAMESPACE
    try {
      $script:diag += "`r`nFailed to query WMI SecurityCenter Namespace`r`n"
      $script:diag += "Possibly Server, attempting to fallback to using 'HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\' registry key`r`n"
      write-host "`r`nFailed to query WMI SecurityCenter Namespace" -foregroundcolor red
      write-host "Possibly Server, attempting to fallback to using 'HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\' registry key" -foregroundcolor red
      try {                                                                                         #QUERY 'HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\' AND SEE IF AN AV IS REGISTRERED THERE
        if ($script:bitarch = "bit64") {
          $AntiVirusProduct = (get-itemproperty -path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Security Center\Monitoring\*" -ErrorAction Stop).PSChildName
        } elseif ($script:bitarch = "bit32") {
          $AntiVirusProduct = (get-itemproperty -path "HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\*" -ErrorAction Stop).PSChildName
        }
      } catch {
        $script:diag += "Could not find AV registered in HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\*`r`n"
        write-host "Could not find AV registered in HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\*" -foregroundcolor red
        $AntiVirusProduct = $null
        $blnSecMon = $true
      }
      if ($AntiVirusProduct -ne $null) {                                                            #RETURNED 'HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\' DATA
        $strDisplay = $null
        $blnSecMon = $false
        $script:diag += "`r`nPerforming AV Product discovery`r`n"
        write-host "`r`nPerforming AV Product discovery" -foregroundcolor yellow
        foreach ($av in $AntiVirusProduct) {
          #PRIMARY AV REGISTERED UNDER 'HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\'
          if ($av -match $env:i_PAV) {
            $script:blnPAV = $true
          } elseif (($env:i_PAV -eq "Trend Micro") -and ($av -match "Worry-Free Business Security")) {
            $script:blnPAV = $true
          }
          $script:diag += "`r`nFound 'HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\$($av)'`r`n"
          write-host "`r`nFound 'HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\$($av)'" -foregroundcolor yellow
          #RETRIEVE DETECTED AV PRODUCT VENDOR XML
          foreach ($vendor in $script:avVendors) {
            if ($av -match $vendor) {
              Get-AVXML $vendor $script:vavkey
              break
            } elseif ($av -match "Worry-Free Business Security") {
              Get-AVXML "Trend Micro" $script:vavkey
              break
            }
          }
          #SEARCH PASSED PRIMARY AV VENDOR XML
          foreach ($key in $script:vavkey.keys) {                                                   #ATTEMPT TO VALIDATE EACH AV PRODUCT CONTAINED IN VENDOR XML
            if ($av.replace(" ", "").replace("-", "").toupper() -eq $key.toupper()) {
              $script:diag += "Matched AV : '$($av)' - '$($key)' AV Product`r`n"
              write-host "Matched AV : '$($av)' - '$($key)' AV Product" -foregroundcolor yellow
              $strName = $null
              $regDisplay = "$($script:vavkey[$key].display)"
              $regDisplayVal = "$($script:vavkey[$key].displayval)"
              $regPath = "$($script:vavkey[$key].path)"
              $regPathVal = "$($script:vavkey[$key].pathval)"
              $regStat = "$($script:vavkey[$key].stat)"
              $regStatVal = "$($script:vavkey[$key].statval)"
              $regRealTime = "$($script:vavkey[$key].rt)"
              $regRTVal = "$($script:vavkey[$key].rtval)"
              break
            }
          }
          try {
            if (($regDisplay -ne "") -and ($regDisplay -ne $null)) {
              if (test-path "HKLM:$($regDisplay)") {                                                #ATTEMPT TO VALIDATE INSTALLED AV PRODUCT BY TEST READING A KEY
                $script:diag += "Found 'HKLM:$($regDisplay)' for product : $($key)`r`n"
                write-host "Found 'HKLM:$($regDisplay)' for product : $($key)" -foregroundcolor yellow
                try {                                                                               #IF VALIDATION PASSES; FABRICATE 'HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\' DATA
                  $keyval1 = get-itemproperty -path "HKLM:$($regDisplay)" -name "$($regDisplayVal)" -erroraction stop
                  $keyval2 = get-itemproperty -path "HKLM:$($regPath)" -name "$($regPathVal)" -erroraction stop
                  $keyval3 = get-itemproperty -path "HKLM:$($regStat)" -name "$($regStatVal)" -erroraction stop
                  $strName = "$($keyval1.$regDisplayVal)"
                  try {
                    $keyval4 = get-itemproperty -path "HKLM:$($regRealTime)" -name "$($regRTVal)" -erroraction stop
                    if ($strName -match "Windows Defender") {
                      try {
                        write-host "Windows Defender Legacy '$($regRTVal)' Key Found : Checking for 'DisableRealtimeMonitoring' Key"
                        $script:diag += "Windows Defender Legacy '$($regRTVal)' Key Found : Checking for 'DisableRealtimeMonitoring' Key`r`n"
                        $keyval5 = get-itemproperty -path "HKLM:$($regRealTime)" -name "DisableRealtimeMonitoring" -erroraction stop
                        $keyval4 | Add-Member -MemberType NoteProperty -Name "$($regRTVal)" -Value "$($keyval5.DisableRealtimeMonitoring)" -force
                      } catch {
                        write-host "Windows Defender 'DisableRealtimeMonitoring' Key Not Found"
                        $script:diag += "Windows Defender 'DisableRealtimeMonitoring' Key Not Found`r`n"
                      }
                    }
                  } catch {
                    if ($strName -match "Windows Defender") {
                      try {
                        write-host "Windows Defender '$($regRTVal)' Key Not Found : Checking for 'DisableRealtimeMonitoring' Key"
                        $script:diag += "Windows Defender Legacy '$($regRTVal)' Key Found : Checking for 'DisableRealtimeMonitoring' Key`r`n"
                        $keyval5 = get-itemproperty -path "HKLM:$($regRealTime)" -name "DisableRealtimeMonitoring" -erroraction stop
                        $keyval4 | Add-Member -MemberType NoteProperty -Name "$($regRTVal)" -Value "$($keyval5.DisableRealtimeMonitoring)" -force
                      } catch {
                        write-host "Windows Defender 'DisableRealtimeMonitoring' Key Not Found"
                        $script:diag += "Windows Defender 'DisableRealtimeMonitoring' Key Not Found`r`n"
                      }
                    }
                  }
                  #FORMAT AV DATA
                  write-host "DISPLAY KEY VALUE : $($strName)"
                  write-host "DISPLAY KEY TYPE : $($strName.GetType())"
                  if ($strName -match "Windows Defender") {                                         #'NORMALIZE' WINDOWS DEFENDER DISPLAY NAME
                    $strName = "Windows Defender"
                  } elseif (($env:i_PAV -match "Sophos") -and ($strName -match "BETA")) {           #'NORMALIZE' SOPHOS INTERCEPT X BETA DISPLAY NAME AND FIX SERVER REG CHECK
                    $strName = "Sophos Intercept X Beta"
                  } elseif (($env:i_PAV -match "Sophos") -and ($strName -match "\d+\.\d+\.\d+")) {  #'NORMALIZE' SOPHOS INTERCEPT X DISPLAY NAME AND FIX SERVER REG CHECK
                    $strName = "Sophos Intercept X"
                  }
                  write-host "NORMALIZED DISPLAY VALUE : $($strName)"
                  $strDisplay = "$($strDisplay)$($strName), "
                  $strPath = "$($strPath)$($keyval2.$regPathVal), "
                  $strStat = "$($strStat)$($keyval3.$regStatVal.tostring()), "
                  #INTERPRET REAL-TIME SCANNING STATUS
                  if ($script:zRealTime -contains $script:vavkey[$key].display) {                   #AV PRODUCTS TREATING '0' AS 'ENABLED' FOR 'REAL-TIME SCANNING'
                    if ($keyval4.$regRTVal -eq "0") {
                      $strRealTime = "$($strRealTime)Enabled (REG Check), "
                    } elseif ($keyval4.$regRTVal -eq "1") {
                      $strRealTime = "$($strRealTime)Disabled (REG Check), "
                    }
                  } elseif ($script:zRealTime -notcontains $script:vavkey[$key].display) {          #AV PRODUCTS TREATING '1' AS 'ENABLED' FOR 'REAL-TIME SCANNING'
                    if ($keyval4.$regRTVal -eq "1") {
                      $strRealTime = "$($strRealTime)Enabled (REG Check), "
                    } elseif ($keyval4.$regRTVal -eq "0") {
                      $strRealTime = "$($strRealTime)Disabled (REG Check), "
                    }
                  }
                } catch {
                  $script:diag += "Could not validate Registry data for product : $($key)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n"
                  write-host "Could not validate Registry data for product : $($key)" -foregroundcolor red
                  write-host $_.scriptstacktrace
                  write-host $_
                }
              }
            }
          } catch {
            $script:diag += "Could not validate Registry data for product : $($key)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n"
            write-host "Not Found 'HKLM:$regDisplay' for product : $($key)" -foregroundcolor red
            write-host $_.scriptstacktrace
            write-host $_
          }
        }
      }
      if (($AntiVirusProduct -eq $null) -or (-not $script:blnPAV)) {                                #FAILED TO RETURN 'HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\' DATA
        $strDisplay = $null
        $blnSecMon = $true
        #RETRIEVE EACH VENDOR XML AND CHECK FOR ALL SUPPORTED AV PRODUCTS
        $script:diag += "`r`nPrimary AV Product not found / No AV Products found; will check each AV Product in all Vendor XMLs`r`n"
        write-host "`r`nPrimary AV Product not found / No AV Products found; will check each AV Product in all Vendor XMLs" -foregroundcolor yellow
        foreach ($vendor in $script:avVendors) {
          Get-AVXML $vendor $script:vavkey
        }
        foreach ($key in $script:vavkey.keys) {                                                     #ATTEMPT TO VALIDATE EACH AV PRODUCT CONTAINED IN VENDOR XML
          if ($key -notmatch "#comment") {                                                          #AVOID ODD 'BUG' WITH A KEY AS '#comment' WHEN SWITCHING AV VENDOR XMLS
            $script:diag += "Attempting to detect AV Product : '$($key)'`r`n"
            write-host "Attempting to detect AV Product : '$($key)'" -foregroundcolor yellow
            $strName = $null
            $regDisplay = "$($script:vavkey[$key].display)"
            $regDisplayVal = "$($script:vavkey[$key].displayval)"
            $regPath = "$($script:vavkey[$key].path)"
            $regPathVal = "$($script:vavkey[$key].pathval)"
            $regStat = "$($script:vavkey[$key].stat)"
            $regStatVal = "$($script:vavkey[$key].statval)"
            $regRealTime = "$($script:vavkey[$key].rt)"
            $regRTVal = "$($script:vavkey[$key].rtval)"
            try {
              if (test-path "HKLM:$($regDisplay)") {                                                #VALIDATE INSTALLED AV PRODUCT BY TESTING READING A KEY
                $script:diag += "Found 'HKLM:$($regDisplay)' for product : $($key)`r`n"
                write-host "Found 'HKLM:$($regDisplay)' for product : $($key)" -foregroundcolor yellow
                try {                                                                               #IF VALIDATION PASSES; FABRICATE 'HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\' DATA
                  $keyval1 = get-itemproperty -path "HKLM:$($regDisplay)" -name "$($regDisplayVal)" -erroraction stop
                  $keyval2 = get-itemproperty -path "HKLM:$($regPath)" -name "$($regPathVal)" -erroraction stop
                  $keyval3 = get-itemproperty -path "HKLM:$($regStat)" -name "$($regStatVal)" -erroraction stop
                  $strName = "$($keyval1.$regDisplayVal)"
                  try {
                    $keyval4 = get-itemproperty -path "HKLM:$($regRealTime)" -name "$($regRTVal)" -erroraction stop
                    if ($strName -match "Windows Defender") {
                      try {
                        write-host "Windows Defender Legacy '$($regRTVal)' Key Found : Checking for 'DisableRealtimeMonitoring' Key"
                        $script:diag += "Windows Defender Legacy '$($regRTVal)' Key Found : Checking for 'DisableRealtimeMonitoring' Key`r`n"
                        $keyval5 = get-itemproperty -path "HKLM:$($regRealTime)" -name "DisableRealtimeMonitoring" -erroraction stop
                        $keyval4 | Add-Member -MemberType NoteProperty -Name "$($regRTVal)" -Value "$($keyval5.DisableRealtimeMonitoring)" -force
                      } catch {
                        write-host "Windows Defender 'DisableRealtimeMonitoring' Key Not Found"
                        $script:diag += "Windows Defender 'DisableRealtimeMonitoring' Key Not Found`r`n"
                      }
                    }
                  } catch {
                    if ($strName -match "Windows Defender") {
                      try {
                        write-host "Windows Defender '$($regRTVal)' Key Not Found : Checking for 'DisableRealtimeMonitoring' Key"
                        $script:diag += "Windows Defender Legacy '$($regRTVal)' Key Found : Checking for 'DisableRealtimeMonitoring' Key`r`n"
                        $keyval5 = get-itemproperty -path "HKLM:$($regRealTime)" -name "DisableRealtimeMonitoring" -erroraction stop
                        $keyval4 | Add-Member -MemberType NoteProperty -Name "$($regRTVal)" -Value "$($keyval5.DisableRealtimeMonitoring)" -force
                      } catch {
                        write-host "Windows Defender 'DisableRealtimeMonitoring' Key Not Found"
                        $script:diag += "Windows Defender 'DisableRealtimeMonitoring' Key Not Found`r`n"
                      }
                    }
                  }
                  #FORMAT AV DATA
                  write-host "DISPLAY KEY VALUE : $($strName)"
                  write-host "DISPLAY KEY TYPE : $($strName.GetType())"
                  if ($strName -match "Windows Defender") {                                         #'NORMALIZE' WINDOWS DEFENDER DISPLAY NAME
                    $strName = "Windows Defender"
                  } elseif (($env:i_PAV -match "Sophos") -and ($strName -match "BETA")) {           #'NORMALIZE' SOPHOS INTERCEPT X BETA DISPLAY NAME AND FIX SERVER REG CHECK
                    $strName = "Sophos Intercept X Beta"
                  } elseif (($env:i_PAV -match "Sophos") -and ($strName -match "\d+\.\d+\.\d+")) {  #'NORMALIZE' SOPHOS INTERCEPT X DISPLAY NAME AND FIX SERVER REG CHECK
                    $strName = "Sophos Intercept X"
                  }
                  write-host "NORMALIZED DISPLAY VALUE : $($strName)"
                  $strDisplay = "$($strDisplay)$($strName), "
                  $strPath = "$($strPath)$($keyval2.$regPathVal), "
                  $strStat = "$($strStat)$($keyval3.$regStatVal.tostring()), "
                  #INTERPRET REAL-TIME SCANNING STATUS
                  if ($script:zRealTime -contains $script:vavkey[$key].display) {                   #AV PRODUCTS TREATING '0' AS 'ENABLED' FOR 'REAL-TIME SCANNING'
                    if ($keyval4.$regRTVal = "0") {
                      $strRealTime = "$($strRealTime)Enabled (REG Check), "
                    } elseif ($keyval4.$regRTVal = "1") {
                      $strRealTime = "$($strRealTime)Disabled (REG Check), "
                    }
                  } elseif ($script:zRealTime -notcontains $script:vavkey[$key].display) {          #AV PRODUCTS TREATING '1' AS 'ENABLED' FOR 'REAL-TIME SCANNING'
                    if ($keyval4.$regRTVal = "1") {
                      $strRealTime = "$($strRealTime)Enabled (REG Check), "
                    } elseif ($keyval4.$regRTVal = "0") {
                      $strRealTime = "$($strRealTime)Disabled (REG Check), "
                    }
                  }
                  #FABRICATE 'HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\' DATA
                  if ($blnSecMon) {
                    $script:diag += "Creating Registry Key HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\$($strName) for product : $($strName)`r`n"
                    write-host "Creating Registry Key HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\$($strName) for product : $($strName)" -foregroundcolor red
                    if ($script:bitarch = "bit64") {
                      try {
                        new-item -path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Security Center\Monitoring\" -name "$strName" -value "$strName" -force
                      } catch {
                        $script:diag += "Could not create Registry Key `HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\$($strName) for product : $($strName)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n"
                        write-host "Could not create Registry Key `HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\$($strName) for product : $($strName)" -foregroundcolor red
                        write-host $_.scriptstacktrace
                        write-host $_
                      }
                    } elseif ($script:bitarch = "bit32") {
                      try {
                        new-item -path "HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\" -name "$($strName)" -value "$($strName)" -force
                      } catch {
                        $script:diag += "Could not create Registry Key `HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\$($strName) for product : $($strName)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n"
                        write-host "Could not create Registry Key `HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\$($strName) for product : $($strName)" -foregroundcolor red
                        write-host $_.scriptstacktrace
                        write-host $_
                      }
                    }
                  }
                  $AntiVirusProduct = "."
                } catch {
                  $script:diag += "Could not validate Registry data for product : $($key)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n"
                  write-host "Could not validate Registry data for product : $($key)" -foregroundcolor red
                  write-host $_.scriptstacktrace
                  write-host $_
                  $AntiVirusProduct = $null
                }
              }
            } catch {
              $script:diag += "Not Found 'HKLM:$($regDisplay)' for product : $($key)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n"
              write-host "Not Found 'HKLM:$($regDisplay)' for product : $($key)" -foregroundcolor red
              write-host $_.scriptstacktrace
              write-host $_
            }
          }
        }
      }
      $tmpavs = $strDisplay -split ", "
      $tmppaths = $strPath -split ", "
      $tmprts = $strRealTime -split ", "
      $tmpstats = $strStat -split ", "
    } catch {
      $script:diag += "`r``nFailed to validate supported AV Products`r`n"
      write-host "Failed to validate supported AV Products" -foregroundcolor red
      write-host $_.scriptstacktrace
      write-host $_
    }
  } elseif ($script:blnWMI) {                                                                       #RETURNED WMI SECURITYCENTER NAMESPACE
    #SEPARATE RETURNED WMI AV PRODUCT INSTANCES
    if ($AntiVirusProduct -ne $null) {                                                              #RETURNED WMI AV PRODUCT DATA
      $tmpavs = $AntiVirusProduct.displayName -split ", "
      $tmppaths = $AntiVirusProduct.pathToSignedProductExe -split ", "
      $tmpstats = $AntiVirusProduct.productState -split ", "
    } elseif ($AntiVirusProduct -eq $null) {                                                        #FAILED TO RETURN WMI AV PRODUCT DATA
      $strDisplay = $null
      #RETRIEVE EACH VENDOR XML AND CHECK FOR ALL SUPPORTED AV PRODUCTS
      $script:diag += "`r`nPrimary AV Product not found / No AV Products found; will check each AV Product in all Vendor XMLs`r`n"
      write-host "`r`nPrimary AV Product not found / No AV Products found; will check each AV Product in all Vendor XMLs" -foregroundcolor yellow
      foreach ($vendor in $script:avVendors) {
        Get-AVXML $vendor $script:vavkey
      }
      foreach ($key in $script:vavkey.keys) {                                                       #ATTEMPT TO VALIDATE EACH AV PRODUCT CONTAINED IN VENDOR XML
        if ($key -notmatch "#comment") {                                                            #AVOID ODD 'BUG' WITH A KEY AS '#comment' WHEN SWITCHING AV VENDOR XMLS
          $script:diag += "Attempting to detect AV Product : '$($key)'`r`n"
          write-host "Attempting to detect AV Product : '$($key)'" -foregroundcolor yellow
          $strName = $null
          $regDisplay = "$($script:vavkey[$key].display)"
          $regDisplayVal = "$($script:vavkey[$key].displayval)"
          $regPath = "$($script:vavkey[$key].path)"
          $regPathVal = "$($script:vavkey[$key].pathval)"
          $regStat = "$($script:vavkey[$key].stat)"
          $regStatVal = "$($script:vavkey[$key].statval)"
          $regRealTime = "$($script:vavkey[$key].rt)"
          $regRTVal = "$($script:vavkey[$key].rtval)"
          try {
            if (test-path "HKLM:$($regDisplay)") {                                                  #VALIDATE INSTALLED AV PRODUCT BY TESTING READING A KEY
              $script:diag += "Found 'HKLM:$($regDisplay)' for product : $($key)`r`n"
              write-host "Found 'HKLM:$($regDisplay)' for product : $($key)" -foregroundcolor yellow
              try {                                                                                 #IF VALIDATION PASSES
                $keyval1 = get-itemproperty -path "HKLM:$($regDisplay)" -name "$($regDisplayVal)" -erroraction stop
                $keyval2 = get-itemproperty -path "HKLM:$($regPath)" -name "$($regPathVal)" -erroraction stop
                $keyval3 = get-itemproperty -path "HKLM:$($regStat)" -name "$($regStatVal)" -erroraction stop
                $strName = "$($keyval1.$regDisplayVal)"
                try {
                  $keyval4 = get-itemproperty -path "HKLM:$($regRealTime)" -name "$($regRTVal)" -erroraction stop
                  if ($strName -match "Windows Defender") {
                    try {
                      write-host "Windows Defender Legacy '$($regRTVal)' Key Found : Checking for 'DisableRealtimeMonitoring' Key"
                      $script:diag += "Windows Defender Legacy '$($regRTVal)' Key Found : Checking for 'DisableRealtimeMonitoring' Key`r`n"
                      $keyval5 = get-itemproperty -path "HKLM:$($regRealTime)" -name "DisableRealtimeMonitoring" -erroraction stop
                      $keyval4 | Add-Member -MemberType NoteProperty -Name "$($regRTVal)" -Value "$($keyval5.DisableRealtimeMonitoring)" -force
                    } catch {
                      write-host "Windows Defender 'DisableRealtimeMonitoring' Key Not Found"
                      $script:diag += "Windows Defender 'DisableRealtimeMonitoring' Key Not Found`r`n"
                    }
                  }
                } catch {
                  if ($strName -match "Windows Defender") {
                    try {
                      write-host "Windows Defender '$($regRTVal)' Key Not Found : Checking for 'DisableRealtimeMonitoring' Key"
                      $script:diag += "Windows Defender Legacy '$($regRTVal)' Key Found : Checking for 'DisableRealtimeMonitoring' Key`r`n"
                      $keyval5 = get-itemproperty -path "HKLM:$($regRealTime)" -name "DisableRealtimeMonitoring" -erroraction stop
                      $keyval4 | Add-Member -MemberType NoteProperty -Name "$($regRTVal)" -Value "$($keyval5.DisableRealtimeMonitoring)" -force
                    } catch {
                      write-host "Windows Defender 'DisableRealtimeMonitoring' Key Not Found"
                      $script:diag += "Windows Defender 'DisableRealtimeMonitoring' Key Not Found`r`n"
                    }
                  }
                }
                #FORMAT AV DATA
                write-host "DISPLAY KEY VALUE : $($strName)"
                write-host "DISPLAY KEY TYPE : $($strName.GetType())"
                if ($strName -match "Windows Defender") {                                           #'NORMALIZE' WINDOWS DEFENDER DISPLAY NAME
                  $strName = "Windows Defender"
                } elseif (($strName -match "Sophos") -and ($strName -match "BETA")) {               #'NORMALIZE' SOPHOS INTERCEPT X BETA DISPLAY NAME AND FIX SERVER REG CHECK
                  $strName = "Sophos Intercept X Beta"
                } elseif (($env:i_PAV -match "Sophos") -and ($strName -match "\d+\.\d+\.\d+")) {    #'NORMALIZE' SOPHOS INTERCEPT X DISPLAY NAME AND FIX SERVER REG CHECK
                  $strName = "Sophos Intercept X"
                }
                write-host "NORMALIZED DISPLAY VALUE : $($strName)"
                $strDisplay = "$($strDisplay)$($strName), "
                $strPath = "$($strPath)$($keyval2.$regPathVal), "
                $strStat = "$($strStat)$($keyval3.$regStatVal.tostring()), "
                #INTERPRET REAL-TIME SCANNING STATUS
                if ($script:zRealTime -contains $script:vavkey[$key].display) {                     #AV PRODUCTS TREATING '0' AS 'ENABLED' FOR 'REAL-TIME SCANNING'
                  if ($keyval4.$regRTVal = "0") {
                    $strRealTime = "$($strRealTime)Enabled (REG Check), "
                  } elseif ($keyval4.$regRTVal = "1") {
                    $strRealTime = "$($strRealTime)Disabled (REG Check), "
                  }
                } elseif ($script:zRealTime -notcontains $script:vavkey[$key].display) {            #AV PRODUCTS TREATING '1' AS 'ENABLED' FOR 'REAL-TIME SCANNING'
                  if ($keyval4.$regRTVal = "1") {
                    $strRealTime = "$($strRealTime)Enabled (REG Check), "
                  } elseif ($keyval4.$regRTVal = "0") {
                    $strRealTime = "$($strRealTime)Disabled (REG Check), "
                  }
                }
                $AntiVirusProduct = "."
              } catch {
                $script:diag += "Could not validate Registry data for product : $($key)`r`n$($_.scriptstacktrace)`r`n$($_)`r``n"
                write-host "Could not validate Registry data for product : $($key)" -foregroundcolor red
                write-host $_.scriptstacktrace
                write-host $_
                $AntiVirusProduct = $null
              }
            }
          } catch {
            $script:diag += "Not Found 'HKLM:$($regDisplay)' for product : $($key)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n"
            write-host "Not Found 'HKLM:$($regDisplay)' for product : $($key)" -foregroundcolor red
            write-host $_.scriptstacktrace
            write-host $_
          }
        }
      }
      $tmpavs = $strDisplay -split ", "
      $tmppaths = $strPath -split ", "
      $tmprts = $strRealTime -split ", "
      $tmpstats = $strStat -split ", "
    }
  }
  #ENSURE ONLY UNIQUE AV PRODUCTS ARE IN '$avs' HASHTABLE
  $i = 0
  foreach ($tmpav in $tmpavs) {
    if ($avs.count -eq 0) {
      if ($tmprts.count -gt 0) {
        $hash = @{
          display = $tmpavs[$i]
          path = $tmppaths[$i]
          rt = $tmprts[$i]
          stat = $tmpstats[$i]
        }
      } elseif ($tmprts.count -eq 0) {
        $hash = @{
          display = $tmpavs[$i]
          path = $tmppaths[$i]
          stat = $tmpstats[$i]
        }
      }
      $avs.add($tmpavs[$i], $hash)
    } elseif ($avs.count -gt 0) {
      $blnADD = $true
      foreach ($av in $avs.keys) {
        if ($tmpav -eq $av) {
          $blnADD = $false
          break
        }
      }
      if ($blnADD) {
        if ($tmprts.count -gt 0) {
          $hash = @{
            display = $tmpavs[$i]
            path = $tmppaths[$i]
            rt = $tmprts[$i]
            stat = $tmpstats[$i]
          }
        } elseif ($tmprts.count -eq 0) {
          $hash = @{
            display = $tmpavs[$i]
            path = $tmppaths[$i]
            stat = $tmpstats[$i]
          }
        }
        $avs.add($tmpavs[$i], $hash)
      }
    }
    $i = $i + 1
  }
  #OBTAIN FINAL AV PRODUCT DETAILS
  $script:diag += "`r`nAV Product discovery completed`r`n`r`n"
  write-host "`r`nAV Product discovery completed`r`n" -foregroundcolor yellow
  if ($AntiVirusProduct -eq $null) {                                                                #NO AV PRODUCT FOUND
    $script:diag += "Could not find any AV Product registered`r`n"
    write-host "Could not find any AV Product registered" -foregroundcolor red
    $script:o_AVname = "No AV Product Found"
    $script:o_AVVersion = $null
    $script:o_AVpath = $null
    $script:o_AVStatus = "Unknown"
    $script:o_RTstate = "Unknown"
    $script:o_DefStatus = "Unknown"
    $script:o_AVcon = 0
    #Stop script execution time calculation
    StopClock
    #DATTO OUTPUT
    write-DRMMAlert "Could not find any AV Product registered`r`n"
    write-DRMMDiag "$($script:diag)"
    exit 1
  } elseif ($AntiVirusProduct -ne $null) {                                                          #FOUND AV PRODUCTS
    foreach ($av in $avs.keys) {                                                                    #ITERATE THROUGH EACH FOUND AV PRODUCT
      if (($avs[$av].display -ne $null) -and ($avs[$av].display -ne "")) {
        #NEITHER PRIMARY AV PRODUCT NOR WINDOWS DEFENDER
        if (($avs[$av].display -notmatch $env:i_PAV) -and ($avs[$av].display -notmatch "Windows Defender")) {
          if (($env:i_PAV -eq "Trend Micro") -and (($avs[$av].display -notmatch "Trend Micro") -and ($avs[$av].display -notmatch "Worry-Free Business Security"))) {
            $script:o_AVcon = 1
            $script:o_CompAV += "$($avs[$av].display)`r`n"
            $script:o_CompPath += "$($avs[$av].path)`r`n"
            if ($script:blnWMI) {
              Get-AVState $script:pskey $avs[$av].stat
              $script:o_CompState += "$($avs[$av].display) - Real-Time Scanning : $($script:rtstatus) - Definitions : $($script:defstatus)`r`n"
            } elseif (-not $script:blnWMI) {
              $script:o_CompState += "$($avs[$av].display) - Real-Time Scanning : $($avs[$av].rt) - Definitions : N/A (WMI Check)`r`n"
            }
          } elseif ($env:i_PAV -ne "Trend Micro") {
            $script:o_AVcon = 1
            $script:o_CompAV += "$($avs[$av].display)`r`n"
            $script:o_CompPath += "$($avs[$av].path)`r`n"
            if ($script:blnWMI) {
              Get-AVState $script:pskey $avs[$av].stat
              $script:o_CompState += "$($avs[$av].display) - Real-Time Scanning : $($script:rtstatus) - Definitions : $($script:defstatus)`r`n"
            } elseif (-not $script:blnWMI) {
              $script:o_CompState += "$($avs[$av].display) - Real-Time Scanning : $($avs[$av].rt) - Definitions : N/A (WMI Check)`r`n"
            }
          }
          Pop-Warnings $script:avwarn $env:i_PAV "AV Conflict detected`r`n"
        }
        #PRIMARY AV PRODUCT
        if (($avs[$av].display -match $env:i_PAV) -or 
          (($env:i_PAV -eq "Trend Micro") -and (($avs[$av].display -match "Trend Micro") -or ($avs[$av].display -match "Worry-Free Business Security")))) {
          #PARSE XML FOR SPECIFIC VENDOR AV PRODUCT
          $node = $avs[$av].display.replace(" ", "").replace("-", "").toupper()
          #AV DETAILS
          $script:o_AVname = $avs[$av].display
          $script:o_AVpath = $avs[$av].path
          #AV PRODUCT VERSION
          if ($env:i_PAV -notmatch "Trend Micro") {
            $i_verkey = $script:pavkey[$node].ver
            $i_verval = $script:pavkey[$node].verval
          } elseif ($env:i_PAV -match "Trend Micro") {
            $i_verkey = $script:pavkey[$node].corever
            $i_verval = $script:pavkey[$node].coreverval
            $i_vckey = $script:pavkey[$node].vcver
            $i_vcval = $script:pavkey[$node].vcverval
          }
          #AV PRODUCT COMPONENTS VERSIONS
          $i_compverkey = $script:pavkey[$node].compver
          if ($env:i_PAV -match "Trend Micro") {
            $i_compverval = $script:pavkey[$node].compverval
          }
          #AV PRODUCT STATE
          $i_statkey = $script:pavkey[$node].stat
          $i_statval = $script:pavkey[$node].statval
          #AV PRODUCT LAST UPDATE TIMESTAMP
          $i_update = $script:pavkey[$node].update
          $i_updateval = $script:pavkey[$node].updateval
          #AV PRODUCT UPDATE SOURCE
          $i_source = $script:pavkey[$node].source
          $i_sourceval = $script:pavkey[$node].sourceval
          #AV PRODUCT REAL-TIME SCANNING
          $i_rtkey = $script:pavkey[$node].rt
          $i_rtval = $script:pavkey[$node].rtval
          #AV PRODUCT DEFINITIONS
          $i_defupdate = $script:pavkey[$node].defupdate
          $i_defupdateval = $script:pavkey[$node].defupdateval
          #AV PRODUCT TAMPER PROTECTION
          $i_tamper = $script:pavkey[$node].tamper
          $i_tamperval = $script:pavkey[$node].tamperval
          #AV PENDING REBOOT
          if ($env:i_PAV -match "Sophos") {
            $i_reboot = $script:pavkey[$node].reboot
            $i_rebootval1 = $script:pavkey[$node].rebootval1
            $i_rebootval2 = $script:pavkey[$node].rebootval2
          }
          #AV PRODUCT SCANS
          $i_scan = $script:pavkey[$node].scan
          $i_scantype = $script:pavkey[$node].scantype
          $i_scanval = $script:pavkey[$node].scanval
          #AV PRODUCT ALERTS
          $i_alert = $script:pavkey[$node].alert
          $i_alertval = $script:pavkey[$node].alertval
          #AV PRODUCT INFECTIONS
          $i_infect = $script:pavkey[$node].infect
          $i_infectval = $script:pavkey[$node].infectval
          #AV PRODUCT THREATS
          $i_threat = $script:pavkey[$node].threat
          #GET PRIMARY AV PRODUCT VERSION VIA REGISTRY
          try {
            $script:diag += "Reading : -path 'HKLM:$($i_verkey)' -name '$($i_verval)'`r`n"
            write-host "Reading : -path 'HKLM:$($i_verkey)' -name '$($i_verval)'" -foregroundcolor yellow
            $script:o_AVVersion = get-itemproperty -path "HKLM:$($i_verkey)" -name "$($i_verval)" -erroraction stop
          } catch {
            $script:diag += "Could not validate Registry data : -path 'HKLM:$($i_verkey)' -name '$($i_verval)'`r`n$($_.scriptstacktrace)`r`n$($_)`r`n"
            write-host "Could not validate Registry data : -path 'HKLM:$($i_verkey)' -name '$($i_verval)'" -foregroundcolor red
            $script:o_AVVersion = "."
            write-host $_.scriptstacktrace
            write-host $_
          }
          $script:o_AVVersion = "$($script:o_AVVersion.$i_verval)"
          #GET PRIMARY AV PRODUCT COMPONENT VERSIONS
          $o_compver = "Core Version : $($script:o_AVVersion)`r`n"
          try {
            $script:diag += "Reading : -path 'HKLM:$($i_compverkey)'`r`n"
            write-host "Reading : -path 'HKLM:$($i_compverkey)'" -foregroundcolor yellow
            if ($env:i_PAV -match "Sophos") {                                                       #SOPHOS COMPONENT VERSIONS
              $compverkey = get-childitem -path "HKLM:$($i_compverkey)" -erroraction silentlycontinue
              foreach ($component in $compverkey) {
                if (($component -ne $null) -and ($component -ne "")) {
                  #write-host "Reading -path HKLM:$i_compverkey$($component.PSChildName)"
                  $longname = get-itemproperty -path "HKLM:$($i_compverkey)$($component.PSChildName)" -name "LongName" -erroraction silentlycontinue
                  $installver = get-itemproperty -path "HKLM:$($i_compverkey)$($component.PSChildName)" -name "InstalledVersion" -erroraction silentlycontinue
                  Pop-Components $script:compkey $($longname.LongName) $($installver.InstalledVersion)
                  #$o_compver += "$($longname.LongName) Version : $($installver.InstalledVersion)`r`n"
                }
              }
              $sort = $script:compkey.GetEnumerator() | sort -Property name
              foreach ($component in $sort) {
                $o_compver += "$($component.name) Version : $($component.value)`r`n"
              }
            } elseif ($env:i_PAV -match "Trend Micro") {                                                #CURSED TREND MICRO
              $compverkey = get-itemproperty -path "HKLM:$($i_compverkey)" -name "$($i_compverval)" -erroraction silentlycontinue
              $compverkey = $compverkey.$i_compverval.split("/")
            }
          } catch {
            if ($env:i_PAV -match "Sophos") {
              write-host "Could not validate Registry data : 'HKLM:$($i_compverkey)' for '$($component.PSChildName)'" -foregroundcolor red
            } elseif ($env:i_PAV -notmatch "Sophos") {
              write-host "Could not validate Registry data : 'HKLM:$($i_compverkey)' for '$($avs[$av].display)'" -foregroundcolor red
            }
            $o_compver = "Components : N/A`r`n"
            write-host $_.scriptstacktrace
            write-host $_
          }
          #GET AV PRODUCT UPDATE SOURCE
          try {
            $script:diag += "Reading : -path 'HKLM:$($i_source)' -name '$($i_sourceval)'`r`n"
            write-host "Reading : -path 'HKLM:$($i_source)' -name '$($i_sourceval)'" -foregroundcolor yellow
            $sourcekey = get-itemproperty -path "HKLM:$($i_source)" -name "$($i_sourceval)" -erroraction stop
            $script:o_AVStatus = "Update Source : $($sourcekey.$i_sourceval)`r`n"
          } catch {
            $script:diag += "Could not validate Registry data : -path 'HKLM:$($i_source)' -name '$($i_sourceval)'`r`n$($_.scriptstacktrace)`r`n$($_)`r`n"
            write-host "Could not validate Registry data : -path 'HKLM:$($i_source)' -name '$($i_sourceval)'" -foregroundcolor red
            $script:o_AVStatus = "Update Source : Unknown`r`n"
            write-host $_.scriptstacktrace
            write-host $_
          }
          #GET PRIMARY AV PRODUCT STATUS VIA REGISTRY
          $updWARN = $false
          #TREND MICRO'S 'ClientUpgradeStatus' VALUES FOUND UNDER THE FOLLOWING REG KEYS HAVE BEEN CONFIRMED TO BE ENTIRELY UNRELIABLE THROUGH MULTIPLE TESTS ACROSS MULTIPLE DEVICES
          # 'HKLM\SOFTWARE\TrendMicro\PC-cillinNTCorp\CurrentVersion\Misc.\'
          # 'HKLM\SOFTWARE\TrendMicro\PC-cillinNTCorp\CurrentVersion\HostedAgent\RUpdate\'
          #AND UNSURPRISINGLY TREND MICRO SUPPORT WAS UNABLE / UNWILLING TO PROVIDE ADDITIONAL GUIDANCE ABOUT KEYS CURRENTLY IN USE AND THE POSSIBLE VALUES THAT COULD BE MONITORED
          #FURTHER TESTING IS WARRANTED TO MONITOR KEY CHANGES WHEN THEY OCCUR; THE ADDITIONAL KEY VALUES FOUND AT THE FOLLOWING LOCATIONS COULD PROVIDE  MORE DETAILS
          # 'HKLM\SOFTWARE\WOW6432Node\TrendMicro\PC-cillinNTCorp\CurrentVersion\HostedAgent\RUpdate\IsClientUpgradeFailed=dword:00000000
          # 'HKLM\SOFTWARE\WOW6432Node\TrendMicro\PC-cillinNTCorp\CurrentVersion\HostedAgent\RUpdate\ClientUpgradeStatus=dword:00000000
          # 'HKLM\SOFTWARE\WOW6432Node\TrendMicro\PC-cillinNTCorp\CurrentVersion\Misc.\ClientUpgradeStatus=dword:00000000
          # 'HKLM\SOFTWARE\WOW6432Node\TrendMicro\PC-cillinNTCorp\CurrentVersion\Misc.\UpdateAgent=dword:00000000
          # 'HKLM\SOFTWARE\WOW6432Node\TrendMicro\PC-cillinNTCorp\CurrentVersion\Misc.\UpdateOngoing=dword:00000000
          # 'HKLM\SOFTWARE\WOW6432Node\TrendMicro\PC-cillinNTCorp\CurrentVersion\Misc.\Updating=dword:00000000
          if ($env:i_PAV -notmatch "Trend Micro") {                                                     #HANDLE ALL AV PRODUCTS EXCEPT TREND MICRO
            try {
              $script:diag += "Reading : -path 'HKLM:$($i_statkey)' -name '$($i_statval)'`r`n"
              write-host "Reading : -path 'HKLM:$($i_statkey)' -name '$($i_statval)'" -foregroundcolor yellow
              $statkey = get-itemproperty -path "HKLM:$($i_statkey)" -name "$($i_statval)" -erroraction stop
              #INTERPRET 'AVSTATUS' BASED ON ANY AV PRODUCT VALUE REPRESENTATION
              if ($script:zUpgrade -contains $avs[$av].display) {                                     #AV PRODUCTS TREATING '0' AS 'UPTODATE'
                $script:diag += "$($avs[$av].display) reports '$($statkey.$i_statval)' for 'Up-To-Date' (Expected : '0')`r`n"
                write-host "$($avs[$av].display) reports '$($statkey.$i_statval)' for 'Up-To-Date' (Expected : '0')" -foregroundcolor yellow
                if ($statkey.$i_statval -eq "0") {
                  $script:o_AVStatus = "Up-to-Date : $($true) (REG Check)`r`n"
                } else {
                  $updWARN = $true
                  $script:o_AVStatus = "Up-to-Date : $($false) (REG Check)`r`n"
                }
              } elseif ($script:zUpgrade -notcontains $avs[$av].display) {                            #AV PRODUCTS TREATING '1' AS 'UPTODATE'
                $script:diag += "$($avs[$av].display) reports '$($statkey.$i_statval)' for 'Up-To-Date' (Expected : '1')`r`n"
                write-host "$($avs[$av].display) reports '$($statkey.$i_statval)' for 'Up-To-Date' (Expected : '1')" -foregroundcolor yellow
                if ($statkey.$i_statval -eq "1") {
                  $script:o_AVStatus = "Up-to-Date : $($true) (REG Check)`r`n"
                } else {
                  $updWARN = $true
                  $script:o_AVStatus = "Up-to-Date : $($false) (REG Check)`r`n"
                }
              }
            } catch {
              $updWARN = $true
              $script:diag += "Could not validate Registry data : -path 'HKLM:$($i_statkey)' -name '$($i_statval)'`r`n$($_.scriptstacktrace)`r`n$($_)`r`n"
              write-host "Could not validate Registry data : -path 'HKLM:$($i_statkey)' -name '$($i_statval)'" -foregroundcolor red
              $script:o_AVStatus = "Up-to-Date : Unknown (REG Check)`r`n"
              Pop-Warnings $script:avwarn $($avs[$av].display) "$($script:o_AVStatus)`r`n"
              write-host $_.scriptstacktrace
              write-host $_
            }
          } elseif ($env:i_PAV -match "Trend Micro") {                                                  #HANDLE TREND MICRO AV PRODUCT
            try {
              write-host "'Trend Micro' Detected : Reading : -path 'HKLM:$($i_vckey)' -name '$($i_vcval)'" -foregroundcolor yellow
              $vckey = get-itemproperty -path "HKLM:$($i_vckey)" -name "$($i_vcval)" -erroraction stop
              write-host "$($avs[$av].display) reports '$($script:o_AVVersion)' for 'Up-To-Date' (Expected : '$($compverkey[0])')" -foregroundcolor yellow
              write-host "$($avs[$av].display) reports '$($vckey.$i_vcval)' for 'Up-To-Date' (Expected : '$($compverkey[1])')" -foregroundcolor yellow
              if (([version]$($script:o_AVVersion) -ge [version]$($compverkey[0])) -and 
                ([version]$($vckey.$i_vcval) -ge [version]$($compverkey[1]))) {
                  $script:o_AVStatus = "Up-to-Date : $($true) (REG Check)`r`n"
              } elseif (([version]$($script:o_AVVersion) -lt [version]$($compverkey[0])) -or 
                ([version]$($vckey.$i_vcval) -lt [version]$($compverkey[1]))) {
                  $script:o_AVStatus = "Up-to-Date : $($false) (REG Check)`r`n"
              }
              $script:o_AVStatus += "Core Version : $($script:o_AVVersion) - Expected : '$($compverkey[0])'`r`n"
              $script:o_AVStatus += "VC Version : $($vckey.$i_vcval) - Expected : '$($compverkey[1])'`r`n"
              $o_compver += "VC Version : $($vckey.$i_vcval)`r`n"
            } catch {
              write-host "Could not validate Registry data : -path 'HKLM:$($i_vckey)' -name '$($i_vcval)'" -foregroundcolor red
              $script:o_AVStatus = "Up-to-Date : Unknown (REG Check)`r`n"
                                            
              write-host $_.scriptstacktrace
              write-host $_
            }
          }
          #GET PRIMARY AV PRODUCT LAST UPDATE TIMESTAMP VIA REGISTRY
          try {
            $script:diag += "Reading : -path 'HKLM:$($i_update)' -name '$($i_updateval)'`r`n"
            write-host "Reading : -path 'HKLM:$($i_update)' -name '$($i_updateval)'" -foregroundcolor yellow
            $updatekey = get-itemproperty -path "HKLM:$($i_update)" -name "$($i_updateval)" -erroraction stop
            if ($avs[$av].display -match "Windows Defender") {                                      #WINDOWS DEFENDER LAST UPDATE TIMESTAMP
              $Int64Value = [System.BitConverter]::ToInt64($updatekey.$i_updateval, 0)
              $time = [DateTime]::FromFileTime($Int64Value)
              $update = Get-Date($time)
              $script:o_AVStatus += "Last Major Update : $(Get-EpochDate($($update))("sec"))`r`n"
              $age = new-timespan -start $update -end (Get-Date)
            } elseif ($avs[$av].display -notmatch "Windows Defender") {                             #ALL OTHER AV LAST UPDATE TIMESTAMP
              if ($avs[$av].display -match "Symantec") {                                            #SYMANTEC AV UPDATE TIMESTAMP
                $script:o_AVStatus += "Last Major Update : $(Get-EpochDate($($updatekey.$i_updateval))("msec"))`r`n"
                $age = new-timespan -start (Get-EpochDate($updatekey.$i_updateval)("msec")) -end (Get-Date)
              } elseif ($avs[$av].display -notmatch "Symantec") {                                   #ALL OTHER AV LAST UPDATE TIMESTAMP
                $script:o_AVStatus += "Last Major Update : $(Get-EpochDate($($updatekey.$i_updateval))("sec"))`r`n"
                $age = new-timespan -start (Get-EpochDate($updatekey.$i_updateval)("sec")) -end (Get-Date)
              }
            }
            $script:o_AVStatus += "Days Since Update (DD:HH:MM) : $($age.tostring("dd\:hh\:mm"))`r`n"
          } catch {
            $updWARN = $true
            $script:diag += "Could not validate Registry data : -path 'HKLM:$($i_update)' -name '$($i_updateval)'`r`n$($_.scriptstacktrace)`r`n$($_)`r`n"
            write-host "Could not validate Registry data : -path 'HKLM:$($i_update)' -name '$($i_updateval)'" -foregroundcolor red
            $script:o_AVStatus += "Last Major Update : N/A`r`n"
            $script:o_AVStatus += "Days Since Update (DD:HH:MM) : N/A`r`n"
            write-host $_.scriptstacktrace
            write-host $_
          }
          if ($updWARN) {
            $updWARN = $false
            $script:blnWARN = $true
            Pop-Warnings $script:avwarn $($avs[$av].display) "$($script:o_AVStatus)`r`n"
          }
          #GET PRIMARY AV PRODUCT REAL-TIME SCANNING
          $rtWARN = $false
          try {
            $script:diag += "Reading : -path 'HKLM:$($i_rtkey)' -name '$($i_rtval)'`r`n"
            write-host "Reading : -path 'HKLM:$($i_rtkey)' -name '$($i_rtval)'" -foregroundcolor yellow
            $rtkey = get-itemproperty -path "HKLM:$($i_rtkey)" -name "$($i_rtval)" -erroraction stop
            try {
              $rtkey = get-itemproperty -path "HKLM:$($i_rtkey)" -name "$($i_rtval)" -erroraction stop
              if ($avs[$av].display -match "Windows Defender") {
                try {
                  write-host "Windows Defender Legacy '$($i_rtval)' Key Found : Checking for 'DisableRealtimeMonitoring' Key"
                  $script:diag += "Windows Defender Legacy '$($i_rtval)' Key Found : Checking for 'DisableRealtimeMonitoring' Key`r`n"
                  $rtkey = get-itemproperty -path "HKLM:$($i_rtkey)" -name "DisableRealtimeMonitoring" -erroraction stop
                  $rtkey | Add-Member -MemberType NoteProperty -Name "$($i_rtval)" -Value "$($rtkey.DisableRealtimeMonitoring)" -force
                } catch {
                  write-host "Windows Defender 'DisableRealtimeMonitoring' Key Not Found"
                  $script:diag += "Windows Defender 'DisableRealtimeMonitoring' Key Not Found`r`n"
                }
              }
            } catch {
              if ($avs[$av].display -match "Windows Defender") {
                try {
                  write-host "Windows Defender '$($i_rtval)' Key Not Found : Checking for 'DisableRealtimeMonitoring' Key"
                  $script:diag += "Windows Defender Legacy '$($i_rtval)' Key Found : Checking for 'DisableRealtimeMonitoring' Key`r`n"
                  $rtkey = get-itemproperty -path "HKLM:$($regRealTime)" -name "DisableRealtimeMonitoring" -erroraction stop
                  $rtkey | Add-Member -MemberType NoteProperty -Name "$($i_rtval)" -Value "$($rtkey.DisableRealtimeMonitoring)" -force
                } catch {
                  write-host "Windows Defender 'DisableRealtimeMonitoring' Key Not Found"
                  $script:diag += "Windows Defender 'DisableRealtimeMonitoring' Key Not Found`r`n"
                }
              }
            }
            $script:o_RTstate = "$($rtkey.$i_rtval)"
            #INTERPRET 'REAL-TIME SCANNING' STATUS BASED ON ANY AV PRODUCT VALUE REPRESENTATION
            if ($script:zRealTime -contains $avs[$av].display) {                                    #AV PRODUCTS TREATING '0' AS 'ENABLED' FOR 'REAL-TIME SCANNING'
              $script:diag += "$($avs[$av].display) reports '$($rtkey.$i_rtval)' for 'Real-Time Scanning' (Expected : '0')`r`n"
              write-host "$($avs[$av].display) reports '$($rtkey.$i_rtval)' for 'Real-Time Scanning' (Expected : '0')" -foregroundcolor yellow
              if ($rtkey.$i_rtval -eq 0) {
                $script:o_RTstate = "Enabled (REG Check)`r`n"
              } elseif ($rtkey.$i_rtval -eq 1) {
                $rtWARN = $true
                $script:o_RTstate = "Disabled (REG Check)`r`n"
              } else {
                $rtWARN = $true
                $script:o_RTstate = "Unknown (REG Check)`r`n"
              }
            } elseif ($script:zRealTime -notcontains $avs[$av].display) {                           #AV PRODUCTS TREATING '1' AS 'ENABLED' FOR 'REAL-TIME SCANNING'
              $script:diag += "$($avs[$av].display) reports '$($rtkey.$i_rtval)' for 'Real-Time Scanning' (Expected : '1')`r`n"
              write-host "$($avs[$av].display) reports '$($rtkey.$i_rtval)' for 'Real-Time Scanning' (Expected : '1')" -foregroundcolor yellow
              if ($rtkey.$i_rtval -eq 1) {
                $script:o_RTstate = "Enabled (REG Check)`r`n"
              } elseif ($rtkey.$i_rtval -eq 0) {
                $rtWARN = $true
                $script:o_RTstate = "Disabled (REG Check)`r`n"
              } else {
                $rtWARN = $true
                $script:o_RTstate = "Unknown (REG Check)`r`n"
              }
            }
          } catch {
            $rtWARN = $true
            $script:diag += "Could not validate Registry data : -path 'HKLM:$($i_rtkey)' -name '$($i_rtval)'`r`n$($_.scriptstacktrace)`r`n$($_)`r`n"
            write-host "Could not validate Registry data : -path 'HKLM:$($i_rtkey)' -name '$($i_rtval)'" -foregroundcolor red
            $script:o_RTstate = "N/A (REG Check)`r`n"
            write-host $_.scriptstacktrace
            write-host $_
          }
          $script:o_AVStatus += "Real-Time Scanning : $($script:o_RTstate)"
          if (($env:i_PAV -match "Sophos") -and ($script:o_AVVersion -match "\d{4}\.\d\.\d\.\d+")) {
            $script:diag += "SOPHOS INTERCEPT X v$($script:o_AVVersion) : DISABLE REAL-TIME WARNINGS`r`n"
            write-host "SOPHOS INTERCEPT X v$($script:o_AVVersion) : DISABLE REAL-TIME WARNINGS"
            $rtWARN = $false
          }
          if ($rtWARN) {
            $rtWARN = $false
            $script:blnWARN = $true
            Pop-Warnings $script:avwarn $($avs[$av].display) "Real-Time Scanning : $($script:o_RTstate)`r`n"
          }
          #GET PRIMARY AV PRODUCT TAMPER PROTECTION STATUS
          $tamperWARN = $false
          try {
            if ($avs[$av].display -notmatch "Sophos Intercept X") {
              $script:diag += "Reading : -path 'HKLM:$($i_tamper)' -name '$($i_tamperval)'`r`n"
              write-host "Reading : -path 'HKLM:$($i_tamper)' -name '$($i_tamperval)'" -foregroundcolor yellow
              $tamperkey = get-itemproperty -path "HKLM:$($i_tamper)" -name "$($i_tamperval)" -erroraction stop
              $tval = "$($tamperkey.$i_tamperval)"
            } elseif ($avs[$av].display -match "Sophos Intercept X") {
              $script:diag += "Reading : -path 'HKLM:$($i_tamper)' -name '$($i_tamperval)'`r`n"
              write-host "Reading : -path 'HKLM:$($i_tamper)' -name '$($i_tamperval)'" -foregroundcolor yellow
              $tamperkey = get-childitem -path "HKLM:$($i_tamper)" -erroraction stop
              foreach ($tkey in $tamperkey) {
                write-host "HKLM:$($i_tamper)$($tkey.PSChildName)\tamper_protection -name $($i_tamperval)"
                $tamperkey = get-itemproperty -path "HKLM:$($i_tamper)$($tkey.PSChildName)\tamper_protection" -name "$($i_tamperval)" -erroraction stop
                $tval = "$($tamperkey.$i_tamperval)"
                break
              }
            }
            #INTERPRET 'TAMPER PROTECTION' STATUS BASED ON ANY AV PRODUCT VALUE REPRESENTATION
            if ($avs[$av].display -match "Windows Defender") {                                      #WINDOWS DEFENDER TREATS '5' AS 'ENABLED' FOR 'TAMPER PROTECTION'
              $script:diag += "$($avs[$av].display) reports '$($tval)' for 'Tamper Protection' (Expected : '5')`r`n"
              write-host "$($avs[$av].display) reports '$($tval)' for 'Tamper Protection' (Expected : '5')" -foregroundcolor yellow
              if ($tval -eq 5) {
                $tamper = "$($true) (REG Check)"
              } elseif ($tval -le 4) {
                $tamperWARN = $true
                $tamper = "$($false) (REG Check)"
              } else {
                $tamperWARN = $true
                $tamper = "Unknown (REG Check)"
              }
            } elseif ($script:zTamper -contains $avs[$av].display) {                                #AV PRODUCTS TREATING '0' AS 'ENABLED' FOR 'TAMPER PROTECTION'
              $script:diag += "$($avs[$av].display) reports '$($tval)' for 'Tamper Protection' (Expected : '0')`r`n"
              write-host "$($avs[$av].display) reports '$($tval)' for 'Tamper Protection' (Expected : '0')" -foregroundcolor yellow
              if ($tval -eq 0) {
                $tamper = "$($true) (REG Check)"
              } elseif ($tval -eq 1) {
                $tamperWARN = $true
                $tamper = "$($false) (REG Check)"
              } else {
                $tamperWARN = $true
                $tamper = "Unknown (REG Check)"
              }
            } elseif ($script:zTamper -notcontains $avs[$av].display) {                             #AV PRODUCTS TREATING '1' AS 'ENABLED' FOR 'TAMPER PROTECTION'
              $script:diag += "$($avs[$av].display) reports '$($tval)' for 'Tamper Protection' (Expected : '1')`r`n"
              write-host "$($avs[$av].display) reports '$($tval)' for 'Tamper Protection' (Expected : '1')" -foregroundcolor yellow
              if ($tval -eq 1) {
                $tamper = "$($true) (REG Check)"
              } elseif ($tval -eq 0) {
                $tamperWARN = $true
                $tamper = "$($false) (REG Check)"
              } else {
                $tamperWARN = $true
                $tamper = "Unknown (REG Check)"
              }
            }
          } catch {
            $tamperWARN = $true
            $script:diag += "Could not validate Registry data : -path 'HKLM:$($i_tamper)' -name '$($i_tamperval)'`r`n$($_.scriptstacktrace)`r`n$($_)`r`n"
            write-host "Could not validate Registry data : -path 'HKLM:$($i_tamper)' -name '$($i_tamperval)'" -foregroundcolor red
            $tamper = "Unknown (REG Check)"
            write-host $_.scriptstacktrace
            write-host $_
          }
          $script:o_AVStatus += "Tamper Protection : $($tamper)`r`n"
          if ($tamperWARN) {
            $tamperWARN = $false
            $script:blnWARN = $true
            Pop-Warnings $script:avwarn $($avs[$av].display) "Tamper Protection : $($tamper)`r`n"
          }
          #GET PRIMARY AV PRODUCT PENDING REBOOT STATUS
          $rebootWARN = $false
          try {
            if ($avs[$av].display -match "Sophos") {
              $script:diag += "Reading : -path 'HKLM:$($i_reboot)' -name '$($i_rebootval1)'`r`n"
              write-host "Reading : -path 'HKLM:$($i_reboot)' -name '$($i_rebootval1)'" -foregroundcolor yellow
              $rebootkey = get-itemproperty -path "HKLM:$($i_reboot)" -name "$($i_rebootval1)" -erroraction stop
              $rval1 = [bool]$rebootkey.$i_rebootval1
              $script:diag += "Reading : -path 'HKLM:$($i_reboot)' -name '$($i_rebootval2)'`r`n"
              write-host "Reading : -path 'HKLM:$($i_reboot)' -name '$($i_rebootval2)'" -foregroundcolor yellow
              $rebootkey = get-itemproperty -path "HKLM:$($i_reboot)" -name "$($i_rebootval2)" -erroraction stop
              $rval2 = [bool]$rebootkey.$i_rebootval2
            } elseif ($avs[$av].display -notmatch "Sophos") {
              #$script:diag += "Reading : -path 'HKLM:$($i_reboot)' -name '$($i_rebootval1)'`r`n"
              #write-host "Reading : -path 'HKLM:$($i_reboot)' -name '$($i_rebootval1)'" -foregroundcolor yellow
              #$rebootkey = get-childitem -path "HKLM:$($i_reboot)" -erroraction stop
              #foreach ($tkey in $rebootkey) {
              #  $rebootkey = get-itemproperty -path "HKLM:$($i_reboot)$($tkey.PSChildName)\tamper_protection" -name "$($i_rebootval1)" -erroraction stop
              #  $tval = "$($rebootkey.$i_rebootval1)"
              #  break
              #}
            }
            #INTERPRET 'PENDING REBOOT' STATUS BASED ON ANY AV PRODUCT VALUE REPRESENTATION
            if ($avs[$av].display -match "Sophos") {                                      #SOPHOS TREATS '0' AS 'NOT REQUIRED' FOR 'REBOOT REQUIRED'
              $script:diag += "$($avs[$av].display) reports '$($rval1)' for 'Reboot Required' (Expected : '0')`r`n"
              write-host "$($avs[$av].display) reports '$($rval1)' for 'Reboot Required' (Expected : '0')" -foregroundcolor yellow
              $script:diag += "$($avs[$av].display) reports '$($rval2)' for 'Urgent Reboot Required' (Expected : '0')`r`n"
              write-host "$($avs[$av].display) reports '$($rval2)' for 'Urgent Reboot Required' (Expected : '0')" -foregroundcolor yellow
              if ((-not $rval1) -and (-not $rval2)) {
                $reboot = "$($false) (REG Check)"
              } elseif ($rval -or $rval2) {
                $rebootWARN = $true
                $reboot = "$($true) (REG Check)"
              } else {
                $rebootWARN = $true
                $reboot = "Unknown (REG Check)"
              }
            }
          } catch {
            $rebootWARN = $false
            $script:diag += "Could not validate Registry data : -path 'HKLM:$($i_reboot)' -name '$($i_rebootval1)'`r`n$($_.scriptstacktrace)`r`n$($_)`r`n"
            write-host "Could not validate Registry data : -path 'HKLM:$($i_reboot)' -name '$($i_rebootval1)'" -foregroundcolor red
            $reboot = "Unknown (REG Check)"
            write-host $_.scriptstacktrace
            write-host $_
          }
          $script:o_AVStatus += "Reboot Required : $($reboot)`r`nUrgent Reboot Required : $($rval2) (REG Check)`r`n"
          if ($rebootWARN) {
            $rebootWARN = $false
            $script:blnWARN = $true
            Pop-Warnings $script:avwarn $($avs[$av].display) "Reboot Required : $($reboot) - Urgent Reboot Required : $($rval2) (REG Check)`r`n"
          }
          #GET PRIMARY AV PRODUCT LAST SCAN DETAILS
          $lastage = 0
          $scanWARN = $false
          if ($avs[$av].display -match "Windows Defender") {                                        #WINDOWS DEFENDER SCAN DATA
            try {
              $script:diag += "Reading : -path 'HKLM:$($i_scan)' -name '$($i_scantype)'`r`n"
              write-host "Reading : -path 'HKLM:$($i_scan)' -name '$($i_scantype)'" -foregroundcolor yellow
              $typekey = get-itemproperty -path "HKLM:$($i_scan)" -name "$($i_scantype)" -erroraction stop
              if ($typekey.$i_scantype -eq 1) {
                $scans += "Scan Type : Quick Scan (REG Check)`r`n"
              } elseif ($typekey.$i_scantype -eq 2) {
                $scans += "Scan Type : Full Scan (REG Check)`r`n"
              }
            } catch {
              $scanWARN = $true
              $script:diag += "Could not validate Registry data : -path 'HKLM:$($i_scan)' -name '$($i_scantype)'`r`n$($_.scriptstacktrace)`r`n$($_)`r`n"
              write-host "Could not validate Registry data : -path 'HKLM:$($i_scan)' -name '$($i_scantype)'" -foregroundcolor red
              $scans += "Scan Type : N/A (REG Check)`r`n"
              write-host $_.scriptstacktrace
              write-host $_
            }
            try {
              $script:diag += "Reading : -path 'HKLM:$($i_scan)' -name '$($i_scanval)'`r`n"
              write-host "Reading : -path 'HKLM:$($i_scan)' -name '$($i_scanval)'" -foregroundcolor yellow
              $scankey = get-itemproperty -path "HKLM:$($i_scan)" -name "$($i_scanval)" -erroraction stop
              $Int64Value = [System.BitConverter]::ToInt64($scankey.$i_scanval,0)
              $stime = Get-Date([DateTime]::FromFileTime($Int64Value))
              $lastage = new-timespan -start $stime -end (Get-Date)
              $scans += "Last Scan Time : $($stime) (REG Check)`r`n"
            } catch {
              $scanWARN = $true
              $script:diag += "Could not validate Registry data : -path 'HKLM:$($i_scan)' -name '$($i_scanval)'`r`n$($_.scriptstacktrace)`r`n$($_)`r`n"
              write-host "Could not validate Registry data : -path 'HKLM:$($i_scan)' -name '$($i_scanval)'" -foregroundcolor red
              $scans += "Last Scan Time : N/A (REG Check)`r`nRecently Scanned : $($false) (REG Check)"
              write-host $_.scriptstacktrace
              write-host $_
            }
          } elseif ($avs[$av].display -notmatch "Windows Defender") {                               #NON-WINDOWS DEFENDER SCAN DATA
            if ($avs[$av].display -match "Sophos") {                                                #SOPHOS SCAN DATA
              try {
                $script:diag += "Reading : -path 'HKLM:$($i_scan)'`r`n"
                write-host "Reading : -path 'HKLM:$($i_scan)'" -foregroundcolor yellow
                if ($avs[$av].display -match "Sophos Intercept X") {
                  $scankey = get-itemproperty -path "HKLM:$($i_scan)" -name "$($i_scanval)" -erroraction stop
                  $stime = [DateTime]::FromFileTime($scankey.LastSystemScanTime)
                  #$stime = [datetime]::ParseExact($scankey.$i_scanval,'yyyyMMddTHHmmssK',[Globalization.CultureInfo]::InvariantCulture)
                  $scans += "Scan Type : On-Demand System Scan (REG Check)`r`nLast Scan Time : $($stime) (REG Check)`r`n"
                  $lastage = new-timespan -start $stime -end (Get-Date)
                } elseif ($avs[$av].display -notmatch "Sophos Intercept X") {
                  $scankey = get-itemproperty -path "HKLM:$($i_scan)" -erroraction stop
                  foreach ($scan in $scankey.psobject.Properties) {
                    if (($scan.name -notlike "PS*") -and ($scan.name -notlike "(default)")) {
                      $scans += "Scan Type : $($scan.name) (REG Check)`r`nLast Scan Time : $(Get-EpochDate($($scan.value))("sec")) (REG Check)`r`n"
                      $age = new-timespan -start (Get-EpochDate($scan.value)("sec")) -end (Get-Date)
                      if (($lastage -eq 0) -or ($age -lt $lastage)) {
                        $lastage = $age
                      }
                    }
                  }
                }
              } catch {
                $scanWARN = $true
                write-host "Could not validate Registry data : -path 'HKLM:$($i_scan)'" -foregroundcolor red
                $scans = "Scan Type : N/A (REG Check)`r`nLast Scan Time : N/A (REG Check)`r`nRecently Scanned : $($false) (REG Check)"
                write-host $_.scriptstacktrace
                write-host $_
              }
            } elseif ($avs[$av].display -match "Symantec") {                                        #SYMANTEC SCAN DATA
              try {
                $script:diag += "Reading : -path 'HKLM:$($i_scan)' -name '$($i_scanval)'`r`n"
                write-host "Reading : -path 'HKLM:$($i_scan)' -name '$($i_scanval)'" -foregroundcolor yellow
                $scankey = get-itemproperty -path "HKLM:$($i_scan)" -name "$($i_scanval)" -erroraction stop
                $scans += "Scan Type : N/A (REG Check)`r`nLast Scan Time : $(Get-Date($($scankey.$i_scanval))) (REG Check)`r`n"
                $lastage = new-timespan -start ($scankey.$i_scanval) -end (Get-Date)
              } catch {
                $scanWARN = $true
                $script:diag += "Could not validate Registry data : -path 'HKLM:$($i_scan)' -name '$($i_scanval)'`r`n$($_.scriptstacktrace)`r`n$($_)`r`n"
                write-host "Could not validate Registry data : -path 'HKLM:$($i_scan)' -name '$($i_scanval)'" -foregroundcolor red
                $scans = "Scan Type : N/A (REG Check)`r`nLast Scan Time : N/A`r`nRecently Scanned : $($false) (REG Check)"
                write-host $_.scriptstacktrace
                write-host $_
              }
            }
          }
          if ($lastage -ne 0) {
            $time1 = New-TimeSpan -days 7
            if ($lastage.compareto($time1) -le 0) {
              $scanWARN = $false
              $scans += "Recently Scanned : $($true) (REG Check)"
            } elseif ($lastage.compareto($time1) -gt 0) {
              $scanWARN = $true
              $scans += "Recently Scanned : $($false) (REG Check)"
            }
          }
          $script:o_AVStatus += "$($scans)"
          if ($scanWARN) {
            $scanWARN = $false
            $script:blnWARN = $true
            Pop-Warnings $script:avwarn $($avs[$av].display) "$($scans)`r`n"
          }
          #GET PRIMARY AV PRODUCT DEFINITIONS / SIGNATURES / PATTERN
          $defWARN = $false
          if ($script:blnWMI) {
            #will still return if it is unknown, etc. if it is unknown look at the code it returns, then look up the status and add it above
            Get-AVState $script:pskey $avs[$av].stat
            $script:o_DefStatus = "Definition Status : $($script:defstatus)`r`n"
          } elseif (-not $script:blnWMI) {
            $script:o_DefStatus = "Definition Status : N/A (WMI Check)`r`n"
          }
          try {
            $time1 = New-TimeSpan -days 1
            $script:diag += "Reading : -path 'HKLM:$($i_defupdate)' -name '$($i_defupdateval)'`r`n"
            write-host "Reading : -path 'HKLM:$($i_defupdate)' -name '$($i_defupdateval)'" -foregroundcolor yellow
            $defkey = get-itemproperty -path "HKLM:$($i_defupdate)" -name "$($i_defupdateval)" -erroraction stop
            if ($avs[$av].display -match "Windows Defender") {                                      #WINDOWS DEFENDER DEFINITION UPDATE TIMESTAMP
              $Int64Value = [System.BitConverter]::ToInt64($defkey.$i_defupdateval,0)
              $time = [DateTime]::FromFileTime($Int64Value)
              $update = Get-Date($time)
              $age = new-timespan -start $update -end (Get-Date)
              if ($age.compareto($time1) -le 0) {
                $script:o_DefStatus += "Definition Status : Up to date (REG Check)`r`n"
              } elseif ($age.compareto($time1) -gt 0) {
                $defWARN = $true
                $script:o_DefStatus += "Definition Status : Out of date (REG Check)`r`n"
              }
              $script:o_DefStatus += "Last Definition Update : $($update)`r`n"
            } elseif ($avs[$av].display -notmatch "Windows Defender") {                             #ALL OTHER AV DEFINITION UPDATE TIMESTAMP
              if ($avs[$av].display -match "Symantec") {                                            #SYMANTEC DEFINITION UPDATE TIMESTAMP
                $age = new-timespan -start ($defkey.$i_defupdateval) -end (Get-Date)
                if ($age.compareto($time1) -le 0) {
                  $script:o_DefStatus += "Definition Status : Up to date (REG Check)`r`n"
                } elseif ($age.compareto($time1) -gt 0) {
                  $defWARN = $true
                  $script:o_DefStatus += "Definition Status : Out of date (REG Check)`r`n"
                }
                $script:o_DefStatus += "Last Definition Update : $($defkey.$i_defupdateval)`r`n"
              } elseif ($avs[$av].display -notmatch "Symantec") {                                   #NON-SYMANTEC DEFINITION UPDATE TIMESTAMP
                $age = new-timespan -start (Get-EpochDate($defkey.$i_defupdateval)("sec")) -end (Get-Date)
                if ($age.compareto($time1) -le 0) {
                  $script:o_DefStatus += "Definition Status : Up to date (REG Check)`r`n"
                } elseif ($age.compareto($time1) -gt 0) {
                  $defWARN = $true
                  $script:o_DefStatus += "Definition Status : Out of date (REG Check)`r`n"
                }
                $script:o_DefStatus += "Last Definition Update : $(Get-EpochDate($($defkey.$i_defupdateval))("sec"))`r`n"
              }
            }
            $script:o_DefStatus += "Definition Age (DD:HH:MM) : $($age.tostring("dd\:hh\:mm"))"
          } catch {
            $defWARN = $true
            $script:diag += "Could not validate Registry data : -path 'HKLM:$($i_defupdate)' -name '$($i_defupdateval)'`r`n$($_.scriptstacktrace)`r`n$($_)`r`n"
            write-host "Could not validate Registry data : -path 'HKLM:$($i_defupdate)' -name '$($i_defupdateval)'" -foregroundcolor red
            $script:o_DefStatus += "Definition Status : Out of date (REG Check)`r`n"
            $script:o_DefStatus += "Last Definition Update : N/A`r`n"
            $script:o_DefStatus += "Definition Age (DD:HH:MM) : N/A"
            write-host $_.scriptstacktrace
            write-host $_
          }
          if ($defWARN) {
            $defWARN = $false
            $script:blnWARN = $true
            Pop-Warnings $script:avwarn $($avs[$av].display) "$($script:o_DefStatus)`r`n"
          }
          #GET PRIMARY AV PRODUCT DETECTED ALERTS VIA REGISTRY
          if ($script:zNoAlert -notcontains $env:i_PAV) {
            try {
              if ($env:i_PAV -match "Sophos") {
                $script:diag += "Reading : -path 'HKLM:$($i_alert)'`r`n"
                write-host "Reading : -path 'HKLM:$($i_alert)'" -foregroundcolor yellow
                $alertkey = get-ItemProperty -path "HKLM:$($i_alert)" -erroraction silentlycontinue
                foreach ($alert in $alertkey.psobject.Properties) {
                  if (($alert.name -notlike "PS*") -and ($alert.name -notlike "(default)")) {
                    if ($alert.value -eq 0) {
                      $script:o_Infect += "Type - $($alert.name) : $($false)`r`n"
                    } elseif ($alert.value -eq 1) {
                      $script:o_Infect += "Type - $($alert.name) : $($true)`r`n"
                    }
                  }
                }
              }
              # NOT ACTUAL DETECTIONS - SAVE BELOW CODE FOR 'CONFIGURED ALERTS' METRIC
              #elseif ($env:i_PAV -match "Trend Micro") {
              #  if ($script:producttype -eq "Workstation") {
              #    $i_alert += "Client"
              #    write-host "Reading : -path 'HKLM:$i_alert'" -foregroundcolor yellow
              #    $alertkey = get-ItemProperty -path "HKLM:$i_alert" -erroraction silentlycontinue
              #  } elseif (($script:producttype -eq "Server") -or ($script:producttype -eq "DC")) {
              #    $i_alert += "Server"
              #    write-host "Reading : -path 'HKLM:$i_alert'" -foregroundcolor yellow
              #    $alertkey = get-ItemProperty -path "HKLM:$i_alert" -erroraction silentlycontinue
              #  }
              #  foreach ($alert in $alertkey.psobject.Properties) {
              #    if (($alert.name -notlike "PS*") -and ($alert.name -notlike "(default)")) {
              #      if ($alert.value -eq 0) {
              #        $script:o_Infect += "Type - $($alert.name) : $false`r`n"
              #      } elseif ($alert.value -eq 1) {
              #        $script:o_Infect += "Type - $($alert.name) : $true`r`n"
              #      }
              #    }
              #  }
              #}
            } catch {
              $script:diag += "Could not validate Registry data : 'HKLM:$($i_alert)'`r`n$($_.scriptstacktrace)`r`n$($_)`r`n"
              write-host "Could not validate Registry data : 'HKLM:$($i_alert)'" -foregroundcolor red
              $script:o_Infect = "N/A`r`n"
              write-host $_.scriptstacktrace
              write-host $_
            }
          }
          #GET PRIMARY AV PRODUCT DETECTED INFECTIONS VIA REGISTRY
          $infectWARN = $false
          if ($script:zNoInfect -notcontains $env:i_PAV) {
            if ($env:i_PAV -match "Sophos") {                                                       #SOPHOS DETECTED INFECTIONS
              try {
                $script:diag += "Reading : -path 'HKLM:$($i_infect)'`r`n"
                write-host "Reading : -path 'HKLM:$($i_infect)'" -foregroundcolor yellow
                $infectkey = get-ItemProperty -path "HKLM:$($i_infect)" -erroraction silentlycontinue
                foreach ($infect in $infectkey.psobject.Properties) {                               #ENUMERATE EACH DETECTED INFECTION
                  if (($infect.name -notlike "PS*") -and ($infect.name -notlike "(default)")) {
                    if ($infect.value -eq 0) {
                      $script:o_Infect += "Type - $($infect.name) : $($false)`r`n"
                    } elseif ($infect.value -eq 1) {
                      #$infectWARN = $true
                      $script:o_Infect += "Type - $($infect.name) : $($true)`r`n"
                    }
                  }
                }
              } catch {
                #$infectWARN = $true
                $script:diag += "Could not validate Registry data : 'HKLM:$($i_infect)'`r`n$($_.scriptstacktrace)`r`n$($_)`r`n"
                write-host "Could not validate Registry data : 'HKLM:$($i_infect)'" -foregroundcolor red
                $script:o_Infect += "Virus/Malware Present : N/A`r`n"
                write-host $_.scriptstacktrace
                write-host $_
              }
            } elseif ($env:i_PAV -match "Trend Micro") {                                            #TREND MICRO DETECTED INFECTIONS
              try {
                $script:diag += "Reading : -path 'HKLM:$($i_infect)' -name '$($i_infectval)'`r`n"
                write-host "Reading : -path 'HKLM:$($i_infect)' -name '$($i_infectval)'" -foregroundcolor yellow
                $infectkey = get-ItemProperty -path "HKLM:$($i_infect)" -name "$($i_infectval)" -erroraction silentlycontinue
                if ($infectkey.$i_infectval -eq 0) {                                                #NO DETECTED INFECTIONS
                  $script:o_Infect += "Virus/Malware Present : $($false)`r`nVirus/Malware Count : $($infectkey.$i_infectval)`r`n"
                } elseif ($infectkey.$i_infectval -gt 0) {                                          #DETECTED INFECTIONS
                  #$infectWARN = $true
                  $script:o_Infect += "Virus/Malware Present : $($true)`r`nVirus/Malware Count - $($infectkey.$i_infectval)`r`n"
                }
              } catch {
                #$infectWARN = $true
                $script:diag += "Could not validate Registry data : 'HKLM:$($i_infect)' -name '$($i_infectval)'`r`n$($_.scriptstacktrace)`r`n$($_)`r`n"
                write-host "Could not validate Registry data : 'HKLM:$($i_infect)' -name '$($i_infectval)'" -foregroundcolor red
                $script:o_Infect += "Virus/Malware Present : N/A`r`n"
                write-host $_.scriptstacktrace
                write-host $_
              }
            } elseif ($env:i_PAV -match "Symantec") {                                               #SYMANTEC DETECTED INFECTIONS
              try {
                $script:diag += "Reading : -path 'HKLM:$($i_infect)' -name '$($i_infectval)'`r`n"
                write-host "Reading : -path 'HKLM:$($i_infect)' -name '$($i_infectval)'" -foregroundcolor yellow
                $infectkey = get-ItemProperty -path "HKLM:$($i_infect)" -name "$($i_infectval)" -erroraction silentlycontinue
                if ($infectkey.$i_infectval -eq 0) {                                                #NO DETECTED INFECTIONS
                  $script:o_Infect += "Virus/Malware Present : $($false)`r`n"
                } elseif ($infectkey.$i_infectval -gt 0) {                                          #DETECTED INFECTIONS
                  try {
                    #$infectWARN = $true
                    $script:diag += "Reading : -path 'HKLM:$($i_scan)' -name 'WorstInfectionType'`r`n"
                    write-host "Reading : -path 'HKLM:$($i_scan)' -name 'WorstInfectionType'" -foregroundcolor yellow
                    $worstkey = get-ItemProperty -path "HKLM:$($i_scan)" -name "WorstInfectionType" -erroraction silentlycontinue
                    $worst = SEP-Map($worstkey.WorstInfectionType)
                  } catch {
                    #$infectWARN = $true
                    $script:diag += "Could not validate Registry data : 'HKLM:$($i_scan)' -name 'WorstInfectionType'`r`n$($_.scriptstacktrace)`r`n$($_)`r`n"
                    write-host "Could not validate Registry data : 'HKLM:$($i_scan)' -name 'WorstInfectionType'" -foregroundcolor red
                    $worst = "N/A"
                    write-host $_.scriptstacktrace
                    write-host $_
                  }
                  $script:o_Infect += "Virus/Malware Present : $($true)`r`nWorst Infection Type : $($worst)`r`n"
                }
              } catch {
                #$infectWARN = $true
                $script:diag += "Could not validate Registry data : 'HKLM:$($i_infect)' -name '$($i_infectval)'`r`n$($_.scriptstacktrace)`r`n$($_)`r`n"
                write-host "Could not validate Registry data : 'HKLM:$($i_infect)' -name '$($i_infectval)'" -foregroundcolor red
                $script:o_Infect += "Virus/Malware Present : N/A`r`nWorst Infection Type : N/A`r`n"
                write-host $_.scriptstacktrace
                write-host $_
              }
            }
            if ($infectWARN) {
              $infectWARN = $false
              $script:blnWARN = $true
              Pop-Warnings $script:avwarn $($avs[$av].display) "Active Detections :`r`n$($script:o_Infect)`r`n"
            }
          }
          #GET PRIMARY AV PRODUCT DETECTED THREATS VIA REGISTRY
          $threatWARN = $false
          if ($script:zNoThreat -notcontains $env:i_PAV) {
            try {
              $script:diag += "Reading : -path 'HKLM:$($i_threat)'`r`n"
              write-host "Reading : -path 'HKLM:$($i_threat)'" -foregroundcolor yellow
              $threatkey = get-childitem -path "HKLM:$($i_threat)" -erroraction silentlycontinue
              if ($env:i_PAV -match "Sophos") {
                if ($threatkey.count -gt 0) {
                  #$threatWARN = $true
                  foreach ($threat in $threatkey) {
                    $threattype = get-itemproperty -path "HKLM:$($i_threat)\$($threat.PSChildName)\" -name "Type" -erroraction silentlycontinue
                    $threatfile = get-childitem -path "HKLM:$($i_threat)\$($threat.PSChildName)\Files\" -erroraction silentlycontinue
                    $script:o_Threats += "Threat : $($threat.PSChildName) - Type : $($threattype.type) - Path : "
                    foreach ($detection in $threatfile) {
                      try {
                        $threatpath = get-itemproperty -path "HKLM:$($i_threat)\$($threat.PSChildName)\Files\$($threatfile.PSChildName)\" -name "Path" -erroraction silentlycontinue
                        $script:o_Threats += "$($threatpath.path)"
                      } catch {
                        $script:o_Threats += "N/A"
                        write-host $_.scriptstacktrace
                        write-host $_
                      }
                    }
                    $script:o_Threats += "`r`n"
                  }
                } elseif ($threatkey.count -le 0) {
                  $script:o_Threats += "N/A`r`n"
                }
              }
            } catch {
              #$threatWARN = $true
              $script:diag += "Could not validate Registry data : 'HKLM:$($i_threat)'`r`n"
              write-host "Could not validate Registry data : 'HKLM:$($i_threat)'" -foregroundcolor red
              $script:o_Threats = "N/A`r`n"
              write-host $_.scriptstacktrace
              write-host $_
            }
          }
          if ($threatWARN) {
            $threatWARN = $false
            $script:blnWARN = $true
            Pop-Warnings $script:avwarn $($avs[$av].display) "Detected Threats :`r`n$($script:o_Threats)`r`n"
          }
        #SAVE WINDOWS DEFENDER FOR LAST - TO PREVENT SCRIPT CONSIDERING IT 'COMPETITOR AV' WHEN SET AS PRIMARY AV
        } elseif ($avs[$av].display -eq "Windows Defender") {
          $script:o_CompAV += "$($avs[$av].display)`r`n"
          $script:o_CompPath += "$($avs[$av].path)`r`n"
          if ($script:blnWMI) {
            Get-AVState $script:pskey $avs[$av].stat
            $script:o_CompState += "$($avs[$av].display) - Real-Time Scanning : $($script:rtstatus) - Definitions : $($script:defstatus)`r`n"
          } elseif (-not $script:blnWMI) {
            $script:o_CompState += "$($avs[$av].display) - Real-Time Scanning : $($avs[$av].rt) - Definitions : N/A (WMI Check)`r`n"
          } 
        }
      }
    }
  }
}
#OUTPUT
if (($script:o_AVname -match "No AV Product Found") -or ($script:o_AVname -match "Selected AV Product Not Found")) {
  $ccode = "red"
} else {
  $ccode = "green"
}
#DEVICE INFO
$script:diag += "`r`nDevice Info :`r`nDevice : $($script:computername)`r`nOperating System : $($script:OSCaption) ($script:OSVersion)`r`n"
write-host "`r`nDevice Info :" -foregroundcolor yellow
write-host "Device : $($script:computername)" -foregroundcolor $ccode
write-host "Operating System : $($script:OSCaption) ($($script:OSVersion))" -foregroundcolor $ccode
#AV DETAILS
$script:diag += "`r`nAV Details :`r`nAV Display Name : $($script:o_AVname)`r`nAV Path : $($script:o_AVpath)`r`n"
$script:diag += "`r`nAV Status :`r`n$($script:o_AVStatus)`r`n`r`nComponent Versions :`r`n$($o_compver)`r`n"
write-host "`r`nAV Details :" -foregroundcolor yellow
write-host "AV Display Name : $($script:o_AVname)" -foregroundcolor $ccode
write-host "AV Path : $($script:o_AVpath)" -foregroundcolor $ccode
write-host "`r`nAV Status :" -foregroundcolor yellow
write-host "$($script:o_AVStatus)" -foregroundcolor $ccode
write-host "`r`nComponent Versions :" -foregroundcolor yellow
write-host "$($o_compver)" -foregroundcolor $ccode
$script:o_AVStatus += "`r`n`r`n$($o_compver)`r`n"
#REAL-TIME SCANNING & DEFINITIONS
$script:diag += "Definitions :`r`n$($script:o_DefStatus)`r`n"
write-host "Definitions :" -foregroundcolor yellow
write-host "$($script:o_DefStatus)" -foregroundcolor $ccode
#THREATS
$script:diag += "`r`nActive Detections :`r`n$($script:o_Infect)`r`nDetected Threats :`r`n$($script:o_Threats)`r`n"
write-host "`r`nActive Detections :" -foregroundcolor yellow
write-host "$($script:o_Infect)" -foregroundcolor $ccode
write-host "Detected Threats :" -foregroundcolor yellow
write-host "$($script:o_Threats)" -foregroundcolor $ccode
#COMPETITOR AV
$script:diag += "Competitor AV :`r`nAV Conflict : $($script:o_AVcon)`r`n$($script:o_CompAV)`r`n"
$script:diag += "Competitor Path :`r`n$($script:o_CompPath)`r`nCompetitor State :`r`n$($script:o_CompState)"
write-host "Competitor AV :" -foregroundcolor yellow
write-host "AV Conflict : $($script:o_AVcon)" -foregroundcolor $ccode
write-host "$($script:o_CompAV)" -foregroundcolor $ccode
write-host "Competitor Path :" -foregroundcolor yellow
write-host "$($script:o_CompPath)" -foregroundcolor $ccode
write-host "Competitor State :" -foregroundcolor yellow
write-host "$($script:o_CompState)" -foregroundcolor $ccode
$script:diag += "`r`nThe following details failed checks :`r`n"
write-host "The following details failed checks :" -foregroundcolor yellow
#DATTO OUTPUT
foreach ($warn in $script:avwarn.values) {
  $script:diag += "$($warn)`r`n"
  write-host "$($warn)" -foregroundcolor red
}
#Stop script execution time calculation
StopClock
#CLEAR LOGFILE
$null | set-content $logPath -force
"$($script:diag)" | add-content $logPath -force
write-host 'DATTO OUTPUT :'
if ($script:blnWARN) {
  write-DRMMAlert "AV Health : $($env:i_PAV) : Warning"
  write-DRMMDiag "$($script:diag)"
  $script:diag = $null
  exit 1
} elseif (-not $script:blnWARN) {
  write-DRMMAlert "AV Health : $($env:i_PAV) : Healthy"
  write-DRMMDiag "$($script:diag)"
  $script:diag = $null
  exit 0
}
#END SCRIPT
#------------