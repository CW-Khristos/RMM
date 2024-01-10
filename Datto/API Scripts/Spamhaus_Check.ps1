#First Clear any variables
Remove-Variable * -ErrorAction SilentlyContinue

#region ----- DECLARATIONS ----
  $script:diag              = $null
  $script:blnFAIL           = $false
  $script:blnWARN           = $false
  $script:blnSITE           = $false
  $script:strLineSeparator  = "---------"
  $script:logPath           = "C:\IT\Log\Spamhaus_Check"
  $script:spamCHECK         = @{}
  $script:spamMAP           = @{
    "Spamhaus"              = @{
      siteAddress           = "zen.spamhaus.org" 
      returnCodes           = @{
        "127.0.0.2"         = @{
          zone         = "SBL"
          description  = "Spamhaus SBL Data"
        }
        "127.0.0.3"         = @{
          zone         = "SBL"
          description  = "Spamhaus SBL CSS Data"
        }
        "127.0.0.4"         = @{
          zone         = "XBL"
          description  = "CBL Data"
        }
        "127.0.0.9"         = @{
          zone         = "SBL"
          description  = "Spamhaus DROP/EDROP Data"
        }
        <#"127.0.0.10"      = @{
          zone         = "PBL"
          description  = "ISP Maintained PBL Data"
        }
        "127.0.0.11"        = @{
          zone         = "PBL"
          description  = "Spamhaus Maintained PBL Data"
        }#>
      }
    }
    "AbuseAT"               = @{
      siteAddress           = "cbl.abuseat.org"
      returnCodes           = @{
        "127.0.0.2"         = @{
          zone         = "SBL"
          description  = "AbuseAT SBL Data"
        }
        "127.0.0.3"         = @{
          zone         = "SBL"
          description  = "AbuseAT SBL CSS Data"
        }
        "127.0.0.4"         = @{
          zone         = "XBL"
          description  = "CBL Data"
        }
        "127.0.0.9"         = @{
          zone         = "SBL"
          description  = "AbuseAT DROP/EDROP Data"
        }
        <#"127.0.0.10"      = @{
          zone         = "PBL"
          description  = "ISP Maintained PBL Data"
        }
        "127.0.0.11"        = @{
          zone         = "PBL"
          description  = "AbuseAT Maintained PBL Data"
        }#>
      }
    }
	  "Sorbs"                 = @{
      siteAddress           = "dnsbl.sorbs.net"
      returnCodes           = @{
        "127.0.0.2"         = @{
          zone         = "SBL"
          description  = "Sorbs SBL Data"
        }
        "127.0.0.3"         = @{
          zone         = "SBL"
          description  = "Sorbs SBL CSS Data"
        }
        "127.0.0.4"         = @{
          zone         = "XBL"
          description  = "CBL Data"
        }
        "127.0.0.9"         = @{
          zone         = "SBL"
          description  = "Sorbs DROP/EDROP Data"
        }
        <#"127.0.0.10"      = @{
          zone         = "PBL"
          description  = "ISP Maintained PBL Data"
        }
        "127.0.0.11"        = @{
          zone         = "PBL"
          description  = "Sorbs Maintained PBL Data"
        }#>
      }
    }
	  "SpamCop"               = @{
      siteAddress           = "bl.spamcop.net"
      returnCodes           = @{
        "127.0.0.2"         = @{
          zone         = "SBL"
          description  = "SpamCop SBL Data"
        }
        "127.0.0.3"         = @{
          zone         = "SBL"
          description  = "SpamCop SBL CSS Data"
        }
        "127.0.0.4"         = @{
          zone         = "XBL"
          description  = "CBL Data"
        }
        "127.0.0.9"         = @{
          zone         = "SBL"
          description  = "SpamCop DROP/EDROP Data"
        }
        <#"127.0.0.10"      = @{
          zone         = "PBL"
          description  = "ISP Maintained PBL Data"
        }
        "127.0.0.11"        = @{
          zone         = "PBL"
          description  = "SpamCop Maintained PBL Data"
        }#>
      }
    }
	  "BarracudaCentral"      = @{
      siteAddress           = "b.barracudacentral.org"
      returnCodes           = @{
        "127.0.0.2"         = @{
          zone         = "SBL"
          description  = "BarracudaCentral SBL Data"
        }
        "127.0.0.3"         = @{
          zone         = "SBL"
          description  = "BarracudaCentral SBL CSS Data"
        }
        "127.0.0.4"         = @{
          zone         = "XBL"
          description  = "CBL Data"
        }
        "127.0.0.9"         = @{
          zone         = "SBL"
          description  = "BarracudaCentral DROP/EDROP Data"
        }
        <#"127.0.0.10"      = @{
          zone         = "PBL"
          description  = "ISP Maintained PBL Data"
        }
        "127.0.0.11"        = @{
          zone         = "PBL"
          description  = "BarracudaCentral Maintained PBL Data"
        }#>
      }
    }
	  "PskyMe"                = @{
      siteAddress           = "bad.psky.me"
      returnCodes           = @{
        "127.0.0.2"         = @{
          zone         = "SBL"
          description  = "PskyMe SBL Data"
        }
        "127.0.0.3"         = @{
          zone         = "SBL"
          description  = "PskyMe SBL CSS Data"
        }
        "127.0.0.4"         = @{
          zone         = "XBL"
          description  = "CBL Data"
        }
        "127.0.0.9"         = @{
          zone         = "SBL"
          description  = "PskyMe DROP/EDROP Data"
        }
        <#"127.0.0.10"      = @{
          zone         = "PBL"
          description  = "ISP Maintained PBL Data"
        }
        "127.0.0.11"        = @{
          zone         = "PBL"
          description  = "PskyMe Maintained PBL Data"
        }#>
      }
    }
  }
  #region######################## TLS Settings ###########################
  #[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType] 'Tls12'
  [System.Net.ServicePointManager]::SecurityProtocol = (
    [System.Net.SecurityProtocolType]::Tls13 -bor 
    [System.Net.SecurityProtocolType]::Tls12 -bor 
    [System.Net.SecurityProtocolType]::Tls11 -bor 
    [System.Net.SecurityProtocolType]::Tls
  )
  #endregion
  #region######################## RMM Settings ###########################
  #RMM API CREDS
  $script:rmmToken          = $null
  $script:rmmKey            = $env:DRMMAPIKey
  $script:rmmSecret         = $env:DRMMAPISecret
  #RMM API VARS
  $script:rmmSites          = 0
  $script:rmmCalls          = 0
  $script:rmmUDF            = 25
  $script:rmmAPI            = $env:DRMMAPIBase
  #endregion
  #region######################## Autotask Settings ###########################
  #PSA API DATASETS
  $script:psaCountries      = $null
  $script:classMap          = @{}
  $script:categoryMap       = @{}
  $script:ciTypeMap         = @{}
  $script:ticketFields      = @{}
  $script:typeMap           = @{
    1 = "Customer"
    2 = "Lead"
    3 = "Prospect"
    4 = "Dead"
    6 = "Cancelation"
    7 = "Vendor"
    8 = "Partner"
  }
  $script:psaSkip           = @(
    "Cancelation", "Dead", "Lead", "Partner", "Prospect", "Vendor"
  )
  #PSA API CREDS
  $script:psaUser           = $env:ATAPIUser
  $script:psaKey            = $env:ATAPIUser
  $script:psaSecret         = $env:ATAPISecret
  $script:psaIntegration    = $env:ATIntegratorID
  $script:psaHeaders        = @{
    'UserName'              = "$($script:psaKey)"
    'Secret'                = "$($script:psaSecret)"
    'ApiIntegrationCode'    = "$($script:psaIntegration)"
  }
  #PSA API VARS
  $script:psaCalls          = 0
  $script:psaAPI            = $env:ATAPIBase
  $script:psaGenFilter      = '{"Filter":[{"field":"Id","op":"gte","value":0}]}'
  $script:psaActFilter      = '{"Filter":[{"op":"and","items":[{"field":"IsActive","op":"eq","value":true},{"field":"Id","op":"gte","value":0}]}]}'
  #endregion
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

