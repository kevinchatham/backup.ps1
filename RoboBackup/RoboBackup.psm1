function Invoke-RoboBackup {
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
            7 { return "Warning: Files were copied, but some were mismatched and extra files were detected." }
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
        } else {
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
        } else {
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
    $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
    $Jobs = [ordered]@{}
    $ConfigPath = $null

    # Config loading logic: 1. -Config param, 2. Current dir, 3. Module dir
    if ($PSBoundParameters.ContainsKey('Config')) {
        if (Test-Path $Config) {
            $ConfigPath = $Config
        } else {
            Write-Error "Config file not found at path specified with -Config: $Config"
            return
        }
    } else {
        $CurrentDirConfig = Join-Path (Get-Location) "robobackup.config.json"
        if (Test-Path $CurrentDirConfig) {
            $ConfigPath = $CurrentDirConfig
        } else {
            $ModulePathConfig = Join-Path $PSScriptRoot "robobackup.config.json"
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
    }

    # --- Execution for Job and Manual modes ---
    if ($PsCmdlet.ParameterSetName -in @('Job', 'Manual')) {
        Start-BackupJob -SourcePath $Source -DestinationPath $Destination -IsDryRun:$Dry
        return
    }

    # --- Interactive Mode ---
    Clear-Host
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "         Robocopy Backup Utility" -ForegroundColor White
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host

    if ($Jobs.Count -gt 0) {
        Write-Host "1. Run a single pre-defined job" -ForegroundColor Green
        Write-Host "2. Run all pre-defined jobs" -ForegroundColor Magenta
        Write-Host "3. Run a custom one-off backup" -ForegroundColor Yellow
        Write-Host "4. Exit" -ForegroundColor Red
        $mainSelection = Read-Host "Enter your choice [1-4]"
    } else {
        Write-Host "No config file loaded. You can only run a custom backup." -ForegroundColor Yellow
        $mainSelection = '3' # No jobs, so force custom backup
    }

    switch ($mainSelection) {
        '1' {
            $i = 1
            $Jobs.Keys | ForEach-Object { Write-Host "$i. $_" -ForegroundColor White; $i++ }
            $jobIndex = [int](Read-Host "Select a job") - 1
            $jobName = ($Jobs.Keys | Select-Object -Index $jobIndex)
            $Source = $Jobs[$jobName].source
            $Destination = $Jobs[$jobName].destination
        }
        '2' {
            $All = $true
        }
        '3' {
            $Source = Read-Host "Enter the source path"
            $Destination = Read-Host "Enter the destination path"
        }
        default {
            return
        }
    }

    if ($All) {
        Write-Host "Perform a dry run (no files copied)?" -ForegroundColor White
        $dryRunSelection = Read-Host "[y/n]"
        if ($dryRunSelection -eq 'y') { $Dry = $true }

        Write-Host "Running all pre-defined backup jobs." -ForegroundColor Yellow
        $Jobs.Values | ForEach-Object {
            Start-BackupJob -SourcePath $_.source -DestinationPath $_.destination -IsDryRun:$Dry
        }
    } elseif (-not ([string]::IsNullOrEmpty($Source))) {
        Write-Host "Perform a dry run (no files copied)?" -ForegroundColor White
        $dryRunSelection = Read-Host "[y/n]"
        if ($dryRunSelection -eq 'y') { $Dry = $true }

        $confirmation = Read-Host "Are you sure you want to proceed with the backup? [y/n]"
        if ($confirmation -ne 'y') {
            Write-Host "Backup cancelled." -ForegroundColor Red
            return
        }
        Start-BackupJob -SourcePath $Source -DestinationPath $Destination -IsDryRun:$Dry
    }
}
