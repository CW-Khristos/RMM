<#
.SYNOPSIS 
    General cleanup script
    Cleanup various logfile paths
    Cleanup temporary file paths
    Removes NCentral remnants

.DESCRIPTION 
    Cleanup various logfile paths
    Cleanup temporary file paths
    Removes NCentral remnants
 
.NOTES
    Version        : 0.1.1 (01 December 2022)
    Creation Date  : 07 October 2022
    Purpose/Change : Provide Primary AV Product Status and Report Possible AV Conflicts
    File Name      : CClutter_0.1.1.ps1 
    Author         : Christopher Bledsoe - cbledsoe@ipmcomputers.com
    Requires       : PowerShell Version 2.0+ installed

.CHANGELOG
    0.1.0 Initial Release
    0.1.1 Added 'chkAU' automated update function

.TODO

#> 

#region ----- DECLARATIONS ----
  #BELOW PARAM() MUST BE COMMENTED OUT FOR USE WITHIN DATTO RMM
  #UNCOMMENT BELOW PARAM() AND RENAME '$env:var' TO '$var' TO UTILIZE IN CLI
  #Param (
  #  [Parameter(Mandatory=$false)]$blnLOG,
  #  [Parameter(Mandatory=$false)]$clrFOL
  #)
  #VERSION FOR SCRIPT UPDATE
  $strSCR           = "CClutter"
  $strVER           = [version]"0.1.1"
  $strREPO          = "RMM"
  $strBRCH          = "dev"
  $strDIR           = "Datto"
  #FILESIZE COUNTER
  $script:lngSIZ    = 0
  $script:diag      = $null
  $script:blnWARN   = $false
  $strLineSeparator = "---------"
  $logPath          = "C:\IT\Log\CCLUTTER"
  #ENVIRONMENT VARIABLES
  $strWFOL          = [System.Environment]::GetEnvironmentVariable('WINDIR','machine')
  $strUTFOL         = [System.Environment]::GetEnvironmentVariable('TEMP','user')
  $strSTFOL         = [System.Environment]::GetEnvironmentVariable('TEMP','machine')
  $strPDFOL         = [System.Environment]::GetEnvironmentVariable('PROGRAMDATA')
  $strPFFOL         = [System.Environment]::GetEnvironmentVariable('PROGRAMFILES')
  $str86FOL         = [System.Environment]::GetEnvironmentVariable('PROGRAMFILES(x86)')
  #COLLECTION OF FOLDERS TO CHECK
  #NCENTRAL FOLDERS TO REMOVE
  $arrSW            = [System.Collections.ArrayList]@(
    "$($strPDFOL)\GetSupportService_N-Central",
    "$($strPDFOL)\MspPlatform",
    "$($strPDFOL)\N-Able Technologies",
    "$($strPDFOL)\SolarWinds MSP",
    "$($str86FOL)\N-able Technologies",
    "$($str86FOL)\SolarWinds MSP",
    "$($strPFFOL)\SolarWinds MSP"
  )
  #THESE FOLDERS REQUIRE RETRIEVAL FROM ENVIRONMENTAL VARIABLES
  $arrFOL           = [System.Collections.ArrayList]@(
    #PROGRAMDATA
    "$($strUTFOL)",
    "$($strSTFOL)",
    "$($strWFOL)\Logs\CBS",
    "$($strWFOL)\SoftwareDistribution",
    "$($strPDFOL)\Sentinel\logs",
    "$($strPDFOL)\MXB\Backup Manager\logs",
    "$($strPDFOL)\GetSupportService\logs",
    "$($strPDFOL)\GetSupportService_N-Central\logs",
    "$($strPDFOL)\GetSupportService_N-Central\Updates",
    "$($strPDFOL)\MspPlatform\FileCacheServiceAgent\cache",
    "$($strPDFOL)\MspPlatform\FileCacheServiceAgent\log",
    "$($strPDFOL)\MspPlatform\PME\log",
    "$($strPDFOL)\MspPlatform\PME.Agent.PmeService\log",
    "$($strPDFOL)\MspPlatform\RequestHandlerAgent\log",
    "$($strPDFOL)\MspPlatform\SolarWinds.MSP.CacheService\log",
    "$($strPDFOL)\MspPlatform\SolarWinds.MSP.RpcServerService\log",
    "$($strPDFOL)\N-Able Technologies\AVDefender\Logs",
    "$($strPDFOL)\N-able Technologies\AutomationManager\Logs",
    "$($strPDFOL)\N-able Technologies\AutomationManager\temp",
    "$($strPDFOL)\N-able Technologies\AutomationManager\ScriptResults",
    "$($strPDFOL)\SolarWinds MSP\AutomationManager\Logs",
    "$($strPDFOL)\SolarWinds MSP\Ecosystem Agent\log",
    "$($strPDFOL)\SolarWinds MSP\PME\log",
    "$($strPDFOL)\SolarWinds MSP\SolarWinds.MSP.Diagnostics\Logs",
    "$($strPDFOL)\SolarWinds MSP\SolarWinds.MSP.CacheService\log",
    "$($strPDFOL)\SolarWinds MSP\SolarWinds.MSP.PME.Agent.PmeService\log",
    "$($strPDFOL)\SolarWinds MSP\SolarWinds.MSP.RpcServerService\log",
    #PROGRAM FILES
    "$($strPFFOL)\SolarWinds MSP",
    #PROGRAM FILES (X86)
    "$($str86FOL)\N-able Technologies\Reactive\Log",
    "$($str86FOL)\N-able Technologies\Tools\Log",
    "$($str86FOL)\N-able Technologies\Windows Agent\Log",
    "$($str86FOL)\N-able Technologies\Windows Software Probe\Log",
    "$($str86FOL)\N-able Technologies\Windows Software Probe\syslog\Log",
    "$($str86FOL)\SolarWinds MSP",
    #THESE FOLDERS ARE NORMAL FOLDER PATHS
    "C:\temp",
    "C:\inetpub\logs\LogFiles\W3SVC2",
    "C:\inetpub\logs\LogFiles\W3SVC1"
  )
  #EXCHANGE LOGGING FOLDERS
  if (test-path -path "$($strPFFOL)\Microsoft\Exchange Server") {
    $arrFOL.add("$($strPFFOL)\Microsoft\Exchange Server\V15\Logging\Diagnostics\AnalyzerLogs")
    $arrFOL.add("$($strPFFOL)\Microsoft\Exchange Server\V15\Logging\Diagnostics\CertificateLogs")
    $arrFOL.add("$($strPFFOL)\Microsoft\Exchange Server\V15\Logging\Diagnostics\CosmosLog")
    $arrFOL.add("$($strPFFOL)\Microsoft\Exchange Server\V15\Logging\Diagnostics\DailyPerformanceLogs")
    $arrFOL.add("$($strPFFOL)\Microsoft\Exchange Server\V15\Logging\Diagnostics\Dumps")
    $arrFOL.add("$($strPFFOL)\Microsoft\Exchange Server\V15\Logging\Diagnostics\EtwTraces")
    $arrFOL.add("$($strPFFOL)\Microsoft\Exchange Server\V15\Logging\Diagnostics\Poison")
    $arrFOL.add("$($strPFFOL)\Microsoft\Exchange Server\V15\Logging\Diagnostics\ServiceLogs")
    $arrFOL.add("$($strPFFOL)\Microsoft\Exchange Server\V15\Logging\Diagnostics\Watermarks")
    $arrFOL.add("$($strPFFOL)\Microsoft\Exchange Server\V15\Logging\MailboxAssistantsLog")
    $arrFOL.add("$($strPFFOL)\Microsoft\Exchange Server\V15\Logging\MailboxAssociationLog")
    $arrFOL.add("$($strPFFOL)\Microsoft\Exchange Server\V15\Logging\MigrationMonitorLogs")
    $arrFOL.add("$($strPFFOL)\Microsoft\Exchange Server\V15\Logging\RpcHttp\W3SVC1")
    $arrFOL.add("$($strPFFOL)\Microsoft\Exchange Server\V15\Logging\RpcHttp\W3SVC2")
    $arrFOL.add("$($strPFFOL)\Microsoft\Exchange Server\V15\Logging\HttpProxy\RpcHttp")
  }
