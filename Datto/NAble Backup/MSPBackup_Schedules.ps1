#region ----- DECLARATIONS ----
  #BELOW PARAM() MUST BE COMMENTED OUT FOR USE WITHIN DATTO RMM
  #UNCOMMENT BELOW PARAM() AND RENAME '$env:var' TO '$var' TO UTILIZE IN CLI
  #Param (
  #)
  #VERSION FOR SCRIPT UPDATE
  $strSCR             = "MSPMSPBackup_Schedules"
  $strVER             = [version]"0.1.2"
  $strREPO            = "RMM"
  $strBRCH            = "dev"
  $strDIR             = "Datto"
  $script:diag        = $null
  $script:blnWARN     = $false
  $script:blnBREAK    = $false
  $strLineSeparator   = "---------"
  $hashMsg            = $null
  $curHashAll         = $env:UDF_16
  $udfSelection       = $env:udfSelection
  $curSchedules       = $env:UDF_17
  $hashSchedules      = $env:UDF_18
  $udfSchedules       = $env:udfSchedules
  $curArchives        = $env:UDF_19
  $hashArchives       = $env:UDF_20
  $udfArchives        = $env:udfArchives
  $curThrottle        = $env:UDF_21
  $udfThrottle        = $env:udfThrottle
  $script:blnBMAuth   = $false
  $AllDevices         = $false
  $AllPartners        = $false
  $urlJSON            = 'https://api.backup.management/jsonapi'
  $logPath            = "C:\IT\Log\MSPMSPBackup_Schedules_$($strVER).log"
  #MXB PATH
  $mxbPath            = ${env:ProgramData} + "\MXB\Backup Manager"
  $script:True_path   = "C:\ProgramData\MXB\"
  $script:APIcredfile = join-path -Path $True_Path -ChildPath "$env:computername API_Credentials.Secure.txt"
  $script:APIcredpath = Split-path -path $APIcredfile
  #TLS
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  [System.Net.ServicePointManager]::MaxServicePointIdleTime = 5000000
  #SANITIZE DRMM VARIABLES
  if (($null -eq $script:PartnerName) -or ($script:PartnerName -eq "")) {$script:PartnerName = $env:BackupRoot}
  if (($null -eq $script:BackupUser) -or ($script:BackupUser -eq "")) {$script:BackupUser = $env:BackupUser}
  if (($null -eq $script:BackupPass) -or ($script:BackupPass -eq "")) {$script:BackupPass = $env:BackupPass}
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

  function Convert-UnixTimeToDateTime ($inputUnixTime) {
    if ($inputUnixTime -gt 0 ) {
      $epoch = Get-Date -Date "1970-01-01 00:00:00Z"
      $epoch = $epoch.ToUniversalTime()
      $epoch = $epoch.AddSeconds($inputUnixTime)
      return $epoch
    } else {
      return ""
    }
  }  ## Convert epoch time to date time

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
    $mill = [string]($total / 1000)
    $mill = $mill.split(".")[1]
    $mill = $mill.SubString(0,[math]::min(3,$mill.length))
    $script:diag += "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
    write-output "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
  }

  function logERR($intSTG, $strModule, $strErr) {
    $script:blnWARN = $true
    #CUSTOM ERROR CODES
    switch ($intSTG) {
      1 {                                                         #'ERRRET'=1 - NOT ENOUGH ARGUMENTS, END SCRIPT
        $script:blnBREAK = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - MSPBackup_Schedules - NO ARGUMENTS PASSED, END SCRIPT`r`n`r`n"
        write-output "$($strLineSeparator)`r`n$($(get-date)) - MSPBackup_Schedules - NO ARGUMENTS PASSED, END SCRIPT`r`n"
      }
      2 {                                                         #'ERRRET'=2 - END SCRIPT
        $script:blnBREAK = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - MSPBackup_Schedules - ($($strModule)) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n"
        write-output "$($strLineSeparator)`r`n$($(get-date)) - MSPBackup_Schedules - ($($strModule)) :"
        write-output "$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n"
      }
      3 {                                                         #'ERRRET'=3
        $script:blnWARN = $false
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - MSPBackup_Schedules - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)`r`n"
        write-output "$($strLineSeparator)`r`n$($(get-date)) - MSPBackup_Schedules - $($strModule) :"
        write-output "$($strLineSeparator)`r`n`t$($strErr)"
      }
      default {                                                   #'ERRRET'=4+
        $script:blnBREAK = $false
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - MSPBackup_Schedules - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)`r`n"
        write-output "$($strLineSeparator)`r`n$($(get-date)) - MSPBackup_Schedules - $($strModule) :"
        write-output "$($strLineSeparator)`r`n`t$($strErr)"
      }
    }
  }

