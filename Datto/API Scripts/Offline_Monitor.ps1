#First Clear any variables
Remove-Variable * -ErrorAction SilentlyContinue

#region ----- DECLARATIONS ----
  $script:diag              = $null
  $script:blnBREAK          = $false
  $script:blnWARN           = $false
  $script:blnSITE           = $false
  $strLineSeparator         = "---------"
  $script:logPath           = "C:\IT\Log\Offline_Monitor"
  #region######################## TLS Settings ###########################
  #[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType] 'Tls12'
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
      Uri         = "$($script:psaAPI)/atservicesrest/v1.0/$($entity)"
      Headers     = $header
    }
    try {
      $script:psaCalls += 1
      Invoke-RestMethod @params -UseBasicParsing -erroraction stop
    } catch {
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
      logERR 4 "PSA-FilterQuery" "Failed to query PSA API via $($params.Uri)`r`n$($err)"
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
    try {
      $script:psaCalls += 1
      Invoke-RestMethod @params -UseBasicParsing -erroraction stop
    } catch {
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
      logERR 4 "PSA-FilterQuery" "Failed to query (filtered) PSA API via $($params.Uri)`r`n$($err)"
    }
  }

  function PSA-GetThreshold {
    param ($header)
    try {
      PSA-Query $header "GET" "ThresholdInformation" -erroraction stop
    } catch {
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
      logERR 4 "PSA-GetMaps" "Failed to populate PSA API Utilization`r`n$($err)"
    }
  }

  function PSA-GetMaps {
    param ($header, $dest, $entity)
    $Uri = "$($script:psaAPI)/atservicesrest/v1.0/$($entity)/query?search=$($script:psaActFilter)"
    try {
      $list = PSA-FilterQuery $header "GET" "$($entity)" "$($script:psaActFilter)"
      foreach ($item in $list.items) {
        if ($dest.containskey($item.id)) {
          continue
        } elseif (-not $dest.containskey($item.id)) {
          $dest.add($item.id, $item.name)
        }
      }
    } catch {
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
        $script:country = $script:psaCountries.items | where {($_.id -eq $script:company.countryID)} | select displayName
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
          country         = "$($script:country.displayName)"
          phone           = "$($script:company.phone)"
          fax             = "$($script:company.fax)"
          webAddress      = "$($script:company.webAddress)"
        }
        #write-output "$($script:company.companyName) : $($script:company.companyType)"
        #write-output "Type Map : $(script:typeMap[[int]$script:company.companyType])"
      }
    } catch {
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
      logERR 4 "PSA-GetCompanies" "Failed to populate PSA Companies via API : $($psaActFilter)`r`n$($err)"
    }
  } ## PSA-GetCompanies API Call

  function PSA-GetAssets {
    param ($header, $companyID)
    try {
      $script:psaDeviceDetails = @()
      $deviceFilter = '{"Filter":[{"op":"and","items":[{"field":"CompanyID","op":"eq","value":'
      $deviceFilter += "$($companyID)},"
      $deviceFilter += '{"field":"IsActive","op":"eq","value":true}]}]}'
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
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
      logERR 4 "PSA-GetAssets" "Failed to populate PSA Assets via API : $($deviceFilter)`r`n$($err)"
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
    # Request access token
    try {
      $script:rmmCalls += 1
      (Invoke-WebRequest @params -UseBasicParsing -erroraction stop | ConvertFrom-Json).access_token
    } catch {
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
      logERR 4 "RMM-ApiAccessToken" "Failed to obtain DRMM API Access Token via $($params.Uri)`r`n$($params.Body)`r`n$($err)"
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
      Headers       = @{'Authorization'	= 'Bearer {0}' -f $apiAccessToken}
    }
    # Add body to parameters if present
    if ($apiRequestBody) {$params.Add('Body',$apiRequestBody)}
    # Make request
    try {
      $script:rmmCalls += 1
      (Invoke-WebRequest @params -UseBasicParsing).Content
    } catch {
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
      logERR 4 "RMM-ApiRequest" "Failed to process DRMM API Query via $($params.Uri)$($apiRequest)`r`n$($params.Body)`r`n$($err)"
    }
  }

  function RMM-PostUDF {
    param ([string]$deviceUID, [string]$companyType)
    $params = @{
      apiMethod       = "POST"
      apiUrl          = $script:rmmAPI
      apiAccessToken  = $script:rmmToken
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
    param ([string]$siteUID,[string]$filterID)
    $apiRequest       = "/v2/site/$($siteUID)/devices"
    if (($null -ne $filterID) -and ($filterID -ne "")) {$apiRequest += "?filterId=$($filterID)"}
    $params = @{
      apiMethod       = "GET"
      apiUrl          = $script:rmmAPI
      apiAccessToken  = $script:rmmToken
      apiRequest      = $apiRequest
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
          lastSeen         = $script:device.lastSeen
          #Assigned Services
          UDFs             = $script:device.udf
          avProduct        = $script:device.antivirus.antivirusproduct
          backupProduct    = $script:device.udf.udf13
        }
      }
      return $script:drmmDeviceDetails
    } catch {
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
      logERR 4 "RMM-GetDevices" "Failed to populate DRMM Devices via $($params.apiUrl)$($params.apiRequest)`r`n$($err)"
    }
  }

  function RMM-GetSites {
    $params = @{
      apiMethod       = "GET"
      apiUrl          = $script:rmmAPI
      apiAccessToken  = $script:rmmToken
      apiRequest      = "/v2/account/sites"
      apiRequestBody  = $null
    }
    try {
      $script:drmmSites = (RMM-ApiRequest @params -UseBasicParsing) | ConvertFrom-Json
      if ($script:drmmSites) {
        $script:drmmSites = $script:drmmSites.sites | sort -property name
      } elseif (($null -eq $script:drmmSites) -or ($script:drmmSites -eq "")) {
        $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
        logERR 4 "RMM-GetSites" "Failed to populate DRMM Sites via $($params.apiUrl)$($params.apiRequest)`r`n$($err)"
      }
    } catch {
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
      logERR 4 "RMM-GetSites" "Failed to populate DRMM Sites via $($params.apiUrl)$($params.apiRequest)`r`n$($err)"
    }
  }

