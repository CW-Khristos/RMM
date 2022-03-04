@ECHO OFF
ECHO "Disabling Automatic Restart-Sign On for All Users"
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "DisableAutomaticRestartSignOn" /t REG_DWORD /d 1
ECHO "Done."