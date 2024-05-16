#First Clear any variables
Remove-Variable * -ErrorAction SilentlyContinue

#region ----- DECLARATIONS ----
  $script:diag              = $null
  $script:blnFAIL           = $false
  $script:blnWARN           = $false
  $script:blnSITE           = $false
  $script:strLineSeparator  = "---------"
  $script:logPath           = "C:\IT\Log\Invoice_Insanity"
  #region######################## TLS Settings ###########################
  #[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType] 'Tls12'
  [System.Net.ServicePointManager]::SecurityProtocol = (
    [System.Net.SecurityProtocolType]::Tls13 -bor 
    [System.Net.SecurityProtocolType]::Tls12 -bor 
    [System.Net.SecurityProtocolType]::Tls11 -bor 
    [System.Net.SecurityProtocolType]::Tls
  )
  #endregion
  #region######################## Syncro Settings ###########################
  $script:syncroCalls       = 0
  $script:syncroWARN        = @{}
  $script:syncroAPI         = $env:syncroAPI
  $script:syncroKey         = $env:syncroKEY
  $script:syncroLnItems     = @(
    "IPM RMS",
    "Managed Router",
    "Sophos",
    "Unifi Monitoring"
  )
  $script:invalLnItems      = @(
    "101",
    "2018",
    "2019",
    "2020"
  )
  #endregion
  #region######################## Hudu Settings ###########################
  $script:huduCalls         = 0
  # Get a Hudu API Key from https://yourhududomain.com/admin/api_keys
  $script:HuduAPIKey        = $env:HuduKey
  # Set the base domain of your Hudu instance without a trailing /
  $script:HuduBaseDomain    = $env:HuduDomain
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
  $script:typeMap           = @{
    1 = "Customer"
    2 = "Lead"
    3 = "Prospect"
    4 = "Dead"
    6 = "Cancelation"
    7 = "Vendor"
    8 = "Partner"
  }
  #PSA API VARS
  $script:psaCalls          = 0
  #PSA API FILTERS
  #Generic Filter - ID -ge 0
  $psaGenFilter             = '{"Filter":[{"field":"Id","op":"gte","value":0}]}'
  #IsActive Filter
  $psaActFilter             = '{"Filter":[{"op":"and","items":[
                              {"field":"IsActive","op":"eq","value":true},
                              {"field":"Id","op":"gte","value":0}]}]}'
  #Ticket Filters
  $ExcludeType              = '[]'
  $ExcludeQueue             = '[]'
  $ExcludeStatus            = '[5,20]'    #EXCLUDE STATUSES : 5 - COMPLETED , 20 - RMM RESOLVED
  $TicketFilter             = "{`"Filter`":[{`"op`":`"notin`",`"field`":`"queueID`",`"value`":$($ExcludeQueue)},
                              {`"op`":`"notin`",`"field`":`"status`",`"value`":$($ExcludeStatus)},
                              {`"op`":`"notin`",`"field`":`"ticketType`",`"value`":$($ExcludeType)}]}"
  #PSA API URLS
  $AutotaskRoot             = $env:ATRoot
  $AutoTaskAPIBase          = $env:ATAPIBase
  $script:psaAPI            = "$($env:ATAPIBase)/atservicesrest/v1.0"
  $AutotaskAcct             = "/Autotask/AutotaskExtend/ExecuteCommand.aspx?Code=OpenAccount&AccountID="
  $AutotaskExe              = "/Autotask/AutotaskExtend/ExecuteCommand.aspx?Code=OpenTicketDetail&TicketNumber="
  $AutotaskDev              = "/Autotask/AutotaskExtend/AutotaskCommand.aspx?&Code=OpenInstalledProduct&InstalledProductID="
  ########################### Autotask Auth ##############################
  $script:psaKey            = $env:ATAPIUser
  $script:psaSecret         = $env:ATAPISecret
  $script:psaIntegration    = $env:ATIntegratorID
  $script:psaHeaders        = @{
    'ApiIntegrationCode'    = "$($script:AutotaskIntegratorID)"
    'UserName'              = "$($script:AutotaskAPIUser)"
    'Secret'                = "$($script:AutotaskAPISecret)"
  }
  #endregion
  #region######################## Backups Settings ##########################
  $script:bmCalls           = 0
  #region###############    Backups Counters - Tallied for All Companies
  $totBackups               = 0
  $procBackups              = 0
  $skipBackups              = 0
  $failBackups              = 0
  #endregion
  $script:blnBM             = $false
  $script:bmRoot            = $env:BackupRoot
  $script:bmUser            = $env:BackupUser
  $script:bmPass            = $env:BackupPass
  $Filter1                  = "AT == 1 AND PN != 'Documents'"   ### Excludes M365 and Documents devices from lookup
  $urlJSON                  = "https://api.backup.management/jsonapi"
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
#region ----- SYNCRO FUNCTIONS ----
  function Syncro-Query {
    param ($method, $entity, $query)
    if (-not ($query)) {
      $params = @{
        Method      = "$($method)"
        ContentType = 'application/json'
        Uri         = "$($script:syncroAPI)/$($entity)"
        Headers     = @{
          "accept" = "application/json"
          "Authorization" = $script:syncroKey
        }
      }
    } elseif ($query) {
      $params = @{
        Method      = "$($method)"
        ContentType = 'application/json'
        Uri         = "$($script:syncroAPI)/$($entity)?$($query)"
        Headers     = @{
          "accept" = "application/json"
          "Authorization" = $script:syncroKey
        }
      }
    }
    $script:syncroCalls += 1
    try {
      $page = 1
      $request = Invoke-RestMethod @params -UseBasicParsing -erroraction stop
      if ($request.meta.total_pages) {
        [int]$totalPages = [int]$request.meta.total_pages
        if ($totalPages -gt 1) {
          while ($page -le $totalPages) {
            if (-not ($query)) {
              $params.Uri = "$($script:syncroAPI)/$($entity)?page=$($page)"
            } elseif ($query) {
              $params.Uri = "$($script:syncroAPI)/$($entity)?$($query)&page=$($page)"
            }
            $script:syncroCalls += 1
            write-output $params
            Invoke-RestMethod @params -UseBasicParsing -erroraction stop
            start-sleep -milliseconds 500
            $page += 1
          }
        } elseif ($totalPages -eq 1) {
          return $request
        }
      } elseif (-not ($request.meta.total_pages)) {
        return $request
      }
    } catch {
      if ($_.exception -match "Too Many Requests") {
        write-output "Too Many Request; Waiting 1 Minute..."
        start-sleep -seconds 60
        Syncro-Query $method $entity $query
      } else {
        $script:blnWARN = $true
        $script:diag += "`r`nInvoice_Insanity : Failed to query Syncro API via $($params.Uri) : $($method) : $($entity) : $($query) : $($page)"
        $script:diag += "`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
        write-output "$($script:diag)`r`n"
      }
    }
  }
#endregion ----- SYNCRO FUNCTIONS ----
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
      $script:diag += "`r`nAPI_WatchDog : Failed to query PSA API via $($params.Uri)"
      $script:diag += "`r`n$($_.Exception)"
      $script:diag += "`r`n$($_.scriptstacktrace)"
      $script:diag += "`r`n$($_)"
      write-output "$($script:diag)`r`n"
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
      $script:diag += "`r`nAPI_WatchDog : Failed to query (filtered) PSA API via $($params.Uri)"
      $script:diag += "`r`n$($_.Exception)"
      $script:diag += "`r`n$($_.scriptstacktrace)"
      $script:diag += "`r`n$($_)"
      write-output "$($script:diag)`r`n"
    }
  }

  function PSA-GetThreshold {
    param ($header)
    try {
      PSA-Query $header "GET" "ThresholdInformation" -erroraction stop
    } catch {
      $script:blnWARN = $true
      $script:diag += "`r`nAPI_WatchDog : Failed to populate PSA API Utilization via $($params.Uri)"
      $script:diag += "`r`n$($_.Exception)"
      $script:diag += "`r`n$($_.scriptstacktrace)"
      $script:diag += "`r`n$($_)"
      write-output "$($script:diag)`r`n"
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
      $script:diag += "`r`nAPI_WatchDog : Failed to populate PSA $($entity) Maps via $($Uri)"
      $script:diag += "`r`n$($_.Exception)"
      $script:diag += "`r`n$($_.scriptstacktrace)"
      $script:diag += "`r`n$($_)"
      write-output "$($script:diag)`r`n"
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
      $script:diag += "`r`nAPI_WatchDog : Failed to populate PSA Companies via $($Uri)"
      $script:diag += "`r`n$($_.Exception)"
      $script:diag += "`r`n$($_.scriptstacktrace)"
      $script:diag += "`r`n$($_)"
      write-output "$($script:diag)`r`n"
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
      return $script:psaDeviceDetails
    } catch {
      $script:blnFAIL = $true
      $script:diag += "`r`nAPI_WatchDog : Failed to populate PSA Devices via $($Uri)"
      $script:diag += "`r`n$($_.Exception)"
      $script:diag += "`r`n$($_.scriptstacktrace)"
      $script:diag += "`r`n$($_)"
      write-output "$($script:diag)`r`n"
    }
  } ## PSA-GetDevices API Call
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
      $script:blnFAIL = $true
      $script:diag += "`r`nAPI_WatchDog : Failed to obtain DRMM API Access Token via $($params.Uri)"
      $script:diag += "`r`n$($_.Exception)"
      $script:diag += "`r`n$($_.scriptstacktrace)"
      $script:diag += "`r`n$($_)"
      write-output "$($script:diag)`r`n"
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
    if ($apiRequestBody) {$params.Add('Body',$apiRequestBody)}
    # Make request
    try {
      (Invoke-WebRequest @params -UseBasicParsing).Content
    } catch {
      $script:blnWARN = $true
      $script:diag += "`r`nAPI_WatchDog : Failed to process DRMM API Query via $($params.Uri)"
      $script:diag += "`r`n$($_.Exception)"
      $script:diag += "`r`n$($_.scriptstacktrace)"
      $script:diag += "`r`n$($_)"
      write-output "$($script:diag)`r`n"
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
      $script:blnWARN = $true
      $script:diag += "`r`nAPI_WatchDog : Failed to populate DRMM Device UDF via $($params.apiUrl)$($params.apiRequest)`r`n$($params.apiRequestBody)"
      $script:diag += "`r`n$($_.Exception)"
      $script:diag += "`r`n$($_.scriptstacktrace)"
      $script:diag += "`r`n$($_)"
      write-output "$($script:diag)`r`n"
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
      return $script:drmmDeviceDetails
    } catch {
      $script:blnWARN = $true
      $script:diag += "`r`nAPI_WatchDog : Failed to populate DRMM Devices via $($params.apiUrl)$($params.apiRequest)"
      $script:diag += "`r`n$($_.Exception)"
      $script:diag += "`r`n$($_.scriptstacktrace)"
      $script:diag += "`r`n$($_)"
      write-output "$($script:diag)`r`n"
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
        $script:blnFAIL = $true
        $script:diag += "`r`nAPI_WatchDog : Failed to populate DRMM Sites via $($params.apiUrl)$($params.apiRequest)"
        $script:diag += "`r`n$($_.Exception)"
        $script:diag += "`r`n$($_.scriptstacktrace)"
        $script:diag += "`r`n$($_)"
        write-output "$($script:diag)`r`n"
      }
    } catch {
      $script:blnFAIL = $true
      $script:diag += "`r`nAPI_WatchDog : Failed to populate DRMM Sites via $($params.apiUrl)$($params.apiRequest)"
      $script:diag += "`r`n$($_.Exception)"
      $script:diag += "`r`n$($_.scriptstacktrace)"
      $script:diag += "`r`n$($_)"
      write-output "$($script:diag)`r`n"
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
      $script:blnWARN = $true
      $script:blnSITE = $false
      $script:diag += "`r`nAPI_WatchDog : Failed to update DRMM Site via $($params.apiUrl)$($params.apiRequest)`r`n$($params.apiRequestBody)"
      $script:diag += "`r`n$($_.Exception)"
      $script:diag += "`r`n$($_.scriptstacktrace)"
      $script:diag += "`r`n$($_)"
      write-output "$($script:diag)`r`n"
      return $false
    }
  }
