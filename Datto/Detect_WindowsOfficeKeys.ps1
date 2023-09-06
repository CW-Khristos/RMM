<# ----- About: ----
This script was adapted from and based on the 'oldScript.vbs' VBS Script by 'Scripting Simon' for detecting Windows and Office Keys
'	Architect	: Scripting Simon
'	Name		: Detect Windows and Office keys
'	Description	: This component detects Windows and Office License keys and writes them into the Customfields 9 and 10
# Modifications: Christopher Bledsoe, Tier II Tech - IPM Computers
# Email: cbledsoe@ipmcomputers.com
# --------------#>  ## About

#BELOW PARAM() MUST BE COMMENTED OUT FOR USE WITHIN DATTO RMM
#UNCOMMENT BELOW PARAM() AND RENAME '$env:var' TO '$var' TO UTILIZE IN CLI
#Param(
#  [Parameter(Mandatory=$true)]$windowsUDF,
#  [Parameter(Mandatory=$true)]$officeUDF
#)

#region ----- DECLARATIONS ----
  $script:diag          = $null
  $script:blnWARN       = $false
  $script:blnBREAK      = $false
  $script:bitarch       = $null
  $script:OSCaption     = $null
  $script:OSVersion     = $null
  $script:producttype   = $null
  $script:computername  = $null
  $script:strBaseKey    = $null
  $script:blnOffice     = $false
  $intProductCount      = 0
  $officeUDF            = $env:officeUDF
  $windowsUDF           = $env:windowsUDF
  $strLineSeparator     = '-------------------'
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
  } ## write-DRRMAlert

  function Get-ProcessOutput {
    Param (
      [Parameter(Mandatory=$true)]$FileName,
      $Args
    )
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo.WindowStyle = "Normal"
    $process.StartInfo.CreateNoWindow = $false
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.RedirectStandardOutput = $true
    $process.StartInfo.RedirectStandardError = $true
    $process.StartInfo.FileName = $FileName
    if($Args) {$process.StartInfo.Arguments = $Args}
    $out = $process.Start()

    $StandardError = $process.StandardError.ReadToEnd()
    $StandardOutput = $process.StandardOutput.ReadToEnd()

    $output = New-Object PSObject
    $output | Add-Member -type NoteProperty -name StandardOutput -Value $StandardOutput
    $output | Add-Member -type NoteProperty -name StandardError -Value $StandardError
    return $output
  } ## Get-ProcessOutput

  function Get-OSArch {                                                                             #Determine Bit Architecture & OS Type
    #OS Bit Architecture
    $osarch = (get-wmiobject win32_operatingsystem).osarchitecture
    if ($osarch -like '*32*') {
      $script:bitarch = "bit32"
      $script:strBaseKey = "HKLM:\SOFTWARE"
    } elseif ($osarch -like '*64*') {
      $script:bitarch = "bit64"
      $script:strBaseKey = "HKLM:\SOFTWARE\Wow6432Node"
    }
    #OS Type & Version
    $script:computername = $env:computername
    $script:OSCaption = (Get-WmiObject Win32_OperatingSystem).Caption
    $script:OSVersion = (Get-WmiObject Win32_OperatingSystem).Version
    $osproduct = (Get-WmiObject -class Win32_OperatingSystem).Producttype
    Switch ($osproduct) {
      "1" {$script:producttype = "Workstation"}
      "2" {$script:producttype = "DC"}
      "3" {$script:producttype = "Server"}
    }
  } ## Get-OSArch

  function StopClock {
    #Stop script execution time calculation
    $script:sw.Stop()
    $Days = $sw.Elapsed.Days
    $Hours = $sw.Elapsed.Hours
    $Minutes = $sw.Elapsed.Minutes
    $Seconds = $sw.Elapsed.Seconds
    $Milliseconds = $sw.Elapsed.Milliseconds
    $ScriptStopTime = (get-date).ToString('yyyy-MM-dd hh:mm:ss')
    write-output "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds"
    $script:diag += "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
  }

  function logERR ($intSTG, $strModule, $strErr) {
    $script:blnWARN = $true
    $logTime = "$((get-date).ToString('yyyy-MM-dd hh:mm:ss'))"
    #CUSTOM ERROR CODES
    switch ($intSTG) {
      1 {                                                         #'ERRRET'=1 - NOT ENOUGH ARGUMENTS, END SCRIPT
        $script:blnBREAK = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($logTime) - WinKey - NO ARGUMENTS PASSED, END SCRIPT`r`n$($strLineSeparator)`r`n"
        write-output "$($strLineSeparator)`r`n$($logTime) - WinKey - NO ARGUMENTS PASSED, END SCRIPT`r`n$($strLineSeparator)`r`n"
      }
      2 {                                                         #'ERRRET'=2 - END SCRIPT
        $script:blnBREAK = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($logTime) - WinKey - ($($strModule)) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n$($strLineSeparator)`r`n"
        write-output "$($strLineSeparator)`r`n$($logTime) - WinKey - ($($strModule)) :"
        write-output "$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n$($strLineSeparator)`r`n"
      }
      3 {                                                         #'ERRRET'=3
        $script:blnWARN = $false
        $script:diag += "`r`n$($strLineSeparator)`r`n$($logTime) - WinKey - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)`r`n$($strLineSeparator)`r`n"
        write-output "$($strLineSeparator)`r`n$($logTime) - WinKey - $($strModule) :"
        write-output "$($strLineSeparator)`r`n`t$($strErr)`r`n$($strLineSeparator)`r`n"
      }
      default {                                                   #'ERRRET'=4+
        $script:blnBREAK = $false
        $script:diag += "`r`n$($strLineSeparator)`r`n$($logTime) - WinKey - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)`r`n$($strLineSeparator)`r`n"
        write-output "$($strLineSeparator)`r`n$($logTime) - WinKey - $($strModule) :"
        write-output "$($strLineSeparator)`r`n`t$($strErr)`r`n$($strLineSeparator)`r`n"
      }
    }
  }

  function BitShift ($strDirection, $intValue, $intShift) {
    switch ($strDirection) {
      "Left" {return ($intValue * ([Math]::Pow(2, $intShift)))}
      "Right" {return [int]($intValue / ([Math]::Pow(2, $intShift)))}
    }
  }

  function WriteData ($strProperty, $strValue) {
    try {
      $strPad = " " * 4
      logERR 3 "WriteData" "Recording Data : $($strProperty) : $($strPad)$($strValue)"
      if ($strProperty -eq "Windows Key") {
        $winKey = get-processoutput -filename "reg.exe" -args "add `"HKLM\Software\CentraStage`" /v `"Custom$($windowsUDF)`" /t REG_SZ /d `"$($strValue) (Windows)`" /f"
        logERR 3 "WriteData" "StandardOutput :`r`n`t$($strLineSeparator)`r`n`t$($winKey.StandardOutput)`t$($strLineSeparator)"
        logERR 3 "WriteData" "StandardError :`r`n`t$($strLineSeparator)`r`n`t$($winKey.StandardError)$($strLineSeparator)"
      } elseif ($strProperty -ne "Windows Key") {
        $offKey = get-processoutput -filename "reg.exe" -args "add `"HKLM\Software\CentraStage`" /v `"Custom$($officeUDF)`" /t REG_SZ /d `"$($strValue) (Office)`" /f"
        logERR 3 "WriteData" "StandardOutput :`r`n`t$($strLineSeparator)`r`n`t$($offKey.StandardOutput)`t$($strLineSeparator)"
        logERR 3 "WriteData" "StandardError :`r`n`t$($strLineSeparator)`r`n`t$($offKey.StandardError)$($strLineSeparator)"
      }
    } catch {
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
      logERR 2 "Reg Add" "Failed to Query Windows/Office Keys`r`n$($err)"
    }
  }

  function DecodeProductKey ($arrKey, $intKeyOffset) {
    $i = 24
    $strKeyOutput = $null
    $strChars = "BCDFGHJKMPQRTVWXY2346789"
    if ($arrKey -isnot [array]) {break}
    $intIsWin8 = (BitShift "Right" $arrKey[$intKeyOffset + 14] 3) -band 1
    $arrKey[$intKeyOffset + 14] = $arrKey[$intKeyOffset + 14] -band 247 -bor (BitShift "Left" ($intIsWin8 -band 2) 2)

    while ($i -gt -1) {
      $intX = 14
      $intCur = 0
      while ($intX -gt -1) {
        $intCur = BitShift "Left" $intCur 8
        #write-output "intCur (BSL) : $($intCur)"
        $intCur = $arrKey[$intX + $intKeyOffset] + $intCur
        #write-output "intCur (arrKey[intX + intKeyOffset] + intCur) : $($intCur)"
        $arrKey[$intX + $intKeyOffset] = [math]::Truncate($intCur / 24)
        #write-output "arrKey[intX + intKeyOffset] : $($arrKey[$intX + $intKeyOffset])"
        $intCur = $intCur % 24
        #write-output "intCur (Mod 24) : $($intCur)"
        $intX -= 1
      }
      #write-output "intCur : $($intCur)"
      $strKeyOutput = "$($strChars.substring($intCur, 1))$($strKeyOutput)"
      #write-output "strKeyOutput : $($strKeyOutput)"
      $intLast = $intCur
      $i -= 1
    }

    if ($intIsWin8 -eq 1) {
      <#
      write-output "strKeyOutput : $($strKeyOutput)"
      write-output "Length : $($strKeyOutput.length)"
      write-output "intLast : $($intLast + 1)"
      write-output "Chunk 1 (1, $($intLast)) : $($strKeyOutput.substring(1, $intLast))"
      write-output "Chunk 2 ($($strKeyOutput.length - ($intLast + 1)), $($strKeyOutput.length)) : $($strKeyOutput.substring(($intLast + 1), $($strKeyOutput.length - ($intLast + 1))))"
      #>
      $strKeyOutput = "$($strKeyOutput.substring(1, $intLast))N$($strKeyOutput.substring(($intLast + 1), $($strKeyOutput.length - ($intLast + 1))))"
    }
    #write-output "strKeyOutput : $($strKeyOutput)"
    $strKeyGUIDOutput = "$($strKeyOutput.substring(0, 5))-$($strKeyOutput.substring(5, 5))-$($strKeyOutput.substring(10, 5))-$($strKeyOutput.substring(15, 5))-$($strKeyOutput.substring(20, 5))"
    #write-output "strKeyGUIDOutput : $($strKeyGUIDOutput)"
    return $strKeyGUIDOutput
  }

  function QueryWindowsKeys {
    try {
      logERR 3 "QueryWindowsKeys" "Querying Windows Keys"
      $strWinKey = $(CheckWindowsKey "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" "DigitalProductId" 52)
      if (($null -ne $strWinKey) -and ($strWinKey -ne "")) {WriteData "Windows Key" $strWinKey; return;}
      
      $strWinKey = $(CheckWindowsKey "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" "DigitalProductId4" 808)
      if (($null -ne $strWinKey) -and ($strWinKey -ne "")) {WriteData "Windows Key" $strWinKey; return;}
      
      $strWinKey = $(CheckWindowsKey "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\DefaultProductKey" "DigitalProductId" 52)
      if (($null -ne $strWinKey) -and ($strWinKey -ne "")) {WriteData "Windows Key" $strWinKey; return;}
      
      $strWinKey = $(CheckWindowsKey "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\DefaultProductKey" "DigitalProductId4" 808)
      if (($null -ne $strWinKey) -and ($strWinKey -ne "")) {WriteData "Windows Key" $strWinKey; return;}
    } catch {
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
      logERR 3 "QueryWindowsKeys" "Failed to Query Windows Keys`r`n$($err)"
      return $null
    }
  }

  function CheckWindowsKey ($strRegPath, $strRegValue, $intKeyOffset) {
    try {
      logERR 3 "CheckWindowsKey" "Checking Windows Key : $($strRegPath)"
      $binRegVal = get-itempropertyvalue -path "$($strRegPath)" -name "$($strRegValue)"
      #write-output "Windows Key (Binary) : $($binRegVal)"
      $strWinKey = $(DecodeProductKey $binRegVal $intKeyOffset)
      if (($null -ne $strWinKey) -and ($strWinKey -ne "") -and ($strWinKey -ne "BBBBB-BBBBB-BBBBB-BBBBB-BBBBB")) {
        #write-output "Windows Key : $($strWinKey)"
        return $strWinKey
      } else {
        return $null
      }
    } catch {
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
      logERR 4 "CheckWindowsKey" "Failed to Check Windows Key`r`n$($err)"
      return $null
    }
  }

  function QueryOfficeKeys {
    try {
      $intProductCount = 1
      logERR 3 "QueryOfficeKeys" "Querying Office Keys : $($script:strBaseKey)\Microsoft\Office"
      $strOfficeKey = "$($script:strBaseKey)\Microsoft\Office"
      $officeKey = get-childitem "$($strOfficeKey)"
      foreach ($subKey in $officeKey) {
        switch ($subKey.name) {
          {$_.contains("11.0")} {CheckOfficeKey "$($strOfficeKey)\11.0\Registration" 52 $intProductCount}
          {$_.contains("12.0")} {CheckOfficeKey "$($strOfficeKey)\12.0\Registration" 52 $intProductCount}
          {$_.contains("14.0")} {CheckOfficeKey "$($strOfficeKey)\14.0\Registration" 808 $intProductCount}
          {$_.contains("15.0")} {CheckOfficeKey "$($strOfficeKey)\15.0\Registration" 808 $intProductCount}
          {$_.contains("16.0")} {CheckOfficeKey "$($strOfficeKey)\16.0\Registration" 808 $intProductCount}
        }
      }
      if (-not $script:blnOffice) {logERR 3 "QueryOfficeKeys" "No Office Registration Data"}
    } catch {
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
      logERR 3 "QueryOfficeKeys" "Failed to Query Office Keys`r`n$($err)"
    }
  }

  function CheckOfficeKey ($strRegPath, $intKeyOffset, $intProdCount) {
    try {
      logERR 3 "CheckOfficeKey" "Check Office Registration : $($strRegPath)"
      $regKey = get-childitem "$($strRegPath)" -erroraction silentlycontinue
      foreach ($subKey in $regKey) {
        try {
          $strOfficeEdition = get-itempropertyvalue -path "Registry::$($subKey)" -name "ConvertToEdition" -erroraction silentlycontinue
          $arrProductID = get-itempropertyvalue -path "Registry::$($subKey)" -name "DigitalProductID" -erroraction silentlycontinue
          if (($null -ne $strOfficeEdition) -and ($strOfficeEdition -ne "") -and ($arrProductID -is [array])) {
            logERR 3 "CheckOfficeKey" "Found : Office Product ($($intProductCount)) : $($strOfficeEdition)"
            $officeKey = $(DecodeProductKey $arrProductID $intKeyOffset)
            WriteData "Office Product ($($intProductCount))" $strOfficeEdition
            WriteData "Office Key ($($intProductCount))" "$($strOfficeEdition) : $($officeKey)"
            $script:blnOffice = $true
            $intProductCount += 1
          }
        } catch {
          $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
          logERR 3 "CheckOfficeKey" "Failed to Check Office Registration`r`n$($err)"
        }
      }
    } catch {
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
      logERR 3 "CheckOfficeKey" "Failed to Check Office Registration`r`n$($err)"
    }
  }
