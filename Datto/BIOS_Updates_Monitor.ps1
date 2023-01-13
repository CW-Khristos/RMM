#region ----- DECLARATIONS ----
  #BELOW PARAM() MUST BE COMMENTED OUT FOR USE WITHIN DATTO RMM
  #UNCOMMENT BELOW PARAM() AND RENAME '$env:var' TO '$var' TO UTILIZE IN CLI
  #Param (
  #)
  #VERSION FOR SCRIPT UPDATE
  $strSCR           = "BIOS_Updates_Monitor"
  $strVER           = [version]"0.1.0"
  $strREPO          = "RMM"
  $strBRCH          = "dev"
  $strDIR           = "Datto"
  $script:diag      = $null
  $script:blnWARN   = $false
  $script:blnBREAK  = $false
  $strLineSeparator = "---------"
  $releaseThreshold = $env:YearThreshold
  $sysRegKey        = "HKLM:\HARDWARE\DESCRIPTION\System"
  $biosRegKey       = "HKLM:\HARDWARE\DESCRIPTION\System\BIOS"
#endregion ----- DECLARATIONS ----

#region ----- FUNCTIONS ----
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

  function logERR($intSTG, $strErr) {
    $script:blnWARN = $true
    #CUSTOM ERROR CODES
    switch ($intSTG) {
      1 {                                                                             #'ERRRET'=1 - ERROR DELETING FILE / FOLDER
        $script:diag += "$($strLineSeparator)`r`n$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - BIOS_Updates_Monitor - ERROR DELETING FILE / FOLDER`r`n$($strErr)`r`n$($strLineSeparator)`r`n`r`n"
        write-host "$($strLineSeparator)`r`n$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - BIOS_Updates_Monitor - ERROR DELETING FILE / FOLDER`r`n$($strErr)`r`n$($strLineSeparator)`r`n"
      }
      2 {                                                                             #'ERRRET'=2 - NOT ENOUGH ARGUMENTS, END SCRIPT
        $script:diag += "$($strLineSeparator)`r`n$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - BIOS_Updates_Monitor - NO ARGUMENTS PASSED, END SCRIPT`r`n$($strErr)`r`n$($strLineSeparator)`r`n`r`n"
        write-host "$($strLineSeparator)`r`n$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - BIOS_Updates_Monitor - NO ARGUMENTS PASSED, END SCRIPT`r`n$($strErr)`r`n$($strLineSeparator)`r`n"
      }
      default {                                                                       #'ERRRET'=3+
        write-host "$($strLineSeparator)`r`n$((get-date).ToString('dd-MM-yyyy hh:mm:ss'))`t - BIOS_Updates_Monitor - $($strErr)`r`n$($strLineSeparator)`r`n"
        $script:diag += "$($strLineSeparator)`r`n$((get-date).ToString('dd-MM-yyyy hh:mm:ss'))`t - BIOS_Updates_Monitor - $($strErr)`r`n$($strLineSeparator)`r`n`r`n"
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
    write-host "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
  }
#endregion ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
clear-host
#Start script execution time calculation
$ScrptStartTime = (Get-Date).ToString('dd-MM-yyyy hh:mm:ss')
$script:sw = [Diagnostics.Stopwatch]::StartNew()
try {
  #RETRIEVE SYSTEM RELEASE DATE
  write-host "$($strLineSeparator)`r`nChecking System BIOS :`r`n$($strLineSeparator)"
  $script:diag += "$($strLineSeparator)`r`nChecking System BIOS :`r`n$($strLineSeparator)`r`n"
  write-host "`tReading : -path '$($sysRegKey)' -name 'SystemBiosDate'"
  $script:diag += "`tReading : -path '$($sysRegKey)' -name 'SystemBiosDate'`r`n"
  $sysDate = get-itemproperty -path "$($sysRegKey)" -name "SystemBiosDate" -erroraction stop

  $biosVersion = $null
  write-host "`tReading : -path '$($sysRegKey)' -name 'SystemBiosVersion'"
  $script:diag += "`tReading : -path '$($sysRegKey)' -name 'SystemBiosVersion'`r`n"
  $sysVersion = get-itemproperty -path "$($sysRegKey)" -name "SystemBiosVersion" -erroraction stop
  foreach ($line in $sysVersion.SystemBiosVersion) {$biosVersion += "`t$($line)`r`n"}

  write-host "`t$($strLineSeparator)`r`n`tBIOS Release Date : $($sysDate.SystemBiosDate)"
  $script:diag += "`t$($strLineSeparator)`r`n`tBIOS Release Date : $($sysDate.SystemBiosDate)`r`n"
  write-host "`tBIOS Release Version : $($biosVersion)`r`n$($strLineSeparator)"
  $script:diag += "`tBIOS Release Version : $($biosVersion)`r`n$($strLineSeparator)`r`n"

  #RETRIEVE BIOS RELEASE VERSION
  write-host "$($strLineSeparator)`r`nChecking BIOS Release Version :`r`n$($strLineSeparator)"
  $script:diag += "$($strLineSeparator)`r`nChecking BIOS Release Version :`r`n$($strLineSeparator)`r`n"
  write-host "`tReading : -path '$($biosRegKey)' -name 'BIOSVendor'"
  $script:diag += "`tReading : -path '$($biosRegKey)' -name 'BIOSVendor'`r`n"
  $biosVendor = get-itemproperty -path "$($biosRegKey)" -name "BIOSVendor" -erroraction stop

  write-host "`tReading : -path '$($biosRegKey)' -name 'BaseBoardManufacturer'"
  $script:diag += "`tReading : -path '$($biosRegKey)' -name 'BaseBoardManufacturer'`r`n"
  $boardManufacturer = get-itemproperty -path "$($biosRegKey)" -name "BaseBoardManufacturer" -erroraction stop

  write-host "`tReading : -path '$($biosRegKey)' -name 'BaseBoardProduct'"
  $script:diag += "`tReading : -path '$($biosRegKey)' -name 'BaseBoardProduct'`r`n"
  $boardProduct = get-itemproperty -path "$($biosRegKey)" -name "BaseBoardProduct" -erroraction stop

  write-host "`tReading : -path '$($biosRegKey)' -name 'BIOSReleaseDate'"
  $script:diag += "`tReading : -path '$($biosRegKey)' -name 'BIOSReleaseDate'`r`n"
  $biosDate = get-itemproperty -path "$($biosRegKey)" -name "BIOSReleaseDate" -erroraction stop

  write-host "`tReading : -path '$($biosRegKey)' -name 'BIOSVersion'"
  $script:diag += "`tReading : -path '$($biosRegKey)' -name 'BIOSVersion'`r`n"
  $biosVersion = get-itemproperty -path "$($biosRegKey)" -name "BIOSVersion" -erroraction stop

  write-host "`t$($strLineSeparator)`r`n`tBIOS Vendor : $($biosVendor.BIOSVendor)"
  $script:diag += "`t$($strLineSeparator)`r`n`tBIOS Vendor : $($biosVendor.BIOSVendor)`r`n"
  write-host "`tBase Board Manufacturer : $($boardManufacturer.BaseBoardManufacturer)"
  $script:diag += "`tBase Board Manufacturer : $($boardManufacturer.BaseBoardManufacturer)`r`n"
  write-host "`tBase Board Product : $($boardProduct.BaseBoardProduct)"
  $script:diag += "`tBase Board Product : $($boardProduct.BaseBoardProduct)`r`n"
  write-host "`tBIOS Release Date : $($biosDate.BIOSReleaseDate)"
  $script:diag += "`tBIOS Release Date : $($biosDate.BIOSReleaseDate)`r`n"
  write-host "`tBIOS Release Version : $($biosVersion.BIOSVersion)`r`n$($strLineSeparator)"
  $script:diag += "`tBIOS Release Version : $($biosVersion.BIOSVersion)`r`n$($strLineSeparator)`r`n"
  if ([DateTime]$biosDate.BIOSReleaseDate -le (get-date).AddYears(-$releaseThreshold)) {
    $script:blnWARN = $true
    write-host "`r`nBIOS_Monitor : WARNING : BIOS Release Date Older than Threshold ($($releaseThreshold) Years)`r`n"
    $script:diag += "`r`nBIOS_Monitor : WARNING : BIOS Release Date Older than Threshold ($($releaseThreshold) Years)`r`n"
  }
} catch {
  $script:blnBREAK = $true
  $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
  logERR 3 $err
}
#Stop script execution time calculation
StopClock
#DATTO OUTPUT
if ($script:blnBREAK) {
  write-DRMMAlert "BIOS_Updates_Monitor : Execution Completed with Warnings : See Diagnostics"
  write-DRMMDiag "$($script:diag)"
  exit 1
} elseif (-not $script:blnBREAK) {
  if ($script:blnWARN) {
    write-DRMMAlert "BIOS_Updates_Monitor : UnHealthy : See Diagnostics"
    write-DRMMDiag "$($script:diag)"
    exit 1
  } elseif (-not $script:blnWARN) {
    write-DRMMAlert "BIOS_Updates_Monitor : Completed Execution"
    write-DRMMDiag "$($script:diag)"
    exit 0
  }
}
#END SCRIPT
#------------