#REGION ----- DECLARATIONS ----
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
  #  [Parameter(Mandatory=$true)]$i_psaAPI
  #)
  $script:diag              = $null
  $script:blnFAIL           = $false
  $script:blnWARN           = $false
  $script:blnSITE           = $false
  $script:strLineSeparator  = "---------"
  # Specify security protocols
  #[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType] 'Tls12'
  [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls -bor [System.Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls12
  #PSA API DATASETS
  $script:typeMap           = @{
    1 = "Customer"
    2 = "Lead"
    3 = "Prospect"
    4 = "Dead"
    6 = "Cancelation"
    7 = "Vendor"
    8 = "Partner"
  }
  $script:classMap          = @{}
  $script:categoryMap       = @{}
  #RMM API CREDS
  $script:rmmKey            = $env:i_rmmKey
  $script:rmmSecret         = $env:i_rmmSecret
  #RMM API VARS
  $script:rmmSites          = 0
  $script:rmmCalls          = 0
  $script:rmmUDF            = $env:i_rmmUDF
  $script:rmmAPI            = $env:i_rmmAPI
  #PSA API CREDS
  $script:psaUser           = $env:i_psaUser
  $script:psaKey            = $env:i_psaKey
  $script:psaSecret         = $env:i_psaSecret
  $script:psaIntegration    = $env:i_psaIntegration
  #PSA API VARS
  $script:psaCalls          = 0
  $script:psaAPI            = $env:i_psaAPI
  $script:psaGenFilter      = '{"Filter":[{"field":"Id","op":"gte","value":0}]}'
  $script:psaActFilter      = '{"Filter":[{"op":"and","items":[{"field":"IsActive","op":"eq","value":true},{"field":"Id","op":"gte","value":0}]}]}'
#ENDREGION ----- DECLARATIONS ----

#REGION ----- FUNCTIONS ----
  function write-DRMMDiag ($messages) {
    write-host  "<-Start Diagnostic->"
    foreach ($message in $messages) {$message}
    write-host "<-End Diagnostic->"
  } ## write-DRMMDiag
  
  function write-DRRMAlert ($message) {
    write-host "<-Start Result->"
    write-host "Alert=$($message)"
    write-host "<-End Result->"
  } ## write-DRRMAlert

  function Get-EpochDate ($epochDate, $opt) {                                                       #Convert Epoch Date Timestamps to Local Time
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

  function PSA-Query {
    param ($method, $entity)
    $params = @{
      Method      = "$($method)"
      ContentType = 'application/json'
      Uri         = "$($script:psaAPI)/$($entity)"
      Headers     = @{
        'Username'            = $script:psaKey
        'Secret'              = $script:psaSecret
        'APIIntegrationcode'  = $script:psaIntegration
      }
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
      write-host "$($script:diag)`r`n"
    }
  }

  function PSA-FilterQuery {
    param ($method, $entity, $filter)
    $params = @{
      Method      = "$($method)"
      ContentType = 'application/json'
      Uri         = "$($script:psaAPI)/$($entity)/query?search=$($filter)"
      Headers     = @{
        'Username'            = $script:psaKey
        'Secret'              = $script:psaSecret
        'APIIntegrationcode'  = $script:psaIntegration
      }
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
      write-host "$($script:diag)`r`n"
    }
  }

  function PSA-GetThreshold {
    try {
      PSA-Query "GET" "ThresholdInformation"
    } catch {
      $script:blnWARN = $true
      $script:diag += "`r`nAPI_WatchDog : Failed to populate PSA API Utilization via $($params.Uri)"
      $script:diag += "`r`n$($_.Exception)"
      $script:diag += "`r`n$($_.scriptstacktrace)"
      $script:diag += "`r`n$($_)"
      write-host "$($script:diag)`r`n"
    }
  }

  function PSA-GetMaps {
    param ($dest, $entity)
    $Uri = "$($script:psaAPI)/$($entity)/query?search=$($script:psaActFilter)"
    try {
      $list = PSA-FilterQuery "GET" "$($entity)" "$($script:psaActFilter)"
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
      write-host "$($script:diag)`r`n"
    }
  } ## PSA-GetMaps

  function PSA-GetCompanies {
    $script:CompanyDetails = @()
    $Uri = "$($script:psaAPI)/Companies/query?search=$($script:psaActFilter)"
    try {
      $CompanyList = PSA-FilterQuery "GET" "Companies" "$($script:psaActFilter)"
      $sort = ($CompanyList.items | Sort-Object -Property companyName)
      foreach ($company in $sort) {
        $script:CompanyDetails += New-Object -TypeName PSObject -Property @{
          CompanyID       = $company.id
          CompanyName     = $company.companyName
          CompanyType     = $company.companyType
          CompanyClass    = $company.classification
          CompanyCategory = $company.companyCategoryID
        }
        #write-host "$($company.companyName) : $($company.companyType)"
        #write-host "Type Map : $(script:typeMap[[int]$company.companyType])"
      }
    } catch {
      $script:blnFAIL = $true
      $script:diag += "`r`nAPI_WatchDog : Failed to populate PSA Companies via $($Uri)"
      $script:diag += "`r`n$($_.Exception)"
      $script:diag += "`r`n$($_.scriptstacktrace)"
      $script:diag += "`r`n$($_)"
      write-host "$($script:diag)`r`n"
    }
  } ## PSA-GetCompanies API Call

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
      write-host "$($script:diag)`r`n"
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
      write-host "$($script:diag)`r`n"
    }
  }

  function RMM-PostUDF {
    param (
      [string]$deviceUID,
      [string]$companyType
    )
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
      write-host "$($script:diag)`r`n"
    }
  }

  function RMM-GetDevices {
    param (
      [string]$siteUID
    )
    $params = @{
      apiMethod       = "GET"
      apiUrl          = $script:rmmAPI
      ApiAccessToken  = $script:rmmToken
      apiRequest      = "/v2/site/$($siteUID)/devices"
      apiRequestBody  = $null
    }
    $script:DeviceDetails = @()
    try {
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
      $script:diag += "`r`nAPI_WatchDog : Failed to populate DRMM Devices via $($params.apiUrl)$($params.apiRequest)"
      $script:diag += "`r`n$($_.Exception)"
      $script:diag += "`r`n$($_.scriptstacktrace)"
      $script:diag += "`r`n$($_)"
      write-host "$($script:diag)`r`n"
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
    } catch {
      $script:blnFAIL = $true
      $script:diag += "`r`nAPI_WatchDog : Failed to populate DRMM Sites via $($params.apiUrl)$($params.apiRequest)"
      $script:diag += "`r`n$($_.Exception)"
      $script:diag += "`r`n$($_.scriptstacktrace)"
      $script:diag += "`r`n$($_)"
      write-host "$($script:diag)`r`n"
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
      write-host "$($script:diag)`r`n"
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
      apiRequestBody  = "{`"autotaskCompanyId`": `"$($id)`",`"autotaskCompanyName`": `"$($name)`",`"description`": `"$($description)`",`"name`": `"$($name)`",`"notes`": `"$($notes)`",`"onDemand`": $onDemand,`"splashtopAutoInstall`": $installSplashtop}"
    }
    $script:blnSITE = $false
    try {
      $script:newSite = (RMM-ApiRequest @params -UseBasicParsing) #| ConvertFrom-Json
      if ($script:newSite -match $name) {
        return $true
      } elseif ($script:newSite -match $name) {
        return $false
      }
    } catch {
      $script:blnWARN = $true
      $script:blnSITE = $false
      $script:diag += "`r`nAPI_WatchDog : Failed to create New DRMM Site via $($params.apiUrl)$($params.apiRequest)`r`n$($params.apiRequestBody)"
      $script:diag += "`r`n$($_.Exception)"
      $script:diag += "`r`n$($_.scriptstacktrace)"
      $script:diag += "`r`n$($_)"
      write-host "$($script:diag)`r`n"
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
    $average = ($total / ($script:psaCalls + $script:rmmCalls))
    $secs = [string]($total / 1000)
    $mill = $secs.split(".")[1]
    $secs = $secs.split(".")[0]
    $mill = $mill.SubString(0,[math]::min(3,$mill.length))
    $asecs = [string]($average / 1000)
    $amill = $asecs.split(".")[1]
    $asecs = $asecs.split(".")[0]
    $amill = $amill.SubString(0,[math]::min(3,$mill.length))
    #DISPLAY API THRESHOLDS
    $psa = PSA-GetThreshold
    write-host "`r`nAPI Calls :`r`nPSA API : $($script:psaCalls) - RMM API : $($script:rmmCalls)"
    write-host "API Limits - PSA API (per Hour) : $($psa.currentTimeframeRequestCount) / $($psa.externalRequestThreshold) - RMM API (per Minute) : $($script:rmmCalls) / 600"
    write-host "Total Execution Time - $($Minutes) Minutes : $($secs) Seconds : $($mill) Milliseconds`r`n"
    $script:diag += "`r`nAPI Calls :`r`nPSA API : $($script:psaCalls) - RMM API : $($script:rmmCalls)`r`n"
    $script:diag += "API Limits :`r`nPSA API (per Hour) : $($psa.currentTimeframeRequestCount) / $($psa.externalRequestThreshold) - RMM API (per Minute) : $($script:rmmCalls) / 600`r`n"
    $script:diag += "Total Execution Time - $($Minutes) Minutes : $($secs) Seconds : $($mill) Milliseconds`r`n"
    if ($Minutes -eq 0) {
      write-host "Average Execution Time (Per API Call) - $($Minutes) Minutes : $($asecs) Seconds : $($amill) Milliseconds"
      $script:diag += "Average Execution Time (Per API Call) - $($Minutes) Minutes : $($asecs) Seconds : $($amill) Milliseconds`r`n"
    } elseif ($Minutes -gt 0) {
      $amin = [string]($asecs / 60)
      $amin = $amin.split(".")[0]
      $amin = $amin.SubString(0,[math]::min(2,$amin.length))
      write-host "Average Execution Time (Per API Call) - $($amin) Minutes : $($asecs) Seconds : $($amill) Milliseconds`r`n"
      $script:diag += "Average Execution Time (Per API Call) - $($amin) Minutes : $($asecs) Seconds : $($amill) Milliseconds`r`n`r`n"
    }
  }
#ENDREGION ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
#Start script execution time calculation
$ScrptStartTime = (Get-Date).ToString('dd-MM-yyyy hh:mm:ss')
$script:sw = [Diagnostics.Stopwatch]::StartNew()
#QUERY PSA API
PSA-GetMaps $script:classMap "ClassificationIcons"
PSA-GetMaps $script:categoryMap "CompanyCategories"
PSA-GetCompanies
#QUERY RMM API
$script:rmmToken = RMM-ApiAccessToken
RMM-GetSites
#OUTPUT
if (-not $script:blnFAIL) {
  write-host "`r`n$($script:strLineSeparator)"
  write-host "COMPANIES :"
  write-host "$($script:strLineSeparator)"
  $script:diag += "`r`n`r`n$($script:strLineSeparator)`r`n"
  $script:diag += "COMPANIES :`r`n"
  $script:diag += "$($script:strLineSeparator)`r`n"
  foreach ($company in $script:CompanyDetails) {
    write-host "`r`n$($script:strLineSeparator)"
    write-host "COMPANY : $($company.CompanyName)"
    write-host "COMPANY TYPE : $($script:typeMap[[int]$($company.CompanyType)])"
    write-host "$($script:strLineSeparator)"
    $script:diag += "`r`n$($script:strLineSeparator)`r`n"
    $script:diag += "ID : $($company.CompanyID)`r`n"
    $script:diag += "TYPE : $($script:typeMap[[int]$($company.CompanyType)])`r`n"
    $script:diag += "COMPANY : $($company.CompanyName)`r`n"
    $script:diag += "CATEGORY : $($script:categoryMap[$($company.CompanyCategory)])`r`n"
    $script:diag += "CLASSIFICATION : $($script:classMap[$($company.CompanyClass)])`r`n"
    $script:diag += "$($script:strLineSeparator)`r`n"
    if (($($script:typeMap[[int]$($company.CompanyType)]) -ne "Dead") -and 
      ($($script:typeMap[[int]$($company.CompanyType)]) -ne "Vendor") -and
      ($($script:typeMap[[int]$($company.CompanyType)]) -ne "Partner") -and
      ($($script:typeMap[[int]$($company.CompanyType)]) -ne "Lead")) {
        $rmmSite = $script:sitesList.sites | where-object {$_.name -eq "$($company.CompanyName)"}
        write-host "$($rmmSite)"
        write-host "$($script:strLineSeparator)"
        $script:diag += "$($rmmSite)`r`n"
        $script:diag += "$($script:strLineSeparator)`r`n"
        if (($null -eq $rmmSite) -or ($rmmsite -eq "")) {
          $script:rmmSites += 1
          $script:blnSITE = $true
          $script:diag += "CREATE SITE : $($company.CompanyName)`r`n"
          $params = @{
            id                  = $company.CompanyID
            name                = $company.CompanyName
            description         = "Customer Type : $($script:categoryMap[$($company.CompanyCategory)])\nCreated by API Watchdog"
            notes               = "Customer Type : $($script:categoryMap[$($company.CompanyCategory)])\nCreated by API Watchdog"
            onDemand            = "false"
            installSplashtop    = "true"
          }
          $postSite = (RMM-NewSite @params -UseBasicParsing)
          write-host "$($postSite)"
          write-host "$($script:strLineSeparator)"
          $script:diag += "$($postSite)`r`n"
          $script:diag += "$($script:strLineSeparator)`r`n"
          if ($postSite) {
            write-host "CREATE : $($company.CompanyName) : SUCCESS" -foregroundcolor green
            $script:diag += "`r`nCREATE : $($company.CompanyName) : SUCCESS" #-foregroundcolor green
          } elseif (-not $postSite) {
            $script:blnWARN = $true
            write-host "CREATE : $($company.CompanyName) : FAILED" -foregroundcolor red
            $script:diag += "`r`nCREATE : $($company.CompanyName) : FAILED" #-foregroundcolor red
          }
        } elseif (($null -ne $rmmSite) -and ($rmmsite -ne "")) {
          try {
            if ($rmmSite.description -notmatch "Customer Type : $($script:categoryMap[$($company.CompanyCategory)])`r`n") {
              $script:diag += "UPDATE SITE : $($company.CompanyName)`r`n"
              $params = @{
                rmmID               = $rmmSite.uid
                psaID               = $company.CompanyID
                name                = $company.CompanyName
                description         = "Customer Type : $($script:categoryMap[$($company.CompanyCategory)])\n$($rmmSite.description)"
                #notes               = "Customer Type : $($script:categoryMap[$($company.CompanyCategory)])\n$($rmmSite.description)"
                onDemand            = "false"
                installSplashtop    = "true"
              }
              $updateSite = (RMM-UpdateSite @params -UseBasicParsing)
              write-host "$($updateSite)"
              write-host "$($script:strLineSeparator)"
              $script:diag += "$($postSite)`r`n"
              $script:diag += "$($script:strLineSeparator)`r`n"
            }
            <#--  DISABLED TO SWITCH TO INSERTING CUSTOMER TYPE INTO SITE DESCRIPTION TO OPTIMIZE RMM API CALLS
            RMM-GetDevices $rmmSite.uid
            write-host "$($script:strLineSeparator)"
            write-host "DEVICES :"
            write-host "$($script:strLineSeparator)"
            $script:diag += "$($script:strLineSeparator)`r`n"
            $script:diag += "DEVICES :`r`n"
            $script:diag += "$($script:strLineSeparator)`r`n"
            foreach ($device in $script:DeviceDetails) {
              write-host "DEVICE : $($device.hostname)"
              write-host "DEVICE UDF : $($device.UDF)"
              $script:diag += "DEVICE : $($device.hostname)`r`n"
              $script:diag += "DEVICE UDF : $($device.UDF)`r`n"
              if (($null -eq $device.UDF) -or 
                ($device.UDF -eq "") -or 
                ($device.UDF -ne $($script:categoryMap[$($company.CompanyCategory)]))) {
                  $script:diag += "Device : $($device.hostname)`r`n"
                  $script:diag += "Device $($script:rmmUDF) : $($device.UDF)`r`n"
                  $script:diag += "Customer Type : $($script:categoryMap[$($company.CompanyCategory)])`r`n"
                  $script:diag += "UPDATING $($script:rmmUDF) ON DEVICE : $($device.hostname)`r`n"
                  write-host "UPDATING $($script:rmmUDF) ON DEVICE : $($device.hostname)"
                  RMM-PostUDF $device.DeviceUID $($script:categoryMap[$($company.CompanyCategory)])
              }
              write-host "$($script:strLineSeparator)"
              $script:diag += "$($script:strLineSeparator)`r`n"
            }
            --#>
          } catch {
            $script:diag += "`r`n$($_.Exception)"
            $script:diag += "`r`n$($_.scriptstacktrace)"
            $script:diag += "`r`n$($_)"
          }
        }
    }
  }
  #Stop script execution time calculation
  StopClock
  if ($script:blnSITE) {
    write-DRRMAlert "API_WatchDog : Execution Successful : Site(s) Created - See Diagnostics"
    write-DRMMDiag "$($script:diag)"
    $script:diag = $null
    exit 1
  }
  if (-not $script:blnWARN) {
    write-DRRMAlert "API_WatchDog : Execution Successful"
    write-DRMMDiag "$($script:diag)"
    $script:diag = $null
    exit 0
  } elseif ($script:blnWARN) {
    write-DRRMAlert "API_WatchDog : Execution Completed with Warnings : See Diagnostics"
    write-DRMMDiag "$($script:diag)"
    $script:diag = $null
    exit 1
  }
} elseif ($script:blnFAIL) {
  #Stop script execution time calculation
  StopClock
  write-DRRMAlert "API_WatchDog : Execution Failure : See Diagnostics"
  write-DRMMDiag "$($script:diag)"
  $script:diag = $null
  exit 1
}
#END SCRIPT
#------------