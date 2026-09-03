<#
.SYNOPSIS
    Installs the Markdown4DStudio example and registers it as the handler for
    Markdown files for the current user.

.DESCRIPTION
    Copies the Release/Win64 build (executable plus sk4d.dll for the FMX
    flavour) to a stable location outside the repository, then writes the
    per-user file associations under HKCU:

      - a ProgID (Markdown4D.md) with icon and open command
      - the extension default plus an OpenWithProgids entry
      - an Applications entry so the studio shows up in "Open with"
      - Capabilities and RegisteredApplications so it shows up in
        Settings > Apps > Default apps

    Nothing is written to HKLM, so no elevation is required. The previous
    default ProgID of every extension is kept in a *_Markdown4DBackup value
    and restored by -Uninstall.

    Windows may still show its own picker once: when a UserChoice already
    exists for an extension, that choice wins over the registration below and
    only the user can change it (Settings, or right-click > Open with > Always).

.PARAMETER Flavour
    Which studio to register, Fmx (default) or Vcl.

.PARAMETER Extensions
    Extensions to associate. Defaults to .md only.

.PARAMETER InstallRoot
    Target directory. Defaults to %LOCALAPPDATA%\Programs\Markdown4D Studio.

.PARAMETER SkipCopy
    Register the executable already present in InstallRoot without rebuilding
    the copy.

.PARAMETER Uninstall
    Remove the registration, restore the previous default ProgID and delete
    the installed copy.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\Install-Markdown4DStudio.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\Install-Markdown4DStudio.ps1 -Uninstall
#>

[CmdletBinding()]
param(
    [ValidateSet('Fmx', 'Vcl')]
    [string] $Flavour = 'Fmx',

    [string[]] $Extensions = @('.md'),

    [string] $InstallRoot = (Join-Path $env:LOCALAPPDATA 'Programs\Markdown4D Studio'),

    [switch] $SkipCopy,

    [switch] $Uninstall
)

$ErrorActionPreference = 'Stop'

$ProgId          = 'Markdown4D.md'
$AppName         = 'Markdown4D Studio'
$AppDescription  = 'Markdown editor with live preview, built on the Markdown4D component set.'
$BackupValueName = 'Markdown4DBackup'
$CapabilitiesKey = 'Software\Markdown4D Studio\Capabilities'

$Root = Split-Path -Parent $PSScriptRoot

if ($Flavour -eq 'Fmx') {
    $ProjectDir = Join-Path $Root 'Examples\Markdown4DStudioFMX'
    $ExeName    = 'Markdown4DStudioFMX.exe'
    $Payload    = @($ExeName, 'sk4d.dll')
}
else {
    $ProjectDir = Join-Path $Root 'Examples\Markdown4DStudioVCL'
    $ExeName    = 'Markdown4DStudioVCL.exe'
    $Payload    = @($ExeName)
}

$BuildDir     = Join-Path $ProjectDir 'Win64\Release'
$InstalledExe = Join-Path $InstallRoot $ExeName

function Set-RegistryDefault {
    param([string] $Path, [string] $Value)

    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }

    Set-ItemProperty -Path $Path -Name '(default)' -Value $Value
}

function Get-RegistryDefault {
    param([string] $Path)

    if (-not (Test-Path $Path)) {
        return $null
    }

    return (Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue).'(default)'
}

function Update-ShellAssociations {
    if (-not ([System.Management.Automation.PSTypeName]'Markdown4D.Shell').Type) {
        Add-Type -Namespace 'Markdown4D' -Name 'Shell' -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("shell32.dll")]
public static extern void SHChangeNotify(int eventId, uint flags, System.IntPtr item1, System.IntPtr item2);
'@
    }

    # SHCNE_ASSOCCHANGED with SHCNF_IDLIST: tells Explorer to drop its cached
    # icon and verb information for the changed extensions.
    [Markdown4D.Shell]::SHChangeNotify(0x08000000, 0x0000, [System.IntPtr]::Zero, [System.IntPtr]::Zero)
}