#region ----- API FUNCTIONS ----
#region ----- AT FUNCTIONS ----
  function PSA-Query {
    param ($header, $method, $entity)
    $params = @{
      Method      = "$($method)"
      ContentType = 'application/json'
      Uri         = "$($script:psaAPI)/$($entity)"
      Headers     = $header
    }
    $script:psaCalls += 1
    try {
      Invoke-RestMethod @params -UseBasicParsing -erroraction stop
    } catch {
      $script:blnWARN = $true
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
      logERR 4 "PSA-Query" "Failed to query PSA API via $($params.Uri)`r`n$($err)"
    }
  }

  function PSA-FilterQuery {
    param ($header, $method, $entity, $filter)
    $params = @{
      Method      = "$($method)"
      ContentType = 'application/json'
      Uri         = "$($script:psaAPI)/$($entity)/query?search=$($filter)"
      Headers     = $header
    }
    $script:psaCalls += 1
    try {
      Invoke-RestMethod @params -UseBasicParsing -erroraction stop
    } catch {
      $script:blnWARN = $true
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
      logERR 4 "PSA-FilterQuery" "Failed to query (filtered) PSA API via $($params.Uri)`r`n$($err)"
    }
  }

  function PSA-Put {
    param ($header, $method, $entity, $body)
    $params = @{
      Method      = "$($method)"
      ContentType = 'application/json'
      Uri         = "$($script:psaAPI)/$($entity)"
      Headers     = $header
      Body        = $body
    }
    $script:psaCalls += 1
    try {
      Invoke-RestMethod @params -UseBasicParsing -erroraction stop
    } catch {
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
      logERR 3 "PSA-Put" "API_WatchDog : Failed to query PSA API via $($params.Uri)`r`n$($err)"
    }
  }

  function PSA-GetThreshold {
    param ($header)
    try {
      PSA-Query $header "GET" "ThresholdInformation" -erroraction stop
    } catch {
      $script:blnWARN = $true
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
      logERR 4 "PSA-GetThreshold" "Failed to populate PSA API Utilization via API`r`n$($err)"
    }
  }

  function PSA-GetMaps {
    param ($header, $dest, $entity)
    $Uri = "$($script:psaAPI)/$($entity)/query?search=$($script:psaActFilter)"
    try {
      $list = PSA-FilterQuery $header "GET" "$($entity)" "$($psaActFilter)"
      foreach ($item in $list.items) {
        if ($dest.containskey($item.id)) {
          continue
        } elseif (-not $dest.containskey($item.id)) {
          $dest.add($item.id, $item.name)
        }
      }
    } catch {
      $script:blnFAIL = $true
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
      logERR 4 "PSA-GetMaps" "Failed to populate PSA $($entity) Maps via $($Uri)`r`n$($err)"
    }
  } ## PSA-GetMaps

  function PSA-GetCompanies {
    param ($header)
    try {
      $script:psaCompanies = @()
      $script:atCompanies = PSA-FilterQuery $header "GET" "Companies" "$($psaActFilter)"
      $script:sort = ($script:atCompanies.items | Sort-Object -Property companyName)
      foreach ($script:company in $script:sort) {
        $country = $psaCountries.items | where {($_.id -eq $script:company.countryID)} | select displayName
        $script:psaCompanies += New-Object -TypeName PSObject -Property @{
          CompanyID       = "$($script:company.id)"
          CompanyName     = "$($script:company.companyName)"
          CompanyType     = "$($script:company.companyType)"
          CompanyClass    = "$($script:company.classification)"
          CompanyCategory = "$($script:company.companyCategoryID)"
          address1        = "$($script:company.address1)"
          address2        = "$($script:company.address2)"
          city            = "$($script:company.city)"
          state           = "$($script:company.state)"
          postalCode      = "$($script:company.postalCode)"
          country         = "$($country.displayName)"
          phone           = "$($script:company.phone)"
          fax             = "$($script:company.fax)"
          webAddress      = "$($script:company.webAddress)"
        }
        #write-output "$($script:company.companyName) : $($script:company.companyType)"
        #write-output "Type Map : $(script:typeMap[[int]$script:company.companyType])"
      }
    } catch {
      $script:blnFAIL = $true
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
      logERR 4 "PSA-GetCompanies" "Failed to populate PSA Companies via API`r`n$($err)"
    }
  } ## PSA-GetCompanies API Call

  function PSA-GetAssets {
    param ($header, $companyID)
    try {
      $script:psaDeviceDetails = @()
      $deviceFilter = '{"Filter":[{"op":"and","items":[{"field":"CompanyID","op":"eq","value":'
      $deviceFilter += "$($companyID)},"
      $deviceFilter += '{"field":"IsActive","op":"eq","value":true}]}]}'
      #$deviceFilter = "{`"Filter`":[{`"op`":`"and`",`"items`":[{`"field`":`"CompanyID`",`"op`":`"eq`",`"value`":$($companyID)},{`"field`":`"IsActive`",`"op`":`"eq`",`"value`":true}]}]}"
      $script:atDevices = PSA-FilterQuery $header "GET" "ConfigurationItems" $deviceFilter
      foreach ($script:atDevice in $script:atDevices.items) {
        $script:psaDeviceDetails += New-Object -TypeName PSObject -Property @{
          #ASSET DETAILS
          psaID                            = "$($script:atDevice.id)"
          createDate                       = "$($script:atDevice.createDate)"
          installDate                      = "$($script:atDevice.installDate)"
          configurationItemType            = "$($script:atDevice.configurationItemType)"
          configurationItemCategoryID      = "$($script:atDevice.configurationItemCategoryID)"
          #COMPANY DETAILS
          companyID                        = "$($script:atDevice.companyID)"
          companyLocationID                = "$($script:atDevice.companyLocationID)"
          #AT Device Details
          referenceTitle                   = "$($script:atDevice.referenceTitle)"
          referenceNumber                  = "$($script:atDevice.referenceNumber)"
          serialNumber                     = "$($script:atDevice.serialNumber)"
          psaUDFs                          = $script:atDevice.userDefinedFields
          #DATTO DETAILS
          rmmDeviceID                      = "$($script:atDevice.rmmDeviceID)"
          rmmDeviceUID                     = "$($script:atDevice.rmmDeviceUID)"
          dattoHostname                    = "$($script:atDevice.dattoHostname)"
          rmmDeviceAuditHostname           = "$($script:atDevice.rmmDeviceAuditHostname)"
          dattoSerialNumber                = "$($script:atDevice.dattoSerialNumber)"
          rmmDeviceAuditDeviceTypeID       = "$($script:atDevice.rmmDeviceAuditDeviceTypeID)"

          dattoOSVersionID                 = "$($script:atDevice.dattoOSVersionID)"
          rmmDeviceAuditOperatingSystem    = "$($script:atDevice.rmmDeviceAuditOperatingSystem)"
          deviceNetworkingID               = "$($script:atDevice.deviceNetworkingID)"
          rmmDeviceAuditSNMPName           = "$($script:atDevice.rmmDeviceAuditSNMPName)"
          
          rmmDeviceAuditMacAddress         = "$($script:atDevice.rmmDeviceAuditMacAddress)"
          dattoInternalIP                  = "$($script:atDevice.dattoInternalIP)"
          rmmDeviceAuditIPAddress          = "$($script:atDevice.rmmDeviceAuditIPAddress)"
          dattoRemoteIP                    = "$($script:atDevice.dattoRemoteIP)"
          rmmDeviceAuditExternalIPAddress  = "$($script:atDevice.rmmDeviceAuditExternalIPAddress)"
          #MISC
          productID                        = "$($script:atDevice.productID)"
          dattoLastCheckInDateTime         = "$($script:atDevice.dattoLastCheckInDateTime)"
        }
      }
      #return $script:psaDeviceDetails
    } catch {
      $script:blnFAIL = $true
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
      logERR 4 "PSA-GetAssets" "Failed to populate PSA Devices via API`r`n$($err)"
    }
  } ## PSA-GetDevices API Call

  function PSA-GetTickets {
    param ($header, $companyID, $deviceID, $title)
    try {
      $script:psaTicketdetails = @()
      $ticketFilter = '{"Filter":[{"op":"and","items":[{"field":"CompanyID","op":"eq","value":'
      $ticketFilter += "$($companyID)}"
      $ticketFilter += ',{"field":"status","op":"notin","value":[5,20]}'
      if (($null -ne $deviceID) -and ($deviceID -ne "")) {
        $ticketFilter += ',{"field":"configurationItemID","op":"eq","value":'
        $ticketFilter += "$($deviceID)}"
      }
      if (($null -ne $title) -and ($title -ne "")) {
        $ticketFilter += ',{"field":"title","op":"contains","value":"'
        $ticketFilter += "$($title)`"}"
      }
      $ticketFilter += ']}]}'
      #write-output "TICKET FILTER : $($ticketFilter)"
      $script:atTickets = PSA-FilterQuery $header "GET" "Tickets" $ticketFilter
      foreach ($script:atTicket in $script:atTickets.items) {
        $script:psaTicketdetails += New-Object -TypeName PSObject -Property @{
          #TICKET DETAILS
          id                   = "$($script:atTicket.id)"
          title                = "$($script:atTicket.title)"
          companyID            = "$($script:atTicket.companyID)"
          #configurationItemID  = "$($script:atTicket.configurationItemID)"

        }
      }
      return $script:psaTicketdetails
    } catch {
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
      logERR 4 "PSA-GetTickets" "Failed to populate PSA Tickets via API : $($ticketFilter)`r`n$($err)"
    }
  }

  function PSA-GetTicketFields {
    param ($header, $dest)
    $params = @{
      Method      = "GET"
      ContentType = 'application/json'
      Uri         = "$($script:psaAPI)/Tickets/entityInformation/fields"
      Headers     = $header
    }
    try {
      $script:psaCalls += 1
      $list = Invoke-RestMethod @params -UseBasicParsing -erroraction stop
      foreach ($item in $list.fields) {
        if ($dest.containskey($item.name)) {
          continue
        } elseif (-not $dest.containskey($item.name)) {
          $dest.add($item.name, $item.picklistValues)
        }
      }
    } catch {
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
      logERR 4 "PSA-GetTicketFields" "Failed to obtain create PSA Ticket via $($params.Uri)`r`n$($err)"
    }
  }

  function PSA-CreateTicket {
    param ($header, $ticket)
    $params = @{
      Method         = "POST"
      ContentType    = 'application/json'
      Uri            = "$($script:psaAPI)/Tickets"
      Headers        = $header
      Body           = convertto-json $ticket
    }
    try {
      $script:psaCalls += 1
      Invoke-RestMethod @params -UseBasicParsing -erroraction stop
    } catch {
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
      logERR 4 "PSA-CreateTicket" "Failed to create PSA Ticket via $($params.Uri)`r`n$($params.Body)`r`n$($err)"
    }
  }
