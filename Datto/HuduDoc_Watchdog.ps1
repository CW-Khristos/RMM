<#
.SYNOPSIS 
    Modification of AutoTask and Customer Services MagicDash to integrate NAble / Cove Data Protection
    Combines AutoTask and Customer Services MagicDash and DNS History enhancements to Hudu

.DESCRIPTION 
    Modification of AutoTask and Customer Services MagicDash to integrate NAble / Cove Data Protection
    Pulls and refreshes appropriate Customer NAble / Cove Data Protection Dashboard
    Combines AutoTask and Customer Services MagicDash and DNS History enhancements to Hudu
 
.NOTES
    Version                  : 0.1.2 (04 August 2022)
    Creation Date            : 25 August 2022
    Purpose/Change           : Modification of AutoTask and Customer Services MagicDash to integrate NAble / Cove Data Protection
                               https://mspp.io/hudu-datto-psa-autotask-open-tickets-magic-dash/
                               https://mspp.io/hudu-magic-dash-customer-services/
                               https://mspp.io/hudu-dns-history-and-alerts/
    File Name                : EventLog_Monitoring_0.1.0.ps1
    Hudu Source              : Luke Whitelock
                               https://mspp.io/author/iqadmin/
    Backup.Management Source : Eric Harless, Head Backup Nerd - N-able 
                               Twitter @Backup_Nerd  Email:eric.harless@n-able.com
    Modification             : Christopher Bledsoe - cbledsoe@ipmcomputers.com
    Supported OS             : Server 2012R2 and higher
    Requires                 : PowerShell Version 2.0+ installed

.CHANGELOG
    0.1.0 Initial Release
    0.1.1 Finalized addition of NAble / Cove Data Protection integration
          Added DNS History Hudu enhancement
    0.1.2 Added Model and Serial Lookup enhancements
          Added Backup.Management dashboards to respective Backup Device Assets
    
To Do:

