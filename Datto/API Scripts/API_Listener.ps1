#region ----- DECLARATIONS ----
  $script:diag              = $null
  $script:finish            = $null
  $script:blnFAIL           = $false
  $script:blnWARN           = $false
  $script:statusCode        = 200
  $script:apiSecret         = 12345
  $VerbosePreference        = 'Continue'
  $script:strLineSeparator  = "---------"
  $script:logPath           = "C:\IT\Log\API_Listener"
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
#region ----- RMM FUNCTIONS ----
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

  function RMM-ApiAccessToken {
    # Convert password to secure string
    $securePassword = ConvertTo-SecureString -String 'public' -AsPlainText -Force
    # Define parameters
    $params = @{
      Method      = 'POST'
      ContentType = 'application/x-www-form-urlencoded'
      Uri         = "$($script:rmmAPI)/auth/oauth/token"
      Body        = "grant_type=password&username=$($script:rmmKey)&password=$($script:rmmSecret)"
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
      Uri           = "$($script:rmmAPI)/api$($apiRequest)"
      Headers       = @{'Authorization'	= "Bearer $($apiAccessToken)"}
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
      write-verbose "$($params.apiUrl) - $($params.ApiAccessToken)"
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

  function RMM-Call ($apiRequest) {
    write-verbose "$($apiRequest)"
    $apiRequest = $apiRequest | convertfrom-json
    switch ($apiRequest.apiMethod) {
      {($_ -eq "Get-Devices")} {
        RMM-GetDevices $apiRequest.SiteUID
        logERR 4 "QUERY RMM API" "RMM Devices`r`n$($script:strLineSeparator)`r`n$($script:DeviceDetails | ft | out-string)"
      }
      {($_ -eq "Get-Sites")} {
        RMM-GetSites
        logERR 4 "QUERY RMM API" "RMM Sites`r`n$($script:strLineSeparator)`r`n$($script:sitesList | ft | out-string)"
      }
    }
  }
#endregion ----- RMM FUNCTIONS ----
  function AV-Call ($apiRequest) {
    write-verbose "$($apiRequest)"
    $apiRequest = $apiRequest | convertfrom-json
    switch ($apiRequest.apiMethod) {
      {($_ -eq "BDGZ")} {
        RMM-GetDevices $apiRequest.SiteUID
        logERR 4 "QUERY RMM API" "RMM Devices`r`n$($script:strLineSeparator)`r`n$($script:DeviceDetails | ft | out-string)"
      }
      {($_ -eq "SOPHOS")} {
        RMM-GetSites
        logERR 4 "QUERY RMM API" "RMM Sites`r`n$($script:strLineSeparator)`r`n$($script:sitesList | ft | out-string)"
      }
    }
  }

  function Backup-Call ($apiRequest) {
    write-verbose "$($apiRequest)"
    $apiRequest = $apiRequest | convertfrom-json
    switch ($apiRequest.apiMethod) {
      {($_ -eq "Get-Devices")} {
        RMM-GetDevices $apiRequest.SiteUID
        logERR 4 "QUERY RMM API" "RMM Devices`r`n$($script:strLineSeparator)`r`n$($script:DeviceDetails | ft | out-string)"
      }
      {($_ -eq "Set-GUIPWD")} {
        RMM-GetSites
        logERR 4 "QUERY RMM API" "RMM Sites`r`n$($script:strLineSeparator)`r`n$($script:sitesList | ft | out-string)"
      }
      {($_ -eq "Wipe-GUIPWD")} {
        RMM-GetSites
        logERR 4 "QUERY RMM API" "RMM Sites`r`n$($script:strLineSeparator)`r`n$($script:sitesList | ft | out-string)"
      }
    }
  }

  function Docs-Call ($apiRequest) {
    write-verbose $apiRequest
    $apiRequest = $apiRequest | convertfrom-json
    switch ($apiRequest.apiMethod) {
      {($_ -eq "Set-FileShare")} {
        RMM-GetDevices $apiRequest.SiteUID
        logERR 4 "QUERY RMM API" "RMM Devices`r`n$($script:strLineSeparator)`r`n$($script:DeviceDetails | ft | out-string)"
      }
      {($_ -eq "Set-PWD")} {
        RMM-GetSites
        logERR 4 "QUERY RMM API" "RMM Sites`r`n$($script:strLineSeparator)`r`n$($script:sitesList | ft | out-string)"
      }
      {($_ -eq "Wipe-GUIPWD")} {
        RMM-GetSites
        logERR 4 "QUERY RMM API" "RMM Sites`r`n$($script:strLineSeparator)`r`n$($script:sitesList | ft | out-string)"
      }
    }
  }

  function PSA-Call ($apiRequest) {
    write-verbose $apiRequest
    $apiRequest = $apiRequest | convertfrom-json
    switch ($apiRequest.apiMethod) {
      {($_ -eq "PSA-GetAssets")} {
        RMM-GetDevices $apiRequest.SiteUID
        logERR 4 "QUERY RMM API" "RMM Devices`r`n$($script:strLineSeparator)`r`n$($script:DeviceDetails | ft | out-string)"
      }
      {($_ -eq "PSA-GetCompanies")} {
        RMM-GetSites
        logERR 4 "QUERY RMM API" "RMM Sites`r`n$($script:strLineSeparator)`r`n$($script:sitesList | ft | out-string)"
      }
      {($_ -eq "PSA-GetTickets")} {
        RMM-GetSites
        logERR 4 "QUERY RMM API" "RMM Sites`r`n$($script:strLineSeparator)`r`n$($script:sitesList | ft | out-string)"
      }
    }
  }

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
        $script:diag += "`r`n$($script:strLineSeparator)`r`n$($(get-date))`t - API_Listener - NO ARGUMENTS PASSED, END SCRIPT`r`n`r`n"
        write-output "$($script:strLineSeparator)`r`n$($(get-date))`t - API_Listener - NO ARGUMENTS PASSED, END SCRIPT`r`n"
      }
      #'ERRRET'=2 - INSTALL / IMPORT MODULE FAILURE, END SCRIPT
      2 {
        $script:blnBREAK = $true
        $script:diag += "`r`n$($script:strLineSeparator)`r`n$($(get-date))`t - API_Listener - ($($strModule)) :"
        $script:diag += "`r`n$($script:strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n"
        write-output "$($script:strLineSeparator)`r`n$($(get-date))`t - API_Listener - ($($strModule)) :"
        write-output "$($script:strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n"
      }
      #'ERRRET'=3 - ERROR / WARNING
      3 {
        $script:blnWARN = $true
        $script:diag += "`r`n$($script:strLineSeparator)`r`n$($(get-date))`t - API_Listener - $($strModule) :"
        $script:diag += "`r`n$($script:strLineSeparator)`r`n`t$($strErr)"
        write-output "$($script:strLineSeparator)`r`n$($(get-date))`t - API_Listener - $($strModule) :"
        write-output "$($sscript:trLineSeparator)`r`n`t$($strErr)"
      }
      #'ERRRET'=4 - INFORMATIONAL
      4 {
        $script:diag += "`r`n$($script:strLineSeparator)`r`n$($(get-date))`t - API_Listener - $($strModule) :"
        $script:diag += "`r`n$($script:strLineSeparator)`r`n`t$($strErr)"
        write-output "$($script:strLineSeparator)`r`n$($(get-date))`t - API_Listener - $($strModule) :"
        write-output "$($script:strLineSeparator)`r`n`t$($strErr)"
      }
      #'ERRRET'=5+ - DEBUG
      default {
        $script:blnWARN = $false
        $script:diag += "`r`n$($script:strLineSeparator)`r`n$($(get-date))`t - API_Listener - $($strModule) :"
        $script:diag += "`r`n$($script:strLineSeparator)`r`n`t$($strErr)"
        write-output "$($script:strLineSeparator)`r`n$($(get-date))`t - API_Listener - $($strModule) :"
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
#Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
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
#Set-PSRepository -Name 'PSGallery' -InstallationPolicy Untrusted

#Retrieve / Create Listener ID and Certificate
$strId = $null
try {
  $apiId = get-itempropertyvalue -path "HKLM:\SOFTWARE\CentraStage" -name "apiId"
  $strId = "apiId : $($apiId) (REG)1"
} catch {
  $apiId = (get-item -path "HKLM:\SOFTWARE\CentraStage").getvalue("apiId")
  $strId = "apiId : $($apiId) (REG)2"
}
if (-not ($apiId)) {
  $apiId = [System.Guid]::NewGuid()
  new-itemproperty "HKLM:\SOFTWARE\CentraStage" -name "apiId" -propertytype string -value "$($apiId.guid)" -force
  $apiId = $apiId.guid
  $strId = "apiId : $($apiId) (GEN)"
}
$strReg = $null
try {
  $apiReg = get-itempropertyvalue -path "HKLM:\SOFTWARE\CentraStage" -name "apiReg"
  $strReg = "apiReg : $($apiReg) (REG)1"
} catch {
  $apiReg = (get-item -path "HKLM:\SOFTWARE\CentraStage").getvalue("apiReg")
  $strReg = "apiReg : $($apiReg) (REG)2"
}
if (-not ($apiReg)) {
  $apiReg = ls Cert:\LocalMachine\my | where {$_.EnhancedKeyUsageList -Match 'Server' -and $_.subject -match (hostname)} | select -last 1
  if (-not ($apiReg)) {$apiReg = new-selfsignedcertificate -DnsName localhost -CertStoreLocation cert:\LocalMachine\My -NotAfter (get-date).AddYears(10)}
  new-itemproperty "HKLM:\SOFTWARE\CentraStage" -name "apiReg" -propertytype string -value "$($apiReg.thumbprint)" -force
  $apiReg = $apiReg.thumbprint
  $strReg = "apiReg : $($apiReg) (CERT)"
}
#Setup Listener for HTTPS and Allow in Firewall
write-verbose "`r`n$($strId)`r`n$($strReg)`r`n"
netsh http add sslcert ipport=0.0.0.0:8443 certhash=$($apiReg) appid=`{$($apiId)`}
netsh advfirewall firewall add rule name="TEMP_API_LISTENER" protocol=TCP dir=in localport=8443 action=allow
#Set Hudu logon information
New-HuduAPIKey $script:HuduAPIKey
New-HuduBaseUrl $script:HuduBaseDomain
<#
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
#>
#QUERY RMM API
logERR 4 "QUERY RMM API" "RMM Sites`r`n$($script:strLineSeparator)"
$script:rmmToken = RMM-ApiAccessToken
RMM-GetSites
write-output "`tDone`r`n$($script:strLineSeparator)`r`n"
$script:diag += "`tDone`r`n$($script:strLineSeparator)`r`n`r`n"
#OUTPUT
$date = get-date
#if (-not $script:blnFAIL) {
  try {
    #$apiListener.dispose()
    $apiListener = New-Object System.Net.HttpListener
    #$apiListener.Prefixes.Add("http://+:80/")
    $apiListener.Prefixes.Add("https://+:8443/")
    $apiListener.Start()
    $FQDN = [System.Net.Dns]::GetHostByName((hostname)).HostName
    while ($apiListener.IsListening) {
      $apiRequest = $null
      $script:statusCode = 200
      $script:blnProcReq = $false
      Write-Warning "Note that thread is blocked waiting for a request. After using Ctrl-C to stop listening, you need to send a valid HTTP request to stop the listener cleanly."
      Write-Warning "Sending 'exit' command will cause listener to stop immediately"
      Write-Verbose "Listening on $($port)..."
      $context = $apiListener.GetContext()
      <#$request = @{
        Url
        Method        = 'POST'
        ContentType   = 'application/json'
        Headers       = @{apiSecret = $env:apiSecret; requestGUID = $env:CS_PROFILE_UID}
        Body          = @{apiEndpoint = ; apiMethod =}
      }#>
      $request = $context.request
      #write-verbose $request.Headers['apiSecret']
      switch ($request.Headers['apiSecret']) {
        {($_ -ne $script:apiSecret)} {
          $script:statusCode = 403
          Write-Verbose "Response:Request Rejected: Not Authorized"
          break
        }
        {($_ -eq $script:apiSecret)} {
          $script:statusCode = 202
          Write-Verbose "Response:Request Accepted: L1 Authorized"
          switch ($request.Headers['requestGUID']) {
            {($script:sitesList.sites.uid -notmatch $_)} {
              $script:statusCode = 403
              $script:blnProcReq = $false
              Write-Verbose "Response:Request Rejected: Not Authorized"
              break
            }
            {($script:sitesList.sites.uid -match $_)} {
              $script:statusCode = 202
              $script:blnProcReq = $true
              Write-Verbose "Response:Request Accepted: L2 Authorized"
              if ($request.HasEntityBody) {
                $sr = new-object System.IO.StreamReader($request.InputStream)
                $apiBody = $sr.ReadToEnd()
                $apiRequest += "$($apiBody)`r`n"
              }
              $apiRequest += $($request | fl | out-string)
              if (!$apiRequest) {$apiRequest = [string]::Empty}
              Write-Verbose "Request:`r`n$($apiRequest)"
              switch ($request.Url) {
                {($request.Url -match '/av/')} {Write-Verbose "Response:Test Received`r`n$($script:strLineSeparator)"; AV-Call $apiBody; break}
                {($request.Url -match '/backup/')} {Write-Verbose "Response:Test Received`r`n$($script:strLineSeparator)"; Backup-Call $apiBody; break}
                {($request.Url -match '/docs/')} {Write-Verbose "Response:Test Received`r`n$($script:strLineSeparator)"; Docs-Call $apiBody; break}
                {($request.Url -match '/psa/')} {Write-Verbose "Response:Test Received`r`n$($script:strLineSeparator)"; PSA-Call $apiBody; break}
                {($request.Url -match '/rmm/')} {Write-Verbose "Response:Test Received`r`n$($script:strLineSeparator)"; RMM-Call $apiBody; break}
                {($request.Url -match '/termkill/')} {Write-Verbose "Response:Terminate Received`r`n$($script:strLineSeparator)`r`n$($script:strLineSeparator)"; return}
              }
              break
            }
          }
          break
        }
      }
      $responseJson = '{"big": "test"}'
      $response = $context.response
      $response.StatusCode = $statusCode
      $response.ContentType = 'application/json'
      if (!$responseJson) {$responseJson = [string]::Empty}
      Write-Verbose "Response:`r`n$($responseJson)"
      $buffer = [System.Text.Encoding]::utf8.getbytes($responseJson)
      #$buffer = [System.Text.Encoding]::utf8.getbytes(($request.Content))
      $response.ContentLength64 = $buffer.Length
      $response.OutputStream.Write($buffer, 0, $buffer.Length)
      $response.OutputStream.Close()
      start-sleep -Milliseconds 10
    }
  } finally {
    $apiListener.Stop()
  }
#}

#Remove Listener Rule from Firewall
netsh advfirewall firewall delete rule name="TEMP_API_LISTENER"