#endregion ----- AT FUNCTIONS ----

#region ----- RMM FUNCTIONS ----
  function RMM-ApiAccessToken {
    # Convert password to secure string
    $securePassword = ConvertTo-SecureString -String 'public' -AsPlainText -Force
    # Define parameters
    $params = @{
      Method      = 'POST'
      ContentType = 'application/x-www-form-urlencoded'
      Uri         = '{0}/auth/oauth/token' -f $script:rmmAPI
      Body        = 'grant_type=password&username={0}&password={1}' -f $script:rmmKey, $script:rmmSecret
      Credential  = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList ('public-client', $securePassword)
    }
    $script:rmmCalls += 1
    # Request access token
    try {
      (Invoke-WebRequest @params -UseBasicParsing -erroraction stop | ConvertFrom-Json).access_token
    } catch {
      $script:blnWARN = $true
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
      logERR 4 "RMM-ApiAccessToken" "Failed to obtain DRMM API Access Token via $($params.Uri)`r`n$($err)"
    }
  }

  function RMM-ApiRequest {
    param (
      [string]$apiAccessToken,
      [string]$apiMethod,
      [string]$apiRequest,
      [string]$apiRequestBody
    )
    # Define parameters
    $params = @{
      Method        = $apiMethod
      ContentType   = 'application/json'
      Uri           = '{0}/api{1}' -f $script:rmmAPI, $apiRequest
      Headers       = @{
        'Authorization'	= 'Bearer {0}' -f $apiAccessToken
      }
    }
    $script:rmmCalls += 1
    # Add body to parameters if present
    if ($apiRequestBody) {$params.Add('Body', $apiRequestBody)}
    # Make request
    try {
      (Invoke-WebRequest @params -UseBasicParsing).Content
    } catch {
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
      logERR 4 "RMM-ApiRequest" "Failed to process DRMM API Query via $($params.Uri)`r`n$($err)"
    }
  }

  function RMM-PostUDF {
    param ([string]$deviceUID, [string]$companyType)
    $params = @{
      apiMethod       = "POST"
      apiUrl          = $script:rmmAPI
      ApiAccessToken  = $script:rmmToken
      apiRequest      = "/v2/device/$($deviceUID)/udf"
      apiRequestBody  = "{`"$($script:rmmUDF)`": `"$($companyType)`"}"
    }
    try {
      $postUDF = (RMM-ApiRequest @params -UseBasicParsing)
    } catch {
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
      logERR 4 "RMM-PostUDF" "Failed to populate DRMM Device UDF via $($params.apiUrl)$($params.apiRequest)`r`n$($params.apiRequestBody)`r`n$($err)"
    }
  }

  function RMM-GetFilters {
    $params = @{
      apiMethod       = "GET"
      apiUrl          = $script:rmmAPI
      apiAccessToken  = $script:rmmToken
      apiRequest      = "/v2/filter/custom-filters"
      apiRequestBody  = $null
    }
    try {
      $script:drmmFilters = (RMM-ApiRequest @params -UseBasicParsing) | ConvertFrom-Json
    } catch {
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
      logERR 4 "RMM-GetFilters" "Failed to populate DRMM Fitlers via $($params.apiUrl)$($params.apiRequest)`r`n$($err)"
    }
  }

  function RMM-GetDevices {
    param ([string]$siteUID)
    $params = @{
      apiMethod       = "GET"
      apiUrl          = $script:rmmAPI
      ApiAccessToken  = $script:rmmToken
      apiRequest      = "/v2/site/$($siteUID)/devices"
      apiRequestBody  = $null
    }
    try {
      $script:drmmDeviceDetails = @()
      $script:rmmDevices = (RMM-ApiRequest @params -UseBasicParsing) | ConvertFrom-Json
      foreach ($script:device in $script:rmmDevices.devices) {
        $script:drmmDeviceDetails += New-Object -TypeName PSObject -Property @{
          DeviceUID        = $script:device.uid
          Hostname         = $script:device.hostname
          Description      = $script:device.description
          deviceType       = $script:device.deviceType
          internalIP       = $script:device.intIpAddress
          externalIP       = $script:device.extIpAddress
          operatingSystem  = $script:device.operatingSystem
          #Assigned Services
          UDFs             = $script:device.udf
          avProduct        = $script:device.antivirus.antivirusproduct
          backupProduct    = $script:device.udf.udf13
        }
      }
      #return $script:drmmDeviceDetails
    } catch {
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
      logERR 4 "RMM-GetDevices" "Failed to populate DRMM Devices via $($params.apiUrl)$($params.apiRequest)`r`n$($err)"
    }
  }

  function RMM-GetSites {
    $params = @{
      apiMethod       = "GET"
      apiUrl          = $script:rmmAPI
      ApiAccessToken  = $script:rmmToken
      apiRequest      = "/v2/account/sites"
      apiRequestBody  = $null
    }
    try {
      $script:drmmSites = (RMM-ApiRequest @params -UseBasicParsing) | ConvertFrom-Json
      if (($null -eq $script:drmmSites) -or ($script:drmmSites -eq "")) {
        $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
        logERR 2 "RMM-GetSites" "Failed to populate DRMM Sites via $($params.apiUrl)$($params.apiRequest)`r`n$($err)"
      }
    } catch {
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
      logERR 2 "RMM-GetSites" "Failed to populate DRMM Sites via $($params.apiUrl)$($params.apiRequest)`r`n$($err)"
    }
  }

  function RMM-UpdateSite {
    param (
      [string]$rmmID,
      [string]$psaID,
      [string]$name,
      [string]$description,
      [string]$notes,
      [string]$onDemand,
      [string]$installSplashtop
    )
    $params = @{
      apiMethod       = "POST"
      apiUrl          = $script:rmmAPI
      ApiAccessToken  = $script:rmmToken
      apiRequest      = "/v2/site/$($rmmID)"
      apiRequestBody  = "{`"autotaskCompanyId`": `"$($psaID)`",`"autotaskCompanyName`": `"$($name)`",`"description`": `"$($description)`",`"name`": `"$($name)`",`"notes`": `"$($notes)`",`"onDemand`": $onDemand,`"splashtopAutoInstall`": $installSplashtop}"
    }
    $script:blnSITE = $false
    try {
      $script:updateSite = (RMM-ApiRequest @params -UseBasicParsing) #| ConvertFrom-Json
      if ($script:updateSite -match $name) {
        return $true
      } elseif ($script:updateSite -notmatch $name) {
        return $false
      }
    } catch {
      $script:blnSITE = $false
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
      logERR 4 "RMM-UpdateSite" "Failed to update DRMM Site via $($params.apiUrl)$($params.apiRequest)`r`n$($params.apiRequestBody)`r`n$($err)"
      return $false
    }
  }
