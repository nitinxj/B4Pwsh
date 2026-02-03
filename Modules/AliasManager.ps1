# AliasManager.ps1
# Manages bash-style aliases

$script:AliasFilePath = Join-Path $env:USERPROFILE ".b4pwsh_aliases"
$global:B4PwshAliases = @{}

function Add-B4PwshAlias {
    param(
        [string]$Name,
        [string]$Command
    )
    
    if ([string]::IsNullOrWhiteSpace($Name) -or [string]::IsNullOrWhiteSpace($Command)) {
        Write-Host "Usage: alias name='command'" -ForegroundColor Red
        return
    }
    
    $global:B4PwshAliases[$Name] = $Command
    Write-Host "Alias added: $Name='$Command'" -ForegroundColor Green
    
    # Auto-save
    Save-B4PwshAliases
}

function Remove-B4PwshAlias {
    param(
        [string]$Name
    )
    
    if ($global:B4PwshAliases.ContainsKey($Name)) {
        $global:B4PwshAliases.Remove($Name)
        Write-Host "Alias removed: $Name" -ForegroundColor Green
        Save-B4PwshAliases
    } else {
        Write-Host "Alias not found: $Name" -ForegroundColor Red
    }
}

function Get-B4PwshAliases {
    if ($global:B4PwshAliases.Count -eq 0) {
        Write-Host "No aliases defined" -ForegroundColor Yellow
        return
    }
    
    Write-Host ""
    Write-Host "Aliases:" -ForegroundColor Cyan
    Write-Host "========" -ForegroundColor Cyan
    foreach ($key in ($global:B4PwshAliases.Keys | Sort-Object)) {
        Write-Host "  $key" -NoNewline -ForegroundColor Green
        Write-Host " = " -NoNewline
        Write-Host "'$($global:B4PwshAliases[$key])'" -ForegroundColor Yellow
    }
    Write-Host ""
}

function Expand-B4PwshAlias {
    param(
        [string]$Command
    )
    
    # Split command to get the first word
    $tokens = $Command -split '\s+', 2
    $firstWord = $tokens[0]
    
    # Check if it's an alias
    if ($global:B4PwshAliases.ContainsKey($firstWord)) {
        $aliasCommand = $global:B4PwshAliases[$firstWord]
        
        # If there are additional arguments, append them
        if ($tokens.Count -gt 1) {
            return "$aliasCommand $($tokens[1])"
        } else {
            return $aliasCommand
        }
    }
    
    # Not an alias, return original
    return $Command
}

function Save-B4PwshAliases {
    try {
        $global:B4PwshAliases | ConvertTo-Json | Out-File -FilePath $script:AliasFilePath -Encoding UTF8
    } catch {
        Write-Host "Warning: Could not save aliases: $_" -ForegroundColor Yellow
    }
}

function Load-B4PwshAliases {
    try {
        if (Test-Path $script:AliasFilePath) {
            $loaded = Get-Content -Path $script:AliasFilePath -Raw -Encoding UTF8 | ConvertFrom-Json
            
            # Convert PSCustomObject to hashtable
            $loaded.PSObject.Properties | ForEach-Object {
                $global:B4PwshAliases[$_.Name] = $_.Value
            }
            
            if ($global:B4PwshAliases.Count -gt 0) {
                Write-Host "Loaded $($global:B4PwshAliases.Count) aliases" -ForegroundColor Gray
            }
        }
    } catch {
        Write-Host "Warning: Could not load aliases: $_" -ForegroundColor Yellow
    }
}

function Clear-B4PwshAliases {
    $global:B4PwshAliases.Clear()
    
    try {
        if (Test-Path $script:AliasFilePath) {
            Remove-Item -Path $script:AliasFilePath -Force
        }
        Write-Host "All aliases cleared" -ForegroundColor Green
    } catch {
        Write-Host "Warning: Could not clear aliases file: $_" -ForegroundColor Yellow
    }
}

function Get-AliasFilePath {
    return $script:AliasFilePath
}