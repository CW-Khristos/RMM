<#Cameron Day, IPM Computers 2023, ESMTP Mail Service Ready Monitor#>
<#Modifications by Chris Bledsoe#>
<#
    Copyright 2023 Cameron Day, Christopher Bledsoe
    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
    The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
    THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#>

#region ----- DECLARATIONS ----
$script:diag           = $null
$script:finish         = $null
$script:blnWARN        = $false
$script:strProtocol    = $env:PuttyProtocol       #Putty supports multiple protocols : -ssh ; -telnet ; -raw
if ($env:strTask -eq "M365SMTP") {
  $script:strHost      = $env:M365SMTP
  $script:strPort      = $env:SMTPPort
} elseif ($env:strTask -eq "CustomSMTP") {
  $script:strHost      = $env:PuttyIP
  $script:strPort      = $env:PuttyPort
}
$LineSeperator         = "------"
$smtpReady             = @(
  "ESMTP MAIL Service ready",
  "220 smtp.gmail.com ESMTP"
)
#region######################## TLS Settings ###########################
#[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType] 'Tls12'
[System.Net.ServicePointManager]::SecurityProtocol = (
  [System.Net.SecurityProtocolType]::Tls13 -bor 
  [System.Net.SecurityProtocolType]::Tls12 -bor 
  [System.Net.SecurityProtocolType]::Tls11 -bor 
  [System.Net.SecurityProtocolType]::Tls
)
#endregion

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

  function StopClock {
    $script:finish = "$((get-date).ToString('yyyy-MM-dd hh:mm:ss'))"
    logERR 3 "StopClock" "$($script:finish) - Completed Execution"
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

  function logERR ($intSTG, $strModule, $strErr) {
    $script:blnWARN = $true
    #CUSTOM ERROR CODES
    switch ($intSTG) {
      1 {                                                         #'ERRRET'=1 - NOT ENOUGH ARGUMENTS, END SCRIPT
        $script:blnBREAK = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - ESMTP_Monitor - NO ARGUMENTS PASSED, END SCRIPT`r`n`r`n"
        write-output "$($strLineSeparator)`r`n$($(get-date)) - ESMTP_Monitor - NO ARGUMENTS PASSED, END SCRIPT`r`n"
      }
      2 {                                                         #'ERRRET'=2 - END SCRIPT
        $script:blnBREAK = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - ESMTP_Monitor - ($($strModule)) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n"
        write-output "$($strLineSeparator)`r`n$($(get-date)) - ESMTP_Monitor - ($($strModule)) :"
        write-output "$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n"
      }
      3 {                                                         #'ERRRET'=3 - DEBUG / INFORMATIONAL
        $script:blnWARN = $false
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - ESMTP_Monitor - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
        write-output "$($strLineSeparator)`r`n$($(get-date)) - ESMTP_Monitor - $($strModule) :"
        write-output "$($strLineSeparator)`r`n`t$($strErr)"
      }
      default {                                                   #'ERRRET'=4+ - ERROR / WARNING
        $script:blnBREAK = $false
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - ESMTP_Monitor - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
        write-output "$($strLineSeparator)`r`n$($(get-date)) - ESMTP_Monitor - $($strModule) :"
        write-output "$($strLineSeparator)`r`n`t$($strErr)"
      }
    }
  }

  function dir-Check () {
    #CHECK 'PERSISTENT' FOLDERS
    if (-not (test-path -path "C:\temp")) {new-item -path "C:\temp" -itemtype directory -force}
    if (-not (test-path -path "C:\IT")) {new-item -path "C:\IT" -itemtype directory -force}
    if (-not (test-path -path "C:\IT\Log")) {new-item -path "C:\IT\Log" -itemtype directory -force}
    if (-not (test-path -path "C:\IT\Scripts")) {new-item -path "C:\IT\Scripts" -itemtype directory -force}
  }
  #IPM-Khristos
  function download-File ($strURL, $path, $file, $strREPO, $strBRCH, $strDIR) {
    if (-not (($strREPO) -and ($strBRCH) -and ($strDIR))) {
      $strURL = $strURL
    } elseif (($strREPO) -or ($strBRCH) -or ($strDIR)) {
      if ($strDIR) {
        $strURL = "$($strURL)/$($strREPO)/$($strBRCH)/$($strDIR)/$($file)"
      } elseif (-not ($strDIR)) {
        $strURL = "$($strURL)/$($strREPO)/$($strBRCH)/$($file)"
      }
    }
    try {
      #IPM-Khristos
      $web = new-object system.net.webclient
      $dlFile = $web.downloadfile($strURL, "$($path)\$($file)")
    } catch {
      try {
        #IPM-Khristos
        $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
        $dldiag = "Web.DownloadFile() - Could not download $($strURL)`r`n$($strLineSeparator)`r`n$($err)"
        logERR 3 "download-File" "$($dldiag)`r`n$($strLineSeparator)"
        start-bitstransfer -source $strURL -destination "C:\IT\BGInfo\$($file)" -erroraction stop
      } catch {
        #IPM-Khristos
        $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
        $dldiag = "BITS.Transfer() - Could not download $($strURL)`r`n$($strLineSeparator)`r`n$($err)"
        logERR 3 "download-File" "$($dldiag)`r`n$($strLineSeparator)"
      }
    }
  }

  function Get-PLinkOutput {
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
    if ($Args) {$process.StartInfo.Arguments = $Args}
    $out = $process.Start()
    #Added to get PLink output
    start-sleep -seconds 10
    taskkill /IM 'plink.exe' /F
    #
    $StandardError = $process.StandardError.ReadToEnd()
    $StandardOutput = $process.StandardOutput.ReadToEnd()

    $output = New-Object PSObject
    $output | Add-Member -type NoteProperty -name StandardOutput -Value $StandardOutput
    $output | Add-Member -type NoteProperty -name StandardError -Value $StandardError
    return $output
  } ## Get-PLinkOutput
#endregion ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
clear-host
#Start script execution time calculation
$ScrptStartTime = (get-date -format "yyyy-MM-dd HH:mm:ss").ToString()
$script:sw = [Diagnostics.Stopwatch]::StartNew()
#CHECK 'PERSISTENT' FOLDERS
dir-Check
#if (Test-Path -Path "C:\IT\putty.exe" ) {
if (Test-Path -Path "C:\IT\plink.exe" ) {
	logERR 3 "BEGIN" "PLink is already installed. Moving on.....`r`n$($strLineSeparator)"
} else {
	try {
		logERR 3 "BEGIN" "PLink not installed. Downloading.....`r`n$($strLineSeparator)"
		#Downloads files and installs putty. 
		#download-File "https://the.earth.li/~sgtatham/putty/latest/w64/putty.exe" "C:\IT" "putty.exe" $null $null $null
		download-File "https://the.earth.li/~sgtatham/putty/latest/w64/plink.exe" "C:\IT" "plink.exe" $null $null $null
		logERR 3 "BEGIN" "PLink was installed successfully. Moving on.....`r`n$($strLineSeparator)"
	} catch {
		logERR 4 "BEGIN" "PLink install was unsuccessful. Please try again`r`n$($strLineSeparator)"
	}
}
if (-not ($script:blnBREAK)) {
	try {
		#Connects to the target computer using telnet, if it fails it outputs an error and exits the script.
		logERR 3 "ESMTP-CHECK" "Connecting : $($script:strHost):$($script:strPort) $($script:strProtocol)`r`n$($strLineSeparator)"
		$script:strOUT = Get-PLinkOutput -filename "C:\IT\\plink.exe" -args "$($script:strProtocol) -P $($script:strPort) $($script:strHost)"
		logERR 3 "ESMTP-CHECK" "STDOUT :`r`n`t$($script:strOUT.StandardOutput)`r`n$($strLineSeparator)"
    logERR 3 "ESMTP-CHECK" "STDERR :`r`n`t$($script:strOUT.StandardError)`r`n$($strLineSeparator)"
    foreach ($ready in $smtpReady) {
      if ($script:strOUT.StandardOutput -match $ready) { #"ESMTP MAIL Service ready") {
        logERR 3 "ESMTP-CHECK" "SMTP connection successful : $($script:strHost):$($script:strPort) : Protocol : $($script:strProtocol)`r`n$($strLineSeparator)"
        break
      } elseif ($script:strOUT.StandardOutput -notmatch $ready) { #"ESMTP MAIL Service ready") {
        logERR 4 "ESMTP-CHECK" "SMTP connection failed : ESMTP MAIL Service not ready`r`n$($strLineSeparator)"
      }
    }
	} catch {
    $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($script:strLineSeparator)"
		logERR 4 "ESMTP-CHECK" "SMTP connection error : $($script:strHost):$($script:strPort) : Protocol : $($script:strProtocol)`r`n$($err)"
    StopClock
    write-DRMMAlert "SMTP Failure : $($script:strHost):$($script:strPort) : Protocol : $($script:strProtocol) : $($script:finish)"
    write-DRMMDiag "$($script:diag)"
    exit 1
	}
} elseif ($script:blnBREAK) {
	logERR 4 "FAIL" "Failed to find / install PLink; unable to continue....`r`n$($strLineSeparator)"
	StopClock
	write-DRMMAlert "Failed to find / install PLink; unable to continue : $($script:finish)"
	write-DRMMDiag "$($script:diag)"
	exit 1
}
#DATTO OUTPUT
#Stop script execution time calculation
StopClock
if ($script:blnWARN) {
  write-DRMMAlert "SMTP Failure : $($script:strHost):$($script:strPort) : Protocol : $($script:strProtocol) : $($script:finish)"
  write-DRMMDiag "$($script:diag)"
  exit 1
} elseif (-not ($script:blnWARN)) {
  write-DRMMAlert "SMTP Successful : $($script:strHost):$($script:strPort) : Protocol : $($script:strProtocol) : $($script:finish)"
  write-DRMMDiag "$($script:diag)"
  exit 0
}
#END SCRIPT
#------------