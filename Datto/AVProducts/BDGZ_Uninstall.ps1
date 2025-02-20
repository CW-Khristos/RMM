#REGION ----- DECLARATIONS ----              
  $script:diag = $null
  $script:blnDL = $true
  $script:blnFAIL = $false
  $script:blnWARN = $false
  #BDGZ VARS
  $script:bdEXE = "C:\IT\BEST_uninstallTool.exe"
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
#Start script execution time calculation
$ScrptStartTime = (Get-Date).ToString('dd-MM-yyyy hh:mm:ss')
$script:sw = [Diagnostics.Stopwatch]::StartNew()
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
#CLEANUP OLD VERSIONS OF BD CLI REMOVAL TOOL
try {
  get-childitem -path "C:\IT"  | where-object {$_.name -match "BEST_uninstallTool"} | % {
    if ($_.creationtime -gt (get-date).adddays(-7)) {
      $script:diag += " - NOT REMOVING BEST_uninstallTool FILE`r`n`r`n"
      write-output " - NOT REMOVING BEST_uninstallTool FILE`r`n"
      $script:blnDL = $false
    } elseif ($_.creationtime -le (get-date).adddays(-7)) {
      $script:diag += " - DELETE : $($_.name)`r`n`r`n"
      write-output " - DELETE : $($_.name)`r`n"
      remove-item $_.fullname -force -erroraction silentlycontinue
      $script:blnDL = $true
    }
  }
} catch {
  $script:diag += "BD UNINSTALL TOOL NOT DETECTED. CONTINUING`r`n`r`n"
}
#DOWNLOAD BD CLI REMOVAL TOOL
if ($script:blnDL) {
  $script:bdSRC = "https://download.bitdefender.com/SMB/Hydra/release/bst_win/uninstallTool/BEST_uninstallTool.exe"
  if (-not (test-path -path $script:bdEXE -pathtype leaf)) {
    try {
      $script:diag += "BITS.Transfer() - Downloading latest version of BEST_uninstallTool.exe`r`n"
      write-output "BITS.Transfer() - Downloading latest version of BEST_uninstallTool.exe"
      start-bitstransfer -erroraction stop -source $script:bdSRC -destination $script:bdEXE
      (get-childitem -path $script:bdEXE).creationtime = (get-date)
    } catch {
      $script:diag += "BITS.Transfer() - Could not download $($script:bdSRC)`r`n"
      write-output "BITS.Transfer() - Could not download $($script:bdSRC)"
      try {
        $script:diag += "Web.DownloadFile() - Downloading latest version of BEST_uninstallTool.exe`r`n"
        write-output "Web.DownloadFile() - Downloading latest version of BEST_uninstallTool.exe"
        $web = new-object system.net.webclient
        $web.downloadfile($script:bdSRC, $script:bdEXE)
        (get-childitem -path $script:bdEXE).creationtime = (get-date)
      } catch {
        $script:diag += "Web.DownloadFile() - Could not download $($script:bdSRC)`r`n"
        write-output "Web.DownloadFile() - Could not download $($script:bdSRC)"
        $script:diag += "$($_.Exception)`r`n"
        $script:diag += "$($_.scriptstacktrace)`r`n"
        $script:diag += "$($_)`r`n`r`n"
        $script:blnFAIL = $true
      }
    }
  }
}
if ($script:blnFAIL) {
  StopClock
  write-DRMMAlert "Execution Failed : Please See Diagnostics"
  write-DRMMDiag "$($script:diag)"
  exit 1
} elseif (-not $script:blnFAIL) {
  #UTILIZE BD CLI REMOVAL TOOL TO UNINSTALL BITDEFENDER
  #
  $script:diag += " - RUNNING BDGZ UNINSTALL TOOL`r`n"
  write-output " - RUNNING BDGZ UNINSTALL TOOL"
  $output = Get-ProcessOutput -FileName $script:bdEXE -Args "/bdparams /bruteForce /log"
  $results = [string]$output.standardoutput
  $errors = [string]$output.standarderror
  $status = "RESULTS :`r`nSTDOUT :`r`n$($results)`r`nSTDERR :`r`n$($errors)`r`n`r`n"
  write-output "RESULTS :`r`nSTDOUT :`r`n$($results)`r`nSTDERR :`r`n$($errors)`r`n"
}
#DATTO OUTPUT
$script:diag += "$($status)`r`n"
if ($script:blnWARN) {
  write-output "$($status)"
} elseif (-not $script:blnWARN) {
  write-output "$($status)"
}
#Stop script execution time calculation
StopClock
if ($script:blnWARN) {
  write-DRMMAlert "$($status)"
  write-DRMMDiag "$($script:diag)"
  exit 1
} elseif (-not $script:blnWARN) {
  write-DRMMAlert "$($status)"
  write-DRMMDiag "$($script:diag)"
  exit 0
}
#END SCRIPT
#------------