#endregion ----- RMM FUNCTIONS ----
#endregion ----- API FUNCTIONS ----

#region ----- MISC FUNCTIONS ----
  function Get-EpochDate ($epochDate, $opt) {
    #Convert Epoch Date Timestamps to Local Time
    switch ($opt) {
      "sec" {[timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($epochDate))}
      "msec" {[timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddMilliSeconds($epochDate))}
    }
  } ## Get-EpochDate

  function Convert-UnixTimeToDateTime($inputUnixTime){
    if ($inputUnixTime -gt 0 ) {
      $epoch = Get-Date -Date "1970-01-01 00:00:00Z"
      $epoch = $epoch.ToUniversalTime()
      $epoch = $epoch.AddSeconds($inputUnixTime)
      return $epoch
    } else {
      return ""
    }
  }  ## Convert epoch time to date time

  function Pop-HashTable {
    param ($dest, $customer, $warn)
    #POPULATE DATA INTO NESTED HASHTABLE FORMAT FOR LATER USE
    try {
      #ONLY USE DATA IF NOT NULL / EMPTY
      if ((($null -ne $warn) -and ($warn -ne "")) -and 
        (($null -ne $customer) -and ($customer -ne ""))) {
          #CHECK IF 'customer' KEY ALREADY EXISTS
          if ($dest.containskey($customer)) {
            $new = [System.Collections.ArrayList]@()
            $prev = [System.Collections.ArrayList]@()
            $blnADD = $true
            #RETRIEVE PREVIOUS ENTRIES FOR MATCHING 'customer'
            $prev = $dest[$customer]
            $prev = $prev.split("`r`n", [System.StringSplitOptions]::RemoveEmptyEntries)
            #CHECK IF 'warn' DATA MATCHES PREVIOUS ENTRIES
            if ($prev -contains $warn) {$blnADD = $false}
            #ADD 'customer' AND 'warn' DATA AS NEW ENTRY
            if ($blnADD) {
              #RETAIN ALL PREVIOUS 'customer' DATA AND ADD NEW 'warn' DATA
              foreach ($itm in $prev) {$new.add("$($itm)`r`n")}
              $new.add("$($warn)`r`n")
              #REMOVE AND RE-ADD 'customer' DATA TO 'dest' HASHTABLE
              $dest.remove($customer)
              $dest.add($customer, $new)
              $script:blnWARN = $true
            }
          #IF 'customer' KEY DOES NOT ALREADY EXIST
          } elseif (-not $dest.containskey($customer)) {
            $new = [System.Collections.ArrayList]@()
            $new = "$($warn)`r`n"
            $dest.add($customer, $new)
            $script:blnWARN = $true
          }
      }
    } catch {
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
      logERR 4 "Pop-HashTable" "Error populating hashtable for $($customer)`r`n$($err)"
    }
  } ## Pop-HashTable

  function logERR ($intSTG, $strModule, $strErr) {
    $script:blnWARN = $true
    #CUSTOM ERROR CODES
    switch ($intSTG) {
      #'ERRRET'=1 - NOT ENOUGH ARGUMENTS, END SCRIPT
      1 {
        $script:blnBREAK = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date))`t - Spamhaus_Check - NO ARGUMENTS PASSED, END SCRIPT`r`n`r`n"
        write-output "$($strLineSeparator)`r`n$($(get-date))`t - Spamhaus_Check - NO ARGUMENTS PASSED, END SCRIPT`r`n"
      }
      #'ERRRET'=2 - INSTALL / IMPORT MODULE FAILURE, END SCRIPT
      2 {                                                         
        $script:blnBREAK = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date))`t - Spamhaus_Check - ($($strModule)) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n"
        write-output "$($strLineSeparator)`r`n$($(get-date))`t - Spamhaus_Check - ($($strModule)) :"
        write-output "$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n"
      }
      #'ERRRET'=3 - WARNING / ERROR
      3 {                                                         
        $script:blnWARN = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date))`t - Spamhaus_Check - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
        write-output "$($strLineSeparator)`r`n$($(get-date))`t - Spamhaus_Check - $($strModule) :"
        write-output "$($strLineSeparator)`r`n`t$($strErr)"
      }
      #'ERRRET'=4+ - DEBUG / INFORMATIONAL
      default {
        $script:blnWARN = $false
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date))`t - Spamhaus_Check - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
        write-output "$($strLineSeparator)`r`n$($(get-date))`t - Spamhaus_Check - $($strModule) :"
        write-output "$($strLineSeparator)`r`n`t$($strErr)"
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
    #TOTAL
    $total = ((((($Hours * 60) + $Minutes) * 60) + $Seconds) * 1000) + $Milliseconds
    $secs = [string]($total / 1000)
    $mill = $secs.split(".")[1]
    $secs = $secs.split(".")[0]
    $mill = $mill.SubString(0,[math]::min(3, $mill.length))
    if ($Minutes -gt 0) {$secs = ($secs - ($Minutes * 60))}
    #AVERAGE
    $average = ($total / ($script:psaCalls + $script:rmmCalls + $script:syncroCalls))
    $asecs = [string]($average / 1000)
    $amill = $asecs.split(".")[1]
    $asecs = $asecs.split(".")[0]
    $amill = $amill.SubString(0, [math]::min(3, $mill.length))
    if ($Minutes -gt 0) {
      $amin = [string]($asecs / 60)
      $amin = $amin.split(".")[0]
      $amin = $amin.SubString(0, [math]::min(2, $amin.length))
      $asecs = ($asecs - ($amin * 60))
    }
    #DISPLAY API THRESHOLDS
    $psa = PSA-GetThreshold $script:psaHeaders
    write-output "`r`nAPI Calls :`r`nPSA API : $($script:psaCalls) - RMM API : $($script:rmmCalls) - SYNCRO API : $($script:syncroCalls)"
    write-output "API Limits - PSA API (per Hour) : $($psa.currentTimeframeRequestCount) / $($psa.externalRequestThreshold) - RMM API (per Minute) : $($script:rmmCalls) / 600 - SYNCRO API (per Minute) : $($script:syncroCalls) / 180"
    write-output "Total Execution Time - $($Minutes) Minutes : $($secs) Seconds : $($mill) Milliseconds`r`n"
    write-output "Average Execution Time (Per API Call) - $($amin) Minutes : $($asecs) Seconds : $($amill) Milliseconds`r`n"
    $script:diag += "`r`nAPI Calls :`r`nPSA API : $($script:psaCalls) - RMM API : $($script:rmmCalls)`r`n"
    $script:diag += "API Limits - PSA API (per Hour) : $($psa.currentTimeframeRequestCount) / $($psa.externalRequestThreshold) - RMM API (per Minute) : $($script:rmmCalls) / 600 - SYNCRO API (per Minute) : $($script:syncroCalls) / 180`r`n"
    $script:diag += "Total Execution Time - $($Minutes) Minutes : $($secs) Seconds : $($mill) Milliseconds`r`n"
    $script:diag += "Average Execution Time (Per API Call) - $($amin) Minutes : $($asecs) Seconds : $($amill) Milliseconds`r`n`r`n"
  }
