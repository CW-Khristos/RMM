#REGION ----- DECLARATIONS ----
  #UNCOMMENT BELOW PARAM() TO UTILIZE IN CLI
  #Param(
  #  [Parameter(Mandatory=$true)]$strUser
  #)
  $script:diag = $null
  $script:blnWARN = $false
  $cmdEXE = "C:\WINDOWS\system32\cmd.exe"
#ENDREGION ----- DECLARATIONS ----

#REGION ----- FUNCTIONS ----
  function write-DRMMDiag ($messages) {
    write-output "<-Start Diagnostic->"
    foreach ($Message in $Messages) {$Message}
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
try {
  $cmdOutput = Get-ProcessOutput -FileName $cmdEXE -Args "/c net user $($env:strUser) /delete /domain"
  $script:diag += "$($cmdOutput)`r`n"
  write-output "$($cmdOutput)"
} catch {
  $script:blnWARN = $true
  $script:diag += "ERROR DELETING USER : $($env:strUser)`r`n"
  $script:diag += "$($_.Exception)`r`n"
  $script:diag += "$($_.scriptstacktrace)`r`n"
  $script:diag += "$($_)`r`n`r`n"
  write-output "ERROR DELETING USER : $($env:strUser)"
}
#Stop script execution time calculation
StopClock
#DATTO OUTPUT
if ($script:blnWARN) {
  write-DRMMDiag "$($script:diag)`r`n"
  exit 1
} elseif (-not ($script:blnWARN)) {
  write-DRMMDiag "$($script:diag)`r`n"
  exit 0
}
#END SCRIPT
#------------