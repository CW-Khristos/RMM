#REGION ----- DECLARATIONS ----
  #BELOW PARAM() MUST BE COMMENTED OUT FOR USE WITHIN DATTO RMM
  #UNCOMMENT BELOW PARAM() AND RENAME '$env:var' TO '$var' TO UTILIZE IN CLI
  #Param (
  #  [Parameter(Mandatory=$true)]$strAV,
  #  [Parameter(Mandatory=$true)]$blnRemove
  #)
  $script:diag      = $null
  $script:blnWARN   = $false
  $script:blnFAIL   = $false
  $blnUninstall     = $false
  $blnMatch         = $false
  $script:arrAV     = @(
    "Avast",
    "AVG",
    "Comodo",
    "CrowdStrike",
    "Kaspersky",
    "Malwarebytes",
    "McAfee",
    "Microsoft Security Essentials",
    "Norton",
    "Sophos",
    "Trend Micro",
    "Webroot"
  )
  $strLineSeparator = "---------"
  $logPath          = "C:\IT\Log\All_AV_Removal"
  #BitDefender Removal Tool
  $script:bdEXE     = "C:\IT\BEST_uninstallTool.exe"
  $script:bdSRC     = "https://download.bitdefender.com/SMB/Hydra/release/bst_win/uninstallTool/BEST_uninstallTool.exe"
  #SET TLS SECURITY FOR CONNECTING TO GITHUB
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12
#ENDREGION ----- DECLARATIONS ----

#REGION ----- FUNCTIONS ----
  function write-DRMMDiag ($messages) {
    write-host  "<-Start Diagnostic->"
    foreach ($message in $messages) {$message}
    write-host "<-End Diagnostic->"
  } ## write-DRMMDiag
  
  function write-DRRMAlert ($message) {
    write-host "<-Start Result->"
    write-host "Alert=$($message)"
    write-host "<-End Result->"
  } ## write-DRRMAlert

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
    if ($mill -like "*.*") {
      $mill = $mill.split(".")[1]
      $mill = $mill.SubString(0,[math]::min(3,$mill.length))
    } elseif ($mill -notlike "*.*") {
      $mill = 0
    }
    $script:diag += "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($mill) Milliseconds`r`n"
    write-host "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($mill) Milliseconds`r`n"
  }

  function logERR ($intSTG, $strModule, $strErr) {
    $script:blnWARN = $true
    #CUSTOM ERROR CODES
    switch ($intSTG) {
      1 {                                                         #'ERRRET'=1 - NOT ENOUGH ARGUMENTS, END SCRIPT
        $script:blnFAIL = $true
        write-host "$($(get-date))`t - All_AV_Removal - NO ARGUMENTS PASSED, END SCRIPT`r`n"
        $script:diag += "`r`n$($(get-date))`t - All_AV_Removal - NO ARGUMENTS PASSED, END SCRIPT`r`n`r`n"
      }
      2 {                                                         #'ERRRET'=2 - INSTALL / IMPORT MODULE FAILURE, END SCRIPT
        $script:blnFAIL = $true
        write-host "$($(get-date))`t - All_AV_Removal - ($($strModule))`r`n$($strErr), END SCRIPT`r`n"
        $script:diag += "`r`n$($(get-date))`t - All_AV_Removal - ($($strModule))`r`n$($strErr), END SCRIPT`r`n`r`n"
      }
      default {                                                   #'ERRRET'=3+
        write-host "$($(get-date))`t - All_AV_Removal - $($strModule) : $($strErr)`r`n"
        $script:diag += "`r`n$($(get-date))`t - All_AV_Removal - $($strModule) : $($strErr)`r`n`r`n"
      }
    }
  }
