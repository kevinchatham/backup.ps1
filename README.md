<p align="center">
  <img src="./robobackup-logo.png" alt="robobackup-logo" width="150px" height="150px"/>
  <br/>
  <em>A simple, powerful backup utility for Windows.</em>
  <br/><br/>
  <a href="./LICENSE">
    <img src="https://img.shields.io/badge/license-MIT-blue" alt="MIT License"/>
  </a>
  <img src="https://img.shields.io/badge/PowerShell-5.1%2B%20%7C%20Core-blueviolet" alt="PowerShell Compatible"/>
</p>

`RoboBackup` is a PowerShell module for running configuration-driven file backups on Windows using `robocopy.exe`. It can be operated via a command-line interface or an interactive menu.

## Features

- 📦 **Simple Installation**: A one-line command to install the module.
- ⌨️ **Cmdlet-Style Usage**: Run backups with a clear, verb-noun command: `Invoke-RoboBackup`.
- 🎨 **Interactive UI**: A colorful, user-friendly menu to guide you through backups without memorizing parameters.
- 📄 **JSON Configuration**: Define all your regular backup jobs in a simple `robobackup.json` file.
- 📝 **Comprehensive Logging**: Every session is fully recorded, and each Robocopy operation creates a unique, timestamped log file.
- 🧹 **Automatic Log Rotation**: Keeps the 100 most recent log files and deletes older ones to save space.
- 💨 **Dry Run Mode**: Simulate any backup operation without actually copying, moving, or deleting files.

## Installation

