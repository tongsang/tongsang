<#
.SYNOPSIS
    Installs or removes a desktop-idle shutdown monitor.

.DESCRIPTION
    The installed scheduled task starts at the current user's logon.  If the
    Windows desktop remains the foreground window for one hour, it schedules a
    shutdown with a 60-second cancellation window.  Bringing any other window
    to the foreground resets the one-hour timer.
#>

[CmdletBinding()]
param(
    [ValidateSet('Install', 'Uninstall')]
    [string]$Mode = 'Install',

    [ValidateRange(1, 1440)]
    [int]$TimeoutMinutes = 60,

    [switch]$Monitor
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$TaskName = 'DesktopIdleShutdown'
$InstallDirectory = Join-Path $env:ProgramData 'DesktopIdleShutdown'
$InstalledScript = Join-Path $InstallDirectory 'desktop-idle-monitor.ps1'

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Add-DesktopWindowInterop {
    if ('DesktopIdleShutdown.NativeMethods' -as [type]) {
        return
    }

    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace DesktopIdleShutdown {
    public static class NativeMethods {
        [DllImport("user32.dll")]
        public static extern IntPtr GetForegroundWindow();

        [DllImport("user32.dll")]
        public static extern IntPtr GetShellWindow();
    }
}
'@
}

function Start-DesktopMonitor {
    Add-DesktopWindowInterop

    $timeout = [TimeSpan]::FromMinutes($TimeoutMinutes)
    $desktopSince = $null

    while ($true) {
        $foreground = [DesktopIdleShutdown.NativeMethods]::GetForegroundWindow()
        $shellWindow = [DesktopIdleShutdown.NativeMethods]::GetShellWindow()

        # GetShellWindow is the actual desktop, unlike normal File Explorer windows.
        if ($foreground -eq $shellWindow) {
            if ($null -eq $desktopSince) {
                $desktopSince = Get-Date
            }

            if (((Get-Date) - $desktopSince) -ge $timeout) {
                shutdown.exe /s /t 60 /c "Windows desktop has been active for $TimeoutMinutes minutes. Run shutdown /a to cancel."
                break
            }
        }
        else {
            $desktopSince = $null
        }

        Start-Sleep -Seconds 5
    }
}

function Install-Monitor {
    if (-not (Test-Administrator)) {
        throw '请以管理员身份运行此脚本，或双击“配置桌面超时关机.cmd”。'
    }

    New-Item -ItemType Directory -Path $InstallDirectory -Force | Out-Null
    Copy-Item -LiteralPath $PSCommandPath -Destination $InstalledScript -Force

    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$InstalledScript`" -Monitor -TimeoutMinutes $TimeoutMinutes"
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $currentUser
    $principal = New-ScheduledTaskPrincipal -UserId $currentUser -LogonType Interactive -RunLevel Limited
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew

    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description 'Shuts down after the Windows desktop remains foreground for the configured duration.' -Force | Out-Null
    Start-ScheduledTask -TaskName $TaskName

    Write-Host "已启用：桌面连续停留 $TimeoutMinutes 分钟后，将在 60 秒倒计时后关机。"
    Write-Host '倒计时期间可运行 shutdown /a 取消本次关机。'
}

function Uninstall-Monitor {
    if (-not (Test-Administrator)) {
        throw '请以管理员身份运行此脚本，或双击“配置桌面超时关机.cmd”。'
    }

    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $InstallDirectory -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host '已移除桌面超时关机任务。'
}

if ($Monitor) {
    Start-DesktopMonitor
}
elseif ($Mode -eq 'Uninstall') {
    Uninstall-Monitor
}
else {
    Install-Monitor
}
