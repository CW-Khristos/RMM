<#
    .SYNOPSIS
        Monitoring - Windows - Zabbix - Cameron Day - Chris Bledsoe
    .DESCRIPTION
        This script will monitor if Zabbix is installed and configured correctly. Will also install or unistall zabbix as needed.
        Copyright 2024 Cameron Day, Chris Bledsoe
    .NOTES
        2024-02-21: Added upgrade and monitor functions.
        2024-02-20: Initial version
#>
#region - DECLORATIONS
$script:diag                = $null
$script:blnWARN             = $false
$script:blnBREAK            = $false
$script:mode                = $env:mode
$script:pskID               = $env:pskID
$script:pskValue            = $env:pskValue
$script:hostname            = $env:COMPUTERNAME
$script:ActivePassive       = $env:ActivePassive
$script:dattoCustomerName   = $env:CS_PROFILE_NAME
$script:serverHostnameOrIP  = $env:serverHostnameOrIP
$script:zabbixInstalled     = Get-Service "Zabbix Agent 2" -ErrorAction SilentlyContinue
$installFolder              = "C:\IT\Zabbix"
$logPath                    = "C:\IT\Log\Zabbix_Monitor"
$logFile                    = "C:\IT\Log\Zabbix_install.log"
$pkg                        = "C:\IT\Zabbix_Agent_2.msi"
$zabbixDownload             = "https://cdn.zabbix.com/zabbix/binaries/stable/6.4/6.4.13/zabbix_agent2-6.4.13-windows-amd64-openssl.msi"
$drmmRoles                  = $env:UDF_7
$strLineSeparator           = "----------------------------------"
#region######################## TLS Settings ###########################
[System.Net.ServicePointManager]::MaxServicePointIdleTime = 5000000
#[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType] 'Tls12'
#[System.Net.SecurityProtocolType]::Ssl3 -bor 
#[System.Net.SecurityProtocolType]::Tls11 -bor 
#[System.Net.SecurityProtocolType]::Tls
[System.Net.ServicePointManager]::SecurityProtocol = (
  [System.Net.SecurityProtocolType]::Ssl2 -bor 
  [System.Net.SecurityProtocolType]::Tls13 -bor 
  [System.Net.SecurityProtocolType]::Tls12
)
#endregion
#endregion - DECLORATIONS

#region - FUNCTIONS
function write-DRMMDiag ($messages) {
  write-output "<-Start Diagnostic->"
  foreach ($message in $messages) { $message }
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
  $script:finish = (get-date -format "yyyy-MM-dd HH:mm:ss").ToString()
  $ScriptStopTime = (get-date -format "yyyy-MM-dd HH:mm:ss").ToString()
  write-output "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
  $script:diag += "`r`n`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
}

function logERR ($intSTG, $strModule, $strErr) {
  $script:blnWARN = $true
  #CUSTOM ERROR CODES
  switch ($intSTG) {
    1 {
      #'ERRRET'=1 - NOT ENOUGH ARGUMENTS, END SCRIPT
      $script:blnBREAK = $true
      $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - Zabbix_Monitor - NO ARGUMENTS PASSED, END SCRIPT`r`n`r`n"
      write-output "$($strLineSeparator)`r`n$($(get-date)) - Zabbix_Monitor - NO ARGUMENTS PASSED, END SCRIPT`r`n"
    }
    2 {
      #'ERRRET'=2 - END SCRIPT
      $script:blnBREAK = $true
      $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - Zabbix_Monitor - ($($strModule)) :"
      $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n"
      write-output "$($strLineSeparator)`r`n$($(get-date)) - Zabbix_Monitor - ($($strModule)) :"
      write-output "$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n"
    }
    3 {
      #'ERRRET'=3
      $script:blnWARN = $false
      $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - Zabbix_Monitor - $($strModule) :"
      $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
      write-output "$($strLineSeparator)`r`n$($(get-date)) - Zabbix_Monitor - $($strModule) :"
      write-output "$($strLineSeparator)`r`n`t$($strErr)"
    }
    default {
      #'ERRRET'=4+
      $script:blnBREAK = $false
      $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - Zabbix_Monitor - $($strModule) :"
      $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
      write-output "$($strLineSeparator)`r`n$($(get-date)) - Zabbix_Monitor - $($strModule) :"
      write-output "$($strLineSeparator)`r`n`t$($strErr)"
    }
  }
}

