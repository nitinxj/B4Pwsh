# B4Pwsh.ps1
# Main entry point - orchestrates all modules

# Get script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Load classes
. "$scriptDir\Classes\BashCommand.ps1"
. "$scriptDir\Classes\BashParser.ps1"

# Load module functions
. "$scriptDir\Modules\TabCompletion.ps1"
. "$scriptDir\Modules\InputHandler.ps1"
. "$scriptDir\Modules\HistoryManager.ps1"
. "$scriptDir\Modules\ConfigManager.ps1"
. "$scriptDir\Modules\AliasManager.ps1"
. "$scriptDir\Modules\HistoryShortcuts.ps1"
. "$scriptDir\Modules\PromptManager.ps1"
. "$scriptDir\Modules\ProfileManager.ps1"

# Shell configuration
$global:B4PwshConfig = @{
    ShowTranslation   = $false
    ViMode            = $false
    ShowModeIndicator = $false
    HelpDefault       = "bash"
}

$global:B4PwshHistory = [System.Collections.ArrayList]::new()
$global:B4PwshParser = [BashParser]::new()

function Start-B4Pwsh {
    Write-Host ""
    Write-Host "b4pwsh - Bash for PowerShell" -ForegroundColor Cyan
    Write-Host "Type 'exit' to quit, 'help' for commands" -ForegroundColor Gray
    Write-Host ""
    
    Load-B4PwshProfiles
    Load-B4PwshConfig -Config $global:B4PwshConfig
    Load-B4PwshHistory -History $global:B4PwshHistory
    Load-B4PwshAliases
    
    $running = $true
    [Console]::TreatControlCAsInput = $true
    
    while ($running) {
        $pwshCmd = $null
        
        try {
            $userInput = Read-B4PwshLine -Prompt (Expand-B4PwshPrompt (Get-B4PwshPrompt PS1)) -History $global:B4PwshHistory -CommandMap $global:B4PwshParser.CommandMap -ViMode $global:B4PwshConfig.ViMode -ShowModeIndicator $global:B4PwshConfig.ShowModeIndicator
            
            $userInput = $userInput.Trim()
            
            if ([string]::IsNullOrWhiteSpace($userInput)) {
                continue
            }
            
            $expandedInput = Expand-HistoryShortcut -Command $userInput -History $global:B4PwshHistory
            
            if ([string]::IsNullOrEmpty($expandedInput)) {
                continue
            }
            
            $expandedInput = Expand-B4PwshAlias -Command $expandedInput
            
            $commandToSave = $expandedInput
            if ($global:B4PwshHistory.Count -eq 0 -or $global:B4PwshHistory[-1] -ne $commandToSave) {
                $global:B4PwshHistory.Add($commandToSave) | Out-Null
                Save-B4PwshHistory -History $global:B4PwshHistory
            }
            
            if ($expandedInput -eq 'exit' -or $expandedInput -eq 'quit') {
                $running = $false
                Save-B4PwshHistory -History $global:B4PwshHistory
                Write-Host "Goodbye!" -ForegroundColor Cyan
                continue
            }
            
            if ($expandedInput -eq 'bhelp') {
                Show-B4PwshHelp
                continue
            }
            
            if ($expandedInput -eq 'bhelp history') {
                Show-HistoryShortcutHelp
                continue
            }
            
            if ($expandedInput -eq 'bhelp profile') {
                Show-B4PwshProfileHelp
                continue
            }
            
            if ($expandedInput -match '^phelp\s*(.*)$') {
                $helpArgs = $matches[1].Trim()
                if ($helpArgs) {
                    Get-Help $helpArgs
                }
                else {
                    Get-Help
                }
                continue
            }
            
            if ($expandedInput -eq 'help') {
                Invoke-B4PwshHelp
                continue
            }
            
            if ($expandedInput -eq 'help history') {
                Invoke-B4PwshHelp "history"
                continue
            }
            
            if ($expandedInput -eq 'help profile') {
                Invoke-B4PwshHelp "profile"
                continue
            }
            
            if ($expandedInput -eq 'config') {
                Show-B4PwshConfig
                continue
            }
            
            if ($expandedInput -eq 'config reset') {
                Reset-B4PwshConfig -Config $global:B4PwshConfig
                continue
            }
            
            if ($expandedInput -eq 'config prompt') {
                Show-B4PwshPrompts
                continue
            }
            
            if ($expandedInput -match '^config\s+prompt\s+(PS[12])\s+(.+)$') {
                Set-B4PwshPrompt -Variable $matches[1] -Value $matches[2].Trim("'", '"')
                continue
            }
            
            if ($expandedInput -eq 'alias') {
                Get-B4PwshAliases
                continue
            }
            
            if ($expandedInput -match '^alias\s+([^=]+)=(.+)$') {
                $aliasName = $matches[1].Trim()
                $aliasCommand = $matches[2].Trim("'", '"')
                Add-B4PwshAlias -Name $aliasName -Command $aliasCommand
                continue
            }
            
            if ($expandedInput -match '^unalias\s+(.+)$') {
                $name = $matches[1].Trim()
                if ($name -eq '-a') {
                    Clear-B4PwshAliases
                }
                else {
                    Remove-B4PwshAlias -Name $name
                }
                continue
            }
            
            if ($expandedInput -eq 'history') {
                for ($i = 0; $i -lt $global:B4PwshHistory.Count; $i++) {
                    Write-Host "$($i + 1)  $($global:B4PwshHistory[$i])"
                }
                continue
            }
            
            if ($expandedInput -eq 'history clear') {
                Clear-B4PwshHistory -History $global:B4PwshHistory
                continue
            }
            
            if ($expandedInput -match '^history\s+size\s+(\d+)$') {
                Set-MaxHistorySize -Size ([int]$matches[1])
                Save-B4PwshConfig -Config $global:B4PwshConfig
                continue
            }
            
            if ($expandedInput -match '^config\s+translation\s+(on|off)$') {
                $global:B4PwshConfig.ShowTranslation = ($matches[1] -eq 'on')
                Write-Host "Translation display: $($matches[1])" -ForegroundColor Yellow
                Save-B4PwshConfig -Config $global:B4PwshConfig
                continue
            }
            
            if ($expandedInput -match '^config\s+vi\s+(on|off)$') {
                $global:B4PwshConfig.ViMode = ($matches[1] -eq 'on')
                Write-Host "Vi mode: $($matches[1])" -ForegroundColor Yellow
                Save-B4PwshConfig -Config $global:B4PwshConfig
                continue
            }
            
            if ($expandedInput -match '^config\s+modeindicator\s+(on|off)$') {
                $global:B4PwshConfig.ShowModeIndicator = ($matches[1] -eq 'on')
                Write-Host "Mode indicator: $($matches[1])" -ForegroundColor Yellow
                Save-B4PwshConfig -Config $global:B4PwshConfig
                continue
            }
            
            if ($expandedInput -match '^config\s+help\s+(bash|pwsh)$') {
                $global:B4PwshConfig.HelpDefault = $matches[1]
                Write-Host "Default help system: $($matches[1])" -ForegroundColor Yellow
                Save-B4PwshConfig -Config $global:B4PwshConfig
                continue
            }
            
            if ($expandedInput -match ';') {
                # Multi-statement: execute each separately
                $statements = $expandedInput -split ';' | ForEach-Object { $_.Trim() }
                $pwshCmd = ($statements | ForEach-Object {
                        $tempCmd = Expand-B4PwshAlias -Command $_
                        $tempBash = $global:B4PwshParser.Parse($tempCmd)
                        $global:B4PwshParser.Translate($tempBash)
                    }) -join '; '
            }
            else {
                $bashCmd = $global:B4PwshParser.Parse($expandedInput)
                $pwshCmd = $global:B4PwshParser.Translate($bashCmd)
            }
            
            if ($global:B4PwshConfig.ShowTranslation) {
                Write-Host "-> $pwshCmd" -ForegroundColor DarkGray
            }
            
        }
        catch {
            Write-Host "Error: $_" -ForegroundColor Red
            continue
        }
        
        if ($pwshCmd) {
            try {
                [Console]::Out.Flush()
                
                $scriptBlock = [scriptblock]::Create($pwshCmd)
                $output = & $scriptBlock
                
                if ($null -ne $output) {
                    $output | Out-Default
                }
                
                [Console]::Out.Flush()
            }
            catch {
                Write-Host "Execution error: $_" -ForegroundColor Red
            }
        }
    }
    
    [Console]::TreatControlCAsInput = $false
}

