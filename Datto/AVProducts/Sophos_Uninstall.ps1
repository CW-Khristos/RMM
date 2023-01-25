#region ----- DECLARATIONS ----
  $script:diag      = $null
  $script:blnWARN   = $false
  $script:blnBREAK  = $false
  $strLineSeparator = "---------"
  $colServices      = @(
    "SAVService",
    "Sophos AutoUpdate Service",
    "Sophos Device Encryption Service",
    "Sophos Endpoint Defense Service",
    "Sophos File Scanner Service",
    "Sophos Health Service",
    "Sophos Live Query",
    "Sophos Managed Threat Response",
    "Sophos MCS Agent",
    "Sophos MCS Client",
    "SntpService",
    "Sophos System Protection Service"
  )
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

  function logERR($intSTG, $strErr) {
    $script:blnWARN = $true
    #CUSTOM ERROR CODES
    switch ($intSTG) {
      1 {                                                                             #'ERRRET'=1 - ERROR DELETING FILE / FOLDER
        $script:diag += "$($strLineSeparator)`r`n$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - Uninstall_Sophos - ERROR DELETING FILE / FOLDER`r`n$($strErr)`r`n$($strLineSeparator)`r`n`r`n"
        write-host "$($strLineSeparator)`r`n$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - Uninstall_Sophos - ERROR DELETING FILE / FOLDER`r`n$($strErr)`r`n$($strLineSeparator)`r`n"
      }
      2 {                                                                             #'ERRRET'=2 - NOT ENOUGH ARGUMENTS, END SCRIPT
        $script:diag += "$($strLineSeparator)`r`n$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - Uninstall_Sophos - NO ARGUMENTS PASSED, END SCRIPT`r`n$($strErr)`r`n$($strLineSeparator)`r`n`r`n"
        write-host "$($strLineSeparator)`r`n$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - Uninstall_Sophos - NO ARGUMENTS PASSED, END SCRIPT`r`n$($strErr)`r`n$($strLineSeparator)`r`n"
      }
      default {                                                                       #'ERRRET'=3+
        write-host "$($strLineSeparator)`r`n$((get-date).ToString('dd-MM-yyyy hh:mm:ss'))`t - Uninstall_Sophos - $($strErr)`r`n$($strLineSeparator)`r`n"
        $script:diag += "$($strLineSeparator)`r`n$((get-date).ToString('dd-MM-yyyy hh:mm:ss'))`t - Uninstall_Sophos - $($strErr)`r`n$($strLineSeparator)`r`n`r`n"
      }
    }
  }

  function StopService($service) {
    try {
      write-host "STOPPING '$($service)'"
      $script:diag += "STOPPING '$($service)'`r`n"
      $result = stop-service -name "$($service)" -force -erroraction stop
      write-host "$($result)"
      $script:diag += "$($result)`r`n"
    } catch {
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
      logERR 3 $err
    }
  }

  function RegUninstall($regitem) {
    write-host "$($regitem.displayname):"
    $script:diag += "$($regitem.displayname):`r`n"
    if (($null -ne $regitem.UninstallString) -and ($regitem.UninstallString -ne "")) {
      write-host "`t - UNINSTALLING $($regitem.displayname):"
      $script:diag += "`t - UNINSTALLING $($regitem.displayname):`r`n"
      if ($regitem.UninstallString -like "*msiexec*") {
        try {
          $regitem.UninstallString = $regitem.UninstallString.split(" ")[1]
          write-host "`t`t - USING MSIEXEC : $($regitem.UninstallString):"
          $script:diag += "`t`t - USING MSIEXEC : $($regitem.UninstallString):`r`n"
          $output = Get-ProcessOutput -FileName "msiexec.exe" -Args "$($regitem.UninstallString) /quiet /qn /norestart REBOOT=ReallySuppress"
        } catch {
          logERR 3 $err
        }
      } elseif ($regitem.UninstallString -notlike "*msiexec*") {
        try {
          write-host "`t`t - USING EXE : $($regitem.UninstallString):"
          $script:diag += "`t`t - USING EXE : $($regitem.UninstallString):`r`n"
          $output = Get-ProcessOutput -FileName "$($regitem.UninstallString)" -Args "/quiet"
        } catch {
          logERR 3 $err
        }
      }
      #PARSE SMARTCTL OUTPUT LINE BY LINE
      $lines = $output.StandardOutput.split("`r`n", [StringSplitOptions]::RemoveEmptyEntries)
      $lines
    } else {
      write-host "$($regitem.displayname) : No Uninstall String`r`n"
      $script:diag += "$($regitem.displayname) : No Uninstall String`r`n`r`n"
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
#STOP SERVICES
write-host "$($strLineSeparator)`r`nSTOPPING SOPHOS SERVICES`r`n$($strLineSeparator)"
$script:diag += "$($strLineSeparator)`r`nSTOPPING SOPHOS SERVICES`r`n$($strLineSeparator)`r`n"
foreach ($service in $colServices) {StopService $service}
write-host "$($strLineSeparator)`r`nCOMPLETED STOPPING SOPHOS SERVICES`r`n$($strLineSeparator)"
$script:diag += "$($strLineSeparator)`r`nCOMPLETED STOPPING SOPHOS SERVICES`r`n$($strLineSeparator)`r`n"
#PROCESS UNINSTALLS
write-host "$($strLineSeparator)`r`nPROCESSING SOPHOS EXE UNINSTALLS`r`n$($strLineSeparator)"
$script:diag += "$($strLineSeparator)`r`nPROCESSING SOPHOS EXE UNINSTALLS`r`n$($strLineSeparator)`r`n"
try {
  write-host "$($strLineSeparator)`r`nTRYING 'C:\Program Files\Sophos\Sophos Endpoint Agent\uninstallcli.exe'"
  $script:diag += "$($strLineSeparator)`r`nTRYING 'C:\Program Files\Sophos\Sophos Endpoint Agent\uninstallcli.exe'`r`n"
  $output = Get-ProcessOutput -FileName "C:\Program Files\Sophos\Sophos Endpoint Agent\uninstallcli.exe" -Args "--quiet"
  #PARSE OUTPUT LINE BY LINE
  $lines = $output.StandardOutput.split("`r`n", [StringSplitOptions]::RemoveEmptyEntries)
  $lines
} catch {
  $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
  logERR 3 $err
}
try {
  write-host "$($strLineSeparator)`r`nTRYING 'C:\Program Files\Sophos\Sophos Endpoint Agent\uninstallgui.exe'"
  $script:diag += "$($strLineSeparator)`r`nTRYING 'C:\Program Files\Sophos\Sophos Endpoint Agent\uninstallgui.exe'`r`n"
  $output = Get-ProcessOutput -FileName "C:\Program Files\Sophos\Sophos Endpoint Agent\uninstallgui.exe" -Args "--quiet"
  #PARSE OUTPUT LINE BY LINE
  $lines = $output.StandardOutput.split("`r`n", [StringSplitOptions]::RemoveEmptyEntries)
  $lines
} catch {
  $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
  logERR 3 $err
}
try {
  write-host "$($strLineSeparator)`r`nTRYING 'C:\Program Files\Sophos\Sophos Endpoint Agent\SophosUninstall.exe'"
  $script:diag += "$($strLineSeparator)`r`nTRYING 'C:\Program Files\Sophos\Sophos Endpoint Agent\SophosUninstall.exe'`r`n"
  $output = Get-ProcessOutput -FileName "C:\Program Files\Sophos\Sophos Endpoint Agent\SophosUninstall.exe" -Args "--quiet"
  #PARSE OUTPUT LINE BY LINE
  $lines = $output.StandardOutput.split("`r`n", [StringSplitOptions]::RemoveEmptyEntries)
  $lines
} catch {
  $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
  logERR 3 $err
}
write-host "$($strLineSeparator)`r`nCOMPLETED SOPHOS EXE UNINSTALLS`r`n$($strLineSeparator)"
$script:diag += "$($strLineSeparator)`r`nCOMPLETED SOPHOS EXE UNINSTALLS`r`n$($strLineSeparator)`r`n"
write-host "$($strLineSeparator)`r`nPROCESSING SOPHOS REG UNINSTALLS`r`n$($strLineSeparator)"
$script:diag += "$($strLineSeparator)`r`nPROCESSING SOPHOS REG UNINSTALLS`r`n$($strLineSeparator)`r`n"
#RETRIEVE UNINSTALL STRINGS FROM REGISTRY
$key32 = get-itemproperty -path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" -erroraction stop | where {$_.DisplayName -like "*Sophos*"}
$key64 = get-itemproperty -path "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -erroraction stop | where {$_.DisplayName -like "*Sophos*"}
#LOOP THROUGH EACH UNINSTALL STRING
try {
  foreach ($string32 in $key32) {
    write-host "$($string32)`r`n$($strLineSeparator)`r`n"
    RegUninstall $string32
  }
  foreach ($string64 in $key64) {
    write-host $string64
    RegUninstall $string64
  }
} catch {
  $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
  logERR 3 $err
}
write-host "$($strLineSeparator)`r`nCOMPLETED SOPHOS REG UNINSTALLS`r`n$($strLineSeparator)"
$script:diag += "$($strLineSeparator)`r`nCOMPLETED SOPHOS REG UNINSTALLS`r`n$($strLineSeparator)`r`n"
write-host "$($strLineSeparator)`r`nPROCESSING FINAL EXE UNINSTALLS`r`n$($strLineSeparator)"
$script:diag += "$($strLineSeparator)`r`nPROCESSING FINAL EXE UNINSTALLS`r`n$($strLineSeparator)`r`n"
#UNINSTALL HITMAN PRO
try {
  write-host "$($strLineSeparator)`r`nTRYING `"C:\Program Files (x86)\HitmanPro.Alert\Uninstall.exe`" -Args `"--quiet`""
  $script:diag += "$($strLineSeparator)`r`nTRYING `"C:\Program Files (x86)\HitmanPro.Alert\Uninstall.exe`" -Args `"--quiet`"`r`n"
  $output = Get-ProcessOutput -FileName "C:\Program Files (x86)\HitmanPro.Alert\Uninstall.exe" -Args "--quiet"
  #PARSE OUTPUT LINE BY LINE
  $lines = $output.StandardOutput.split("`r`n", [StringSplitOptions]::RemoveEmptyEntries)
  $lines
} catch {
  $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
  logERR 3 $err
}
try {
  write-host "$($strLineSeparator)`r`nTRYING `"C:\Program Files (x86)\HitmanPro.Alert\hmpalert.exe`" -Args `"/uninstall /quiet`""
  $script:diag += "$($strLineSeparator)`r`nTRYING `"C:\Program Files (x86)\HitmanPro.Alert\hmpalert.exe`" -Args `"/uninstall /quiet`"`r`n"
  $output = Get-ProcessOutput -FileName "C:\Program Files (x86)\HitmanPro.Alert\hmpalert.exe" -Args "/uninstall /quiet"
  #PARSE OUTPUT LINE BY LINE
  $lines = $output.StandardOutput.split("`r`n", [StringSplitOptions]::RemoveEmptyEntries)
  $lines
} catch {
  $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
  logERR 3 $err
}
write-host "$($strLineSeparator)`r`nCOMPLETED FINAL EXE UNINSTALLS`r`n$($strLineSeparator)"
$script:diag += "$($strLineSeparator)`r`nCOMPLETED FINAL EXE UNINSTALLS`r`n$($strLineSeparator)`r`n"
#Stop script execution time calculation
StopClock
#DATTO OUTPUT
if ($script:blnBREAK) {
  write-DRMMAlert "Uninstall_Sophos : Execution Failed : See Diagnostics"
  write-DRMMDiag "$($script:diag)"
  exit 1
} elseif (-not $script:blnBREAK) {
  if ($script:blnWARN) {
    write-DRMMAlert "Uninstall_Sophos : Warning : See Diagnostics"
    write-DRMMDiag "$($script:diag)"
    exit 1
  } elseif (-not $script:blnWARN) {
    write-DRMMAlert "Uninstall_Sophos : Completed Execution"
    write-DRMMDiag "$($script:diag)"
    exit 0
  }
}
#END SCRIPT
#------------