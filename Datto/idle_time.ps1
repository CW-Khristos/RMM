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



    
Write-Host ("Last input " + [PInvoke.Win32.UserInput]::LastInput)
Write-Host ("Idle for " + [PInvoke.Win32.UserInput]::IdleTime)
     
$Customfield = "Custom"+$ENV:UDFNumber
$IdleTime = [PInvoke.Win32.UserInput]::IdleTime
$Last = [PInvoke.Win32.UserInput]::LastInput
$LastStr = $Last.ToLocalTime().ToString("MM/dd/yyyy hh:mm tt")
$RegKey = ("Idle for " + $IdleTime.Days + " day(s), " + $IdleTime.Hours + " hour(s), " + $IdleTime.Minutes + " minute(s), " + $IdleTime.Seconds + " second(s).")

Write-Host ("Last user keyboard/mouse input: " + $LastStr)
Write-Host $RegKey
write-host $IdleTime
If ($idleTime -le [timespan]"00:00:05:00")
	{
		#New-ItemProperty "HKLM:\SOFTWARE\CentraStage" -Name $Customfield -PropertyType string -value "Active" -Force
	}
	Else
	{
		#New-ItemProperty "HKLM:\SOFTWARE\CentraStage" -Name $Customfield -PropertyType string -value $RegKey -Force
	}