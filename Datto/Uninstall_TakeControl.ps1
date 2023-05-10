$script:diag      = $null
$script:blnWARN   = $false
$script:blnBREAK  = $false
$strLineSeparator = "-------------------"
$strPD            = "$env:ProgramData"
$strPF            = "$env:ProgramFiles"
$strPF86          = "${env:ProgramFiles(x86)}"

  function Get-ProcessOutput {
    Param (
      [Parameter(Mandatory=$true)]$FileName,
      $Args
    )
    logERR 3 "Get-ProcessOutput" " - RUNNING : $($FileName) : $($Args)"
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
    $errTime = (get-date -format "yyyy-MM-dd HH:mm:ss").ToString()
    #CUSTOM ERROR CODES
    switch ($intSTG) {
      1 {                                                         #'ERRRET'=1 - NOT ENOUGH ARGUMENTS, END SCRIPT
        $script:blnBREAK = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($errTime) - Uninstall_TakeControl - NO ARGUMENTS PASSED, END SCRIPT`r`n`r`n"
        write-host "$($strLineSeparator)`r`n$($(get-date)) - Uninstall_TakeControl - NO ARGUMENTS PASSED, END SCRIPT`r`n" -foregroundcolor red
      }
      2 {                                                         #'ERRRET'=2 - INSTALL / IMPORT MODULE FAILURE, END SCRIPT
        $script:blnBREAK = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($errTime) - Uninstall_TakeControl - ($($strModule)) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n"
        write-host "$($strLineSeparator)`r`n$($(get-date)) - Uninstall_TakeControl - ($($strModule)) :" -foregroundcolor red
        write-host "$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n" -foregroundcolor red
      }
      3 {                                                         #'ERRRET'=3
        $script:blnWARN = $false
        $script:diag += "`r`n$($strLineSeparator)`r`n$($errTime) - Uninstall_TakeControl - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
        write-host "$($strLineSeparator)`r`n$($(get-date)) - Uninstall_TakeControl - $($strModule) :" -foregroundcolor yellow
        write-host "$($strLineSeparator)`r`n`t$($strErr)" -foregroundcolor yellow
      }
      default {                                                   #'ERRRET'=4+
        $script:blnBREAK = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($errTime) - Uninstall_TakeControl - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
        write-host "$($strLineSeparator)`r`n$($(get-date)) - Uninstall_TakeControl - $($strModule) :" -foregroundcolor yellow
        write-host "$($strLineSeparator)`r`n`t$($strErr)" -foregroundcolor red
      }
    }
  }
