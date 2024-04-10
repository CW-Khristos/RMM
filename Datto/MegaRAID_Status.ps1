#First Clear any variables
Remove-Variable * -ErrorAction SilentlyContinue

#region ----- DECLARATIONS ----
  $script:diag          = $null
  $script:blnWARN       = $false
  $script:pDisks        = @()
  $script:vDisks        = @()
  $script:Controllers   = @()
  $strLineSeparator     = "---------"
  $storCLIexe           = 'C:\IT\StorCLI\Storcli64.exe' #$env:StorCliPath
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
      #'ERRRET'=1 - NOT ENOUGH ARGUMENTS, END SCRIPT
      1 {
        $script:blnBREAK = $true
        $script:diag += "$($strLineSeparator)`r`n$($(get-date))`t - MegaRAID_Status - NO ARGUMENTS PASSED, END SCRIPT`r`n`r`n"
        write-output "$($strLineSeparator)`r`n$($(get-date))`t - MegaRAID_Status - NO ARGUMENTS PASSED, END SCRIPT`r`n"
      }
      #'ERRRET'=2 - INSTALL / IMPORT MODULE FAILURE, END SCRIPT
      2 {
        $script:blnBREAK = $true
        $script:diag += "$($strLineSeparator)`r`n$($(get-date))`t - MegaRAID_Status - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n"
        write-output "$($strLineSeparator)`r`n$($(get-date))`t - MegaRAID_Status - $($strModule) :"
        write-output "$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n"
      }
      #'ERRRET'=3+
      3 {
        $script:blnWARN = $false
        $script:diag += "$($strLineSeparator)`r`n$($(get-date))`t - MegaRAID_Status - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
        write-output "$($strLineSeparator)`r`n$($(get-date))`t - MegaRAID_Status - $($strModule) :"
        write-output "$($strLineSeparator)`r`n`t$($strErr)"
      }
      #'ERRRET'=4+
      default {
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
    if (($($Controller.Status.'Controller Status') -eq "OK") -or ($($Controller.Status.'Controller Status') -eq "Optimal")) {
      $output = "Controller : $(($Controller.Status | fl | out-string).trim())"
      logERR 3 "CHK-CONTROLLER" "`t- INFO :`r`n$($output)`r`n$($strLineSeparator)"
    } elseif (($($Controller.Status.'Controller Status') -ne "OK") -and ($($Controller.Status.'Controller Status') -ne "Optimal")) {
      $script:blnWARN = $true
      $output = "Controller : $(($Controller.Status | fl | out-string).trim())"
      logERR 4 "CHK-CONTROLLER" "`t- WARNING :`r`n$($output)`r`n$($strLineSeparator)"
    }
    #PHYSICAL DISKS
    $pDisk = @{}
    $pDiskObj = $ArrayStorCLI.Controllers.'Response data'.'Physical Device Information' | out-string
    if (-not ($pDiskObj)) {
      $strMatch = "SyncRoot"
      $pDiskObj = $ArrayStorCLI.Controllers.'Response data'.'PD LIST'
    } elseif ($pDiskObj) {
      $strMatch = " - Detailed Information"
      $pDiskObj = $ArrayStorCLI.Controllers.'Response data'.'Physical Device Information'
    }
    $pDiskObj.psobject.properties | where {($_.value.state)} | foreach {
      foreach ($disk in $_.value) {$script:pDisks += New-Object -TypeName PSObject -Property @{pDisk = $disk}}
    }
    foreach ($disk in $script:pDisks.pDisk) {
      if ($disk) {
        if (($($disk.state) -eq "GHS") -or ($($disk.state) -eq "-")) {
          $output = "`tSlot : $($disk.'EID:Slt')`r`n`t`tDisk : $($disk.DID) - Disk Group : $($disk.DG)"
          $output += "`r`n`t`tModel : $($disk.Model)`r`n`t`tState : Global Hot Spare"
          logERR 3 "CHK-PDISK" "- INFO :`r`n`t$($output)`r`n$($strLineSeparator)"
        } elseif (($($disk.state) -eq "Onln") -or ($($disk.state) -eq "-")) {
          $output = "`tSlot : $($disk.'EID:Slt')`r`n`t`tDisk : $($disk.DID) - Disk Group : $($disk.DG)"
          $output += "`r`n`t`tModel : $($disk.Model)`r`n`t`tState : Online"
          logERR 3 "CHK-PDISK" "- INFO :`r`n`t$($output)`r`n$($strLineSeparator)"
        } elseif (($($disk.state) -ne "Onln") -and ($($disk.state) -ne "-") -and ($($disk.state) -ne "GHS")) {
          $script:blnWARN = $true
          $output = "$($_) : $($_ | fl | out-string)"
          logERR 4 "CHK-PDISK" "- WARNING :`r`n`t$($output)`r`n$($strLineSeparator)"
        }
      }
    }
    #VIRTUAL DISKS
    $vDisk = @{}
    $vDiskObj = $ArrayStorCLI.Controllers.'Response data'.'Virtual Drives' | out-string
    if ((-not ($vDiskObj)) -or ($vdiskObj -match 2)) {
      $strMatch = "SyncRoot"
      $vDiskObj = $ArrayStorCLI.Controllers.'Response data'.'VD LIST'
    } elseif ($vDiskObj) {
      $strMatch = " - Detailed Information"
      $vDiskObj = $ArrayStorCLI.Controllers.'Response data'.'Physical Device Information'
    }
    $vDiskObj.psobject.properties | where {($_.value.state)} | foreach {
      foreach ($disk in $_.value) {$script:vDisks += New-Object -TypeName PSObject -Property @{vDisk = $disk}}
    }
    foreach ($disk in $script:vDisks.vDisk) {
      if ($disk) {
        if (($($disk.state) -eq "Optl") -and ($($disk.Consist) -eq "Yes")) {
          $output = "`tVirtual Disk : $($disk.'DG/VD') - Name : $($disk.Name)"
          $output += "`r`n`t`tType : $($disk.Type)`r`n`t`tSize : $($disk.Size)`r`n`t`tCache : $($disk.Cache)"
          logERR 3 "CHK-VDISK" "- INFO :`r`n`t$($output)`r`n$($strLineSeparator)"
        } elseif (($($disk.state) -ne "Optl") -or ($($disk.state) -ne "Yes")) {
          $script:blnWARN = $true
          $output = "`tSlot : $($disk.'EID:Slt')`r`n`t`tDisk : $($disk.DID) - Disk Group : $($disk.DG)"
          $output += "`r`n`t`tModel : $($disk.Model)`r`n`t`tState : Online"
          logERR 4 "CHK-VDISK" "- INFO :`r`n`t$($output)`r`n$($strLineSeparator)"
        }
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