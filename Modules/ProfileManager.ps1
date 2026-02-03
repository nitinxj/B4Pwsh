# ProfileManager.ps1
# Manages .profile, .b4pwsh_profile, and .b4pwsh_rc loading
# Profile commands set in-memory only — no disk saves.
# Config and aliases load after profiles, so interactive changes win.

$script:ProfileFiles = @{
    Profile        = Join-Path $env:USERPROFILE ".profile"
    B4PwshProfile  = Join-Path $env:USERPROFILE ".b4pwsh_profile"
    B4PwshRc       = Join-Path $env:USERPROFILE ".b4pwsh_rc"
}

$script:ProfileLoadOrder = @("Profile", "B4PwshProfile", "B4PwshRc")

function Load-B4PwshProfiles {
    foreach ($key in $script:ProfileLoadOrder) {
        $filePath = $script:ProfileFiles[$key]
        if (Test-Path $filePath) {
            Write-Host "Loading $filePath..." -ForegroundColor Gray
            Invoke-B4PwshProfileFile -FilePath $filePath
        }
    }
}

function Invoke-B4PwshProfileFile {
    param(
        [string]$FilePath
    )

    try {
        $lines = Get-Content -Path $FilePath -Encoding UTF8 -ErrorAction Stop
    } catch {
        Write-Host "Warning: Could not read '$FilePath': $_" -ForegroundColor Yellow
        return
    }

    $lineNumber = 0

    foreach ($line in $lines) {
        $lineNumber++
        $line = $line.Trim()

        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) {
            continue
        }

        try {
            Invoke-B4PwshProfileCommand -Command $line
        } catch {
            Write-Host "Warning: Error in '$FilePath' at line $lineNumber`: $_" -ForegroundColor Yellow
        }
    }
}

function Invoke-B4PwshProfileCommand {
    param(
        [string]$Command
    )

    # config translation on/off
    if ($Command -match '^config\s+translation\s+(on|off)$') {
        $global:B4PwshConfig.ShowTranslation = ($matches[1] -eq 'on')
        return
    }

    # config vi on/off
    if ($Command -match '^config\s+vi\s+(on|off)$') {
        $global:B4PwshConfig.ViMode = ($matches[1] -eq 'on')
        return
    }

    # config modeindicator on/off
    if ($Command -match '^config\s+modeindicator\s+(on|off)$') {
        $global:B4PwshConfig.ShowModeIndicator = ($matches[1] -eq 'on')
        return
    }

    # config prompt PS1/PS2 — in-memory only
    if ($Command -match '^config\s+prompt\s+(PS[12])\s+(.+)$') {
        $global:B4PwshPrompts[$matches[1]] = $matches[2].Trim("'", '"')
        return
    }

    # alias — in-memory only. [^=]+ supports non-word chars like ..
    if ($Command -match '^alias\s+([^=]+)=(.+)$') {
        $global:B4PwshAliases[$matches[1].Trim()] = $matches[2].Trim("'", '"')
        return
    }

    # unalias — in-memory only
    if ($Command -match '^unalias\s+(.+)$') {
        $name = $matches[1].Trim()
        if ($name -eq '-a') {
            $global:B4PwshAliases.Clear()
        } else {
            $global:B4PwshAliases.Remove($name)
        }
        return
    }

    # history size <n> — in-memory only, no save
    if ($Command -match '^history\s+size\s+(\d+)$') {
        Set-MaxHistorySize -Size ([int]$matches[1])
        return
    }

    # Everything else (including export) goes through the parser
    $bashCmd = $global:B4PwshParser.Parse($Command)
    $pwshCmd = $global:B4PwshParser.Translate($bashCmd)

    if ($pwshCmd) {
        $scriptBlock = [scriptblock]::Create($pwshCmd)
        $output = & $scriptBlock
        if ($null -ne $output) {
            $output | Out-Default
        }
    }
}

function Get-ProfileFilePaths {
    return $script:ProfileFiles
}