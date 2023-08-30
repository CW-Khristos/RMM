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
  $logPath                        = "C:\IT\Log\Warranty_WatchDog"
  $strLineSeparator               = "----------------------------------"
  $timestamp                      = (get-date -format "yyyy-MM-dd HH:mm:ss").ToString()
  ######################### TLS Settings ###########################
  [System.Net.ServicePointManager]::MaxServicePointIdleTime = 5000000
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  #region######################## Hudu Settings ###########################
  $script:huduCalls               = 0
  # The name of the field where you wish Warranty data to be stored
  $HuduWarrantyField              = "Warranty Expiry"
  # Get a Hudu API Key from https://yourhududomain.com/admin/api_keys
  $script:HuduAPIKey              = $env:HuduKey
  # Set the base domain of your Hudu instance without a trailing /
  $script:HuduBaseDomain          = $env:HuduDomain
  ### Dell API Details ###
  $script:DellClientID            = $env:DellID
  $script:DellClientSecret        = $env:DellSecret
  #endregion
  #region######################## Autotask Settings ###########################
  $script:psaCalls                = 0
  #PSA API FILTERS
  #Generic Filter - ID -ge 0
  $psaGenFilter                   = '{"Filter":[{"field":"Id","op":"gte","value":0}]}'
  #IsActive Filter
  $psaActFilter                   = '{"Filter":[{"op":"and","items":[
                                    {"field":"IsActive","op":"eq","value":true},
                                    {"field":"Id","op":"gte","value":0}]}]}'
  #PSA API URLS
  $AutotaskRoot                   = $env:ATRoot
  $AutoTaskAPIBase                = $env:ATAPIBase
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
      1 {                                                         #'ERRRET'=1 - NOT ENOUGH ARGUMENTS, END SCRIPT
        $script:blnBREAK = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - Warranty_WatchDog - NO ARGUMENTS PASSED, END SCRIPT`r`n`r`n"
        write-output "$($strLineSeparator)`r`n$($(get-date)) - Warranty_WatchDog - NO ARGUMENTS PASSED, END SCRIPT`r`n" -foregroundcolor red
      }
      2 {                                                         #'ERRRET'=2 - INSTALL / IMPORT MODULE FAILURE, END SCRIPT
        $script:blnBREAK = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - Warranty_WatchDog - ($($strModule)) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n"
        write-output "$($strLineSeparator)`r`n$($(get-date)) - Warranty_WatchDog - ($($strModule)) :" -foregroundcolor red
        write-output "$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n" -foregroundcolor red
      }
      {3,4} {                                                     #'ERRRET'=3 & 4
        $script:blnWARN = $false
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - Warranty_WatchDog - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
        write-output "$($strLineSeparator)`r`n$($(get-date)) - Warranty_WatchDog - $($strModule) :" -foregroundcolor yellow
        write-output "$($strLineSeparator)`r`n`t$($strErr)" -foregroundcolor yellow
      }
      default {                                                   #'ERRRET'=5+
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - Warranty_WatchDog - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
        write-output "$($strLineSeparator)`r`n$($(get-date)) - Warranty_WatchDog - $($strModule) :" -foregroundcolor yellow
        write-output "$($strLineSeparator)`r`n`t$($strErr)" -foregroundcolor red
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
    write-output "`r`n$($strLineSeparator)`r`nAPI Calls :`r`nPSA API : $($script:psaCalls) - Hudu API : $($script:huduCalls)"
    write-output "$($strLineSeparator)`r`nAPI Limits :$($strLineSeparator)"
    write-output "API Limits - PSA API (per Hour) : $($psa.currentTimeframeRequestCount) / $($psa.externalRequestThreshold)"
    write-output "API Limits - Hudu API (per Minute) : $($avgHudu) / 300`r`n$($strLineSeparator)"
    write-output "Total Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds"
    $script:diag += "`r`n$($strLineSeparator)`r`nAPI Calls :`r`nPSA API : $($script:psaCalls) - Hudu API : $($script:huduCalls)"
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
      $amin = $amin.SubString(0,[math]::min(2,$amin.length))
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
    install-module HuduAPI -MaximumVersion 2.3.2 -force -confirm:$false
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
#Get the PSWarranty API Module if not installed
if (Get-Module -ListAvailable -Name PSWarranty) {
  try {
    Import-Module PSWarranty
  } catch {
    logERR 2 "PSWarranty" "INSTALL / IMPORT MODULE FAILURE"
  }
} else {
  try {
    Install-Module PSWarranty -Force -Confirm:$false
    Import-Module PSWarranty
  } catch {
    logERR 2 "PSWarranty" "INSTALL / IMPORT MODULE FAILURE"
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
  } catch {
    $script:blnBREAK = $true
    $authdiag = "Failed`r`n$($strLineSeparator)"
    $authdiag += "`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
    logERR 5 "Authenticating Hudu" "$($authdiag)"
  }
}
#Update Warranties on PSA Assets
if (-not $script:blnBREAK) {
  try {
    logERR 3 "Processing Warranties" "WARRANTIES :`r`n$($strLineSeparator)"
    if (($null -ne $script:DellClientID) -and ($script:DellClientID -ne "") -and ($script:DellClientID -ne "CHANGEME") -and 
      ($null -ne $script:DellClientSecret) -and ($script:DellClientSecret -ne "") -and ($script:DellClientSecret -ne "CHANGEME")) {
        set-WarrantyAPIKeys -DellClientID $script:DellClientID -DellClientSecret $script:DellClientSecret
    }
    logERR 3 "AutoTask Warranties" "WARRANTIES :`r`n$($strLineSeparator)"
    $pass = ConvertTo-SecureString $script:AutotaskAPISecret -AsPlainText -Force
    $atcreds = New-Object System.Management.Automation.PSCredential ("$($script:AutotaskAPIUser)", $pass)
    update-warrantyinfo -Autotask -AutotaskCredentials $atcreds -AutotaskAPIKey $script:AutotaskIntegratorID -SyncWithSource:$true -MissingOnly:$true -OverwriteWarranty:$true
    logERR 3 "Hudu Warranties" "WARRANTIES :`r`n$($strLineSeparator)"
    update-warrantyinfo -Hudu -HuduAPIKey $script:HuduAPIKey -HuduBaseURL $script:HuduBaseDomain -HuduDeviceAssetLayout "Server" -HuduWarrantyField $HuduWarrantyField -SyncWithSource:$true -OverwriteWarranty:$true -ExcludeApple:$true
    update-warrantyinfo -Hudu -HuduAPIKey $script:HuduAPIKey -HuduBaseURL $script:HuduBaseDomain -HuduDeviceAssetLayout "Workstaion" -HuduWarrantyField $HuduWarrantyField -SyncWithSource:$true -OverwriteWarranty:$true -ExcludeApple:$true
    $atcreds = $null
    $pass = $null
    write-output "Done`r`n$($strLineSeparator)"
    $script:diag += "`r`nDone`r`n$($strLineSeparator)`r`n"
  } catch {
    $script:blnBREAK = $true
    $authdiag = "Failed`r`n$($strLineSeparator)"
    $authdiag += "`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
    logERR 5 "Processing Warranties" "$($authdiag)"
  }
  #DATTO OUTPUT
  #Stop script execution time calculation
  StopClock
  #CLEAR LOGFILE
  $null | set-content $logPath -force
  $finish = (get-date -format "yyyy-MM-dd HH:mm:ss").ToString()
  if (-not $script:blnWARN) {
    #WRITE TO LOGFILE
    $enddiag = "Execution Successful : $($finish)"
    logERR 3 "Warranty_WatchDog" "$($enddiag)"
    "$($script:diag)" | add-content $logPath -force
    write-DRMMAlert "Warranty_WatchDog : Successful : Diagnostics - $($logPath) : $($finish)"
    #write-DRMMDiag "$($script:diag)"
    exit 0
  } elseif ($script:blnWARN) {
    #WRITE TO LOGFILE
    $enddiag = "Execution Completed with Warnings : $($finish)"
    logERR 3 "Warranty_WatchDog" "$($enddiag)"
    "$($script:diag)" | add-content $logPath -force
    write-DRMMAlert "Warranty_WatchDog : Warning : Diagnostics - $($logPath) : $($finish)"
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
  logERR 3 "Warranty_WatchDog" "$($enddiag)"
  "$($script:diag)" | add-content $logPath -force
  write-DRMMAlert "Warranty_WatchDog : Failure : Diagnostics - $($logPath) : $($finish)"
  #write-DRMMDiag "$($script:diag)"
  exit 1
}
#END SCRIPT
#------------