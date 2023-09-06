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
    Version        : 0.2.0 (04 March 2022)
    Creation Date  : 14 December 2021
    Purpose/Change : Provide Primary AV Product Status and Report Possible AV Conflicts
    File Name      : AVHealth_0.2.0.ps1 
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
          Added '$script:ncxml<vendor>' variables for assigning static 'fallback' sources for AV Product XMLs; XMLs should be uploaded to NC Script Repository and URLs updated (Begin Ln148)
            The above 'Fallback' method is to allow for uploading AV Product XML files to NCentral Script Repository to attempt to support older OSes which cannot securely connect to GitHub (Requires using "Compatibility" mode for NC Network Security)
    0.2.0 Optimization and more bugfixes
          Forked script to implement 'AV Health' script into Datto RMM
          Planning to re-organize repo to account for implementation of scripts to multiple RMM platforms

.TODO
    Still need more AV Product registry samples for identifying keys to monitor for relevant data
    Need to obtain version and calculate date timestamps for AV Product updates, Definition updates, and Last Scan
    Need to obtain Infection Status and Detected Threats; bonus for timestamps for these metrics - Partially Complete (Sophos - full support; Trend Micro - 'Active Detections Present / Count')
        Do other AVs report individual Threat information in the registry? Sophos does; but if others don't will we be able to use this metric?
        Still need to determine if timestamps are possible for detected threats
    Need to create a 'Get-AVProducts' function and move looped 'detection' code into a function to call
#> 

