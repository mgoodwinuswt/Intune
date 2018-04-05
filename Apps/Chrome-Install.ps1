$Path = $env:TEMP
$Installer = "chrome_installer.exe"

Invoke-WebRequest "http://dl.google.com/chrome/install/375.126/chrome_installer.exe" -OutFile $Path\$Installer
Start-Process -FilePath $Path\$Installer -Args "/silent /install" -Wait
Remove-Item $Path\$Installer