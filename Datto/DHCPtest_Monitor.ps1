#region ----- DECLARATIONS ----
  #VERSION FOR SCRIPT UPDATE
  $strSCR           = "DHCPtest_Monitor"
  $strVER           = [version]"0.1.0"
  $strREPO          = "RMM"
  $strBRCH          = "dev"
  $strDIR           = "Datto"
  $script:diag      = $null
  $script:blnWARN   = $false
  $script:blnBREAK  = $false
  $strOpt           = $env:strTask
  $logPath          = "C:\IT\Log\DHCPtest_Monitor"
  $strLineSeparator = "--------------------------"
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

  function StopClock {
    #Stop script execution time calculation
    $script:sw.Stop()
    $Days = $sw.Elapsed.Days
    $Hours = $sw.Elapsed.Hours
    $Minutes = $sw.Elapsed.Minutes
    $Seconds = $sw.Elapsed.Seconds
    $Milliseconds = $sw.Elapsed.Milliseconds
    $ScriptStopTime = (Get-Date).ToString('yyyy-MM-dd hh:mm:ss')
    write-output "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds"
    $script:diag += "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
  }

  function logERR ($intSTG, $strModule, $strErr) {
    $script:blnWARN = $true
    #CUSTOM ERROR CODES
    switch ($intSTG) {
      1 {                                                         #'ERRRET'=1 - NOT ENOUGH ARGUMENTS, END SCRIPT
        $script:blnBREAK = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - DHCPtest_Monitor - NO ARGUMENTS PASSED, END SCRIPT`r`n$($strLineSeparator)`r`n"
        write-output "$($strLineSeparator)`r`n$($(get-date)) - DHCPtest_Monitor - NO ARGUMENTS PASSED, END SCRIPT`r`n$($strLineSeparator)`r`n" -foregroundcolor red
      }
      2 {                                                         #'ERRRET'=2 - END SCRIPT
        $script:blnBREAK = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - DHCPtest_Monitor - ($($strModule)) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n$($strLineSeparator)`r`n"
        write-output "$($strLineSeparator)`r`n$($(get-date)) - DHCPtest_Monitor - ($($strModule)) :" -foregroundcolor red
        write-output "$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n$($strLineSeparator)`r`n" -foregroundcolor red
      }
      3 {                                                         #'ERRRET'=3
        $script:blnWARN = $false
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - DHCPtest_Monitor - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)`r`n$($strLineSeparator)`r`n"
        write-output "$($strLineSeparator)`r`n$($(get-date)) - DHCPtest_Monitor - $($strModule) :" -foregroundcolor yellow
        write-output "$($strLineSeparator)`r`n`t$($strErr)`r`n$($strLineSeparator)`r`n" -foregroundcolor yellow
      }
      default {                                                   #'ERRRET'=4+
        $script:blnBREAK = $false
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - DHCPtest_Monitor - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)`r`n$($strLineSeparator)`r`n"
        write-output "$($strLineSeparator)`r`n$($(get-date)) - DHCPtest_Monitor - $($strModule) :" -foregroundcolor yellow
        write-output "$($strLineSeparator)`r`n`t$($strErr)`r`n$($strLineSeparator)`r`n" -foregroundcolor red
      }
    }
  }

  function chkAU {
    param (
      $ver, $repo, $brch, $dir, $scr
    )
    $blnXML = $true
    $xmldiag = $null
    #RETRIEVE VERSION XML FROM GITHUB
    $xmldiag += "Loading : '$($strREPO)/$($strBRCH)' Version XML`r`n"
    write-output "Loading : '$($strREPO)/$($strBRCH)' Version XML" -foregroundcolor yellow
    $srcVER = "https://raw.githubusercontent.com/CW-Khristos/$($strREPO)/$($strBRCH)/Datto/version.xml"
    try {
      $verXML = New-Object System.Xml.XmlDocument
      $verXML.Load($srcVER)
    } catch {
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
      $xmldiag += "XML.Load() - Could not open $($srcVER)`r`n$($err)`r`n"
      write-output "XML.Load() - Could not open $($srcVER)`r`n$($err)" -foregroundcolor red
      try {
        $web = new-object system.net.webclient
        [xml]$verXML = $web.DownloadString($srcVER)
      } catch {
        $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
        $xmldiag += "Web.DownloadString() - Could not download $($srcVER)`r`n$($err)`r`n"
        write-output "Web.DownloadString() - Could not download $($srcVER)`r`n$($err)" -foregroundcolor red
        try {
          start-bitstransfer -erroraction stop -source $srcVER -destination "C:\IT\Scripts\version.xml"
          [xml]$verXML = "C:\IT\Scripts\version.xml"
        } catch {
          $blnXML = $false
          $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
          $xmldiag += "BITS.Transfer() - Could not download $($srcVER)`r`n$($err)`r`n"
          write-output "BITS.Transfer() - Could not download $($srcVER)`r`n$($err)`r`n" -foregroundcolor red
        }
      }
    }
    #READ VERSION XML DATA INTO NESTED HASHTABLE FOR LATER USE
    try {
      if (-not $blnXML) {
        write-output $blnXML
      } elseif ($blnXML) {
        foreach ($objSCR in $verXML.SCRIPTS.ChildNodes) {
          if ($objSCR.name -match $strSCR) {
            #CHECK LATEST VERSION
            $xmldiag += "`r`n`t$($strLineSeparator)`r`n`t - CHKAU : $($strVER) : GitHub - $($strBRCH) : $($objSCR.innertext)`r`n"
            write-output "`t$($strLineSeparator)`r`n`t - CHKAU : $($strVER) : GitHub - $($strBRCH) : $($objSCR.innertext)"
            if ([version]$objSCR.innertext -gt $strVER) {
              $xmldiag += "`t`t - UPDATING : $($objSCR.name) : $($objSCR.innertext)`r`n"
              write-output "`t`t - UPDATING : $($objSCR.name) : $($objSCR.innertext)`r`n"
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
              write-output "`t`t - RE-EXECUTING : $($objSCR.name) : $($objSCR.innertext)`r`n"
              $output = C:\Windows\System32\cmd.exe "/C powershell -executionpolicy bypass -file `"C:\IT\Scripts\$($strSCR)_$($objSCR.innertext).ps1`""
              foreach ($line in $output) {$stdout += "$($line)`r`n"}
              $xmldiag += "`t`t - StdOut : $($stdout)`r`n`t`t$($strLineSeparator)`r`n"
              write-output "`t`t - StdOut : $($stdout)`r`n`t`t$($strLineSeparator)"
              $xmldiag += "`t`t - CHKAU COMPLETED : $($objSCR.name) : $($objSCR.innertext)`r`n`t$($strLineSeparator)`r`n"
              write-output "`t`t - CHKAU COMPLETED : $($objSCR.name) : $($objSCR.innertext)`r`n`t$($strLineSeparator)"
              $script:blnBREAK = $true
            } elseif ([version]$objSCR.innertext -le $strVER) {
              $xmldiag += "`t`t - NO UPDATE : $($objSCR.name) : $($objSCR.innertext)`r`n`t$($strLineSeparator)`r`n"
              write-output "`t`t - NO UPDATE : $($objSCR.name) : $($objSCR.innertext)`r`n`t$($strLineSeparator)"
            }
            break
          }
        }
      }
      $script:diag += "$($xmldiag)"
      $xmldiag = $null
    } catch {
      $script:blnBREAK = $false
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
      $xmldiag += "Error reading Version XML : $($srcVER)`r`n$($err)`r`n"
      write-output "Error reading Version XML : $($srcVER)`r`n$($err)"
      $script:diag += "$($xmldiag)"
      $xmldiag = $null
    }
  } ## chkAU

  function download-Files ($file) {
    $strURL = "https://raw.githubusercontent.com/CW-Khristos/$($strREPO)/$($strBRCH)/$($strDIR)/$($file)"
    try {
      $web = new-object system.net.webclient
      $dlFile = $web.downloadfile($strURL, "C:\IT\DHCPtest\$($file)")
    } catch {
      $dldiag = "Web.DownloadFile() - Could not download $($strURL)`r`n$($strLineSeparator)`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n"
      write-output "Web.DownloadFile() - Could not download $($strURL)" -foregroundcolor red
      logERR 3 "download-Files" "$($dldiag)"
      try {
        start-bitstransfer -source $strURL -destination "C:\IT\DHCPtest\$($file)" -erroraction stop
      } catch {
        $dldiag = "BITS.Transfer() - Could not download $($strURL)`r`n$($strLineSeparator)`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n"
        write-output "BITS.Transfer() - Could not download $($strURL)" -foregroundcolor red
        logERR 2 "download-Files" "$($dldiag)"
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
    if (-not (test-path -path "C:\IT\DHCPtest")) {
      new-item -path "C:\IT\DHCPtest" -itemtype directory -force | out-string
    }
  }

  function run-Deploy () {
    #CHECK 'PERSISTENT' FOLDERS
    dir-Check
    # install the executable somewhere we can bank on its presence
    try {
      move-item dhcptest-0.8-win64.exe "C:\IT\DHCPtest" -force -erroraction stop
      # inform the user
      $deploydiag = "`r`n`t - DHCPtest has been deployed and can be used in location : 'C:\IT\DHCPtest'"
      logERR 3 "run-Deploy" "$($deploydiag)`r`n$($strLineSeparator)"
    } catch {
      try {
        $deploydiag += "`r`n`t - No Component Attached Files. Downloading from GitHub"
        logERR 3 "run-Deploy" "$($deploydiag)`r`n$($strLineSeparator)"
        download-Files "dhcptest-0.8-win64.exe"
        # inform the user
        $deploydiag = " - DHCPtest has been deployed and can be used in location : 'C:\IT\DHCPtest'"
        logERR 3 "run-Deploy" "$($deploydiag)`r`n$($strLineSeparator)"
      } catch {
        $deploydiag += "`r`n`tCould Not Download Files`r`n"
        logERR 2 "run-Deploy" "$($deploydiag)`r`n$($strLineSeparator)"
      }
    }
  }

  function run-Monitor () {
    #CHECK PATH EXISTENCE
    $result = test-path -path "C:\IT\DHCPtest"
    if (-not $result) {                 #PATH DOES NOT EXIST, DEPLOY DHCPtest
      run-Deploy
    } elseif ($result) {                #PATH EXISTS
      #CHECK EXECUTABLE
      $result = test-path -path "C:\IT\DHCPtest\dhcptest-0.8-win64.exe"
      if (-not $result) {               #FILE DOES NOT EXIST, DEPLOY EXECUTABLE
        $err = "File Not Found : 'C:\IT\DHCPtest\dhcptest-0.8-win64.exe' : Re-Acquiring`r`n$($strLineSeparator)"
        logERR 3 "run-Monitor" "$($err)"
        run-Deploy
      } elseif ($result) {              #FILE EXISTS
        $err = "File : 'C:\IT\DHCPtest\dhcptest-0.8-win64.exe' : Present`r`n$($strLineSeparator)"
        logERR 3 "run-Monitor" "$($err)"
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
    #CHECK IF DHCPtest IS RUNNING
    $process = tasklist | findstr /B "dhcptest-0.8-win64.exe"
    if ($process) {                   #DHCPtest RUNNING
      $running = $true
      $result = taskkill /IM "dhcptest-0.8-win64.exe" /F
    } elseif (-not $process) {        #DHCPtest NOT RUNNING
      $running = $false
    }
    #REMOVE FILES
    $remdiag = "Removing DHCPtest Files`r`n$($strLineSeparator)`r`n"
    try {
      remove-item -path "C:\IT\DHCPtest" -recurse -force -erroraction stop
      $remdiag += "`tFiles Successfully Removed`r`n`t$($strLineSeparator)"
      logERR 3 "run-Remove" "$($remdiag)"
    } catch {
      if ($_.exception -match "ItemNotFoundException") {
        $remdiag += "NOT PRESENT : C:\IT\DHCPtest`r`n$($strLineSeparator)"
      } elseif ($_.exception -notmatch "ItemNotFoundException") {
        $err = "ERROR : `r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
        $remdiag += "COULD NOT REMOVE : C:\IT\DHCPtest`r`n$($err)`r`n$($strLineSeparator)"
      }
      logERR 4 "run-Remove" "$($remdiag)"
    }
  }
#endregion ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
clear-host
#Start script execution time calculation
$ScrptStartTime = (get-date).ToString('yyyy-MM-dd hh:mm:ss')
$script:sw = [Diagnostics.Stopwatch]::StartNew()
#CHECK 'PERSISTENT' FOLDERS
dir-Check
if ($strOpt.toupper() -eq "DEPLOY") {
  logERR 3 "$($strOpt)" "Deploying DHCPtest Files`r`n$($strLineSeparator)"
  try {
    run-Deploy -erroraction stop
    
  } catch {
    
  }
} elseif ($strOpt.toupper() -eq "MONITOR") {
  logERR 3 "$($strOpt)" "Monitoring DHCPtest Files`r`n$($strLineSeparator)"
  try {
    run-Monitor -erroraction stop
    
  } catch {
    
  }
} elseif ($strOpt.toupper() -eq "UPGRADE") {
  logERR 3 "$($strOpt)" "Replacing DHCPtest Files`r`n$($strLineSeparator)"
  try {
    run-Upgrade -erroraction stop
    
  } catch {
    
  }
} elseif ($strOpt.toupper() -eq "REMOVE") {
  logERR 3 "$($strOpt)" "Removing DHCPtest Files`r`n$($strLineSeparator)"
  try {
    run-Remove -erroraction stop
    
  } catch {
    
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
    $enddiag = "Execution Successful : $($finish)"
    logERR 3 "DHCPtest_Monitor" "$($enddiag)"
    "$($script:diag)" | add-content $logPath -force
    write-DRMMAlert "DHCPtest_Monitor : $($strOpt) Successful : Diagnostics - $($logPath) : $($finish)"
    write-DRMMDiag "$($script:diag)"
    exit 0
  } elseif ($script:blnWARN) {
    #WRITE TO LOGFILE
    $enddiag = "Execution Completed with Warnings : $($finish)"
    logERR 3 "DHCPtest_Monitor" "$($enddiag)"
    "$($script:diag)" | add-content $logPath -force
    write-DRMMAlert "DHCPtest_Monitor : $($strOpt) Warning : Diagnostics - $($logPath) : $($finish)"
    write-DRMMDiag "$($script:diag)"
    exit 1
  }
} elseif ($script:blnBREAK) {
  #WRITE TO LOGFILE
  $enddiag = "Execution Failed : $($finish)"
  logERR 4 "DHCPtest_Monitor" "$($enddiag)"
  "$($script:diag)" | add-content $logPath -force
  write-DRMMAlert "DHCPtest_Monitor : $($strOpt) Failure : Diagnostics - $($logPath) : $($finish)"
  write-DRMMDiag "$($script:diag)"
  $script:diag = $null
  exit 1
}
#END SCRIPT
#------------