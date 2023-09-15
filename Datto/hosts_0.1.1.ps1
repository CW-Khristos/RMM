<# 
.SYNOPSIS
    HOSTS monitor :: build 1/seagull

.DESCRIPTION
    Monitors the HOSTS file for changes in the past 24 hours
    Reports found changes back in diagnostic report

.NOTES
    Version        : 0.1.2 (05 September 2023)
    Creation Date  : 30 March 2022
    Purpose/Change : Monitors and reports on HOSTS file changes in the past 24 hours
    File Name      : hosts_0.1.1.ps1 
    Author         : mat s., datto labs
    Modified       : Christopher Bledsoe - cbledsoe@ipmcomputers.com

.CHANGELOG
    0.1.0 Initial Release
    0.1.1 Added ability for script to return active changes to HOSTS file

.TODO

#>

#REGION ----- DECLARATIONS ----
  $script:intLN = 0
  $script:diag = $null
  $script:blnCHG = $false
  $script:blnBAK = $false
  $script:arrHOST = [System.Collections.ArrayList]@()
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
#ENDREGION ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
$strMod = $((Get-ItemProperty -Path "$env:SystemRoot\System32\drivers\etc\hosts" -Name LastWriteTime).LastWriteTime)
if ($strMod -gt $((Get-Date).AddDays(-1))) {
  #COMPARE BACKUP TO CURRENT MODIFIED HOSTS FILE
  Get-Content "C:\IT\hosts" -erroraction silentlycontinue | ForEach-Object {
    $script:arrHOST.add($_)
  }
  Get-Content "$env:SystemRoot\System32\drivers\etc\hosts" | ForEach-Object {
    if (($null -ne $_) -and ($_ -ne "")) {
      if ($script:arrHOST) {
        $script:blnBAK = $true
          write-output "COMPARING : $($_) : $($script:arrHOST[$script:intLN])"
          $script:diag += "COMPARING : $($_) : $($script:arrHOST[$script:intLN])`r`n"
          if (($_ -match "\s") -and ($_ -ne $script:arrHOST[$script:intLN])) {
            #FLAG CHANGE
            $script:blnCHG = $true
            write-output "DETECTED CHANGE : $($_)"
            $script:diag += "DETECTED CHANGE : $($_)`r`n"
          } else {
            write-output "MATCHED - NO CHANGE"
            $script:diag += "MATCHED - NO CHANGE`r`n"
          }
      }
    }
    $script:intLN += 1
  }
  if ($script:blnBAK -and $script:blnCHG) {
    write-output "`r`nTEXT MODIFICATIONS MADE"
    $script:diag += "`r`nTEXT MODIFICATIONS MADE"
    write-DRMMAlert "HOSTS : Modified Within 24 hours. Last Modification @ $($strMod)"
    write-DRMMDiag "$($script:diag)"
    exit 1
  } elseif (-not $script:blnCHG) {
    if ($script:blnBAK) {
        write-output "`r`nFILE MODIFIED; BUT NO TEXT MODIFICATIONS MADE"
        $script:diag += "`r`nFILE MODIFIED; BUT NO TEXT MODIFICATIONS MADE"
        write-DRMMAlert "HOSTS : Last Modification @ $($strMod) : No Text Changes"
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
  Copy-Item "$env:SystemRoot\System32\drivers\etc\hosts" -Destination "C:\IT\hosts"
  write-DRMMAlert "HOSTS : Not Modified Since $($strMod)"
  write-DRMMDiag "$($script:diag)"
  exit 0
}
#END SCRIPT
#------------