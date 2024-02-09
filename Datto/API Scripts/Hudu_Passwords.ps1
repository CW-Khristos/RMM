#First Clear any variables
#Remove-Variable * -ErrorAction SilentlyContinue
#region ----- DECLARATIONS ----
  $strOPT                 = $null
  $script:diag            = $null
  $script:blnBREAK        = $false
  $script:blnDomain       = $false
  $script:strComputer     = $env:computername
  $strLineSeparator       = "-------------------"
  ######################### TLS Settings ###########################
  #[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType] 'Tls12'
  [System.Net.ServicePointManager]::SecurityProtocol = (
    [System.Net.SecurityProtocolType]::Ssl3 -bor 
    [System.Net.SecurityProtocolType]::Ssl2 -bor 
    [System.Net.SecurityProtocolType]::Tls13 -bor 
    [System.Net.SecurityProtocolType]::Tls12 -bor 
    [System.Net.SecurityProtocolType]::Tls11 -bor 
    [System.Net.SecurityProtocolType]::Tls
  )
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
  $script:pwdLength       = 8 #$env:Length
  $script:strPassword     = $null #$env:Password
#endregion ----- DECLARATIONS ----

#REGION ----- FUNCTIONS ----
  function StopClock {
    #Stop script execution time calculation
    $script:sw.Stop()
    $Days = $sw.Elapsed.Days
    $Hours = $sw.Elapsed.Hours
    $Minutes = $sw.Elapsed.Minutes
    $Seconds = $sw.Elapsed.Seconds
    $Milliseconds = $sw.Elapsed.Milliseconds
    $ScriptStopTime = (Get-Date).ToString('dd-MM-yyyy hh:mm:ss')
    write-output "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds"
    $script:diag += "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
  }

  function logERR ($intSTG, $strModule, $strErr) {
    $script:blnWARN = $true
    #CUSTOM ERROR CODES
    switch ($intSTG) {
      1 {                                                         #'ERRRET'=1 - NOT ENOUGH ARGUMENTS, END SCRIPT
        $script:blnBREAK = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - Hudu_Passwords - NO ARGUMENTS PASSED, END SCRIPT`r`n`r`n"
        write-output "$($strLineSeparator)`r`n$($(get-date)) - Hudu_Passwords - NO ARGUMENTS PASSED, END SCRIPT`r`n`r`n" -foregroundcolor red
      }
      2 {                                                         #'ERRRET'=2 - END SCRIPT
        $script:blnBREAK = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - Hudu_Passwords - ($($strModule)) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)`r`n`tEND SCRIPT`r`n$($strLineSeparator)`r`n"
        write-output "$($strLineSeparator)`r`n$($(get-date)) - Hudu_Passwords - ($($strModule)) :" -foregroundcolor red
        write-output "$($strLineSeparator)`r`n`t$($strErr)`r`n`tEND SCRIPT`r`n$($strLineSeparator)`r`n" -foregroundcolor red
      }
      3 {                                                         #'ERRRET'=3
        $script:blnWARN = $false
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - Hudu_Passwords - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
        write-output "$($strLineSeparator)`r`n$($(get-date)) - Hudu_Passwords - $($strModule) :" -foregroundcolor yellow
        write-output "$($strLineSeparator)`r`n`t$($strErr)" -foregroundcolor yellow
      }
      default {                                                   #'ERRRET'=4+
        $script:blnBREAK = $false
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - Hudu_Passwords - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
        write-output "$($strLineSeparator)`r`n$($(get-date)) - Hudu_Passwords - $($strModule) :" -foregroundcolor yellow
        write-output "$($strLineSeparator)`r`n`t$($strErr)" -foregroundcolor red
      }
    }
  }

  function chkAU {
    param (
      $ver, $repo, $brch, $dir, $scr
    )
    $blnXML = $true
    #RETRIEVE VERSION XML FROM GITHUB
    $srcVER = "https://raw.githubusercontent.com/CW-Khristos/$($strREPO)/$($strBRCH)/Datto/version.xml"
    $xmldiag = "Loading : '$($strREPO)/$($strBRCH)' Version XML`r`n$($strLineSeparator)"
    logERR 3 "chkAU" "$($xmldiag)"
    try {
      $verXML = New-Object System.Xml.XmlDocument
      $verXML.Load($srcVER)
    } catch {
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
      $xmldiag = "XML.Load() - Could not open $($srcVER)`r`n$($err)`r`n"
      try {
        $web = new-object system.net.webclient
        [xml]$verXML = $web.DownloadString($srcVER)
      } catch {
        $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
        $xmldiag += "Web.DownloadString() - Could not download $($srcVER)`r`n$($err)`r`n"
        try {
          start-bitstransfer -erroraction stop -source $srcVER -destination "C:\IT\Scripts\version.xml"
          [xml]$verXML = "C:\IT\Scripts\version.xml"
        } catch {
          $blnXML = $false
          $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
          $xmldiag += "BITS.Transfer() - Could not download $($srcVER)`r`n$($err)`r`n"
        }
      }
    }
    logERR 3 "chkAU" "$($xmldiag)`r`n$($strLineSeparator)"
    #READ VERSION XML DATA INTO NESTED HASHTABLE FOR LATER USE
    try {
      if ($blnXML) {
        foreach ($objSCR in $verXML.SCRIPTS.ChildNodes) {
          if ($objSCR.name -match $strSCR) {
            #CHECK LATEST VERSION
            $xmldiag = "`t - CHKAU : $($strVER) : GitHub - $($strBRCH) : $($objSCR.innertext)`r`n"
            if ([version]$objSCR.innertext -gt $strVER) {
              $xmldiag += "`t`t - UPDATING : $($objSCR.name) : $($objSCR.innertext)`r`n"
              #REMOVE PREVIOUS COPIES OF SCRIPT
              if (test-path -path "C:\IT\Scripts\$($strSCR)_$($strVER).ps1") {
                remove-item -path "C:\IT\Scripts\$($strSCR)_$($strVER).ps1" -force -erroraction stop
              }
              #DOWNLOAD LATEST VERSION OF ORIGINAL SCRIPT
              if (($null -eq $strDIR) -or ($strDIR -eq "")) {
                $strURL = "https://raw.githubusercontent.com/CW-Khristos/$($strREPO)/$($strBRCH)/$($strSCR)_$($objSCR.innertext).ps1"
              } elseif (($null -ne $strDIR) -and ($strDIR -ne "")) {
                $strURL = "https://raw.githubusercontent.com/CW-Khristos/$($strREPO)/$($strBRCH)/$($strDIR)/$($strSCR)_$($objSCR.innertext).ps1"
              }
              Invoke-WebRequest "$($strURL)" | Select-Object -ExpandProperty Content | Out-File "C:\IT\Scripts\$($strSCR)_$($objSCR.innertext).ps1"
              #RE-EXECUTE LATEST VERSION OF SCRIPT
              $xmldiag += "`t`t - RE-EXECUTING : $($objSCR.name) : $($objSCR.innertext)`r`n`r`n"
              $output = C:\Windows\System32\cmd.exe "/C powershell -executionpolicy bypass -file `"C:\IT\Scripts\$($strSCR)_$($objSCR.innertext).ps1`""
              foreach ($line in $output) {$stdout += "$($line)`r`n"}
              $xmldiag += "`t`t - StdOut : $($stdout)`r`n`t`t$($strLineSeparator)`r`n"
              $xmldiag += "`t`t - CHKAU COMPLETED : $($objSCR.name) : $($objSCR.innertext)`r`n`t`t$($strLineSeparator)`r`n"
              $script:blnBREAK = $true
            } elseif ([version]$objSCR.innertext -le $strVER) {
              $xmldiag += "`t`t - NO UPDATE : $($objSCR.name) : $($objSCR.innertext)`r`n`t`t$($strLineSeparator)`r`n"
            }
            break
          }
        }
      }
      logERR 3 "chkAU" "$($xmldiag)`r`n$($strLineSeparator)"
    } catch {
      $script:blnBREAK = $false
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
      $xmldiag = "Error reading Version XML : $($srcVER)`r`n$($err)"
      logERR 3 "chkAU" "$($xmldiag)`r`n$($strLineSeparator)"
    }
  } ## chkAU

  function download-Files ($file, $dest) {
    $strURL = "https://raw.githubusercontent.com/CW-Khristos/$($strREPO)/$($strBRCH)/$($strDIR)/$($file)"
    try {
      $dldiag = "Downloading File : '$($strURL)'"
      logERR 3 "download-Files" "$($dldiag)`r`n$($strLineSeparator)"
      $web = new-object system.net.webclient
      $dlFile = $web.downloadfile("$($strURL)", "$($dest)\$($file)")
    } catch {
      try {
        $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
        $dldiag = "Web.DownloadFile() - Could not download $($strURL)`r`n$($strLineSeparator)`r`n$($err)"
        logERR 3 "download-Files" "$($dldiag)`r`n$($strLineSeparator)"
        start-bitstransfer -source "$($strURL)" -destination "$($dest)\$($file)" -erroraction stop
      } catch {
        $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
        $dldiag = "`r`nBITS.Transfer() - Could not download $($strURL)`r`n$($strLineSeparator)`r`n$($err)"
        logERR 2 "download-Files" "$($dldiag)`r`n$($strLineSeparator)"
      }
    }
  }
#ENDREGION ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
clear-host
#Start script execution time calculation
$ScrptStartTime = (get-date).ToString('dd-MM-yyyy hh:mm:ss')
$script:sw = [Diagnostics.Stopwatch]::StartNew()
if ($script:blnPortal -eq "true") {
  $script:blnPortal = $true
} elseif ($script:blnPortal -eq "false") {
  $script:blnPortal = $false
}
if ((Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain) {$script:blnDomain = $true}
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
  try {
    Install-PackageProvider -Name NuGet -Force -Confirm:$false
  } catch {
    logERR 2 "NuGet" "INSTALL / IMPORT PACKAGE FAILURE"
  }
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
#INSTALL ACTIVE DIRECTORY MODULE
if ($script:blnDomain) {
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
}
Set-PSRepository -Name 'PSGallery' -InstallationPolicy Untrusted
# GENERATE RANDOMIZED PASSWORD UP TO LEN($script:pwdLength)
if (($script:pwdLength -eq 0) -or ($script:pwdLength -lt 8)) {$script:pwdLength = 10}
if ($script:strPassword) {
  $script:strPassword  = $script:strPassword 
} elseif (($script:strPassword -eq $null) -or ($script:strPassword -eq "") -or ($script:strPassword -eq "NULL")) {
  $script:pass = $false
  while (-not $script:pass) {
    start-sleep -milliseconds 100
    $script:strPassword = -join ((33..33) + (35..37) + (42..42) + (50..57) + (63..72) + (74..75) + (77..78) + (80..90) + (97..104) + (106..107) + (109..110) + (112..122) | 
      Get-Random -Count $script:pwdLength | ForEach-Object {[char]$_})
    if (($script:strPassword -cmatch "[A-Z\p{Lu}\s]") -and `
      ($script:strPassword -cmatch "[a-z\p{Ll}\s]") -and `
      ($script:strPassword -match "[\d]") -and `
      ($script:strPassword -match "[^\w]")) {
        $script:pass = $true
    }
  }
}
if (-not $script:blnBREAK) {
  #Set Hudu logon information
  New-HuduAPIKey $HuduAPIKey
  New-HuduBaseUrl $HuduBaseDomain
  # Get the Hudu Company
  try {
    logERR 3 "Company Retrieval" "Accessing $($script:strCompany) in Hudu`r`n$($strLineSeparator)"
    $company = Get-HuduCompanies -name "$($script:strCompany)"
  } catch {
  }
  if ($company) {
    # See if a password already exists
    logERR 3 "Password Retrieval" "Accessing Password Asset in Hudu : $($script:pwdName)`r`n$($strLineSeparator)"
    $acctPWD = Get-HuduPasswords -name "$($script:pwdName)" -companyid $company.id
    #Find the parent asset
    logERR 3 "Parent Retrieval" "Accessing Password Parent Asset in Hudu`r`n$($strLineSeparator)"
    if (-not $script:blnDomain) {
      $huduParent = Get-HuduAssets -name "$($script:strComputer)"
    } elseif ($script:blnDomain) {
      $huduParent = Get-HuduAssets -name "$($script:strCompany) Active Directory"
    }
    if ($acctPWD) {                             #Password Exists
      try {
        #Update Notes
        logERR 3 "Update Password" "Password Exists : Updating Notes`r`n$($strLineSeparator)"
        if ($acctPWD.description -match "Last Rotation :") {
          $description = $null
          $tmp = $acctPWD.description.split([Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries)
          foreach ($line in $tmp) {if ($line -notmatch "Last Rotation :") {$description += "$($description)$($line)`r`n"}}
          $notes = "Last Rotation : $($(get-date))`r`n$($description)"
        } elseif ($acctPWD.description -notmatch "Last Rotation :") {
          $notes = "Last Rotation : $($(get-date))`r`n$($acctPWD.description)"
        }
        #Set Password
        logERR 3 "Update Password" "Password Exists : Updating Password`r`n$($strLineSeparator)"
        $acctPWD = set-hudupassword -id $acctPWD.id -company_id $company.id -passwordable_type "Asset" `
          -passwordable_id $huduParent.id -in_portal $script:blnPortal -password "$($script:strPassword)" -description "$($notes)" -name "$($script:pwdName)"
        if (-not $script:blnDomain) {           #Local Computer Account
          Set-LocalUser -erroraction stop -Name "$($script:adUser)" -Password (ConvertTo-SecureString -AsPlainText "$($script:strPassword)" -Force)
        } elseif ($script:blnDomain) {          #Active Directory Account
          Set-ADAccountPassword -erroraction stop -Identity "$($script:adUser)" -Reset -NewPassword (ConvertTo-SecureString -AsPlainText "$($script:strPassword)" -Force)
        }
        logERR 3 "Update Password" "Updated Password : $($script:pwdName)`r`n$($strLineSeparator)"
      } catch {
        $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
        logERR 4 "Update Password" "Error Updating Password : $($script:pwdName)`r`n$($err)`r`n$($strLineSeparator)"
      }
    } elseif (-not $acctPWD) {                  #Password Doesn't Exist
      try {
        #Set Notes
        logERR 3 "Create Password" "Password Doesn't Exist : Creating Notes`r`n$($strLineSeparator)"
        $notes = "Last Rotation : $($(get-date))`r`nCreated By : Hudu_Passwords"
        #Set Password
        logERR 3 "Create Password" "Password Doesn't Exist : Creating Password`r`n$($strLineSeparator)"
        $acctPWD = new-hudupassword -company_id $company.id -passwordable_type "Asset" `
          -passwordable_id $huduParent.id -in_portal $script:blnPortal -password "$($script:strPassword)" -description "$($notes)" -name "$($script:pwdName)"
        if (-not $script:blnDomain) {           #Local Computer Account
          Set-LocalUser -erroraction stop -Name "$($script:adUser)" -Password (ConvertTo-SecureString -AsPlainText "$($script:strPassword)" -Force)
        } elseif ($script:blnDomain) {          #Active Directory Account
          Set-ADAccountPassword -erroraction stop -Identity "$($script:adUser)" -Reset -NewPassword (ConvertTo-SecureString -AsPlainText "$($script:strPassword)" -Force)
        }
        logERR 3 "Create Password" "Created Password : $($script:pwdName)`r`n$($strLineSeparator)"
      } catch {
        $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
        logERR 4 "Create Password" "Error Creating Password : $($script:pwdName)`r`n$($strLineSeparator)"
      }
    }
    # See if a password already exists
    logERR 3 "Password Retrieval" "Accessing Password Asset in Hudu : $($script:pwdName) O365 Admin`r`n$($strLineSeparator)"
    $o365PWD = Get-HuduPasswords -name "$($script:pwdName) O365 Admin" -companyid $company.id
    #Find the parent asset from serial
    logERR 3 "Parent Retrieval" "Accessing Password Parent Asset in Hudu`r`n$($strLineSeparator)"
    $o365Parent = Get-HuduAssets -name "$($script:strCompany) Office 365"
    if ($o365PWD) {                             #Password Exists
      try {
        #Update Notes
        logERR 3 "Update Password" "Password Exists : Updating Notes`r`n$($strLineSeparator)"
        if ($o365PWD.description -match "Last Rotation :") {
          $description = $null
          $tmp = $o365PWD.description.split([Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries)
          foreach ($line in $tmp) {if ($line -notmatch "Last Rotation :") {$description += "$($description)$($line)`r`n"}}
          $notes = "Last Rotation : $($(get-date))`r`n$($description)"
        } elseif ($adPWD.description -notmatch "Last Rotation :") {
          $notes = "Last Rotation : $($(get-date))`r`n$($o365PWD.description)"
        }
        #Set Password
        logERR 3 "Update Password" "Password Exists : Updating Password`r`n$($strLineSeparator)"
        $o365PWD = set-hudupassword -id $o365PWD.id -company_id $company.id -passwordable_type "Asset" `
          -passwordable_id $o365Parent.id -in_portal $script:blnPortal -password "$($script:strPassword)" -description "$($notes)" -name "$($script:pwdName) O365 Admin"
        logERR 3 "Update Password" "Updated Password : $($script:pwdName) O365 Admin`r`n$($strLineSeparator)"
      } catch {
        $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
        logERR 4 "Update Password" "Error Updating Password : $($script:pwdName) O365 Admin`r`n$($err)`r`n$($strLineSeparator)"
      }
    } elseif (-not $o365PWD) {                  #Password Doesn't Exist
      try {
        #Update Notes
        $notes = "Last Rotation : $($(get-date))`r`nCreated By : Hudu_Passwords"
        #Set Password
        $o365PWD = new-hudupassword -company_id $company.id -passwordable_type "Asset" `
          -passwordable_id $o365Parent.id -in_portal $script:blnPortal -password "$($script:strPassword)" -description "$($notes)" -name "$($script:pwdName) O365 Admin"
        logERR 3 "Create Password" "Created Password : $($script:pwdName) O365 Admin`r`n$($strLineSeparator)"
      } catch {
        $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
        logERR 4 "Create Password" "Error Creating Password : $($script:pwdName) O365 Admin`r`n$($err)`r`n$($strLineSeparator)"
      }
    }
  } elseif (-not $company) {
    logERR 4 "Company Retrieval" "$($script:strCompany) was not found in Hudu`r`n$($strLineSeparator)"
  }
}
#DATTO OUTPUT
#Stop script execution time calculation
StopClock
#CLEAR LOGFILE
#$null | set-content $logPath -force
$finish = "$((Get-Date).ToString('yyyy-MM-dd hh:mm:ss'))"
if (-not $script:blnBREAK) {
  if (-not $script:blnWARN) {
    #WRITE TO LOGFILE
    logERR 3 "$($strOPT)" "Execution Successful : $($finish)`r`n$($strLineSeparator)"
    exit 0
  } elseif ($script:blnWARN) {
    #WRITE TO LOGFILE
    logERR 3 "END" "Execution Completed With Warnings : $($finish)`r`n$($strLineSeparator)"
    exit 1
  }
} elseif ($script:blnBREAK) {
  #WRITE TO LOGFILE
  logERR 4 "END" "Execution Failed : $($finish)`r`n$($strLineSeparator)"
  exit 1
}
#END SCRIPT
#------------