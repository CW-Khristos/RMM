  function Get-ProcessOutput {
    Param (
      [Parameter(Mandatory=$true)]$FileName,
      $Args
    )
    write-output "RUNNING : $($FileName)"
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
write-output "ECOSYSTEM AGENT:"
$script:installed
if (($null -ne $script:installed.UninstallString) -and ($script:installed.UninstallString -ne "")) {
  write-output "UNINSTALLING ECOSYSTEM AGENT:"
  if ($script:installed.UninstallString -like "*msiexec*") {
    $script:installed.UninstallString = $script:installed.UninstallString.split(" ")[1]
    $script:installed.UninstallString
    $output = Get-ProcessOutput -FileName "msiexec.exe" -Args "$($script:installed.UninstallString) /quiet /qn /norestart"
  } elseif ($script:installed.UninstallString -notlike "*msiexec*") {
    $output = Get-ProcessOutput -FileName "$($script:installed.UninstallString)" -Args "/SILENT"
  }
  #PARSE SMARTCTL OUTPUT LINE BY LINE
  $lines = $output.StandardOutput.split("`r`n", [StringSplitOptions]::RemoveEmptyEntries)
  $lines
} else {
  write-output "Ecosystem Agent Not Installed`r`n"
}
#FILE CACHE SERVICE AGENT REMOVAL
$script:installed = (Get-ItemProperty "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ea SilentlyContinue) | where-object {$_.DisplayName -contains "File Cache Service Agent"}
write-output "FILE CACHE SERVICE:"
$script:installed
if (($null -ne $script:installed.UninstallString) -and ($script:installed.UninstallString -ne "")) {
  write-output "UNINSTALLING FILE CACHE SERVICE:"
  if ($script:installed.UninstallString -like "*msiexec*") {
    $script:installed.UninstallString = $script:installed.UninstallString.split(" ")[1]
    $script:installed.UninstallString
    $output = Get-ProcessOutput -FileName "msiexec.exe" -Args "$($script:installed.UninstallString) /quiet /qn /norestart"
  } elseif ($script:installed.UninstallString -notlike "*msiexec*") {
    $output = Get-ProcessOutput -FileName "$($script:installed.UninstallString)" -Args "/SILENT"
  }
  #PARSE SMARTCTL OUTPUT LINE BY LINE
  $lines = $output.StandardOutput.split("`r`n", [StringSplitOptions]::RemoveEmptyEntries)
  $lines
} else {
  write-output "File Cache Service Agent Not Installed`r`n"
}
#PATCH MANAGEMENT SERVICE CONTROLLER REMOVAL 
$script:installed = (Get-ItemProperty "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ea SilentlyContinue) | where-object {$_.DisplayName -contains "Patch Management Service Controller"}
write-output "PATCH MANAGEMENT SERVICE:"
$script:installed
if (($null -ne $script:installed.UninstallString) -and ($script:installed.UninstallString -ne "")) {
  write-output "UNINSTALLING PATCH MANAGEMENT SERVICE:"
  if ($script:installed.UninstallString -like "*msiexec*") {
    $script:installed.UninstallString = $script:installed.UninstallString.split(" ")[1]
    $script:installed.UninstallString
    $output = Get-ProcessOutput -FileName "msiexec.exe" -Args "$($script:installed.UninstallString) /quiet /qn /norestart"
  } elseif ($script:installed.UninstallString -notlike "*msiexec*") {
    $output = Get-ProcessOutput -FileName "$($script:installed.UninstallString)" -Args "/SILENT"
  }
  #PARSE OUTPUT LINE BY LINE
  $lines = $output.StandardOutput.split("`r`n", [StringSplitOptions]::RemoveEmptyEntries)
  $lines
} else {
  write-output "Patch Management Service Controller Not Installed`r`n"
}
$script:installed = (Get-ItemProperty "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ea SilentlyContinue) | where-object {$_.DisplayName -contains "PME Agent"}
write-output "PME AGENT:"
$script:installed
if (($null -ne $script:installed.UninstallString) -and ($script:installed.UninstallString -ne "")) {
  write-output "UNINSTALLING PME AGENT:"
  if ($script:installed.UninstallString -like "*msiexec*") {
    $script:installed.UninstallString = $script:installed.UninstallString.split(" ")[1]
    $script:installed.UninstallString
    $output = Get-ProcessOutput -FileName "msiexec.exe" -Args "$($script:installed.UninstallString) /quiet /qn /norestart"
  } elseif ($script:installed.UninstallString -notlike "*msiexec*") {
    $output = Get-ProcessOutput -FileName "$($script:installed.UninstallString)" -Args "/SILENT"
  }
  #PARSE OUTPUT LINE BY LINE
  $lines = $output.StandardOutput.split("`r`n", [StringSplitOptions]::RemoveEmptyEntries)
  $lines
} else {
  write-output "PME Agent Not Installed`r`n"
}
#REQUEST HANDLER AGENT REMOVAL
$script:installed = (Get-ItemProperty "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ea SilentlyContinue) | where-object {$_.DisplayName -contains "Request Handler Agent"}
write-output "REQUEST HANDLER AGENT:"
$script:installed
if (($null -ne $script:installed.UninstallString) -and ($script:installed.UninstallString -ne "")) {
  write-output "UNINSTALLING REQUEST HANDLER AGENT:"
  if ($script:installed.UninstallString -like "*msiexec*") {
    $script:installed.UninstallString = $script:installed.UninstallString.split(" ")[1]
    $script:installed.UninstallString
    $output = Get-ProcessOutput -FileName "msiexec.exe" -Args "$($script:installed.UninstallString) /quiet /qn /norestart"
  } elseif ($script:installed.UninstallString -notlike "*msiexec*") {
    $output = Get-ProcessOutput -FileName "$($script:installed.UninstallString)" -Args "/SILENT"
  }
  #PARSE OUTPUT LINE BY LINE
  $lines = $output.StandardOutput.split("`r`n", [StringSplitOptions]::RemoveEmptyEntries)
  $lines
} else {
  write-output "Request Handler Agent Not Installed`r`n"
}
#WINDOWS AGENT REMOVAL 
$script:installed = (Get-ItemProperty "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ea SilentlyContinue) | where-object {$_.DisplayName -contains "Windows Agent"}
write-output "NABLE AGENT:"
$script:installed
if (($null -ne $script:installed.UninstallString) -and ($script:installed.UninstallString -ne "")) {
  write-output "UNINSTALLING NABLE AGENT:"
  if ($script:installed.UninstallString -like "*msiexec*") {
    $script:installed.UninstallString = $script:installed.UninstallString.split(" ")[1]
    $script:installed.UninstallString
    $output = Get-ProcessOutput -FileName "msiexec.exe" -Args "$($script:installed.UninstallString) /quiet /qn /norestart"
  } elseif ($script:installed.UninstallString -notlike "*msiexec*") {
    $output = Get-ProcessOutput -FileName "$($script:installed.UninstallString)" -Args "/SILENT"
  }
  #PARSE OUTPUT LINE BY LINE
  $lines = $output.StandardOutput.split("`r`n", [StringSplitOptions]::RemoveEmptyEntries)
  $lines
} else {
  write-output "NAble Agent Not Installed`r`n"
}