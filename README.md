# RoboBackup

A powerful and flexible PowerShell module for running and managing file backups using Robocopy. It provides a simple command-line interface and an interactive menu to streamline your backup process.

**Note on Compatibility:** This module is designed for the **Windows** operating system and works with both **Windows PowerShell 5.1** and **PowerShell Core (pwsh)**. It will **not** work on Linux or macOS because it fundamentally relies on `robocopy.exe`, a Windows-native command.

## Features

*   **Simple Installation**: A one-line command to install or update the module from GitHub.
*   **Cmdlet-Style Usage**: Run backups with a clear, verb-noun command: `Invoke-RoboBackup`.
*   **Interactive UI**: Run the command without any parameters to launch a colorful, user-friendly menu that guides you through the backup process.
*   **Configuration File**: Define all your regular backup tasks in a simple `robobackup.config.json` file for quick and repeatable execution.
*   **Detailed Logging**: Every backup operation creates a unique, timestamped log file in a dedicated `logs` directory.
*   **Automatic Log Rotation**: Keeps the 100 most recent log files and deletes older ones to save space.
*   **Dry Run Mode**: Simulate any backup operation without actually copying, moving, or deleting any files.

## Installation

To install the `RoboBackup` module, open a PowerShell terminal and run the following command. It will download and install the module into your user profile.

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/kevinchatham/backup.ps1/main/install.ps1'))
```
After installation, you may need to restart your PowerShell session or run `Import-Module RoboBackup` to make the command available.

## Setup

The script finds its configuration file, `robobackup.config.json`, in the following order:
1.  A path provided directly using the `-Config` parameter.
2.  In the current working directory (where you are running the command).
3.  In the module's installation directory (`~\Documents\PowerShell\Modules\RoboBackup`).

To get started:
1.  **Create Your Configuration**: Find the module's installation directory, make a copy of `robobackup.config.template.json`, and rename it to `robobackup.config.json`. You can place this file in the module directory itself or in any project folder from which you intend to run the command.
2.  **Define Your Backup Jobs**: Open `robobackup.config.json` and define your backup jobs. For example:

    ```json
    {
      "backupJobs": [
        {
          "name": "My Documents",
          "source": "C:\\Users\\YourUser\\Documents",
          "destination": "D:\\Backups\\Documents"
        },
        {
          "name": "Photos Archive",
          "source": "E:\\Photos",
          "destination": "\\\\MyNAS\\Backups\\Photos"
        }
      ]
    }
    ```

## Usage

All commands are run from a PowerShell terminal.

### Interactive Mode

For the most user-friendly experience, run the command with no parameters. It will present you with a menu to choose from the following options:
*   Run a single pre-defined job.
*   Run all pre-defined jobs sequentially.
*   Run a custom one-off backup.

```powershell
Invoke-RoboBackup
```

### Running a Pre-defined Job

To run a job that you have already defined in `robobackup.config.json`, use the `-Job` parameter.

```powershell
Invoke-RoboBackup -Job "My Documents"
```

### Running All Pre-defined Jobs

To run all jobs defined in `robobackup.config.json` sequentially, use the `-All` switch. The script will execute them in the order they appear in the file.

```powershell
Invoke-RoboBackup -All
```

### Manual (One-Off) Backup

To run a backup without saving it as a job, specify the source and destination paths directly. This mode does not require a `robobackup.config.json` file.

```powershell
Invoke-RoboBackup -Source "C:\Some\Folder" -Destination "D:\Some\BackupLocation"
```

### Using a Specific Configuration File

Use the `-Config` parameter to point to a specific `robobackup.config.json` file. This is useful for managing multiple, separate sets of backup jobs.

```powershell
Invoke-RoboBackup -Config "robobackup.config.json" -All
```

### Performing a Dry Run

To see what the script *would* do without making any changes, add the `-Dry` switch to any command.

```powershell
# Dry run of a single pre-defined job
Invoke-RoboBackup -Job "Photos Archive" -Dry

# Dry run of all pre-defined jobs
Invoke-RoboBackup -All -Dry

# Dry run of a manual backup
Invoke-RoboBackup -Source "C:\Some\Folder" -Destination "D:\Some\BackupLocation" -Dry
```

## Robocopy Exit Codes

The script provides a clear summary of the backup result based on the exit code from Robocopy.

| Code | Meaning                                                              |
| :--- | :------------------------------------------------------------------- |
| 0    | Success: No files were copied. Source and destination are identical. |
| 1    | Success: All files were copied successfully.                         |
| 2    | Success: Some extra files or directories were detected.              |
| 3    | Success: Files were copied and extra files were detected.            |
| 5    | Warning: Some files were mismatched and did not copy.                |
| 6    | Warning: Mismatched files and extra files were detected.             |
| 7    | Warning: Files were copied, but with some mismatches.                |
| 8+   | Error: Robocopy failed with critical errors. Check the log.          |

## Logging

All backup operations are logged in the `logs` directory within the module's installation path. Each log file is timestamped and contains a full report of the source, destination, options used, and the final result.

## Development and Local Testing

If you are developing the script and want to test your changes locally without installing the module system-wide, you can load it directly into your PowerShell session.

1.  **Open a PowerShell terminal** and navigate to the project's root directory.
2.  **Import the module file directly**:
    ```powershell
    Import-Module .\RoboBackup\RoboBackup.psm1
    ```
3.  **Run your test commands**. The `Invoke-RoboBackup` command will be available in your current session.
    ```powershell
    # Example: Test a manual backup with a dry run
    Invoke-RoboBackup -Source "C:\Some\Folder" -Destination "D:\BackupLocation" -Dry
    ```
4.  **Reload the module after making changes**: If you edit the `.psm1` file, you can reload it with the `-Force` parameter to see your changes.
    ```powershell
    Import-Module .\RoboBackup\RoboBackup.psm1 -Force
    ```
5.  **Unload the module** when you are finished testing:
    ```powershell
    Remove-Module RoboBackup
    ```
