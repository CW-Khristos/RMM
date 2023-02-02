# https://mspp.io/cyberdrain-automatic-documentation-scripts-to-hudu/
# https://github.com/lwhitelock/HuduAutomation/blob/main/CyberdrainRewrite/Hudu-Unifi-Documentation.ps1
# https://github.com/lwhitelock/HuduAutomation/blob/main/CyberdrainRewrite/Hudu-Unifi-Device-Documentation.ps1
# Based on the original script by Kelvin Tegelaar https://github.com/KelvinTegelaar/AutomaticDocumentation
#region ----- DECLARATIONS ----
  #BELOW PARAM() MUST BE COMMENTED OUT FOR USE WITHIN DATTO RMM
  #UNCOMMENT BELOW PARAM() AND RENAME '$env:var' TO '$var' TO UTILIZE IN CLI
  #Param(
  #  [Parameter(Mandatory=$true)]$i_urlUnifi,
  #  [Parameter(Mandatory=$true)]$i_unifiUser,
  #  [Parameter(Mandatory=$true)]$i_unifiPass,
  #  [Parameter(Mandatory=$true)]$i_HuduKey,
  #  [Parameter(Mandatory=$true)]$i_HuduDomain
  #)
  $script:diag              = $null
  $script:blnSITE           = $false
  $script:blnFAIL           = $false
  $script:blnWARN           = $false
  $strLineSeparator         = "---------"
  $script:logPath           = "C:\IT\Log\Unifi_WatchDog"
  ######################### Hudu Settings ###########################
  $script:huduCalls         = 0
  # Get a Hudu API Key from https://yourhududomain.com/admin/api_keys
  $script:HuduAPIKey        = $env:i_HuduKey
  # Set the base domain of your Hudu instance without a trailing /
  $script:HuduBaseDomain    = $env:i_HuduDomain
  #This is the name of layout from the Hudu-Unifi-Documentation.ps1 script
  $HuduSiteLayoutName       = "Unifi - AutoDoc"
  #This is the namne of the layout that will be used by this script
  $HuduAssetLayoutName      = "Unifi Device - AutoDoc"
  $TableStyling             = "<th>", "<th style=`"background-color:#4CAF50`">"
  ######################### Unifi Settings ###########################
  $script:UnifiBaseUri      = $env:i_urlUnifi
  $script:UnifiUser         = $env:i_unifiUser
  $script:UnifiPassword     = $env:i_unifiPass
  $script:UniFiCredentials  = @{
    username = $UnifiUser
    password = $UnifiPassword
    remember = $true
  } | ConvertTo-Json
  $unifiAllModels           = @"
    [{"c":"BZ2","t":"uap","n":"UniFi AP"},{"c":"BZ2LR","t":"uap","n":"UniFi AP-LR"},{"c":"U2HSR","t":"uap","n":"UniFi AP-Outdoor+"},
    {"c":"U2IW","t":"uap","n":"UniFi AP-In Wall"},{"c":"U2L48","t":"uap","n":"UniFi AP-LR"},{"c":"U2Lv2","t":"uap","n":"UniFi AP-LR v2"},
    {"c":"U2M","t":"uap","n":"UniFi AP-Mini"},{"c":"U2O","t":"uap","n":"UniFi AP-Outdoor"},{"c":"U2S48","t":"uap","n":"UniFi AP"},
    {"c":"U2Sv2","t":"uap","n":"UniFi AP v2"},{"c":"U5O","t":"uap","n":"UniFi AP-Outdoor 5G"},{"c":"U7E","t":"uap","n":"UniFi AP-AC"},
    {"c":"U7EDU","t":"uap","n":"UniFi AP-AC-EDU"},{"c":"U7Ev2","t":"uap","n":"UniFi AP-AC v2"},{"c":"U7HD","t":"uap","n":"UniFi AP-HD"},
    {"c":"U7SHD","t":"uap","n":"UniFi AP-SHD"},{"c":"U7NHD","t":"uap","n":"UniFi AP-nanoHD"},{"c":"UCXG","t":"uap","n":"UniFi AP-XG"},
    {"c":"UXSDM","t":"uap","n":"UniFi AP-BaseStationXG"},{"c":"UCMSH","t":"uap","n":"UniFi AP-MeshXG"},{"c":"U7IW","t":"uap","n":"UniFi AP-AC-In Wall"},
    {"c":"U7IWP","t":"uap","n":"UniFi AP-AC-In Wall Pro"},{"c":"U7MP","t":"uap","n":"UniFi AP-AC-Mesh-Pro"},{"c":"U7LR","t":"uap","n":"UniFi AP-AC-LR"},
    {"c":"U7LT","t":"uap","n":"UniFi AP-AC-Lite"},{"c":"U7O","t":"uap","n":"UniFi AP-AC Outdoor"},{"c":"U7P","t":"uap","n":"UniFi AP-Pro"},
    {"c":"U7MSH","t":"uap","n":"UniFi AP-AC-Mesh"},{"c":"U7PG2","t":"uap","n":"UniFi AP-AC-Pro"},{"c":"p2N","t":"uap","n":"PicoStation M2"},
    {"c":"US8","t":"usw","n":"UniFi Switch 8"},{"c":"US8P60","t":"usw","n":"UniFi Switch 8 POE-60W"},{"c":"US8P150","t":"usw","n":"UniFi Switch 8 POE-150W"},
    {"c":"S28150","t":"usw","n":"UniFi Switch 8 AT-150W"},{"c":"USC8","t":"usw","n":"UniFi Switch 8"},{"c":"US16P150","t":"usw","n":"UniFi Switch 16 POE-150W"},
    {"c":"S216150","t":"usw","n":"UniFi Switch 16 AT-150W"},{"c":"US24","t":"usw","n":"UniFi Switch 24"},{"c":"US24P250","t":"usw","n":"UniFi Switch 24 POE-250W"},
    {"c":"US24PL2","t":"usw","n":"UniFi Switch 24 L2 POE"},{"c":"US24P500","t":"usw","n":"UniFi Switch 24 POE-500W"},{"c":"S224250","t":"usw","n":"UniFi Switch 24 AT-250W"},
    {"c":"S224500","t":"usw","n":"UniFi Switch 24 AT-500W"},{"c":"US48","t":"usw","n":"UniFi Switch 48"},{"c":"US48P500","t":"usw","n":"UniFi Switch 48 POE-500W"},
    {"c":"US48PL2","t":"usw","n":"UniFi Switch 48 L2 POE"},{"c":"US48P750","t":"usw","n":"UniFi Switch 48 POE-750W"},{"c":"S248500","t":"usw","n":"UniFi Switch 48 AT-500W"},
    {"c":"S248750","t":"usw","n":"UniFi Switch 48 AT-750W"},{"c":"US6XG150","t":"usw","n":"UniFi Switch 6XG POE-150W"},{"c":"USXG","t":"usw","n":"UniFi Switch 16XG"},
    {"c":"UGW3","t":"ugw","n":"UniFi Security Gateway 3P"},{"c":"UGW4","t":"ugw","n":"UniFi Security Gateway 4P"},{"c":"UGWHD4","t":"ugw","n":"UniFi Security Gateway HD"},
    {"c":"UGWXG","t":"ugw","n":"UniFi Security Gateway XG-8"},{"c":"UP4","t":"uph","n":"UniFi Phone-X"},{"c":"UP5","t":"uph","n":"UniFi Phone"},
    {"c":"UP5t","t":"uph","n":"UniFi Phone-Pro"},{"c":"UP7","t":"uph","n":"UniFi Phone-Executive"},{"c":"UP5c","t":"uph","n":"UniFi Phone"},
    {"c":"UP5tc","t":"uph","n":"UniFi Phone-Pro"},{"c":"UP7c","t":"uph","n":"UniFi Phone-Executive"}]
