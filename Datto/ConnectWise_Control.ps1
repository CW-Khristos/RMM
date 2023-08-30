#connectwise control in UDF :: redux build 2, march 23/seagull
#Modified by : Chris Bledsoe | cbledsoe@ipmcomputers.com

#region ----- DECLARATIONS ----
  $script:diag                = $null
  $script:blnWARN             = $false
  $script:blnBREAK            = $false
  $strLineSeparator           = "-------------------"
  $logPath                    = "C:\IT\Log\CW_Control"
  $exePath                    = "C:\IT\ConnectWiseControl.ClientSetup.exe"
  $usrUDF                     = "$($env:usrUDF)"
  $strTask                    = "$($env:strTask)"
  $varSite                    = "$($env:strSite)"
  $varCompany                 = "$($env:strCompany)"
  $CWKeyThumbprint            = "$($env:ConnectWiseControlPublicKeyThumbprint)"
  $CWControlInstallURL        = "$($env:ConnectWiseControlInstallerUrl)"
  $ConnectWiseControlBaseUrl  = "$($env:ConnectWiseControlBaseUrl)"
  #SET TLS SECURITY
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12
#endregion ----- DECLARATIONS ----

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
    write-output "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds"
    $script:diag += "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
  }

  function logERR ($intSTG, $strModule, $strErr) {
    $script:blnWARN = $true
    #CUSTOM ERROR CODES
    switch ($intSTG) {
      1 {                                                         #'ERRRET'=1 - NOT ENOUGH ARGUMENTS, END SCRIPT
        $script:blnBREAK = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - CW_Control - NO ARGUMENTS PASSED, END SCRIPT`r`n`r`n"
        write-output "$($strLineSeparator)`r`n$($(get-date)) - CW_Control - NO ARGUMENTS PASSED, END SCRIPT`r`n" -foregroundcolor red
      }
      2 {                                                         #'ERRRET'=2 - END SCRIPT
        $script:blnBREAK = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - CW_Control - ($($strModule)) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n"
        write-output "$($strLineSeparator)`r`n$($(get-date)) - CW_Control - ($($strModule)) :" -foregroundcolor red
        write-output "$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n" -foregroundcolor red
      }
      3 {                                                         #'ERRRET'=3
        $script:blnWARN = $false
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - CW_Control - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
        write-output "$($strLineSeparator)`r`n$($(get-date)) - CW_Control - $($strModule) :" -foregroundcolor yellow
        write-output "$($strLineSeparator)`r`n`t$($strErr)" -foregroundcolor yellow
      }
      default {                                                   #'ERRRET'=4+
        $script:blnBREAK = $false
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - CW_Control - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
        write-output "$($strLineSeparator)`r`n$($(get-date)) - CW_Control - $($strModule) :" -foregroundcolor yellow
        write-output "$($strLineSeparator)`r`n`t$($strErr)" -foregroundcolor red
      }
    }
  }

  #function provided by Datto
  function verifyPackage ($file, $certificate, $thumbprint, $name, $url) {
    $varChain = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Chain
    try {
      $varChain.Build((Get-AuthenticodeSignature -FilePath "$($file)").SignerCertificate) | out-null
    } catch [System.Management.Automation.MethodInvocationException] {
      $err = "`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
      $verify = "- ERROR: $($name) installer did not contain a valid digital certificate.`r`n"
      $verify += "  This could suggest a change in the way $($name) is packaged; it could`r`n"
      $verify += "  also suggest tampering in the connection chain.`r`n"
      $verify += "- Please ensure $($url) is whitelisted and try again.`r`n"
      $verify += "  If this issue persists across different devices, please file a support ticket.`r`n$($err)`r`n"
    }

    $varIntermediate=($varChain.ChainElements | ForEach-Object {$_.Certificate} | Where-Object {$_.Subject -match "$certificate"}).Thumbprint

    if ($varIntermediate -ne $thumbprint) {
      $verify = "- ERROR: $($file) did not pass verification checks for its digital signature.`r`n"
      $verify += "  This could suggest that the certificate used to sign the $($name) installer`r`n"
      $verify += "  has changed; it could also suggest tampering in the connection chain.`r`n"
      if ($varIntermediate) {
        $verify += ": We received: $($varIntermediate)`r`n: We expected: $($thumbprint)`r`nPlease report this issue.`r`n"
      } else {
        $verify += "  The installer's certificate authority has changed.`r`n"
      }
      $verify += "- Installation cannot continue. Exiting.`r`n"
      logERR 2 "verifyPackage" "$($verify)`r`n$($strLineSeparator)"
      exit 1
    } else {
      $verify = "- Digital Signature verification passed.`r`n"
      logERR 3 "verifyPackage" "$($verify)`r`n$($strLineSeparator)"
    }
  }

  function CreateJoinLink {
    $null = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\ScreenConnect Client ($CWKeyThumbprint)" -Name ImagePath).ImagePath -Match '(&s=[a-f0-9\-]*)'
    $GUID = $Matches[0] -replace '&s='
    $apiLaunchUrl= "$($ConnectWiseControlBaseUrl)/Host#Access///$($GUID)/Join"
    New-ItemProperty -Path "HKLM:\Software\CentraStage" -Name "Custom$($usrUDF)" -PropertyType String -Value "$($apiLaunchUrl)" -force | out-null
    logERR 3 "run-Deploy" "- UDF written to UDF#$($usrUDF)`r`n$($strLineSeparator)"
  }

  function dir-Check () {
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
  }

  function run-Deploy () {
    #CHECK 'PERSISTENT' FOLDERS
    dir-Check
    try {
      #CHECK CW CONTROL SERVICE
      logERR 3 "run-Deploy" "Checking for CW Control Service...`r`n$($strLineSeparator)"
      $service = get-service -name "ScreenConnect Client ($($CWKeyThumbprint))" -erroraction continue
      if (-not $service) {
        logERR 3 "run-Deploy" "- CW Control Service not Found; Continuing...`r`n$($strLineSeparator)"
      } elseif ($service) {
        logERR 3 "run-Deploy" "- CW Control Service Found; Ensuring Service is Running...`r`n$($strLineSeparator)"
        if ($service.status -ne "Running") {start-service -name "$($service.name)"}
      }
      if (-not (test-path "HKLM:\SYSTEM\CurrentControlSet\Services\ScreenConnect Client ($CWKeyThumbprint)" )) {
        $redeploy = $true
      } elseif (test-path "HKLM:\SYSTEM\CurrentControlSet\Services\ScreenConnect Client ($CWKeyThumbprint)" ) {
        logERR 3 "run-Deploy" "- CW Control already installed. Establishing link...`r`n$($strLineSeparator)"
        CreateJoinLink
      }
      if (($redeploy) -or (-not $service)) {
        if ($redeploy) {logERR 3 "run-Deploy" "- Registry Thumbprint Not Found; Re-Deploying CW Control...`r`n$($strLineSeparator)"}
        if (-not $service) {logERR 3 "run-Deploy" "- Service Not Found; Downloading CW Control Installer...`r`n$($strLineSeparator)"}
        invoke-webrequest -uri "$($CWControlInstallURL)" -outfile "$($exePath)"
        #cert from 16/August/2022 to 15/August/2025
        logERR 3 "run-Deploy" "- Verifying CW Control Download...`r`n$($strLineSeparator)"
        verifyPackage "$($exePath)" "ConnectWise, LLC" "4c2272fba7a7380f55e2a424e9e624aee1c14579" "ConnectWise Control Client Setup" "$($CWControlInstallURL)"
        logERR 3 "run-Deploy" "- Installing ConnectWise Control...`r`n$($strLineSeparator)"
        start-process -wait -filepath "$($exePath)" -argumentlist "/qn" -passthru
        CreateJoinLink
      }
      $depdiag = "DEPLOY CW CONTROL COMPLETED - CW Control has been deployed"
      logERR 3 "run-Deploy" "$($depdiag)`r`n$($strLineSeparator)"
    } catch {
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
      $depdiag = "FAILED TO DOWNLOAD CW CONTROL`r`n$($strLineSeparator)`r`n$($err)"
      logERR 2 "run-Deploy" "$($depdiag)`r`n$($strLineSeparator)"
    }
  }

  function run-Monitor () {
    #CHECK CW CONTROL SERVICE
    logERR 3 "run-Monitor" "Checking for CW Control Service...`r`n$($strLineSeparator)"
    $service = get-service -name "ScreenConnect Client ($($CWKeyThumbprint))" -erroraction continue
    try {
      if (-not $service) {                   #SERVICE DOES NOT EXIST, DEPLOY CW CONTROL
        logERR 3 "run-Monitor" "- Service Not Found; Deploying CW Control...`r`n$($strLineSeparator)"
        run-Deploy
      } elseif ($service) {                  #SERVICE EXISTS
        logERR 3 "run-Monitor" "- CW Control Service Found; Ensuring Service is Running...`r`n$($strLineSeparator)"
        if ($service.status -ne "Running") {start-service -name "$($service.name)"}
        if (-not (test-path "HKLM:\SYSTEM\CurrentControlSet\Services\ScreenConnect Client ($CWKeyThumbprint)" )) {
          $redeploy = $true
        } elseif (test-path "HKLM:\SYSTEM\CurrentControlSet\Services\ScreenConnect Client ($CWKeyThumbprint)" ) {
          logERR 3 "run-Monitor" "- CW Control already installed. Establishing link...`r`n$($strLineSeparator)"
          CreateJoinLink
        }
      }
    } catch {
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
      $mondiag = "FAILED TO MONITOR CW CONTROL`r`n$($strLineSeparator)`r`n$($err)"
      logERR 2 "run-Monitor" "$($mondiag)`r`n$($strLineSeparator)"
    }
  }

  function run-Upgrade () {
    try {
      run-Remove
    } catch {
      
    }
    try {
      run-Deploy
    } catch {
      
    }
  }

  function run-Remove () {
    #CHECK IF CW CONTROL IS RUNNING
    $remove = $true
    $varAttempts = 0
    logERR 3 "run-Remove" "Checking if CW Control is Running`r`n$($strLineSeparator)"
    $service = get-service -name "ScreenConnect Client ($($CWKeyThumbprint))" -erroraction continue
    try {
      if (-not $service) {
        $remove = $false
        logERR 3 "run-Remove" "CW Control Service is not Installed; Exiting...`r`n$($strLineSeparator)"
      } elseif ($service.status -eq "Stopped") {
        $remove = $true
        logERR 3 "run-Remove" "CW Control Service is not Running; Continuing...`r`n$($strLineSeparator)"
      } elseif ($service.status -ne "Stopped") {
        while (($service.status -ne "Stopped") -and ($varAttempts -lt 3)) {
          $varAttempts++
          logERR 3 "run-Remove" "Terminating CW Control`r`n$($strLineSeparator)"
          $result = stop-service -name "$($service.name)" -erroraction continue
          start-sleep -seconds 5
          $service = get-service -name "ScreenConnect Client ($($CWKeyThumbprint))" -erroraction continue
          logERR 3 "run-Remove" "`tStatus : $($service.status)`r`n$($strLineSeparator)"
          if ($service.status -eq "Stopped") {$remove = $true}
        }
      }
      if ($remove) {                    #REMOVE CW CONTROL
        logERR 3 "run-Remove" "Removing CW Control`r`n$($strLineSeparator)"
        try {
          $keys = get-childitem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" -recurse
          $keys += get-childitem "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall" -recurse
          foreach ($key in $keys) {
            try {
              $key | get-itemproperty | where {$_.DisplayName -match "ScreenConnect Client"}
            } catch {
              $script:blnWARN = $true
              $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
              $remdiag = "ERROR READING KEY (POSSIBLY CORRUPT KEY) : $($key | out-string)`r`n$($strLineSeparator)`r`n$($err)"
              logERR 3 "run-Remove" "$($remdiag)`r`n$($strLineSeparator)"
            }
          }
          $cwKeys = $keys | get-itemproperty | where {$_.DisplayName -match "ScreenConnect Client"}
          $cwKeys = $cwKeys | where {$_.DisplayName -match "$($CWKeyThumbprint)"}
          $UninstallString = $cwKeys.UninstallString.split(" ")[1]
          $output = Get-ProcessOutput -FileName "msiexec.exe" -Args "$($UninstallString) /quiet /qn /norestart /log `"C:\IT\Log\$($key.displayname)_uninstall`""
          logERR 3 "run-Remove" " - StdOut : $($output.standardoutput) `r`n`t- StdErr : $($output.standarderror)`r`n$($strLineSeparator)"
        } catch {
          $script:blnWARN = $true
          $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
          $remdiag = "FAILED TO REMOVE CW CONTROL`r`n$($strLineSeparator)`r`n$($err)"
          logERR 2 "run-Remove" "$($remdiag)`r`n$($strLineSeparator)"
        }
      }
    } catch {
      $script:blnWARN = $true
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
      $remdiag = "FAILED TO REMOVE CW CONTROL`r`n$($strLineSeparator)`r`n$($err)"
      logERR 2 "run-Remove" "$($remdiag)`r`n$($strLineSeparator)"
    }
  }
