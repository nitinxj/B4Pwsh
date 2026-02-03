# ConfigManager.ps1
# Manages configuration persistence between sessions
# Only saves/restores values that were explicitly changed interactively.
# Profile files set the baseline; this file only overrides when something differs.

$script:ConfigFilePath = Join-Path $env:USERPROFILE ".b4pwsh_config"

function Save-B4PwshConfig {
    param(
        [hashtable]$Config
    )
    
    try {
        $configData = @{
            ShowTranslation = $Config.ShowTranslation
            ViMode = $Config.ViMode
            ShowModeIndicator = $Config.ShowModeIndicator
            HelpDefault = $Config.HelpDefault
            MaxHistorySize = Get-MaxHistorySize
            Prompts = $global:B4PwshPrompts
        }
        
        $configData | ConvertTo-Json | Out-File -FilePath $script:ConfigFilePath -Encoding UTF8
        
    } catch {
        Write-Host "Warning: Could not save configuration: $_" -ForegroundColor Yellow
    }
}

function Load-B4PwshConfig {
    param(
        [hashtable]$Config
    )
    
    try {
        if (Test-Path $script:ConfigFilePath) {
            $configData = Get-Content -Path $script:ConfigFilePath -Raw -Encoding UTF8 | ConvertFrom-Json
            
            if ($null -ne $configData.ShowTranslation) {
                $Config.ShowTranslation = $configData.ShowTranslation
            }
            
            if ($null -ne $configData.ViMode) {
                $Config.ViMode = $configData.ViMode
            }
            
            if ($null -ne $configData.ShowModeIndicator) {
                $Config.ShowModeIndicator = $configData.ShowModeIndicator
            }
            
            if ($null -ne $configData.HelpDefault) {
                $Config.HelpDefault = $configData.HelpDefault
            }
            
            # Only restore MaxHistorySize if it was explicitly saved
            # (i.e. user changed it interactively after profile already set it)
            if ($null -ne $configData.MaxHistorySize) {
                Set-MaxHistorySize -Size $configData.MaxHistorySize
            }
            
            # Only restore prompts if they exist in saved config
            if ($null -ne $configData.Prompts) {
                if ($null -ne $configData.Prompts.PS1) {
                    $global:B4PwshPrompts["PS1"] = $configData.Prompts.PS1
                }
                if ($null -ne $configData.Prompts.PS2) {
                    $global:B4PwshPrompts["PS2"] = $configData.Prompts.PS2
                }
            }
            
            Write-Host "Configuration loaded" -ForegroundColor Gray
        }
    } catch {
        Write-Host "Warning: Could not load configuration: $_" -ForegroundColor Yellow
    }
}

function Reset-B4PwshConfig {
    param(
        [hashtable]$Config
    )
    
    $Config.ShowTranslation = $false
    $Config.ViMode = $false
    $Config.ShowModeIndicator = $false
    $Config.HelpDefault = "bash"
    Set-MaxHistorySize -Size 1000
    
    # Reset prompts to defaults
    $global:B4PwshPrompts["PS1"] = "b4pwsh$ "
    $global:B4PwshPrompts["PS2"] = "> "
    
    try {
        if (Test-Path $script:ConfigFilePath) {
            Remove-Item -Path $script:ConfigFilePath -Force
        }
        Write-Host "Configuration reset to defaults" -ForegroundColor Green
    } catch {
        Write-Host "Warning: Could not reset configuration file: $_" -ForegroundColor Yellow
    }
}

function Get-ConfigFilePath {
    return $script:ConfigFilePath
}