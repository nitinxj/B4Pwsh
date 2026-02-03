# PromptManager.ps1
# Manages PS1, PS2 style prompt variables

$global:B4PwshPrompts = @{
    PS1 = "b4pwsh$ "
    PS2 = "> "
}

function Get-B4PwshPrompt {
    param(
        [ValidateSet("PS1", "PS2")]
        [string]$Variable = "PS1"
    )

    return $global:B4PwshPrompts[$Variable]
}

function Set-B4PwshPrompt {
    param(
        [ValidateSet("PS1", "PS2")]
        [string]$Variable,
        [string]$Value
    )

    if ([string]::IsNullOrEmpty($Value)) {
        Write-Host "Error: Prompt value cannot be empty" -ForegroundColor Red
        return
    }

    $global:B4PwshPrompts[$Variable] = $Value
    Write-Host "$Variable set to '$Value'" -ForegroundColor Green
    Save-B4PwshConfig -Config $global:B4PwshConfig
}

function Expand-B4PwshPrompt {
    param(
        [string]$PromptString
    )

    $expanded = $PromptString

    # Replace prompt tokens with live values
    $expanded = $expanded -replace '\\u', $env:USERNAME
    $expanded = $expanded -replace '\\h', $env:COMPUTERNAME
    $expanded = $expanded -replace '\\w', (Get-Location).Path
    $expanded = $expanded -replace '\\W', (Split-Path -Leaf (Get-Location).Path)
    $expanded = $expanded -replace '\\d', (Get-Date -Format 'ddd MMM dd')
    $expanded = $expanded -replace '\\t', (Get-Date -Format 'HH:mm:ss')
    $expanded = $expanded -replace '\\@', (Get-Date -Format 'hh:mm tt')
    $expanded = $expanded -replace '\\\\', '\'

    return $expanded
}

function Show-B4PwshPrompts {
    foreach ($key in @("PS1", "PS2")) {
        Write-Host "  ${key}:                    " -NoNewline
        Write-Host "'$($global:B4PwshPrompts[$key])'" -ForegroundColor Cyan
    }

    Write-Host ""
    Write-Host "  Available tokens:" -ForegroundColor Yellow
    Write-Host "    \u    Username"
    Write-Host "    \h    Hostname"
    Write-Host "    \w    Full working directory path"
    Write-Host "    \W    Current directory name only"
    Write-Host "    \d    Date (e.g. Mon Jan 31)"
    Write-Host "    \t    Time (24-hour HH:mm:ss)"
    Write-Host "    \@    Time (12-hour with AM/PM)"
    Write-Host "    \\    Literal backslash"
}