"@ | ConvertFrom-Json
#endregion ----- DECLARATIONS ----

#region ----- FUNCTIONS ----
  function write-DRMMDiag ($messages) {
    write-host "<-Start Diagnostic->"
    foreach ($message in $messages) {$message}
    write-host "<-End Diagnostic->"
  } ## write-DRMMDiag
  
  function write-DRMMAlert ($message) {
    write-host "<-Start Result->"
    write-host "Alert=$($message)"
    write-host "<-End Result->"
  } ## write-DRMMAlert

  function logERR ($intSTG, $strModule, $strErr) {
    $script:blnWARN = $true
    #CUSTOM ERROR CODES
    switch ($intSTG) {
      1 {                                                         #'ERRRET'=1 - NOT ENOUGH ARGUMENTS, END SCRIPT
        $script:blnFAIL = $true
        $script:diag += "`r`n$($(get-date))`t - Unifi_WatchDog - NO ARGUMENTS PASSED, END SCRIPT`r`n`r`n"
        write-host "$($(get-date))`t - Unifi_WatchDog - NO ARGUMENTS PASSED, END SCRIPT`r`n"
      }
      2 {                                                         #'ERRRET'=2 - INSTALL / IMPORT MODULE FAILURE, END SCRIPT
        $script:blnFAIL = $true
        $script:diag += "`r`n$($(get-date))`t - Unifi_WatchDog - ($($strModule))`r`n$($strErr), END SCRIPT`r`n`r`n"
        write-host "$($(get-date))`t - Unifi_WatchDog - ($($strModule))`r`n$($strErr), END SCRIPT`r`n`r`n"
      }
      default {                                                   #'ERRRET'=3+
        $script:diag += "`r`n$($(get-date))`t - Unifi_WatchDog - $($strModule) : $($strErr)"
        write-host "$($(get-date))`t - Unifi_WatchDog - $($strModule) : $($strErr)"
      }
    }
  }

  function StopClock {
    #Stop script execution time calculation
    $script:sw.Stop()
    $Days = $sw.Elapsed.Days
    $Hours = $sw.Elapsed.Hours
    $Minutes = $sw.Elapsed.Minutes
    $Seconds = $sw.Elapsed.Seconds
    $Milliseconds = $sw.Elapsed.Milliseconds
    $ScriptStopTime = (Get-Date).ToString('dd-MM-yyyy hh:mm:ss')
    $total = ((((($Hours * 60) + $Minutes) * 60) + $Seconds) * 1000) + $Milliseconds
    $mill = [string]($total / 1000)
    $mill = $mill.split(".")[1]
    $mill = $mill.SubString(0,[math]::min(3,$mill.length))
    $script:diag += "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
    write-host "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
  }