function dir-Check () {
  #CHECK 'PERSISTENT' FOLDERS
  if (-not (test-path -path "C:\temp")) { new-item -path "C:\temp" -itemtype directory -force }
  if (-not (test-path -path "C:\IT")) { new-item -path "C:\IT" -itemtype directory -force }
  if (-not (test-path -path "C:\IT\Log")) { new-item -path "C:\IT\Log" -itemtype directory -force }
  if (-not (test-path -path "C:\IT\Scripts")) { new-item -path "C:\IT\Scripts" -itemtype directory -force }
}

function run-Download {
  logERR 3 "run-Download" "Downloading Zabbix 2`r`n$($strLineSeparator)"
  try { Invoke-WebRequest -uri "$($zabbixDownload)" -OutFile "$($pkg)" } catch {
    $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
    $taskdiag = "Failed to Download Zabbix 2`r`n$($strLineSeparator)"
    logERR 2 "run-Download" "$($taskdiag)`r`n$($err)`r`n$($strLineSeparator)"
  }
}

function run-Deploy {
  try {
    #OS Type & Version
    $osarch = (Get-WmiObject -class Win32_OperatingSystem)
    Switch ($osarch.ProductType) {
      "1" {$producttype = "Workstation"}
      "2" {$producttype = "DC"}
      "3" {$producttype = "Server"}
    }
    logERR 3 "run-Deploy" "Deploying Zabbix 2`r`n$($strLineSeparator)"
    $params = "/l*v $($logFile) "
    $params += "HOSTNAME=`"$($script:dattoCustomerName) - $($script:hostname)`" ENABLEPATH=1 HOSTMETADATA=Windows$($producttype):$($script:ActivePassive)$($drmmRoles) "
    $params += "LISTENPORT=10050 SERVER=$($script:serverHostnameOrIP) SERVERACTIVE=$($script:serverHostnameOrIP) INSTALLFOLDER=`"$($installFolder)`" "
    $params += "TLSCONNECT=psk TLSACCEPT=psk TLSPSKIDENTITY=$($script:pskID) TLSPSKVALUE=$($script:pskValue) RefreshActiveChecks=120 /qn"
    #Start-Process -FilePath $pkg -ArgumentList "$($params)" -PassThru -Wait
    $taskdiag = Get-ProcessOutput -FileName "C:\Windows\system32\msiexec.exe" -Args "/i $($pkg) $($params)"
    logERR 3 "run-Deploy" "Deploy Complete :`r`n`t- StdOut : $($taskdiag.standardoutput) `r`n`t- StdErr : $($taskdiag.standarderror)`r`n`r`n$($strLineSeparator)"
  } catch {
    $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
    $taskdiag = "Failed to Install Zabbix 2`r`n$($strLineSeparator)"
    logERR 2 "run-Deploy" "$($taskdiag)`r`n$($err)`r`n$($strLineSeparator)"
  }
  Start-Sleep -seconds 30
}

function run-Remove {
  logERR 3 "run-Remove" "Removing Zabbix`r`n$($strLineSeparator)"
  $regPath = get-itemproperty -path 'HKLM:\SOFTWARE\Zabbix SIA\Zabbix Agent 2 (64-bit)' -name 'ProductCode'
  $regPath.ProductCode
  try {
    Start-Process -FilePath "C:\Windows\system32\msiexec.exe" -ArgumentList "/x $($regPath.ProductCode) /qn" -PassThru -Wait
    rm $installFolder -Recurse -Force -ErrorAction SilentlyContinue
  } catch {
    $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
    $taskdiag += "`r`nFailed to remove Zabbix 2`r`n$($strLineSeparator)"
    logERR 2 "run-Remove" "$($taskdiag)`r`n$($err)`r`n$($strLineSeparator)"
  }
  sc.exe delete "Zabbix Agent 2"
  Remove-Item -Path "HKLM:SYSTEM\CurrentControlSet\Services\EventLog\Application\Zabbix Agent 2" -Force
}

