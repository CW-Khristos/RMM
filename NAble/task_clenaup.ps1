#REGION ----- DECLARATIONS ----
  $taskFOL = "\IPM Computers\"
  $tasks = @("N-able Windows Agent Self-Healing", "NcentralAMX")
#ENDREGION ----- DECLARATIONS ----

#REGION ----- FUNCTIONS ----
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
#ENDREGION ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
foreach ($task in $tasks) {
  try {
    if (Get-ScheduledTask -TaskName "$($task)" -erroraction silentlycontinue) { write-output "Deleting Task : $($task)" }
    try {
      Unregister-ScheduledTask -TaskName "$($task)" -Confirm:$false -erroraction silentlycontinue
      remove-item "C:\Windows\System32\Tasks$($taskFOL)" -force -erroraction silentlycontinue
    } catch {
      try {
        Unregister-ScheduledTask -TaskPath "$($taskFOL)" -TaskName "$($task)" -Confirm:$false -erroraction silentlycontinue
        remove-item "C:\Windows\System32\Tasks$($taskFOL)" -force -erroraction silentlycontinue
      } catch {
        write-hot "Couldn't remove task : $($task)`r`n"
      }
    }
  } catch {
    write-output "Error - Task : $($task) still present"
  }
  $xmltasks = Get-ChildItem -Path 'C:\Windows\System32\Tasks' | where-object { $_.Name -match "$($task)" }
  if (!$xmltasks) {
    write-output "Confirmed Task $($task) deleted"
  } elseif ($xmltasks) {
    write-output "Error - Task : $($task) still present"
  }
  #schtasks /Delete /TN "<task folder path>\<task name>" /F
}
#END SCRIPT
#------------