#endregion ----- DECLARATIONS ----

#region ----- FUNCTIONS ----
  function write-DRMMDiag ($messages) {
    write-host  "<-Start Diagnostic->"
    foreach ($message in $messages) {$message}
    write-host "<-End Diagnostic->"
  } ## write-DRMMDiag
  
  function write-DRRMAlert ($message) {
    write-host "<-Start Result->"
    write-host "Alert=$($message)"
    write-host "<-End Result->"
  } ## write-DRRMAlert

  function Get-ProcessOutput {
    Param (
      [Parameter(Mandatory=$true)]$FileName,
      $Args
    )
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo.WindowStyle = "Hidden"
    $process.StartInfo.CreateNoWindow = $true
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

  function logERR($intSTG, $strErr) {
    $script:blnWARN = $true
    #CUSTOM ERROR CODES
    switch ($intSTG) {
      1 {                                                                             #'ERRRET'=1 - ERROR DELETING FILE / FOLDER
        $script:diag += "$($strLineSeparator)`r`n$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - CCLUTTER - ERROR DELETING FILE / FOLDER`r`n$($strErr)`r`n$($strLineSeparator)`r`n`r`n"
        write-host "$($strLineSeparator)`r`n$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - CCLUTTER - ERROR DELETING FILE / FOLDER`r`n$($strErr)`r`n$($strLineSeparator)`r`n"
      }
      2 {                                                                             #'ERRRET'=2 - NOT ENOUGH ARGUMENTS, END SCRIPT
        $script:diag += "$($strLineSeparator)`r`n$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - CCLUTTER - NO ARGUMENTS PASSED, END SCRIPT`r`n$($strErr)`r`n$($strLineSeparator)`r`n`r`n"
        write-host "$($strLineSeparator)`r`n$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - CCLUTTER - NO ARGUMENTS PASSED, END SCRIPT`r`n$($strErr)`r`n$($strLineSeparator)`r`n"
      }
    }
  }
  
  function cFolder ($objFOL) {                                                        #FUNCTION TO CLEAR CONTENTS OF FOLDER
    #SUB-ROUTINE IS RECURSIVE, WILL CLEAR FOLDER AND SUB-FOLDERS!
    #DELETE FILES
    $colFIL = get-childitem -path "$($objFOL)" | where {(-not $_.psiscontainer)}
    foreach ($objFIL in $colFIL) {                                                    #ENUMERATE EACH FILE
      try {
        $strFIL = $objFil.fullname
        $filSIZ = [math]::round(((get-item $objFIL.fullname -erroraction stop).length / 1MB), 2)
        $script:lngSIZ = $script:lngSIZ + $filSIZ
        remove-item -path "$($strFIL)" -force
        #SUCCESSFULLY DELETED FILE
        $script:diag += "`t`t - DELETED FILE : $($strFIL) : $($filSIZ)`r`n"
        write-host "`t`t - DELETED FILE : $($strFIL) : $($filSIZ)"
      } catch {
        #ERROR ENCOUNTERED DELETING FILE
        logERR 1 "ERROR DELETING : $($strFIL)`r`n$($strLineSeparator)`r`n`t - $($_.Exception)`r`n`t - $($_.scriptstacktrace)`r`n`t - $($_)"
      }
    }
    #EMPTY AND DELETE SUB-FOLDERS
    $colFOL = get-childitem -path "$($objFOL)" | where {$_.psiscontainer}
    foreach ($subFOL in $colFOL) {                                                    #ENUMERATE EACH SUB-FOLDER
      try {
        $strFOL = $subFOL.fullname
        #CLEAR CONTENTS OF FOLDER
        $script:diag += "`t`t - CLIEARING FOLDER : $($strFOL)`r`n"
        write-host "`t`t - CLEARING FOLDER : $($strFOL)"
        cFolder "$($strFOL)"
        remove-item -path "$($strFOL)\" -recurse -force -erroraction stop
        #SUCCESSFULLY DELETED FOLDER
        $script:diag += "`t`t - REMOVED FOLDER : $($strFOL)`r`n"
        write-host "`t`t - REMOVED FOLDER : $($strFOL)"
      } catch {                                                                       #ENCOUNTERED ERROR TRYING TO DELETE FOLDER
        logERR 1 "ERROR DELETING : $($strFOL)`r`n$($strLineSeparator)`r`n`t - $($_.Exception)`r`n`t - $($_.scriptstacktrace)`r`n`t - $($_)"
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
    $mill = [string]($total / 1000)
    $mill = $mill.split(".")[1]
    $mill = $mill.SubString(0,[math]::min(3,$mill.length))
    $script:diag += "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
    write-host "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
  }

  function chkAU {
    param (
      $ver, $repo, $brch, $dir, $scr
    )
    $blnXML = $true
    $xmldiag = $null
    #RETRIEVE AV VENDOR XML FROM GITHUB
    if (($null -eq $strDIR) -or ($strDIR -eq "")) {
      $xmldiag += "Loading : '$($strREPO)/$($strBRCH)' Version XML`r`n"
      write-host "Loading : '$($strREPO)/$($strBRCH)' Version XML" -foregroundcolor yellow
      $srcVER = "https://raw.githubusercontent.com/CW-Khristos/$($strREPO)/$($strBRCH)/version.xml"
    } elseif (($null -ne $strDIR) -and ($strDIR -ne "")) {
      $xmldiag += "Loading : '$($strREPO)/$($strBRCH)/$($strDIR)' Version XML`r`n"
      write-host "Loading : '$($strREPO)/$($strBRCH)/$($strDIR)' Version XML" -foregroundcolor yellow
      $srcVER = "https://raw.githubusercontent.com/CW-Khristos/$($strREPO)/$($strBRCH)/$($strDIR)/version.xml"
    }
    try {
      $verXML = New-Object System.Xml.XmlDocument
      $verXML.Load($srcVER)
    } catch {
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
      $xmldiag += "XML.Load() - Could not open $($srcVER)`r`n$($err)`r`n"
      write-host "XML.Load() - Could not open $($srcVER)`r`n$($err)" -foregroundcolor red
      try {
        $web = new-object system.net.webclient
        [xml]$verXML = $web.DownloadString($srcVER)
      } catch {
        $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
        $xmldiag += "Web.DownloadString() - Could not download $($srcVER)`r`n$($err)`r`n"
        write-host "Web.DownloadString() - Could not download $($srcVER)`r`n$($err)" -foregroundcolor red
        try {
          start-bitstransfer -erroraction stop -source $srcVER -destination "C:\IT\Scripts\version.xml"
          [xml]$verXML = "C:\IT\Scripts\version.xml"
        } catch {
          $blnXML = $false
          $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
          $xmldiag += "BITS.Transfer() - Could not download $($srcVER)`r`n$($err)`r`n"
          write-host "BITS.Transfer() - Could not download $($srcVER)`r`n$($err)`r`n" -foregroundcolor red
        }
      }
    }
    #READ PRIMARY AV PRODUCT VENDOR XML DATA INTO NESTED HASHTABLE FOR LATER USE
    try {
      if (-not $blnXML) {
        write-host $blnXML
      } elseif ($blnXML) {
        foreach ($objSCR in $verXML.SCRIPTS.ChildNodes) {
          if ($objSCR.name -match $strSCR) {
            #CHECK LATEST VERSION
            $xmldiag += "`r`n`t - CHKAU : $($strVER) : GitHub - $($strBRCH) : $($objSCR.innertext)`r`n"
            write-host "`t - CHKAU : $($strVER) : GitHub - $($strBRCH) : $($objSCR.innertext)`r`n"
            if ([version]$objSCR.text -gt $strVER) {
              $xmldiag += "`t - UPDATING : $($objSCR.name) : $($objSCR.innertext)`r`n"
              write-host "`t - UPDATING : $($objSCR.name) : $($objSCR.innertext)`r`n"
              #DOWNLOAD LATEST VERSION OF ORIGINAL SCRIPT
              if (($null -eq $strDIR) -or ($strDIR -eq "")) {
                $strURL = "https://raw.githubusercontent.com/CW-Khristos/scripts/$($strREPO)/$($strBRCH)/$($strSCR)_$($objSCR.innertext).ps1"
              } elseif (($null -ne $strDIR) -and ($strDIR -ne "")) {
                $strURL = "https://raw.githubusercontent.com/CW-Khristos/scripts/$($strREPO)/$($strBRCH)/$($strDIR)/$($strSCR)_$($objSCR.innertext).ps1"
              }
              Invoke-WebRequest "$($strURL)" | Select-Object -ExpandProperty Content | Out-File "C:\IT\Scripts\$($strSCR)_$($objSCR.innertext).ps1"
              #RE-EXECUTE LATEST VERSION OF SCRIPT
              $output = Get-ProcessOutput -filename "powershell.exe" -args "-executionpolicy bypass -file C:\IT\Scripts\$($strSCR)_$($objSCR.innertext).ps1"
              $script:diag += "`t`t - StdOut : $($output.standardoutput)`r`n`t`t - StdErr : $($output.standarderror)`r`n$($strLineSeparator)`r`n"
              write-host "`t`t - StdOut : $($output.standardoutput)`r`n`t`t - StdErr : $($output.standarderror)`r`n$($strLineSeparator)"
            }
            break
          }
        }
      }
      $script:diag += "$($xmldiag)"
      $xmldiag = $null
    } catch {
      $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
      $xmldiag += "AV Health : Error reading AV XML : $($srcVER)`r`n$($err)`r`n"
      write-host "AV Health : Error reading AV XML : $($srcVER)`r`n$($err)`r`n"
      $script:diag += "$($xmldiag)"
      $xmldiag = $null
    }
  } ## chkAU
#endregion ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
clear-host
#Start script execution time calculation
$ScrptStartTime = (Get-Date).ToString('dd-MM-yyyy hh:mm:ss')
$script:sw = [Diagnostics.Stopwatch]::StartNew()
$script:diag += "$($strLineSeparator)`r`n$($ScrptStartTime) - EXECUTING CCLUTTER`r`n$($strLineSeparator)`r`n"
write-host "$($strLineSeparator)`r`n$($ScrptStartTime) - EXECUTING CCLUTTER`r`n$($strLineSeparator)"
#CHECK FOR UPDATE
chkAU $strVER $strREPO $strBRCH $strDIR $strSCR
#REMOVE PREVIOUS LOGFILE
if (test-path -path "$($logPath)") {
  remove-item -path "$($logPath)" -force
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
#USE ICACLS TO 'RESET' PERMISSIONS ON C:\WINDOWS\TEMP
$script:diag += "`t - ATTEMPTING TO RESET PERMISSIONS ON 'C:\WINDOWS\TEMP'`r`n"
write-host "`t - ATTEMPTING TO RESET PERMISSIONS ON 'C:\WINDOWS\TEMP'"
$output = get-processoutput -filename "C:\Windows\System32\cmd.exe" -args "/C icacls C:\Windows\Temp /grant administrators:f"
$script:diag += "`t`t - StdOut : $($output.standardoutput)`r`n`t`t - StdErr : $($output.standarderror)`r`n$($strLineSeparator)`r`n"
write-host "`t`t - StdOut : $($output.standardoutput)`r`n`t`t - StdErr : $($output.standarderror)`r`n$($strLineSeparator)"
#USE ICACLS TO 'RESET' PERMISSIONS ON C:\PROGRAMDATA\SENTINEL\LOGS
$script:diag += "`t - ATTEMPTING TO RESET PERMISSIONS ON 'C:\PROGRAMDATA\SENTINEL\LOGS'`r`n"
write-host "`t - ATTEMPTING TO RESET PERMISSIONS ON 'C:\PROGRAMDATA\SENTINEL\LOGS'"
$output = get-processoutput -filename "C:\Windows\System32\cmd.exe" -args "/C icacls C:\ProgramData\Sentinel\logs /grant administrators:f"
$script:diag += "`t`t - StdOut : $($output.standardoutput)`r`n`t`t - StdErr : $($output.standarderror)`r`n$($strLineSeparator)`r`n"
write-host "`t`t - StdOut : $($output.standardoutput)`r`n`t`t - StdErr : $($output.standarderror)`r`n$($strLineSeparator)"
#ENUMERATE THROUGH FOLDER COLLECTION
foreach ($tgtFOL in $arrFOL) {
  if (($null -ne $tgtFOL) -and ($tgtFOL -ne "")) {                                #ENSURE $TGTFOL IS NOT EMPTY
    if (test-path -path "$($tgtFOL)") {                                           #ENSURE FOLDER EXISTS BEFORE CLEARING
      #CLEAR NORMAL FOLDERS
      if ($tgtFOL -ne "$($strWFOL)\SoftwareDistribution") {
        $script:diag += "`t - CLEARING : $($tgtFOL)`r`n"
        write-host "`t - CLEARING : $($tgtFOL)"
        #CLEAR CONTENTS OF FOLDER
        cFolder "$($tgtFOL)"
      #CLEARING WINDOWS UPDATES
      } elseif ($tgtFOL -eq "$($strWFOL)\SoftwareDistribution") {
        #CHECK FOR 'PENDING.XML IF CLEARING SOFTWAREDISTRIBUTION
        if (test-path -path "$($strWFOL)\WinSxS\pending.xml") {
          $script:diag += "`t - 'PENDING.XML' FOUND : SKIPPING : $($tgtFOL)`r`n"
          write-host "`t - 'PENDING.XML' FOUND : SKIPPING : $($tgtFOL)"
        } elseif (-not (test-path -path "$($strWFOL)\WinSxS\pending.xml")) {
          $script:diag += "`t - 'PENDING.XML' NOT FOUND : CLEARING : $($tgtFOL)`r`n"
          write-host "`t - 'PENDING.XML' NOT FOUND : CLEARING : $($tgtFOL)"
          #STOP WINDOWS UPDATE SERVICE TO CLEAR WINDOWS UPDATE FOLDER
          $script:diag += "`t - STOPPING 'WUAUSERV' SERVICE TO CLEAR 'SOFTWAREDISTRIBUTION'`r`n"
          write-host "`t - STOPPING 'WUAUSERV' SERVICE TO CLEAR 'SOFTWAREDISTRIBUTION'"
          $output = get-processoutput -filename "C:\Windows\System32\cmd.exe" -args "/C net stop wuauserv /y"
          $script:diag += "`t`t - StdOut : $($output.standardoutput)`r`n`t`t - StdErr : $($output.standarderror)`r`n"
          write-host "`t`t - StdOut : $($output.standardoutput)`r`n`t`t - StdErr : $($output.standarderror)"
          #CLEAR CONTENTS OF FOLDER
          cFolder "$($tgtFOL)"
          #RESTART WINDOWS UPDATE SERVICE
          $script:diag += "`t - RESTARTING 'WUAUSERV' SERVICE`r`n"
          write-host "`t - RESTARTING 'WUAUSERV' SERVICE"
          $output = get-processoutput -filename "C:\Windows\System32\cmd.exe" -args "/C net start wuauserv"
          $script:diag += "`t`t - StdOut : $($output.standardoutput)`r`n`t`t - StdErr : $($output.standarderror)`r`n"
          write-host "`t`t - StdOut : $($output.standardoutput)`r`n`t`t - StdErr : $($output.standarderror)"
        }
      }
    } else {                                                                      #NON-EXISTENT FOLDER
      $script:diag += "`t - NON-EXISTENT : $($tgtFOL)`r`n"
      write-host "`t - NON-EXISTENT : $($tgtFOL)"
    }
  }
}
#FINAL CLEANUP OF NCENTRAL PROGRAM LOGS
$script:diag += "`t - FINAL CLEANUP : `r`n"
write-host "`t - FINAL CLEANUP : "
$script:diag += "`t - LOOKING FOR '*.BDINSTALL.BIN' FILES`r`n"
write-host "`t - LOOKING FOR '*.BDINSTALL.BIN' FILES"
$output = get-processoutput -filename "C:\Windows\System32\cmd.exe" -args "/C DIR `"C:\ProgramData\*.bdinstall.bin`""
$script:diag += "`t`t - StdOut : $($output.standardoutput)`r`n`t`t - StdErr : $($output.standarderror)`r`n"
write-host "`t`t - StdOut : $($output.standardoutput)`r`n`t`t - StdErr : $($output.standarderror)"
$script:diag += "`t - REMOVING '*.BDINSTALL.BIN' FILES`r`n"
write-host "`t - REMOVING '*.BDINSTALL.BIN' FILES"
$output = get-processoutput -filename "C:\Windows\System32\cmd.exe" -args "/C DEL /S /Q `"C:\ProgramData\*.bdinstall.bin`""
$script:diag += "`t`t - StdOut : $($output.standardoutput)`r`n`t`t - StdErr : $($output.standarderror)`r`n"
write-host "`t`t - StdOut : $($output.standardoutput)`r`n`t`t - StdErr : $($output.standarderror)"
#REMOVE NCENTRAL REMNANTS
foreach ($tgtFOL in $arrSW) {
  if (test-path -path "$($tgtFOL)") {
      try {
        $script:diag += "`t - CLEARING : $($tgtFOL)`r`n"
        write-host "`t - CLEARING : $($tgtFOL)"
        #CLEAR CONTENTS OF FOLDER
        cFolder "$($tgtFOL)"
      } catch {
        logERR 1 "ERROR DELETING : $($strFOL)`r`n$($strLineSeparator)`r`n`t - $($_.Exception)`r`n`t - $($_.scriptstacktrace)`r`n`t - $($_)"
      }
      try {
        $script:diag += "`t - REMOVING : $($tgtFOL)`r`n"
        write-host "`t - REMOVING : $($tgtFOL)"
        remove-item -path "$($tgtFOL)\" -recurse -force
      } catch {
        logERR 1 "ERROR DELETING : $($strFOL)`r`n$($strLineSeparator)`r`n`t - $($_.Exception)`r`n`t - $($_.scriptstacktrace)`r`n`t - $($_)"
      }
  }
}
#ENUMERATE THROUGH PASSED FOLDER PATH
if (($null -ne $env:clrFOL) -and ($env:clrFOL -ne "")) {
  if (test-path -path "$($env:clrFOL)" ) {                                            #ENSURE FOLDER EXISTS BEFORE CLEARING
    $script:diag += "`t - CLEARING : $($env:clrFOL)`r`n"
    write-host "`t - CLEARING : $($env:clrFOL)"
    #CLEAR CONTENTS OF FOLDER
    cFolder "$($env:clrFOL)"
  } else {                                                                        #NON-EXISTENT FOLDER
    $script:diag += "`t - NON-EXISTENT : $($env:clrFOL)`r`n"
    write-host "`t - NON-EXISTENT : $($env:clrFOL)"
  }
}
$script:diag += "$($strLineSeparator)`r`n$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss')) - CCLUTTER COMPLETE - $($script:lngSIZ)MB CLEARED`r`n$($strLineSeparator)`r`n"
write-host "$($strLineSeparator)`r`n$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss')) - CCLUTTER COMPLETE - $($script:lngSIZ)MB CLEARED`r`n$($strLineSeparator)"
#Stop script execution time calculation
StopClock
#WRITE LOGFILE
if ($env:blnLOG) {
  $script:diag | out-file $logPath
}
#DATTO OUTPUT
if ($script:blnWARN) {
  write-DRRMAlert "CCLUTTER : Execution Completed with Warnings : See Diagnostics"
  write-DRMMDiag "$($script:diag)"
  exit 1
} elseif (-not $script:blnWARN) {
  write-DRRMAlert "CCLUTTER : Completed Execution"
  write-DRMMDiag "$($script:diag)"
  exit 0
}
#END SCRIPT
#------------