function run-Upgrade () {
  try {
    run-Remove -wait
  } catch {
    $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
    $taskdiag += "`r`nFailed to Remove Zabbix 2`r`n$($strLineSeparator)"
    logERR 2 "run-Upgrade" "$($taskdiag)`r`n$($err)`r`n$($strLineSeparator)"
  }
  Start-Sleep -Seconds 2
  try {
    run-Download -wait
    run-Deploy -wait
  } catch {
    $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
    $taskdiag += "`r`nFailed to Upgrade Zabbix 2`r`n$($strLineSeparator)"
    logERR 2 "run-Upgrade" "$($taskdiag)`r`n$($err)`r`n$($strLineSeparator)"
  }
}

function run-Monitor {
  if ($($script:zabbixInstalled.Status) -eq "Stopped") {
    $taskdiag = "Warning! Service is not started : `r`nAttempting to start`r`n$($strLineSeparator)"
    logERR 3 "run-Monitor" "$($taskdiag)"
    try {Start-Service -Name $($script:zabbixInstalled.Name)} catch {
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
      $taskdiag += "`r`nFailed to Start Zabbix Service`r`n$($strLineSeparator)"
      logERR 2 "run-Monitor" "$($taskdiag)`r`n$($err)`r`n$($strLineSeparator)"
    }
    #& "c:\IT\Zabbix\zabbix_agent2.exe -c c:\IT\Zabbix\zabbix_agent2.conf -i"
  }
  if (-not ($script:blnBREAK)) {
    if ($($script:zabbixInstalled.Status) -eq "Running") { 
      $taskdiag = "$($script:zabbixInstalled.Name) is started`r`n$($strLineSeparator)"
      logERR 3 "run-Monitor" "$($taskdiag)" 
    }
    $taskdiag = "Begin Verification of Correct Configuration : `r`n$($strLineSeparator)"
    logERR 3 "run-Monitor" "$($taskdiag)" 
    #verify ServerIP, and customername & devicename in proper format : '[CustomerName - DeviceName]'
    $blnMatch = $true
    $localConfig = Get-Content -Path "C:\IT\Zabbix\zabbix_agent2.conf"
    if (-not ($localConfig -match "Hostname=$($script:dattoCustomerName) - $($script:hostname)")) {
      $blnMatch = $false
      logERR 3 "run-Monitor" "Config doesn't match hostname"
    }
    if (-not ($localConfig -match "Server=$($script:serverHostnameOrIP)")) {
      $blnMatch = $false
      logERR 3 "run-Monitor" "Config doesn't match server hostname or IP"
    }
    if (-not ($localConfig -match "ServerActive=$($script:serverHostnameOrIP)")) {
      $blnMatch = $false
      logERR 3 "run-Monitor" "Config doesn't match server (active) hostname or IP"
    }
    if (-not ($localConfig -match "$($script:pskID)")) {
      $blnMatch = $false
      logERR 3 "run-Monitor" "PSK ID doesn't match PSK Identity"
    }
    $pskFile = Get-Content -Path "C:\IT\Zabbix\psk.key"
    if (-not ($pskFile -match "$($script:pskValue)")) {
      $blnMatch = $false
      logERR 3 "run-Monitor" "PSK value doesn't match psk.key"
    }
    if (-not ($blnMatch)) { run-Upgrade }
  }
}
#endregion - FUNCTIONS

