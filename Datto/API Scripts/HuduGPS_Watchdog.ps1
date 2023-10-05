#region ----- DECLARATIONS ----
  #BELOW PARAM() MUST BE COMMENTED OUT FOR USE WITHIN DATTO RMM
  #UNCOMMENT BELOW PARAM() AND RENAME '$env:i_PAV' TO '$i_PAV' TO UTILIZE IN CLI
  #Param(
  #  [Parameter(Mandatory=$true)]$i_PAV
  #)
  $script:diag            = $null
  $script:bitarch         = $null
  $script:OSCaption       = $null
  $script:OSVersion       = $null
  $script:producttype     = $null
  $script:computername    = $null
  $script:blnWARN         = $false
  $script:blnBREAK        = $false
  $logPath                = "C:\IT\Log\HuduGPS_Watchdog"
  $strLineSeparator       = "----------------------------------"
  ######################### TLS Settings ###########################
  #[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType] 'Tls12'
  [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls -bor [System.Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls12
  ######################### Hudu Settings ###########################
  $script:huduCalls       = 0
  # Get a Hudu API Key from https://yourhududomain.com/admin/api_keys
  $script:HuduAPIKey      = $env:HuduKey
  # Set the base domain of your Hudu instance without a trailing /
  $script:HuduBaseDomain  = $env:HuduDomain
  $script:Customer        = $env:CS_PROFILE_NAME
#endregion ----- DECLARATIONS ----

#region ----- FUNCTIONS ----
  function write-DRMMDiag ($messages) {
    write-output "<-Start Diagnostic->"
    foreach ($message in $messages) {$message}
    write-output "<-End Diagnostic->"
  } ## write-DRMMDiag
  
  function write-DRMMAlert ($message) {
    write-output "<-Start Result->"
    write-output "Alert=$($message)"
    write-output "<-End Result->"
  } ## write-DRMMAlert

  function Get-ProcessOutput {
    Param (
      [Parameter(Mandatory=$true)]$FileName,
      $Args
    )
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo.WindowStyle = "Hidden"
    $process.StartInfo.CreateNoWindow = $true
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.RedirectStandardOutput = $true
    $process.StartInfo.RedirectStandardError = $true
    $process.StartInfo.FileName = $FileName
    if($Args) {$process.StartInfo.Arguments = $Args}
    $out = $process.Start()

    $StandardError = $process.StandardError.ReadToEnd()
    $StandardOutput = $process.StandardOutput.ReadToEnd()

    $output = New-Object PSObject
    $output | Add-Member -type NoteProperty -name StandardOutput -Value $StandardOutput
    $output | Add-Member -type NoteProperty -name StandardError -Value $StandardError
    return $output
  } ## Get-ProcessOutput

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

  function logERR ($intSTG, $strModule, $strErr) {
    $script:blnWARN = $true
    #CUSTOM ERROR CODES
    switch ($intSTG) {
      1 {                                                         #'ERRRET'=1 - NOT ENOUGH ARGUMENTS, END SCRIPT
        $script:blnBREAK = $true
        $script:diag += "`r`n$($(get-date))`t - HuduGPS_Watchdog - NO ARGUMENTS PASSED, END SCRIPT`r`n`r`n"
        write-output "$($(get-date))`t - HuduGPS_Watchdog - NO ARGUMENTS PASSED, END SCRIPT`r`n"
      }
      2 {                                                         #'ERRRET'=2 - INSTALL / IMPORT MODULE FAILURE, END SCRIPT
        $script:blnBREAK = $true
        $script:diag += "`r`n$($(get-date))`t - HuduGPS_Watchdog - ($($strModule))`r`n$($strErr), END SCRIPT`r`n`r`n"
        write-output "$($(get-date))`t - HuduGPS_Watchdog - ($($strModule))`r`n$($strErr), END SCRIPT`r`n`r`n"
      }
      default {                                                   #'ERRRET'=3+
        $script:diag += "`r`n$($(get-date))`t - HuduGPS_Watchdog - $($strModule) : $($strErr)"
        write-output "$($(get-date))`t - HuduGPS_Watchdog - $($strModule) : $($strErr)"
      }
    }
  }

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
    write-output "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
  }
#endregion ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
clear-host
#Start script execution time calculation
$ScrptStartTime = (Get-Date).ToString('dd-MM-yyyy hh:mm:ss')
$script:sw = [Diagnostics.Stopwatch]::StartNew()
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
Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
#INSTALL NUGET PROVIDER
if (-not (Get-PackageProvider -name NuGet)) {
  Install-PackageProvider -Name NuGet -force -Confirm:$false
}
#INSTALL POWERSHELLGET MODULE
if (Get-Module -ListAvailable -Name PowershellGet) {
  Import-Module PowershellGet 
} else {
  Install-Module PowershellGet -force -Confirm:$false
  Import-Module PowershellGet
}
#Get the Hudu API Module if not installed
if (Get-Module -ListAvailable -Name HuduAPI) {
  try {
    Import-Module HuduAPI -MaximumVersion 2.3.2 -force
  } catch {
    logERR 2 "HuduAPI" "INSTALL / IMPORT MODULE FAILURE"
  }
} else {
  try {
    install-module HuduAPI -MaximumVersion 2.3.2 -force -confirm:$false
    Import-Module HuduAPI -MaximumVersion 2.3.2 -force
  } catch {
    logERR 2 "HuduAPI" "INSTALL / IMPORT MODULE FAILURE"
  }
}
Set-PSRepository -Name 'PSGallery' -InstallationPolicy Untrusted
if (-not $script:blnBREAK) {
  #GET OS TYPE
  Get-OSArch
  #ENABLE LOCATION SERVICES AND SETTINGS
  write-output "$($strLineSeparator)`r`nEnabling Location Services :`r`n$($strLineSeparator)"
  $script:diag += "$($strLineSeparator)`r`nEnabling Location Services :`r`n$($strLineSeparator)`r`n"
  $out = get-processoutput -filename "C:\Windows\System32\sc.exe" -args "config lfsvc start=auto"
  write-output "`tSTDOUT :`r`n`t$($out.standardoutput)`r`n`tSTDERR :`r`n`t$($out.standarderror)"
  $out = get-processoutput -filename "C:\Windows\System32\net.exe" -args "start lfsvc"
  write-output "`tSTDOUT :`r`n`t$($out.standardoutput)`r`n`tSTDERR :`r`n`t$($out.standarderror)"
  $out = get-processoutput -filename "C:\Windows\System32\reg.exe" -args "add HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\AppPrivacy  /t REG_DWORD /v `"LetAppsAccessLocation`" /d 1 /f"
  write-output "`tSTDOUT :`r`n`t$($out.standardoutput)`r`n`tSTDERR :`r`n`t$($out.standarderror)"
  $out = get-processoutput -filename "C:\Windows\System32\reg.exe" -args "add HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location /t REG_SZ /v `"Value`" /d `"Allow`" /f"
  write-output "`tSTDOUT :`r`n`t$($out.standardoutput)`r`n`tSTDERR :`r`n`t$($out.standarderror)"
  $out = get-processoutput -filename "C:\Windows\System32\reg.exe" -args "add HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location\NonPackaged /t REG_SZ /v `"Value`" /d `"Allow`" /f"
  write-output "`tSTDOUT :`r`n`t$($out.standardoutput)`r`n`tSTDERR :`r`n`t$($out.standarderror)"
  $out = get-processoutput -filename "C:\Windows\System32\reg.exe" -args "add HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location /t REG_SZ /v `"Value`" /d `"Allow`" /f"
  write-output "`tSTDOUT :`r`n`t$($out.standardoutput)`r`n`tSTDERR :`r`n`t$($out.standarderror)"
  $out = get-processoutput -filename "C:\Windows\System32\reg.exe" -args "add HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location\NonPackaged /t REG_SZ /v `"Value`" /d `"Allow`" /f"
  write-output "`tSTDOUT :`r`n`t$($out.standardoutput)`r`n`tSTDERR :`r`n`t$($out.standarderror)"
  #Begin resolving current locaton
  write-output "$($strLineSeparator)`r`nResolving Location :`r`n$($strLineSeparator)"
  $script:diag += "$($strLineSeparator)`r`nResolving Location :`r`n$($strLineSeparator)`r`n"
  Add-Type -AssemblyName System.Device #Required to access System.Device.Location namespace
  $GeoWatcher = New-Object System.Device.Location.GeoCoordinateWatcher #Create the required object
  $GeoWatcher.Start()
  while ($GeoWatcher.Status -ne "Ready") {
    write-output "$($Geowatcher.Permission)"
    $script:diag += "`r`n$($Geowatcher.Permission)`r`n"
    #write-output "$($Geowatcher.Position)"
    #$script:diag += "`r`n$($Geowatcher.Position)`r`n"
    write-output "$($Geowatcher.Status)"
    $script:diag += "`r`n$($Geowatcher.Status)`r`n"
    sleep -Milliseconds 1000
  } #Wait for discovery
  write-output "$($Geowatcher.Status)`r`n"
  $script:diag += "`r`n$($Geowatcher.Status)`r`n`r`n"
  $lat = [string]($GeoWatcher.Position.Location.Latitude)
  $long = [string]($GeoWatcher.Position.Location.Longitude)
  if ([int]$lat -gt 0) {
    $degLAT = "$($lat.split(".")[0])°$($lat.split(".")[1].substring(0,2))'$($lat.split(".")[1].substring($lat.split(".")[1].length - 2,2))`"N"
  } elseif ([int]$lat -lt 0) {
    $degLAT = "$($lat.split(".")[0])°$($lat.split(".")[1].substring(0,2))'$($lat.split(".")[1].substring($lat.split(".")[1].length - 2,2))`"S"
  }
  if ([int]$long -gt 0) {
    $degLONG = "$($long.split(".")[0])°$($long.split(".")[1].substring(0,2))'$($long.split(".")[1].substring($long.split(".")[1].length - 2,2))`"E"
  } elseif ([int]$long -lt 0) {
    $degLONG = "$($long.split(".")[0])°$($long.split(".")[1].substring(0,2))'$($long.split(".")[1].substring($long.split(".")[1].length - 2,2))`"W"
  }
  write-output "$($strLineSeparator)`r`nRetrieved Location :`r`n$($strLineSeparator)"
  $script:diag += "$($strLineSeparator)`r`nRetrieved Location :`r`n$($strLineSeparator)`r`n"
  $gpsURL = "https://www.google.com/maps/search/?api=1&query=$($lat),$($long)"
  write-output "LAT : $($lat) - LAT (DEG) : $($degLAT)"
  $script:diag += "`r`nLAT : $($lat) - LAT (DEG) : $($degLAT)`r`n"
  write-output "LONG : $($long) - LONG (DEG) : $($degLONG)"
  $script:diag += "`r`nLONG : $($long) - LONG (DEG) : $($degLONG)`r`n"
  write-output "URL : $($gpsURL)"
  $script:diag += "`r`nURL : $($gpsURL)`r`n"
  write-output "$($env:CS_PROFILE_NAME)"
  $script:diag += "$($env:CS_PROFILE_NAME)`r`n"
  #########
  #Set Hudu logon information
  New-HuduAPIKey $script:HuduAPIKey
  New-HuduBaseUrl $script:HuduBaseDomain
  $huduCompany = Get-HuduCompanies -Name "$($script:Customer)"
  try {
    switch ($script:producttype) {
      "Workstation" {$script:producttype = "Workstation";break}
      {"DC","Server"} {$script:producttype = "Server";break}
    }
    write-output "`r`n$($strLineSeparator)`r`nAccessing $($script:computername) Hudu Asset in $($huduCompany.name)($($huduCompany.id))"
    $script:diag += "`r`n`r`n$($strLineSeparator)`r`nAccessing $($script:computername) Hudu Asset in $($huduCompany.name)($($huduCompany.id))`r`n"
    $AssetLayout = Get-HuduAssetLayouts -name "$($script:producttype)"
    $Asset = Get-HuduAssets -name "$($script:computername)" -companyid $huduCompany.id -assetlayoutid $AssetLayout.id
    write-output "$($strLineSeparator)`r`n$($Asset)`r`n$($strLineSeparator)`r`n"
    $script:diag += "$($strLineSeparator)`r`n$($Asset)`r`n$($strLineSeparator)`r`n`r`n"
    if (($Asset | measure-object).count -ne 1) {
      write-output "$($strLineSeparator)`r`n$(($Asset | measure-object).count) layout(s) found with name $($script:computername)"
      $script:diag += "`r`n$($strLineSeparator)`r`n$(($Asset | measure-object).count) layout(s) found with name $($script:computername)"
    } else {
      if ($Asset) {
        $AssetFields = @{
          'approx_gps_location' = "$($gpsURL)"
        }
        try {
          $script:huduCalls += 1
          write-output "$($strLineSeparator)`r`nUpdating $($script:producttype) Asset - $($Asset.name)`r`n$($strLineSeparator)"
          $script:diag += "`r`n$($strLineSeparator)`r`nUpdating $($script:producttype) - Asset $($Asset.name)`r`n$($strLineSeparator)"
          $Asset = Set-HuduAsset -asset_id $Asset.id -name "$($Asset.name)" -company_id $huduCompany.id -assetlayoutid $AssetLayout.id -fields $AssetFields
        } catch {
          $err = "$($_.Exception)`r`n$($strLineSeparator)`r`n$($_.scriptstacktrace)`r`n$($strLineSeparator)`r`n$($_)`r`n$($strLineSeparator)"
          $err = "$($strLineSeparator)`r`nError Updating $($script:producttype) Asset - $($script:computername)`r`n$($strLineSeparator)`r`n$($err)"
          logERR 3 "Update Hudu Asset" "`r`n$($err)`r`n`r`n"
        }
      }
    }
  } catch {
    $err = "$($_.Exception)`r`n$($strLineSeparator)`r`n$($_.scriptstacktrace)`r`n$($strLineSeparator)`r`n$($_)`r`n$($strLineSeparator)"
    $err = "$($strLineSeparator)`r`nError Retrieving $($script:producttype) Asset - $($script:computername)`r`n$($strLineSeparator)`r`n$($err)"
    logERR 3 "Retrieve Hudu Asset" "`r`n$($err)`r`n`r`n"
  }
  #DATTO OUTPUT
  #Stop script execution time calculation
  StopClock
  #CLEAR LOGFILE
  $null | set-content $logPath -force
  if (-not $script:blnWARN) {
    #WRITE TO LOGFILE
    $script:diag += "`r`n`r`nHuduGPS_Watchdog : Execution Successful"
    "$($script:diag)" | add-content $logPath -force
    write-DRMMAlert "HuduGPS_Watchdog : Execution Successful"
    #write-DRMMDiag "$($script:diag)"
    $script:diag = $null
    exit 0
  } elseif ($script:blnWARN) {
    #WRITE TO LOGFILE
    $script:diag += "`r`n`r`nHuduGPS_Watchdog : Execution Completed with Warnings : See Diagnostics"
    "$($script:diag)" | add-content $logPath -force
    write-DRMMAlert "HuduGPS_Watchdog : Execution Completed with Warnings : See Diagnostics"
    write-DRMMDiag "$($script:diag)"
    $script:diag = $null
    exit 1
  }
} elseif ($script:blnBREAK) {
  #WRITE TO LOGFILE
  $script:diag += "`r`n`r`nHuduGPS_Watchdog : Execution Failure : See Diagnostics"
  "$($script:diag)" | add-content $logPath -force
  write-DRMMAlert "HuduGPS_Watchdog : Execution Failure : See Diagnostics"
  write-DRMMDiag "$($script:diag)"
  $script:diag = $null
  exit 1
}
#END SCRIPT
#------------