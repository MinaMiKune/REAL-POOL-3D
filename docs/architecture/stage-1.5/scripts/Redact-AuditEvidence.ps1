#requires -Version 5.1
<#
.SYNOPSIS
Apply privacy-only redaction to retained stage 1.5.1 audit evidence.

.DESCRIPTION
This utility changes absolute-path text only. It does not alter check IDs,
statuses, exit codes, durations, commands, or numeric observations. It handles
both plain text and JSON-escaped Windows paths.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string[]]$EvidencePath
)

$rules = @(
    [pscustomobject]@{ Name = 'workspace'; Pattern = '(?i)\b[A-Z]:(?:\\+|/)KimiData(?:\\+|/)kimi(?:\\+|/)Workspaces(?:\\+|/)REAL-POOL-3D'; Replacement = '<WORKSPACE>' },
    [pscustomobject]@{ Name = 'daemon-home'; Pattern = '(?i)\b[A-Z]:(?:\\+|/)KimiData(?:\\+|/)daimon-share(?:\\+|/)daimon'; Replacement = '<KIMI_DAIMON_HOME>' },
    [pscustomobject]@{ Name = 'bundle-runtime'; Pattern = '(?i)\b[A-Z]:(?:\\+|/)KimiData(?:\\+|/)daimon-bundle(?:\\+|/)runtime'; Replacement = '<KIMI_BUNDLE_RUNTIME>' },
    [pscustomobject]@{ Name = 'client-runtime'; Pattern = '(?i)\b[A-Z]:(?:\\+|/)Kimi(?:\\+|/)resources(?:\\+|/)resources(?:\\+|/)runtime'; Replacement = '<KIMI_CLIENT_RUNTIME>' },
    [pscustomobject]@{ Name = 'user-profile'; Pattern = '(?i)\b[A-Z]:(?:\\+|/)Users(?:\\+|/)[^\\\s"/]+'; Replacement = '<USER_PROFILE>' },
    [pscustomobject]@{ Name = 'ruffle-home'; Pattern = '(?i)\b[A-Z]:(?:\\+|/)Ruffle(?=(?:\\+|/)|$)'; Replacement = '<RUFFLE_HOME>' },
    [pscustomobject]@{ Name = 'nodejs-home'; Pattern = '(?i)\b[A-Z]:(?:\\+|/)nodejs(?=(?:\\+|/)|$)'; Replacement = '<NODEJS_HOME>' },
    [pscustomobject]@{ Name = 'vscode-home'; Pattern = '(?i)\b[A-Z]:(?:\\+|/)VSCode(?=(?:\\+|/)|$)'; Replacement = '<VSCODE_HOME>' },
    [pscustomobject]@{ Name = 'gpu-device-uuid'; Pattern = '(?i)(deviceUUID\s*=\s*)[0-9a-f-]+'; Replacement = '$1<GPU_DEVICE_UUID>' },
    [pscustomobject]@{ Name = 'gpu-driver-uuid'; Pattern = '(?i)(driverUUID\s*=\s*)[0-9a-f-]+'; Replacement = '$1<GPU_DRIVER_UUID>' },
    [pscustomobject]@{ Name = 'gpu-device-luid'; Pattern = '(?i)(deviceLUID\s*=\s*)[0-9a-f-]+'; Replacement = '$1<GPU_DEVICE_LUID>' },
    [pscustomobject]@{ Name = 'uri-userinfo'; Pattern = '(?i)://[^\s/:@]+:[^\s/@]+@'; Replacement = '://<REDACTED>@' }
)

foreach ($path in $EvidencePath) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Write-Error "Evidence file not found: $path"
        continue
    }
    $resolved = (Resolve-Path -LiteralPath $path).Path
    $text = [IO.File]::ReadAllText($resolved)
    $total = 0
    $details = @()
    foreach ($rule in $rules) {
        $count = [regex]::Matches($text, $rule.Pattern).Count
        if ($count -gt 0) {
            $text = [regex]::Replace($text, $rule.Pattern, $rule.Replacement)
            $total += $count
            $details += "$($rule.Name)=$count"
        }
    }
    if ($total -gt 0) {
        [IO.File]::WriteAllText($resolved, $text, (New-Object System.Text.UTF8Encoding($false)))
    }
    Write-Output ("REDACTED file={0} replacements={1} rules={2}" -f (Split-Path -Leaf $resolved), $total, ($details -join ','))
}