#endregion ----- RMM FUNCTIONS ----
#region ----- Backup.Management Authentication ----
  function Send-APICredentialsCookie {
    $url = $urlJSON
    $data = @{}
    $data.jsonrpc = '2.0'
    $data.id = '2'
    $data.method = 'Login'
    $data.params = @{}
    $script:bmPass = Convertto-SecureString -string $script:bmPass -asplaintext -force
    $script:bmPass = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($script:bmPass))
    $data.params.partner = $script:bmRoot
    $data.params.username = $script:bmUser
    $data.params.password = $script:bmPass
    $script:bmCalls += 1
    $webrequest = Invoke-WebRequest -Method POST `
      -ContentType 'application/json' `
      -Body (ConvertTo-Json $data) `
      -Uri $url `
      -SessionVariable Script:websession `
      -UseBasicParsing
    $Script:cookies = $websession.Cookies.GetCookies($url)
    $Script:websession = $websession
    $Script:Authenticate = $webrequest | convertfrom-json
    <#-- DEBUG
    write-output "$($strLineSeparator)`r`n$($strLineSeparator)"
    write-output "$($Script:cookies[0].name) = $($cookies[0].value)"
    write-output $strLineSeparator
    write-output $Script:Authenticate
    write-output "$($strLineSeparator)`r`n$($strLineSeparator)"
    --#>
    if ($authenticate.visa) {
      $script:blnBM = $true
      $bmdiag = "BM AUTH SUCCESS : $($script:blnBM)`r`n$($strLineSeparator)"
      logERR 4 "Send-APICredentialsCookie" "$($bmdiag)"
      $Script:visa = $Script:Authenticate.visa
    } else {
      $script:blnBM = $false
      $bmdiag = "BM AUTH SUCCESS : $($script:blnBM)`r`n$($strLineSeparator)"
      $bmdiag += "`r`n`tAuthentication Failed: Please confirm your Backup.Management Partner Name and Credentials"
      $bmdiag += "`r`n`tPlease Note: Multiple failed authentication attempts could temporarily lockout your user account`r`n$($strLineSeparator)"
      $bmdiag += "`r`n$($Script:Authenticate.error.message)`r`n$($strLineSeparator)"
      logERR 4 "Send-APICredentialsCookie" "$($bmdiag)"
    }
  }  ## Use Backup.Management credentials to Authenticate