#endregion ----- MISC FUNCTIONS ----
#endregion ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
clear-host
#Start script execution time calculation
$ScrptStartTime = (Get-Date).ToString('dd-MM-yyyy hh:mm:ss')
$script:sw = [Diagnostics.Stopwatch]::StartNew()
#CHECK 'PERSISTENT' FOLDERS
if (-not (test-path -path "C:\temp")) {new-item -path "C:\temp" -itemtype directory}
if (-not (test-path -path "C:\IT")) {new-item -path "C:\IT" -itemtype directory}
if (-not (test-path -path "C:\IT\Log")) {new-item -path "C:\IT\Log" -itemtype directory}
if (-not (test-path -path "C:\IT\Scripts")) {new-item -path "C:\IT\Scripts" -itemtype directory}
Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
#Get the Autotask API Module if not installed
if (Get-Module -ListAvailable -Name AutotaskAPI) {
  try {
    Import-Module AutotaskAPI
  } catch {
    logERR 2 "AutotaskAPI" "INSTALL / IMPORT MODULE FAILURE"
  }
} else {
  try {
    Install-Module AutotaskAPI -Force -Confirm:$false
    Import-Module AutotaskAPI
  } catch {
    logERR 2 "AutotaskAPI" "INSTALL / IMPORT MODULE FAILURE"
  }
}
Set-PSRepository -Name 'PSGallery' -InstallationPolicy Untrusted

