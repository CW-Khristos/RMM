<#--Copyright 2023 Cameron Day, Chris Bledsoe, Haley Parnell#>
$script:exchWARN   = @{}
$script:diag       = $null
$script:finish     = $null
$script:blnWARN    = $false
$script:blnBREAK   = $false
$strLineSeparator  = "----------"
$logPath           = "C:\IT\Log\Exchange_Monitor"

#region ------ FUNCTIONS -----
function write-DRMMDiag ($messages) {
    Write-Output "<-Start Diagnostic->"
    foreach ($message in $messages) {$message}
    Write-Output "<-End Diagnostic->"
}
function write-DRMMAlert ($message) {
    Write-Output "<-Start Result->"
    write-output "Alert=$($message)"
    Write-Output "<-End Result->"
}

function dir-Check () {
    #CHECK 'PERSISTENT' FOLDERS
    if (-not (test-path -path "C:\temp")) {new-item -path "C:\temp" -itemtype directory -force}
    if (-not (test-path -path "C:\IT")) {new-item -path "C:\IT" -itemtype directory -force}
    if (-not (test-path -path "C:\IT\Log")) {new-item -path "C:\IT\Log" -itemtype directory -force}
    if (-not (test-path -path "C:\IT\Scripts")) {new-item -path "C:\IT\Scripts" -itemtype directory -force}
}

function logERR ($intSTG, $strModule, $strErr) {
    #CUSTOM ERROR CODES
    switch ($intSTG) {
        1 {                                                         #'ERRRET'=1 - NOT ENOUGH ARGUMENTS, END SCRIPT
            $script:blnBREAK = $true
            $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - Exchange_Monitor - NO ARGUMENTS PASSED, END SCRIPT`r`n`r`n"
            write-output "$($strLineSeparator)`r`n$($(get-date)) - Exchange_Monitor - NO ARGUMENTS PASSED, END SCRIPT`r`n"
        }
        2 {                                                         #'ERRRET'=2 - END SCRIPT
            $script:blnBREAK = $true
            $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - Exchange_Monitor - ($($strModule)) :"
            $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n"
            write-output "$($strLineSeparator)`r`n$($(get-date)) - Exchange_Monitor - ($($strModule)) :"
            write-output "$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n"
        }
        3 {                                                         #'ERRRET'=3
            #$script:blnWARN = $false
            $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - Exchange_Monitor - $($strModule) :"
            $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
            write-output "$($strLineSeparator)`r`n$($(get-date)) - Exchange_Monitor - $($strModule) :"
            write-output "$($strLineSeparator)`r`n`t$($strErr)"
        }
        default {                                                   #'ERRRET'=4+
            $script:blnWARN = $true
            $script:blnBREAK = $false
            $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - Exchange_Monitor - $($strModule) :"
            $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
            write-output "$($strLineSeparator)`r`n$($(get-date)) - Exchange_Monitor - $($strModule) :"
            write-output "$($strLineSeparator)`r`n`t$($strErr)"
        }
    }
}

function StopClock {
    $script:finish ="$((get-date).ToString('yyyy-MM-dd HH:mm:ss'))"
    logERR 3 "StopClock" "$($script:finish) - Completed Execution"
    #Stop stop execution time calculation
    $script:sw.Stop()
    $Days = $sw.Elapsed.Days
    $Hours = $sw.Elapsed.Hours
    $Minutes = $sw.Elapsed.Minutes
    $Seconds = $sw.Elapsed.Seconds
    $Milliseconds = $sw.Elapsed.Milliseconds
    $ScriptStopTime = (Get-Date -Format "yyyy-MM-dd HH:mm:ss").ToString()
    Write-Output "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
    $script:diag += "`r`n`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
} 

