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
    Version        : 0.2.2 (24 March 2022)
    Creation Date  : 14 December 2021
    Purpose/Change : Provide Primary AV Product Status and Report Possible AV Conflicts
    File Name      : AVHealth_0.2.2.ps1 
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
          Added '$global:ncxml<vendor>' variables for assigning static 'fallback' sources for AV Product XMLs; XMLs should be uploaded to NC Script Repository and URLs updated (Begin Ln164)
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
    Need to obtain version and calculate date timestamps for AV Product updates, Definition updates, and Last Scan - Partially Implemented
    Need to obtain Infection Status and Detected Threats; bonus for timestamps for these metrics - Partially Complete (Sophos - full support; Trend Micro - 'Active Detections Present / Count')
        Do other AVs report individual Threat information in the registry? Sophos does; but if others don't will we be able to use this metric?
        Still need to determine if timestamps are possible for detected threats - Believe this is likely a 'no-go'
    Need to create a 'Get-AVProducts' function and move looped 'detection' code into a function to call - This just isn't priority atm since the code does appear to be detecting multiple AV Products without issue currently
    Trend Micro continues to cause issues with properly evaluating if the core AV Client itself is up to date due to the number of 'duplicate' and inconsistent Registry Keys / Values that clutter their Registry Hive
    
#> 

#REGION ----- DECLARATIONS ----
  #BELOW PARAM() MUST BE COMMENTED OUT FOR USE WITHIN NABLE NCENTRAL RMM
  #UNCOMMENT BELOW PARAM() TO UTILIZE IN CLI
  #Param(
  #  [Parameter(Mandatory=$true)]$i_PAV
  #)
  $global:bitarch = $null
  $global:OSCaption = $null
  $global:OSVersion = $null
  $global:producttype = $null
  $global:computername = $null
  $global:blnWMI = $true
  $global:blnPAV = $false
  $global:blnAVXML = $true
  $global:blnPSXML = $false
  $global:avs = @{}
  $global:pskey = @{}
  $global:pavkey = @{}
  $global:vavkey = @{}
  $global:compkey = @{}
  $global:o_AVname = "Selected AV Product Not Found"
  $global:o_AVVersion = "Selected AV Product Not Found"
  $global:o_AVpath = "Selected AV Product Not Found"
  $global:o_AVStatus = "Selected AV Product Not Found"
  $global:rtstatus = "Unknown"
  $global:o_RTstate = "Unknown"
  $global:defstatus = "Unknown"
  $global:o_DefStatus = "Unknown"
  $global:o_Infect = $null
  $global:o_Threats = $null
  $global:o_AVcon = 0
  $global:o_CompAV = $null
  $global:o_CompPath = $null
  $global:o_CompState = $null
  #SUPPORTED AV VENDORS
  $global:avVendors = @(
    "Sophos"
    "Symantec"
    "Trend Micro"
    "Windows Defender"
  )
  #AV PRODUCTS USING '0' FOR 'UP-TO-DATE' PRODUCT STATUS
  $global:zUpgrade = @(
    "Sophos Intercept X"
    "Symantec Endpoint Protection"
    "Trend Micro Security Agent"
    "Worry-Free Business Security"
    "Windows Defender"
  )
  #AV PRODUCTS USING '0' FOR 'REAL-TIME SCANNING' STATUS
  $global:zRealTime = @(
    "Symantec Endpoint Protection"
    "Windows Defender"
  )
  #AV PRODUCTS USING '0' FOR 'TAMPER PROTECTION' STATUS
  $global:zTamper = @(
    "Sophos Anti-Virus"
    "Symantec Endpoint Protection"
    "Windows Defender"
  )
  #AV PRODUCTS NOT SUPPORTING ALERTS DETECTIONS
  $global:zNoAlert = @(
    "Symantec Endpoint Protection"
    "Windows Defender"
  )
  #AV PRODUCTS NOT SUPPORTING INFECTION DETECTIONS
  $global:zNoInfect = @(
    "Symantec Endpoint Protection"
    "Windows Defender"
  )
  #AV PRODUCTS NOT SUPPORTING THREAT DETECTIONS
  $global:zNoThreat = @(
    "Symantec Endpoint Protection"
    "Trend Micro Security Agent"
    "Worry-Free Business Security"
    "Windows Defender"
  )
  #AV PRODUCT XML NC REPOSITORY URLS FOR FALLBACK - CHANGE THESE TO MATCH YOUR NCENTRAL URLS AFTER UPLOADING EACH XML TO REPO
  $global:ncxmlSOPHOS = "https://nableserver/download/repository/1639682702/sophos.xml"
  $global:ncxmlSYMANTEC = "https://nableserver/download/repository/1238159723/symantec.xml"
  $global:ncxmlTRENDMICRO = "https://nableserver/download/repository/308457410/trendmicro.xml"
  $global:ncxmlWINDEFEND = "https://nableserver/download/repository/968395355/windowsdefender.xml"
  $global:ncxmlPRODUCTSTATE = "https://nableserver/download/repository/968395355/productstate.xml"
  #SET TLS SECURITY FOR CONNECTING TO GITHUB
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12
#ENDREGION ----- DECLARATIONS ----

