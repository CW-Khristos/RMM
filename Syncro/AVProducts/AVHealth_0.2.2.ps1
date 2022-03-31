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
    Version        : 0.2.2 (15 March 2022)
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
          Added '$ncxml<vendor>' variables for assigning static 'fallback' sources for AV Product XMLs; XMLs should be uploaded to NC Script Repository and URLs updated (Begin Ln166)
            The above 'Fallback' method is to allow for uploading AV Product XML files to NCentral Script Repository to attempt to support older OSes which cannot securely connect to GitHub (Requires using "Compatibility" mode for NC Network Security)
    0.2.0 Optimization and more bugfixes
          Forked script to implement 'AV Health' script into Datto RMM
          Planning to re-organize repo to account for implementation of scripts to multiple RMM platforms
    0.2.1 Optimization and more bugfixes; namely putting an end to populating the key '#comment' into Vendor AV Product and Product State hashtables due to how PS parses XML natively
          Copied and modified code to retrieve Vendor AV Product XML into 'Get-AVState' function to replace the hard-coded 'swtich' to interpret WMI AV Product States
            This implements similar XML method to interpret WMI AV Product States as with retrieving Vendor AV Product details
            This should facilitate easier community contributions to WMI AV Product States and with this change plan to leave the WMI checks in place
    0.2.2 Optimization and more bugfixes; code cleanup and enhanced diagnostic output
          Added call to 'Log-Activity' to record results to Syncro Device Activity Log for historical monitoring purposes
          Added 'Pop-Warnings' function to populate '$avwarn' hashtable for tracking AV details which did not pass checks

.TODO
    Still need more AV Product registry samples for identifying keys to monitor for relevant data
    Need to obtain version and calculate date timestamps for AV Product updates, Definition updates, and Last Scan
    Need to obtain Infection Status and Detected Threats; bonus for timestamps for these metrics - Partially Complete (Sophos - full support; Trend Micro - 'Active Detections Present / Count')
        Do other AVs report individual Threat information in the registry? Sophos does; but if others don't will we be able to use this metric?
        Still need to determine if timestamps are possible for detected threats
    Need to create a 'Get-AVProducts' function and move looped 'detection' code into a function to call
    Trend Micro continues to cause issues with properly evaluating if the core AV Client itself is up to date due to the number of 'duplicate' and inconsistent Registry Keys / Values that clutter their Registry Hive
    
#> 

