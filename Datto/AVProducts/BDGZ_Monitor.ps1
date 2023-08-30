#REGION ----- DECLARATIONS ----               
  $script:diag = $null
  $script:blnDL = $true
  $script:blnFAIL = $false
  $script:blnWARN = $false
  $script:bitarch = $null
  $script:producttype = $null
  #BDGZ VARS
  $script:detected = $null
  $script:isupdated = $null
  $script:running = $false
  $script:qscan = $null
  $script:fscan = $null
  $script:epsEXE = "C:\IT\eps.rmm.exe"
  #DIRECTORY VARS
  $script:dirPD = [System.Environment]::ExpandEnvironmentVariables("%ProgramData%")
  $script:dirAU = [System.Environment]::ExpandEnvironmentVariables("%AllUsersProfile%")
  #SET TLS SECURITY FOR CONNECTING TO GITHUB
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12
#ENDREGION ----- DECLARATIONS ----

#REGION ----- FUNCTIONS ----
  function write-DRMMDiag ($messages) {
    write-output "<-Start Diagnostic->"
    foreach ($message in $messages) {$message}
    write-output "<-End Diagnostic->"
  } ## write-DRMMDiag
  
  function write-DRRMAlert ($message) {
    write-output "<-Start Result->"
    write-output "Alert=$($message)"
    write-output "<-End Result->"
  } ## write-DRRMAlert

  function Get-EpochDate ($epochDate, $opt) {                                                       #Convert Epoch Date Timestamps to Local Time
    switch ($opt) {
      "sec" {[timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($epochDate))}
      "msec" {[timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddMilliSeconds($epochDate))}
    }
  } ## Get-EpochDate

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

  function Get-OSArch {                                                                             #Determine Bit Architecture & OS Type
    #OS Bit Architecture
    $osarch = (get-wmiobject win32_operatingsystem).osarchitecture
    if ($osarch -like '*64*') {
      $script:bitarch = "x64"
    } elseif ($osarch -like '*32*') {
      $script:bitarch = "Win32"
    }
    #OS Type & Version
    $script:computername = $env:computername
    $script:OSCaption = (Get-WmiObject Win32_OperatingSystem).Caption
    $script:OSVersion = (Get-WmiObject Win32_OperatingSystem).Version
    $osproduct = (Get-WmiObject -class Win32_OperatingSystem).Producttype
    Switch ($osproduct) {
      "1" {$script:producttype = "Workstation"}
      "2" {$script:producttype = "DC"}
      "3" {$script:producttype = "Server"}
    }
  } ## Get-OSArch

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
#Start script execution time calculation
$ScrptStartTime = (Get-Date).ToString('dd-MM-yyyy hh:mm:ss')
$script:sw = [Diagnostics.Stopwatch]::StartNew()
#GET ARCHITECTURE
Get-OSArch
#GET OS VERSION
$version = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentVersion
if ([version]$version -ge [version]"6.0") {
  $script:avjson = "$($script:dirPD)\CentraStage\AEMAgent\antivirus.json"
} elseif ([version]$version -lt [version]"6.0") {
  $script:diag += "Unsupported OS. Only Vista / Win 7/8 / Server 2008 and up are supported.`r`n`r`n"
  write-output "Unsupported OS. Only Vista / Win 7/8 / Server 2008 and up are supported.`r`n" -foregroundcolor red
  $script:avjson = "$($script:dirAU)\Application Data\CentraStage\AEMAgent\antivirus.json"
}
#CHECK 'PERSISTENT' FOLDERS
if (-not (test-path -path "C:\temp")) {
  new-item -path "C:\temp" -itemtype directory
}
if (-not (test-path -path "C:\IT")) {
  new-item -path "C:\IT" -itemtype directory
}
if (-not (test-path -path "C:\IT\Scripts")) {
  new-item -path "C:\IT\Scripts" -itemtype directory
}
#CLEANUP OLD VERSIONS OF 'EPS.RMM.EXE'
get-childitem -path "C:\IT"  | where-object {$_.name -match "eps.rmm.exe"} | % {
  write-output " - eps.rmm.exe file last downloaded : $($_.creationtime)"
  if ($_.creationtime -gt (get-date).adddays(-$env:i_epsInterval)) {
    $script:diag += " - NOT REMOVING EPS FILE`r`n`r`n"
    write-output " - NOT REMOVING EPS FILE`r`n"
    $script:blnDL = $false
  } elseif ($_.creationtime -le (get-date).adddays(-$env:i_epsInterval)) {
    $script:diag += " - DELETE : $($_.name)`r`n`r`n"
    write-output " - DELETE : $($_.name)`r`n"
    remove-item $_.fullname -force -erroraction silentlycontinue
    $script:blnDL = $true
  }
}
#DOWNLOAD EPS.RMM.EXE
if ($script:blnDL) {
    try {
      $script:diag += "Invoke-WebRequest() - Determining latest version of eps.rmm.exe`r`n"
      write-output "Invoke-WebRequest() - Determining latest version of eps.rmm.exe" -foregroundcolor yellow
      $script:epsVER = [System.Text.Encoding]::ASCII.GetString((invoke-webrequest -URI "http://download.bitdefender.com/SMB/RMM/Tools/Win/latest.dat" -UseBasicParsing -erroraction stop).content)
    } catch {
      $script:diag += "Unable to determine latest version of eps.rmm.exe`r`n"
      $script:diag += "Invoke-WebRequest() - Could not open http://download.bitdefender.com/SMB/RMM/Tools/Win/latest.dat`r`n"

      write-output "Unable to determine latest version of eps.rmm.exe"
      write-output "Invoke-WebRequest() - Could not open http://download.bitdefender.com/SMB/RMM/Tools/Win/latest.dat" -foregroundcolor red
      $script:diag += "$($_.Exception)`r`n"
      $script:diag += "$($_.scriptstacktrace)`r`n"
      $script:diag += "$($_)`r`n`r`n"
      try {
        $script:diag += "Web.DownloadFile() - Determining latest version of eps.rmm.exe`r`n"
        write-output "Web.DownloadFile() - Determining latest version of eps.rmm.exe" -foregroundcolor yellow

        $web = new-object system.net.webclient
        $web.downloadfile("http://download.bitdefender.com/SMB/RMM/Tools/Win/latest.dat", "C:\IT\latest.dat")
        $script:epsVER = get-content -path "C:\IT\latest.dat"
      } catch {
        $script:diag += "Unable to determine latest version of eps.rmm.exe`r`n"
        $script:diag += "Web.DownloadFile() - Could not open http://download.bitdefender.com/SMB/RMM/Tools/Win/latest.dat`r`n"

        write-output "Unable to determine latest version of eps.rmm.exe"
        write-output "Web.DownloadFile() - Could not open http://download.bitdefender.com/SMB/RMM/Tools/Win/latest.dat" -foregroundcolor red
        $script:diag += "$($_.Exception)`r`n"
        $script:diag += "$($_.scriptstacktrace)`r`n"
        $script:diag += "$($_)`r`n`r`n"
        $script:blnFAIL = $true
      }
    }
    if (-not $script:blnFAIL) {
      $script:epsSRC = "http://download.bitdefender.com/SMB/RMM/Tools/Win/$($script:epsVER)/$($script:bitarch)/eps.rmm.exe"
      if (-not (test-path -path $script:epsEXE -pathtype leaf)) {
        try {
          $script:diag += "BITS.Transfer() - Downloading latest version of eps.rmm.exe ($($script:epsVER))`r`n"
          write-output "BITS.Transfer() - Downloading latest version of eps.rmm.exe ($($script:epsVER))" -foregroundcolor yellow

          start-bitstransfer -erroraction stop -source $script:epsSRC -destination $script:epsEXE
          (get-childitem -path $script:epsEXE).creationtime = (get-date)
        } catch {
          $script:diag += "BITS.Transfer() - Could not download $($script:epsSRC)`r`n"
          write-output "BITS.Transfer() - Could not download $($script:epsSRC)" -foregroundcolor red
          try {
            $script:diag += "Web.DownloadFile() - Downloading latest version of eps.rmm.exe ($($script:epsVER))`r`n"
            write-output "Web.DownloadFile() - Downloading latest version of eps.rmm.exe ($($script:epsVER))" -foregroundcolor yellow

            $web = new-object system.net.webclient
            $web.downloadfile($script:epsSRC, $script:epsEXE)
            (get-childitem -path $script:epsEXE).creationtime = (get-date)
          } catch {
            $script:diag += "Web.DownloadFile() - Could not download $($script:epsSRC)`r`n"
            write-output "Web.DownloadFile() - Could not download $($script:epsSRC)" -foregroundcolor red
            $script:diag += "$($_.Exception)`r`n"
            $script:diag += "$($_.scriptstacktrace)`r`n"
            $script:diag += "$($_)`r`n`r`n"
            $script:blnFAIL = $true
          }
        }
      }
    }
}
if ($script:blnFAIL) {
  StopClock
  write-DRRMAlert "Execution Failed : Please See Diagnostics"
  write-DRMMDiag "$($script:diag)"
  exit 1
} elseif (-not $script:blnFAIL) {
  #UTILIZE EPS.RMM.EXE TO DETECT BD INSTALL
  $script:diag += " - CHECKING BDGZ INSTALL`r`n"
  write-output " - CHECKING BDGZ INSTALL" -foregroundcolor yellow
  $output = Get-ProcessOutput -FileName $script:epsEXE -Args "-detect"
  $script:detected = [int]$output.standardoutput.split("|")[0]
  #UTILIZE EPS.RMM.EXE TO DETECT BD UPDATE STATUS
  $script:diag += " - CHECKING BDGZ UPDATE STATUS`r`n`r`n"
  write-output " - CHECKING BDGZ UPDATE STATUS`r`n" -foregroundcolor yellow
  $output = Get-ProcessOutput -FileName $script:epsEXE -Args "-isUpToDate"
  $script:isupdated = [bool][int]$output.standardoutput
  #INITIAL STATUS CHECK
  switch ($script:detected) {
    0 {
      $script:diag += "BDGZ not installed`r`n`r`n"
      write-output "BDGZ not installed`r`n" -foregroundcolor red
      remove-item "$($script:avjson)" -force -erroraction silentlycontinue
      StopClock
      write-DRRMAlert "BDGZ not installed"
      write-DRMMDiag "$($script:diag)"
      exit 1
    }
    1 {
      $script:running = $true
      $script:diag += "BDGZ installed; AV running`r`n`r`n"
      write-output "BDGZ installed; AV running`r`n" -foregroundcolor green
    }
    2 {
      $script:running = $false
      $script:diag += "BDGZ installed; AV not running`r`n`r`n"
      write-output "BDGZ installed; AV not running`r`n" -foregroundcolor red
      remove-item "$($script:avjson)" -force -erroraction silentlycontinue
      $json = "{`"product`":`"Bitdefender Endpoint Security Tools`",`"running`":$($script:running.tostring().tolower()),`"upToDate`":$($script:isupdated.tostring().tolower())}"
      set-content "$($script:avjson)" -value "$($json)"
      StopClock
      write-DRRMAlert "BDGZ installed; AV not running"
      write-DRMMDiag "$($script:diag)"
      exit 1
    }
  }
  #CHOOSE MONITOR ACTION BASED ON '$i_Action'
  switch ($env:i_Action.toupper()) {
    {($_ -eq "VERIFYINSTALL") -or ($_ -eq "VERIFYUPDATE")} {
      $act = $env:i_Action.replace("Verify", "")
      $script:diag += " - VERIFYING BDGZ $($act)`r`n`r`n"
      write-output " - VERIFYING BDGZ $($act)`r`n" -foregroundcolor yellow
      $output = Get-ProcessOutput -FileName $script:epsEXE -Args "-getProductVersion"
      $bdver = [string]$output.standardoutput
      $output = Get-ProcessOutput -FileName $script:epsEXE -Args "-getLastUpdate"
      $bdupdate = Get-EpochDate([string]$output.standardoutput)("sec")
      $output = Get-ProcessOutput -FileName $script:epsEXE -Args "-hasCriticalIssues"
      $bdissue = [string]$output.standardoutput
      if (($null -eq $bdissue) -or ($bdissue -eq "")) {
        $status = "Version : $($bdver) - Issues : None - UpToDate : $($script:isupdated.tostring()) - Last Update : $($bdupdate)"
        write-output "$($status)"
      } elseif (($null -ne $bdissue) -or ($bdissue -ne "")) {
        $script:blnWARN = $true
        $status = "Version : $($bdver) - Issues : Critical Issues Detected - UpToDate : $($script:isupdated.tostring()) - Last Update : $($bdupdate)"
        write-output "$($status)"
      }
      $script:diag += "$($status)`r`n`r`n"
      if ($script:isupdated.tostring().tolower() -eq "false") {
        #$script:blnWARN = $true
        $bdupdate = Get-ProcessOutput -FileName $script:epsEXE -Args "-startUpdate"
        $bdupdate = [string]$bdupdate.standardoutput
        switch ($bdupdate) {
          "0" {$status = " - UPDATE PROCESS STARTED -`r`n`r`n$($status)`r`n`r`n";write-output "$($status)"}
          "1552" {$status = " - UPDATE PROCESS ALREADY RUNNING -`r`n`r`n$($status)`r`n`r`n";write-output "$($status)"}
          default {$status = " - COULDN'T START UPDATE PROCESS -`r`n`r`n$($status)`r`n`r`n";write-output "$($status)"}
        }
      }
      $script:diag += "$($status)`r`n`r`n"
      #$script:diag += "$($status)`r`n - WRITING ANTIVIRUS.JSON FILE`r`n`r`n"
      #write-output "$($status)`r`n - WRITING ANTIVIRUS.JSON FILE`r`n" -foregroundcolor yellow
      remove-item "$($script:avjson)" -force -erroraction silentlycontinue
      $json = "{`"product`":`"Bitdefender Endpoint Security Tools`",`"running`":$($script:running.tostring().tolower()),`"upToDate`":$($script:isupdated.tostring().tolower())}"
      set-content "$($script:avjson)" -value "$($json)"
    }
    {($_ -eq "VERIFYSCANS")} {
      $act = $env:i_Action.replace("Verify", "")
      $script:diag += " - VERIFYING BDGZ $($act)`r`n`r`n"
      write-output " - VERIFYING BDGZ $($act)`r`n" -foregroundcolor yellow
      $output = Get-ProcessOutput -FileName $script:epsEXE -Args "-getLastSystemScan"
      #FULL SCANS
      $script:fscan = $output.standardoutput.split("|")[0]
      $script:fscan = Get-EpochDate([int]$script:fscan.split("=")[1])("sec")
      $age = new-timespan -start ($script:fscan) -end (Get-Date)
      if ($age.days -ge $env:i_fsInterval) {$script:blnWARN = $true}
      $fsstatus = "Last Full Scan : $($script:fscan)`r`nTime Since Last Full Scan : $($age.tostring("dd\:hh\:mm")) (Current Threshold : $($env:i_fsInterval) days)"
      $script:diag += "$($fsstatus)`r`n`r`n"
      write-output "$($fsstatus)`r`n"
      #QUICK SCANS
      $script:qscan = $output.standardoutput.split("|")[1]
      $script:qscan = Get-EpochDate([int]$script:qscan.split("=")[1])("sec")
      $age = new-timespan -start ($script:qscan) -end (Get-Date)
      if ($age.days -ge $env:i_qsInterval) {$script:blnWARN = $true}
      $qsstatus = "Last Quick Scan : $($script:qscan)`r`nTime Since Last Quick Scan : $($age.tostring("dd\:hh\:mm")) (Current Threshold : $($env:i_qsInterval) days)"
      $script:diag += "$($qsstatus)`r`n`r`n"
      write-output "$($qsstatus)`r`n"
      $status = "$($fsstatus)`r`n$($qsstatus)`r`n`r`n"
    }
    {($_ -eq "RUNUPDATE")} {
      $act = $env:i_Action.replace("Run", "")
      $script:diag += " - RUNNING BDGZ $($act)`r`n`r`n"
      write-output " - RUNNING BDGZ $($act)`r`n" -foregroundcolor yellow
      $output = Get-ProcessOutput -FileName $script:epsEXE -Args "-getProductVersion"
      $bdver = [string]$output.standardoutput
      $output = Get-ProcessOutput -FileName $script:epsEXE -Args "-getLastUpdate"
      $bdupdate = Get-EpochDate([string]$output.standardoutput)("sec")
      $output = Get-ProcessOutput -FileName $script:epsEXE -Args "-hasCriticalIssues"
      $bdissue = [string]$output.standardoutput
      if (($null -eq $bdissue) -or ($bdissue -eq "")) {
        $status = "Version : $($bdver) - Issues : None - UpToDate : $($script:isupdated.tostring()) - Last Update : $($bdupdate)"
        write-output "$($status)"
      } elseif (($null -ne $bdissue) -or ($bdissue -ne "")) {
        $script:blnWARN = $true
        $status = "Version : $($bdver) - Issues : Critical Issues Detected - UpToDate : $($script:isupdated.tostring()) - Last Update : $($bdupdate)"
        write-output "$($status)"
      }
      $script:diag += "$($status)`r`n`r`n"
      $bdissue = [string]$output.standardoutput
      $bdupdate = Get-ProcessOutput -FileName $script:epsEXE -Args "-startUpdate"
      $bdupdate = [string]$bdupdate.standardoutput
      switch ($bdupdate) {
        "0" {$status = " - UPDATE PROCESS STARTED`r`n`r`n$($status)`r`n`r`n";write-output "$($status)"}
        "1552" {$status = " - UPDATE PROCESS ALREADY RUNNING`r`n`r`n$($status)`r`n`r`n";write-output "$($status)"}
        default {$status = " - COULDN'T START UPDATE PROCESS`r`n`r`n$($status)`r`n`r`n";write-output "$($status)"}
      }
      $script:diag += "$($status)`r`n`r`n"
    }
    {($_ -eq "RUNFULLSCAN") -or ($_ -eq "RUNQUICKSCAN")} {
      $act = $env:i_Action.replace("Run", "")
      $script:diag += " - RUNNING BDGZ $($act)`r`n`r`n"
      write-output " - RUNNING BDGZ $($act)`r`n" -foregroundcolor yellow
      $output = Get-ProcessOutput -FileName $script:epsEXE -Args "-getLastSystemScan"
      switch ($env:i_Action.toupper()) {
        "RUNFULLSCAN" {
          $output = $output.standardoutput.split("|")[0]
          $script:fscan = Get-EpochDate([int]$output.split("=")[1])("sec")
          $age = new-timespan -start ($script:fscan) -end (Get-Date)
          $status = "Last $($act) : $($script:fscan)`r`nTime Since Last $($act) : $($age.tostring("dd\:hh\:mm")) (Current Threshold : $($env:i_fsInterval) days)"
          if ($age.days -ge $env:i_fsInterval) {$script:blnWARN = $true}
          $output = Get-ProcessOutput -FileName $script:epsEXE -Args "-startFullScan"
        }
        "RUNQUICKSCAN" {
          $output = $output.standardoutput.split("|")[1]
          $script:qscan = Get-EpochDate([int]$output.split("=")[1])("sec")
          $age = new-timespan -start ($script:qscan) -end (Get-Date)
          $status = "Last $($act) : $($script:qscan)`r`nTime Since Last $($act) : $($age.tostring("dd\:hh\:mm")) (Current Threshold : $($env:i_qsInterval) days)"
          if ($age.days -ge $env:i_qsInterval) {$script:blnWARN = $true}
          $output = Get-ProcessOutput -FileName $script:epsEXE -Args "-startQuickScan"
        }
      }
      $script:diag += "$($status)`r`n`r`n"
      $output = [string]$output.standardoutput
      switch ($output) {
        "0" {$status = " - $($act) OPERATION PERFORMED SUCCESSFULLY`r`n`r`n$($status)"}
        "622" {$status = " - FILESCAN FEATURE IS EXPIRED`r`n`r`n$($status)"}
        "1168" {$status = " - STORED SCAN TASK NOT FOUND`r`n`r`n$($status)"}
        "5006" {$status = " - ANTIMALWARE SCANNER NOT AVAILABLE`r`n`r`n$($status)"}
        "5023" {$status = " - STORED SCAN TASK ALREADY RUNNING`r`n`r`n$($status)"}
        default {$status = " - $($act) CANNOT BE PERFORMED. ERROR CODE : $($output)`r`n`r`n$($status)"}
      }
      $script:diag += "$($status)`r`n`r`n"
    }
  }
}
#DATTO OUTPUT
if ($script:blnWARN) {
  write-output "$($status)" -foregroundcolor red
  StopClock
  write-DRRMAlert "$($status)"
  write-DRMMDiag "$($script:diag)"
  exit 1
} elseif (-not $script:blnWARN) {
  write-output "$($status)" -foregroundcolor green
  StopClock
  write-DRRMAlert "$($status)"
  write-DRMMDiag "$($script:diag)"
  exit 0
}
#END SCRIPT
#------------