#region ----- Authentication ----
  function Send-APICredentialsCookie {
    #Get-APICredentials  ## Read API Credential File before Authentication
    $url = $urlJSON
    $data = @{}
    $data.jsonrpc = '2.0'
    $data.id = '2'
    $data.method = 'Login'
    $data.params = @{}
    $data.params.partner = $script:PartnerName
    $data.params.username = $script:BackupUser
    $data.params.password = $script:BackupPass

    $webrequest = Invoke-WebRequest -Method POST `
      -ContentType 'application/json' `
      -Body (ConvertTo-Json $data) `
      -Uri $url `
      -SessionVariable script:websession `
      -UseBasicParsing
    $script:cookies = $websession.Cookies.GetCookies($url)
    $script:websession = $websession
    $script:Authenticate = $webrequest | convertfrom-json
    #Debug write-output "Cookie : $($script:cookies[0].name) = $($cookies[0].value)"
    $webrequest

    if ($authenticate.visa) {
      $script:blnBMAuth = $true
      write-output "`tBM Auth : $($script:blnBMAuth)"
      $script:visa = $authenticate.visa
    } else {
      $script:blnBMAuth = $false
      write-output "`tBM Auth : $($script:blnBMAuth)"
      $authMsg = "Authentication Failed: Please confirm your Backup.Management Partner Name and Credentials`r`n`t$($strLineSeparator)"
      $authMsg += "`r`n`tPlease Note: Multiple failed authentication attempts could temporarily lockout your user account`r`n`t$($strLineSeparator)"
      logERR 4 "Send-APICredentialsCookie" "$($authMsg)`r`n$($strLineSeparator)"
      #Set-APICredentials  ## Create API Credential File if Authentication Fails
    }
  }  ## Use Backup.Management credentials to Authenticate
#endregion ----- Authentication ----

