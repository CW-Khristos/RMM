<# ----- About: ----
    # Bulk Set SW Backup GUI Password 
    # Revision v12 - 2021-09-13
    # Author: Eric Harless, Head Backup Nerd - N-able 
    # Twitter @Backup_Nerd  Email:eric.harless@n-able.com
    # Modifications: Christopher Bledsoe, Tier II Tech - IPM Computers
    # Email: cbledsoe@ipmcomputers.com
    # Reddit https://www.reddit.com/r/Nable/
# -----------------------------------------------------------#>  ## About

<# ----- Legal: ----
    # Sample scripts are not supported under any N-able support program or service.
    # The sample scripts are provided AS IS without warranty of any kind.
    # N-able expressly disclaims all implied warranties including, warranties
    # of merchantability or of fitness for a particular purpose. 
    # In no event shall N-able or any other party be liable for damages arising
    # out of the use of or inability to use the sample scripts.
# -----------------------------------------------------------#>  ## Legal

<# ----- Compatibility: ----
    # For use with the Standalone edition of N-able Backup
# -----------------------------------------------------------#>  ## Compatibility

<# ----- Behavior: ----
    # Check / Get / Store secure credentials 
    # Authenticate to https://backup.management console
    # Check partner level / Enumerate partners/ GUI select partner
    # Enumerate devices / GUI select devices
    # Prompt / Set / Wipe GUI password via Remote commands
    #
    # Use the -AllPartners switch parameter to skip GUI partner selection
    # Use the -AllDevices switch parameter to skip GUI device selection
    #
    # Use the -SetGUIPassword (default) parameter to be prompted to enter a Secure GUI Password to be applied
    # Use the -RestoreOnly parameter with the -SetGUIPassword parameter to allow restores when GUI password is set
    # Use the -WipeGUIPassword parameter to clear the GUI password from selected devices
    # Use the -ClearCredentials parameter to remove stored API credentials at start of script

    # https://documentation.n-able.com/backup/userguide/documentation/Content/service-management/json-api/home.htm
    # https://documentation.n-able.com/backup/userguide/documentation/Content/service-management/console/remote-commands.htm
# -----------------------------------------------------------#>  ## Behavior