#REGION ----- FUNCTIONS ----
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
      $global:bitarch = "bit64"
    } elseif ($osarch -like '*32*') {
      $global:bitarch = "bit32"
    }
    #OS Type & Version
    $global:computername = $env:computername
    $global:OSCaption = (Get-WmiObject Win32_OperatingSystem).Caption
    $global:OSVersion = (Get-WmiObject Win32_OperatingSystem).Version
    $osproduct = (Get-WmiObject -class Win32_OperatingSystem).Producttype
    Switch ($osproduct) {
      "1" {$global:producttype = "Workstation"}
      "2" {$global:producttype = "DC"}
      "3" {$global:producttype = "Server"}
    }
  } ## Get-OSArch

  function Get-AVState {                                                                            #DETERMINE ANTIVIRUS STATE
    param (
      $dest, $state
    )
    $xmldiag = $null
    if (-not $global:blnPSXML) {                                                                    #AV PRODUCT STATES NOT LOADED INTO HASHTABLE
      #$dest = @{}
      $global:blnPSXML = $true
      #RETRIEVE AV PRODUCT STATE XML FROM GITHUB
      $xmldiag += "Loading : AV Product State XML`r`n"
      write-host "Loading : AV Product State XML" -foregroundcolor yellow
      $srcAVP = "https://raw.githubusercontent.com/CW-Khristos/scripts/dev/AVProducts/productstate.xml"
      try {
        $psXML = New-Object System.Xml.XmlDocument
        $psXML.Load($srcAVP)
      } catch {
        $xmldiag += "XML.Load() - Could not open $($srcAVP)`r`n"
        write-host "XML.Load() - Could not open $($srcAVP)" -foregroundcolor red
        try {
          $web = new-object system.net.webclient
          [xml]$psXML = $web.DownloadString($srcAVP)
        } catch {
          $xmldiag += "Web.DownloadString() - Could not download $($srcAVP)`r`n"
          write-host "Web.DownloadString() - Could not download $($srcAVP)" -foregroundcolor red
          try {
            start-bitstransfer -erroraction stop -source $srcAVP -destination "C:\IT\Scripts\productstate.xml"
            [xml]$psXML = "C:\IT\Scripts\productstate.xml"
          } catch {
            $xmldiag += "BITS.Transfer() - Could not download $($srcAVP)`r`n"
            write-host "BITS.Transfer() - Could not download $($srcAVP)" -foregroundcolor red
            $global:blnPSXML = $false
          }
        }
      }
      #NABLE FALLBACK IF GITHUB IS NOT ACCESSIBLE
      if (-not $global:blnPSXML) {
        $xmldiag += "`r`nFailed : AV Product XML Retrieval from GitHub; Attempting download from NAble Server`r`n"
        $xmldiag += "Loading : '$($src)' AV Product XML`r`n"
        write-host "Failed : AV Product State XML Retrieval from GitHub; Attempting download from NAble Server" -foregroundcolor yellow
        write-host "Loading : AV Product State XML" -foregroundcolor yellow
        $srcAVP = $global:ncxmlPRODUCTSTATE
        try {
          $psXML = New-Object System.Xml.XmlDocument
          $psXML.Load($srcAVP)
          $global:blnPSXML = $true
        } catch {
          $xmldiag += "XML.Load() - Could not open $($srcAVP)`r`n"
          write-host "XML.Load() - Could not open $($srcAVP)" -foregroundcolor red
          try {
            $web = new-object system.net.webclient
            [xml]$psXML = $web.DownloadString($srcAVP)
            $global:blnPSXML = $true
          } catch {
            $xmldiag += "Web.DownloadString() - Could not download $($srcAVP)`r`n"
            write-host "Web.DownloadString() - Could not download $($srcAVP)" -foregroundcolor red
            try {
              start-bitstransfer -erroraction stop -source $srcAVP -destination "C:\IT\Scripts\productstate.xml"
              [xml]$psXML = "C:\IT\Scripts\productstate.xml"
              $global:blnPSXML = $true
            } catch {
              $xmldiag += "BITS.Transfer() - Could not download $($srcAVP)`r`n"
              write-host "BITS.Transfer() - Could not download $($srcAVP)" -foregroundcolor red
              $global:defstatus = "Unknown (WMI Check)`r`nUnable to download AV Product State XML"
              $global:rtstatus = "Unknown (WMI Check)`r`nUnable to download AV Product State XML"
              $global:blnPSXML = $false
            }
          }
        }
      }
      #READ AV PRODUCT STATE XML DATA INTO NESTED HASHTABLE FOR LATER USE
      try {
        if ($global:blnPSXML) {
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
        $global:blnPSXML = $false
        write-host $_.scriptstacktrace
        write-host $_
      }
    } elseif ($global:blnPSXML) {                                                                   #AV PRODUCT STATES ALREADY LOADED IN HASHTABLE
      #SET '$global:defstatus' AND '$global:rtstatus' TO INTERPRET PASSED PRODUCT STATE FROM POPULATED HASHTABLE
      try {
        $global:defstatus = $global:pskey["ps$($state)"].defstatus
        $global:rtstatus = $global:pskey["ps$($state)"].rtstatus
      } catch {
        $global:defstatus = "Unknown (WMI Check)`r`nAV Product State Unknown : $($state)"
        $global:rtstatus = "Unknown (WMI Check)`r`nAV Product State Unknown : $($state)"
      }
    }
    $global:diag += "$($xmldiag)"
    $xmldiag = $null
  } ## Get-AVState
  
  function Get-AVXML {                                                                              #RETRIEVE AV VENDOR XML FROM GITHUB
    param (
      $src, $dest
    )
    #$dest = @{}
    $xmldiag = $null
    $global:blnAVXML = $true
    #RETRIEVE AV VENDOR XML FROM GITHUB
    $xmldiag+= "Loading : '$($src)' AV Product XML`r`n"
    write-host "Loading : '$($src)' AV Product XML" -foregroundcolor yellow
    $srcAVP = "https://raw.githubusercontent.com/CW-Khristos/scripts/dev/AVProducts/" + $src.replace(" ", "").replace("-", "").tolower() + ".xml"
    try {
      $avXML = New-Object System.Xml.XmlDocument
      $avXML.Load($srcAVP)
    } catch {
      $xmldiag += "XML.Load() - Could not open $($srcAVP)`r`n"
      write-host "XML.Load() - Could not open $($srcAVP)" -foregroundcolor red
      try {
        $web = new-object system.net.webclient
        [xml]$avXML = $web.DownloadString($srcAVP)
      } catch {
        $xmldiag += "Web.DownloadString() - Could not download $($srcAVP)`r`n"
        write-host "Web.DownloadString() - Could not download $($srcAVP)" -foregroundcolor red
        try {
          start-bitstransfer -erroraction stop -source $srcAVP -destination "C:\IT\Scripts\" + $src.replace(" ", "").replace("-", "").tolower() + ".xml"
          [xml]$avXML = "C:\IT\Scripts\" + $src.replace(" ", "").replace("-", "").tolower() + ".xml"
        } catch {
          $xmldiag += "BITS.Transfer() - Could not download $($srcAVP)`r`n"
          write-host "BITS.Transfer() - Could not download $($srcAVP)" -foregroundcolor red
          $global:blnAVXML = $false
        }
      }
    }
    #NABLE FALLBACK IF GITHUB IS NOT ACCESSIBLE
    if (-not $global:blnAVXML) {
      $xmldiag += "`r`nFailed : AV Product XML Retrieval from GitHub; Attempting download from NAble Server`r`n"
      $xmldiag += "Loading : '$($src)' AV Product XML`r`n"
      write-host "Failed : AV Product XML Retrieval from GitHub; Attempting download from NAble Server" -foregroundcolor yellow
      write-host "Loading : '$($src)' AV Product XML" -foregroundcolor yellow
      switch ($src) {
        "Sophos" {$srcAVP = $global:ncxmlSOPHOS}
        "Symantec" {$srcAVP = $global:ncxmlSYMANTEC}
        "Trend Micro" {$srcAVP = $global:ncxmlTRENDMICRO}
        "Windows Defender" {$srcAVP = $global:ncxmlWINDEFEND}
      }
      try {
        $avXML = New-Object System.Xml.XmlDocument
        $avXML.Load($srcAVP)
        $global:blnAVXML = $true
      } catch {
        $xmldiag += "XML.Load() - Could not open $($srcAVP)`r`n"
        write-host "XML.Load() - Could not open $($srcAVP)" -foregroundcolor red
        try {
          $web = new-object system.net.webclient
          [xml]$avXML = $web.DownloadString($srcAVP)
          $global:blnAVXML = $true
        } catch {
          $xmldiag += "Web.DownloadString() - Could not download $($srcAVP)`r`n"
          write-host "Web.DownloadString() - Could not download $($srcAVP)" -foregroundcolor red
          try {
            start-bitstransfer -erroraction stop -source $srcAVP -destination "C:\IT\Scripts\" + $src.replace(" ", "").replace("-", "").tolower() + ".xml"
            [xml]$avXML = "C:\IT\Scripts\" + $src.replace(" ", "").replace("-", "").tolower() + ".xml"
            $global:blnAVXML = $true
          } catch {
            $xmldiag += "BITS.Transfer() - Could not download $($srcAVP)`r`n"
            write-host "BITS.Transfer() - Could not download $($srcAVP)" -foregroundcolor red
            $global:blnAVXML = $false
          }
        }
      }
    }
    #READ PRIMARY AV PRODUCT VENDOR XML DATA INTO NESTED HASHTABLE FOR LATER USE
    try {
      if ($global:blnAVXML) {
        foreach ($itm in $avXML.NODE.ChildNodes) {
          if ($itm.name -notmatch "#comment") {                                                     #AVOID 'BUG' WITH A KEY AS '#comment'
            if ($i_PAV -notmatch "Trend Micro") {                                                   #BUILD HASHTABLE FOR ALL AV PRODUCTS EXCEPT TREND MICRO
              $hash = @{
                display = "$($itm.$global:bitarch.display)"
                displayval = "$($itm.$global:bitarch.displayval)"
                path = "$($itm.$global:bitarch.path)"
                pathval = "$($itm.$global:bitarch.pathval)"
                ver = "$($itm.$global:bitarch.ver)"
                verval = "$($itm.$global:bitarch.verval)"
                compver = "$($itm.$global:bitarch.compver)"
                stat = "$($itm.$global:bitarch.stat)"
                statval = "$($itm.$global:bitarch.statval)"
                update = "$($itm.$global:bitarch.update)"
                updateval = "$($itm.$global:bitarch.updateval)"
                source = "$($itm.$global:bitarch.source)"
                sourceval = "$($itm.$global:bitarch.sourceval)"
                defupdate = "$($itm.$global:bitarch.defupdate)"
                defupdateval = "$($itm.$global:bitarch.defupdateval)"
                tamper = "$($itm.$global:bitarch.tamper)"
                tamperval = "$($itm.$global:bitarch.tamperval)"
                rt = "$($itm.$global:bitarch.rt)"
                rtval = "$($itm.$global:bitarch.rtval)"
                scan = "$($itm.$global:bitarch.scan)"
                scantype = "$($itm.$global:bitarch.scantype)"
                scanval = "$($itm.$global:bitarch.scanval)"
                alert = "$($itm.$global:bitarch.alert)"
                alertval = "$($itm.$global:bitarch.alertval)"
                infect = "$($itm.$global:bitarch.infect)"
                infectval = "$($itm.$global:bitarch.infectval)"
                threat = "$($itm.$global:bitarch.threat)"
              }
            } elseif ($i_PAV -match "Trend Micro") {                                                #BUILD HASHTABLE FOR CURSED TREND MICRO
              $hash = @{
                display = "$($itm.$global:bitarch.display)"
                displayval = "$($itm.$global:bitarch.displayval)"
                path = "$($itm.$global:bitarch.path)"
                pathval = "$($itm.$global:bitarch.pathval)"
                corever = "$($itm.$global:bitarch.corever)"
                coreverval = "$($itm.$global:bitarch.coreverval)"
                vcver = "$($itm.$global:bitarch.vcver)"
                vcverval = "$($itm.$global:bitarch.vcverval)"
                compver = "$($itm.$global:bitarch.compver)"
                compverval = "$($itm.$global:bitarch.compverval)"
                stat = "$($itm.$global:bitarch.stat)"
                statval = "$($itm.$global:bitarch.statval)"
                update = "$($itm.$global:bitarch.update)"
                updateval = "$($itm.$global:bitarch.updateval)"
                source = "$($itm.$global:bitarch.source)"
                sourceval = "$($itm.$global:bitarch.sourceval)"
                defupdate = "$($itm.$global:bitarch.defupdate)"
                defupdateval = "$($itm.$global:bitarch.defupdateval)"
                tamper = "$($itm.$global:bitarch.tamper)"
                tamperval = "$($itm.$global:bitarch.tamperval)"
                rt = "$($itm.$global:bitarch.rt)"
                rtval = "$($itm.$global:bitarch.rtval)"
                scan = "$($itm.$global:bitarch.scan)"
                scantype = "$($itm.$global:bitarch.scantype)"
                scanval = "$($itm.$global:bitarch.scanval)"
                alert = "$($itm.$global:bitarch.alert)"
                alertval = "$($itm.$global:bitarch.alertval)"
                infect = "$($itm.$global:bitarch.infect)"
                infectval = "$($itm.$global:bitarch.infectval)"
                threat = "$($itm.$global:bitarch.threat)"
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
      $global:blnAVXML = $false
      write-host $_.scriptstacktrace
      write-host $_
    }
    $global:diag += "$($xmldiag)"
    $xmldiag = $null
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
      write-host $_.scriptstacktrace
      write-host $_
    }
  } ## Pop-Components

  function SEP-Map {                                                                                #INTERPRET SYMANTEC ENDPOINT PROTECTION DETECTION CODES
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
#ENDREGION ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
Get-OSArch
Get-AVXML $i_PAV $global:pavkey
if (-not ($global:blnAVXML)) {
  #AV DETAILS
  $global:o_AVname = "Selected AV Product Not Found`r`nUnable to download AV Vendor XML`r`n"
  $global:o_AVVersion = "Selected AV Product Not Found`r`nUnable to download AV Vendor XML`r`n"
  $global:o_AVpath = "Selected AV Product Not Found`r`nUnable to download AV Vendor XML`r`n"
  $global:o_AVStatus = "Selected AV Product Not Found`r`nUnable to download AV Vendor XML`r`n"
  #REAL-TIME SCANNING & DEFINITIONS
  $global:o_RTstate = "Selected AV Product Not Found`r`nUnable to download AV Vendor XML`r`n"
  $global:o_DefStatus = "Selected AV Product Not Found`r`nUnable to download AV Vendor XML`r`n"
  #THREATS
  $global:o_Infect = "Selected AV Product Not Found`r`nUnable to download AV Vendor XML`r`n"
  $global:o_Threats = "Selected AV Product Not Found`r`nUnable to download AV Vendor XML`r`n"
  #COMPETITOR AV
  $global:o_CompAV = "Selected AV Product Not Found`r`nUnable to download AV Vendor XML`r`n"
  $global:o_CompPath = "Selected AV Product Not Found`r`nUnable to download AV Vendor XML`r`n"
  $global:o_CompState = "Selected AV Product Not Found`r`nUnable to download AV Vendor XML`r`n"
} elseif ($global:blnAVXML) {
  #QUERY WMI SECURITYCENTER NAMESPACE FOR AV PRODUCT DETAILS
  if ([system.version]$global:OSVersion -ge [system.version]'6.0.0.0') {
    write-verbose "OS Windows Vista/Server 2008 or newer detected."
    try {
      $AntiVirusProduct = get-wmiobject -Namespace "root\SecurityCenter2" -Class "AntiVirusProduct" -ComputerName "$($global:computername)" -ErrorAction Stop
    } catch {
      $global:blnWMI = $false
    }
  } elseif ([system.version]$global:OSVersion -lt [system.version]'6.0.0.0') {
    write-verbose "Windows 2000, 2003, XP detected" 
    try {
      $AntiVirusProduct = get-wmiobject -Namespace "root\SecurityCenter" -Class "AntiVirusProduct"  -ComputerName "$($global:computername)" -ErrorAction Stop
    } catch {
      $global:blnWMI = $false
    }
  }
  if (-not $global:blnWMI) {                                                                        #FAILED TO RETURN WMI SECURITYCENTER NAMESPACE
    try {
      write-host "`r`nFailed to query WMI SecurityCenter Namespace" -foregroundcolor red
      write-host "Possibly Server, attempting to fallback to using 'HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\' registry key" -foregroundcolor red
      try {                                                                                         #QUERY 'HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\' AND SEE IF AN AV IS REGISTRERED THERE
        if ($global:bitarch = "bit64") {
          $AntiVirusProduct = (get-itemproperty -path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Security Center\Monitoring\*" -ErrorAction Stop).PSChildName
        } elseif ($global:bitarch = "bit32") {
          $AntiVirusProduct = (get-itemproperty -path "HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\*" -ErrorAction Stop).PSChildName
        }
      } catch {
        write-host "Could not find AV registered in HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\*" -foregroundcolor red
        $AntiVirusProduct = $null
        $blnSecMon = $true
      }
      if ($AntiVirusProduct -ne $null) {                                                            #RETURNED 'HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\' DATA
        $strDisplay = $null
        $blnSecMon = $false
        write-host "`r`nPerforming AV Product discovery" -foregroundcolor yellow
        foreach ($av in $AntiVirusProduct) {
          #PRIMARY AV REGISTERED UNDER 'HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\'
          if ($av -match $i_PAV) {
            $global:blnPAV = $true
          } elseif (($i_PAV -eq "Trend Micro") -and ($av -match "Worry-Free Business Security")) {
            $global:blnPAV = $true
          }
          write-host "`r`nFound 'HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\$($av)'" -foregroundcolor yellow
          #RETRIEVE DETECTED AV PRODUCT VENDOR XML
          foreach ($vendor in $global:avVendors) {
            if ($av -match $vendor) {
              Get-AVXML $vendor $global:vavkey
              break
            } elseif ($av -match "Worry-Free Business Security") {
              Get-AVXML "Trend Micro" $global:vavkey
              break
            }
          }
          #SEARCH PASSED PRIMARY AV VENDOR XML
          foreach ($key in $global:vavkey.keys) {                                                   #ATTEMPT TO VALIDATE EACH AV PRODUCT CONTAINED IN VENDOR XML
            if ($av.replace(" ", "").replace("-", "").toupper() -eq $key.toupper()) {
              write-host "Matched AV : '$($av)' - '$($key)' AV Product" -foregroundcolor yellow
              $strName = $null
              $regDisplay = "$($global:vavkey[$key].display)"
              $regDisplayVal = "$($global:vavkey[$key].displayval)"
              $regPath = "$($global:vavkey[$key].path)"
              $regPathVal = "$($global:vavkey[$key].pathval)"
              $regStat = "$($global:vavkey[$key].stat)"
              $regStatVal = "$($global:vavkey[$key].statval)"
              $regRealTime = "$($global:vavkey[$key].rt)"
              $regRTVal = "$($global:vavkey[$key].rtval)"
              break
            }
          }
          try {
            if (($regDisplay -ne "") -and ($regDisplay -ne $null)) {
              if (test-path "HKLM:$($regDisplay)") {                                                #ATTEMPT TO VALIDATE INSTALLED AV PRODUCT BY TEST READING A KEY
                write-host "Found 'HKLM:$($regDisplay)' for product : $($key)" -foregroundcolor yellow
                try {                                                                               #IF VALIDATION PASSES; FABRICATE 'HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\' DATA
                  $keyval1 = get-itemproperty -path "HKLM:$($regDisplay)" -name "$($regDisplayVal)" -erroraction stop
                  $keyval2 = get-itemproperty -path "HKLM:$($regPath)" -name "$($regPathVal)" -erroraction stop
                  $keyval3 = get-itemproperty -path "HKLM:$($regStat)" -name "$($regStatVal)" -erroraction stop
                  $keyval4 = get-itemproperty -path "HKLM:$($regRealTime)" -name "$($regRTVal)" -erroraction stop
                  #FORMAT AV DATA
                  $strName = $keyval1.$regDisplayVal
                  if ($strName -match "Windows Defender") {                                         #'NORMALIZE' WINDOWS DEFENDER DISPLAY NAME
                    $strName = "Windows Defender"
                  } elseif (($regDisplay -match "Sophos") -and ($strName -match "BETA")) {          #'NORMALIZE' SOPHOS INTERCEPT X BETA DISPLAY NAME AND FIX SERVER REG CHECK
                    $strName = "Sophos Intercept X Beta"
                  }
                  $strDisplay = "$($strDisplay)$($strName), "
                  $strPath = "$($strPath)$($keyval2.$regPathVal), "
                  $strStat = "$($strStat)$($keyval3.$regStatVal.tostring()), "
                  if ($keyval4.$regRTVal = "0") {                                                   #INTERPRET REAL-TIME SCANNING STATUS
                    $strRealTime = "$($strRealTime)Enabled (REG Check), "
                  } elseif ($keyval4.$regRTVal = "1") {
                    $strRealTime = "$($strRealTime)Disabled (REG Check), "
                  }
                } catch {
                  write-host "Could not validate Registry data for product : $($key)" -foregroundcolor red
                  write-host $_.scriptstacktrace
                  write-host $_
                }
              }
            }
          } catch {
            write-host "Not Found 'HKLM:$regDisplay' for product : $($key)" -foregroundcolor red
            write-host $_.scriptstacktrace
            write-host $_
          }
        }
      }
      if (($AntiVirusProduct -eq $null) -or (-not $global:blnPAV)) {                                #FAILED TO RETURN 'HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\' DATA
        $strDisplay = $null
        $blnSecMon = $true
        #RETRIEVE EACH VENDOR XML AND CHECK FOR ALL SUPPORTED AV PRODUCTS
        write-host "`r`nPrimary AV Product not found / No AV Products found; will check each AV Product in all Vendor XMLs" -foregroundcolor yellow
        foreach ($vendor in $global:avVendors) {
          Get-AVXML $vendor $global:vavkey
        }
        foreach ($key in $global:vavkey.keys) {                                                     #ATTEMPT TO VALIDATE EACH AV PRODUCT CONTAINED IN VENDOR XML
          if ($key -notmatch "#comment") {                                                          #AVOID ODD 'BUG' WITH A KEY AS '#comment' WHEN SWITCHING AV VENDOR XMLS
            write-host "Attempting to detect AV Product : '$($key)'" -foregroundcolor yellow
            $strName = $null
            $regDisplay = "$($global:vavkey[$key].display)"
            $regDisplayVal = "$($global:vavkey[$key].displayval)"
            $regPath = "$($global:vavkey[$key].path)"
            $regPathVal = "$($global:vavkey[$key].pathval)"
            $regStat = "$($global:vavkey[$key].stat)"
            $regStatVal = "$($global:vavkey[$key].statval)"
            $regRealTime = "$($global:vavkey[$key].rt)"
            $regRTVal = "$($global:vavkey[$key].rtval)"
            try {
              if (test-path "HKLM:$($regDisplay)") {                                                #VALIDATE INSTALLED AV PRODUCT BY TESTING READING A KEY
                write-host "Found 'HKLM:$($regDisplay)' for product : $($key)" -foregroundcolor yellow
                try {                                                                               #IF VALIDATION PASSES; FABRICATE 'HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\' DATA
                  $keyval1 = get-itemproperty -path "HKLM:$($regDisplay)" -name "$($regDisplayVal)" -erroraction stop
                  $keyval2 = get-itemproperty -path "HKLM:$($regPath)" -name "$($regPathVal)" -erroraction stop
                  $keyval3 = get-itemproperty -path "HKLM:$($regStat)" -name "$($regStatVal)" -erroraction stop
                  $keyval4 = get-itemproperty -path "HKLM:$($regRealTime)" -name "$($regRTVal)" -erroraction stop
                  #FORMAT AV DATA
                  $strName = "$($keyval1.$regDisplayVal)"
                  if ($strName -match "Windows Defender") {                                         #'NORMALIZE' WINDOWS DEFENDER DISPLAY NAME
                    $strName = "Windows Defender"
                  } elseif (($regDisplay -match "Sophos") -and ($strName -match "BETA")) {          #'NORMALIZE' SOPHOS INTERCEPT X BETA DISPLAY NAME AND FIX SERVER REG CHECK
                    $strName = "Sophos Intercept X Beta"
                  }
                  $strDisplay = "$($strDisplay)$($strName), "
                  $strPath = "$($strPath)$($keyval2.$regPathVal), "
                  $strStat = "$($strStat)$($keyval3.$regStatVal.tostring()), "
                  #INTERPRET REAL-TIME SCANNING STATUS
                  if ($global:zRealTime -contains $global:vavkey[$key].display) {                   #AV PRODUCTS TREATING '0' AS 'ENABLED' FOR 'REAL-TIME SCANNING'
                    if ($keyval4.$regRTVal = "0") {
                      $strRealTime = "$($strRealTime)Enabled (REG Check), "
                    } elseif ($keyval4.$regRTVal = "1") {
                      $strRealTime = "$($strRealTime)Disabled (REG Check), "
                    }
                  } elseif ($global:zRealTime -notcontains $global:vavkey[$key].display) {          #AV PRODUCTS TREATING '1' AS 'ENABLED' FOR 'REAL-TIME SCANNING'
                    if ($keyval4.$regRTVal = "1") {
                      $strRealTime = "$($strRealTime)Enabled (REG Check), "
                    } elseif ($keyval4.$regRTVal = "0") {
                      $strRealTime = "$($strRealTime)Disabled (REG Check), "
                    }
                  }
                  #FABRICATE 'HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\' DATA
                  if ($blnSecMon) {
                    write-host "Creating Registry Key HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\$strName for product : $($strName)" -foregroundcolor red
                    if ($global:bitarch = "bit64") {
                      try {
                        new-item -path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Security Center\Monitoring\" -name "$($strName)" -value "$($strName)" -force
                      } catch {
                        write-host "Could not create Registry Key `HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\$($strName) for product : $($strName)" -foregroundcolor red
                        write-host $_.scriptstacktrace
                        write-host $_
                      }
                    } elseif ($global:bitarch = "bit32") {
                      try {
                        new-item -path "HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\" -name "$($strName)" -value "$($strName)" -force
                      } catch {
                        write-host "Could not create Registry Key `HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\$($strName) for product : $($strName)" -foregroundcolor red
                        write-host $_.scriptstacktrace
                        write-host $_
                      }
                    }
                  }
                  $AntiVirusProduct = "."
                } catch {
                  write-host "Could not validate Registry data for product : $($key)" -foregroundcolor red
                  write-host $_.scriptstacktrace
                  write-host $_
                  $AntiVirusProduct = $null
                }
              }
            } catch {
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
      write-host "Failed to validate supported AV Products" -foregroundcolor red
      write-host $_.scriptstacktrace
      write-host $_
    }
  } elseif ($global:blnWMI) {                                                                       #RETURNED WMI SECURITYCENTER NAMESPACE
    #SEPARATE RETURNED WMI AV PRODUCT INSTANCES
    if ($AntiVirusProduct -ne $null) {                                                              #RETURNED WMI AV PRODUCT DATA
      $tmpavs = $AntiVirusProduct.displayName -split ", "
      $tmppaths = $AntiVirusProduct.pathToSignedProductExe -split ", "
      $tmpstats = $AntiVirusProduct.productState -split ", "
    } elseif ($AntiVirusProduct -eq $null) {                                                        #FAILED TO RETURN WMI AV PRODUCT DATA
      $strDisplay = ""
      #RETRIEVE EACH VENDOR XML AND CHECK FOR ALL SUPPORTED AV PRODUCTS
      write-host "`r`nPrimary AV Product not found / No AV Products found; will check each AV Product in all Vendor XMLs" -foregroundcolor yellow
      foreach ($vendor in $global:avVendors) {
        Get-AVXML $vendor $global:vavkey
      }
      foreach ($key in $global:vavkey.keys) {                                                       #ATTEMPT TO VALIDATE EACH AV PRODUCT CONTAINED IN VENDOR XML
        if ($key -notmatch "#comment") {                                                            #AVOID ODD 'BUG' WITH A KEY AS '#comment' WHEN SWITCHING AV VENDOR XMLS
          write-host "Attempting to detect AV Product : '$($key)'" -foregroundcolor yellow
          $strName = $null
          $regDisplay = "$($global:vavkey[$key].display)"
          $regDisplayVal = "$($global:vavkey[$key].displayval)"
          $regPath = "$($global:vavkey[$key].path)"
          $regPathVal = "$($global:vavkey[$key].pathval)"
          $regStat = "$($global:vavkey[$key].stat)"
          $regStatVal = "$($global:vavkey[$key].statval)"
          $regRealTime = "$($global:vavkey[$key].rt)"
          $regRTVal = "$($global:vavkey[$key].rtval)"
          try {
            if (test-path "HKLM:$($regDisplay)") {                                                  #VALIDATE INSTALLED AV PRODUCT BY TESTING READING A KEY
              write-host "Found 'HKLM:$($regDisplay)' for product : $($key)" -foregroundcolor yellow
              try {                                                                                 #IF VALIDATION PASSES
                $keyval1 = get-itemproperty -path "HKLM:$($regDisplay)" -name "$($regDisplayVal)" -erroraction stop
                $keyval2 = get-itemproperty -path "HKLM:$($regPath)" -name "$($regPathVal)" -erroraction stop
                $keyval3 = get-itemproperty -path "HKLM:$($regStat)" -name "$($regStatVal)" -erroraction stop
                $keyval4 = get-itemproperty -path "HKLM:$($regRealTime)" -name "$($regRTVal)" -erroraction stop
                #FORMAT AV DATA
                $strName = "$($keyval1.$regDisplayVal)"
                if ($strName -match "Windows Defender") {                                           #'NORMALIZE' WINDOWS DEFENDER DISPLAY NAME
                  $strName = "Windows Defender"
                } elseif (($i_PAV -match "Sophos") -and ($strName -match "BETA")) {                 #'NORMALIZE' SOPHOS INTERCEPT X BETA DISPLAY NAME AND FIX SERVER REG CHECK
                  $strName = "Sophos Intercept X Beta"
                }
                $strDisplay = "$($strDisplay)$($strName), "
                $strPath = "$($strPath)$($keyval2.$regPathVal), "
                $strStat = "$($strStat)$($keyval3.$regStatVal.tostring()), "
                #INTERPRET REAL-TIME SCANNING STATUS
                if ($global:zRealTime -contains $global:vavkey[$key].display) {                     #AV PRODUCTS TREATING '0' AS 'ENABLED' FOR 'REAL-TIME SCANNING'
                  if ($keyval4.$regRTVal = "0") {
                    $strRealTime = "$($strRealTime)Enabled (REG Check), "
                  } elseif ($keyval4.$regRTVal = "1") {
                    $strRealTime = "$($strRealTime)Disabled (REG Check), "
                  }
                } elseif ($global:zRealTime -notcontains $global:vavkey[$key].display) {            #AV PRODUCTS TREATING '1' AS 'ENABLED' FOR 'REAL-TIME SCANNING'
                  if ($keyval4.$regRTVal = "1") {
                    $strRealTime = "$($strRealTime)Enabled (REG Check), "
                  } elseif ($keyval4.$regRTVal = "0") {
                    $strRealTime = "$($strRealTime)Disabled (REG Check), "
                  }
                }
                $AntiVirusProduct = "."
              } catch {
                write-host "Could not validate Registry data for product : $($key)" -foregroundcolor red
                write-host $_.scriptstacktrace
                write-host $_
                $AntiVirusProduct = $null
              }
            }
          } catch {
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
  write-host "`r`nAV Product discovery completed`r`n" -foregroundcolor yellow
  if ($AntiVirusProduct -eq $null) {                                                                #NO AV PRODUCT FOUND
    $AntiVirusProduct
    write-host "Could not find any AV Product registered" -foregroundcolor red
    $global:o_AVname = "No AV Product Found"
    $global:o_AVVersion = $null
    $global:o_AVpath = $null
    $global:o_AVStatus = "Unknown"
    $global:o_RTstate = "Unknown"
    $global:o_DefStatus = "Unknown"
    $global:o_AVcon = 0
  } elseif ($AntiVirusProduct -ne $null) {                                                          #FOUND AV PRODUCTS
    foreach ($av in $avs.keys) {                                                                    #ITERATE THROUGH EACH FOUND AV PRODUCT
      if (($avs[$av].display -ne $null) -and ($avs[$av].display -ne "")) {
        #NEITHER PRIMARY AV PRODUCT NOR WINDOWS DEFENDER
        if (($avs[$av].display -notmatch $i_PAV) -and ($avs[$av].display -notmatch "Windows Defender")) {
          if (($i_PAV -eq "Trend Micro") -and (($avs[$av].display -notmatch "Trend Micro") -and ($avs[$av].display -notmatch "Worry-Free Business Security"))) {
            $global:o_AVcon = 1
            $global:o_CompAV += "$($avs[$av].display)`r`n"
            $global:o_CompPath += "$($avs[$av].path)`r`n"
            if ($global:blnWMI) {
              Get-AVState $global:pskey $avs[$av].stat
              $global:o_CompState += "$($avs[$av].display) - Real-Time Scanning : $($global:rtstatus) - Definitions : $($global:defstatus)`r`n"
            } elseif (-not $global:blnWMI) {
              $global:o_CompState += "$($avs[$av].display) - Real-Time Scanning : $($avs[$av].rt) - Definitions : N/A (WMI Check)`r`n"
            }
          } elseif ($i_PAV -ne "Trend Micro") {
            $global:o_AVcon = 1
            $global:o_CompAV += "$($avs[$av].display)`r`n"
            $global:o_CompPath += "$($avs[$av].path)`r`n"
            if ($global:blnWMI) {
              Get-AVState $global:pskey $avs[$av].stat
              $global:o_CompState += "$($avs[$av].display) - Real-Time Scanning : $($global:rtstatus) - Definitions : $($global:defstatus)`r`n"
            } elseif (-not $global:blnWMI) {
              $global:o_CompState += "$($avs[$av].display) - Real-Time Scanning : $($avs[$av].rt) - Definitions : N/A (WMI Check)`r`n"
            }
          }
        }
        #PRIMARY AV PRODUCT
        if (($avs[$av].display -match $i_PAV) -or 
          (($i_PAV -eq "Trend Micro") -and (($avs[$av].display -match "Trend Micro") -or ($avs[$av].display -match "Worry-Free Business Security")))) {
          #PARSE XML FOR SPECIFIC VENDOR AV PRODUCT
          $node = $avs[$av].display.replace(" ", "").replace("-", "").toupper()
          #AV DETAILS
          $global:o_AVname = $avs[$av].display
          $global:o_AVpath = $avs[$av].path
          #AV PRODUCT VERSION
          if ($i_PAV -notmatch "Trend Micro") {
            $i_verkey = $global:pavkey[$node].ver
            $i_verval = $global:pavkey[$node].verval
          } elseif ($i_PAV -match "Trend Micro") {
            $i_verkey = $global:pavkey[$node].corever
            $i_verval = $global:pavkey[$node].coreverval
            $i_vckey = $global:pavkey[$node].vcver
            $i_vcval = $global:pavkey[$node].vcverval
          }
          #AV PRODUCT COMPONENTS VERSIONS
          $i_compverkey = $global:pavkey[$node].compver
          if ($i_PAV -match "Trend Micro") {
            $i_compverval = $global:pavkey[$node].compverval
          }
          #AV PRODUCT STATE
          $i_statkey = $global:pavkey[$node].stat
          $i_statval = $global:pavkey[$node].statval
          #AV PRODUCT LAST UPDATE TIMESTAMP
          $i_update = $global:pavkey[$node].update
          $i_updateval = $global:pavkey[$node].updateval
          #AV PRODUCT UPDATE SOURCE
          $i_source = $global:pavkey[$node].source
          $i_sourceval = $global:pavkey[$node].sourceval
          #AV PRODUCT REAL-TIME SCANNING
          $i_rtkey = $global:pavkey[$node].rt
          $i_rtval = $global:pavkey[$node].rtval
          #AV PRODUCT DEFINITIONS
          $i_defupdate = $global:pavkey[$node].defupdate
          $i_defupdateval = $global:pavkey[$node].defupdateval
          #AV PRODUCT TAMPER PROTECTION
          $i_tamper = $global:pavkey[$node].tamper
          $i_tamperval = $global:pavkey[$node].tamperval
          #AV PRODUCT SCANS
          $i_scan = $global:pavkey[$node].scan
          $i_scantype = $global:pavkey[$node].scantype
          $i_scanval = $global:pavkey[$node].scanval
          #AV PRODUCT ALERTS
          $i_alert = $global:pavkey[$node].alert
          $i_alertval = $global:pavkey[$node].alertval
          #AV PRODUCT INFECTIONS
          $i_infect = $global:pavkey[$node].infect
          $i_infectval = $global:pavkey[$node].infectval
          #AV PRODUCT THREATS
          $i_threat = $global:pavkey[$node].threat
          #GET PRIMARY AV PRODUCT VERSION VIA REGISTRY
          try {
            write-host "Reading : -path 'HKLM:$($i_verkey)' -name '$($i_verval)'" -foregroundcolor yellow
            $global:o_AVVersion = get-itemproperty -path "HKLM:$($i_verkey)" -name "$($i_verval)" -erroraction stop
            $global:o_AVVersion = "$($global:o_AVVersion.$i_verval)"
          } catch {
            write-host "Could not validate Registry data : -path 'HKLM:$($i_verkey)' -name '$($i_verval)'" -foregroundcolor red
            $global:o_AVVersion = "."
            write-host $_.scriptstacktrace
            write-host $_
          }
          #GET PRIMARY AV PRODUCT COMPONENT VERSIONS
          $o_compver = "Core Version : $($global:o_AVVersion)`r`n"
          try {
            write-host "Reading : -path 'HKLM:$($i_compverkey)'" -foregroundcolor yellow
            if ($i_PAV -match "Sophos") {                                                           #SOPHOS COMPONENT VERSIONS
              $compverkey = get-childitem -path "HKLM:$($i_compverkey)" -erroraction silentlycontinue
              foreach ($component in $compverkey) {
                if (($component -ne $null) -and ($component -ne "")) {
                  $longname = get-itemproperty -path "HKLM:$($i_compverkey)$($component.PSChildName)" -name "LongName" -erroraction silentlycontinue
                  $installver = get-itemproperty -path "HKLM:$($i_compverkey)$($component.PSChildName)" -name "InstalledVersion" -erroraction silentlycontinue
                  Pop-Components $global:compkey $($longname.LongName) $($installver.InstalledVersion)
                }
              }
              $sort = $global:compkey.GetEnumerator() | sort -Property name
              foreach ($component in $sort) {
                $o_compver += "$($component.name) Version : $($component.value)`r`n"
              }
            } elseif ($i_PAV -match "Trend Micro") {                                                #CURSED TREND MICRO
              $compverkey = get-itemproperty -path "HKLM:$($i_compverkey)" -name "$($i_compverval)" -erroraction silentlycontinue
              $compverkey = $compverkey.$i_compverval.split("/")
              $o_compver += "VC Version : $($compverkey[1])`r`n"
            }
          } catch {
            if ($i_PAV -match "Sophos") {
              write-host "Could not validate Registry data : 'HKLM:$($i_compverkey)' for '$($component.PSChildName)'" -foregroundcolor red
            } elseif ($i_PAV -notmatch "Sophos") {
              write-host "Could not validate Registry data : 'HKLM:$($i_compverkey)' for '$($avs[$av].display)'" -foregroundcolor red
            }
            $o_compver = "Components : N/A`r`n"
            write-host $_.scriptstacktrace
            write-host $_
          }
          #GET AV PRODUCT UPDATE SOURCE
          try {
            write-host "Reading : -path 'HKLM:$($i_source)' -name '$($i_sourceval)'" -foregroundcolor yellow
            $sourcekey = get-itemproperty -path "HKLM:$($i_source)" -name "$($i_sourceval)" -erroraction stop
            $global:o_AVStatus = "Update Source : $($sourcekey.$i_sourceval)`r`n"
          } catch {
            write-host "Could not validate Registry data : -path 'HKLM:$($i_source)' -name '$($i_sourceval)'" -foregroundcolor red
            $global:o_AVStatus = "Update Source : Unknown`r`n"
            write-host $_.scriptstacktrace
            write-host $_
          }
          #GET PRIMARY AV PRODUCT STATUS VIA REGISTRY
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
          if ($i_PAV -notmatch "Trend Micro") {                                                     #HANDLE ALL AV PRODUCTS EXCEPT TREND MICRO
            try {
              write-host "Reading : -path 'HKLM:$($i_statkey)' -name '$($i_statval)'" -foregroundcolor yellow
              $statkey = get-itemproperty -path "HKLM:$($i_statkey)" -name "$($i_statval)" -erroraction stop
              #INTERPRET 'AVSTATUS' BASED ON ANY AV PRODUCT VALUE REPRESENTATION
              if ($global:zUpgrade -contains $avs[$av].display) {                                   #AV PRODUCTS TREATING '0' AS 'UPTODATE'
                write-host "$($avs[$av].display) reports '$($statkey.$i_statval)' for 'Up-To-Date' (Expected : '0')" -foregroundcolor yellow
                if ($statkey.$i_statval -eq "0") {
                  $global:o_AVStatus = "Up-to-Date : $($true) (REG Check)`r`n"
                } else {
                  $global:o_AVStatus = "Up-to-Date : $($false) (REG Check)`r`n"
                }
              } elseif ($global:zUpgrade -notcontains $avs[$av].display) {                          #AV PRODUCTS TREATING '1' AS 'UPTODATE'
                write-host "$($avs[$av].display) reports '$($statkey.$i_statval)' for 'Up-To-Date' (Expected : '1')" -foregroundcolor yellow
                if ($statkey.$i_statval -eq "1") {
                  $global:o_AVStatus = "Up-to-Date : $($true) (REG Check)`r`n"
                } else {
                  $global:o_AVStatus = "Up-to-Date : $($false) (REG Check)`r`n"
                }
              }
            } catch {
              write-host "Could not validate Registry data : -path 'HKLM:$($i_statkey)' -name '$($i_statval)'" -foregroundcolor red
              $global:o_AVStatus = "Up-to-Date : Unknown (REG Check)`r`n"
              write-host $_.scriptstacktrace
              write-host $_
            }
          } elseif ($i_PAV -match "Trend Micro") {                                                  #HANDLE TREND MICRO AV PRODUCT
            try {
              write-host "'Trend Micro' Detected : Reading : -path 'HKLM:$($i_vckey)' -name '$($i_vcval)'" -foregroundcolor yellow
              $vckey = get-itemproperty -path "HKLM:$($i_vckey)" -name "$($i_vcval)" -erroraction stop
              write-host "$($avs[$av].display) reports '$($global:o_AVVersion)' for 'Up-To-Date' (Expected : '$($compverkey[0])')" -foregroundcolor yellow
              write-host "$($avs[$av].display) reports '$($vckey.$i_vcval)' for 'Up-To-Date' (Expected : '$($compverkey[1])')" -foregroundcolor yellow
              if (([version]$($global:o_AVVersion) -ge [version]$($compverkey[0])) -and 
                ([version]$($vckey.$i_vcval) -ge [version]$($compverkey[1]))) {
                  $global:o_AVStatus = "Up-to-Date : $($true) (REG Check)`r`n"
              } elseif (([version]$($global:o_AVVersion) -lt [version]$($compverkey[0])) -or 
                ([version]$($vckey.$i_vcval) -lt [version]$($compverkey[1]))) {
                  $global:o_AVStatus = "Up-to-Date : $($false) (REG Check)`r`n"
              }
              $global:o_AVStatus += "Core Version : $($global:o_AVVersion) - Expected : '$($compverkey[0])'`r`n"
              $global:o_AVStatus += "VC Version : $($vckey.$i_vcval) - Expected : '$($compverkey[1])'`r`n"
            } catch {
              write-host "Could not validate Registry data : -path 'HKLM:$($i_vckey)' -name '$($i_vcval)'" -foregroundcolor red
              $global:o_AVStatus = "Up-to-Date : Unknown (REG Check)`r`n"
              write-host $_.scriptstacktrace
              write-host $_
            }
          }
          #GET PRIMARY AV PRODUCT LAST UPDATE TIMESTAMP VIA REGISTRY
          try {
            write-host "Reading : -path 'HKLM:$($i_update)' -name '$($i_updateval)'" -foregroundcolor yellow
            $updatekey = get-itemproperty -path "HKLM:$($i_update)" -name "$($i_updateval)" -erroraction stop
            if ($avs[$av].display -match "Windows Defender") {                                      #WINDOWS DEFENDER LAST UPDATE TIMESTAMP
              $Int64Value = [System.BitConverter]::ToInt64($updatekey.$i_updateval, 0)
              $time = [DateTime]::FromFileTime($Int64Value)
              $update = Get-Date($time)
              $global:o_AVStatus += "Last Major Update : $(Get-EpochDate($($update))("sec"))`r`n"
              $age = new-timespan -start $update -end (Get-Date)
            } elseif ($avs[$av].display -notmatch "Windows Defender") {                             #ALL OTHER AV LAST UPDATE TIMESTAMP
              if ($avs[$av].display -match "Symantec") {                                            #SYMANTEC AV UPDATE TIMESTAMP
                $global:o_AVStatus += "Last Major Update : $(Get-EpochDate($($updatekey.$i_updateval))("msec"))`r`n"
                $age = new-timespan -start (Get-EpochDate($updatekey.$i_updateval)("msec")) -end (Get-Date)
              } elseif ($avs[$av].display -notmatch "Symantec") {                                   #ALL OTHER AV LAST UPDATE TIMESTAMP
                $global:o_AVStatus += "Last Major Update : $(Get-EpochDate($($updatekey.$i_updateval))("sec"))`r`n"
                $age = new-timespan -start (Get-EpochDate($updatekey.$i_updateval)("sec")) -end (Get-Date)
              }
            }
            $global:o_AVStatus += "Days Since Update (DD:HH:MM) : $($age.tostring("dd\:hh\:mm"))`r`n"
          } catch {
            write-host "Could not validate Registry data : -path 'HKLM:$($i_update)' -name '$($i_updateval)'" -foregroundcolor red
            $global:o_AVStatus += "Last Major Update : N/A`r`n"
            $global:o_AVStatus += "Days Since Update (DD:HH:MM) : N/A`r`n"
            write-host $_.scriptstacktrace
            write-host $_
          }
          #GET PRIMARY AV PRODUCT REAL-TIME SCANNING
          try {
            write-host "Reading : -path 'HKLM:$($i_rtkey)' -name '$($i_rtval)'" -foregroundcolor yellow
            $rtkey = get-itemproperty -path "HKLM:$($i_rtkey)" -name "$($i_rtval)" -erroraction stop
            $global:o_RTstate = "$($rtkey.$i_rtval)"
            #INTERPRET 'REAL-TIME SCANNING' STATUS BASED ON ANY AV PRODUCT VALUE REPRESENTATION
            if ($global:zRealTime -contains $avs[$av].display) {                                    #AV PRODUCTS TREATING '0' AS 'ENABLED' FOR 'REAL-TIME SCANNING'
              write-host "$($avs[$av].display) reports '$($rtkey.$i_rtval)' for 'Real-Time Scanning' (Expected : '0')" -foregroundcolor yellow
              if ($rtkey.$i_rtval -eq 0) {
                $global:o_RTstate = "Enabled (REG Check)`r`n"
              } elseif ($rtkey.$i_rtval -eq 1) {
                $global:o_RTstate = "Disabled (REG Check)`r`n"
              } else {
                $global:o_RTstate = "Unknown (REG Check)`r`n"
              }
            } elseif ($global:zRealTime -notcontains $avs[$av].display) {                           #AV PRODUCTS TREATING '1' AS 'ENABLED' FOR 'REAL-TIME SCANNING'
              write-host "$($avs[$av].display) reports '$($rtkey.$i_rtval)' for 'Real-Time Scanning' (Expected : '1')" -foregroundcolor yellow
              if ($rtkey.$i_rtval -eq 1) {
                $global:o_RTstate = "Enabled (REG Check)`r`n"
              } elseif ($rtkey.$i_rtval -eq 0) {
                $global:o_RTstate = "Disabled (REG Check)`r`n"
              } else {
                $global:o_RTstate = "Unknown (REG Check)`r`n"
              }
            }
          } catch {
            write-host "Could not validate Registry data : -path 'HKLM:$($i_rtkey)' -name '$($i_rtval)'" -foregroundcolor red
            $global:o_RTstate = "N/A (REG Check)`r`n"
            write-host $_.scriptstacktrace
            write-host $_
          }
          $global:o_AVStatus += "Real-Time Scanning : $($global:o_RTstate)"
          #GET PRIMARY AV PRODUCT TAMPER PROTECTION STATUS
          try {
            if ($avs[$av].display -notmatch "Sophos Intercept X") {
              write-host "Reading : -path 'HKLM:$($i_tamper)' -name '$($i_tamperval)'" -foregroundcolor yellow
              $tamperkey = get-itemproperty -path "HKLM:$($i_tamper)" -name "$($i_tamperval)" -erroraction stop
              $tval = "$($tamperkey.$i_tamperval)"
            } elseif ($avs[$av].display -match "Sophos Intercept X") {
              write-host "Reading : -path 'HKLM:$($i_tamper)' -name '$($i_tamperval)'" -foregroundcolor yellow
              $tamperkey = get-childitem -path "HKLM:$($i_tamper)" -erroraction stop
              foreach ($tkey in $tamperkey) {
                $tamperkey = get-itemproperty -path "HKLM:$($i_tamper)$($tkey.PSChildName)\tamper_protection" -name "$($i_tamperval)" -erroraction stop
                $tval = "$($tamperkey.$i_tamperval)"
                break
              }
            }
            #INTERPRET 'TAMPER PROTECTION' STATUS BASED ON ANY AV PRODUCT VALUE REPRESENTATION
            if ($avs[$av].display -match "Windows Defender") {                                      #WINDOWS DEFENDER TREATS '5' AS 'ENABLED' FOR 'TAMPER PROTECTION'
              write-host "$($avs[$av].display) reports '$($tval)' for 'Tamper Protection' (Expected : '5')" -foregroundcolor yellow
              if ($tval -eq 5) {
                $tamper = "$($true) (REG Check)"
              } elseif ($tval -le 4) {
                $tamper = "$($false) (REG Check)"
              } else {
                $tamper = "Unknown (REG Check)"
              }
            } elseif ($global:zTamper -contains $avs[$av].display) {                                #AV PRODUCTS TREATING '0' AS 'ENABLED' FOR 'TAMPER PROTECTION'
              write-host "$($avs[$av].display) reports '$($tval)' for 'Tamper Protection' (Expected : '0')" -foregroundcolor yellow
              if ($tval -eq 0) {
                $tamper = "$($true) (REG Check)"
              } elseif ($tval -eq 1) {
                $tamper = "$($false) (REG Check)"
              } else {
                $tamper = "Unknown (REG Check)"
              }
            } elseif ($global:zTamper -notcontains $avs[$av].display) {                             #AV PRODUCTS TREATING '1' AS 'ENABLED' FOR 'TAMPER PROTECTION'
              write-host "$($avs[$av].display) reports '$($tval)' for 'Tamper Protection' (Expected : '1')" -foregroundcolor yellow
              if ($tval -eq 1) {
                $tamper = "$($true) (REG Check)"
              } elseif ($tval -eq 0) {
                $tamper = "$($false) (REG Check)"
              } else {
                $tamper = "Unknown (REG Check)"
              }
            }
          } catch {
            write-host "Could not validate Registry data : -path 'HKLM:$($i_tamper)' -name '$($i_tamperval)'" -foregroundcolor red
            $tamper = "Unknown (REG Check)"
            write-host $_.scriptstacktrace
            write-host $_
          }
          $global:o_AVStatus += "Tamper Protection : $($tamper)"
          #GET PRIMARY AV PRODUCT LAST SCAN DETAILS
          $lastage = 0
          if ($avs[$av].display -match "Windows Defender") {                                        #WINDOWS DEFENDER SCAN DATA
            try {
              write-host "Reading : -path 'HKLM:$($i_scan)' -name '$($i_scantype)'" -foregroundcolor yellow
              $typekey = get-itemproperty -path "HKLM:$($i_scan)" -name "$($i_scantype)" -erroraction stop
              if ($typekey.$i_scantype -eq 1) {
                $scans += "Scan Type : Quick Scan (REG Check)`r`n"
              } elseif ($typekey.$i_scantype -eq 2) {
                $scans += "Scan Type : Full Scan (REG Check)`r`n"
              }
            } catch {
              write-host "Could not validate Registry data : -path 'HKLM:$($i_scan)' -name '$($i_scantype)'" -foregroundcolor red
              $scans += "Scan Type : N/A (REG Check)`r`n"
              write-host $_.scriptstacktrace
              write-host $_
            }
            try {
              write-host "Reading : -path 'HKLM:$($i_scan)' -name '$($i_scanval)'" -foregroundcolor yellow
              $scankey = get-itemproperty -path "HKLM:$($i_scan)" -name "$($i_scanval)" -erroraction stop
              $Int64Value = [System.BitConverter]::ToInt64($scankey.$i_scanval,0)
              $stime = Get-Date([DateTime]::FromFileTime($Int64Value))
              $lastage = new-timespan -start $stime -end (Get-Date)
              $scans += "Last Scan Time : $($stime) (REG Check)`r`n"
            } catch {
              write-host "Could not validate Registry data : -path 'HKLM:$($i_scan)' -name '$($i_scanval)'" -foregroundcolor red
              $scans += "Last Scan Time : N/A (REG Check)`r`nRecently Scanned : $($false) (REG Check)"
              write-host $_.scriptstacktrace
              write-host $_
            }
          } elseif ($avs[$av].display -notmatch "Windows Defender") {                               #NON-WINDOWS DEFENDER SCAN DATA
            if ($avs[$av].display -match "Sophos") {                                                #SOPHOS SCAN DATA
              try {
                if ($avs[$av].display -match "Sophos Intercept X") {
                  write-host "Reading : -path 'HKLM:$($i_scan)'" -foregroundcolor yellow
                  $scankey = get-itemproperty -path "HKLM:$($i_scan)" -name "$($i_scanval)" -erroraction stop
                  $stime = [datetime]::ParseExact($scankey.$i_scanval,'yyyyMMddTHHmmssK',[Globalization.CultureInfo]::InvariantCulture)
                  $scans += "Scan Type : BackgroundScanV2 (REG Check)`r`nLast Scan Time : $($stime) (REG Check)`r`n"
                  $lastage = new-timespan -start $stime -end (Get-Date)
                } elseif ($avs[$av].display -notmatch "Sophos Intercept X") {
                  write-host "Reading : -path 'HKLM:$($i_scan)'" -foregroundcolor yellow
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
                write-host "Could not validate Registry data : -path 'HKLM:$($i_scan)'" -foregroundcolor red
                $scans = "Scan Type : N/A (REG Check)`r`nLast Scan Time : N/A (REG Check)`r`nRecently Scanned : $($false) (REG Check)"
                write-host $_.scriptstacktrace
                write-host $_
              }
            } elseif ($avs[$av].display -match "Symantec") {                                        #SYMANTEC SCAN DATA
              try {
                write-host "Reading : -path 'HKLM:$($i_scan)' -name '$($i_scanval)'" -foregroundcolor yellow
                $scankey = get-itemproperty -path "HKLM:$($i_scan)" -name "$($i_scanval)" -erroraction stop
                $scans += "Scan Type : N/A (REG Check)`r`nLast Scan Time : $(Get-Date($scankey.$i_scanval)) (REG Check)`r`n"
                $lastage = new-timespan -start ($scankey.$i_scanval) -end (Get-Date)
              } catch {
                write-host "Could not validate Registry data : -path 'HKLM:$($i_scan)' -name '$($i_scanval)'" -foregroundcolor red
                $scans = "Scan Type : N/A (REG Check)`r`nLast Scan Time : N/A`r`nRecently Scanned : $($false) (REG Check)"
                write-host $_.scriptstacktrace
                write-host $_
              }
            }
          }
          if ($lastage -ne 0) {
            $time1 = New-TimeSpan -days 5
            if ($lastage.compareto($time1) -le 0) {
              $scans += "Recently Scanned : $($true) (REG Check)"
            } elseif ($lastage.compareto($time1) -gt 0) {
              $scans += "Recently Scanned : $($false) (REG Check)"
            }
          }
          $global:o_AVStatus += "`r`n$($scans)"
          #GET PRIMARY AV PRODUCT DEFINITIONS / SIGNATURES / PATTERN
          if ($global:blnWMI) {
            #will still return if it is unknown, etc. if it is unknown look at the code it returns, then look up the status and add it above
            Get-AVState $global:pskey $avs[$av].stat
            $global:o_DefStatus = "$($global:defstatus)`r`n"
          } elseif (-not $global:blnWMI) {
            $global:o_DefStatus = "N/A (WMI Check)`r`n"
          }
          try {
            $time1 = New-TimeSpan -days 1
            write-host "Reading : -path 'HKLM:$($i_defupdate)' -name '$($i_defupdateval)'" -foregroundcolor yellow
            $defkey = get-itemproperty -path "HKLM:$($i_defupdate)" -name "$($i_defupdateval)" -erroraction stop
            if ($avs[$av].display -match "Windows Defender") {                                      #WINDOWS DEFENDER DEFINITION UPDATE TIMESTAMP
              $Int64Value = [System.BitConverter]::ToInt64($defkey.$i_defupdateval,0)
              $time = [DateTime]::FromFileTime($Int64Value)
              $update = Get-Date($time)
              $age = new-timespan -start $update -end (Get-Date)
              if ($age.compareto($time1) -le 0) {
                $global:o_DefStatus += "Definition Status : Up to date (REG Check)`r`n"
              } elseif ($age.compareto($time1) -gt 0) {
                $global:o_DefStatus += "Definition Status : Out of date (REG Check)`r`n"
              }
              $global:o_DefStatus += "Last Definition Update : $($update)`r`n"
            } elseif ($avs[$av].display -notmatch "Windows Defender") {                             #ALL OTHER AV DEFINITION UPDATE TIMESTAMP
              if ($avs[$av].display -match "Symantec") {                                            #SYMANTEC DEFINITION UPDATE TIMESTAMP
                $age = new-timespan -start ($defkey.$i_defupdateval) -end (Get-Date)
                if ($age.compareto($time1) -le 0) {
                  $global:o_DefStatus += "Definition Status : Up to date (REG Check)`r`n"
                } elseif ($age.compareto($time1) -gt 0) {
                  $global:o_DefStatus += "Definition Status : Out of date (REG Check)`r`n"
                }
                $global:o_DefStatus += "Last Definition Update : $($defkey.$i_defupdateval)`r`n"
              } elseif ($avs[$av].display -notmatch "Symantec") {                                   #NON-SYMANTEC DEFINITION UPDATE TIMESTAMP
                $age = new-timespan -start (Get-EpochDate($defkey.$i_defupdateval)("sec")) -end (Get-Date)
                if ($age.compareto($time1) -le 0) {
                  $global:o_DefStatus += "Definition Status : Up to date (REG Check)`r`n"
                } elseif ($age.compareto($time1) -gt 0) {
                  $global:o_DefStatus += "Definition Status : Out of date (REG Check)`r`n"
                }
                $global:o_DefStatus += "Last Definition Update : $(Get-EpochDate($($defkey.$i_defupdateval))("sec"))`r`n"
              }
            }
            $global:o_DefStatus += "Definition Age (DD:HH:MM) : $($age.tostring("dd\:hh\:mm"))"
          } catch {
            write-host "Could not validate Registry data : -path 'HKLM:$($i_defupdate)' -name '$($i_defupdateval)'" -foregroundcolor red
            $global:o_DefStatus += "Definition Status : Out of date (REG Check)`r`n"
            $global:o_DefStatus += "Last Definition Update : N/A`r`n"
            $global:o_DefStatus += "Definition Age (DD:HH:MM) : N/A"
            write-host $_.scriptstacktrace
            write-host $_
          }
          $global:o_DefStatus = "Definition Status : $($global:o_DefStatus)"
          #GET PRIMARY AV PRODUCT DETECTED ALERTS VIA REGISTRY
          if ($global:zNoAlert -notcontains $i_PAV) {
            if ($i_PAV -match "Sophos") {
              try {
                write-host "Reading : -path 'HKLM:$($i_alert)'" -foregroundcolor yellow
                $alertkey = get-ItemProperty -path "HKLM:$($i_alert)" -erroraction silentlycontinue
                foreach ($alert in $alertkey.psobject.Properties) {
                  if (($alert.name -notlike "PS*") -and ($alert.name -notlike "(default)")) {
                    if ($alert.value -eq 0) {
                      $global:o_Infect += "Type - $($alert.name) : $($false)`r`n"
                    } elseif ($alert.value -eq 1) {
                      $global:o_Infect += "Type - $($alert.name) : $($true)`r`n"
                    }
                  }
                }
              } catch {
                write-host "Could not validate Registry data : 'HKLM:$($i_alert)'" -foregroundcolor red
                $global:o_Infect = "N/A`r`n"
                write-host $_.scriptstacktrace
                write-host $_
              }
            }
            # NOT ACTUAL DETECTIONS - SAVE BELOW CODE FOR 'CONFIGURED ALERTS' METRIC
            #elseif ($i_PAV -match "Trend Micro") {
            #  if ($global:producttype -eq "Workstation") {
            #    $i_alert += "Client"
            #    write-host "Reading : -path 'HKLM:$i_alert'" -foregroundcolor yellow
            #    $alertkey = get-ItemProperty -path "HKLM:$i_alert" -erroraction silentlycontinue
            #  } elseif (($global:producttype -eq "Server") -or ($global:producttype -eq "DC")) {
            #    $i_alert += "Server"
            #    write-host "Reading : -path 'HKLM:$i_alert'" -foregroundcolor yellow
            #    $alertkey = get-ItemProperty -path "HKLM:$i_alert" -erroraction silentlycontinue
            #  }
            #  foreach ($alert in $alertkey.psobject.Properties) {
            #    if (($alert.name -notlike "PS*") -and ($alert.name -notlike "(default)")) {
            #      if ($alert.value -eq 0) {
            #        $global:o_Infect += "Type - $($alert.name) : $false`r`n"
            #      } elseif ($alert.value -eq 1) {
            #        $global:o_Infect += "Type - $($alert.name) : $true`r`n"
            #      }
            #    }
            #  }
            #}
          }
          #GET PRIMARY AV PRODUCT DETECTED INFECTIONS VIA REGISTRY
          if ($global:zNoInfect -notcontains $i_PAV) {
            if ($i_PAV -match "Sophos") {                                                           #SOPHOS DETECTED INFECTIONS
              try {
                write-host "Reading : -path 'HKLM:$($i_infect)'" -foregroundcolor yellow
                $infectkey = get-ItemProperty -path "HKLM:$($i_infect)" -erroraction silentlycontinue
                foreach ($infect in $infectkey.psobject.Properties) {                               #ENUMERATE EACH DETECTED INFECTION
                  if (($infect.name -notlike "PS*") -and ($infect.name -notlike "(default)")) {
                    if ($infect.value -eq 0) {
                      $global:o_Infect += "Type - $($infect.name) : $($false)`r`n"
                    } elseif ($infect.value -eq 1) {
                      $global:o_Infect += "Type - $($infect.name) : $($true)`r`n"
                    }
                  }
                }
              } catch {
                write-host "Could not validate Registry data : 'HKLM:$($i_infect)'" -foregroundcolor red
                $global:o_Infect += "Virus/Malware Present : N/A`r`n"
                write-host $_.scriptstacktrace
                write-host $_
              }
            } elseif ($i_PAV -match "Trend Micro") {                                                #TREND MICRO DETECTED INFECTIONS
              try {
                write-host "Reading : -path 'HKLM:$($i_infect)' -name '$($i_infectval)'" -foregroundcolor yellow
                $infectkey = get-ItemProperty -path "HKLM:$($i_infect)" -name "$($i_infectval)" -erroraction silentlycontinue
                if ($infectkey.$i_infectval -eq 0) {                                                #NO DETECTED INFECTIONS
                  $global:o_Infect += "Virus/Malware Present : $($false)`r`nVirus/Malware Count : $($infectkey.$i_infectval)`r`n"
                } elseif ($infectkey.$i_infectval -gt 0) {                                          #DETECTED INFECTIONS
                  $global:o_Infect += "Virus/Malware Present : $($true)`r`nVirus/Malware Count : $($infectkey.$i_infectval)`r`n"
                }
              } catch {
                write-host "Could not validate Registry data : 'HKLM:$($i_infect)' -name '$($i_infectval)'" -foregroundcolor red
                $global:o_Infect += "Virus/Malware Present : N/A`r`n"
                write-host $_.scriptstacktrace
                write-host $_
              }
            } elseif ($i_PAV -match "Symantec") {                                                   #SYMANTEC DETECTED INFECTIONS
              try {
                write-host "Reading : -path 'HKLM:$($i_infect)' -name '$($i_infectval)'" -foregroundcolor yellow
                $infectkey = get-ItemProperty -path "HKLM:$($i_infect)" -name "$($i_infectval)" -erroraction silentlycontinue
                if ($infectkey.$i_infectval -eq 0) {                                                #NO DETECTED INFECTIONS
                  $global:o_Infect += "Virus/Malware Present : $($false)`r`n"
                } elseif ($infectkey.$i_infectval -gt 0) {                                          #DETECTED INFECTIONS
                  try {
                    write-host "Reading : -path 'HKLM:$($i_scan)' -name 'WorstInfectionType'" -foregroundcolor yellow
                    $worstkey = get-ItemProperty -path "HKLM:$($i_scan)" -name "WorstInfectionType" -erroraction silentlycontinue
                    $worst = SEP-Map($worstkey.WorstInfectionType)
                  } catch {
                    write-host "Could not validate Registry data : 'HKLM:$($i_scan)' -name 'WorstInfectionType'" -foregroundcolor red
                    $worst = "N/A"
                    write-host $_.scriptstacktrace
                    write-host $_
                  }
                  $global:o_Infect += "Virus/Malware Present : $($true)`r`nWorst Infection Type : $($worst)`r`n"
                }
              } catch {
                write-host "Could not validate Registry data : 'HKLM:$($i_infect)' -name '$($i_infectval)'" -foregroundcolor red
                $global:o_Infect += "Virus/Malware Present : N/A`r`nWorst Infection Type : N/A`r`n"
                write-host $_.scriptstacktrace
                write-host $_
              }
            }
          }
          #GET PRIMARY AV PRODUCT DETECTED THREATS VIA REGISTRY
          if ($global:zNoThreat -notcontains $i_PAV) {
            try {
              write-host "Reading : -path 'HKLM:$($i_threat)'" -foregroundcolor yellow
              $threatkey = get-childitem -path "HKLM:$($i_threat)" -erroraction silentlycontinue
              if ($i_PAV -match "Sophos") {
                if ($threatkey.count -gt 0) {
                  foreach ($threat in $threatkey) {
                    $threattype = get-itemproperty -path "HKLM:$($i_threat)\$($threat.PSChildName)\" -name "Type" -erroraction silentlycontinue
                    $threatfile = get-childitem -path "HKLM:$($i_threat)\$($threat.PSChildName)\Files\" -erroraction silentlycontinue
                    $global:o_Threats += "Threat : $($threat.PSChildName) - Type : $($threattype.type) - Path : "
                    foreach ($detection in $threatfile) {
                      try {
                        $threatpath = get-itemproperty -path "HKLM:$($i_threat)\$($threat.PSChildName)\Files\$($threatfile.PSChildName)\" -name "Path" -erroraction silentlycontinue
                        $global:o_Threats += "$($threatpath.path)"
                      } catch {
                        $global:o_Threats += "N/A"
                        write-host $_.scriptstacktrace
                        write-host $_
                      }
                    }
                    $global:o_Threats += "`r`n"
                  }
                } elseif ($threatkey.count -le 0) {
                  $global:o_Threats += "N/A`r`n"
                }
              }
            } catch {
              write-host "Could not validate Registry data : 'HKLM:$($i_threat)'" -foregroundcolor red
              $global:o_Threats = "N/A`r`n"
              write-host $_.scriptstacktrace
              write-host $_
            }
          }
        #SAVE WINDOWS DEFENDER FOR LAST - TO PREVENT SCRIPT CONSIDERING IT 'COMPETITOR AV' WHEN SET AS PRIMARY AV
        } elseif ($avs[$av].display -eq "Windows Defender") {
          $global:o_CompAV += "$($avs[$av].display)`r`n"
          $global:o_CompPath += "$($avs[$av].path)`r`n"
          if ($global:blnWMI) {
            Get-AVState $global:pskey $avs[$av].stat
            $global:o_CompState += "$($avs[$av].display) - Real-Time Scanning : $($global:rtstatus) - Definitions : $($global:defstatus)`r`n"
          } elseif (-not $global:blnWMI) {
            $global:o_CompState += "$($avs[$av].display) - Real-Time Scanning : $($avs[$av].rt) - Definitions : N/A (WMI Check)`r`n"
          } 
        }
      }
    }
  }
}
#OUTPUT
if (($global:o_AVname -match "No AV Product Found") -or ($global:o_AVname -match "Selected AV Product Not Found")) {
  $ccode = "red"
} else {
  $ccode = "green"
}
#DEVICE INFO
write-host "`r`nDevice Info :" -foregroundcolor yellow
write-host "Device : $($global:computername)" -foregroundcolor $ccode
write-host "Operating System : $($global:OSCaption) ($($global:OSVersion))" -foregroundcolor $ccode
#AV DETAILS
write-host "`r`nAV Details :" -foregroundcolor yellow
write-host "AV Display Name : $($global:o_AVname)" -foregroundcolor $ccode
write-host "AV Path : $($global:o_AVpath)" -foregroundcolor $ccode
write-host "`r`nAV Status :" -foregroundcolor yellow
write-host "$($global:o_AVStatus)" -foregroundcolor $ccode
write-host "`r`nComponent Versions :" -foregroundcolor yellow
write-host "$($o_compver)" -foregroundcolor $ccode
$global:o_AVStatus += "`r`n`r`n$($o_compver)`r`n"
#REAL-TIME SCANNING & DEFINITIONS
write-host "Definitions :" -foregroundcolor yellow
write-host "Status : $($global:o_DefStatus)" -foregroundcolor $ccode
#THREATS
write-host "`r`nActive Detections :" -foregroundcolor yellow
write-host "$($global:o_Infect)" -foregroundcolor $ccode
write-host "Detected Threats :" -foregroundcolor yellow
write-host "$($global:o_Threats)" -foregroundcolor $ccode
#COMPETITOR AV
write-host "Competitor AV :" -foregroundcolor yellow
write-host "AV Conflict : $($global:o_AVcon)" -foregroundcolor $ccode
write-host "$($global:o_CompAV)" -foregroundcolor $ccode
write-host "Competitor Path :" -foregroundcolor yellow
write-host "$($global:o_CompPath)" -foregroundcolor $ccode
write-host "Competitor State :" -foregroundcolor yellow
write-host "$($global:o_CompState)" -foregroundcolor $ccode
#REFORMAT OUTPUT METRICS FOR LEGIBILITY IN NCENTRAL
#AV DETAILS
if (($global:o_AVname -ne "") -and ($global:o_AVname -ne $null)) {$global:o_AVname = $global:o_AVname.replace("`r`n", "<br>")}
if (($global:o_AVpath -ne "") -and ($global:o_AVpath -ne $null)) {$global:o_AVpath = $global:o_AVpath.replace("`r`n", "<br>")}
if (($global:o_AVVersion -ne "") -and ($global:o_AVVersion -ne $null)) {$global:o_AVVersion = $global:o_AVVersion.replace("`r`n", "<br>")}
if (($global:o_AVStatus -ne "") -and ($global:o_AVStatus -ne $null)) {$global:o_AVStatus = $global:o_AVStatus.replace("`r`n", "<br>")}
#REAL-TIME SCANNING & DEFINITIONS
if (($global:o_RTstate -ne "") -and ($global:o_RTstate -ne $null)) {$global:o_RTstate = $global:o_RTstate.replace("`r`n", "<br>")}
if (($global:o_DefStatus -ne "") -and ($global:o_DefStatus -ne $null)) {$global:o_DefStatus = $global:o_DefStatus.replace("`r`n", "<br>")}
#THREATS
if (($global:o_Infect -ne "") -and ($global:o_Infect -ne $null)) {$global:o_Infect = $global:o_Infect.replace("`r`n", "<br>")}
if (($global:o_Threats -ne "") -and ($global:o_Threats -ne $null)) {$global:o_Threats = $global:o_Threats.replace("`r`n", "<br>")}
#COMPETITOR AV
if (($global:o_CompAV -ne "") -and ($global:o_CompAV -ne $null)) {$global:o_CompAV = $global:o_CompAV.replace("`r`n", "<br>")}
if (($global:o_CompPath -ne "") -and ($global:o_CompPath -ne $null)) {$global:o_CompPath = $global:o_CompPath.replace("`r`n", "<br>")}
if (($global:o_CompState -ne "") -and ($global:o_CompState -ne $null)) {$global:o_CompState = $global:o_CompState.replace("`r`n", "<br>")}
#END SCRIPT
#------------