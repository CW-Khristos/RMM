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
    write-output "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($mill) Milliseconds`r`n"
  }

  function logERR ($intSTG, $strModule, $strErr) {
    $script:blnWARN = $true
    #CUSTOM ERROR CODES
    switch ($intSTG) {
      1 {                                                         #'ERRRET'=1 - NOT ENOUGH ARGUMENTS, END SCRIPT
        $script:blnFAIL = $true
        write-output "$($(get-date))`t - All_AV_Removal - NO ARGUMENTS PASSED, END SCRIPT`r`n"
        $script:diag += "`r`n$($(get-date))`t - All_AV_Removal - NO ARGUMENTS PASSED, END SCRIPT`r`n`r`n"
      }
      2 {                                                         #'ERRRET'=2 - INSTALL / IMPORT MODULE FAILURE, END SCRIPT
        $script:blnFAIL = $true
        write-output "$($(get-date))`t - All_AV_Removal - ($($strModule))`r`n$($strErr), END SCRIPT`r`n"
        $script:diag += "`r`n$($(get-date))`t - All_AV_Removal - ($($strModule))`r`n$($strErr), END SCRIPT`r`n`r`n"
      }
      default {                                                   #'ERRRET'=3+
        write-output "$($(get-date))`t - All_AV_Removal - $($strModule) : $($strErr)`r`n"
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
write-output "$($strLineSeparator)"
write-output "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss')) - EXECUTING All_AV_Removal"
write-output "$($strLineSeparator)`r`n"
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
  $avUninstall = $UninstallStrings | get-itemproperty | where {$_.displayname -like "*$($env:strAV)*"}
  if (($null -ne $avUninstall) -and ($avUninstall -ne "")) {          #TARGET AV FOUND
    #SET REBOOT STRINGS
    switch ($env:strAV.toupper()) {
      "MALWAREBYTES" {$strReboot = "/SILENT /VERYSILENT /SUPPRESSMSGBOXES /NORESTART"}
      "MCAFEE" {$strReboot = "/SILENT /VERYSILENT /quiet /qn /norestart REBOOT=SUPPRESS"}
      "SOPHOS" {$strReboot = "/SILENT /VERYSILENT /quiet /qn /norestart REBOOT=SUPPRESS"}
    }
    foreach ($item in $avUninstall) {
      write-output "`r`n$($strLineSeparator)`r`nFOUND $($item.displayname):`r`nDescription : $($item.comments)`r`n$($item.UninstallString)"
      write-output "$($strLineSeparator)"
      $script:diag += "`r`n$($strLineSeparator)`r`nFOUND $($item.displayname):`r`nDescription : $($item.comments)`r`n$($item.UninstallString)`r`n"
      $script:diag += "$($strLineSeparator)`r`n"
      #AV REMOVAL
      if ($blnUninstall) {
        write-output "REMOVING $($item.displayname):"
        write-output "$($strLineSeparator)"
        $script:diag += "REMOVING $($item.displayname):`r`n"
        $script:diag += "$($strLineSeparator)`r`n"
        if ($item.UninstallString -like "*msiexec*") {                #MSI UNINSTALL
          try {
            $UninstallString = $item.UninstallString.split(" ")[1]
            $output = Get-ProcessOutput -FileName "msiexec.exe" -Args "$($UninstallString) /quiet /qn /norestart /log `"C:\IT\Log\$($item.displayname)_uninstall`""
            write-output "UNINSTALL TRIGGERED; SEE `"C:\IT\Log\$($item.displayname)_uninstall`""
            write-output "$($strLineSeparator)"
            $script:diag += "UNINSTALL TRIGGERED; SEE `"C:\IT\Log\$($item.displayname)_uninstall`"`r`n"
            $script:diag += "$($strLineSeparator)`r`n"
          } catch {
            $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
            logERR 3 "$($item.displayname) UNINSTALL UNSUCCESSFUL :" $err
          }
        } elseif ($item.UninstallString -notlike "*msiexec*") {       #EXE UNINSTALL
          try {
            $output = Get-ProcessOutput -FileName "$($item.UninstallString)" -Args "$($strReboot)"
          } catch {
            $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
            logERR 3 "$($item.displayname) UNINSTALL UNSUCCESSFUL :" $err
          }
        }
        #PARSE OUTPUT
        write-output "`t`t - StdOut : $($output.standardoutput) - StdErr : $($output.standarderror)"
        $script:diag += "`t`t - StdOut : $($output.standardoutput) - StdErr : $($output.standarderror)`r`n"
      } elseif (-not ($blnUninstall)) {
        write-output "REMOVAL DISABLED`r`n$($strLineSeparator)"
        $script:diag += "REMOVAL DISABLED`r`n$($strLineSeparator)`r`n"
      }
    }
  } elseif (($null -eq $avUninstall) -or ($avUninstall -eq "")) {     #TARGET AV NOT FOUND
    write-output "`r`n$($strLineSeparator)"
    write-output "NO $($env:strAV.toupper()) INSTALLATION DETECTED"
    write-output "$($strLineSeparator)"
    $script:diag += "`r`n$($strLineSeparator)`r`n"
    $script:diag += "NO $($env:strAV.toupper()) INSTALLATION DETECTED`r`n"
    $script:diag += "$($strLineSeparator)`r`n"
  }
} elseif (($null -eq $env:strAV) -or ($env:strAV -eq "")) {           #A TARGET AV WAS NOT PASSED
  foreach ($av in $script:arrAV) {
    $avUninstall = $UninstallStrings | get-itemproperty | where {$_.displayname -like "*$($av)*"}
    if (($null -ne $avUninstall) -and ($avUninstall -ne "")) {        #TARGET AV FOUND
      #SET REBOOT STRINGS
      switch ($av.toupper()) {
        "MALWAREBYTES" {$strReboot = "/SILENT /VERYSILENT /SUPPRESSMSGBOXES /NORESTART"}
        "MCAFEE" {$strReboot = "/SILENT /VERYSILENT /quiet /qn /norestart REBOOT=SUPPRESS"}
        "SOPHOS" {$strReboot = "/SILENT /VERYSILENT /quiet /qn /norestart REBOOT=SUPPRESS"}
      }
      foreach ($item in $avUninstall) {
        write-output "`r`n$($strLineSeparator)`r`nFOUND $($item.displayname):`r`nDescription : $($item.comments)`r`n$($item.UninstallString)"
        write-output "$($strLineSeparator)"
        $script:diag += "`r`n$($strLineSeparator)`r`nFOUND $($item.displayname):`r`nDescription : $($item.comments)`r`n$($item.UninstallString)`r`n"
        $script:diag += "$($strLineSeparator)`r`n"
        #AV REMOVAL
        if ($blnUninstall) {
          write-output "REMOVING $($item.displayname):"
          write-output "$($strLineSeparator)"
          $script:diag += "REMOVING $($item.displayname):`r`n"
          $script:diag += "$($strLineSeparator)`r`n"
          if ($item.UninstallString -like "*msiexec*") {              #MSI UNINSTALL
            try {
              $UninstallString = $item.UninstallString.split(" ")[1]
              $output = Get-ProcessOutput -FileName "msiexec.exe" -Args "$($UninstallString) /quiet /qn /norestart /log `"C:\IT\Log\$($item.displayname)_uninstall`""
              write-output "UNINSTALL TRIGGERED; SEE `"C:\IT\Log\$($item.displayname)_uninstall`""
              write-output "$($strLineSeparator)"
              $script:diag += "UNINSTALL TRIGGERED; SEE `"C:\IT\Log\$($item.displayname)_uninstall`"`r`n"
              $script:diag += "$($strLineSeparator)`r`n"
            } catch {
              $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
              logERR 3 "$($item.displayname) UNINSTALL UNSUCCESSFUL :" $err
            }
          } elseif ($item.UninstallString -notlike "*msiexec*") {     #EXE UNINSTALL
            try {
              $output = Get-ProcessOutput -FileName "$($item.UninstallString)" -Args "$($strReboot)"
            } catch {
              $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
              logERR 3 "$($item.displayname) UNINSTALL UNSUCCESSFUL :" $err
            }
          }
          #PARSE OUTPUT
          write-output "`t`t - StdOut : $($output.standardoutput) - StdErr : $($output.standarderror)"
          $script:diag += "`t`t - StdOut : $($output.standardoutput) - StdErr : $($output.standarderror)`r`n"
        } elseif (-not ($blnUninstall)) {
          write-output "REMOVAL DISABLED`r`n$($strLineSeparator)"
          $script:diag += "REMOVAL DISABLED`r`n$($strLineSeparator)`r`n"
        }
      }
    } elseif (($null -eq $avUninstall) -or ($avUninstall -eq "")) {   #TARGET AV NOT FOUND
      write-output "`r`n$($strLineSeparator)"
      write-output "NO $($av.toupper()) INSTALLATION DETECTED"
      write-output "$($strLineSeparator)"
      $script:diag += "`r`n$($strLineSeparator)`r`n"
      $script:diag += "NO $($av.toupper()) INSTALLATION DETECTED`r`n"
      $script:diag += "$($strLineSeparator)`r`n"
    }
  }
}
write-output "`r`n$($strLineSeparator)"
write-output "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss')) - All_AV_Removal COMPLETE"
write-output "$($strLineSeparator)"
$script:diag += "`r`n$($strLineSeparator)`r`n"
$script:diag += "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss')) - All_AV_Removal COMPLETE`r`n"
$script:diag += "$($strLineSeparator)`r`n"
#Stop script execution time calculation
StopClock
#WRITE LOGFILE
$script:diag | out-file $logPath
#DATTO OUTPUT
if ($script:blnWARN) {
  write-DRMMAlert "All_AV_Removal : Execution Failure : See Diagnostics"
  write-DRMMDiag "$($script:diag)"
  exit 1
} elseif (-not $script:blnWARN) {
  write-DRMMAlert "All_AV_Removal : Completed Execution"
  write-DRMMDiag "$($script:diag)"
  exit 0
}
#END SCRIPT
#------------