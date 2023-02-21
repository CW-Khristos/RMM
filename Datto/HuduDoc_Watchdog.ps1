<#
.SYNOPSIS 
    Modification of AutoTask and Customer Services MagicDash to integrate NAble / Cove Data Protection
    Combines AutoTask and Customer Services MagicDash and DNS History enhancements to Hudu

.DESCRIPTION 
    Modification of AutoTask and Customer Services MagicDash to integrate NAble / Cove Data Protection
    Pulls and refreshes appropriate Customer NAble / Cove Data Protection Dashboard
    Combines AutoTask and Customer Services MagicDash and DNS History enhancements to Hudu
 
.NOTES
    Version                  : 0.1.3 (20 February 2022)
    Creation Date            : 23 August 2022
    Purpose/Change           : Modification of AutoTask and Customer Services MagicDash to integrate NAble / Cove Data Protection
                               https://mspp.io/hudu-datto-psa-autotask-open-tickets-magic-dash/
                               https://mspp.io/hudu-magic-dash-customer-services/
                               https://mspp.io/hudu-dns-history-and-alerts/
    File Name                : HuduDoc_Watchdog.ps1
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
    0.1.3 Dealing with minor bugs, erro handling, output formatting
          Major Optimizations in reducing number of subsequent AT and Hudu API Calls
          Reduction of AT API Calls :
           - Tested and confirmed more efficient and faster to retrieve filtered set of "all" Tickets vs filtering for each Company
           - Tested and confirmed more efficient and faster to retrieve filtered set of "active" Assets vs filtering for each Company
          Reduction of Hudu API Calls :
           - Switched to collecting each relevant Asset Layout once for the entire script; previously this was done as each was required
          Timing Tweaks :
           - Added 1/4 second delay when encountering Companies which will be "Skipped" in Processing; this was to create some time buffer between Hudu requests
           - Added 10 millisecond delay when encountering Assets which will be accessing Hudu Assets during Processing
           - Target Runtime :: < 30min - Current Runtime :: 26 Minutes : 5 Seconds : 282 Milliseconds
             Total Companies : 266
              - Processed : 99 - Skipped : 167 - Failed : 0
             Total Tickets : 177
              - Processed : 177 - Skipped : 0 - Failed : 0
             Total Assets : 1404
              - Processed : 1334 - Skipped : 70 - Failed : 12
To Do:

#>
#Add this CSS to Admin -> Design -> Custom CSS
# .custom-fast-fact.custom-fast-fact--warning {
#     background: #f5c086;
# }
#First Clear any variables
#Remove-Variable * -ErrorAction SilentlyContinue
#region ----- DECLARATIONS ----
  $script:diag            = $null
  $script:blnWARN         = $false
  $script:blnBREAK        = $false
  $logPath                = "C:\IT\Log\HuduDoc_Watchdog"
  $strLineSeparator       = "----------------------------------"
  $timestamp              = "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))"
  ######################### TLS Settings ###########################
  [System.Net.ServicePointManager]::MaxServicePointIdleTime = 5000000
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  #region######################## Hudu Settings ###########################
  $script:huduCalls       = 0
  #HUDU DATASETS
  $huduLayouts            = $null
  $Layouts                = @(
    "Customer Management",
    "DNS Entries - Autodoc",
    "Printers",
    "Network - AP",
    "Network - NAS/SAN",
    "Network - Switch",
    "Network - Router",
    "Server",
    "UPS",
    "Unknown",
    "Workstation")
  # Get a Hudu API Key from https://yourhududomain.com/admin/api_keys
  $script:HuduAPIKey      = $env:HuduKey
  # Set the base domain of your Hudu instance without a trailing /
  $script:HuduBaseDomain  = $env:HuduDomain
  #endregion
  #region####################### Customer Management ##########################
  $SplitChar              = ":"
  $ManagementLayoutName   = "Customer Management"
  $AllowedActions         = @(
    "ENABLED",
    "NOTE",
    "URL")
  $FieldTiles             = @(
    "BACKUP",
    "FW",
    "NETWORK",
    "EMAIL",
    "ANTI-SPAM",
    "BACKUPIFY",
    "AV",
    "VOICE",
    "MSA")
  #endregion
  #region####################### DNS Settings ##########################
  $script:dnsCalls        = 0
  $DNSHistoryLayoutName   = "DNS Entries - Autodoc"
  # Enable sending alerts on dns change to a teams webhook
  $enableTeamsAlerts      = $false
  #$teamsWebhook          = "Your Teams Webhook URL"
  # Enable sending alerts on dns change to an email address
  $enableEmailAlerts      = $false
  #$mailTo                = "alerts@domain.com"
  #$mailFrom              = "alerts@domain.com"
  #$mailServer            = "mailserver.domain.com"
  #$mailPort              = "25"
  $mailUseSSL             = $false
  #$mailUser              = "user"
  #$mailPass              = "pass"
  #endregion
  #region####################### Backups Settings ##########################
  $script:bmCalls         = 0
  $script:blnBM           = $false
  $script:bmRoot          = $env:BackupRoot
  $script:bmUser          = $env:BackupUser
  $script:bmPass          = $env:BackupPass
  $Filter1                = "AT == 1 AND PN != 'Documents'"   ### Excludes M365 and Documents devices from lookup
  $urlJSON                = "https://api.backup.management/jsonapi"
  #endregion
  #region####################### Backupify Settings ##########################
  $script:buCalls         = 0
  #endregion
  #region######################## Autotask Settings ###########################
  $script:psaCalls        = 0
  #PSA API DATASETS
  $script:typeMap         = @{
    1 = "Customer"
    2 = "Lead"
    3 = "Prospect"
    4 = "Dead"
    6 = "Cancelation"
    7 = "Vendor"
    8 = "Partner"
  }
  $script:classMap        = @{}
  $script:categoryMap     = @{}
  $GlobalOverdue          = [System.Collections.ArrayList]@()
  #PSA API URLS
  $AutotaskRoot           = $env:ATRoot
  $AutoTaskAPIBase        = $env:ATAPIBase
  $AutotaskExe            = "/Autotask/AutotaskExtend/ExecuteCommand.aspx?Code=OpenTicketDetail&TicketNumber="
  $AutotaskDev            = "/Autotask/AutotaskExtend/AutotaskCommand.aspx?&Code=OpenInstalledProduct&InstalledProductID="
  #PSA API FILTERS
  $ExcludeType            = '[]'
  $ExcludeQueue           = '[]'
  #EXCLUDE STATUSES : 5 - COMPLETED , 20 - RMM RESOLVED
  $ExcludeStatus          = '[5,20]'
  $psaGenFilter           = '{"Filter":[{"field":"Id","op":"gte","value":0}]}'
  $psaActFilter           = '{"Filter":[{"op":"and","items":[{"field":"IsActive","op":"eq","value":true},{"field":"Id","op":"gte","value":0}]}]}'
  $TicketFilter           = "{`"Filter`":[{`"op`":`"notin`",`"field`":`"queueID`",`"value`":$($ExcludeQueue)},{`"op`":`"notin`",`"field`":`"status`",`"value`":$($ExcludeStatus)},{`"op`":`"notin`",`"field`":`"ticketType`",`"value`":$($ExcludeType)}]}"
  ########################### Autotask Auth ##############################
  $script:AutotaskAPIUser         = $env:ATAPIUser
  $script:AutotaskAPISecret       = $env:ATAPISecret
  $script:AutotaskIntegratorID    = $env:ATIntegratorID
  $script:psaHeaders              = @{
    'ApiIntegrationCode'          = "$($script:AutotaskIntegratorID)"
    'UserName'                    = "$($script:AutotaskAPIUser)"
    'Secret'                      = "$($script:AutotaskAPISecret)"
  }
  ##################### Autotask Report Settings ########################
  $folderID                       = 2
  $CreateAllOverdueTicketsReport  = $true
  $globalReportName               = "Autotask - Overdue Ticket Report"
  $TableStylingBad                = "<th>", "<th style=`"background-color:#f8d1d3`">"
  $TableStylingGood               = "<th>", "<th style=`"background-color:#aeeab4`">"
  #endregion
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
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - HuduDoc_WatchDog - NO ARGUMENTS PASSED, END SCRIPT`r`n`r`n"
        write-host "$($strLineSeparator)`r`n$($(get-date)) - HuduDoc_WatchDog - NO ARGUMENTS PASSED, END SCRIPT`r`n" -foregroundcolor red
      }
      2 {                                                         #'ERRRET'=2 - INSTALL / IMPORT MODULE FAILURE, END SCRIPT
        $script:blnBREAK = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - HuduDoc_WatchDog - ($($strModule)) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n"
        write-host "$($strLineSeparator)`r`n$($(get-date)) - HuduDoc_WatchDog - ($($strModule)) :" -foregroundcolor red
        write-host "$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n" -foregroundcolor red
      }
      {3,4} {                                                     #'ERRRET'=3 & 4
        $script:blnWARN = $false
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - HuduDoc_WatchDog - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
        write-host "$($strLineSeparator)`r`n$($(get-date)) - HuduDoc_WatchDog - $($strModule) :" -foregroundcolor yellow
        write-host "$($strLineSeparator)`r`n`t$($strErr)" -foregroundcolor yellow
      }
      default {                                                   #'ERRRET'=5+
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - HuduDoc_WatchDog - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
        write-host "$($strLineSeparator)`r`n$($(get-date)) - HuduDoc_WatchDog - $($strModule) :" -foregroundcolor yellow
        write-host "$($strLineSeparator)`r`n`t$($strErr)" -foregroundcolor red
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
    $totalCalls = ($script:psaCalls + $script:bmCalls + $script:buCalls + $script:huduCalls + $script:dnsCalls)
    #TOTAL AVERAGE
    $average = ($total / $totalCalls)
    $secs = [string]($total / 1000)
    $mill = $secs.split(".")[1]
    $secs = $secs.split(".")[0]
    $mill = $mill.SubString(0,[math]::min(3,$mill.length))
    $asecs = [string]($average / 1000)
    $amill = $asecs.split(".")[1]
    $asecs = $asecs.split(".")[0]
    $amill = $amill.SubString(0,[math]::min(3,$mill.length))
    #HUDU AVERAGE CALLS (PER MIN)
    $avgHudu = [math]::Round(($script:huduCalls / $Minutes))
    #DISPLAY API THRESHOLDS
    $psa = PSA-GetThreshold $script:psaHeaders
    write-host "`r`nAPI Calls :`r`nPSA API : $($script:psaCalls) - Hudu API : $($script:huduCalls)"
    write-host "Backup.Management API : $($script:bmCalls) - Backupify Calls : $($script:buCalls)"
    write-host "DNS Calls : $($script:dnsCalls)"
    write-host "API Limits - PSA API (per Hour) : $($psa.currentTimeframeRequestCount) / $($psa.externalRequestThreshold)"
    write-host "API Limits - Hudu API (per Minute) : 300"
    write-host "Total Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds"
    $script:diag += "`r`nAPI Calls :`r`nPSA API : $($script:psaCalls) - Hudu API : $($script:huduCalls)"
    $script:diag += "`r`nBackup.Management API : $($script:bmCalls) - Backupify Calls : $($script:buCalls)"
    $script:diag += "`r`nDNS Calls : $($script:dnsCalls)"
    $script:diag += "`r`nAPI Limits :`r`nPSA API (per Hour) : $($psa.currentTimeframeRequestCount) / $($psa.externalRequestThreshold)"
    $script:diag += "`r`nAPI Limits - Hudu API (per Minute) : $($avgHudu) / 300"
    $script:diag += "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
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
    #$script:psaCalls += 1
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
    try {
      $script:psaCalls += 1
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
    try {
      $script:psaCalls += 1
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
      $bmdiag = "Passed Partner: $($bmPartner)"
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
        $bmdiag = "$($SelectedDevices.AccountId.count) Devices Selected`r`n$($strLineSeparator)"
        logERR 4 "Set-BackupDash" "$($bmdiag)"
      } elseif (-not $i_AllDevices) {
        if (($null -ne $i_BackupID) -and ($i_BackupID -ne "")) {
          $script:SelectedDevices = $script:BackupsDetails | 
            Select-Object PartnerId,PartnerName,AccountID,ComputerName,DeviceName,OS,IPMGUIPwd,
              TimeStamp,LastSuccess,Product,DataSources,SelectedGB,UsedGB,Location,Notes | 
                Where-object {$_.DeviceName -eq $i_BackupID}
          $bmdiag = "$($SelectedDevices.AccountId.count) Devices Selected`r`n$($strLineSeparator)"
          logERR 4 "Set-BackupDash" "$($bmdiag)"
        }
      }    

      if (@($script:SelectedDevices).count -gt 0) {
        # OK was pressed, $Selection contains what was chosen
        # Run OK script
        $selected = $script:SelectedDevices | 
          Select-Object PartnerId,PartnerName,@{Name="AccountID"; Expression={[int]$_.AccountId}},ComputerName,DeviceName,OS,IPMGUIPwd,
            TimeStamp,LastSuccess,Product,DataSources,SelectedGB,UsedGB,Location,Notes | 
              Sort-object AccountId | Format-Table | out-string
        write-host "`r`n$($strLineSeparator)`r`n$($selected)`r`n$($strLineSeparator)`r`n"
        $badHTML = $null
        $goodHTML = $null
        $shade = "success"
        $reportDate = get-date
        $MagicMessage = "$(@($script:SelectedDevices).count) Protected Devices"
        $overdue = @($script:SelectedDevices | 
            where {(get-date -date "$($_.TimeStamp)") -lt $reportDate.AddDays(-1)} | 
              select PartnerId,PartnerName,AccountID,ComputerName,DeviceName,OS,IPMGUIPwd,
                TimeStamp,LastSuccess,Product,DataSources,SelectedGB,UsedGB,Location,Notes).count
        #Update 'Tile' Shade based on Overdue Backups
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
        #Update 'Tile' Shade based on Overdue Backups
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
          $bmdiag = "Backup Magic Dash Set`r`n$($strLineSeparator)"
          logERR 4 "Set-BackupDash" "$($bmdiag)"
          $arrayAssets = @("Server","Workstation")
          foreach ($type in $arrayAssets) {
            # Get the Asset Layout
            #$script:huduCalls += 1
            $AssetLayout = $huduLayouts | where {$_.name -match "$($type)"} #Get-HuduAssetLayouts -name "$($type)"
            # Check we found the layout
            if (($AssetLayout | measure-object).count -le 0) {
              $bmdiag = "No layout(s) found in $($type)`r`n$($strLineSeparator)"
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
                    $bmdiag = "Updated $($AssetName) in $($i_Company) $($type) Assets`r`n$($strLineSeparator)"
                    logERR 4 "Set-BackupDash" "$($bmdiag)"
                    $script:huduCalls += 1
                  } catch {
                    $bmdiag = "Error Updating $($AssetName) in $($i_Company) $($type) Assets`r`n$($strLineSeparator)"
                    $bmdiag += "`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
                    logERR 4 "Set-BackupDash" "$($bmdiag)"
                  }
                }
              }
            }
          }
        } catch {
          $bmdiag = "$($i_Company) not found in Hudu or other error occured`r`n$($strLineSeparator)"
          $bmdiag += "`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
          logERR 4 "Set-BackupDash" "$($bmdiag)"
        }
      } else {
        try {
          $script:huduCalls += 1
          $Huduresult = Set-HuduMagicDash -title "Backup - $($i_Note)" -company_name "$($i_Company)" -message "No Backups Found" -icon "fas fa-chart-pie" -shade "grey" -ea stop
          write-host "`r`n$($strLineSeparator)`r`n`tNo Devices Selected`r`n$($strLineSeparator)`r`n"
          $bmdiag = "Backup Magic Dash Set`r`n$($strLineSeparator)"
          logERR 4 "Set-BackupDash" "$($bmdiag)"
        } catch {
          $bmdiag = "$($i_Company) not found in Hudu or other error occured`r`n$($strLineSeparator)"
          $bmdiag += "`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
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
        $bmdiag = "FAILED TO LOGIN TO BACKUP.MANAGEMENT - $($(get-date))`r`n$($strLineSeparator)"
        $bmdiag += "`r`nBackup Magic Dash Set`r`n$($strLineSeparator)"
        logERR 4 "Set-BackupDash" "$($bmdiag)"
      } catch {
        $bmdiag = "$($i_Company)) not found in Hudu or other error occured`r`n$($strLineSeparator)"
        $bmdiag += "`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
        logERR 4 "Set-BackupDash" "$($bmdiag)"
      }
    }
  }
