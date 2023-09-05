#REGION ----- DECLARATIONS ----
  #BELOW PARAM() MUST BE COMMENTED OUT FOR USE WITHIN DATTO RMM
  #UNCOMMENT BELOW PARAM() AND RENAME '$env:i_Action' TO '$i_Action' TO UTILIZE IN CLI
  #Param (
  #  [Parameter(Mandatory=$true)]$i_Action
  #)
  $script:diag = $null
  $script:blnFAIL = $false
  $script:blnWARN = $false
  $script:bitarch = $null
  $script:producttype = $null
  #DIRECTORY VARS
  $script:engtime = $null
  $script:datatime = $null
  $script:auEXE = "C:\Program Files (x86)\Sophos\AutoUpdate\SAUcli.exe"
  $script:dataDIR = "C:\Program Files\Sophos\Sophos Standalone Engine\engine1\data"
  $script:engDIR = "C:\Program Files\Sophos\Sophos Standalone Engine\engine1\engine"
  #SET TLS SECURITY FOR CONNECTING TO GITHUB
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12
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
switch ($env:i_Action.toupper()) {
  "SOPHOS SCAN" {
    #GET LATEST ENGINE DIRECTORY
    get-childitem -directory "$($script:engDIR)" | % {
      if (($null -eq $script:engtime) -or ($script:engtime -eq "")) {
        $script:engtime = $_.creationtime
        $script:engDIR = $_.FullName
      } elseif ($script:engtime -le $_.creationtime) {
        $script:engtime = $_.creationtime
        $script:engDIR = $_.FullName
      }
    }
    write-output "Latest Engine : $($script:engDIR)"
    #GET LATEST DATA DIRECTORY
    get-childitem -directory "$($script:dataDIR)" | % {
      if (($null -eq $script:datatime) -or ($script:datatime -eq "")) {
        $script:datatime = $_.creationtime
        $script:dataDIR = $_.FullName
      } elseif ($script:engtime -le $_.creationtime) {
        $script:datatime = $_.creationtime
        $script:dataDIR = $_.FullName
      }
    }
    write-output "Latest Engine Data : $($script:dataDIR)"
    #START SOPHOS SCAN
    $script:diag += " - STARTING SOPHOS SCAN`r`n`r`n"
    write-output " - STARTING SOPHOS SCAN`r`n"
    try {
      #$scan = Get-ProcessOutput -FileName "$($script:engDIR)\SophosSAVICLI.exe" -Args "-vdldir=`"$($script:dataDIR)`" -dn -archive -all c:\it --stop-scan -P=C:\IT\Log\SophosScan.txt"
      #$scan = [string]$scan.standardoutput
      $scan = { & "$($script:engDIR)\SophosSAVICLI.exe" "-vdldir=`"$($script:dataDIR)`" -dn -archive -all c:\ --stop-scan -P=C:\IT\Log\SophosScan.txt" }
      Start-Job -name "Sophos Scan" -ScriptBlock $scan
      $script:diag += "$($scan)`r`n`r`nScanning Started : See Log : 'C:\IT\Log\SophosScan.txt'`r`n"
      write-output "`r`nScanning Started : See Log : 'C:\IT\Log\SophosScan.txt'"
    } catch {
      $script:blnWARN = $true
      $script:diag += "Error Starting Scan`r`n$($_.Exception)`r`n`r`n$($_.scriptstacktrace)`r`n`r`n$($_)`r`n"
      write-output "Error Starting Scan"
      write-output $_.Exception
      write-output $_.scriptstacktrace
      write-output $_
    }
  }
  "SOPHOS UPDATE" {
    #START SOPHOS UPDATE
    $script:diag += " - STARTING SOPHOS UPDATE`r`n`r`n"
    write-output " - STARTING SOPHOS UPDATE`r`n"
    try {
      $update = Get-ProcessOutput -FileName "$($script:auEXE)" -Args "UpdateNow"
      $update = [string]$update.standardoutput
      $script:diag += "$($update)`r`nUpdate Started`r`n"
      write-output "$($update)`r`nUpdate Started"
    } catch {
      $script:blnWARN = $true
      $script:diag += "Error Running Update`r`n"
      write-output "Error Running Update"
    }
  }
}
StopClock
if ($script:blnWARN) {
  write-DRMMAlert "$($env:i_Action) : Execution Failure : See Diagnostics"
  write-DRMMDiag "$($script:diag)"
  exit 1
} elseif (-not $script:blnWARN) {
  write-DRMMAlert "($env:i_Action) : Completed Execution"
  write-DRMMDiag "$($script:diag)"
  exit 0
}