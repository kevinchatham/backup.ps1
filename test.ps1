Clear-Host
Set-Location -Path $PSScriptRoot
Import-Module .\RoboBackup\RoboBackup.psm1 -Force
Invoke-RoboBackup
