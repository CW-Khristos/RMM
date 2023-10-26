#First Clear any variables
Remove-Variable * -ErrorAction SilentlyContinue

#region ----- DECLARATIONS ----
  $script:diag          = $null
  $script:blnWARN       = $false
  $script:pDisks        = @()
  $script:vDisks        = @()
  $script:Controllers   = @()
  $strLineSeparator     = "---------"
  $storCLIexe           = 'C:\IT\StorCLI\Storcli64.exe' #$env:StoreCliPath
  $storCLIcmd           = "/call show all J"
  $storCLIsrc           = "https://github.com/CW-Khristos/scripts/raw/master/StorCLI/Windows/storcli64.exe"
#endregion ----- DECLARATIONS ----

#region ----- FUNCTIONS ----
  function write-DRMMDiag ($messages) {
    write-output "<-Start Diagnostic->"
    foreach ($message in $messages) {$message}
    write-output "<-End Diagnostic->"
  }

  function write-DRMMAlert ($message) {
    write-output "<-Start Result->"
    write-output "Alert=$($message)"
    write-output "<-End Result->"
  }

  function logERR ($intSTG, $strModule, $strErr) {
    $script:blnWARN = $true
    #CUSTOM ERROR CODES
    switch ($intSTG) {
      1 {                                                         #'ERRRET'=1 - NOT ENOUGH ARGUMENTS, END SCRIPT
        $script:blnBREAK = $true
        $script:diag += "$($strLineSeparator)`r`n$($(get-date))`t - MegaRAID_Status - NO ARGUMENTS PASSED, END SCRIPT`r`n`r`n"
        write-output "$($strLineSeparator)`r`n$($(get-date))`t - MegaRAID_Status - NO ARGUMENTS PASSED, END SCRIPT`r`n"
      }
      2 {                                                         #'ERRRET'=2 - INSTALL / IMPORT MODULE FAILURE, END SCRIPT
        $script:blnBREAK = $true
        $script:diag += "$($strLineSeparator)`r`n$($(get-date))`t - MegaRAID_Status - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n"
        write-output "$($strLineSeparator)`r`n$($(get-date))`t - MegaRAID_Status - $($strModule) :"
        write-output "$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n"
      }
      3 {                                                         #'ERRRET'=3+
        $script:blnWARN = $false
        $script:diag += "$($strLineSeparator)`r`n$($(get-date))`t - MegaRAID_Status - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
        write-output "$($strLineSeparator)`r`n$($(get-date))`t - MegaRAID_Status - $($strModule) :"
        write-output "$($strLineSeparator)`r`n`t$($strErr)"
      }
      default {                                                   #'ERRRET'=4+
        $script:diag += "$($strLineSeparator)`r`n$($(get-date))`t - MegaRAID_Status - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
        write-output "$($strLineSeparator)`r`n$($(get-date))`t - MegaRAID_Status - $($strModule) :"
        write-output "$($strLineSeparator)`r`n`t$($strErr)"
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
    $ScriptStopTime = (get-date -format "yyyy-MM-dd HH:mm:ss").ToString()
    write-output "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
    $script:diag += "`r`n`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
  }
#endregion ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
clear-host
#Start script execution time calculation
$ScrptStartTime = (Get-Date).ToString('dd-MM-yyyy hh:mm:ss')
$script:sw = [Diagnostics.Stopwatch]::StartNew()
#CHECK 'PERSISTENT' FOLDERS
if (-not (test-path -path "C:\temp")) {new-item -path "C:\temp" -itemtype directory}
if (-not (test-path -path "C:\IT")) {new-item -path "C:\IT" -itemtype directory}
if (-not (test-path -path "C:\IT\StorCLI")) {new-item -path "C:\IT\StorCLI" -itemtype directory}
logERR 3 "START" "`t- Checking StorCLI`r`n$($strLineSeparator)"
#DOWNLOAD STORCLI64.EXE IF NEEDED
if (-not (test-path -path "$($storCLIexe)" -pathtype leaf)) {
  try {
    #IPM-Khristos
    start-bitstransfer -erroraction stop -source $storCLIsrc -destination $storCLIexe
  } catch {
    $err += "`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
    logERR 3 "BitsTransfer" "`tFAILED TO DOWNLOAD STORCLI`r`n$($err)`r`n$($strLineSeparator)"
    try {
      #IPM-Khristos
      $web = new-object system.net.webclient
      $web.downloadfile($storCLIsrc, $storCLIexe)
    } catch {
      $err += "`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
      logERR 2 "DownloadFile" "`tFAILED TO DOWNLOAD STORCLI`r`n$($err)`r`n$($strLineSeparator)"
    }
  }
}
#EXECUTE STORCLI64.EXE
if (-not ($script:blnBREAK)) {
  try {
    $ExecuteStorCLI = & $storCLIexe $storCLIcmd | out-string
    $ArrayStorCLI = ConvertFrom-Json $ExecuteStorCLI
  } catch {
    $err += "`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
    logERR 2 "COMMAND" "`t- StorCLI Command Failed: `r`n$($err)`r`n$($strLineSeparator)"
    write-DRMMAlert "StorCLI Command Failed : Please check diagnostic information"
    write-DRMMDiag "$($script:diag)"
    exit 1
  }
  #ADAPTERS / CONTROLLERS
  foreach ($Controller in $ArrayStorCLI.Controllers.'Response data') {
    if ($($Controller.Status.'Controller Status') -eq "OK") {
      $output = "Controller : $($Controller.Status | fl | out-string)"
      logERR 3 "CHK-CONTROLLER" "`t- INFO :`r`n$($output)`r`n$($strLineSeparator)"
    } elseif ($($Controller.Status.'Controller Status') -ne "OK") {
      $script:blnWARN = $true
      $output = "Controller : $($Controller.Status | fl | out-string)"
      logERR 3 "CHK-CONTROLLER" "`t- WARNING :`r`n$($output)`r`n$($strLineSeparator)"
    }
    #PHYSICAL DISKS
    $pDisk = @{}
    $pDiskObj = $ArrayStorCLI.Controllers.'Response data'.'Physical Device Information'
    foreach ($pDiskProp in $pDiskObj.psobject.properties) {
      if ($pDiskProp.name -notmatch " - Detailed Information") {
        if (($($pDiskProp.value.state) -eq "Onln") -or ($($pDiskProp.value.state) -eq "-")) {
          $output = "$($pDiskProp.name) : State : Online"
          logERR 3 "CHK-PDISK" "`t- INFO :`r`n$($output)`r`n$($strLineSeparator)"
        } elseif (($($pDiskProp.value.state) -ne "Onln") -and ($($pDiskProp.value.state) -ne "-")) {
          $script:blnWARN = $true
          $output = "$($pDiskProp.name) : $($pDiskProp.value | fl | out-string)"
          logERR 3 "CHK-PDISK" "`t- WARNING :`r`n$($output)`r`n$($strLineSeparator)"
        }
        $pDisk = @{
          ID                = $pDiskProp.value.DID
          State             = $pDiskProp.value.State
          Group             = $pDiskProp.value.DG
          Interface         = $pDiskProp.value.Intf
          Medium            = $pDiskProp.value.Med
          SectorSz          = $pDiskProp.value.SeSz
          Size              = $pDiskProp.value.Size
          Model             = $pDiskProp.value.Model
          DetailState       = $pDiskObj."$($pDiskProp.name) - Detailed Information"."$($pDiskProp.name) State"
          DetailAttributes  = $pDiskObj."$($pDiskProp.name) - Detailed Information"."$($pDiskProp.name) Device attributes"
          DetailSettings    = $pDiskObj."$($pDiskProp.name) - Detailed Information"."$($pDiskProp.name) Policies/Settings"
        }
        $script:pDisks += New-Object -TypeName PSObject -Property @{pDisk = $pDisk}
      }
    }
    #VIRTUAL DISKS
    $vDisk = @{}
    $vDiskObj = $ArrayStorCLI.Controllers.'Response data'.'Virtual Drives'
    foreach ($vDiskProp in $vDiskObj.psobject.properties) {
      if ($vDiskProp.name -notmatch " - Detailed Information") {
        if ($($vDiskProp.value.state) -eq "Optl") {
          $output = "$($vDiskProp.name) : State : Optimal"
          logERR 3 "CHK-VDISK" "`t- INFO :`r`n$($output)`r`n$($strLineSeparator)"
        } elseif ($($vDiskProp.value.state) -ne "Optl") {
          $script:blnWARN = $true
          $output = "$($vDiskProp.name) : $($vDiskProp.value | fl | out-string)"
          logERR 3 "CHK-VDISK" "`t- WARNING :`r`n$($output)`r`n$($strLineSeparator)"
        }
        $vDisk = @{
          ID                = $vDiskProp.value.DID
          State             = $vDiskProp.value.State
          Group             = $vDiskProp.value.DG
          Interface         = $vDiskProp.value.Intf
          Medium            = $vDiskProp.value.Med
          SectorSz          = $vDiskProp.value.SeSz
          Size              = $vDiskProp.value.Size
          Model             = $vDiskProp.value.Model
          DetailState       = $vDiskObj."$($vDiskProp.name) - Detailed Information"."$($vDiskProp.name) State"
          DetailAttributes  = $vDiskObj."$($vDiskProp.name) - Detailed Information"."$($vDiskProp.name) Device attributes"
          DetailSettings    = $vDiskObj."$($vDiskProp.name) - Detailed Information"."$($vDiskProp.name) Policies/Settings"
        }
        $script:vDisks += New-Object -TypeName PSObject -Property @{vDisk = $vDisk}
      }
    }
    $script:Controllers += New-Object -TypeName PSObject -Property @{
      Basics          = $Controller.Basics
      Status          = $Controller.Status
      PCIVersion      = $Controller.'PCI Version'
      Firmware        = $Controller.Version
      HwConfig        = $Controller.HwCfg
      Capabilities    = $Controller.Capabilities
      pDisks          = $script:pDisks
      vDisks          = $script:vDisks
    }
  }
  StopClock
  if ($script:blnWARN) {
    write-DRMMAlert "Controller(s) Reporting Unhealthy / Not Optimal. Please check diagnostic information"
    write-DRMMDiag "$($script:diag)"
    exit 1
  } elseif (-not $script:blnWARN) {
    write-DRMMAlert "Controller(s) Reporting Healthy"
    exit 0
  }
} elseif ($script:blnBREAK) {
  StopClock
  write-DRMMAlert "Unable to Check RAID Status. Please check diagnostic information"
  write-DRMMDiag "$($script:diag)"
  exit 1
}
#END SCRIPT
#------------