#First Clear any variables
#Remove-Variable * -ErrorAction SilentlyContinue
#region ----- DECLARATIONS ----
  $strOPT = $null
  $script:diag = $null
  $script:blnBREAK = $false
  $strLineSeparator  = "-------------------"
  ######################### TLS Settings ###########################
  #[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType] 'Tls12'
  [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls -bor [System.Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls12
  ######################### Hudu Settings ###########################
  $script:huduCalls       = 0
  # Get a Hudu API Key from https://yourhududomain.com/admin/api_keys
  $script:HuduAPIKey      = $env:HuduKey
  # Set the base domain of your Hudu instance without a trailing /
  $script:HuduBaseDomain  = $env:HuduDomain
  ######################### Account Details ###########################
  $script:pwdName         = $env:Name
  $script:adUser          = $env:User
  $script:strCompany      = $env:HuduCompany
  $script:blnPortal       = $env:Portal
  ######################### Password Details ###########################
  $script:pwdLength       = $env:Length
  $script:strPassword     = $env:Password
#endregion ----- DECLARATIONS ----

#REGION ----- FUNCTIONS ----
function logERR ($intSTG, $strModule, $strErr) {
  $script:blnWARN = $true
  #CUSTOM ERROR CODES
  switch ($intSTG) {
    1 {                                                         #'ERRRET'=1 - NOT ENOUGH ARGUMENTS, END SCRIPT
      $script:blnBREAK = $true
      $script:diag += "`r`n$($(get-date))`t - Hudu_Passwords - NO ARGUMENTS PASSED, END SCRIPT`r`n`r`n"
      write-host "$($(get-date))`t - Hudu_Passwords - NO ARGUMENTS PASSED, END SCRIPT`r`n"
    }
    2 {                                                         #'ERRRET'=2 - INSTALL / IMPORT MODULE FAILURE, END SCRIPT
      $script:blnBREAK = $true
      $script:diag += "`r`n$($(get-date))`t - Hudu_Passwords - ($($strModule))`r`n$($strErr), END SCRIPT`r`n`r`n"
      write-host "$($(get-date))`t - Hudu_Passwords - ($($strModule))`r`n$($strErr), END SCRIPT`r`n`r`n"
    }
    default {                                                   #'ERRRET'=3+
      $script:diag += "`r`n$($(get-date))`t - Hudu_Passwords - $($strModule) : $($strErr)"
      write-host "$($(get-date))`t - Hudu_Passwords - $($strModule) : $($strErr)"
    }
  }
}
#ENDREGION ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
clear-host
if ($script:blnPortal -eq "true") {
  $script:blnPortal = $true
} elseif ($script:blnPortal -eq "false") {
  $script:blnPortal = $false
}
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
if (Get-Module -Name PowerShellGet -ListAvailable) {
  try {
    Import-Module PowerShellGet
  } catch {
    logERR 2 "PowerShellGet" "INSTALL / IMPORT MODULE FAILURE"
  }
} else {
  try {
    Install-Module PowerShellGet -Force -Confirm:$false
    Import-Module PowerShellGet
  } catch {
    logERR 2 "PowerShellGet" "INSTALL / IMPORT MODULE FAILURE"
  }
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
#INSTALL ACTIVE DIRECTORY MODULE
if (Get-Module -Name ActiveDirectory -ListAvailable) {
  try {
    Import-Module ActiveDirectory
  } catch {
    logERR 2 "ActiveDirectory" "INSTALL / IMPORT MODULE FAILURE"
  }
} else {
  try {
    Install-Module ActiveDirectory -Force -Confirm:$false
    Import-Module ActiveDirectory
  } catch {
    logERR 2 "ActiveDirectory" "INSTALL / IMPORT MODULE FAILURE"
  }
}
Set-PSRepository -Name 'PSGallery' -InstallationPolicy Untrusted
# GENERATE RANDOMIZED PASSWORD UP TO LEN($env:Password)
if (($script:pwdLength -eq 0) -or ($script:pwdLength -lt 8)) {
  $script:pwdLength = 10
}
if (($script:strPassword -eq $null) -or ($script:strPassword -eq "") -or ($script:strPassword -eq "NULL")) {
  $script:pass = $false
  while (-not $script:pass) {
    $script:strPassword = -join ((33..33) + (35..37) + (42..42) + (50..57) + (63..72) + (74..75) + (77..78) + (80..90) + (97..104) + (106..107) + (109..110) + (112..122) | 
      Get-Random -Count $script:pwdLength | ForEach-Object {[char]$_})
    if (($script:strPassword -cmatch "[A-Z\p{Lu}\s]") -and `
      ($script:strPassword -cmatch "[a-z\p{Ll}\s]") -and `
      ($script:strPassword -match "[\d]") -and `
      ($script:strPassword -match "[^\w]")) {
        $script:pass = $true
    }
    start-sleep -milliseconds 100
  }
} else {
  $script:strPassword  = $script:strPassword 
}
#Set Hudu logon information
New-HuduAPIKey $HuduAPIKey
New-HuduBaseUrl $HuduBaseDomain
# Get the Hudu Company we are working without
$company = Get-HuduCompanies -name $script:strCompany
if ($company) {
  # See if a password already exists
  $adPWD = Get-HuduPasswords -name "$($script:pwdName)" -companyid $company.id
  #Find the parent asset from serial
  $adParent = Get-HuduAssets -name "$($script:strCompany) Active Directory"
  if ($adPWD) {
    try {
      if ($adPWD.description -match "Last Rotation :") {
        $description = $null
        $tmp = $adPWD.description.split([Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries)
        foreach ($line in $tmp) {
          if ($line -notmatch "Last Rotation :") {
            $description += "$($description)$($line)`r`n"
          }
        }
        $notes = "Last Rotation : $($(get-date))`r`n$($description)"
      } elseif ($adPWD.description -notmatch "Last Rotation :") {
        $notes = "Last Rotation : $($(get-date))`r`n$($adPWD.description)"
      }
      $adPWD = set-hudupassword -id $adPWD.id -company_id $company.id -passwordable_type "Asset" `
        -passwordable_id $adParent.id -in_portal $script:blnPortal -password "$($script:strPassword)" -description "$($notes)" -name "$($script:pwdName)"
      try {
        Set-ADAccountPassword -erroraction stop -Identity $script:adUser -Reset -NewPassword (ConvertTo-SecureString -AsPlainText "$($script:strPassword)" -Force)
      } catch {
        write-host "`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
      }
      $script:diag += "`r`nUpdated Password : $($script:pwdName)`r`n$($strLineSeparator)`r`n"
      Write-Host "Updated Password : $($script:pwdName)`r`n$($strLineSeparator)"
    } catch {
      $script:diag += "`r`nError Updating Password : $($script:pwdName)`r`n$($strLineSeparator)`r`n"
      Write-Host "Error Updating Password : $($script:pwdName)`r`n$($strLineSeparator)"
    }
  } else {
    try {
      $notes = "Last Rotation : $($(get-date))`r`nCreated By : Hudu_Passwords"
      $adPWD = new-hudupassword -company_id $company.id -passwordable_type "Asset" `
        -passwordable_id $adParent.id -in_portal $script:blnPortal -password "$($script:strPassword)" -description "$($notes)" -name "$($script:pwdName)"
      try {
        Set-ADAccountPassword -erroraction stop -Identity $script:adUser -Reset -NewPassword (ConvertTo-SecureString -AsPlainText "$($script:strPassword)" -Force)
      } catch {
        write-host "`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
      }
      $script:diag += "`r`nCreated Password : $($script:pwdName)`r`n$($strLineSeparator)`r`n"
      Write-Host "Created Password : $($script:pwdName)`r`n$($strLineSeparator)"
    } catch {
      $script:diag += "`r`nError Creating Password : $($script:pwdName)`r`n$($strLineSeparator)`r`n"
      Write-Host "Error Creating Password : $($script:pwdName)`r`n$($strLineSeparator)"
    }
  }
  # See if a password already exists
  $o365PWD = Get-HuduPasswords -name "$($script:pwdName) O365 Admin" -companyid $company.id
  #Find the parent asset from serial
  $o365Parent = Get-HuduAssets -name "$($script:strCompany) Office 365"
  if ($o365PWD) {
    try {
      if ($o365PWD.description -match "Last Rotation :") {
        $description = $null
        $tmp = $o365PWD.description.split([Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries)
        foreach ($line in $tmp) {
          if ($line -notmatch "Last Rotation :") {
            $description += "$($description)$($line)`r`n"
          }
        }
        $notes = "Last Rotation : $($(get-date))`r`n$($description)"
      } elseif ($adPWD.description -notmatch "Last Rotation :") {
        $notes = "Last Rotation : $($(get-date))`r`n$($o365PWD.description)"
      }
      $o365PWD = set-hudupassword -id $o365PWD.id -company_id $company.id -passwordable_type "Asset" `
        -passwordable_id $o365Parent.id -in_portal $script:blnPortal -password "$($script:strPassword)" -description "$($notes)" -name "$($script:pwdName) O365 Admin"
      $script:diag += "`r`nUpdated Password : $($script:pwdName) O365 Admin`r`n$($strLineSeparator)`r`n"
      Write-Host "Updated Password : $($script:pwdName) O365 Admin`r`n$($strLineSeparator)"
    } catch {
      $script:diag += "`r`nError Updating Password : $($script:pwdName) O365 Admin`r`n$($strLineSeparator)`r`n"
      Write-Host "Error Updating Password : $($script:pwdName) O365 Admin`r`n$($strLineSeparator)"
    }
  } else {
    try {
      $notes = "Last Rotation : $($(get-date))`r`nCreated By : Hudu_Passwords"
      $o365PWD = new-hudupassword -company_id $company.id -passwordable_type "Asset" `
        -passwordable_id $o365Parent.id -in_portal $script:blnPortal -password "$($script:strPassword)" -description "$($notes)" -name "$($script:pwdName) O365 Admin"
      $script:diag += "`r`nCreated Password : $($script:pwdName) O365 Admin`r`n$($strLineSeparator)`r`n"
      Write-Host "Created Password : $($script:pwdName) O365 Admin`r`n$($strLineSeparator)"
    } catch {
      $script:diag += "`r`nError Creating Password : $($script:pwdName) O365 Admin`r`n$($strLineSeparator)`r`n"
      Write-Host "Error Creating Password : $($script:pwdName) O365 Admin`r`n$($strLineSeparator)"
    }
  }
} else {
  $script:diag += "`r`n$($script:strCompany) was not found in Hudu"
  Write-Host "$($script:strCompany) was not found in Hudu"
}
#END SCRIPT
#------------