#endregion ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
clear-host
Get-OSArch
#Start script execution time calculation
$script:sw = [Diagnostics.Stopwatch]::StartNew()
$ScrptStartTime = (get-date).ToString('yyyy-MM-dd hh:mm:ss')

try {
  QueryOfficeKeys
  logERR 3 "WinKey" "Checking WMI for Windows Original Product Key"
  $prodKey = (Get-WmiObject -query 'select * from SoftwareLicensingService').OA3xOriginalProductKey
  if (-not $prodKey) {
    try {
      logERR 3 "WinKey" "Unable to locate Windows Original Product Key`r`n`tRunning legacy script..."
      <#
      $oldScript = get-processoutput -filename "cscript.exe" -args "/nologo .\oldScript.vbs $($windowsUDF) $($officeUDF)"
      logERR 3 "Legacy Script" "StandardOutput :`r`n`t$($strLineSeparator)`r`n`t$($oldScript.StandardOutput)`t$($strLineSeparator)"
      logERR 3 "Legacy Script" "StandardError :`r`n`t$($strLineSeparator)`r`n`t$($oldScript.StandardError)$($strLineSeparator)"
      #>
      QueryWindowsKeys
    } catch {
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
      logERR 2 "Legacy Script" "Failed to Query Windows/Office Keys`r`n$($err)"
    }
  } elseif ($prodKey) {
    try {
      logERR 3 "WinKey" "Windows Original Product Key found: $($prodKey)`r`n`tWritten to UDF$($windowsUDF)`r`n`t$($strLineSeparator)"
      WriteData "Windows Key" $($prodKey)
      <#
      $winKey = get-processoutput -filename "reg.exe" -args "add `"HKLM\Software\CentraStage`" /v `"Custom$($windowsUDF)`" /t REG_SZ /d `"$($prodKey) (Windows)`" /f"
      logERR 3 "Reg Add" "StandardOutput :`r`n`t$($strLineSeparator)`r`n`t$($winKey.StandardOutput)`t$($strLineSeparator)"
      logERR 3 "Reg Add" "StandardError :`r`n`t$($strLineSeparator)`r`n`t$($winKey.StandardError)$($strLineSeparator)"
      #>
    } catch {
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
      logERR 2 "WinKey" "Failed to Write Windows/Office Keys`r`n$($err)"
    }
  }
} catch {
  $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
  logERR 2 "WinKey" "Failed to Query Windows/Office Keys`r`n$($err)"
}
#Stop script execution time calculation
StopClock
$finish = "$((get-date).ToString('yyyy-MM-dd hh:mm:ss'))"
if (-not $script:blnBREAK) {
  if (-not $script:blnWARN) {
    write-DRMMAlert "WinKey : Keys Retrieved. See UDFs $($officeUDF) & $($windowsUDF) : $($finish)"
    write-DRMMDiag "$($script:diag)"
    exit 0
  } elseif ($script:blnWARN) {
    write-DRMMAlert "WinKey : Issues Found. Please Check Diagnostics : $($finish)"
    write-DRMMDiag "$($script:diag)"
    exit 1
  }
} elseif ($script:blnBREAK) {
  write-DRMMAlert "WinKey : Execution Failed : $($finish)"
  write-DRMMDiag "$($script:diag)"
  exit 1
}
#END SCRIPT
#------------