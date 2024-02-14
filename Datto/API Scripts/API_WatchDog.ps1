#region ----- DECLARATIONS ----
  #BELOW PARAM() MUST BE COMMENTED OUT FOR USE WITHIN DATTO RMM
  #UNCOMMENT BELOW PARAM() AND RENAME '$env:var' TO '$var' TO UTILIZE IN CLI
  #Param(
  #  [Parameter(Mandatory=$true)]$i_rmmKey,
  #  [Parameter(Mandatory=$true)]$i_rmmSecret,
  #  [Parameter(Mandatory=$true)]$i_rmmUDF,
  #  [Parameter(Mandatory=$true)]$i_rmmAPI,
  #  [Parameter(Mandatory=$true)]$i_psaUser,
  #  [Parameter(Mandatory=$true)]$i_psaKey,
  #  [Parameter(Mandatory=$true)]$i_psaSecret,
  #  [Parameter(Mandatory=$true)]$i_psaIntegration,
  #  [Parameter(Mandatory=$true)]$i_psaAPI,
  #  [Parameter(Mandatory=$true)]$i_HuduKey,
  #  [Parameter(Mandatory=$true)]$i_HuduDomain
  #)
  $script:diag              = $null
  $script:finish            = $null
  $script:blnFAIL           = $false
  $script:blnWARN           = $false
  $script:blnSITE           = $false
  $script:strLineSeparator  = "---------"
  $script:logPath           = "C:\IT\Log\API_WatchDog"
  #region######################## TLS Settings ###########################
  #[System.Net.ServicePointManager]::MaxServicePointIdleTime = 5000000
  #[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType] 'Tls12'
  #[System.Net.SecurityProtocolType]::Ssl3 -bor 
  [System.Net.ServicePointManager]::SecurityProtocol = (
    [System.Net.SecurityProtocolType]::Ssl2 -bor 
    [System.Net.SecurityProtocolType]::Tls13 -bor 
    [System.Net.SecurityProtocolType]::Tls12 -bor 
    [System.Net.SecurityProtocolType]::Tls11 -bor 
    [System.Net.SecurityProtocolType]::Tls
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
  $script:classMap          = @{}
  $script:categoryMap       = @{}
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
  $script:psaAPI            = "$($env:ATAPIBase)/atservicesrest/v1.0"
  $AutotaskAcct             = "/Autotask/AutotaskExtend/ExecuteCommand.aspx?Code=OpenAccount&AccountID="
  $AutotaskExe              = "/Autotask/AutotaskExtend/ExecuteCommand.aspx?Code=OpenTicketDetail&TicketNumber="
  $AutotaskDev              = "/Autotask/AutotaskExtend/AutotaskCommand.aspx?&Code=OpenInstalledProduct&InstalledProductID="
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
#region ----- PSA FUNCTIONS ----
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
      $script:CompanyDetails = @()
      $Uri = "$($script:psaAPI)/Companies/query?search=$($script:psaActFilter)"
      $CompanyList = PSA-FilterQuery $header "GET" "Companies" "$($script:psaActFilter)"
      $sort = ($CompanyList.items | Sort-Object -Property companyName)
      foreach ($company in $sort) {
        $country = $countries.items | where {($_.id -eq $company.countryID)} | select displayName
        $script:CompanyDetails += New-Object -TypeName PSObject -Property @{
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
#endregion ----- PSA FUNCTIONS ----
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
    try {
      # Request access token
      $script:rmmCalls += 1
      (Invoke-WebRequest @params -UseBasicParsing -erroraction stop | ConvertFrom-Json).access_token
    } catch {
      $script:blnFAIL = $true
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($script:strLineSeparator)"
      logERR 3 "RMM-ApiAccessToken" "Failed to obtain DRMM API Access Token via $($params.Uri)`r`n$($err)"
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
    try {
      # Make request
      $script:rmmCalls += 1
      # Add body to parameters if present
      if ($apiRequestBody) {$params.Add('Body', $apiRequestBody)}
      (Invoke-WebRequest @params -UseBasicParsing).Content
    } catch {
      $script:blnWARN = $true
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($script:strLineSeparator)"
      logERR 3 "RMM-ApiRequest" "Failed to process DRMM API Query via $($params.Uri)`r`n$($err)"
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
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($script:strLineSeparator)"
      logERR 3 "RMM-PostUDF" "Failed to populate DRMM Device UDF via $($params.apiUrl)$($params.apiRequest)`r`n$($params.apiRequestBody)`r`n$($err)"
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
      $script:DeviceDetails = @()
      $DeviceList = (RMM-ApiRequest @params -UseBasicParsing) | ConvertFrom-Json
      foreach ($device in $DeviceList.devices) {
        $script:DeviceDetails += New-Object -TypeName PSObject -Property @{
          Hostname  = $device.hostname
          DeviceUID = $device.uid
          UDF       = $device.udf.$($script:rmmUDF)
        }
      }
    } catch {
      $script:blnWARN = $true
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($script:strLineSeparator)"
      logERR 3 "RMM-GetDevices" "Failed to populate DRMM Devices via $($params.apiUrl)$($params.apiRequest)`r`n$($err)"
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
      $script:sitesList = (RMM-ApiRequest @params -UseBasicParsing) | ConvertFrom-Json
      if (($null -eq $script:sitesList) -or ($script:sitesList -eq "")) {
        $script:blnFAIL = $true
        $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($script:strLineSeparator)"
        logERR 3 "RMM-GetSites" "Failed to populate DRMM Sites via $($params.apiUrl)$($params.apiRequest)`r`n$($err)"
      }
    } catch {
      $script:blnFAIL = $true
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($script:strLineSeparator)"
      logERR 3 "RMM-GetSites" "Failed to populate DRMM Sites via $($params.apiUrl)$($params.apiRequest)`r`n$($err)"
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
    try {
      $script:blnSITE = $false
      $script:updateSite = (RMM-ApiRequest @params -UseBasicParsing) #| ConvertFrom-Json
      if ($script:updateSite -match $name) {
        return $true
      } elseif ($script:updateSite -notmatch $name) {
        return $false
      }
    } catch {
      $script:blnWARN = $true
      $script:blnFAIL = $true
      $script:blnSITE = $false
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($script:strLineSeparator)"
      logERR 3 "RMM-UpdateSite" "Failed to update DRMM Site via $($params.apiUrl)$($params.apiRequest)`r`n$($params.apiRequestBody)`r`n$($err)"
    }
  }

  function RMM-NewSite {
    param (
      [string]$id,
      [string]$name,
      [string]$description,
      [string]$notes,
      [string]$onDemand,
      [string]$installSplashtop
    )
    $params = @{
      apiMethod       = "PUT"
      apiUrl          = $script:rmmAPI
      ApiAccessToken  = $script:rmmToken
      apiRequest      = "/v2/site"
      apiRequestBody  = "{`"autotaskCompanyId`": `"$($id)`",`"autotaskCompanyName`": `"$($name)`",`"description`": `"$($description)`",`"name`": `"$($name)`",`"notes`": `"$($notes)`",`"onDemand`": $($onDemand),`"splashtopAutoInstall`": $($installSplashtop)}"
    }
    try {
      $script:blnSITE = $false
      $script:newSite = (RMM-ApiRequest @params -UseBasicParsing) #| ConvertFrom-Json
      if ($script:newSite -match $name) {
        return $true
      } elseif ($script:newSite -match $name) {
        return $false
      }
    } catch {
      $script:blnWARN = $true
      $script:blnFAIL = $true
      $script:blnSITE = $false
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($script:strLineSeparator)"
      logERR 3 "RMM-NewSite" "Failed to create New DRMM Site via $($params.apiUrl)$($params.apiRequest)`r`n$($params.apiRequestBody)`r`n$($err)"
    }
  }
#endregion ----- RMM FUNCTIONS ----
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

  function dir-Check () {
    #CHECK 'PERSISTENT' FOLDERS
    if (-not (test-path -path "C:\temp")) {new-item -path "C:\temp" -itemtype directory}
    if (-not (test-path -path "C:\IT")) {new-item -path "C:\IT" -itemtype directory}
    if (-not (test-path -path "C:\IT\Log")) {new-item -path "C:\IT\Log" -itemtype directory}
    if (-not (test-path -path "C:\IT\Scripts")) {new-item -path "C:\IT\Scripts" -itemtype directory}
  }  ## dir-Check

  function logERR ($intSTG, $strModule, $strErr) {
    #CUSTOM ERROR CODES
    switch ($intSTG) {
      #'ERRRET'=1 - NOT ENOUGH ARGUMENTS, END SCRIPT
      1 {
        $script:blnBREAK = $true
        $script:diag += "`r`n$($script:strLineSeparator)`r`n$($(get-date))`t - API_WatchDog - NO ARGUMENTS PASSED, END SCRIPT`r`n`r`n"
        write-output "$($script:strLineSeparator)`r`n$($(get-date))`t - API_WatchDog - NO ARGUMENTS PASSED, END SCRIPT`r`n"
      }
      #'ERRRET'=2 - INSTALL / IMPORT MODULE FAILURE, END SCRIPT
      2 {
        $script:blnBREAK = $true
        $script:diag += "`r`n$($script:strLineSeparator)`r`n$($(get-date))`t - API_WatchDog - ($($strModule)) :"
        $script:diag += "`r`n$($script:strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n"
        write-output "$($script:strLineSeparator)`r`n$($(get-date))`t - API_WatchDog - ($($strModule)) :"
        write-output "$($script:strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n"
      }
      #'ERRRET'=3 - ERROR / WARNING
      3 {
        $script:blnWARN = $true
        $script:diag += "`r`n$($script:strLineSeparator)`r`n$($(get-date))`t - API_WatchDog - $($strModule) :"
        $script:diag += "`r`n$($script:strLineSeparator)`r`n`t$($strErr)"
        write-output "$($script:strLineSeparator)`r`n$($(get-date))`t - API_WatchDog - $($strModule) :"
        write-output "$($sscript:trLineSeparator)`r`n`t$($strErr)"
      }
      #'ERRRET'=4 - INFORMATIONAL
      4 {
        $script:diag += "`r`n$($script:strLineSeparator)`r`n$($(get-date))`t - API_WatchDog - $($strModule) :"
        $script:diag += "`r`n$($script:strLineSeparator)`r`n`t$($strErr)"
        write-output "$($script:strLineSeparator)`r`n$($(get-date))`t - API_WatchDog - $($strModule) :"
        write-output "$($script:strLineSeparator)`r`n`t$($strErr)"
      }
      #'ERRRET'=5+ - DEBUG
      default {
        $script:blnWARN = $false
        $script:diag += "`r`n$($script:strLineSeparator)`r`n$($(get-date))`t - API_WatchDog - $($strModule) :"
        $script:diag += "`r`n$($script:strLineSeparator)`r`n`t$($strErr)"
        write-output "$($script:strLineSeparator)`r`n$($(get-date))`t - API_WatchDog - $($strModule) :"
        write-output "$($script:strLineSeparator)`r`n`t$($strErr)"
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
    $script:finish = (get-date).tostring('yyyy-MM-dd hh:mm:ss')
    #TOTAL
    $total = ((((($Hours * 60) + $Minutes) * 60) + $Seconds) * 1000) + $Milliseconds
    $secs = [string]($total / 1000)
    $mill = $secs.split(".")[1]
    $secs = $secs.split(".")[0]
    $mill = $mill.SubString(0, [math]::min(3, $mill.length))
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
    write-output "API Limits - PSA API (per Hour) : $($psa.currentTimeframeRequestCount) / $($psa.externalRequestThreshold) - RMM API (per Minute) : $($script:rmmCalls) / 600 - SYNCRO API (per Minute) : $($script:syncroCalls) / 180 - BDGZ API : $($script:bdgzCalls)`r`n"
    write-output "Total Execution Time - $($Minutes) Minutes : $($secs) Seconds : $($mill) Milliseconds"
    write-output "Average Execution Time (Per API Call) - $($amin) Minutes : $($asecs) Seconds : $($amill) Milliseconds`r`n"
    $script:diag += "`r`nAPI Calls :`r`nPSA API : $($script:psaCalls) - RMM API : $($script:rmmCalls) - SYNCRO API : $($script:syncroCalls) - BDGZ API : $($script:bdgzCalls)`r`n"
    $script:diag += "API Limits - PSA API (per Hour) : $($psa.currentTimeframeRequestCount) / $($psa.externalRequestThreshold) - RMM API (per Minute) : $($script:rmmCalls) / 600 - SYNCRO API (per Minute) : $($script:syncroCalls) / 180 - BDGZ API : $($script:bdgzCalls)`r`n`r`n"
    $script:diag += "Total Execution Time - $($Minutes) Minutes : $($secs) Seconds : $($mill) Milliseconds`r`n"
    $script:diag += "Average Execution Time (Per API Call) - $($amin) Minutes : $($asecs) Seconds : $($amill) Milliseconds`r`n`r`n"
  }
#endregion ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
clear-host
#CHECK 'PERSISTENT' FOLDERS
dir-Check
#Start script execution time calculation
$ScrptStartTime = (get-date).tostring('dd-MM-yyyy hh:mm:ss')
$script:sw = [Diagnostics.Stopwatch]::StartNew()
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
#Set Hudu logon information
New-HuduAPIKey $script:HuduAPIKey
New-HuduBaseUrl $script:HuduBaseDomain
#QUERY PSA API
$countries = PSA-FilterQuery $script:psaHeaders "GET" "Countries" $script:psaGenFilter
logERR 4 "QUERY PSA API" "Classification Map`r`n`t$($script:strLineSeparator)"
PSA-GetMaps $script:psaHeaders $script:classMap "ClassificationIcons"
write-output "$(($script:classMap | out-string).trim())`r`n`t$($script:strLineSeparator)`r`n`tDone`r`n$($script:strLineSeparator)"
$script:diag += "$(($script:classMap | out-string).trim())`r`n`t$($script:strLineSeparator)`r`n`tDone`r`n$($script:strLineSeparator)`r`n"
logERR 4 "QUERY PSA API" "Company Category Map`r`n`t$($script:strLineSeparator)"
PSA-GetMaps $script:psaHeaders $script:categoryMap "CompanyCategories"
write-output "$(($script:categoryMap | out-string).trim())`r`n`t$($script:strLineSeparator)`r`n`tDone`r`n$($script:strLineSeparator)"
$script:diag += "$(($script:categoryMap | out-string).trim())`r`n`t$($script:strLineSeparator)`r`n`tDone`r`n$($script:strLineSeparator)`r`n"
logERR 4 "QUERY PSA API" "PSA Opportunity Fields`r`n`t$($script:strLineSeparator)"
$script:psaOpFields = PSA-Query $script:psaHeaders "GET" "Opportunities/entityInformation/fields"
#$script:psaOpFields
$script:OpStages = $script:psaOpFields.fields | where {$_.name -eq 'stage'}
$script:OpStatuses = $script:psaOpFields.fields | where {$_.name -eq 'status'}
write-output "`tStages :`r`n`t$($script:strLineSeparator)`r`n"
write-output "$(($script:OpStages.picklistValues | select Value, Label | out-string).trim())`r`n`t$($script:strLineSeparator)"
$script:diag += "`tStages :`r`n`t$($script:strLineSeparator)`r`n"
$script:diag += "$(($script:OpStages.picklistValues | select Value, Label | out-string).trim())`r`n`t$($script:strLineSeparator)`r`n"
write-output "`tStatuses :`r`n`t$($script:strLineSeparator)`r`n"
write-output "$(($script:OpStatuses.picklistValues | select Value, Label | out-string).trim())`r`n`t$($script:strLineSeparator)"
$script:diag += "`tStatuses :`r`n`t$($script:strLineSeparator)`r`n"
$script:diag += "$(($script:OpStatuses.picklistValues | select Value, Label | out-string).trim())`r`n`t$($script:strLineSeparator)`r`n"
write-output "`tDone`r`n`t$($script:strLineSeparator)`r`n$($script:strLineSeparator)"
$script:diag += "`tDone`r`n`t$($script:strLineSeparator)`r`n$($script:strLineSeparator)`r`n"
logERR 4 "QUERY PSA API" "PSA Opportunities`r`n`t$($script:strLineSeparator)"
$script:psaAllOpps = PSA-FilterQuery $script:psaHeaders "GET" "Opportunities" $psaGenFilter
write-output "`tDone`r`n`t$($script:strLineSeparator)`r`n$($script:strLineSeparator)"
$script:diag += "`tDone`r`n`t$($script:strLineSeparator)`r`n$($script:strLineSeparator)`r`n"
logERR 4 "QUERY PSA API" "PSA Companies`r`n`t$($script:strLineSeparator)"
PSA-GetCompanies $script:psaHeaders
write-output "`tDone`r`n$($script:strLineSeparator)"
$script:diag += "`tDone`r`n$($script:strLineSeparator)`r`n"
#QUERY RMM API
logERR 4 "QUERY RMM API" "RMM Sites`r`n$($script:strLineSeparator)"
$script:rmmToken = RMM-ApiAccessToken
RMM-GetSites
write-output "`tDone`r`n$($script:strLineSeparator)`r`n"
$script:diag += "`tDone`r`n$($script:strLineSeparator)`r`n`r`n"
#OUTPUT
$date = get-date
if (-not $script:blnFAIL) {
  logERR 4 "POCESSING" "PROCESSING COMPANIES :`r`n$($script:strLineSeparator)"
  foreach ($company in $script:CompanyDetails) {
    $blnUpdate = $false
    write-output "$($script:strLineSeparator)"
    write-output "COMPANY : $($company.CompanyName)"
    write-output "ID : $($company.CompanyID)"
    write-output "TYPE : $($script:typeMap[[int]$($company.CompanyType)])"
    write-output "CATEGORY : $($script:categoryMap[[int]$($company.CompanyCategory)])"
    write-output "CLASSIFICATION : $($script:classMap[[int]$($company.CompanyClass)])"
    write-output "$($script:strLineSeparator)"
    $script:diag += "$($script:strLineSeparator)`r`n"
    $script:diag += "ID : $($company.CompanyID)`r`n"
    $script:diag += "TYPE : $($script:typeMap[[int]$($company.CompanyType)])`r`n"
    $script:diag += "COMPANY : $($company.CompanyName)`r`n"
    $script:diag += "CATEGORY : $($script:categoryMap[[int]$($company.CompanyCategory)])`r`n"
    $script:diag += "CLASSIFICATION : $($script:classMap[[int]$($company.CompanyClass)])`r`n"
    $script:diag += "$($script:strLineSeparator)`r`n"
    if ($script:psaSkip -contains "$($script:typeMap[[int]$($company.CompanyType)])") {
      write-output "Skipping : Not Managed`r`n$($script:strLineSeparator)`r`n"
      $script:diag += "Skipping : Not Managed`r`n$($script:strLineSeparator)`r`n`r`n"
    } elseif ($script:psaSkip -notcontains "$($script:typeMap[[int]$($company.CompanyType)])") {
      #GET COMPLETE PSA COMPANY DETAILS
      $script:fullCompany = PSA-Query $script:psaHeaders "GET" "Companies/$($company.companyID)"
      #COLLECT PSA COMPANY OPPORTUNITIES VIA NAMING STANDARD : 'Managed Services'
      $script:psaOpps = $script:psaAllOpps.items | where {(($_.companyID -eq $company.CompanyID) -and 
        (($_.title -match "Managed Services") -or ($_.title -match "Risk Assessment") -or ($_.title -match "Assessment MSA")))}
      $oppStage = ($script:OpStages.picklistValues | where {$_.value -eq $script:psaOpps.stage}).label
      $oppStatus = ($script:OpStatuses.picklistValues | where {$_.value -eq $script:psaOpps.status}).label
      #CHECK PSA OPPORTUNITY PROGRESSION VIA STAUTS / STAGE
      switch ($oppStatus) {
        "Active" {
          switch ($oppStage) {
            {(($_ -eq "New Lead") -or 
              ($_ -eq "Stage 1 First Contact") -or ($_ -eq "Stage 2 Get CSRA Signature"))} {
                if (($script:fullCompany.item.companyType -ne 3) -or 
                  ($script:fullCompany.item.classification -ne 7) -or 
                  ($script:fullCompany.item.companyCategoryID -ne 1)) {
                    write-output "OPPORTUNITY DIAG : $($_) : Update Company"
                    $script:diag += "OPPORTUNITY DIAG : $($_) : Update Company`r`n"
                    $script:fullCompany.item.companyType = 3            #Company Type 'Prospect'
                    $script:fullCompany.item.classification = 7         #Company Classification 'Target'
                    $script:fullCompany.item.companyCategoryID = 1      #Company Category 'Standard'
                    $blnUpdate = $true
                }
            }
            {(($_ -eq "Stage 3 Performing Assessments") -or ($_ -eq "Stage 4 Proposal Sent") -or 
              ($_ -eq "Stage 5 Contract Sent") -or ($_ -eq "On Hold"))} {
                if (($script:fullCompany.item.companyType -ne 1) -or 
                  ($script:fullCompany.item.classification -ne 202) -or 
                  ($script:fullCompany.item.companyCategoryID -ne 101)) {
                    write-output "OPPORTUNITY DIAG : $($_) : Update Company"
                    $script:diag += "OPPORTUNITY DIAG : $($_) : Update Company`r`n"
                    $script:fullCompany.item.companyType = 1            #Company Type 'Customer'
                    $script:fullCompany.item.classification = 202       #Company Classification 'Assessment'
                    $script:fullCompany.item.companyCategoryID = 101    #Company Category 'Assessment'
                    $blnUpdate = $true
                }
            }
          }
        }
        "Closed" {
          switch ($oppStage) {
            {$_ -eq "Stage 5 Closed - Won"} {
              if (($script:fullCompany.item.companyType -ne 1) -or 
                ($script:fullCompany.item.classification -ne 18) -or 
                ($script:fullCompany.item.companyCategoryID -ne 100)) {
                  write-output "OPPORTUNITY DIAG : $($_) : Update Company"
                  $script:diag += "OPPORTUNITY DIAG : $($_) : Update Company`r`n"
                  $script:fullCompany.item.companyType = 1            #Company Type 'Customer'
                  $script:fullCompany.item.classification = 18        #Company Classification 'Managed Services'
                  $script:fullCompany.item.companyCategoryID = 100    #Company Category 'Fully Managed'
                  $blnUpdate = $true
              }
            }
          }
        }
        "Lost" {
          switch ($oppStage) {
            {$_ -eq "Stage 5 Closed - Lost"} {
              if (($script:fullCompany.item.companyType -ne 1) -or 
                ($script:fullCompany.item.classification -ne 18) -or 
                ($script:fullCompany.item.companyCategoryID -ne 100)) {
                  write-output "OPPORTUNITY DIAG : $($_) : Update Company"
                  $script:diag += "OPPORTUNITY DIAG : $($_) : Update Company`r`n"
                  $script:fullCompany.item.companyType = 4            #Company Type 'Dead'
                  $script:fullCompany.item.classification = 204       #Company Classification 'Lost'
                  $script:fullCompany.item.companyCategoryID = 106    #Company Category 'Lost'
                  $blnUpdate = $true
              }
            }
          }
        }
      }
      #UPDATE COMPANY - SHOULD BASE SETS OF ACTIONS DEPENDENT ON CURRENT COMPANY CLASSIFICATION
      if ($blnUpdate) {
        write-output "OPPORTUNITY DIAG : UPDATING : $($company.CompanyName)`r`n$($script:fullCompany.item | convertto-json)`r`n$($script:strLineSeparator)"
        $script:diag += "OPPORTUNITY DIAG : UPDATING : $($company.CompanyName)`r`n$($script:fullCompany.item | convertto-json)`r`n$($script:strLineSeparator)`r`n"
        PSA-Put $script:psaHeaders "PUT" "Companies" ($script:fullCompany.item | convertto-json)
      } elseif (-not ($blnUpdate)) {
        write-output "OPPORTUNITY DIAG : NO NEED TO UPDATE : $($company.CompanyName)`r`n$($script:strLineSeparator)"
        $script:diag += "OPPORTUNITY DIAG : NO NEED TO UPDATE : $($company.CompanyName)`r`n$($script:strLineSeparator)`r`n"
      }
      #CHECK FOR COMPANY IN DRMM SITES
      $rmmSite = $script:sitesList.sites | where-object {$_.name -eq "$($company.CompanyName)"}
      write-output "---------RMM Site :`r`n$($rmmSite)`r`n$($script:strLineSeparator)"
      $script:diag += "---------RMM Site :`r`n$($rmmSite)`r`n$($script:strLineSeparator)`r`n"
      #CREATE SITE IN DRMM
      if (($null -eq $rmmSite) -or ($rmmSite -eq "")) {
        try {
          $script:rmmSites += 1
          $script:blnSITE = $true
          write-output "NEED TO CREATE COMPANY IN RMM"
          $script:diag += "NEED TO CREATE COMPANY IN RMM`r`n"
          logERR 4 "RMM CREATE SITE" "RMM CREATE SITE : $($company.CompanyName)`r`n$($script:strLineSeparator)"
          $params = @{
            id                  = $company.CompanyID
            name                = $company.CompanyName
            description         = "Customer Type : $($script:categoryMap[[int]$($company.CompanyCategory)])\nCreated by API Watchdog\n$($date)"
            notes               = "Customer Type : $($script:categoryMap[[int]$($company.CompanyCategory)])\nCreated by API Watchdog\n$($date)"
            onDemand            = "false"
            installSplashtop    = "true"
          }
          $postSite = (RMM-NewSite @params -UseBasicParsing)
          write-output "$($postSite)`r`n$($script:strLineSeparator)"
          $script:diag += "$($postSite)`r`n$($script:strLineSeparator)`r`n"
          if ($postSite) {
            write-output "RMM CREATE SITE : $($company.CompanyName) : SUCCESS"
            $script:diag += "RMM CREATE SITE : $($company.CompanyName) : SUCCESS`r`n"
          } elseif (-not $postSite) {
            $script:blnWARN = $true
            $script:blnFAIL = $true
            write-output "RMM CREATE SITE : $($company.CompanyName) : FAILED"
            $script:diag += "RMM CREATE SITE : $($company.CompanyName) : FAILED`r`n"
          }
        } catch {
          $script:blnWARN = $true
          $script:blnFAIL = $true
          $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
          logERR 3 "RMM CREATE SITE" "RMM CREATE SITE : $($company.CompanyName) : FAILED :`r`n$($params)`r`n$($strLineSeparator)`r`n$($err)"
        }
      #UPDATE SITE IN DRMM
      } elseif (($null -ne $rmmSite) -and ($rmmSite -ne "")) {
        try {
          write-output "---------Notes :`r`n$($rmmSite.notes)`r`n---------"
          $script:diag += "---------Notes :`r`n$($rmmSite.notes)`r`n---------`r`n"
          write-output "---------Description :`r`n$($rmmSite.description)`r`n---------"
          $script:diag += "---------Description :`r`n$($rmmSite.description)`r`n---------`r`n"
          if ($rmmSite.description -notlike "*Customer Type : $($script:categoryMap[[int]$($company.CompanyCategory)])*") {
            logERR 4 "RMM UPDATE SITE" "RMM UPDATE SITE : $($company.CompanyName)`r`n$($script:strLineSeparator)"
            $note = "$($rmmSite.notes)"
            $params = @{
              rmmID               = $rmmSite.uid
              psaID               = $company.CompanyID
              name                = $company.CompanyName
              description         = "Customer Type : $($script:categoryMap[[int]$($company.CompanyCategory)])\nUpdated by API Watchdog\n$($date)"
              notes               = "$($note)"
              onDemand            = "false"
              installSplashtop    = "true"
            }
            $updateSite = (RMM-UpdateSite @params -UseBasicParsing)
            write-output "$($updateSite)`r`n$($script:strLineSeparator)"
            $script:diag += "$($updateSite)`r`n$($script:strLineSeparator)`r`n"
            if ($updateSite) {
              write-output "UPDATE : $($company.CompanyName) : SUCCESS"
              $script:diag += "UPDATE : $($company.CompanyName) : SUCCESS`r`n"
            } elseif (-not $updateSite) {
              $script:blnWARN = $true
              $script:blnFAIL = $true
              write-output "UPDATE : $($company.CompanyName) : FAILED"
              $script:diag += "UPDATE : $($company.CompanyName) : FAILED`r`n"
            }
          } elseif ($rmmSite.description -like "*Customer Type : $($script:categoryMap[[int]$($company.CompanyCategory)])*") {
            write-output "DO NOT NEED TO CREATE / UPDATE SITE IN RMM`r`n$($script:strLineSeparator)"
            $script:diag += "DO NOT NEED TO CREATE / UPDATE SITE IN RMM`r`n$($script:strLineSeparator)`r`n"
          }
        } catch {
          $script:blnWARN = $true
          $script:blnFAIL = $true
          $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
          logERR 3 "RMM UPDATE SITE" "RMM UPDATE SITE : $($company.CompanyName) : FAILED`r`n$($err)"
        }
      }
      #CHECK FOR COMPANY IN HUDU
      $huduSite = Get-HuduCompanies -Name "$($company.CompanyName)"
      #CREATE COMPANY IN HUDU
      if (($null -eq $huduSite) -or ($huduSite -eq "")) {
        try {
          $script:huduSites += 1
          $script:blnSITE = $true
          write-output "NEED TO CREATE COMPANY IN HUDU"
          $script:diag += "NEED TO CREATE COMPANY IN HUDU`r`n"
          $country = $countries.items | where {($_.id -eq $company.countryID)} | select displayName
          $huduInfo = "$($company.address1), $($company.address2), $($company.city), $($company.state), $($company.postalCode) $($company.country)"
          logERR 4 "HUDU CREATE COMPANY" "HUDU CREATE COMPANY : $($company.CompanyName) :`r`n`t$($huduInfo)`r`n$($strLineSeparator)"
          $params = @{
            name                = "$($company.CompanyName)"
            company_type        = "$($script:categoryMap[[int]$($company.CompanyCategory)])"
            nickname            = ""
            address_line_1      = "$($company.address1)"
            address_line_2      = "$($company.address2)"
            city                = "$($company.city)"
            state               = "$($company.state)"
            zip                 = "$($company.postalCode)"
            country_name        = "$($country.displayName)"
            phone_number        = "$($company.phone)"
            fax_number          = "$($company.fax)"
            website             = "$($company.webAddress)"
            id_number           = ""
            notes               = "Customer Type : $($script:categoryMap[[int]$($company.CompanyCategory)])`r`nCreated by API Watchdog`r`n$($date)"
          }
          $postHUDU = (New-HuduCompany @params -erroraction stop)
          write-output "$($postHUDU)`r`n$($script:strLineSeparator)"
          $script:diag += "$($postHUDU)`r`n$($script:strLineSeparator)`r`n"
          if ($postHUDU) {
            write-output "HUDU CREATE COMPANY : $($company.CompanyName) : SUCCESS`r`n"
            $script:diag += "HUDU CREATE COMPANY : $($company.CompanyName) : SUCCESS`r`n`r`n"
          } elseif (-not $postHUDU) {
            $script:blnWARN = $true
            $script:blnFAIL = $true
            write-output "HUDU CREATE COMPANY : $($company.CompanyName) : FAILED`r`n"
            $script:diag += "HUDU CREATE COMPANY : $($company.CompanyName) : FAILED`r`n`r`n"
          }
        } catch {
          $script:blnWARN = $true
          $script:blnFAIL = $true
          $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
          logERR 3 "HUDU CREATE COMPANY" "HUDU CREATE COMPANY : $($company.CompanyName) : FAILED`r`n$($err)"
        }
      } elseif (($null -ne $huduSite) -and ($huduSite -ne "")) {
        write-output "DO NOT NEED TO CREATE COMPANY IN HUDU`r`n$($script:strLineSeparator)`r`n"
        $script:diag += "DO NOT NEED TO CREATE COMPANY IN HUDU`r`n$($script:strLineSeparator)`r`n`r`n"
      }
    }
  }
  #Stop script execution time calculation
  StopClock
  #CLEAR LOGFILE
  $null | set-content $script:logPath -force
  if ($script:blnFAIL) {
    #WRITE TO LOGFILE
    logERR 3 "END" "Execution Failure : See Diagnostics : $($script:finish)`r`n$($script:strLineSeparator)"
    "$($script:diag)" | add-content $script:logPath -force
    write-DRMMAlert "API_WatchDog : Execution Failure : See Diagnostics : $($script:finish)"
    write-DRMMDiag "$($script:diag)"
    $script:diag = $null
  }
  if ($script:blnSITE) {
    #WRITE TO LOGFILE
    logERR 3 "END" "Execution Successful : Site(s) Created - See Diagnostics : $($script:finish)`r`n$($script:strLineSeparator)"
    "$($script:diag)" | add-content $script:logPath -force
    write-DRMMAlert "API_WatchDog : Execution Successful : Site(s) Created - See Diagnostics : $($script:finish)"
    write-DRMMDiag "$($script:diag)"
    $script:diag = $null
  }
  if (-not $script:blnWARN) {
    #WRITE TO LOGFILE
    logERR 4 "END" "Execution Successful : No Sites Created : $($script:finish)`r`n$($script:strLineSeparator)"
    "$($script:diag)" | add-content $script:logPath -force
    write-DRMMAlert "API_WatchDog : Execution Successful : No Sites Created : $($script:finish)"
    write-DRMMDiag "$($script:diag)"
    $script:diag = $null
  } elseif ($script:blnWARN) {
    #WRITE TO LOGFILE
    logERR 3 "END" "Execution Completed with Warnings : See Diagnostics : $($script:finish)`r`n$($script:strLineSeparator)"
    "$($script:diag)" | add-content $script:logPath -force
    write-DRMMAlert "API_WatchDog : Execution Completed with Warnings : See Diagnostics : $($script:finish)"
    write-DRMMDiag "$($script:diag)"
    $script:diag = $null
  }
  if ((-not ($script:blnFAIL)) -and (-not ($script:blnWARN)) -and (-not ($script:blnSITE))) {exit 0}
  if (($script:blnFAIL) -or ($script:blnWARN) -or ($script:blnSITE)) {exit 1}
} elseif ($script:blnFAIL) {
  #Stop script execution time calculation
  StopClock
  #CLEAR LOGFILE
  $null | set-content $script:logPath -force
  #WRITE TO LOGFILE
  logERR 3 "END" "API_WatchDog : Execution Failure : See Diagnostics : $($script:finish)`r`n$($script:strLineSeparator)"
  "$($script:diag)" | add-content $script:logPath -force
  write-DRMMAlert "API_WatchDog : Execution Failure : See Diagnostics : $($script:finish)"
  write-DRMMDiag "$($script:diag)"
  $script:diag = $null
  exit 1
}
#END SCRIPT
#------------