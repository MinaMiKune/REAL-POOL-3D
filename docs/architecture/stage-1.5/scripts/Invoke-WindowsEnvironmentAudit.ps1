#requires -Version 5.1
<#
.SYNOPSIS
Read-only Windows development-host audit for REAL-POOL-3D stage 1.5.1.

.DESCRIPTION
Does not install software, change persistent configuration, create a Godot
project, or invoke Godot directly. Run from the repository root. The only
intended write is the JSON report specified by OutputPath.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$GodotBrokerScript,

    [string]$OutputPath = "docs/architecture/stage-1.5/results/environment-audit.json"
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$OutputEncoding = [Console]::OutputEncoding

$Workspace = (Get-Location).Path
if (-not [IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = [IO.Path]::GetFullPath((Join-Path $Workspace $OutputPath))
}
$outputDirectory = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}

$script:Checks = @()
$script:VolumeData = @()
$script:OsData = $null
$script:CpuData = @()
$script:MemoryData = $null
$script:GpuData = @()
$script:SdkRoots = @()

$redactions = New-Object System.Collections.Generic.List[object]
function Add-Redaction([string]$Value, [string]$Replacement) {
    if (-not [string]::IsNullOrWhiteSpace($Value) -and $Value.Length -ge 3) {
        $redactions.Add([pscustomobject]@{ Value = $Value; Replacement = $Replacement })
    }
}
Add-Redaction $Workspace "<WORKSPACE>"
Add-Redaction $GodotBrokerScript "<GODOT_BROKER>"
Add-Redaction $env:USERPROFILE "<USER_PROFILE>"
Add-Redaction $env:LOCALAPPDATA "<LOCAL_APPDATA>"
Add-Redaction $env:APPDATA "<ROAMING_APPDATA>"
Add-Redaction $env:COMPUTERNAME "<COMPUTER_NAME>"
Add-Redaction $env:USERNAME "<USER_NAME>"
$normalizedBroker = $GodotBrokerScript.Replace('/', '\')
if ($normalizedBroker -match '^(.*\\runtime)(?:\\|$)') {
    Add-Redaction $Matches[1] "<KIMI_RUNTIME>"
}

function Protect-Text([AllowNull()][AllowEmptyString()][string]$Text) {
    if ($null -eq $Text) { return $null }
    $result = $Text
    foreach ($item in $redactions) {
        $result = [regex]::Replace(
            $result,
            [regex]::Escape($item.Value),
            $item.Replacement,
            [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
        )
    }
    $result = [regex]::Replace($result, '(?i)\b[A-Z]:\\Users\\[^\\\s\"]+', '<USER_PROFILE>')
    $result = [regex]::Replace($result, '(?i)\b[A-Z]:\\[^\s\"]*daimon-bundle\\runtime', '<KIMI_BUNDLE_RUNTIME>')
    $result = [regex]::Replace($result, '(?i)\b[A-Z]:\\KimiData\\daimon-share\\daimon', '<KIMI_DAIMON_HOME>')
    $result = [regex]::Replace($result, '(?i)\b[A-Z]:\\Kimi\\resources\\resources\\runtime', '<KIMI_CLIENT_RUNTIME>')
    $result = [regex]::Replace($result, '(?i)\b[A-Z]:\\Ruffle(?=\\|$)', '<RUFFLE_HOME>')
    $result = [regex]::Replace($result, '(?i)\b[A-Z]:\\nodejs(?=\\|$)', '<NODEJS_HOME>')
    $result = [regex]::Replace($result, '(?i)\b[A-Z]:\\VSCode(?=\\|$)', '<VSCODE_HOME>')
    $result = [regex]::Replace($result, '(?i)(deviceUUID\s*=\s*)[0-9a-f-]+', '$1<GPU_DEVICE_UUID>')
    $result = [regex]::Replace($result, '(?i)(driverUUID\s*=\s*)[0-9a-f-]+', '$1<GPU_DRIVER_UUID>')
    $result = [regex]::Replace($result, '(?i)(deviceLUID\s*=\s*)[0-9a-f-]+', '$1<GPU_DEVICE_LUID>')
    $result = [regex]::Replace($result, '(?i)://[^\s/:@]+:[^\s/@]+@', '://<REDACTED>@')
    return $result
}

function Protect-Object([AllowNull()]$InputObject) {
    if ($null -eq $InputObject) { return $null }
    if ($InputObject -is [string]) { return Protect-Text $InputObject }
    if ($InputObject.GetType().IsValueType) { return $InputObject }
    if ($InputObject -is [System.Collections.IDictionary]) {
        $safe = [ordered]@{}
        foreach ($key in $InputObject.Keys) { $safe[$key] = Protect-Object $InputObject[$key] }
        return $safe
    }
    if ($InputObject -is [System.Collections.IEnumerable]) {
        return ,@(foreach ($item in $InputObject) { Protect-Object $item })
    }
    if ($InputObject -is [pscustomobject]) {
        $safe = [ordered]@{}
        foreach ($property in $InputObject.PSObject.Properties) { $safe[$property.Name] = Protect-Object $property.Value }
        return $safe
    }
    return $InputObject
}

function Invoke-Native([string]$FilePath, [string[]]$Arguments) {
    $output = @(& $FilePath @Arguments 2>&1 | ForEach-Object { $_.ToString() })
    $code = $LASTEXITCODE
    return [ordered]@{ output = $output; exitCode = $code }
}

function Invoke-AuditCheck {
    param(
        [string]$Id,
        [string]$Category,
        [string]$Purpose,
        [string]$Command,
        [string]$Expected,
        [string]$Prerequisites,
        [scriptblock]$Body,
        [scriptblock]$Evaluate
    )
    $started = Get-Date
    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    $observed = $null
    $failure = $null
    $succeeded = $true
    try {
        $observed = & $Body
    }
    catch {
        $succeeded = $false
        $failure = $_.Exception.Message
    }
    $stopwatch.Stop()

    $status = "BLOCKED"
    if ($succeeded) {
        if ($null -ne $Evaluate) {
            $status = & $Evaluate $observed
        }
        else {
            $status = "PASS"
        }
    }
    if (@("PASS", "FAIL", "BLOCKED", "NOT RUN") -notcontains $status) {
        throw "Invalid status for ${Id}: $status"
    }

    $check = [ordered]@{
        id = $Id
        category = $Category
        purpose = $Purpose
        prerequisites = $Prerequisites
        command = $Command
        workingDirectory = "<WORKSPACE>"
        expected = $Expected
        startedAtLocal = $started.ToString("yyyy-MM-ddTHH:mm:ss.fffffffK")
        durationMilliseconds = $stopwatch.ElapsedMilliseconds
        status = $status
        exitCode = $null
        powershellSucceeded = $succeeded
        error = $failure
        observed = $observed
        evidence = @(
            "docs/architecture/stage-1.5/results/environment-audit.json",
            "docs/architecture/stage-1.5/results/environment-audit-console.log"
        )
        firstFailure = $null
        rerun = $null
        limitations = @()
        followUp = @()
    }
    if ($observed -is [System.Collections.IDictionary] -and $observed.Contains("exitCode")) {
        $check.exitCode = $observed.exitCode
    }
    $safeCheck = Protect-Object $check
    $script:Checks += $safeCheck
    Write-Output ("AUDIT_CHECK {0} {1} duration_ms={2}" -f $Id, $status, $stopwatch.ElapsedMilliseconds)
    Write-Output ($safeCheck | ConvertTo-Json -Depth 14 -Compress)
}

function Get-CommandInventory([string[]]$Names) {
    $rows = @()
    foreach ($name in $Names) {
        $commands = @(Get-Command $name -All -ErrorAction SilentlyContinue)
        if ($commands.Count -eq 0) {
            $rows += [pscustomobject]@{ name = $name; found = $false; resolutions = @() }
            continue
        }
        $resolutions = @($commands | ForEach-Object {
            [pscustomobject]@{
                commandType = $_.CommandType.ToString()
                name = $_.Name
                source = $_.Source
                path = $_.Path
                version = if ($_.Version) { $_.Version.ToString() } else { $null }
            }
        })
        $rows += [pscustomobject]@{ name = $name; found = $true; resolutions = $resolutions }
    }
    return $rows
}

function Get-ExistingFiles([string[]]$Candidates) {
    $files = @()
    foreach ($candidate in $Candidates) {
        if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
        $files += @(Get-ChildItem -Path $candidate -File -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
    }
    return @($files | Sort-Object -Unique)
}

function Get-ToolInvocation([string]$Name, [string[]]$ExtraCandidates, [string[]]$Arguments) {
    $pathCandidates = @()
    $command = Get-Command $Name -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command -and $command.Path) { $pathCandidates += $command.Path }
    $fileNames = if ([IO.Path]::HasExtension($Name)) { @($Name) } else { @("$Name.exe", "$Name.bat", "$Name.cmd") }
    foreach ($scope in @('User', 'Machine')) {
        $persistentPath = [Environment]::GetEnvironmentVariable('Path', $scope)
        foreach ($directory in ($persistentPath -split ';')) {
            $expanded = [Environment]::ExpandEnvironmentVariables($directory)
            if ([string]::IsNullOrWhiteSpace($expanded) -or -not (Test-Path -LiteralPath $expanded -PathType Container)) { continue }
            foreach ($fileName in $fileNames) {
                $candidate = Join-Path $expanded $fileName
                if (Test-Path -LiteralPath $candidate -PathType Leaf) { $pathCandidates += $candidate }
            }
        }
    }
    $pathCandidates += @(Get-ExistingFiles $ExtraCandidates)
    $pathCandidates = @($pathCandidates | Select-Object -Unique)
    if ($pathCandidates.Count -eq 0) {
        return [ordered]@{ found = $false; executable = $null; output = @("No executable found on PATH or in bounded common locations."); exitCode = $null }
    }
    $executable = $pathCandidates[0]
    $result = Invoke-Native $executable $Arguments
    return [ordered]@{
        found = $true
        executable = $executable
        candidateExecutables = $pathCandidates
        output = $result.output
        exitCode = $result.exitCode
    }
}

# --- Operating system and update state ---
Invoke-AuditCheck -Id "WIN-001" -Category "Windows" `
    -Purpose "Collect Windows edition, version, build and architecture without host identifiers." `
    -Command 'Get-ComputerInfo; Get-CimInstance Win32_OperatingSystem; Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' `
    -Expected "Native queries complete and return an OS inventory." `
    -Prerequisites "PowerShell 5.1; CIM and registry read access." `
    -Body {
        $ci = Get-ComputerInfo -ErrorAction Stop
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop
        $script:OsData = [ordered]@{
            caption = $os.Caption
            version = $os.Version
            buildNumber = [int]$os.BuildNumber
            osArchitecture = $os.OSArchitecture
            productName = $cv.ProductName
            displayVersion = $cv.DisplayVersion
            currentBuild = $cv.CurrentBuild
            ubr = $cv.UBR
            editionId = $cv.EditionID
            buildLabEx = $cv.BuildLabEx
            computerInfo = [ordered]@{
                windowsProductName = $ci.WindowsProductName
                windowsVersion = $ci.WindowsVersion
                osName = $ci.OsName
                osVersion = $ci.OsVersion.ToString()
                osArchitecture = $ci.OsArchitecture.ToString()
                osBuildNumber = $ci.OsBuildNumber
            }
        }
        return $script:OsData
    }

Invoke-AuditCheck -Id "WIN-002" -Category "Windows" `
    -Purpose "Check the stated Windows 10 22H2 x64 development-host baseline." `
    -Command '$os = Get-CimInstance Win32_OperatingSystem; $cv = Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion; evaluate build, DisplayVersion and architecture' `
    -Expected "Windows 10 22H2, build 19045, 64-bit OS." `
    -Prerequisites "WIN-001 inventory." `
    -Body {
        if ($null -eq $script:OsData) { throw "OS inventory unavailable." }
        return [ordered]@{
            caption = $script:OsData.caption
            displayVersion = $script:OsData.displayVersion
            buildNumber = $script:OsData.buildNumber
            osArchitecture = $script:OsData.osArchitecture
            isWindows10 = ($script:OsData.buildNumber -ge 10240 -and $script:OsData.buildNumber -lt 22000)
            is22H2 = ($script:OsData.displayVersion -eq '22H2' -and $script:OsData.buildNumber -eq 19045)
            is64Bit = ($script:OsData.osArchitecture -match '64')
        }
    } `
    -Evaluate { param($o) if ($o.isWindows10 -and $o.is22H2 -and $o.is64Bit) { "PASS" } else { "FAIL" } }

Invoke-AuditCheck -Id "WIN-003" -Category "Windows" `
    -Purpose "Enumerate installed update identifiers without claiming ESU enrollment." `
    -Command 'Get-HotFix | Select-Object HotFixID, Description, InstalledOn' `
    -Expected "Hotfix query completes and returns all entries visible to the native provider." `
    -Prerequisites "Windows Update WMI/CIM provider access." `
    -Body {
        $hotfixes = @(Get-HotFix -ErrorAction Stop | Select-Object HotFixID, Description, InstalledOn | Sort-Object HotFixID)
        return [ordered]@{ count = $hotfixes.Count; hotfixes = $hotfixes; providerLimit = "Get-HotFix visibility is not a complete servicing or ESU licensing record." }
    }

Invoke-AuditCheck -Id "WIN-004" -Category "Windows" `
    -Purpose "Check presence of the consumer ESU Licensing Preparation Package KB5126256." `
    -Command 'Get-HotFix -Id KB5126256' `
    -Expected "KB5126256 is visible in Get-HotFix on a Windows 10 host seeking consumer ESU." `
    -Prerequisites "Same provider as WIN-003; package presence alone does not prove enrollment." `
    -Body {
        $matches = @(Get-HotFix -ErrorAction Stop | Where-Object { $_.HotFixID -eq 'KB5126256' } | Select-Object HotFixID, Description, InstalledOn)
        return [ordered]@{ present = ($matches.Count -gt 0); matches = $matches }
    } `
    -Evaluate { param($o) if ($o.present) { "PASS" } else { "FAIL" } }

Invoke-AuditCheck -Id "WIN-005" -Category "Windows" `
    -Purpose "Determine actual Windows 10 ESU enrollment without reading account or license secrets." `
    -Command 'Manual check required: Settings > Update & Security > Windows Update; no automated enrollment command executed' `
    -Expected "User-visible Windows Update page explicitly reports enrollment status." `
    -Prerequisites "Interactive user inspection; do not infer enrollment from installed hotfixes." `
    -Body {
        return [ordered]@{ enrollment = "UNKNOWN"; reason = "No privacy-safe native query was established in this audit; KB presence is not enrollment proof." }
    } `
    -Evaluate { "BLOCKED" }

Invoke-AuditCheck -Id "WIN-006" -Category "Windows" `
    -Purpose "Record TPM and Secure Boot facts relevant only to Windows 11 planning." `
    -Command 'Get-Tpm; Confirm-SecureBootUEFI' `
    -Expected "Read available TPM/Secure Boot facts; access or firmware errors are captured." `
    -Prerequisites "Native cmdlets and firmware support; no settings are changed." `
    -Body {
        $errors = @()
        $tpm = $null
        $secureBoot = $null
        try {
            $items = @(Get-Tpm -ErrorAction Stop | Select-Object -First 1)
            if ($items.Count -eq 0 -or $null -eq $items[0]) {
                $errors += 'Get-Tpm: no TPM object returned in the current non-elevated context.'
            } else {
                $t = $items[0]
                $tpm = [ordered]@{ tpmPresent = $t.TpmPresent; tpmReady = $t.TpmReady; tpmEnabled = $t.TpmEnabled; tpmActivated = $t.TpmActivated }
            }
        } catch { $errors += "Get-Tpm: $($_.Exception.Message)" }
        try { $secureBoot = Confirm-SecureBootUEFI -ErrorAction Stop } catch { $errors += "Confirm-SecureBootUEFI: $($_.Exception.Message)" }
        return [ordered]@{ tpm = $tpm; secureBootEnabled = $secureBoot; errors = $errors; eligibility = "UNKNOWN" }
    } `
    -Evaluate { param($o) if (($null -ne $o.tpm -and ($null -ne $o.tpm.tpmPresent -or $null -ne $o.tpm.tpmReady -or $null -ne $o.tpm.tpmEnabled -or $null -ne $o.tpm.tpmActivated)) -or $null -ne $o.secureBootEnabled) { "PASS" } else { "BLOCKED" } }

Invoke-AuditCheck -Id "WIN-007" -Category "Windows" `
    -Purpose "Determine complete Windows 11 upgrade eligibility." `
    -Command 'Not executed: PC Health Check / Windows Update eligibility offer; TPM and Secure Boot inventory only in WIN-006' `
    -Expected "An official complete eligibility result from PC Health Check or Windows Update." `
    -Prerequisites "User-approved interactive Microsoft eligibility check; no upgrade is authorized." `
    -Body { return [ordered]@{ eligibility = "UNKNOWN"; reason = "TPM/Secure Boot fragments cannot establish complete CPU, firmware, compatibility or offer eligibility." } } `
    -Evaluate { "BLOCKED" }

# --- CPU and memory ---
Invoke-AuditCheck -Id "CPU-001" -Category "Hardware" `
    -Purpose "Collect CPU architecture, cores, virtualization and SLAT facts." `
    -Command 'Get-CimInstance Win32_Processor; Get-CimInstance Win32_ComputerSystem' `
    -Expected "Processor and computer-system inventory is returned." `
    -Prerequisites "CIM read access." `
    -Body {
        $cpu = @(Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object Name, Manufacturer, AddressWidth, DataWidth, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed, VirtualizationFirmwareEnabled, VMMonitorModeExtensions, SecondLevelAddressTranslationExtensions)
        $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop | Select-Object HypervisorPresent
        $script:CpuData = $cpu
        return [ordered]@{ processors = $cpu; computerSystem = $cs }
    }

Invoke-AuditCheck -Id "CPU-002" -Category "Hardware" `
    -Purpose "Verify actual SSE4.2 instruction-set support required by Godot x86_64." `
    -Command 'Get-Command coreinfo -ErrorAction SilentlyContinue; if found: coreinfo -f' `
    -Expected "An actual CPU feature tool reports SSE4.2; model-name inference is not accepted." `
    -Prerequisites "A preinstalled trusted CPU feature reporting tool." `
    -Body {
        $inventory = @(Get-CommandInventory @('coreinfo'))
        return [ordered]@{ tools = $inventory; sse42 = "UNKNOWN"; reason = "Win32_Processor does not expose an SSE4.2 feature flag." }
    } `
    -Evaluate { "BLOCKED" }

Invoke-AuditCheck -Id "CPU-003" -Category "Hardware" `
    -Purpose "Check Android Studio's required firmware virtualization support." `
    -Command 'Get-CimInstance Win32_Processor | Select-Object VirtualizationFirmwareEnabled, SecondLevelAddressTranslationExtensions' `
    -Expected "VirtualizationFirmwareEnabled is true on every processor; SLAT is recorded." `
    -Prerequisites "CPU-001; firmware value as exposed by Windows." `
    -Body {
        if ($script:CpuData.Count -eq 0) { throw "CPU inventory unavailable." }
        $enabled = @($script:CpuData | Where-Object { $_.VirtualizationFirmwareEnabled -eq $true }).Count
        return [ordered]@{ processorCount = $script:CpuData.Count; virtualizationEnabledCount = $enabled; allEnabled = ($enabled -eq $script:CpuData.Count); details = $script:CpuData }
    } `
    -Evaluate { param($o) if ($o.allEnabled) { "PASS" } else { "FAIL" } }

Invoke-AuditCheck -Id "CPU-004" -Category "Hardware" `
    -Purpose "Compare the real CPU with Android Studio's minimum post-2017 microarchitecture requirement." `
    -Command 'Get-CimInstance Win32_Processor; compare exact model with Intel official launch specification Q2 2014' `
    -Expected "Android Studio full-IDE route requires a CPU microarchitecture after 2017." `
    -Prerequisites "CPU-001 exact model plus Intel official product-series evidence; this does not assess the standalone command-line-tools route." `
    -Body {
        if ($script:CpuData.Count -eq 0) { throw "CPU inventory unavailable." }
        $models = @($script:CpuData | ForEach-Object Name)
        $knownLegacy = (@($models | Where-Object { $_ -match 'i7-4710MQ' }).Count -gt 0)
        return [ordered]@{ models = $models; exactModelEvidence = 'Intel official 4th Generation Core i7 product series: i7-4710MQ launched Q2 2014'; evidenceUrl = 'https://www.intel.com/content/www/us/en/ark/products/series/75023/4th-generation-intel-core-i7-processors.html'; androidStudioRequires = 'CPU microarchitecture after 2017'; meetsPost2017Requirement = if ($knownLegacy) { $false } else { $null }; route = 'Android Studio full IDE only; standalone SDK command-line tools remain unverified' }
    } `
    -Evaluate { param($o) if ($o.meetsPost2017Requirement -eq $false) { "FAIL" } elseif ($o.meetsPost2017Requirement -eq $true) { "PASS" } else { "BLOCKED" } }

Invoke-AuditCheck -Id "MEM-001" -Category "Hardware" `
    -Purpose "Measure memory against Godot native editor minimum 4 GiB and recommended 8 GiB." `
    -Command 'Get-CimInstance Win32_OperatingSystem; Get-CimInstance Win32_PhysicalMemory' `
    -Expected "Installed physical memory is at least 4 GiB; available memory and recommended threshold are recorded." `
    -Prerequisites "CIM read access." `
    -Body {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $modules = @(Get-CimInstance Win32_PhysicalMemory -ErrorAction Stop | Select-Object Capacity, Speed, ConfiguredClockSpeed, Manufacturer, PartNumber)
        $totalBytes = [int64]$os.TotalVisibleMemorySize * 1KB
        $freeBytes = [int64]$os.FreePhysicalMemory * 1KB
        $script:MemoryData = [ordered]@{
            totalVisibleBytes = $totalBytes
            totalVisibleGiB = [math]::Round($totalBytes / 1GB, 2)
            freeBytes = $freeBytes
            freeGiB = [math]::Round($freeBytes / 1GB, 2)
            physicalModuleCapacityBytes = [int64](($modules | Measure-Object -Property Capacity -Sum).Sum)
            physicalModuleCapacityGiB = [math]::Round([int64](($modules | Measure-Object -Property Capacity -Sum).Sum) / 1GB, 2)
            meetsGodotMinimum4GiB = ($totalBytes -ge 4GB)
            meetsGodotRecommended8GiB = ($totalBytes -ge 8GB)
            meetsAndroidStudioMinimum8GiB = ([int64](($modules | Measure-Object -Property Capacity -Sum).Sum) -ge 8GB)
            meetsAndroidStudioAndEmulatorMinimum16GiB = ([int64](($modules | Measure-Object -Property Capacity -Sum).Sum) -ge 16GB)
            modules = $modules
        }
        return $script:MemoryData
    } `
    -Evaluate { param($o) if ($o.meetsGodotMinimum4GiB) { "PASS" } else { "FAIL" } }

# --- Storage ---
Invoke-AuditCheck -Id "DISK-001" -Category "Storage" `
    -Purpose "Inventory volumes and map project/tool drives to disk and media where Windows exposes it." `
    -Command 'Get-Volume; Get-Partition; Get-Disk; Get-PhysicalDisk' `
    -Expected "At least volume capacity data is returned; mapping errors are retained." `
    -Prerequisites "Storage cmdlets; some physical-disk properties may require elevated access." `
    -Body {
        $errors = @()
        $volumes = @(); $partitions = @(); $disks = @(); $physical = @()
        try { $volumes = @(Get-Volume -ErrorAction Stop | Where-Object DriveLetter | Select-Object DriveLetter, FileSystemLabel, FileSystem, DriveType, HealthStatus, Size, SizeRemaining) } catch { $errors += "Get-Volume: $($_.Exception.Message)" }
        try { $partitions = @(Get-Partition -ErrorAction Stop | Where-Object DriveLetter | Select-Object DiskNumber, PartitionNumber, DriveLetter, Size, Type) } catch { $errors += "Get-Partition: $($_.Exception.Message)" }
        try { $disks = @(Get-Disk -ErrorAction Stop | Select-Object Number, FriendlyName, BusType, PartitionStyle, OperationalStatus, HealthStatus, Size) } catch { $errors += "Get-Disk: $($_.Exception.Message)" }
        try { $physical = @(Get-PhysicalDisk -ErrorAction Stop | Select-Object DeviceId, FriendlyName, MediaType, BusType, SpindleSpeed, HealthStatus, Size) } catch { $errors += "Get-PhysicalDisk: $($_.Exception.Message)" }
        $script:VolumeData = $volumes
        return [ordered]@{ volumes = $volumes; partitions = $partitions; disks = $disks; physicalDisks = $physical; errors = $errors }
    } `
    -Evaluate { param($o) if (@($o.volumes).Count -gt 0) { "PASS" } else { "BLOCKED" } }

Invoke-AuditCheck -Id "DISK-002" -Category "Storage" `
    -Purpose "Apply explicit conservative project planning thresholds for PoC and Android tool storage." `
    -Command 'Get-Volume; project drive = workspace drive; test project free >=20 GiB and any fixed volume free >=80 GiB' `
    -Expected "Project drive has >=20 GiB free and at least one fixed candidate tool drive has >=80 GiB free. These are project thresholds, not official minimums." `
    -Prerequisites "DISK-001 volume inventory; no directories are created." `
    -Body {
        if ($script:VolumeData.Count -eq 0) { throw "Volume inventory unavailable." }
        $projectLetter = (Split-Path -Qualifier $Workspace).TrimEnd(':')
        $project = $script:VolumeData | Where-Object { $_.DriveLetter -eq $projectLetter } | Select-Object -First 1
        $fixed = @($script:VolumeData | Where-Object { $_.DriveType -eq 'Fixed' })
        $candidates = @($fixed | Where-Object { $_.SizeRemaining -ge 80GB } | Select-Object DriveLetter, SizeRemaining)
        return [ordered]@{
            thresholds = [ordered]@{ projectFreeGiB = 20; candidateToolDriveFreeGiB = 80; officialMinimum = $false }
            projectDrive = $projectLetter
            project = $project
            projectMeets20GiB = ($null -ne $project -and $project.SizeRemaining -ge 20GB)
            fixedVolumes = $fixed
            candidateToolDrives = $candidates
            anyCandidateMeets80GiB = ($candidates.Count -gt 0)
        }
    } `
    -Evaluate { param($o) if ($o.projectMeets20GiB -and $o.anyCandidateMeets80GiB) { "PASS" } else { "FAIL" } }

# --- GPU and display ---
Invoke-AuditCheck -Id "GPU-001" -Category "Graphics" `
    -Purpose "Collect GPU model, driver and current display mode without inferring API support." `
    -Command 'Get-CimInstance Win32_VideoController' `
    -Expected "Video-controller inventory is returned." `
    -Prerequisites "CIM read access; current display modes can be null in remote/headless sessions." `
    -Body {
        $gpu = @(Get-CimInstance Win32_VideoController -ErrorAction Stop | Select-Object Name, AdapterCompatibility, DriverVersion, DriverDate, VideoProcessor, CurrentHorizontalResolution, CurrentVerticalResolution, CurrentRefreshRate, PNPDeviceID)
        $script:GpuData = $gpu
        return [ordered]@{ controllers = $gpu; warning = "Adapter model and DLL presence do not prove full Vulkan/OpenGL support." }
    }

Invoke-AuditCheck -Id "GPU-002" -Category "Graphics" `
    -Purpose "Verify actual Vulkan 1.0 capability for the Godot Mobile renderer." `
    -Command 'Get-Command vulkaninfo -ErrorAction SilentlyContinue; if found: vulkaninfo' `
    -Expected "The installed Vulkan tool exits 0 and at least one real device reports apiVersion >=1.0." `
    -Prerequisites "Preinstalled Vulkan reporting tool and working display drivers; no tool installation allowed in 1.5.1." `
    -Body {
        $tools = @(Get-CommandInventory @('vulkaninfo'))
        $vulkan = Get-Command vulkaninfo -ErrorAction SilentlyContinue | Select-Object -First 1
        $vulkanResult = $null
        if ($vulkan) { $vulkanResult = Invoke-Native $vulkan.Path @() }
        $devices = @()
        $current = $null
        $instanceVersion = $null
        if ($null -ne $vulkanResult) {
            foreach ($line in $vulkanResult.output) {
                if ($line -match 'Vulkan Instance Version:\s*([0-9.]+)') { $instanceVersion = $Matches[1] }
                if ($line -match '^GPU\s*(\d+)') {
                    if ($null -ne $current) { $devices += [pscustomobject]$current }
                    $current = [ordered]@{ gpuIndex = [int]$Matches[1]; deviceName = $null; apiVersion = $null; driverVersion = $null }
                }
                if ($null -ne $current -and $line -match 'deviceName\s*=\s*(.+)$') { $current.deviceName = $Matches[1].Trim() }
                if ($null -ne $current -and $line -match 'apiVersion\s*=\s*(?:[0-9]+\s*\(\s*)?([0-9]+\.[0-9]+\.[0-9]+)') { $current.apiVersion = $Matches[1] }
                if ($null -ne $current -and $line -match 'driverVersion\s*=\s*(.+)$') { $current.driverVersion = $Matches[1].Trim() }
            }
            if ($null -ne $current) { $devices += [pscustomobject]$current }
        }
        $capable = @($devices | Where-Object { $_.apiVersion -and [version]$_.apiVersion -ge [version]'1.0.0' })
        $loaderExists = Test-Path -LiteralPath (Join-Path $env:WINDIR 'System32\vulkan-1.dll')
        return [ordered]@{ tools = $tools; vulkanOutput = $vulkanResult; instanceVersion = $instanceVersion; devices = $devices; vulkan10CapableDeviceCount = $capable.Count; runtimeLoaderExistsOnly = $loaderExists; exitCode = if ($vulkanResult) { $vulkanResult.exitCode } else { $null } }
    } `
    -Evaluate { param($o) if (-not $o.vulkanOutput -or $o.vulkanOutput.exitCode -ne 0) { "BLOCKED" } elseif ($o.vulkan10CapableDeviceCount -gt 0) { "PASS" } else { "FAIL" } }

Invoke-AuditCheck -Id "GPU-003" -Category "Graphics" `
    -Purpose "Check the Android Studio minimum 1280 x 800 display resolution from current display modes." `
    -Command 'Get-CimInstance Win32_VideoController | Select-Object CurrentHorizontalResolution,CurrentVerticalResolution' `
    -Expected "At least one current display mode is >=1280 x 800; null values are BLOCKED." `
    -Prerequisites "GPU-001; a locally reported current display mode." `
    -Body {
        $valid = @($script:GpuData | Where-Object { $_.CurrentHorizontalResolution -and $_.CurrentVerticalResolution })
        $meets = @($valid | Where-Object { $_.CurrentHorizontalResolution -ge 1280 -and $_.CurrentVerticalResolution -ge 800 })
        return [ordered]@{ reportedModes = $valid; meetsMinimum = ($meets.Count -gt 0); minimumWidth = 1280; minimumHeight = 800 }
    } `
    -Evaluate { param($o) if (@($o.reportedModes).Count -eq 0) { "BLOCKED" } elseif ($o.meetsMinimum) { "PASS" } else { "FAIL" } }

Invoke-AuditCheck -Id "GPU-004" -Category "Graphics" `
    -Purpose "Verify actual OpenGL 3.3 capability for the Godot Compatibility renderer." `
    -Command 'Get-Command wglinfo -ErrorAction SilentlyContinue; if found: wglinfo' `
    -Expected "A trusted installed tool actually reports OpenGL >=3.3; DLL existence alone is insufficient." `
    -Prerequisites "Preinstalled OpenGL reporting tool and working display drivers; no tool installation allowed in 1.5.1." `
    -Body {
        $tools = @(Get-CommandInventory @('wglinfo'))
        $wgl = Get-Command wglinfo -ErrorAction SilentlyContinue | Select-Object -First 1
        $result = $null
        if ($wgl) { $result = Invoke-Native $wgl.Path @() }
        $version = $null
        if ($result -and ($result.output -join "`n") -match 'OpenGL version[^0-9]*([0-9]+\.[0-9]+)') { $version = $Matches[1] }
        $runtimeExists = Test-Path -LiteralPath (Join-Path $env:WINDIR 'System32\opengl32.dll')
        return [ordered]@{ tools = $tools; openGlOutput = $result; detectedVersion = $version; runtimeDllExistsOnly = $runtimeExists; capability = if ($version) { 'MEASURED' } else { 'UNKNOWN' }; exitCode = if ($result) { $result.exitCode } else { $null } }
    } `
    -Evaluate { param($o) if (-not $o.openGlOutput) { "BLOCKED" } elseif ($o.openGlOutput.exitCode -eq 0 -and $o.detectedVersion -and [version]$o.detectedVersion -ge [version]'3.3') { "PASS" } elseif ($o.openGlOutput.exitCode -eq 0 -and $o.detectedVersion) { "FAIL" } else { "BLOCKED" } }

# --- Network ---
Invoke-AuditCheck -Id "NET-001" -Category "Network" `
    -Purpose "Inventory adapter capabilities and link state without IP, SSID, MAC or credentials." `
    -Command 'Get-NetAdapter | Select-Object Name,InterfaceDescription,Status,LinkSpeed,InterfaceType,HardwareInterface,Virtual,DriverVersion,DriverProvider' `
    -Expected "Native adapter inventory completes with privacy-sensitive fields excluded." `
    -Prerequisites "Network Adapter cmdlet read access." `
    -Body {
        $adapters = @(Get-NetAdapter -ErrorAction Stop | Select-Object Name, InterfaceDescription, Status, MediaConnectionState, LinkSpeed, InterfaceType, HardwareInterface, Virtual, ConnectorPresent, DriverVersion, DriverProvider, DriverDate)
        return [ordered]@{ adapters = $adapters; excluded = @('IPAddress', 'MacAddress', 'SSID', 'NetworkCredentials') }
    }

Invoke-AuditCheck -Id "NET-002" -Category "Network" `
    -Purpose "Check for at least one operational non-virtual adapter; this is not a LAN communication test." `
    -Command 'Get-NetAdapter | Where-Object { -not $_.Virtual -and $_.Status -eq "Up" }' `
    -Expected "At least one non-virtual adapter is Up; no packet transmission is performed." `
    -Prerequisites "NET-001; virtual-only and disconnected adapters do not meet this inventory check." `
    -Body {
        $adapters = @(Get-NetAdapter -ErrorAction Stop | Where-Object { -not $_.Virtual } | Select-Object Name, InterfaceDescription, Status, LinkSpeed, InterfaceType, HardwareInterface)
        $up = @($adapters | Where-Object Status -eq 'Up')
        return [ordered]@{ physicalAdapters = $adapters; upCount = $up.Count; lanTestPerformed = $false }
    } `
    -Evaluate { param($o) if ($o.upCount -gt 0) { "PASS" } else { "FAIL" } }

# --- Shell and source-control runtimes ---
Invoke-AuditCheck -Id "TOOL-001" -Category "Tools" `
    -Purpose "Record the actual PowerShell runtime and process architecture." `
    -Command '$PSVersionTable; [Environment]::Is64BitProcess' `
    -Expected "PowerShell version data is available and process architecture is recorded." `
    -Prerequisites "The audit script is running." `
    -Body {
        return [ordered]@{ psVersion = $PSVersionTable.PSVersion.ToString(); psEdition = $PSVersionTable.PSEdition; clrVersion = $PSVersionTable.CLRVersion.ToString(); is64BitProcess = [Environment]::Is64BitProcess; executionPolicyProcess = (Get-ExecutionPolicy -Scope Process).ToString() }
    }

Invoke-AuditCheck -Id "TOOL-002" -Category "Tools" `
    -Purpose "Resolve and execute Git version from the current Windows process PATH." `
    -Command 'Get-Command git -All; git --version' `
    -Expected "Git executable resolves and git --version exits 0." `
    -Prerequisites "Existing Git installation; no repository mutation." `
    -Body { return Get-ToolInvocation 'git' @() @('--version') } `
    -Evaluate { param($o) if (-not $o.found) { "BLOCKED" } elseif ($o.exitCode -eq 0) { "PASS" } else { "FAIL" } }

Invoke-AuditCheck -Id "TOOL-003" -Category "Tools" `
    -Purpose "Resolve and execute Python version and architecture from the current Windows process PATH." `
    -Command 'Get-Command python,python3,py -All; python --version; python -c "import sys,platform; print(sys.executable); print(platform.machine()); print(platform.architecture())"' `
    -Expected "A Python interpreter executes successfully and reports its real executable and architecture." `
    -Prerequisites "Existing Python installation; version inspection only." `
    -Body {
        $inventory = @(Get-CommandInventory @('python', 'python3', 'py'))
        $version = Get-ToolInvocation 'python' @() @('--version')
        $details = $null
        if ($version.found -and $version.exitCode -eq 0) {
            $details = Invoke-Native $version.executable @('-c', 'import sys,platform; print(sys.executable); print(sys.version); print(platform.machine()); print(platform.architecture())')
        }
        return [ordered]@{ inventory = $inventory; version = $version; details = $details; exitCode = $version.exitCode }
    } `
    -Evaluate { param($o) if (-not $o.version.found) { "BLOCKED" } elseif ($o.version.exitCode -eq 0 -and $null -ne $o.details -and $o.details.exitCode -eq 0) { "PASS" } else { "FAIL" } }

# --- Godot broker (never direct Godot invocation) ---
Invoke-AuditCheck -Id "TOOL-004" -Category "Tools" `
    -Purpose "Use the required Godot broker doctor to inspect the actual engine binary and version." `
    -Command 'python3 "<GODOT_BROKER>" doctor (fallback to resolved python only if python3 is unavailable)' `
    -Expected "Broker executes, reads a real binary, and reports Godot 4.7.2; no direct Godot command is used." `
    -Prerequisites "Python and the managed broker script; Godot may be absent and must then remain BLOCKED." `
    -Body {
        $python = Get-Command python3 -ErrorAction SilentlyContinue | Select-Object -First 1
        $pythonName = 'python3'
        if (-not $python) { $python = Get-Command python -ErrorAction SilentlyContinue | Select-Object -First 1; $pythonName = 'python' }
        if (-not $python) { return [ordered]@{ found = $false; output = @('No python3 or python interpreter found.'); exitCode = $null } }
        if (-not (Test-Path -LiteralPath $GodotBrokerScript -PathType Leaf)) { return [ordered]@{ found = $false; output = @('Godot broker script not found.'); exitCode = $null } }
        $result = Invoke-Native $python.Path @($GodotBrokerScript, 'doctor')
        return [ordered]@{ found = $true; interpreter = $pythonName; interpreterPath = $python.Path; broker = $GodotBrokerScript; output = $result.output; exitCode = $result.exitCode }
    } `
    -Evaluate { param($o) if (-not $o.found -or $o.exitCode -ne 0) { "BLOCKED" } elseif (($o.output -join "`n") -match '4\.7\.2') { "PASS" } else { "FAIL" } }

# --- Java, Gradle, Android SDK bounded discovery ---
$javaCandidates = @(
    "$env:ProgramFiles\Java\*\bin\java.exe",
    "${env:ProgramFiles(x86)}\Java\*\bin\java.exe",
    "$env:ProgramFiles\Eclipse Adoptium\*\bin\java.exe",
    "$env:ProgramFiles\Microsoft\jdk-*\bin\java.exe",
    "$env:ProgramFiles\Amazon Corretto\*\bin\java.exe",
    "$env:ProgramFiles\Zulu\*\bin\java.exe",
    "$env:ProgramFiles\Android\Android Studio\jbr\bin\java.exe",
    "$env:LOCALAPPDATA\Programs\Android Studio\jbr\bin\java.exe"
)
foreach ($name in @('JAVA_HOME', 'JDK_HOME')) {
    foreach ($scope in @('Process', 'User', 'Machine')) {
        $root = [Environment]::GetEnvironmentVariable($name, $scope)
        if ($root) { $javaCandidates = @((Join-Path $root 'bin\java.exe')) + $javaCandidates }
    }
}

Invoke-AuditCheck -Id "TOOL-005" -Category "Tools" `
    -Purpose "Find a Java runtime and compiler and verify a JDK compatible with Godot's recommended OpenJDK 17." `
    -Command 'Get-Command java,javac -All; bounded common JDK/Android Studio JBR paths; java -version; javac -version' `
    -Expected "A real java and sibling javac both execute; major version 17 is preferred and recorded." `
    -Prerequisites "Existing JDK; no install or PATH changes. Higher versions require later export validation." `
    -Body {
        $inventory = @(Get-CommandInventory @('java', 'javac'))
        $java = Get-ToolInvocation 'java' $javaCandidates @('-version')
        $javacResult = $null
        if ($java.found) {
            $javacPath = Join-Path (Split-Path -Parent $java.executable) 'javac.exe'
            if (Test-Path -LiteralPath $javacPath -PathType Leaf) { $javacResult = Invoke-Native $javacPath @('-version') }
        }
        $combined = (@($java.output) + @($javacResult.output)) -join "`n"
        $major = $null
        if ($combined -match 'version\s+\"(?:1\.)?(\d+)') { $major = [int]$Matches[1] }
        return [ordered]@{ inventory = $inventory; java = $java; javac = $javacResult; detectedMajor = $major; recommendedMajor = 17; exitCode = $java.exitCode }
    } `
    -Evaluate { param($o) if (-not $o.java.found -or $null -eq $o.javac) { "BLOCKED" } elseif ($o.java.exitCode -ne 0 -or $o.javac.exitCode -ne 0) { "FAIL" } elseif ($o.detectedMajor -eq 17) { "PASS" } else { "FAIL" } }

Invoke-AuditCheck -Id "TOOL-006" -Category "Tools" `
    -Purpose "Record standalone Gradle availability without treating it as Godot's generated wrapper." `
    -Command 'Get-Command gradle -All; gradle --version' `
    -Expected "If a standalone Gradle exists, its version executes; absence blocks only this standalone-tool check." `
    -Prerequisites "Existing standalone Gradle; Godot wrapper version remains a later-stage check." `
    -Body {
        $candidates = @()
        if ($env:GRADLE_HOME) { $candidates += "$env:GRADLE_HOME\bin\gradle.bat" }
        $result = Get-ToolInvocation 'gradle' $candidates @('--version')
        return [ordered]@{ standalone = $result; wrapperInspected = $false; exitCode = $result.exitCode }
    } `
    -Evaluate { param($o) if (-not $o.standalone.found) { "BLOCKED" } elseif ($o.standalone.exitCode -eq 0) { "PASS" } else { "FAIL" } }

$sdkEnvironmentRoots = @()
foreach ($name in @('ANDROID_SDK_ROOT', 'ANDROID_HOME')) {
    foreach ($scope in @('Process', 'User', 'Machine')) {
        $root = [Environment]::GetEnvironmentVariable($name, $scope)
        if ($root) { $sdkEnvironmentRoots += $root }
    }
}
$sdkCandidates = @(
    $sdkEnvironmentRoots,
    "$env:LOCALAPPDATA\Android\Sdk",
    'D:\Android\Sdk',
    'C:\Android\Sdk'
) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
$script:SdkRoots = @($sdkCandidates | Sort-Object -Unique | Where-Object { Test-Path -LiteralPath $_ -PathType Container })
$adbCandidates = @($sdkCandidates | ForEach-Object { Join-Path $_ 'platform-tools\adb.exe' })
$sdkManagerCandidates = @()
foreach ($root in $sdkCandidates) {
    $sdkManagerCandidates += "$root\cmdline-tools\*\bin\sdkmanager.bat"
    $sdkManagerCandidates += "$root\tools\bin\sdkmanager.bat"
}

Invoke-AuditCheck -Id "TOOL-007" -Category "Tools" `
    -Purpose "Find ADB on PATH or bounded SDK locations and execute its version command." `
    -Command 'Get-Command adb -All; bounded Android SDK paths; adb version' `
    -Expected "adb version executes and reports Platform-Tools >=35.0.0 for the Godot baseline." `
    -Prerequisites "Existing Android Platform-Tools; no SDK installation." `
    -Body {
        $inventory = @(Get-CommandInventory @('adb'))
        $adb = Get-ToolInvocation 'adb' $adbCandidates @('version')
        $version = $null
        if (($adb.output -join "`n") -match 'Android Debug Bridge version\s+([0-9.]+)') { $version = $Matches[1] }
        return [ordered]@{ inventory = $inventory; adb = $adb; platformToolsVersion = $version; minimumVersion = '35.0.0'; exitCode = $adb.exitCode }
    } `
    -Evaluate { param($o) if (-not $o.adb.found) { "BLOCKED" } elseif ($o.adb.exitCode -ne 0 -or -not $o.platformToolsVersion) { "FAIL" } elseif ([version]$o.platformToolsVersion -ge [version]'35.0.0') { "PASS" } else { "FAIL" } }

Invoke-AuditCheck -Id "TOOL-008" -Category "Tools" `
    -Purpose "Find sdkmanager on PATH or bounded SDK locations and execute its version command." `
    -Command 'Get-Command sdkmanager -All; bounded Android SDK paths; sdkmanager --version' `
    -Expected "sdkmanager executes and reports its real version." `
    -Prerequisites "Existing SDK command-line tools and working Java; no package installation." `
    -Body {
        $inventory = @(Get-CommandInventory @('sdkmanager'))
        $manager = Get-ToolInvocation 'sdkmanager' $sdkManagerCandidates @('--version')
        return [ordered]@{ inventory = $inventory; sdkmanager = $manager; exitCode = $manager.exitCode }
    } `
    -Evaluate { param($o) if (-not $o.sdkmanager.found) { "BLOCKED" } elseif ($o.sdkmanager.exitCode -eq 0) { "PASS" } else { "FAIL" } }

Invoke-AuditCheck -Id "TOOL-009" -Category "Tools" `
    -Purpose "Inventory locally installed Android SDK packages against the unresolved Godot/API 37 candidate matrix." `
    -Command 'Inspect bounded SDK roots and package source.properties; sdkmanager --list_installed only when sdkmanager is available' `
    -Expected "Real local package evidence includes Platform-Tools >=35.0.0, Build-Tools 35.0.1, Platform 35 and API 37 planning inputs; absence is BLOCKED, not a successful export." `
    -Prerequisites "Existing SDK root; package versions are not inferred from directory names alone when source.properties is available." `
    -Body {
        $roots = @()
        foreach ($root in $script:SdkRoots) {
            $packages = @()
            foreach ($relative in @('platform-tools', 'build-tools', 'platforms', 'cmdline-tools', 'ndk', 'cmake')) {
                $directory = Join-Path $root $relative
                if (-not (Test-Path -LiteralPath $directory -PathType Container)) { continue }
                $children = @(Get-ChildItem -LiteralPath $directory -Directory -ErrorAction SilentlyContinue)
                if ($children.Count -eq 0) { $children = @(Get-Item -LiteralPath $directory) }
                foreach ($child in $children) {
                    $source = Join-Path $child.FullName 'source.properties'
                    $revision = $null
                    if (Test-Path -LiteralPath $source -PathType Leaf) {
                        $line = Get-Content -LiteralPath $source -ErrorAction SilentlyContinue | Where-Object { $_ -match '^Pkg\.Revision=' } | Select-Object -First 1
                        if ($line) { $revision = $line.Substring('Pkg.Revision='.Length).Trim() }
                    }
                    $packages += [pscustomobject]@{ packageType = $relative; name = $child.Name; revision = $revision }
                }
            }
            $roots += [pscustomobject]@{ root = $root; packages = $packages }
        }
        $manager = Get-ToolInvocation 'sdkmanager' $sdkManagerCandidates @('--list_installed')
        $required = [ordered]@{ platformTools = '>=35.0.0'; godotBuildTools = '35.0.1'; godotPlatform = 'android-35'; projectTargetCompilePlatform = 'android-37'; ndk = '28.1.13356709'; cmake = '3.10.2.4988404' }
        return [ordered]@{ roots = $roots; sdkmanagerListInstalled = $manager; candidateMatrix = $required; matrixValidated = $false; exitCode = $manager.exitCode }
    } `
    -Evaluate { param($o) if (@($o.roots).Count -eq 0 -or -not $o.sdkmanagerListInstalled.found) { "BLOCKED" } elseif ($o.sdkmanagerListInstalled.exitCode -ne 0) { "FAIL" } else { "BLOCKED" } }

# --- Environment and command resolution ---
Invoke-AuditCheck -Id "PATH-001" -Category "Configuration" `
    -Purpose "Audit whitelisted environment variables, sanitized PATH entries, duplicates, invalid paths and command conflicts." `
    -Command '[Environment]::GetEnvironmentVariable for whitelist; $env:PATH -split ";"; Get-Command <names> -All' `
    -Expected "Inventory completes; conflicts are reported as observations rather than automatically classified as failures." `
    -Prerequisites "Read process/user/machine environment only; no secret-valued variables are collected." `
    -Body {
        $whitelist = @('JAVA_HOME', 'JDK_HOME', 'ANDROID_HOME', 'ANDROID_SDK_ROOT', 'ANDROID_SDK_HOME', 'ANDROID_AVD_HOME', 'GRADLE_HOME', 'GRADLE_USER_HOME', 'GODOT_BIN', 'VULKAN_SDK')
        $variables = @()
        foreach ($scope in @('Process', 'User', 'Machine')) {
            foreach ($name in $whitelist) {
                $value = [Environment]::GetEnvironmentVariable($name, $scope)
                if ($null -ne $value) {
                    $expanded = [Environment]::ExpandEnvironmentVariables($value)
                    $variables += [pscustomobject]@{ scope = $scope; name = $name; value = $value; pathExists = (Test-Path -LiteralPath $expanded) }
                }
            }
        }
        $pathRows = @()
        foreach ($scope in @('Process', 'User', 'Machine')) {
            $raw = [Environment]::GetEnvironmentVariable('Path', $scope)
            if ($null -eq $raw) { continue }
            $index = 0
            foreach ($entry in ($raw -split ';')) {
                $expanded = [Environment]::ExpandEnvironmentVariables($entry)
                $pathRows += [pscustomobject]@{ scope = $scope; index = $index; entry = $entry; exists = if ([string]::IsNullOrWhiteSpace($expanded)) { $false } else { Test-Path -LiteralPath $expanded } }
                $index++
            }
        }
        $duplicates = @($pathRows | Where-Object { -not [string]::IsNullOrWhiteSpace($_.entry) } | Group-Object { $_.entry.TrimEnd('\').ToLowerInvariant() } | Where-Object Count -gt 1 | ForEach-Object {
            [pscustomobject]@{ normalizedEntry = $_.Name; occurrences = @($_.Group | Select-Object scope, index, entry) }
        })
        $names = @('git', 'python', 'python3', 'py', 'godot', 'godot4', 'java', 'javac', 'gradle', 'adb', 'sdkmanager', 'vulkaninfo', 'wglinfo', 'coreinfo')
        $commands = @(Get-CommandInventory $names)
        $conflicts = @($commands | Where-Object { @($_.resolutions).Count -gt 1 })
        return [ordered]@{ variables = $variables; pathEntries = $pathRows; invalidPathEntries = @($pathRows | Where-Object { -not $_.exists }); duplicatePathEntries = $duplicates; commands = $commands; commandsWithMultipleResolutions = $conflicts; note = "Multiple resolutions and duplicate PATH entries require review but are not intrinsically failures." }
    }

# --- Android device query only if ADB already exists ---
Invoke-AuditCheck -Id "DEV-001" -Category "AndroidDevice" `
    -Purpose "Check visible Android device and ADB authorization state without connecting or configuring a device." `
    -Command 'adb devices -l only when an existing adb is found; otherwise no device command executed' `
    -Expected "An attached device reports device state; serial numbers are redacted. Missing ADB/device/authorization is BLOCKED." `
    -Prerequisites "Preinstalled ADB and an already configured USB-debugging device; neither is required for 1.5.1." `
    -Body {
        $adb = Get-ToolInvocation 'adb' $adbCandidates @('devices', '-l')
        if (-not $adb.found) { return [ordered]@{ adbFound = $false; devices = @(); authorization = "UNKNOWN"; exitCode = $null } }
        $safeLines = @()
        foreach ($line in $adb.output) {
            if ($line -match '^\s*([^\s]+)\s+(device|unauthorized|offline|recovery|sideload|bootloader)(\s|$)') {
                $safeLines += ($line -replace '^\s*[^\s]+', '<DEVICE_SERIAL>')
            } else { $safeLines += $line }
        }
        $deviceLines = @($safeLines | Where-Object { $_ -match '^<DEVICE_SERIAL>\s+' })
        $authorized = @($deviceLines | Where-Object { $_ -match '^<DEVICE_SERIAL>\s+device(\s|$)' })
        return [ordered]@{ adbFound = $true; executable = $adb.executable; rawOutputRedacted = $safeLines; visibleDeviceCount = $deviceLines.Count; authorizedDeviceCount = $authorized.Count; authorization = if ($authorized.Count -gt 0) { 'AUTHORIZED' } else { 'UNKNOWN' }; exitCode = $adb.exitCode }
    } `
    -Evaluate { param($o) if ($o.adbFound -and $o.authorizedDeviceCount -gt 0 -and $o.exitCode -eq 0) { "PASS" } else { "BLOCKED" } }

# Add evidence-specific limitations/follow-ups without changing observed results.
foreach ($check in $script:Checks) {
    switch ($check.id) {
        'WIN-005' { $check.limitations += 'Actual ESU enrollment remains UNKNOWN until the user checks Windows Update.'; $check.followUp += 'User: inspect Settings > Update & Security > Windows Update and report the ESU enrollment label.' }
        'WIN-007' { $check.followUp += 'If Windows 11 migration is desired, run the official PC Health Check interactively; do not upgrade during stage 1.5.1.' }
        'CPU-002' { $check.followUp += 'Use a preapproved CPU feature tool or later Godot startup evidence; do not infer SSE4.2 from the model name.' }
        'GPU-002' { $check.followUp += 'After approval, install/use trusted API reporting tools and run real Godot renderer smoke tests in later stages.' }
        'TOOL-004' { $check.followUp += 'Stage 1.5.2 requires separate user approval before installing Godot or changing GODOT_BIN.' }
        'TOOL-005' { $check.followUp += 'Stage 1.5.2 must verify JDK 17 and Godot recognition; no JDK was installed by this audit.' }
        'TOOL-009' { $check.followUp += 'Resolve the Godot 35.x baseline versus Android API 37 requirements using the actual generated export build in later stages.' }
        'DEV-001' { $check.followUp += 'No device setup is requested now; test USB debugging and authorization only when a device and ADB are available.' }
    }
}

$summary = [ordered]@{}
foreach ($status in @('PASS', 'FAIL', 'BLOCKED', 'NOT RUN')) {
    $summary[$status] = @($script:Checks | Where-Object { $_.status -eq $status }).Count
}

$report = [ordered]@{
    schemaVersion = '1.0.0'
    project = 'REAL-POOL-3D'
    stage = '1.5.1'
    title = 'Windows 10 read-only development environment audit'
    generatedAtLocal = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
    generatedAtUtc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
    workspace = '<WORKSPACE>'
    script = 'docs/architecture/stage-1.5/scripts/Invoke-WindowsEnvironmentAudit.ps1'
    statusDefinitions = [ordered]@{
        PASS = 'Executed and met the predefined criterion with reproducible evidence.'
        FAIL = 'Executed and did not meet the predefined criterion.'
        BLOCKED = 'Could not complete because a tool, permission, device, driver or external condition is unavailable.'
        NOT_RUN = 'Not executed.'
    }
    redaction = [ordered]@{
        placeholders = @('<WORKSPACE>', '<GODOT_BROKER>', '<KIMI_RUNTIME>', '<KIMI_BUNDLE_RUNTIME>', '<KIMI_DAIMON_HOME>', '<KIMI_CLIENT_RUNTIME>', '<USER_PROFILE>', '<LOCAL_APPDATA>', '<ROAMING_APPDATA>', '<COMPUTER_NAME>', '<USER_NAME>', '<RUFFLE_HOME>', '<NODEJS_HOME>', '<VSCODE_HOME>', '<DEVICE_SERIAL>', '<REDACTED>')
        excludedData = @('passwords', 'tokens', 'signing keys', 'network credentials', 'IP addresses', 'SSID', 'MAC addresses', 'device serial numbers', 'product keys')
    }
    planningThresholds = [ordered]@{
        projectDriveMinimumFreeGiB = 20
        candidateToolDriveMinimumFreeGiB = 80
        note = 'Conservative project planning thresholds only; not vendor minimum requirements.'
    }
    executionHistory = @(
        [ordered]@{
            attempt = 'initial-launch'
            outcome = 'FAIL'
            auditExecuted = $false
            exitCode = 1
            evidence = 'docs/architecture/stage-1.5/results/environment-audit-console.initial_fail.log'
            reason = 'tee could not open its log because the results directory did not exist; PowerShell did not start.'
            fix = 'Created the results directory and reran the unchanged audit script.'
        },
        [ordered]@{
            attempt = 'run1'
            outcome = 'COMPLETED_WITH_FAIL_AND_BLOCKED'
            auditExecuted = $true
            summary = [ordered]@{ PASS = 16; FAIL = 2; BLOCKED = 11; NOT_RUN = 0 }
            evidence = @('docs/architecture/stage-1.5/results/environment-audit.initial_fail.json', 'docs/architecture/stage-1.5/results/environment-audit-console.run1.log')
            affectedCheckIds = @('WIN-006', 'MEM-001', 'GPU-002', 'TOOL-003', 'TOOL-005', 'TOOL-006', 'PATH-001')
            fixes = @('Used the installed vulkaninfo without the unsupported --summary option.', 'Detected tools on persistent User/Machine PATH as well as process PATH.', 'Removed nested quotes that broke the Python architecture probe.', 'Corrected physical-memory threshold accounting.', 'Corrected empty TPM result handling.', 'Redacted strings before JSON escaping.')
            note = 'Run1 evidence is retained with privacy redaction only; statuses and observed command failures are not rewritten.'
        },
        [ordered]@{
            attempt = 'run2'
            outcome = 'COMPLETED_WITH_PARSER_AND_REDACTION_DEFECTS'
            auditExecuted = $true
            summary = [ordered]@{ PASS = 17; FAIL = 5; BLOCKED = 9; NOT_RUN = 0 }
            evidence = @('docs/architecture/stage-1.5/results/environment-audit.run2.json', 'docs/architecture/stage-1.5/results/environment-audit-console.run2.log')
            affectedCheckIds = @('WIN-006', 'GPU-002', 'PATH-001')
            fixes = @('Recognized Vulkan apiVersion in both semantic-only and raw-version-with-parentheses formats.', 'Preserved empty and single-element arrays during recursive redaction.', 'Preserved primitive Boolean values.', 'Redacted the managed runtime root derived from a forward-slash broker path.', 'Handled empty TPM command output as BLOCKED.')
            note = 'Run2 evidence is retained with privacy redaction only; its GPU-002 FAIL was a parser defect, not a hardware failure.'
        },
        [ordered]@{
            attempt = 'run3'
            outcome = 'COMPLETED_WITH_RESIDUAL_REDACTION_AND_NULL_STATUS_DEFECTS'
            auditExecuted = $true
            summary = [ordered]@{ PASS = 18; FAIL = 4; BLOCKED = 9; NOT_RUN = 0 }
            evidence = @('docs/architecture/stage-1.5/results/environment-audit.run3.json', 'docs/architecture/stage-1.5/results/environment-audit-console.run3.log')
            affectedCheckIds = @('WIN-006', 'PATH-001')
            fixes = @('Redacted the remaining managed-daemon base path.', 'Required at least one non-null TPM or Secure Boot fact before marking WIN-006 PASS.')
            note = 'Run3 evidence is retained with privacy redaction only; no hardware result is changed.'
        },
        [ordered]@{
            attempt = 'run4'
            outcome = 'CURRENT'
            auditExecuted = $true
            evidence = @('docs/architecture/stage-1.5/results/environment-audit.json', 'docs/architecture/stage-1.5/results/environment-audit-console.log')
        }
    )
    checks = $script:Checks
    summary = $summary
    scope = [ordered]@{
        softwareInstalled = $false
        persistentConfigurationChanged = $false
        godotProjectCreated = $false
        pocCreated = $false
        stage152Executed = $false
        stage2Executed = $false
        directGodotInvocation = $false
        deviceConfigurationChanged = $false
    }
    knownLimitations = @(
        'Static documentation review is not dynamic tool or engine validation.',
        'Vulkan tool output does not prove Godot renderer compatibility; unmeasured OpenGL remains BLOCKED and both renderers require later Godot tests.',
        'ESU preparation-package presence does not prove ESU enrollment.',
        'A physical network adapter being Up does not prove LAN discovery, ENet communication or Android permissions.',
        'The Godot Android 35.x baseline and Android API 37 requirements are not asserted as a validated combined toolchain.',
        'No Android export, device, SQLite, network or renderer PoC was executed.'
    )
}

$json = $report | ConvertTo-Json -Depth 16
$json = Protect-Text $json
[IO.File]::WriteAllText($OutputPath, $json, (New-Object System.Text.UTF8Encoding($false)))
Write-Output ("AUDIT_SUMMARY " + ($summary | ConvertTo-Json -Compress))
Write-Output ("AUDIT_JSON " + (Protect-Text $OutputPath))
