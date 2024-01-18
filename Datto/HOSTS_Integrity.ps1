<# 
.SYNOPSIS
    HOSTS monitor :: build 1/seagull

.DESCRIPTION
    Monitors the HOSTS file for changes in the past 24 hours
    Reports found changes back in diagnostic report

.NOTES
    Version        : 0.1.3 (17 January 2024)
    Creation Date  : 30 March 2022
    Purpose/Change : Monitors and reports on HOSTS file changes in the past 24 hours
    File Name      : hosts_0.1.3.ps1 
    Author         : mat s., datto labs
    Modified       : Christopher Bledsoe - cbledsoe@ipmcomputers.com

.CHANGELOG
    0.1.0 Initial Release
    0.1.1 Added ability for script to return active changes to HOSTS file

.TODO

#>

#region ----- DECLARATIONS ----
  $script:intLN       = 0
  $script:intEntries  = 0
  $script:diag        = $null
  $script:blnCHG      = $false
  $script:blnBAK      = $false
  $script:arrHOST     = [System.Collections.ArrayList]@()
#endregion ----- DECLARATIONS ----

#region ----- FUNCTIONS ----
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
#endregion ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
$strMod = $((Get-ItemProperty -Path "$($env:SystemRoot)\System32\drivers\etc\hosts" -Name LastWriteTime).LastWriteTime)
if ($strMod -gt $((Get-Date).AddDays(-1))) {
  #COMPARE BACKUP TO CURRENT MODIFIED HOSTS FILE
  write-output "GETTING HOSTS BACKUP"
  $script:diag += "GETTING HOSTS BACKUP`r`n"
  Get-Content "C:\IT\hosts" -erroraction silentlycontinue | ForEach-Object {$script:arrHOST.add($_)}
  write-output "HOSTS BACKUP ENTRIES : $($script:arrHOST.count)`r`n"
  $script:diag += "HOSTS BACKUP ENTRIES : $($script:arrHOST.count)`r`n`r`n"
  write-output "GETTING CURRENT HOSTS FILE"
  $script:diag += "GETTING CURRENT HOSTS FILE`r`n"
  Get-Content "$($env:SystemRoot)\System32\drivers\etc\hosts" | ForEach-Object {
    if (($null -ne $_) -and ($_ -ne "")) {
      if ($script:arrHOST[$script:intLN]) {
        $script:blnBAK = $true
        write-output "COMPARING : $($_) : $($script:arrHOST[$script:intLN])"
        $script:diag += "COMPARING : $($_) : $($script:arrHOST[$script:intLN])`r`n"
        if (($(($_).trim()) -match "\s") -and ($(($_).trim()) -ne $(($script:arrHOST[$script:intLN]).trim()))) {
          #FLAG CHANGE
          $script:blnCHG = $true
          write-output "DETECTED CHANGE : $($_)"
          $script:diag += "DETECTED CHANGE : $($_)`r`n"
        } else {
          write-output "MATCHED - NO CHANGE"
          $script:diag += "MATCHED - NO CHANGE`r`n"
        }
      } else {
        #FLAG CHANGE
        $script:blnBAK = $true
        $script:blnCHG = $true
        write-output "END OF BACKUP : CONTENT ADDED :`r`n`tDETECTED CHANGE : $($_)"
        $script:diag += "END OF BACKUP : CONTENT ADDED :`r`n`tDETECTED CHANGE : $($_)`r`n"
      }
    }
    $script:intEntries += 1
    $script:intLN += 1
  }
  if ($script:blnBAK -and $script:blnCHG) {
    write-output "`r`nTEXT MODIFICATIONS MADE`r`n"
    $script:diag += "`r`n`r`nTEXT MODIFICATIONS MADE`r`n"
    write-DRMMAlert "HOSTS : Modified Within 24 hours : Last Modification @ $($strMod)"
    write-DRMMDiag "$($script:diag)"
    exit 1
  } elseif (-not $script:blnCHG) {
    if ($script:blnBAK) {
      write-output "FILE MODIFIED; BUT NO TEXT MODIFICATIONS MADE :"
      $script:diag += "`r`nFILE MODIFIED; BUT NO TEXT MODIFICATIONS MADE :`r`n"
      while ($script:intLN -le $script:arrHOST.count) {
        if (($null -ne $($script:arrHOST[$script:intLN])) -and ($($script:arrHOST[$script:intLN]) -ne "")) {
          write-output "`tCONTENT LIKELY REMOVED : $($script:arrHOST[$script:intLN])"
          $script:diag += "`tCONTENT LIKELY REMOVED : $($script:arrHOST[$script:intLN])`r`n"
        }
        $script:intLN += 1
      }
      write-DRMMAlert "HOSTS : Last Modification @ $($strMod) : Content Removed / No Text Changes"
      write-DRMMDiag "$($script:diag)"
      exit 0
    } elseif (-not ($script:blnBAK)) {
      write-output "`r`nFILE MODIFIED; BUT NO BACKUP FOR COMPARISON"
      $script:diag += "`r`nFILE MODIFIED; BUT NO BACKUP FOR COMPARISON"
      write-DRMMAlert "HOSTS : Last Modification @ $($strMod) : No Backup for Comparison"
      write-DRMMDiag "$($script:diag)"
      exit 0
    }
  }
} else {
  #WRITE HOSTS BACKUP
  Copy-Item "$($env:SystemRoot)\System32\drivers\etc\hosts" -Destination "C:\IT\hosts" -force
  write-DRMMAlert "HOSTS : Not Modified Since $($strMod)"
  write-DRMMDiag "$($script:diag)"
  exit 0
}
#END SCRIPT
#------------