try {
  #QUERY AT PSA API
  logERR 3 "AT API" "$($script:strLineSeparator)`r`nQUERYING AT API :`r`n`t$($script:strLineSeparator)"
  $script:psaCountries = PSA-FilterQuery $script:psaHeaders "GET" "Countries" $psaGenFilter
  logERR 3 "AT API" "$($strLineSeparator)`r`n`tCLASS MAP :"
  PSA-GetMaps $script:psaHeaders $script:classMap "ClassificationIcons"
  $script:classMap
  Write-Output "`t$($strLineSeparator)`r`n`tDone`r`n`t$($strLineSeparator)"
  $script:diag += "`r`n`t$($strLineSeparator)`r`n`tDone`r`n`t$($strLineSeparator)`r`n"
  logERR 3 "AT API" "$($strLineSeparator)`r`n`tCATEGORY MAP :"
  PSA-GetMaps $script:psaHeaders $script:categoryMap "CompanyCategories"
  $script:categoryMap
  write-output "`t$($strLineSeparator)`r`n`tDone`r`n`t$($strLineSeparator)"
  $script:diag += "`r`n`t$($strLineSeparator)`r`n`tDone`r`n`t$($strLineSeparator)`r`n"
  logERR 3 "AT API" "$($strLineSeparator)`r`n`tASSET TYPE MAP :"
  PSA-GetMaps $script:psaHeaders $script:ciTypeMap "ConfigurationItemTypes"
  $script:ciTypeMap
  write-output "`t$($strLineSeparator)`r`n`tDone`r`n`t$($strLineSeparator)"
  $script:diag += "`r`n`t$($strLineSeparator)`r`n`tDone`r`n`t$($strLineSeparator)`r`n"
  logERR 3 "AT API" "$($strLineSeparator)`r`n`tTICKET FIELDS :"
  PSA-GetTicketFields $script:psaHeaders $script:ticketFields
  #$script:ticketFields
  write-output "`t$($strLineSeparator)`r`n`tDone`r`n`t$($strLineSeparator)"
  $script:diag += "`r`n`t$($strLineSeparator)`r`n`tDone`r`n`t$($strLineSeparator)`r`n"
  logERR 3 "AT API" "RETRIEVING COMPANIES :`r`n`t$($strLineSeparator)"
  PSA-GetCompanies $script:psaHeaders
  write-output "`tDone`r`n`t$($strLineSeparator)"
  $script:diag += "`r`n`tDone`r`n`t$($strLineSeparator)"
  logERR 3 "AT API" "QUERY AT DONE`r`n$($strLineSeparator)`r`n"

  #QUERY DRMM API
  $script:rmmToken = RMM-ApiAccessToken
  RMM-GetFilters
  $filter = $script:drmmFilters.filters | where {$_.name -eq "Site Group: Spamhaus Checks"}
  logERR 3 "DRMM API" "QUERYING DRMM API :`r`n`t$($strLineSeparator)"
  logERR 3 "DRMM API" "RETRIEVING DRMM SITES :`r`n`t$($strLineSeparator)"
  RMM-GetSites
  write-output "`tDone`r`n`t$($strLineSeparator)"
  $script:diag += "`r`n`tDone`r`n`t$($strLineSeparator)"
  logERR 3 "DRMM API" "QUERY DRMM DONE`r`n$($strLineSeparator)`r`n"

  #ENUMERATE THROUGH DRMM SITES
  foreach ($script:drmmSite in $script:drmmSites.sites) {
    RMM-GetDevices $script:drmmSite.uid $filter.id
    #ENUMERATE THROUGH DRMM SITE DEVICES
    foreach ($script:drmmDevice in $script:drmmDeviceDetails) {
      #CHECK EXTERNAL IP OF EACH DRMM DEVICE
      if (($script:drmmDevice.externalIP) -and 
        ($null -ne $script:drmmDevice.externalIP) -and ($script:drmmDevice.externalIP -ne "")) {
          #ADD EXTERNAL IP TO 'spamCHECK' HASHTABLE
          Pop-HashTable $script:spamCHECK "$($script:drmmSite.name)" "$($script:drmmDevice.externalIP)"
      }
    }
  }

} catch {
  $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($script:strLineSeparator)"
  logERR 2 "BEGIN API" "Spamhaus_Check : Failed to query API via $($params.Uri)`r`n$($err)"
}

