<#
.SYNOPSIS 
    Modification of AutoTask and Customer Services MagicDash to integrate NAble / Cove Data Protection
    Combines AutoTask and Customer Services MagicDash and DNS History enhancements to Hudu

.DESCRIPTION 
    Modification of AutoTask and Customer Services MagicDash to integrate NAble / Cove Data Protection
    Pulls and refreshes appropriate Customer NAble / Cove Data Protection Dashboard and Recovery Verification
    Combines AutoTask and Customer Services MagicDash and DNS History enhancements to Hudu
 
.NOTES
    Version                  : 0.1.5 (05 September 2023)
    Creation Date            : 23 August 2022
    Purpose/Change           : Modification of AutoTask and Customer Services MagicDash to integrate NAble / Cove Data Protection
                               https://mspp.io/hudu-datto-psa-autotask-open-tickets-magic-dash/
                               https://mspp.io/hudu-magic-dash-customer-services/
                               https://mspp.io/hudu-dns-history-and-alerts/
                               https://mspp.io/hudu-warranty-expiration-tracking/
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
    0.1.3 Dealing with minor bugs, error handling, output formatting
          Major Optimizations in reducing number of subsequent AT, Backup.Management, and Hudu API Calls
          Reduction of AT API Calls :
           - Tested and confirmed more efficient and faster to retrieve filtered set of "all" Tickets once vs filtering for each Company each time
           - Tested and confirmed more efficient and faster to retrieve filtered set of "active" Assets once vs filtering for each Company each time
          Reduction of Backup.Management API Calls :
           - Tested and confirmed more efficient and faster to retrieve all Backup Accounts once vs filtering for each Company each time
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
    0.1.4 Added retrieval of Backup.Management Recovery Verification statistics
          Added Revovery Verification statistics to Set-BackupDash function to add Recovery Verification to Backup MagicDash
           - Still need to capture Last Recovery timestamps and status for updating Hudu "Next Verification" field on Backup Assets
To Do:

