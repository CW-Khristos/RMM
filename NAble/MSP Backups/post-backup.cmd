@echo off
set errorlevel=
cscript.exe //nologo "C:\IT\Scripts\msp_postbackup.vbs" > "C:\IT\Scripts\postbackup_vbsoutput.txt"
if %errorlevel% == 0 goto end

:fail
set /A interr=%errorlevel%+2147221504
set errorlevel=
echo %date% : %time% : POST-BACKUP.CMD FAIL : %interr% >> "C:\IT\Scripts\postbackup_cmdout.txt"
echo %interr%
exit %interr%

:end
set /A interr=%errorlevel%+2147221504
set errorlevel=
echo %date% : %time% : POST-BACKUP.CMD SUCCESS : %interr% >> "C:\IT\Scripts\postbackup_cmdout.txt"
exit 0