function Invoke-B4PwshHelp {
    param([string]$Args = "")
    
    $helpDefault = $global:B4PwshConfig.HelpDefault
    
    if ($Args -eq "history") {
        if ($helpDefault -eq "bash") {
            Show-HistoryShortcutHelp
        }
        else {
            Get-Help about_History
        }
    }
    elseif ($Args -eq "profile") {
        if ($helpDefault -eq "bash") {
            Show-B4PwshProfileHelp
        }
        else {
            Get-Help about_Profiles
        }
    }
    elseif ($Args) {
        if ($helpDefault -eq "bash") {
            Show-B4PwshHelp
        }
        else {
            Get-Help $Args
        }
    }
    else {
        if ($helpDefault -eq "bash") {
            Show-B4PwshHelp
        }
        else {
            Get-Help
        }
    }
}

function Show-B4PwshHelp {
    Write-Host ""
    Write-Host "b4pwsh - Bash for PowerShell" -ForegroundColor Cyan
    Write-Host "============================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Available Commands:" -ForegroundColor Yellow
    Write-Host "  ls, ll, pwd, cd, cat, rm, cp, mv, mkdir, touch"
    Write-Host "  clear, ps, kill, echo, which, grep, sort, head, tail, wc, uniq"
    Write-Host "  export, env, more"
    Write-Host ""
    Write-Host "Features:" -ForegroundColor Yellow
    Write-Host "  - Tab completion (commands + files)"
    Write-Host "  - Command history (UP/DOWN arrows)"
    Write-Host "  - Ctrl+R interactive reverse search"
    Write-Host "  - Persistent history across sessions"
    Write-Host "  - Bash-style aliases"
    Write-Host "  - History shortcuts (!! !n !string)"
    Write-Host "  - Output redirection (> and >>)"
    Write-Host "  - Piping support (|) including | more"
    Write-Host "  - Vi-style navigation (optional)"
    Write-Host "  - Configurable PS1/PS2 prompts"
    Write-Host "  - Profile files (.profile, .b4pwsh_profile, .b4pwsh_rc)"
    Write-Host ""
    Write-Host "Commands:" -ForegroundColor Yellow
    Write-Host "  exit/quit                    Exit the shell"
    Write-Host "  bhelp                        Show b4pwsh help"
    Write-Host "  bhelp history                Show history shortcuts help"
    Write-Host "  bhelp profile                Show profile files help"
    Write-Host "  phelp <cmdlet>               Show PowerShell help"
    Write-Host "  help                         Show help (default: bash or pwsh)"
    Write-Host "  config                       Show current configuration"
    Write-Host "  config reset                 Reset configuration to defaults"
    Write-Host "  config help bash|pwsh        Set default help system"
    Write-Host "  config prompt                Show current prompt values"
    Write-Host "  config prompt PS1 'text'     Set PS1 prompt (supports \u \h \w \W \d \t \@ \\)"
    Write-Host "  config prompt PS2 'text'     Set PS2 prompt"
    Write-Host "  history                      Show command history"
    Write-Host "  history clear                Clear all history"
    Write-Host "  history size <num>           Set max history size (default: 1000)"
    Write-Host "  alias                        List all aliases"
    Write-Host "  alias name='command'         Create alias"
    Write-Host "  unalias name                 Remove alias"
    Write-Host "  unalias -a                   Remove all aliases"
    Write-Host "  config translation on/off    Show PowerShell translations"
    Write-Host "  config vi on/off             Enable vi-style navigation"
    Write-Host "  config modeindicator on/off  Show/hide [CMD] and [SEARCH] indicators"
    Write-Host ""
    Write-Host "Environment Variables:" -ForegroundColor Yellow
    Write-Host "  export                       Show all environment variables"
    Write-Host "  export VAR=value             Set environment variable"
    Write-Host "  export VAR='value'           Set environment variable (with quotes)"
    Write-Host "  export PATH=\${PATH}:/new/path  Append to PATH"
    Write-Host "  export VAR                   Show current value of VAR"
    Write-Host "  env                          List all environment variables"
    Write-Host ""
    Write-Host "Common Variables: \${HOME}, \${USER}, \${HOSTNAME}, \${PWD} expand automatically"
    Write-Host ""
    Write-Host "History Shortcuts:" -ForegroundColor Yellow
    Write-Host "  !!                           Repeat last command"
    Write-Host "  !n                           Execute command number n"
    Write-Host "  !string                      Execute most recent command starting with 'string'"
    Write-Host "  !?string                     Execute most recent command containing 'string'"
    Write-Host "  ^old^new                     Replace 'old' with 'new' in last command"
    Write-Host "  Ctrl+R                       Interactive reverse search (type to search, Ctrl+R to cycle)"
    Write-Host ""
    Write-Host "Vi Mode Keys (when enabled):" -ForegroundColor Yellow
    Write-Host "  ESC                     Enter command mode"
    Write-Host "  h/l                     Move cursor left/right"
    Write-Host "  0/$                     Jump to start/end of line"
    Write-Host "  w/b                     Jump word forward/backward"
    Write-Host "  x                       Delete character under cursor"
    Write-Host "  dd                      Delete entire line"
    Write-Host "  dw                      Delete word"
    Write-Host "  cw                      Change word"
    Write-Host "  i/a/A                   Enter insert mode"
    Write-Host "  k/j                     Previous/next command in history"
    Write-Host "  /                       Search history backward"
    Write-Host "  n/N                     Next/previous search match"
    Write-Host ""
}