clear-host
#STOP TAKE CONTROL SERVICES
logERR 3 "Services" " - STOPPING TAKE CONTROL SERVICES`r`n$($strLineSeparator)"
$out = Get-ProcessOutput -filename "C:\Windows\System32\sc.exe" -args "stop BASupportExpressSrvcUpdater"
logERR 3 "Services" "STDOUT :`r`n`t$($out.standardoutput)`r`n`tSTDERR :`r`n`t$($out.standarderror)`r`n$($strLineSeparator)"
$out = Get-ProcessOutput -filename "C:\Windows\System32\sc.exe" -args "stop BASupportExpressStandaloneService"
logERR 3 "Services" "STDOUT :`r`n`t$($out.standardoutput)`r`n`tSTDERR :`r`n`t$($out.standarderror)`r`n$($strLineSeparator)"
write-host "Done`r`n$($strLineSeparator)"
$script:diag += "`r`nDone`r`n$($strLineSeparator)`r`n"
#KILL SERVICE PROCESSES
logERR 3 "Processes" " - STOPPING TAKE CONTROL PROCESSES`r`n$($strLineSeparator)"
$out = Get-ProcessOutput -filename "C:\Windows\System32\taskkill.exe" -args "/F /IM BASupSrvc.exe /T"
logERR 3 "Processes" "STDOUT :`r`n`t$($out.standardoutput)`r`n`tSTDERR :`r`n`t$($out.standarderror)`r`n$($strLineSeparator)"
$out = Get-ProcessOutput -filename "C:\Windows\System32\taskkill.exe" -args "/F /IM BASupSysInf.exe /T"
logERR 3 "Processes" "STDOUT :`r`n`t$($out.standardoutput)`r`n`tSTDERR :`r`n`t$($out.standarderror)`r`n$($strLineSeparator)"
$out = Get-ProcessOutput -filename "C:\Windows\System32\taskkill.exe" -args "/F /IM BASupSrvcCnfg.exe /T"
logERR 3 "Processes" "STDOUT :`r`n`t$($out.standardoutput)`r`n`tSTDERR :`r`n`t$($out.standarderror)`r`n$($strLineSeparator)"
$out = Get-ProcessOutput -filename "C:\Windows\System32\taskkill.exe" -args "/F /IM BASupSrvcUpdater.exe /T"
logERR 3 "Processes" "STDOUT :`r`n`t$($out.standardoutput)`r`n`tSTDERR :`r`n`t$($out.standarderror)`r`n$($strLineSeparator)"
$out = Get-ProcessOutput -filename "C:\Windows\System32\taskkill.exe" -args "/F /IM NCentralRDLdr.exe /T"
logERR 3 "Processes" "STDOUT :`r`n`t$($out.standardoutput)`r`n`tSTDERR :`r`n`t$($out.standarderror)`r`n$($strLineSeparator)"
$out = Get-ProcessOutput -filename "C:\Windows\System32\taskkill.exe" -args "/F /IM NCentralRDViewer.exe /T"
logERR 3 "Processes" "STDOUT :`r`n`t$($out.standardoutput)`r`n`tSTDERR :`r`n`t$($out.standarderror)`r`n$($strLineSeparator)"
write-host "Done`r`n$($strLineSeparator)"
$script:diag += "`r`nDone`r`n$($strLineSeparator)`r`n"
#UNINSTALL GetSupportService
logERR 3 "Uninstall" " - CHECKING INSTALL DIRECTORIES`r`n$($strLineSeparator)"
if (test-path -path "$($strPF)\BeAnywhere Support Express\GetSupportService" -erroraction silentlycontinue) {
  #RUN UNINSTALL
  logERR 3 "Uninstall" " - UNINSTALLING TAKE CONTROL`r`n$($strLineSeparator)"
  if (test-path -path "$($strPF)\BeAnywhere Support Express\GetSupportService\uninstall.exe") {
    try {
      $out = Get-ProcessOutput -filename "$($strPF)\BeAnywhere Support Express\GetSupportService\uninstall.exe" -args "/S"
      logERR 3 "Uninstall" "STDOUT :`r`n`t$($out.standardoutput)`r`n`tSTDERR :`r`n`t$($out.standarderror)`r`n$($strLineSeparator)"
    } catch {
      $ddiag = "Failed`r`n$($strLineSeparator)"
      $ddiag += "`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
      logERR 5 "Uninstall" "$($ddiag)`r`n$($strLineSeparator)"
    }
  }
}
if (test-path -path "$($strPF86)\BeAnywhere Support Express\GetSupportService" -erroraction silentlycontinue) {
  #RUN UNINSTALL
  logERR 3 "Uninstall" " - UNINSTALLING TAKE CONTROL`r`n$($strLineSeparator)"
  if (test-path -path "$($strPF86)\BeAnywhere Support Express\GetSupportService\uninstall.exe") {
    try {
      $out = Get-ProcessOutput -filename "$($strPF86)\BeAnywhere Support Express\GetSupportService\uninstall.exe" -args "/S"
      logERR 3 "Uninstall" "STDOUT :`r`n`t$($out.standardoutput)`r`n`tSTDERR :`r`n`t$($out.standarderror)`r`n$($strLineSeparator)"
    } catch {
      $ddiag = "Failed`r`n$($strLineSeparator)"
      $ddiag += "`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
      logERR 5 "Uninstall" "$($ddiag)`r`n$($strLineSeparator)"
    }
  }
}
write-host "Done`r`n$($strLineSeparator)"
$script:diag += "`r`nDone`r`n$($strLineSeparator)`r`n"
#REMOVE DIRECTORIES
start-sleep 10
logERR 3 "Cleanup" " - REMOVING TAKE CONTROL DIRECTORIE`r`n$($strLineSeparator)"
if (test-path -path "$($strPF)\BeAnywhere Support Express\GetSupportService" -erroraction silentlycontinue) {
  try {
    write-host "Removing : $($strPF)\BeAnywhere Support Express\GetSupportService`r`n$($strLineSeparator)"
    $script:diag += "`r`nRemoving : $($strPF)\BeAnywhere Support Express\GetSupportService`r`n$($strLineSeparator)`r`n"
    remove-item -path "$($strPF)\BeAnywhere Support Express\GetSupportService" -recurse -force -erroraction stop
  } catch {
    $ddiag = "Failed`r`n$($strLineSeparator)"
    $ddiag += "`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
    logERR 5 "Uninstall" "$($ddiag)`r`n$($strLineSeparator)"
  }
}
if (test-path -path "$($strPF86)\BeAnywhere Support Express\GetSupportService" -erroraction silentlycontinue) {
  try {
    write-host "Removing : $($strPF86)\BeAnywhere Support Express\GetSupportService`r`n$($strLineSeparator)"
    $script:diag += "`r`nRemoving : $($strPF86)\BeAnywhere Support Express\GetSupportService`r`n$($strLineSeparator)`r`n"
    remove-item -path "$($strPF86)\BeAnywhere Support Express\GetSupportService" -recurse -force -erroraction stop
  } catch {
    $ddiag = "Failed`r`n$($strLineSeparator)"
    $ddiag += "`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
    logERR 5 "Uninstall" "$($ddiag)`r`n$($strLineSeparator)"
  }
}
if (test-path -path "$($strPD)\GetSupportService" -erroraction silentlycontinue) {
  try {
    write-host "Removing : $($strPD)\GetSupportService`r`n$($strLineSeparator)"
    $script:diag += "`r`nRemoving : $($strPD)\GetSupportService`r`n$($strLineSeparator)`r`n"
    remove-item -path "$($strPD)\GetSupportService" -recurse -force -erroraction stop
  } catch {
    $ddiag = "Failed`r`n$($strLineSeparator)"
    $ddiag += "`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
    logERR 5 "Uninstall" "$($ddiag)`r`n$($strLineSeparator)"
  }
}
if (test-path -path "$($strPD)\GetSupportService_Common" -erroraction silentlycontinue) {
  try {
    write-host "Removing : $($strPD)\GetSupportService_Common`r`n$($strLineSeparator)"
    $script:diag += "`r`nRemoving : $($strPD)\GetSupportService_Common`r`n$($strLineSeparator)`r`n"
    remove-item -path "$($strPD)\GetSupportService_Common" -recurse -force -erroraction stop
  } catch {
    $ddiag = "Failed`r`n$($strLineSeparator)"
    $ddiag += "`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
    logERR 5 "Uninstall" "$($ddiag)`r`n$($strLineSeparator)"
  }
}
write-host "Done`r`n$($strLineSeparator)"
$script:diag += "`r`nDone`r`n$($strLineSeparator)`r`n"