#endregion ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
clear-host
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
Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
#INSTALL NUGET PROVIDER
if (-not (Get-PackageProvider -name NuGet)) {
  Install-PackageProvider -Name NuGet -Force -Confirm:$false
}
#INSTALL POWERSHELLGET MODULE
if (Get-Module -ListAvailable -Name PowershellGet) {
  Import-Module PowershellGet 
} else {
  Install-Module PowershellGet -Force -Confirm:$false
  Import-Module PowershellGet
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
  #Gather Hudu Layouts Only Once
  $huduLayouts = foreach ($huduLayout in $Layouts) {Get-HuduAssetLayouts -name "$($huduLayout)"}
  #region######################## Autotask  Section ###########################
  # https://mspp.io/hudu-datto-psa-autotask-open-tickets-magic-dash/
  #QUERY PSA API
  logERR 3 "Autotask Processing" "Beginning Autotask Processing`r`n$($strLineSeparator)"
  #Autotask Auth
  $script:psaCalls += 1
  $Creds = New-Object System.Management.Automation.PSCredential($script:AutotaskAPIUser, $(ConvertTo-SecureString $script:AutotaskAPISecret -AsPlainText -Force))
  Add-AutotaskAPIAuth -ApiIntegrationcode "$($script:AutotaskIntegratorID)" -credentials $Creds
  #Get Company Classifications and Categories
  logERR 3 "Autotask Retrieval" "CLASS MAP :`r`n$($strLineSeparator)"
  PSA-GetMaps $script:psaHeaders $script:classMap "ClassificationIcons"
  $script:classMap
  write-host "$($strLineSeparator)`r`nDone`r`n$($strLineSeparator)"
  $script:diag += "`r`n$($strLineSeparator)`r`nDone`r`n$($strLineSeparator)`r`n"
  logERR 3 "Autotask Retrieval" "CATEGORY MAP :`r`n$($strLineSeparator)"
  PSA-GetMaps $script:psaHeaders $script:categoryMap "CompanyCategories"
  $script:categoryMap
  write-host "$($strLineSeparator)`r`nDone`r`n$($strLineSeparator)"
  $script:diag += "`r`n$($strLineSeparator)`r`nDone`r`n$($strLineSeparator)`r`n"
  #Get Companies, Tickets, and Resources
  logERR 3 "Autotask Retrieval" "COMPANIES :`r`n$($strLineSeparator)"
  PSA-GetCompanies $script:psaHeaders
  write-host "Done`r`n$($strLineSeparator)"
  $script:diag += "`r`nDone`r`n$($strLineSeparator)`r`n"
  $script:psaCalls += 1
  logERR 3 "Autotask Retrieval" "TICKETS :`r`n$($strLineSeparator)"
  $tickets = Get-AutotaskAPIResource -Resource Tickets -SearchQuery "$($TicketFilter)"
  #$tickets = PSA-FilterQuery $script:psaHeaders "GET" "Tickets" $TicketFilter
  write-host "Done`r`n$($strLineSeparator)"
  $script:diag += "`r`nDone`r`n$($strLineSeparator)`r`n"
  #Get Ticket Fields
  logERR 3 "Autotask Retrieval" "TICKET FIELDS :`r`n$($strLineSeparator)"
  $ticketFields = PSA-Query $script:psaHeaders "GET" "Tickets/entityInformation/fields"
  #Get Statuses
  $statusValues = Get-ATFieldHash -name "status" -fieldsIn $ticketFields
  if (!$ExcludeStatus) {
    write-host "ExcludeStatus not set please exclude your closed statuses at least from below in the format of '[1,5,7,9]'"
    $script:diag += "`r`nExcludeStatus not set please exclude your closed statuses at least from below in the format of '[1,5,7,9]'"
    $statusValues | ft
  }
  #Get Ticket types
  $typeValues = Get-ATFieldHash -name "ticketType" -fieldsIn $ticketFields
  if (!$ExcludeType) {
    write-host "ExcludeType not set please exclude types from below in the format of '[1,5,7,9]"
    $script:diag += "`r`nExcludeType not set please exclude types from below in the format of '[1,5,7,9]"
    $typeValues | ft
  }
  #Get Queue Types
  $queueValues = Get-ATFieldHash -name "queueID" -fieldsIn $ticketFields
  if (!$ExcludeType) {
    write-host "ExcludeQueue not set please exclude types from below in the format of '[1,5,7,9]"
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
  write-host "Done`r`n$($strLineSeparator)"
  $script:diag += "`r`nDone`r`n$($strLineSeparator)`r`n"
  #$resourceValues
  logERR 3 "Autotask Retrieval" "RESOURCES :`r`n$($strLineSeparator)"
  $resources = PSA-FilterQuery $script:psaHeaders "GET" "Resources" $psaGenFilter
  write-host "Done`r`n$($strLineSeparator)"
  $script:diag += "`r`nDone`r`n$($strLineSeparator)`r`n"
  #Grab All Assets for All Companies in a Single Call
  $configitems = $null
  $script:psaCalls += 1
  logERR 3 "Autotask Retrieval" "PSA ASSETS :`r`n$($strLineSeparator)"
  $psaAssetFilter = "{`"Filter`":[{`"field`":`"IsActive`",`"op`":`"eq`",`"value`":true}]}"
  $configitems = Get-AutotaskAPIResource -Resource ConfigurationItems -SearchQuery "$($psaAssetFilter)"
  write-host "Done`r`n$($strLineSeparator)"
  $script:diag += "`r`nDone`r`n$($strLineSeparator)`r`n"
  #Get PSA Asset Fields
  logERR 3 "Autotask Retrieval" "ASSET FIELDS :`r`n$($strLineSeparator)"
  $assetFields = PSA-Query $script:psaHeaders "GET" "ConfigurationItems/entityInformation/fields"
  #Get PSA Asset Manufacturer Data Map
  $assetMakes = Get-ATFieldHash -name "rmmDeviceAuditManufacturerID" -fieldsIn $assetFields
  #Get PSA Asset Model Data Map
  $assetModels = Get-ATFieldHash -name "rmmDeviceAuditModelID" -fieldsIn $assetFields
  write-host "Done`r`n$($strLineSeparator)"
  $script:diag += "`r`nDone`r`n$($strLineSeparator)`r`n"
  #region###############    PSA Counters - Tallied for All Companies
  $totCompany = 0
  $procCompany = 0
  $skipCompany = 0
  $failCompany = 0
  $totPSAassets = 0
  $procPSAassets = 0
  $skipPSAassets = 0
  $failPSAassets = 0
  $totPSAtickets = 0
  $procPSAtickets = 0
  $skipPSAtickets = 0
  $failPSAtickets = 0
  #endregion
  #region###############    Enumerate through each Company retrieved from PSA
  logERR 3 "Autotask Processing" "PROCESSING COMPANIES :`r`n$($strLineSeparator)"
  foreach ($company in $script:CompanyDetails) {
    $psadiag = "COMPANY : $($company.CompanyName)`r`n`tCOMPANY TYPE : "
    $psadiag += "$($script:typeMap[[int]$($company.CompanyType)])`r`n$($script:strLineSeparator)"
    logERR 3 "Autotask Processing" "$($psadiag)"
    $script:diag += "`r`n$($script:strLineSeparator)`r`nID : $($company.CompanyID)`r`n"
    $script:diag += "CATEGORY : $($script:categoryMap[$($company.CompanyCategory)])`r`n"
    $script:diag += "CLASSIFICATION : $($script:classMap[$($company.CompanyClass)])`r`n$($script:strLineSeparator)"
    if (($($script:typeMap[[int]$($company.CompanyType)]) -ne "Dead") -and 
      ($($script:typeMap[[int]$($company.CompanyType)]) -ne "Vendor") -and
      ($($script:typeMap[[int]$($company.CompanyType)]) -ne "Partner") -and
      ($($script:typeMap[[int]$($company.CompanyType)]) -ne "Lead") -and 
      ($($script:typeMap[[int]$($company.CompanyType)]) -ne "Cancelation")) {
        #region###############    Company Counters - Reset to '0' with each Company
        $procCoAssets = 0
        $skipCoAssets = 0
        $failCoAssets = 0
        $procCoTickets = 0
        $skipCoTickets = 0
        $failCoTickets = 0
        #endregion
        write-host "`r`n$($strLineSeparator)`r`nProcessing $($company.CompanyName)`r`n$($strLineSeparator)" -foregroundcolor green
        $script:diag += "`r`n`r`n$($strLineSeparator)`r`nProcessing $($company.CompanyName)`r`n$($strLineSeparator)`r`n"
        #Find Company in Hudu
        $script:huduCalls += 1
        $huduCompany = Get-HuduCompanies -Name "$($company.CompanyName)"
        #region###############    Arrange collected Ticket data for Hudu
        $custTickets = $tickets | 
          where {$_.companyID -eq $company.CompanyID} | 
            select id, ticketNUmber, createdate, title, description, dueDateTime, assignedResourceID, lastActivityPersonType, lastCustomerVisibleActivityDateTime, priority, source, status, issueType, subIssueType, ticketType
        if (@($custTickets).count -gt 0) {
          $outTickets = foreach ($ticket in $custTickets) {
            $procCoTickets += 1
            $procPSAtickets += 1
            #Retrieve Assigned Resource for Tickets
            $tech = $resources.items | where {$_.id -eq $ticket.assignedResourceID} | select firstName, lastName
            #write-host "TEST RESOURCE : $($tech.firstName) $($tech.lastName)"
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
          $shade = "success"
          $reportDate = get-date
          $MagicMessage = "$(@($outTickets).count) Open Tickets"
          write-host "Customer Tickets :`r`nCollected $(@($outTickets).count) Tickets`r`n$($strLineSeparator)"
          $script:diag += "Customer Tickets :`r`nCollected $(@($outTickets).count) Tickets`r`n$($strLineSeparator)"
          $overdue = @($outTickets | where {[Datetime](Get-Date -Date $_.Due) -lt [Datetime]$reportDate}).count
          #Update 'Tile' Shade based on Overdue Tickets
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
          #Update 'Tile' Shade based on Overdue Tickets
          if ($overdue -ge 2) {$shade = "danger"}
          try {
            $script:huduCalls += 1
            $Huduresult = Set-HuduMagicDash -title "Autotask - Open Tickets" -company_name "$(($company.CompanyName).Trim())" -message "$($MagicMessage)" -icon "fas fa-chart-pie" -content "$($body)" -shade "$($shade)" -ea stop
            $psadiag = "Autotask Magic Dash Set`r`n$($strLineSeparator)"
            logERR 3 "Set Autotask MagicDash" "$($psadiag)"
          } catch {
            $psadiag = "$(($company.CompanyName).Trim()) not found in Hudu or other error occured`r`n$($strLineSeparator)`r`n"
            $psadiag += "$($strLineSeparator)`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
            logERR 3 "Set Autotask MagicDash" "$($psadiag)"
            $procPSAtickets += -($procCoTickets)
            $failPSAtickets += $procCoTickets
            $failCoTickets += $procCoTickets
            $procCoTickets = 0
          }
        } else {
          try {
            $script:huduCalls += 1
            $Huduresult = Set-HuduMagicDash -title "Autotask - Open Tickets" -company_name "$(($company.companyName).Trim())" -message "No Open Tickets" -icon "fas fa-chart-pie" -shade "success" -ea stop
            $psadiag = "Autotask Magic Dash Set`r`n$($strLineSeparator)"
            logERR 3 "Set Autotask MagicDash" "$($psadiag)"
          } catch {
            $psadiag = "$(($company.CompanyName).Trim()) not found in Hudu or other error occured`r`n$($strLineSeparator)`r`n"
            $psadiag += "$($strLineSeparator)`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
            logERR 3 "Set Autotask MagicDash" "$($psadiag)"
            $procPSAtickets += -($procCoTickets)
            $failPSAtickets += $procCoTickets
            $failCoTickets += $procCoTickets
            $procCoTickets = 0
          }
        }
        #endregion
        #region###############    Filter PSA Assets to Company
        #Arrange collected Asset data for Hudu
        #USELESS PROPERTIES : dattoInternalIP, dattoSerialNumber, rMMDeviceAuditOperatingSystem
        $custAssets = $null
        $custAssets = foreach ($psaAsset in ($configitems | 
          where {$_.companyID -eq $company.CompanyID} | 
            select id, referenceNumber, referenceTitle, serialNumber, rmmDeviceID, rmmDeviceUID, 
              rmmDeviceAuditManufacturerID, rmmDeviceAuditModelID, rmmDeviceAuditDeviceTypeID, 
              rmmDeviceAuditIPAddress, rmmDeviceAuditMacAddress, dattoHostname)) {
                  $totPSAassets += 1
                  $assetMake = $assetMakes["$($psaAsset.rmmDeviceAuditManufacturerID)"]
                  $assetModel = $assetModels["$($psaAsset.rmmDeviceAuditModelID)"]
                  [PSCustomObject]@{
                    'RMMLink'     = "<p class=`"callout callout-info`"><button type=`"button`" style=`"background-color: #B5B5B5;font-size: 16px;`">
                      <a target=`"_blank`" href=`"https://concord.rmm.datto.com/device/$($psaAsset.rmmDeviceID)`">
                      <b>Open $($psaAsset.referenceTitle) in RMM</b></a></button></p>"
                    'PSALink'     =	"<p class=`"callout callout-info`"><button type=`"button`" style=`"background-color: #B5B5B5;font-size: 16px;`">
                      <a target=`"_blank`" href=`"$($AutotaskRoot)$($AutotaskDev)$($psaAsset.id)`">
                      <b>Open $($psaAsset.referenceTitle) in PSA</b></a></button></p>"
                    'make'        = $assetMake
                    'model'       = $assetModel
                    'ModelLink'   =	"<p class=`"callout callout-info`"><button type=`"button`" style=`"background-color: #B5B5B5;font-size: 16px;`">
                      <a target=`"_blank`" href=`"http://www.google.com/search?hl=en&q=$($assetMake)+$($assetModel)`">
                      <b>$($assetMake) $($assetModel)</b></a></button></p>"
                    'SerialLink'  =	"<p class=`"callout callout-info`"><button type=`"button`" style=`"background-color: #B5B5B5;font-size: 16px;`">
                      <a target=`"_blank`" href=`"http://www.google.com/search?hl=en&q=$($assetMake)+$($psaAsset.serialNumber)`">
                      <b>$($assetMake) $($psaAsset.serialNumber)</b></a></button></p>"
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
        write-host "$($strLineSeparator)`r`nCustomer Assets :`r`nCollected $(@($custAssets).count) Assets`r`n$($strLineSeparator)"
        $script:diag += "`r`n$($strLineSeparator)`r`nCustomer Assets :`r`nCollected $(@($custAssets).count) Assets`r`n$($strLineSeparator)"
        if (@($custAssets).count -gt 0) {
          $test = [System.Net.WebUtility]::HtmlDecode(($custAssets | 
            select-object 'RMMLink', 'PSALink', 'make', 'model', 'ModelLink', 'dattoSerial', 'SerialLink', 
              'dattoHost', 'refNumber', 'refTitle', 'rmmID', 'rmmUID', 'serial', 'rmmTypeID', 'rmmModelID', 'rmmInIP', 'rmmDevIP', 'rmmDevMAC' | 
                convertto-html -fragment | out-string) -replace $TableStylingGood)
          foreach ($psaAsset in $custAssets) {
            if ((($null -ne $psaAsset.rmmTypeID) -and ($psaAsset.rmmTypeID -ne "")) -and 
              (($null -ne $psaAsset.refTitle) -and ($psaAsset.refTitle -ne ""))) {
                #Map rmmTypeID to Hudu Asset Types
                $type = switch ($psaAsset.rmmTypeID) {
                  1   {'Workstation'}
                  2   {'Workstation'}
                  3   {'Server'}
                  6   {'Printers'}
                  7   {'Network - AP'}
                  9   {'Network - Switch'}
                  10  {'Network - Router'}
                  11  {'UPS'}
                  12  {'Unknown'}
                  15  {'Network - NAS/SAN'}
                }
                write-host "$($strLineSeparator)`r`nProcessing $($type) Asset $($Asset.name)`r`n$($strLineSeparator)"
                write-host "Type : $($psaAsset.rmmTypeID)`r`nName : $($psaAsset.refTitle)"
                write-host "Make : $($psaAsset.make)`r`nModel : $($psaAsset.model)`r`nModel ID : $($psaAsset.rmmModelID)"
                write-host "S/N : $($psaAsset.serial)`r`nMAC : $($psaAsset.rmmDevMAC)`r`nDevice IP : $($psaAsset.rmmDevIP)"
                $script:diag += "`r`n$($strLineSeparator)`r`nProcessing $($type) Asset $($Asset.name)`r`n$($strLineSeparator)"
                $script:diag += "`r`nType : $($psaAsset.rmmTypeID)`r`nName : $($psaAsset.refTitle)"
                $script:diag += "`r`nMake : $($psaAsset.make)`r`nModel : $($psaAsset.model)`r`nModel ID : $($psaAsset.rmmModelID)"
                $script:diag += "`r`nS/N : $($psaAsset.serial)`r`nMAC : $($psaAsset.rmmDevMAC)`r`nDevice IP : $($psaAsset.rmmDevIP)"
                if (($type -ne "UPS") -and ($type -ne "Network Appliance") -and ($type -ne "Unkown")) {
                  try {
                    start-sleep -milliseconds 10
                    #Attempt to find Asset Layout and PSA Asset in Hudu
                    $script:huduCalls += 1 #2
                    write-host "Accessing $($psaAsset.refTitle) Hudu Asset in $($huduCompany.name)($($huduCompany.id))"
                    $AssetLayout = $huduLayouts | where {$_.name -match "$($type)"} #Get-HuduAssetLayouts -name "$($type)"
                    $Asset = Get-HuduAssets -name "$($psaAsset.refTitle)" -companyid $huduCompany.id -assetlayoutid $AssetLayout.id
                    if (($Asset | measure-object).count -ne 1) {
                      $psadiag = "No / multiple layout(s) found with Name : $($psaAsset.refTitle)`r`n$($strLineSeparator)"
                      logERR 3 "Update PSA Asset" "$($psadiag)"
                      try {
                        $Asset = Get-HuduAssets -name "$($psaAsset.refTitle)" -companyid $huduCompany.id -assetlayoutid $AssetLayout.id -primaryserial "$($psaAsset.serial)"
                        if (($Asset | measure-object).count -ne 1) {
                          $psadiag = "No / multiple layout(s) found with Name : $($psaAsset.refTitle) - Serial : $($psaAsset.serial)`r`n$($strLineSeparator)"
                          logERR 3 "Update PSA Asset" "$($psadiag)"
                          write-host "Skipped`r`n$($strLineSeparator)" -foregroundcolor yellow
                          $script:diag += "`r`mSkipped`r`n$($strLineSeparator)"
                          $skipPSAassets += 1
                          $skipCoAssets += 1
                        }
                      } catch {
                        $psadiag = "Error retrieving Hudu Asset - $($psaAsset.refTitle)`r`n$($strLineSeparator)`r`n"
                        $psadiag += "$($strLineSeparator)`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)`r`n"
                        logERR 3 "Retrieve Hudu PSA Asset" "$($psadiag)"
                        $failPSAassets += 1
                        $failCoAssets += 1
                      }
                    } #else {
                    if (($Asset | measure-object).count -eq 1) {
                      if (($type -eq "Workstation") -or ($type -eq "Server")) {
                        $AssetFields = @{
                          'control_tools'         = "$($psaAsset.RMMLink)$($psaAsset.PSALink)"
                          'asset_location'        = ($Asset.fields | where-object -filter {$_.label -eq "Asset Location"}).value
                          'manufacturer'          = $psaAsset.make
                          'model'                 = $psaAsset.model
                          'model_lookup'          = $psaAsset.ModelLink
                          'serial_number'         = $psaAsset.serial
                          'serial_lookup'         = $psaAsset.SerialLink
                          'has_notes'             = if ($null -eq ($Asset.fields | where-object -filter {$_.label -eq "Has Notes"}).value) {
                                                      $false
                                                    } else {
                                                      ($Asset.fields | where-object -filter {$_.label -eq "Has Notes"}).value
                                                    }
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
                          'serial_number'         = $psaAsset.serial
                          'serial_lookup'         = $psaAsset.SerialLink
                          'has_notes'             = if ($null -eq ($Asset.fields | where-object -filter {$_.label -eq "Has Notes"}).value) {
                                                      $false
                                                    } else {
                                                      ($Asset.fields | where-object -filter {$_.label -eq "Has Notes"}).value
                                                    }
                          'mac_address'           = $psaAsset.rmmDevMAC #($Asset.fields | where-object -filter {$_.label -eq "MAC Address"}).value
                          'ip_address'            = $psaAsset.rmmDevIP #($Asset.fields | where-object -filter {$_.label -eq "IP Address"}).value
                          'gateway'               = ($Asset.fields | where-object -filter {$_.label -eq "Gateway"}).value
                          'subnet'                = ($Asset.fields | where-object -filter {$_.label -eq "Subnet"}).value
                          'notes'                 = ($Asset.fields | where-object -filter {$_.label -eq "Notes"}).value
                        }
                      }
                      #$AssetFields | out-string
                      try {
                        $script:huduCalls += 1
                        write-host "$($AssetFields | out-string)$($strLineSeparator)`r`nUpdating $($type) Asset $($Asset.name)`r`n$($strLineSeparator)`r`n"
                        $script:diag += "`r`n$($AssetFields | out-string))$($strLineSeparator)`r`nUpdating $($type) Asset $($Asset.name)`r`n$($strLineSeparator)"
                        $Asset = Set-HuduAsset -asset_id $Asset.id -name "$($psaAsset.refTitle)" -company_id $huduCompany.id -assetlayoutid $AssetLayout.id -fields $AssetFields
                        $procPSAassets += 1
                        $procCoAssets += 1
                      } catch {
                        $psadiag = "Error Updating $($type) Asset - $($Asset.name)`r`n$($strLineSeparator)`r`n"
                        $psadiag += "$($strLineSeparator)`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)`r`n"
                        logERR 3 "Update PSA Asset" "$($psadiag)"
                        $failPSAassets += 1
                        $failCoAssets += 1
                      }
                    }
                  } catch {
                    $psadiag = "Error retrieving Hudu Asset - $($psaAsset.refTitle)`r`n$($strLineSeparator)`r`n"
                    $psadiag += "$($strLineSeparator)`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)`r`n"
                    logERR 3 "Retrieve Hudu PSA Asset" "$($psadiag)"
                    $failPSAassets += 1
                    $failCoAssets += 1
                  }
                }
            }
          }
        }
        #endregion
        $psadiag = "Finished`r`n$($strLineSeparator)"
        logERR 3 "Autotask Processing" "$($psadiag)"
        $procCompany += 1
    } else {
      write-host "$($strLineSeparator)`r`nSkipped`r`n$($strLineSeparator)" -foregroundcolor yellow
      $script:diag += "`r`m$($strLineSeparator)`r`nSkipped`r`n$($strLineSeparator)"
      #$psadiag = "Skipped`r`n$($strLineSeparator)"
      #logERR 3 "Autotask Processing" "$($psadiag)"
      $skipCompany += 1
      start-sleep -milliseconds 250
    }
  }
  write-host "Done`r`n$($strLineSeparator)"
  $script:diag += "`r`nDone`r`n$($strLineSeparator)`r`n"
  #endregion
  #Create Global Overdue Ticket Report
  if ($CreateAllOverdueTicketsReport -eq $true) {
    $reportDate = get-date
    $articleHTML = [System.Net.WebUtility]::HtmlDecode($($GlobalOverdue | 
      select 'Ticket-Number', 'Company', 'Title', 'Due', 'Resource', 'Last-Update', 'Priority', 'Status' | 
        Sort-object Company | convertto-html -fragment | out-string))
    $body = "<h4>Report last updated: $($reportDate)</h4><figure class=`"table`">$($articleHTML)</figure>"
    #Check if an article already exists
    $script:huduCalls += 2
    $article = Get-HuduArticles -name $globalReportName
    if ($article) {
      $result = Set-HuduArticle -name $globalReportName -content $body -folder_id $folderID -article_id $article.id
      $psadiag = "Updated Autotask Global Report`r`n$($strLineSeparator)"
      logERR 3 "Global Overdue Tickets" "$($psadiag)"
    } else {
      $result = New-HuduArticle -name $globalReportName -content $body -folder_id $folderID
      $psadiag = "Created Autotask Global Report`r`n$($strLineSeparator)"
      logERR 3 "Global Overdue Tickets" "$($psadiag)"
    }
  }
  $psadiag = "Autotask Processing : Completed`r`n$($strLineSeparator)`r`n"
  $psadiag += "Total Companies : $(@($script:CompanyDetails).count)`r`n"
  $psadiag += "`t- Processed : $($procCompany) - Skipped : $($skipCompany) - Failed : $($failCompany)`r`n"
  $psadiag += "Total Tickets : $(@($tickets).count)`r`n"
  $psadiag += "`t- Processed : $($procPSAtickets) - Skipped : $($skipPSAtickets) - Failed : $($failPSAtickets)`r`n"
  $psadiag += "Total Assets : $($totPSAassets)`r`n"
  $psadiag += "`t- Processed : $($procPSAassets) - Skipped : $($skipPSAassets) - Failed : $($failPSAassets)`r`n$($strLineSeparator)"
  logERR 3 "Autotask Processing" "$($psadiag)"
  #endregion
  #region######################## Customer Management Section ###########################
  # https://mspp.io/hudu-magic-dash-customer-services/
  logERR 3 "Customer Management" "Beginning Customer Management Processing`r`n$($strLineSeparator)"
  # Get the Asset Layout
  #$script:huduCalls += 1
  $DetailsLayout = $huduLayouts | where {$_.name -match "$($ManagementLayoutName)"} #Get-HuduAssetLayouts -name $ManagementLayoutName
  # Check we found the layout
  if (($DetailsLayout | measure-object).count -ne 1) {
    logERR 3 "Customer Management" "No / multiple layout(s) found with name $($ManagementLayoutName)`r`n$($strLineSeparator)"
  } else {
    # Get all the detail assets and loop
    $script:huduCalls += 1
    $DetailsAssets = Get-HuduAssets -assetlayoutid $DetailsLayout.id | Sort-Object -Property company_name
    foreach ($Asset in $DetailsAssets) {
      write-host "`r`n$($strLineSeparator)`r`nProcessing $($Asset.company_name) Managed Services`r`n$($strLineSeparator)"
      $script:diag += "`r`n`r`n$($strLineSeparator)`r`nProcessing $($Asset.company_name) Managed Services`r`n$($strLineSeparator)"
      # Return relevant Asset Fields
      $Fields = foreach ($field in $FieldTiles) {
        $Asset.fields | where {$($_.label).toupper() -match "$($field):"} | foreach {
          $SplitField = $_.label -split $SplitChar
          # Check the field has an allowed action.
          if ($SplitField[1] -notin $AllowedActions) {
            logERR 3 "Customer ManageMent" "Field $($_.label) is not an allowed action`r`n$($strLineSeparator)"
          } else {
            [PSCustomObject]@{
              ServiceName   = $SplitField[0]
              ServiceAction = $SplitField[1]
              Value         = $_.value
            }
          }
        }
      }
      foreach ($Service in $Fields.ServiceName | select-object -unique) {
        write-host "`r`n$($strLineSeparator)`r`nFields :`r`n$($strLineSeparator)"
        $EnabledField = $Fields | Where-Object {$_.ServiceName -eq $Service -and $_.ServiceAction -eq 'ENABLED'}
        write-host "$($strLineSeparator)`r`nEnabledField :`r`n$($EnabledField)"
        $NoteField = $Fields | Where-Object {$_.ServiceName -eq $Service -and $_.ServiceAction -eq 'NOTE'}
        write-host "NoteField :`r`n$($NoteField)"
        $URLField = $Fields | Where-Object {$_.ServiceName -eq $Service -and $_.ServiceAction -eq 'URL'}
        write-host "URLField :`r`n$($URLField)`r`n$($strLineSeparator)"
        if ($EnabledField) {
          logERR 3 "Customer Management" "Enabled Field found`r`n$($strLineSeparator)"
        } else {
          $EnabledField.value = $false
          logERR 3 "Customer Management" "No Enabled Field was found`r`n$($strLineSeparator)"
        }
        $Colour = switch ($EnabledField.value) {
          $true {'success'}
          $false {'grey'}
          default {'grey'}
        }
        $Param = @{
          Title = "$($Service)"
          CompanyName = "$($Asset.company_name)"
          Shade = "$($Colour)"
        }
        if ($NoteField.value){
            $Param['Message'] = "$($NoteField.value)"
            $Param | Add-Member -MemberType NoteProperty -Name 'Message' -Value "$($NoteField.value)"
        } else {
          $Param['Message'] = switch ($EnabledField.value) {
            $true {"Customer has $($Service)"}
            $false {"No $($Service)"}
            default {"No $($Service)"}
          }
        }
        if (($URLField.value) -and ($Service -ne "Backup")) {
          $Param['ContentLink'] = "$($URLField.value)"
        }
        if ($Service -ne "Backup") {
          $script:huduCalls += 1
          Set-HuduMagicDash @Param
          write-host "$($strLineSeparator)"
          logERR 3 "Customer Management" "$($Service) Magic Dash Set`r`n$($strLineSeparator)"
        } elseif ($Service -eq "Backup") {
          switch ($EnabledField.value) {
            $true {Set-BackupDash "$($Asset.company_name)" $Asset.company_id $false $true "$($NoteField.value)" "$($URLField.value)" $null}
            $false {$script:huduCalls += 1; Set-HuduMagicDash @Param}
          }
        }
      }
    }
  }
  write-host "Done`r`n$($strLineSeparator)"
  $script:diag += "`r`nDone`r`n$($strLineSeparator)`r`n"
  #endregion
  #region######################## DNS History Section ###########################
  # https://mspp.io/hudu-dns-history-and-alerts/
  logERR 3 "DNS History" "Beginning DNS History Processing`r`n$($strLineSeparator)"
  #$script:huduCalls += 1
  $DNSLayout = $huduLayouts | where {$_.name -match "$($DNSHistoryLayoutName)"} #Get-HuduAssetLayouts -name $DNSHistoryLayoutName
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
    #$script:huduCalls += 1 #2
    logERR 3 "DNS History" "Missing DNS Asset Layout $($DNSHistoryLayoutName)`r`n$($strLineSeparator)"
    #$NewLayout = New-HuduAssetLayout -name $DNSHistoryLayoutName -icon "fas fa-sitemap" -color "#00adef" -icon_color "#ffffff" -include_passwords $true -include_photos $false -include_comments $true -include_files $true -fields $AssetLayoutFields
    #$DNSLayout = $huduLayouts | where {$_.name -match "$($DNSHistoryLayoutName)"} #Get-HuduAssetLayouts -name $DNSHistoryLayoutName
  } elseif ($DNSLayout) {
    $script:huduCalls += 1
    $websites = Get-HuduWebsites | where -filter {$_.disable_dns -eq $false} | Sort-Object -Property company_name
    foreach ($website in $websites) {
      $dnsname = ([System.Uri]$website.name).authority
      write-host "$($strLineSeparator)`r`nResolving $($dnsname) for $($website.company_name)"
      $script:diag += "`r`n$($strLineSeparator)`r`nResolving $($dnsname) for $($website.company_name)"
      try {
        $script:dnsCalls += 5
        $arecords = resolve-dnsname "$($dnsname)" -type "A_AAAA" -ErrorAction Stop | select type, IPADDRESS | sort IPADDRESS | convertto-html -fragment | out-string
        $mxrecords = resolve-dnsname "$($dnsname)" -type "MX" -ErrorAction Stop | sort NameExchange |convertto-html -fragment -property NameExchange | out-string
        $nsrecords = resolve-dnsname "$($dnsname)" -type "NS" -ErrorAction Stop | sort NameHost | convertto-html -fragment -property NameHost| out-string
        $txtrecords = resolve-dnsname "$($dnsname)" -type "TXT" -ErrorAction Stop | select @{N='Records';E={$($_.strings)}}| sort Records | convertto-html -fragment -property Records | out-string
        $soarecords = resolve-dnsname "$($dnsname)" -type "SOA" -ErrorAction Stop | select PrimaryServer, NameAdministrator, SerialNumber | sort NameAdministrator | convertto-html -fragment | out-string
      } catch {
        $err = "$($dnsname) lookup failed`r`n$($strLineSeparator)`r`n"
        $err += "$($strLineSeparator)`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
        logERR 3 "DNS Lookup" "$($err)"
        continue
      }

      $AssetFields = @{
        'a_and_aaaa_records'  = $arecords
        'mx_records'          = $mxrecords
        'name_servers'        = $nsrecords
        'txt_records'         = $txtrecords
        'soa_records'         = $soarecords                      
      }
      $script:huduCalls += 1
      #Swap out # as Hudu doesn't like it when searching
      $AssetName = "$($dnsname)"
      $companyid = $website.company_id
      $script:diag += "`r`n$($strLineSeparator)`r`n$($dnsname) lookup successful"
      write-host "$($strLineSeparator)`r`n$($dnsname) lookup successful" -foregroundcolor green
      #Check if there is already an asset
      $Asset = Get-HuduAssets -name "$($AssetName)" -companyid $companyid -assetlayoutid $DNSLayout.id
      #If the Asset does not exist, we edit the body to be in the form of a new asset, if not, we just upload.
      if (!$Asset) {
        try {
          $script:huduCalls += 1
          write-host "$($strLineSeparator)`r`nCreating new DNS Asset`r`n$($strLineSeparator)"
          $script:diag += "`r`n$($strLineSeparator)`r`nCreating new DNS Asset`r`n$($strLineSeparator)"
          $Asset = New-HuduAsset -name "$($AssetName)" -company_id $companyid -asset_layout_id $DNSLayout.id -fields $AssetFields
        } catch {
          $err = "Error Creating DNS Asset - $($AssetName)`r`n$($strLineSeparator)`r`n"
          $err += "$($strLineSeparator)`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
          logERR 3 "Create DNS Asset" "$($err)"
        }
      } else {
        <#Get the existing records    --  DISABLED 20230218 - NOT SENDING TEAMS OR EMAIL ALERTS - SHOULD BUILD THIS INTO A MONITOR IF NEEDED
        $a_cur_value = ($Asset.fields | where-object -filter {$_.label -eq "A and AAAA Records"}).value
        $mx_cur_value = ($Asset.fields | where-object -filter {$_.label -eq "MX Records"}).value
        $ns_cur_value = ($Asset.fields | where-object -filter {$_.label -eq "Name Servers"}).value
        $txt_cur_value = ($Asset.fields | where-object -filter {$_.label -eq "TXT Records"}).value
        $soa_cur_value = ($Asset.fields | where-object -filter {$_.label -eq "SOA Records"}).value
        #Compare the new and old values and send alerts
        Check-DNSChange -currentDNS $a_cur_value -newDNS $arecords -recordType "A / AAAA" -website "$($AssetName)" -companyName "$($website.company_name)"
        Check-DNSChange -currentDNS $mx_cur_value -newDNS $mxrecords -recordType "MX" -website "$($AssetName)" -companyName "$($website.company_name)"
        Check-DNSChange -currentDNS $ns_cur_value -newDNS $nsrecords -recordType "Name Servers" -website "$($AssetName)" -companyName "$($website.company_name)"
        Check-DNSChange -currentDNS $txt_cur_value -newDNS $txtrecords -recordType "TXT" -website "$($AssetName)" -companyName "$($website.company_name)"
        #>
        try {
          $script:huduCalls += 1
          write-host "$($strLineSeparator)`r`nUpdating DNS Asset - ID : $($Asset.id)`r`n$($strLineSeparator)"
          $script:diag += "`r`n$($strLineSeparator)`r`nUpdating DNS Asset - ID : $($Asset.id)`r`n$($strLineSeparator)"
          $Asset = Set-HuduAsset -asset_id $Asset.id -name "$($AssetName)" -company_id $companyid -asset_layout_id $DNSLayout.id -fields $AssetFields
        } catch {
          $err = "Error Updating DNS Asset - $($AssetName)`r`n$($strLineSeparator)`r`n"
          $err += "$($strLineSeparator)`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
          logERR 3 "Update DNS Asset" "$($err)"
        }
      }
    }
  }
  write-host "Done`r`n$($strLineSeparator)"
  $script:diag += "`r`nDone`r`n$($strLineSeparator)`r`n"
  #endregion
  #DATTO OUTPUT
  #Stop script execution time calculation
  StopClock
  #CLEAR LOGFILE
  $null | set-content $logPath -force
  if (-not $script:blnWARN) {
    #WRITE TO LOGFILE
    $finish = "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))"
    $enddiag = "`r`n`r`nExecution Successful : $($finish)"
    logERR 3 "HuduDoc_WatchDog" "$($enddiag)"
    "$($script:diag)" | add-content $logPath -force
    write-DRMMAlert "HuduDoc_WatchDog : Successful : Diagnostics - $($logPath) : $($finish)"
    write-DRMMDiag "$($script:diag)"
    exit 0
  } elseif ($script:blnWARN) {
    #WRITE TO LOGFILE
    $finish = "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))"
    $enddiag = "`r`n`r`nExecution Completed with Warnings : $($finish)"
    logERR 3 "HuduDoc_WatchDog" "$($enddiag)"
    "$($script:diag)" | add-content $logPath -force
    write-DRMMAlert "HuduDoc_WatchDog : Warning : Diagnostics - $($logPath) : $($finish)"
    #write-DRMMDiag "$($script:diag)"
    exit 1
  }
} elseif ($script:blnBREAK) {
  #Stop script execution time calculation
  StopClock
  #CLEAR LOGFILE
  $null | set-content $logPath -force
  #WRITE TO LOGFILE
  $finish = "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))"
  $enddiag = "`r`n`r`nExecution Failure : $($finish)"
  logERR 3 "HuduDoc_WatchDog" "$($enddiag)"
  "$($script:diag)" | add-content $logPath -force
  write-DRMMAlert "HuduDoc_WatchDog : Failure : Diagnostics - $($logPath) : $($finish)"
  #write-DRMMDiag "$($script:diag)"
  exit 1
}
#END SCRIPT
#------------