#REGION ----- DECLARATIONS ----
  $script:diag = $null
  $script:blnWARN = $false
  $script:blnFAIL = $false
  $logPath = "C:\IT\Log\FireEye_Uninstall"
  $feDEST= "C:\IT\xagtSetup_33.46.6_universal.msi"
  $feURL= "https://s3.wasabisys.com/createme/xagtSetup_33.46.6_universal.msi"
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
    $mill = $mill.split(".")[1]
    $mill = $mill.SubString(0,[math]::min(3,$mill.length))
    $script:diag += "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
    write-output "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
  }

  function logERR ($intSTG, $strModule, $strErr) {
    $script:blnWARN = $true
    #CUSTOM ERROR CODES
    switch ($intSTG) {
      1 {                                                         #'ERRRET'=1 - NOT ENOUGH ARGUMENTS, END SCRIPT
        $script:blnFAIL = $true
        write-output "$($(get-date))`t - FireEye_Uninstall - NO ARGUMENTS PASSED, END SCRIPT`r`n"
        $script:diag += "`r`n$($(get-date))`t - FireEye_Uninstall - NO ARGUMENTS PASSED, END SCRIPT`r`n`r`n"
      }
      2 {                                                         #'ERRRET'=2 - INSTALL / IMPORT MODULE FAILURE, END SCRIPT
        $script:blnFAIL = $true
        write-output "$($(get-date))`t - FireEye_Uninstall - ($($strModule))`r`n$($strErr), END SCRIPT`r`n"
        $script:diag += "`r`n$($(get-date))`t - FireEye_Uninstall - ($($strModule))`r`n$($strErr), END SCRIPT`r`n`r`n"
      }
      default {                                                   #'ERRRET'=3+
        write-output "$($(get-date))`t - FireEye_Uninstall - $($strModule) : $($strErr)`r`n"
        $script:diag += "`r`n$($(get-date))`t - FireEye_Uninstall - $($strModule) : $($strErr)`r`n`r`n"
      }
    }
  }
#ENDREGION ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
#Start script execution time calculation
$ScrptStartTime = (Get-Date).ToString('dd-MM-yyyy hh:mm:ss')
$script:sw = [Diagnostics.Stopwatch]::StartNew()
$script:diag += "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss')) - EXECUTING FireEye_Uninstall`r`n"
write-output "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss')) - EXECUTING FireEye_Uninstall"
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
#DOWNLOAD FIREEYE MSI
try {
  $feMSI = Invoke-WebRequest -Uri $feURL -OutFile $feDEST -erroraction stop
} catch {
  $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
  logERR 3 "Invoke-WebRequest() - Could not download $($feURL)" $err
  try {
    $web = new-object system.net.webclient
    $feMSI = $web.DownloadFile($feURL, $feDEST)
  } catch {
    $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
    logERR 4 "Web.DownloadFile() - Could not download $($feURL)" $err
    try {
      $feMSI = start-bitstransfer -source $feURL -destination $feDEST -erroraction stop
    } catch {
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
      logERR 2 "Start-BitsTransfer() - Could not download $($feURL)" $err
    }
  }
}
if (-not ($script:blnFAIL)) {
  #RUN FIREEYE MSI TO UNINSTALL
  write-output "`t`t - EXECUTING : 'msiexec.exe /x $($feDEST) /qn'"
  $script:diag += "`t`t - EXECUTING : 'msiexec.exe /x $($feDEST) /qn'`r`n"
  $output = Get-ProcessOutput -filename "msiexec.exe" -args "/x $($feDEST) /qn"
  write-output "`t`t`t - StdOut : $($output.standardoutput) - StdErr : $($output.standarderror)"
  $script:diag += "`t`t`t - StdOut : $($output.standardoutput) - StdErr : $($output.standarderror)`r`n"
}
$script:diag += "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss')) - FireEye_Uninstall COMPLETE`r`n"
write-output "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss')) - FireEye_Uninstall COMPLETE"
#Stop script execution time calculation
StopClock
#WRITE LOGFILE
$script:diag | out-file $logPath
#DATTO OUTPUT
if ($script:blnWARN) {
  write-DRMMAlert "FireEye_Uninstall : Execution Failure : See Diagnostics"
  write-DRMMDiag "$($script:diag)"
  exit 1
} elseif (-not $script:blnWARN) {
  write-DRMMAlert "FireEye_Uninstall : Completed Execution"
  write-DRMMDiag "$($script:diag)"
  exit 0
}
#END SCRIPT
#------------