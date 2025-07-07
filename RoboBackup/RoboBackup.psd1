@{
    # Script module or binary module file associated with this manifest.
    RootModule        = 'RoboBackup.psm1'

    # Version number of this module.
    ModuleVersion     = '1.0.0'

    # ID used to uniquely identify this module
    GUID              = 'f1bda93a-f3c8-4d8e-9b9a-7a3d7b8e6f0c'

    # Author of this module
    Author            = 'kevinchatham'

    # Company or vendor of this module
    CompanyName       = 'kevinchatham'

    # Description of the functionality provided by this module
    Description       = 'A powerful and flexible PowerShell module for running and managing file backups using Robocopy.'

    # Functions to export from this module
    FunctionsToExport = @(
        'Invoke-RoboBackup'
    )
}
