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
  $global:intLN = 0
  $global:diag = $null
  $global:arrCHG = [System.Collections.ArrayList]@()
  $global:arrHOST = [System.Collections.ArrayList]@()
#ENDREGION ----- DECLARATIONS ----

#REGION ----- FUNCTIONS ----
  function write-DRMMDiag ($messages) {
    write-host  '<-Start Diagnostic->'
    foreach ($Message in $Messages) {$Message}
    write-host '<-End Diagnostic->'
  } ## write-DRMMDiag
  
  function write-DRRMAlert ($message) {
    write-host '<-Start Result->'
    write-host "Alert=$($message)"
    write-host '<-End Result->'
  } ## write-DRRMAlert
#ENDREGION ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
if ((Get-ItemProperty -Path "$env:SystemRoot\System32\drivers\etc\hosts" -Name LastWriteTime).LastWriteTime -gt $((Get-Date).AddDays(-1))) {
  #COMPARE BACKUP TO CURRENT MODIFIED HOSTS FILE
  Get-Content "C:\IT\hosts" | ForEach-Object {
    $global:arrHOST.add($_)
  }
  Get-Content "$env:SystemRoot\System32\drivers\etc\hosts" | ForEach-Object {
    if ($_ -ne $global:arrHOST[$global:intLN]) {
      #FLAG CHANGE
      write-host "DETECTED CHANGE : $($_)"
      $global:diag += "DETECTED CHANGE : $($_)`r`n"
    }
    $global:intLN += 1
  }
  write-DRMMAlert "HOSTS modified within the last 24 hours. Last modification @ $((Get-ItemProperty -Path "$env:SystemRoot\System32\drivers\etc\hosts" -Name LastWriteTime).LastWriteTime)"
  write-DRMMDiag "$($global:diag)"
  Exit 1
} else {
  #WRITE HOSTS BACKUP
  Copy-Item "$env:SystemRoot\System32\drivers\etc\hosts" -Destination "C:\IT\hosts"
  write-DRRMAlert "HOSTS not modified since $((Get-ItemProperty -Path "$env:SystemRoot\System32\drivers\etc\hosts" -Name LastWriteTime).LastWriteTime)"
  Exit 0
}
#END SCRIPT
#------------