#region ----- Backup.Management JSON Calls ----
  function CallJSON ($url,$object) {
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
    $data.visa = $script:visa
    $data.method = 'GetPartnerInfo'
    $data.params = @{}
    $data.params.name = [String]$PartnerName

    $webrequest = Invoke-WebRequest -Method POST `
      -ContentType 'application/json' `
      -Body (ConvertTo-Json $data -depth 5) `
      -Uri $url `
      -SessionVariable $script:websession `
      -UseBasicParsing
      $script:cookies = $websession.Cookies.GetCookies($url)
      $script:websession = $websession
      $script:Partner = $webrequest | convertfrom-json

    $RestrictedPartnerLevel = @("Root","Sub-root","Distributor")
    <#---# POWERSHELL 2.0 #---#>
    if ($RestrictedPartnerLevel -notcontains $Partner.result.result.Level) {
    #---#>
    <#---# POWERSHELL 3.0+ #--->
    if ($Partner.result.result.Level -notin $RestrictedPartnerLevel) {
    #---#>
      [String]$script:Uid = $Partner.result.result.Uid
      [int]$script:PartnerId = [int]$Partner.result.result.Id
      [String]$script:Level = $Partner.result.result.Level
      [String]$script:PartnerName = $Partner.result.result.Name
      logERR 3 "Send-GetPartnerInfo" "$($PartnerName) - $($partnerId) - $($Uid)`r`n$($strLineSeparator)"
    } else {
      logERR 3 "Send-GetPartnerInfo" "Lookup for $($Partner.result.result.Level) Partner Level Not Allowed`r`n$($strLineSeparator)"
    }

    if ($partner.error) {
      write-output "  $($partner.error.message)"
      $script:diag += "  $($partner.error.message)`r`n"
    }
  } ## Send-GetPartnerInfo API Call

  function Send-GetDevices {
    $url = $urlJSON
    $method = 'POST'
    $data = @{}
    $data.jsonrpc = '2.0'
    $data.id = '2'
    $data.visa = $script:visa
    $data.method = 'EnumerateAccountStatistics'
    $data.params = @{}
    $data.params.query = @{}
    $data.params.query.PartnerId = [int]$PartnerId
    $data.params.query.Filter = $Filter1
    $data.params.query.Columns = @("AU","AR","AN","MN","AL","LN","OP","OI","OS","PD","AP","PF","PN","CD","TS","TL","T3","US","AA843","AA77","AA2048","AA2531")
    $data.params.query.OrderBy = "CD DESC"
    $data.params.query.StartRecordNumber = 0
    $data.params.query.RecordsCount = 2000
    $data.params.query.Totals = @("COUNT(AT==1)","SUM(T3)","SUM(US)")
    $jsondata = (ConvertTo-Json $data -depth 6)

    $params = @{
      Uri         = $url
      Method      = $method
      Headers     = @{ 'Authorization' = "Bearer $($script:visa)" }
      Body        = ([System.Text.Encoding]::UTF8.GetBytes($jsondata))
      ContentType = 'application/json; charset=utf-8'
    }

    $script:DeviceDetail = @()
    $script:DeviceResponse = Invoke-RestMethod @params
    ForEach ( $DeviceResult in $DeviceResponse.result.result ) {
      $script:DeviceDetail += New-Object -TypeName PSObject -Property @{
        AccountID      = [Int]$DeviceResult.AccountId;
        PartnerID      = [string]$DeviceResult.PartnerId;
        DeviceName     = $DeviceResult.Settings.AN -join '' ;
        ComputerName   = $DeviceResult.Settings.MN -join '' ;
        DeviceAlias    = $DeviceResult.Settings.AL -join '' ;
        PartnerName    = $DeviceResult.Settings.AR -join '' ;
        Reference      = $DeviceResult.Settings.PF -join '' ;
        Creation       = Convert-UnixTimeToDateTime ($DeviceResult.Settings.CD -join '') ;
        TimeStamp      = Convert-UnixTimeToDateTime ($DeviceResult.Settings.TS -join '') ;
        LastSuccess    = Convert-UnixTimeToDateTime ($DeviceResult.Settings.TL -join '') ;
        SelectedGB     = (($DeviceResult.Settings.T3 -join '') /1GB) ;
        UsedGB         = (($DeviceResult.Settings.US -join '') /1GB) ;
        DataSources    = $DeviceResult.Settings.AP -join '' ;
        Account        = $DeviceResult.Settings.AU -join '' ;
        Location       = $DeviceResult.Settings.LN -join '' ;
        Notes          = $DeviceResult.Settings.AA843 -join '' ;
        GUIPassword    = $DeviceResult.Settings.AA2048 -join '' ;
        IPMGUIPwd      = $DeviceResult.Settings.AA2531 -join '' ;
        TempInfo       = $DeviceResult.Settings.AA77 -join '' ;
        Product        = $DeviceResult.Settings.PN -join '' ;
        ProductID      = $DeviceResult.Settings.PD -join '' ;
        Profile        = $DeviceResult.Settings.OP -join '' ;
        OS             = $DeviceResult.Settings.OS -join '' ;
        ProfileID      = $DeviceResult.Settings.OI -join ''
      }
    }
  } ## Send-GetDevices API Call

  function AuditDeviceBandwidth($DeviceId) {
    $url2 = "https://backup.management/web/accounts/properties/api/audit?accounts.SelectedAccount.Id=$deviceId&accounts.SelectedAccount.StorageNode.Audit.Shift=0&accounts.SelectedAccount.StorageNode.Audit.Count=1&accounts.SelectedAccount.StorageNode.Audit.Filter=Bandwidth"
    $method = 'GET'
    $params = @{
      Uri         = $url2
      Method      = $method
      Headers     = @{ 'Authorization' = "Bearer $script:visa" }
      WebSession  = $websession
      ContentType = 'application/json; charset=utf-8'
    }   

    $script:AuditResponse = Invoke-RestMethod @params 
    $response = [string]$AuditResponse -replace("[][]","") -replace("[{}]","") -creplace("ESCAPE","") -replace('    ','') -replace("`n`n`n","") -replace(",`n,","") -replace("rows: ","") -split("`n")
    $response = $response -replace (": "," = ") | ConvertFrom-StringData -ErrorAction SilentlyContinue 
    $response = $response.details -replace ('"','') -replace (' = ',' ') -replace ('enable true start ','') -replace (' stop ','-') -replace ('upload ','') -replace (' download ','/') -replace ('unlimited ','') -replace ('unlimitedDays ','') -replace ('Saturday','SA') -replace ('Sunday','SU')           
    $response = $response -replace ('limitBandWidth=1','') -replace (' turnOffAt=','Off/') -replace ('turnOnAt=','On/') -replace ('maxUploadSpeed=','') -replace ('-1=','UNLIM') -replace (' kbit/s maxDownloadSpeed=','/') -replace('unlimitedDays=0000000','') -replace('pluginsToCancel=','') -replace('dataThroughputUnits=1','') -replace('dataThroughputUnits=2','')

    if ($response -like "*False*") { $response = "" } 
    if ($response -like "*limitBandWidth=0*") { $response = "" }
    $output = "DeviceId : $($DeviceId) - Bandwidth Throttle : $($response)"
    return $output
  }