#>
#Add this CSS to Admin -> Design -> Custom CSS
# .custom-fast-fact.custom-fast-fact--warning {
#     background: #f5c086;
# }
#First Clear any variables
#Remove-Variable * -ErrorAction SilentlyContinue
#region ----- DECLARATIONS ----
  $script:diag      = $null
  $script:blnWARN   = $false
  $script:blnBREAK  = $false
  $logPath          = "C:\IT\Log\HuduDoc_Watchdog"
  $strLineSeparator = "----------------------------------"
  $timestamp        = "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))"
  ######################### TLS Settings ###########################
  [System.Net.ServicePointManager]::MaxServicePointIdleTime = 5000000
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  ######################### Hudu Settings ###########################
  $script:huduCalls       = 0
  # Get a Hudu API Key from https://yourhududomain.com/admin/api_keys
  $script:HuduAPIKey      = $env:HuduKey
  # Set the base domain of your Hudu instance without a trailing /
  $script:HuduBaseDomain  = $env:HuduDomain
  ######################## Customer Management ##########################
  $SplitChar            = ":"
  $ManagementLayoutName = "Customer Management"
  $AllowedActions       = @("ENABLED", "NOTE", "URL")
  ######################## DNS Settings ##########################
  $script:dnsCalls      = 0
  $DNSHistoryLayoutName = "DNS Entries - Autodoc"
  # Enable sending alerts on dns change to a teams webhook
  $enableTeamsAlerts    = $false
  #$teamsWebhook         = "Your Teams Webhook URL"
  # Enable sending alerts on dns change to an email address
  $enableEmailAlerts    = $false
  #$mailTo               = "alerts@domain.com"
  #$mailFrom             = "alerts@domain.com"
  #$mailServer           = "mailserver.domain.com"
  #$mailPort             = "25"
  $mailUseSSL           = $false
  #$mailUser             = "user"
  #$mailPass             = "pass"
  ######################## Backups Settings ##########################
  $script:bmCalls = 0
  $script:blnBM   = $false
  $script:bmRoot  = $env:BackupRoot
  $script:bmUser  = $env:BackupUser
  $script:bmPass  = $env:BackupPass
  $urlJSON        = "https://api.backup.management/jsonapi"
  $Filter1        = "AT == 1 AND PN != 'Documents'"   ### Excludes M365 and Documents devices from lookup.
  ######################### Autotask Settings ###########################
  $script:psaCalls    = 0
  $AutotaskRoot       = $env:ATRoot
  $AutoTaskAPIBase    = $env:ATAPIBase
  $ExcludeType        = '[]'
  $ExcludeQueue       = '[]'
  $ExcludeStatus      = '[5,20]'
  #PSA API DATASETS
  $script:typeMap     = @{
    1 = "Customer"
    2 = "Lead"
    3 = "Prospect"
    4 = "Dead"
    6 = "Cancelation"
    7 = "Vendor"
    8 = "Partner"
  }
  $script:classMap    = @{}
  $script:categoryMap = @{}
  $GlobalOverdue      = [System.Collections.ArrayList]@()
  $AutotaskExe        = "/Autotask/AutotaskExtend/ExecuteCommand.aspx?Code=OpenTicketDetail&TicketNumber="
  $AutotaskDev        = "/Autotask/AutotaskExtend/AutotaskCommand.aspx?&Code=OpenInstalledProduct&InstalledProductID="
  $psaGenFilter       = '{"Filter":[{"field":"Id","op":"gte","value":0}]}'
  $psaActFilter       = '{"Filter":[{"op":"and","items":[{"field":"IsActive","op":"eq","value":true},{"field":"Id","op":"gte","value":0}]}]}'
  $TicketFilter       = "{`"filter`":[{`"op`":`"notin`",`"field`":`"queueID`",`"value`":$($ExcludeQueue)},{`"op`":`"notin`",`"field`":`"status`",`"value`":$($ExcludeStatus)},{`"op`":`"notin`",`"field`":`"ticketType`",`"value`":$($ExcludeType)}]}"
  ########################### Autotask Auth ##############################
  $script:AutotaskAPIUser       = $env:ATAPIUser
  $script:AutotaskAPISecret     = $env:ATAPISecret
  $script:AutotaskIntegratorID  = $env:ATIntegratorID
  $psaHeaders                   = @{
    'ApiIntegrationCode'        = "$($script:AutotaskIntegratorID)"
    'UserName'                  = "$($script:AutotaskAPIUser)"
    'Secret'                    = "$($script:AutotaskAPISecret)"
  }
  ##################### Autotask Report Settings ########################
  $folderID                       = 2
  $CreateAllOverdueTicketsReport  = $true
  $globalReportName               = "Autotask - Overdue Ticket Report"
  $TableStylingBad                = "<th>", "<th style=`"background-color:#f8d1d3`">"
  $TableStylingGood               = "<th>", "<th style=`"background-color:#aeeab4`">"
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

#region ----- MISC FUNCTIONS ----
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

  function logERR ($intSTG, $strModule, $strErr) {
    $script:blnWARN = $true
    #CUSTOM ERROR CODES
    switch ($intSTG) {
      1 {                                                         #'ERRRET'=1 - NOT ENOUGH ARGUMENTS, END SCRIPT
        $script:blnBREAK = $true
        $script:diag += "`r`n$($(get-date))`t - HuduDoc_WatchDog - NO ARGUMENTS PASSED, END SCRIPT`r`n`r`n"
        write-host "$($(get-date))`t - HuduDoc_WatchDog - NO ARGUMENTS PASSED, END SCRIPT`r`n"
      }
      2 {                                                         #'ERRRET'=2 - INSTALL / IMPORT MODULE FAILURE, END SCRIPT
        $script:blnBREAK = $true
        $script:diag += "`r`n$($(get-date))`t - HuduDoc_WatchDog - ($($strModule))`r`n$($strErr), END SCRIPT`r`n`r`n"
        write-host "$($(get-date))`t - HuduDoc_WatchDog - ($($strModule))`r`n$($strErr), END SCRIPT`r`n`r`n"
      }
      default {                                                   #'ERRRET'=3+
        $script:diag += "`r`n$($(get-date))`t - HuduDoc_WatchDog - $($strModule) : $($strErr)"
        write-host "$($(get-date))`t - HuduDoc_WatchDog - $($strModule) : $($strErr)"
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
    $totalCalls = ($script:psaCalls + $script:bmCalls + $script:huduCalls + $script:dnsCalls)
    $average = ($total / $totalCalls)
    $secs = [string]($total / 1000)
    $mill = $secs.split(".")[1]
    $secs = $secs.split(".")[0]
    $mill = $mill.SubString(0,[math]::min(3,$mill.length))
    $asecs = [string]($average / 1000)
    $amill = $asecs.split(".")[1]
    $asecs = $asecs.split(".")[0]
    $amill = $amill.SubString(0,[math]::min(3,$mill.length))
    #DISPLAY API THRESHOLDS
    $psa = PSA-GetThreshold $psaHeaders
    write-host "`r`nAPI Calls :`r`nPSA API : $($script:psaCalls) - Hudu API : $($script:huduCalls)"
    write-host "Backup.Management API : $($script:bmCalls) - DNS Calls : $($script:dnsCalls)"
    write-host "API Limits - PSA API (per Hour) : $($psa.currentTimeframeRequestCount) / $($psa.externalRequestThreshold)"
    write-host "Total Execution Time - $($Minutes) Minutes : $($secs) Seconds : $($mill) Milliseconds"
    $script:diag += "`r`nAPI Calls :`r`nPSA API : $($script:psaCalls) - Hudu API : $($script:huduCalls)"
    $script:diag += "`r`nBackup.Management API : $($script:bmCalls) - DNS Calls : $($script:dnsCalls)"
    $script:diag += "`r`nAPI Limits :`r`nPSA API (per Hour) : $($psa.currentTimeframeRequestCount) / $($psa.externalRequestThreshold)"
    $script:diag += "`r`nTotal Execution Time - $($Minutes) Minutes : $($secs) Seconds : $($mill) Milliseconds`r`n"
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
#endregion ----- MISC FUNCTIONS ----

#region ----- PSA FUNCTIONS ----
  function Get-ATFieldHash {
    Param(
      [Array]$fieldsIn,
      [string]$name
    )
    $script:psaCalls += 1
    $tempFields = ($fieldsIn.fields | where -filter {$_.name -eq $name}).picklistValues
    $tempValues = $tempFields | where -filter {$_.isActive -eq $true} | select value,label
    $tempHash = @{}
    $tempValues | Foreach {$tempHash[$_.value] = $_.label}
    return $tempHash	
  }

  function PSA-Query {
    param ($header, $method, $entity)
    $params = @{
      Method      = "$($method)"
      ContentType = 'application/json'
      Uri         = "$($AutoTaskAPIBase)/ATServicesRest/V1.0/$($entity)"
      Headers     = $header
    }
    $script:psaCalls += 1
    try {
      Invoke-RestMethod @params -UseBasicParsing -erroraction stop
    } catch {
      $psadiag = $null
      $script:blnWARN = $true
      $psadiag += "Failed to query PSA API via $($params.Uri)"
      $psadiag += "`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
      logERR 3 "PSA-Query" "$($psadiag)"
    }
  }

  function PSA-FilterQuery {
    param ($header, $method, $entity, $filter)
    $params = @{
      Method      = "$($method)"
      ContentType = 'application/json'
      Uri         = "$($AutoTaskAPIBase)/ATServicesRest/V1.0/$($entity)/query?search=$($filter)"
      Headers     = $header
    }
    $script:psaCalls += 1
    try {
      Invoke-RestMethod @params -UseBasicParsing -erroraction stop
    } catch {
      $psadiag = $null
      $script:blnWARN = $true
      $psadiag += "Failed to query (filtered) PSA API via $($params.Uri)"
      $psadiag += "`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
      logERR 3 "PSA-FilterQuery" "$($psadiag)"
    }
  }

  function PSA-GetThreshold {
    param ($header)
    try {
      PSA-Query $header "GET" "ThresholdInformation" -erroraction stop
    } catch {
      $psadiag = $null
      $script:blnWARN = $true
      $psadiag += "Failed to populate PSA API Utilization via $($params.Uri)"
      $psadiag += "`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
      logERR 3 "PSA-GetThreshold" "$($psadiag)"
    }
  }

  function PSA-GetMaps {
    param ($header, $dest, $entity)
    $Uri = "$($AutoTaskAPIBase)/ATServicesRest/V1.0/$($entity)/query?search=$($psaActFilter)"
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
      $psadiag = $null
      $script:blnFAIL = $true
      $psadiag += "Failed to populate PSA $($entity) Maps via $($Uri)"
      $psadiag += "`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
      logERR 3 "PSA-GetMaps" "$($psadiag)"
    }
  } ## PSA-GetMaps

  function PSA-GetCompanies {
    param ($header)
    $script:CompanyDetails = @()
    $Uri = "$($AutoTaskAPIBase)/ATServicesRest/V1.0/Companies/query?search=$($psaActFilter)"
    try {
      $CompanyList = PSA-FilterQuery $header "GET" "Companies" "$($psaActFilter)"
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
      $psadiag = $null
      $script:blnFAIL = $true
      $psadiag += "Failed to populate PSA Companies via $($Uri)"
      $psadiag += "`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
      logERR 3 "PSA-GetCompanies" "$($psadiag)"
    }
  } ## PSA-GetCompanies API Call
#endregion ----- PSA FUNCTIONS ----

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
    write-host "$($strLineSeparator)`r`n$($strLineSeparator)"
    write-host "$($Script:cookies[0].name) = $($cookies[0].value)"
    write-host $strLineSeparator
    write-host $Script:Authenticate
    write-host "$($strLineSeparator)`r`n$($strLineSeparator)"
    --#>
    if ($authenticate.visa) {
      $script:blnBM = $true
      $bmdiag = "`r`n$($strLineSeparator)`r`nBM AUTH SUCCESS : $($script:blnBM)`r`n$($strLineSeparator)"
      logERR 4 "Send-APICredentialsCookie" "$($bmdiag)"
      $Script:visa = $Script:Authenticate.visa
    } else {
      $script:blnBM = $false
      $bmdiag = "`r`n($strLineSeparator)`r`nBM AUTH SUCCESS : $($script:blnBM)`r`n$($strLineSeparator)"
      $bmdiag += "`r`n  Authentication Failed: Please confirm your Backup.Management Partner Name and Credentials"
      $bmdiag += "`r`n  Please Note: Multiple failed authentication attempts could temporarily lockout your user account"
      $bmdiag += "`r`n$($strLineSeparator)"
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
      $bmdiag = "`r`n$($strLineSeparator)`r`n  $($PartnerName) - $($partnerId) - $($Uid)`r`n$($strLineSeparator)"
      logERR 4 "Send-GetPartnerInfo" "$($bmdiag)"
    } else {
      $script:blnBM = $false
      $bmdiag = "`r`n$($strLineSeparator)`r`n  Lookup for $($Partner.result.result.Level) Partner Level Not Allowed`r`n$($strLineSeparator)"
      logERR 4 "Send-GetPartnerInfo" "$($bmdiag)"
    }

    if ($partner.error) {
      $script:blnBM = $false
      $bmdiag = "`r`n$($strLineSeparator)`r`n  $($partner.error.message)`r`n$($strLineSeparator)"
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
    $data.params.query.Columns = @("AU","AR","AN","MN","AL","LN","OP","OI","OS","PD","AP","PF","PN","CD","TS","TL","T3","US","AA843","AA77","AA2048","AA2531","I78")
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
        GUIPassword       = $BackupsResult.Settings.AA2048 -join '' ;
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
  } ## Send-GetDevices API Call
#endregion ----- Backup.Management JSON Calls ----

  function Check-DNSChange {
    Param (
      [string]$currentDNS = '',
      [string]$newDNS = '',
      [string]$recordType = '',
      [string]$website = '',
      [string]$companyName = ''
    )
    $Comp = Compare-Object -ReferenceObject $($currentDNS -split "`n") -DifferenceObject $($newDNS -split "`n")
    if ($Comp){
      # Send Teams Alert
      if ($enableTeamsAlerts) {
        $JSONBody = [PSCustomObject][Ordered]@{
          "@type"      = "MessageCard"
          "@context"   = "http://schema.org/extensions"
          "summary"    = "$companyName - $website - DNS $recordType change detected"
          "themeColor" = '0078D7'
          "sections"   = @(
            @{
              "activityTitle"    = "$companyName - $website - DNS $recordType Change Detected"
              "facts"            = @(
                @{
                  "name"  = "Original DNS Records"
                  "value" = $((($Comp | where-object -filter {$_.SideIndicator -eq "<="}).InputObject | out-string ) -replace '<[^>]+>',' ')
                },
                @{
                  "name"  = "New DNS Records"
                  "value" = $((($Comp | where-object -filter {$_.SideIndicator -eq "=>"}).InputObject | out-string ) -replace '<[^>]+>',' ')
                }
              )
              "markdown" = $true
            }
          )
        }
        $TeamMessageBody = ConvertTo-Json $JSONBody -Depth 100          
        $parameters = @{
          "URI"         = $teamsWebhook
          "Method"      = 'POST'
          "Body"        = $TeamMessageBody
          "ContentType" = 'application/json'
        }
        $result = Invoke-RestMethod @parameters
      }
      if ($enableEmailAlerts){
        $oldVal = ($Comp | where-object -filter {$_.SideIndicator -eq "<="}).InputObject | out-string
        $newVal = ($Comp | where-object -filter {$_.SideIndicator -eq "=>"}).InputObject | out-string
        $mailSubject = "$companyName - $website - DNS $recordType change detected"
        $body = "
          <h3>$mailSubject</h3>
          <p>Original DNS Record:</p>
          <table>
          $oldVal
          </table>
          <p>New DNS Record:</p>
          <table>
          $newVal
          </table>
          "
        $password = ConvertTo-SecureString $mailPass -AsPlainText -Force
        $mailcred = New-Object System.Management.Automation.PSCredential ($mailUser, $password)
        $sendMailParams = @{
          From = $mailFrom
          To = $mailTo
          Subject = $mailSubject
          Body = $body
          SMTPServer = $mailServer
          UseSsl = $mailUseSSL
          Credential = $mailcred
        }
        Send-MailMessage @sendMailParams -BodyAsHtml
      }
    }
  }

  function Set-BackupDash ($i_Company, $i_CompanyID, $i_AllPartners, $i_AllDevices, $i_Note, $i_URL, $i_BackupID) {
    ######################### Backups Section ###########################
    Send-APICredentialsCookie
    $bmdiag = "Validating Backups : AUTH STATE : $($script:blnBM)"
    logERR 4 "Set-BackupDash" "$($bmdiag)"
    if ($script:blnBM) {
      #Fix Mis-Matched Target Partner Names
      if ($i_Company -eq "Autotask Customer Name") {
        $bmPartner = "Backup.Management Customer Name"
      } else {
        $bmPartner = $i_Company
      }
      write-host $strLineSeparator
      # OBTAIN PARTNER AND BACKUP ACCOUNT ID
      $bmdiag = "  Passed Partner: $($bmPartner)"
      logERR 4 "Set-BackupDash" "$($bmdiag)"
      if ($i_AllPartners) {
        Send-GetPartnerInfo "$($script:bmRoot)"
        Send-GetBackups "$($script:bmRoot)"
      } elseif (-not $i_AllPartners) {
        Send-GetPartnerInfo "$($bmPartner)"
        Send-GetBackups "$($bmPartner)"
      }

      if ($i_AllDevices) {
        $script:SelectedDevices = $script:BackupsDetails | 
          Select-Object PartnerId,PartnerName,AccountID,ComputerName,DeviceName,OS,IPMGUIPwd,
            TimeStamp,LastSuccess,Product,DataSources,SelectedGB,UsedGB,Location,Notes
        $bmdiag = "`r`n$($strLineSeparator)`r`n  $($SelectedDevices.AccountId.count) Devices Selected`r`n$($strLineSeparator)"
        logERR 4 "Set-BackupDash" "$($bmdiag)"
      } elseif (-not $i_AllDevices) {
        if (($null -ne $i_BackupID) -and ($i_BackupID -ne "")) {
          $script:SelectedDevices = $script:BackupsDetails | 
            Select-Object PartnerId,PartnerName,AccountID,ComputerName,DeviceName,OS,IPMGUIPwd,
              TimeStamp,LastSuccess,Product,DataSources,SelectedGB,UsedGB,Location,Notes | 
                Where-object {$_.DeviceName -eq $i_BackupID}
          $bmdiag = "`r`n$($strLineSeparator)`r`n  $($SelectedDevices.AccountId.count) Devices Selected`r`n$($strLineSeparator)"
          logERR 4 "Set-BackupDash" "$($bmdiag)"
        }
      }    

      if (@($script:SelectedDevices).count -gt 0) {
        # OK was pressed, $Selection contains what was chosen
        # Run OK script
        $script:SelectedDevices | 
          Select-Object PartnerId,PartnerName,@{Name="AccountID"; Expression={[int]$_.AccountId}},ComputerName,DeviceName,OS,IPMGUIPwd,
            TimeStamp,LastSuccess,Product,DataSources,SelectedGB,UsedGB,Location,Notes | 
              Sort-object AccountId | Format-Table

        $badHTML = $null
        $goodHTML = $null
        $shade = "success"
        $reportDate = get-date
        $MagicMessage = "$(@($script:SelectedDevices).count) Protected Devices"
        $overdue = @($script:SelectedDevices | 
            where {(get-date -date "$($_.TimeStamp)") -lt $reportDate.AddDays(-1)} | 
              select PartnerId,PartnerName,AccountID,ComputerName,DeviceName,OS,IPMGUIPwd,
                TimeStamp,LastSuccess,Product,DataSources,SelectedGB,UsedGB,Location,Notes).count
        if ($overdue -ge 1) {
          $shade = "warning"
          $MagicMessage = "$($overdue) / $(@($script:SelectedDevices).count) Backups Overdue"
          $badHTML = [System.Net.WebUtility]::HtmlDecode(($script:SelectedDevices | 
            where {(get-date -date "$($_.TimeStamp)") -lt $reportDate.AddDays(-1)} | 
              select PartnerId,PartnerName,AccountID,ComputerName,DeviceName,OS,IPMGUIPwd,
                TimeStamp,LastSuccess,Product,DataSources,SelectedGB,UsedGB,Location,Notes | 
                  convertto-html -fragment | out-string) -replace $TableStylingBad)
          $goodHTML = [System.Net.WebUtility]::HtmlDecode(($script:SelectedDevices | 
            where {(get-date -date "$($_.TimeStamp)") -ge $reportDate.AddDays(-1)} | 
              select PartnerId,PartnerName,AccountID,ComputerName,DeviceName,OS,IPMGUIPwd,
                TimeStamp,LastSuccess,Product,DataSources,SelectedGB,UsedGB,Location,Notes | 
                  convertto-html -fragment | out-string) -replace $TableStylingGood)
          $badbody = "<h2>Overdue Backups:</h2><figure class=`"table`">$($badHTML)</figure>"
          $badbody = "$($badbody)<h2>Completed Backups:</h2><figure class=`"table`">$($goodHTML)</figure>"
        } else {
          $goodHTML = [System.Net.WebUtility]::HtmlDecode(($script:SelectedDevices | 
            where {(get-date -date "$($_.TimeStamp)") -ge $reportDate.AddDays(-1)} | 
              select PartnerId,PartnerName,AccountID,ComputerName,DeviceName,OS,IPMGUIPwd,
                TimeStamp,LastSuccess,Product,DataSources,SelectedGB,UsedGB,Location,Notes | 
                  convertto-html -fragment | out-string) -replace $TableStylingGood)
          $goodbody = "<h2>$($i_Company) Backups:</h2><figure class=`"table`">$($goodHTML)</figure>"
        }

        if ($overdue -ge 2) {$shade = "danger"}
        $body = "<p class=`"callout callout-info`"><button type=`"button`" style=`"background-color: #B5B5B5;font-size: 16px;`"><a target=`"_blank`" href=`"$($i_URL)`"><b>Open Backup.Management</b></a></button></p>"
        $body = "$($body)<h4>Report last updated: $($timestamp)</h4>$($badbody)$($goodbody)"
        $body = $body.replace("<table>",'<table style="width: 100%;">')
        $body = $body.replace("<tr>",'<tr style="width: 100%;">')
        $body = $body.replace("<td>",'<td style="resize: both;overflow: auto;margin: 25px;"><div style="resize: both; overflow: auto;margin: 5px;">')
        $body = $body.replace("</td>",'</td></div>')
        #write-host "$($body)"
        #write-host $i_Note
        try {
          $script:huduCalls += 1
          $Huduresult = Set-HuduMagicDash -title "Backup - $($i_Note)" -company_name "$($i_Company)" -message "$($MagicMessage)" -icon "fas fa-chart-pie" -content "$($body)" -shade "$($shade)" -ea stop
          $bmdiag = "Backup Magic Dash Set"
          logERR 4 "Set-BackupDash" "$($bmdiag)"
          $arrayAssets = @("Server","Workstation")
          foreach ($type in $arrayAssets) {
            # Get the Asset Layout
            $script:huduCalls += 1
            $AssetLayout = Get-HuduAssetLayouts -name "$($type)"
            # Check we found the layout
            if (($AssetLayout | measure-object).count -le 0) {
              $bmdiag = "`r`n$($strLineSeparator)`r`nNo layout(s) found in  $($type)"
              logERR 4 "Set-BackupDash" "$($bmdiag)"
            } else {
              # Get all the detail assets and loop
              foreach ($device in $script:SelectedDevices) { 
                $AssetName = "$($device.ComputerName)"
                # Get all the detail assets and loop
                $script:huduCalls += 1
                $Asset = Get-HuduAssets -name "$($AssetName)" -companyid $i_CompanyID -assetlayoutid $AssetLayout.id
                if ($Asset) {
                  $badHTML = $null
                  $goodHTML = $null
                  if ((get-date -date "$($device.TimeStamp)") -lt $reportDate.AddDays(-1)) {
                    $badHTML = [System.Net.WebUtility]::HtmlDecode(($device | 
                      select PartnerId,PartnerName,AccountID,ComputerName,DeviceName,OS,IPMGUIPwd,
                        TimeStamp,LastSuccess,Product,DataSources,SelectedGB,UsedGB,Location,Notes | 
                          convertto-html -fragment | out-string) -replace $TableStylingBad)
                  } elseif ((get-date -date "$($device.TimeStamp)") -ge $reportDate.AddDays(-1)) {
                    $goodHTML = [System.Net.WebUtility]::HtmlDecode(($device | 
                      select PartnerId,PartnerName,AccountID,ComputerName,DeviceName,OS,IPMGUIPwd,
                        TimeStamp,LastSuccess,Product,DataSources,SelectedGB,UsedGB,Location,Notes | 
                          convertto-html -fragment | out-string) -replace $TableStylingGood)
                  }
                  $body = "<p class=`"callout callout-info`"><button type=`"button`" style=`"background-color: #B5B5B5;font-size: 16px;`"><a target=`"_blank`" href=`"$($i_URL)`"><b>Open Backup.Management</b></a></a></button></p>"
                  $body = "$($body)<h4>Report last updated: $($timestamp)</h4><h2>$($AssetName) Backups:</h2>$($badHTML)$($goodHTML)"
                  $body = $body.replace("<table>",'<table style="width: 100%;">')
                  $body = $body.replace("<tr>",'<tr style="width: 100%;">')
                  $body = $body.replace("<td>",'<td style="resize: both;overflow: auto;margin: 25px;"><div style="resize: both; overflow: auto;margin: 5px;">')
                  $body = $body.replace("</td>",'</td></div>')
                  # Loop through all the fields on the Asset
                  $AssetFields = @{
                    'control_tools'         = ($Asset.fields | where-object -filter {$_.label -eq "Control Tools"}).value
                    'asset_location'        = ($Asset.fields | where-object -filter {$_.label -eq "Asset Location"}).value
                    'manufacturer'          = ($Asset.fields | where-object -filter {$_.label -eq "Manufacturer"}).value
                    'model'                 = ($Asset.fields | where-object -filter {$_.label -eq "Model"}).value
                    'model_lookup'          = ($Asset.fields | where-object -filter {$_.label -eq "Model Lookup"}).value
                    'serial_number'         = ($Asset.fields | where-object -filter {$_.label -eq "Serial Number"}).value
                    'serial_lookup'         = ($Asset.fields | where-object -filter {$_.label -eq "Serial Lookup"}).value
                    'has_notes'             = ($Asset.fields | where-object -filter {$_.label -eq "Has Notes"}).value
                    'mac_address'           = ($Asset.fields | where-object -filter {$_.label -eq "MAC Address"}).value
                    'ip_address'            = ($Asset.fields | where-object -filter {$_.label -eq "IP Address"}).value
                    'gateway'               = ($Asset.fields | where-object -filter {$_.label -eq "Gateway"}).value
                    'subnet'                = ($Asset.fields | where-object -filter {$_.label -eq "Subnet"}).value
                    'smart_enabled_in_bios' = ($Asset.fields | where-object -filter {$_.label -eq "SMART Enabled In BIOS"}).value
                    'backup_dash'           = $body
                    'notes'                 = ($Asset.fields | where-object -filter {$_.label -eq "Notes"}).value
                  }
                  try {
                    $Asset = Set-HuduAsset -asset_id $Asset.id -name "$($AssetName)" -companyid $i_CompanyID -assetlayoutid $AssetLayout.id -fields $AssetFields
                    $bmdiag = "Updated $($AssetName) in $($i_Company) $($type) Assets"
                    logERR 4 "Set-BackupDash" "$($bmdiag)"
                    $script:huduCalls += 1
                  } catch {
                    $bmdiag = "Error Updating $($AssetName) in $($i_Company) $($type) Assets`r`n$($strLineSeparator)"
                    $bmdiag += "`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
                  }
                }
              }
            }
          }
        } catch {
          $bmdiag = "$($i_Company) not found in Hudu or other error occured`r`n$($strLineSeparator)"
          $bmdiag = "`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
          logERR 4 "Set-BackupDash" "$($bmdiag)"
        }
      } else {
        try {
          $script:huduCalls += 1
          $Huduresult = Set-HuduMagicDash -title "Backup - $($i_Note)" -company_name "$($i_Company)" -message "No Backups Found" -icon "fas fa-chart-pie" -shade "grey" -ea stop
          $bmdiag = "`r`n$($strLineSeparator)`r`n  No Devices Selected`r`n$($strLineSeparator)"
          $bmdiag += "`r`nBackup Magic Dash Set`r`n$($strLineSeparator)"
          logERR 4 "Set-BackupDash" "$($bmdiag)"
        } catch {
          $bmdiag = "$($i_Company) not found in Hudu or other error occured`r`n$($strLineSeparator)"
          $bmdiag += "`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
          logERR 4 "Set-BackupDash" "$($bmdiag)"
        }
      }
    } elseif (-not $script:blnBM) {
      $shade = "warning"
      $script:huduCalls += 1
      $dash = Get-HuduMagicDashes -Title "Backup - $($i_Note)" -company_name "$($i_Company)"
      $head = "<table><th style=`"background-color:#f8d1d3`"><p class=`"callout callout-danger`">FAILED TO LOGIN TO BACKUP.MANAGEMENT - $($timestamp)</p></th></table>"
      if ($dash.content -match "FAILED TO LOGIN TO BACKUP.MANAGEMENT") {
        $delim = '</table>'
        $array = $dash.content -split $delim, 0, "simplematch"
        $body = "$($head)$($array[$array.GetUpperBound(0) - 1])</table>"
      } elseif ($dash.content -notmatch "FAILED TO LOGIN TO BACKUP.MANAGEMENT") {
        $body = "$($head)$($dash.content)"
      }
      try {
        #write-host "$($body)"
        #write-host $i_Note
        $script:huduCalls += 1
        $Huduresult = Set-HuduMagicDash -title "Backup - $($i_Note)" -company_name "$($i_Company)" -message "Failed to login to Backup.Management" -icon "fas fa-chart-pie" -content "$($body)" -shade "$($shade)" -ea stop
        $bmdiag = "FAILED TO LOGIN TO BACKUP.MANAGEMENT - $($(get-date))"
        $bmdiag += " - Backup Magic Dash Set`r`n$($strLineSeparator)"
        logERR 4 "Set-BackupDash" "$($bmdiag)"
      } catch {
        $bmdiag = "$($i_Company)) not found in Hudu or other error occured`r`n$($strLineSeparator)"
        $bmdiag += "`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
        logERR 4 "Set-BackupDash" "$($bmdiag)"
      }
    }
  }
#endregion ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
clear-host
Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
#Start script execution time calculation
$ScrptStartTime = (get-date).ToString('dd-MM-yyyy hh:mm:ss')
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
if (-not $script:blnBREAK) {
  #Set Hudu logon information
  New-HuduAPIKey $script:HuduAPIKey
  New-HuduBaseUrl $script:HuduBaseDomain
  ######################### Customer Management Section ###########################
  # https://mspp.io/hudu-magic-dash-customer-services/
  # Get the Asset Layout
  $script:huduCalls += 1
  $DetailsLayout = Get-HuduAssetLayouts -name $ManagementLayoutName
  # Check we found the layout
  if (($DetailsLayout | measure-object).count -ne 1) {
    write-host "$($strLineSeparator)`r`nNo / multiple layout(s) found with name $($ManagementLayoutName)"
    $script:diag += "`r`n$($strLineSeparator)`r`nNo / multiple layout(s) found with name $($ManagementLayoutName)"
  } else {
    # Get all the detail assets and loop
    $script:huduCalls += 1
    $DetailsAssets = Get-HuduAssets -assetlayoutid $DetailsLayout.id | Sort-Object -Property company_name
    foreach ($Asset in $DetailsAssets) {
      write-host "`r`n$($strLineSeparator)`r`nProcessing $($Asset.company_name) Managed Services`r`n$($strLineSeparator)"
      $script:diag += "`r`n`r`n$($strLineSeparator)`r`nProcessing $($Asset.company_name) Managed Services`r`n$($strLineSeparator)"
      # Loop through all the fields on the Asset
      $Fields = foreach ($field in $Asset.fields) {
        if ($field.label -like "*:*") {
          # Split the field name
          $SplitField = $field.label -split $SplitChar
          # Check the field has an allowed action.
          if ($SplitField[1] -notin $AllowedActions) {
            write-host "$($strLineSeparator)`r`nField $($field.label) is not an allowed action"
            $script:diag += "`r`n$($strLineSeparator)`r`nField $($field.label) is not an allowed action"
          } else {
            # Format an object to work with
            [PSCustomObject]@{
              ServiceName   = $SplitField[0]
              ServiceAction = $SplitField[1]
              Value         = $field.value
            }
          }
        }
      }
      foreach ($Service in $Fields.servicename | select-object -unique){
        $EnabledField = $Fields | Where-Object {$_.servicename -eq $Service -and $_.serviceaction -eq 'ENABLED'}
        $NoteField = $Fields | Where-Object {$_.servicename -eq $Service -and $_.serviceaction -eq 'NOTE'}
        $URLField = $Fields | Where-Object {$_.servicename -eq $Service -and $_.serviceaction -eq 'URL'}
        if ($EnabledField) {
          $Colour = switch ($EnabledField.value) {
            $true {'success'}
            $false {'grey'}
            default {'grey'}
          }
          $Param = @{
            Title = $Service
            CompanyName = $Asset.company_name
            Shade = $Colour
          }
          if ($NoteField.value){
              $Param['Message'] = $NoteField.value
              $Param | Add-Member -MemberType NoteProperty -Name 'Message' -Value $NoteField.value
          } else {
            $Param['Message'] = switch ($EnabledField.value) {
              $true {"Customer has $($Service)"}
              $false {"No $($Service)"}
              default {"No $($Service)"}
            }
          }
          if (($URLField.value) -and ($Service -ne "Backup")) {
            $Param['ContentLink'] = $URLField.value
          }
          if ($Service -ne "Backup") {
            $script:huduCalls += 1
            Set-HuduMagicDash @Param
            write-host "$($Service) Magic Dash Set`r`n$($strLineSeparator)"
            $script:diag += "`r`n$($Service) Magic Dash Set`r`n$($strLineSeparator)"
          } elseif ($Service -eq "Backup") {
            switch ($EnabledField.value) {
              $true {Set-BackupDash $Asset.company_name $Asset.company_id $false $true $NoteField.value $URLField.value $null}
              $false {$script:huduCalls += 1;Set-HuduMagicDash @Param}
            }
          }
        } else {
          write-host "$($strLineSeparator)`r`nNo Enabled Field was found"
          $script:diag += "`r`n$($strLineSeparator)`r`nNo Enabled Field was found"
        }
      }
    }
  }
  ######################### DNS History Section ###########################
  # https://mspp.io/hudu-dns-history-and-alerts/
  write-host "`r`n$($strLineSeparator)`r`nBeginning DNS History Processing"
  $script:diag += "`r`n`r`n$($strLineSeparator)`r`nBeginning DNS History Processing"
  $script:huduCalls += 1
  $DNSLayout = Get-HuduAssetLayouts -name $DNSHistoryLayoutName
  if (!$DNSLayout) { 
    $AssetLayoutFields = @(
      @{
        label = 'A and AAAA Records'
        field_type = 'RichText'
        show_in_list = 'true'
        position = 1
      },
      @{
        label = 'MX Records'
        field_type = 'RichText'
        show_in_list = 'false'
        position = 2
      },
      @{
        label = 'Name Servers'
        field_type = 'RichText'
        show_in_list = 'false'
        position = 3
      },
      @{
        label = 'TXT Records'
        field_type = 'RichText'
        show_in_list = 'false'
        position = 4
      },
      @{
        label = 'SOA Records'
        field_type = 'RichText'
        show_in_list = 'false'
        position = 5
      }
    )
    #$script:huduCalls += 2
    write-host "$($strLineSeparator)`r`nMissing DNS Asset Layout $($DNSHistoryLayoutName)"
    $script:diag += "`r`n$($strLineSeparator)`r`nMissing DNS Asset Layout $($DNSHistoryLayoutName)"
    #$NewLayout = New-HuduAssetLayout -name $DNSHistoryLayoutName -icon "fas fa-sitemap" -color "#00adef" -icon_color "#ffffff" -include_passwords $true -include_photos $false -include_comments $true -include_files $true -fields $AssetLayoutFields
    #$DNSLayout = Get-HuduAssetLayouts -name $DNSHistoryLayoutName
  }
  $websites = Get-HuduWebsites | where -filter {$_.disable_dns -eq $false} | Sort-Object -Property company_name
  foreach ($website in $websites){
    $dnsname = ([System.Uri]$website.name).authority
    write-host "$($strLineSeparator)`r`nResolving $($dnsname) for $($website.company_name)"
    $script:diag += "`r`n$($strLineSeparator)`r`nResolving $($dnsname) for $($website.company_name)"
    try {
      $script:dnsCalls += 5
      $arecords = resolve-dnsname $dnsname -type A_AAAA -ErrorAction Stop | select type, IPADDRESS | sort IPADDRESS | convertto-html -fragment | out-string
      $mxrecords = resolve-dnsname $dnsname -type MX -ErrorAction Stop | sort NameExchange |convertto-html -fragment -property NameExchange | out-string
      $nsrecords = resolve-dnsname $dnsname -type NS -ErrorAction Stop | sort NameHost | convertto-html -fragment -property NameHost| out-string
      $txtrecords = resolve-dnsname $dnsname -type TXT -ErrorAction Stop | select @{N='Records';E={$($_.strings)}}| sort Records | convertto-html -fragment -property Records | out-string
      $soarecords = resolve-dnsname $dnsname -type SOA -ErrorAction Stop | select PrimaryServer, NameAdministrator, SerialNumber | sort NameAdministrator | convertto-html -fragment | out-string
    } catch {
      $script:diag += "`r`n$($strLineSeparator)`r`n$($dnsname) lookup failed"
      write-host "$($strLineSeparator)`r`n$($dnsname) lookup failed" -foregroundcolor red
      continue
    }
       
    $AssetFields = @{
      'a_and_aaaa_records'  = $arecords
      'mx_records'          = $mxrecords
      'name_servers'        = $nsrecords
      'txt_records'         = $txtrecords
      'soa_records'         = $soarecords                      
    }
    $script:diag += "`r`n$($strLineSeparator)`r`n$($dnsname) lookup successful"
    write-host "$($strLineSeparator)`r`n$($dnsname) lookup successful" -foregroundcolor green
    $companyid = $website.company_id
    #Swap out # as Hudu doesn't like it when searching
    $AssetName = $dnsname
    #Check if there is already an asset
    $script:huduCalls += 1
    $Asset = Get-HuduAssets -name $AssetName -companyid $companyid -assetlayoutid $DNSLayout.id
    #If the Asset does not exist, we edit the body to be in the form of a new asset, if not, we just upload.
    if (!$Asset) {
      try {
        $script:huduCalls += 1
        write-host "$($strLineSeparator)`r`nCreating new DNS Asset`r`n$($strLineSeparator)"
        $script:diag += "`r`n$($strLineSeparator)`r`nCreating new DNS Asset`r`n$($strLineSeparator)"
        $Asset = New-HuduAsset -name $AssetName -company_id $companyid -asset_layout_id $DNSLayout.id -fields $AssetFields
      } catch {
        write-host "$($strLineSeparator)`r`nError Creating DNS Asset - $($AssetName)" -foregroundcolor red
        $script:diag += "`r`n$($strLineSeparator)`r`nError Creating DNS Asset - $($AssetName)"
      }
    } else {
      #Get the existing records
      $a_cur_value = ($Asset.fields | where-object -filter {$_.label -eq "A and AAAA Records"}).value
      $mx_cur_value = ($Asset.fields | where-object -filter {$_.label -eq "MX Records"}).value
      $ns_cur_value = ($Asset.fields | where-object -filter {$_.label -eq "Name Servers"}).value
      $txt_cur_value = ($Asset.fields | where-object -filter {$_.label -eq "TXT Records"}).value
      $soa_cur_value = ($Asset.fields | where-object -filter {$_.label -eq "SOA Records"}).value
      #Compare the new and old values and send alerts
      Check-DNSChange -currentDNS $a_cur_value -newDNS $arecords -recordType "A / AAAA" -website $AssetName -companyName $website.company_name
      Check-DNSChange -currentDNS $mx_cur_value -newDNS $mxrecords -recordType "MX" -website $AssetName -companyName $website.company_name
      Check-DNSChange -currentDNS $ns_cur_value -newDNS $nsrecords -recordType "Name Servers" -website $AssetName -companyName $website.company_name
      Check-DNSChange -currentDNS $txt_cur_value -newDNS $txtrecords -recordType "TXT" -website $AssetName -companyName $website.company_name
      try {
        $script:huduCalls += 1
        write-host "$($strLineSeparator)`r`nUpdating DNS Asset`r`n$($strLineSeparator)"
        $script:diag += "`r`n$($strLineSeparator)`r`nUpdating DNS Asset`r`n$($strLineSeparator)"
        $Asset = Set-HuduAsset -asset_id $Asset.id -name $AssetName -company_id $companyid -asset_layout_id $DNSLayout.id -fields $AssetFields
      } catch {
        write-host "$($strLineSeparator)`r`nError Updating DNS Asset - $($AssetName)" -foregroundcolor red
        $script:diag += "`r`n$($strLineSeparator)`r`nError Updating DNS Asset - $($AssetName)"
      }
    }
  }
  ######################### Autotask  Section ###########################
  # https://mspp.io/hudu-datto-psa-autotask-open-tickets-magic-dash/
  write-host "`r`n$($strLineSeparator)`r`nBeginning Autotask Processing`r`n$($strLineSeparator)"
  $script:diag += "`r`n`r`n$($strLineSeparator)`r`nBeginning Autotask Processing`r`n$($strLineSeparator)"
  #QUERY PSA API
  write-host "$($strLineSeparator)`r`n`tCLASS MAP :"
  PSA-GetMaps $psaHeaders $script:classMap "ClassificationIcons"
  $script:classMap
  write-host "$($strLineSeparator)`r`n$($strLineSeparator)`r`n`tCATEGORY MAP :"
  PSA-GetMaps $psaHeaders $script:categoryMap "CompanyCategories"
  $script:categoryMap
  write-host "$($strLineSeparator)"
  PSA-GetCompanies $psaHeaders
  #Get Ticket Fields
  $script:psaCalls += 1
  $fields = Invoke-RestMethod -method "GET" -uri "$($AutoTaskAPIBase)/ATServicesRest/V1.0/Tickets/entityInformation/fields" -headers $psaHeaders -contentType 'application/json'
  #Get Statuses
  $statusValues = Get-ATFieldHash -name "status" -fieldsIn $fields
  if (!$ExcludeStatus) {
    write-host "ExcludeStatus not set please exclude your closed statuses at least from below in the format of '[1,5,7,9]'"
    $script:diag += "`r`nExcludeStatus not set please exclude your closed statuses at least from below in the format of '[1,5,7,9]'"
    $statusValues | ft
  }
  #Get Ticket types
  $typeValues = Get-ATFieldHash -name "ticketType" -fieldsIn $fields
  if (!$ExcludeType) {
    write-host "ExcludeType not set please exclude types from below in the format of '[1,5,7,9]"
    $script:diag += "`r`nExcludeType not set please exclude types from below in the format of '[1,5,7,9]"
    $typeValues | ft
  }
  #Get Queue Types
  $queueValues = Get-ATFieldHash -name "queueID" -fieldsIn $fields
  if (!$ExcludeType) {
    write-host "ExcludeQueue not set please exclude types from below in the format of '[1,5,7,9]"
    $script:diag += "`r`nExcludeQueue not set please exclude types from below in the format of '[1,5,7,9]"
    $queueValues | ft
  }
  #Get Creator Types
  $creatorValues = Get-ATFieldHash -name "creatorType" -fieldsIn $fields
  #Get Issue Types
  $issueValues = Get-ATFieldHash -name "issueType" -fieldsIn $fields
  #Get Priority Types
  $priorityValues = Get-ATFieldHash -name "priority" -fieldsIn $fields
  #Get Source Types
  $sourceValues = Get-ATFieldHash -name "source" -fieldsIn $fields
  #Get Sub Issue Types
  $subissueValues = Get-ATFieldHash -name "subIssueType" -fieldsIn $fields
  #Get Categories
  $catValues = Get-ATFieldHash -name "ticketCategory" -fieldsIn $fields
  #Autotask Auth
  $script:psaCalls += 2
  $Creds = New-Object System.Management.Automation.PSCredential($script:AutotaskAPIUser, $(ConvertTo-SecureString $script:AutotaskAPISecret -AsPlainText -Force))
  Add-AutotaskAPIAuth -ApiIntegrationcode "$($script:AutotaskIntegratorID)" -credentials $Creds
  #Get Company and Ticket Resources
  #$companies = Get-AutotaskAPIResource -resource Companies -SimpleSearch "isactive eq $true"
  foreach ($company in $script:CompanyDetails) {
    write-host "`r`n$($script:strLineSeparator)`r`nCOMPANY : $($company.CompanyName)"
    write-host "COMPANY TYPE : $($script:typeMap[[int]$($company.CompanyType)])`r`n$($script:strLineSeparator)"
    $script:diag += "`r`n$($script:strLineSeparator)`r`nID : $($company.CompanyID)`r`n"
    $script:diag += "TYPE : $($script:typeMap[[int]$($company.CompanyType)])`r`n"
    $script:diag += "COMPANY : $($company.CompanyName)`r`n"
    $script:diag += "CATEGORY : $($script:categoryMap[$($company.CompanyCategory)])`r`n"
    $script:diag += "CLASSIFICATION : $($script:classMap[$($company.CompanyClass)])`r`n"
    $script:diag += "$($script:strLineSeparator)`r`n"
    if (($($script:typeMap[[int]$($company.CompanyType)]) -ne "Dead") -and 
      ($($script:typeMap[[int]$($company.CompanyType)]) -ne "Vendor") -and
      ($($script:typeMap[[int]$($company.CompanyType)]) -ne "Partner") -and
      ($($script:typeMap[[int]$($company.CompanyType)]) -ne "Lead") -and 
      ($($script:typeMap[[int]$($company.CompanyType)]) -ne "Cancelation")) {
        write-host "$($strLineSeparator)`r`nProcessing $($company.CompanyName)" -foregroundcolor green
        $script:diag += "`r`n$($strLineSeparator)`r`nProcessing $($company.CompanyName)"
        $assetFields = PSA-Query $psaHeaders "GET" "ConfigurationItems/entityInformation/fields"
        #Get PSA Manufacturer Data Map
        $assetMakes = Get-ATFieldHash -name "rmmDeviceAuditManufacturerID" -fieldsIn $assetFields
        $script:diag += "`r`n$($assetMakes) | out-string"
        #Get PSA Model Data Map
        $assetModels = Get-ATFieldHash -name "rmmDeviceAuditModelID" -fieldsIn $assetFields
        $script:diag += "`r`n$($assetModels) | out-string"
        $script:psaCalls += 1
        $psaAssetFilter = "{`"Filter`":[{`"op`":`"and`",`"items`":[
          {`"field`":`"IsActive`",`"op`":`"eq`",`"value`":true},
          {`"field`":`"companyID`",`"op`":`"eq`",`"value`":$($company.CompanyID)}]}]}"
        $configitems = $null
        $configitems = Get-AutotaskAPIResource -Resource ConfigurationItems -SearchQuery "$($psaAssetFilter)"
        #USELESS PROPERTIES : dattoInternalIP, dattoSerialNumber, rMMDeviceAuditOperatingSystem
        $custAssets = $null
        $custAssets = $configitems | 
          where {$_.companyID -eq $company.CompanyID} | 
            select id, referenceNumber, referenceTitle, serialNumber, rmmDeviceID, rmmDeviceUID, 
              rmmDeviceAuditManufacturerID, rmmDeviceAuditModelID, rmmDeviceAuditDeviceTypeID, 
              rmmDeviceAuditIPAddress, rmmDeviceAuditMacAddress, dattoHostname
        $outAssets = $null
        $outAssets = foreach ($psaAsset in $custAssets) {
          $assetMake = $assetMakes["$($psaAsset.rmmDeviceAuditManufacturerID)"]
          $assetModel = $assetModels["$($psaAsset.rmmDeviceAuditModelID)"]
          [PSCustomObject]@{
            'RMMLink'     = "<p class=`"callout callout-info`"><button type=`"button`" style=`"background-color: #B5B5B5;font-size: 16px;`"><a target=`"_blank`" href=`"https://concord.rmm.datto.com/device/$($psaAsset.rmmDeviceID)`"><b>Open $($psaAsset.referenceTitle) in RMM</b></a></button></p>"
            'PSALink'     =	"<p class=`"callout callout-info`"><button type=`"button`" style=`"background-color: #B5B5B5;font-size: 16px;`"><a target=`"_blank`" href=`"$($AutotaskRoot)$($AutotaskDev)$($psaAsset.id)`"><b>Open $($psaAsset.referenceTitle) in PSA</b></a></button></p>"
            'make'        = $assetMake
            'model'       = $assetModel
            'ModelLink'   =	"<p class=`"callout callout-info`"><button type=`"button`" style=`"background-color: #B5B5B5;font-size: 16px;`"><a target=`"_blank`" href=`"http://www.google.com/search?hl=en&q=$($assetMake)+$($assetModel)`"><b>$($assetMake) $($assetModel)</b></a></button></p>"
            'SerialLink'  =	"<p class=`"callout callout-info`"><button type=`"button`" style=`"background-color: #B5B5B5;font-size: 16px;`"><a target=`"_blank`" href=`"http://www.google.com/search?hl=en&q=$($assetMake)+$($psaAsset.serialNumber)`"><b>$($assetMake) $($psaAsset.serialNumber)</b></a></button></p>"
            'dattoHost'   =	$psaAsset.dattoHostname
            'refNumber'   =	$psaAsset.referenceNumber
            'refTitle'    =	$psaAsset.referenceTitle
            'rmmID'       =	$psaAsset.rmmDeviceID
            'rmmUID'      =	$psaAsset.rmmDeviceUID
            'serial'      =	$psaAsset.serialNumber
            'rmmTypeID'   = $psaAsset.rmmDeviceAuditDeviceTypeID
            'rmmModelID'  = $psaAsset.rmmDeviceAuditModelID
            'rmmDevIP'    = $psaAsset.rmmDeviceAuditIPAddress
            'rmmDevMAC'   = $psaAsset.rmmDeviceAuditMacAddress
          }
        }
        write-host "$($strLineSeparator)`r`nCustomer Assets :`r`nCollected $(@($outAssets).count) Assets`r`n$($strLineSeparator)"
        $script:diag += "`r`n$($strLineSeparator)`r`nCustomer Assets :`r`nCollected $(@($outAssets).count) Assets`r`n$($strLineSeparator)"
        if (@($outAssets).count -gt 0) {
          $test = [System.Net.WebUtility]::HtmlDecode(($outAssets | 
            select-object 'RMMLink', 'PSALink', 'make', 'model', 'ModelLink', 'dattoSerial', 'SerialLink', 
              'dattoHost', 'refNumber', 'refTitle', 'rmmID', 'rmmUID', 'serial', 'rmmTypeID', 'rmmModelID', 'rmmInIP', 'rmmDevIP', 'rmmDevMAC' | 
                convertto-html -fragment | out-string) -replace $TableStylingGood)
          $huduCompany = Get-HuduCompanies -Name "$($company.CompanyName)"
          foreach ($psaAsset in $outAssets) {
            if ((($null -ne $psaAsset.rmmTypeID) -and ($psaAsset.rmmTypeID -ne "")) -and 
              (($null -ne $psaAsset.refTitle) -and ($psaAsset.refTitle -ne ""))) {
                write-host "Type : $($psaAsset.rmmTypeID)`r`nName : $($psaAsset.refTitle)"
                write-host "Make : $($psaAsset.make)`r`nModel : $($psaAsset.model)`r`nModel ID : $($psaAsset.rmmModelID)"
                write-host "MAC : $($psaAsset.rmmDevMAC)`r`nDevice IP : $($psaAsset.rmmDevIP)"
                $script:diag += "`r`nType : $($psaAsset.rmmTypeID)`r`nName : $($psaAsset.refTitle)"
                $script:diag += "`r`nMake : $($psaAsset.make)`r`nModel : $($psaAsset.model)`r`nModel ID : $($psaAsset.rmmModelID)"
                $script:diag += "`r`nMAC : $($psaAsset.rmmDevMAC)`r`nDevice IP : $($psaAsset.rmmDevIP)"
                $type = switch ($psaAsset.rmmTypeID) {
                  1   {'Workstation'}
                  2   {'Workstation'}
                  3   {'Server'}
                  6   {'Printers'}
                  7   {'Network - AP'}
                  9   {'Network - Switch'}
                  10  {'Network - Router'}
                  11  {'UPS'}
                  12  {'Unkown'}
                  15  {'Network - NAS/SAN'}
                }
                if (($type -ne "UPS") -and ($type -ne "Network Appliance") -and ($type -ne "Unkown")) {
                  try {
                    write-host "Accessing $($psaAsset.refTitle) Hudu Asset in $($huduCompany.name)($($huduCompany.id))"
                    $AssetLayout = Get-HuduAssetLayouts -name "$($type)"
                    $Asset = Get-HuduAssets -name "$($psaAsset.refTitle)" -companyid $huduCompany.id -assetlayoutid $AssetLayout.id
                    if (($Asset | measure-object).count -ne 1) {
                      write-host "$($strLineSeparator)`r`nNo / multiple layout(s) found with name $($psaAsset.refTitle)"
                      $script:diag += "`r`n$($strLineSeparator)`r`nNo / multiple layout(s) found with name $($psaAsset.refTitle)"
                    } #else {
                    if ($Asset) {
                      if (($type -eq "Workstation") -or ($type -eq "Server")) {
                        $AssetFields = @{
                          'control_tools'         = "$($psaAsset.RMMLink)$($psaAsset.PSALink)"
                          'asset_location'        = ($Asset.fields | where-object -filter {$_.label -eq "Asset Location"}).value
                          'manufacturer'          = $psaAsset.make
                          'model'                 = $psaAsset.model
                          'model_lookup'          = $psaAsset.ModelLink
                          'serial_number'         = ($Asset.fields | where-object -filter {$_.label -eq "Serial Number"}).value
                          'serial_lookup'         = $psaAsset.SerialLink
                          'has_notes'             = ($Asset.fields | where-object -filter {$_.label -eq "Has Notes"}).value
                          'mac_address'           = $psaAsset.rmmDevMAC #($Asset.fields | where-object -filter {$_.label -eq "MAC Address"}).value
                          'ip_address'            = $psaAsset.rmmDevIP #($Asset.fields | where-object -filter {$_.label -eq "IP Address"}).value
                          'gateway'               = ($Asset.fields | where-object -filter {$_.label -eq "Gateway"}).value
                          'subnet'                = ($Asset.fields | where-object -filter {$_.label -eq "Subnet"}).value
                          'smart_enabled_in_bios' = ($Asset.fields | where-object -filter {$_.label -eq "SMART Enabled In BIOS"}).value
                          'backup_dash'           = ($Asset.fields | where-object -filter {$_.label -eq "Backup Dash"}).value
                          'notes'                 = ($Asset.fields | where-object -filter {$_.label -eq "Notes"}).value
                        }
                      } elseif (($type -ne "Workstation") -and ($type -ne "Server")) {
                        $AssetFields = @{
                          'control_tools'         = "$($psaAsset.RMMLink)$($psaAsset.PSALink)"
                          'asset_location'        = ($Asset.fields | where-object -filter {$_.label -eq "Asset Location"}).value
                          'manufacturer'          = $psaAsset.make
                          'model'                 = $psaAsset.model
                          'model_lookup'          = $psaAsset.ModelLink
                          'serial_number'         = ($Asset.fields | where-object -filter {$_.label -eq "Serial Number"}).value
                          'serial_lookup'         = $psaAsset.SerialLink
                          'has_notes'             = ($Asset.fields | where-object -filter {$_.label -eq "Has Notes"}).value
                          'mac_address'           = $psaAsset.rmmDevMAC #($Asset.fields | where-object -filter {$_.label -eq "MAC Address"}).value
                          'ip_address'            = $psaAsset.rmmDevIP #($Asset.fields | where-object -filter {$_.label -eq "IP Address"}).value
                          'gateway'               = ($Asset.fields | where-object -filter {$_.label -eq "Gateway"}).value
                          'subnet'                = ($Asset.fields | where-object -filter {$_.label -eq "Subnet"}).value
                          'notes'                 = ($Asset.fields | where-object -filter {$_.label -eq "Notes"}).value
                        }
                      }
                      $AssetFields
                      try {
                        $script:huduCalls += 1
                        write-host "$($strLineSeparator)`r`nUpdating $($type) Asset $($Asset.name)`r`n$($strLineSeparator)"
                        $script:diag += "`r`n$($strLineSeparator)`r`nUpdating $($type) Asset $($Asset.name)`r`n$($strLineSeparator)"
                        $Asset = Set-HuduAsset -asset_id $Asset.id -name "$($psaAsset.refTitle)" -company_id $huduCompany.id -assetlayoutid $AssetLayout.id -fields $AssetFields
                      } catch {
                        write-host "$($strLineSeparator)`r`nError Updating $($type) Asset - $($Asset.name)`r`n$($strLineSeparator)" -foregroundcolor red
                        write-host  "$($_.Exception)"
                        write-host  "$($_.scriptstacktrace)"
                        write-host  "`$($_)"
                        $script:diag += "$($strLineSeparator)`r`nError Updating $($type) Asset - $($Asset.name)`r`n$($strLineSeparator)"
                      }
                    }
                  } catch {
                    write-host "$($strLineSeparator)`r`nError retrieving Hudu Asset - $($psaAsset.refTitle)`r`n$($strLineSeparator)" -foregroundcolor red
                    write-host  "$($_.Exception)"
                    write-host  "$($_.scriptstacktrace)"
                    write-host  "`$($_)"
                    $script:diag += "`r`n$($strLineSeparator)`r`nError retrieving Hudu Asset - $($psaAsset.refTitle)`r`n$($strLineSeparator)"
                  }
                }
            }
          }
        }
        $script:psaCalls += 1
        $resourceValues
        $tickets = Get-AutotaskAPIResource -Resource Tickets -SearchQuery "$($TicketFilter)"
        $resources = PSA-FilterQuery $psaHeaders "GET" "Resources" $psaGenFilter
        $custTickets = $tickets | 
          where {$_.companyID -eq $company.CompanyID} | 
            select id, ticketNUmber, createdate, title, description, dueDateTime, assignedResourceID, lastActivityPersonType, lastCustomerVisibleActivityDateTime, priority, source, status, issueType, subIssueType, ticketType
        if (@($custTickets).count -gt 0) {
          $outTickets = foreach ($ticket in $custTickets) {
            $tech = $resources.items | where {$_.id -eq $ticket.assignedResourceID} | select firstName, lastName
            write-host "TEST RESOURCE : $($tech.firstName) $($tech.lastName)"
            [PSCustomObject]@{
              'Ticket-Number'   =	"<a target=`"_blank`" href=`"$($AutotaskRoot)$($AutotaskExe)$($ticket.ticketNumber)`">$($ticket.ticketNumber)</a>"
              'Created'         =	$ticket.createdate
              'Title'           =	$ticket.title
              'Due'             =	$ticket.dueDateTime
              'Resource'        = "$($tech.firstName) $($tech.lastName)"
              'Last-Updater'    =	$creatorValues["$($ticket.lastActivityPersonType)"]
              'Last-Update'     =	$ticket.lastCustomerVisibleActivityDateTime
              'Priority'        =	$priorityValues["$($ticket.priority)"]
              'Source'          =	$sourceValues["$($ticket.source)"]
              'Status'          =	$statusValues["$($ticket.status)"]
              'Type'            =	$issueValues["$($ticket.issueType)"]
              'Sub-Type'        =	$subissueValues["$($ticket.subIssueType)"]
              'Ticket-Type'     =	$typeValues["$($ticket.ticketType)"]
              'Company'         =	$company.CompanyName
            }
          }
          write-host "$($strLineSeparator)`r`nCustomer Tickets :`r`nCollected $(@($outTickets).count) Tickets`r`n$($strLineSeparator)"
          $script:diag += "`r`n$($strLineSeparator)`r`nCustomer Tickets :`r`nCollected $(@($outTickets).count) Tickets`r`n$($strLineSeparator)"
          $shade = "success"
          $reportDate = get-date
          $MagicMessage = "$(@($outTickets).count) Open Tickets"
          $overdue = @($outTickets | where {[Datetime](Get-Date -Date $_.Due) -lt [Datetime]$reportDate}).count
          if ($overdue -ge 1) {
            $shade = "warning"
            $MagicMessage = "$overdue / $(@($outTickets).count) Tickets Overdue"
            $overdueTickets = $outTickets | where {[Datetime](Get-Date -Date $_.Due) -le [Datetime]$reportDate}
            foreach ($odticket in $overdueTickets) {$null = $GlobalOverdue.add($odticket)}	
            $outTickets = $outTickets | where {[Datetime](Get-Date -Date $_.Due) -gt [Datetime]$reportDate}
            $overdueHTML = [System.Net.WebUtility]::HtmlDecode(($overdueTickets | 
              select 'Ticket-Number', 'Created', 'Title', 'Due', 'Resource', 'Last-Updater', 'Last-Update', 
                'Priority', 'Source', 'Status', 'Type', 'Sub-Type', 'Ticket-Type' | 
                  convertto-html -fragment | out-string) -replace $TableStylingBad)
            $goodHTML = [System.Net.WebUtility]::HtmlDecode(($outTickets | 
              select 'Ticket-Number', 'Created', 'Title', 'Due', 'Resource', 'Last-Updater', 'Last-Update', 
                'Priority', 'Source', 'Status', 'Type', 'Sub-Type', 'Ticket-Type' | 
                  convertto-html -fragment | out-string) -replace $TableStylingGood)
            $body = "<h4>Report last updated: $($reportDate)</h4><h2>Overdue Tickets:</h2><figure class=`"table`">$($overdueHTML)</figure>"
            $body = "$($body)<h2>Tickets:</h2><figure class=`"table`">$($goodhtml)</figure>"
          } else {
            $goodHTML = [System.Net.WebUtility]::HtmlDecode(($outTickets | 
              select 'Ticket-Number', 'Created', 'Title', 'Due', 'Resource', 'Last-Updater', 'Last-Update', 
                'Priority', 'Source', 'Status', 'Type', 'Sub-Type', 'Ticket-Type' | 
                  convertto-html -fragment | out-string) -replace $TableStylingGood)
            $body = "<h4>Report last updated: $($reportDate)</h4><h2>Tickets:</h2><figure class=`"table`">$($goodHTML)</figure>"
          }

          if ($overdue -ge 2) {$shade = "danger"}
          try {
            $script:huduCalls += 1
            $Huduresult = Set-HuduMagicDash -title "Autotask - Open Tickets" -company_name "$(($company.CompanyName).Trim())" -message "$($MagicMessage)" -icon "fas fa-chart-pie" -content "$($body)" -shade "$($shade)" -ea stop
            write-host "Autotask Magic Dash Set`r`n$($strLineSeparator)"
            $script:diag += "`r`nAutotask Magic Dash Set`r`n$($strLineSeparator)"
          } catch {
            write-host "$(($company.CompanyName).Trim()) not found in Hudu or other error occured`r`n$($strLineSeparator)"
            write-host  "$($_.Exception)"
            write-host  "$($_.scriptstacktrace)"
            write-host  "`$($_)"
            $script:diag += "`r`n$(($company.CompanyName).Trim()) not found in Hudu or other error occured`r`n$($strLineSeparator)"
          }
        } else {
          try {
            $script:huduCalls += 1
            $Huduresult = Set-HuduMagicDash -title "Autotask - Open Tickets" -company_name "$(($company.companyName).Trim())" -message "No Open Tickets" -icon "fas fa-chart-pie" -shade "success" -ea stop
            write-host "Autotask Magic Dash Set`r`n$($strLineSeparator)"
            $script:diag += "`r`nAutotask Magic Dash Set`r`n$($strLineSeparator)"
          } catch {
            write-host "$(($company.CompanyName).Trim()) not found in Hudu or other error occured`r`n$($strLineSeparator)"
            write-host  "$($_.Exception)"
            write-host  "$($_.scriptstacktrace)"
            write-host  "`$($_)"
            $script:diag += "`r`n$(($company.CompanyName).Trim()) not found in Hudu or other error occured`r`n$($strLineSeparator)"
          }
        }
    }
  }
  #Create Global Overdue Ticket Report
  if ($CreateAllOverdueTicketsReport -eq $true) {
    $articleHTML = [System.Net.WebUtility]::HtmlDecode($($GlobalOverdue | 
      select 'Ticket-Number', 'Company', 'Title', 'Due', 'Resource', 'Last-Update', 'Priority', 'Status' | 
        Sort-object Company | convertto-html -fragment | out-string))
    $reportDate = get-date
    $body = "<h4>Report last updated: $($reportDate)</h4><figure class=`"table`">$($articleHTML)</figure>"
    #Check if an article already exists
    $script:huduCalls += 1
    $article = Get-HuduArticles -name $globalReportName
    if ($article) {
      $script:huduCalls += 1
      $result = Set-HuduArticle -name $globalReportName -content $body -folder_id $folderID -article_id $article.id
      write-host "$($strLineSeparator)`r`nUpdated Autotask Global Report`r`n$($strLineSeparator)"
      $script:diag += "`r`n$($strLineSeparator)`r`nUpdated Autotask Global Report`r`n$($strLineSeparator)"
    } else {
      $script:huduCalls += 1
      $result = New-HuduArticle -name $globalReportName -content $body -folder_id $folderID
      write-host "$($strLineSeparator)`r`nCreated Autotask Global Report`r`n$($strLineSeparator)"
      $script:diag += "`r`n$($strLineSeparator)`r`nCreated Autotask Global Report`r`n$($strLineSeparator)"
    }
  }
  #DATTO OUTPUT
  #Stop script execution time calculation
  StopClock
  #CLEAR LOGFILE
  $null | set-content $logPath -force
  if (-not $script:blnWARN) {
    #WRITE TO LOGFILE
    $script:diag += "`r`n`r`nHuduDoc_WatchDog : Execution Successful"
    "$($script:diag)" | add-content $logPath -force
    write-DRMMAlert "HuduDoc_WatchDog : Execution Successful"
    #write-DRMMDiag "$($script:diag)"
    $script:diag = $null
    exit 0
  } elseif ($script:blnWARN) {
    #WRITE TO LOGFILE
    $script:diag += "`r`n`r`nHuduDoc_WatchDog : Execution Completed with Warnings : See Diagnostics"
    "$($script:diag)" | add-content $logPath -force
    write-DRMMAlert "HuduDoc_WatchDog : Execution Completed with Warnings : See Diagnostics"
    #write-DRMMDiag "$($script:diag)"
    $script:diag = $null
    exit 1
  }
} elseif ($script:blnBREAK) {
  #Stop script execution time calculation
  StopClock
  #CLEAR LOGFILE
  $null | set-content $logPath -force
  #WRITE TO LOGFILE
  $script:diag += "`r`n`r`nHuduDoc_WatchDog : Execution Failure : See Diagnostics"
  "$($script:diag)" | add-content $logPath -force
  write-DRMMAlert "HuduDoc_WatchDog : Execution Failure : See Diagnostics"
  write-DRMMDiag "$($script:diag)"
  $script:diag = $null
  exit 1
}
#END SCRIPT
#------------