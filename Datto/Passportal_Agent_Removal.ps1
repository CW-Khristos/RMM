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

$blnINSTALL = $false  
#PASSPORTAL AGENT REMOVAL
$script:installed = (Get-ItemProperty "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ea SilentlyContinue) | where-object {$_.DisplayName -contains "Passportal Agent"}
write-output "PASSPORTAL AGENT:"
$script:installed
if (($null -ne $script:installed.UninstallString) -and ($script:installed.UninstallString -ne "")) {
  write-output "UNINSTALLING PASSPORTAL AGENT:"
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
  $script:reg = remove-item "HKLM:\Software\Passportal" -recurse -force -ea SilentlyContinue
  $script:reg
  $script:reg = remove-item "HKLM:\Software\WOW6432Node\Passportal" -recurse -force -ea SilentlyContinue
  $script:reg
} else {
    $script:installed = (Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" -ea SilentlyContinue) | where-object {$_.DisplayName -contains "Passportal Agent"}
    $script:installed
    if (($null -ne $script:installed.UninstallString) -and ($script:installed.UninstallString -ne "")) {
      write-output "UNINSTALLING PASSPORTAL AGENT:"
      if ($script:installed.UninstallString -like "*msiexec*") {
        $script:installed.UninstallString = "{$($script:installed.UninstallString.split("{")[1])"
        $output = Get-ProcessOutput -FileName "msiexec.exe" -Args "/X $($script:installed.UninstallString) /quiet /qn /norestart"
      } elseif ($script:installed.UninstallString -notlike "*msiexec*") {
        $output = Get-ProcessOutput -FileName "$($script:installed.UninstallString)" -Args "/SILENT"
      }
      #PARSE SMARTCTL OUTPUT LINE BY LINE
      $lines = $output.StandardOutput.split("`r`n", [StringSplitOptions]::RemoveEmptyEntries)
      $lines
      $script:reg = remove-item "HKLM:\Software\Passportal" -recurse -force -ea SilentlyContinue
      $script:reg
      $script:reg = remove-item "HKLM:\Software\WOW6432Node\Passportal" -recurse -force -ea SilentlyContinue
      $script:reg
    } else {
      write-output "Passportal Agent Not Installed`r`n"
    }
}