#REGION ----- DECLARATIONS ----
  Import-Module $env:SyncroModule
  #BELOW PARAM() MUST BE COMMENTED OUT FOR USE WITHIN SYNCRO RMM
  #UNCOMMENT BELOW PARAM() TO UTILIZE IN CLI
  #Param(
  #  [Parameter(Mandatory=$true)]$i_PAV
  #)
  $script:bitarch = $null
  $script:OSCaption = $null
  $script:OSVersion = $null
  $script:producttype = $null
  $script:computername = $null
  $script:blnWMI = $true
  $script:blnPAV = $false
  $script:blnAVXML = $true
  $script:avs = @{}
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
      $state
    )
    #Switch to determine the status of antivirus definitions and real-time protection.
    #THIS COULD PROBABLY ALSO BE TURNED INTO A SIMPLE XML / JSON LOOKUP TO FACILITATE COMMUNITY CONTRIBUTION
    switch ($state) {
      #AVG IS 2012 AV / CrowdStrike / Kaspersky
      "262144" {$script:defstatus = "Up to date (WMI Check)" ;$script:rtstatus = "Disabled (WMI Check)"}
      "266240" {$script:defstatus = "Up to date (WMI Check)" ;$script:rtstatus = "Enabled (WMI Check)"}
      #AVG IS 2012 FW
      "266256" {$script:defstatus = "Out of date (WMI Check)" ;$script:rtstatus = "Enabled (WMI Check)"}
      "262160" {$script:defstatus = "Out of date (WMI Check)" ;$script:rtstatus = "Disabled (WMI Check)"}
      #MSSE
      "393216" {$script:defstatus = "Up to date (WMI Check)" ;$script:rtstatus = "Disabled (WMI Check)"}
      "397312" {$script:defstatus = "Up to date (WMI Check)" ;$script:rtstatus = "Enabled (WMI Check)"}
      #Windows Defender
      "393472" {$script:defstatus = "Up to date (WMI Check)" ;$script:rtstatus = "Disabled (WMI Check)"}
      "397584" {$script:defstatus = "Out of date (WMI Check)" ;$script:rtstatus = "Enabled (WMI Check)"}
      "397568" {$script:defstatus = "Up to date (WMI Check)" ;$script:rtstatus = "Enabled (WMI Check)"}
      "401664" {$script:defstatus = "Up to date (WMI Check)" ;$script:rtstatus = "Disabled (WMI Check)"}
      #
      "393232" {$script:defstatus = "Out of date (WMI Check)" ;$script:rtstatus = "Disabled (WMI Check)"}
      "393488" {$script:defstatus = "Out of date (WMI Check)" ;$script:rtstatus = "Disabled (WMI Check)"}
      "397328" {$script:defstatus = "Out of date (WMI Check)" ;$script:rtstatus = "Enabled (WMI Check)"}
      #Sophos
      "331776" {$script:defstatus = "Up to date (WMI Check)" ;$script:rtstatus = "Enabled (WMI Check)"}
      "335872" {$script:defstatus = "Up to date (WMI Check)" ;$script:rtstatus = "Disabled (WMI Check)"}
      #Norton Security
      "327696" {$script:defstatus = "Out of date (WMI Check)" ;$script:rtstatus = "Disabled (WMI Check)"}
      default {$script:defstatus = "Unknown (WMI Check)" ;$script:rtstatus = "Unknown (WMI Check)"}
    }
  } ## Get-AVState
  
  function Get-AVXML {                                                                              #RETRIEVE AV VENDOR XML FROM GITHUB
    param (
      $src, $dest
    )
    #$dest = @{}
    $script:blnAVXML = $true
    #RETRIEVE AV VENDOR XML FROM GITHUB
    write-output "Loading : '$($src)' AV Product XML"
    $srcAVP = "https://raw.githubusercontent.com/CW-Khristos/scripts/master/AVProducts/" + $src.replace(" ", "").replace("-", "").tolower() + ".xml"
    try {
      $avXML = New-Object System.Xml.XmlDocument
      $avXML.Load($srcAVP)
    } catch {
      write-output "XML.Load() - Could not open $($srcAVP)"
      try {
        $web = new-object system.net.webclient
        [xml]$avXML = $web.DownloadString($srcAVP)
      } catch {
        write-output "Web.DownloadString() - Could not download $($srcAVP)"
        try {
          start-bitstransfer -erroraction stop -source $srcAVP -destination "C:\IT\Scripts\" + $src.replace(" ", "").replace("-", "").tolower() + ".xml"
          [xml]$avXML = "C:\IT\Scripts\" + $src.replace(" ", "").replace("-", "").tolower() + ".xml"
        } catch {
          write-output "BITS.Transfer() - Could not download $($srcAVP)"
          $script:blnAVXML = $false
        }
      }
    }
    #NABLE FALLBACK IF GITHUB IS NOT ACCESSIBLE
    if (-not $script:blnAVXML) {
      write-output "Failed : AV Product XML Retrieval from GitHub; Attempting download from NAble Server"
      write-output "Loading : '$($src)' AV Product XML"
      switch ($src) {
        "Sophos" {$srcAVP = $script:ncxmlSOPHOS}
        "Symantec" {$srcAVP = $script:ncxmlSYMANTEC}
        "Trend Micro" {$srcAVP = $script:ncxmlTRENDMICRO}
        "Windows Defender" {$srcAVP = $script:ncxmlWINDEFEND}
      }
      try {
        $avXML = New-Object System.Xml.XmlDocument
        $avXML.Load($srcAVP)
        $script:blnAVXML = $true
      } catch {
        write-output "XML.Load() - Could not open $($srcAVP)"
        try {
          $web = new-object system.net.webclient
          [xml]$avXML = $web.DownloadString($srcAVP)
          $script:blnAVXML = $true
        } catch {
          write-output "Web.DownloadString() - Could not download $($srcAVP)"
          try {
            start-bitstransfer -erroraction stop -source $srcAVP -destination "C:\IT\Scripts\" + $src.replace(" ", "").replace("-", "").tolower() + ".xml"
            [xml]$avXML = "C:\IT\Scripts\" + $src.replace(" ", "").replace("-", "").tolower() + ".xml"
            $script:blnAVXML = $true
          } catch {
            write-output "BITS.Transfer() - Could not download $($srcAVP)"
            $script:blnAVXML = $false
          }
        }
      }
    }
    #READ PRIMARY AV PRODUCT VENDOR XML DATA INTO NESTED HASHTABLE FOR LATER USE
    try {
      if ($script:blnAVXML) {
        foreach ($itm in $avXML.NODE.ChildNodes) {
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
          if ($dest.containskey($itm.name)) {
            continue
          } elseif (-not $dest.containskey($itm.name)) {
            $dest.add($itm.name, $hash)
          }
        }
      }
    } catch {
      write-output $_.scriptstacktrace
      write-output $_
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
      write-output $_.scriptstacktrace
      write-output $_
    }
  } ## Pop-Components

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
#ENDREGION ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
Get-OSArch
Get-AVXML $i_PAV $script:pavkey
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
      write-output "`r`nFailed to query WMI SecurityCenter Namespace"
      write-output "Possibly Server, attempting to fallback to using 'HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\' registry key"
      try {                                                                                         #QUERY 'HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\' AND SEE IF AN AV IS REGISTRERED THERE
        if ($script:bitarch = "bit64") {
          $AntiVirusProduct = (get-itemproperty -path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Security Center\Monitoring\*" -ErrorAction Stop).PSChildName
        } elseif ($script:bitarch = "bit32") {
          $AntiVirusProduct = (get-itemproperty -path "HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\*" -ErrorAction Stop).PSChildName
        }
      } catch {
        write-output "Could not find AV registered in HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\*"
        $AntiVirusProduct = $null
        $blnSecMon = $true
      }
      if ($AntiVirusProduct -ne $null) {                                                            #RETURNED 'HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\' DATA
        $strDisplay = $null
        $blnSecMon = $false
        write-output "`r`nPerforming AV Product discovery"
        foreach ($av in $AntiVirusProduct) {
          #PRIMARY AV REGISTERED UNDER 'HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\'
          if ($av -match $i_PAV) {
            $script:blnPAV = $true
          } elseif (($i_PAV -eq "Trend Micro") -and ($av -match "Worry-Free Business Security")) {
            $script:blnPAV = $true
          }
          write-output "`r`nFound 'HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\$($av)'"
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
              write-output "Matched AV : '$($av)' - '$($key)' AV Product"
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
                write-output "Found 'HKLM:$($regDisplay)' for product : $($key)"
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
                  write-output "Could not validate Registry data for product : $($key)"
                  write-output $_.scriptstacktrace
                  write-output $_
                }
              }
            }
          } catch {
            write-output "Not Found 'HKLM:$regDisplay' for product : $($key)"
            write-output $_.scriptstacktrace
            write-output $_
          }
        }
      }
      if (($AntiVirusProduct -eq $null) -or (-not $script:blnPAV)) {                                #FAILED TO RETURN 'HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\' DATA
        $strDisplay = $null
        $blnSecMon = $true
        #RETRIEVE EACH VENDOR XML AND CHECK FOR ALL SUPPORTED AV PRODUCTS
        write-output "`r`nPrimary AV Product not found / No AV Products found; will check each AV Product in all Vendor XMLs"
        foreach ($vendor in $script:avVendors) {
          Get-AVXML $vendor $script:vavkey
        }
        foreach ($key in $script:vavkey.keys) {                                                     #ATTEMPT TO VALIDATE EACH AV PRODUCT CONTAINED IN VENDOR XML
          if ($key -notmatch "#comment") {                                                          #AVOID ODD 'BUG' WITH A KEY AS '#comment' WHEN SWITCHING AV VENDOR XMLS
            write-output "Attempting to detect AV Product : '$($key)'"
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
                write-output "Found 'HKLM:$($regDisplay)' for product : $($key)"
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
                    write-output "Creating Registry Key HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\$strName for product : $($strName)"
                    if ($script:bitarch = "bit64") {
                      try {
                        new-item -path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Security Center\Monitoring\" -name "$($strName)" -value "$($strName)" -force
                      } catch {
                        write-output "Could not create Registry Key `HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\$($strName) for product : $($strName)"
                        write-output $_.scriptstacktrace
                        write-output $_
                      }
                    } elseif ($script:bitarch = "bit32") {
                      try {
                        new-item -path "HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\" -name "$($strName)" -value "$($strName)" -force
                      } catch {
                        write-output "Could not create Registry Key `HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\$($strName) for product : $($strName)"
                        write-output $_.scriptstacktrace
                        write-output $_
                      }
                    }
                  }
                  $AntiVirusProduct = "."
                } catch {
                  write-output "Could not validate Registry data for product : $($key)"
                  write-output $_.scriptstacktrace
                  write-output $_
                  $AntiVirusProduct = $null
                }
              }
            } catch {
              write-output "Not Found 'HKLM:$($regDisplay)' for product : $($key)"
              write-output $_.scriptstacktrace
              write-output $_
            }
          }
        }
      }
      $tmpavs = $strDisplay -split ", "
      $tmppaths = $strPath -split ", "
      $tmprts = $strRealTime -split ", "
      $tmpstats = $strStat -split ", "
    } catch {
      write-output "Failed to validate supported AV Products"
      write-output $_.scriptstacktrace
      write-output $_
    }
  } elseif ($script:blnWMI) {                                                                       #RETURNED WMI SECURITYCENTER NAMESPACE
    #SEPARATE RETURNED WMI AV PRODUCT INSTANCES
    if ($AntiVirusProduct -ne $null) {                                                              #RETURNED WMI AV PRODUCT DATA
      $tmpavs = $AntiVirusProduct.displayName -split ", "
      $tmppaths = $AntiVirusProduct.pathToSignedProductExe -split ", "
      $tmpstats = $AntiVirusProduct.productState -split ", "
    } elseif ($AntiVirusProduct -eq $null) {                                                        #FAILED TO RETURN WMI AV PRODUCT DATA
      $strDisplay = ""
      #RETRIEVE EACH VENDOR XML AND CHECK FOR ALL SUPPORTED AV PRODUCTS
      write-output "`r`nPrimary AV Product not found / No AV Products found; will check each AV Product in all Vendor XMLs"
      foreach ($vendor in $script:avVendors) {
        Get-AVXML $vendor $script:vavkey
      }
      foreach ($key in $script:vavkey.keys) {                                                       #ATTEMPT TO VALIDATE EACH AV PRODUCT CONTAINED IN VENDOR XML
        if ($key -notmatch "#comment") {                                                            #AVOID ODD 'BUG' WITH A KEY AS '#comment' WHEN SWITCHING AV VENDOR XMLS
          write-output "Attempting to detect AV Product : '$($key)'"
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
              write-output "Found 'HKLM:$($regDisplay)' for product : $($key)"
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
                write-output "Could not validate Registry data for product : $($key)"
                write-output $_.scriptstacktrace
                write-output $_
                $AntiVirusProduct = $null
              }
            }
          } catch {
            write-output "Not Found 'HKLM:$($regDisplay)' for product : $($key)"
            write-output $_.scriptstacktrace
            write-output $_
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
  write-output "`r`nAV Product discovery completed`r`n"
  if ($AntiVirusProduct -eq $null) {                                                                #NO AV PRODUCT FOUND
    $AntiVirusProduct
    write-output "Could not find any AV Product registered"
    $script:o_AVname = "No AV Product Found"
    $script:o_AVVersion = $null
    $script:o_AVpath = $null
    $script:o_AVStatus = "Unknown"
    $script:o_RTstate = "Unknown"
    $script:o_DefStatus = "Unknown"
    $script:o_AVcon = 0
  } elseif ($AntiVirusProduct -ne $null) {                                                          #FOUND AV PRODUCTS
    foreach ($av in $avs.keys) {                                                                    #ITERATE THROUGH EACH FOUND AV PRODUCT
      if (($avs[$av].display -ne $null) -and ($avs[$av].display -ne "")) {
        #NEITHER PRIMARY AV PRODUCT NOR WINDOWS DEFENDER
        if (($avs[$av].display -notmatch $i_PAV) -and ($avs[$av].display -notmatch "Windows Defender")) {
          if (($i_PAV -eq "Trend Micro") -and (($avs[$av].display -notmatch "Trend Micro") -and ($avs[$av].display -notmatch "Worry-Free Business Security"))) {
            $script:o_AVcon = 1
            $script:o_CompAV += "$($avs[$av].display)`r`n"
            $script:o_CompPath += "$($avs[$av].path)`r`n"
            if ($script:blnWMI) {
              Get-AVState($avs[$av].stat)
              $script:o_CompState += "$($avs[$av].display) - Real-Time Scanning : $($script:rtstatus) - Definitions : $($script:defstatus)`r`n"
            } elseif (-not $script:blnWMI) {
              $script:o_CompState += "$($avs[$av].display) - Real-Time Scanning : $($avs[$av].rt) - Definitions : N/A (WMI Check)`r`n"
            }
          } elseif ($i_PAV -ne "Trend Micro") {
            $script:o_AVcon = 1
            $script:o_CompAV += "$($avs[$av].display)`r`n"
            $script:o_CompPath += "$($avs[$av].path)`r`n"
            if ($script:blnWMI) {
              Get-AVState($avs[$av].stat)
              $script:o_CompState += "$($avs[$av].display) - Real-Time Scanning : $($script:rtstatus) - Definitions : $($script:defstatus)`r`n"
            } elseif (-not $script:blnWMI) {
              $script:o_CompState += "$($avs[$av].display) - Real-Time Scanning : $($avs[$av].rt) - Definitions : N/A (WMI Check)`r`n"
            }
          }
        }
        #PRIMARY AV PRODUCT
        if (($avs[$av].display -match $i_PAV) -or 
          (($i_PAV -eq "Trend Micro") -and (($avs[$av].display -match "Trend Micro") -or ($avs[$av].display -match "Worry-Free Business Security")))) {
          #PARSE XML FOR SPECIFIC VENDOR AV PRODUCT
          $node = $avs[$av].display.replace(" ", "").replace("-", "").toupper()
          #AV DETAILS
          $script:o_AVname = $avs[$av].display
          $script:o_AVpath = $avs[$av].path
          #AV PRODUCT VERSION
          $i_verkey = $script:pavkey[$node].ver
          $i_verval = $script:pavkey[$node].verval
          #AV PRODUCT COMPONENTS VERSIONS
          $i_compverkey = $script:pavkey[$node].compver
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
            write-output "Reading : -path 'HKLM:$($i_verkey)' -name '$($i_verval)'"
            $script:o_AVVersion = get-itemproperty -path "HKLM:$($i_verkey)" -name "$($i_verval)" -erroraction stop
          } catch {
            write-output "Could not validate Registry data : -path 'HKLM:$($i_verkey)' -name '$($i_verval)'"
            $script:o_AVVersion = "."
            write-output $_.scriptstacktrace
            write-output $_
          }
          $script:o_AVVersion = "$($script:o_AVVersion.$i_verval)"
          #GET PRIMARY AV PRODUCT COMPONENT VERSIONS
          $o_compver = "Core Version : $($script:o_AVVersion)`r`n"
          try {
            write-output "Reading : -path 'HKLM:$($i_compverkey)'"
            if ($i_PAV -match "Sophos") {
              $compverkey = get-childitem -path "HKLM:$($i_compverkey)" -erroraction silentlycontinue
              foreach ($component in $compverkey) {
                if (($component -ne $null) -and ($component -ne "")) {
                  $longname = get-itemproperty -path "HKLM:$($i_compverkey)$($component.PSChildName)" -name "LongName" -erroraction silentlycontinue
                  $installver = get-itemproperty -path "HKLM:$($i_compverkey)$($component.PSChildName)" -name "InstalledVersion" -erroraction silentlycontinue
                  Pop-Components $script:compkey $($longname.LongName) $($installver.InstalledVersion)
                }
              }
              $sort = $script:compkey.GetEnumerator() | sort -Property name
              foreach ($component in $sort) {
                $o_compver += "$($component.name) Version : $($component.value)`r`n"
              }
            }
          } catch {
            write-output "Could not validate Registry data : 'HKLM:$($i_compverkey)' for '$($component.PSChildName)'"
            $o_compver = "Components : N/A"
            write-output $_.scriptstacktrace
            write-output $_
          }
          #GET AV PRODUCT UPDATE SOURCE
          try {
            write-output "Reading : -path 'HKLM:$($i_source)' -name '$($i_sourceval)'"
            $sourcekey = get-itemproperty -path "HKLM:$($i_source)" -name "$($i_sourceval)" -erroraction stop
            $script:o_AVStatus = "Update Source : $($sourcekey.$i_sourceval)`r`n"
          } catch {
            write-output "Could not validate Registry data : -path 'HKLM:$($i_source)' -name '$($i_sourceval)'"
            $script:o_AVStatus = "Update Source : Unknown`r`n"
            write-output $_.scriptstacktrace
            write-output $_
          }
          #GET PRIMARY AV PRODUCT STATUS VIA REGISTRY
          try {
            write-output "Reading : -path 'HKLM:$($i_statkey)' -name '$($i_statval)'"
            $statkey = get-itemproperty -path "HKLM:$($i_statkey)" -name "$($i_statval)" -erroraction stop
            #INTERPRET 'AVSTATUS' BASED ON ANY AV PRODUCT VALUE REPRESENTATION
            if ($script:zUpgrade -contains $avs[$av].display) {                                     #AV PRODUCTS TREATING '0' AS 'UPTODATE'
              write-output "$($avs[$av].display) reports '$($statkey.$i_statval)' for 'Up-To-Date' (Expected : '0')"
              if ($statkey.$i_statval -eq "0") {
                $script:o_AVStatus = "Up-to-Date : $($true) (REG Check)`r`n"
              } else {
                $script:o_AVStatus = "Up-to-Date : $($false) (REG Check)`r`n"
              }
            } elseif ($script:zUpgrade -notcontains $avs[$av].display) {                            #AV PRODUCTS TREATING '1' AS 'UPTODATE'
              write-output "$($avs[$av].display) reports '$($statkey.$i_statval)' for 'Up-To-Date' (Expected : '1')"
              if ($statkey.$i_statval -eq "1") {
                $script:o_AVStatus = "Up-to-Date : $($true) (REG Check)`r`n"
              } else {
                $script:o_AVStatus = "Up-to-Date : $($false) (REG Check)`r`n"
              }
            }
          } catch {
            write-output "Could not validate Registry data : -path 'HKLM:$($i_statkey)' -name '$($i_statval)'"
            $script:o_AVStatus = "Up-to-Date : Unknown (REG Check)`r`n"
            write-output $_.scriptstacktrace
            write-output $_
          }
          #GET PRIMARY AV PRODUCT LAST UPDATE TIMESTAMP VIA REGISTRY
          try {
            write-output "Reading : -path 'HKLM:$($i_update)' -name '$($i_updateval)'"
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
            write-output "Could not validate Registry data : -path 'HKLM:$($i_update)' -name '$($i_updateval)'"
            $script:o_AVStatus += "Last Major Update : N/A`r`n"
            $script:o_AVStatus += "Days Since Update (DD:HH:MM) : N/A`r`n"
            write-output $_.scriptstacktrace
            write-output $_
          }
          #GET PRIMARY AV PRODUCT REAL-TIME SCANNING
          try {
            write-output "Reading : -path 'HKLM:$($i_rtkey)' -name '$($i_rtval)'"
            $rtkey = get-itemproperty -path "HKLM:$($i_rtkey)" -name "$($i_rtval)" -erroraction stop
            $script:o_RTstate = "$($rtkey.$i_rtval)"
            #INTERPRET 'REAL-TIME SCANNING' STATUS BASED ON ANY AV PRODUCT VALUE REPRESENTATION
            if ($script:zRealTime -contains $avs[$av].display) {                                    #AV PRODUCTS TREATING '0' AS 'ENABLED' FOR 'REAL-TIME SCANNING'
              write-output "$($avs[$av].display) reports '$($rtkey.$i_rtval)' for 'Real-Time Scanning' (Expected : '0')"
              if ($rtkey.$i_rtval -eq 0) {
                $script:o_RTstate = "Enabled (REG Check)`r`n"
              } elseif ($rtkey.$i_rtval -eq 1) {
                $script:o_RTstate = "Disabled (REG Check)`r`n"
              } else {
                $script:o_RTstate = "Unknown (REG Check)`r`n"
              }
            } elseif ($script:zRealTime -notcontains $avs[$av].display) {                           #AV PRODUCTS TREATING '1' AS 'ENABLED' FOR 'REAL-TIME SCANNING'
              write-output "$($avs[$av].display) reports '$($rtkey.$i_rtval)' for 'Real-Time Scanning' (Expected : '1')"
              if ($rtkey.$i_rtval -eq 1) {
                $script:o_RTstate = "Enabled (REG Check)`r`n"
              } elseif ($rtkey.$i_rtval -eq 0) {
                $script:o_RTstate = "Disabled (REG Check)`r`n"
              } else {
                $script:o_RTstate = "Unknown (REG Check)`r`n"
              }
            }
          } catch {
            write-output "Could not validate Registry data : -path 'HKLM:$($i_rtkey)' -name '$($i_rtval)'"
            $script:o_RTstate = "N/A (REG Check)`r`n"
            write-output $_.scriptstacktrace
            write-output $_
          }
          $script:o_AVStatus += "Real-Time Status : $($script:o_RTstate)"
          #GET PRIMARY AV PRODUCT TAMPER PROTECTION STATUS
          try {
            if ($avs[$av].display -notmatch "Sophos Intercept X") {
              write-output "Reading : -path 'HKLM:$($i_tamper)' -name '$($i_tamperval)'"
              $tamperkey = get-itemproperty -path "HKLM:$($i_tamper)" -name "$($i_tamperval)" -erroraction stop
              $tval = "$($tamperkey.$i_tamperval)"
            } elseif ($avs[$av].display -match "Sophos Intercept X") {
              write-output "Reading : -path 'HKLM:$($i_tamper)' -name '$($i_tamperval)'"
              $tamperkey = get-childitem -path "HKLM:$($i_tamper)" -erroraction stop
              foreach ($tkey in $tamperkey) {
                $tamperkey = get-itemproperty -path "HKLM:$($i_tamper)$($tkey.PSChildName)\tamper_protection" -name "$($i_tamperval)" -erroraction stop
                $tval = "$($tamperkey.$i_tamperval)"
                break
              }
            }
            #INTERPRET 'TAMPER PROTECTION' STATUS BASED ON ANY AV PRODUCT VALUE REPRESENTATION
            if ($avs[$av].display -match "Windows Defender") {                                      #WINDOWS DEFENDER TREATS '5' AS 'ENABLED' FOR 'TAMPER PROTECTION'
              write-output "$($avs[$av].display) reports '$($tval)' for 'Tamper Protection' (Expected : '5')"
              if ($tval -eq 5) {
                $tamper = "$($true) (REG Check)"
              } elseif ($tval -le 4) {
                $tamper = "$($false) (REG Check)"
              } else {
                $tamper = "Unknown (REG Check)"
              }
            } elseif ($script:zTamper -contains $avs[$av].display) {                                #AV PRODUCTS TREATING '0' AS 'ENABLED' FOR 'TAMPER PROTECTION'
              write-output "$($avs[$av].display) reports '$($tval)' for 'Tamper Protection' (Expected : '0')"
              if ($tval -eq 0) {
                $tamper = "$($true) (REG Check)"
              } elseif ($tval -eq 1) {
                $tamper = "$($false) (REG Check)"
              } else {
                $tamper = "Unknown (REG Check)"
              }
            } elseif ($script:zTamper -notcontains $avs[$av].display) {                             #AV PRODUCTS TREATING '1' AS 'ENABLED' FOR 'TAMPER PROTECTION'
              write-output "$($avs[$av].display) reports '$($tval)' for 'Tamper Protection' (Expected : '1')"
              if ($tval -eq 1) {
                $tamper = "$($true) (REG Check)"
              } elseif ($tval -eq 0) {
                $tamper = "$($false) (REG Check)"
              } else {
                $tamper = "Unknown (REG Check)"
              }
            }
          } catch {
            write-output "Could not validate Registry data : -path 'HKLM:$($i_tamper)' -name '$($i_tamperval)'"
            $tamper = "Unknown (REG Check)"
            write-output $_.scriptstacktrace
            write-output $_
          }
          $script:o_AVStatus += "Tamper Protection : $($tamper)`r`n"
          #GET PRIMARY AV PRODUCT LAST SCAN DETAILS
          $lastage = 0
          if ($avs[$av].display -match "Windows Defender") {                                        #WINDOWS DEFENDER SCAN DATA
            try {
              write-output "Reading : -path 'HKLM:$($i_scan)' -name '$($i_scantype)'"
              $typekey = get-itemproperty -path "HKLM:$($i_scan)" -name "$($i_scantype)" -erroraction stop
              if ($typekey.$i_scantype -eq 1) {
                $scans += "Scan Type : Quick Scan (REG Check)`r`n"
              } elseif ($typekey.$i_scantype -eq 2) {
                $scans += "Scan Type : Full Scan (REG Check)`r`n"
              }
            } catch {
              write-output "Could not validate Registry data : -path 'HKLM:$($i_scan)' -name '$($i_scantype)'"
              $scans += "Scan Type : N/A (REG Check)`r`n"
              write-output $_.scriptstacktrace
              write-output $_
            }
            try {
              write-output "Reading : -path 'HKLM:$($i_scan)' -name '$($i_scanval)'"
              $scankey = get-itemproperty -path "HKLM:$($i_scan)" -name "$($i_scanval)" -erroraction stop
              $Int64Value = [System.BitConverter]::ToInt64($scankey.$i_scanval,0)
              $stime = Get-Date([DateTime]::FromFileTime($Int64Value))
              $lastage = new-timespan -start $stime -end (Get-Date)
              $scans += "Last Scan Time : $($stime) (REG Check)`r`n"
            } catch {
              write-output "Could not validate Registry data : -path 'HKLM:$($i_scan)' -name '$($i_scanval)'"
              $scans += "Last Scan Time : N/A (REG Check)`r`nRecently Scanned : $($false) (REG Check)"
              write-output $_.scriptstacktrace
              write-output $_
            }
          } elseif ($avs[$av].display -notmatch "Windows Defender") {                               #NON-WINDOWS DEFENDER SCAN DATA
            if ($avs[$av].display -match "Sophos") {                                                #SOPHOS SCAN DATA
              try {
                if ($avs[$av].display -match "Sophos Intercept X") {
                  write-output "Reading : -path 'HKLM:$($i_scan)'"
                  $scankey = get-itemproperty -path "HKLM:$($i_scan)" -name "$($i_scanval)" -erroraction stop
                  $stime = [datetime]::ParseExact($scankey.$i_scanval,'yyyyMMddTHHmmssK',[Globalization.CultureInfo]::InvariantCulture)
                  $scans += "Scan Type : BackgroundScanV2 (REG Check)`r`nLast Scan Time : $($stime) (REG Check)`r`n"
                  $lastage = new-timespan -start $stime -end (Get-Date)
                } elseif ($avs[$av].display -notmatch "Sophos Intercept X") {
                  write-output "Reading : -path 'HKLM:$($i_scan)'"
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
                write-output "Could not validate Registry data : -path 'HKLM:$($i_scan)'"
                $scans = "Scan Type : N/A (REG Check)`r`nLast Scan Time : N/A (REG Check)`r`nRecently Scanned : $($false) (REG Check)"
                write-output $_.scriptstacktrace
                write-output $_
              }
            } elseif ($avs[$av].display -match "Symantec") {                                        #SYMANTEC SCAN DATA
              try {
                write-output "Reading : -path 'HKLM:$($i_scan)' -name '$($i_scanval)'"
                $scankey = get-itemproperty -path "HKLM:$($i_scan)" -name "$($i_scanval)" -erroraction stop
                $scans += "Scan Type : N/A (REG Check)`r`nLast Scan Time : $(Get-Date($scankey.$i_scanval)) (REG Check)`r`n"
                $lastage = new-timespan -start ($scankey.$i_scanval) -end (Get-Date)
              } catch {
                write-output "Could not validate Registry data : -path 'HKLM:$($i_scan)' -name '$($i_scanval)'"
                $scans = "Scan Type : N/A (REG Check)`r`nLast Scan Time : N/A`r`nRecently Scanned : $($false) (REG Check)"
                write-output $_.scriptstacktrace
                write-output $_
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
          $script:o_AVStatus += $scans
          #GET PRIMARY AV PRODUCT DEFINITIONS / SIGNATURES / PATTERN
          if ($script:blnWMI) {
            #will still return if it is unknown, etc. if it is unknown look at the code it returns, then look up the status and add it above
            Get-AVState($avs[$av].stat)
            $script:o_DefStatus = "$($script:defstatus)`r`n"
          } elseif (-not $script:blnWMI) {
            $script:o_DefStatus = "N/A (WMI Check)`r`n"
          }
          try {
            $time1 = New-TimeSpan -days 1
            write-output "Reading : -path 'HKLM:$($i_defupdate)' -name '$($i_defupdateval)'"
            $defkey = get-itemproperty -path "HKLM:$($i_defupdate)" -name "$($i_defupdateval)" -erroraction stop
            if ($avs[$av].display -match "Windows Defender") {                                      #WINDOWS DEFENDER DEFINITION UPDATE TIMESTAMP
              $Int64Value = [System.BitConverter]::ToInt64($defkey.$i_defupdateval,0)
              $time = [DateTime]::FromFileTime($Int64Value)
              $update = Get-Date($time)
              $age = new-timespan -start $update -end (Get-Date)
              if ($age.compareto($time1) -le 0) {
                $script:o_DefStatus += "Status : Up to date (REG Check)`r`n"
              } elseif ($age.compareto($time1) -gt 0) {
                $script:o_DefStatus += "Status : Out of date (REG Check)`r`n"
              }
              $script:o_DefStatus += "Last Definition Update : $($update)`r`n"
            } elseif ($avs[$av].display -notmatch "Windows Defender") {                             #ALL OTHER AV DEFINITION UPDATE TIMESTAMP
              if ($avs[$av].display -match "Symantec") {                                            #SYMANTEC DEFINITION UPDATE TIMESTAMP
                $age = new-timespan -start ($defkey.$i_defupdateval) -end (Get-Date)
                if ($age.compareto($time1) -le 0) {
                  $script:o_DefStatus += "Status : Up to date (REG Check)`r`n"
                } elseif ($age.compareto($time1) -gt 0) {
                  $script:o_DefStatus += "Status : Out of date (REG Check)`r`n"
                }
                $script:o_DefStatus += "Last Definition Update : $($defkey.$i_defupdateval)`r`n"
              } elseif ($avs[$av].display -notmatch "Symantec") {                                   #NON-SYMANTEC DEFINITION UPDATE TIMESTAMP
                $age = new-timespan -start (Get-EpochDate($defkey.$i_defupdateval)("sec")) -end (Get-Date)
                if ($age.compareto($time1) -le 0) {
                  $script:o_DefStatus += "Status : Up to date (REG Check)`r`n"
                } elseif ($age.compareto($time1) -gt 0) {
                  $script:o_DefStatus += "Status : Out of date (REG Check)`r`n"
                }
                $script:o_DefStatus += "Last Definition Update : $(Get-EpochDate($($defkey.$i_defupdateval))("sec"))`r`n"
              }
            }
            $script:o_DefStatus += "Definition Age (DD:HH:MM) : $($age.tostring("dd\:hh\:mm"))"
          } catch {
            write-output "Could not validate Registry data : -path 'HKLM:$($i_defupdate)' -name '$($i_defupdateval)'"
            $script:o_DefStatus += "Status : Out of date (REG Check)`r`n"
            $script:o_DefStatus += "Last Definition Update : N/A`r`n"
            $script:o_DefStatus += "Definition Age (DD:HH:MM) : N/A"
            write-output $_.scriptstacktrace
            write-output $_
          }
          #GET PRIMARY AV PRODUCT DETECTED ALERTS VIA REGISTRY
          if ($script:zNoAlert -notcontains $i_PAV) {
            if ($i_PAV -match "Sophos") {
              try {
                write-output "Reading : -path 'HKLM:$($i_alert)'"
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
              } catch {
                write-output "Could not validate Registry data : 'HKLM:$($i_alert)'"
                $script:o_Infect = "N/A`r`n"
                write-output $_.scriptstacktrace
                write-output $_
              }
            }
            # NOT ACTUAL DETECTIONS - SAVE BELOW CODE FOR 'CONFIGURED ALERTS' METRIC
            #elseif ($i_PAV -match "Trend Micro") {
            #  if ($script:producttype -eq "Workstation") {
            #    $i_alert += "Client"
            #    write-output "Reading : -path 'HKLM:$i_alert'"
            #    $alertkey = get-ItemProperty -path "HKLM:$i_alert" -erroraction silentlycontinue
            #  } elseif (($script:producttype -eq "Server") -or ($script:producttype -eq "DC")) {
            #    $i_alert += "Server"
            #    write-output "Reading : -path 'HKLM:$i_alert'"
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
          }
          #GET PRIMARY AV PRODUCT DETECTED INFECTIONS VIA REGISTRY
          if ($script:zNoInfect -notcontains $i_PAV) {
            if ($i_PAV -match "Sophos") {                                                           #SOPHOS DETECTED INFECTIONS
              try {
                write-output "Reading : -path 'HKLM:$($i_infect)'"
                $infectkey = get-ItemProperty -path "HKLM:$($i_infect)" -erroraction silentlycontinue
                foreach ($infect in $infectkey.psobject.Properties) {                               #ENUMERATE EACH DETECTED INFECTION
                  if (($infect.name -notlike "PS*") -and ($infect.name -notlike "(default)")) {
                    if ($infect.value -eq 0) {
                      $script:o_Infect += "Type - $($infect.name) : $($false)`r`n"
                    } elseif ($infect.value -eq 1) {
                      $script:o_Infect += "Type - $($infect.name) : $($true)`r`n"
                    }
                  }
                }
              } catch {
                write-output "Could not validate Registry data : 'HKLM:$($i_infect)'"
                $script:o_Infect += "Virus/Malware Present : N/A`r`n"
                write-output $_.scriptstacktrace
                write-output $_
              }
            } elseif ($i_PAV -match "Trend Micro") {                                                #TREND MICRO DETECTED INFECTIONS
              try {
                write-output "Reading : -path 'HKLM:$($i_infect)' -name '$($i_infectval)'"
                $infectkey = get-ItemProperty -path "HKLM:$($i_infect)" -name "$($i_infectval)" -erroraction silentlycontinue
                if ($infectkey.$i_infectval -eq 0) {                                                #NO DETECTED INFECTIONS
                  $script:o_Infect += "Virus/Malware Present : $($false)`r`nVirus/Malware Count : $($infectkey.$i_infectval)`r`n"
                } elseif ($infectkey.$i_infectval -gt 0) {                                          #DETECTED INFECTIONS
                  $script:o_Infect += "Virus/Malware Present : $($true)`r`nVirus/Malware Count : $($infectkey.$i_infectval)`r`n"
                }
              } catch {
                write-output "Could not validate Registry data : 'HKLM:$($i_infect)' -name '$($i_infectval)'"
                $script:o_Infect += "Virus/Malware Present : N/A`r`n"
                write-output $_.scriptstacktrace
                write-output $_
              }
            } elseif ($i_PAV -match "Symantec") {                                                   #SYMANTEC DETECTED INFECTIONS
              try {
                write-output "Reading : -path 'HKLM:$($i_infect)' -name '$($i_infectval)'"
                $infectkey = get-ItemProperty -path "HKLM:$($i_infect)" -name "$($i_infectval)" -erroraction silentlycontinue
                if ($infectkey.$i_infectval -eq 0) {                                                #NO DETECTED INFECTIONS
                  $script:o_Infect += "Virus/Malware Present : $($false)`r`n"
                } elseif ($infectkey.$i_infectval -gt 0) {                                          #DETECTED INFECTIONS
                  try {
                    write-output "Reading : -path 'HKLM:$($i_scan)' -name 'WorstInfectionType'"
                    $worstkey = get-ItemProperty -path "HKLM:$($i_scan)" -name "WorstInfectionType" -erroraction silentlycontinue
                    $worst = SEP-Map($worstkey.WorstInfectionType)
                  } catch {
                    write-output "Could not validate Registry data : 'HKLM:$($i_scan)' -name 'WorstInfectionType'"
                    $worst = "N/A"
                    write-output $_.scriptstacktrace
                    write-output $_
                  }
                  $script:o_Infect += "Virus/Malware Present : $($true)`r`nWorst Infection Type : $($worst)`r`n"
                }
              } catch {
                write-output "Could not validate Registry data : 'HKLM:$($i_infect)' -name '$($i_infectval)'"
                $script:o_Infect += "Virus/Malware Present : N/A`r`nWorst Infection Type : N/A`r`n"
                write-output $_.scriptstacktrace
                write-output $_
              }
            }
          }
          #GET PRIMARY AV PRODUCT DETECTED THREATS VIA REGISTRY
          if ($script:zNoThreat -notcontains $i_PAV) {
            try {
              write-output "Reading : -path 'HKLM:$($i_threat)'"
              $threatkey = get-childitem -path "HKLM:$($i_threat)" -erroraction silentlycontinue
              if ($i_PAV -match "Sophos") {
                if ($threatkey.count -gt 0) {
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
                        write-output $_.scriptstacktrace
                        write-output $_
                      }
                    }
                    $script:o_Threats += "`r`n"
                  }
                } elseif ($threatkey.count -le 0) {
                  $script:o_Threats += "N/A`r`n"
                }
              }
            } catch {
              write-output "Could not validate Registry data : 'HKLM:$($i_threat)'"
              $script:o_Threats = "N/A`r`n"
              write-output $_.scriptstacktrace
              write-output $_
            }
          }
        #SAVE WINDOWS DEFENDER FOR LAST - TO PREVENT SCRIPT CONSIDERING IT 'COMPETITOR AV' WHEN SET AS PRIMARY AV
        } elseif ($avs[$av].display -eq "Windows Defender") {
          $script:o_CompAV += "$($avs[$av].display)`r`n"
          $script:o_CompPath += "$($avs[$av].path)`r`n"
          if ($script:blnWMI) {
            Get-AVState($avs[$av].stat)
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
write-output "`r`nDevice Info :"
write-output "Device : $($script:computername)" -foregroundcolor $ccode
write-output "Operating System : $($script:OSCaption) ($($script:OSVersion))" -foregroundcolor $ccode
$allout += "`r`nDevice Info :`r`nDevice : $($script:computername)`r`n"
$allout += "Operating System : $($script:OSCaption) ($($script:OSVersion))`r`n"
#AV DETAILS
write-output "`r`nAV Details :"
write-output "AV Display Name : $($script:o_AVname)" -foregroundcolor $ccode
write-output "AV Path : $($script:o_AVpath)" -foregroundcolor $ccode
write-output "`r`nAV Status :"
write-output "$($script:o_AVStatus)" -foregroundcolor $ccode
write-output "`r`nComponent Versions :"
write-output "$($o_compver)" -foregroundcolor $ccode
$allout += "`r`nAV Details :`r`nAV Display Name : $($script:o_AVname)`r`nAV Path : $($script:o_AVpath)`r`n"
$allout += "`r`nComponent Versions :`r`n$($o_compver)`r`n"
#REAL-TIME SCANNING & DEFINITIONS
write-output "Definitions :"
write-output "Status : $($script:o_DefStatus)" -foregroundcolor $ccode
$allout += "`r`nDefinitions :`r`nStatus : $($script:o_DefStatus)`r`n"
#THREATS
write-output "`r`nActive Detections :"
write-output "$($script:o_Infect)" -foregroundcolor $ccode
write-output "Detected Threats :"
write-output "$($script:o_Threats)" -foregroundcolor $ccode
$allout += "`r`nActive Detections :`r`n$($script:o_Infect)`r`nDetected Threats :`r`n$($script:o_Threats)`r`n"
#COMPETITOR AV
write-output "Competitor AV :"
write-output "AV Conflict : $($script:o_AVcon)" -foregroundcolor $ccode
write-output "$($script:o_CompAV)" -foregroundcolor $ccode
write-output "Competitor Path :"
write-output "$($script:o_CompPath)" -foregroundcolor $ccode
write-output "Competitor State :"
write-output "$($script:o_CompState)" -foregroundcolor $ccode
$allout += "`r`nCompetitor AV :`r`nAV Conflict : $($script:o_AVcon)`r`n$($script:o_CompAV)"
$allout += "`r`nCompetitor Path :`r`n$($script:o_CompPath)`r`nCompetitor State :`r`n$($script:o_CompState)"
# This creates an alert in Syncro and triggers the "New RMM Alert" in the Notification Center - automatically de-duping per asset.
Rmm-Alert -Category 'AV Health Warning' -Body "$($allout)"
#END SCRIPT
#------------