##Quickpass Installation PowerShell Script
#REGION ----- DECLARATIONS ----
  $Path = "C:\IT\QPInstall"
  $DownloadURL = "https://storage.googleapis.com/qp-installer/production/Quickpass-Agent-Setup.exe"
  $Setup = "$($Path)\Quickpass-Agent-Setup.exe"
  #Edit These Values for your Install Token and Agent ID Inside quotation Marks
  $psQPInstallTokenID = "$($env:QPInstallToken)"
  $psQPAgentID = "$($env:QPAgentID)"
  #Edit RegionID for EU Tenant ONLY
  $RegionID = "NA"
  #adds quotes to Installation Parameter
  $QPInstallTokenIDBLQt = "`"$($psQPInstallTokenID)`""
  $QPAgentIDDBlQt = "`"$($psQPAgentID)`""
  $Region = "`"$($RegionID)`""
  #Restart Options
  <#Restart Commands 
  .NET lower than 4.7.2 
  .NET 4.7.2 or Higher Already Installed

  No value Specified 
  After installation of .NET completes the system will automatically be restarted & After admin login, installation of the Agent system will complete and system will NOT be rebooted 
  After installation of the Agent system will NOT be rebooted

  /NORESTART 
  After installation of .NET completes the system will NOT automatically be restarted & After admin login, installation of the Agent will complete and system will NOT be rebooted 
  After installation of the Agent system will NOT be rebooted

  /FORCERESTART 
  After installation of .NET completes the system will automatically be restarted & After admin login, installation of the Agent will complete and system will NOT be rebooted 
  After installation of the Agent system will NOT be rebooted

  RESTART=1
  After installation of .NET completes the system will automatically be restarted & After admin login, installation of the Agent will complete and system will be rebooted 
  After installation of the Agent system will be rebooted
  #>
  $RestartOption = "/NORESTART"
  #MSA vs Local System Service Options
  <#MSA Commands
  No Value Specified
  The Agent will use the Local System Account to run the service

  MSA=0
  The Agent will use the Local System Account to run the service

  MSA=1
  A Managed Service Account will be created to run the Service 
  NOTE: This is only used for Domain Controllers.  All other system types this command will be ignored.
  #>
  $MSAOption = "MSA=1"
#ENDREGION ----- DECLARATIONS ----

#REGION ----- FUNCTIONS ----
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
#ENDREGION ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
clear-host
#Start script execution time calculation
$ScrptStartTime = (Get-Date).ToString('dd-MM-yyyy hh:mm:ss')
$script:sw = [Diagnostics.Stopwatch]::StartNew()
#INPUT VALIDATION
if ((($null -eq $psQPInstallTokenID) -or ($psQPInstallTokenID -eq "") -or ($psQPInstallTokenID -eq "CHANGEME")) -or 
  (($null -eq $psQPAgentID) -or ($psQPAgentID -eq "") -or ($psQPAgentID -eq "CHANGEME"))) {
    $script:diag += "Invalid Input Values`r`n"
    write-output "Invalid Input Values"
    $script:diag += "Variables in use for QuickPass Agent installation`r`n"
    write-output "Variables in use for QuickPass Agent installation"
    $script:diag += "`t - Software Path: $($Setup)`r`n"
    write-output "`t - Software Path: $($Setup)"
    $script:diag += "`t - Installation Token: $($psQPInstallTokenID)`r`n"
    write-output "`t - Installation Token: $($psQPInstallTokenID)"
    $script:diag += "`t - Customer ID $($psQPAgentID)`r`n"
    write-output "`t - Customer ID $($psQPAgentID)"
    $script:diag += "`t - Restart option Selected $($RestartOption)`r`n"
    write-output "`t - Restart option Selected $($RestartOption)"
    $script:diag += "`t - MSA Creation Selected $($MSAOption)`r`n"
    write-output "`t - MSA Creation Selected $($MSAOption)"
    $script:diag += "Not Proceeding with QuickPass Install`r`n"
    write-output "Not Proceeding with QuickPass Install"
    StopClock
    exit 1
} elseif ((($null -ne $psQPInstallTokenID) -and ($psQPInstallTokenID -ne "") -and ($psQPInstallTokenID -ne "CHANGEME")) -and 
  (($null -ne $psQPAgentID) -and ($psQPAgentID -ne "") -and ($psQPAgentID -ne "CHANGEME"))) {
    $script:diag += "Validated Input Values`r`nProceeding with QuickPass Install`r`n"
    write-output "Validated Input Values`r`nProceeding with QuickPass Install"
    #Test if download destination folder exists, create folder if required
    if (test-path $Path) {
      write-output "Destination folder exists"
    } else {
      #Create Directory to download quickpass installer into
      write-output "Creating folder $($Path)"
      md $Path
    }

    #Begin download of Quickpass Agent
    $script:diag += "Beginning download of the QuickPass agent`r`n"
    write-output "Beginning download of the QuickPass agent"
    try {
      $script:diag += "`t - Web.DownloadFile() - Downloading: $($DownloadURL)`r`n"
      write-output "`t - Web.DownloadFile() - Downloading: $($DownloadURL)"
      $web = new-object system.net.webclient
      $web.DownloadFile($DownloadURL, $Setup)
    } catch {
      $script:diag += "`t - Web.DownloadFile() - Could not download $($DownloadURL)`r`n"
      write-output "`t - Web.DownloadFile() - Could not download $($DownloadURL)"
      write-output $_.Exception
      write-output $_.scriptstacktrace
      write-output $_
      try {
        start-bitstransfer -source $DownloadURL -destination $Setup -erroraction stop
      } catch {
        $script:diag += "`t - BITS.Transfer() - Downloading: $($DownloadURL)`r`n"
        write-output "`t - BITS.Transfer() - Downloading: $($DownloadURL)"
        $script:diag += "`t - BITS.Transfer() - Could not download $($DownloadURL)`r`n"
        write-output "`t - BITS.Transfer() - Could not download $($DownloadURL)"
        write-output $_.Exception
        write-output $_.scriptstacktrace
        write-output $_
      }
    }
    $script:diag += "Variables in use for QuickPass Agent installation`r`n"
    write-output "Variables in use for QuickPass Agent installation"
    $script:diag += "`t - Software Path: $($Setup)`r`n"
    write-output "`t - Software Path: $($Setup)"
    $script:diag += "`t - Installation Token: $($psQPInstallTokenID)`r`n"
    write-output "`t - Installation Token: $($psQPInstallTokenID)"
    $script:diag += "`t - Customer ID $($psQPAgentID)`r`n"
    write-output "`t - Customer ID $($psQPAgentID)"
    $script:diag += "`t - Restart option Selected $($RestartOption)`r`n"
    write-output "`t - Restart option Selected $($RestartOption)"
    $script:diag += "`t - MSA Creation Selected $($MSAOption)`r`n"
    write-output "`t - MSA Creation Selected $($MSAOption)"
    $script:diag += "Beginning installation of QuickPass`r`n"
    write-output "Beginning installation of QuickPass"

    try {
      #Start-Process "$Setup" -ArgumentList "/quiet $RestartOption INSTALLTOKEN=$QPInstallTokenIDBLQt CUSTOMERID=$QPAgentIDDBlQt REGION=$Region $MSAOption" -ErrorAction Stop
      $output = Get-ProcessOutput -filename "$($Setup)" -args "/quiet $($RestartOption) INSTALLTOKEN=$($QPInstallTokenIDBLQt) CUSTOMERID=$($QPAgentIDDBlQt) REGION=$($Region) $($MSAOption)" -erroraction stop
      $script:diag += "StdOut : $($output.standardoutput) - StdErr : $($output.standarderror)`r`n"
      write-output "StdOut : $($output.standardoutput) - StdErr : $($output.standarderror)"
      StopClock
    } catch {
      $ErrorMessage = $_.Exception.Message
      $script:diag += "Install error was: $($ErrorMessage)`r`n"
      write-output "Install error was: $($ErrorMessage)"
      StopClock
      exit 1
    }
    $script:diag += "QuickPass Agent should have been installed successfully`r`n"
    write-output "QuickPass Agent should have been installed successfully"
}