<#--Template Function for Final Result Alert Output#>
function Pop-Warning ($dest, $key, $warn) {
    #POPULATE WARNINGS DATA INTO NESTED HASHTABLE FORMAT FOR LATER USE
    try {
        $blnADD = $true
        $new = [System.Collections.ArrayList]@()
        $prev = [System.Collections.ArrayList]@()
        if (($warn -ne $null) -and ($key -ne "")) {
            write-output "$($warn)"
            $script:diag += "$($warn)`r`n"
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

<#--Template Function for WMI Queries--#>
function Get-ExchangeWMIData ($namespace, $class) {
    $script:exchangePerfData = @()
    try {
        $script:wmiPerfData = get-wmiobject -namespace "$($namespace)" -class "$($class)"
        foreach ($instance in $script:wmiPerfData) {
            $prophash = @()
            $instancehash = @()
            if (($null -ne $instance.name) -and ($instance.name -ne "")) {
                $instance | get-member | 
                    where {(($_.name -notmatch "_") -and ($_.membertype -eq "Property"))} | 
                        foreach {
                            #write-output $_.name
                            if (($null -ne $_.name) -and ($_.name -ne "")) {$prophash += @{$_.name = $instance.$($_.name)}}
                }
                $instancehash = @{$instance.name = $prophash}
                $script:exchangePerfData += $instancehash
            }
        }
        return $script:exchangePerfData
    } catch {
        logERR 3 "Get-ExchangeWMIData" "No -namespace '$($namespace)' -class '$($class)' Data`r`n$($strLineSeparator)"
    }
}
#endregion ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
clear-host
#Start script execution time calculation
$script:sw = [Diagnostics.Stopwatch]::StartNew()
$ScrptStartTime = (get-date -Format "yyyy-MM-dd HH:mm:ss").ToString()
#CHECK 'PERSISTENT' FOLDERS
dir-Check

#region--Exchange Database--#>
logERR 3 "Exchange Database" "Checking MS Exchange Database Metrics`r`n$($strLineSeparator)"
$script:exchPerfData = Get-ExchangeWMIData "root/cimv2" "Win32_PerfFormattedData_ESE_MSExchangeDatabase"
foreach ($db in $script:exchPerfData.keys) {
    write-output "`t$($strLineSeparator)`r`n`t$($db) :`r`n`t$($strLineSeparator)"; $script:diag += "`t$($strLineSeparator)`r`n`t$($db) :`r`n`t$($strLineSeparator)`r`n"
    $strOUT = "`t$($db) - Database Page Faults (per Sec) : $($script:exchPerfData.$db.DatabasePageFaultsPersec)"
    switch ($script:exchPerfData.$db.PageFaultpsec) {
        {$_ -le 10} {$script:diag += "$($strOUT) : Normal`r`n"; write-output "$($strOUT) : Normal"; break}
        {(($_ -gt 10) -and ($_ -lt 100))} {Pop-Warning $script:exchWARN $db "$($strOUT) : Warning`r`n"; break}
        {$_ -ge 100} {Pop-Warning $script:exchWARN $db "$($strOUT) : Failed`r`n"; break}
    }
    $strOUT = "`t$($db) - Database Cache Percent Hit : $($script:exchPerfData.$db.DatabaseCachePercentHit)"
    switch ($script:exchPerfData.$db.CachePercentHit) {
        {(($_ -ge 90) -and ($_ -le 100))} {$script:diag += "$($strOUT) : Normal`r`n"; write-output "$($strOUT) : Normal"; break}
        {(($_ -ge 80) -and ($_ -lt 90))} {Pop-Warning $script:exchWARN $db "$($strOUT) : Warning`r`n"; break}
        {(($_ -ge 0) -and ($_ -lt 70))} {Pop-Warning $script:exchWARN $db "$($strOUT) : Failed`r`n"; break}
    }
    $strOUT = "`t$($db) - Log Record Stals (per Sec) : $($script:exchPerfData.$db.LogRecordStallsPersec)"
    switch ($script:exchPerfData.$db.LogRecordStallpsec) {
        {$_ -le 10} {$script:diag += "$($strOUT) : Normal`r`n"; write-output "$($strOUT) : Normal"; break}
        {(($_ -gt 10) -and ($_ -lt 50))} {Pop-Warning $script:exchWARN $db "$($strOUT) : Warning`r`n"; break}
        {(($_ -ge 50) -and ($_ -le 100))} {Pop-Warning $script:exchWARN $db "$($strOUT) : Failed`r`n"; break}
    }
    $strOUT = "`t$($db) - Log Threads Waiting : $($script:exchPerfData.$db.LogThreadsWaiting)"
    switch ($script:exchPerfData.$db.LogThreadsWait) {
        {$_ -le 10} {$script:diag += "$($strOUT) : Normal`r`n"; write-output "$($strOUT) : Normal"; break}
        {(($_ -gt 10) -and ($_ -lt 50))} {Pop-Warning $script:exchWARN $db "$($strOUT) : Warning`r`n"; break}
        {(($_ -ge 50) -and ($_ -le 100))} {Pop-Warning $script:exchWARN $db "$($strOUT) : Failed`r`n"; break}
    }
}
write-output "$($strLineSeparator)"; $script:diag += "$($strLineSeparator)`r`n"
#endregion

#region--Exchange Database Delivery Queue Service--#>
logERR 3 "Exchange Delivery Queue" "Checking MS Exchange Delivery Queue Metrics`r`n$($strLineSeparator)"
$script:exchPerfData = Get-ExchangeWMIData "root/cimv2" "Win32_PerfRawData_MSExchangeTransportQueues_MSExchangeTransportQueues"
foreach ($dq in $script:exchPerfData.keys) {
    write-output "`t$($strLineSeparator)`r`n`t$($dq) :`r`n`t$($strLineSeparator)"; $script:diag += "`t$($strLineSeparator)`r`n`t$($dq) :`r`n`t$($strLineSeparator)`r`n"
    $strOUT = "`t$($dq) - Active Mailbox Delivery Queue Length : $($script:exchPerfData.$dq.ActiveMailboxDeliveryQueueLength)"
    switch ($script:exchPerfData.$dq.ActiveMailboxDeliveryQueueLength) {
        {$_ -le 100} {$script:diag += "$($strOUT) : Normal`r`n"; write-output "$($strOUT) : Normal"; break}
        {(($_ -ge 101) -and ($_ -le $249))} {Pop-Warning $script:exchWARN $dq "$($strOUT) : Warning`r`n"; break}
        {$_ -ge 250} {Pop-Warning $script:exchWARN $dq "$($strOUT) : Failed`r`n"; break}
    }
    $strOUT = "`t$($dq) - Active Non-SMTP Delivery Queue Length : $($script:exchPerfData.$dq.ActiveNonSmtpDeliveryQueueLength)"
    switch ($script:exchPerfData.$dq.ActiveNonSmtpDeliveryQueueLength) {
        {$_ -le 100} {$script:diag += "$($strOUT) : Normal`r`n"; write-output "$($strOUT) : Normal"; break}
        {(($_ -ge 101) -and ($_ -le 249))} {Pop-Warning $script:exchWARN $dq "$($strOUT) : Warning`r`n"; break}
        {$_ -ge 250} {Pop-Warning $script:exchWARN $dq "$($strOUT) : Failed`r`n"; break}
    }
    if ($script:exchPerfData.$dq.ActiveRemoteDeliveryQueueLength) {
        $strOUT = "`t$($dq) - Active Remote Delivery Queue Length : $($script:exchPerfData.$dq.ActiveRemoteDeliveryQueueLength)"
        switch ($script:exchPerfData.$dq.ActiveRemoteDeliveryQueueLength) {
            {$_ -le 100} {$script:diag += "$($strOUT) : Normal`r`n"; write-output "$($strOUT) : Normal"; break}
            {(($_ -ge 101) -and ($_ -le 249))} {Pop-Warning $script:exchWARN $dq "$($strOUT) : Warning`r`n"; break}
            {$_ -ge 250} {Pop-Warning $script:exchWARN $dq "$($strOUT) : Failed`r`n"; break}
        }
    }
    if ($script:exchPerfData.$dq.DelayQueueLength) {
        $strOUT = "`t$($dq) - Largest Delivery Queue Length : $($script:exchPerfData.$dq.DelayQueueLength)"
        switch ($script:exchPerfData.$dq.DelayQueueLength) {
            {$_ -le 100} {$script:diag += "$($strOUT) : Normal`r`n"; write-output "$($strOUT) : Normal"; break}
            {(($_ -ge 101) -and ($_ -le 249))} {Pop-Warning $script:exchWARN $dq "$($strOUT) : Warning`r`n"; break}
            {$_ -ge 250} {Pop-Warning $script:exchWARN $dq "$($strOUT) : Failed`r`n"; break}
        }
    }
    $strOUT = "`t$($dq) - Poison Queue Length : $($script:exchPerfData.$dq.PoisonQueueLength)"
    switch ($script:exchPerfData.$dq.PoisonQueueLength) {
        {$_ -le 0} {$script:diag += "$($strOUT) : Normal`r`n"; write-output "$($strOUT) : Normal"; break}
        {(($_ -ge 1) -and ($_ -le 4))} {Pop-Warning $script:exchWARN $dq "$($strOUT) : Warning`r`n"; break}
        {$_ -ge 5} {Pop-Warning $script:exchWARN $dq "$($strOUT) : Failed`r`n"; break}
    }
    $strOUT = "`t$($dq) - Retry Mailbox Delivery Queue Length : $($script:exchPerfData.$dq.RetryMailboxDeliveryQueueLength)"
    switch ($script:exchPerfData.$dq.RetryMailboxDeliveryQueueLength) {
        {$_ -le 100} {$script:diag += "$($strOUT) : Normal`r`n"; write-output "$($strOUT): Normal"; break}
        {(($_ -ge 101) -and ($_ -le 249))} {Pop-Warning $script:exchWARN $dq "$($strOUT) : Warning`r`n"; break}
        {$_ -ge 250} {Pop-Warning $script:exchWARN $dq "$($strOUT) : Failed`r`n"; break}
    }
    $strOUT = "`t$($dq) - Retry Non-SMTP Delivery Queue Length : $($script:exchPerfData.$dq.RetryNonSMTPDeliveryQueueLength)"
    switch ($script:exchPerfData.$dq.RetryNonSMTPDeliveryQueueLength) {
        {$_ -le 100} {$script:diag += "$($strOUT) : Normal`r`n"; write-output "$($strOUT): Normal"; break}
        {(($_ -ge 101) -and ($_ -le 249))} {Pop-Warning $script:exchWARN $dq "$($strOUT) : Warning`r`n"; break}
        {$_ -ge 250} {Pop-Warning $script:exchWARN $dq "$($strOUT) : Failed`r`n"; break}
    }
    $strOUT = "`t$($dq) - Submission Queue Length : $($script:exchPerfData.$dq.SubmissionQueueLength)"
    switch ($script:exchPerfData.$dq.SubmissionQueueLength) {
        {$_ -le 100} {$script:diag += "$($strOUT) : Normal`r`n"; write-output "$($strOUT) : Normal"; break}
        {(($_ -ge 101) -and ($_ -le 249))} {Pop-Warning $script:exchWARN $dq "$($strOUT) : Warning`r`n"; break}
        {$_ -ge 250} {Pop-Warning $script:exchWARN $dq "$($strOUT) : Failed`r`n"; break}
    }
    $strOUT = "`t$($dq) - Unreachable Queue Length : $($script:exchPerfData.$dq.UnreachableQueueLength)"
    switch ($script:exchPerfData.$dq.UnreachableQueueLength) {
        {$_ -le 100} {$script:diag += "$($strOUT) : Normal`r`n"; write-output "$($strOUT) : Normal"; break}
        {(($_ -ge 101) -and ($_ -le 249))} {Pop-Warning $script:exchWARN $dq "$($strOUT) : Warning`r`n"; break}
        {$_ -ge 250} {Pop-Warning $script:exchWARN $dq "$($strOUT) : Failed`r`n"; break}
    }
}
write-output "$($strLineSeparator)"; $script:diag += "$($strLineSeparator)`r`n"
#endregion

#region--Exchange Database Latency 2013/2016 Service--#>
<#--Read/Write values are in miliseconds. Log generation values are for the depth of said log. --#>
logERR 3 "Exchange Database Latency" "Checking MS Exchange Database Latency Metrics`r`n$($strLineSeparator)"
$script:exchPerfData = Get-ExchangeWMIData "root/cimv2" "Win32_PerfFormattedData_ESE_MSExchangeDatabaseInstances"
foreach ($dl in $script:exchPerfData.Keys) {
    write-output "`t$($strLineSeparator)`r`n`t$($dl) :`r`n`t$($strLineSeparator)"; $script:diag += "`t$($strLineSeparator)`r`n`t$($dl) :`r`n`t$($strLineSeparator)`r`n"
    $strOut = "`t$($dl) - Log Generation Checkpoint Depth : $($script:exchPerfData.$dl.LogGenerationCheckpointDepth)"
    Switch ($script:exchPerfData.$dl.LogGenerationCheckpointDepth) {
        {$_ -lt 350} {$script:diag += "$($strOUT) : Normal`r`n"; write-output "$($strOUT) : Normal"; break}
        {$_ -ge 350} {Pop-Warning $script:exchWARN $dl "$($strOUT) : Warning`r`n"; break}
        {$_ -ge 500} {Pop-Warning $script:exchWARN $dl "$($strOUT) : Failed`r`n"; break}
    }
    $strOut = "`t$($dl) - IO Database Reads Average Latency : $($script:exchPerfData.$dl.IODatabaseReadsAverageLatency)"
    Switch ($script:exchPerfData.$dl.IODatabaseReadsAverageLatency) {
        {$_ -le 20} {$script:diag += "$($strOUT) : Normal`r`n"; write-output "$($strOUT) : Normal"; break}
        {$_ -gt 20} {Pop-Warning $script:exchWARN $dl "$($strOUT) : Warning`r`n"; break}
    }
    $strOut = "`t$($dl) - IO Database Writes Average Latency : $($script:exchPerfData.$dl.IODatabaseWritesAverageLatency)"
    Switch ($script:exchPerfData.$dl.IODatabaseWritesAverageLatency) {
        {$_ -le 50} {$script:diag += "$($strOUT) : Normal`r`n"; write-output "$($strOUT) : Normal"; break}
        {$_ -gt 50} {Pop-Warning $script:exchWARN $dl "$($strOUT) : Warning`r`n"; break}
    }
}
write-output "$($strLineSeparator)"; $script:diag += "$($strLineSeparator)`r`n"
#endregion

#region--Exchange Processing Time--#>
<#
Win32_PerfFormattedData_MSExchangeOWA_MSExchangeOWA ?
Win32_PerfFormattedData_MSExchangeADPerformance_MSExchangeADPerformance.ServerProcessingTime ?
Win32_PerfFormattedData_MSExchangeADPerformance_MSExchangeADPerformance.ClientProcessingTime ?
Win32_PerfFormattedData_MSExchangeActiveSync_MSExchangeActiveSync.AverageRequestTime ?
#>
try {
    logERR 3 "Exchange Processing Time" "Checking MS Exchange Processing Time Metrics`r`n$($strLineSeparator)"
    $script:exchPerfData = Get-ExchangeWMIData "root/cimv2" "Win32_PerfFormattedData_MSExchangeProcessingTime"
    foreach ($pt in $script:exchPerfData.keys) {
        write-output "`t$($strLineSeparator)`r`n`t$($pt) :`r`n`t$($strLineSeparator)"; $script:diag += "`t$($strLineSeparator)`r`n`t$($pt) :`r`n`t$($strLineSeparator)`r`n"
        $strOUT = "`t$($pt) - Average Search Processing Time : $($script:exchPerfData.$pt.AverageSearchProcessingTime)"
        switch ($script:exchPerfData.$pt.AverageSearchProcessingTime) {
            {$_ -le 5000} {$script:diag += "$($strOUT) : Normal`r`n"; write-output "$($strOUT) : Normal"; break}
            default {Pop-Warning $script:exchWARN $pt "$($strOUT) : Failed`r`n"; break}
        }
        $strOUT = "`t$($pt) - Outbound Proxy Requests Average Response Time : $($script:exchPerfData.$pt.OutboundProxyRequestsAverageResponseTime)"
        switch ($script:exchPerfData.$pt.OutboundProxyRequestsAverageResponseTime) {
            {$_ -le 6000} {$script:diag += "$($strOUT) : Normal`r`n"; write-output "$($strOUT) : Normal"; break}
            default {Pop-Warning $script:exchWARN $pt "$($strOUT) : Failed`r`n"; break}
        }
        $strOUT = "`t$($pt) - Requests Average Response Time : $($script:exchPerfData.$pt.RequestsAverageResponseTime)"
        switch ($script:exchPerfData.$pt.RequestsAverageResponseTime) {
            {$_ -le 6000} {$script:diag += "$($strOUT) : Normal`r`n"; write-output "$($strOUT) : Normal"; break}
            default {Pop-Warning $script:exchWARN $pt "$($strOUT) : Failed`r`n"; break}
        }
    }
    write-output "$($strLineSeparator)"; $script:diag += "$($strLineSeparator)`r`n"
} catch {
    logERR 3 "Exchange Processing Time" "Error Processing MS Exchange Processing Time WMI Metrics`r`n$($strLineSeparator)"
}
#endregion

#region--Exchange Database Store Mount Status --#>
<#
Database Name	The name of the Microsoft Exchange database the service is monitoring.
Database Mount Status	Indicates the status of the database's accessibility as one of:
Normal 1 : The database is mounted and accessible.
Warning 0 : The database is unmounted and not accessible.
Failed -1 : The service cannot determine the status of the database. The database may or may not be mounted and accessible.
Database Copy Role Active Status	Indicates the Active status of the database's accessibility as one of:
Normal 1 : Database Copy is Active
Warning 0 : Database Copy is Not Active
Failed -1 : The service cannot determine the status of the database. The database may or may not be mounted and accessible.
#>
logERR 3 "Exchange Database Store" "Checking MS Exchange Database Store Metrics`r`n$($strLineSeparator)"
$script:exchPerfData = Get-ExchangeWMIData "root/cimv2" "Win32_PerfFormattedData_MSExchangeActiveManager_MSExchangeActiveManager"
foreach ($db in $script:exchPerfData.keys) {
    write-output "`t$($strLineSeparator)`r`n`t$($db) :`r`n`t$($strLineSeparator)"; $script:diag += "`t$($strLineSeparator)`r`n`t$($db) :`r`n`t$($strLineSeparator)`r`n"
    $strOUT = "`t$($db) - Database Mounted : $($script:exchPerfData.$db.DatabaseMounted)"
    switch ($script:exchPerfData.$db.DatabaseMounted) {
        {$_ -eq 1} {$script:diag += "$($strOUT) : Normal : DB Mounted`r`n"; write-output "$($strOUT) : Normal : DB Mounted"; break}
        {$_ -eq 0} {Pop-Warning $script:exchWARN $db "$($strOUT) : Warning : DB Not Mounted`r`n"; break}
        default    {Pop-Warning $script:exchWARN $db "$($strOUT) : Failed : UnKnown Status`r`n"; break}
    }
    $strOUT = "`t$($db) - Database Copy Role Active : $($script:exchPerfData.$db.DatabaseCopyRoleActive)"
    switch ($script:exchPerfData.$db.DatabaseCopyRoleActive) {
        {$_ -eq 1} {$script:diag += "$($strOUT) : Normal : DB Copy Active`r`n"; write-output "$($strOUT) : Normal : DB Copy Active"; break}
        {$_ -eq 0} {Pop-Warning $script:exchWARN $db "$($strOUT) : Warning : Not Active`r`n"; break}
        default {Pop-Warning $script:exchWARN $db "$($strOUT) : Failed : UnKnown Status`r`n"; break}
    }
}
write-output "$($strLineSeparator)"; $script:diag += "$($strLineSeparator)`r`n"
#endregion

#DATTO OUTPUT
logERR 3 "RESULT" "The following details failed checks :`r`n$($strLineSeparator)"
foreach ($warn in $script:exchWARN.values) {
  $script:diag += "`r`n`t$($warn)`r`n"
  write-output "`t$($warn)"
}
$script:diag += "$($strLineSeparator)`r`n"
write-output "$($strLineSeparator)"
#Stop script execution time calculation
StopClock
#CLEAR LOGFILE
$null | set-content $logPath -force
if (-not $script:blnBREAK) {
  if (-not $script:blnWARN) {
    #WRITE TO LOGFILE
    $enddiag = "Execution Successful : $($script:finish)"
    logERR 3 "END" "$($enddiag)"
    "$($script:diag)" | add-content $logPath -force
    write-DRMMAlert "Exchange_Monitor : Successful : Diagnostics - $($logPath) : $($script:finish)"
    write-DRMMDiag "$($script:diag)"
    exit 0
  } elseif ($script:blnWARN) {
    #WRITE TO LOGFILE
    $enddiag = "Execution Completed with Warnings : $($script:finish)"
    logERR 3 "END" "$($enddiag)"
    "$($script:diag)" | add-content $logPath -force
    write-DRMMAlert "Exchange_Monitor : Warning : Diagnostics - $($logPath) : $($script:finish)"
    write-DRMMDiag "$($script:diag)"
    exit 1
  }
} elseif ($script:blnBREAK) {
  #WRITE TO LOGFILE
  $enddiag = "Execution Failed : $($script:finish)"
  logERR 4 "END" "$($enddiag)"
  "$($script:diag)" | add-content $logPath -force
  write-DRMMAlert "Exchange_Monitor : Failure : Diagnostics - $($logPath) : $($script:finish)"
  write-DRMMDiag "$($script:diag)"
  $script:diag = $null
  exit 1
}
#END SCRIPT
#------------