function Show-B4PwshConfig {
    Write-Host ""
    Write-Host "Current Configuration:" -ForegroundColor Cyan
    Write-Host "=====================" -ForegroundColor Cyan
    Write-Host ""
    
    $onOffColor = { param($value) if ($value) { "Green" } else { "Red" } }
    $onOffText = { param($value) if ($value) { "on" } else { "off" } }
    
    Write-Host "  Translation Display:  " -NoNewline
    Write-Host (& $onOffText $global:B4PwshConfig.ShowTranslation) -ForegroundColor (& $onOffColor $global:B4PwshConfig.ShowTranslation)
    
    Write-Host "  Vi Mode:              " -NoNewline
    Write-Host (& $onOffText $global:B4PwshConfig.ViMode) -ForegroundColor (& $onOffColor $global:B4PwshConfig.ViMode)
    
    Write-Host "  Mode Indicator:       " -NoNewline
    Write-Host (& $onOffText $global:B4PwshConfig.ShowModeIndicator) -ForegroundColor (& $onOffColor $global:B4PwshConfig.ShowModeIndicator)
    
    Write-Host "  Default Help System:  " -NoNewline
    Write-Host $global:B4PwshConfig.HelpDefault -ForegroundColor Cyan
    
    Write-Host ""
    Write-Host "  Prompts:" -ForegroundColor Yellow
    Show-B4PwshPrompts
    
    Write-Host ""
    Write-Host "  Max History Size:     " -NoNewline
    Write-Host (Get-MaxHistorySize) -ForegroundColor Cyan
    
    Write-Host "  History File:         " -NoNewline
    Write-Host (Get-HistoryFilePath) -ForegroundColor Gray
    
    Write-Host "  Config File:          " -NoNewline
    Write-Host (Get-ConfigFilePath) -ForegroundColor Gray
    
    Write-Host "  Alias File:           " -NoNewline
    Write-Host (Get-AliasFilePath) -ForegroundColor Gray
    
    Write-Host ""
    Write-Host "  Profile Files:" -ForegroundColor Yellow
    $profilePaths = Get-ProfileFilePaths
    foreach ($key in @("Profile", "B4PwshProfile", "B4PwshRc")) {
        $path = $profilePaths[$key]
        $exists = if (Test-Path $path) { "exists" } else { "not found" }
        $color = if (Test-Path $path) { "Green" } else { "Red" }
        Write-Host "    ${key}: " -NoNewline
        Write-Host "$path " -NoNewline -ForegroundColor Gray
        Write-Host "($exists)" -ForegroundColor $color
    }
    
    Write-Host ""
    Write-Host "  Current History:      " -NoNewline
    Write-Host "$($global:B4PwshHistory.Count) commands" -ForegroundColor Cyan
    
    Write-Host "  Aliases Defined:      " -NoNewline
    Write-Host "$($global:B4PwshAliases.Count) aliases" -ForegroundColor Cyan
    
    Write-Host ""
}