#endregion ----- RMM FUNCTIONS ----
#endregion ----- API FUNCTIONS ----

#region ----- MISC FUNCTIONS ----
  function Get-EpochDate ($epochDate, $opt) {                     #Convert Epoch Date Timestamps to Local Time
    switch ($opt) {
      "sec" {[timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($epochDate))}
      "msec" {[timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddMilliSeconds($epochDate))}
    }
  } ## Get-EpochDate

  function Convert-UnixTimeToDateTime ($inputUnixTime) {
    if ($inputUnixTime -gt 0 ) {
      $epoch = Get-Date -Date "1970-01-01 00:00:00Z"
      $epoch = $epoch.ToUniversalTime()
      $epoch = $epoch.AddSeconds($inputUnixTime)
      return $epoch
    } else {
      return ""
    }
  }  ## Convert epoch time to date time

  function logERR ($intSTG, $strModule, $strErr) {
    $script:blnWARN = $true
    #CUSTOM ERROR CODES
    switch ($intSTG) {
      1 {                                                         #'ERRRET'=1 - NOT ENOUGH ARGUMENTS, END SCRIPT
        $script:blnBREAK = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date))`t - Offline_Monitor`r`n`tNO ARGUMENTS PASSED, END SCRIPT`r`n`r`n"
        write-output "$($strLineSeparator)`r`n$($(get-date))`t - Offline_Monitor`r`n`tNO ARGUMENTS PASSED, END SCRIPT`r`n"
      }
      2 {                                                         #'ERRRET'=2 - INSTALL / IMPORT MODULE FAILURE, END SCRIPT
        $script:blnBREAK = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date))`t - Offline_Monitor - ($($strModule)) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n"
        write-output "$($strLineSeparator)`r`n$($(get-date))`t - Offline_Monitor - ($($strModule)) :"
        write-output "$($strLineSeparator)`r`n`t$($strErr)`r`n`tEND SCRIPT`r`n`r`n"
      }
      3 {                                                         #'ERRRET'=3+
        $script:blnWARN = $false
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date))`t - Offline_Monitor - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
        write-output "$($strLineSeparator)`r`n$($(get-date))`t - Offline_Monitor - $($strModule) :"
        write-output "$($strLineSeparator)`r`n`t$($strErr)"
      }
      default {                                                   #'ERRRET'=4+
        $script:blnBREAK = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date))`t - Offline_Monitor - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
        write-output "$($strLineSeparator)`r`n$($(get-date))`t - Offline_Monitor - $($strModule) :"
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
  logERR 3 "AT API" "QUERYING AT API :`r`n$($strLineSeparator)"
  $script:psaCountries = PSA-FilterQuery $script:psaHeaders "GET" "Countries" $psaGenFilter
  logERR 3 "AT API" "$($strLineSeparator)`r`n`tASSET TYPE MAP :"
  PSA-GetMaps $script:psaHeaders $script:ciTypeMap "ConfigurationItemTypes"
  write-output "$(($script:ciTypeMap | out-string).trim())`r`n`t$($strLineSeparator)`r`n`tDone`r`n`t$($strLineSeparator)"
  $script:diag += "$(($script:ciTypeMap | out-string).trim())`r`n`t$($strLineSeparator)`r`n`tDone`r`n`t$($strLineSeparator)"
  logERR 3 "AT API" "$($strLineSeparator)`r`n`tTICKET FIELDS :"
  PSA-GetTicketFields $script:psaHeaders $script:ticketFields
  #$script:ticketFields
  write-output "`t$($strLineSeparator)`r`n`tDone`r`n`t$($strLineSeparator)"
  $script:diag += "`t$($strLineSeparator)`r`n`tDone`r`n`t$($strLineSeparator)`r`n"
  logERR 3 "AT API" "RETRIEVING COMPANIES :`r`n`t$($strLineSeparator)"
  PSA-GetCompanies $script:psaHeaders
  write-output "`tDone`r`n`t$($strLineSeparator)"
  $script:diag += "`tDone`r`n`t$($strLineSeparator)"
  logERR 3 "AT API" "QUERY AT DONE`r`n$($strLineSeparator)`r`n"

  #QUERY DRMM API
  logERR 3 "DRMM API" "QUERYING DRMM API :`r`n$($strLineSeparator)"
  logERR 3 "DRMM API" "RETRIEVING DRMM SITES :`r`n`t$($strLineSeparator)"
  $script:rmmToken = RMM-ApiAccessToken
  RMM-GetSites
  RMM-GetFilters
  $filter = $script:drmmFilters.filters | where {$_.name -eq "Devices: Offline > 30 Days"}
  write-output "`tDone`r`n`t$($strLineSeparator)"
  $script:diag += "`tDone`r`n`t$($strLineSeparator)"
  logERR 3 "DRMM API" "QUERY DRMM DONE`r`n$($strLineSeparator)`r`n"

  # for each DRMM Site
  foreach ($script:rmmSite in $script:drmmSites) {
    write-output ""
    $script:diag += "`r`n"
    start-sleep -Milliseconds 100
    if (($script:rmmSite.name -match 'CreateMe') -or 
      ($script:rmmSite.name -match 'Garland') -or 
      ($script:rmmSite.name -match 'Managed') -or 
      ($script:rmmSite.name -match 'Deleted Devices')) {
        logERR 3 "SITE DIAG" "Skipping $($script:rmmSite.name)`r`n$($strLineSeparator)"
    } elseif (($script:rmmSite.name -notmatch 'CreateMe') -and 
      ($script:rmmSite.name -notmatch 'Garland') -and 
      ($script:rmmSite.name -notmatch 'Managed') -and 
      ($script:rmmSite.name -notmatch 'Deleted Devices')) {
        logERR 3 "SITE DIAG" "Processing $($script:rmmSite.name) :`r`n$($strLineSeparator)"
        # collect all Devices
        $script:siteDevices = RMM-GetDevices $script:rmmSite.uid $filter.id
        $script:siteAssets = PSA-GetAssets $script:psaHeaders $script:rmmSite.autotaskCompanyId
        # check Device online status and last seen
        foreach ($script:rmmDevice in $script:siteDevices) {
          $script:siteAsset = $script:siteAssets | where {$_.rmmDeviceUID -eq $script:rmmDevice.DeviceUID}
          $script:assetTickets = PSA-GetTickets $script:psaHeaders $script:rmmSite.autotaskCompanyId $script:siteAsset.psaID "Device Activity Alert: Offline"
          $diagAsset = "$($script:rmmDevice.hostname) - Last Seen : $(Get-EpochDate $script:rmmDevice.lastSeen "msec")"
          $diagAsset += "`r`n`t$($strLineSeparator)`r`n$(($script:psaTicketdetails | fl | out-string).trim())"
          logERR 3 "ASSET DIAG" "$($diagAsset)`r`n`t$($strLineSeparator)"
          if ($script:assetTickets) {
            write-output "`tExisting Tickets Found. Not Creating Ticket`r`n`t$($strLineSeparator)`r`n$($strLineSeparator)"
            $script:diag += "`tExisting Tickets Found. Not Creating Ticket`r`n`t$($strLineSeparator)`r`n$($strLineSeparator)`r`n"
          } elseif (-not ($script:assetTickets)) {
            write-output "`tNo Tickets Found. Creating Ticket`r`n`t$($strLineSeparator)`r`n$($strLineSeparator)"
            $script:diag += "`tNo Tickets Found. Creating Ticket`r`n`t$($strLineSeparator)`r`n$($strLineSeparator)`r`n"
            $newTicket = @{
              id                   = '0'
              companyID            = $script:rmmSite.autotaskCompanyId
              configurationItemID  = "$($script:siteAsset.psaID)"
              queueID              = '8'         #Monitoring Alert
              ticketType           = '1'         #Standard
              ticketCategory       = "2"         #Datto RMM Alert
              status               = '1'         #New
              priority             = '2'         #Medium
              DueDateTime          = (get-date).adddays(7)
              monitorTypeID        = '1'         #Online Status Monitor
              source               = '8'         #Monitoring Alert
              issueType            = '18'        #RMM Monitoring
              subIssueType         = '231'       #Online Status Monitor
              billingCodeID        = '29682804'  #Maintenance
              title                = "Device Activity Alert: Offline 30+ Days : $($script:rmmDevice.hostname)"
              description          = "$($script:rmmDevice.hostname) - Last Seen : $(Get-EpochDate $script:rmmDevice.lastSeen "msec")"
            }
            PSA-CreateTicket $script:psaHeaders $newTicket
          }
        }
    }
  }
  
} catch {
  $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
  logERR 4 "INIT" "Failed to Query APIs`r`n`t$($err)`r`n$($strLineSeparator)"
}