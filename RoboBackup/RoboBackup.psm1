function Invoke-RoboBackup {
    <#
    .SYNOPSIS
    A flexible backup utility using Robocopy with an interactive menu and JSON-based job configuration.

    .DESCRIPTION
    Invoke-RoboBackup is a powerful wrapper for the Windows Robocopy tool. It can be run in several modes:
    - Interactive Mode: If run with no parameters, it provides a menu to run pre-defined jobs, all jobs, or a custom one-off backup.
    - Init Mode (-Init): Creates a new 'robobackup.json' configuration file in the specified directory.
    - Job Mode (-Job): Runs a single, specific backup job defined in the configuration file.
    - All Jobs Mode (-All): Runs all backup jobs defined in the configuration file sequentially.
    - Manual Mode (-Source, -Destination): Runs a one-off backup with the specified source and destination paths.

    The script automatically handles logging, log rotation, and provides clear success or failure messages.

    It locates the configuration file 'robobackup.json' by searching the following locations in order:
    1. The path specified by the -Config parameter.
    2. The current working directory.

    .PARAMETER Init
    A switch to create a new 'robobackup.json' configuration file.

    .PARAMETER Job
    The name of a specific backup job to run, as defined in the 'robobackup.json' file.

    .PARAMETER Source
    The source directory for a manual (one-off) backup. This parameter is used with -Destination.

    .PARAMETER Destination
    The destination directory for a manual (one-off) backup. This parameter is used with -Source.

    .PARAMETER Mirror
    A switch to perform a mirror backup, which makes the destination an exact copy of the source.
    If this switch is omitted for a manual backup, the backup will be additive (only copying new/changed files).
    For jobs defined in the config, this is controlled by the 'mirror' property.

    .PARAMETER All
    A switch to run all backup jobs defined in the 'robobackup.json' file sequentially.

    .PARAMETER Config
    Specifies the full path to a 'robobackup.json' file. If omitted, the script will search in the current directory.

    .PARAMETER Dry
    A switch to perform a dry run. This will simulate the backup operation, showing what would be copied or deleted, without making any actual changes.

    .PARAMETER Logs
    A switch to open the logs directory in Visual Studio Code (if available) or the default file explorer.

    .EXAMPLE
    PS C:\> Invoke-RoboBackup
    Launches the interactive menu to guide the user through backup options.
    .EXAMPLE
    PS C:\> Invoke-RoboBackup -Init
    Starts an interactive prompt to create a new configuration file.
    .EXAMPLE
    PS C:\> Invoke-RoboBackup -Job "My Documents"
    Runs the pre-defined backup job named "My Documents", using the 'mirror' setting from the config.
    .EXAMPLE
    PS C:\> Invoke-RoboBackup -All
    Runs all pre-defined backup jobs from the configuration file.
    .EXAMPLE
    PS C:\> Invoke-RoboBackup -Source "C:\Users\Me\Photos" -Destination "D:\Backups\Photos" -Mirror
    Performs a one-off MIRROR backup of the Photos folder.
    .EXAMPLE
    PS C:\> Invoke-RoboBackup -Source "C:\Users\Me\Photos" -Destination "D:\Backups\Photos"
    Performs a one-off ADDITIVE backup of the Photos folder (does not delete extra files in destination).
    .EXAMPLE
    PS C:\> Invoke-RoboBackup -Job "My Documents" -Dry
    Performs a dry run of the "My Documents" job to see what changes would be made.
    .EXAMPLE
    PS C:\> Invoke-RoboBackup -Logs
    Opens the log file directory.

    .LINK
    https://github.com/kevinchatham/backup.ps1
    #>
    [CmdletBinding(DefaultParameterSetName = 'Interactive')]
    param(
        [Parameter(ParameterSetName = 'Init', Mandatory = $true)]
        [switch]$Init,

        [Parameter(ParameterSetName = 'Job', Mandatory = $true)]
        [string]$Job,

        [Parameter(ParameterSetName = 'Manual', Mandatory = $true)]
        [string]$Source,

        [Parameter(ParameterSetName = 'Manual', Mandatory = $true)]
        [string]$Destination,

        [Parameter(ParameterSetName = 'Manual')]
        [switch]$Mirror,

        [Parameter(ParameterSetName = 'All', Mandatory = $true)]
        [switch]$All,

        [Parameter(ParameterSetName = 'Logs', Mandatory = $true)]
        [switch]$Logs,

        [Parameter()]
        [string]$Config,

        [Parameter()]
        [switch]$Dry
    )

    $OriginalLocation = Get-Location
    $LogDir = Join-Path $PSScriptRoot "logs"
    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir | Out-Null
    }
    $TranscriptLogFile = Join-Path $LogDir "session-$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log"
    Start-Transcript -Path $TranscriptLogFile -Append | Out-Null

    try {
        # Helper function to create a new configuration file.
        function New-Configuration {
            $SchemaPath = Join-Path $PSScriptRoot "robobackup.schema.json"
            if (-not (Test-Path $SchemaPath)) {
                Write-Error "Configuration schema 'robobackup.schema.json' not found in module directory."
                return
            }

            $DefaultPath = Join-Path (Get-Location) "robobackup.json"
            $TargetPath = Read-Host "Enter the full path to create robobackup.json (or press Enter for current dir)"
            if ([string]::IsNullOrWhiteSpace($TargetPath)) {
                $TargetPath = $DefaultPath
            }

            if (Test-Path $TargetPath) {
                $Overwrite = Read-Host "File '$TargetPath' already exists. Overwrite? [y/n]"
                if ($Overwrite -ne 'y') {
                    Write-Host "Configuration creation cancelled." -ForegroundColor Red
                    return
                }
            }

            Copy-Item -Path $SchemaPath -Destination $TargetPath -Force
            Write-Host "Successfully created configuration file at: $TargetPath" -ForegroundColor Green
        }
        
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
        function Start-BackupJob($SourcePath, $DestinationPath, $IsDryRun, $MirrorBackup) {
            Write-Host "---------------------------------------------" -ForegroundColor Cyan
            Write-Host "Starting Backup..."
            Write-Host "Source:      $SourcePath" -ForegroundColor White
            Write-Host "Destination: $DestinationPath" -ForegroundColor White
            if ($IsDryRun) {
                Write-Host "Mode:        Dry Run (No files will be changed)" -ForegroundColor Yellow
            }
            if ($MirrorBackup) {
                Write-Host "Type:        Mirror (Destination will match source exactly)" -ForegroundColor Magenta
            }
            else {
                Write-Host "Type:        Additive (New/changed files are copied)" -ForegroundColor Green
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
Mode:           $($IsDryRun ? 'Dry Run' : 'Live')
Type:           $($MirrorBackup ? 'Mirror' : 'Additive')
=============================================
"@
            $LogHeader | Out-File -FilePath $LogFile -Encoding utf8

            $RobocopyArgs = @($SourcePath, $DestinationPath, "/R:3", "/W:10", "/LOG+:$LogFile", "/TEE")
            if ($MirrorBackup) {
                $RobocopyArgs += "/MIR"
            }
            else {
                $RobocopyArgs += "/E"
            }
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
        if ($PSBoundParameters.ContainsKey('Init')) {
            New-Configuration
            return
        }

        $Jobs = [ordered]@{}
        $ConfigPath = $null

        # Config loading logic
        if ($PSBoundParameters.ContainsKey('Config')) {
            if (Test-Path $Config) { $ConfigPath = $Config }
            else { Write-Error "Config file not found at path: $Config"; return }
        }
        else {
            $CurrentDirConfig = Join-Path (Get-Location) "robobackup.json"
            if (Test-Path $CurrentDirConfig) { $ConfigPath = $CurrentDirConfig }
        }

        if ($ConfigPath) {
            if ($PsCmdlet.ParameterSetName -in @('Job', 'All', 'Interactive')) {
                Write-Host "Using configuration file: $ConfigPath"
            }

            $Jobs = @{}

            # This is the most robust method to parse a JSON file in PowerShell.
            # 1. Get-Content -Raw: Reads the entire file as a single string.
            # 2. ConvertFrom-Json -Depth 99: Parses the string, ensuring nested objects are handled.
            # 3. .jobs: Directly access the 'jobs' property, which is more reliable.
            $jobList = (Get-Content -Raw -Path $ConfigPath | ConvertFrom-Json -Depth 99).jobs

            if ($null -eq $jobList) {
                Write-Error "The configuration file '$ConfigPath' does not contain a 'jobs' array or is improperly formatted."
                return
            }

            # Use an [ordered] dictionary to preserve the job order from the JSON file.
            $Jobs = [ordered]@{}

            foreach ($jobObject in $jobList) {
                # In some PowerShell versions or environments, parsing the JSON objects can lead to odd null-like behavior
                # where property access via dot notation (e.g., $job.name) fails and returns an empty or null value,
                # even though the object appears to be populated correctly when inspected.
                # To ensure robust and reliable property access, we manually convert each PSCustomObject job into a Hashtable.
                # This avoids the parsing quirks and guarantees the script can read the job configuration.
                $jobHashtable = @{}
                $jobObject.PSObject.Properties | ForEach-Object {
                    $jobHashtable[$_.Name] = $_.Value
                }

                $jobName = $jobHashtable.name
                $jobSource = $jobHashtable.source
                $jobDestination = $jobHashtable.destination
                $jobMirror = $jobHashtable.mirror

                if ([string]::IsNullOrEmpty($jobName) -or `
                        [string]::IsNullOrEmpty($jobSource) -or `
                        [string]::IsNullOrEmpty($jobDestination) -or `
                        $null -eq $jobMirror) {
                    Write-Error "A job in '$ConfigPath' is missing a required property or has an empty value. Please check 'name', 'source', 'destination', and 'mirror'."
                    return
                }
                $Jobs[$jobName] = $jobHashtable
            }

            $ConfigDir = Split-Path -Path $ConfigPath -Parent
            if ($ConfigDir) { Set-Location -Path $ConfigDir }
        }
        
        # --- Parameter Handling ---
        switch ($PsCmdlet.ParameterSetName) {
            'Job' {
                if ($Jobs.Count -eq 0) { Write-Error "No configuration file found."; return }
                if (-not $Jobs.ContainsKey($Job)) { Write-Error "Job '$Job' not found."; return }
                $jobToRun = $Jobs[$Job]
                Start-BackupJob -SourcePath $jobToRun.source -DestinationPath $jobToRun.destination -IsDryRun:$Dry -MirrorBackup:$jobToRun.mirror
                return
            }
            'All' {
                if ($Jobs.Count -eq 0) { Write-Error "No configuration file found."; return }
                Write-Host "Running all pre-defined backup jobs." -ForegroundColor Yellow
                $Jobs.Values | ForEach-Object {
                    Start-BackupJob -SourcePath $_.source -DestinationPath $_.destination -IsDryRun:$Dry -MirrorBackup:$_.mirror
                }
                return
            }
            'Logs' {
                $LogDir = Join-Path $PSScriptRoot "logs"
                if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }
                $VSCodePath = Get-Command code -ErrorAction SilentlyContinue
                if ($null -ne $VSCodePath) { code $LogDir } else { explorer $LogDir }
                return
            }
        }

        # --- Execution for Manual mode ---
        if ($PsCmdlet.ParameterSetName -eq 'Manual') {
            Start-BackupJob -SourcePath $Source -DestinationPath $Destination -IsDryRun:$Dry -MirrorBackup:$Mirror.IsPresent
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
            $Source, $Destination, $isMirror, $All, $Dry = $null, $null, $null, $false, $false

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
                    $jobToRun = $Jobs[$jobName]
                    $Source = $jobToRun.source
                    $Destination = $jobToRun.destination
                    $isMirror = $jobToRun.mirror
                }
                '2' { $All = $true }
                '3' {
                    Show-Header
                    $Source = Read-Host "Enter the source path"
                    $Destination = Read-Host "Enter the destination path"
                    $mirrorSelection = Read-Host "Perform a mirror backup (deletes extra files at destination)? [y/n]"
                    $isMirror = $mirrorSelection -eq 'y'
                }
                '4' {
                    $LogDir = Join-Path $PSScriptRoot "logs"
                    if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir }
                    $VSCodePath = Get-Command code -ErrorAction SilentlyContinue
                    if ($null -ne $VSCodePath) { code $LogDir } else { explorer $LogDir }
                    Start-Sleep -Seconds 2
                    continue
                }
                '5' { Show-Header; Get-Help $MyInvocation.MyCommand -Full }
                '6' { return }
                default { Write-Warning "Invalid selection."; Start-Sleep -Seconds 2; continue }
            }

            if ($All) {
                Show-Header
                Write-Host "Running all pre-defined backup jobs." -ForegroundColor Yellow
                Write-Host
                $dryRunSelection = Read-Host "Perform a dry run (no files copied)? [y/n]"
                if ($dryRunSelection -eq 'y') { $Dry = $true }

                $Jobs.Values | ForEach-Object {
                    Start-BackupJob -SourcePath $_.source -DestinationPath $_.destination -IsDryRun:$Dry -MirrorBackup:$_.mirror
                }
            }
            elseif (-not ([string]::IsNullOrEmpty($Source))) {
                Show-Header
                Write-Host "Source:      $Source"
                Write-Host "Destination: $Destination"
                Write-Host "Mirror Mode: $($isMirror)" -ForegroundColor Yellow
                Write-Host
                $dryRunSelection = Read-Host "Perform a dry run (no files copied)? [y/n]"
                if ($dryRunSelection -eq 'y') { $Dry = $true }

                Write-Host
                $confirmation = Read-Host "Are you sure you want to proceed with the backup? [y/n]"
                if ($confirmation -ne 'y') { Write-Host "Backup cancelled." -ForegroundColor Red }
                else { Start-BackupJob -SourcePath $Source -DestinationPath $Destination -IsDryRun:$Dry -MirrorBackup:$isMirror }
            }

            Write-Host
            Read-Host "Press Enter to return to the main menu..."
        }
    }
    finally {
        Set-Location -Path $OriginalLocation
        Stop-Transcript | Out-Null
    }
}