#>
#Add this CSS to Admin -> Design -> Custom CSS
# .custom-fast-fact.custom-fast-fact--warning {
#     background: #f5c086;
# }
#First Clear any variables
#Remove-Variable * -ErrorAction SilentlyContinue
#region ----- DECLARATIONS ----
  $script:diag                    = $null
  $script:blnWARN                 = $false
  $script:blnBREAK                = $false
  $logPath                        = "C:\IT\Log\HuduDoc_Watchdog"
  $strLineSeparator               = "----------------------------------"
  $timestamp                      = (get-date -format "yyyy-MM-dd HH:mm:ss").ToString()
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
  #region######################## Hudu Settings ###########################
  $script:huduCalls               = 0
  #HUDU DATASETS
  $Layouts                        = @(
    "Customer Management",
    "DNS Entries - Autodoc",
    "Printers",
    "Network - APs",
    "Network - NAS/SAN",
    "Network - Switches",
    "Network - Routers",
    "Servers",
    "UPS",
    "Unknown",
    "Workstations",
    "Sales/Finance")
  $huduLayouts                    = $null
  # Get a Hudu API Key from https://yourhududomain.com/admin/api_keys
  $script:HuduAPIKey              = $env:HuduKey
  # Set the base domain of your Hudu instance without a trailing /
  $script:HuduBaseDomain          = $env:HuduDomain
  #endregion
  #region####################### Customer Management ##########################
  $AllowedActions                 = @(
    "ENABLED",
    "NOTE",
    "URL")
  $FieldTiles                     = @(
    "BACKUP",
    "FW",
    "NETWORK",
    "EMAIL",
    "ANTI-SPAM",
    "BACKUPIFY",
    "AV",
    "VOICE",
    "MSA")
  $SplitChar                      = ":"
  $ManagementLayoutName           = "Customer Management"
  #endregion
  #region####################### DNS Settings ##########################
  $script:dnsCalls                = 0
  # Enable sending alerts on dns change to a teams webhook
  $enableTeamsAlerts              = $false
  #$teamsWebhook                  = "Your Teams Webhook URL"
  # Enable sending alerts on dns change to an email address
  $enableEmailAlerts              = $false
  #$mailTo                        = "alerts@domain.com"
  #$mailFrom                      = "alerts@domain.com"
  #$mailServer                    = "mailserver.domain.com"
  #$mailPort                      = "25"
  $mailUseSSL                     = $false
  #$mailUser                      = "user"
  #$mailPass                      = "pass"
  $DNSHistoryLayoutName           = "DNS Entries - Autodoc"
  #endregion
  #region####################### Sales/Finance Settings ##########################
  $SalesLayoutName                = "Sales/Finance"
  #endregion####################### Sales/Finance Settings ##########################
  #region####################### Backups Settings ##########################
  $script:bmCalls                 = 0
  #region###############    Backups Counters - Tallied for All Companies
  $totBackups                     = 0
  $procBackups                    = 0
  $skipBackups                    = 0
  $failBackups                    = 0
  #endregion
  $script:blnBM                   = $false
  $script:bmRoot                  = $env:BackupRoot
  $script:bmUser                  = $env:BackupUser
  $script:bmPass                  = $env:BackupPass
  $Filter1                        = "AT == 1 AND PN != 'Documents'"   ### Excludes M365 and Documents devices from lookup
  $urlJSON                        = "https://api.backup.management/jsonapi"
  #endregion
  #region####################### Backupify Settings ##########################
  $script:buCalls                 = 0
  #endregion
  #region######################## Autotask Settings ###########################
  $script:psaCalls                = 0
  #region###############    PSA Counters - Tallied for All Companies
  $totCompany                     = 0
  $procCompany                    = 0
  $skipCompany                    = 0
  $failCompany                    = 0
  $totPSAassets                   = 0
  $procPSAassets                  = 0
  $skipPSAassets                  = 0
  $failPSAassets                  = 0
  $totPSAtickets                  = 0
  $procPSAtickets                 = 0
  $skipPSAtickets                 = 0
  $failPSAtickets                 = 0
  #endregion
  #PSA API DATASETS
  $script:typeMap                 = @{
    1 = "Customer"
    2 = "Lead"
    3 = "Prospect"
    4 = "Dead"
    6 = "Cancelation"
    7 = "Vendor"
    8 = "Partner"
  }
  $script:classMap                = @{}
  $script:categoryMap             = @{}
  $script:salesIDs                = @(29682885, 29682895)
  $GlobalOverdue                  = [System.Collections.ArrayList]@()
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
    write-output "<-Start Diagnostic->"
    foreach ($message in $messages) {$message}
    write-output "<-End Diagnostic->"
  } ## write-DRMMDiag
  
  function write-DRMMAlert ($message) {
    write-output "<-Start Result->"
    write-output "Alert=$($message)"
    write-output "<-End Result->"
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
      #'ERRRET'=1 - NOT ENOUGH ARGUMENTS, END SCRIPT
      1 {
        $script:blnBREAK = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - HuduDoc_WatchDog - NO ARGUMENTS PASSED, END SCRIPT`r`n`r`n"
        write-output "$($strLineSeparator)`r`n$($(get-date)) - HuduDoc_WatchDog - NO ARGUMENTS PASSED, END SCRIPT`r`n"
      }
      #'ERRRET'=2 - INSTALL / IMPORT MODULE FAILURE, END SCRIPT
      2 {
        $script:blnBREAK = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - HuduDoc_WatchDog - ($($strModule)) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n"
        write-output "$($strLineSeparator)`r`n$($(get-date)) - HuduDoc_WatchDog - ($($strModule)) :"
        write-output "$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n"
      }
      #'ERRRET'=3 & 4
      {3, 4} {
        $script:blnWARN = $false
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - HuduDoc_WatchDog - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
        write-output "$($strLineSeparator)`r`n$($(get-date)) - HuduDoc_WatchDog - $($strModule) :"
        write-output "$($strLineSeparator)`r`n`t$($strErr)"
      }
      #'ERRRET'=5+
      default {
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - HuduDoc_WatchDog - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
        write-output "$($strLineSeparator)`r`n$($(get-date)) - HuduDoc_WatchDog - $($strModule) :"
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
    $total = ((((($Hours * 60) + $Minutes) * 60) + $Seconds) * 1000) + $Milliseconds
    $totalCalls = ($script:psaCalls + $script:bmCalls + $script:buCalls + $script:huduCalls + $script:dnsCalls)
    #TOTAL AVERAGE
    $average = ($total / $totalCalls)
    $secs = [string]($total / 1000)
    $mill = $secs.split(".")[1]
    $secs = $secs.split(".")[0]
    $mill = $mill.SubString(0, [math]::min(3, $mill.length))
    $asecs = [string]($average / 1000)
    $amill = $asecs.split(".")[1]
    $asecs = $asecs.split(".")[0]
    $amill = $amill.SubString(0, [math]::min(3, $mill.length))
    #HUDU AVERAGE CALLS (PER MIN)
    $avgHudu = [math]::Round(($script:huduCalls / $Minutes))
    #DISPLAY API THRESHOLDS
    $psa = PSA-GetThreshold $script:psaHeaders
    write-output "`r`n$($strLineSeparator)`r`nAPI Calls :`r`nPSA API : $($script:psaCalls) - Hudu API : $($script:huduCalls)"
    write-output "Backup.Management API : $($script:bmCalls) - Backupify Calls : $($script:buCalls)"
    write-output "DNS Calls : $($script:dnsCalls)"
    write-output "$($strLineSeparator)`r`nAPI Limits :$($strLineSeparator)"
    write-output "API Limits - PSA API (per Hour) : $($psa.currentTimeframeRequestCount) / $($psa.externalRequestThreshold)"
    write-output "API Limits - Hudu API (per Minute) : $($avgHudu) / 300`r`n$($strLineSeparator)"
    write-output "Total Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds"
    $script:diag += "`r`n$($strLineSeparator)`r`nAPI Calls :`r`nPSA API : $($script:psaCalls) - Hudu API : $($script:huduCalls)"
    $script:diag += "`r`nBackup.Management API : $($script:bmCalls) - Backupify Calls : $($script:buCalls)"
    $script:diag += "`r`nDNS Calls : $($script:dnsCalls)"
    $script:diag += "`r`n$($strLineSeparator)`r`nAPI Limits :`r`n$($strLineSeparator)"
    $script:diag += "`r`nAPI Limits - PSA API (per Hour) : $($psa.currentTimeframeRequestCount) / $($psa.externalRequestThreshold)"
    $script:diag += "`r`nAPI Limits - Hudu API (per Minute) : $($avgHudu) / 300`r`n$($strLineSeparator)"
    $script:diag += "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
    if ($Minutes -eq 0) {
      write-output "Average Execution Time (Per API Call) - $($Minutes) Minutes : $($asecs) Seconds : $($amill) Milliseconds`r`n$($strLineSeparator)"
      $script:diag += "Average Execution Time (Per API Call) - $($Minutes) Minutes : $($asecs) Seconds : $($amill) Milliseconds`r`n$($strLineSeparator)`r`n"
    } elseif ($Minutes -gt 0) {
      $amin = [string]($asecs / 60)
      $amin = $amin.split(".")[0]
      $amin = $amin.SubString(0, [math]::min(2, $amin.length))
      write-output "Average Execution Time (Per API Call) - $($amin) Minutes : $($asecs) Seconds : $($amill) Milliseconds`r`n$($strLineSeparator)"
      $script:diag += "Average Execution Time (Per API Call) - $($amin) Minutes : $($asecs) Seconds : $($amill) Milliseconds`r`n$($strLineSeparator)`r`n"
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

  function PSA-Put {
    param ($header, $method, $entity, $body)
    $params = @{
      Method      = "$($method)"
      ContentType = 'application/json'
      Uri         = "$($AutoTaskAPIBase)/ATServicesRest/V1.0/$($entity)"
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
        #write-output "$($company.companyName) : $($company.companyType)"
        #write-output "Type Map : $(script:typeMap[[int]$company.companyType])"
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
  function CallBackupsJSON ($url, $object) {
    $script:bmCalls += 1
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($object)
    $web = [System.Net.WebRequest]::Create($url)
    $web.Method = "POST"
    $web.ContentLength = $bytes.Length
    $web.ContentType = "application/json"
    $stream = $web.GetRequestStream()
    $stream.Write($bytes, 0, $bytes.Length)
    $stream.close()
    $reader = New-Object System.IO.Streamreader -ArgumentList $web.GetResponse().GetResponseStream()
    return $reader.ReadToEnd() | ConvertFrom-Json
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

    $RestrictedPartnerLevel = @("Root", "Sub-root", "Distributor")
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
    $data.params.query.Columns = @(
      "AU", "AR", "AN", "MN", "AL", "LN", "OP", "OI", "OS", "PD", "AP", 
      "PF", "PN", "CD", "TS", "TL", "T3", "US", "AA843", "AA77", "AA2531", "I78"
    )
    $data.params.query.OrderBy = "CD DESC"
    $data.params.query.StartRecordNumber = 0
    $data.params.query.RecordsCount = 2000
    $data.params.query.Totals = @("COUNT(AT==1)", "SUM(T3)", "SUM(US)")
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
      $Script:DRStatistics | foreach-object { $_.last_recovery_selected_size = [Math]::Round([Decimal]($($_.last_recovery_selected_size) /1GB), 2) }
      $Script:DRStatistics | foreach-object { $_.last_recovery_restored_size = [Math]::Round([Decimal]($($_.last_recovery_restored_size) /1GB), 2) }
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

  function Check-DNSChange {
    Param (
      [string]$currentDNS = '',
      [string]$newDNS = '',
      [string]$recordType = '',
      [string]$website = '',
      [string]$companyName = ''
    )
    $Comp = Compare-Object -ReferenceObject $($currentDNS -split "`n") -DifferenceObject $($newDNS -split "`n")
    if ($Comp) {
      # Send Teams Alert
      if ($enableTeamsAlerts) {
        $JSONBody = [PSCustomObject][Ordered]@{
          "@type"      = "MessageCard"
          "@context"   = "http://schema.org/extensions"
          "summary"    = "$companyName - $website - DNS $recordType change detected"
          "themeColor" = '0078D7'
          "sections"   = @(@{
            "activityTitle"    = "$companyName - $website - DNS $recordType Change Detected"
            "facts"            = @(
              @{
                "name"  = "Original DNS Records"
                "value" = $((($Comp | where-object -filter {$_.SideIndicator -eq "<="}).InputObject | out-string ) -replace '<[^>]+>', ' ')
              },
              @{
                "name"  = "New DNS Records"
                "value" = $((($Comp | where-object -filter {$_.SideIndicator -eq "=>"}).InputObject | out-string ) -replace '<[^>]+>', ' ')
              }
            )
            "markdown" = $true
          })
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
        $mailSubject = "$($companyName) - $($website) - DNS $($recordType) change detected"
        $body = "
          <h3>$($mailSubject)</h3>
          <p>Original DNS Record:</p>
          <table>
          $($oldVal)
          </table>
          <p>New DNS Record:</p>
          <table>
          $($newVal)
          </table>
          "
        $password = ConvertTo-SecureString $mailPass -AsPlainText -Force
        $mailcred = New-Object System.Management.Automation.PSCredential ($mailUser, $password)
        $sendMailParams = @{
          To          = $mailTo
          From        = $mailFrom
          Subject     = $mailSubject
          Body        = $body
          Credential  = $mailcred
          SMTPServer  = $mailServer
          UseSsl      = $mailUseSSL
        }
        Send-MailMessage @sendMailParams -BodyAsHtml
      }
    }
  }

  function Set-BackupDash ($i_Company, $i_CompanyID, $i_AllPartners, $i_AllDevices, $i_Note, $i_URL, $i_BackupID) {
    $bmdiag = "Validating Backups : AUTH STATE : $($script:blnBM) : Company : $($i_Company)"
    logERR 4 "Set-BackupDash" "$($bmdiag)"
    if ($script:blnBM) {
      $badHTML = $null
      $goodHTML = $null
      $shade = "success"
      $reportDate = get-date
      if ($i_AllDevices) {
        #BACKUPS
        $script:SelectedDevices = $script:BackupsDetails | 
          where {(($_.PartnerName -eq "$($i_Company)") -or ($_.PartnerName -match "$($i_Company)"))} | 
            select PartnerId, PartnerName, AccountID, ComputerName, DeviceName, OS, IPMGUIPwd, 
              TimeStamp, LastSuccess, Product, DataSources, SelectedGB, UsedGB, Location, Notes
        $bmdiag = "$($SelectedDevices.AccountId.count) Devices Selected`r`n$($strLineSeparator)"
        logERR 4 "Set-BackupDash : Backups" "$($bmdiag)"
        #RECOVERIES
        $script:SelectedRecoveries = $Script:DRStatistics | 
          where {(($_.backup_cloud_partner_name -eq "$($i_Company)") -or ($_.backup_cloud_partner_name -match "$($i_Company)"))} | 
            select backup_cloud_partner_name, backup_cloud_device_id, backup_cloud_device_name, backup_cloud_device_machine_name, plan_name, data_sources, 
              backup_cloud_device_status, last_recovery_status, last_recovery_boot_status, current_recovery_status, last_recovery_timestamp, recovery_target_type
        $bmdiag = "$($SelectedRecoveries.AccountId.count) Devices Selected`r`n$($strLineSeparator)"
        logERR 4 "Set-BackupDash : Recoveries" "$($bmdiag)"
      } elseif (-not $i_AllDevices) {
        if (($null -ne $i_BackupID) -and ($i_BackupID -ne "")) {
          #BACKUPS
          $script:SelectedDevices = $script:BackupsDetails | where {$_.DeviceName -eq $i_BackupID} | 
            select PartnerId, PartnerName, AccountID, ComputerName, DeviceName, OS, IPMGUIPwd, 
              TimeStamp, LastSuccess, Product, DataSources, SelectedGB, UsedGB, Location, Notes
          $bmdiag = "$($SelectedDevices.AccountId.count) Devices Selected`r`n$($strLineSeparator)"
          logERR 4 "Set-BackupDash : Backups" "$($bmdiag)"
          #RECOVERIES
          $script:SelectedRecoveries = $Script:DRStatistics | where {$_.backup_cloud_device_machine_name -eq $i_BackupID} | 
            select backup_cloud_partner_name, backup_cloud_device_id, backup_cloud_device_name, backup_cloud_device_machine_name, plan_name, data_sources, 
              backup_cloud_device_status, last_recovery_status, last_recovery_boot_status, current_recovery_status, last_recovery_timestamp, recovery_target_type
          $bmdiag = "$($SelectedRecoveries.AccountId.count) Devices Selected`r`n$($strLineSeparator)"
          logERR 4 "Set-BackupDash : Recoveries" "$($bmdiag)"
        }
      }

      if (@($script:SelectedDevices).count -gt 0) {
        #BACKUPS
        $selected = $script:SelectedDevices | 
          select PartnerId, PartnerName, @{Name="AccountID"; Expression={[int]$_.AccountId}}, ComputerName, DeviceName, OS, IPMGUIPwd,
            TimeStamp, LastSuccess, Product, DataSources, SelectedGB, UsedGB, Location, Notes | 
              sort-object AccountId | format-table | out-string
        $overdue = @($script:SelectedDevices | 
          where {(get-date -date "$($_.TimeStamp)") -lt $reportDate.AddDays(-1)} | 
            select PartnerId, PartnerName, AccountID, ComputerName, DeviceName, OS, IPMGUIPwd, 
              TimeStamp, LastSuccess, Product, DataSources, SelectedGB, UsedGB, Location, Notes).count
        $bmdiag = $selected | out-string
        $bmdiag = "`r`n$($strLineSeparator)`r`n`tBackups :`r`n$($bmdiag)`r`n$($strLineSeparator)`r`n"
        logERR 4 "Set-BackupDash : Backups" "$($bmdiag)"
        #RECOVERIES
        if (@($script:SelectedRecoveries).count -gt 0) {
          $recoveries = $script:SelectedRecoveries | 
            select backup_cloud_partner_name, backup_cloud_device_id, backup_cloud_device_name, backup_cloud_device_machine_name, plan_name, data_sources,
              backup_cloud_device_status, last_recovery_status, last_recovery_boot_status, current_recovery_status, last_recovery_timestamp, recovery_target_type | 
                format-table | out-string
          $failed = @($script:SelectedRecoveries | where {$_.last_recovery_status -ne "Completed"}).count
          $bmdiag = $recoveries | out-string
          $bmdiag = "`r`n$($strLineSeparator)`r`n`tRecoveries :`r`n$($bmdiag)`r`n$($strLineSeparator)`r`n"
          $bmdiag = "$($SelectedDevices.AccountId.count) Devices Selected`r`n$($strLineSeparator)"
          logERR 4 "Set-BackupDash : Recoveries" "$($bmdiag)"
        }
        $MagicMessage = "$(@($script:SelectedDevices).count) Protected Devices / `r`n<br>`r`n"
        $MagicMessage += " $(@($script:SelectedRecoveries).count) Recovery Verification Devices"
        #Update 'Tile' Shade based on Overdue Backups
        if (($overdue -ge 1) -or ($failed -ge 1)) {
          $shade = "warning"
          $MagicMessage = "$($overdue) / $(@($script:SelectedDevices).count) Backups Overdue`r`n<br>`r`n"
          $MagicMessage += " $($failed) / $(@($script:SelectedRecoveries).count) Recoveries Failed"
          #BACKUPS
          $badHTML = [System.Net.WebUtility]::HtmlDecode(($script:SelectedDevices | 
            where {(get-date -date "$($_.TimeStamp)") -lt $reportDate.AddDays(-1)} | 
              select PartnerId, PartnerName, AccountID, ComputerName, DeviceName, OS, IPMGUIPwd, 
                TimeStamp, LastSuccess, Product, DataSources, SelectedGB, UsedGB, Location, Notes | 
                  convertto-html -fragment | out-string) -replace $TableStylingBad)
          $goodHTML = [System.Net.WebUtility]::HtmlDecode(($script:SelectedDevices | 
            where {(get-date -date "$($_.TimeStamp)") -ge $reportDate.AddDays(-1)} | 
              select PartnerId, PartnerName, AccountID, ComputerName, DeviceName, OS, IPMGUIPwd, 
                TimeStamp, LastSuccess, Product, DataSources, SelectedGB, UsedGB, Location, Notes | 
                  convertto-html -fragment | out-string) -replace $TableStylingGood)
          $badbody = "<h2>Overdue Backups:</h2><figure class=`"table`">$($badHTML)</figure>"
          $badbody = "$($badbody)<h2>Completed Backups:</h2><figure class=`"table`">$($goodHTML)</figure>"
          #RECOVERIES
          $badHTML = [System.Net.WebUtility]::HtmlDecode(($script:SelectedRecoveries | 
            where {$_.last_recovery_status -ne "Completed"} | convertto-html -fragment | out-string) -replace $TableStylingBad)
          $goodHTML = [System.Net.WebUtility]::HtmlDecode(($script:SelectedRecoveries | 
            where {$_.last_recovery_status -eq "Completed"} | convertto-html -fragment | out-string) -replace $TableStylingGood)
          $badbody = "$($badbody)<h2>Failed Recovery Verifications:</h2><figure class=`"table`">$($badHTML)</figure>"
          $badbody = "$($badbody)<h2>Completed Recovery Verifications:</h2><figure class=`"table`">$($goodHTML)</figure>"
        } else {
          #BACKUPS
          $goodHTML = [System.Net.WebUtility]::HtmlDecode(($script:SelectedDevices | 
            where {(get-date -date "$($_.TimeStamp)") -ge $reportDate.AddDays(-1)} | 
              select PartnerId, PartnerName, AccountID, ComputerName, DeviceName, OS, IPMGUIPwd, 
                TimeStamp, LastSuccess, Product, DataSources, SelectedGB, UsedGB, Location, Notes | 
                  convertto-html -fragment | out-string) -replace $TableStylingGood)
          $goodbody = "<h2>$($i_Company) Backups:</h2><figure class=`"table`">$($goodHTML)</figure>"
          #RECOVERIES
          $goodHTML = [System.Net.WebUtility]::HtmlDecode(($script:SelectedRecoveries | 
            where {$_.last_recovery_status -ne "Completed"} | convertto-html -fragment | out-string) -replace $TableStylingGood)
          $goodbody = "$($goodbody)<h2>$($i_Company) Recovery Verifications:</h2><figure class=`"table`">$($goodHTML)</figure>"
        }
        #Update 'Tile' Shade based on Overdue Backups
        if (($overdue -ge 2) -or ($failed -ge 2)) {$shade = "danger"}
        $body = "<p class=`"callout callout-info`"><button type=`"button`" style=`"background-color: #B5B5B5;font-size: 16px;`">"
        $body = "$($body)<a target=`"_blank`" href=`"$($i_URL)`"><b>Open Backup.Management</b></a></button></p>"
        $body = "$($body)<h4>Report last updated: $($timestamp)</h4>$($badbody)$($goodbody)"
        $body = $body.replace("<table>", '<table style="width: 100%;">')
        $body = $body.replace("<tr>", '<tr style="width: 100%;">')
        $body = $body.replace("<td>", '<td style="resize: both;overflow: auto;margin: 25px;"><div style="resize: both; overflow: auto;margin: 5px;">')
        $body = $body.replace("</td>", '</td></div>')
        #write-output "$($body)"
        #write-output $i_Note
        try {
          $script:huduCalls += 1
          $Huduresult = Set-HuduMagicDash -title "Backup - $($i_Note)" -company_name "$($i_Company)" -message "$($MagicMessage)" -icon "fas fa-chart-pie" -content "$($body)" -shade "$($shade)" -ea stop
          $bmdiag = "Backup Magic Dash Set`r`n$($strLineSeparator)"
          logERR 4 "Set-BackupDash" "$($bmdiag)"
          $arrayAssets = @("Server", "Workstation")
          foreach ($type in $arrayAssets) {
            # Get the Asset Layout
            $AssetLayout = $huduLayouts | where {$_.name -match "$($type)"} #Get-HuduAssetLayouts -name "$($type)"
            # Check we found the layout
            if (($AssetLayout | measure-object).count -le 0) {
              $bmdiag = "No layout(s) found in $($type)`r`n$($strLineSeparator)"
              logERR 4 "Set-BackupDash" "$($bmdiag)"
              $skipBackups += 1
            } else {
              # Get all the detail assets and loop
              foreach ($device in $script:SelectedDevices) {
                $totBackups += 1
                $script:huduCalls += 1
                $AssetName = "$($device.ComputerName)"
                $Asset = Get-HuduAssets -name "$($AssetName)" -companyid $i_CompanyID -assetlayoutid $AssetLayout.id
                if ($Asset) {
                  $badHTML = $null
                  $goodHTML = $null
                  if ((get-date -date "$($device.TimeStamp)") -lt $reportDate.AddDays(-1)) {
                    $badHTML = [System.Net.WebUtility]::HtmlDecode(($device | 
                      select PartnerId, PartnerName, AccountID, ComputerName, DeviceName, OS, IPMGUIPwd, 
                        TimeStamp, LastSuccess, Product, DataSources, SelectedGB, UsedGB, Location, Notes | 
                          convertto-html -fragment | out-string) -replace $TableStylingBad)
                  } elseif ((get-date -date "$($device.TimeStamp)") -ge $reportDate.AddDays(-1)) {
                    $goodHTML = [System.Net.WebUtility]::HtmlDecode(($device | 
                      select PartnerId, PartnerName, AccountID, ComputerName, DeviceName, OS, IPMGUIPwd, 
                        TimeStamp, LastSuccess, Product, DataSources, SelectedGB, UsedGB, Location, Notes | 
                          convertto-html -fragment | out-string) -replace $TableStylingGood)
                  }
                  $body = "<p class=`"callout callout-info`"><button type=`"button`" style=`"background-color: #B5B5B5;font-size: 16px;`">"
                  $body = "$($body)<a target=`"_blank`" href=`"$($i_URL)`"><b>Open Backup.Management</b></a></a></button></p>"
                  $body = "$($body)<h4>Report last updated: $($timestamp)</h4><h2>$($AssetName) Backups:</h2>$($badHTML)$($goodHTML)"
                  $body = $body.replace("<table>", '<table style="width: 100%;">')
                  $body = $body.replace("<tr>", '<tr style="width: 100%;">')
                  $body = $body.replace("<td>", '<td style="resize: both;overflow: auto;margin: 25px;"><div style="resize: both; overflow: auto;margin: 5px;">')
                  $body = $body.replace("</td>", '</td></div>')
                  # Loop through all the fields on the Asset
                  $AssetFields = @{
                    'control_tools'         = ($Asset.fields | where-object -filter {$_.label -eq "Control Tools"}).value
                    'asset_location'        = ($Asset.fields | where-object -filter {$_.label -eq "Asset Location"}).value
                    'manufacturer'          = ($Asset.fields | where-object -filter {$_.label -eq "Manufacturer"}).value
                    'model'                 = ($Asset.fields | where-object -filter {$_.label -eq "Model"}).value
                    'model_lookup'          = ($Asset.fields | where-object -filter {$_.label -eq "Model Lookup"}).value
                    'serial_number'         = ($Asset.fields | where-object -filter {$_.label -eq "Serial Number"}).value
                    'serial_lookup'         = ($Asset.fields | where-object -filter {$_.label -eq "Serial Lookup"}).value
                    'warranty_expiry'       = ($Asset.fields | where-object -filter {$_.label -eq "Warranty Expiry"}).value
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
                    $procBackups += 1
                  } catch {
                    $bmdiag = "Error Updating $($AssetName) in $($i_Company) $($type) Assets`r`n$($strLineSeparator)"
                    $bmdiag += "`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
                    logERR 4 "Set-BackupDash" "$($bmdiag)"
                    $failBackups += 1
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
          write-output "`r`n$($strLineSeparator)`r`n`tNo Devices Selected`r`n$($strLineSeparator)`r`n"
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
        #write-output "$($body)"
        #write-output $i_Note
        $script:huduCalls += 1
        $Huduresult = Set-HuduMagicDash -title "Backup - $($i_Note)" -company_name "$($i_Company)" -message "Failed to login to Backup.Management" -icon "fas fa-chart-pie" -content "$($body)" -shade "$($shade)" -ea stop
        $bmdiag = "FAILED TO LOGIN TO BACKUP.MANAGEMENT - $($(get-date))`r`n$($strLineSeparator)"
        $bmdiag += "`r`nBackup Magic Dash Set`r`n$($strLineSeparator)"
        logERR 4 "Set-BackupDash" "$($bmdiag)"
      } catch {
        $bmdiag = "$($i_Company)) not found in Hudu or other error occured`r`n$($strLineSeparator)"
        $bmdiag += "`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
        logERR 5 "Set-BackupDash" "$($bmdiag)"
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
write-output "$($strLineSeparator)`r`nInitializing"
$script:diag += "`r`n$($strLineSeparator)`r`nInitializing`r`n"
#Attempt Hudu Authentication; Fail Script if this fails
if (-not $script:blnBREAK) {
  try {
    $script:huduCalls += 1
    $authdiag = "Authenticating Hudu`r`n$($strLineSeparator)"
    logERR 4 "Authenticating Hudu" "$($authdiag)"
    #Set Hudu logon information
    New-HuduAPIKey $script:HuduAPIKey
    New-HuduBaseUrl $script:HuduBaseDomain
    $authdiag = "Successful`r`n$($strLineSeparator)"
    logERR 4 "Authenticating Hudu" "$($authdiag)"
    #Gather Hudu Resources
    #Gather Hudu Layouts Only Once
    $hududiag = "Asset Layouts :`r`n$($strLineSeparator)"
    logERR 4 "Hudu Retrieval" "$($hududiag)"
    $huduLayouts = foreach ($huduLayout in $Layouts) {$script:huduCalls += 1; Get-HuduAssetLayouts -name "$($huduLayout)"}
    write-output "Done`r`n$($strLineSeparator)"
    $script:diag += "`r`nDone`r`n$($strLineSeparator)`r`n"
    #Retrieve all Hudu Customer Management Assets Only Once
    $script:huduCalls += 1
    $hududiag = "Customer Management Assets :`r`n$($strLineSeparator)"
    logERR 4 "Hudu Retrieval" "$($hududiag)"
    $ManagementLayout = $huduLayouts | where {$_.name -eq "$($ManagementLayoutName)"}
    $ManagementAssets = Get-HuduAssets -AssetLayoutId $ManagementLayout.id | Sort-Object -Property company_name
    write-output "Done`r`n$($strLineSeparator)"
    $script:diag += "`r`nDone`r`n$($strLineSeparator)`r`n"
    #Retrieve all Hudu DNS Entries Assets Only Once
    $script:huduCalls += 1
    $hududiag = "DNS Entries - AutoDoc Assets :`r`n$($strLineSeparator)"
    logERR 4 "Hudu Retrieval" "$($hududiag)"
    $DNSLayout = $huduLayouts | where {$_.name -match "$($DNSHistoryLayoutName)"}
    $DNSAssets = Get-HuduAssets -assetlayoutid $DNSLayout.id | Sort-Object -Property company_name
    write-output "Done`r`n$($strLineSeparator)"
    $script:diag += "`r`nDone`r`n$($strLineSeparator)`r`n"
    #Retrieve all Hudu Sales/Finance Assets Only Once
    $script:huduCalls += 1
    $hududiag = "Sales/Finance Assets :`r`n$($strLineSeparator)"
    logERR 4 "Hudu Retrieval" "$($hududiag)"
    $SalesLayout = $huduLayouts | where {$_.name -match "$($SalesLayoutName)"}
    $SalesAssets = Get-HuduAssets -assetlayoutid $SalesLayout.id | Sort-Object -Property company_name
    write-output "Done`r`n$($strLineSeparator)"
    $script:diag += "`r`nDone`r`n$($strLineSeparator)`r`n"
  } catch {
    $script:blnBREAK = $true
    $authdiag = "Failed`r`n$($strLineSeparator)"
    $authdiag += "`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
    logERR 5 "Authenticating Hudu" "$($authdiag)"
  }
}
#Attempt AutoTask Authentication; Fail Script if this fails
if (-not $script:blnBREAK) {
  try {
    $script:psaCalls += 1
    $authdiag = "Authenticating AutoTask`r`n$($strLineSeparator)"
    logERR 3 "Authenticating AutoTask" "$($authdiag)"
    #Autotask Auth
    $Creds = New-Object System.Management.Automation.PSCredential($script:AutotaskAPIUser, $(ConvertTo-SecureString $script:AutotaskAPISecret -AsPlainText -Force))
    Add-AutotaskAPIAuth -ApiIntegrationcode "$($script:AutotaskIntegratorID)" -credentials $Creds
    $authdiag = "Successful`r`n$($strLineSeparator)"
    logERR 3 "Authenticating AutoTask" "$($authdiag)"
    #Get Company Classifications and Categories
    logERR 3 "Autotask Retrieval" "CLASS MAP :`r`n$($strLineSeparator)"
    PSA-GetMaps $script:psaHeaders $script:classMap "ClassificationIcons"
    $script:classMap
    write-output "$($strLineSeparator)`r`nDone`r`n$($strLineSeparator)"
    $script:diag += "`r`n$($strLineSeparator)`r`nDone`r`n$($strLineSeparator)`r`n"
    logERR 3 "Autotask Retrieval" "CATEGORY MAP :`r`n$($strLineSeparator)"
    PSA-GetMaps $script:psaHeaders $script:categoryMap "CompanyCategories"
    $script:categoryMap
    write-output "$($strLineSeparator)`r`nDone`r`n$($strLineSeparator)"
    $script:diag += "`r`n$($strLineSeparator)`r`nDone`r`n$($strLineSeparator)`r`n"
    #Get Companies, Tickets, and Resources
    logERR 3 "Autotask Retrieval" "COMPANIES :`r`n$($strLineSeparator)"
    PSA-GetCompanies $script:psaHeaders
    write-output "Done`r`n$($strLineSeparator)"
    $script:diag += "`r`nDone`r`n$($strLineSeparator)`r`n"
    $script:psaCalls += 1
    logERR 3 "Autotask Retrieval" "TICKETS :`r`n$($strLineSeparator)"
    $tickets = Get-AutotaskAPIResource -Resource Tickets -SearchQuery "$($TicketFilter)"
    #$tickets = PSA-FilterQuery $script:psaHeaders "GET" "Tickets" $TicketFilter
    write-output "Done`r`n$($strLineSeparator)"
    $script:diag += "`r`nDone`r`n$($strLineSeparator)`r`n"
    #Get Ticket Fields
    logERR 3 "Autotask Retrieval" "TICKET FIELDS :`r`n$($strLineSeparator)"
    $ticketFields = PSA-Query $script:psaHeaders "GET" "Tickets/entityInformation/fields"
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
    write-output "Done`r`n$($strLineSeparator)"
    $script:diag += "`r`nDone`r`n$($strLineSeparator)`r`n"
    #$resourceValues
    logERR 3 "Autotask Retrieval" "RESOURCES :`r`n$($strLineSeparator)"
    $resources = PSA-FilterQuery $script:psaHeaders "GET" "Resources" $psaGenFilter
    write-output "Done`r`n$($strLineSeparator)"
    $script:diag += "`r`nDone`r`n$($strLineSeparator)`r`n"
    #Grab all 'Open' Appointments from Dispatch Calendar
    logERR 3 "Autotask Retrieval" "APPOINTMENTS :`r`n$($strLineSeparator)"
    #$appointments = PSA-FilterQuery $script:psaHeaders "GET" "Appointments" $psaGenFilter
    $appointments = Get-AutotaskAPIResource -Resource Appointments -SearchQuery "$($psaGenFilter)"
    write-output "Done`r`n$($strLineSeparator)"
    $script:diag += "`r`nDone`r`n$($strLineSeparator)`r`n"
    #Grab All Assets for All Companies in a Single Call
    $configitems = $null
    $script:psaCalls += 1
    logERR 3 "Autotask Retrieval" "PSA ASSETS :`r`n$($strLineSeparator)"
    $psaAssetFilter = "{`"Filter`":[{`"field`":`"IsActive`",`"op`":`"eq`",`"value`":true}]}"
    $configitems = Get-AutotaskAPIResource -Resource ConfigurationItems -SearchQuery "$($psaAssetFilter)"
    write-output "Done`r`n$($strLineSeparator)"
    $script:diag += "`r`nDone`r`n$($strLineSeparator)`r`n"
    #Get PSA Asset Fields
    logERR 3 "Autotask Retrieval" "ASSET FIELDS :`r`n$($strLineSeparator)"
    $assetFields = PSA-Query $script:psaHeaders "GET" "ConfigurationItems/entityInformation/fields"
    #Get PSA Asset Manufacturer Data Map
    $assetMakes = Get-ATFieldHash -name "rmmDeviceAuditManufacturerID" -fieldsIn $assetFields
    #Get PSA Asset Model Data Map
    $assetModels = Get-ATFieldHash -name "rmmDeviceAuditModelID" -fieldsIn $assetFields
    write-output "Done`r`n$($strLineSeparator)"
    $script:diag += "`r`nDone`r`n$($strLineSeparator)`r`n"
  } catch {
    $script:blnBREAK = $true
    $authdiag = "Failed`r`n$($strLineSeparator)"
    $authdiag += "`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
    logERR 5 "Authenticating AutoTask" "$($authdiag)"
  }
}
if (-not $script:blnBREAK) {
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
  write-output "Initializing Done`r`n$($strLineSeparator)"
  $script:diag += "`r`nInitializing Done`r`n$($strLineSeparator)`r`n"
  #region######################## Autotask  Section ###########################
  # https://mspp.io/hudu-datto-psa-autotask-open-tickets-magic-dash/
  #QUERY PSA API
  logERR 3 "Autotask Processing" "Beginning Autotask Processing`r`n$($strLineSeparator)"
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
        $atURL = "$($AutotaskAcct)$($company.CompanyID)"
        $body = "<p class=`"callout callout-info`"><button type=`"button`" style=`"background-color: #B5B5B5;font-size: 16px;`">"
        $body = "$($body)<a target=`"_blank`" href=`"$($atURL)`"><b>Open $($company.CompanyName) in PSA</b></a></a></button></p>"
        write-output "`r`n$($strLineSeparator)`r`nProcessing $($company.CompanyName)`r`n$($strLineSeparator)"
        $script:diag += "`r`n`r`n$($strLineSeparator)`r`nProcessing $($company.CompanyName)`r`n$($strLineSeparator)`r`n"
        #Find Company in Hudu
        $script:huduCalls += 1
        $huduCompany = Get-HuduCompanies -Name "$($company.CompanyName)"
        #region###############    Arrange PSA Ticket data for Hudu
        $custTickets = $tickets | 
          where {$_.companyID -eq $company.CompanyID} | 
            select id, ticketNUmber, createdate, title, description, dueDateTime, assignedResourceID, lastActivityPersonType, 
              lastCustomerVisibleActivityDateTime, priority, source, status, issueType, subIssueType, ticketType
        if (@($custTickets).count -gt 0) {
          $outTickets = foreach ($ticket in $custTickets) {
            $procCoTickets += 1
            $procPSAtickets += 1
            #Retrieve Assigned Resource for Tickets
            $tech = $resources.items | where {$_.id -eq $ticket.assignedResourceID} | select firstName, lastName
            #write-output "TEST RESOURCE : $($tech.firstName) $($tech.lastName)"
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
          write-output "Customer Tickets :`r`nCollected $(@($outTickets).count) Tickets`r`n$($strLineSeparator)"
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
            $body = "$($body)<h4>Report last updated: $($reportDate)</h4><h2>Overdue Tickets:</h2><figure class=`"table`">$($overdueHTML)</figure>"
            $body = "$($body)<h2>Tickets:</h2><figure class=`"table`">$($goodhtml)</figure>"
          } else {
            $goodHTML = [System.Net.WebUtility]::HtmlDecode(($outTickets | 
              select 'Ticket-Number', 'Created', 'Title', 'Due', 'Resource', 'Last-Updater', 'Last-Update', 
                'Priority', 'Source', 'Status', 'Type', 'Sub-Type', 'Ticket-Type' | 
                  convertto-html -fragment | out-string) -replace $TableStylingGood)
            $body = "$($body)<h4>Report last updated: $($reportDate)</h4><h2>Tickets:</h2><figure class=`"table`">$($goodHTML)</figure>"
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
            $Huduresult = Set-HuduMagicDash -title "Autotask - Open Tickets" -company_name "$(($company.companyName).Trim())" -message "No Open Tickets" -contentlink "$($atURL)" -icon "fas fa-chart-pie" -shade "success" -ea stop
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
        write-output "$($strLineSeparator)`r`nCustomer Assets :`r`nCollected $(@($custAssets).count) Assets`r`n$($strLineSeparator)"
        $script:diag += "`r`n$($strLineSeparator)`r`nCustomer Assets :`r`nCollected $(@($custAssets).count) Assets`r`n$($strLineSeparator)"
        if (@($custAssets).count -gt 0) {
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
                write-output "$($strLineSeparator)`r`nProcessing $($type) Asset $($Asset.name)`r`n$($strLineSeparator)"
                write-output "Type : $($psaAsset.rmmTypeID)`r`nName : $($psaAsset.refTitle)"
                write-output "Make : $($psaAsset.make)`r`nModel : $($psaAsset.model)`r`nModel ID : $($psaAsset.rmmModelID)"
                write-output "S/N : $($psaAsset.serial)`r`nMAC : $($psaAsset.rmmDevMAC)`r`nDevice IP : $($psaAsset.rmmDevIP)"
                $script:diag += "`r`n`r`n$($strLineSeparator)`r`nProcessing $($type) Asset $($Asset.name)`r`n$($strLineSeparator)"
                $script:diag += "`r`nType : $($psaAsset.rmmTypeID)`r`nName : $($psaAsset.refTitle)"
                $script:diag += "`r`nMake : $($psaAsset.make)`r`nModel : $($psaAsset.model)`r`nModel ID : $($psaAsset.rmmModelID)"
                $script:diag += "`r`nS/N : $($psaAsset.serial)`r`nMAC : $($psaAsset.rmmDevMAC)`r`nDevice IP : $($psaAsset.rmmDevIP)"
                if (($type -ne "UPS") -and ($type -ne "Network Appliance") -and ($type -ne "Unkown")) {
                  try {
                    start-sleep -milliseconds 10
                    #Attempt to find Asset Layout and PSA Asset in Hudu
                    $script:huduCalls += 1 #2
                    write-output "Accessing $($psaAsset.refTitle) Hudu Asset in $($huduCompany.name)($($huduCompany.id))"
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
                          write-output "Skipped`r`n$($strLineSeparator)"
                          $script:diag += "`r`nSkipped`r`n$($strLineSeparator)"
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
                          'warranty_expiry'       = ($Asset.fields | where-object -filter {$_.label -eq "Warranty Expiry"}).value
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
                        write-output "$($AssetFields | out-string)$($strLineSeparator)`r`nUpdating $($type) Asset $($Asset.name)`r`n$($strLineSeparator)`r`n"
                        $script:diag += "`r`n$($AssetFields | out-string)$($strLineSeparator)`r`nUpdating $($type) Asset $($Asset.name)`r`n$($strLineSeparator)"
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
      write-output "$($strLineSeparator)`r`nSkipped`r`n$($strLineSeparator)"
      $script:diag += "`r`n$($strLineSeparator)`r`nSkipped`r`n$($strLineSeparator)"
      #$psadiag = "Skipped`r`n$($strLineSeparator)"
      #logERR 3 "Autotask Processing" "$($psadiag)"
      $skipCompany += 1
      start-sleep -milliseconds 250
    }
  }
  write-output "Done`r`n$($strLineSeparator)"
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
  #region######################## Sales/Finance Section ###########################
  logERR 3 "Sales/Finance" "Beginning Sales/Finance Processing`r`n$($strLineSeparator)"
  # Check we found the layout
  if (($SalesLayout | measure-object).count -ne 1) {
    logERR 3 "Sales/Finance" "No / multiple layout(s) found with name $($SalesLayoutName)`r`n$($strLineSeparator)"
  } else {
    # Loop through AT PSA Sales Resources
    foreach ($resource in $script:salesIDs) {
      # Loop through all Sales/Finance Assets
      foreach ($Asset in $SalesAssets) {
        #Create AT APPT
        #'https://webservices14.autotask.net/ATServicesRest/V1.0/Appointments'
        #$resources.items | where {($_.firstname -match 'Greg') -or ($_.firstname -match 'Raymond')}
        #29682885 - Greg
        #29682895 - Raymond
        #29682901 - API User
        $newAppt = @{
          id = 0
          createDateTime = "$(get-date)"
          creatorResourceID = 29682901
          description = "Test APPT via API"
          endDateTime = "2024-03-04T19:48:50.773Z"
          resourceID = $resource
          startDateTime = "2024-03-04T18:48:50.773Z"
          title = "$($sales.company_name) : " #"Test APPT"
          updateDateTime = "$(get-date)"
        }
        #Clear any prev Appts
        $cur30day = $null
        $cur60day = $null
        $RenewalDate = [datetime](($sales.fields | where {$_.label -eq "Agreement End"}).value).replace("Z", "")
        #Filter AT PSA Appts
        $cur30day = $appointments | where {(($_.resourceID -eq $resource) -and ($_.startDateTime -ge $(get-date)) -and 
          ($_.title -match "$($sales.company_name) : Contract 30 Day Notice"))}
        if (-not ($cur30day)) {
          $newAppt.endDateTime = "$(($RenewalDate.AddDays(-30)).AddHours(13))"
          $newAppt.startDateTime = "$(($RenewalDate.AddDays(-30)).AddHours(12))"
          $newAppt.title = "$($sales.company_name) : Contract 30 Day Notice"
          $newAppt.description = "$($sales.company_name) : Contract 30 Day Notice`r`nGenerated by HuduDoc_WatchDog API"
          logERR 4 "APPT DIAG" "UPDATING : `r`n$($newAppt | convertto-json)`r`n$($script:strLineSeparator)"
          PSA-Put $script:psaHeaders "POST" "Appointments" ($newAppt | convertto-json)
        }
        $cur60day = $appointments | where {(($_.resourceID -eq $resource) -and ($_.startDateTime -ge $(get-date)) -and 
          ($_.title -match "$($sales.company_name) : Contract 60 Day Notice"))}
        if (-not ($cur60day)) {
          $newAppt.endDateTime = "$(($RenewalDate.AddDays(-60)).AddHours(13))"
          $newAppt.startDateTime = "$(($RenewalDate.AddDays(-60)).AddHours(12))"
          $newAppt.title = "$($sales.company_name) : Contract 60 Day Notice"
          $newAppt.description = "$($sales.company_name) : Contract 60 Day Notice`r`nGenerated by HuduDoc_WatchDog API"
          logERR 4 "APPT DIAG" "UPDATING : `r`n$($newAppt | convertto-json)`r`n$($script:strLineSeparator)"
          PSA-Put $script:psaHeaders "POST" "Appointments" ($newAppt | convertto-json)
        }
      }
    }
  }
  #endregion######################## Sales/Finance Section ###########################
  #region######################## Customer Management Section ###########################
  # https://mspp.io/hudu-magic-dash-customer-services/
  logERR 3 "Customer Management" "Beginning Customer Management Processing`r`n$($strLineSeparator)"
  # Check we found the layout
  if (($ManagementLayout | measure-object).count -ne 1) {
    logERR 3 "Customer Management" "No / multiple layout(s) found with name $($ManagementLayoutName)`r`n$($strLineSeparator)"
  } else {
    # Loop through all Hudu Customer Management Assets
    foreach ($Asset in $ManagementAssets) {
      write-output "`r`n$($strLineSeparator)`r`nProcessing $($Asset.company_name) Managed Services`r`n$($strLineSeparator)"
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
        write-output "`r`n$($strLineSeparator)`r`nFields :`r`n$($strLineSeparator)"
        $EnabledField = $Fields | Where-Object {$_.ServiceName -eq $Service -and $_.ServiceAction -eq 'ENABLED'}
        write-output "$($strLineSeparator)`r`nEnabledField :`r`n$($EnabledField)"
        $NoteField = $Fields | Where-Object {$_.ServiceName -eq $Service -and $_.ServiceAction -eq 'NOTE'}
        write-output "NoteField :`r`n$($NoteField)"
        $URLField = $Fields | Where-Object {$_.ServiceName -eq $Service -and $_.ServiceAction -eq 'URL'}
        write-output "URLField :`r`n$($URLField)`r`n$($strLineSeparator)"
        if ($EnabledField) {
          logERR 3 "Customer Management" "Enabled Field found`r`n$($strLineSeparator)"
        } else {
          #$EnabledField.value = $false
          logERR 3 "Customer Management" "No Enabled Field was found`r`n$($strLineSeparator)"
        }
        $Colour = switch ($EnabledField.value) {
          $true   {'success'}
          $false  {'grey'}
          default {'grey'}
        }
        $Param = @{
          Shade       = "$($Colour)"
          Title       = "$($Service)"
          CompanyName = "$($Asset.company_name)"
        }
        if ($NoteField.value){
          $Param['Message'] = "$($NoteField.value)"
          $Param | Add-Member -MemberType NoteProperty -Name 'Message' -Value "$($NoteField.value)"
        } else {
          $Param['Message'] = switch ($EnabledField.value) {
            $true   {"Customer has $($Service)"}
            $false  {"No $($Service)"}
            default {"No $($Service)"}
          }
        }
        if (($URLField.value) -and ($Service -ne "Backup")) {$Param['ContentLink'] = "$($URLField.value)"}
        if ($Service -ne "Backup") {
          $script:huduCalls += 1
          Set-HuduMagicDash @Param
          write-output "$($strLineSeparator)"
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
  $cmdiag = "Customer Management : Completed`r`n$($strLineSeparator)`r`n"
  $cmdiag += "Total Backups : $($totBackups)`r`n"
  $cmdiag += "`t- Processed : $($procBackups) - Skipped : $($skipBackups) - Failed : $($failBackups)`r`n$($strLineSeparator)"
  logERR 3 "Customer Management" "$($cmdiag)"
  write-output "Done`r`n$($strLineSeparator)"
  $script:diag += "`r`nDone`r`n$($strLineSeparator)`r`n"
  #endregion
  #region######################## DNS History Section ###########################
  # https://mspp.io/hudu-dns-history-and-alerts/
  logERR 3 "DNS History" "Beginning DNS History Processing`r`n$($strLineSeparator)"
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
    logERR 3 "DNS History" "Missing DNS Asset Layout $($DNSHistoryLayoutName)`r`n$($strLineSeparator)"
  } elseif ($DNSLayout) {
    $script:huduCalls += 1
    $script:websites = Get-HuduWebsites | where -filter {$_.disable_dns -eq $false} | Sort-Object -Property company_name
    foreach ($website in $script:websites) {
      $dnsname = ([System.Uri]$website.name).authority
      write-output "$($strLineSeparator)`r`nResolving $($dnsname) for $($website.company_name)"
      $script:diag += "`r`n$($strLineSeparator)`r`nResolving $($dnsname) for $($website.company_name)"
      try {
        $script:dnsCalls += 5
        $arecords = resolve-dnsname "$($dnsname)" -type "A_AAAA" -ErrorAction Stop | 
          select type, IPADDRESS | sort IPADDRESS | convertto-html -fragment | out-string
        $mxrecords = resolve-dnsname "$($dnsname)" -type "MX" -ErrorAction Stop | 
          sort NameExchange | convertto-html -fragment -property NameExchange | out-string
        $nsrecords = resolve-dnsname "$($dnsname)" -type "NS" -ErrorAction Stop | 
          sort NameHost | convertto-html -fragment -property NameHost | out-string
        $txtrecords = resolve-dnsname "$($dnsname)" -type "TXT" -ErrorAction Stop | 
          select @{N='Records'; E={$($_.strings)}} | sort Records | convertto-html -fragment -property Records | out-string
        $soarecords = resolve-dnsname "$($dnsname)" -type "SOA" -ErrorAction Stop | 
          select PrimaryServer, NameAdministrator, SerialNumber | sort NameAdministrator | convertto-html -fragment | out-string
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
      write-output "$($strLineSeparator)`r`n$($dnsname) lookup successful"
      #Check if there is already an asset
      $Asset = $DNSAssets | where {(($_.name -eq "$($AssetName)") -and $_.company_name -eq "$($website.company_name)")}    #Get-HuduAssets -name "$($AssetName)" -companyid $companyid -assetlayoutid $DNSLayout.id
      #If the Asset does not exist, we edit the body to be in the form of a new asset, if not, we just upload.
      if (!$Asset) {
        try {
          $script:huduCalls += 1
          write-output "$($strLineSeparator)`r`nCreating new DNS Asset`r`n$($strLineSeparator)"
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
          write-output "$($strLineSeparator)`r`nUpdating DNS Asset - ID : $($Asset.id)`r`n$($strLineSeparator)"
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
  write-output "Done`r`n$($strLineSeparator)"
  $script:diag += "`r`nDone`r`n$($strLineSeparator)`r`n"
  #endregion
  #DATTO OUTPUT
  #Stop script execution time calculation
  StopClock
  #CLEAR LOGFILE
  $null | set-content $logPath -force
  $finish = (get-date -format "yyyy-MM-dd HH:mm:ss").ToString()
  if (-not $script:blnWARN) {
    #WRITE TO LOGFILE
    $enddiag = "Execution Successful : $($finish)"
    logERR 3 "HuduDoc_WatchDog" "$($enddiag)"
    "$($script:diag)" | add-content $logPath -force
    write-DRMMAlert "HuduDoc_WatchDog : Successful : Diagnostics - $($logPath) : $($finish)"
    #write-DRMMDiag "$($script:diag)"
    exit 0
  } elseif ($script:blnWARN) {
    #WRITE TO LOGFILE
    $enddiag = "Execution Completed with Warnings : $($finish)"
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
  $enddiag = "Execution Failure : $($finish)"
  logERR 3 "HuduDoc_WatchDog" "$($enddiag)"
  "$($script:diag)" | add-content $logPath -force
  write-DRMMAlert "HuduDoc_WatchDog : Failure : Diagnostics - $($logPath) : $($finish)"
  #write-DRMMDiag "$($script:diag)"
  exit 1
}
#END SCRIPT
#------------