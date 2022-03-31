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
    Version        : 0.1.7 (26 January 2022)
    Creation Date  : 14 December 2021
    Purpose/Change : Provide Primary AV Product Status and Report Possible AV Conflicts
    File Name      : AVHealth_0.1.7.ps1 
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

.TODO
    Still need more AV Product registry samples for identifying keys to monitor for relevant data
    Need to obtain version and calculate date timestamps for AV Product updates, Definition updates, and Last Scan
    Need to obtain Infection Status and Detected Threats; bonus for timestamps for these metrics
        Do other AVs report individual Threat information in the registry? Sophos does; but if others don't will we be able to use this metric?
#> 

#REGION ----- DECLARATIONS ----
  Param(
    [Parameter(Mandatory=$true)]$i_PAV
  )
  $script:bitarch = ""
  $script:OSCaption = ""
  $script:OSVersion = ""
  $script:producttype = ""
  $script:computername = ""
  $script:blnWMI = $true
  $script:avkey = @{}
  $script:o_AVname = ""
  $script:o_AVVersion = ""
  $script:o_AVpath = ""
  $script:o_AVStatus = ""
  $script:rtstatus = "Unknown"
  $script:o_RTstate = "Unknown"
  $script:defstatus = "Unknown"
  $script:o_DefStatus = "Unknown"
  $script:o_AVcon = 0
  $script:o_CompAV = ""
  $script:o_CompPath = ""
  $script:o_Compstate = ""
  #AV PRODUCTS USING '0' FOR 'UP-TO-DATE' PRODUCT STATUS
  $script:zUpgrade = @(
    "Sophos Intercept X"
    "Symantec Endpoint Protection"
    "Trend Micro Security Agent"
    "Worry-Free Business Security"
    "Windows Defender"
  )
#ENDREGION ----- DECLARATIONS ----