#endregion ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
clear-host
#Start script execution time calculation
$ScrptStartTime = (get-date).ToString('dd-MM-yyyy hh:mm:ss')
$script:sw = [Diagnostics.Stopwatch]::StartNew()
#FORMAT COMPANY NAME
if (-not $varCompany) {$varCompany = "$($env:CS_PROFILE_NAME)"}
if ($varCompany -match ' ') {$varCompany = $varCompany.replace(' ','%20')}
#FORMAT CW URL
if ($CWControlInstallURL -match "|") {$CWControlInstallURL = $CWControlInstallURL.replace('|','&')}
$CWControlInstallURL = "$($CWControlInstallURL)&y=Guest&c=$($varCompany)"
if (-not $varSite) {
  $CWControlInstallURL = "$($CWControlInstallURL)&c=&c=&c=&c=&c=&c=&c="
} elseif ($varSite) {
  if ($varSite -match ' ') {$varSite = $varSite.replace(' ','%20')}
  $CWControlInstallURL = "$($CWControlInstallURL)&c=$($varSite)&c=&c=&c=&c=&c=&c="
}
#SETTINGS
$settings = "`r`n===================================`r`n"
$settings += "SC UDF : $($usrUDF)`r`n"
$settings += "SC Site : $($varSite)`r`n"
$settings += "SC Company : $($varCompany)`r`n"
$settings += "SC Thumbprint : $($CWKeyThumbprint)`r`n"
$settings += "SC Install URL : $($CWControlInstallURL)`r`n"
$settings += "SC Base URL : $($ConnectWiseControlBaseUrl)`r`n"
$settings += "===================================`r`n"
logERR 3 "Settings" "$($settings)`r`n$($strLineSeparator)"
#CHECK 'PERSISTENT' FOLDERS
dir-Check
if ($strTask -eq "DEPLOY") {
  logERR 3 "run-Deploy" "Deploying CW Control`r`n$($strLineSeparator)"
  try {
    run-Deploy -erroraction stop
    
  } catch {
    $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
    logERR 3 "run-Deploy" "$($err)`r`n$($strLineSeparator)"
  }
} elseif ($strTask -eq "MONITOR") {
  logERR 3 "run-Monitor" "Monitoring CW Control`r`n$($strLineSeparator)"
  try {
    run-Monitor -erroraction stop
    
  } catch {
    $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
    logERR 3 "run-Monitor" "$($err)`r`n$($strLineSeparator)"
  }
} elseif ($strTask -eq "UPGRADE") {
  logERR 3 "run-Upgrade" "Replacing CW Control`r`n$($strLineSeparator)"
  try {
    run-Upgrade -erroraction stop
    
  } catch {
    $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
    logERR 3 "run-Upgrade" "$($err)`r`n$($strLineSeparator)"
  }
} elseif ($strTask -eq "REMOVE") {
  logERR 3 "run-Remove" "Removing CW Control`r`n$($strLineSeparator)"
  try {
    run-Remove -erroraction stop
    
  } catch {
    $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
    logERR 3 "run-Remove" "$($err)`r`n$($strLineSeparator)"
  }
}
#DATTO OUTPUT
#Stop script execution time calculation
StopClock
#CLEAR LOGFILE
$null | set-content $logPath -force
$finish = (get-date -format "yyyy-MM-dd HH:mm:ss").ToString()
if (-not $script:blnBREAK) {
  if (-not $script:blnWARN) {
    $result = "$($strTask) : Successful : $($finish)"
    $enddiag = "$($result)`r`n$($strLineSeparator)`r`n"
  } elseif ($script:blnWARN) {
    $result = "$($strTask) : Warning : $($finish)"
    $enddiag = "$($result)`r`n$($strLineSeparator)`r`n"
  }
  if ($strTask -eq "DEPLOY") {
    $alert = "- CW Control Deployed"
    $enddiag += "`t- CW Control Deployed`r`n$($strLineSeparator)"
  } elseif ($strTask -eq "MONITOR") {
    $alert = "- Monitoring CW Control"
    $enddiag += "`r`n$($strLineSeparator)"
  } elseif ($strTask -eq "UPGRADE") {
    $alert = "- CW Control Replaced"
    $enddiag += "`t- CW Control Replaced`r`n$($strLineSeparator)"
  } elseif ($strTask -eq "REMOVE") {
    $alert = "- CW Control Removed"
    $enddiag += "`t- CW Control Removed`r`n$($strLineSeparator)"
  }
  logERR 3 "CW_Control" "$($enddiag)"
  #WRITE TO LOGFILE
  "$($script:diag)" | add-content $logPath -force
  write-DRMMAlert "CW_Control : $($result) : $($alert)"
  write-DRMMDiag "$($script:diag)"
  exit 0
} elseif ($script:blnBREAK) {
  #WRITE TO LOGFILE
  $result = "$($strTask) : Execution Failed : $($finish)"
  $enddiag = "$($result)`r`n$($strLineSeparator)`r`n"
  logERR 4 "CW_Control" "$($enddiag)"
  "$($script:diag)" | add-content $logPath -force
  write-DRMMAlert "CW_Control : $($result) : Diagnostics - $($logPath)"
  write-DRMMDiag "$($script:diag)"
  exit 1
}
#END SCRIPT
#------------