#region ----- DECLARATIONS ----
  #BELOW PARAM() MUST BE COMMENTED OUT FOR USE WITHIN DATTO RMM
  #UNCOMMENT BELOW PARAM() AND RENAME '$env:var' TO '$var' TO UTILIZE IN CLI
  #[CmdletBinding(DefaultParameterSetName="SetGUIPW")]
  #Param (
  #  [Parameter(ParameterSetName="WipeGUIPW",Mandatory=$False)] [Switch]$WipeGUIPassword,  ## Clear GUI Password   
  #  [Parameter(ParameterSetName="SetGUIPW",Mandatory=$False)] [switch]$SetGUIPassword,    ## Specify GUI Password to set
  #  [Parameter(ParameterSetName="SetGUIPW",Mandatory=$False)] [Switch]$RestoreOnly,       ## Allow Restore Only GUI Access
  #  [Parameter(ParameterSetName="SetGUIPW",Mandatory=$False)] 
  #  [Parameter(ParameterSetName="WipeGUIPW",Mandatory=$False)][Switch]$AllPartners,       ## Skip partner selection
  #  [Parameter(ParameterSetName="SetGUIPW",Mandatory=$False)] 
  #  [Parameter(ParameterSetName="WipeGUIPW",Mandatory=$False)] [Switch]$AllDevices,       ## Skip device selection             
  #  [Parameter(Mandatory=$False)] [switch] $ClearCredentials,                             ## Remove Stored API Credentials at start of script 
  #  [Parameter(Mandatory=$true)] $i_AllPartners,
  #  [Parameter(Mandatory=$true)] $i_AllDevices,
  #  [Parameter(Mandatory=$true)] $i_BackupCMD,
  #  [Parameter(Mandatory=$true)] $i_GUILength,
  #  [Parameter(Mandatory=$true)] $i_GUIpassword,
  #  [Parameter(Mandatory=$true)] $i_PartnerName,
  #  [Parameter(Mandatory=$false)] $i_BackupName,
  #  [Parameter(Mandatory=$true)] $i_BackupUser,
  #  [Parameter(Mandatory=$true)] $i_BackupPWD,
  #  [Parameter(Mandatory=$true)] $i_UDFpassword
  #)
  #VERSION FOR SCRIPT UPDATE
  $strSCR                 = "MSPBackup_SetGUI"
  $strVER                 = [version]"0.1.1"
  $strREPO                = "RMM"
  $strBRCH                = "dev"
  $strDIR                 = "Datto\NAble Backup"
  $script:diag            = $null
  $script:blnWARN         = $false
  $script:blnBMAuth       = $false
  $ErrorActionPreference  = 'Continue'
  $strLineSeparator       = "  ---------"
  $logPath                = "C:\IT\Log\MSPBackup_SetGUI_$($strVER).log"
  $urlJSON                = 'https://api.backup.management/jsonapi'
  $mxbPath                = ${env:ProgramData} + "\MXB\Backup Manager"
  $CurrentDate            = Get-Date -format "yyy-MM-dd_hh-mm-ss"
  #MXB PATH
  $script:True_path       = "C:\ProgramData\MXB\"
  $script:APIcredfile     = join-path -Path $True_Path -ChildPath "$env:computername API_Credentials.Secure.txt"
  $script:APIcredpath     = Split-path -path $APIcredfile
  
  # ALL PARTNERS / ALL DEVICES BOOLEANS
  if ($env:i_AllDevices -eq "false") {
    $AllDevices = $false
  } elseif ($env:i_AllDevices -eq "true") {
    $AllDevices = $true
  }
  if ($env:i_AllPartners -eq "false") {
    $AllPartners = $false
  } elseif ($env:i_AllPartners -eq "true") {
    $AllPartners = $true
  }
  #SANITIZE DRMM VARIABLES
  if (($null -eq $script:PartnerName) -or ($script:PartnerName -eq "")) {$script:PartnerName = $env:BackupRoot}
  if (($null -eq $script:i_BackupUser) -or ($script:i_BackupUser -eq "")) {$script:i_BackupUser = $env:BackupUser}
  if (($null -eq $script:i_BackupPWD) -or ($script:i_BackupPWD -eq "")) {$script:i_BackupPWD = $env:BackupPass}
  clear-host
  write-output "  Bulk Set GUI Password `n"
  $script:diag += "  Bulk Set GUI Password `r`n`r`n"
  #$Syntax = Get-Command $PSCommandPath -Syntax ; write-output "Script Parameter Syntax:`n`n  $Syntax"
  write-output "  Current Parameters:"
  $script:diag += "  Current Parameters:`r`n"
  write-output "  -AllPartners     = $($AllPartners)"
  $script:diag += "  -AllPartners     = $($AllPartners)`r`n"
  write-output "  -AllDevices      = $($AllDevices)"
  $script:diag += "  -AllDevices      = $($AllDevices)`r`n"
  write-output "  -SetGUIPassword  = $($SetGUIPassword)"
  $script:diag += "  -SetGUIPassword  = $($SetGUIPassword)`r`n"
  write-output "  -RestoreOnly     = $($RestoreOnly)"
  $script:diag += "  -RestoreOnly     = $($RestoreOnly)`r`n"
  write-output "  -i_BackupCMD = $($env:i_BackupCMD)"
  $script:diag += "  -i_BackupCMD = $($env:i_BackupCMD)`r`n"
  write-output "  -i_GUILength = $($env:i_GUILength)"
  $script:diag += "  -i_GUILength = $($env:i_GUILength)`r`n"
  write-output "  -i_GUIpassword = $($env:i_GUIpassword)"
  $script:diag += "  -i_GUIpassword = $($env:i_GUIpassword)`r`n"
  write-output "  -i_PartnerName = $($env:i_PartnerName)"
  $script:diag += "  -i_PartnerName = $($script:PartnerName)`r`n"
  write-output "  -i_BackupName = $($env:i_BackupName)"
  $script:diag += "  -i_BackupName = $($env:i_BackupName)`r`n"
  write-output "  -i_BackupUser = $($script:i_BackupUser)"
  $script:diag += "  -i_BackupUser = {ENCRYPTED}`r`n"
  write-output "  -i_BackupPWD = {ENCRYPTED}"
  $script:diag += "  -i_BackupPWD = {ENCRYPTED}`r`n"
  write-output "  -i_UDFpassword = $($env:i_UDFpassword)"
  $script:diag += "  -i_UDFpassword = $($env:i_UDFpassword)`r`n"
  write-output "  -i_UDFaccount = $($env:i_UDFaccount)"
  $script:diag += "  -i_UDFaccount = $($env:i_UDFaccount)`r`n"
  
  #$scriptpath = $MyInvocation.MyCommand.Path
  #$dir = Split-Path $scriptpath
  #Push-Location $dir
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  [System.Net.ServicePointManager]::MaxServicePointIdleTime = 5000000

  # GENERATE RANDOMIZED PASSWORD UP TO LEN($env:i_GUILength)
  if (($env:i_GUILength -eq 0) -or ($env:i_GUILength -lt 8)) {$env:i_GUILength = 8}
  if (($env:i_GUIpassword -eq $null) -or ($env:i_GUIpassword -eq "") -or ($env:i_GUIpassword -eq "NULL")) {
    $password = -join ((33..33) + (35..38) + (42..42) + (50..57) + (63..72) + (74..75) + (77..78) + (80..90) + (97..104) + (106..107) + (109..110) + (112..122) | 
      Get-Random -Count $env:i_GUILength | ForEach-Object {[char]$_})
  } else {
    $password = $env:i_GUIpassword
  }
  $SecurePassword = ConvertTo-SecureString -String $password -AsPlainText -Force
  # SET PASSWORD WIPE
  if ($env:i_BackupCMD -eq "WipeGUIPassword") {$WipeGUIPassword = $True}
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

