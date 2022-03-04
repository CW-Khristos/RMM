iCACLS "\\SF-SERVER\Scans_Test\%USERNAME%" /reset /T
iCACLS "\\SF-SERVER\Scans_Test\%USERNAME%" /inheritance:r /grant "%USERDOMAIN%\%USERNAME%":(OI)(CI)F /T /inheritance:r /grant:r "Administrators":(OI)(CI)F /T
