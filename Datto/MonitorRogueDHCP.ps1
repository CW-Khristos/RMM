#REGION ----- DECLARATIONS ----
  $blnADD = $true
  $ListedDHCPServers = @{}
  #SET TLS SECURITY FOR CONNECTING TO GITHUB
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12
#ENDREGION ----- DECLARATIONS ----

#REGION ----- FUNCTIONS ----
  function write-DRMMDiag ($messages) {
    write-host "<-Start Diagnostic->"
    foreach ($Message in $Messages) { $Message }
    write-host "<-End Diagnostic->"
  } ## write-DRMMDiag

  function write-DRRMAlert ($message) {
      write-host "<-Start Result->"
      write-host "Alert=$($message)"
      write-host "<-End Result->"
  } ## write-DRRMAlert
#ENDREGION ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
$version = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentVersion
if ($Version -lt "6.3") {
  write-host "Unsupported OS. Only Server 2012R2 and up are supported."
  #exit 1
}

try {
  $AllowedDHCPServer = Get-DhcpServerInDC
  write-host "Local Server (In AD) : $($AllowedDHCPServer)"
} catch {
  $ipV4 = Test-Connection -ComputerName "$($env:computername)" -Count 1  | Select -ExpandProperty IPV4Address 
  $AllowedDHCPServer = $ipV4.IPAddressToString
  write-host "Local Server (Local IP) : $($AllowedDHCPServer)"
}

#Replace the Download URL to where you've uploaded the DHCPTest file yourself. We will only download this file once. 
$DownloadURL = $ENV:DownloadURL
$DownloadLocation = "$($Env:ProgramData)\DHCPTest"
try {
  $TestDownloadLocation = Test-Path $DownloadLocation
  if (!$TestDownloadLocation) {new-item $DownloadLocation -ItemType Directory -force}
  $TestDownloadLocationZip = Test-Path "$($DownloadLocation)\DHCPTest.exe"
  #IPM-Khristos
  if (!$TestDownloadLocationZip) {Invoke-WebRequest -UseBasicParsing -Uri $DownloadURL -OutFile "$($DownloadLocation)\DHCPTest.exe"}
} catch {
  write-DRRMAlert "The download and extraction of DHCPTest failed. Error: $($_.Exception.Message)"
  exit 1
}
$Tests = 0
$FoundServers = do {
  & "$($DownloadLocation)\DHCPTest.exe" --quiet --query --print-only 54 --wait --timeout 3
  $Tests ++
} while ($Tests -lt 2)

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
    if ($blnADD) {
      $ListedDHCPServers.add($server, $server)
    }
  }
}
write-host "`r`nDHCP SERVERS FOUND :"
$ListedDHCPServers.values

$DHCPHealth = foreach ($ListedServer in $ListedDHCPServers.keys) {
  write-host "`r`nCHECK SERVER : $($ListedServer)"
  if ($AllowedDHCPServer.IPAddress -notcontains $ListedServer.value) {"Rogue DHCP Server found. IP of rogue server is $($ListedServer)"}
}

if (!$DHCPHealth) { 
  write-DRRMAlert "Healthy. No Rogue DHCP servers found."
  exit 0
} elseif ($DHCPHealth) { 
  write-DRRMAlert $DHCPHealth
  foreach ($ListedServer in $ListedDHCPServers.keys) {
    if ($AllowedDHCPServer.IPAddress -notcontains $ListedServer.value) {write-DRMMDiag $ListedDHCPServers.values}
  }
  exit 1
}
#END SCRIPT
#------------