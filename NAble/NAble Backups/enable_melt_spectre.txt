::  It is recommended to test the script on a local machine for its purpose and effects. 
::  ManageEngine Desktop Central will not be responsible for any 
::  damage/loss to the data/setup based on the behavior of the script.

::  Description - Script to enable mitigations for Speculative execution side channel vulnerabilities 
::  Source - https://support.microsoft.com/sl-si/help/4072698/windows-server-guidance-to-protect-against-the-speculative-execution
::  Reboot Required - Yes
::  Configuration Type - Computer
::  ===========================================================================================================================

reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v FeatureSettingsOverride /t REG_DWORD /d 0 /f
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v FeatureSettingsOverrideMask /t REG_DWORD /d 3 /f
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Virtualization" /v MinVmVersionForCpuBasedMitigations /t REG_SZ /d "1.0" /f
echo Enabled Mitigations for Speculative execution side channel vulnerabilities 