#endregion ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
clear-host
#Start script execution time calculation
$ScrptStartTime = (Get-Date).ToString('dd-MM-yyyy hh:mm:ss')
$script:sw = [Diagnostics.Stopwatch]::StartNew()
#CHECK 'PERSISTENT' FOLDERS
if (-not (test-path -path "C:\temp")) {
  new-item -path "C:\temp" -itemtype directory
}
if (-not (test-path -path "C:\IT")) {
  new-item -path "C:\IT" -itemtype directory
}
if (-not (test-path -path "C:\IT\Log")) {
  new-item -path "C:\IT\Log" -itemtype directory
}
if (-not (test-path -path "C:\IT\Scripts")) {
  new-item -path "C:\IT\Scripts" -itemtype directory
}
#Get the Hudu API Module if not installed
Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
if (Get-Module -ListAvailable -Name HuduAPI) {
  try {
    Import-Module HuduAPI
  } catch {
    logERR 2 "HuduAPI" "INSTALL / IMPORT MODULE FAILURE"
  }
} else {
  try {
    Install-Module HuduAPI -Force -Confirm:$false
    Import-Module HuduAPI
  } catch {
    logERR 2 "HuduAPI" "INSTALL / IMPORT MODULE FAILURE"
  }
}
Set-PSRepository -Name 'PSGallery' -InstallationPolicy Untrusted
if (-not $script:blnFAIL) { 
  #Set Hudu logon information
  New-HuduAPIKey $HuduAPIKey
  New-HuduBaseUrl $HuduBaseDomain

  $SiteLayout = Get-HuduAssetLayouts -name $HuduSiteLayoutName
  if (!$SiteLayout) {
    $script:blnFAIL = $true
    $AssetLayoutFields = @(
      @{
        label = 'Site Name'
        field_type = 'Text'
        show_in_list = 'true'
        position = 1
      },
      @{
        label = 'WAN'
        field_type = 'RichText'
        show_in_list = 'false'
        position = 2
      },
      @{
        label = 'LAN'
        field_type = 'RichText'
        show_in_list = 'false'
        position = 3
      },
      @{
        label = 'VPN'
        field_type = 'RichText'
        show_in_list = 'false'
        position = 4
      },
      @{
        label = 'Wi-Fi'
        field_type = 'RichText'
        show_in_list = 'false'
        position = 5
      },
      @{
        label = 'Port Forwards'
        field_type = 'RichText'
        show_in_list = 'false'
        position = 6
      },
      @{
        label = 'Switches'
        field_type = 'RichText'
        show_in_list = 'false'
        position = 7
      }
    )
    Write-Host "Missing Site Layout $($HuduSiteLayoutName)"
    $script:diag += "Missing Site Layout $($HuduSiteLayoutName)`r`n"
    #$NewLayout = New-HuduAssetLayout -name $HuduSiteLayoutName -icon "fas fa-network-wired" -color "#4CAF50" -icon_color "#ffffff" -include_passwords $true -include_photos $true -include_comments $true -include_files $true -fields $AssetLayoutFields
    #$SiteLayout = Get-HuduAssetLayouts -name $HuduSiteLayoutName
  }
  $DeviceLayout = Get-HuduAssetLayouts -name $HuduAssetLayoutName
  if (!$DeviceLayout) {
    $script:blnFAIL = $true
    $AssetLayoutFields = @(
      @{
        label = 'Device Name'
        field_type = 'Text'
        show_in_list = 'true'
        position = 1
      },
      @{
        label = 'IP'
        field_type = 'Text'
        show_in_list = 'true'
        position = 1
      },
      @{
        label = 'MAC'
        field_type = 'Text'
        show_in_list = 'true'
        position = 1
      },
      @{
        label = 'Type'
        field_type = 'Text'
        show_in_list = 'true'
        position = 1
      },
      @{
        label = 'Model'
        field_type = 'Text'
        show_in_list = 'true'
        position = 1
      },
      @{
        label = 'Version'
        field_type = 'Text'
        show_in_list = 'true'
        position = 1
      },
      @{
        label = 'Serial Number'
        field_type = 'Text'
        show_in_list = 'true'
        position = 1
      },
      @{
        label = 'Site'
        field_type = 'AssetLink'
        show_in_list = 'true'
        position = 1
        linkable_id = $SiteLayout.id
      },
      @{
        label = 'Management URL'
        field_type = 'RichText'
        show_in_list = 'true'
        position = 1
      },
      @{
        label = 'Device Stats'
        field_type = 'RichText'
        show_in_list = 'false'
        position = 2
      }
    )
    Write-Host "Missing Asset Layout $($HuduAssetLayoutName)"
    $script:diag += "Missing Asset Layout $($HuduAssetLayoutName)`r`n"
    #$NewLayout = New-HuduAssetLayout -name $HuduAssetLayoutName -icon "fas fa-network-wired" -color "#4CAF50" -icon_color "#ffffff" -include_passwords $true -include_photos $true -include_comments $true -include_files $true -fields $AssetLayoutFields
    #$DeviceLayout = Get-HuduAssetLayouts -name $HuduAssetLayoutName
  }

  if (-not $script:blnFAIL) {
    $script:diag += "`r`n`r`n$($strLineSeparator)`r`n"
    $script:diag += "Start documentation process.`r`nLogging in to Unifi API.`r`n"
    $script:diag += "$($strLineSeparator)`r`n"
    write-host "`r`n$($strLineSeparator)"
    write-host "Start documentation process.`r`nLogging in to Unifi API." -foregroundColor green
    write-host "$($strLineSeparator)"
    try {
      Invoke-RestMethod -Uri "$($UnifiBaseUri)/login" -Method POST -Body $script:uniFiCredentials -SessionVariable websession
    } catch {
      $script:blnFAIL = $true
      $script:diag += "Failed to log in on the Unifi API.`r`n`tError was: $($_.Exception.Message)`r`n"
      $script:diag += "$($strLineSeparator)`r`n`r`n"
      write-host "Failed to log in on the Unifi API.`r`n`tError was: $($_.Exception.Message)" -ForegroundColor Red
      write-host "$($strLineSeparator)`r`n"
    }
    $script:diag += "`r`n`r`n$($strLineSeparator)`r`n"
    $script:diag += "Collecting sites from Unifi API.`r`n"
    $script:diag += "$($strLineSeparator)`r`n"
    write-host "`r`n$($strLineSeparator)"
    write-host "Collecting sites from Unifi API." -ForegroundColor Green
    write-host "$($strLineSeparator)"
    try {
      $sites = (Invoke-RestMethod -Uri "$($UnifiBaseUri)/self/sites" -WebSession $websession).data
      $sites = $sites | sort -property desc
    } catch {
      $script:blnFAIL = $true
      $script:diag += "Failed to collect the sites.`r`n`tError was: $($_.Exception.Message)`r`n"
      $script:diag += "$($strLineSeparator)`r`n`r`n"
      write-host "Failed to collect the sites.`r`n`tError was: $($_.Exception.Message)" -ForegroundColor Red
      write-host "$($strLineSeparator)`r`n"
    }

    foreach ($site in $sites) {
      ######################### Unifi Site Documentation ###########################
      #First we will see if there is an Asset that matches the site name with this Asset Layout
      write-host "`r`n$($strLineSeparator)"
      Write-Host "Attempting to map $($site.desc)"
      write-host "$($strLineSeparator)"
      $script:diag += "`r`n`r`n$($strLineSeparator)`r`n"
      $script:diag += "Attempting to map $($site.desc)`r`n"
      $script:diag += "$($strLineSeparator)`r`n"
      $SiteAsset = Get-HuduAssets -name "$($site.desc) - Unifi" -assetlayoutid $SiteLayout.id
      if (!$SiteAsset) {
        #Check on company name
        $Company = Get-HuduCompanies -name "$($site.desc)"
        if (!$company) {
          $script:diag += "A company in Hudu could not be matched to the site : $($site.desc). Please create a blank $($HuduSiteLayoutName) asset, with a name of `"$($site.desc) - Unifi`" under the company in Hudu you wish to map this site to.`r`n"
          $script:diag += "$($strLineSeparator)`r`n`r`n"
          Write-Host "A company in Hudu could not be matched to the site : $($site.desc). Please create a blank $($HuduSiteLayoutName) asset, with a name of `"$($site.desc) - Unifi`" under the company in Hudu you wish to map this site to." -ForegroundColor Red
          write-host "$($strLineSeparator)`r`n"
          continue
        }
      }
      #GET UNIFI DEVICES
      $unifiDevices = Invoke-RestMethod -Uri "$($UnifiBaseUri)/s/$($site.name)/stat/device" -WebSession $websession
      #SWITCHES
      $intPorts = 0
      $UnifiSwitches = $unifiDevices.data | Where-Object {$_.type -contains "usw"}
      $SwitchPorts = foreach ($unifiswitch in $UnifiSwitches) {
        "<h2>$($unifiswitch.name) - $($unifiswitch.mac)</h2> <table><tr>"
        foreach ($Port in $unifiswitch.port_table) {$intPorts += 1;"<th>$($port.port_idx)</th>"}
        "</tr><tr>"
        $tdWidth = (100 / $intPorts)
        foreach ($Port in $unifiswitch.port_table) {
          $speed = switch ($port.speed) {
            10000 {$colour = "02AB26";"10Gb" }
            1000 {$colour = "8DFF84";"1Gb" }
            100 {$colour = "FFEF95";"100Mb"}
            10 {$colour = "FFA24A";"10Mb" }
            0 {$colour = "696363";"Port off" }
          }
          if (-not ($port.up)) {$colour = "AD2323"}
          "<td style='width:$($tdWidth)%;background-color:#$($colour)'>$($speed)</td>"
        }
        "</tr><tr>"
        foreach ($Port in $unifiswitch.port_table) {
          $intPorts += 1
          $poestate = if ($port.poe_enable) {
            "<i class='fa-sharp fa-solid fa-bolt'></i>"
            $colour = "02AB26"
          } elseif (-not ($port.port_poe)) {
            "<i class='fa-sharp fa-solid fa-bolt-slash'></i>"
            $colour = "696363"
          } else {
            "<i class='fa-regular fa-bolt'></i>"
            $colour = "AD2323"
          }
          "<td style='background-color:#$($colour)'>$($Poestate)</td>"
        }
        "</tr></table>"
      }
      #WIRELESS
      $uaps = $unifiDevices.data | Where-Object {$_.type -contains "uap"}
      $Wifinetworks = $uaps.vap_table | Group-Object Essid
      $wifi = foreach ($Wifinetwork in $Wifinetworks) {
        $Wifinetwork | Select-object @{n = "SSID"; e = {$_.Name}}, @{n = "Access Points"; e = {$uaps.name -join "`n"}}, 
          @{n = "Channel"; e = {$_.group.channel -join ", "}}, @{n = "Usage"; e = {$_.group.usage | Sort-Object -Unique}}, @{n = "Enabled"; e = {$_.group.up | sort-object -Unique}}
      } 
      #ALARMS
      $alarms = (Invoke-RestMethod -Uri "$($UnifiBaseUri)/s/$($site.name)/stat/alarm" -WebSession $websession).data
      $alarms = $alarms | Select-Object @{n = "Universal Time"; e = {[datetime]$_.datetime }}, 
        @{n = "Device Name"; e = {$_.$(($_ | Get-Member | Where-Object {$_.Name -match "_name" }).name)}}, @{n = "Message"; e = {$_.msg}} -First 10
      #PORT FORWARDS
      $portforward = (Invoke-RestMethod -Uri "$($UnifiBaseUri)/s/$($site.name)/rest/portforward" -WebSession $websession).data
      $portForward = $portforward | Select-Object Name, @{n = "Source"; e = {"$($_.src):$($_.dst_port)"}}, 
        @{n = "Destination"; e = {"$($_.fwd):$($_.fwd_port)"}}, @{n = "Protocol"; e = {$_.proto}}
      #NETWORK CONFIG
      $networkConf = (Invoke-RestMethod -Uri "$($UnifiBaseUri)/s/$($site.name)/rest/networkconf" -WebSession $websession).data
      $NetworkInfo = foreach ($network in $networkConf) {
        [pscustomobject] @{
          'Purpose'                 = $network.purpose
          'Name'                    = $network.name
          'vlan'                    = "$($network.vlan_enabled) $($network.vlan)"
          "LAN IP Subnet"           = $network.ip_subnet                 
          "LAN DHCP Relay Enabled"  = $network.dhcp_relay_enabled        
          "LAN DHCP Enabled"        = $network.dhcpd_enabled
          "LAN Network Group"       = $network.networkgroup              
          "LAN Domain Name"         = $network.domain_name               
          "LAN DHCP Lease Time"     = $network.dhcpd_leasetime           
          "LAN DNS 1"               = $network.dhcpd_dns_1               
          "LAN DNS 2"               = $network.dhcpd_dns_2               
          "LAN DNS 3"               = $network.dhcpd_dns_3               
          "LAN DNS 4"               = $network.dhcpd_dns_4                           
          'DHCP Range'              = "$($network.dhcpd_start) - $($network.dhcpd_stop)"
          "WAN IP Type"             = $network.wan_type 
          'WAN IP'                  = $network.wan_ip 
          "WAN Subnet"              = $network.wan_netmask
          'WAN Gateway'             = $network.wan_gateway 
          "WAN DNS 1"               = $network.wan_dns1 
          "WAN DNS 2"               = $network.wan_dns2 
          "WAN Failover Type"       = $network.wan_load_balance_type
          'VPN Ike Version'         = $network.ipsec_key_exchange
          'VPN Encryption protocol' = $network.ipsec_encryption
          'VPN Hashing protocol'    = $network.ipsec_hash
          'VPN DH Group'            = $network.ipsec_dh_group
          'VPN PFS Enabled'         = $network.ipsec_pfs
          'VPN Dynamic Routing'     = $network.ipsec_dynamic_routing
          'VPN Local IP'            = $network.ipsec_local_ip
          'VPN Peer IP'             = $network.ipsec_peer_ip
          'VPN IPSEC Key'           = $network.x_ipsec_pre_shared_key
        }
      }
      #CONVERT TO HTML TABLES
      $WANs = ($networkinfo | where-object {$_.Purpose -eq "wan"} | select-object Name, *WAN* | convertto-html -frag | out-string) -replace $tablestyling
      $LANS = ($networkinfo | where-object {$_.Purpose -eq "corporate"} | select-object Name, *LAN* | convertto-html -frag | out-string) -replace $tablestyling
      $VPNs = ($networkinfo | where-object {$_.Purpose -eq "site-vpn"} | select-object Name, *VPN* | convertto-html -frag | out-string) -replace $tablestyling
      $Wifi = ($wifi | convertto-html -frag | out-string) -replace $tablestyling
      $PortForwards = ($Portforward | convertto-html -frag | out-string) -replace $tablestyling

      $AssetName = "$($site.desc) - Unifi"
      $AssetFields = @{
        'site_name'     = $site.name
        'wan'           = $WANs
        'lan'           = $LANS
        'vpn'           = $VPNs
        'wi-fi'          = $wifi
        'port_forwards' = $PortForwards
        'switches'      = ($SwitchPorts | out-string)
      }
      
      if (!$SiteAsset) {
        $script:blnSITE = $true
        $companyid = $company.id
        Write-Host "Creating new Site Unifi - AutoDoc : $($AssetName)"
        write-host "$($strLineSeparator)"
        $script:diag += "Creating new Site Unifi - AutoDoc : $($AssetName)`r`n"
        $script:diag += "$($strLineSeparator)`r`n"
        try {
          $SiteAsset = New-HuduAsset -name $AssetName -company_id $companyid -asset_layout_id $SiteLayout.id -fields $AssetFields	
        } catch {
          Write-Host "Error Creating new Site Unifi - AutoDoc : $($AssetName)" -foregroundColor red
          write-host "$($strLineSeparator)`r`n"
          $script:diag += "Error Creating new Site Unifi - AutoDoc : $($AssetName)`r`n"
          $script:diag += "$($strLineSeparator)`r`n`r`n"
          $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
          logERR 3 "Create Site Unifi - AutoDoc" $err
        }
      } else {
        $companyid = $SiteAsset.company_id
        Write-Host "Updating Site Unifi - AutoDoc : $($AssetName)"
        write-host "$($strLineSeparator)"
        $script:diag += "Updating Site Unifi - AutoDoc : $($AssetName)`r`n"
        $script:diag += "$($strLineSeparator)`r`n"
        try {
          $SiteAsset = Set-HuduAsset -asset_id $SiteAsset.id -name $AssetName -company_id $companyid -asset_layout_id $SiteLayout.id -fields $AssetFields	
        } catch {
          Write-Host "Error Updating Site Unifi - AutoDoc : $($AssetName)" -foregroundColor red
          write-host "$($strLineSeparator)`r`n"
          $script:diag += "Error Updating Site Unifi - AutoDoc : $($AssetName)`r`n"
          $script:diag += "$($strLineSeparator)`r`n`r`n"
          $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
          logERR 3 "Create Site Unifi - AutoDoc" $err
        }
      }
      ######################### Unifi Device Documentation ###########################
      write-host "`r`n$($strLineSeparator)"
      Write-Host "Attempting to map $($site.desc) devices"
      write-host "$($strLineSeparator)"
      $script:diag += "`r`n`r`n$($strLineSeparator)`r`n"
      $script:diag += "Attempting to map $($site.desc) devices`r`n"
      $script:diag += "$($strLineSeparator)`r`n"
      if (!$SiteLayout) {
        $script:diag += "Please run the Hudu-Unifi-Documentation.ps1 first to create the Unifi site layout or check the name in '$($HuduSiteLayoutName)'`r`n"
        $script:diag += "$($strLineSeparator)`r`n`r`n"
        Write-Host "Please run the Hudu-Unifi-Documentation.ps1 first to create the Unifi site layout or check the name in '$($HuduSiteLayoutName)'"
        write-host "$($strLineSeparator)`r`n"
        #WRITE TO LOGFILE
        "$($script:diag)" | add-content $script:logPath -force
        write-DRMMAlert "Unifi_WatchDog : Execution Failed : Please Create the 'Unifi - AutoDoc' Site Layout"
        write-DRMMDiag "$($script:diag)"
        $script:diag = $null
        exit 1
      }
      $SiteAsset = Get-HuduAssets -name "$($site.desc) - Unifi" -assetlayoutid $SiteLayout.id
      if (!$SiteAsset) {
        $script:diag += "A Site in Hudu could not be matched to the site : $($site.desc). Please create a blank Unifi site asset (created with the other Unifi Sync script), with a name of `"$($site.desc) - Unifi`" under the company in Hudu you wish to map this site to.`r`n"
        $script:diag += "$($strLineSeparator)`r`n`r`n"
        Write-Host "A Site in Hudu could not be matched to the site : $($site.desc). Please create a blank Unifi site asset (created with the other Unifi Sync script), with a name of `"$($site.desc) - Unifi`" under the company in Hudu you wish to map this site to."  -ForegroundColor Red
        write-host "$($strLineSeparator)`r`n"
        continue
      }
      
      $Companyid    = $SiteAsset.company_id
      $UnifiRoot    = $UnifiBaseUri.trim("/api")
      $unifiDevices = Invoke-RestMethod -Uri "$($UnifiBaseUri)/s/$($site.name)/stat/device" -WebSession $websession
      foreach ($device in $unifiDevices.data) {
        $LoadHTML = ($device.sys_stats | convertto-html -as list -frag | out-string)
        $ResourceHTML = ($device.'system-stats' | convertto-html -as list -frag | out-string)
        $StatsHTML = $ResourceHTML + $LoadHTML
        $model = ($unifiAllModels | where-object {$_.c -eq $device.model} | select n).n
        if (!$model) {
          $model = "Unknown - $($device.model)"
        } else {
          $model = "$model - $($device.model)"
        }
        if (!$($device.name)){
          $devicename = "$($model) - $($device.mac)"
        } else {
          $devicename = $device.name
        }
        $AssetName          = $devicename
        $AssetFields        = @{
          'device_name'     = $device.name
          'ip'              = $device.ip
          'mac'             = $device.mac
          'type'            = $device.type
          'model'           = $model
          'version'         = $device.version
          'serial_number'   = $device.serial
          'site'            = $SiteAsset.id
          'management_url'  = "<a href=`"$($UniFiRoot)/manage/site/$($site.name)/devices/list/1/100`" >$($UniFiRoot)/manage/site/$($site.name)/devices/list/1/100</a>"
          'device_stats'    = $StatsHTML
        }
        #Check if there is already an asset	
        $Asset = Get-HuduAssets -name $AssetName -companyid $companyid -assetlayoutid $DeviceLayout.id
        if (!$Asset) {
          Write-Host "Creating new Asset - $($AssetName)"
          write-host "$($strLineSeparator)"
          $script:diag += "Creating new Asset - $($AssetName)`r`n"
          $script:diag += "$($strLineSeparator)`r`n"
          $Asset = New-HuduAsset -name $AssetName -company_id $companyid -asset_layout_id $DeviceLayout.id -fields $AssetFields	
        } else {
          Write-Host "Updating Asset - $($AssetName)"
          write-host "$($strLineSeparator)"
          $script:diag += "Updating Asset - $($AssetName)`r`n"
          $script:diag += "$($strLineSeparator)`r`n"
          $Asset = Set-HuduAsset -asset_id $Asset.id -name $AssetName -company_id $companyid -asset_layout_id $DeviceLayout.id -fields $AssetFields	
        }
      }
    }
  }
  #DATTO OUTPUT
  #Stop script execution time calculation
  StopClock
  #CLEAR LOGFILE
  $null | set-content $script:logPath -force
  if ($script:blnSITE) {
    #WRITE TO LOGFILE
    $script:diag += "`r`n`r`nUnifi_WatchDog : Execution Successful : Site(s) Created - See Diagnostics"
    "$($script:diag)" | add-content $script:logPath -force
    write-DRMMAlert "Unifi_WatchDog : Execution Successful : Site(s) Created - See Diagnostics"
    write-DRMMDiag "$($script:diag)"
    $script:diag = $null
    exit 1
  }
  if (-not $script:blnWARN) {
    #WRITE TO LOGFILE
    $script:diag += "`r`n`r`nUnifi_WatchDog : Execution Successful : No Sites Created"
    "$($script:diag)" | add-content $script:logPath -force
    write-DRMMAlert "Unifi_WatchDog : Execution Successful : No Sites Created"
    write-DRMMDiag "$($script:diag)"
    $script:diag = $null
    exit 0
  } elseif ($script:blnWARN) {
    #WRITE TO LOGFILE
    $script:diag += "`r`n`r`nUnifi_WatchDog : Execution Completed with Warnings : See Diagnostics"
    "$($script:diag)" | add-content $script:logPath -force
    write-DRMMAlert "Unifi_WatchDog : Execution Completed with Warnings : See Diagnostics"
    write-DRMMDiag "$($script:diag)"
    $script:diag = $null
    exit 1
  }
} elseif ($script:blnFAIL) {
  #Stop script execution time calculation
  StopClock
  #CLEAR LOGFILE
  $null | set-content $script:logPath -force
  #WRITE TO LOGFILE
  $script:diag += "`r`n`r`nUnifi_WatchDog : Execution Failed : See Diagnostics"
  "$($script:diag)" | add-content $script:logPath -force
  write-DRMMAlert "Unifi_WatchDog : Execution Failure : See Diagnostics"
  write-DRMMDiag "$($script:diag)"
  $script:diag = $null
  exit 1
}
#END SCRIPT
#------------