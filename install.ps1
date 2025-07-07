# Installer for the RoboBackup PowerShell Module

$ModuleName = "RoboBackup"
$RepoOwner = "kevinchatham"
$RepoName = "backup.ps1" # Replace with your repository name

# Determine the user's module path
$DocumentsPath = [Environment]::GetFolderPath([System.Environment+SpecialFolder]::MyDocuments)
$ModulePath = Join-Path $DocumentsPath "PowerShell\Modules"
if (-not (Test-Path $ModulePath)) {
    New-Item -ItemType Directory -Path $ModulePath -Force
}
$InstallPath = Join-Path $ModulePath $ModuleName

# Remove any old version
if (Test-Path $InstallPath) {
    Write-Host "Removing existing version of $ModuleName..."
    Remove-Item -Recurse -Force $InstallPath
}

# Download the latest version from GitHub
$ZipUrl = "https://github.com/$RepoOwner/$RepoName/archive/refs/heads/main.zip"
$TempZip = Join-Path $env:TEMP "RoboBackup.zip"
Write-Host "Downloading $ModuleName from $ZipUrl..."
try {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $ZipUrl -OutFile $TempZip
} catch {
    Write-Error "Failed to download the module. Please check the URL and your internet connection."
    exit 1
}

# Unzip and install the module
$TempUnzip = Join-Path $env:TEMP "RoboBackup-Unzipped"
Expand-Archive -Path $TempZip -DestinationPath $TempUnzip -Force
$SourcePath = Join-Path $TempUnzip "$RepoName-main"

# Copy the entire module folder to the user's module path
Copy-Item -Path (Join-Path $SourcePath $ModuleName) -Destination $ModulePath -Recurse -Force

# Copy the license and readme into the new module folder
Copy-Item -Path (Join-Path $SourcePath "LICENSE") -Destination $InstallPath -Force
Copy-Item -Path (Join-Path $SourcePath "README.md") -Destination $InstallPath -Force

# Clean up temporary files
Remove-Item $TempZip -Force
Remove-Item $TempUnzip -Recurse -Force

Write-Host "$ModuleName has been successfully installed." -ForegroundColor Green
Write-Host "Run 'Import-Module $ModuleName' or restart your PowerShell session to use it."