function Register-Studio {
    if (-not $SkipCopy) {
        if (-not (Test-Path (Join-Path $BuildDir $ExeName))) {
            throw "Build not found: $(Join-Path $BuildDir $ExeName). Build the $Flavour studio in Release/Win64 first."
        }

        if (-not (Test-Path $InstallRoot)) {
            New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null
        }

        foreach ($File in $Payload) {
            $Source = Join-Path $BuildDir $File
            if (-not (Test-Path $Source)) {
                throw "Missing build output: $Source"
            }

            Copy-Item -Path $Source -Destination $InstallRoot -Force
        }

        Write-Host "Installed $Flavour studio to $InstallRoot"
    }

    if (-not (Test-Path $InstalledExe)) {
        throw "Executable not found: $InstalledExe"
    }

    $Command = '"{0}" "%1"' -f $InstalledExe

    Set-RegistryDefault "HKCU:\Software\Classes\$ProgId" 'Markdown document'
    Set-ItemProperty -Path "HKCU:\Software\Classes\$ProgId" -Name 'FriendlyTypeName' -Value 'Markdown document'
    Set-RegistryDefault "HKCU:\Software\Classes\$ProgId\DefaultIcon" ('{0},0' -f $InstalledExe)
    Set-RegistryDefault "HKCU:\Software\Classes\$ProgId\shell\open" "Open with $AppName"
    Set-RegistryDefault "HKCU:\Software\Classes\$ProgId\shell\open\command" $Command

    # "Open with" list.
    $AppKey = "HKCU:\Software\Classes\Applications\$ExeName"
    Set-RegistryDefault "$AppKey\shell\open\command" $Command
    Set-ItemProperty -Path $AppKey -Name 'FriendlyAppName' -Value $AppName

    # Settings > Apps > Default apps.
    $Capabilities = "HKCU:\$CapabilitiesKey"
    if (-not (Test-Path $Capabilities)) {
        New-Item -Path $Capabilities -Force | Out-Null
    }

    Set-ItemProperty -Path $Capabilities -Name 'ApplicationName' -Value $AppName
    Set-ItemProperty -Path $Capabilities -Name 'ApplicationDescription' -Value $AppDescription
    Set-ItemProperty -Path $Capabilities -Name 'ApplicationIcon' -Value ('{0},0' -f $InstalledExe)

    if (-not (Test-Path 'HKCU:\Software\RegisteredApplications')) {
        New-Item -Path 'HKCU:\Software\RegisteredApplications' -Force | Out-Null
    }

    Set-ItemProperty -Path 'HKCU:\Software\RegisteredApplications' -Name $AppName -Value $CapabilitiesKey

    foreach ($Extension in $Extensions) {
        $ExtensionKey = "HKCU:\Software\Classes\$Extension"
        $Previous     = Get-RegistryDefault $ExtensionKey

        if ($Previous -and $Previous -ne $ProgId) {
            Set-ItemProperty -Path $ExtensionKey -Name $BackupValueName -Value $Previous
        }

        Set-RegistryDefault $ExtensionKey $ProgId

        $ProgIdsKey = "$ExtensionKey\OpenWithProgids"
        if (-not (Test-Path $ProgIdsKey)) {
            New-Item -Path $ProgIdsKey -Force | Out-Null
        }

        Set-ItemProperty -Path $ProgIdsKey -Name $ProgId -Value ''

        if (-not (Test-Path "$Capabilities\FileAssociations")) {
            New-Item -Path "$Capabilities\FileAssociations" -Force | Out-Null
        }

        Set-ItemProperty -Path "$Capabilities\FileAssociations" -Name $Extension -Value $ProgId

        if (-not (Test-Path "$AppKey\SupportedTypes")) {
            New-Item -Path "$AppKey\SupportedTypes" -Force | Out-Null
        }

        Set-ItemProperty -Path "$AppKey\SupportedTypes" -Name $Extension -Value ''

        $UserChoice = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$Extension\UserChoice"
        if (Test-Path $UserChoice) {
            $Chosen = (Get-ItemProperty -Path $UserChoice -ErrorAction SilentlyContinue).ProgId
            if ($Chosen -and $Chosen -ne $ProgId) {
                Write-Warning "$Extension has a UserChoice pointing at '$Chosen'. Windows honours that over this registration; change it once in Settings > Apps > Default apps."
            }
        }

        Write-Host "Associated $Extension with $ProgId"
    }

    Update-ShellAssociations
}

function Unregister-Studio {
    foreach ($Extension in $Extensions) {
        $ExtensionKey = "HKCU:\Software\Classes\$Extension"
        if (-not (Test-Path $ExtensionKey)) {
            continue
        }

        $Current = Get-RegistryDefault $ExtensionKey
        $Backup  = (Get-ItemProperty -Path $ExtensionKey -ErrorAction SilentlyContinue).$BackupValueName

        if ($Current -eq $ProgId) {
            if ($Backup) {
                Set-RegistryDefault $ExtensionKey $Backup
                Write-Host "Restored $Extension to $Backup"
            }
            else {
                Set-RegistryDefault $ExtensionKey ''
                Write-Host "Cleared the default ProgID of $Extension"
            }
        }

        Remove-ItemProperty -Path $ExtensionKey -Name $BackupValueName -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "$ExtensionKey\OpenWithProgids" -Name $ProgId -ErrorAction SilentlyContinue
    }

    Remove-Item -Path "HKCU:\Software\Classes\$ProgId" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "HKCU:\Software\Classes\Applications\$ExeName" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path 'HKCU:\Software\Markdown4D Studio' -Recurse -Force -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path 'HKCU:\Software\RegisteredApplications' -Name $AppName -ErrorAction SilentlyContinue

    if (Test-Path $InstallRoot) {
        Remove-Item -Path $InstallRoot -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Removed $InstallRoot"
    }

    Update-ShellAssociations
    Write-Host 'Unregistered the studio.'
}

if ($Uninstall) {
    Unregister-Studio
}
else {
    Register-Studio
    Write-Host ''
    Write-Host "Done. $ExeName now handles: $($Extensions -join ', ')"
}
