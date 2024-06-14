<#
    .SYNOPSIS
        Monitoring - Windows - Time Drift
    .DESCRIPTION
        This script will monitor time drift on the machine vs a provided "source of truth".
    .NOTES
        2024-02-15: Modifications by Cameron Day for IPM Computers LLC
        2023-03-22: Exclude empty lines in the output.
        2023-03-18: Add `-Resync` parameter to force a resync if the time drift exceeds threshold.
        2023-03-17: Initial version
    .LINK
        Original Source: https://kevinholman.com/2017/08/26/monitoring-for-time-drift-in-your-enterprise/
    .LINK
        Blog post: https://homotechsual.dev/2023/03/17/Monitoring-Time-Drift-PowerShell/
#>
#region ----- Declorations -----
[string]$ReferenceServer  = $env:ReferenceServer #default '0.pool.ntp.org'
# The number of samples to take.
[int]$NumberOfSamples     = $env:NumberOfSamples #default 1
# The allowed time drift in seconds.
[int]$AllowedTimeDrift    = $env:AllowedTimeDrift #default 1
# Force a resync of the time if the time drift is greater than the allowed time drift.
$ForceResync              = $env:ForceResync #default 'false'
if ($ForceResync -eq 'true') {
  $ForceResync = $true
} elseif ($ForceResync -eq 'false') {
  $ForceResync = $false
}
#endregion ----- Decloarions -----
#region ----- Functions -----
function write-DRMMDiag ($messages) {
  write-output "<-Start Diagnostic->"
  foreach ($message in $messages) { $message }
  write-output "<-End Diagnostic->"
} 
  
function write-DRMMAlert ($message) {
  write-output "<-Start Result->"
  write-output "Alert=$($message)"
  write-output "<-End Result->"
} 
#endregion ----- Functions ------

$Win32TimeExe = Join-Path -Path $ENV:SystemRoot -ChildPath 'System32\w32tm.exe'
$Win32TimeArgs = '/stripchart /computer:{0} /samples:{1} /dataonly' -f $ReferenceServer, $NumberOfSamples
$ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
$ProcessInfo.FileName = $Win32TimeExe
$ProcessInfo.Arguments = $Win32TimeArgs
$ProcessInfo.RedirectStandardError = $true
$ProcessInfo.RedirectStandardOutput = $true
$ProcessInfo.UseShellExecute = $false
$ProcessInfo.CreateNoWindow = $true
$Process = New-Object System.Diagnostics.Process
$Process.StartInfo = $ProcessInfo
$Process.Start() | Out-Null
$ProcessResult = [PSCustomObject]@{
  ExitCode = $Process.ExitCode
  StdOut   = $Process.StandardOutput.ReadToEnd()
  StdErr   = $Process.StandardError.ReadToEnd()
}
$Process.WaitForExit()
if ($ProcessResult.StdErr) {
  Write-Error "w32tm.exe returned the following error: $($ProcessResult.StdErr)"
} elseif ($ProcessResult.StdOut -contains 'Error') {
  Write-Error "w32tm.exe returned the following error: $($ProcessResult.StdOut)"
} else {
  Write-Debug ('Raw StdOut: {0}' -f $ProcessResult.StdOut)
  $ProcessOutput = $ProcessResult.StdOut.Split("`n") | Where-Object { $_ }
  $Skew = $ProcessOutput[-1..($NumberOfSamples * -1)] | ConvertFrom-Csv -Header @('Time', 'Skew') | Select-Object -ExpandProperty Skew
  Write-Debug ('Raw Skew: {0}' -f $Skew)
  $AverageSkew = $Skew | ForEach-Object { $_ -replace 's', '' } | Measure-Object -Average | Select-Object -ExpandProperty Average
  Write-Debug ('Average Skew: {0}' -f $AverageSkew)
  if ($AverageSkew -lt 0) { $AverageSkew = $AverageSkew * -1 }
  $TimeDriftMinutes = ([Math]::Round($AverageSkew, 2)) / 60
  $finish = (get-date).tostring('yyyy-MM-dd hh:mm:ss')
  if ($TimeDriftMinutes -gt $AllowedTimeDrift) {
    if ($ForceResync) {
      Start-Process -FilePath $Win32TimeExe -ArgumentList '/config /manualpeerlist:"0.pool.ntp.org 1.pool.ntp.org 2.pool.ntp.org 3.pool.ntp.org" /syncfromflags:manual /update' -Wait
      Start-Process -FilePath $Win32TimeExe -ArgumentList "/resync /computer:$($ReferenceServer)" -Wait
      $strOUT = "Time drift was greater than the allowed : $($AllowedTimeDrift)min: Resync was Forced : $($finish)"
      Write-Warning "Time drift was greater than the allowed time drift of $AllowedTimeDrift minute. Time drift was $TimeDriftMinutes minutes A resync was forced."
      write-DRMMAlert "$($strOUT)"
      write-DRMMDiag "$($strOUT)`r`n$($ProcessResult.StdOut)`r`n$($ProcessResult.StdErr)"
      Exit 1
    } else {
      $strOUT = "Time drift was greater than the allowed : $($AllowedTimeDrift)min : Resync was not Forced : $($finish)"
      Write-Error "Time drift is greater than the allowed time drift of $AllowedTimeDrift minutes. Time drift is $TimeDriftMinutes minutes."
      write-DRMMAlert "Time drift was greater than the allowed : $($AllowedTimeDrift)min : Resync was not Forced : $($finish)"
      write-DRMMDiag "$($strOUT)`r`n$($ProcessResult.StdOut)`r`n$($ProcessResult.StdErr)"
      Exit 1
    }
  } else {
    Write-Verbose "Time drift is within accepted limits. Time drift is $TimeDriftMinutes minutes."
    write-DRMMAlert "Time drift is within accepted limits : $($AllowedTimeDrift)min : $($finish)"
    write-DRMMDiag "$($ProcessResult.StdOut)`r`n$($ProcessResult.StdErr)"
    Exit 0
  }
}