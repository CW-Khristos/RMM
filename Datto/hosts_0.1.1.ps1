<# 
.SYNOPSIS
    HOSTS monitor :: build 1/seagull

.DESCRIPTION
    Monitors the HOSTS file for changes in the past 24 hours
    Reports found changes back in diagnostic report

.NOTES
    Version        : 0.1.1 (30 March 2022)
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
  $script:arrCHG = [System.Collections.ArrayList]@()
  $script:arrHOST = [System.Collections.ArrayList]@()
#ENDREGION ----- DECLARATIONS ----

#REGION ----- FUNCTIONS ----
  function write-DRMMDiag ($messages) {
    write-output  '<-Start Diagnostic->'
    foreach ($Message in $Messages) {$Message}
    write-output '<-End Diagnostic->'
  } ## write-DRMMDiag
  
  function write-DRMMAlert ($message) {
    write-output '<-Start Result->'
    write-output "Alert=$($message)"
    write-output '<-End Result->'
  } ## write-DRRMAlert
#ENDREGION ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
if ((Get-ItemProperty -Path "$env:SystemRoot\System32\drivers\etc\hosts" -Name LastWriteTime).LastWriteTime -gt $((Get-Date).AddDays(-1))) {
  #COMPARE BACKUP TO CURRENT MODIFIED HOSTS FILE
  Get-Content "C:\IT\hosts" | ForEach-Object {
    $script:arrHOST.add($_)
  }
  Get-Content "$env:SystemRoot\System32\drivers\etc\hosts" | ForEach-Object {
    if ((($null -ne $_) -and ($_ -ne "")) -and ($_ -ne $script:arrHOST[$script:intLN])) {
      #FLAG CHANGE
      write-output "DETECTED CHANGE : $($_)"
      $script:diag += "DETECTED CHANGE : $($_)`r`n"
      $script:arrCHG.add($_)
    }
    $script:intLN += 1
  }
  write-output $script:arrCHG
  $strMod = $((Get-ItemProperty -Path "$env:SystemRoot\System32\drivers\etc\hosts" -Name LastWriteTime).LastWriteTime)
  write-DRMMAlert "HOSTS modified within the last 24 hours. Last modification @ $($strMod)"
  write-DRMMDiag "$($script:diag)"
  Exit 1
} else {
  #WRITE HOSTS BACKUP
  $strMod = $((Get-ItemProperty -Path "$env:SystemRoot\System32\drivers\etc\hosts" -Name LastWriteTime).LastWriteTime)
  Copy-Item "$env:SystemRoot\System32\drivers\etc\hosts" -Destination "C:\IT\hosts"
  write-DRMMAlert "HOSTS not modified since $($strMod)"
  Exit 0
}
#END SCRIPT
#------------