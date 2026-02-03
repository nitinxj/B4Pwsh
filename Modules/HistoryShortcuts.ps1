# HistoryShortcuts.ps1
# Handles bash-style history expansion: !!, !n, !command, !?search

function Expand-HistoryShortcut {
    param(
        [string]$Command,
        [System.Collections.ArrayList]$History
    )
    
    # Return command unchanged if it doesn't start with ! or ^
    if (-not $Command.StartsWith('!') -and -not $Command.StartsWith('^')) {
        return $Command
    }
    
    # If history is empty and we have a history command, return empty to signal error
    if ($History.Count -eq 0) {
        Write-Host "Error: No command history available" -ForegroundColor Red
        return ""
    }
    
    # !! - Repeat last command
    if ($Command -eq '!!') {
        $lastCmd = $History[-1]
        Write-Host "Executing: $lastCmd" -ForegroundColor DarkGray
        return $lastCmd
    }
    
    # !! with additional arguments - append to last command
    if ($Command -match '^!!\s+(.+)$') {
        $lastCmd = $History[-1]
        $args = $matches[1]
        $expandedCmd = "$lastCmd $args"
        Write-Host "Executing: $expandedCmd" -ForegroundColor DarkGray
        return $expandedCmd
    }
    
    # !n - Execute command number n (1-based)
    if ($Command -match '^!(\d+)$') {
        $cmdNumber = [int]$matches[1]
        
        if ($cmdNumber -lt 1 -or $cmdNumber -gt $History.Count) {
            Write-Host "Error: No such command in history: $cmdNumber" -ForegroundColor Red
            return ""
        }
        
        $cmd = $History[$cmdNumber - 1]
        Write-Host "Executing: $cmd" -ForegroundColor DarkGray
        return $cmd
    }
    
    # !-n - Execute command n positions back (1 is last, 2 is second to last, etc.)
    if ($Command -match '^!-(\d+)$') {
        $offset = [int]$matches[1]
        
        if ($offset -lt 1 -or $offset -gt $History.Count) {
            Write-Host "Error: No such command in history: !-$offset" -ForegroundColor Red
            return ""
        }
        
        $cmd = $History[$History.Count - $offset]
        Write-Host "Executing: $cmd" -ForegroundColor DarkGray
        return $cmd
    }
    
    # !string - Execute most recent command starting with string
    if ($Command -match '^!([a-zA-Z0-9_\-]+)(.*)$') {
        $searchString = $matches[1]
        $additionalArgs = $matches[2]
        
        # Search backwards through history
        for ($i = $History.Count - 1; $i -ge 0; $i--) {
            if ($History[$i].StartsWith($searchString)) {
                $cmd = $History[$i]
                if ($additionalArgs) {
                    $cmd = "$cmd$additionalArgs"
                }
                Write-Host "Executing: $cmd" -ForegroundColor DarkGray
                return $cmd
            }
        }
        
        Write-Host "Error: No command in history starting with '$searchString'" -ForegroundColor Red
        return ""
    }
    
    # !?string - Execute most recent command containing string
    if ($Command -match '^!\?(.+)\??$') {
        $searchString = $matches[1].TrimEnd('?')
        
        # Search backwards through history
        for ($i = $History.Count - 1; $i -ge 0; $i--) {
            if ($History[$i] -like "*$searchString*") {
                $cmd = $History[$i]
                Write-Host "Executing: $cmd" -ForegroundColor DarkGray
                return $cmd
            }
        }
        
        Write-Host "Error: No command in history containing '$searchString'" -ForegroundColor Red
        return ""
    }
    
    # ^old^new - Replace first occurrence in last command
    if ($Command -match '^\^([^^]+)\^([^^]*)\^?$') {
        if ($History.Count -eq 0) {
            Write-Host "Error: No previous command" -ForegroundColor Red
            return ""
        }
        
        $oldString = $matches[1]
        $newString = $matches[2]
        $lastCmd = $History[-1]
        
        if ($lastCmd -like "*$oldString*") {
            $expandedCmd = $lastCmd -replace [regex]::Escape($oldString), $newString
            Write-Host "Executing: $expandedCmd" -ForegroundColor DarkGray
            return $expandedCmd
        } else {
            Write-Host "Error: '$oldString' not found in last command" -ForegroundColor Red
            return ""
        }
    }
    
    # If we get here, it's an unrecognized pattern
    return $Command
}

function Show-HistoryShortcutHelp {
    Write-Host ""
    Write-Host "History Shortcuts:" -ForegroundColor Cyan
    Write-Host "==================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  !!              " -NoNewline
    Write-Host "Repeat last command" -ForegroundColor Gray
    
    Write-Host "  !! args         " -NoNewline
    Write-Host "Repeat last command with additional arguments" -ForegroundColor Gray
    
    Write-Host "  !n              " -NoNewline
    Write-Host "Execute command number n (use 'history' to see numbers)" -ForegroundColor Gray
    
    Write-Host "  !-n             " -NoNewline
    Write-Host "Execute command n positions back (!-1 = last, !-2 = second to last)" -ForegroundColor Gray
    
    Write-Host "  !string         " -NoNewline
    Write-Host "Execute most recent command starting with 'string'" -ForegroundColor Gray
    
    Write-Host "  !?string        " -NoNewline
    Write-Host "Execute most recent command containing 'string'" -ForegroundColor Gray
    
    Write-Host "  ^old^new        " -NoNewline
    Write-Host "Replace 'old' with 'new' in last command and execute" -ForegroundColor Gray
    
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  !!" -ForegroundColor Green -NoNewline
    Write-Host "                → Repeat: ls -la" -ForegroundColor DarkGray
    
    Write-Host "  !! | grep txt" -ForegroundColor Green -NoNewline
    Write-Host "   → Repeat with pipe: ls -la | grep txt" -ForegroundColor DarkGray
    
    Write-Host "  !5" -ForegroundColor Green -NoNewline
    Write-Host "                → Execute command #5 from history" -ForegroundColor DarkGray
    
    Write-Host "  !-2" -ForegroundColor Green -NoNewline
    Write-Host "               → Execute command 2 positions back" -ForegroundColor DarkGray
    
    Write-Host "  !ls" -ForegroundColor Green -NoNewline
    Write-Host "               → Execute most recent 'ls...' command" -ForegroundColor DarkGray
    
    Write-Host "  !?config" -ForegroundColor Green -NoNewline
    Write-Host "         → Execute most recent command containing 'config'" -ForegroundColor DarkGray
    
    Write-Host "  ^txt^log" -ForegroundColor Green -NoNewline
    Write-Host "         → Replace 'txt' with 'log' in last command" -ForegroundColor DarkGray
    
    Write-Host ""
}