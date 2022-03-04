# https://gallery.technet.microsoft.com/scriptcenter/Speculation-Control-e36f0050/file/190138/1/SpeculationControl.zip
# Save the current execution policy so it can be reset
$SaveExecutionPolicy = Get-ExecutionPolicy
Set-ExecutionPolicy RemoteSigned -Scope Currentuser
CD "C:\temp\SpeculationControl"
Import-Module SpeculationControl.psd1
Import-Module SpeculationControl.psm1
Get-SpeculationControlSettings
# Reset the execution policy to the original state
Set-ExecutionPolicy $SaveExecutionPolicy -Scope Currentuser