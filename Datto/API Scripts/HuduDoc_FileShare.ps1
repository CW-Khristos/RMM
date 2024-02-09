# https://mspp.io/cyberdrain-automatic-documentation-scripts-to-hudu/
# Based on the original script by Kelvin Tegelaar https://github.com/KelvinTegelaar/AutomaticDocumentation
#region ----- DECLARATIONS ----
  $script:diag            = $null
  #region######################## TLS Settings ###########################
  [System.Net.ServicePointManager]::MaxServicePointIdleTime = 5000000
  #[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType] 'Tls12'
  [System.Net.ServicePointManager]::SecurityProtocol = (
    [System.Net.SecurityProtocolType]::Ssl3 -bor 
    [System.Net.SecurityProtocolType]::Ssl2 -bor 
    [System.Net.SecurityProtocolType]::Tls13 -bor 
    [System.Net.SecurityProtocolType]::Tls12 -bor 
    [System.Net.SecurityProtocolType]::Tls11 -bor 
    [System.Net.SecurityProtocolType]::Tls
  )
  #endregion
  #region######################## Hudu Settings ###########################
  $RecursiveDepth         = 2
  $script:huduCalls       = 0
  # Get a Hudu API Key from https://yourhududomain.com/admin/api_keys
  $script:HuduAPIKey      = $env:HuduKey
  # Set the base domain of your Hudu instance without a trailing /
  $script:HuduBaseDomain  = $env:HuduDomain
  #Company Name as it appears in Hudu
  $CompanyName            = $env:CS_PROFILE_NAME
  $HuduAssetLayoutName    = "File Shares - AutoDoc"
  $timestamp              = "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))"
  #endregion
#endregion ----- DECLARATIONS ----

#region ----- FUNCTIONS ----
  function Get-ProcessOutput {
    Param (
      [Parameter(Mandatory = $true)]$FileName,
      $Args
    )
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo.WindowStyle = "Hidden"
    $process.StartInfo.CreateNoWindow = $true
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.RedirectStandardOutput = $true
    $process.StartInfo.RedirectStandardError = $true
    $process.StartInfo.FileName = $FileName
    if ($Args) {$process.StartInfo.Arguments = $Args}
    $process.Start()

    $StandardError = $process.StandardError.ReadToEnd()
    $StandardOutput = $process.StandardOutput.ReadToEnd()

    $output = New-Object PSObject
    $output | Add-Member -type NoteProperty -name StandardOutput -Value $StandardOutput
    $output | Add-Member -type NoteProperty -name StandardError -Value $StandardError
    return $output
  } ## Get-ProcessOutput

  function logERR ($intSTG, $strModule, $strErr) {
    $script:blnWARN = $true
    #CUSTOM ERROR CODES
    switch ($intSTG) {
      #'ERRRET'=1 - NOT ENOUGH ARGUMENTS, END SCRIPT
      1 {
        $script:blnBREAK = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - HuduDoc_FileShare - NO ARGUMENTS PASSED, END SCRIPT`r`n`r`n"
        write-output "$($strLineSeparator)`r`n$($(get-date)) - HuduDoc_FileShare - NO ARGUMENTS PASSED, END SCRIPT`r`n"
      }
      #'ERRRET'=2 - INSTALL / IMPORT MODULE FAILURE, END SCRIPT
      2 {
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - HuduDoc_FileShare - ($($strModule)) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n"
        write-output "$($strLineSeparator)`r`n$($(get-date)) - HuduDoc_FileShare - ($($strModule)) :"
        write-output "$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n"
      }
      #'ERRRET'=3+
      default {
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - HuduDoc_FileShare - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
        write-output "$($strLineSeparator)`r`n$($(get-date)) - HuduDoc_FileShare - $($strModule) :"
        write-output "$($strLineSeparator)`r`n`t$($strErr)"
      }
    }
  }
#endregion ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
clear-host
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
#INSTALL HUDUAPI MODULE
if (Get-Module -ListAvailable -Name HuduAPI) {
  Import-Module HuduAPI -MaximumVersion 2.3.2 -force
} else {
  install-module HuduAPI -MaximumVersion 2.3.2 -force -confirm:$false
  Import-Module HuduAPI -MaximumVersion 2.3.2 -force
}
#INSTALL NTFSSECURITY MODULE
if (Get-Module -ListAvailable -Name "NTFSSecurity") {
  Import-module "NTFSSecurity"
} else {
  install-module "NTFSSecurity" -Force -Confirm:$false
  import-module "NTFSSecurity"
}
Set-PSRepository -Name 'PSGallery' -InstallationPolicy Untrusted
#Set Hudu logon information
New-HuduAPIKey $script:HuduAPIKey
New-HuduBaseUrl $script:HuduBaseDomain

