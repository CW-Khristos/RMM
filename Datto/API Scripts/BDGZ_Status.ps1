#First Clear any variables
Remove-Variable * -ErrorAction SilentlyContinue

#region ----- DECLARATIONS ----
  $script:diag              = $null
  $script:blnFAIL           = $false
  $script:blnWARN           = $false
  $script:blnSITE           = $false
  $script:strLineSeparator  = "---------"
  $script:logPath           = "C:\IT\Log\BDGZ_Status"
  #region######################## TLS Settings ###########################
  #[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType] 'Tls12'
  [System.Net.ServicePointManager]::SecurityProtocol = (
    [System.Net.SecurityProtocolType]::Tls13 -bor 
    [System.Net.SecurityProtocolType]::Tls12 -bor 
    [System.Net.SecurityProtocolType]::Tls11 -bor 
    [System.Net.SecurityProtocolType]::Tls
  )
  #endregion
  #region######################## BDGZ Settings ###########################
  $script:bdgzCalls         = 0
  $script:bdgzWARN          = @{}
  $script:bdgzAPI           = $env:BDGZAPIurl
  $script:bdgzKey           = $env:BDGZAPIkey
  $script:bdgzLogin         = "$($script:bdgzKey):"
  $script:bytes             = [System.Text.Encoding]::UTF8.GetBytes("$($script:bdgzKey):")
  $script:bdgzLogin         = [Convert]::ToBase64String($script:bytes)
  $script:bdgzHeader        = "Basic $($script:bdgzLogin)"
  #endregion
  #region######################## Syncro Settings ###########################
  $script:syncroCalls       = 0
  $script:syncroWARN        = @{}
  $script:syncroAPI         = $env:SyncroAPI
  $script:syncroKey         = $env:SyncroAPIkey
  $script:kabutoAPI         = 'https://rmm.syncromsp.com'
  #endregion
  #region######################## Autotask Settings ###########################
  #PSA API DATASETS
  $script:psaCountries      = $null
  $script:atWARN            = @{}
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
#region ----- BDGZ FUNCTIONS ----
  function BDGZ-GetCompanies {
    param ($customerID)
    $guid = [guid]::NewGuid()
    $request_data = @{
      jsonrpc     = "2.0"
      id          = "$($guid)"
      method      = "getCompaniesList"
      params      = @{}
    }
    if ($customerID) {$request_data.params.add("parentId", "$($customerID)")}
    #$request_data | convertto-json | out-string
    $params       = @{
      Method      = "POST"
      ContentType = 'application/json'
      Uri         = "$($script:bdgzAPI)/network"
      Body        = "$($request_data | convertto-json | out-string)"
      Headers     = @{
        "Content-Type"  = "application/json"
        "Authorization" = "$($script:bdgzHeader)"
      }
    }
    #$params
    try {
      $script:bdgzCalls += 1
      $response = Invoke-RestMethod @params
      return $response
    } catch {
    }
  }

  function BDGZ-GetEndpoints {
    param ($customerID)
    $guid = [guid]::NewGuid()
    $request_data = @{
      jsonrpc     = "2.0"
      id          = "$($guid)"
      method      = "getEndpointsList"
      params      = @{
        page      = 1
        perPage   = 100
        options   = @{
          returnProductOutdated = $true
        }
      }
    }
    if ($customerID) {$request_data.params.add("parentId", "$($customerID)")}
    #$request_data | convertto-json | out-string
    $params       = @{
      Method      = "POST"
      ContentType = 'application/json'
      Uri         = "$($script:bdgzAPI)/network"
      Body        = "$($request_data | convertto-json | out-string)"
      Headers     = @{
        "Content-Type"  = "application/json"
        "Authorization" = "$($script:bdgzHeader)"
      }
    }
    #$params
    try {
      $script:bdgzCalls += 1
      $response = Invoke-RestMethod @params
      if ([int]$response.result.pagesCount -gt 1) {
        $page = 1
        while ($page -lt [int]$response.result.pagesCount) {
          $page += 1
          $guid = [guid]::NewGuid()
          $request_data.id = "$($guid)"
          $request_data.page = [int]$page
          #$request_data | convertto-json | out-string
          $params       = @{
            Method      = "POST"
            ContentType = 'application/json'
            Uri         = "$($script:bdgzAPI)/network"
            Body        = "$($request_data | convertto-json | out-string)"
            Headers     = @{
              "Content-Type"  = "application/json"
              "Authorization" = "$($script:bdgzHeader)"
            }
          }
          #$params
          try {
            $script:bdgzCalls += 1
            $response += Invoke-RestMethod @params
          } catch {
          }
        }
      }
      return $response
    } catch {
    }
  }

  function BDGZ-GetEndpointDetail {
    param ($endpointID)
    $guid = [guid]::NewGuid()
    $request_data = @{
      jsonrpc     = "2.0"
      id          = "$($guid)"
      method      = "getManagedEndpointDetails"
      params      = @{
        endpointId = "$($endpointID)"
      }
    }
    #$request_data | convertto-json | out-string
    $params       = @{
      Method      = "POST"
      ContentType = 'application/json'
      Uri         = "$($script:bdgzAPI)/network"
      Body        = "$($request_data | convertto-json | out-string)"
      Headers     = @{
        "Content-Type"  = "application/json"
        "Authorization" = "$($script:bdgzHeader)"
      }
    }
    #$params
    try {
      $script:bdgzCalls += 1
      $response = Invoke-RestMethod @params
      return $response
    } catch {
    }
  }
