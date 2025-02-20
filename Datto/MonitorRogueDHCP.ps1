#REGION ----- DECLARATIONS ----
  $blnADD = $true
  $blnWARN = $false
  $ListedDHCPServers = @{}
  #SET TLS SECURITY FOR CONNECTING TO GITHUB
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12
#ENDREGION ----- DECLARATIONS ----

#REGION ----- FUNCTIONS ----
  function write-DRMMDiag ($messages) {
    write-output "<-Start Diagnostic->"
    foreach ($Message in $Messages) { $Message }
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
$version = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentVersion
if ($Version -lt "6.3") {
  write-output "Unsupported OS. Only Server 2012R2 and up are supported."
  #exit 1
}

try {
  $AllowedDHCPServer = Get-DhcpServerInDC
  write-output "Local Server (In AD) : "
  $AllowedDHCPServer
} catch {
  $ipV4 = Test-Connection -ComputerName "$($env:computername)" -Count 1  | Select -ExpandProperty IPV4Address 
  $AllowedDHCPServer = $ipV4.IPAddressToString
  write-output "Local Server (Local IP) :"
  $AllowedDHCPServer
}

#Replace the Download URL to where you've uploaded the DHCPTest file yourself. We will only download this file once. 
$DownloadURL = $ENV:DownloadURL
$DownloadLocation = "$($Env:ProgramData)\DHCPTest"
try {
  $TestDownloadLocation = Test-Path $DownloadLocation
  if (!$TestDownloadLocation) {new-item $DownloadLocation -ItemType Directory -force}
  $TestDownloadLocationZip = Test-Path "$($DownloadLocation)\DHCPTest.exe"
  if (!$TestDownloadLocationZip) {Invoke-WebRequest -UseBasicParsing -Uri $DownloadURL -OutFile "$($DownloadLocation)\DHCPTest.exe"}
} catch {
  write-DRMMAlert "The download and extraction of DHCPTest failed. Error: $($_.Exception.Message)"
  exit 1
}
$Tests = 0
$FoundServers = do {
  & "$($DownloadLocation)\DHCPTest.exe" --quiet --query --print-only 54 --wait --timeout 3
  $Tests ++
} while ($Tests -lt 2)
write-output "`r`nDHCP SERVERS FOUND (via DHCPTest) :"
$FoundServers

#ENSURE ONLY UNIQUE SERVERS ARE IN '$ListedDHCPServers' HASHTABLE
foreach ($server in $FoundServers) {
  if ($ListedDHCPServers.count -eq 0) {
    $ListedDHCPServers.add($server, $server)
  } elseif ($ListedDHCPServers.count -gt 0) {
    $blnADD = $true
    foreach ($dhcp in $ListedDHCPServers.keys) {
      if ($server -eq $dhcp) {
        $blnADD = $false
        break
      }
    }
    if ($blnADD) {$ListedDHCPServers.add($server, $server)}
  }
}
write-output "`r`nDHCP SERVERS TO CHECK :"
$ListedDHCPServers.values

$DHCPHealth = foreach ($ListedServer in $ListedDHCPServers.values) {
  write-output "`r`nCHECK SERVER : "
  $ListedServer
  if ($AllowedDHCPServer.IPAddress -notcontains $ListedServer) {
    $blnWARN = $true
    write-output "Rogue DHCP Server found. IP of rogue server is $($ListedServer)"
  } elseif ($AllowedDHCPServer.IPAddress -contains $ListedServer) {
    write-output "Authorized DHCP Server found. IP of DHCP server is $($ListedServer)"
  }
}
$DHCPHealth = $DHCPHealth | out-string

if (-not $blnWARN) { 
  write-DRMMAlert "Healthy. No Rogue DHCP servers found."
  exit 0
} elseif ($blnWARN) { 
  write-DRMMAlert $DHCPHealth
  foreach ($ListedServer in $ListedDHCPServers.values) {
    if ($AllowedDHCPServer.IPAddress -notcontains $ListedServer) {write-DRMMDiag $ListedServer}
  }
  exit 1
}
#END SCRIPT
#------------