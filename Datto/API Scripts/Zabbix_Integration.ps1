#region ----- DECLARATIONS ----
  #BELOW PARAM() MUST BE COMMENTED OUT FOR USE WITHIN DATTO RMM
  #UNCOMMENT BELOW PARAM() AND RENAME '$env:var' TO '$var' TO UTILIZE IN CLI
  #Param(
  #  [Parameter(Mandatory=$true)]$i_rmmKey,
  #  [Parameter(Mandatory=$true)]$i_rmmSecret
  #)
  $script:diag              = $null
  $script:finish            = $null
  $script:blnFAIL           = $false
  $script:blnWARN           = $false
  $script:blnSITE           = $false
  $script:strLineSeparator  = "---------"
  $script:logPath           = "C:\IT\Log\Zabbix_Integration"
  #region######################## TLS Settings ###########################
  [System.Net.ServicePointManager]::MaxServicePointIdleTime = 5000000
  #[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType] 'Tls12'
  #[System.Net.SecurityProtocolType]::Ssl3 -bor 
  #[System.Net.SecurityProtocolType]::Tls11 -bor 
  #[System.Net.SecurityProtocolType]::Tls
  [System.Net.ServicePointManager]::SecurityProtocol = (
    [System.Net.SecurityProtocolType]::Ssl2 -bor 
    [System.Net.SecurityProtocolType]::Tls13 -bor 
    [System.Net.SecurityProtocolType]::Tls12
  )
  #endregion
  #region######################## Zabbix Settings ###########################
  $script:zabbixAPI         = $env:ZabbixAPI    #"https://status.ipmrms.com/api_jsonrpc.php"
  $script:zabbixUSER        = $env:ZabbixUser
  $script:zabbixKEY         = $env:ZabbixKEY
  $script:zabbixGroups      = @(22, 23, 25)     #Zabbix Host Group IDs to retrieve Hosts from
  $script:zabbixTickets     = @(
    "Unavailable by ICMP ping",
    "Windows: Zabbix agent is not available",
    "Windows: Active checks are not available"
  )
  #endregion
  #region######################## Autotask Settings ###########################
  #PSA API DATASETS
  $script:psaCalls                = 0
  $script:classMap                = @{}
  $script:categoryMap             = @{}
  $script:typeMap                 = @{
    1 = "Customer"
    2 = "Lead"
    3 = "Prospect"
    4 = "Dead"
    6 = "Cancelation"
    7 = "Vendor"
    8 = "Partner"
  }
  $script:psaSkip                 = @("Cancelation", "Dead", "Lead", "Partner", "Prospect", "Vendor")
  #PSA API FILTERS
  #Generic Filter - ID -ge 0
  $psaGenFilter                   = '{"Filter":[{"field":"Id","op":"gte","value":0}]}'
  #IsActive Filter
  $psaActFilter                   = '{"Filter":[{"op":"and","items":[
                                    {"field":"IsActive","op":"eq","value":true},
                                    {"field":"Id","op":"gte","value":0}]}]}'
  #Ticket Filters
  $ExcludeType                    = '[]'
  $ExcludeQueue                   = '[]'
  $ExcludeStatus                  = '[5,20]'    #EXCLUDE STATUSES : 5 - COMPLETED , 20 - RMM RESOLVED
  $TicketFilter                   = "{`"Filter`":[{`"op`":`"notin`",`"field`":`"queueID`",`"value`":$($ExcludeQueue)},
                                    {`"op`":`"notin`",`"field`":`"status`",`"value`":$($ExcludeStatus)},
                                    {`"op`":`"notin`",`"field`":`"ticketType`",`"value`":$($ExcludeType)}]}"
  #PSA API URLS
  $AutotaskRoot                   = $env:ATRoot
  $AutoTaskAPIBase                = $env:ATAPIBase
  $script:psaAPI                  = "$($env:ATAPIBase)/atservicesrest/v1.0"
  $AutotaskAcct                   = "/Autotask/AutotaskExtend/ExecuteCommand.aspx?Code=OpenAccount&AccountID="
  $AutotaskExe                    = "/Autotask/AutotaskExtend/ExecuteCommand.aspx?Code=OpenTicketDetail&TicketNumber="
  $AutotaskDev                    = "/Autotask/AutotaskExtend/AutotaskCommand.aspx?&Code=OpenInstalledProduct&InstalledProductID="
  ########################### Autotask Auth ##############################
  $script:AutotaskAPIUser         = $env:ATAPIUser
  $script:AutotaskAPISecret       = $env:ATAPISecret
  $script:AutotaskIntegratorID    = $env:ATIntegratorID
  $script:psaHeaders              = @{
    'ApiIntegrationCode'          = "$($script:AutotaskIntegratorID)"
    'UserName'                    = "$($script:AutotaskAPIUser)"
    'Secret'                      = "$($script:AutotaskAPISecret)"
  }
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

  #region ----- PSA FUNCTIONS ----
  function Get-ATFieldHash {
    Param(
      [Array]$fieldsIn,
      [string]$name
    )
    #$script:psaCalls += 1
    $tempFields = ($fieldsIn.fields | where -filter {$_.name -eq $name}).picklistValues
    $tempValues = $tempFields | where -filter {$_.isActive -eq $true} | select value, label
    $tempHash = @{}
    $tempValues | Foreach {$tempHash[$_.value] = $_.label}
    return $tempHash	
  }

  function PSA-Query {
    param ($header, $method, $entity)
    $params = @{
      Method      = "$($method)"
      ContentType = 'application/json'
      Uri         = "$($script:psaAPI)/$($entity)"
      Headers     = $header
    }
    try {
      $script:psaCalls += 1
      Invoke-RestMethod @params -UseBasicParsing -erroraction stop
    } catch {
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($script:strLineSeparator)"
      logERR 3 "PSA-Query" "Failed to query PSA API via $($params.Uri)`r`n$($err)"
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
    try {
      $script:psaCalls += 1
      Invoke-RestMethod @params -UseBasicParsing -erroraction stop
    } catch {
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($script:strLineSeparator)"
      logERR 3 "PSA-FilterQuery" "Failed to query (filtered) PSA API via $($params.Uri)`r`n$($err)"
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
    try {
      $script:psaCalls += 1
      Invoke-RestMethod @params -UseBasicParsing -erroraction stop
    } catch {
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($script:strLineSeparator)"
      logERR 3 "PSA-Put" "Failed to post to PSA API via $($params.Uri)`r`n-----`r`n$($params.body)`r`n$($err)"
    }
  }

  function PSA-GetThreshold {
    param ($header)
    try {
      PSA-Query $header "GET" "ThresholdInformation" -erroraction stop
    } catch {
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($script:strLineSeparator)"
      logERR 3 "PSA-GetThreshold" "Failed to populate PSA API Utilization`r`n$($err)"
    }
  }

  function PSA-GetMaps {
    param ($header, $dest, $entity)
    try {
      $Uri = "$($script:psaAPI)/$($entity)/query?search=$($script:psaActFilter)"
      $list = PSA-FilterQuery $header "GET" "$($entity)" "$($script:psaActFilter)"
      foreach ($item in $list.items) {
        if ($dest.containskey($item.id)) {
          continue
        } elseif (-not $dest.containskey($item.id)) {
          $dest.add($item.id, $item.name)
        }
      }
    } catch {
      $script:blnFAIL = $true
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($script:strLineSeparator)"
      logERR 3 "PSA-GetMaps" "Failed to populate PSA $($entity) Maps via $($Uri)`r`n$($err)"
    }
  } ## PSA-GetMaps

  function PSA-GetCompanies {
    param ($header)
    try {
      $script:psaCompanies = @()
      $Uri = "$($script:psaAPI)/Companies/query?search=$($script:psaActFilter)"
      $CompanyList = PSA-FilterQuery $header "GET" "Companies" "$($script:psaActFilter)"
      $sort = ($CompanyList.items | Sort-Object -Property companyName)
      foreach ($company in $sort) {
        $country = $countries.items | where {($_.id -eq $company.countryID)} | select displayName
        $script:psaCompanies += New-Object -TypeName PSObject -Property @{
          CompanyID       = "$($company.id)"
          CompanyName     = "$($company.companyName)"
          CompanyType     = "$($company.companyType)"
          CompanyClass    = "$($company.classification)"
          CompanyCategory = "$($company.companyCategoryID)"
          address1        = "$($company.address1)"
          address2        = "$($company.address2)"
          city            = "$($company.city)"
          state           = "$($company.state)"
          postalCode      = "$($company.postalCode)"
          country         = "$($country.displayName)"
          phone           = "$($company.phone)"
          fax             = "$($company.fax)"
          webAddress      = "$($company.webAddress)"
        }
        #write-output "$($company.companyName) : $($company.companyType)"
        #write-output "Type Map : $(script:typeMap[[int]$company.companyType])"
      }
    } catch {
      $script:blnFAIL = $true
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($script:strLineSeparator)"
      logERR 3 "PSA-GetCompanies" "Failed to populate PSA Companies via $($Uri)`r`n$($err)"
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
      $Uri = "$($script:psaAPI)/ConfigurationItems/query?search=$($deviceFilter)"
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
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($script:strLineSeparator)"
      logERR 4 "PSA-GetAssets" "Failed to populate PSA Devices via API : $($Uri)`r`n$($err)"
    }
  } ## PSA-GetAssets API Call

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
      $Uri = "$($script:psaAPI)/Tickets/query?search=$($ticketFilter)"
      $script:atTickets = PSA-FilterQuery $header "GET" "Tickets" $ticketFilter
      return $script:atTickets.items
    } catch {
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($script:strLineSeparator)"
      logERR 4 "PSA-GetTickets" "Failed to populate PSA Tickets via API : $($Uri)`r`n$($err)"
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
      $Uri = "$($script:psaAPI)/Tickets/entityInformation/fields"
      #$list = Invoke-RestMethod @params -UseBasicParsing -erroraction stop
      $list = PSA-Query $header "GET" "Tickets/entityInformation/fields"
      foreach ($item in $list.fields) {
        if ($dest.containskey($item.name)) {
          continue
        } elseif (-not $dest.containskey($item.name)) {
          $dest.add($item.name, $item.picklistValues)
        }
      }
    } catch {
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($script:strLineSeparator)"
      logERR 4 "PSA-GetTicketFields" "Failed to populate PSA Ticket Fields via API : $($Uri)`r`n$($err)"
    }
  }

  function PSA-CreateTicket {
    param ($header, $ticket)
    $tParams         = @{
      Method        = "POST"
      ContentType   = 'application/json'
      Uri           = "$($script:psaAPI)/Tickets"
      Headers       = $header
      Body          = $ticket | convertto-json
    }
    try {
      $script:psaCalls += 1
      Invoke-RestMethod @tParams -UseBasicParsing -erroraction stop
    } catch {
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($script:strLineSeparator)"
      logERR 4 "PSA-CreateTicket" "Failed to create PSA Ticket via API : $($tParams.Uri)`r`n$($tParams.Body)`r`n$($err)"
    }
  }
  #endregion ----- PSA FUNCTIONS ----

  #region ----- ZABBIX FUNCTIONS ----
  function ZBX-ApiRequest {
    param ($header, $apiMethod, $reqParams)
    try {
      $script:apiBody = @{
        "jsonrpc"   = "2.0"
        "method"    = $apiMethod
        "params"    = $reqParams
        "id"        = $script:zabbixID
      }
      $script:params = @{
        Method        = "POST"
        Uri           = $script:zabbixAPI
        ContentType   = 'application/json'
        Headers       = @{'Authorization' = "Bearer $script:zabbixKEY"}
        Body          = $script:apiBody | convertto-json
      }
      $script:result = (invoke-webrequest @script:params).content | convertfrom-json
      if ($script:result.result) {
        return $script:result.result
      } elseif (-not ($script:result.result)) {
        $err = "$($script:result.error)`r`n$($script:strLineSeparator)`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($script:strLineSeparator)"
        logERR 4 "ZBX-ApiRequest"  "No Results from query to Zabbix API via $($script:params.Uri)`r`n$($script:params.Body)`r`n$($err)"
        return $null
      }
    } catch {
      $err = "$($script:result.error)`r`n$($script:strLineSeparator)`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($script:strLineSeparator)"
      logERR 4 "ZBX-ApiRequest"  "Failed to query Zabbix API via $($script:params.Uri)`r`n$($script:params.Body)`r`n$($err)"
    }
  }

  function ZBX-AckAction {
    param ($header, $apiMethod, $reqParams)
    try {
      $script:apiBody = @{
        "jsonrpc"   = "2.0"
        "method"    = $apiMethod  #"event.acknowledge"
        "params"    = $reqParams
        <#"params": {
          "eventids": "{EVENT.ID}",
          "action": 1,
          "message": "Problem resolved."
        },#>
        "id"        = $script:zabbixID
      }
      $script:params = @{
        Method        = "POST"
        Uri           = $script:zabbixAPI
        ContentType   = 'application/json'
        Headers       = @{'Authorization' = "Bearer $script:zabbixKEY"}
        Body          = $script:apiBody | convertto-json
      }
      $script:result = (invoke-webrequest @script:params).content | convertfrom-json
      if ($script:result.result) {
        return $script:result.result
      } elseif (-not ($script:result.result)) {
        $err = "$($script:result.error)`r`n$($script:strLineSeparator)`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($script:strLineSeparator)"
        logERR 4 "ZBX-AckAction"  "Failed to acknowledge Zabbix Problem via $($script:params.Uri)`r`n$($script:params.Body)`r`n$($err)"
        return $null
      }
    } catch {
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($script:strLineSeparator)"
      logERR 4 "ZBX-AckAction"  "Failed to acknowledge Zabbix Problem via $($script:params.Uri)`r`n$($script:params.Body)`r`n$($err)"
    }
  }
  #endregion ----- ZABBIX FUNCTIONS ----

  #region ----- MISC FUNCTIONS ----
  function logERR ($intSTG, $strModule, $strErr) {
    #CUSTOM ERROR CODES
    switch ($intSTG) {
      #'ERRRET'=1 - NOT ENOUGH ARGUMENTS, END SCRIPT
      1 {
        $script:blnBREAK = $true
        $script:diag += "`r`n$($script:strLineSeparator)`r`n$($(get-date))`t - Zabbix_Integration - NO ARGUMENTS PASSED, END SCRIPT`r`n`r`n"
        write-output "$($script:strLineSeparator)`r`n$($(get-date))`t - Zabbix_Integration - NO ARGUMENTS PASSED, END SCRIPT`r`n"
        break
      }
      #'ERRRET'=2 - INSTALL / IMPORT MODULE FAILURE, END SCRIPT
      2 {
        $script:blnBREAK = $true
        $script:diag += "`r`n$($script:strLineSeparator)`r`n$($(get-date))`t - Zabbix_Integration - ($($strModule)) :"
        $script:diag += "`r`n$($script:strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n"
        write-output "$($script:strLineSeparator)`r`n$($(get-date))`t - Zabbix_Integration - ($($strModule)) :"
        write-output "$($script:strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n"
        break
      }
      #'ERRRET'=3 - ERROR / WARNING
      3 {
        $script:blnWARN = $true
        $script:diag += "`r`n$($script:strLineSeparator)`r`n$($(get-date))`t - Zabbix_Integration - $($strModule) :"
        $script:diag += "`r`n$($script:strLineSeparator)`r`n`t$($strErr)"
        write-output "$($script:strLineSeparator)`r`n$($(get-date))`t - Zabbix_Integration - $($strModule) :"
        write-output "$($script:strLineSeparator)`r`n`t$($strErr)"
        break
      }
      #'ERRRET'=4 - INFORMATIONAL
      4 {
        $script:diag += "`r`n$($script:strLineSeparator)`r`n$($(get-date))`t - Zabbix_Integration - $($strModule) :"
        $script:diag += "`r`n$($script:strLineSeparator)`r`n`t$($strErr)"
        write-output "$($script:strLineSeparator)`r`n$($(get-date))`t - Zabbix_Integration - $($strModule) :"
        write-output "$($script:strLineSeparator)`r`n`t$($strErr)"
        break
      }
      #'ERRRET'=5+ - DEBUG
      default {
        $script:blnWARN = $false
        $script:diag += "`r`n$($script:strLineSeparator)`r`n$($(get-date))`t - Zabbix_Integration - $($strModule) :"
        $script:diag += "`r`n$($script:strLineSeparator)`r`n`t$($strErr)"
        write-output "$($script:strLineSeparator)`r`n$($(get-date))`t - Zabbix_Integration - $($strModule) :"
        write-output "$($script:strLineSeparator)`r`n`t$($strErr)"
        break
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
    $mill = $mill.SubString(0, [math]::min(3, $mill.length))
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
    $script:diag += "`r`nAPI Calls :`r`nPSA API : $($script:psaCalls) - RMM API : $($script:rmmCalls) - SYNCRO API : $($script:syncroCalls)`r`n"
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
#Attempt AutoTask Authentication; Fail Script if this fails
if (-not $script:blnBREAK) {
  try {
    $script:psaCalls += 1
    $authdiag = "Authenticating AutoTask`r`n$($script:strLineSeparator)"
    logERR 3 "Authenticating AutoTask" "$($authdiag)"
    #Autotask Auth
    $Creds = New-Object System.Management.Automation.PSCredential($script:AutotaskAPIUser, $(ConvertTo-SecureString $script:AutotaskAPISecret -AsPlainText -Force))
    Add-AutotaskAPIAuth -ApiIntegrationcode "$($script:AutotaskIntegratorID)" -credentials $Creds
    $authdiag = "Successful`r`n$($script:strLineSeparator)"
    logERR 3 "Authenticating AutoTask" "$($authdiag)"
    #Get Company Classifications and Categories
    logERR 3 "Autotask Retrieval" "CLASS MAP :`r`n$($script:strLineSeparator)"
    PSA-GetMaps $script:psaHeaders $script:classMap "ClassificationIcons"
    $script:classMap
    write-output "$($script:strLineSeparator)`r`nDone`r`n$($script:strLineSeparator)"
    $script:diag += "`r`n$($script:strLineSeparator)`r`nDone`r`n$($script:strLineSeparator)`r`n"
    logERR 3 "Autotask Retrieval" "CATEGORY MAP :`r`n$($script:strLineSeparator)"
    PSA-GetMaps $script:psaHeaders $script:categoryMap "CompanyCategories"
    $script:categoryMap
    write-output "$($script:strLineSeparator)`r`nDone`r`n$($script:strLineSeparator)"
    $script:diag += "`r`n$($script:strLineSeparator)`r`nDone`r`n$($script:strLineSeparator)`r`n"
    #Get Companies, Tickets, and Resources
    logERR 3 "Autotask Retrieval" "COMPANIES :`r`n$($script:strLineSeparator)"
    PSA-GetCompanies $script:psaHeaders
    write-output "Done`r`n$($script:strLineSeparator)"
    $script:diag += "`r`nDone`r`n$($script:strLineSeparator)`r`n"
    $script:psaCalls += 1
    logERR 3 "Autotask Retrieval" "TICKETS :`r`n$($script:strLineSeparator)"
    $tickets = Get-AutotaskAPIResource -Resource Tickets -SearchQuery "$($TicketFilter)"
    #$tickets = PSA-FilterQuery $script:psaHeaders "GET" "Tickets" $TicketFilter
    write-output "Done`r`n$($script:strLineSeparator)"
    $script:diag += "`r`nDone`r`n$($script:strLineSeparator)`r`n"
    #Get Ticket Fields
    logERR 3 "Autotask Retrieval" "TICKET FIELDS :`r`n$($script:strLineSeparator)"
    $ticketFields = PSA-Query $script:psaHeaders "GET" "Tickets/entityInformation/fields"
    $ticketUDFs = PSA-Query $script:psaHeaders "GET" "Tickets/entityInformation/userDefinedFields"
    #Get Statuses
    $statusValues = Get-ATFieldHash -name "status" -fieldsIn $ticketFields
    if (!$ExcludeStatus) {
      write-output "ExcludeStatus not set please exclude your closed statuses at least from below in the format of '[1,5,7,9]'"
      $script:diag += "`r`nExcludeStatus not set please exclude your closed statuses at least from below in the format of '[1,5,7,9]'"
      $statusValues | ft
    }
    #Get Ticket types
    $typeValues = Get-ATFieldHash -name "ticketType" -fieldsIn $ticketFields
    if (!$ExcludeType) {
      write-output "ExcludeType not set please exclude types from below in the format of '[1,5,7,9]"
      $script:diag += "`r`nExcludeType not set please exclude types from below in the format of '[1,5,7,9]"
      $typeValues | ft
    }
    #Get Queue Types
    $queueValues = Get-ATFieldHash -name "queueID" -fieldsIn $ticketFields
    if (!$ExcludeType) {
      write-output "ExcludeQueue not set please exclude types from below in the format of '[1,5,7,9]"
      $script:diag += "`r`nExcludeQueue not set please exclude types from below in the format of '[1,5,7,9]"
      $queueValues | ft
    }
    #Get Creator Types
    $creatorValues = Get-ATFieldHash -name "creatorType" -fieldsIn $ticketFields
    #Get Issue Types
    $issueValues = Get-ATFieldHash -name "issueType" -fieldsIn $ticketFields
    #Get Priority Types
    $priorityValues = Get-ATFieldHash -name "priority" -fieldsIn $ticketFields
    #Get Source Types
    $sourceValues = Get-ATFieldHash -name "source" -fieldsIn $ticketFields
    #Get Sub Issue Types
    $subissueValues = Get-ATFieldHash -name "subIssueType" -fieldsIn $ticketFields
    #Get Categories
    $catValues = Get-ATFieldHash -name "ticketCategory" -fieldsIn $ticketFields
    write-output "Done`r`n$($script:strLineSeparator)"
    $script:diag += "`r`nDone`r`n$($script:strLineSeparator)`r`n"
    #$resourceValues
    logERR 3 "Autotask Retrieval" "RESOURCES :`r`n$($script:strLineSeparator)"
    $resources = PSA-FilterQuery $script:psaHeaders "GET" "Resources" $psaGenFilter
    write-output "Done`r`n$($script:strLineSeparator)"
    $script:diag += "`r`nDone`r`n$($script:strLineSeparator)`r`n"
    #Grab All Assets for All Companies in a Single Call
    $configitems = $null
    $script:psaCalls += 1
    logERR 3 "Autotask Retrieval" "PSA ASSETS :`r`n$($script:strLineSeparator)"
    $psaAssetFilter = "{`"Filter`":[{`"field`":`"IsActive`",`"op`":`"eq`",`"value`":true}]}"
    $configitems = Get-AutotaskAPIResource -Resource ConfigurationItems -SearchQuery "$($psaAssetFilter)"
    write-output "Done`r`n$($script:strLineSeparator)"
    $script:diag += "`r`nDone`r`n$($script:strLineSeparator)`r`n"
    #Get PSA Asset Fields
    logERR 3 "Autotask Retrieval" "ASSET FIELDS :`r`n$($script:strLineSeparator)"
    $assetFields = PSA-Query $script:psaHeaders "GET" "ConfigurationItems/entityInformation/fields"
    #Get PSA Asset Manufacturer Data Map
    $assetMakes = Get-ATFieldHash -name "rmmDeviceAuditManufacturerID" -fieldsIn $assetFields
    #Get PSA Asset Model Data Map
    $assetModels = Get-ATFieldHash -name "rmmDeviceAuditModelID" -fieldsIn $assetFields
    write-output "Done`r`n$($script:strLineSeparator)"
    $script:diag += "`r`nDone`r`n$($script:strLineSeparator)`r`n"
  } catch {
    $script:blnBREAK = $true
    $authdiag = "Failed`r`n$($script:strLineSeparator)"
    $authdiag += "`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($script:strLineSeparator)"
    logERR 5 "Authenticating AutoTask" "$($authdiag)"
  }
}

if (-not $script:blnBREAK) {
  #region --- Group Loop --- Place this block into a loop of each primary Zabbix Host Group
  foreach ($script:zbxGroup in $script:zabbixGroups) {
    #Retrieve Zabbix Hosts by Host Groups
    $reqParams = @{
      "groupids" = $script:zbxGroup
    }
    #reqParams = @{
    #  "selectInterfaces" = "extend"
    #  "groupids" = 25
    #  "time_from" = ([DateTimeOffset]((get-date).adddays(-30))).tounixtimeseconds()
    #}
    $script:zbxInterfaces = ZBX-ApiRequest "TEST" "host.get" $reqParams
    $script:zbxHosts = $script:zbxInterfaces | foreach {
      #$($_.name).trim(); $($_.interfaces | out-string).trim();
      #write-output "`r`nProblems Detected :`r`n"
      $hostReq = @{"hostids" = $_.hostid}
      $hostProb = ZBX-ApiRequest $_.name "problem.get" $hostReq
      [pscustomobject]@{
        'Name'        = $_.name
        'Problems'    = if ($hostProb) {$hostProb} elseif (-not ($hostProb)) {$null}
      }
    }
    #region --- Process Host --- Place this block into a loop of each retrieved Zabbix Host
    foreach ($script:zbxHost in $script:zbxHosts) {
      $script:zbxHostChunks = $zbxHost.name -split " - "
      if ($script:zbxHostChunks.count -le 2) {
        $script:zbxHostDevice = $script:zbxHostChunks[1]
      } elseif ($script:zbxHostChunks.count -gt 2) {
        $script:zbxHostDevice = "$($script:zbxHostChunks[1])-$($script:zbxHostChunks[2])"
      }
      $script:psaCompany = $script:psaCompanies | where {$_.CompanyName -match (($zbxHost.name -split " - ")[0])}
      $script:siteAssets = $configitems | where {$_.companyID -eq $script:psaCompany.companyid}
      # Match PSA Asset by 'Zabbix HostID' UDF mapping
      $script:siteAsset = $script:siteAssets | where {$_.userDefinedFields.value -eq "$($zbxHost.interfaces.hostid)"}
      #region --- Process PSA Asset Open Tickets --- Turn this block into its own function
      #Retrieve all Open 'Zabbix Alert:' Tickets for PSA Asset
      $script:assetTickets = PSA-GetTickets $script:psaHeaders $script:psaCompany.CompanyID $null "Zabbix Alert: $($script:zbxHostDevice) :"
      if ($script:assetTickets) {
        $script:assetTickets | foreach {
          $curTicket = $_
          $blnClose = $true
          #Attempt to match Open Tickets to Open Problems
          if ($zbxHost.problems.eventid -contains ($curTicket.userDefinedFields | where {$_.name -eq 'Zabbix Problem ID'}).value) {$blnClose = $false}
          #Close any Open Tickets without matching Open Problems
          if ($blnClose) {
            logERR 3 "TICKET DIAG" "Close Ticket : $($curTicket.title)`r`n`t$($script:strLineSeparator)"
            #Create Ticket Note
            $ticketNote                       = @{
              id                              = 0
              publish                         = 1
              noteType                        = 1
              ticketID                        = $curTicket.id
              title                           = "Zabbix_Integration"
              createdByContactID              = $null
              creatorResourceID               = 29682901    #AT, API User
              description                     = "Zabbix_Integration : Self-Heal Notification : Problem No Longer Exists"
              impersonatorCreatorResourceID   = $null
              impersonatorUpdaterResourceID   = $null
              soapParentPropertyId            = @{body = @{}}
            }
            PSA-Put $script:psaHeaders "POST" "Tickets/$($curTicket.id)/Notes" ($ticketNote | convertto-json)
            #Set Ticket Status to 'RMM Resolved'
            $curTicket.status = '20'
            PSA-Put $script:psaHeaders "PUT" "Tickets" ($curTicket | convertto-json)
          } elseif (-not ($blnClose)) {
            logERR 3 "TICKET DIAG" "Matched Ticket : $($_.title)`r`n`t$($script:strLineSeparator)"
          }
        }
      }
      #endregion --- Process PSA Asset Open Tickets
      #region --- Process Problems --- Turn this block into its own function
      if ($zbxHost.problems) {
        $zbxHost.problems | foreach {
          #start-sleep -seconds 5
          #Skip Problem if no Problem ID exists --- Issue with 'ghost' Problems returned by API but not present in UI
          if (($script:zabbixTickets -contains $_.name) -and ($_.eventid)) {
            #Plan to handle Tickets by mapping 'Zabbix Problem ID' UDF mapping
            $blnTicket = $true
            $pTimestamp = "$([datetimeoffset]::fromunixtimeseconds($_.clock).localdatetime)"
            #Attempt to match PSA Ticket to Exact Zabbix Problem
            $script:assetTickets = PSA-GetTickets $script:psaHeaders $script:psaCompany.CompanyID $script:siteAsset.id "Zabbix Alert: $($script:zbxHostDevice) : $($_.name)"
            $diagAsset = "$($zbxHost.name)`r`nProblem : $($_.name) reported @ $($pTimestamp)`r`n$(($_ | fl) | out-string)"
            #$diagAsset += "`r`n`t$($script:strLineSeparator)`r`n$(($script:assetTickets | fl | out-string).trim())"
            logERR 3 "ASSET DIAG" "$($diagAsset)`r`n`t$($script:strLineSeparator)"
            if ($script:assetTickets) {
              if (($script:assetTickets.userDefinedFields | where {$_.name -eq 'Zabbix Problem ID'}).value -eq "$($_.eventid)") {$blnTicket = $false}
            }
            if (-not ($blnTicket)) {
              write-output "`tExisting Tickets Found. Not Creating Ticket`r`n`t$($script:strLineSeparator)`r`n$($script:strLineSeparator)"
              $script:diag += "`tExisting Tickets Found. Not Creating Ticket`r`n`t$($script:strLineSeparator)`r`n$($script:strLineSeparator)`r`n"
            } elseif ($blnTicket) {
              write-output "`tNo Tickets Found. Creating Ticket`r`n`t$($script:strLineSeparator)`r`n$($script:strLineSeparator)"
              $script:diag += "`tNo Tickets Found. Creating Ticket`r`n`t$($script:strLineSeparator)`r`n$($script:strLineSeparator)`r`n"
              $newTicket = @{
                id                    = '0'
                companyID             = $script:psaCompany.CompanyID
                configurationItemID   = "$($script:siteAsset.id)"
                queueID               = '8'         #Monitoring Alert
                ticketType            = '1'         #Standard
                ticketCategory        = "2"         #Datto RMM Alert
                status                = '1'         #New
                priority              = '2'         #Medium
                DueDateTime           = (get-date).adddays(7)
                monitorTypeID         = '1'         #Online Status Monitor
                source                = '8'         #Monitoring Alert
                issueType             = '30'        #Zabbix Monitoring
                subIssueType          = '329'       #Sophos Offline
                billingCodeID         = '29682804'  #Maintenance
                title                 = "Zabbix Alert: $($script:zbxHostDevice) : $($_.name)"
                userDefinedFields     = @(@{name = "Zabbix Problem ID"; value = "$($_.eventid)"})
                description           = "$($zbxHost.name)`r`nProblem : $($_.name) reported @ $($pTimestamp)`r`n$(($_ | fl) | out-string)"
              }
              #Create Ticket in AT PSA
              PSA-CreateTicket $script:psaHeaders $newTicket
              #Acknowledge in Zabbix
              <#"reqParams": {
                "eventids": "{EVENT.ID}",
                "action": 1,
                "message": "Problem resolved."
              },#>
              $reqParams  = @{
                action    = 1   #Acknowledge Problem
                eventids  = "$($_.eventid)"
                message   = "Problem ack via Zabbix_Integration"
              }
              ZBX-AckAction "ACKNOWLEDGE" "event.acknowledge" $reqParams
            }
          }
        }
      }
      #endregion --- Process Problems
    }
    #endregion --- Process Host
  }
  #endregion --- Group Loop
}

#Stop script execution time calculation
StopClock
#CLEAR LOGFILE
$null | set-content $script:logPath -force
"$($script:diag)" | add-content $script:logPath -force
if (-not $script:blnBREAK) {
  if (-not $script:blnWARN) {
    write-DRMMAlert "Zabbix_Integration : Healthy. No Issues Found : $($finish)"
    write-DRMMDiag "$($script:diag)"
    #exit 0
  } elseif ($script:blnWARN) {
    write-DRMMAlert "Zabbix_Integration : Issues Found. Please Check Diagnostics : $($finish)"
    write-DRMMDiag "$($script:diag)"
    #exit 1
  }
} elseif ($script:blnBREAK) {
  write-DRMMAlert "Zabbix_Integration : Execution Failed : $($finish)"
  write-DRMMDiag "$($script:diag)"
  #exit 1
}
#END SCRIPT
#------------