#REGION ----- DECLARATIONS ----
  Import-Module $env:SyncroModule
  #BELOW PARAM() MUST BE COMMENTED OUT FOR USE WITHIN SYNCRO RMM
  #UNCOMMENT BELOW PARAM() TO UTILIZE IN CLI
  #Param(
  #  [Parameter(Mandatory=$true)]$i_PAV
  #)
  $diag = $null
  $bitarch = $null
  $OSCaption = $null
  $OSVersion = $null
  $producttype = $null
  $computername = $null
  $blnWMI = $true
  $blnPAV = $false
  $blnAVXML = $true
  $blnPSXML = $false
  $blnWARN = $false
  $avs = @{}
  $pskey = @{}
  $avwarn = @{}
  $pavkey = @{}
  $vavkey = @{}
  $compkey = @{}
  $o_AVname = "Selected AV Product Not Found"
  $o_AVVersion = "Selected AV Product Not Found"
  $o_AVpath = "Selected AV Product Not Found"
  $o_AVStatus = "Selected AV Product Not Found"
  $rtstatus = "Unknown"
  $o_RTstate = "Unknown"
  $defstatus = "Unknown"
  $o_DefStatus = "Unknown"
  $o_Infect = $null
  $o_Threats = $null
  $o_AVcon = 0
  $o_CompAV = $null
  $o_CompPath = $null
  $o_CompState = $null
  #SUPPORTED AV VENDORS
  $avVendors = @(
    "Sophos"
    "Symantec"
    "Trend Micro"
    "Windows Defender"
  )
  #AV PRODUCTS USING '0' FOR 'UP-TO-DATE' PRODUCT STATUS
  $zUpgrade = @(
    "Sophos Intercept X"
    "Symantec Endpoint Protection"
    "Trend Micro Security Agent"
    "Worry-Free Business Security"
    "Windows Defender"
  )
  #AV PRODUCTS USING '0' FOR 'REAL-TIME SCANNING' STATUS
  $zRealTime = @(
    "Symantec Endpoint Protection"
    "Windows Defender"
  )
  #AV PRODUCTS USING '0' FOR 'TAMPER PROTECTION' STATUS
  $zTamper = @(
    "Sophos Anti-Virus"
    "Symantec Endpoint Protection"
    "Windows Defender"
  )
  #AV PRODUCTS NOT SUPPORTING ALERTS DETECTIONS
  $zNoAlert = @(
    "Symantec Endpoint Protection"
    "Windows Defender"
  )
  #AV PRODUCTS NOT SUPPORTING INFECTION DETECTIONS
  $zNoInfect = @(
    "Symantec Endpoint Protection"
    "Windows Defender"
  )
  #AV PRODUCTS NOT SUPPORTING THREAT DETECTIONS
  $zNoThreat = @(
    "Symantec Endpoint Protection"
    "Trend Micro Security Agent"
    "Worry-Free Business Security"
    "Windows Defender"
  )
  #AV PRODUCT XML NC REPOSITORY URLS FOR FALLBACK - CHANGE THESE TO MATCH YOUR NCENTRAL URLS AFTER UPLOADING EACH XML TO REPO
  $ncxmlSOPHOS = "https://nableserver/download/repository/1639682702/sophos.xml"
  $ncxmlSYMANTEC = "https://nableserver/download/repository/1238159723/symantec.xml"
  $ncxmlTRENDMICRO = "https://nableserver/download/repository/308457410/trendmicro.xml"
  $ncxmlWINDEFEND = "https://nableserver/download/repository/968395355/windowsdefender.xml"
  $ncxmlPRODUCTSTATE = "https://nableserver/download/repository/968395355/productstate.xml"
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
      $bitarch = "bit64"
    } elseif ($osarch -like '*32*') {
      $bitarch = "bit32"
    }
    #OS Type & Version
    $computername = $env:computername
    $OSCaption = (Get-WmiObject Win32_OperatingSystem).Caption
    $OSVersion = (Get-WmiObject Win32_OperatingSystem).Version
    $osproduct = (Get-WmiObject -class Win32_OperatingSystem).Producttype
    Switch ($osproduct) {
      "1" {$producttype = "Workstation"}
      "2" {$producttype = "DC"}
      "3" {$producttype = "Server"}
    }
  } ## Get-OSArch

  function Get-AVState {                                                                            #DETERMINE ANTIVIRUS STATE
    param (
      $dest, $state
    )
    $xmldiag = $null
    if (-not $blnPSXML) {                                                                    #AV PRODUCT STATES NOT LOADED INTO HASHTABLE
      #$dest = @{}
      $blnPSXML = $true
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
            $blnPSXML = $false
          }
        }
      }
      #NABLE FALLBACK IF GITHUB IS NOT ACCESSIBLE
      if (-not $blnPSXML) {
        $xmldiag += "`r`nFailed : AV Product XML Retrieval from GitHub; Attempting download from NAble Server`r`n"
        $xmldiag += "Loading : '$($src)' AV Product XML`r`n"
        write-host "Failed : AV Product State XML Retrieval from GitHub; Attempting download from NAble Server" -foregroundcolor yellow
        write-host "Loading : AV Product State XML" -foregroundcolor yellow
        $srcAVP = $ncxmlPRODUCTSTATE
        try {
          $psXML = New-Object System.Xml.XmlDocument
          $psXML.Load($srcAVP)
          $blnPSXML = $true
        } catch {
          $xmldiag += "XML.Load() - Could not open $($srcAVP)`r`n"
          write-host "XML.Load() - Could not open $($srcAVP)" -foregroundcolor red
          try {
            $web = new-object system.net.webclient
            [xml]$psXML = $web.DownloadString($srcAVP)
            $blnPSXML = $true
          } catch {
            $xmldiag += "Web.DownloadString() - Could not download $($srcAVP)`r`n"
            write-host "Web.DownloadString() - Could not download $($srcAVP)" -foregroundcolor red
            try {
              start-bitstransfer -erroraction stop -source $srcAVP -destination "C:\IT\Scripts\productstate.xml"
              [xml]$psXML = "C:\IT\Scripts\productstate.xml"
              $blnPSXML = $true
            } catch {
              $xmldiag += "BITS.Transfer() - Could not download $($srcAVP)`r`n"
              write-host "BITS.Transfer() - Could not download $($srcAVP)" -foregroundcolor red
              $defstatus = "Unknown (WMI Check)`r`nUnable to download AV Product State XML"
              $rtstatus = "Unknown (WMI Check)`r`nUnable to download AV Product State XML"
              $blnPSXML = $false
            }
          }
        }
      }
      #READ AV PRODUCT STATE XML DATA INTO NESTED HASHTABLE FOR LATER USE
      try {
        if ($blnPSXML) {
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
        $blnPSXML = $false
        write-host $_.scriptstacktrace
        write-host $_
      }
    } elseif ($blnPSXML) {                                                                   #AV PRODUCT STATES ALREADY LOADED IN HASHTABLE
      #SET '$defstatus' AND '$rtstatus' TO INTERPRET PASSED PRODUCT STATE FROM POPULATED HASHTABLE
      try {
        $defstatus = $pskey["ps$($state)"].defstatus
        $rtstatus = $pskey["ps$($state)"].rtstatus
      } catch {
        $defstatus = "Unknown (WMI Check)`r`nAV Product State Unknown : $($state)"
        $rtstatus = "Unknown (WMI Check)`r`nAV Product State Unknown : $($state)"
      }
    }
    $diag += "$($xmldiag)"
    $xmldiag = $null
  } ## Get-AVState
  
  function Get-AVXML {                                                                              #RETRIEVE AV VENDOR XML FROM GITHUB
    param (
      $src, $dest
    )
    #$dest = @{}
    $xmldiag = $null
    $blnAVXML = $true
    #RETRIEVE AV VENDOR XML FROM GITHUB
    $diag += "Loading : '$($src)' AV Product XML`r`n"
    write-host "Loading : '$($src)' AV Product XML" -foregroundcolor yellow
    $srcAVP = "https://raw.githubusercontent.com/CW-Khristos/scripts/master/AVProducts/" + $src.replace(" ", "").replace("-", "").tolower() + ".xml"
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
          $blnAVXML = $false
        }
      }
    }
    #NABLE FALLBACK IF GITHUB IS NOT ACCESSIBLE
    if (-not $blnAVXML) {
      $xmldiag += "Failed : AV Product State XML Retrieval from GitHub; Attempting download from NAble Server`r`n"
      $xmldiag += "Loading : AV Product State XML`r`n"
      write-host "Failed : AV Product XML Retrieval from GitHub; Attempting download from NAble Server" -foregroundcolor yellow
      write-host "Loading : '$($src)' AV Product XML" -foregroundcolor yellow
      switch ($src) {
        "Sophos" {$srcAVP = $ncxmlSOPHOS}
        "Symantec" {$srcAVP = $ncxmlSYMANTEC}
        "Trend Micro" {$srcAVP = $ncxmlTRENDMICRO}
        "Windows Defender" {$srcAVP = $ncxmlWINDEFEND}
      }
      try {
        $avXML = New-Object System.Xml.XmlDocument
        $avXML.Load($srcAVP)
        $blnAVXML = $true
      } catch {
        $xmldiag += "XML.Load() - Could not open $($srcAVP)`r`n"
        write-host "XML.Load() - Could not open $($srcAVP)" -foregroundcolor red
        try {
          $web = new-object system.net.webclient
          [xml]$avXML = $web.DownloadString($srcAVP)
          $blnAVXML = $true
        } catch {
          $xmldiag += "Web.DownloadString() - Could not download $($srcAVP)`r`n"
          write-host "Web.DownloadString() - Could not download $($srcAVP)" -foregroundcolor red
          try {
            start-bitstransfer -erroraction stop -source $srcAVP -destination "C:\IT\Scripts\" + $src.replace(" ", "").replace("-", "").tolower() + ".xml"
            [xml]$avXML = "C:\IT\Scripts\" + $src.replace(" ", "").replace("-", "").tolower() + ".xml"
            $blnAVXML = $true
          } catch {
            $xmldiag += "BITS.Transfer() - Could not download $($srcAVP)`r`n"
            write-host "BITS.Transfer() - Could not download $($srcAVP)" -foregroundcolor red
            $blnAVXML = $false
          }
        }
      }
    }
    #READ PRIMARY AV PRODUCT VENDOR XML DATA INTO NESTED HASHTABLE FOR LATER USE
    try {
      if ($blnAVXML) {
        foreach ($itm in $avXML.NODE.ChildNodes) {
          if ($itm.name -notmatch "#comment") {                                                     #AVOID 'BUG' WITH A KEY AS '#comment'
            $hash = @{
              display = "$($itm.$bitarch.display)"
              displayval = "$($itm.$bitarch.displayval)"
              path = "$($itm.$bitarch.path)"
              pathval = "$($itm.$bitarch.pathval)"
              ver = "$($itm.$bitarch.ver)"
              verval = "$($itm.$bitarch.verval)"
              compver = "$($itm.$bitarch.compver)"
              stat = "$($itm.$bitarch.stat)"
              statval = "$($itm.$bitarch.statval)"
              update = "$($itm.$bitarch.update)"
              updateval = "$($itm.$bitarch.updateval)"
              source = "$($itm.$bitarch.source)"
              sourceval = "$($itm.$bitarch.sourceval)"
              defupdate = "$($itm.$bitarch.defupdate)"
              defupdateval = "$($itm.$bitarch.defupdateval)"
              tamper = "$($itm.$bitarch.tamper)"
              tamperval = "$($itm.$bitarch.tamperval)"
              rt = "$($itm.$bitarch.rt)"
              rtval = "$($itm.$bitarch.rtval)"
              scan = "$($itm.$bitarch.scan)"
              scantype = "$($itm.$bitarch.scantype)"
              scanval = "$($itm.$bitarch.scanval)"
              alert = "$($itm.$bitarch.alert)"
              alertval = "$($itm.$bitarch.alertval)"
              infect = "$($itm.$bitarch.infect)"
              infectval = "$($itm.$bitarch.infectval)"
              threat = "$($itm.$bitarch.threat)"
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
      write-host $_.scriptstacktrace
      write-host $_
    }
    $diag += "$($xmldiag)"
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
            foreach ($itms in $prev) {
              $new.add("$($itm)`r`n")
            }
            $new.add("$($warn)`r`n")
            $dest.remove($av)
            $dest.add($av, $new)
            $blnWARN = $true
          }
        } elseif (-not $dest.containskey($av)) {
          $new = [System.Collections.ArrayList]@()
          $new = "$($warn)`r`n"
          $dest.add($av, $new)
          $blnWARN = $true
        }
      }
    } catch {
      $warndiag = "AV Health : Error populating warnings for $($av)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n"
      write-host "AV Health : Error populating warnings for $($av)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n"
      write-host $_.scriptstacktrace
      write-host $_
      $diag += "$($warndiag)"
      $warndiag = $null
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
#ENDREGION ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
Get-OSArch
Get-AVXML $i_PAV $pavkey
if (-not ($blnAVXML)) {
  #AV DETAILS
  $o_AVname = "Selected AV Product Not Found`r`nUnable to download AV Vendor XML`r`n"
  $o_AVVersion = "Selected AV Product Not Found`r`nUnable to download AV Vendor XML`r`n"
  $o_AVpath = "Selected AV Product Not Found`r`nUnable to download AV Vendor XML`r`n"
  $o_AVStatus = "Selected AV Product Not Found`r`nUnable to download AV Vendor XML`r`n"
  #REAL-TIME SCANNING & DEFINITIONS
  $o_RTstate = "Selected AV Product Not Found`r`nUnable to download AV Vendor XML`r`n"
  $o_DefStatus = "Selected AV Product Not Found`r`nUnable to download AV Vendor XML`r`n"
  #THREATS
  $o_Infect = "Selected AV Product Not Found`r`nUnable to download AV Vendor XML`r`n"
  $o_Threats = "Selected AV Product Not Found`r`nUnable to download AV Vendor XML`r`n"
  #COMPETITOR AV
  $o_CompAV = "Selected AV Product Not Found`r`nUnable to download AV Vendor XML`r`n"
  $o_CompPath = "Selected AV Product Not Found`r`nUnable to download AV Vendor XML`r`n"
  $o_CompState = "Selected AV Product Not Found`r`nUnable to download AV Vendor XML`r`n"
  # This creates an alert in Syncro and triggers the "New RMM Alert" in the Notification Center - automatically de-duping per asset.
  Rmm-Alert -Category "AV Health : $($i_PAV) : Warning" -Body "$($diag)"
} elseif ($blnAVXML) {
  #QUERY WMI SECURITYCENTER NAMESPACE FOR AV PRODUCT DETAILS
  if ([system.version]$OSVersion -ge [system.version]'6.0.0.0') {
    write-verbose "OS Windows Vista/Server 2008 or newer detected."
    try {
      $AntiVirusProduct = get-wmiobject -Namespace "root\SecurityCenter2" -Class "AntiVirusProduct" -ComputerName "$($computername)" -ErrorAction Stop
    } catch {
      $blnWMI = $false
    }
  } elseif ([system.version]$OSVersion -lt [system.version]'6.0.0.0') {
    write-verbose "Windows 2000, 2003, XP detected" 
    try {
      $AntiVirusProduct = get-wmiobject -Namespace "root\SecurityCenter" -Class "AntiVirusProduct"  -ComputerName "$($computername)" -ErrorAction Stop
    } catch {
      $blnWMI = $false
    }
  }
  if (-not $blnWMI) {                                                                        #FAILED TO RETURN WMI SECURITYCENTER NAMESPACE
    try {
      write-host "`r`nFailed to query WMI SecurityCenter Namespace" -foregroundcolor red
      write-host "Possibly Server, attempting to fallback to using 'HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\' registry key" -foregroundcolor red
      try {                                                                                         #QUERY 'HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\' AND SEE IF AN AV IS REGISTRERED THERE
        if ($bitarch = "bit64") {
          $AntiVirusProduct = (get-itemproperty -path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Security Center\Monitoring\*" -ErrorAction Stop).PSChildName
        } elseif ($bitarch = "bit32") {
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
            $blnPAV = $true
          } elseif (($i_PAV -eq "Trend Micro") -and ($av -match "Worry-Free Business Security")) {
            $blnPAV = $true
          }
          write-host "`r`nFound 'HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\$($av)'" -foregroundcolor yellow
          #RETRIEVE DETECTED AV PRODUCT VENDOR XML
          foreach ($vendor in $avVendors) {
            if ($av -match $vendor) {
              Get-AVXML $vendor $vavkey
              break
            } elseif ($av -match "Worry-Free Business Security") {
              Get-AVXML "Trend Micro" $vavkey
              break
            }
          }
          #SEARCH PASSED PRIMARY AV VENDOR XML
          foreach ($key in $vavkey.keys) {                                                   #ATTEMPT TO VALIDATE EACH AV PRODUCT CONTAINED IN VENDOR XML
            if ($av.replace(" ", "").replace("-", "").toupper() -eq $key.toupper()) {
              write-host "Matched AV : '$($av)' - '$($key)' AV Product" -foregroundcolor yellow
              $strName = $null
              $regDisplay = "$($vavkey[$key].display)"
              $regDisplayVal = "$($vavkey[$key].displayval)"
              $regPath = "$($vavkey[$key].path)"
              $regPathVal = "$($vavkey[$key].pathval)"
              $regStat = "$($vavkey[$key].stat)"
              $regStatVal = "$($vavkey[$key].statval)"
              $regRealTime = "$($vavkey[$key].rt)"
              $regRTVal = "$($vavkey[$key].rtval)"
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
      if (($AntiVirusProduct -eq $null) -or (-not $blnPAV)) {                                #FAILED TO RETURN 'HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\' DATA
        $strDisplay = $null
        $blnSecMon = $true
        #RETRIEVE EACH VENDOR XML AND CHECK FOR ALL SUPPORTED AV PRODUCTS
        write-host "`r`nPrimary AV Product not found / No AV Products found; will check each AV Product in all Vendor XMLs" -foregroundcolor yellow
        foreach ($vendor in $avVendors) {
          Get-AVXML $vendor $vavkey
        }
        foreach ($key in $vavkey.keys) {                                                     #ATTEMPT TO VALIDATE EACH AV PRODUCT CONTAINED IN VENDOR XML
          if ($key -notmatch "#comment") {                                                          #AVOID ODD 'BUG' WITH A KEY AS '#comment' WHEN SWITCHING AV VENDOR XMLS
            write-host "Attempting to detect AV Product : '$($key)'" -foregroundcolor yellow
            $strName = $null
            $regDisplay = "$($vavkey[$key].display)"
            $regDisplayVal = "$($vavkey[$key].displayval)"
            $regPath = "$($vavkey[$key].path)"
            $regPathVal = "$($vavkey[$key].pathval)"
            $regStat = "$($vavkey[$key].stat)"
            $regStatVal = "$($vavkey[$key].statval)"
            $regRealTime = "$($vavkey[$key].rt)"
            $regRTVal = "$($vavkey[$key].rtval)"
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
                  if ($zRealTime -contains $vavkey[$key].display) {                   #AV PRODUCTS TREATING '0' AS 'ENABLED' FOR 'REAL-TIME SCANNING'
                    if ($keyval4.$regRTVal = "0") {
                      $strRealTime = "$($strRealTime)Enabled (REG Check), "
                    } elseif ($keyval4.$regRTVal = "1") {
                      $strRealTime = "$($strRealTime)Disabled (REG Check), "
                    }
                  } elseif ($zRealTime -notcontains $vavkey[$key].display) {          #AV PRODUCTS TREATING '1' AS 'ENABLED' FOR 'REAL-TIME SCANNING'
                    if ($keyval4.$regRTVal = "1") {
                      $strRealTime = "$($strRealTime)Enabled (REG Check), "
                    } elseif ($keyval4.$regRTVal = "0") {
                      $strRealTime = "$($strRealTime)Disabled (REG Check), "
                    }
                  }
                  #FABRICATE 'HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\' DATA
                  if ($blnSecMon) {
                    write-host "Creating Registry Key HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\$strName for product : $($strName)" -foregroundcolor red
                    if ($bitarch = "bit64") {
                      try {
                        new-item -path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Security Center\Monitoring\" -name "$($strName)" -value "$($strName)" -force
                      } catch {
                        write-host "Could not create Registry Key `HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\$($strName) for product : $($strName)" -foregroundcolor red
                        write-host $_.scriptstacktrace
                        write-host $_
                      }
                    } elseif ($bitarch = "bit32") {
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
  } elseif ($blnWMI) {                                                                       #RETURNED WMI SECURITYCENTER NAMESPACE
    #SEPARATE RETURNED WMI AV PRODUCT INSTANCES
    if ($AntiVirusProduct -ne $null) {                                                              #RETURNED WMI AV PRODUCT DATA
      $tmpavs = $AntiVirusProduct.displayName -split ", "
      $tmppaths = $AntiVirusProduct.pathToSignedProductExe -split ", "
      $tmpstats = $AntiVirusProduct.productState -split ", "
    } elseif ($AntiVirusProduct -eq $null) {                                                        #FAILED TO RETURN WMI AV PRODUCT DATA
      $strDisplay = ""
      #RETRIEVE EACH VENDOR XML AND CHECK FOR ALL SUPPORTED AV PRODUCTS
      write-host "`r`nPrimary AV Product not found / No AV Products found; will check each AV Product in all Vendor XMLs" -foregroundcolor yellow
      foreach ($vendor in $avVendors) {
        Get-AVXML $vendor $vavkey
      }
      foreach ($key in $vavkey.keys) {                                                       #ATTEMPT TO VALIDATE EACH AV PRODUCT CONTAINED IN VENDOR XML
        if ($key -notmatch "#comment") {                                                            #AVOID ODD 'BUG' WITH A KEY AS '#comment' WHEN SWITCHING AV VENDOR XMLS
          write-host "Attempting to detect AV Product : '$($key)'" -foregroundcolor yellow
          $strName = $null
          $regDisplay = "$($vavkey[$key].display)"
          $regDisplayVal = "$($vavkey[$key].displayval)"
          $regPath = "$($vavkey[$key].path)"
          $regPathVal = "$($vavkey[$key].pathval)"
          $regStat = "$($vavkey[$key].stat)"
          $regStatVal = "$($vavkey[$key].statval)"
          $regRealTime = "$($vavkey[$key].rt)"
          $regRTVal = "$($vavkey[$key].rtval)"
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
                if ($zRealTime -contains $vavkey[$key].display) {                     #AV PRODUCTS TREATING '0' AS 'ENABLED' FOR 'REAL-TIME SCANNING'
                  if ($keyval4.$regRTVal = "0") {
                    $strRealTime = "$($strRealTime)Enabled (REG Check), "
                  } elseif ($keyval4.$regRTVal = "1") {
                    $strRealTime = "$($strRealTime)Disabled (REG Check), "
                  }
                } elseif ($zRealTime -notcontains $vavkey[$key].display) {            #AV PRODUCTS TREATING '1' AS 'ENABLED' FOR 'REAL-TIME SCANNING'
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
  $diag += "`r`nAV Product discovery completed`r`n`r`n"
  write-host "`r`nAV Product discovery completed`r`n" -foregroundcolor yellow
  if ($AntiVirusProduct -eq $null) {                                                                #NO AV PRODUCT FOUND
    $diag += "Could not find any AV Product registered`r`n"
    write-host "Could not find any AV Product registered" -foregroundcolor red
    $o_AVname = "No AV Product Found"
    $o_AVVersion = $null
    $o_AVpath = $null
    $o_AVStatus = "Unknown"
    $o_RTstate = "Unknown"
    $o_DefStatus = "Unknown"
    $o_AVcon = 0
  } elseif ($AntiVirusProduct -ne $null) {                                                          #FOUND AV PRODUCTS
    foreach ($av in $avs.keys) {                                                                    #ITERATE THROUGH EACH FOUND AV PRODUCT
      if (($avs[$av].display -ne $null) -and ($avs[$av].display -ne "")) {
        #NEITHER PRIMARY AV PRODUCT NOR WINDOWS DEFENDER
        if (($avs[$av].display -notmatch $i_PAV) -and ($avs[$av].display -notmatch "Windows Defender")) {
          if (($i_PAV -eq "Trend Micro") -and (($avs[$av].display -notmatch "Trend Micro") -and ($avs[$av].display -notmatch "Worry-Free Business Security"))) {
            $o_AVcon = 1
            $o_CompAV += "$($avs[$av].display)`r`n"
            $o_CompPath += "$($avs[$av].path)`r`n"
            if ($blnWMI) {
              Get-AVState $pskey $avs[$av].stat
              $o_CompState += "$($avs[$av].display) - Real-Time Scanning : $($rtstatus) - Definitions : $($defstatus)`r`n"
            } elseif (-not $blnWMI) {
              $o_CompState += "$($avs[$av].display) - Real-Time Scanning : $($avs[$av].rt) - Definitions : N/A (WMI Check)`r`n"
            }
          } elseif ($i_PAV -ne "Trend Micro") {
            $o_AVcon = 1
            $o_CompAV += "$($avs[$av].display)`r`n"
            $o_CompPath += "$($avs[$av].path)`r`n"
            if ($blnWMI) {
              Get-AVState $pskey $avs[$av].stat
              $o_CompState += "$($avs[$av].display) - Real-Time Scanning : $($rtstatus) - Definitions : $($defstatus)`r`n"
            } elseif (-not $blnWMI) {
              $o_CompState += "$($avs[$av].display) - Real-Time Scanning : $($avs[$av].rt) - Definitions : N/A (WMI Check)`r`n"
            }
          }
          Pop-Warnings $avwarn $i_PAV "AV Conflict detected`r`n"
        }
        #PRIMARY AV PRODUCT
        if (($avs[$av].display -match $i_PAV) -or 
          (($i_PAV -eq "Trend Micro") -and (($avs[$av].display -match "Trend Micro") -or ($avs[$av].display -match "Worry-Free Business Security")))) {
          #PARSE XML FOR SPECIFIC VENDOR AV PRODUCT
          $node = $avs[$av].display.replace(" ", "").replace("-", "").toupper()
          #AV DETAILS
          $o_AVname = $avs[$av].display
          $o_AVpath = $avs[$av].path
          #AV PRODUCT VERSION
          $i_verkey = $pavkey[$node].ver
          $i_verval = $pavkey[$node].verval
          #AV PRODUCT COMPONENTS VERSIONS
          $i_compverkey = $pavkey[$node].compver
          #AV PRODUCT STATE
          $i_statkey = $pavkey[$node].stat
          $i_statval = $pavkey[$node].statval
          #AV PRODUCT LAST UPDATE TIMESTAMP
          $i_update = $pavkey[$node].update
          $i_updateval = $pavkey[$node].updateval
          #AV PRODUCT UPDATE SOURCE
          $i_source = $pavkey[$node].source
          $i_sourceval = $pavkey[$node].sourceval
          #AV PRODUCT REAL-TIME SCANNING
          $i_rtkey = $pavkey[$node].rt
          $i_rtval = $pavkey[$node].rtval
          #AV PRODUCT DEFINITIONS
          $i_defupdate = $pavkey[$node].defupdate
          $i_defupdateval = $pavkey[$node].defupdateval
          #AV PRODUCT TAMPER PROTECTION
          $i_tamper = $pavkey[$node].tamper
          $i_tamperval = $pavkey[$node].tamperval
          #AV PRODUCT SCANS
          $i_scan = $pavkey[$node].scan
          $i_scantype = $pavkey[$node].scantype
          $i_scanval = $pavkey[$node].scanval
          #AV PRODUCT ALERTS
          $i_alert = $pavkey[$node].alert
          $i_alertval = $pavkey[$node].alertval
          #AV PRODUCT INFECTIONS
          $i_infect = $pavkey[$node].infect
          $i_infectval = $pavkey[$node].infectval
          #AV PRODUCT THREATS
          $i_threat = $pavkey[$node].threat
          #GET PRIMARY AV PRODUCT VERSION VIA REGISTRY
          try {
            write-host "Reading : -path 'HKLM:$($i_verkey)' -name '$($i_verval)'" -foregroundcolor yellow
            $o_AVVersion = get-itemproperty -path "HKLM:$($i_verkey)" -name "$($i_verval)" -erroraction stop
          } catch {
            write-host "Could not validate Registry data : -path 'HKLM:$($i_verkey)' -name '$($i_verval)'" -foregroundcolor red
            $o_AVVersion = "."
            write-host $_.scriptstacktrace
            write-host $_
          }
          $o_AVVersion = "$($o_AVVersion.$i_verval)"
          #GET PRIMARY AV PRODUCT COMPONENT VERSIONS
          $o_compver = "Core Version : $($o_AVVersion)`r`n"
          try {
            write-host "Reading : -path 'HKLM:$($i_compverkey)'" -foregroundcolor yellow
            if ($i_PAV -match "Sophos") {
              $compverkey = get-childitem -path "HKLM:$($i_compverkey)" -erroraction silentlycontinue
              foreach ($component in $compverkey) {
                if (($component -ne $null) -and ($component -ne "")) {
                  $longname = get-itemproperty -path "HKLM:$($i_compverkey)$($component.PSChildName)" -name "LongName" -erroraction silentlycontinue
                  $installver = get-itemproperty -path "HKLM:$($i_compverkey)$($component.PSChildName)" -name "InstalledVersion" -erroraction silentlycontinue
                  Pop-Components $compkey $($longname.LongName) $($installver.InstalledVersion)
                }
              }
              $sort = $compkey.GetEnumerator() | sort -Property name
              foreach ($component in $sort) {
                $o_compver += "$($component.name) Version : $($component.value)`r`n"
              }
            }
          } catch {
            write-host "Could not validate Registry data : 'HKLM:$($i_compverkey)' for '$($component.PSChildName)'" -foregroundcolor red
            $o_compver = "Components : N/A"
            write-host $_.scriptstacktrace
            write-host $_
          }
          #GET AV PRODUCT UPDATE SOURCE
          try {
            write-host "Reading : -path 'HKLM:$($i_source)' -name '$($i_sourceval)'" -foregroundcolor yellow
            $sourcekey = get-itemproperty -path "HKLM:$($i_source)" -name "$($i_sourceval)" -erroraction stop
            $o_AVStatus = "Update Source : $($sourcekey.$i_sourceval)`r`n"
          } catch {
            write-host "Could not validate Registry data : -path 'HKLM:$($i_source)' -name '$($i_sourceval)'" -foregroundcolor red
            $o_AVStatus = "Update Source : Unknown`r`n"
            write-host $_.scriptstacktrace
            write-host $_
          }
          #GET PRIMARY AV PRODUCT STATUS VIA REGISTRY
          try {
            write-host "Reading : -path 'HKLM:$($i_statkey)' -name '$($i_statval)'" -foregroundcolor yellow
            $statkey = get-itemproperty -path "HKLM:$($i_statkey)" -name "$($i_statval)" -erroraction stop
            #INTERPRET 'AVSTATUS' BASED ON ANY AV PRODUCT VALUE REPRESENTATION
            if ($zUpgrade -contains $avs[$av].display) {                                     #AV PRODUCTS TREATING '0' AS 'UPTODATE'
              write-host "$($avs[$av].display) reports '$($statkey.$i_statval)' for 'Up-To-Date' (Expected : '0')" -foregroundcolor yellow
              if ($statkey.$i_statval -eq "0") {
                $o_AVStatus = "Up-to-Date : $($true) (REG Check)`r`n"
              } else {
                $updWARN = $true
                $o_AVStatus = "Up-to-Date : $($false) (REG Check)`r`n"
                Pop-Warnings $avwarn $($avs[$av].display) "$($o_AVStatus)`r`n"
              }
            } elseif ($zUpgrade -notcontains $avs[$av].display) {                            #AV PRODUCTS TREATING '1' AS 'UPTODATE'
              write-host "$($avs[$av].display) reports '$($statkey.$i_statval)' for 'Up-To-Date' (Expected : '1')" -foregroundcolor yellow
              if ($statkey.$i_statval -eq "1") {
                $o_AVStatus = "Up-to-Date : $($true) (REG Check)`r`n"
              } else {
                $updWARN = $true
                $o_AVStatus = "Up-to-Date : $($false) (REG Check)`r`n"
                Pop-Warnings $avwarn $($avs[$av].display) "$($o_AVStatus)`r`n"
              }
            }
          } catch {
            $updWARN = $true
            write-host "Could not validate Registry data : -path 'HKLM:$($i_statkey)' -name '$($i_statval)'" -foregroundcolor red
            $o_AVStatus = "Up-to-Date : Unknown (REG Check)`r`n"
            Pop-Warnings $avwarn $($avs[$av].display) "$($o_AVStatus)`r`n"
            write-host $_.scriptstacktrace
            write-host $_
          }
          #GET PRIMARY AV PRODUCT LAST UPDATE TIMESTAMP VIA REGISTRY
          try {
            write-host "Reading : -path 'HKLM:$($i_update)' -name '$($i_updateval)'" -foregroundcolor yellow
            $updatekey = get-itemproperty -path "HKLM:$($i_update)" -name "$($i_updateval)" -erroraction stop
            if ($avs[$av].display -match "Windows Defender") {                                      #WINDOWS DEFENDER LAST UPDATE TIMESTAMP
              $Int64Value = [System.BitConverter]::ToInt64($updatekey.$i_updateval, 0)
              $time = [DateTime]::FromFileTime($Int64Value)
              $update = Get-Date($time)
              $o_AVStatus += "Last Major Update : $(Get-EpochDate($($update))("sec"))`r`n"
              $age = new-timespan -start $update -end (Get-Date)
            } elseif ($avs[$av].display -notmatch "Windows Defender") {                             #ALL OTHER AV LAST UPDATE TIMESTAMP
              if ($avs[$av].display -match "Symantec") {                                            #SYMANTEC AV UPDATE TIMESTAMP
                $o_AVStatus += "Last Major Update : $(Get-EpochDate($($updatekey.$i_updateval))("msec"))`r`n"
                $age = new-timespan -start (Get-EpochDate($updatekey.$i_updateval)("msec")) -end (Get-Date)
              } elseif ($avs[$av].display -notmatch "Symantec") {                                   #ALL OTHER AV LAST UPDATE TIMESTAMP
                $o_AVStatus += "Last Major Update : $(Get-EpochDate($($updatekey.$i_updateval))("sec"))`r`n"
                $age = new-timespan -start (Get-EpochDate($updatekey.$i_updateval)("sec")) -end (Get-Date)
              }
            }
            $o_AVStatus += "Days Since Update (DD:HH:MM) : $($age.tostring("dd\:hh\:mm"))`r`n"
          } catch {
            $updWARN = $true
            write-host "Could not validate Registry data : -path 'HKLM:$($i_update)' -name '$($i_updateval)'" -foregroundcolor red
            $o_AVStatus += "Last Major Update : N/A`r`n"
            $o_AVStatus += "Days Since Update (DD:HH:MM) : N/A`r`n"
            Pop-Warnings $avwarn $($avs[$av].display) "$($o_AVStatus)`r`n"
            write-host $_.scriptstacktrace
            write-host $_
          }
          if ($updWARN) {
            $updWARN = $false
            $blnWARN = $true
            Pop-Warnings $avwarn $($avs[$av].display) "$($o_AVStatus)`r`n"
          }
          #GET PRIMARY AV PRODUCT REAL-TIME SCANNING
          $rtWARN = $false
          try {
            write-host "Reading : -path 'HKLM:$($i_rtkey)' -name '$($i_rtval)'" -foregroundcolor yellow
            $rtkey = get-itemproperty -path "HKLM:$($i_rtkey)" -name "$($i_rtval)" -erroraction stop
            $o_RTstate = "$($rtkey.$i_rtval)"
            #INTERPRET 'REAL-TIME SCANNING' STATUS BASED ON ANY AV PRODUCT VALUE REPRESENTATION
            if ($zRealTime -contains $avs[$av].display) {                                    #AV PRODUCTS TREATING '0' AS 'ENABLED' FOR 'REAL-TIME SCANNING'
              write-host "$($avs[$av].display) reports '$($rtkey.$i_rtval)' for 'Real-Time Scanning' (Expected : '0')" -foregroundcolor yellow
              if ($rtkey.$i_rtval -eq 0) {
                $o_RTstate = "Enabled (REG Check)`r`n"
              } elseif ($rtkey.$i_rtval -eq 1) {
                $rtWARN = $true
                $o_RTstate = "Disabled (REG Check)`r`n"
              } else {
                $rtWARN = $true
                $o_RTstate = "Unknown (REG Check)`r`n"
              }
            } elseif ($zRealTime -notcontains $avs[$av].display) {                           #AV PRODUCTS TREATING '1' AS 'ENABLED' FOR 'REAL-TIME SCANNING'
              write-host "$($avs[$av].display) reports '$($rtkey.$i_rtval)' for 'Real-Time Scanning' (Expected : '1')" -foregroundcolor yellow
              if ($rtkey.$i_rtval -eq 1) {
                $o_RTstate = "Enabled (REG Check)`r`n"
              } elseif ($rtkey.$i_rtval -eq 0) {
                $rtWARN = $true
                $o_RTstate = "Disabled (REG Check)`r`n"
              } else {
                $rtWARN = $true
                $o_RTstate = "Unknown (REG Check)`r`n"
              }
            }
          } catch {
            $rtWARN = $true
            write-host "Could not validate Registry data : -path 'HKLM:$($i_rtkey)' -name '$($i_rtval)'" -foregroundcolor red
            $o_RTstate = "N/A (REG Check)`r`n"
            write-host $_.scriptstacktrace
            write-host $_
          }
          $o_AVStatus += "Real-Time Status : $($o_RTstate)"
          if ($rtWARN) {
            $rtWARN = $false
            $blnWARN = $true
            Pop-Warnings $avwarn $($avs[$av].display) "Real-Time Scanning :`r`m$($o_RTstate)`r`n"
          }
          #GET PRIMARY AV PRODUCT TAMPER PROTECTION STATUS
          $tamperWARN = $false
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
                $tamperWARN = $true
                $tamper = "$($false) (REG Check)"
                
              } else {
                $tamperWARN = $true
                $tamper = "Unknown (REG Check)"
              }
            } elseif ($zTamper -contains $avs[$av].display) {                                #AV PRODUCTS TREATING '0' AS 'ENABLED' FOR 'TAMPER PROTECTION'
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
            } elseif ($zTamper -notcontains $avs[$av].display) {                             #AV PRODUCTS TREATING '1' AS 'ENABLED' FOR 'TAMPER PROTECTION'
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
            write-host "Could not validate Registry data : -path 'HKLM:$($i_tamper)' -name '$($i_tamperval)'" -foregroundcolor red
            $tamper = "Unknown (REG Check)"
            write-host $_.scriptstacktrace
            write-host $_
          }
          $o_AVStatus += "Tamper Protection : $($tamper)`r`n"
          if ($tamperWARN) {
            $tamperWARN = $false
            $blnWARN = $true
            Pop-Warnings $avwarn $($avs[$av].display) "Tamper Protection :`r`n$($tamper)`r`n"
          }
          #GET PRIMARY AV PRODUCT LAST SCAN DETAILS
          $lastage = 0
          $scanWARN = $false
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
              $scanWARN = $true
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
              $scanWARN = $true
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
                $scanWARN = $true
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
                $scanWARN = $true
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
              $scanWARN = $true
              $scans += "Recently Scanned : $($false) (REG Check)"
            }
          }
          if ($scanWARN) {
            $scanWARN = $false
            $blnWARN = $true
            Pop-Warnings $avwarn $($avs[$av].display) "Last Scan :`r`n$($scans)`r`n"
          }
          $o_AVStatus += $scans
          #GET PRIMARY AV PRODUCT DEFINITIONS / SIGNATURES / PATTERN
          $defWARN = $false
          if ($blnWMI) {
            #will still return if it is unknown, etc. if it is unknown look at the code it returns, then look up the status and add it above
            Get-AVState $pskey $avs[$av].stat
            $o_DefStatus = "$($defstatus)`r`n"
          } elseif (-not $blnWMI) {
            $o_DefStatus = "N/A (WMI Check)`r`n"
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
                $o_DefStatus += "Status : Up to date (REG Check)`r`n"
              } elseif ($age.compareto($time1) -gt 0) {
                $defWARN = $true
                $o_DefStatus += "Status : Out of date (REG Check)`r`n"
              }
              $o_DefStatus += "Last Definition Update : $($update)`r`n"
            } elseif ($avs[$av].display -notmatch "Windows Defender") {                             #ALL OTHER AV DEFINITION UPDATE TIMESTAMP
              if ($avs[$av].display -match "Symantec") {                                            #SYMANTEC DEFINITION UPDATE TIMESTAMP
                $age = new-timespan -start ($defkey.$i_defupdateval) -end (Get-Date)
                if ($age.compareto($time1) -le 0) {
                  $o_DefStatus += "Status : Up to date (REG Check)`r`n"
                } elseif ($age.compareto($time1) -gt 0) {
                  $defWARN = $true
                  $o_DefStatus += "Status : Out of date (REG Check)`r`n"
                }
                $o_DefStatus += "Last Definition Update : $($defkey.$i_defupdateval)`r`n"
              } elseif ($avs[$av].display -notmatch "Symantec") {                                   #NON-SYMANTEC DEFINITION UPDATE TIMESTAMP
                $age = new-timespan -start (Get-EpochDate($defkey.$i_defupdateval)("sec")) -end (Get-Date)
                if ($age.compareto($time1) -le 0) {
                  $o_DefStatus += "Status : Up to date (REG Check)`r`n"
                } elseif ($age.compareto($time1) -gt 0) {
                  $defWARN = $true
                  $o_DefStatus += "Status : Out of date (REG Check)`r`n"
                }
                $o_DefStatus += "Last Definition Update : $(Get-EpochDate($($defkey.$i_defupdateval))("sec"))`r`n"
              }
            }
            $o_DefStatus += "Definition Age (DD:HH:MM) : $($age.tostring("dd\:hh\:mm"))"
          } catch {
            $defWARN = $true
            write-host "Could not validate Registry data : -path 'HKLM:$($i_defupdate)' -name '$($i_defupdateval)'" -foregroundcolor red
            $o_DefStatus += "Status : Out of date (REG Check)`r`n"
            $o_DefStatus += "Last Definition Update : N/A`r`n"
            $o_DefStatus += "Definition Age (DD:HH:MM) : N/A"
            write-host $_.scriptstacktrace
            write-host $_
          }
          if ($defWARN) {
            $defWARN = $false
            $blnWARN = $true
            Pop-Warnings $avwarn $($avs[$av].display) "Definition Status :`r`n$($o_DefStatus)`r`n"
          }
          #GET PRIMARY AV PRODUCT DETECTED ALERTS VIA REGISTRY
          if ($zNoAlert -notcontains $i_PAV) {
            if ($i_PAV -match "Sophos") {
              try {
                write-host "Reading : -path 'HKLM:$($i_alert)'" -foregroundcolor yellow
                $alertkey = get-ItemProperty -path "HKLM:$($i_alert)" -erroraction silentlycontinue
                foreach ($alert in $alertkey.psobject.Properties) {
                  if (($alert.name -notlike "PS*") -and ($alert.name -notlike "(default)")) {
                    if ($alert.value -eq 0) {
                      $o_Infect += "Type - $($alert.name) : $($false)`r`n"
                    } elseif ($alert.value -eq 1) {
                      $o_Infect += "Type - $($alert.name) : $($true)`r`n"
                    }
                  }
                }
              } catch {
                write-host "Could not validate Registry data : 'HKLM:$($i_alert)'" -foregroundcolor red
                $o_Infect = "N/A`r`n"
                write-host $_.scriptstacktrace
                write-host $_
              }
            }
            # NOT ACTUAL DETECTIONS - SAVE BELOW CODE FOR 'CONFIGURED ALERTS' METRIC
            #elseif ($i_PAV -match "Trend Micro") {
            #  if ($producttype -eq "Workstation") {
            #    $i_alert += "Client"
            #    write-host "Reading : -path 'HKLM:$i_alert'" -foregroundcolor yellow
            #    $alertkey = get-ItemProperty -path "HKLM:$i_alert" -erroraction silentlycontinue
            #  } elseif (($producttype -eq "Server") -or ($producttype -eq "DC")) {
            #    $i_alert += "Server"
            #    write-host "Reading : -path 'HKLM:$i_alert'" -foregroundcolor yellow
            #    $alertkey = get-ItemProperty -path "HKLM:$i_alert" -erroraction silentlycontinue
            #  }
            #  foreach ($alert in $alertkey.psobject.Properties) {
            #    if (($alert.name -notlike "PS*") -and ($alert.name -notlike "(default)")) {
            #      if ($alert.value -eq 0) {
            #        $o_Infect += "Type - $($alert.name) : $false`r`n"
            #      } elseif ($alert.value -eq 1) {
            #        $o_Infect += "Type - $($alert.name) : $true`r`n"
            #      }
            #    }
            #  }
            #}
          }
          #GET PRIMARY AV PRODUCT DETECTED INFECTIONS VIA REGISTRY
          $infectWARN = $false
          if ($zNoInfect -notcontains $i_PAV) {
            if ($i_PAV -match "Sophos") {                                                           #SOPHOS DETECTED INFECTIONS
              try {
                write-host "Reading : -path 'HKLM:$($i_infect)'" -foregroundcolor yellow
                $infectkey = get-ItemProperty -path "HKLM:$($i_infect)" -erroraction silentlycontinue
                foreach ($infect in $infectkey.psobject.Properties) {                               #ENUMERATE EACH DETECTED INFECTION
                  if (($infect.name -notlike "PS*") -and ($infect.name -notlike "(default)")) {
                    if ($infect.value -eq 0) {
                      $o_Infect += "Type - $($infect.name) : $($false)`r`n"
                    } elseif ($infect.value -eq 1) {
                      $infectWARN = $true
                      $o_Infect += "Type - $($infect.name) : $($true)`r`n"
                    }
                  }
                }
              } catch {
                write-host "Could not validate Registry data : 'HKLM:$($i_infect)'" -foregroundcolor red
                $o_Infect += "Virus/Malware Present : N/A`r`n"
                write-host $_.scriptstacktrace
                write-host $_
              }
            } elseif ($i_PAV -match "Trend Micro") {                                                #TREND MICRO DETECTED INFECTIONS
              try {
                write-host "Reading : -path 'HKLM:$($i_infect)' -name '$($i_infectval)'" -foregroundcolor yellow
                $infectkey = get-ItemProperty -path "HKLM:$($i_infect)" -name "$($i_infectval)" -erroraction silentlycontinue
                if ($infectkey.$i_infectval -eq 0) {                                                #NO DETECTED INFECTIONS
                  $o_Infect += "Virus/Malware Present : $($false)`r`nVirus/Malware Count : $($infectkey.$i_infectval)`r`n"
                } elseif ($infectkey.$i_infectval -gt 0) {                                          #DETECTED INFECTIONS
                  $infectWARN = $true
                  $o_Infect += "Virus/Malware Present : $($true)`r`nVirus/Malware Count : $($infectkey.$i_infectval)`r`n"
                }
              } catch {
                $infectWARN = $true
                write-host "Could not validate Registry data : 'HKLM:$($i_infect)' -name '$($i_infectval)'" -foregroundcolor red
                $o_Infect += "Virus/Malware Present : N/A`r`n"
                write-host $_.scriptstacktrace
                write-host $_
              }
            } elseif ($i_PAV -match "Symantec") {                                                   #SYMANTEC DETECTED INFECTIONS
              try {
                write-host "Reading : -path 'HKLM:$($i_infect)' -name '$($i_infectval)'" -foregroundcolor yellow
                $infectkey = get-ItemProperty -path "HKLM:$($i_infect)" -name "$($i_infectval)" -erroraction silentlycontinue
                if ($infectkey.$i_infectval -eq 0) {                                                #NO DETECTED INFECTIONS
                  $o_Infect += "Virus/Malware Present : $($false)`r`n"
                } elseif ($infectkey.$i_infectval -gt 0) {                                          #DETECTED INFECTIONS
                  try {
                    $infectWARN = $true
                    write-host "Reading : -path 'HKLM:$($i_scan)' -name 'WorstInfectionType'" -foregroundcolor yellow
                    $worstkey = get-ItemProperty -path "HKLM:$($i_scan)" -name "WorstInfectionType" -erroraction silentlycontinue
                    $worst = SEP-Map($worstkey.WorstInfectionType)
                  } catch {
                    $infectWARN = $true
                    write-host "Could not validate Registry data : 'HKLM:$($i_scan)' -name 'WorstInfectionType'" -foregroundcolor red
                    $worst = "N/A"
                    write-host $_.scriptstacktrace
                    write-host $_
                  }
                  $o_Infect += "Virus/Malware Present : $($true)`r`nWorst Infection Type : $($worst)`r`n"
                }
              } catch {
                $infectWARN = $true
                write-host "Could not validate Registry data : 'HKLM:$($i_infect)' -name '$($i_infectval)'" -foregroundcolor red
                $o_Infect += "Virus/Malware Present : N/A`r`nWorst Infection Type : N/A`r`n"
                write-host $_.scriptstacktrace
                write-host $_
              }
            }
          }
          if ($infectWARN) {
            $infectWARN = $false
            $blnWARN = $true
            Pop-Warnings $avwarn $($avs[$av].display) "Active Detections :`r`n$($o_Infect)`r`n"
          }
          #GET PRIMARY AV PRODUCT DETECTED THREATS VIA REGISTRY
          $threatWARN = $false
          if ($zNoThreat -notcontains $i_PAV) {
            try {
              write-host "Reading : -path 'HKLM:$($i_threat)'" -foregroundcolor yellow
              $threatkey = get-childitem -path "HKLM:$($i_threat)" -erroraction silentlycontinue
              if ($i_PAV -match "Sophos") {
                if ($threatkey.count -gt 0) {
                  $threatWARN = $true
                  foreach ($threat in $threatkey) {
                    $threattype = get-itemproperty -path "HKLM:$($i_threat)\$($threat.PSChildName)\" -name "Type" -erroraction silentlycontinue
                    $threatfile = get-childitem -path "HKLM:$($i_threat)\$($threat.PSChildName)\Files\" -erroraction silentlycontinue
                    $o_Threats += "Threat : $($threat.PSChildName) - Type : $($threattype.type) - Path : "
                    foreach ($detection in $threatfile) {
                      try {
                        $threatpath = get-itemproperty -path "HKLM:$($i_threat)\$($threat.PSChildName)\Files\$($threatfile.PSChildName)\" -name "Path" -erroraction silentlycontinue
                        $o_Threats += "$($threatpath.path)"
                      } catch {
                        $o_Threats += "N/A"
                        write-host $_.scriptstacktrace
                        write-host $_
                      }
                    }
                    $o_Threats += "`r`n"
                  }
                } elseif ($threatkey.count -le 0) {
                  $o_Threats += "N/A`r`n"
                }
              }
            } catch {
              $threatWARN = $true
              write-host "Could not validate Registry data : 'HKLM:$($i_threat)'" -foregroundcolor red
              $o_Threats = "N/A`r`n"
              write-host $_.scriptstacktrace
              write-host $_
            }
          }
          if ($threatWARN) {
            $threatWARN = $false
            $blnWARN = $true
            Pop-Warnings $avwarn $($avs[$av].display) "Detected Threats :`r`n$($o_Threats)`r`n"
          }
        #SAVE WINDOWS DEFENDER FOR LAST - TO PREVENT SCRIPT CONSIDERING IT 'COMPETITOR AV' WHEN SET AS PRIMARY AV
        } elseif ($avs[$av].display -eq "Windows Defender") {
          $o_CompAV += "$($avs[$av].display)`r`n"
          $o_CompPath += "$($avs[$av].path)`r`n"
          if ($blnWMI) {
            Get-AVState $pskey $avs[$av].stat
            $o_CompState += "$($avs[$av].display) - Real-Time Scanning : $($rtstatus) - Definitions : $($defstatus)`r`n"
          } elseif (-not $blnWMI) {
            $o_CompState += "$($avs[$av].display) - Real-Time Scanning : $($avs[$av].rt) - Definitions : N/A (WMI Check)`r`n"
          } 
        }
      }
    }
  }
}
#OUTPUT
if (($o_AVname -match "No AV Product Found") -or ($o_AVname -match "Selected AV Product Not Found")) {
  $ccode = "red"
} else {
  $ccode = "green"
}
#DEVICE INFO
write-host "`r`nDevice Info :" -foregroundcolor yellow
write-host "Device : $($computername)" -foregroundcolor $ccode
write-host "Operating System : $($OSCaption) ($($OSVersion))" -foregroundcolor $ccode
$diag += "`r`nDevice Info :`r`nDevice : $($computername)`r`n"
$diag += "Operating System : $($OSCaption) ($($OSVersion))`r`n"
#AV DETAILS
write-host "`r`nAV Details :" -foregroundcolor yellow
write-host "AV Display Name : $($o_AVname)" -foregroundcolor $ccode
write-host "AV Path : $($o_AVpath)" -foregroundcolor $ccode
write-host "`r`nAV Status :" -foregroundcolor yellow
write-host "$($o_AVStatus)" -foregroundcolor $ccode
write-host "`r`nComponent Versions :" -foregroundcolor yellow
write-host "$($o_compver)" -foregroundcolor $ccode
$diag += "`r`nAV Details :`r`nAV Display Name : $($o_AVname)`r`nAV Path : $($o_AVpath)`r`n"
$diag += "`r`nComponent Versions :`r`n$($o_compver)`r`n"
#REAL-TIME SCANNING & DEFINITIONS
write-host "Definitions :" -foregroundcolor yellow
write-host "Status : $($o_DefStatus)" -foregroundcolor $ccode
$diag += "`r`nDefinitions :`r`nStatus : $($o_DefStatus)`r`n"
#THREATS
write-host "`r`nActive Detections :" -foregroundcolor yellow
write-host "$($o_Infect)" -foregroundcolor $ccode
write-host "Detected Threats :" -foregroundcolor yellow
write-host "$($o_Threats)" -foregroundcolor $ccode
$diag += "`r`nActive Detections :`r`n$($o_Infect)`r`nDetected Threats :`r`n$($o_Threats)`r`n"
#COMPETITOR AV
write-host "Competitor AV :" -foregroundcolor yellow
write-host "AV Conflict : $($o_AVcon)" -foregroundcolor $ccode
write-host "$($o_CompAV)" -foregroundcolor $ccode
write-host "Competitor Path :" -foregroundcolor yellow
write-host "$($o_CompPath)" -foregroundcolor $ccode
write-host "Competitor State :" -foregroundcolor yellow
write-host "$($o_CompState)" -foregroundcolor $ccode
$diag += "`r`nCompetitor AV :`r`nAV Conflict : $($o_AVcon)`r`n$($o_CompAV)"
$diag += "`r`nCompetitor Path :`r`n$($o_CompPath)`r`nCompetitor State :`r`n$($o_CompState)"
#SYNCRO OUTPUT
if ($blnWARN) {
  # This creates an alert in Syncro and triggers the "New RMM Alert" in the Notification Center - automatically de-duping per asset.
  Rmm-Alert -Category "AV Health : $($i_PAV) : Warning" -Body "$($diag)"
} elseif (-not $blnWARN) {
  # This logs an activity feed item on an Assets's Activity feed
  Log-Activity -Message "AV Health : $($i_PAV) : Healthy" -EventName "$($diag)"
}
#END SCRIPT
#------------