# Author : Christopher Bledsoe - cbledsoe@ipmcomputers.com

#region ----- DECLARATIONS ----
  $script:diag = $null
  $script:blnWARN = $false
  $script:blnBREAK  = $false
  #VERSION FOR SCRIPT UPDATE
  $strREPO          = "RMM"
  $strBRCH          = "dev"
  $strDIR           = "Datto\NAble%20Backup"
  $strVER           = [version]"0.1.0"
  $strSCR           = "Monitor_MSPBackup"
  $strOperation     = "Monitor" #"$($env:strTask)"
  $strDevice        = "$($env:computername)"
  $strUID           = "$($env:strUID)"
  $strInstallPwd    = "$($env:strInstallPwd)"
  $strEncryptKey    = "$($env:strEncryptKey)"
  $strPassphrase    = "$($env:strPassphrase)"
  $logPath          = "C:\IT\Log\Monitor_MSPBackup"
  $strLineSeparator = "----------------------------------"
  #https://cdn.cloudbackup.management/maxdownloads/mxb-windows-x86_x64.exe
  #mxb-windows-x86_x64.exe -silent -user "support_win_jab67v" -password "Secureh0982b2bxgt" -passphrase "914hahdgf-0000-example"
  #https://cdn.cloudbackup.management/maxdownloads/mxb-macosx-x86_64.zip
  #sudo installer -pkg mxb-17.7.0.17249-macosx-x86_64.pkg -target
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

  function StopClock {
    #Stop script execution time calculation
    $script:sw.Stop()
    $Days = $sw.Elapsed.Days
    $Hours = $sw.Elapsed.Hours
    $Minutes = $sw.Elapsed.Minutes
    $Seconds = $sw.Elapsed.Seconds
    $Milliseconds = $sw.Elapsed.Milliseconds
    $ScriptStopTime = (Get-Date).ToString('dd-MM-yyyy hh:mm:ss')
    write-host "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds"
    $script:diag += "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
  }

  function logERR ($intSTG, $strModule, $strErr) {
    $script:blnWARN = $true
    #CUSTOM ERROR CODES
    switch ($intSTG) {
      1 {                                                         #'ERRRET'=1 - NOT ENOUGH ARGUMENTS, END SCRIPT
        $script:blnBREAK = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - Monitor_MSPBackup - NO ARGUMENTS PASSED, END SCRIPT`r`n`r`n"
        write-host "$($strLineSeparator)`r`n$($(get-date)) - Monitor_MSPBackup - NO ARGUMENTS PASSED, END SCRIPT`r`n`r`n" -foregroundcolor red
      }
      2 {                                                         #'ERRRET'=2 - END SCRIPT
        $script:blnBREAK = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - Monitor_MSPBackup - ($($strModule)) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)`r`n`tEND SCRIPT`r`n$($strLineSeparator)"
        write-host "$($strLineSeparator)`r`n$($(get-date)) - Monitor_MSPBackup - ($($strModule)) :" -foregroundcolor red
        write-host "$($strLineSeparator)`r`n`t$($strErr)`r`n`tEND SCRIPT`r`n$($strLineSeparator)" -foregroundcolor red
      }
      3 {                                                         #'ERRRET'=3
        $script:blnWARN = $false
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - Monitor_MSPBackup - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
        write-host "$($strLineSeparator)`r`n$($(get-date)) - Monitor_MSPBackup - $($strModule) :" -foregroundcolor yellow
        write-host "$($strLineSeparator)`r`n`t$($strErr)" -foregroundcolor yellow
      }
      default {                                                   #'ERRRET'=4+
        $script:blnBREAK = $false
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - Monitor_MSPBackup - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
        write-host "$($strLineSeparator)`r`n$($(get-date)) - Monitor_MSPBackup - $($strModule) :" -foregroundcolor yellow
        write-host "$($strLineSeparator)`r`n`t$($strErr)" -foregroundcolor red
      }
    }
  }

  function chkAU {
    param (
      $ver, $repo, $brch, $dir, $scr
    )
    $blnXML = $true
    #RETRIEVE VERSION XML FROM GITHUB
    $srcVER = "https://raw.githubusercontent.com/CW-Khristos/$($strREPO)/$($strBRCH)/Datto/version.xml"
    $xmldiag = "Loading : '$($strREPO)/$($strBRCH)' Version XML`r`n$($strLineSeparator)"
    logERR 3 "chkAU" "$($xmldiag)"
    try {
      $verXML = New-Object System.Xml.XmlDocument
      $verXML.Load($srcVER)
    } catch {
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
      $xmldiag = "XML.Load() - Could not open $($srcVER)`r`n$($err)`r`n"
      try {
        $web = new-object system.net.webclient
        [xml]$verXML = $web.DownloadString($srcVER)
      } catch {
        $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
        $xmldiag += "Web.DownloadString() - Could not download $($srcVER)`r`n$($err)`r`n"
        try {
          start-bitstransfer -erroraction stop -source $srcVER -destination "C:\IT\Scripts\version.xml"
          [xml]$verXML = "C:\IT\Scripts\version.xml"
        } catch {
          $blnXML = $false
          $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
          $xmldiag += "BITS.Transfer() - Could not download $($srcVER)`r`n$($err)`r`n"
        }
      }
    }
    logERR 3 "chkAU" "$($xmldiag)`r`n$($strLineSeparator)"
    #READ VERSION XML DATA INTO NESTED HASHTABLE FOR LATER USE
    try {
      if ($blnXML) {
        foreach ($objSCR in $verXML.SCRIPTS.ChildNodes) {
          if ($objSCR.name -match $strSCR) {
            #CHECK LATEST VERSION
            $xmldiag = "`t - CHKAU : $($strVER) : GitHub - $($strBRCH) : $($objSCR.innertext)`r`n"
            if ([version]$objSCR.innertext -gt $strVER) {
              $xmldiag += "`t`t - UPDATING : $($objSCR.name) : $($objSCR.innertext)`r`n"
              #REMOVE PREVIOUS COPIES OF SCRIPT
              if (test-path -path "C:\IT\Scripts\$($strSCR)_$($strVER).ps1") {
                remove-item -path "C:\IT\Scripts\$($strSCR)_$($strVER).ps1" -force -erroraction stop
              }
              #DOWNLOAD LATEST VERSION OF ORIGINAL SCRIPT
              if (($null -eq $strDIR) -or ($strDIR -eq "")) {
                $strURL = "https://raw.githubusercontent.com/CW-Khristos/$($strREPO)/$($strBRCH)/$($strSCR)_$($objSCR.innertext).ps1"
              } elseif (($null -ne $strDIR) -and ($strDIR -ne "")) {
                $strURL = "https://raw.githubusercontent.com/CW-Khristos/$($strREPO)/$($strBRCH)/$($strDIR)/$($strSCR)_$($objSCR.innertext).ps1"
              }
              Invoke-WebRequest "$($strURL)" | Select-Object -ExpandProperty Content | Out-File "C:\IT\Scripts\$($strSCR)_$($objSCR.innertext).ps1"
              #RE-EXECUTE LATEST VERSION OF SCRIPT
              $xmldiag += "`t`t - RE-EXECUTING : $($objSCR.name) : $($objSCR.innertext)`r`n`r`n"
              $output = C:\Windows\System32\cmd.exe "/C powershell -executionpolicy bypass -file `"C:\IT\Scripts\$($strSCR)_$($objSCR.innertext).ps1`""
              foreach ($line in $output) {$stdout += "$($line)`r`n"}
              $xmldiag += "`t`t - StdOut : $($stdout)`r`n`t`t$($strLineSeparator)`r`n"
              $xmldiag += "`t`t - CHKAU COMPLETED : $($objSCR.name) : $($objSCR.innertext)`r`n`t`t$($strLineSeparator)`r`n"
              $script:blnBREAK = $true
            } elseif ([version]$objSCR.innertext -le $strVER) {
              $xmldiag += "`t`t - NO UPDATE : $($objSCR.name) : $($objSCR.innertext)`r`n`t`t$($strLineSeparator)`r`n"
            }
            break
          }
        }
      }
      logERR 3 "chkAU" "$($xmldiag)`r`n$($strLineSeparator)"
    } catch {
      $script:blnBREAK = $false
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
      $xmldiag = "Error reading Version XML : $($srcVER)`r`n$($err)"
      logERR 3 "chkAU" "$($xmldiag)`r`n$($strLineSeparator)"
    }
  } ## chkAU

  function download-Files ($url, $dest, $file) {
    #"https://raw.githubusercontent.com/CW-Khristos/$($strREPO)/$($strBRCH)/$($strDIR)/$($file)"
    try {
      $dldiag = "Downloading File : '$($url)'"
      $web = new-object system.net.webclient
      $dlFile = $web.downloadfile("$($url)", "$($dest)\$($file)")
      logERR 3 "download-Files" "$($dldiag)`r`n$($strLineSeparator)"
    } catch {
      $dldiag += "`r`nWeb.DownloadFile() - Could not download $($url)`r`n$($strLineSeparator)`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
      try {
        start-bitstransfer -source "$($url)" -destination "$($dest)\$($file)" -erroraction stop
        logERR 3 "download-Files" "$($dldiag)`r`n$($strLineSeparator)"
      } catch {
        $dldiag += "`r`nBITS.Transfer() - Could not download $($url)`r`n$($strLineSeparator)`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
        logERR 2 "download-Files" "$($dldiag)`r`n$($strLineSeparator)"
      }
    }
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
    $deploydiag = "Checking Local Files"
    # install the executable somewhere we can bank on its presence
    try {
      #move-item cygwin1.dll "C:\IT\IPERF" -force -erroraction stop
      move-item iperf3.exe "C:\IT\IPERF" -force -erroraction stop
      # inform the user
      #$deploydiag = "`r`n`t - IPERF has been deployed and can be used in location : 'C:\IT\IPERF'"
      logERR 3 "run-Deploy" "$($deploydiag)`r`n$($strLineSeparator)"
    } catch {
      try {
        #$deploydiag += "`r`n`t - No Component Attached Files. Downloading from GitHub"
        #logERR 3 "run-Deploy" "$($deploydiag)"
        #download-Files "cygwin1.dll" "C:\IT\IPERF"
        #download-Files "iperf3.exe" "C:\IT\IPERF"
        # inform the user
        #$deploydiag = " - IPERF has been deployed and can be used in location : 'C:\IT\IPERF'"
        logERR 3 "run-Deploy" "$($deploydiag)`r`n$($strLineSeparator)"
      } catch {
        $deploydiag += "`r`n`tCould Not Download Files`r`n"
        logERR 2 "run-Deploy" "$($deploydiag)`r`n$($strLineSeparator)"
      }
    }
  }

  function run-Monitor () {
    #CHECK PATH EXISTENCE
    $result = get-itemproperty -path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Backup Manager" -name "QuietUninstallString"
    if (-not $result) {                 #PATH DOES NOT EXIST, DEPLOY MSP BACKUPS
      $mondiag = "MSP Backup Install Not Detected : Re-Deploying"
      logERR 3 "run-Monitor" "$($mondiag)`r`n$($strLineSeparator)"
      run-Deploy
    } elseif ($result) {                #PATH EXISTS
      #CHECK SERVICE
      $mondiag = "MSP Backup Installed : Checking Service"
      logERR 3 "run-Monitor" "$($mondiag)`r`n$($strLineSeparator)"
      $service = get-service -name "Backup Service Controller"
      if (-not $service) {              #SERVICE DOES NOT EXIST, DEPLOY MSP BACKUPS
        $mondiag = "Service Does Not Exist : 'Backup Service Controller' : Re-Deploying"
        logERR 3 "run-Monitor" "$($mondiag)`r`n$($strLineSeparator)"
        run-Deploy
      } elseif ($service) {             #SERVICE EXISTS
        $intTries = 0
        $mondiag = "Service Exists : 'Backup Service Controller' : Continuing"
        logERR 3 "run-Monitor" "$($mondiag)`r`n$($strLineSeparator)"
        if ($service.status -ne "Running") {
          while (($intTries -lt 3) -and ($service.status -ne "Running")) {
            $intTries += 1
            $mondiag = "Service Not Started : 'Backup Service Controller' : Attempting Restart"
            logERR 4 "run-Monitor" "$($mondiag)`r`n$($strLineSeparator)"
            $service = start-service -name "$($service.name)" -passthru
            if ($service.status -eq "Running") {$running = $true}
          }
        }
        if ($service.status -eq "Running") {
          $running = $true
          $mondiag = "`r`n`tBackup Service Controller Started"
          logERR 3 "run-Monitor" "$($mondiag)`r`n$($strLineSeparator)"
        }
      }
      if ($running) {
        $script:blnWARN = $false
        $script:blnBREAK = $false
      } elseif (-not $running) {
        $script:blnWARN = $true
        $script:blnBREAK = $true
      }
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
    try {
      #CHECK IF MSP BACKUPS ARE RUNNING
      $intTries = 0
      $running = $true
      $remdiag = "Uninstalling Backup Manager`r`n$($strLineSeparator)"
      $remdiag += "`r`nStopping Backup Service Controller service`r`n$($strLineSeparator)"
      $service = get-service -name "Backup Service Controller"
      if (($service) -and ($service.status -eq "Stopped")) {
        $running = $false
      } elseif (($service) -and ($service.status -eq "Running")) {
        while (($intTries -lt 3) -and ($result.status -ne "Stopped")) {
          $intTries += 1
          $result = stop-service -name "$($service.name)" -passthru -force
          if ($result.status -eq "Stopped") {$running = $false}
          $remdiag += "`r`n`tBackup Service Controller Stopped"
          logERR 3 "run-Remove" "$($remdiag)`r`n$($strLineSeparator)"
        }
        if ($running) {                                           #BACKUPS RUNNING
          $intTries = 0
          $remdiag = "`r`nBackup Service Controller Still Running; Attempting to kill processes"
          logERR 3 "run-Remove" "$($remdiag)`r`n$($strLineSeparator)"
          $process = tasklist | findstr /B "BackupFP"
          if ($process) {$result = taskkill /IM "BackupFP.exe" /F}
          $process = tasklist | findstr /B "ProcessController"
          if ($process) {$result = taskkill /IM "ProcessController.exe" /F}
          $service = stop-service -name "$($service.name)" -passthru -force
          while (($intTries -lt 3) -and ($service.status -ne "Stopped")) {
            $intTries += 1
            $service = stop-service -name "$($service.name)" -passthru -force
            if ($service.status -eq "Stopped") {$running = $false}
          }
        }
      }
      #EXECUTE UNINSTALL
      if (-not $running) {
        try {
          $uninstall = get-itemproperty -path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Backup Manager" -name "QuietUninstallString"
          $uninstall = $uninstall.QuietUninstallString -split " uninstall "
          $output = get-processoutput -filename "$($uninstall[0])" -args "uninstall $($uninstall[1])"
          $remdiag += "`r`n`t- StdOut : $($output.standardoutput)`r`n`t- StdErr : $($output.standarderror)"
          $remdiag += "`r`n`tBackup Manager Successfully Uninstalled"
          logERR 3 "run-Remove" "$($remdiag)`r`n$($strLineSeparator)"
        } catch {
          $script:blnBREAK = $true
          $err = "ERROR :`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
          $remdiag += "`r`n`tCOULD NOT UNINSTALL BACKUP MANAGER :`r`n$($err)"
          logERR 2 "run-Remove" "$($remdiag)`r`n$($strLineSeparator)"
        }
      } elseif ($running) {
        $script:blnBREAK = $true
        $remdiag += "COULD NOT STOP BACKUP MANAGER : ENDING"
        logERR 2 "run-Remove" "$($remdiag)`r`n$($strLineSeparator)"
      }
    } catch {
      $script:blnBREAK = $true
      $err = "ERROR :`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
      $remdiag += "COULD NOT UNINSTALL BACKUP MANAGER :`r`n$($err)"
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
#CHECK 'PERSISTENT' FOLDERS
dir-Check
switch ($strOperation.toupper()) {
  "DEPLOY" {
    logERR 3 "$($strOperation)" "Deploying MSP Backups`r`n$($strLineSeparator)"
    try {
      run-Deploy -erroraction stop
      
    } catch {
      
    }
  }
  "MONITOR" {
    logERR 3 "$($strOperation)" "Monitoring MSP Backups`r`n$($strLineSeparator)"
    try {
      run-Monitor -erroraction stop
      
    } catch {
      
    }
  }
  "UPGRADE" {
    logERR 3 "$($strOperation)" "Replacing MSP Backups`r`n$($strLineSeparator)"
    try {
      run-Upgrade -erroraction stop
      
    } catch {
      
    }
  }
  "REMOVE" {
    logERR 3 "$($strOperation)" "Removing MSP Backups`r`n$($strLineSeparator)"
    try {
      run-Remove -erroraction stop
      
    } catch {
      
    }
  }
}
#DATTO OUTPUT
#Stop script execution time calculation
StopClock
#CLEAR LOGFILE
$null | set-content $logPath -force
$finish = "$((Get-Date).ToString('yyyy-MM-dd hh:mm:ss'))"
if (-not $script:blnBREAK) {
  if (-not $script:blnWARN) {
    #WRITE TO LOGFILE
    $enddiag = "$($strOperation) : Success : $($finish)`r`n$($strLineSeparator)"
    logERR 3 "$($strOperation)" "$($enddiag)"
    "$($script:diag)" | add-content $logPath -force
    write-DRMMAlert "$($strOperation) : Successful : Diagnostics - $($logPath) : $($finish)"
    write-DRMMDiag "$($script:diag)"
    exit 0
  } elseif ($script:blnWARN) {
    #WRITE TO LOGFILE
    $enddiag = "$($strOperation) : Warning : $($finish)`r`n$($strLineSeparator)"
    logERR 3 "$($strOperation)" "$($enddiag)"
    "$($script:diag)" | add-content $logPath -force
    write-DRMMAlert "$($strOperation) : Warning : Diagnostics - $($logPath) : $($finish)"
    write-DRMMDiag "$($script:diag)"
    exit 1
  }
} elseif ($script:blnBREAK) {
  #WRITE TO LOGFILE
  $enddiag = "$($strOperation) : Failed : $($finish)`r`n$($strLineSeparator)"
  logERR 4 "$($strOperation)" "$($enddiag)"
  "$($script:diag)" | add-content $logPath -force
  write-DRMMAlert "$($strOperation) : Failure : Diagnostics - $($logPath) : $($finish)"
  write-DRMMDiag "$($script:diag)"
  $script:diag = $null
  exit 1
}
#END SCRIPT
#------------