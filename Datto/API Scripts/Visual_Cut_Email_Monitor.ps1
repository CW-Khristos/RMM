<#File in Folder Monitor#>
$intFiles           = 0
$fileList           = @()
$blnWARN            = $false
$varFolder          = $env:varPath
$varDestination     = $env:varMoveTo
$strLineSeparator   = "----------"
$script:ignoreList  = $env:varIgnoreFiles.split("|", [System.StringSplitOptions]::RemoveEmptyEntries)

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

$colFiles = Get-ChildItem -Path "$($varFolder)"
foreach ($file in $colFiles) {
  $blnIgnore = $false
  foreach ($ignore in $script:ignoreList) {if ($file.name -like "*$($ignore)*") {$blnIgnore = $true; break}}
  if (-not ($blnIgnore)) {
    $intFiles += 1
    $fileList += "$($file.name)`r`n"
    try {
      write-output "Moving : $($file.name)"
      $movdiag += "Moving : $($file.name)`r`n"
      move-item -path "$($file.fullname)" -destination "$($varDestination)"
      Start-Sleep -Seconds 5 
    } catch {
      $blnWARN = $true
      $err += "`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
      write-output "ERROR : $($file.name)`r`n$($err)`r`n$($strLineSeparator)"
      $movdiag += "ERROR : $($file.name)`r`n$($err)`r`n$($strLineSeparator)`r`n"
    }
  }
}

#File Verification
foreach ($file1 in $colFiles1.name) {$blnConfirm = $false;
  foreach ($file2 in $colFiles2.name) {if ($file1 -eq $file2) {write-output "$($file1) Verified"; $blnConfirm = $true; break}}
  if (-not ($blnConfirm)) {write-output "$($file1) Not Verified"; $blnWARN = $true}
}
$finish = (get-date -format "yyyy-MM-dd HH:mm:ss").ToString()
$enddiag = "$($finish)`r`n$($strLineSeparator)`r`n"
$enddiag += "There are $($intFiles) files in the target folder not matching the 'IgnoreList'`r`n$($strLineSeparator)"
$enddiag += "Target Folder : $($varFolder)`r`nDetected Files : `r`n$($fileList)`r`n$($strLineSeparator)"
$enddiag += "'IgnoreList' :`r`n$($strLineSeparator)`r`n$($script:ignoreList)`r`n$($strLineSeparator)"
$enddiag += "Move Files Output :`r`n$($strLineSeparator)`r`n$($movdiag)`r`n$($strLineSeparator)"
if ($intFiles -gt 0) {
  if ($blnWARN) {
    write-DRMMAlert "Warning - Visual Cut Files Found; Failed to Move Files"
    write-DRMMDiag "$($enddiag)"
    exit 1
  } elseif (-not ($blnWARN)) {
    write-DRMMAlert "Healthy - Visual Cut Files Found; Moved Successfully"
    write-DRMMDiag "$($enddiag)"
    exit 0
  }
} elseif ($intFiles -le 0) {
  write-DRMMAlert "Healthy - No Visual Cut Files Found"
  write-DRMMDiag "$($enddiag)"
  exit 0
}