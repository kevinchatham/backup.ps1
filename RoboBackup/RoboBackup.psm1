function Invoke-RoboBackup {
    <#
    .SYNOPSIS
    A flexible backup utility using Robocopy with an interactive menu and JSON-based job configuration.

    .DESCRIPTION
    Invoke-RoboBackup is a powerful wrapper for the Windows Robocopy tool. It can be run in several modes:
    - Interactive Mode: If run with no parameters, it provides a menu to run pre-defined jobs, all jobs, or a custom one-off backup.
    - Job Mode (-Job): Runs a single, specific backup job defined in the configuration file.
    - All Jobs Mode (-All): Runs all backup jobs defined in the configuration file sequentially.
    - Manual Mode (-Source, -Destination): Runs a one-off backup with the specified source and destination paths.

    The script automatically handles logging, log rotation, and provides clear success or failure messages.

    It locates the configuration file 'robobackup.json' by searching the following locations in order:
    1. The path specified by the -Config parameter.
    2. The current working directory.
    3. The script's own module directory.

    .PARAMETER Job
    The name of a specific backup job to run, as defined in the 'robobackup.json' file.

    .PARAMETER Source
    The source directory for a manual (one-off) backup. This parameter is used with -Destination.

    .PARAMETER Destination
    The destination directory for a manual (one-off) backup. This parameter is used with -Source.

    .PARAMETER All
    A switch to run all backup jobs defined in the 'robobackup.json' file sequentially.

    .PARAMETER Config
    Specifies the full path to a 'robobackup.json' file. If omitted, the script will search in the current directory and then the module directory.

    .PARAMETER Dry
    A switch to perform a dry run. This will simulate the backup operation, showing what would be copied or deleted, without making any actual changes.

    .PARAMETER Logs
    A switch to open the logs directory in Visual Studio Code (if available) or the default file explorer.

    .EXAMPLE
    PS C:\> Invoke-RoboBackup
    Launches the interactive menu to guide the user through backup options.
    .EXAMPLE
    PS C:\> Invoke-RoboBackup -Job "My Documents"
    Runs the pre-defined backup job named "My Documents".
    .EXAMPLE
    PS C:\> Invoke-RoboBackup -All
    Runs all pre-defined backup jobs from the configuration file.
    .EXAMPLE
    PS C:\> Invoke-RoboBackup -Source "C:\Users\Me\Photos" -Destination "D:\Backups\Photos"
    Performs a one-off backup of the Photos folder.
    .EXAMPLE
    PS C:\> Invoke-RoboBackup -Job "My Documents" -Dry
    Performs a dry run of the "My Documents" job to see what changes would be made.
    .EXAMPLE
    PS C:\> Invoke-RoboBackup -Config "C:\Temp\my-special-config.json" -All
    Runs all jobs defined in the specified configuration file.
    .EXAMPLE
    PS C:\> Invoke-RoboBackup -Logs
    Opens the log file directory.

    .LINK
    https://github.com/kevinchatham/backup.ps1
    #>
    [CmdletBinding(DefaultParameterSetName = 'Interactive')]
    param(
        [Parameter(ParameterSetName = 'Job', Mandatory = $true)]
        [string]$Job,

        [Parameter(ParameterSetName = 'Manual', Mandatory = $true)]
        [string]$Source,

        [Parameter(ParameterSetName = 'Manual', Mandatory = $true)]
        [string]$Destination,

        [Parameter(ParameterSetName = 'All', Mandatory = $true)]
        [switch]$All,

        [Parameter(ParameterSetName = 'Logs', Mandatory = $true)]
        [switch]$Logs,

        [Parameter()]
        [string]$Config,

        [Parameter()]
        [switch]$Dry
    )

    # Helper function to get a descriptive message for a Robocopy exit code.
    function Get-RobocopyExitMessage($exitCode) {
        switch ($exitCode) {
            0 { return "Success: No files were copied. Source and destination are identical." }
            1 { return "Success: All files were copied successfully." }
            2 { return "Success: Some extra files or directories were detected in the destination." }
            3 { return "Success: Files were copied and extra files were detected." }
            5 { return "Warning: Some files were mismatched and did not copy." }
            6 { return "Warning: Mismatched files and extra files were detected." }
            7 { return "Success: Files were copied, but some were mismatched and extra files were detected." }
            default { return "Error: Robocopy failed with critical errors (Code: $exitCode). Check the log for details." }
        }
    }

    # Core function to execute a single backup job.
    function Start-BackupJob($SourcePath, $DestinationPath, $IsDryRun) {
        Write-Host "---------------------------------------------" -ForegroundColor Cyan
        Write-Host "Starting Backup..."
        Write-Host "Source:      $SourcePath" -ForegroundColor White
        Write-Host "Destination: $DestinationPath" -ForegroundColor White
        if ($IsDryRun) {
            Write-Host "Mode:        Dry Run (No files will be copied)" -ForegroundColor Yellow
        }
        else {
            Write-Host "Mode:        Standard Backup" -ForegroundColor Green
        }
        Write-Host "---------------------------------------------" -ForegroundColor Cyan

        $LogDir = Join-Path $PSScriptRoot "logs"
        if (-not (Test-Path $LogDir)) {
            New-Item -ItemType Directory -Path $LogDir
        }

        $Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $LogFile = Join-Path $LogDir "log-$Timestamp.log"

        $LogHeader = @"
=============================================
        Robocopy Backup Log
=============================================
Start Time:     $Timestamp
Source:         $SourcePath
Destination:    $DestinationPath
Mode:           $($IsDryRun ? 'Dry Run' : 'Standard Backup')
=============================================
"@
        $LogHeader | Out-File -FilePath $LogFile -Encoding utf8

        $RobocopyArgs = @($SourcePath, $DestinationPath, "/MIR", "/E", "/R:3", "/W:10", "/LOG+:$LogFile", "/TEE")
        if ($IsDryRun) { $RobocopyArgs += "/L" }

        robocopy @RobocopyArgs
        $ExitCode = $LASTEXITCODE

        $ExitMessage = Get-RobocopyExitMessage $ExitCode
        $LogFooter = @"
=============================================
End Time:       $(Get-Date -Format "yyyy-MM-dd_HH-mm-ss")
Exit Code:      $ExitCode
Result:         $ExitMessage
=============================================
"@
        $LogFooter | Out-File -FilePath $LogFile -Encoding utf8 -Append

        if ($ExitCode -lt 8) {
            Write-Host $ExitMessage -ForegroundColor Green
        }
        else {
            Write-Host $ExitMessage -ForegroundColor Red
        }

        # Clean up old logs
        $LogFiles = Get-ChildItem -Path $LogDir -Filter "log-*.log" | Sort-Object CreationTime -Descending
        if ($LogFiles.Count -gt 100) {
            $LogsToDelete = $LogFiles | Select-Object -Skip 100
            $LogsToDelete | ForEach-Object { Remove-Item -Path $_.FullName }
            Write-Host "Removed $($LogsToDelete.Count) old log file(s)." -ForegroundColor Yellow
        }
        Write-Host "Backup job finished."
        Write-Host
    }

    # --- Main Script Logic ---
    $Jobs = [ordered]@{}
    $ConfigPath = $null

    # Config loading logic: 1. -Config param, 2. Current dir, 3. Module dir
    if ($PSBoundParameters.ContainsKey('Config')) {
        if (Test-Path $Config) {
            $ConfigPath = $Config
        }
        else {
            Write-Error "Config file not found at path specified with -Config: $Config"
            return
        }
    }
    else {
        $CurrentDirConfig = Join-Path (Get-Location) "robobackup.json"
        if (Test-Path $CurrentDirConfig) {
            $ConfigPath = $CurrentDirConfig
        }
        else {
            $ModulePathConfig = Join-Path $PSScriptRoot "robobackup.json"
            if (Test-Path $ModulePathConfig) {
                $ConfigPath = $ModulePathConfig
            }
        }
    }

    if ($ConfigPath) {
        $ConfigContent = Get-Content $ConfigPath | ConvertFrom-Json
        $ConfigContent.backupJobs.ForEach({ $Jobs[$_.name] = $_ })
    }

    # --- Parameter Handling ---
    switch ($PsCmdlet.ParameterSetName) {
        'Job' {
            if ($Jobs.Count -eq 0) {
                Write-Error "No configuration file found. Cannot run a named job."
                return
            }
            if (-not $Jobs.ContainsKey($Job)) {
                Write-Error "Job '$Job' not found in the configuration file."
                return
            }
            $Source = $Jobs[$Job].source
            $Destination = $Jobs[$Job].destination
        }
        'All' {
            if ($Jobs.Count -eq 0) {
                Write-Error "No configuration file found. Cannot run all jobs."
                return
            }
            Write-Host "Running all pre-defined backup jobs." -ForegroundColor Yellow
            $Jobs.Values | ForEach-Object {
                Start-BackupJob -SourcePath $_.source -DestinationPath $_.destination -IsDryRun:$Dry
            }
            return
        }
        'Logs' {
            $LogDir = Join-Path $PSScriptRoot "logs"
            if (-not (Test-Path $LogDir)) {
                New-Item -ItemType Directory -Path $LogDir | Out-Null
            }
            
            $VSCodePath = Get-Command code -ErrorAction SilentlyContinue
            if ($null -ne $VSCodePath) {
                code $LogDir
            } else {
                explorer $LogDir
            }
            return
        }
    }

    # --- Execution for Job and Manual modes ---
    if ($PsCmdlet.ParameterSetName -in @('Job', 'Manual')) {
        Start-BackupJob -SourcePath $Source -DestinationPath $Destination -IsDryRun:$Dry
        return
    }

    # --- Interactive Mode UI Functions ---
    function Show-Header {
        Clear-Host
        Write-Host "=============================================" -ForegroundColor Cyan
        Write-Host "              RoboBackup" -ForegroundColor White
        Write-Host "=============================================" -ForegroundColor Cyan
        Write-Host
    }

    # --- Interactive Mode ---
    while ($true) {
        Show-Header
        if ($Jobs.Count -gt 0) {
            Write-Host "1. Run a single pre-defined job" -ForegroundColor Green
            Write-Host "2. Run all pre-defined jobs" -ForegroundColor Magenta
            Write-Host "3. Run a custom one-off backup" -ForegroundColor Yellow
            Write-Host "4. Open Logs Directory" -ForegroundColor Cyan
            Write-Host "5. Help" -ForegroundColor Cyan
            Write-Host "6. Exit" -ForegroundColor Red
            Write-Host
            $mainSelection = Read-Host "Enter your choice [1-6]"
        }
        else {
            Write-Host "No robobackup.json file loaded." -ForegroundColor Yellow
            Write-Host "1. Run a custom one-off backup"
            Write-Host "2. Open Logs Directory"
            Write-Host "3. Help"
            Write-Host "4. Exit"
            Write-Host
            $customOnlySelection = Read-Host "Enter your choice [1-4]"
            switch ($customOnlySelection) {
                '1' { $mainSelection = '3' }
                '2' { $mainSelection = '4' }
                '3' { $mainSelection = '5' }
                '4' { $mainSelection = '6' }
            }
        }

        switch ($mainSelection) {
            '1' {
                Show-Header
                $i = 1
                $Jobs.Keys | ForEach-Object { Write-Host "$i. $_" -ForegroundColor White; $i++ }
                Write-Host
                $jobIndex = [int](Read-Host "Select a job") - 1
                $jobName = ($Jobs.Keys | Select-Object -Index $jobIndex)
                $Source = $Jobs[$jobName].source
                $Destination = $Jobs[$jobName].destination
            }
            '2' {
                $All = $true
            }
            '3' {
                Show-Header
                $Source = Read-Host "Enter the source path"
                $Destination = Read-Host "Enter the destination path"
            }
            '4' {
                $LogDir = Join-Path $PSScriptRoot "logs"
                if (-not (Test-Path $LogDir)) {
                    New-Item -ItemType Directory -Path $LogDir
                }
                
                $VSCodePath = Get-Command code -ErrorAction SilentlyContinue
                if ($null -ne $VSCodePath) {
                    Write-Host
                    Write-Host "Opening logs directory in Visual Studio Code..." -ForegroundColor Green
                    code $LogDir
                }
                else {
                    Write-Host
                    Write-Host "Opening logs directory in File Explorer..." -ForegroundColor Green
                    explorer $LogDir
                }
                Start-Sleep -Seconds 2
                continue
            }
            '5' {
                Show-Header
                Get-Help $MyInvocation.MyCommand -Full
            }
            '6' {
                return # Exit the function, thus ending the script
            }
            default {
                Write-Warning "Invalid selection. Please try again."
                Start-Sleep -Seconds 2
                continue # Skip the rest of the loop and restart
            }
        }

        if ($All) {
            Show-Header
            Write-Host "Running all pre-defined backup jobs." -ForegroundColor Yellow
            Write-Host
            $dryRunSelection = Read-Host "Perform a dry run (no files copied)? [y/n]"
            if ($dryRunSelection -eq 'y') { $Dry = $true }

            $Jobs.Values | ForEach-Object {
                Start-BackupJob -SourcePath $_.source -DestinationPath $_.destination -IsDryRun:$Dry
            }
        }
        elseif (-not ([string]::IsNullOrEmpty($Source))) {
            Show-Header
            Write-Host "Source:      $Source"
            Write-Host "Destination: $Destination"
            Write-Host
            $dryRunSelection = Read-Host "Perform a dry run (no files copied)? [y/n]"
            if ($dryRunSelection -eq 'y') { $Dry = $true }

            Write-Host
            $confirmation = Read-Host "Are you sure you want to proceed with the backup? [y/n]"
            if ($confirmation -ne 'y') {
                Write-Host "Backup cancelled." -ForegroundColor Red
            }
            else {
                Start-BackupJob -SourcePath $Source -DestinationPath $Destination -IsDryRun:$Dry
            }
        }

        Write-Host
        Read-Host "Press Enter to return to the main menu..."
        # Reset variables for the next loop iteration
        $Source = $null
        $Destination = $null
        $All = $false
        $Dry = $false
    }
}
