#https://github.com/eladshamir/Internal-Monologue

#region ----- DECLARATIONS ----
  #BELOW PARAM() MUST BE COMMENTED OUT FOR USE WITHIN DATTO RMM
  #UNCOMMENT BELOW PARAM() AND RENAME '$env:var' TO '$var' TO UTILIZE IN CLI
  #Param(
  #)
  $script:diag                = $null
  $script:finish              = $null
  $script:blnFAIL             = $false
  $script:blnWARN             = $false
  $script:strLineSeparator    = "---------"
  $blnFix                     = $env:blnFix
  $hashNTLM                   = @{}
  $regValues                  = @(
    "NtlmMinClientSec"
    "NtlmMinServerSec"
    "LMCompatibilityLevel"
    "AuditReceivingNTLMTraffic"
    "RestrictSendingNTLMtraffic"
    "RestrictReceivingNTLMtraffic"
  )
  $regPaths                   = @(
    "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
    "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0"
  )
  $mapNTLMSecurity            = @{
    NTLMv1      = 512
    NTLMv2      = 5376
    NTLMv2Sec   = 524288
    Bit128      = 536870912
    Bit56       = 2147483648
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

  function write-NTLMSecurity ($path, $setting, $value) {
    try {
      write-output "$($script:strLineSeparator)`r`nApplying Changes to $($path)\$($setting) : New Value ($($value))`r`n$($script:strLineSeparator)"
      $script:diag += "$($script:strLineSeparator)`r`nApplying Changes to $($path)\$($setting) : New Value ($($value))`r`n$($script:strLineSeparator)`r`n"
      set-itemproperty -path "$($path)" -name "$($setting)" -value $value -force -erroraction stop
      write-output "`tDone`r`n$($script:strLineSeparator)"
      $script:diag += "`tDone`r`n$($script:strLineSeparator)`r`n"
    } catch {
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
      $script:diag += "$($err)`r`n"
      write-output "$($err)"
    }
  }

  function map-NTLMSecurity ($setting, $value) {
    $hashNTLM.add($setting, $value)
    $strConfig = "$($script:strLineSeparator)`r`n`t"
    switch ($setting) {
    #https://learn.microsoft.com/en-us/troubleshoot/windows-client/windows-security/enable-ntlm-2-authentication
    <#.HKLM:\SYSTEM\CurrentControlSet\Services\Lsa
      .LMCompatibility (0-3) : Windows 95 and Windows 98-based computers
      .LMCompatibilityLevel (0-5) : Windows NT 4.0 and Windows 2000
        .Level 0
          Send LM and NTLM response; never use NTLM 2 session security
          Clients use LM and NTLM authentication, and never use NTLM 2 session security; domain controllers accept LM, NTLM, and NTLM 2 authentication
        .Level 1
          Use NTLM 2 session security if negotiated
          Clients use LM and NTLM authentication, and use NTLM 2 session security if the server supports it; domain controllers accept LM, NTLM, and NTLM 2 authentication
        .Level 2
          Send NTLM response only
          Clients use only NTLM authentication, and use NTLM 2 session security if the server supports it; domain controllers accept LM, NTLM, and NTLM 2 authentication
        .Level 3
          Send NTLM 2 response only
          Clients use NTLM 2 authentication, and use NTLM 2 session security if the server supports it; domain controllers accept LM, NTLM, and NTLM 2 authentication
        .Level 4
          Domain controllers refuse LM responses
          Clients use NTLM authentication, and use NTLM 2 session security if the server supports it; domain controllers refuse LM authentication
          (that is, they accept NTLM and NTLM 2)
        .Level 5
          Domain controllers refuse LM and NTLM responses (accept only NTLM 2)
          Clients use NTLM 2 authentication, use NTLM 2 session security if the server supports it; domain controllers refuse NTLM and LM authentication (they accept only NTLM 2)
          A client computer can only use one protocol in talking to all servers
          You cannot configure it, for example, to use NTLM v2 to connect to Windows 2000-based servers and then to use NTLM to connect to other servers. This is by design
    #>
      "LMCompatibilityLevel" {
        switch ($value) {
          0 {$strConfig += "$($setting) : Level $($value)`r`n`t(Send LM and NTLMv1 response; never use NTLM 2 Session Security)"; break}
          1 {$strConfig += "$($setting) : Level $($value)`r`n`t(Use NTLM 2 Session Security if negotiated)"; break}
          2 {$strConfig += "$($setting) : Level $($value)`r`n`t(Send NTLMv1 response only)"; break}
          3 {$strConfig += "$($setting) : Level $($value)`r`n`t(Send NTLMv2 response only)"; break}
          4 {$strConfig += "$($setting) : Level $($value)`r`n`t(Clients use NTLMv1 authentication, and use NTLM 2 Session Security if supported`r`n`tDomain controllers refuse LM responses)"; break}
          5 {$strConfig += "$($setting) : Level $($value)`r`n`t(Clients use NTLMv2 authentication, use NTLM 2 Session Security if supported`r`n`tDomain controllers refuse LM and NTLM responses (accept only NTLMv2))"; break}
        }
        break
      }
    <#.HKLM:\System\CurrentControlSet\Control\LSA
        .HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0\NtlmMinClientSec
        .HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0\NtlmMinServerSec
          0x00000010 (16) - Message integrity
          0x00000020 (32) - Message confidentiality
          512 - NTLMv1
          5376 - NTLMv2
          5368 - NTLMv2-SSP
          0x00080000 (524288) - NTLM 2 session security
          0x20000000 (536870912) - 128-bit encryption
          0x80000000 (2147483648) - 56-bit encryption
    #>
      {($setting -eq "NtlmMinClientSec") -or ($setting -eq "NtlmMinServerSec")} {
        $strMinSec = $null
        $mapNTLMSecurity.keys | foreach {
          $secNTLM = $mapNTLMSecurity[$_]
          if ($secNTLM -band $value) {
            if ($null -eq $strMinSec) {
              $strMinSec += "$($setting) : $($_) ($($secNTLM))"
              #$strConfig += "$($setting) : $($_) ($($secNTLM))"
            } elseif ($null -ne $strMinSec) {
              $strMinSec += " + $($_) ($($secNTLM))"
              #$strConfig += " + $($_) ($($secNTLM))"
            }
          }
        }
        $strConfig += "$($strMinSec)"
        break
      }
      "AuditReceivingNTLMTraffic" {
        #https://learn.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/network-security-restrict-ntlm-incoming-ntlm-traffic
        switch ($value) {
          0 {$strConfig += "$($setting) : $($value) (Disabled)"; break}
          1 {$strConfig += "$($setting) : $($value) (Audit All Domain Accounts)"; break}
          2 {$strConfig += "$($setting) : $($value) (Audit All Accounts)"; break}
        }
      }
      "RestrictReceivingNTLMtraffic" {
        #https://learn.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/network-security-restrict-ntlm-incoming-ntlm-traffic
        switch ($value) {
          0 {$strConfig += "$($setting) : $($value) (Allow All)"; break}
          1 {$strConfig += "$($setting) : $($value) (Deny All Domain Accounts)"; break}
          2 {$strConfig += "$($setting) : $($value) (Deny All Accounts)"; break}
        }
      }
      "RestrictSendingNTLMtraffic" {
        #https://learn.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/network-security-restrict-ntlm-incoming-ntlm-traffic
        switch ($value) {
          0 {$strConfig += "$($setting) : $($value) (Allow All)"; break}
          1 {$strConfig += "$($setting) : $($value) (Audit All)"; break}
          2 {$strConfig += "$($setting) : $($value) (Deny All)"; break}
        }
      }
    }
    #$strConfig += "`r`n$($script:strLineSeparator)`r`n"
    $script:diag += "$($strConfig)`r`n"
  }

  function StopClock {
    #Stop script execution time calculation
    $script:sw.Stop()
    $Days = $sw.Elapsed.Days
    $Hours = $sw.Elapsed.Hours
    $Minutes = $sw.Elapsed.Minutes
    $Seconds = $sw.Elapsed.Seconds
    $Milliseconds = $sw.Elapsed.Milliseconds
    $total = ((((($Hours * 60) + $Minutes) * 60) + $Seconds) * 1000) + $Milliseconds
    $mill = [string]($total / 1000)
    $mill = $mill.split(".")[1]
    $mill = $mill.SubString(0, [math]::min(3, $mill.length))
    $script:finish = (Get-Date).ToString('yyyy-MM-dd hh:mm:ss')
    $script:diag += "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
    write-output "Total Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
  }
#endregion ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
clear-host
#Start script execution time calculation
$ScrptStartTime = (Get-Date).ToString('yyyy-MM-dd hh:mm:ss')
$script:sw = [Diagnostics.Stopwatch]::StartNew()
try {
  $regPaths | foreach {$path = $_; $regValues | foreach {$value = $_;
    try {
      $NTLM = get-itempropertyvalue -path "$($path)" -name "$($value)" -erroraction silentlycontinue
      map-NTLMSecurity $value $NTLM
    } catch {
      #$err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
      #write-output $err
    }
  }}
  $warn = $null
  if (($null -eq $hashNTLM.LMCompatibilityLevel) -or ($hashNTLM.LMCompatibilityLevel -ne 3) -and ($hashNTLM.LMCompatibilityLevel -ne 5)) {
    #Set `LMCompatibilityLevel` to `NTLMv2 Only; Refuse LM / NTLMv1`
    $script:blnWARN = $true; $warn += "NTLMv1 Authentication Allowed`r`n"
    if ($blnFix -eq 'True') {write-NTLMSecurity "$($regPaths[0])" "LMCompatibilityLevel" 5}
  }
  if (($null -eq $hashNTLM.NtlmMinClientSec) -or ($hashNTLM.NtlmMinClientSec -band $mapNTLMSecurity.NTLMv1)) {
    #Set `NtlmMinClientSec` to `128-bit Session Security`
    $script:blnWARN = $true; $warn += "NTLMv1 Client Negotiation Allowed`r`n"
    if ($blnFix -eq 'True') {write-NTLMSecurity "$($regPaths[1])" "NtlmMinClientSec" 537395200}
  }
  if (($null -eq $hashNTLM.NtlmMinServerSec) -or ($hashNTLM.NtlmMinServerSec -band $mapNTLMSecurity.NTLMv1)) {
    #Set `NtlmMinServerSec` to `128-bit Session Security`
    $script:blnWARN = $true; $warn += "NTLMv1 Server Negotiation Allowed`r`n"
    if ($blnFix -eq 'True') {write-NTLMSecurity "$($regPaths[1])" "NtlmMinServerSec" 537395200}
  }
  if (($null -eq $hashNTLM.AuditReceivingNTLMTraffic) -or ($hashNTLM.AuditReceivingNTLMTraffic -ne 2)) {
    #Set `AuditReceivingNTLMTraffic` to `Audit All Accounts`
    $script:blnWARN = $true; $warn += "Not Auditing Received NTLM Traffic from All Accounts`r`n"
    if ($blnFix -eq 'True') {write-NTLMSecurity "$($regPaths[1])" "AuditReceivingNTLMTraffic" 2}
  }
  if (($null -eq $hashNTLM.RestrictSendingNTLMtraffic) -or ($hashNTLM.RestrictSendingNTLMtraffic -eq 0)) {
    $script:blnWARN = $true; $warn += "Sending of NTLM Traffic Remotely Allowed and not Audited`r`n"
    #Full Consequences currently unknown
    #Known Issues : 'Deny All' will prevent Outlook / Office authentication
    #Known Issues : Any 'Deny' settings can/will prevent Network Shares/SMB authentication
    #Set `RestrictSendingNTLMtraffic` to `Audit All`
    if ($blnFix -eq 'True') {write-NTLMSecurity "$($regPaths[1])" "RestrictSendingNTLMtraffic" 1}
  }
  if (($null -eq $hashNTLM.RestrictReceivingNTLMtraffic) -or ($hashNTLM.RestrictReceivingNTLMtraffic -eq 0)) {
    #$script:blnWARN = $true; 
    $warn += "Receiving of NTLM Traffic Remotely Allowed`r`n"
    #Full Consequences currently unknown - Likely Dangerous on a Domain / AD DC
    #if ($blnFix -eq 'True') {write-NTLMSecurity "$($regPaths[1])" "RestrictReceivingNTLMtraffic" 1}
  }
} catch {
  #$err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
  #write-output "$($err)"
}
$script:diag += "`r`n$($warn)`r`n"
#Stop script execution time calculation
StopClock
#DATTO RMM OUTPUT
if ($script:blnWARN) {
  if ($blnFix -eq 'False') {
    write-DRMMAlert "Monitor_NTLMv1 : UnHealthy - 'Fix' Not Applied : See Diagnostics : $($script:finish)"
  } elseif ($blnFix -eq 'True') {
    write-DRMMAlert "Monitor_NTLMv1 : UnHealthy - 'Fix' Applied : See Diagnostics : $($script:finish)"
  }
  write-DRMMDiag "$($script:diag)"
  exit 1
} elseif (-not ($script:blnWARN)) {
  write-DRMMAlert "Monitor_NTLMv1 : Healthy : $($script:finish)"
  write-DRMMDiag "$($script:diag)"
  exit 0
}
#END SCRIPT
#------------