#ENDREGION ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
clear-host
#Start script execution time calculation
$ScrptStartTime = (Get-Date).ToString('dd-MM-yyyy hh:mm:ss')
$script:sw = [Diagnostics.Stopwatch]::StartNew()
write-host "$($strLineSeparator)"
write-host "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss')) - EXECUTING All_AV_Removal"
write-host "$($strLineSeparator)`r`n"
$script:diag += "$($strLineSeparator)`r`n"
$script:diag += "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss')) - EXECUTING All_AV_Removal`r`n"
$script:diag += "$($strLineSeparator)`r`n`r`n"
#REMOVE PREVIOUS LOGFILE
if (test-path -path "$($logPath)") {
  remove-item -path "$($logPath)" -force
}
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
if (-not (test-path -path "C:\IT\AVTools")) {
  new-item -path "C:\IT\AVTools" -itemtype directory
}
#SET UNINSTALL FLAG
if ($env:blnRemove.toupper() -eq "TRUE") {
  $blnUninstall = $true
} elseif ($env:blnRemove.toupper() -eq "FALSE") {
  $blnUninstall = $false
}
#COLLECT UNINSTALL STRINGS FROM THE REGISTRY
$UninstallStrings = get-childitem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
$UninstallStrings += get-childitem "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
if (($null -ne $env:strAV) -and ($env:strAV -ne "")) {                #A TARGET AV WAS PASSED
  #REMOVAL VIA REGISTRY
  write-host "BEGINNING REMOVAL VIA REGISTRY :"
  write-host "$($strLineSeparator)"
  $script:diag += "BEGINNING REMOVAL VIA REGISTRY :`r`n"
  $script:diag += "$($strLineSeparator)`r`n"
  $avUninstall = $UninstallStrings | get-itemproperty | where {$_.displayname -like "*$($env:strAV)*"}
  if (($null -ne $avUninstall) -and ($avUninstall -ne "")) {          #TARGET AV FOUND
    #SET REBOOT STRINGS
    switch ($env:strAV.toupper()) {
      "MALWAREBYTES" {$strReboot = "/SILENT /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /L*v"}
      "MCAFEE" {$strReboot = "/SILENT /VERYSILENT /quiet /qn /norestart REBOOT=SUPPRESS /L*v"}
      "SOPHOS" {$strReboot = "/SILENT /VERYSILENT /quiet /qn /norestart REBOOT=SUPPRESS /L*v"}
    }
    foreach ($item in $avUninstall) {
      write-host "`r`n$($strLineSeparator)`r`nFOUND $($item.displayname):`r`nDescription : $($item.comments)`r`n$($item.UninstallString)"
      write-host "$($strLineSeparator)"
      $script:diag += "`r`n$($strLineSeparator)`r`nFOUND $($item.displayname):`r`nDescription : $($item.comments)`r`n$($item.UninstallString)`r`n"
      $script:diag += "$($strLineSeparator)`r`n"
      #AV REMOVAL
      if ($blnUninstall) {
        write-host "REMOVING $($item.displayname):"
        write-host "$($strLineSeparator)"
        $script:diag += "REMOVING $($item.displayname):`r`n"
        $script:diag += "$($strLineSeparator)`r`n"
        if ($item.UninstallString -like "*msiexec*") {                #MSI UNINSTALL
          try {
            $UninstallString = $item.UninstallString.split(" ")[1]
            $output = Get-ProcessOutput -FileName "msiexec.exe" -Args "$($UninstallString) /quiet /qn /norestart /log `"C:\IT\Log\$($item.displayname)_uninstall`""
            write-host "UNINSTALL TRIGGERED; SEE `"C:\IT\Log\$($item.displayname)_uninstall`""
            write-host "$($strLineSeparator)"
            $script:diag += "UNINSTALL TRIGGERED; SEE `"C:\IT\Log\$($item.displayname)_uninstall`"`r`n"
            $script:diag += "$($strLineSeparator)`r`n"
          } catch {
            $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
            logERR 3 "$($item.displayname) UNINSTALL UNSUCCESSFUL :" $err
          }
        } elseif ($item.UninstallString -notlike "*msiexec*") {       #EXE UNINSTALL
          try {
            $output = Get-ProcessOutput -FileName "$($item.UninstallString)" -Args "$($strReboot) `"C:\IT\Log\$($item.displayname)_uninstall`""
            write-host "UNINSTALL TRIGGERED; SEE `"C:\IT\Log\$($item.displayname)_uninstall`""
            write-host "$($strLineSeparator)"
            $script:diag += "UNINSTALL TRIGGERED; SEE `"C:\IT\Log\$($item.displayname)_uninstall`"`r`n"
            $script:diag += "$($strLineSeparator)`r`n"
          } catch {
            $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
            logERR 3 "$($item.displayname) UNINSTALL UNSUCCESSFUL :" $err
          }
        }
        #PARSE OUTPUT
        write-host "`t`t - StdOut : $($output.standardoutput) - StdErr : $($output.standarderror)"
        $script:diag += "`t`t - StdOut : $($output.standardoutput) - StdErr : $($output.standarderror)`r`n"
      } elseif (-not ($blnUninstall)) {
        write-host "REMOVAL DISABLED`r`n$($strLineSeparator)"
        $script:diag += "REMOVAL DISABLED`r`n$($strLineSeparator)`r`n"
      }
    }
  } elseif (($null -eq $avUninstall) -or ($avUninstall -eq "")) {     #TARGET AV NOT FOUND
    write-host "`r`n$($strLineSeparator)"
    write-host "NO $($env:strAV.toupper()) INSTALLATION DETECTED"
    write-host "$($strLineSeparator)"
    $script:diag += "`r`n$($strLineSeparator)`r`n"
    $script:diag += "NO $($env:strAV.toupper()) INSTALLATION DETECTED`r`n"
    $script:diag += "$($strLineSeparator)`r`n"
  }
  #REMOVAL VIA AV TOOLS
  write-host "BEGINNING REMOVAL VIA REMOVAL TOOLS :"
  write-host "$($strLineSeparator)"
  $script:diag += "BEGINNING REMOVAL VIA REMOVAL TOOLS :`r`n"
  $script:diag += "$($strLineSeparator)`r`n"
} elseif (($null -eq $env:strAV) -or ($env:strAV -eq "")) {           #A TARGET AV WAS NOT PASSED
  foreach ($av in $script:arrAV) {
    #REMOVAL VIA REGISTRY
    write-host "BEGINNING REMOVAL VIA REGISTRY :"
    write-host "$($strLineSeparator)"
    $script:diag += "BEGINNING REMOVAL VIA REGISTRY :`r`n"
    $script:diag += "$($strLineSeparator)`r`n"
    $avUninstall = $UninstallStrings | get-itemproperty | where {$_.displayname -like "*$($av)*"}
    if (($null -ne $avUninstall) -and ($avUninstall -ne "")) {        #TARGET AV FOUND
      #SET REBOOT STRINGS
      switch ($av.toupper()) {
        "MALWAREBYTES" {$strReboot = "/SILENT /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /L*v"}
        "MCAFEE" {$strReboot = "/SILENT /VERYSILENT /quiet /qn /norestart REBOOT=SUPPRESS /L*v"}
        "SOPHOS" {$strReboot = "/SILENT /VERYSILENT /quiet /qn /norestart REBOOT=SUPPRESS /L*v"}
      }
      foreach ($item in $avUninstall) {
        write-host "`r`n$($strLineSeparator)`r`nFOUND $($item.displayname):`r`nDescription : $($item.comments)`r`n$($item.UninstallString)"
        write-host "$($strLineSeparator)"
        $script:diag += "`r`n$($strLineSeparator)`r`nFOUND $($item.displayname):`r`nDescription : $($item.comments)`r`n$($item.UninstallString)`r`n"
        $script:diag += "$($strLineSeparator)`r`n"
        #AV REMOVAL
        if ($blnUninstall) {
          write-host "REMOVING $($item.displayname):"
          write-host "$($strLineSeparator)"
          $script:diag += "REMOVING $($item.displayname):`r`n"
          $script:diag += "$($strLineSeparator)`r`n"
          if ($item.UninstallString -like "*msiexec*") {              #MSI UNINSTALL
            try {
              $UninstallString = $item.UninstallString.split(" ")[1]
              $output = Get-ProcessOutput -FileName "msiexec.exe" -Args "$($UninstallString) /quiet /qn /norestart /log `"C:\IT\Log\$($item.displayname)_uninstall`""
              write-host "UNINSTALL TRIGGERED; SEE `"C:\IT\Log\$($item.displayname)_uninstall`""
              write-host "$($strLineSeparator)"
              $script:diag += "UNINSTALL TRIGGERED; SEE `"C:\IT\Log\$($item.displayname)_uninstall`"`r`n"
              $script:diag += "$($strLineSeparator)`r`n"
            } catch {
              $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
              logERR 3 "$($item.displayname) UNINSTALL UNSUCCESSFUL :" $err
            }
          } elseif ($item.UninstallString -notlike "*msiexec*") {     #EXE UNINSTALL
            try {
              $output = Get-ProcessOutput -FileName "$($item.UninstallString)" -Args "$($strReboot) `"C:\IT\Log\$($item.displayname)_uninstall`""
              write-host "UNINSTALL TRIGGERED; SEE `"C:\IT\Log\$($item.displayname)_uninstall`""
              write-host "$($strLineSeparator)"
              $script:diag += "UNINSTALL TRIGGERED; SEE `"C:\IT\Log\$($item.displayname)_uninstall`"`r`n"
              $script:diag += "$($strLineSeparator)`r`n"
            } catch {
              $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
              logERR 3 "$($item.displayname) UNINSTALL UNSUCCESSFUL :" $err
            }
          }
          #PARSE OUTPUT
          write-host "`t`t - StdOut : $($output.standardoutput) - StdErr : $($output.standarderror)"
          $script:diag += "`t`t - StdOut : $($output.standardoutput) - StdErr : $($output.standarderror)`r`n"
        } elseif (-not ($blnUninstall)) {
          write-host "REMOVAL DISABLED`r`n$($strLineSeparator)"
          $script:diag += "REMOVAL DISABLED`r`n$($strLineSeparator)`r`n"
        }
      }
    } elseif (($null -eq $avUninstall) -or ($avUninstall -eq "")) {   #TARGET AV NOT FOUND
      write-host "`r`n$($strLineSeparator)"
      write-host "NO $($av.toupper()) INSTALLATION DETECTED"
      write-host "$($strLineSeparator)"
      $script:diag += "`r`n$($strLineSeparator)`r`n"
      $script:diag += "NO $($av.toupper()) INSTALLATION DETECTED`r`n"
      $script:diag += "$($strLineSeparator)`r`n"
    }
    #REMOVAL VIA AV TOOLS
    write-host "BEGINNING REMOVAL VIA REMOVAL TOOLS :"
    write-host "$($strLineSeparator)"
    $script:diag += "BEGINNING REMOVAL VIA REMOVAL TOOLS :`r`n"
    $script:diag += "$($strLineSeparator)`r`n"
    #SET REMOVAL TOOL
    switch ($av.toupper()) {
      "AVAST" {$blnMatch = $false}
      {"AVD","AVDEFENDER","AV DEFENDER"} {
        $blnMatch = $true
        $strDir = "AVD_Latest_Removal_Tool"
        $strUninstall = @(
          "Uninstall_Tool_6.4.2.79.exe",
          "Uninstall_Tool_6.6.2.49.exe",
          "Uninstall_Tool_6.6.10.148.exe",
          "Uninstall_Tool_6.6.11.164.exe",
          "Uninstall_Tool_6.6.23.330.exe",
          "Uninstall_Tool_7.2.2.92.exe",
          "Uninstall_Tool_7.2.2.101.exe",
          "Uninstall_Tool_7.4.3.146.exe"
        )
        $strArgs = "/bruteForce /noWait /skipUnsafeCheck /unsafe"
      }
      "AVG" {$blnMatch = $false}
      "COMODO" {$blnMatch = $false}
      "CROWDSTRIKE" {
        $blnMatch = $true
        $strDir = "CrowdStrike"
        $strUninstall = @("csuninstalltool.exe")
        $strArgs = "/quiet"
      }
      "KASPERSKY" {$blnMatch = $false}
      {"MWB","MALWAREBYTES"} {$blnMatch = $false}
      "MCAFEE" {$blnMatch = $false}
      "NORTON" {
        $blnMatch = $true
        $strDir = "Norton"
        $strUninstall = @("NRnR.exe")
        $strArgs = "/cleanup /noeula /advancedoptions /norepair /noautofix /uninstall /admin /forceremove /automationmode"
      }
      "SOPHOS" {$blnMatch = $false}
      {"TREND MICRO","TRENDMICRO"} {$blnMatch = $false}
      "WEBROOT" {}
      default {$blnMatch = $false}
    }
  }
}
write-host "`r`n$($strLineSeparator)"
write-host "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss')) - All_AV_Removal COMPLETE"
write-host "$($strLineSeparator)"
$script:diag += "`r`n$($strLineSeparator)`r`n"
$script:diag += "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss')) - All_AV_Removal COMPLETE`r`n"
$script:diag += "$($strLineSeparator)`r`n"
#Stop script execution time calculation
StopClock
#WRITE LOGFILE
$script:diag | out-file $logPath
#DATTO OUTPUT
if ($script:blnWARN) {
  write-DRRMAlert "All_AV_Removal : Execution Failure : See Diagnostics"
  write-DRMMDiag "$($script:diag)"
  exit 1
} elseif (-not $script:blnWARN) {
  write-DRRMAlert "All_AV_Removal : Completed Execution"
  write-DRMMDiag "$($script:diag)"
  exit 0
}
#END SCRIPT
#------------