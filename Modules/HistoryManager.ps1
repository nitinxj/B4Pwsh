# HistoryManager.ps1
# Manages command history persistence between sessions

$script:HistoryFilePath = Join-Path $env:USERPROFILE ".b4pwsh_history"
$script:MaxHistorySize = 1000

function Save-B4PwshHistory {
    param(
        [System.Collections.ArrayList]$History
    )
    
    try {
        # Keep only the last MaxHistorySize items
        $itemsToSave = if ($History.Count -gt $script:MaxHistorySize) {
            $History[($History.Count - $script:MaxHistorySize)..($History.Count - 1)]
        } else {
            $History
        }
        
        # Save to file
        $itemsToSave | Out-File -FilePath $script:HistoryFilePath -Encoding UTF8
        
    } catch {
        Write-Host "Warning: Could not save history: $_" -ForegroundColor Yellow
    }
}

function Load-B4PwshHistory {
    param(
        [System.Collections.ArrayList]$History
    )
    
    try {
        if (Test-Path $script:HistoryFilePath) {
            $lines = Get-Content -Path $script:HistoryFilePath -Encoding UTF8 -ErrorAction SilentlyContinue
            
            foreach ($line in $lines) {
                if (-not [string]::IsNullOrWhiteSpace($line)) {
                    $History.Add($line) | Out-Null
                }
            }
            
            Write-Host "Loaded $($History.Count) commands from history" -ForegroundColor Gray
        }
    } catch {
        Write-Host "Warning: Could not load history: $_" -ForegroundColor Yellow
    }
}

function Clear-B4PwshHistory {
    param(
        [System.Collections.ArrayList]$History
    )
    
    $History.Clear()
    
    try {
        if (Test-Path $script:HistoryFilePath) {
            Remove-Item -Path $script:HistoryFilePath -Force
        }
        Write-Host "History cleared" -ForegroundColor Green
    } catch {
        Write-Host "Warning: Could not clear history file: $_" -ForegroundColor Yellow
    }
}

function Get-HistoryFilePath {
    return $script:HistoryFilePath
}

function Set-MaxHistorySize {
    param(
        [int]$Size
    )
    
    if ($Size -lt 10) {
        Write-Host "History size must be at least 10" -ForegroundColor Red
        return
    }
    
    $script:MaxHistorySize = $Size
    Write-Host "Max history size set to $Size" -ForegroundColor Green
}

function Get-MaxHistorySize {
    return $script:MaxHistorySize
}