#First Clear any variables
Remove-Variable * -ErrorAction SilentlyContinue

#region ----- DECLARATIONS ----
  $script:diag              = $null
  $script:blnFAIL           = $false
  $script:blnWARN           = $false
  $script:blnSITE           = $false
  $script:strLineSeparator  = "---------"
  $script:logPath           = "C:\IT\Log\Syncro_Payments"
  #region######################## TLS Settings ###########################
  #[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType] 'Tls12'
  [System.Net.ServicePointManager]::SecurityProtocol = (
    [System.Net.SecurityProtocolType]::Tls13 -bor 
    [System.Net.SecurityProtocolType]::Tls12 -bor 
    [System.Net.SecurityProtocolType]::Tls11 -bor 
    [System.Net.SecurityProtocolType]::Tls
  )
  #endregion
  #region######################## Syncro Settings ###########################
  $script:syncroCalls       = 0
  $script:syncroWARN        = @{}
  $script:syncroAPI         = $env:SyncroAPI
  $script:syncroKey         = $env:SyncroAPIkey
  #endregion
#endregion

#region ----- API FUNCTIONS ----
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
        $script:diag += "`r`nSyncro_Payments : Failed to query Syncro API via $($params.Uri) : $($method) : $($entity) : $($query) : $($page)"
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
        Body        = $body | ConvertTo-Json
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
        $script:diag += "`r`nSyncro_Payments : Failed to query Syncro API via $($params.Uri) : $($method) : $($entity) : $($body) : $($page)"
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
        $script:diag += "`r`nSyncro_Payments : Failed to query Syncro API via $($params.Uri) : $($method) : $($entity) : $($query) : $($page)"
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

  function Pop-Warning ($dest, $key, $warn) {
    #POPULATE WARNINGS DATA INTO NESTED HASHTABLE FORMAT FOR LATER USE
    try {
      $blnADD = $true
      $new = [System.Collections.ArrayList]@()
      $prev = [System.Collections.ArrayList]@()
      if (($warn -ne $null) -and ($key -ne "")) {
        write-output "`t$($warn)"
        $script:diag += "`t$($warn)`r`n"
        if ($dest.containskey($key)) {
          $prev = $dest[$key]
          $prev = $prev.split("`r`n",[System.StringSplitOptions]::RemoveEmptyEntries)
          if ($prev -contains $warn) {$blnADD = $false}
          if ($blnADD) {
            foreach ($itm in $prev) {$new.add("$($itm)`r`n")}
              $new.add("$($warn)`r`n")
              $dest.remove($key)
              $dest.add($key, $new)
              $script:blnWARN = $true
            }
          } elseif (-not $dest.containskey($key)) {
            $new = [System.Collections.ArrayList]@()
            $new = "$($warn)`r`n"
            $dest.add($key, $new)
            $script:blnWARN = $true
          }
      }
    } catch {
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
      logERR 3 "Pop-Warnings" "Error populating warnings for $($key)`r`n$($err)`r`n$($strLineSeparator)"
    }
} ## Pop-Warnings

  function logERR ($intSTG, $strModule, $strErr) {
    $script:blnWARN = $true
    #CUSTOM ERROR CODES
    switch ($intSTG) {
      1 {                                                         #'ERRRET'=1 - NOT ENOUGH ARGUMENTS, END SCRIPT
        $script:blnBREAK = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date))`t - Syncro_Payments - NO ARGUMENTS PASSED, END SCRIPT`r`n`r`n"
        write-output "$($strLineSeparator)`r`n$($(get-date))`t - Syncro_Payments - NO ARGUMENTS PASSED, END SCRIPT`r`n"
      }
      2 {                                                         #'ERRRET'=2 - INSTALL / IMPORT MODULE FAILURE, END SCRIPT
        $script:blnBREAK = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date))`t - Syncro_Payments - ($($strModule)) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n"
        write-output "$($strLineSeparator)`r`n$($(get-date))`t - Syncro_Payments - ($($strModule)) :"
        write-output "$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n"
      }
      default {                                                   #'ERRRET'=3+
        $script:blnWARN = $false
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date))`t - Syncro_Payments - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
        write-output "$($strLineSeparator)`r`n$($(get-date))`t - Syncro_Payments - $($strModule) :"
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
#Start script execution time calculation
$ScrptStartTime = (Get-Date).ToString('dd-MM-yyyy hh:mm:ss')
$script:sw = [Diagnostics.Stopwatch]::StartNew()

