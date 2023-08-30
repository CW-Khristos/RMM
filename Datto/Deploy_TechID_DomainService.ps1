#REGION ----- DECLARATIONS ----
  $script:diag      = $null
  $script:blnWARN   = $false
  $script:blnFAIL   = $false
  $strLineSeparator = "---------"
  $script:logPath   = "C:\IT\Log\Deploy TechID_DomainService"
#ENDREGION ----- DECLARATIONS ----

#REGION ----- FUNCTIONS ----
  function write-DRMMDiag ($messages) {
    write-output  "<-Start Diagnostic->"
    foreach ($message in $messages) {$message}
    write-output "<-End Diagnostic->"
  } ## write-DRMMDiag
  
  function write-DRRMAlert ($message) {
    write-output "<-Start Result->"
    write-output "Alert=$($message)"
    write-output "<-End Result->"
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

  function logERR ($intSTG, $strModule, $strErr) {
    $script:blnWARN = $true
    #CUSTOM ERROR CODES
    switch ($intSTG) {
      1 {                                                         #'ERRRET'=1 - NOT ENOUGH ARGUMENTS, END SCRIPT
        $script:blnFAIL = $true
        $script:diag += "`r`n$($(get-date))`t - Deploy TechID_DomainService - NO ARGUMENTS PASSED, END SCRIPT`r`n`r`n"
        write-output "$($(get-date))`t - Deploy TechID_DomainService - NO ARGUMENTS PASSED, END SCRIPT`r`n"
      }
      2 {                                                         #'ERRRET'=2 - INSTALL / IMPORT MODULE FAILURE, END SCRIPT
        $script:blnFAIL = $true
        $script:diag += "`r`n$($(get-date))`t - Deploy TechID_DomainService - ($($strModule))`r`n$($strErr), END SCRIPT`r`n`r`n"
        write-output "$($(get-date))`t - Deploy TechID_DomainService - ($($strModule))`r`n$($strErr), END SCRIPT`r`n"
      }
      default {                                                   #'ERRRET'=3+
        $script:blnWARN = $true
        $script:diag += "`r`n$($(get-date))`t - Deploy TechID_DomainService - $($strModule) : $($strErr)`r`n`r`n"
        write-output "$($(get-date))`t - Deploy TechID_DomainService - $($strModule) : $($strErr)`r`n"
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
#ENDREGION ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
clear-host
#Start script execution time calculation
$ScrptStartTime = (Get-Date).ToString('dd-MM-yyyy hh:mm:ss')
$script:sw = [Diagnostics.Stopwatch]::StartNew()
#CHECK 'PERSISTENT' FOLDERS
if (-not (test-path -path "C:\temp")) {
  new-item -path "C:\temp" -itemtype directory -force
}
if (-not (test-path -path "C:\IT")) {
  new-item -path "C:\IT" -itemtype directory -force
}
if (-not (test-path -path "C:\IT\Log")) {
  new-item -path "C:\IT\Log" -itemtype directory -force
}
if (-not (test-path -path "C:\IT\Scripts")) {
  new-item -path "C:\IT\Scripts" -itemtype directory -force
}
if (-not (test-path -path "$($env:strDeploy)")) {
  new-item -path "$($env:strDeploy)" -itemtype directory -force
}
if (($null -eq $env:strGUID) -or ($env:strGUID -eq "")) {
  logERR 2 "DEPLOY" "CLIENT GUID NOT SET"
}
if ($script:blnFAIL) {
  $script:blnWARN = $true
} elseif (-not ($script:blnFAIL)) {
  write-output "$($strLineSeparator)`r`nCHECKING FOR DomainService"
  $script:diag += "$($strLineSeparator)`r`nCHECKING FOR DomainService`r`n"
  $service = get-service -name "RuffianDomainService"
  if ($service) {
    try {
      write-output "$($strLineSeparator)`r`nSTOPPING DomainService"
      $script:diag += "$($strLineSeparator)`r`nSTOPPING DomainService`r`n"
      stop-service -name "RuffianDomainService"
      write-output "$($strLineSeparator)`r`nSTOPPED DomainService`r`nREMOVING FILES"
      $script:diag += "$($strLineSeparator)`r`nSTOPPED DomainService`r`nREMOVING FILES`r`n"
      get-childitem "$($env:strDeploy)" | remove-item -force -erroraction continue
    } catch {
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
      logERR 3 "INSTALL" $err
    }
  }
  write-output "$($strLineSeparator)`r`nDEPLOYING DomainService"
  $script:diag += "$($strLineSeparator)`r`nDEPLOYING DomainService`r`n"
  move-item DomainService_v3.164x64.zip "$($env:strDeploy)"
  $shell = New-Object -ComObject Shell.Application
  $zip = $shell.Namespace("$($env:strDeploy)\DomainService_v3.164x64.zip")
  $items = $zip.items()
  $shell.Namespace("$($env:strDeploy)").CopyHere($items, 1556)
  $script:diag += "DomainService EXTRACTED TO '$($env:strDeploy)'`r`n$($strLineSeparator)`r`n"
  write-output "DomainService EXTRACTED TO '$($env:strDeploy)'`r`n$($strLineSeparator)"
  remove-item "$($env:strDeploy)\DomainService_v3.164x64.zip"
  $strEXE = "$($env:strDeploy)\DomainService.exe"
  #INSTALL
  try {
    write-output "$($strLineSeparator)`r`nINSTALLING DomainService`r`n`tCMD : $($strEXE) install"
    $script:diag += "$($strLineSeparator)`r`nINSTALLING DomainService`r`n`tCMD : $($strEXE) install`r`n"
    $output = Get-ProcessOutput -filename "$($strEXE)" -args "install"
    $script:diag += "`t - StdOut : $($output.standardoutput)`r`n`t - StdErr : $($output.standarderror)`r`n"
    write-output "`t - StdOut : $($output.standardoutput)`r`n`t - StdErr : $($output.standarderror)"
  } catch {
    $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
    logERR 3 "INSTALL" $err
  }
  #SET GUID
  try {
    write-output "$($strLineSeparator)`r`nSETTING CLIENT GUID`r`n`tCMD : $($strEXE) clientguid $($env:strGUID)"
    $script:diag += "$($strLineSeparator)`r`nSETTING CLIENT GUID`r`n`tCMD : $($strEXE) clientguid $($env:strGUID)`r`n"
    $output = Get-ProcessOutput -filename "$($strEXE)" -args "clientguid $($env:strGUID)"
    $script:diag += "`t - StdOut : $($output.standardoutput)`r`n`t - StdErr : $($output.standarderror)`r`n"
    write-output "`t - StdOut : $($output.standardoutput)`r`n`t - StdErr : $($output.standarderror)"
  } catch {
    $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
    logERR 4 "SET GUID" $err
  }
  #SET OU
  try {
    write-output "$($strLineSeparator)`r`nSETTING TECH ACCOUNT OU`r`n`tCMD : $($strEXE) ou `"$($env:strOU)`""
    $script:diag += "$($strLineSeparator)`r`nSETTING TECH ACCOUNT OU`r`n`tCMD : $($strEXE) ou `"$($env:strOU)`"`r`n"
    $output = Get-ProcessOutput -filename "$($strEXE)" -args "ou `"$($env:strOU)`""
    $script:diag += "`t - StdOut : $($output.standardoutput)`r`n`t - StdErr : $($output.standarderror)`r`n"
    write-output "`t - StdOut : $($output.standardoutput)`r`n`t - StdErr : $($output.standarderror)"
  } catch {
    $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
    logERR 5 "SET OU" $err
  }
  #SET TECH NAME
  try {
    write-output "$($strLineSeparator)`r`nSETTING TECH ACCOUNT NAME`r`n`tCMD : $($strEXE) username `"{firstinitial}{last}.IPM`""
    $script:diag += "$($strLineSeparator)`r`nSETTING TECH ACCOUNT NAME`r`n`tCMD : $($strEXE) username `"{firstinitial}{last}.IPM`"`r`n"
    $output = Get-ProcessOutput -filename "$($strEXE)" -args "username `"{firstinitial}{last}.IPM`""
    $script:diag += "`t - StdOut : $($output.standardoutput)`r`n`t - StdErr : $($output.standarderror)`r`n"
    write-output "`t - StdOut : $($output.standardoutput)`r`n`t - StdErr : $($output.standarderror)"
  } catch {
    $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
    logERR 6 "SET TECH NAME" $err
  }
  #SET DISPLAY NAME
  try {
    if (($null -ne $env:strDName) -and ($env:strDName -ne "")) {
      $displayname = $env:strDName
    } elseif (($null -eq $env:strDName) -or ($env:strDName -eq "")) {
      $displayname = "{firstinitial}{last}.IPM"
    }
    write-output "$($strLineSeparator)`r`nSETTING DISPLAY NAME`r`n`tCMD : $($strEXE) displayname `"$($displayname)`""
    $script:diag += "$($strLineSeparator)`r`nSETTING DISPLAY NAME`r`n`tCMD : $($strEXE) displayname `"$($displayname)`"`r`n"
    $output = Get-ProcessOutput -filename "$($strEXE)" -args "displayname `"$($displayname)`""
    $script:diag += "`t - StdOut : $($output.standardoutput)`r`n`t - StdErr : $($output.standarderror)`r`n"
    write-output "`t - StdOut : $($output.standardoutput)`r`n`t - StdErr : $($output.standarderror)"
  } catch {
    $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
    logERR 7 "SET DISPLAY NAME" $err
  }
  #SET ACCOUNT DESCRIPTION
  try {
    write-output "$($strLineSeparator)`r`nSETTING ACCOUNT DESCRIPTION`r`n`tCMD : $($strEXE) accountdescription `"IPM TechClient Admin`""
    $script:diag += "$($strLineSeparator)`r`nSETTING ACCOUNT DESCRIPTION`r`n`tCMD : $($strEXE) accountdescription `"IPM TechClient Admin`"`r`n"
    $output = Get-ProcessOutput -filename "$($strEXE)" -args "accountdescription `"IPM TechClient Admin`""
    $script:diag += "`t - StdOut : $($output.standardoutput)`r`n`t - StdErr : $($output.standarderror)`r`n"
    write-output "`t - StdOut : $($output.standardoutput)`r`n`t - StdErr : $($output.standarderror)"
  } catch {
    $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
    logERR 8 "SET ACCOUNT DESCRIPTION" $err
  }
  #SET HIDELOGONNAME
  try {
    write-output "$($strLineSeparator)`r`nSETTING HIDE TECH LOGONS`r`n`tCMD : $($strEXE) hideonloginscreen"
    $script:diag += "$($strLineSeparator)`r`nSETTING HIDE TECH LOGONS`r`n`tCMD : $($strEXE) hideonloginscreen`r`n"
    $output = Get-ProcessOutput -filename "$($strEXE)" -args "hideonloginscreen"
    $script:diag += "`t - StdOut : $($output.standardoutput)`r`n`t - StdErr : $($output.standarderror)`r`n"
    write-output "`t - StdOut : $($output.standardoutput)`r`n`t - StdErr : $($output.standarderror)"
  } catch {
    $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
    logERR 9 "SET HIDELOGONNAME" $err
  }
  #SET FRIENDLY NAME
  try {
    if (($null -ne $env:strFName) -and ($env:strFName -ne "")) {
      $friendlyname = $env:strFName
    } elseif (($null -eq $env:strFName) -or ($env:strFName -eq "")) {
      $friendlyname = $env:CS_PROFILE_NAME
    }
    write-output "$($strLineSeparator)`r`nSETTING FRIENDLY NAME`r`n`tCMD : $($strEXE) friendlyname `"$($friendlyname)`""
    $script:diag += "$($strLineSeparator)`r`nSETTING FRIENDLY NAME`r`n`tCMD : $($strEXE) friendlyname `"$($friendlyname)`"`r`n"
    $output = Get-ProcessOutput -filename "$($strEXE)" -args "friendlyname `"$($friendlyname)`""
    $script:diag += "`t - StdOut : $($output.standardoutput)`r`n`t - StdErr : $($output.standarderror)`r`n"
    write-output "`t - StdOut : $($output.standardoutput)`r`n`t - StdErr : $($output.standarderror)"
  } catch {
    $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
    logERR 10 "SET FRIENDLY NAME" $err
  }
  #SET RMM NAME
  try {
    if (($null -ne $env:strRName) -and ($env:strRName -ne "")) {
      $rmmname = $env:strRName
    } elseif (($null -eq $env:strRName) -or ($env:strRName -eq "")) {
      $rmmname = $env:CS_PROFILE_NAME
    }
    write-output "$($strLineSeparator)`r`nSETTING RMM NAME`r`n`tCMD : $($strEXE) rmmname `"$($rmmname)`""
    $script:diag += "$($strLineSeparator)`r`nSETTING RMM NAME`r`n`tCMD : $($strEXE) rmmname `"$($rmmname)`"`r`n"
    $output = Get-ProcessOutput -filename "$($strEXE)" -args "rmmname `"$($rmmname)`""
    $script:diag += "`t - StdOut : $($output.standardoutput)`r`n`t - StdErr : $($output.standarderror)`r`n"
    write-output "`t - StdOut : $($output.standardoutput)`r`n`t - StdErr : $($output.standarderror)"
  } catch {
    $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
    logERR 11 "SET RMM NAME" $err
  }
  #START
  try {
    write-output "$($strLineSeparator)`r`nSTARTING DomainService"
    $script:diag += "$($strLineSeparator)`r`nSTARTING DomainService`r`n"
    $output = Get-ProcessOutput -filename "$($strEXE)" -args "start"
    $script:diag += "`t - StdOut : $($output.standardoutput)`r`n`t - StdErr : $($output.standarderror)`r`n"
    write-output "`t - StdOut : $($output.standardoutput)`r`n`t - StdErr : $($output.standarderror)"
  } catch {
    $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
    logERR 12 "START" $err
  }
}
#Stop script execution time calculation
StopClock
#WRITE LOGFILE
$script:diag | out-file $logPath
#DATTO OUTPUT
if ($script:blnWARN) {
  write-DRRMAlert "Deploy TechID_DomainService : Execution Failure : See Diagnostics"
  write-DRMMDiag "$($script:diag)"
  exit 1
} elseif (-not $script:blnWARN) {
  write-DRRMAlert "Deploy TechID_DomainService : Completed Execution"
  write-DRMMDiag "$($script:diag)"
  exit 0
}
#END SCRIPT
#------------