#endregion ----- BDGZ FUNCTIONS ----
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
        $script:diag += "`r`nBDGZ_Status : Failed to query Syncro API via $($params.Uri) : $($method) : $($entity) : $($query) : $($page)"
        $script:diag += "`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
        write-output "$($script:diag)`r`n"
      }
    }
  }

  function Syncro-Post {
    param ($method, $entity, $body)
    if (-not ($body)) {
      $params = @{
        Method      = "$($method)"
        ContentType = 'application/json'
        Uri         = "$($script:syncroAPI)/$($entity)"
        Headers     = @{
          "accept" = "application/json"
          "Authorization" = $script:syncroKey
        }
      }
    } elseif ($body) {
      $params = @{
        Method      = "$($method)"
        ContentType = 'application/json'
        Uri         = "$($script:syncroAPI)/$($entity)"
        Body        = $body
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
      return $request
    } catch {
      if ($_.exception -match "Too Many Requests") {
        write-output "Too Many Request; Waiting 1 Minute..."
        start-sleep -seconds 60
        Syncro-Post $method $entity $body
      } else {
        $script:blnWARN = $true
        $script:diag += "`r`nBDGZ_Status : Failed to query Syncro API via $($params.Uri) : $($method) : $($entity) : $($query) : $($page)"
        $script:diag += "`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
        write-output "$($script:diag)`r`n"
      }
    }
  }

  function Syncro-Alert {
    param ($deviceUID, $alert)
    write-output $alert
    $data = @{
      device_uuid = $deviceUID
      trigger = $alert.properties.subject
      description = "$($alert.properties.tech)`r`n$($alert.description)`r`n$($alert.properties.body)"
    }
    $params = @{
      Method      = "POST"
      ContentType = 'application/json'
      Uri         = "$($kabutoAPI)/device_api/rmm_alert"
      Body        = $data | convertto-json
    }
    $uri = "$($kabutoAPI)/device_api/rmm_alert"
    $body = ConvertTo-Json20 -InputObject $data
    write-output "----"
    $body
    write-output "----"

    try {
      $page = 1
      $script:syncroCalls += 1
      #$request = Invoke-RestMethod @params -UseBasicParsing -erroraction stop
      $request = Invoke-WebRequest20 -Uri $uri -Method "POST" -Body $body -ContentType 'application/json'
      $resp = ConvertFrom-Json20($request)
      write-output $resp
      return $request
    } catch {
      if ($_.exception -match "Too Many Requests") {
        write-output "Too Many Request; Waiting 1 Minute..."
        start-sleep -seconds 60
        Syncro-Post $method $entity $body
      } else {
        $script:blnWARN = $true
        $script:diag += "`r`nBDGZ_Status : Failed to query Syncro API via $($params.Uri) : $($method) : $($entity) : $($query) : $($page)"
        $script:diag += "`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
        write-output "$($script:diag)`r`n"
      }
    }
  }

  function ConvertTo-Json20 ([object] $InputObject) {
    Add-Type -Assembly System.Web.Extensions
    $ps_js = New-Object System.Web.Script.Serialization.JavaScriptSerializer
    return $ps_js.Serialize($InputObject)
  }

  function ConvertFrom-Json20 ([object] $InputObject) {
    Add-Type -Assembly System.Web.Extensions
    $ps_js = New-Object System.Web.Script.Serialization.JavaScriptSerializer
    # The comma operator is the array construction operator in PowerShell
    return ,$ps_js.DeserializeObject($InputObject)
  }

  function Invoke-WebRequest20 ($Uri, $ContentType, $Method, $Body) {
      $request = [System.Net.WebRequest]::Create($Uri)
      $request.ContentType = $ContentType
      $request.Method = $Method
      try {
        $requestStream = $request.GetRequestStream()
        $streamWriter = New-Object System.IO.StreamWriter($requestStream)
        $streamWriter.Write($Body)
      } finally {
        if ($null -ne $streamWriter) { $streamWriter.Dispose() }
        if ($null -ne $requestStream) { $requestStream.Dispose() }
      }
      $response = $request.GetResponse();
      if ($null -ne $response) { Read-WebResponse($response) }
      return $null
  }

  function Read-WebResponse ([System.Net.WebResponse] $response) {
    try {
      $responseStream = $response.GetResponseStream()
      $streamReader = New-Object System.IO.StreamReader($responseStream)
      $content = $streamReader.ReadToEnd()
      return $content
    } finally {
      if ($null -ne $streamReader) { $streamReader.Dispose() }
      if ($null -ne $responseStream) { $responseStream.Dispose() }
    }
  }
#endregion ----- SYNCRO FUNCTIONS ----
#region ----- AT FUNCTIONS ----
  function PSA-Query {
    param ($header, $method, $entity)
    $params = @{
      Method      = "$($method)"
      ContentType = 'application/json'
      Uri         = "$($script:psaAPI)/atservicesrest/v1.0/$($entity)"
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
      Uri         = "$($script:psaAPI)/atservicesrest/v1.0/$($entity)/query?search=$($filter)"
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
    $Uri = "$($script:psaAPI)/$($entity)/atservicesrest/v1.0/query?search=$($script:psaActFilter)"
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
          configurationItemID  = "$($script:atTicket.configurationItemID)"

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
      Uri         = "$($script:psaAPI)/atservicesrest/v1.0/Tickets/entityInformation/fields"
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
      Uri            = "$($script:psaAPI)/atservicesrest/v1.0/Tickets"
      Headers        = $header
      Body           = convertto-json $ticket
    }
    try {
      $script:psaCalls += 1
      Invoke-RestMethod @params -UseBasicParsing -erroraction stop
    } catch {
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
      logERR 4 "PSA-CreateTicket" "Failed to obtain create PSA Ticket via $($params.Uri)`r`n$($params.Body)`r`n$($err)"
    }
  }
#endregion ----- AT FUNCTIONS ----
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
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date))`t - BDGZ_Status - NO ARGUMENTS PASSED, END SCRIPT`r`n`r`n"
        write-output "$($strLineSeparator)`r`n$($(get-date))`t - BDGZ_Status - NO ARGUMENTS PASSED, END SCRIPT`r`n"
      }
      2 {                                                         #'ERRRET'=2 - INSTALL / IMPORT MODULE FAILURE, END SCRIPT
        $script:blnBREAK = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date))`t - BDGZ_Status - ($($strModule)) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n"
        write-output "$($strLineSeparator)`r`n$($(get-date))`t - BDGZ_Status - ($($strModule)) :"
        write-output "$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n"
      }
      default {                                                   #'ERRRET'=3+
        $script:blnWARN = $false
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date))`t - BDGZ_Status - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
        write-output "$($strLineSeparator)`r`n$($(get-date))`t - BDGZ_Status - $($strModule) :"
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
    $average = ($total / ($script:psaCalls + $script:rmmCalls + $script:syncroCalls + $script:bdgzCalls))
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
    write-output "`r`nAPI Calls :`r`nPSA API : $($script:psaCalls) - RMM API : $($script:rmmCalls) - SYNCRO API : $($script:syncroCalls) - BDGZ API : $($script:bdgzCalls)"
    write-output "API Limits - PSA API (per Hour) : $($psa.currentTimeframeRequestCount) / $($psa.externalRequestThreshold) - RMM API (per Minute) : $($script:rmmCalls) / 600 - SYNCRO API (per Minute) : $($script:syncroCalls) / 180 - BDGZ API : $($script:bdgzCalls)"
    write-output "Total Execution Time - $($Minutes) Minutes : $($secs) Seconds : $($mill) Milliseconds`r`n"
    write-output "Average Execution Time (Per API Call) - $($amin) Minutes : $($asecs) Seconds : $($amill) Milliseconds`r`n"
    $script:diag += "`r`nAPI Calls :`r`nPSA API : $($script:psaCalls) - RMM API : $($script:rmmCalls) - SYNCRO API : $($script:syncroCalls) - BDGZ API : $($script:bdgzCalls)`r`n"
    $script:diag += "API Limits - PSA API (per Hour) : $($psa.currentTimeframeRequestCount) / $($psa.externalRequestThreshold) - RMM API (per Minute) : $($script:rmmCalls) / 600 - SYNCRO API (per Minute) : $($script:syncroCalls) / 180 - BDGZ API : $($script:bdgzCalls)`r`n"
    $script:diag += "Total Execution Time - $($Minutes) Minutes : $($secs) Seconds : $($mill) Milliseconds`r`n"
    $script:diag += "Average Execution Time (Per API Call) - $($amin) Minutes : $($asecs) Seconds : $($amill) Milliseconds`r`n`r`n"
  }