try {
  #QUERY SYNCRO API
  write-output "`r`n$($script:strLineSeparator)`r`nQUERYING SYNCRO API :`r`n$($script:strLineSeparator)"
  $script:syncroCustomers = Syncro-Query "GET" "customers" $null
  #write-output $script:syncroCustomers | out-string
  write-output "`t$($script:strLineSeparator)`r`n`tTotal # Syncro Customers : $($script:syncroCustomers.customers.Count)"
  start-sleep -milliseconds 200
  $script:syncroProducts = Syncro-Query "GET" "products" "category_id=195696"
  #write-output $script:syncroProducts | out-string
  write-output "`t$($script:strLineSeparator)`r`n`tTotal # Syncro Products : $($script:syncroProducts.products.Count)"
  start-sleep -milliseconds 200
  $script:unpaidInvoices = Syncro-Query "GET" "invoices" "unpaid=true"
  #write-output $script:syncroInvoices | out-string
  write-output "`t$($script:strLineSeparator)`r`n`tTotal # UnPaid Syncro Invoices : $($script:unpaidInvoices.invoices.Count)"
  write-output "`t$($script:strLineSeparator)`r`nQUERY SYNCRO DONE`r`n$($script:strLineSeparator)`r`n"
  start-sleep -milliseconds 200
  
  if ($script:syncroCustomers) {
    #ITERATE THROUGH SYNCRO CUSTOMERS
    $actDate = ((get-date).AddYears(-3))
    foreach ($script:customer in $script:syncroCustomers.customers) {
      $invoices = $null
      start-sleep -milliseconds 200 #200msec X ~300 = 1min
      write-output "$($script:strLineSeparator)"
      write-output "`tProcessing Syncro Customer : $($script:customer.fullname) | $($script:customer.business_name) | Last Updated : $($script:customer.updated_at)"
      write-output "$($script:strLineSeparator)"
      switch ([datetime]$actDate -le [datetime]$script:customer.updated_at) {
        false {
          $blnChk = $false
          Pop-Warning $script:syncroWARN "$($script:customer.fullname) | $($script:customer.business_name)" "WARN : Last Updated : $($script:customer.updated_at)`r`n"
          write-output "`tWARN : $($script:customer.fullname) : Last Updated : $($script:customer.updated_at)"
          #break
        }
        true {
          $script:customerInvoices = $script:unpaidInvoices.invoices | where {($_.customer_id -eq $script:customer.id)}
          #write-output $script:customerInvoices | out-string
          if (($script:customerInvoices | measure).count -eq 0) {
            write-output "`t# UnPaid Customer Syncro Invoices : $(($script:customerInvoices | measure).count)`r`n`t$($script:strLineSeparator)"
          } elseif (($script:customerInvoices | measure).count -gt 0) {
            foreach ($invoice in $script:customerInvoices) {
              $invoices += "Invoice # : $($invoice.number)`t- Due : $($invoice.due_date)`t- Total : $($invoice.total)`r`nhttps://ipmcomputers.syncromsp.com/invoices/$($invoice.id)`r`n"
            }
            write-output "`t# UnPaid Customer Syncro Invoices : $(($script:customerInvoices | measure).count)`r`n`t$($script:strLineSeparator)"
            $script:paymentProfile = Syncro-Query "GET" "customers/$($script:customer.id)/payment_profiles" $null
            if (-not ($script:paymentProfile.payment_profiles)) {
              Pop-Warning $script:syncroWARN "$($script:customer.fullname) | $($script:customer.business_name)" "WARN : UnPaid Invoices Detected - No Payment Profile Detected`r`n"
              $script:payTickets = Syncro-Query "GET" "tickets" "customer_id=$($script:customer.id)&query=Syncro Payment Alert"
              $script:payTickets = $script:payTickets.tickets | where {(($_.status -ne 'Resolved') -and ($_.customer_id -eq $script:customer.id))}
              if ($script:payTickets.tickets.count -gt 0) {
                write-output "`tOpen Payment Tickets Found : Not Creating Ticket"
              } elseif ($script:payTickets.tickets.count -le 0) {
                write-output "`tNo Open Payment Tickets Found : Creating Ticket"
                $newTicket = @{
                  number               = $null
                  ticket_type_id       = 42563
                  status               = "New"
                  priority             = "2 Normal"
                  due_date             = "$((get-date).adddays(7))"
                  subject              = "Syncro Payment Alert"
                  customer_id          = $script:customer.id
                  problem_type         = "RMS - Remote Support"
                  properties           = $null
                  asset_ids            = $null
                  comments_attributes  = @(
                    @{
                      hidden        = $false
                      do_not_email  = $true
                      tech          = 'Syncro API - Payments'
                      subject       = "UnPaid Invoices - No Payment Profile"
                      body          = "$($invoices)"
                      #sms_body      = "$($invoices)"
                    }
                  )
                }
                Syncro-Post "POST" "tickets" $newTicket
              }
            }
          }
        }
      }
    }
  }
} catch {
  $script:blnWARN = $true
  $script:diag += "`r`nSyncro_Payments : Failed to query API via $($params.Uri)"
  $script:diag += "`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
  write-output "$($script:diag)`r`n"
}

write-output "`r`n$($strLineSeparator)`r`n`tThe Following Warning(s) Occurred :"
foreach ($key in $script:syncroWARN.keys) {
  write-output "`t$($strLineSeparator)`r`n`t$($strLineSeparator)`r`n`t$(($key).trim())`r`n`t`t$($strLineSeparator)"
  foreach ($warn in $script:syncroWARN[$key]) {
    write-output "`t`t$($warn.trim())`r`n`t`t$($strLineSeparator)"
  }
}
write-output "$($strLineSeparator)`r`n"