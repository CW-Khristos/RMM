#SetPermsWithCACLS.ps1
# CACLS rights are usually
# F = FullControl
# C = Change
# R = Readonly
# W = Write

$StartingDir=Read-Host "What directory do you want to start at?"
$Right=Read-Host "What CACLS right do you want to grant? Valid choices are F, C, R or W"
Switch ($Right) {
  "F" {$Null}
  "C" {$Null}
  "R" {$Null}
  "W" {$Null}
  default {
    Write-Host -foregroundcolor "Red" `
    `n $Right.ToUpper() " is an invalid choice. Please Try again."`n
    exit
  }
}

$Principal=Read-Host "What security principal do you want to grant?" `
"CACLS right"$Right.ToUpper()"to?" `n `
"Use format domain\username or domain\group"

$Verify=Read-Host `n "You are about to change permissions on all" `
"files starting at"$StartingDir.ToUpper() `n "for security"`
"principal"$Principal.ToUpper() `
"with new right of"$Right.ToUpper()"."`n `
"Do you want to continue? [Y,N]"

if ($Verify -eq "Y") {

 foreach ($file in $(Get-ChildItem $StartingDir -recurse)) {
  #display filename and old permissions
  write-Host -foregroundcolor Yellow $file.FullName
  #uncomment if you want to see old permissions
  #CACLS $file.FullName
  
  #ADD new permission with CACLS
  CACLS $file.FullName /E /P "${Principal}:${Right}" >$NULL
  
  #display new permissions
  Write-Host -foregroundcolor Green "New Permissions"
  CACLS $file.FullName
 }
}