function Show-B4PwshProfileHelp {
    Write-Host ""
    Write-Host "Profile Files:" -ForegroundColor Cyan
    Write-Host "==============" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "b4pwsh loads profile files on startup in this order:" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  1. .profile              General login profile (cross-shell compatible)" -ForegroundColor Yellow
    Write-Host "  2. .b4pwsh_profile       b4pwsh-specific login profile" -ForegroundColor Yellow
    Write-Host "  3. .b4pwsh_rc            b4pwsh interactive shell config (most common)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  After profiles load, .b4pwsh_config and .b4pwsh_aliases load on top." -ForegroundColor Gray
    Write-Host "  This means interactive changes override profile defaults." -ForegroundColor Gray
    Write-Host ""
    Write-Host "Location: All files are in your home directory (" -NoNewline -ForegroundColor Gray
    Write-Host $env:USERPROFILE -NoNewline -ForegroundColor Cyan
    Write-Host ")" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Syntax:" -ForegroundColor Yellow
    Write-Host "  # This is a comment"
    Write-Host "  Lines are executed as if typed at the prompt"
    Write-Host "  Empty lines are ignored"
    Write-Host ""
    Write-Host "Supported Commands in Profile Files:" -ForegroundColor Yellow
    Write-Host "  Shell settings:"
    Write-Host "    config prompt PS1 '\u@\h:\W$ '"
    Write-Host "    config vi on"
    Write-Host "    config translation off"
    Write-Host "    config modeindicator on"
    Write-Host "    history size 5000"
    Write-Host ""
    Write-Host "  Aliases:"
    Write-Host "    alias ll='ls -la'"
    Write-Host "    alias gs='git status'"
    Write-Host "    alias ..='cd ..'"
    Write-Host ""
    Write-Host "  Environment Variables:"
    Write-Host "    export EDITOR=code"
    Write-Host "    export PATH=\${PATH}:\${HOME}/bin"
    Write-Host "    export NODE_ENV=development"
    Write-Host ""
    Write-Host "Example .b4pwsh_rc:" -ForegroundColor Yellow
    Write-Host "  ----------------------------------------"
    Write-Host "  # Prompt"
    Write-Host "  config prompt PS1 '\u@\h:\W$ '"
    Write-Host ""
    Write-Host "  # Shell settings"
    Write-Host "  config vi on"
    Write-Host "  history size 5000"
    Write-Host ""
    Write-Host "  # Aliases"
    Write-Host "  alias ll='ls -la'"
    Write-Host "  alias gs='git status'"
    Write-Host ""
    Write-Host "  # Environment"
    Write-Host "  export EDITOR=code"
    Write-Host "  export PATH=\${PATH}:\${HOME}/bin"
    Write-Host "  ----------------------------------------"
    Write-Host ""
}

Set-Alias -Name b4pwsh -Value Start-B4Pwsh -Scope Global

Write-Host "b4pwsh loaded! Type 'b4pwsh' to start" -ForegroundColor Green