#CHECK THAT A 'BREAKING' ERROR HAS NOT OCCURRED
if (-not $script:blnBREAK) {
  write-output "`r`n$($strLineSeparator)`r`nThe Following Check(s) Will Be Performed :"
  foreach ($key in $script:spamCHECK.keys) {
    write-output "`t$($strLineSeparator)`r`n`t$($strLineSeparator)`r`n`t$(($key).trim())`r`n`t`t$($strLineSeparator)"
    foreach ($check in $script:spamCHECK[$key]) {
      write-output "`t`t$($check.trim())`r`n`t`t$($strLineSeparator)"
    }
  }
  write-output "$($strLineSeparator)`r`n"

  write-output "`r`n$($strLineSeparator)`r`nPerforming Spamhaus Check(s) :"
  $script:diag += "`r`n`r`n$($strLineSeparator)`r`nPerforming Spamhaus Check(s) :"
  foreach ($key in $script:spamCHECK.keys) {
    start-sleep -Milliseconds 200
    logERR 3 "SPAMHAUS DIAG" "$($strLineSeparator)`r`n`t$($strLineSeparator)`r`n`t$(($key).trim())`r`n`t`t$($strLineSeparator)"
    foreach ($extIP in $script:spamCHECK[$key]) {
      $script:outCheck = $null
      try {
        start-sleep -Milliseconds 200
        #REVERSE THE IP ADDRESS TO CHECK
        $ipParts = ($extIP.trim()).Split('.')
        [array]::Reverse($ipParts)
        $ipParts = [string]::Join('.', $ipParts)
        #RUN THE REVERSE IP LOOKUP
        foreach ($blocklist in $script:spamMAP.keys) {
          start-sleep -Milliseconds 200
          $script:outCheck = $null
          logERR 3 "`tChecking : $($extIP.trim()) as '$($ipParts).$($script:spamMAP[$blocklist].siteAddress).' :`r`n`t`t$($strLineSeparator)"
          $script:diag += "`r`n`tChecking : $($extIP.trim()) as '$($ipParts).$($script:spamMAP[$blocklist].siteAddress).' :`r`n`t`t$($strLineSeparator)"
          try {
            $script:outCheck = [system.net.dns]::gethostentry("$($ipParts).$($script:spamMAP[$blocklist].siteAddress).")
          } catch {
            write-output "`tNo Listing for $($extIP.trim()) as '$($ipParts).$($script:spamMAP[$blocklist].siteAddress).'`r`n`t`t$($strLineSeparator)"
            #NOT CATCHING ANY ERRORS ATM
          }
          #IF RETURNED DATA MATCHES KNOWN RETURN CODES in 'spamMAP' HASHTABLE
          $returnCode = $script:outCheck.addresslist.ipaddresstostring
          if ($script:spamMAP[$blocklist].returnCodes."$($returnCode)") {
            $script:spamdiag = "`tBLOCKED : $($extIP.trim()) :`r`n"
            $script:spamdiag += "`t`tZone : $($script:spamMAP[$blocklist].returnCodes[$returnCode].zone)`r`n"
            $script:spamdiag += "`t`tDescription : $($script:spamMAP[$blocklist].returnCodes[$returnCode].description)"
            logERR 3 "SPAMHAUS DIAG" "$($script:spamdiag)`r`n`t$($strLineSeparator)`r`n$($strLineSeparator)"
            #SEARCH FOR EXISTING TICKETS
            $script:psaCompanyID = ($script:drmmSites.sites | where {$_.name -match $key}).autotaskCompanyId
            $script:psaTickets = PSA-GetTickets $script:psaHeaders $script:psaCompanyID $null "Spamhaus Alert: BLOCKED : $($extIP.trim())"
            $script:ticketDescription = "Zone : $($script:spamMAP[$blocklist].returnCodes[$returnCode].zone)`r`n"
            $script:ticketDescription += "Description : $($script:spamMAP[$blocklist].returnCodes[$returnCode].description)`r`n"
            $script:ticketDescription += "$(($script:outCheck | ft | out-string))"
            logERR 3 "SPAMHAUS DIAG" "$($script:outCheck | ft | out-string)`r`n`t$($strLineSeparator)"
            if ($script:psaTickets) {
              write-output "`tExisting Tickets Found. Not Creating Ticket`r`n`t$($strLineSeparator)"
              $script:diag += "`tExisting Tickets Found. Not Creating Ticket`r`n`t$($strLineSeparator)`r`n"
            } elseif (-not ($script:psaTickets)) {
              write-output "`tNo Tickets Found. Creating Ticket`r`n`t$($strLineSeparator)"
              $script:diag += "`tNo Tickets Found. Creating Ticket`r`n`t$($strLineSeparator)`r`n"
              $newTicket = @{
                id                   = '0'
                companyID            = $script:psaCompanyID
                #configurationItemID  = "$($script:siteAsset.psaID)"
                queueID              = '8'         #Monitoring Alert
                ticketType           = '1'         #Standard
                ticketCategory       = "2"         #Datto RMM Alert
                status               = '1'         #New
                priority             = '2'         #Medium
                DueDateTime          = (get-date).adddays(7)
                monitorTypeID        = '1'         #Online Status Monitor
                source               = '8'         #Monitoring Alert
                issueType            = '18'        #RMM Monitoring
                subIssueType         = '320'       #Spamhaus Monitor
                billingCodeID        = '29682804'  #Maintenance
                title                = "Spamhaus Alert: BLOCKED : $($extIP.trim())"
                description          = "$($script:ticketDescription)"
              }
              $newTicket
              PSA-CreateTicket $script:psaHeaders $newTicket
            }
          }
        }
      } catch {
        write-output "No Listing for $($extIP.trim()) as '$($ipParts).$($script:spamMAP[$blocklist].siteAddress).'"
        #NOT CATCHING ANY ERRORS ATM
      }
    }
  }
  write-output "$($strLineSeparator)`r`n"
}

#Stop script execution time calculation
StopClock
$finish = "$((get-date).ToString('yyyy-MM-dd hh:mm:ss'))"
logERR 3 "END" "$($finish) - Completed Execution"
#WRITE LOGFILE
$null | set-content $script:logPath -force
"$($script:diag)" | add-content $script:logPath -force
if (-not $script:blnBREAK) {
  if (-not $script:blnWARN) {
    write-DRMMAlert "Spamhaus_Check : Healthy. No Issues Found : $($finish)"
    write-DRMMDiag "$($script:diag)"
    exit 0
  } elseif ($script:blnWARN) {
    write-DRMMAlert "Spamhaus_Check : Issues Found. Please Check Diagnostics : $($finish)"
    write-DRMMDiag "$($script:diag)"
    exit 1
  }
} elseif ($script:blnBREAK) {
  write-DRMMAlert "Spamhaus_Check : Execution Failed : $($finish)"
  write-DRMMDiag "$($script:diag)"
  exit 1
}
#END SCRIPT
#------------