#REGION ----- FUNCTIONS ----
  function Get-EpochDate ($epochDate) {           #Convert Epoch Date Timestamps to Local Time
    [timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($epochDate))
  } ## Get-EpochDate

  function Get-OSArch {                           #Determine Bit Architecture & OS Type
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

  function Get-AVState {                          #DETERMINE ANTIVIRUS STATE
    param (
      $state
    )
    #Switch to determine the status of antivirus definitions and real-time protection.
    #THIS COULD PROBABLY ALSO BE TURNED INTO A SIMPLE XML / JSON LOOKUP TO FACILITATE COMMUNITY CONTRIBUTION
    switch ($state) {
      #AVG IS 2012 AV / CrowdStrike / Kaspersky
      "262144" {$script:defstatus = "Up to date" ;$script:rtstatus = "Disabled"}
      "266240" {$script:defstatus = "Up to date" ;$script:rtstatus = "Enabled"}
      #AVG IS 2012 FW
      "266256" {$script:defstatus = "Out of date" ;$script:rtstatus = "Enabled"}
      "262160" {$script:defstatus = "Out of date" ;$script:rtstatus = "Disabled"}
      #MSSE
      "393216" {$script:defstatus = "Up to date" ;$script:rtstatus = "Disabled"}
      "397312" {$script:defstatus = "Up to date" ;$script:rtstatus = "Enabled"}
      #Windows Defender
      "393472" {$script:defstatus = "Up to date" ;$script:rtstatus = "Disabled"}
      "397584" {$script:defstatus = "Out of date" ;$script:rtstatus = "Enabled"}
      "397568" {$script:defstatus = "Up to date" ;$script:rtstatus = "Enabled"}
      "401664" {$script:defstatus = "Up to date" ;$script:rtstatus = "Disabled"}
      #
      "393232" {$script:defstatus = "Out of date" ;$script:rtstatus = "Disabled"}
      "393488" {$script:defstatus = "Out of date" ;$script:rtstatus = "Disabled"}
      "397328" {$script:defstatus = "Out of date" ;$script:rtstatus = "Enabled"}
      #Sophos
      "331776" {$script:defstatus = "Up to date" ;$script:rtstatus = "Enabled"}
      "335872" {$script:defstatus = "Up to date" ;$script:rtstatus = "Disabled"}
      #Norton Security
      "327696" {$script:defstatus = "Out of date" ;$script:rtstatus = "Disabled"}
      default {$script:defstatus = "Unknown" ;$script:rtstatus = "Unknown"}
    }
  } ## Get-AVState
#ENDREGION ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
$i = 0
Get-OSArch
#COMMENT OUT THE BELOW LINE (LN154) FOR USE WITH AMP / PASSING OF PRIMARY AV AS INPUT
#$i_PAV = "Sophos"
$srcAVP = "https://raw.githubusercontent.com/CW-Khristos/scripts/master/AVProducts/" + $i_PAV.replace(" ", "").replace("-", "").tolower() + ".xml"
#READ AV PRODUCT DETAILS FROM XML
try {
  $avXML = New-Object System.Xml.XmlDocument
  $avXML.Load($srcAVP)
} catch {
  $web = new-object system.net.webclient
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12
  [xml]$avXML = $web.DownloadString($srcAVP)
}
#READ XML DATA INTO NESTED HASHTABLE FORMAT FOR LATER USE
foreach ($itm in $avXML.NODE.ChildNodes) {
  $hash = @{
    display = $itm.$script:bitarch.display
    displayval = $itm.$script:bitarch.displayval
    path = $itm.$script:bitarch.path
    pathval = $itm.$script:bitarch.pathval
    ver = $itm.$script:bitarch.ver
    verval = $itm.$script:bitarch.verval
    rt = $itm.$script:bitarch.rt
    rtval = $itm.$script:bitarch.rtval
    stat = $itm.$script:bitarch.stat
    statval = $itm.$script:bitarch.statval
    infect = $itm.$script:bitarch.infect
    threat = $itm.$script:bitarch.threat
  }
  $avkey.add($itm.name,$hash)
}
#QUERY WMI SECURITYCENTER NAMESPACE FOR AV PRODUCT DETAILS
if ([system.version]$script:OSVersion -ge [system.version]'6.0.0.0') {
  write-verbose "OS Windows Vista/Server 2008 or newer detected."
  try {
    $AntiVirusProduct = get-wmiobject -Namespace "root\SecurityCenter2" -Class "AntiVirusProduct" -ComputerName $script:computername -ErrorAction Stop
  } catch {
    $blnWMI = $false
  }
} elseif ([system.version]$script:OSVersion -lt [system.version]'6.0.0.0') {
  write-verbose "Windows 2000, 2003, XP detected" 
  try {
    $AntiVirusProduct = get-wmiobject -Namespace "root\SecurityCenter" -Class "AntiVirusProduct"  -ComputerName $script:computername -ErrorAction Stop
  } catch {
    $blnWMI = $false
  }
}
if (-not $blnWMI) {                               #FAILED TO RETURN WMI SECURITYCENTER NAMESPACE
  try {
    write-host "Failed to query WMI SecurityCenter Namespace" -foregroundcolor Red
    write-host "Possibly Server, attempting to  fallback to using 'HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\' registry key" -foregroundcolor Red
    try {                                         #QUERY 'HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\' AND SEE IF AN AV IS REGISTRERED THERE
      if ($script:bitarch = "bit64") {
        $AntiVirusProduct = (get-itemproperty -path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Security Center\Monitoring\*" -ErrorAction Stop).PSChildName
      } elseif ($script:bitarch = "bit32") {
        $AntiVirusProduct = (get-itemproperty -path "HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\*" -ErrorAction Stop).PSChildName
      }
    } catch {
      write-host "Could not find AV registered in HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\*" -foregroundcolor Red
      $AntiVirusProduct = $null
      $blnSecMon = $true
    }
    if ($AntiVirusProduct -ne $null) {            #RETURNED 'HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\' DATA
      $strDisplay = ""
      $blnSecMon = $false
      foreach ($av in $AntiVirusProduct) {
        write-host "Found 'HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\$av'" -foregroundcolor Yellow
        foreach ($key in $script:avkey.keys) {    #ATTEMPT TO VALIDATE EACH AV PRODUCT CONTAINED IN VENDOR XML
          if ($av.replace(" ", "").replace("-", "").toupper() -eq $key.toupper()) {
            $strName = ""
            $regDisplay = $script:avkey[$key].display
            $regDisplayVal = $script:avkey[$key].displayval
            $regPath = $script:avkey[$key].path
            $regPathVal = $script:avkey[$key].pathval
            $regRealTime = $script:avkey[$key].rt
            $regRTVal = $script:avkey[$key].rtval
            $regStat = $script:avkey[$key].stat
            $regStatVal = $script:avkey[$key].statval
            break 
          }
        }
        try {
          if (test-path "HKLM:$regDisplay") {     #VALIDATE INSTALLED AV PRODUCT BY TESTING READING A KEY
            write-host "Found 'HKLM:$regDisplay' for product : $key" -foregroundcolor Yellow
            try {                                 #IF VALIDATION PASSES; FABRICATE 'HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\' DATA
              $keyval1 = get-itemproperty -path "HKLM:$regDisplay" -name "$regDisplayVal" -erroraction stop
              $keyval2 = get-itemproperty -path "HKLM:$regPath" -name "$regPathVal" -erroraction stop
              $keyval3 = get-itemproperty -path "HKLM:$regRealTime" -name "$regRTVal" -erroraction stop
              $keyval4 = get-itemproperty -path "HKLM:$regStat" -name "$regStatVal" -erroraction stop
              $strName = $keyval1.$regDisplayVal
              $strDisplay = $strDisplay + $keyval1.$regDisplayVal + ", "
              $strPath = $strPath + $keyval2.$regPathVal + ", "
              if ($keyval3.$regRTVal = "0") {
                $strRealTime = $strRealTime + "Enabled, "
              } elseif ($keyval3.$regRTVal = "1") {
                $strRealTime = $strRealTime + "Disabled, "
              }
              $strStat = $strStat + $keyval4.$regStatVal.tostring() + ", "
              #'NORMALIZE' WINDOWS DEFENDER DISPLAY NAME
              if ($strName -match "Windows Defender") {
                $strDisplay = "Windows Defender, "
              }
            } catch {
              write-host "Not Found 'HKLM:$regDisplay' for product : $key" -foregroundcolor Red
              write-host $_.scriptstacktrace
              write-host $_
            }
          }
        } catch {
          write-host "Not Found 'HKLM:$regDisplay' for product : $key" -foregroundcolor Red
          write-host $_.scriptstacktrace
          write-host $_
        }
      }
      $avs = $strDisplay -split ", "
      $avpath = $strPath -split ", "
      $avrt = $strRealTime -split ", "
      $avstat = $strStat -split ", "
    } elseif ($AntiVirusProduct -eq $null) {      #FAILED TO RETURN 'HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\' DATA
      $strDisplay = ""
      $blnSecMon = $true
      foreach ($key in $script:avkey.keys) {      #ATTEMPT TO VALIDATE EACH AV PRODUCT CONTAINED IN VENDOR XML
        $strName = ""
        $regDisplay = $script:avkey[$key].display
        $regDisplayVal = $script:avkey[$key].displayval
        $regPath = $script:avkey[$key].path
        $regPathVal = $script:avkey[$key].pathval
        $regRealTime = $script:avkey[$key].rt
        $regRTVal = $script:avkey[$key].rtval
        $regStat = $script:avkey[$key].stat
        $regStatVal = $script:avkey[$key].statval
        try {
          if (test-path "HKLM:$regDisplay") {     #VALIDATE INSTALLED AV PRODUCT BY TESTING READING A KEY
            write-host "Found 'HKLM:$regDisplay' for product : $key" -foregroundcolor Yellow
            try {                                 #IF VALIDATION PASSES; FABRICATE 'HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\' DATA
              $keyval1 = get-itemproperty -path "HKLM:$regDisplay" -name "$regDisplayVal" -erroraction stop
              $keyval2 = get-itemproperty -path "HKLM:$regPath" -name "$regPathVal" -erroraction stop
              $keyval3 = get-itemproperty -path "HKLM:$regRealTime" -name "$regRTVal" -erroraction stop
              $keyval4 = get-itemproperty -path "HKLM:$regStat" -name "$regStatVal" -erroraction stop
              $strName = $keyval1.$regDisplayVal
              $strDisplay = $strDisplay + $keyval1.$regDisplayVal + ", "
              $strPath = $strPath + $keyval2.$regPathVal + ", "
              if ($keyval3.$regRTVal = "0") {
                $strRealTime = $strRealTime + "Enabled, "
              } elseif ($keyval3.$regRTVal = "1") {
                $strRealTime = $strRealTime + "Disabled, "
              }
              $strStat = $strStat + $keyval4.$regStatVal.tostring() + ", "
              #'NORMALIZE' WINDOWS DEFENDER DISPLAY NAME
              if ($strName -match "Windows Defender") {
                $strDisplay = $strDisplay + "Windows Defender, "
              }
              #$string4 = $strDisplay.substring(0, $strDisplay.length - 2)
              if ($blnSecMon) {
                write-host "Creating Registry Key HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\" $strName " for : " $strName -foregroundcolor Red
                if ($script:bitarch = "bit64") {
                  try {
                    new-item -path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Security Center\Monitoring\" -name $strName -value $strName -force
                  } catch {
                    write-host $_.scriptstacktrace
                    write-host $_
                  }
                } elseif ($script:bitarch = "bit32") {
                  try {
                    new-item -path "HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\" -name $strName -value $strName -force
                  } catch {
                    write-host $_.scriptstacktrace
                    write-host $_
                  }
                }
              }
              $AntiVirusProduct = "."
            } catch {
              write-host "Could not create Registry Key `HKLM:\SOFTWARE\Microsoft\Security Center\Monitoring\" $strName " for : " $strName -foregroundcolor Red
              write-host $_.scriptstacktrace
              write-host $_
              $AntiVirusProduct = $null
            }
            #break
          }
        } catch {
          write-host "Not Found 'HKLM:$regDisplay' for product : $key" -foregroundcolor Red
          write-host $_.scriptstacktrace
          write-host $_
        }
      }
      $avs = $strDisplay -split ", "
      $avpath = $strPath -split ", "
      $avrt = $strRealTime -split ", "
      $avstat = $strStat -split ", "
    }
  } catch {
    write-host "Failed to validate selected AV Products for : " $i_PAV -foregroundcolor Red
    write-host $_.scriptstacktrace
    write-host $_
  }
} elseif ($blnWMI) {                              #RETURNED WMI SECURITYCENTER NAMESPACE
  #SEPARATE RETURNED WMI AV PRODUCT INSTANCES
  $string = $AntiVirusProduct.displayName
  $avs = $string -split ", "
  $string = $AntiVirusProduct.pathToSignedProductExe
  $avpath = $string -split ", "
  $string = $AntiVirusProduct.productState
  $avstat = $string -split ", "
}
#OBTAIN FINAL AV PRODUCT DETAILS
if ($AntiVirusProduct -eq $null) {                #NO AV PRODUCT FOUND
  write-host "Could not find any AV Product registered" -foregroundcolor Red
  $script:o_AVname = "No AV Product Found"
  $script:o_AVVersion = ""
  $script:o_AVpath = ""
  $script:o_AVStatus = "Unknown"
  $script:o_RTstate = "Unknown"
  $script:o_DefStatus = "Unknown"
  $script:o_AVcon = 0
} elseif ($AntiVirusProduct -ne $null) {          #FOUND AV PRODUCTS
  foreach ($av in $avs) {                         #ITERATE THROUGH EACH FOUND AV PRODUCT
    if (($av -ne $null) -And ($av -ne "")) {
      #NEITHER PRIMARY AV PRODUCT NOR WINDOWS DEFENDER
      if (($avs[$i] -notmatch $i_PAV) -And ($avs[$i] -notmatch "Windows Defender")) {
        if (($i_PAV -eq "Trend Micro") -and (($avs[$i] -notmatch "Trend Micro") -and ($avs[$i] -notmatch "Worry-Free Business Security"))) {
          $script:o_AVcon = 1
          $script:o_CompAV += $avs[$i] + '<br>' #$script:o_CompAV + $avs[$i] + " , "
          $script:o_CompPath += $avpath[$i] + '<br>' #$script:o_CompPath + $avpath[$i] + " , "
          $script:o_Compstate += $avstat[$i] + '<br>' #$script:o_Compstate + $avstat[$i] + " , "
        } elseif ($i_PAV -ne "Trend Micro") {
          $script:o_AVcon = 1
          $script:o_CompAV += $avs[$i] + '<br>' #$script:o_CompAV + $avs[$i] + " , "
          $script:o_CompPath += $avpath[$i] + '<br>' #$script:o_CompPath + $avpath[$i] + " , "
          $script:o_Compstate += $avstat[$i] + '<br>' #$script:o_Compstate + $avstat[$i] + " , "
        }
      }
      #PRIMARY AV PRODUCT
      if (($avs[$i] -match $i_PAV) -or 
        (($i_PAV -eq "Trend Micro") -and (($avs[$i] -match "Trend Micro") -or ($avs[$i] -match "Worry-Free Business Security")))) {
        #AV DETAILS
        $script:o_AVname = $avs[$i]
        $script:o_AVpath = $avpath[$i]
        #REAL-TIME SCANNING & DEFINITIONS
        if ($blnWMI) {
          #will still return if it is unknown, etc. if it is unknown look at the code it returns, then look up the status and add it above
          Get-AVState($avstat[$i])
          $script:o_DefStatus = $script:defstatus
          $script:o_RTstate = $script:rtstatus
        } elseif (-not $blnWMI) {
          $script:o_DefStatus = $script:defstatus
          $script:o_RTstate = $avrt[$i]
        }
        #PARSE XML FOR SPECIFIC VENDOR AV PRODUCT
        $node = $avs[$i].replace(" ", "").replace("-", "").toupper()
        #AV PRODUCT VERSION KEY PATH AND VALUE
        $i_verkey = $avXML.NODE.$node.$script:bitarch.ver
        $i_verval = $avXML.NODE.$node.$script:bitarch.verval
        #AV PRODUCT STATE KEY PATH AND VALUE
        $i_statkey = $avXML.NODE.$node.$script:bitarch.stat
        $i_statval = $avXML.NODE.$node.$script:bitarch.statval
        #GET PRIMARY AV PRODUCT VERSION VIA REGISTRY
        try {
          $script:o_AVVersion = get-itemproperty -path "HKLM:$i_verkey" -name "$i_verval" -ErrorAction Stop
          write-host "Reading -path HKLM:$i_verkey -name $i_verval" -foregroundcolor Yellow
        } catch {
          $script:o_AVVersion | add-member -NotePropertyName "$i_verval" -NotePropertyValue "."
        }
        $script:o_AVVersion = $script:o_AVVersion.$i_verval
        #GET PRIMARY AV PRODUCT STATUS VIA REGISTRY
        try {
          $script:o_AVStatus = get-itemproperty -path "HKLM:$i_statkey" -name "$i_statval" -ErrorAction Stop
          write-host "Reading -path HKLM:$i_statkey -name $i_statval" -foregroundcolor Yellow
        } catch {
          $script:o_AVStatus | add-member -NotePropertyName "$i_statval" -NotePropertyValue "0"
        }
        #INTERPRET 'AVSTATUS' BASED ON ANY AV PRODUCT VALUE REPRESENTATION - SOME TREAT '0' AS 'UPTODATE' SOME TREAT '1' AS 'UPTODATE'
        #$script:o_AVStatus.$i_statval
        if ($script:zUpgrade -contains $avs[$i]) {
          write-host $avs[$i] " reports " $script:o_AVStatus.$i_statval " for 'Up-To-Date' (Expected : '0')" -foregroundcolor Yellow
          if ($script:o_AVStatus.$i_statval -eq "0") {
            $script:o_AVStatus = $true
          } else {
            $script:o_AVStatus = $false
          }
        } elseif ($script:zUpgrade -notcontains $avs[$i]) {
          write-host $avs[$i] " reports " $script:o_AVStatus.$i_statval " for 'Up-To-Date' (Expected : '1')" -foregroundcolor Yellow
          if ($script:o_AVStatus.$i_statval -eq "1") {
            $script:o_AVStatus = $true
          } else {
            $script:o_AVStatus = $false
          }
        }
      #SAVE WINDOWS DEFENDER FOR LAST - TO PREVENT SCRIPT CONSIDERING IT 'COMPETITOR AV' WHEN SET AS PRIMARY AV
      } elseif ($avs[$i] -eq "Windows Defender") {
        $script:o_CompAV += $avs[$i] + '<br>' #$script:o_CompAV + $avs[$i] + " , "
        $script:o_CompPath += $avpath[$i] + '<br>' #$script:o_CompPath + $avpath[$i] + " , "
        $script:o_Compstate += $avstat[$i] + '<br>' #$script:o_Compstate + $avstat[$i] + " , "  
      }
    }
    $i = $i + 1
  }
}
#OUTPUT
if ($script:o_AVname -ne "No AV Product Found") {
  $ccode = "Green"
} elseif ($script:o_AVname -eq "No AV Product Found") {
  $ccode = "Red"
}
write-host "Device : " $script:computername -ForegroundColor $ccode
write-host "Operating System : " $script:OSCaption ($script:OSVersion) -ForegroundColor $ccode
write-host "AV Display Name : " $script:o_AVname -foregroundcolor $ccode
write-host "AV Version : " $script:o_AVVersion -foregroundcolor $ccode
write-host "AV Path : " $script:o_AVpath -foregroundcolor $ccode
write-host "AV Status : " $script:o_AVStatus -foregroundcolor $ccode
write-host "Real-Time Status : " $script:o_RTstate -foregroundcolor $ccode
write-host "Definition Status : " $script:o_DefStatus -foregroundcolor $ccode
write-host "AV Conflict : " $script:o_AVcon -foregroundcolor $ccode
write-host "Competitor AV : " $script:o_CompAV -foregroundcolor $ccode
write-host "Competitor Path : " $script:o_CompPath -foregroundcolor $ccode
#END SCRIPT
#------------