#endregion ----- Backup.Management JSON Calls ----
#endregion ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
$i = -1
clear-host
$filter1 = $null
$script:DeviceDetail = @()
#Start script execution time calculation
$ScrptStartTime = (Get-Date).ToString('dd-MM-yyyy hh:mm:ss')
$script:sw = [Diagnostics.Stopwatch]::StartNew()
remove-item -Path $script:APIcredfile -force
write-output "$($strLineSeparator)`r`n"
$script:diag += "$($strLineSeparator)`r`n`r`n"
cd "C:\Program Files\Backup Manager"
$beginmsg = "Cached Archive Hash (UDF20) : $($hashArchives)`r`n"
$beginmsg += "`tCached Schedule Hash (UDF18) : $($hashSchedules)"
logERR 3 "BEGIN" "$($beginmsg)`r`n$($strLineSeparator)"
#QUERY BACKUP SCHEDULES
try {
  $scheduleset = $null
  $schedule = .\clienttool.exe control.schedule.list
  $schedule = $schedule | where {$_ -like "* yes *"} | out-string
  $array = $schedule.split([Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries)
  foreach ($line in $array) {$scheduleset += "`r`n`t$($line.trim())"}
  logERR 3 "SCHEDULE" "SCHEDULE :`r`n`t$($strLineSeparator)$($scheduleset)`r`n$($strLineSeparator)"
  $scheduleset = $null
  foreach ($line in $array) {
    $chunk = ($line.trim()).split(" ", [StringSplitOptions]::RemoveEmptyEntries)
    $scheduleset += "$($chunk[2])-$($chunk[4]) : $($chunk[7])-$($chunk[5]) - $($chunk[6]) | "
  }
  $scheduleset = $scheduleset.replace("FileSystem","FS").replace("NetworkShares","NS").replace("SystemState","SS").replace("Exchange","EXCH").replace("VMWare","VM").replace("HyperV","HV")
  $scheduleset = $scheduleset.replace("Monday","M").replace("Tuesday","T").replace("Wednesday","W").replace("Thursday","Th").replace("Friday","F").replace("Saturday","Sa").replace("Sunday","S")
  $array = $scheduleset.split('|', [StringSplitOptions]::RemoveEmptyEntries)
  $scheduleout = $null
  foreach ($line in $array) {if ($line -ne " ") {$scheduleout += "`r`n`t$($line.trim()) | "}}
  logERR 3 "SCHEDULE" "FINAL SCHEDULE :`r`n`t$($strLineSeparator)$($scheduleout)`r`n$($strLineSeparator)"
  #COMPUTE SCHEDULE HASH
  $utf8 = new-object -TypeName System.Text.UTF8Encoding
  $md5 = new-object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
  $hash = [System.BitConverter]::ToString($md5.ComputeHash($utf8.GetBytes($scheduleset)))
  logERR 3 "SCHEDULE" "COMPUTED SCHEDULE HASH :`r`n`t$($strLineSeparator)`r`n`t$($hash)`r`n$($strLineSeparator)"
  #COMPARE SCHEDULE HASH
  if ($hashSchedules) {
    if (Compare-Object -ReferenceObject $hashSchedules -DifferenceObject $hash) {
      $scheduleMsg = "| Schedule Hashes are different |"
    } else {
      $scheduleMsg = "| Schedule Hashes are same |"
    }
  } elseif (-not $hashSchedules) {
    new-itemproperty -path "HKLM:\Software\Centrastage" -name "Custom18" -value "$($hash)" -force
  }
  if ($curSchedules) {
    $curScheduleout = $curSchedules.replace(' | ', " | `r`n`t")
    logERR 3 "SCHEDULE" "PREV SCHEDULE :`r`n`t$($strLineSeparator)`r`n`t$($curScheduleout)`r`n$($strLineSeparator)"
    if (($scheduleset.trim()).contains($curSchedules.trim())) {
      $scheduleMsg += "| Schedule Strings are same |"
      logERR 3 "SCHEDULE" "$($scheduleMsg)`r`n$($strLineSeparator)"
    } elseif (-not ($scheduleset.trim()).contains($curSchedules.trim())) {
      $scheduleMsg += "| Schedule Strings are different |"
      logERR 4 "SCHEDULE" "$($scheduleMsg)`r`n$($strLineSeparator)"
    }
  } elseif ((-not $curSchedules) -or ($null -eq $curSchedules) -or ($curSchedules -eq "")) {
    new-itemproperty -path "HKLM:\Software\Centrastage" -name "Custom$($udfSchedules)" -value "$($scheduleset.trim())" -force
  }
} catch {
  $script:blnWARN = $true
  $err = "$($_.scriptstacktrace)`r`n$($_.Exception)`r`n$($_)`r`n"
  logERR 4 "SCHEDULE" "ERROR ENCOUNTERED :`r`n$($err)`r`n$($strLineSeparator)"
}
#QUERY ARCHIVE SCHEDULES
try {
  $archiveset = $null
  $archive = .\clienttool.exe control.archiving.list
  $archive = $archive | where {$_ -like "* yes *"} | out-string
  $array = $archive.split([Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries)
  foreach ($line in $array) {$archiveset += "`r`n`t$($line.trim())"}
  logERR 3 "ARCHIVE" "ARCHIVE :`r`n`t$($strLineSeparator)$($archiveset)`r`n$($strLineSeparator)"
  $archiveset = $null
  foreach ($line in $array) {
    $chunk = ($line.trim()).split(" ", [StringSplitOptions]::RemoveEmptyEntries)
    $archiveset += "$($chunk[2]) - $($chunk[4]) - Datasources : $($chunk[5]) - Archive Time : $($chunk[6]) - Archive Months : $($chunk[7]) - Archive Days : $($chunk[8]) | "
  }
  $archiveset = "$($chunk[2]) - $($chunk[4]) - Datasources : $($chunk[5]) - Archive Time : $($chunk[6]) - Archive Months : $($chunk[7]) - Archive Days : $($chunk[8])"
  $archiveset = $archiveset.replace("FileSystem","FS").replace("NetworkShares","NS").replace("SystemState","SS").replace("Exchange","EXCH").replace("VMWare","VM").replace("HyperV","HV")
  $archiveset = $archiveset.replace("Monday","M").replace("Tuesday","T").replace("Wednesday","W").replace("Thursday","Th").replace("Friday","F").replace("Saturday","Sa").replace("Sunday","S")
  $array = $archiveset.split('|', [StringSplitOptions]::RemoveEmptyEntries)
  $archiveout = $null
  foreach ($line in $array) {$archiveout += "`r`n`t$($line.trim()) | "}
  logERR 3 "ARCHIVE" "FINAL ARCHIVE :`r`n`t$($strLineSeparator)$($archiveout)`r`n$($strLineSeparator)"
  #COMPUTE ARCHIVE HASH
  $utf8 = new-object -TypeName System.Text.UTF8Encoding
  $md5 = new-object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
  $hash = [System.BitConverter]::ToString($md5.ComputeHash($utf8.GetBytes($archiveset)))
  logERR 3 "ARCHIVE" "COMPUTED ARCHIVE HASH :`r`n`t$($strLineSeparator)`r`n`t$($hash)`r`n$($strLineSeparator)"
  #COMPARE ARCHIVE HASH
  if ($hashArchives) {
    if (Compare-Object -ReferenceObject $hashArchives -DifferenceObject $hash) {
      $archiveMsg = "| Archive Hashes are different |"
    } else {
      $archiveMsg = "| Archive Hashes are same |"
    }
  } elseif (-not $hashArchives) {
    new-itemproperty -path "HKLM:\Software\Centrastage" -name "Custom20" -value "$($hash)" -force
  }
  if ($curArchives) {
    $curArchivesout = $curArchives.replace(' | ', " | `r`n`t")
    logERR 3 "ARCHIVE" "PREV ARCHIVE :`r`n$($strLineSeparator)`r`n`t$($curArchivesout)`r`n$($strLineSeparator)"
    if (($archiveset.trim()).contains($curArchives.trim())) {
      $archiveMsg += "| Archive Strings are same |"
      logERR 3 "ARCHIVE" "$($archiveMsg)`r`n$($strLineSeparator)"
    } elseif (-not ($archiveset.trim()).contains($curArchives.trim())) {
      $archiveMsg += "| Archive Strings are different |"
      logERR 4 "ARCHIVE" "$($archiveMsg)`r`n$($strLineSeparator)"
    }
  } elseif ((-not $curArchives) -or ($null -eq $curArchives) -or ($curArchives -eq "")) {
    new-itemproperty -path "HKLM:\Software\Centrastage" -name "Custom$($udfArchives)" -value "$($archiveset.trim())" -force
  }
} catch {
  $script:blnWARN = $true
  $err = "$($_.scriptstacktrace)`r`n$($_.Exception)`r`n$($_)`r`n"
  logERR 4 "ARCHIVE" "ERROR ENCOUNTERED :`r`n$($err)`r`n$($strLineSeparator)"
}

#QUERY SELECTIONS
$allHash = $null
$selections = .\clienttool.exe -machine-readable control.selection.list -delimiter "," | out-file "C:\IT\selections.csv"
$selections = import-csv -path "C:\IT\selections.csv"
#remove-item "C:\IT\selections.csv" -force
#COMPUTE ARCHIVE HASH
$hash = $null
$utf8 = new-object -TypeName System.Text.UTF8Encoding
$md5 = new-object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
$hash = [System.BitConverter]::ToString($md5.ComputeHash($utf8.GetBytes($selections)))
logERR 3 "SELECTIONS" "COMPUTED SELECTIONS HASH :`r`n`t$($strLineSeparator)`r`n`t$($hash)`r`n$($strLineSeparator)"
write-output "`tSelections = See 'C:\IT\selections.csv'"
$allHash += $hash
#QUERY FILTERS
$filters = .\clienttool.exe -machine-readable control.filter.list | out-file "C:\IT\filters.csv"
$filters = import-csv -path "C:\IT\filters.csv" -Header value
#remove-item "C:\IT\filters.csv" -force
#COMPUTE FILTERS HASH
$hash = $null
$filters = $filters.value.replace("\\","\") -join " | "
$utf8 = new-object -TypeName System.Text.UTF8Encoding
$md5 = new-object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
$hash = [System.BitConverter]::ToString($md5.ComputeHash($utf8.GetBytes($filters)))
logERR 3 "FILTERS" "COMPUTED FILTERS HASH :`r`n`t$($strLineSeparator)`r`n`t$($hash)`r`n$($strLineSeparator)"
Write-output "`tFilters = $($filters)"
$allHash += $hash
#QUERY INCLUSIONS
$inclusions = $selections | where-object {(($_.type -eq "Inclusive") -and ($_.DSRC -eq "FileSystem")) }
if ($inclusions) {
  if ($inclusions[0].path -ne "") {
    $inclusionBase = "FileSystem"
  } else {
    $inclusionBase = $null
  }
  $inclusions = $inclusions.path.replace("\","\\") -join " | "
} else {
  $inclusionBase = $null
  $inclusions = "-"
}
#COMPUTE INCLUSIONS HASH
$hash = $null
$inclusions = $inclusions.replace("\\","\")
$utf8 = new-object -TypeName System.Text.UTF8Encoding
$md5 = new-object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
$hash = [System.BitConverter]::ToString($md5.ComputeHash($utf8.GetBytes($inclusions)))
logERR 3 "INCLUSIONS" "COMPUTED INCLUSIONS HASH :`r`n`t$($strLineSeparator)`r`n`t$($hash)`r`n$($strLineSeparator)"
Write-output "`tInclusions = $($inclusionBase) - $($inclusions)"
$allHash += $hash
#QUERY EXCLUSIONS
$exclusions = $selections | where-object {(($_.type -eq "Exclusive") -and ($_.DSRC -eq "FileSystem")) }
if ($exclusions) {
  if ($inclusions[0].path -ne "") {
    $exclusionBase = "FileSystem"
  } else {
    $exclusionBase = $null
  }
  $exclusions = $exclusions.path.replace("\","\\") -join " | "
} else {
  if (($inclusions) -and ($inclusions[0].path -ne "")) {
    $exclusionBase = "FileSystem"
    $exclusions = $null
  } else {
    $exclusionBase = $null
    $exclusions = "-"
  }
}
#COMPUTE EXCLUSIONS HASH
$hash = $null
$exclusions = $exclusions.replace("\\","\")
$utf8 = new-object -TypeName System.Text.UTF8Encoding
$md5 = new-object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
$hash = [System.BitConverter]::ToString($md5.ComputeHash($utf8.GetBytes($exclusions)))
logERR 3 "EXCLUSIONS" "COMPUTED EXCLUSIONS HASH :`r`n`t$($strLineSeparator)`r`n`t$($hash)`r`n$($strLineSeparator)"
Write-output "`tExclusions = $($exclusionBase) - $($exclusions)"
$allHash += $hash
#COMPUTE ALL HASHES TOGETHER
$hash = $null
$utf8 = new-object -TypeName System.Text.UTF8Encoding
$md5 = new-object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
$hash = [System.BitConverter]::ToString($md5.ComputeHash($utf8.GetBytes($allHash)))
logERR 3 "HASH-ALL" "COMPUTED HASH-ALL :`r`n`t$($strLineSeparator)`r`n`t$($hash)`r`n$($strLineSeparator)"
if ($curHashAll) {
  logERR 3 "HASH-ALL" "PREV SELECTIONS HASH :`r`n$($strLineSeparator)`r`n`t$($curHashAll)`r`n$($strLineSeparator)"
  if ($curHashAll.trim() -match $hash.trim()) {
    $hashMsg += "| Selection / Filters / Inclusions / Exclusions Hashes are same |"
    logERR 3 "HASH-ALL" "$($hashMsg)`r`n$($strLineSeparator)"
  } elseif ($curHashAll.trim() -notmatch $hash.trim()) {
    $hashMsg += "| Selection / Filters / Inclusions / Exclusions Hashes are different |"
    logERR 4 "HASH-ALL" "$($hashMsg)`r`n$($strLineSeparator)"
  }
} elseif ((-not $curHashAll) -or ($null -eq $curHashAll) -or ($curHashAll -eq "")) {
  new-itemproperty -path "HKLM:\Software\Centrastage" -name "Custom$($udfSelection)" -value "$($hash.trim())" -force
}

#QUERY THROTTLING
try {
  #OBTAIN PARTNER AND BACKUP ACCOUNT ID
  [xml]$statusXML = Get-Content -LiteralPath $mxbPath\StatusReport.xml
  $xmlBackupID = $statusXML.Statistics.Account
  $xmlPartnerID = $statusXML.Statistics.PartnerName
  #AUTH TO BACKUP.MANAGEMENT API
  Send-APICredentialsCookie
  if ($script:blnBMAuth) {
    $filter1 = "AT == 1 AND PN != 'Documents'"   ### Excludes M365 and Documents devices from lookup
    if ((-not $AllPartners) -and (($null -eq $script:i_BackupName) -or ($script:i_BackupName -eq ""))) {
      write-output "`r`n$($strLineSeparator)`r`n`tXML Partner: $($xmlPartnerID)"
      $script:diag += "`r`n$($strLineSeparator)`r`n`tXML Partner: $($xmlPartnerID)"
      Send-GetPartnerInfo $xmlPartnerID
    } elseif ((-not $AllPartners) -and (($null -ne $script:i_BackupName) -and ($script:i_BackupName -ne ""))) {
      write-output "`r`n$($strLineSeparator)`r`n`tPassed Partner: $($script:i_BackupName)"
      $script:diag += "`r`n$($strLineSeparator)`r`n`tPassed Partner: $($script:i_BackupName)"
      Send-GetPartnerInfo $script:i_BackupName
    }
    if ($AllPartners) {
      Send-GetDevices "External IPM"
    } elseif (-not $AllPartners) {
      Send-GetDevices $xmlPartnerID
    }

    if ($AllDevices) {
      $script:SelectedDevices = $DeviceDetail | 
        select-object PartnerId,PartnerName,Reference,AccountID,DeviceName,ComputerName,DeviceAlias,GUIPassword,IPMGUIPwd,Creation,TimeStamp,LastSuccess,ProductId,Product,ProfileId,Profile,DataSources,SelectedGB,UsedGB,Location,OS,Notes,TempInfo
      write-output "$($strLineSeparator)`r`n  $($SelectedDevices.AccountId.count) Devices Selected"
      $script:diag += "$($strLineSeparator)`r`n  $($SelectedDevices.AccountId.count) Devices Selected`r`n"
    } elseif (-not $AllDevices) {
      #$script:SelectedDevices = $DeviceDetail | 
      #  Select-Object PartnerId,PartnerName,Reference,AccountID,DeviceName,ComputerName,DeviceAlias,GUIPassword,Creation,TimeStamp,LastSuccess,ProductId,Product,ProfileId,Profile,DataSources,SelectedGB,UsedGB,Location,OS,Notes,TempInfo | 
      #  Out-GridView -title "Current Partner | $partnername" -OutputMode Multiple
      if (($null -ne $xmlBackupID) -and ($xmlBackupID -ne "")) {
        $script:SelectedDevices = $DeviceDetail | 
          select-object PartnerId,PartnerName,Reference,AccountID,DeviceName,ComputerName,DeviceAlias,GUIPassword,IPMGUIPwd,Creation,TimeStamp,LastSuccess,ProductId,Product,ProfileId,Profile,DataSources,SelectedGB,UsedGB,Location,OS,Notes,TempInfo | 
            where-object {$_.DeviceName -eq $xmlBackupID}
        write-output "$($strLineSeparator)`r`n`t$($SelectedDevices.AccountId.count) Devices Selected`r`n$($strLineSeparator)"
        $script:diag += "$($strLineSeparator)`r`n`t$($SelectedDevices.AccountId.count) Devices Selected`r`n$($strLineSeparator)`r`n"
      }
    }    

    if ($null -eq $SelectedDevices) {
      # Cancel was pressed
      # Run cancel script
      write-output "$($strLineSeparator)`r`n  No Devices Selected`r`n$($strLineSeparator)"
      $script:diag += "$($strLineSeparator)`r`n  No Devices Selected`r`n$($strLineSeparator)`r`n"
      break
    } else {
      $throttle = "$($SelectedDevices.DeviceName) in $($SelectedDevices.PartnerName) - "
      $throttle += AuditDeviceBandwidth($SelectedDevices.AccountId)
      logERR 3 "THROTTLE" "$($throttle)`r`n$($strLineSeparator)"
      if ($curThrottle) {
        logERR 3 "THROTTLE" "PREV THROTTLE :`r`n$($strLineSeparator)`r`n`t$($throttle)`r`n$($strLineSeparator)"
        if ($curThrottle.trim() -match $throttle.trim()) {
          $throttleMsg += "| Throttle Settings are same |"
          logERR 3 "THROTTLE" "$($throttleMsg)`r`n$($strLineSeparator)"
        } elseif ($curThrottle.trim() -notmatch $throttle.trim()) {
          $throttleMsg += "| Throttle Settings are different |"
          logERR 4 "THROTTLE" "$($throttleMsg)`r`n$($strLineSeparator)"
        }
      } elseif ((-not $curThrottle) -or ($null -eq $curThrottle) -or ($curThrottle -eq "")) {
        new-itemproperty -path "HKLM:\Software\Centrastage" -name "Custom$($udfThrottle)" -value "$($throttle.trim())" -force
      }
    }
  }
} catch {
  $script:blnWARN = $true
  $err = "$($_.scriptstacktrace)`r`n$($_.Exception)`r`n$($_)`r`n"
  if ($_.exception -match "CommandNotFoundException") {
    logERR 3 "THROTTLE" "ERROR ENCOUNTERED :`r`n$($err)`r`n`t$($strLineSeparator)`r`n`tSystem doesn't support IWR - Likely Win7/8/2K8 OS`r`n$($strLineSeparator)"
  } elseif ($_.exception -notmatch "(500) Internal Server Error") {
    logERR 3 "THROTTLE" "ERROR ENCOUNTERED :`r`n$($err)`r`n`t$($strLineSeparator)`r`n`tInternal Server Error (500)`r`n$($strLineSeparator)"
  } elseif ($_.exception -notmatch "CommandNotFoundException") {
    logERR 4 "THROTTLE" "ERROR ENCOUNTERED :`r`n$($err)`r`n$($strLineSeparator)"
  }
}
#Stop script execution time calculation
StopClock
#DATTO OUTPUT
$result = $null
$finish = "$((Get-Date).ToString('yyyy-MM-dd hh:mm:ss'))"
if ((($scheduleMsg -notmatch "are different") -and ($scheduleMsg -match "are same")) -and 
  (($archiveMsg -notmatch "are different") -and ($archiveMsg -match "are same")) -and 
  (($hashMsg -notmatch "are different") -and ($hashMsg -match "are same")) -and 
  (($throttleMsg -notmatch "are different") -and ($throttleMsg -match "are same"))) {
    $warnMsg = "No Changes Detected"
} elseif (($scheduleMsg -match "are different") -or 
  ($archiveMsg -match "are different") -or 
  ($hashMsg -match "are different") -or 
  ($throttleMsg -match "are different")) {
    $warnMsg = "Detected Changes"
    $script:blnWARN = $true
}
if ($script:blnWARN) {
  write-DRMMAlert "MSPBackup_Schedules : Warning : $($warnMsg) : See Diagnostics : $($finish)"
  write-DRMMDiag "$($script:diag)"
  exit 1
} elseif (-not $script:blnWARN) {
  write-DRMMAlert "MSPBackup_Schedules : Healthy : $($warnMsg) : $($finish)"
  write-DRMMDiag "$($script:diag)"
  exit 0
}
#END SCRIPT
#------------