#endregion ----- Backup.Management Authentication ----
#region ----- Backup.Management JSON Calls ----
  function CallBackupsJSON ($url,$object) {
    $script:bmCalls += 1
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($object)
    $web = [System.Net.WebRequest]::Create($url)
    $web.Method = "POST"
    $web.ContentLength = $bytes.Length
    $web.ContentType = "application/json"
    $stream = $web.GetRequestStream()
    $stream.Write($bytes,0,$bytes.Length)
    $stream.close()
    $reader = New-Object System.IO.Streamreader -ArgumentList $web.GetResponse().GetResponseStream()
    return $reader.ReadToEnd()| ConvertFrom-Json
    $reader.Close()
  }

  function Send-GetPartnerInfo ($PartnerName) {                
    $url = $urlJSON
    $data = @{}
    $data.jsonrpc = '2.0'
    $data.id = '2'
    $data.visa = $Script:visa
    $data.method = 'GetPartnerInfo'
    $data.params = @{}
    $data.params.name = [String]$PartnerName
    $script:bmCalls += 1
    $webrequest = Invoke-WebRequest -Method POST `
      -ContentType 'application/json' `
      -Body (ConvertTo-Json $data -depth 5) `
      -Uri $url `
      -SessionVariable Script:websession `
      -UseBasicParsing
    $Script:cookies = $websession.Cookies.GetCookies($url)
    $Script:websession = $websession
    $Script:Partner = $webrequest | convertfrom-json

    $RestrictedPartnerLevel = @("Root","Sub-root","Distributor")
    <#---# POWERSHELL 2.0 #---#>
    if ($RestrictedPartnerLevel -notcontains $Partner.result.result.Level) {
    #---#>
    <#---# POWERSHELL 3.0+ #--->
    if ($Partner.result.result.Level -notin $RestrictedPartnerLevel) {
    #---#>
      $script:blnBM = $true
      [String]$Script:Uid = $Partner.result.result.Uid
      [int]$Script:PartnerId = [int]$Partner.result.result.Id
      [String]$script:Level = $Partner.result.result.Level
      [String]$Script:PartnerName = $Partner.result.result.Name
      $bmdiag = "$($PartnerName) - $($partnerId) - $($Uid)`r`n$($strLineSeparator)"
      logERR 4 "Send-GetPartnerInfo" "$($bmdiag)"
    } else {
      $script:blnBM = $false
      $bmdiag = "$($strLineSeparator)`r`n`tLookup for $($Partner.result.result.Level) Partner Level Not Allowed`r`n$($strLineSeparator)"
      logERR 4 "Send-GetPartnerInfo" "$($bmdiag)"
    }

    if ($partner.error) {
      $script:blnBM = $false
      $bmdiag = "$($strLineSeparator)`r`n`t$($partner.error.message)`r`n$($strLineSeparator)"
      logERR 4 "Send-GetPartnerInfo" "$($bmdiag)"
    }
  } ## Send-GetPartnerInfo API Call

  function Send-GetBackups {
    $url = $urlJSON
    $method = 'POST'
    $data = @{}
    $data.jsonrpc = '2.0'
    $data.id = '2'
    $data.visa = $Script:visa
    $data.method = 'EnumerateAccountStatistics'
    $data.params = @{}
    $data.params.query = @{}
    $data.params.query.PartnerId = [int]$PartnerId
    $data.params.query.Filter = $Filter1
    $data.params.query.Columns = @("AU","AR","AN","MN","AL","LN","OP","OI","OS","PD","AP","PF","PN","CD","TS","TL","T3","US","AA843","AA77","AA2531","I78")
    $data.params.query.OrderBy = "CD DESC"
    $data.params.query.StartRecordNumber = 0
    $data.params.query.RecordsCount = 2000
    $data.params.query.Totals = @("COUNT(AT==1)","SUM(T3)","SUM(US)")
    $jsondata = (ConvertTo-Json $data -depth 6)

    $params = @{
      Uri         = $url
      Method      = $method
      Headers     = @{ 'Authorization' = "Bearer $Script:visa" }
      Body        = ([System.Text.Encoding]::UTF8.GetBytes($jsondata))
      ContentType = 'application/json; charset=utf-8'
    }

    try {
      $script:bmCalls += 1
      $script:BackupsDetails = @()
      $script:BackupsResponse = Invoke-RestMethod @params
      ForEach ( $BackupsResult in $script:BackupsResponse.result.result ) {
        $script:BackupsDetails += New-Object -TypeName PSObject -Property @{
          AccountID         = [Int]$BackupsResult.AccountId;
          PartnerID         = [string]$BackupsResult.PartnerId;
          DeviceName        = $BackupsResult.Settings.AN -join '' ;
          ComputerName      = $BackupsResult.Settings.MN -join '' ;
          DeviceAlias       = $BackupsResult.Settings.AL -join '' ;
          PartnerName       = $BackupsResult.Settings.AR -join '' ;
          Reference         = $BackupsResult.Settings.PF -join '' ;
          Creation          = Convert-UnixTimeToDateTime ($BackupsResult.Settings.CD -join '') ;
          TimeStamp         = Convert-UnixTimeToDateTime ($BackupsResult.Settings.TS -join '') ;  
          LastSuccess       = Convert-UnixTimeToDateTime ($BackupsResult.Settings.TL -join '') ;                                                                                                                                                                                                               
          SelectedGB        = (($BackupsResult.Settings.T3 -join '') /1GB) ;  
          UsedGB            = (($BackupsResult.Settings.US -join '') /1GB) ;  
          DataSources       = $BackupsResult.Settings.AP -join '' ;                                                                
          Account           = $BackupsResult.Settings.AU -join '' ;
          Location          = $BackupsResult.Settings.LN -join '' ;
          Notes             = $BackupsResult.Settings.AA843 -join '' ;
          IPMGUIPwd         = $BackupsResult.Settings.AA2531 -join '' ;
          TempInfo          = $BackupsResult.Settings.AA77 -join '' ;
          Product           = $BackupsResult.Settings.PN -join '' ;
          ProductID         = $BackupsResult.Settings.PD -join '' ;
          Profile           = $BackupsResult.Settings.OP -join '' ;
          OS                = $BackupsResult.Settings.OS -join '' ;                                                                
          ProfileID         = $BackupsResult.Settings.OI -join '' ;
          ActiveDatasources = $BackupsResult.Settings.I78 -join ''
        }
      }
      $bmdiag = "Retrieving Backups : Successful`r`n$($strLineSeparator)"
      logERR 4 "Send-GetBackups" "$($bmdiag)"
    } catch {
      $bmdiag = "Error Retrieving Backups : Backup Reports will be Unavailable`r`n$($strLineSeparator)"
      $bmdiag += "`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
      logERR 5 "Send-GetBackups" "$($bmdiag)"
    }
  } ## Send-GetDevices API Call

  function Get-DRStatistics {
    Param ([Parameter(Mandatory=$False)][Int]$PartnerId) #end param

    $Script:url2 = "https://api.backup.management/draas/actual-statistics/v1/dashboard/?" #fields=backup_cloud_device_id,plan_device_id,backup_cloud_partner_id,last_recovery_session_id,current_recovery_status,last_recovery_status,last_recovery_timestamp,last_recovery_duration_user,plan_name,backup_cloud_partner_name,backup_cloud_device_name,backup_cloud_device_machine_name,region_name,type,recovery_target_type,recovery_agent_name,backup_cloud_device_status,backup_cloud_device_name,backup_cloud_partner_name,colorbar,last_recovery_boot_status,current_recovery_status,last_recovery_timestamp,last_recovery_errors_count,last_recovery_duration_user,plan_name,last_recovery_screenshot_presented,backup_cloud_device_status,last_recovery_restored_files_count,last_recovery_selected_files_count,region_name,data_sources,last_recovery_status,last_recovery_restored_size,last_recovery_selected_size,backup_cloud_device_machine_os_type,recovery_session_progress,recovery_agent_state,backup_cloud_device_alias,recovery_target_type,recovery_target_vm_virtual_switch,recovery_target_vhd_path,recovery_target_local_speed_vault,recovery_target_lsv_path,recovery_target_enable_replication_service,recovery_target_vm_address,recovery_target_subnet_mask,recovery_target_gateway,recovery_target_dns_server,recovery_target_enable_machine_boot&sort=last_recovery_timestamp&filter%5Btype%5D=RECOVERY_TESTING&filter%5Bpartner_materialized_path.contains%5D=/$($PartnerId)/"
    $data = @{}
    $data.visa = $Script:visa
    $data.params = @{}
    $data.params.query = @{}
    $data.params.query.PartnerId = $PartnerId
    #$data.params.query.sort = "backup_cloud_partner_name"
    #$data.params.query.Filter = @("%5Btype%5D=RECOVERY_TESTIN", "%5Bpartner_materialized_path.contains%5D=/$($PartnerId)/")
    $data.params.query.fields = @(
      "backup_cloud_device_id",
      "plan_device_id",
      "last_recovery_session_id",
      "current_recovery_status",
      "last_recovery_status",
      "last_recovery_timestamp",
      "last_recovery_duration_user",
      "plan_name",
      "backup_cloud_partner_name",
      "backup_cloud_device_name",
      "backup_cloud_device_machine_name",
      "region_name",
      "type",
      "recovery_target_type",
      "recovery_agent_name",
      "backup_cloud_device_status",
      "backup_cloud_device_name",
      "backup_cloud_partner_name",
      "colorbar",
      "last_recovery_boot_status",
      "current_recovery_status",
      "last_recovery_timestamp",
      "last_recovery_errors_count",
      "last_recovery_duration_user",
      "plan_name",
      "last_recovery_screenshot_presented",
      "backup_cloud_device_status",
      "last_recovery_restored_files_count",
      "last_recovery_selected_files_count",
      "region_name",
      "data_sources",
      "last_recovery_status",
      "last_recovery_restored_size",
      "last_recovery_selected_size",
      "backup_cloud_device_machine_os_type",
      "recovery_session_progress",
      "recovery_agent_state",
      "backup_cloud_device_alias",
      "recovery_target_type",
      "recovery_target_vm_virtual_switch",
      "recovery_target_vhd_path",
      "recovery_target_local_speed_vault",
      "recovery_target_lsv_path",
      "recovery_target_enable_replication_service",
      "recovery_target_vm_address",
      "recovery_target_subnet_mask",
      "recovery_target_gateway",
      "recovery_target_dns_server",
      "recovery_target_enable_machine_boot"
    )

    $params = @{
      Uri         = $url2
      Method      = 'GET'
      Headers     = @{ 'Authorization' = "Bearer $Script:visa" }
      WebSession  = $websession
      ContentType = 'application/json; charset=utf-8'
    }

    try {
      $Script:DRStatisticsResponse = Invoke-RestMethod @params
      $Script:DRStatistics = $Script:DRStatisticsResponse.data.attributes | sort-object -property backup_cloud_partner_name | Select-object *
      $Script:DRStatistics | foreach-object { $_.last_recovery_selected_size = [Math]::Round([Decimal]($($_.last_recovery_selected_size) /1GB),2) }
      $Script:DRStatistics | foreach-object { $_.last_recovery_restored_size = [Math]::Round([Decimal]($($_.last_recovery_restored_size) /1GB),2) }
      $Script:DRStatistics | foreach-object { $_.last_recovery_timestamp = Convert-UnixTimeToDateTime $($_.last_recovery_timestamp) }
      $bmdiag = "Retrieving Recovery Verification : Successful`r`n$($strLineSeparator)"
      logERR 4 "Get-DRStatistics" "$($bmdiag)"
    } catch {
      $bmdiag = "Error Retrieving Recovery Verification : Recovery Verification Reports will be Unavailable`r`n$($strLineSeparator)"
      $bmdiag += "`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
      logERR 5 "Get-DRStatistics" "$($bmdiag)"
    }
  } ## Get-DRStatistics API Call