#endregion ----- MISC FUNCTIONS ----
#endregion ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
clear-host
$offTimestamp = (get-date).AddDays(-30)
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
  #QUERY BDGZ API
  logERR 3 "BDGZ API" "QUERYING BDGZ COMPANIES :`r`n`t$($script:strLineSeparator)"
  $script:bdgzCompanies = BDGZ-GetCompanies
  write-output "`tDone`r`n`t$($script:strLineSeparator)"
  logERR 3 "BDGZ API" "QUERY BDGZ COMPANIES DONE`r`n$($script:strLineSeparator)`r`n"

  #QUERY AT PSA API
  logERR 3 "AT API" "QUERYING AT API :`r`n`t$($script:strLineSeparator)"
  $script:psaCountries = PSA-FilterQuery $script:psaHeaders "GET" "Countries" $psaGenFilter
  logERR 3 "AT API" "$($script:strLineSeparator)`r`n`tCLASS MAP :"
  PSA-GetMaps $script:psaHeaders $script:classMap "ClassificationIcons"
  $script:classMap
  logERR 3 "AT API" "$($script:strLineSeparator)`r`n`tCATEGORY MAP :"
  PSA-GetMaps $script:psaHeaders $script:categoryMap "CompanyCategories"
  $script:categoryMap
  logERR 3 "AT API" "$($script:strLineSeparator)`r`n`tASSET TYPE MAP :"
  PSA-GetMaps $script:psaHeaders $script:ciTypeMap "ConfigurationItemTypes"
  $script:ciTypeMap
  logERR 3 "AT API" "$($script:strLineSeparator)`r`n`tTICKET FIELDS :"
  PSA-GetTicketFields $script:psaHeaders $script:ticketFields
  #$script:ticketFields
  logERR 3 "AT API" "$($script:strLineSeparator)`r`n`tRETRIEVING COMPANIES :`r`n`t$($script:strLineSeparator)"
  PSA-GetCompanies $script:psaHeaders
  write-output "`tDone`r`n`t$($script:strLineSeparator)"
  logERR 3 "AT API" "QUERY AT DONE`r`n$($script:strLineSeparator)`r`n"

  #QUERY SYNCRO API
  write-output "`r`n$($script:strLineSeparator)`r`nQUERYING SYNCRO API :`r`n$($script:strLineSeparator)"
  $script:syncroCustomers = Syncro-Query "GET" "customers" $null
  #write-output $script:syncroCustomers | out-string
  write-output "`t$($script:strLineSeparator)`r`n`tTotal # Syncro Customers : $($script:syncroCustomers.customers.Count)"
  start-sleep -milliseconds 200
  write-output "`t$($script:strLineSeparator)`r`nQUERY SYNCRO DONE`r`n$($script:strLineSeparator)`r`n"
  start-sleep -milliseconds 200
  
  #ITERATE THROUGH BDGZ CUSTOMERS
  if ($script:bdgzCompanies.result.count -gt 0) {
    foreach ($script:bdgzCompany in $script:bdgzCompanies.result) {
      $script:psaAsset = $null
      $script:psaAssets = $null
      $script:syncroAsset = $null
      $script:syncroAssets = $null
      write-output "`r`n$($script:strLineSeparator)`r`nPROCESSING COMPANY : $($script:bdgzCompany.name)`r`n$($script:strLineSeparator)"
      #CHECK AT PSA FOR CUSTOMER
      $script:psaCompany = $script:psaCompanies | where {$_.CompanyName -match $script:bdgzCompany.name}
      if ($script:psaCompany) {$script:psaAssets = PSA-GetAssets $script:psaHeaders $script:psaCompany.CompanyID}
      #CHECK SYNCRO PSA FOR CUSTOMER
      if ($script:bdgzCompany.name -match "_") {
        $script:syncroID = $script:bdgzCompany.name.split("_",[System.StringSplitOptions]::RemoveEmptyEntries)[1]
        $script:syncroCompany = $script:syncroCustomers.customers | where {$_.id -match $script:syncroID}
      } elseif ($script:bdgzCompany.name -notmatch "_") {
        $script:syncroCompany = $script:syncroCustomers.customers | 
          where {(($_.fullname -match $script:bdgzCompany.name) -or 
            ($_.business_name -match $script:bdgzCompany.name) -or 
            ($_.business_and_full_name -match $script:bdgzCompany.name))}
      }
      if ($script:syncroCompany) {
        $script:syncroAssets = Syncro-Query "GET" "customer_assets" "customer_id=$($script:syncroCompany.id)"
      }
      #ENUMERATE THROUGH BDGZ DEVICES
      $script:bdgzEndpoints = BDGZ-GetEndpoints $script:bdgzCompany.id
      if ($script:bdgzEndpoints.result.items.count -gt 0) {
        foreach ($script:bdgzEndpoint in $script:bdgzEndpoints.result.items) {
          $blnTicket = $false
          $script:bdgzDetails = BDGZ-GetEndpointDetail $script:bdgzEndpoint.id
          if (-not ($script:bdgzDetails.error)) {
            $warn = $null
            write-output "`t$($script:strLineSeparator)`r`n`tPROCESSING BDGZ DEVICE : $(($script:bdgzDetails.result.name | out-string).trim())`r`n`t$($script:strLineSeparator)"
            if ($offTimestamp -ge [datetime]$script:bdgzDetails.result.lastSeen) {$blnTicket = $true; $warn = "DEVICE ALERT : OFFLINE 30+"}
            if ($offTimestamp -ge [datetime]$script:bdgzDetails.result.agent.lastUpdate) {$blnTicket = $true; $warn = "DEVICE ALERT : AGENT OUTDATED"}
            if ($script:bdgzDetails.result.agent.productOutdated -ne $false) {$blnTicket = $true; $warn = "DEVICE ALERT : PRODUCT OUTDATED"}
            #if ($script:bdgzDetails.result.agent.signatureOutdated -ne $false) {$blnTicket = $true; $warn = "DEVICE ALERT : SIGNATURE OUTDATED"}
            if (($script:bdgzDetails.result.malwareStatus.detection -ne $false) -or 
              ($script:bdgzDetails.result.malwareStatus.infected -ne $false)) {
                $blnTicket = $true; $warn = "DEVICE ALERT : MALWARE DETECTED"
            }
            write-output "`t`t$($warn)"
            #CREATE TICKET
            if ($blnTicket) {
              if ($script:psaAssets.count -gt 0) {
                write-output "AT PSA ASSETS COUNT : $($script:psaAssets.count)"
                $script:psaAsset = $script:psaAssets | where {$_.referenceTitle -eq $script:bdgzDetails.result.name}
                write-output "AT PSA ASSET : $($script:psaAsset | fl | out-string)"
                #CHECK ASSET TICKETS
                $script:assetTickets = PSA-GetTickets $script:psaHeaders $script:psaCompany.CompanyID $script:psaAsset.psaID "BDGZ Device Activity Alert: $($script:bdgzDetails.result.name)"
                $diagAsset = "$($script:bdgzDetails.result.name) - Last Seen : $((get-date $script:bdgzDetails.result.lastSeen).ToString('yyyy-MM-dd hh:mm:ss'))"
                $diagAsset += "`r`n`t$($strLineSeparator)`r`n$(($script:psaTicketdetails | fl | out-string).trim())"
                logERR 3 "ASSET DIAG" "$($diagAsset)`r`n`t$($strLineSeparator)"
                if ($script:assetTickets) {
                  write-output "`tExisting Tickets Found. Not Creating Ticket`r`n`t$($strLineSeparator)`r`n$($strLineSeparator)"
                  $script:diag += "`tExisting Tickets Found. Not Creating Ticket`r`n`t$($strLineSeparator)`r`n$($strLineSeparator)`r`n"
                } elseif (-not ($script:assetTickets)) {
                  $newTicket = $null
                  write-output "`tNo Tickets Found. Creating Ticket`r`n`t$($strLineSeparator)`r`n$($strLineSeparator)"
                  $script:diag += "`tNo Tickets Found. Creating Ticket`r`n`t$($strLineSeparator)`r`n$($strLineSeparator)`r`n"
                  $newTicket = @{
                    id                   = '0'
                    companyID            = "$($script:psaCompany.CompanyID)"
                    configurationItemID  = "$($script:psaAsset.psaID)"
                    queueID              = '8'         #Monitoring Alert
                    ticketType           = '1'         #Standard
                    ticketCategory       = "2"         #Datto RMM Alert
                    status               = '1'         #New
                    priority             = '2'         #Medium
                    DueDateTime          = (get-date).adddays(7)
                    monitorTypeID        = '1'         #Online Status Monitor
                    source               = '8'         #Monitoring Alert
                    issueType            = '29'        #bitDefender GZ
                    subIssueType         = '323'       #Endpoint Connectivity
                    billingCodeID        = '29682804'  #Maintenance
                    title                = "BDGZ Device Activity Alert: $($script:bdgzDetails.result.name)"
                    description          = "$($warn)`r`n$($script:bdgzDetails.result.name) - Last Seen : $((get-date $script:bdgzDetails.result.lastSeen).ToString('yyyy-MM-dd hh:mm:ss')))"
                  }
                  PSA-CreateTicket $script:psaHeaders $newTicket
                }

              }
              if ($script:syncroAssets.assets.count -gt 0) {
                $script:syncroAsset = $script:syncroAssets.assets | where {$_.name -match $script:bdgzDetails.result.name}
                if ($script:syncroAsset) {
                  write-output "SYNCRO PSA ASSET : $($script:syncroAsset | fl | out-string)"
                  #CHECK SYNCRO ALERTS
                  $script:assetAlerts = Syncro-Query "GET" "rmm_alerts" "status=active"
                  $script:assetAlerts = $script:assetAlerts.rmm_alerts | where {$_.properties.description -match "$($warn)`r`n$($script:bdgzDetails.result.name)"}
                  if ($script:assetAlerts) {
                    write-output "`tExisting Syncro Alerts Found. Not Creating Alert`r`n`t$($strLineSeparator)`r`n$($strLineSeparator)"
                    $script:diag += "`tExisting Syncro Alerts Found. Not Creating Alert`r`n`t$($strLineSeparator)`r`n$($strLineSeparator)`r`n"
                  } elseif (-not ($script:assetAlerts)) {
                    $newAlert = $null
                    write-output "`tNo Syncro Alerts Found. Creating Alert`r`n`t$($strLineSeparator)`r`n$($strLineSeparator)"
                    $script:diag += "`tNo Syncro Alerts Found. Creating Alert`r`n`t$($strLineSeparator)`r`n$($strLineSeparator)`r`n"
                    $newAlert = @{
                      status               = 'New'
                      resolved             = $false
                      asset_id             = $script:syncroAsset.id
                      customer_id          = $script:syncroCompany.id
                      description          = "BDGZ Device Activity Alert: $($script:bdgzDetails.result.name)"
                      properties           = @{
                        hidden        = $true
                        do_not_email  = $true
                        tech          = 'BDGZ API'
                        subject       = "BDGZ $($warn)"
                        body          = "$($warn)`r`n$($script:bdgzDetails.result.name) - Last Seen : $((get-date $script:bdgzDetails.result.lastSeen).ToString('yyyy-MM-dd hh:mm:ss')))"
                        sms_body      = "$($warn)`r`n$($script:bdgzDetails.result.name) - Last Seen : $((get-date $script:bdgzDetails.result.lastSeen).ToString('yyyy-MM-dd hh:mm:ss')))"
                      }
                    }
                    Syncro-Alert $script:syncroAsset.properties.kabuto_live_uuid $newAlert
                  }
                }
              }
            }
          }
        }
      }
    }
  }
} catch {
  $script:blnWARN = $true
  $script:diag += "`r`nBDGZ_Status : Failed to query API via $($params.Uri)"
  $script:diag += "`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
  write-output "$($script:diag)`r`n"
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