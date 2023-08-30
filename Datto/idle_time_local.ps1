$script:diag        = $null
$strLineSerparator  = "----------"
$logTrigger         = "C:\IT\Log\Idle_Trigger"
# Get the MyInvocation variable at script level
# Can be done anywhere within a script
$ScriptInvocation   = (Get-Variable MyInvocation -Scope Script).Value
# Get the full path to the script
$ScriptPath         = $ScriptInvocation.MyCommand.Path

Add-Type @'
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;

namespace PInvoke.Win32 {
  public static class UserInput {
    [DllImport("user32.dll", SetLastError=false)]
    private static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);

    [StructLayout(LayoutKind.Sequential)]
    private struct LASTINPUTINFO {
      public uint cbSize;
      public int dwTime;
    }

    public static DateTime LastInput {
      get {
        DateTime bootTime = DateTime.UtcNow.AddMilliseconds(-Environment.TickCount);
        DateTime lastInput = bootTime.AddMilliseconds(LastInputTicks);
        return lastInput;
      }
    }

    public static TimeSpan IdleTime {
      get {
        return DateTime.UtcNow.Subtract(LastInput);
      }
    }

    public static int LastInputTicks {
      get {
        LASTINPUTINFO lii = new LASTINPUTINFO();
        lii.cbSize = (uint)Marshal.SizeOf(typeof(LASTINPUTINFO));
        GetLastInputInfo(ref lii);
        return lii.dwTime;
      }
    }
  }
}
'@

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

try {
  $idleScript = (get-content $ScriptPath)
  $idleScript | set-content "C:\IT\Scripts\idle_time.ps1" -force
  $idleTask = get-scheduledtask -taskname 'Idle Time' -erroraction silentlycontinue
  if (-not $idleTask) {
    $settings = New-ScheduledTaskSettingsSet
    #$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -RunLevel Highest
    $idleAction = new-scheduledtaskaction -execute 'powershell.exe' -argument '-executionpolicy bypass -file "C:\IT\Scripts\idle_time.ps1"'
    $idleTrigger = new-scheduledtasktrigger -Once -At 1am -RepetitionDuration  (New-TimeSpan -Days 1)  -RepetitionInterval  (New-TimeSpan -Minutes 5)
    $idleTask = Register-ScheduledTask -TaskName 'Idle Time' -RunLevel Highest -Trigger $idleTrigger -Action $idleAction -Settings $settings
    $idleTask | Set-ScheduledTask
  }

  $idle = ("Idle for " + [PInvoke.Win32.UserInput]::IdleTime)
  $last = ("Last input " + ([PInvoke.Win32.UserInput]::LastInput).ToLocalTime().ToString("MM/dd/yyyy hh:mm tt"))
  write-output "$($idle)`r`n$($strLineSerparator)`r`n$($last)"
  $script:diag += "$($idle)`r`n$($strLineSerparator)`r`n$($last)`r`n"
  
  $Customfield = "Custom$($ENV:UDFNumber)"
  $IdleTime = [PInvoke.Win32.UserInput]::IdleTime
  $LastStr = ([PInvoke.Win32.UserInput]::LastInput).ToLocalTime().ToString("MM/dd/yyyy hh:mm tt")
  $RegKey = ("Idle for $($IdleTime.Days) day(s), $($IdleTime.Hours) hour(s), $($IdleTime.Minutes) minute(s), $($IdleTime.Seconds) second(s)")
  New-ItemProperty "HKLM:\SOFTWARE\CentraStage" -Name "Custom" -PropertyType string -value "$($RegKey)" -Force

  #CLEAR LOGFILE
  $null | set-content $logTrigger -force
  #WRITE TO LOGFILE
  $idleMsg = "$($strLineSerparator)`r`n$($IdleTime)`r`n"
  $idleMsg += "$($strLineSerparator)`r`nLast user keyboard/mouse input: $($LastStr)`r`n"
  $idleMsg += "$($strLineSerparator)`r`n$($RegKey)`r`n"
  write-output "$($idleMsg)"
  $script:diag += "$($idleMsg)`r`n"
  "$($script:diag)" | add-content $logTask -force
  write-DRMMAlert "Last user input: $($LastStr) - Idle : $($IdleTime)"
  exit 0
} catch {
  #CLEAR LOGFILE
  $null | set-content $logTrigger -force
  #WRITE TO LOGFILE
  $err = "ERROR -`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n"
  write-output "$($err)"
  $script:diag += "$($err)`r`n"
  "$($script:diag)" | add-content $logTrigger -force
  write-DRMMAlert "ERROR - $($_.Exception)"
  exit 1
}
