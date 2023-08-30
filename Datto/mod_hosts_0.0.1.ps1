<# 
.SYNOPSIS

.DESCRIPTION
    Modifies the HOSTS file and adds a static entry

.NOTES
    Version        : 0.1.1 (28 July 2022)
    Creation Date  : 28 July 2022
    Purpose/Change : Modifies HOSTS file
    File Name      : mod_hosts_0.0.1.ps1 
    Author         : Christopher Bledsoe - cbledsoe@ipmcomputers.com

.CHANGELOG
    0.1.0 Initial Release

.TODO

#>

#REGION ----- DECLARATIONS ----
  #BELOW PARAM() MUST BE COMMENTED OUT FOR USE WITHIN DATTO RMM
  #UNCOMMENT BELOW PARAM() AND RENAME '$env:var' TO '$var' TO UTILIZE IN CLI
  #Param (
  #  [Parameter(Mandatory=$true)]$i_IP,
  #  [Parameter(Mandatory=$true)]$i_Host,
  #) 
  $script:diag = $null
  $script:blnMOD = $true
#ENDREGION ----- DECLARATIONS ----

#REGION ----- FUNCTIONS ----
  function write-DRMMDiag ($messages) {
    write-output "<-Start Diagnostic->"
    foreach ($message in $messages) {$message}
    write-output "<-End Diagnostic->"
  } ## write-DRMMDiag
  
  function write-DRMMAlert ($message) {
    write-output "<-Start Result->"
    write-output "Alert=$($message)"
    write-output "<-End Result->"
  } ## write-DRRMAlert
#ENDREGION ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
#RETRIEVE CURRENT HOSTS FILE
write-output "SCANNING HOSTS :`r`n"
$script:diag += "SCANNING HOSTS :`r`n`r`n"
get-content "$env:SystemRoot\System32\drivers\etc\hosts" | foreach-object {
  $script:blnMOD
  if (($_ -match "$($env:i_IP)") -and ($_ -match "$($env:i_Host)")) {$script:blnMOD = $false}
  $hosts += "$($_)`r`n"
}
write-output "CURRENT HOSTS :"
write-output "$($hosts)`r`n"
$script:diag += "CURRENT HOSTS :`r`n"
$script:diag += "$($hosts)`r`n`r`n"
if ($blnMOD) {
  write-output "MODIFYING HOSTS...`r`n"
  $script:diag += "MODIFYING HOSTS...`r`n`r`n"
  $hosts = "$($hosts)`r`n$($env:i_IP)`t$($env:i_Host)"
  #WRITE HOSTS FILE
  try {
    remove-item "$env:SystemRoot\System32\drivers\etc\hosts" -force
    set-content -path "$env:SystemRoot\System32\drivers\etc\hosts" -value "$($hosts)" -force
    write-output "MODIFIED HOSTS :"
    $script:diag += "MODIFIED HOSTS :`r`n"
    get-content "$env:SystemRoot\System32\drivers\etc\hosts" | foreach-object {
      write-output "$($_)`r`n"
      $script:diag += "$($_)`r`n"
    }
    write-DRMMAlert "HOSTS file modified successfully"
    write-DRMMDiag "$($script:diag)"
    exit 0
  } catch {
    $script:diag += "HOSTS file modification failed.`r`n`r`n$($_.Exception)`r`n-----`r`n"
    $script:diag += "$($_.scriptstacktrace)`r`n-----`r`n$($_)`r`n"
    write-output "HOSTS file modification failed.`r`n`r`n$($_.Exception)`r`n-----"
    write-output "$($_.scriptstacktrace)`r`n-----`r`n$($_)`r`n"
    write-DRMMAlert "HOSTS file modification failed. See Diagnostics"
    write-DRMMDiag "$($script:diag)"
    exit 1
  }
} elseif (-not ($blnMOD)) {
  write-output "HOSTS file does not require modification"
  $script:diag += "HOSTS file does not require modification`r`n"
  write-DRMMAlert "HOSTS file does not require modification"
  write-DRMMDiag "$($script:diag)"
  exit 0
}
#END SCRIPT
#------------