﻿  function Get-ProcessOutput {
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
  
$script:installed = (Get-ItemProperty "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ea SilentlyContinue) | where-object -property DisplayName -contains "Windows Agent"
$script:installed.UninstallString = $script:installed.UninstallString.split(" ")[1]
$script:installed.UninstallString

$output = Get-ProcessOutput -FileName "msiexec.exe" -Args "$($script:installed.UninstallString) /quiet /qn /norestart"
#PARSE SMARTCTL OUTPUT LINE BY LINE
$lines = $output.StandardOutput.split("`r`n", [StringSplitOptions]::RemoveEmptyEntries)
$lines