#region - SCRIPT
$ScrptStartTime = (get-date -format "yyyy-MM-dd HH:mm:ss").ToString()
$script:sw = [Diagnostics.Stopwatch]::StartNew()
logERR 3 "Mode : $($script:mode)" "Begin Script : $($ScrptStartTime)"
dir-Check -wait
switch ($script:mode) {
  "Deploy" {
    run-Download -wait
    run-Deploy -wait
    try {
      $script:zabbixInstalled = Get-Service "Zabbix Agent 2"
      if ($($script:zabbixInstalled.Status) -ne "Running") {
        Restart-Service -Name $($script:zabbixInstalled.Name)
        $taskdiag = "Warning! Service is not started : `r`n`tAttempting to start`r`n`t$($strLineSeparator)"
        logERR 3 "Mode : $($script:mode)" "$($taskdiag)"
        #Write-Warning "Service is not started : `r`n Attempting to start"
        Start-Service -Name $($script:zabbixInstalled.Name)
        #& "c:\IT\Zabbix\zabbix_agent2.exe -c c:\IT\Zabbix\zabbix_agent2.conf -i"
      }
      if ($($script:zabbixInstalled.Status) -eq "Running") { Write-Output "Zabbix is running" }
    } catch {
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
      $taskdiag = "Error failed to start $($script:zabbixInstalled.Name) : Attempting redeploy`r`n$($strLineSeparator)"
      logERR 3 "Mode : $($script:mode)" "$($taskdiag)`r`n$($err)`r`n$($strLineSeparator)"
        try {
          run-Upgrade -wait
        }
        catch {
          $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
          $taskdiag = "Error failed to redeploy Zabbix`r`n$($strLineSeparator)"
          logERR 2 "Mode : $($script:mode)" "$($taskdiag)`r`n$($err)`r`n$($strLineSeparator)"
      }
    }
  }
  "Remove" {
    run-Remove -wait
  }
  "Upgrade" {
    run-Upgrade -wait
  }
  "Monitor" {
    if (-not (test-path -path "C:\IT\Zabbix")) { 
      $taskdiag = "No C:\IT\Zabbix dir Means that Zabbix was not Installed Correctly : Rerunning Download/Deploy`r`n$($strLineSeparator)"
      logERR 3 "Mode : $($script:mode)" "$($taskdiag)"
      run-Download -wait
      run-Deploy -wait
    }
    run-Monitor
  }
}

$script:finish = (get-date -format "yyyy-MM-dd HH:mm:ss").ToString()
if (-not $script:blnBREAK) {
  if (-not $script:blnWARN) {
    $enddiag = "Execution Successful : $($script:finish)`r`n$($strLineSeparator)`r`n"
    logERR 3 "END" "$($enddiag)"
    #WRITE TO LOGFILE
    "$($script:diag)" | add-content $logPath -force
    write-DRMMAlert "$($script:mode) : Healthy : $($script:finish)"
    write-DRMMDiag "$($script:diag)"
    exit 0
  } elseif ($script:blnWARN) {
    $enddiag = "Execution Completed with Warnings : $($script:finish)`r`n$($strLineSeparator)`r`n"
    logERR 3 "END" "$($enddiag)"
    #WRITE TO LOGFILE
    "$($script:diag)" | add-content $logPath -force
    write-DRMMAlert "$($script:mode) : Execution Completed with Warnings : Diagnostics - $($logPath) : $($script:finish)"
    write-DRMMDiag "$($script:diag)"
    exit 1
  }
} elseif ($script:blnBREAK) {
  #WRITE TO LOGFILE
  $enddiag += "Execution Failed : $($finish)`r`n$($strLineSeparator)"
  logERR 4 "END" "$($enddiag)"
  "$($script:diag)" | add-content $logPath -force
  write-DRMMAlert "$($script:mode) : Failure : Diagnostics - $($logPath) : $($script:finish)"
  write-DRMMDiag "$($script:diag)"
  exit 1
}
#endregion - SCRIPT