# Deploys IPERF command line utility to C:\IT\iperf for testing internet / network connection performance
# Modifications : Christopher Bledsoe - cbledsoe@ipmcomputers.com

#region ----- DECLARATIONS ----
  #VERSION FOR SCRIPT UPDATE
  $strSCR             = "IPERF_Monitor"
  $strVER             = [version]"0.1.0"
  $strREPO            = "RMM"
  $strBRCH            = "dev"
  $strDIR             = "Datto/IPERF"
  $script:diag        = $null
  $script:blnWARN     = $false
  $script:blnBREAK    = $false
  $strOPT             = $env:strTask
  $logPath            = "C:\IT\Log\IPERF_Monitor"
  $strLineSeparator   = "----------------------------------"
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
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - IPERF_Monitor - NO ARGUMENTS PASSED, END SCRIPT`r`n`r`n"
        write-output "$($strLineSeparator)`r`n$($(get-date)) - IPERF_Monitor - NO ARGUMENTS PASSED, END SCRIPT`r`n`r`n"
      }
      2 {                                                         #'ERRRET'=2 - END SCRIPT
        $script:blnBREAK = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - IPERF_Monitor - ($($strModule)) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)`r`n`tEND SCRIPT`r`n$($strLineSeparator)`r`n"
        write-output "$($strLineSeparator)`r`n$($(get-date)) - IPERF_Monitor - ($($strModule)) :"
        write-output "$($strLineSeparator)`r`n`t$($strErr)`r`n`tEND SCRIPT`r`n$($strLineSeparator)`r`n"
      }
      3 {                                                         #'ERRRET'=3
        $script:blnWARN = $false
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - IPERF_Monitor - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
        write-output "$($strLineSeparator)`r`n$($(get-date)) - IPERF_Monitor - $($strModule) :"
        write-output "$($strLineSeparator)`r`n`t$($strErr)"
      }
      default {                                                   #'ERRRET'=4+
        $script:blnBREAK = $false
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - IPERF_Monitor - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
        write-output "$($strLineSeparator)`r`n$($(get-date)) - IPERF_Monitor - $($strModule) :"
        write-output "$($strLineSeparator)`r`n`t$($strErr)"
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

  function download-Files ($file, $dest) {
    $strURL = "https://raw.githubusercontent.com/CW-Khristos/$($strREPO)/$($strBRCH)/$($strDIR)/$($file)"
    try {
      $dldiag = "Downloading File : '$($strURL)'"
      logERR 3 "download-Files" "$($dldiag)`r`n$($strLineSeparator)"
      $web = new-object system.net.webclient
      $dlFile = $web.downloadfile("$($strURL)", "$($dest)\$($file)")
    } catch {
      try {
        $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
        $dldiag = "Web.DownloadFile() - Could not download $($strURL)`r`n$($strLineSeparator)`r`n$($err)"
        logERR 3 "download-Files" "$($dldiag)`r`n$($strLineSeparator)"
        start-bitstransfer -source "$($strURL)" -destination "$($dest)\$($file)" -erroraction stop
      } catch {
        $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
        $dldiag = "`r`nBITS.Transfer() - Could not download $($strURL)`r`n$($strLineSeparator)`r`n$($err)"
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
    if (-not (test-path -path "C:\IT\IPERF")) {
      new-item -path "C:\IT\IPERF" -itemtype directory -force | out-string
    }
  }

  function run-Deploy () {
    #CHECK 'PERSISTENT' FOLDERS
    dir-Check
    $deploydiag = "Checking Local Files"
    # install the executable somewhere we can bank on its presence
    try {
      move-item cygwin1.dll "C:\IT\IPERF" -force -erroraction stop
      move-item iperf3.exe "C:\IT\IPERF" -force -erroraction stop
      # inform the user
      $deploydiag += "`r`n`t - IPERF has been deployed and can be used in location : 'C:\IT\IPERF'"
      logERR 3 "run-Deploy" "$($deploydiag)`r`n$($strLineSeparator)"
    } catch {
      try {
        $deploydiag += "`r`n`t - No Component Attached Files. Downloading from GitHub"
        logERR 3 "run-Deploy" "$($deploydiag)`r`n$($strLineSeparator)"
        download-Files "cygwin1.dll" "C:\IT\IPERF"
        download-Files "iperf3.exe" "C:\IT\IPERF"
        # inform the user
        $deploydiag = " - IPERF has been deployed and can be used in location : 'C:\IT\IPERF'"
        logERR 3 "run-Deploy" "$($deploydiag)`r`n$($strLineSeparator)"
      } catch {
        $deploydiag = "Could Not Download Files"
        logERR 2 "run-Deploy" "$($deploydiag)`r`n$($strLineSeparator)"
      }
    }
  }

  function run-Monitor () {
    #CHECK PATH EXISTENCE
    $result = test-path -path "C:\IT\IPERF"
    if (-not $result) {                 #PATH DOES NOT EXIST, DEPLOY IPERF
      run-Deploy
    } elseif ($result) {                #PATH EXISTS
      #CHECK EXECUTABLE AND DLL
      $result = test-path -path "C:\IT\IPERF\iperf3.exe"
      if (-not $result) {               #FILE DOES NOT EXIST, DEPLOY EXECUTABLE
        $err = "File Not Found : 'C:\IT\IPERF\iperf3.exe' : Re-Acquiring"
        logERR 3 "run-Monitor" "$($err)`r`n$($strLineSeparator)"
        run-Deploy
      } elseif ($result) {              #FILE EXISTS
        $err = "File : 'C:\IT\IPERF\iperf3.exe' : Present"
        logERR 3 "run-Monitor" "$($err)`r`n$($strLineSeparator)"
      }
      $result = test-path -path "C:\IT\IPERF\cygwin1.dll"
      if (-not $result) {               #FILE EXISTS
        $err = "File Not Found : 'C:\IT\IPERF\cygwin1.dll' : Re-Acquiring"
        logERR 3 "run-Monitor" "$($err)`r`n$($strLineSeparator)"
        run-Deploy
      } elseif ($result) {              #FILE EXISTS
        $err = "File : 'C:\IT\IPERF\cygwin1.dll' : Present"
        logERR 3 "run-Monitor" "$($err)`r`n$($strLineSeparator)"
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
    #CHECK IF IPERF IS RUNNING
    $process = tasklist | findstr /B "iperf3"
    if ($process) {                   #IPERF RUNNING
      $running = $true
      $result = taskkill /IM "iperf3" /F
    } elseif (-not $process) {        #IPERF NOT RUNNING
      $running = $false
    }
    #REMOVE FILES
    try {
      $remdiag = "Removing IPERF Files`r`n$($strLineSeparator)"
      remove-item -path "C:\IT\IPERF" -recurse -force -erroraction stop
      $remdiag += "`r`n`tFiles Successfully Removed`r`n$($strLineSeparator)"
      logERR 3 "run-Remove" "$($remdiag)"
    } catch {
      if ($_.exception -match "ItemNotFoundException") {
        $remdiag += "`r`n`tNOT PRESENT : C:\IT\IPERF`r`n$($strLineSeparator)"
      } elseif ($_.exception -notmatch "ItemNotFoundException") {
        $err = "`r`nERROR : `r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
        $remdiag += "`r`n`tCOULD NOT REMOVE : C:\IT\IPERF`r`n$($err)`r`n$($strLineSeparator)"
      }
      logERR 4 "run-Remove" "$($remdiag)"
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
if ($strOPT -eq "DEPLOY") {
  try {
    logERR 3 "$($strOPT)" "Deploying IPERF Files`r`n$($strLineSeparator)"
    run-Deploy -erroraction stop
    
  } catch {
    
  }
} elseif ($strOPT -eq "MONITOR") {
  try {
    logERR 3 "$($strOPT)" "Monitoring IPERF Files`r`n$($strLineSeparator)"
    run-Monitor -erroraction stop
    
  } catch {
    
  }
} elseif ($strOPT -eq "UPGRADE") {
  try {
    logERR 3 "$($strOPT)" "Replacing IPERF Files`r`n$($strLineSeparator)"
    run-Upgrade -erroraction stop
    
  } catch {
    
  }
} elseif ($strOPT -eq "REMOVE") {
  try {
    logERR 3 "$($strOPT)" "Removing IPERF Files`r`n$($strLineSeparator)"
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
    $enddiag = "$($strOPT) : Success : $($finish)"
    logERR 3 "$($strOPT)" "$($enddiag)`r`n$($strLineSeparator)"
    "$($script:diag)" | add-content $logPath -force
    write-DRMMAlert "$($strOPT) : Successful : Diagnostics - $($logPath) : $($finish)"
    write-DRMMDiag "$($script:diag)"
    exit 0
  } elseif ($script:blnWARN) {
    #WRITE TO LOGFILE
    $enddiag = "$($strOPT) : Warning : $($finish)"
    logERR 3 "$($strOPT)" "$($enddiag)`r`n$($strLineSeparator)"
    "$($script:diag)" | add-content $logPath -force
    write-DRMMAlert "$($strOPT) : Warning : Diagnostics - $($logPath) : $($finish)"
    write-DRMMDiag "$($script:diag)"
    exit 1
  }
} elseif ($script:blnBREAK) {
  #WRITE TO LOGFILE
  $enddiag = "$($strOPT) : Failed : $($finish)"
  logERR 4 "$($strOPT)" "$($enddiag)`r`n$($strLineSeparator)"
  "$($script:diag)" | add-content $logPath -force
  write-DRMMAlert "$($strOPT) : Failure : Diagnostics - $($logPath) : $($finish)"
  write-DRMMDiag "$($script:diag)"
  $script:diag = $null
  exit 1
}
#END SCRIPT
#------------