#endregion ----- Backup.Management JSON Calls ----
#endregion ----- API FUNCTIONS ----

#region ----- MISC FUNCTIONS ----
  function Get-EpochDate ($epochDate, $opt) {                     #Convert Epoch Date Timestamps to Local Time
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

  function Pop-Warnings {
    param (
      $dest, $customer, $warn
    )
    #POPULATE AV PRODUCT WARNINGS DATA INTO NESTED HASHTABLE FORMAT FOR LATER USE
    try {
      if (($warn -ne $null) -and ($customer -ne "")) {
        if ($dest.containskey($customer)) {
          $new = [System.Collections.ArrayList]@()
          $prev = [System.Collections.ArrayList]@()
          $blnADD = $true
          $prev = $dest[$customer]
          $prev = $prev.split("`r`n",[System.StringSplitOptions]::RemoveEmptyEntries)
          if ($prev -contains $warn) {
            $blnADD = $false
          }
          if ($blnADD) {
            foreach ($itm in $prev) {
              $new.add("$($itm)`r`n")
            }
            $new.add("$($warn)`r`n")
            $dest.remove($customer)
            $dest.add($customer, $new)
            $script:blnWARN = $true
          }
        } elseif (-not $dest.containskey($customer)) {
          $new = [System.Collections.ArrayList]@()
          $new = "$($warn)`r`n"
          $dest.add($customer, $new)
          $script:blnWARN = $true
        }
      }
    } catch {
      $warndiag = "Error populating warnings for $($customer)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n"
      write-output "Error populating warnings for $($customer)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n"
      $script:diag += "$($warndiag)"
      $warndiag = $null
      write-output $_.Exception
      write-output $_.scriptstacktrace
      write-output $_
    }
  } ## Pop-Warnings

  function logERR ($intSTG, $strModule, $strErr) {
    $script:blnWARN = $true
    #CUSTOM ERROR CODES
    switch ($intSTG) {
      1 {                                                         #'ERRRET'=1 - NOT ENOUGH ARGUMENTS, END SCRIPT
        $script:blnBREAK = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date))`t - Invoice_Insanity - NO ARGUMENTS PASSED, END SCRIPT`r`n`r`n"
        write-output "$($strLineSeparator)`r`n$($(get-date))`t - Invoice_Insanity - NO ARGUMENTS PASSED, END SCRIPT`r`n"
      }
      2 {                                                         #'ERRRET'=2 - INSTALL / IMPORT MODULE FAILURE, END SCRIPT
        $script:blnBREAK = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date))`t - Invoice_Insanity - ($($strModule)) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n"
        write-output "$($strLineSeparator)`r`n$($(get-date))`t - Invoice_Insanity - ($($strModule)) :"
        write-output "$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n"
      }
      default {                                                   #'ERRRET'=3+
        $script:blnWARN = $false
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date))`t - Invoice_Insanity - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
        write-output "$($strLineSeparator)`r`n$($(get-date))`t - Invoice_Insanity - $($strModule) :"
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
    $mill = $mill.SubString(0,[math]::min(3,$mill.length))
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
#Get the Hudu API Module if not installed
if (Get-Module -ListAvailable -Name HuduAPI) {
  try {
    Import-Module HuduAPI -MaximumVersion 2.3.2 -force
  } catch {
    logERR 2 "HuduAPI" "INSTALL / IMPORT MODULE FAILURE"
  }
} else {
  try {
    install-module HuduAPI -MaximumVersion 2.3.2 -force -confirm:$false
    Import-Module HuduAPI -MaximumVersion 2.3.2 -force
  } catch {
    logERR 2 "HuduAPI" "INSTALL / IMPORT MODULE FAILURE"
  }
}
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
  #Set Hudu logon information
  New-HuduAPIKey $script:HuduAPIKey
  New-HuduBaseUrl $script:HuduBaseDomain

  #Retrieve all Backup Accounts Only Once
  $bmdiag = "Authenticating Backups`r`n$($strLineSeparator)"
  logERR 4 "Authenticating Backups" "$($bmdiag)"
  Send-APICredentialsCookie
  $bmdiag = "AUTH STATE : $($script:blnBM)"
  logERR 4 "Authenticating Backups" "$($bmdiag)"
  if ($script:blnBM) {
    # OBTAIN PARTNER AND BACKUP ACCOUNT ID
    $bmdiag = "Passed Partner: $($script:bmRoot)`r`n$($strLineSeparator)"
    logERR 4 "Backups Retrieval" "$($bmdiag)"
    Send-GetPartnerInfo "$($script:bmRoot)"
    Send-GetBackups "$($script:bmRoot)"
    Get-DRStatistics "$($PartnerId)"
  } elseif (-not $script:blnBM) {
    $bmdiag = "Error Authenticating : Backup Reports will be Unavailable`r`n$($strLineSeparator)"
    $authdiag += "`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
    logERR 5 "Backups Retrieval" "$($bmdiag)"
  }

  #QUERY AT PSA API
  write-output "`r`n$($script:strLineSeparator)`r`nQUERYING AT API :`r`n$($script:strLineSeparator)"
  $script:psaCountries = PSA-FilterQuery $script:psaHeaders "GET" "Countries" $psaGenFilter
  write-output "`t$($script:strLineSeparator)`r`n`tCLASS MAP :"
  PSA-GetMaps $script:psaHeaders $script:classMap "ClassificationIcons"
  $script:classMap
  write-output "`t$($script:strLineSeparator)`r`n`t$($script:strLineSeparator)`r`n`tCATEGORY MAP :"
  PSA-GetMaps $script:psaHeaders $script:categoryMap "CompanyCategories"
  $script:categoryMap
  write-output "`t$($script:strLineSeparator)`r`n`t$($script:strLineSeparator)`r`n`tASSET TYPE MAP :"
  PSA-GetMaps $script:psaHeaders $script:ciTypeMap "ConfigurationItemTypes"
  $script:ciTypeMap
  write-output "`t$($script:strLineSeparator)`r`n`t$($script:strLineSeparator)`r`n`tRETRIEVING COMPANIES :`r`n`t$($script:strLineSeparator)"
  PSA-GetCompanies $script:psaHeaders
  write-output "`tDone`r`n`t$($script:strLineSeparator)`r`nQUERY AT DONE`r`n$($script:strLineSeparator)"

  #QUERY DRMM API
  write-output "`r`n$($script:strLineSeparator)`r`nQUERYING DRMM API :`r`n$($script:strLineSeparator)"
  write-output "`t$($script:strLineSeparator)`r`n`tRETRIEVING DRMM SITES :`r`n`t$($script:strLineSeparator)"
  $script:rmmToken = RMM-ApiAccessToken
  RMM-GetSites
  write-output "`tDone`r`n`t$($script:strLineSeparator)`r`nQUERY DRMM DONE`r`n$($script:strLineSeparator)"

  #QUERY SYNCRO API
  write-output "`r`n$($script:strLineSeparator)`r`nQUERYING SYNCRO API :`r`n$($script:strLineSeparator)"
  $script:syncroCustomers = Syncro-Query "GET" "customers" $null
  #write-output $script:syncroCustomers | out-string
  write-output "`t$($script:strLineSeparator)`r`n`tTotal # Syncro Customers : $($script:syncroCustomers.customers.Count)"
  start-sleep -milliseconds 200
  $script:syncroProducts = Syncro-Query "GET" "products" "category_id=195696"
  #write-output $script:syncroProducts | out-string
  write-output "`t$($script:strLineSeparator)`r`n`tTotal # Syncro Products : $($script:syncroProducts.products.Count)"
  start-sleep -milliseconds 200
  $script:syncroInvoices = Syncro-Query "GET" "invoices" $null
  #write-output $script:syncroInvoices | out-string
  write-output "`t$($script:strLineSeparator)`r`n`tTotal # Syncro Invoices : $($script:syncroInvoices.invoices.Count)"
  write-output "`t$($script:strLineSeparator)`r`nQUERY SYNCRO DONE`r`n$($script:strLineSeparator)`r`n"
  start-sleep -milliseconds 200
  
  if ($script:syncroCustomers) {
    #ITERATE THROUGH SYNCRO CUSTOMERS
    $actDate = ((get-date).AddYears(-3))
    foreach ($script:customer in $script:syncroCustomers.customers) {
      $rmmNETCount         = 0
      $rmmSRVCount         = 0
      $rmmWKSTCount        = 0
      $rmmSRVBackupCount   = 0
      $rmmWKSTBackupCount  = 0
      $psaNETCount         = 0
      $psaSRVCount         = 0
      $psaWKSTCount        = 0
      $psaSRVBackupCount   = 0
      $psaWKSTBackupCount  = 0
      start-sleep -milliseconds 100 #100msec X ~300 = 0.5min
      write-output "$($script:strLineSeparator)"
      write-output "`tProcessing Syncro Customer : $($script:customer.fullname) | $($script:customer.business_name) | Last Updated : $($script:customer.updated_at)"
      write-output "$($script:strLineSeparator)"
      switch ([datetime]$actDate -le [datetime]$script:customer.updated_at) {
        false {
          $blnChk = $false
          Pop-Warnings $script:syncroWARN "$($script:customer.fullname) | $($script:customer.business_name)" "WARN : Last Updated : $($script:customer.updated_at)`r`n"
          write-output "`tWARN : $($script:customer.fullname) : Last Updated : $($script:customer.updated_at)"
          break
        }
        true {
          $script:custLnItems = @()
          $script:customerInvoices = $script:syncroInvoices.invoices | 
            where {(($_.customer_id -eq $script:customer.id) -and ([datetime]($actDate).AddYears(2) -le [datetime]$_.updated_at))} | 
              sort -property updated_at
          #write-output $script:customerInvoices | out-string
          write-output "`t# Customer Syncro Invoices : $($script:customerInvoices.invoices.Count)`r`n`t$($script:strLineSeparator)"
          #COLLECT LINE ITEMS FROM EACH INVOICE
          $script:customerInvoices | foreach {
            $blnLnItem = $false
            start-sleep -Milliseconds 200
            #write-output "`t$($script:strLineSeparator)`r`n`tInvoice ID : $($_.id)`r`n`t`tLast Updated : $($_.updated_at)"
            $script:chkInvoice = Syncro-Query "GET" "invoices/$($_.id)" $null
            $script:chkLnItems = $script:chkInvoice.invoice.line_items
            foreach ($script:item in $script:chkLnItems) {
              foreach ($valid in $script:syncroLnItems) {
                if (($script:item.quantity -gt 0) -and 
                  (($script:item.name -match $valid) -or ($script:item.item -match $valid))) {
                    $blnLnItem = $true
                    #write-output "Line Item : $($item.item)`r`n----------"
                    #write-output "Line Item Name : $($item.name)`r`n----------"
                    #write-output "Matched : IPM RMS`r`n----------"
                    foreach ($invalid in $script:invalLnItems) {
                      if (($script:item.item -match $invalid) -or ($script:item.name -match $invalid)) {
                        Pop-Warnings $script:syncroWARN "$($script:customer.fullname) | $($script:customer.business_name)" "WARN : Invoice : $($_.id) : Outdated Line Items : $($script:item.item) / $($script:item.name)`r`n"
                        write-output "`t`tWARN : Invoice : $($_.id) : Outdated Line Items : $($script:item.item) / $($script:item.name)"
                        break
                      }
                    }
                    $script:custLnItems += New-Object -TypeName PSObject -Property @{
                      InvoiceID = $script:chkInvoice.invoice.id
                      UpdatedAt = $script:chkInvoice.invoice.updated_at
                      LnID = $script:item.id
                      LnItem = $script:item.item
                      LnName = $script:item.name
                      LnQty = $script:item.quantity
                    }
                  break
                }
              }
            }
            #if (-not ($blnLnItem)) {write-output "`t`tINFO : Skipped Invoice : $($_.id) : No Target Line Items"}
          }
          $script:custLnItems = $script:custLnItems | 
            sort -property LnItem -Unique | sort -property LnName -Unique | sort -property UpdatedAt -Descending
          $script:outLnItems = $script:custLnItems | fl | out-string
          write-output "`t$($script:strLineSeparator)`r`n`tFinal Customer Line Items :`r`n$($script:outLnItems.trim())`t$($script:strLineSeparator)"

          #CHECK HOME CUSTOMER SERVICES
          if (($null -eq $script:customer.business_name) -or ($script:customer.business_name -eq "")) {
            $script:syncroAssets = Syncro-Query "GET" "customer_assets" "customer_id=$($script:customer.id)"
            $script:syncroAssets = $script:syncroAssets | where {$_.assets.asset_type -eq "Syncro Device"}
            $script:outDevices = $script:syncroAssets.assets | fl | out-string
            write-output "`t# Customer Syncro Assets : $($script:syncroAssets.assets.count)`r`n`t$($script:strLineSeparator)"
            #write-output "`tSyncro Devices :`r`n`t$($script:outDevices)`r`n`t$($script:strLineSeparator)"
            #COMPARE SERVICES
            if (($script:syncroAssets.assets.count -eq 0) -and ($script:custLnItems)) {
              $script:custLnItems | foreach {
                #$script:blnWARN = $true
                Pop-Warnings $script:syncroWARN "$($script:customer.fullname) | $($script:customer.business_name)" "WARN : $($_.LnQty) '$($_.LnItem)' Invoice Line Items Found : No Syncro Devices to Match`r`n"
                write-output "`tWARN : $($script:customer.fullname) : $($_.LnQty) '$($_.LnItem)' Invoice Line Items Found : No Syncro Devices to Match"
              }
            } elseif (($script:syncroAssets.assets.count -gt 0) -and (-not ($script:custLnItems))) {
              #$script:blnWARN = $true
              Pop-Warnings $script:syncroWARN "$($script:customer.fullname) | $($script:customer.business_name)" "WARN : Invoice : $($_.id) : No Invoice Line Items : $($script:syncroAssets.assets.count) Syncro Devices Found`r`n"
              write-output "`tWARN : $($script:customer.fullname) : Invoice : $($_.id) : No Invoice Line Items : $($script:syncroAssets.assets.count) Syncro Devices Found"
            } elseif (($script:syncroAssets.assets.count -gt 0) -and ($script:custLnItems)) {
              $script:custLnItems | foreach {
                write-output "`tINFO : $($script:customer.fullname) : Matching 'IPM RMS' Invoice Line Items Found : $($script:syncroAssets.assets.count) Syncro Devices Found"
                #SERVERS
                if (($_.LnItem -match "IPM RMS - Server") -or ($_.LnName -match "IPM RMS - Server")) {
                  write-output "`t# Matching Syncro 'IPM RMS - Server' Assets : $($script:syncroAssets.assets.count) / $([int]$_.LnQty)`r`n`t$($script:strLineSeparator)"
                  if ([int]$_.LnQty -lt $script:syncroAssets.assets.count) {
                    Pop-Warnings $script:syncroWARN "$($script:customer.fullname) | $($script:customer.business_name)" "WARN : Syncro Device Count ($($script:syncroAssets.assets.count)) Exceeds '$($_.LnItem)' Line Item Quantity ($($_.LnQty))`r`n"
                    write-output "`tWARN : $($script:customer.fullname) : Syncro Device Count ($($script:syncroAssets.assets.count)) Exceeds '$($_.LnItem)' Line Item Quantity ($($_.LnQty))"
                  }

                } elseif (($_.LnItem -match "IPM RMS Backup - Server") -or ($_.LnName -match "IPM RMS Backup - Server")) {
                  write-output "`t# Matching Syncro 'IPM RMS Backup - Server' Assets : $($script:syncroAssets.assets.count) / $([int]$_.LnQty)`r`n`t$($script:strLineSeparator)"
                  if ([int]$_.LnQty -lt $script:syncroAssets.assets.count) {
                    Pop-Warnings $script:syncroWARN "$($script:customer.fullname) | $($script:customer.business_name)" "WARN : Syncro Device Count ($($script:syncroAssets.assets.count)) Exceeds '$($_.LnItem)' Line Item Quantity ($($_.LnQty))`r`n"
                    write-output "`tWARN : $($script:customer.fullname) : Syncro Device Count ($($script:syncroAssets.assets.count)) Exceeds '$($_.LnItem)' Line Item Quantity ($($_.LnQty))"
                  }

                #WORKSTATIONS
                } elseif (($_.LnItem -match "IPM RMS - Desktop") -or ($_.LnName -match "IPM RMS - Desktop")) {
                  write-output "`t# Matching Syncro 'IPM RMS - Desktop' Assets : $($script:syncroAssets.assets.count) / $([int]$_.LnQty)`r`n`t$($script:strLineSeparator)"
                  if ([int]$_.LnQty -lt $script:syncroAssets.assets.count) {
                    Pop-Warnings $script:syncroWARN "$($script:customer.fullname) | $($script:customer.business_name)" "WARN : Syncro Device Count ($($script:syncroAssets.assets.count)) Exceeds '$($_.LnItem)' Line Item Quantity ($($_.LnQty))`r`n"
                    write-output "`tWARN : $($script:customer.fullname) : Syncro Device Count ($($script:syncroAssets.assets.count)) Exceeds '$($_.LnItem)' Line Item Quantity ($($_.LnQty))"
                  }

                } elseif (($_.LnItem -match "IPM RMS Backup - Desktop") -or ($_.LnName -match "IPM RMS Backup - Desktop")) {
                  write-output "`t# Matching Syncro 'IPM RMS Backup - Desktop' Assets : $($script:syncroAssets.assets.count) / $([int]$_.LnQty)`r`n`t$($script:strLineSeparator)"
                  if ([int]$_.LnQty -lt $script:syncroAssets.assets.count) {
                    Pop-Warnings $script:syncroWARN "$($script:customer.fullname) | $($script:customer.business_name)" "WARN : Syncro Device Count ($($script:syncroAssets.assets.count)) Exceeds '$($_.LnItem)' Line Item Quantity ($($_.LnQty))`r`n"
                    write-output "`tWARN : $($script:customer.fullname) : Syncro Device Count ($($script:syncroAssets.assets.count)) Exceeds '$($_.LnItem)' Line Item Quantity ($($_.LnQty))"
                  }
                }
              }
            }
          #CHECK BUSINESS CUSTOMER SERVICES
          } elseif (($null -ne $script:customer.business_name) -and ($script:customer.business_name -ne "")) {
            #CHECK AT COMPANIES
            $script:atCompany = $script:psaCompanies | where-object {$_.CompanyName -eq "$($script:customer.business_name)"}
            if ($script:atCompany) {
              $script:psaAssets = PSA-GetAssets $script:psaHeaders $script:atCompany.CompanyID
              $script:outAssets = $script:psaAssets | fl | out-string
              $script:outCompany = $script:atCompany | fl | out-string
              write-output "`tAT Company Match :`r`n$($script:outCompany.trim())`t$($script:strLineSeparator)"
              write-output "`t# Customer AT Assets : $($script:psaAssets.count)`r`n`t$($script:strLineSeparator)"
              #write-output "`tAT Assets :`r`n`t$($script:outAssets)`t$($script:strLineSeparator)"
              #COMPARE SERVICES
              if (($script:psaAssets.count -eq 0) -and ($script:custLnItems)) {
                $script:custLnItems | foreach {
                  #$script:blnWARN = $true
                  Pop-Warnings $script:syncroWARN "$($script:customer.fullname) | $($script:customer.business_name)" "WARN : $($_.LnQty) '$($_.LnItem)' Invoice Line Items Found : No AT Assets to Match`r`n"
                  write-output "`tWARN : $($script:customer.business_name) : $($_.LnQty) '$($_.LnItem)' Invoice Line Items Found : No AT Assets to Match"
                }
              } elseif (($script:psaAssets.count -gt 0) -and (-not ($script:custLnItems))) {
                #$script:blnWARN = $true
                Pop-Warnings $script:syncroWARN "$($script:customer.fullname) | $($script:customer.business_name)" "WARN : Invoice : $($_.id) : No Invoice Line Items : $($script:psaAssets.count) AT Assets Found`r`n"
                write-output "`tWARN : $($script:customer.business_name) : Invoice : $($_.id) : No Invoice Line Items : $($script:psaAssets.count) AT Assets Found"
              } elseif (($script:psaAssets.count -gt 0) -and ($script:custLnItems)) {
                $script:custLnItems | foreach {
                  write-output "`tINFO : $($script:customer.business_name) : Matching 'IPM RMS' Invoice Line Items Found : $($script:psaAssets.count) AT Assets Found"
                  #SERVERS
                  if (($_.LnItem -match "IPM RMS - Server") -or ($_.LnName -match "IPM RMS - Server")) {
                    $psaSRVCount = $script:psaAssets | 
                      where {$script:ciTypeMap[[int]$_.configurationItemType] -eq "Server"}
                    write-output "`t# Matching AT 'IPM RMS - Server' Assets : $($psaSRVCount.count) / $([int]$_.LnQty)`r`n`t$($script:strLineSeparator)"
                    if ([int]$_.LnQty -lt $psaSRVCount.count) {
                      Pop-Warnings $script:syncroWARN "$($script:customer.fullname) | $($script:customer.business_name)" "WARN : AT Assets Count ($($psaSRVCount.count)) Exceeds '$($_.LnItem)' Line Item Quantity ($($_.LnQty))`r`n"
                      write-output "`tWARN : $($script:customer.business_name) : AT Assets Count ($($psaSRVCount.count)) Exceeds '$($_.LnItem)' Line Item Quantity ($($_.LnQty))"
                    }

                  } elseif (($_.LnItem -match "IPM RMS Backup - Server") -or ($_.LnName -match "IPM RMS Backup - Server")) {
                    $psaSRVBackupCount = $script:psaAssets | 
                      where {(($script:ciTypeMap[[int]$_.configurationItemType] -eq "Server") -and 
                        ($_.psaUDFs.value -contains 'Backup Manager|'))}
                    write-output "`t# Matching AT 'IPM RMS Backup - Server' Assets : $($psaSRVBackupCount.count) / $([int]$_.LnQty)`r`n`t$($script:strLineSeparator)"
                    if ([int]$_.LnQty -lt $psaSRVBackupCount.count) {
                      Pop-Warnings $script:syncroWARN "$($script:customer.fullname) | $($script:customer.business_name)" "WARN : AT Assets Count ($($psaSRVBackupCount.count)) Exceeds '$($_.LnItem)' Line Item Quantity ($($_.LnQty))`r`n"
                      write-output "`tWARN : $($script:customer.business_name) : AT Assets Count ($($psaSRVBackupCount.count)) Exceeds '$($_.LnItem)' Line Item Quantity ($($_.LnQty))"
                    }
                  
                  #WORKSTATIONS
                  } elseif (($_.LnItem -match "IPM RMS - Desktop") -or ($_.LnName -match "IPM RMS - Desktop")) {
                    $psaWKSTCount = $script:psaAssets | 
                      where {(($script:ciTypeMap[[int]$_.configurationItemType] -eq "Desktop") -or 
                        ($script:ciTypeMap[[int]$_.configurationItemType] -eq "Laptop") -or 
                        ($script:ciTypeMap[[int]$_.configurationItemType] -eq "Tablet") -or 
                        ($script:ciTypeMap[[int]$_.configurationItemType] -eq "Workstation"))}
                    write-output "`t# Matching AT 'IPM RMS - Desktop' Assets : $($psaWKSTCount.count) / $([int]$_.LnQty)`r`n`t$($script:strLineSeparator)"
                    if ([int]$_.LnQty -lt $psaWKSTCount.count) {
                      Pop-Warnings $script:syncroWARN "$($script:customer.fullname) | $($script:customer.business_name)" "WARN : AT Assets Count ($($psaWKSTCount.count)) Exceeds '$($_.LnItem)' Line Item Quantity ($($_.LnQty))`r`n"
                      write-output "`tWARN : $($script:customer.business_name) : AT Assets Count ($($psaWKSTCount.count)) Exceeds '$($_.LnItem)' Line Item Quantity ($($_.LnQty))"
                    }

                  } elseif (($_.LnItem -match "IPM RMS Backup - Desktop") -or ($_.LnName -match "IPM RMS Backup - Desktop")) {
                    $psaWKSTBackupCount = $script:psaAssets | 
                      where {((($script:ciTypeMap[[int]$_.configurationItemType] -eq "Desktop") -or 
                        ($script:ciTypeMap[[int]$_.configurationItemType] -eq "Laptop") -or 
                        ($script:ciTypeMap[[int]$_.configurationItemType] -eq "Tablet") -or 
                        ($script:ciTypeMap[[int]$_.configurationItemType] -eq "Workstation")) -and 
                        ($_.psaUDFs.value -contains 'Backup Manager|'))}
                    write-output "`t# Matching AT 'IPM RMS Backup - Desktop' Assets : $($psaWKSTBackupCount.count) / $([int]$_.LnQty)`r`n`t$($script:strLineSeparator)"
                    if ([int]$_.LnQty -lt $psaWKSTBackupCount.count) {
                      Pop-Warnings $script:syncroWARN "$($script:customer.fullname) | $($script:customer.business_name)" "WARN : AT Assets Count ($($psaWKSTBackupCount.count)) Exceeds '$($_.LnItem)' Line Item Quantity ($($_.LnQty))`r`n"
                      write-output "`tWARN : $($script:customer.business_name) : AT Assets Count ($($psaWKSTBackupCount.count)) Exceeds '$($_.LnItem)' Line Item Quantity ($($_.LnQty))"
                    }
                  
                  #NETWORK DEVICES
                  } elseif (($_.LnItem -match "IPM RMS - Network device") -or 
                    ($_.LnItem -match "IPM RMS - Misc network device") -or 
                    ($_.LnName -match "IPM RMS - Network device") -or 
                    ($_.LnName -match "IPM RMS - Misc network device")) {
                      $psaNETCount = $script:psaAssets | 
                        where {(($script:ciTypeMap[[int]$_.configurationItemType] -eq "Access Point") -or 
                          ($script:ciTypeMap[[int]$_.configurationItemType] -eq "Router") -or 
                          ($script:ciTypeMap[[int]$_.configurationItemType] -eq "Switch"))}
                      write-output "`t# Matching DRMM 'IPM RMS - Network' Devices : $($psaNETCount.count) / $([int]$_.LnQty)`r`n`t$($script:strLineSeparator)"
                      if ([int]$_.LnQty -lt $psaNETCount.count) {
                        Pop-Warnings $script:syncroWARN "$($script:customer.fullname) | $($script:customer.business_name)" "WARN : AT Assets Count ($($psaNETCount.count)) Exceeds '$($_.LnItem)' Line Item Quantity ($($_.LnQty))`r`n"
                        write-output "`tWARN : $($script:customer.business_name) : AT Assets Count ($($psaNETCount.count)) Exceeds '$($_.LnItem)' Line Item Quantity ($($_.LnQty))"
                      }
                  }
                }
              }
            } elseif (-not ($script:atCompany)) {
              write-output "`tNo AT Company Match`r`n`t$($script:strLineSeparator)"
            }

            #CHECK DRMM SITES
            $script:rmmSite = $script:drmmSites.sites | where-object {$_.name -eq "$($script:customer.business_name)"}
            if ($script:rmmSite) {
              $script:rmmDevices = RMM-GetDevices $script:rmmSite.uid
              $script:outDevices = $script:rmmDevices | fl | out-string
              $script:outSite = $script:rmmSite | fl | out-string
              write-output "`tDRMM Site Match :`r`n$($script:outSite.trim())`t$($script:strLineSeparator)"
              write-output "`t# Customer DRMM Devices : $($script:rmmDevices.count)`r`n`t$($script:strLineSeparator)"
              #write-output "`tDRMM Devices :`r`n`t$($script:outDevices)`t$($script:strLineSeparator)"
              #COMPARE SERVICES
              if (($script:rmmDevices.count -eq 0) -and ($script:custLnItems)) {
                $script:custLnItems | foreach {
                  #$script:blnWARN = $true
                  Pop-Warnings $script:syncroWARN "$($script:customer.fullname) | $($script:customer.business_name)" "WARN : $($_.LnQty) '$($_.LnItem)' Invoice Line Items Found : No DRMM Devices to Match`r`n"
                  write-output "`tWARN : $($script:customer.business_name) : $($_.LnQty) '$($_.LnItem)' Invoice Line Items Found : No DRMM Devices to Match"
                }
              } elseif (($script:rmmDevices.count -gt 0) -and (-not ($script:custLnItems))) {
                #$script:blnWARN = $true
                Pop-Warnings $script:syncroWARN "$($script:customer.fullname) | $($script:customer.business_name)" "WARN : Invoice : $($_.id) : No Invoice Line Items : $($script:rmmDevices.count) DRMM Devices Found`r`n"
                write-output "`tWARN : $($script:customer.business_name) : Invoice : $($_.id) : No Invoice Line Items : $($script:rmmDevices.count) DRMM Devices Found"
              } elseif (($script:rmmDevices.count -gt 0) -and ($script:custLnItems)) {
                $script:custLnItems | foreach {
                  write-output "`tINFO : $($script:customer.business_name) : Matching 'IPM RMS' Invoice Line Items Found : $($script:rmmDevices.count) DRMM Devices Found"
                  #SERVERS
                  if (($_.LnItem -match "IPM RMS - Server") -or ($_.LnName -match "IPM RMS - Server")) {
                    $rmmSRVCount = $script:rmmDevices | 
                      where {$_.deviceType.category -eq "Server"}
                    write-output "`t# Matching DRMM 'IPM RMS - Server' Devices : $($rmmSRVCount.count) / $([int]$_.LnQty)`r`n`t$($script:strLineSeparator)"
                    if ([int]$_.LnQty -lt $rmmSRVCount.count) {
                      Pop-Warnings $script:syncroWARN "$($script:customer.fullname) | $($script:customer.business_name)" "WARN : DRMM Devices Count ($($rmmSRVCount.count)) Exceeds '$($_.LnItem)' Line Item Quantity ($($_.LnQty))`r`n"
                      write-output "`tWARN : $($script:customer.business_name) : DRMM Devices Count ($($rmmSRVCount.count)) Exceeds '$($_.LnItem)' Line Item Quantity ($($_.LnQty))"
                    }

                  } elseif (($_.LnItem -match "IPM RMS Backup - Server") -or ($_.LnName -match "IPM RMS Backup - Server")) {
                    $rmmSRVBackupCount = $script:rmmDevices | 
                      where {(($_.deviceType.category -eq "Server") -and 
                        ($_.backupProduct -contains 'Backup Manager|'))}
                    write-output "`t# Matching DRMM 'IPM RMS Backup - Server' Devices : $($rmmSRVBackupCount.count) / $([int]$_.LnQty)`r`n`t$($script:strLineSeparator)"
                    if ([int]$_.LnQty -lt $rmmSRVBackupCount.count) {
                      Pop-Warnings $script:syncroWARN "$($script:customer.fullname) | $($script:customer.business_name)" "WARN : DRMM Devices Count ($($rmmSRVBackupCount.count)) Exceeds '$($_.LnItem)' Line Item Quantity ($($_.LnQty))`r`n"
                      write-output "`tWARN : $($script:customer.business_name) : DRMM Devices Count ($($rmmSRVBackupCount.count)) Exceeds '$($_.LnItem)' Line Item Quantity ($($_.LnQty))"
                    }
                  
                  #WORKSTATIONS
                  } elseif (($_.LnItem -match "IPM RMS - Desktop") -or ($_.LnName -match "IPM RMS - Desktop")) {
                    $rmmWKSTCount = $script:rmmDevices | 
                      where {(($_.deviceType.category -eq "Desktop") -or 
                        ($_.deviceType.category -eq "Laptop") -or 
                        ($_.deviceType.category -eq "Tablet"))}
                    write-output "`t# Matching DRMM 'IPM RMS - Desktop' Devices : $($rmmWKSTCount.count) / $([int]$_.LnQty)`r`n`t$($script:strLineSeparator)"
                    if ([int]$_.LnQty -lt $rmmWKSTCount.count) {
                      Pop-Warnings $script:syncroWARN "$($script:customer.fullname) | $($script:customer.business_name)" "WARN : DRMM Devices Count ($($rmmWKSTCount.count)) Exceeds '$($_.LnItem)' Line Item Quantity ($($_.LnQty))`r`n"
                      write-output "`tWARN : $($script:customer.business_name) : DRMM Devices Count ($($rmmWKSTCount.count)) Exceeds '$($_.LnItem)' Line Item Quantity ($($_.LnQty))"
                    }

                  } elseif (($_.LnItem -match "IPM RMS Backup - Desktop") -or ($_.LnName -match "IPM RMS Backup - Desktop")) {
                    $rmmWKSTBackupCount = $script:rmmDevices | 
                      where {((($_.deviceType.category -eq "Desktop") -or 
                        ($_.deviceType.category -eq "Laptop") -or 
                        ($_.deviceType.category -eq "Tablet")) -and 
                        ($_.backupProduct -contains 'Backup Manager|'))}
                    write-output "`t# Matching DRMM 'IPM RMS Backup - Desktop' Devices : $($rmmWKSTBackupCount.count) / $([int]$_.LnQty)`r`n`t$($script:strLineSeparator)"
                    if ([int]$_.LnQty -lt $rmmWKSTBackupCount.count) {
                      Pop-Warnings $script:syncroWARN "$($script:customer.fullname) | $($script:customer.business_name)" "WARN : DRMM Devices Count ($($rmmWKSTBackupCount.count)) Exceeds '$($_.LnItem)' Line Item Quantity ($($_.LnQty))`r`n"
                      write-output "`tWARN : $($script:customer.business_name) : DRMM Devices Count ($($rmmWKSTBackupCount.count)) Exceeds '$($_.LnItem)' Line Item Quantity ($($_.LnQty))"
                    }
                  
                  #NETWORK DEVICES
                  } elseif (($_.LnItem -match "IPM RMS - Network device") -or 
                    ($_.LnItem -match "IPM RMS - Misc network device") -or 
                    ($_.LnName -match "IPM RMS - Network device") -or 
                    ($_.LnName -match "IPM RMS - Misc network device")) {
                      $rmmNETCount = $script:rmmDevices | 
                        where {$_.deviceType.category -match "Network"}
                      write-output "`t# Matching DRMM 'IPM RMS - Network' Devices : $($rmmNETCount.count) / $([int]$_.LnQty)`r`n`t$($script:strLineSeparator)"
                      if ([int]$_.LnQty -lt $rmmNETCount.count) {
                        Pop-Warnings $script:syncroWARN "$($script:customer.fullname) | $($script:customer.business_name)" "WARN : DRMM Devices Count ($($rmmNETCount.count)) Exceeds '$($_.LnItem)' Line Item Quantity ($($_.LnQty))`r`n"
                        write-output "`tWARN : $($script:customer.business_name) : DRMM Devices Count ($($rmmNETCount.count)) Exceeds '$($_.LnItem)' Line Item Quantity ($($_.LnQty))"
                      }
                  }
                }
              }
            } elseif (-not ($script:rmmSite)) {
              write-output "`tNo DRMM Site Match`r`n`t$($script:strLineSeparator)"
            }
          }

          #CHECK BACKUP SERVICES
          $script:custBackups = $script:BackupsDetails | where {(($_.PartnerName -eq $script:customer.fullname) -or ($_.PartnerName -eq $script:customer.business_name))}
          $script:backupsOut = $script:custBackups | fl | out-string
          write-output "`t# Customer Cove Backup Devices : $($script:custBackups.count)`r`n`t$($script:strLineSeparator)"
          #write-output "`tCustomer Cove Backup Devices :`r`n`t$($script:backupsOut)`r`n`t$($script:strLineSeparator)"
          if (($script:custBackups.count -eq 0) -and ($script:custLnItems)) {
            $script:custLnItems | foreach {
              if (($_.LnItem -match "IPM RMS Backup") -or ($_.LnName -match "IPM RMS Backup")) {
                #$script:blnWARN = $true
                Pop-Warnings $script:syncroWARN "$($script:customer.fullname) | $($script:customer.business_name)" "WARN : $($_.LnQty) '$($_.LnItem)' Invoice Line Items Found : No Cove Backup Devices to Match`r`n"
                write-output "`tWARN : $($script:customer.fullname) | $($script:customer.business_name) :"
                write-output "`tWARN : $($_.LnQty) '$($_.LnItem)' Invoice Line Items Found : No Cove Backup Devices to Match"
              }
            }
          } elseif (($script:custBackups.count -gt 0) -and (-not ($script:custLnItems))) {
            #$script:blnWARN = $true
            Pop-Warnings $script:syncroWARN "$($script:customer.fullname) | $($script:customer.business_name)" "WARN : Invoice : $($_.id) : No Invoice Line Items : $($script:custBackups.count) Cove Backup Devices Found`r`n"
            write-output "`tWARN : $($script:customer.fullname) | $($script:customer.business_name) :"
            write-output "`tWARN : No Invoice Line Items : $($script:custBackups.count) Cove Backup Devices Found"
          } elseif (($script:custBackups.count -gt 0) -and ($script:custLnItems)) {
            $script:custLnItems | foreach {
              if (($_.LnItem -match "IPM RMS Backup") -or ($_.LnName -match "IPM RMS Backup")) {
                #$script:blnWARN = $true
                write-output "`tINFO : $($script:customer.fullname) | $($script:customer.business_name) :"
                write-output "`tINFO : Line Item : $($_.LnItem) - Qty : $([int]$_.LnQty) / $($script:custBackups.count) Cove Backup Devices Found"
                if ([int]$_.LnQty -lt $rmmNETCount.count) {
                  Pop-Warnings $script:syncroWARN "$($script:customer.fullname) | $($script:customer.business_name)" "WARN : Cove Backup Devices Count ($($script:custBackups.count)) Exceeds '$($_.LnItem)' Line Item Quantity ($($_.LnQty))`r`n"
                  write-output "`tWARN : $($script:customer.business_name) : Cove Backup Devices Count ($($script:custBackups.count)) Exceeds '$($_.LnItem)' Line Item Quantity ($($_.LnQty))"
                }
              }
            }            
          }
          break
        }
      }
      write-output "$($script:strLineSeparator)`r`n"
    }
  }
} catch {
  $script:blnWARN = $true
  $script:diag += "`r`nInvoice_Insanity : Failed to query API via $($params.Uri)"
  $script:diag += "`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
  write-output "$($script:diag)`r`n"
}

  write-output "`r`n$($strLineSeparator)`r`n`tThe Following Warning(s) Occurred :"
  foreach ($key in $script:syncroWARN.keys) {
    write-output "`t$($strLineSeparator)`r`n`t$($strLineSeparator)`r`n`t$(($key).trim())`r`n`t`t$($strLineSeparator)"
    foreach ($warn in $script:syncroWARN[$key]) {
      write-output "`t`t$($warn.trim())`r`n`t`t$($strLineSeparator)"
    }
  }
  write-output "$($strLineSeparator)`r`n"

  #Stop script execution time calculation
  StopClock
  logERR 3 "END" "$((get-date).ToString('yyyy-MM-dd hh:mm:ss')) - Completed Execution"
  #WRITE LOGFILE
  $null | set-content $script:logPath -force
  "$($script:diag)" | add-content $script:logPath -force
#END SCRIPT
#------------