#region ----- Authentication ----
  function Send-APICredentialsCookie {
    $url = $urlJSON
    $data = @{}
    $data.jsonrpc = '2.0'
    $data.id = '2'
    $data.method = 'Login'
    $data.params = @{}
    $data.params.partner = $script:PartnerName
    $data.params.username = $script:i_BackupUser
    $data.params.password = $script:i_BackupPWD

    $webrequest = Invoke-WebRequest -Method POST `
      -ContentType 'application/json' `
      -Body (ConvertTo-Json $data) `
      -Uri $url `
      -SessionVariable script:websession `
      -UseBasicParsing
    $script:cookies = $websession.Cookies.GetCookies($url)
    $script:websession = $websession
    $script:Authenticate = $webrequest | convertfrom-json
    #Debug write-output "$($script:cookies[0].name) = $($cookies[0].value)"

    if ($authenticate.visa) {
      $script:blnBMAuth = $true
      $script:visa = $authenticate.visa
    } else {
      write-output "  $($strLineSeparator)`r`n  Authentication Failed: Please confirm your Backup.Management Partner Name and Credentials"
      $script:diag += "  $($strLineSeparator)`r`n  Authentication Failed: Please confirm your Backup.Management Partner Name and Credentials`r`n"
      write-output "  Please Note: Multiple failed authentication attempts could temporarily lockout your user account`r`n   $($strLineSeparator)"
      $script:diag += "  Please Note: Multiple failed authentication attempts could temporarily lockout your user account`r`n   $($strLineSeparator)`r`n"
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
      -SessionVariable script:websession `
      -UseBasicParsing
    #$script:cookies = $websession.Cookies.GetCookies($url)
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
      write-output "$($strLineSeparator)`r`n  $($PartnerName) - $($partnerId) - $($Uid)`r`n$($strLineSeparator)"
      $script:diag += "$($strLineSeparator)`r`n  $($PartnerName) - $($partnerId) - $($Uid)`r`n$($strLineSeparator)`r`n"
    } else {
      write-output "$($strLineSeparator)`r`n  Lookup for $($Partner.result.result.Level) Partner Level Not Allowed`r`n$($strLineSeparator)"
      $script:diag += "$($strLineSeparator)`r`n  Lookup for $($Partner.result.result.Level) Partner Level Not Allowed`r`n$($strLineSeparator)`r`n"
      #$script:PartnerName = Read-Host "  Enter EXACT Case Sensitive Customer/ Partner displayed name to lookup i.e. 'Acme, Inc (bob@acme.net)'"
      #Send-GetPartnerInfo $script:partnername
    }

    if ($partner.error) {
      write-output "  $($partner.error.message)"
      $script:diag += "  $($partner.error.message)`r`n"
      #$script:PartnerName = Read-Host "  Enter EXACT Case Sensitive Customer/ Partner displayed name to lookup i.e. 'Acme, Inc (bob@acme.net)'"
      #Send-GetPartnerInfo $script:partnername
    }
  } ## Send-GetPartnerInfo API Call

  function Send-EnumeratePartners {
    # ----- Get Partners via EnumeratePartners -----
    # (Create the JSON object to call the EnumeratePartners function)
    $objEnumeratePartners = (New-Object PSObject | 
      Add-Member -PassThru NoteProperty jsonrpc '2.0' |
      Add-Member -PassThru NoteProperty visa $script:visa |
      Add-Member -PassThru NoteProperty method 'EnumeratePartners' |
      Add-Member -PassThru NoteProperty params @{
        parentPartnerId = $PartnerId 
        fetchRecursively = "false"
        fields = (0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22) 
      } |
      Add-Member -PassThru NoteProperty id '1') | ConvertTo-Json -Depth 5
    
    # (Call the JSON Web Request Function to get the EnumeratePartners Object)
    [array]$script:EnumeratePartnersSession = CallJSON $urlJSON $objEnumeratePartners
    $script:visa = $EnumeratePartnersSession.visa
    write-output "$($strLineSeparator)`r`n  Using Visa: $($script:visa)`r`n$($strLineSeparator)"
    $script:diag += "$($strLineSeparator)`r`n  Using Visa: $($script:visa)`r`n$($strLineSeparator)`r`n"
    # (Added Delay in case command takes a bit to respond)
    Start-Sleep -Milliseconds 100
    # (Get Result Status of EnumerateAccountProfiles)
    $EnumeratePartnersSessionErrorCode = $EnumeratePartnersSession.error.code
    $EnumeratePartnersSessionErrorMsg = $EnumeratePartnersSession.error.message
    
    # (Check for Errors with EnumeratePartners - Check if ErrorCode has a value)
    if ($EnumeratePartnersSessionErrorCode) {
      write-output "$($strLineSeparator)`r`n  EnumeratePartnersSession Error Code:  $($EnumeratePartnersSessionErrorCode)"
      $script:diag += "$($strLineSeparator)`r`n  EnumeratePartnersSession Error Code:  $($EnumeratePartnersSessionErrorCode)`r`n"
      write-output "  EnumeratePartnersSession Message:  $($EnumeratePartnersSessionErrorMsg)`r`n$($strLineSeparator)`r`n  Exiting script"
      $script:diag += "  EnumeratePartnersSession Message:  $($EnumeratePartnersSessionErrorMsg)`r`n$($strLineSeparator)`r`n  Exiting script`r`n"
      # (Exit script if there is a problem)
      #Break script
    } else {
      # (No error)
      $script:EnumeratePartnersSessionResults = $EnumeratePartnersSession.result.result | 
      select-object Name,@{l='Id';e={($_.Id).tostring()}},Level,ExternalCode,ParentId,LocationId,* -ExcludeProperty Company -ErrorAction Ignore
      $script:EnumeratePartnersSessionResults | ForEach-Object {
        $_.CreationTime = [timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($_.CreationTime))
      }
      $script:EnumeratePartnersSessionResults | ForEach-Object {
        if ($_.TrialExpirationTime  -ne "0") {
          $_.TrialExpirationTime = [timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($_.TrialExpirationTime))
        }
      }
      $script:EnumeratePartnersSessionResults | ForEach-Object {
        if ($_.TrialRegistrationTime -ne "0") {
          $_.TrialRegistrationTime = [timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($_.TrialRegistrationTime))
        }
      }
      $script:SelectedPartners = $EnumeratePartnersSessionResults | Select-object * | 
        Where-object {$_.name -notlike "001???????????????- Recycle Bin"} | Where-object {$_.Externalcode -notlike '`[??????????`]* - ????????-????-????-????-????????????'}
      $script:SelectedPartner = $script:SelectedPartners += @( [pscustomobject]@{Name=$PartnerName;Id=[string]$PartnerId;Level='<ParentPartner>'} ) 
      
      if ($AllPartners) {
        $script:Selection = $script:SelectedPartners | 
          Select-object id,Name,Level,CreationTime,State,TrialRegistrationTime,TrialExpirationTime,Uid | sort-object Level,name
        write-output "$($strLineSeparator)`r`n  All Partners Selected"
        $script:diag += "$($strLineSeparator)`r`n  All Partners Selected`r`n"
      } else {
        $script:Selection = $script:SelectedPartners |  
          Select-object id,Name,Level,CreationTime,State,TrialRegistrationTime,TrialExpirationTime,Uid | sort-object Level,name | 
            out-gridview -Title "Current Partner | $($partnername)" -OutputMode Single
        if (($null -eq $Selection) -or ($Selection -eq "")) {
          # Cancel was pressed
          # Run cancel script
          write-output "$($strLineSeparator)`r`n  No Partners Selected"
          $script:diag += "$($strLineSeparator)`r`n  No Partners Selected`r`n"
          Break
        } else {
            # OK was pressed, $Selection contains what was chosen
            # Run OK script
            [int]$script:PartnerId = $script:Selection.Id
            [String]$script:PartnerName = $script:Selection.Name
        }
      }
    }
  }  ## Send-EnumeratePartners API Call

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

  function Send-RemoteCommand { 
    if ($SecurePassword.length -ge 1) {
      $UnsecureGUIPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword))
    }
    if ($RestoreOnly) {
      $PasswordParam = "password $($UnsecureGUIPassword)`nrestore_only allow"
    } else {
      $PasswordParam = "password $($UnsecureGUIPassword)`nrestore_only disallow"
    }
    if ($env:i_BackupCMD -eq "WipeGUIPassword") {
      $UnsecureGUIPassword = ""
      write-output -NoNewline "Wiping GUI Password"
    }

    $url = "https://backup.management/jsonrpcv1"
    $method = 'POST'
    $script:data = @{}
    $data.jsonrpc = '2.0'
    $data.id = 'jsonrpc'
    $data.method = 'SendRemoteCommands'
    $data.params = @{}
    $data.params.command = "set gui password"
    $data.params.parameters = "$($PasswordParam)"
    $data.params.ids = @([System.Int32[]]$selecteddevice.accountid)
    $jsondata = (ConvertTo-Json $data -depth 6)
    #$jsondata  ## Debug
    write-output "`n##Sending Remote Command##`n$($data.params.command)`n$($CommandParameters)" ## Output sent Remote Command
    $script:diag += "`r`n##Sending Remote Command##`r`n$($data.params.command)`r`n$($CommandParameters)`r`n"

    $params = @{
      Uri         = $url
      Method      = $method
      Headers     = @{ 'Authorization' = "Bearer $($script:visa)" }
      Body        = ([System.Text.Encoding]::UTF8.GetBytes($jsondata))
      ContentType = 'application/json; charset=utf-8'
    }

    $script:sendResult = Invoke-RestMethod @params
    #$script:sendResult.result.result | Select-Object Id,@{Name="Status"; Expression={$_.Result.code}},@{Name="Message"; Expression={$_.Result.Message}} | Format-Table
    write-output " $($script:sendResult.result.result.id) $($script:sendResult.result.result.result.code)"
    $script:diag += " $($script:sendResult.result.result.id) $($script:sendResult.result.result.result.code)`r`n"
  } ## Send-RemoteCommand API Call

  function UpdateCustomColumn ($DeviceId,$ColumnId,$Message) {
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization","Bearer $($script:visa)")
    $headers.Add("Content-Type","application/json")
  
    $body = "{
      `n    `"jsonrpc`":`"2.0`",
      `n    `"id`":`"jsonrpc`",
      `n    `"visa`":`"$($script:visa)`",
      `n    `"method`":`"UpdateAccountCustomColumnValues`",
      `n    `"params`":{
      `n      `"accountId`": $($DeviceId),
      `n      `"values`": [[$($ColumnId),`"$($Message)`"]]
      `n      }
      `n    }
      `n"

    try {
      $script:updateCC = Invoke-RestMethod $urlJSON -Method 'POST' -Headers $headers -Body $body
      write-output "$($strLineSeparator)`r`n  UpdateCC : SUCCESS"
      $script:diag += "$($strLineSeparator)`r`n  UpdateCC : SUCCESS`r`n"
    } catch {
      write-output "$($strLineSeparator)`r`n  UpdateCC : FAILURE"
      $script:diag += "$($strLineSeparator)`r`n  UpdateCC : FAILURE`r`n"
    }
  } ## UpdateCustomColumn API Call
#endregion ----- Backup.Management JSON Calls ----
#endregion ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
try {
  Send-APICredentialsCookie
  if (-not $script:blnBMAuth) {
    write-output "  $($strLineSeparator)`r`n  Authentication Failed: Script Will Not Continue`r`n$($strLineSeparator)"
    $script:diag += "  $($strLineSeparator)`r`n  Authentication Failed: Script Will Not Continue`r`n$($strLineSeparator)`r`n"
  } elseif ($script:blnBMAuth) {
    write-output "$($strLineSeparator)`r`n"
    $script:diag += "$($strLineSeparator)`r`n`r`n"
    # OBTAIN PARTNER AND BACKUP ACCOUNT ID
    [xml]$statusXML = Get-Content -LiteralPath $mxbPath\StatusReport.xml
    $xmlBackupID = $statusXML.Statistics.Account
    $xmlPartnerID = $statusXML.Statistics.PartnerName
    #Send-GetPartnerInfo $script:cred0
    #Send-EnumeratePartners
    if ((-not $AllPartners) -and (($null -eq $env:i_BackupName) -or ($env:i_BackupName -eq ""))) {
      write-output "  XML Partner: $($xmlPartnerID)"
      $script:diag += "  XML Partner: $($xmlPartnerID)`r`n"
      Send-GetPartnerInfo $xmlPartnerID
    } elseif ((-not $AllPartners) -and (($null -ne $env:i_BackupName) -and ($env:i_BackupName -ne ""))) {
      write-output "  Passed Partner: $($env:i_BackupName)"
      $script:diag += "  Passed Partner: $($env:i_BackupName)`r`n"
      Send-GetPartnerInfo $env:i_BackupName
    }
    $filter1 = "AT == 1 AND PN != 'Documents'"   ### Excludes M365 and Documents devices from lookup.
    if ($AllPartners) {
      Send-GetDevices "External IPM"
    } elseif (-not $AllPartners) {
      Send-GetDevices $xmlPartnerID
    }

    if ($AllDevices) {
      $script:SelectedDevices = $DeviceDetail | 
        Select-Object PartnerId,PartnerName,Reference,AccountID,DeviceName,ComputerName,DeviceAlias,GUIPassword,IPMGUIPwd,Creation,TimeStamp,LastSuccess,ProductId,Product,ProfileId,Profile,DataSources,SelectedGB,UsedGB,Location,OS,Notes,TempInfo
      write-output "$($strLineSeparator)`r`n  $($SelectedDevices.AccountId.count) Devices Selected"
      $script:diag += "$($strLineSeparator)`r`n  $($SelectedDevices.AccountId.count) Devices Selected`r`n"
    } elseif (-not $AllDevices) {
      #$script:SelectedDevices = $DeviceDetail | 
      #  Select-Object PartnerId,PartnerName,Reference,AccountID,DeviceName,ComputerName,DeviceAlias,GUIPassword,Creation,TimeStamp,LastSuccess,ProductId,Product,ProfileId,Profile,DataSources,SelectedGB,UsedGB,Location,OS,Notes,TempInfo | 
      #  Out-GridView -title "Current Partner | $partnername" -OutputMode Multiple
      if (($null -ne $xmlBackupID) -and ($xmlBackupID -ne "")) {
        $script:SelectedDevices = $DeviceDetail | 
          Select-Object PartnerId,PartnerName,Reference,AccountID,DeviceName,ComputerName,DeviceAlias,GUIPassword,IPMGUIPwd,Creation,TimeStamp,LastSuccess,ProductId,Product,ProfileId,Profile,DataSources,SelectedGB,UsedGB,Location,OS,Notes,TempInfo | 
            Where-object {$_.DeviceName -eq $xmlBackupID}
        write-output "$($strLineSeparator)`r`n  $($SelectedDevices.AccountId.count) Devices Selected"
        $script:diag += "$($strLineSeparator)`r`n  $($SelectedDevices.AccountId.count) Devices Selected`r`n"
      }
    }    

    if ($null -eq $SelectedDevices) {
      # Cancel was pressed
      # Run cancel script
      write-output "$($strLineSeparator)`r`n  No Devices Selected"
      $script:diag += "$($strLineSeparator)`r`n  No Devices Selected`r`n"
      Break
    } else {
      # OK was pressed, $Selection contains what was chosen
      # Run OK script
      $script:SelectedDevices | 
        Select-Object PartnerId,PartnerName,Reference,@{Name="AccountID"; Expression={[int]$_.AccountId}},DeviceName,ComputerName,DeviceAlias,GUIPassword,IPMGUIPwd,Creation,TimeStamp | 
          Sort-object AccountId | Format-Table

      if ($env:i_BackupCMD -eq "-SetGUIPassword") {
        #$SecurePassword = Read-Host "  Enter Backup Manager GUI Password to be applied to $($SelectedDevices.AccountId.count) Devices" -AsSecureString
        write-output "$($strLineSeparator)`r`n  Applying GUI Password to $($SelectedDevices.AccountId.count) Devices, please be patient."
        $script:diag += "$($strLineSeparator)`r`n  Applying GUI Password to $($SelectedDevices.AccountId.count) Devices, please be patient.`r`n"
      }

      foreach ($selecteddevice in $SelectedDevices) {
        $device = $selecteddevice.DeviceName
        # UPDATE CUSOTM COLUMN 'GUI PW'
        write-output "$($strLineSeparator)`r`n  Updating GUI PW Column for $($device) - $($selecteddevice.AccountID) 2531 $($password)"
        $script:diag += "$($strLineSeparator)`r`n  Updating GUI PW Column for $($device) - $($selecteddevice.AccountID) 2531 $($password)`r`n"
        UpdateCustomColumn $selecteddevice.AccountID 2531 $password
        Start-Sleep -Milliseconds 500
        # SEND REMOTE COMMAND
        write-output "$($strLineSeparator)`r`n  Updating GUI PW for $($device)"
        $script:diag += "$($strLineSeparator)`r`n  Updating GUI PW for $($device)`r`n"
        Send-RemoteCommand
        Start-Sleep -Milliseconds 500
      }
      # SET UDF
      $Customfield = "Custom$($env:i_UDFpassword)"
      New-ItemProperty "HKLM:\SOFTWARE\CentraStage" -Name "$($Customfield)" -PropertyType string -value "$($password)" -Force
      $Customfield = "Custom$($env:i_UDFaccount)"
      New-ItemProperty "HKLM:\SOFTWARE\CentraStage" -Name "$($Customfield)" -PropertyType string -value "$($xmlBackupID)" -Force
    }
  }
} catch {
  $script:blnWARN = $true
  write-output "ERROR :`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
  $script:diag += "`r`nERROR :`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n"
}
#CLEAR LOGFILE
$null | set-content $logPath -force
# DATTO OUTPUT
if (-not $script:blnWARN) {
  "$($script:diag)" | add-content $logPath -force
  write-DRMMAlert "MSP_Backup : GUI Password Set : $(get-date)"
  write-DRMMDiag "$($script:diag)"
  exit 0
} elseif ($script:blnWARN) {
  "$($script:diag)" | add-content $logPath -force
  write-DRMMAlert "MSP_Backup : Execution Failure : $(get-date)"
  write-DRMMDiag "$($script:diag)"
  exit 1
}
#END SCRIPT
#------------