To install the `RoboBackup` module, open a PowerShell terminal and run the following command. It will download and install the module into your user profile.

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/kevinchatham/backup.ps1/main/install.ps1'))
```

> **Note on Execution Policy**: The `Set-ExecutionPolicy Bypass` command ensures the installation script can run without being blocked. This setting only affects the current PowerShell session.

After installation, you may need to restart your PowerShell session or run `Import-Module RoboBackup` to make the command available.

### Manual Installation

For those who prefer not to run the installation script directly, you can perform a manual installation by following these steps:

1.  **Clone or Download the Repository**

    Clone the repository to your local machine using Git:

    ```bash
    git clone https://github.com/kevinchatham/backup.ps1.git
    ```

    Alternatively, you can [download the repository as a ZIP file](https://github.com/kevinchatham/backup.ps1/archive/refs/heads/main.zip) and extract it.

2.  **Copy the Module Directory**

    Copy the `RoboBackup` directory from the cloned repository into one of your PowerShell module directories. The most common user-specific location is:

    - `~\Documents\PowerShell\Modules\`

    You may need to create the `Modules` directory if it does not exist.

3.  **Verify the Installation**

    Open a new PowerShell terminal and run the following command to ensure the module is recognized:

    ```powershell
    Get-Module -ListAvailable -Name RoboBackup
    ```

## Configuration

The `Invoke-RoboBackup` command relies on a `robobackup.json` file to define your backup jobs. Each job in the configuration **must** have the following four properties:

-   `"name"`: A unique name to identify the job.
-   `"source"`: The directory to back up.
-   `"destination"`: The directory where the backup will be stored.
-   `"mirror"`: A boolean (`true` or `false`) to define the backup type.
    -   `true`: Performs a **mirror** backup (`/MIR`), which makes the destination an exact copy of the source. Any files in the destination that do not exist in the source will be **deleted**.
    -   `false`: Performs an **additive** backup (`/E`), which copies new and updated files without deleting extra files from the destination.

The script searches for this file in the following order of priority:
1.  A specific file path provided using the `-Config "C:\Path\to\robobackup.json"` parameter.
2.  A file named `robobackup.json` in the current working directory.
3.  A file named `robobackup.json` in the module's installation directory (`~\Documents\PowerShell\Modules\RoboBackup`).

When a configuration file is loaded, the script automatically changes its working directory to the directory containing the `robobackup.json` file. This ensures that any **relative paths** used in the `source` and `destination` fields are resolved correctly from the location of the configuration file, not from where the script was invoked. The original working directory is restored when the script finishes.

This design makes your backup configurations highly portable. By placing a `robobackup.json` file in the root of a project folder and using `.` as the `source`, you create a self-contained backup definition that travels with your files. To back up the entire folder, you just need to run `Invoke-RoboBackup` from within that folder.

### Getting Started

1.  **Download the Template**: Get the configuration template file, [`robobackup.template.json`](https://github.com/kevinchatham/backup.ps1/blob/main/robobackup.template.json), directly from the repository.
2.  **Rename and Place the File**: Rename it to `robobackup.json` and place it where you intend to run your backups.
3.  **Define Your Backup Jobs**: Open `robobackup.json` and define your jobs. You can use relative paths for portability.

        ```json
        {
          "jobs": [
            {
              "name": "Documents (Mirror)",
              "source": "C:\\Users\\Me\\Documents",
              "destination": "D:\\Backups\\Documents",
              "mirror": true
            },
            {
              "name": "Downloads (Additive)",
              "source": "C:\\Users\\Me\\Downloads",
              "destination": "D:\\Backups\\Downloads",
              "mirror": false
            }
          ]
        }
        ```

    In the example above, the "Documents" job will delete files from the backup if they are removed from the source, while the "Downloads" job will only add new files.

## Logging

`RoboBackup` creates two types of log files in the `RoboBackup/logs` directory:

1.  **Session Transcript**: A complete transcript of the entire script's execution is saved as `session-YYYY-MM-DD_HH-mm-ss.log`. This log captures all console output, including startup messages, configuration validation, and any errors that occur, making it ideal for debugging scheduled tasks.
2.  **Robocopy Log**: Each individual backup job generates a detailed `log-YYYY-MM-DD_HH-mm-ss.log` file containing the full output from the `robocopy.exe` command, including the list of copied files and the final summary.

## Usage

`Invoke-RoboBackup` can be run in different modes depending on the parameters you provide.

### Interactive Mode

For the most user-friendly experience, run the command with no parameters. This launches a persistent, menu-driven interface.

```powershell
Invoke-RoboBackup
```

From the main menu, you can:

- Run a single pre-defined job (respecting its `mirror` setting).
- Run all pre-defined jobs sequentially.
- Run a custom one-off backup, where you will be prompted to choose between a **mirror** or **additive** backup.
- Open the logs directory.
- Display the full command-line help.
- Exit the utility.

### Command-Line Usage

You can also run backups directly from the command line.

#### **Run a Pre-defined Job**

```powershell
Invoke-RoboBackup -Job "Documents (Mirror)"
```
This command runs the job as defined in the configuration, respecting its `mirror` property.

#### **Run All Pre-defined Jobs**

```powershell
Invoke-RoboBackup -All
```

#### **Perform a Manual (One-Off) Backup**

For manual backups, you can control the mirror behavior with the `-Mirror` switch.

-   **Mirror Backup** (Deletes extra files at destination):
    ```powershell
    Invoke-RoboBackup -Source "C:\Some\Folder" -Destination "D:\BackupLocation" -Mirror
    ```
-   **Additive Backup** (Default for manual, does not delete):
    ```powershell
    Invoke-RoboBackup -Source "C:\Some\Folder" -Destination "D:\BackupLocation"
    ```

#### **Perform a Dry Run**

Add the `-Dry` switch to any command to see what _would_ happen without changing any files.

```powershell
Invoke-RoboBackup -Job "Documents (Mirror)" -Dry
```

### Parameters

| Parameter               | Description                                                                  |
| :---------------------- | :--------------------------------------------------------------------------- |
| `-Job <string>`         | The name of a specific backup job to run from your `robobackup.json`.        |
| `-All`                  | A switch to run all backup jobs defined in your `robobackup.json`.           |
| `-Source <string>`      | The source directory for a manual (one-off) backup.                          |
| `-Destination <string>` | The destination directory for a manual (one-off) backup.                     |
| `-Mirror`               | A switch to perform a mirror backup for a manual job. If omitted, the backup is additive. |
| `-Config <string>`      | Specifies the full path to a `robobackup.json` file to use.                  |
| `-Dry`                  | A switch to perform a dry run, simulating the backup without making changes. |
| `-Logs`                 | A switch to open the logs directory in VS Code or File Explorer.             |

## Understanding Backup Results

The script provides a clear summary of the backup result based on the exit code from Robocopy.

| Code | Meaning                                                                                 |
| :--- | :-------------------------------------------------------------------------------------- |
| 0    | **Success**: No files were copied. Source and destination are identical.                |
| 1    | **Success**: All files were copied successfully.                                        |
| 2    | **Success**: Some extra files or directories were detected in the destination.          |
| 3    | **Success**: Files were copied and extra files were detected.                           |
| 5    | **Warning**: Some files were mismatched and did not copy.                               |
| 6    | **Warning**: Mismatched files and extra files were detected.                            |
| 7    | **Success**: Files were copied, but some were mismatched and extra files were detected. |
| 8+   | **Error**: Robocopy failed with critical errors. Check the log for details.             |

## Creating a Scheduled Backup Task

You can use Windows Task Scheduler to run your backups automatically. The following steps show how to create a task that runs all jobs from your configuration file on a daily basis.

1.  Open **Task Scheduler** from the Windows Start Menu.
2.  In the **Actions** pane, click **Create Task...**.

#### **General Tab**

- **Name**: Give the task a descriptive name (e.g., `RoboBackup Daily`).
- Select **Run whether user is logged on or not**.
- Check the box for **Run with highest privileges**.

#### **Triggers Tab**

- Click **New...**.
- Configure a schedule that suits your needs. For a daily backup, select **Daily** and set a start time (e.g., `2:00 AM`).

#### **Actions Tab**

- Click **New...**.
- **Action**: `Start a program`.
- **Program/script**: `pwsh.exe` (or `powershell.exe`)
- **Add arguments**: `-Command "& { Import-Module RoboBackup; Invoke-RoboBackup -All -Config 'C:\Path\To\Your\robobackup.json' }"`

> **Important**: Using the `-Config` parameter with an absolute path is the most reliable way to ensure the script can always find your configuration file when run via Task Scheduler. This avoids any ambiguity related to the "Start in" directory.

> **Note on PowerShell Version**: While this module works with both modern PowerShell (`pwsh.exe`) and the older Windows PowerShell (`powershell.exe`), using `pwsh.exe` is strongly recommended for better performance and future compatibility.

#### **Settings Tab**

- Review the default settings. You may want to adjust options like **Stop the task if it runs longer than:** or **Stop if the computer switches to battery power** to fit your needs.

5.  Click **OK** to save the task. You may be prompted to enter your user password.

Your automated backup task is now ready. It will run at the scheduled time without any manual intervention.

## Development and Local Testing

If you are developing the script and want to test your changes locally:

1.  **Open a PowerShell terminal** in the project's root directory.
2.  **Import the module file directly**:
    ```powershell
    Import-Module .\RoboBackup\RoboBackup.psm1 -Force
    ```
3.  **Run your test commands**:
    ```powershell
    Invoke-RoboBackup -Source "C:\Temp\Src" -Destination "C:\Temp\Dst" -Dry
    ```
4.  **Unload the module** when you are finished:
    ```powershell
    Remove-Module RoboBackup
    ```