$Company = Get-HuduCompanies -name $CompanyName 
if ($Company) {
  $ComputerName = $($Env:COMPUTERNAME)
  # Find the asset we are running from
  $ParentAsset = Get-HuduAssets -primary_serial (get-ciminstance win32_bios).serialnumber
  #If count exists we either got 0 or more than 1 either way lets try to match off name
  if ($ParentAsset.count) {
    $ParentAsset = Get-HuduAssets -companyid $Company.id -name $ComputerName
  }
  # Check we found an Asset
  if ($ParentAsset) {
    $Layout = Get-HuduAssetLayouts -name $HuduAssetLayoutName
    if (!$Layout) { 
      $AssetLayoutFields = @(
        @{
          label        = 'Last Update'
          field_type   = 'Text'
          show_in_list = 'true'
          position     = 1
        },
        @{
          label        = 'Share Name'
          field_type   = 'Text'
          show_in_list = 'true'
          position     = 2
        },
        @{
          label        = 'Server'
          field_type   = 'RichText'
          show_in_list = 'false'
          position     = 3
        },
        @{
          label        = 'Share Path'
          field_type   = 'Email'
          show_in_list = 'true'
          position     = 4
        },
        @{
          label        = 'Net Share Permissions'
          field_type   = 'RichText'
          show_in_list = 'false'
          position     = 5
        },
        @{
          label        = 'Local Path'
          field_type   = 'RichText'
          show_in_list = 'false'
          position     = 6
        },
        @{
          label        = 'Full Control Permissions'
          field_type   = 'RichText'
          show_in_list = 'false'
          position     = 7
        },
        @{
          label        = 'Modify Permissions'
          field_type   = 'RichText'
          show_in_list = 'false'
          position     = 8
        },
        @{
          label        = 'Read permissions'
          field_type   = 'RichText'
          show_in_list = 'false'
          position     = 9
        },
        @{
          label        = 'Deny permissions'
          field_type   = 'RichText'
          show_in_list = 'false'
          position     = 10
        }
      )
      write-output "Creating New Asset Layout $($HuduAssetLayoutName)"
      New-HuduAssetLayout -name $HuduAssetLayoutName -icon "fas fa-folder-open" -color "#4CAF50" -icon_color "#ffffff" -include_passwords $false -include_photos $false -include_comments $false -include_files $false -fields $AssetLayoutFields
      $Layout = Get-HuduAssetLayouts -name $HuduAssetLayoutName
    }

    #Collect Data
    $AllSMBShares = Get-SmbShare | 
      where-object {(((@('Remote Admin', 'Default share', 'Remote IPC', 'Printer Drivers') -notcontains $_.Description)) -and $_.ShareType -eq 'FileSystemDirectory')}
    foreach ($SMBShare in $AllSMBShares) {
      $output = Get-ProcessOutput -FileName "C:\Windows\System32\net.exe" -Args "share `"$($SMBShare.name)`""
      $NetOut = $output.StandardOutput -split "Permission"
      $NetOut = $NetOut[1].split([Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries)
      $NetPermissions = "<table><colgroup><col/><col/><col/><col/></colgroup><tr><th>Permissions :</th></tr>"
      foreach ($perm in $NetOut) {
        if ($perm -ne "The command completed successfully.") {
          $NetPermissions += "<tr><td>$($perm.trim())</td></tr>"
        } elseif ($perm -eq "The command completed successfully.") {
          $NetPermissions += "</table>"
        }
      }
      try {
        $Permissions = get-item "$($SMBShare.path)" -erroraction stop | get-ntfsaccess
        $FullAccess = $Permissions | 
          where-object {(($_.'AccessRights' -eq "FullControl") -and ($_.'AccessControlType' -ne "Deny"))} | 
            select-object FullName, Account, AccessRights, AccessControlType  | convertto-html -Fragment | out-string
        #$FullAccess
        $Modify = $Permissions | 
          where-object {(($_.'AccessRights' -match "Modify") -and ($_.'AccessControlType' -ne "Deny"))} | 
            select-object FullName, Account, AccessRights, AccessControlType  | convertto-html -Fragment | out-string
        $ReadOnly = $Permissions | 
          where-object {(($_.'AccessRights' -match "Read") -and ($_.'AccessControlType' -ne "Deny"))} | 
            select-object FullName, Account, AccessRights, AccessControlType  | convertto-html -Fragment | out-string
        $Deny = $Permissions | 
          where-object {($_.'AccessControlType' -eq "Deny")} | 
            select-object FullName, Account, AccessRights, AccessControlType | convertto-html -Fragment | out-string
    
        if ($FullAccess.Length / 1kb -gt 64)  {$FullAccess = "The table is too long to display. Please see included CSV file."}
        if ($ReadOnly.Length / 1kb -gt 64)    {$ReadOnly = "The table is too long to display. Please see included CSV file."}
        if ($Modify.Length / 1kb -gt 64)      {$Modify = "The table is too long to display. Please see included CSV file."}
        if ($Deny.Length / 1kb -gt 64)        {$Deny = "The table is too long to display. Please see included CSV file."}
      } catch {
        $err = "`r`n$($_.Exeception) : $($_.scriptstacktrace) : $($_)`r`n$($script:strLineSeparator)"
        logERR 3 "SMB SHARE PERMISSIONS" "Failed Collecting Permisions`r`n$($script:strLineSeparator)`r`n$($err)"
        exit 1
      }
      #$PermCSV = ($Permissions | ConvertTo-Csv -NoTypeInformation -Delimiter ",") -join [Environment]::NewLine
      #$Bytes = [System.Text.Encoding]::UTF8.GetBytes($PermCSV)
      #$Base64CSV =[Convert]::ToBase64String($Bytes)    
      $AssetLink = "<a href=$($ParentAsset.url)>$($ParentAsset.name)</a>"
      
      $AssetFields = @{
        "last_update"              = $($timestamp)
        "share_name"               = $($SMBShare.name)
        "local_path"               = $($SMBShare.path)
        "share_path"               = "`\`\$($ParentAsset.name)`\$($SMBShare.name)"
        "net_share_permissions"    = $NetPermissions
        "full_control_permissions" = $FullAccess
        "read_permissions"         = $ReadOnly
        "modify_permissions"       = $Modify
        "deny_permissions"         = $Deny
        "server"                   = $AssetLink
      }
		
      try {
        start-sleep -seconds 5
        $AssetName = "$($ComputerName) - $($SMBShare.name)"
        write-output "Documenting to Hudu"  -ForegroundColor Green
        $Asset = Get-HuduAssets -name $AssetName -companyid $Company.id -assetlayoutid $Layout.id
        #If the Asset does not exist, we edit the body to be in the form of a new asset, if not, we just upload.
        if (!$Asset) {
          try {
            start-sleep -seconds 5
            write-output "Creating new Asset"
            $Asset = New-HuduAsset -name $AssetName -company_id $Company.id -asset_layout_id $Layout.id -fields $AssetFields
          } catch {
            #$script:diag += "`r`nFailed Creating new Asset"
            #$script:diag += "`r`n$($_.Exception)"
            #$script:diag += "`r`n$($_.scriptstacktrace)"
            #$script:diag += "`r`n$($_)"
            #write-output "$($script:diag)`r`n"
            $err = "`r`n$($_.Exeception) : $($_.scriptstacktrace) : $($_)`r`n$($script:strLineSeparator)"
            logERR 3 "HUDU ASSET CREATION" "Failed Creating New Asset`r`n$($script:strLineSeparator)`r`n$($err)"
            exit 1
          }
        } else {
          try {
            start-sleep -seconds 5
            write-output "Updating Asset"
            $Asset = Set-HuduAsset -asset_id $Asset.id -name $AssetName -company_id $Company.id -asset_layout_id $Layout.id -fields $AssetFields
          } catch {
            #$script:diag += "`r`nFailed Updating Asset"
            #$script:diag += "`r`n$($_.Exception)"
            #$script:diag += "`r`n$($_.scriptstacktrace)"
            #$script:diag += "`r`n$($_)"
            #write-output "$($script:diag)`r`n"
            $err = "`r`n$($_.Exeception) : $($_.scriptstacktrace) : $($_)`r`n$($script:strLineSeparator)"
            logERR 3 "HUDU ASSET UPDATE" "Failed to Update the Hudu Asset`r`n$($script:strLineSeparator)`r`n$($err)"
            exit 1
          }
        }
      } catch {
        #$script:diag += "`r`nAPI_WatchDog : Failed Retrieving Asset"
        #$script:diag += "`r`n$($_.Exception)"
        #$script:diag += "`r`n$($_.scriptstacktrace)"
        #$script:diag += "`r`n$($_)"
        #write-output "$($script:diag)`r`n"
        $err = "`r`n$($_.Exeception) : $($_.scriptstacktrace) : $($_)`r`n$($script:strLineSeparator)"
        logERR 3 "HUDU ASSET RETRIEVAL" "Failed to Retrieve the Hudu Asset`r`n$($script:strLineSeparator)`r`n$($err)"
        exit 1
      }
    }
  } else {
    write-output "$($ComputerName) was not found in Hudu"
  }
} else {
  write-output "$($CompanyName) was not found in Hudu"
}
write-output "Done."
exit 0