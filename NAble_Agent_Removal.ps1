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
  
#ECOSYSTEM AGENT REMOVAL
$script:installed = (Get-ItemProperty "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ea SilentlyContinue) | where-object {$_.DisplayName -contains "Ecosystem Agent"}
write-host "ECOSYSTEM AGENT:`r`n"
$script:installed
if (($null -ne $script:installed.UninstallString) -and ($script:installed.UninstallString -ne "")) {
  $script:installed.UninstallString = $script:installed.UninstallString.split(" ")[1]
  $script:installed.UninstallString
  $output = Get-ProcessOutput -FileName "msiexec.exe" -Args "$($script:installed.UninstallString) /quiet /qn /norestart"
  #PARSE SMARTCTL OUTPUT LINE BY LINE
  $lines = $output.StandardOutput.split("`r`n", [StringSplitOptions]::RemoveEmptyEntries)
  $lines
} else {
  write-host "Ecosystem Agent Not Installed"
}
#FILE CACHE SERVICE AGENT REMOVAL
$script:installed = (Get-ItemProperty "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ea SilentlyContinue) | where-object {$_.DisplayName -contains "File Cache Service Agent"}
write-host "FILE CACHE SERVICE:`r`n"
$script:installed
if (($null -ne $script:installed.UninstallString) -and ($script:installed.UninstallString -ne "")) {
  $script:installed.UninstallString = $script:installed.UninstallString.split(" ")[1]
  $script:installed.UninstallString
  $output = Get-ProcessOutput -FileName "msiexec.exe" -Args "$($script:installed.UninstallString) /quiet /qn /norestart"
  #PARSE SMARTCTL OUTPUT LINE BY LINE
  $lines = $output.StandardOutput.split("`r`n", [StringSplitOptions]::RemoveEmptyEntries)
  $lines
} else {
  write-host "File Cache Service Agent Not Installed"
}
#PATCH MANAGEMENT SERVICE CONTROLLER REMOVAL 
$script:installed = (Get-ItemProperty "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ea SilentlyContinue) | where-object {$_.DisplayName -contains "Patch Management Service Controller"}
write-host "PATCH MANAGEMENT SERVICE:`r`n"
$script:installed
if (($null -ne $script:installed.UninstallString) -and ($script:installed.UninstallString -ne "")) {
  $script:installed.UninstallString = $script:installed.UninstallString.split(" ")[1]
  $script:installed.UninstallString
  $output = Get-ProcessOutput -FileName "msiexec.exe" -Args "$($script:installed.UninstallString) /quiet /qn /norestart"
  #PARSE OUTPUT LINE BY LINE
  $lines = $output.StandardOutput.split("`r`n", [StringSplitOptions]::RemoveEmptyEntries)
  $lines
} else {
  write-host "Patch Management Service Controller Not Installed"
}
$script:installed = (Get-ItemProperty "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ea SilentlyContinue) | where-object {$_.DisplayName -contains "PME Agent"}
write-host "PME AGENT:`r`n"
$script:installed
if (($null -ne $script:installed.UninstallString) -and ($script:installed.UninstallString -ne "")) {
  $script:installed.UninstallString = $script:installed.UninstallString.split(" ")[1]
  $script:installed.UninstallString
  $output = Get-ProcessOutput -FileName "msiexec.exe" -Args "$($script:installed.UninstallString) /quiet /qn /norestart"
  #PARSE OUTPUT LINE BY LINE
  $lines = $output.StandardOutput.split("`r`n", [StringSplitOptions]::RemoveEmptyEntries)
  $lines
} else {
  write-host "PME Agent Not Installed"
}
#REQUEST HANDLER AGENT REMOVAL
$script:installed = (Get-ItemProperty "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ea SilentlyContinue) | where-object {$_.DisplayName -contains "Request Handler Agent"}
write-host "REQUEST HANDLER AGENT:`r`n"
$script:installed
if (($null -ne $script:installed.UninstallString) -and ($script:installed.UninstallString -ne "")) {
  $script:installed.UninstallString = $script:installed.UninstallString.split(" ")[1]
  $script:installed.UninstallString
  $output = Get-ProcessOutput -FileName "msiexec.exe" -Args "$($script:installed.UninstallString) /quiet /qn /norestart"
  #PARSE OUTPUT LINE BY LINE
  $lines = $output.StandardOutput.split("`r`n", [StringSplitOptions]::RemoveEmptyEntries)
  $lines
} else {
  write-host "Request Handler Agent Not Installed"
}
#WINDOWS AGENT REMOVAL 
$script:installed = (Get-ItemProperty "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ea SilentlyContinue) | where-object {$_.DisplayName -contains "Windows Agent"}
write-host "NABLE AGENT:`r`n"
$script:installed
if (($null -ne $script:installed.UninstallString) -and ($script:installed.UninstallString -ne "")) {
  $script:installed.UninstallString = $script:installed.UninstallString.split(" ")[1]
  $script:installed.UninstallString
  $output = Get-ProcessOutput -FileName "msiexec.exe" -Args "$($script:installed.UninstallString) /quiet /qn /norestart"
  #PARSE OUTPUT LINE BY LINE
  $lines = $output.StandardOutput.split("`r`n", [StringSplitOptions]::RemoveEmptyEntries)
  $lines
} else {
  write-host "NAble Agent Not Installed"
}