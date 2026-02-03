# InputHandler.ps1
# Handles line input with history, tab completion, and vi-style navigation

function Read-B4PwshLine {
    param(
        [string]$Prompt,
        [System.Collections.ArrayList]$History,
        [hashtable]$CommandMap,
        [bool]$ViMode = $false,
        [bool]$ShowModeIndicator = $true
    )
    
    $lineInput = ""
    $cursorPos = 0
    $historyIndex = -1
    $completionIndex = 0
    $completions = @()
    $lastCompletionInput = ""
    
    # Vi mode variables
    $viCommandMode = $false
    $viSearchMode = $false
    $viSearchPattern = ""
    $viSearchResults = @()
    $viSearchIndex = -1
    
    # Ctrl+R reverse search variables
    $reverseSearchMode = $false
    $reverseSearchPattern = ""
    $reverseSearchResults = @()
    $reverseSearchIndex = 0
    
    # Derive prompt length dynamically from whatever PS1 is set to
    $promptLength = $Prompt.Length
    
    function RedrawLine {
        param([string]$InputText, [int]$CursorPosition, [string]$ModeIndicator = "", [string]$SearchPrompt = "")
        
        $currentLine = [Console]::CursorTop
        [Console]::SetCursorPosition(0, $currentLine)
        Write-Host (' ' * [Console]::WindowWidth) -NoNewline
        [Console]::SetCursorPosition(0, $currentLine)
        
        if ($SearchPrompt) {
            Write-Host $Prompt -NoNewline -ForegroundColor Green
            if ($ShowModeIndicator) {
                Write-Host "[SEARCH] " -NoNewline -ForegroundColor Yellow
                Write-Host $SearchPrompt -NoNewline -ForegroundColor White
                [Console]::SetCursorPosition($promptLength + 9 + $SearchPrompt.Length, $currentLine)
            } else {
                Write-Host $SearchPrompt -NoNewline -ForegroundColor White
                [Console]::SetCursorPosition($promptLength + $SearchPrompt.Length, $currentLine)
            }
        } else {
            Write-Host $Prompt -NoNewline -ForegroundColor Green
            
            if ($ModeIndicator -and $ShowModeIndicator) {
                Write-Host "[$ModeIndicator] " -NoNewline -ForegroundColor Yellow
            }
            
            Write-Host $InputText -NoNewline
            
            $indicatorLength = if ($ModeIndicator -and $ShowModeIndicator) { $ModeIndicator.Length + 3 } else { 0 }
            $actualPromptLength = $promptLength + $indicatorLength
            [Console]::SetCursorPosition($actualPromptLength + $CursorPosition, $currentLine)
        }
    }
    
    function Search-History {
        param([string]$Pattern)
        
        $results = @()
        for ($i = $History.Count - 1; $i -ge 0; $i--) {
            if ($History[$i] -like "*$Pattern*") {
                $results += @{ Index = $i; Command = $History[$i] }
            }
        }
        return $results
    }
    
    $modeIndicator = ""
    RedrawLine $lineInput $cursorPos $modeIndicator
    
    while ($true) {
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            
            # Handle Ctrl+C FIRST - clear line and stay in REPL
            if ($key.Modifiers -band [ConsoleModifiers]::Control) {
                if ($key.Key -eq 'C') {
                    Write-Host ""
                    Write-Host "^C" -ForegroundColor Red
                    $lineInput = ""
                    $cursorPos = 0
                    $historyIndex = -1
                    $viCommandMode = $false
                    $viSearchMode = $false
                    $viSearchPattern = ""
                    $viSearchResults = @()
                    $viSearchIndex = -1
                    $reverseSearchMode = $false
                    $reverseSearchPattern = ""
                    $reverseSearchResults = @()
                    $reverseSearchIndex = 0
                    $modeIndicator = ""
                    RedrawLine $lineInput $cursorPos $modeIndicator
                    continue
                }
                elseif ($key.Key -eq 'R') {
                    # Ctrl+R - Enter reverse search mode
                    Write-Host ""  # Move to new line, keeping original prompt visible
                    $reverseSearchMode = $true
                    $reverseSearchPattern = ""
                    $reverseSearchResults = @()
                    $reverseSearchIndex = 0
                    $reverseSearchPrompt = "(reverse-i-search)``: "
                    
                    # Write the reverse search prompt on new line
                    Write-Host $reverseSearchPrompt -NoNewline -ForegroundColor Cyan
                    continue
                }
            }
            
            # Handle Reverse Search Mode
            if ($reverseSearchMode) {
                if ($key.Key -eq 'Enter') {
                    $reverseSearchMode = $false
                    if ($reverseSearchResults.Count -gt 0) {
                        $lineInput = $reverseSearchResults[$reverseSearchIndex]
                        $cursorPos = $lineInput.Length
                    }
                    Write-Host ""
                    [Console]::CursorLeft = 0
                    [System.Console]::Out.Flush()
                    return $lineInput
                }
                elseif ($key.Key -eq 'Escape') {
                    $reverseSearchMode = $false
                    $lineInput = ""
                    $cursorPos = 0
                    Write-Host ""
                    RedrawLine $lineInput $cursorPos $modeIndicator
                    continue
                }
                elseif ($key.Modifiers -band [ConsoleModifiers]::Control -and $key.Key -eq 'R') {
                    if ($reverseSearchResults.Count -gt 0) {
                        $reverseSearchIndex = ($reverseSearchIndex + 1) % $reverseSearchResults.Count
                        $matchedCmd = $reverseSearchResults[$reverseSearchIndex]
                        
                        $currentLine = [Console]::CursorTop
                        [Console]::SetCursorPosition(0, $currentLine)
                        Write-Host (' ' * [Console]::WindowWidth) -NoNewline
                        [Console]::SetCursorPosition(0, $currentLine)
                        
                        $reverseSearchPrompt = "(reverse-i-search)``$reverseSearchPattern': $matchedCmd"
                        Write-Host $reverseSearchPrompt -NoNewline -ForegroundColor Cyan
                    }
                    continue
                }
                elseif ($key.Key -eq 'Backspace') {
                    if ($reverseSearchPattern.Length -gt 0) {
                        $reverseSearchPattern = $reverseSearchPattern.Substring(0, $reverseSearchPattern.Length - 1)
                        
                        $reverseSearchResults = @()
                        $reverseSearchIndex = 0
                        
                        if ($reverseSearchPattern.Length -gt 0) {
                            for ($i = $History.Count - 1; $i -ge 0; $i--) {
                                if ($History[$i] -like "*$reverseSearchPattern*") {
                                    $reverseSearchResults += $History[$i]
                                }
                            }
                        }
                        
                        $currentLine = [Console]::CursorTop
                        [Console]::SetCursorPosition(0, $currentLine)
                        Write-Host (' ' * [Console]::WindowWidth) -NoNewline
                        [Console]::SetCursorPosition(0, $currentLine)
                        
                        if ($reverseSearchResults.Count -gt 0) {
                            $matchedCmd = $reverseSearchResults[0]
                            $reverseSearchPrompt = "(reverse-i-search)``$reverseSearchPattern': $matchedCmd"
                            Write-Host $reverseSearchPrompt -NoNewline -ForegroundColor Cyan
                        } else {
                            $reverseSearchPrompt = "(reverse-i-search)``$reverseSearchPattern': "
                            Write-Host $reverseSearchPrompt -NoNewline -ForegroundColor Cyan
                        }
                    }
                    continue
                }
                elseif ($key.KeyChar -ge 32 -and $key.KeyChar -le 126) {
                    $reverseSearchPattern += $key.KeyChar
                    
                    $reverseSearchResults = @()
                    $reverseSearchIndex = 0
                    
                    for ($i = $History.Count - 1; $i -ge 0; $i--) {
                        if ($History[$i] -like "*$reverseSearchPattern*") {
                            $reverseSearchResults += $History[$i]
                        }
                    }
                    
                    $currentLine = [Console]::CursorTop
                    [Console]::SetCursorPosition(0, $currentLine)
                    Write-Host (' ' * [Console]::WindowWidth) -NoNewline
                    [Console]::SetCursorPosition(0, $currentLine)
                    
                    if ($reverseSearchResults.Count -gt 0) {
                        $matchedCmd = $reverseSearchResults[0]
                        $reverseSearchPrompt = "(reverse-i-search)``$reverseSearchPattern': $matchedCmd"
                        Write-Host $reverseSearchPrompt -NoNewline -ForegroundColor Cyan
                    } else {
                        $reverseSearchPrompt = "(failed reverse-i-search)``$reverseSearchPattern': "
                        Write-Host $reverseSearchPrompt -NoNewline -ForegroundColor Red
                    }
                    continue
                }
            }
            
            # Handle Vi search mode
            if ($viSearchMode) {
                $searchPrompt = "/$viSearchPattern"
                
                if ($key.Key -eq 'Enter') {
                    $viSearchMode = $false
                    $viSearchResults = Search-History $viSearchPattern
                    if ($viSearchResults.Count -gt 0) {
                        $viSearchIndex = 0
                        $lineInput = $viSearchResults[0].Command
                        $historyIndex = $History.Count - 1 - $viSearchResults[0].Index
                        $cursorPos = 0
                    }
                    $modeIndicator = "CMD"
                    RedrawLine $lineInput $cursorPos $modeIndicator
                    continue
                }
                elseif ($key.Key -eq 'Backspace') {
                    if ($viSearchPattern.Length -gt 0) {
                        $viSearchPattern = $viSearchPattern.Substring(0, $viSearchPattern.Length - 1)
                        $searchPrompt = "/$viSearchPattern"
                        RedrawLine "" 0 "" $searchPrompt
                    }
                    continue
                }
                elseif ($key.KeyChar -ge 32 -and $key.KeyChar -le 126) {
                    $viSearchPattern += $key.KeyChar
                    $searchPrompt = "/$viSearchPattern"
                    RedrawLine "" 0 "" $searchPrompt
                    continue
                }
            }
            
            # Handle Escape key for Vi mode BEFORE checking command mode
            if ($key.Key -eq 'Escape') {
                if ($ViMode) {
                    if ($viSearchMode) {
                        $viSearchMode = $false
                        $viSearchPattern = ""
                        $viSearchResults = @()
                        $viSearchIndex = -1
                        $modeIndicator = "CMD"
                        RedrawLine $lineInput $cursorPos $modeIndicator
                        continue
                    }
                    if (-not $viCommandMode) {
                        $viCommandMode = $true
                        $modeIndicator = "CMD"
                        if ($cursorPos -ge $lineInput.Length -and $lineInput.Length -gt 0) {
                            $cursorPos = $lineInput.Length - 1
                        }
                        RedrawLine $lineInput $cursorPos $modeIndicator
                        continue
                    }
                }
            }
            
            # Handle Vi command mode
            if ($viCommandMode -and $ViMode) {
                if ($key.Key -eq 'Enter') {
                    Write-Host ""
                    [Console]::CursorLeft = 0
                    [System.Console]::Out.Flush()
                    return $lineInput
                }
                elseif ($key.KeyChar -ceq 'i') {
                    $viCommandMode = $false
                    $modeIndicator = ""
                    RedrawLine $lineInput $cursorPos $modeIndicator
                    continue
                }
                elseif ($key.KeyChar -ceq 'a') {
                    $viCommandMode = $false
                    $modeIndicator = ""
                    if ($cursorPos -lt $lineInput.Length) {
                        $cursorPos++
                    }
                    RedrawLine $lineInput $cursorPos $modeIndicator
                    continue
                }
                elseif ($key.KeyChar -ceq 'A') {
                    $viCommandMode = $false
                    $modeIndicator = ""
                    $cursorPos = $lineInput.Length
                    RedrawLine $lineInput $cursorPos $modeIndicator
                    continue
                }
                elseif ($key.KeyChar -ceq 'h') {
                    if ($cursorPos -gt 0) {
                        $cursorPos--
                        RedrawLine $lineInput $cursorPos $modeIndicator
                    }
                    continue
                }
                elseif ($key.Key -eq 'LeftArrow') {
                    if ($cursorPos -gt 0) {
                        $cursorPos--
                        RedrawLine $lineInput $cursorPos $modeIndicator
                    }
                    continue
                }
                elseif ($key.KeyChar -ceq 'l') {
                    if ($cursorPos -lt $lineInput.Length - 1) {
                        $cursorPos++
                        RedrawLine $lineInput $cursorPos $modeIndicator
                    }
                    continue
                }
                elseif ($key.Key -eq 'RightArrow') {
                    if ($cursorPos -lt $lineInput.Length - 1) {
                        $cursorPos++
                        RedrawLine $lineInput $cursorPos $modeIndicator
                    }
                    continue
                }
                elseif ($key.KeyChar -eq '0') {
                    $cursorPos = 0
                    RedrawLine $lineInput $cursorPos $modeIndicator
                    continue
                }
                elseif ($key.KeyChar -eq '$') {
                    $cursorPos = if ($lineInput.Length -gt 0) { $lineInput.Length - 1 } else { 0 }
                    RedrawLine $lineInput $cursorPos $modeIndicator
                    continue
                }
                elseif ($key.KeyChar -eq 'w') {
                    $pos = $cursorPos
                    while ($pos -lt $lineInput.Length -and $lineInput[$pos] -match '\S') {
                        $pos++
                    }
                    while ($pos -lt $lineInput.Length -and $lineInput[$pos] -match '\s') {
                        $pos++
                    }
                    $cursorPos = if ($pos -ge $lineInput.Length) { 
                        if ($lineInput.Length -gt 0) { $lineInput.Length - 1 } else { 0 }
                    } else { $pos }
                    RedrawLine $lineInput $cursorPos $modeIndicator
                    continue
                }
                elseif ($key.KeyChar -eq 'b') {
                    if ($cursorPos -gt 0) {
                        $pos = $cursorPos - 1
                        while ($pos -gt 0 -and $lineInput[$pos] -match '\s') {
                            $pos--
                        }
                        while ($pos -gt 0 -and $lineInput[$pos - 1] -match '\S') {
                            $pos--
                        }
                        $cursorPos = $pos
                        RedrawLine $lineInput $cursorPos $modeIndicator
                    }
                    continue
                }
                elseif ($key.KeyChar -eq 'x') {
                    if ($lineInput.Length -gt 0 -and $cursorPos -lt $lineInput.Length) {
                        $lineInput = $lineInput.Substring(0, $cursorPos) + $lineInput.Substring($cursorPos + 1)
                        if ($cursorPos -ge $lineInput.Length -and $lineInput.Length -gt 0) {
                            $cursorPos = $lineInput.Length - 1
                        }
                        RedrawLine $lineInput $cursorPos $modeIndicator
                    }
                    continue
                }
                elseif ($key.KeyChar -eq 'd') {
                    $startTime = [DateTime]::Now
                    while (-not [Console]::KeyAvailable -and ([DateTime]::Now - $startTime).TotalMilliseconds -lt 500) {
                        Start-Sleep -Milliseconds 10
                    }
                    if ([Console]::KeyAvailable) {
                        $nextKey = [Console]::ReadKey($true)
                        if ($nextKey.KeyChar -eq 'd') {
                            $lineInput = ""
                            $cursorPos = 0
                            RedrawLine $lineInput $cursorPos $modeIndicator
                        }
                        elseif ($nextKey.KeyChar -ceq 'w') {
                            $pos = $cursorPos
                            while ($pos -lt $lineInput.Length -and $lineInput[$pos] -match '\S') {
                                $pos++
                            }
                            while ($pos -lt $lineInput.Length -and $lineInput[$pos] -match '\s') {
                                $pos++
                            }
                            $lineInput = $lineInput.Substring(0, $cursorPos) + $lineInput.Substring($pos)
                            if ($cursorPos -ge $lineInput.Length -and $lineInput.Length -gt 0) {
                                $cursorPos = $lineInput.Length - 1
                            }
                            RedrawLine $lineInput $cursorPos $modeIndicator
                        }
                    }
                    continue
                }
                elseif ($key.KeyChar -eq 'c') {
                    $startTime = [DateTime]::Now
                    while (-not [Console]::KeyAvailable -and ([DateTime]::Now - $startTime).TotalMilliseconds -lt 500) {
                        Start-Sleep -Milliseconds 10
                    }
                    if ([Console]::KeyAvailable) {
                        $nextKey = [Console]::ReadKey($true)
                        if ($nextKey.KeyChar -eq 'w') {
                            $pos = $cursorPos
                            while ($pos -lt $lineInput.Length -and $lineInput[$pos] -match '\S') {
                                $pos++
                            }
                            $lineInput = $lineInput.Substring(0, $cursorPos) + $lineInput.Substring($pos)
                            $viCommandMode = $false
                            $modeIndicator = ""
                            RedrawLine $lineInput $cursorPos $modeIndicator
                        }
                    }
                    continue
                }
                elseif ($key.KeyChar -ceq 'k') {
                    if ($History.Count -gt 0 -and $historyIndex -lt $History.Count - 1) {
                        $historyIndex++
                        $lineInput = $History[$History.Count - 1 - $historyIndex]
                        $cursorPos = 0
                        RedrawLine $lineInput $cursorPos $modeIndicator
                    }
                    continue
                }
                elseif ($key.Key -eq 'UpArrow') {
                    if ($History.Count -gt 0 -and $historyIndex -lt $History.Count - 1) {
                        $historyIndex++
                        $lineInput = $History[$History.Count - 1 - $historyIndex]
                        $cursorPos = 0
                        RedrawLine $lineInput $cursorPos $modeIndicator
                    }
                    continue
                }
                elseif ($key.KeyChar -ceq 'j') {
                    if ($historyIndex -gt 0) {
                        $historyIndex--
                        $lineInput = $History[$History.Count - 1 - $historyIndex]
                        $cursorPos = 0
                        RedrawLine $lineInput $cursorPos $modeIndicator
                    } elseif ($historyIndex -eq 0) {
                        $historyIndex = -1
                        $lineInput = ""
                        $cursorPos = 0
                        RedrawLine $lineInput $cursorPos $modeIndicator
                    }
                    continue
                }
                elseif ($key.Key -eq 'DownArrow') {
                    if ($historyIndex -gt 0) {
                        $historyIndex--
                        $lineInput = $History[$History.Count - 1 - $historyIndex]
                        $cursorPos = 0
                        RedrawLine $lineInput $cursorPos $modeIndicator
                    } elseif ($historyIndex -eq 0) {
                        $historyIndex = -1
                        $lineInput = ""
                        $cursorPos = 0
                        RedrawLine $lineInput $cursorPos $modeIndicator
                    }
                    continue
                }
                elseif ($key.KeyChar -ceq '/') {
                    $viSearchMode = $true
                    $viSearchPattern = ""
                    $viSearchResults = @()
                    $viSearchIndex = -1
                    $searchPrompt = "/"
                    RedrawLine "" 0 "" $searchPrompt
                    continue
                }
                elseif ($key.KeyChar -ceq 'n') {
                    if ($viSearchResults.Count -gt 0) {
                        $viSearchIndex = ($viSearchIndex + 1) % $viSearchResults.Count
                        $lineInput = $viSearchResults[$viSearchIndex].Command
                        $historyIndex = $History.Count - 1 - $viSearchResults[$viSearchIndex].Index
                        $cursorPos = 0
                        RedrawLine $lineInput $cursorPos $modeIndicator
                    }
                    continue
                }
                elseif ($key.KeyChar -ceq 'N') {
                    if ($viSearchResults.Count -gt 0) {
                        $viSearchIndex--
                        if ($viSearchIndex -lt 0) {
                            $viSearchIndex = $viSearchResults.Count - 1
                        }
                        $lineInput = $viSearchResults[$viSearchIndex].Command
                        $historyIndex = $History.Count - 1 - $viSearchResults[$viSearchIndex].Index
                        $cursorPos = 0
                        RedrawLine $lineInput $cursorPos $modeIndicator
                    }
                    continue
                }
                continue
            }
            
            # Standard insert mode handling
            if ($key.Key -eq 'Enter') {
                Write-Host ""
                [Console]::CursorLeft = 0
                [System.Console]::Out.Flush()
                return $lineInput
            }
            elseif ($key.Key -eq 'Tab') {
                $tokens = $lineInput -split '\s+'
                $lastWord = if ($tokens.Count -gt 0) { $tokens[-1] } else { "" }
                
                if ($lineInput -ne $lastCompletionInput) {
                    $completions = Get-BashCompletion -Word $lastWord -IsFirstWord ($tokens.Count -eq 1) -CommandMap $CommandMap
                    $completionIndex = 0
                    $lastCompletionInput = $lineInput
                } else {
                    if ($completions.Count -gt 0) {
                        $completionIndex = ($completionIndex + 1) % $completions.Count
                    }
                }
                
                if ($completions.Count -gt 0) {
                    $prefix = if ($tokens.Count -gt 1) {
                        ($tokens[0..($tokens.Count - 2)] -join ' ') + ' '
                    } else { "" }
                    
                    $completion = $completions[$completionIndex]
                    $lineInput = $prefix + $completion
                    $lastCompletionInput = $lineInput
                    $cursorPos = $lineInput.Length
                    
                    RedrawLine $lineInput $cursorPos $modeIndicator
                    
                    if ($completions.Count -gt 1) {
                        $curLine = [Console]::CursorTop
                        $curCol = [Console]::CursorLeft
                        Write-Host " [$($completionIndex + 1)/$($completions.Count)]" -ForegroundColor DarkGray -NoNewline
                        [Console]::SetCursorPosition($curCol, $curLine)
                    }
                }
            }
            elseif ($key.Key -eq 'UpArrow') {
                $completions = @()
                $lastCompletionInput = ""
                if ($History.Count -gt 0 -and $historyIndex -lt $History.Count - 1) {
                    $historyIndex++
                    $lineInput = $History[$History.Count - 1 - $historyIndex]
                    $cursorPos = $lineInput.Length
                    RedrawLine $lineInput $cursorPos $modeIndicator
                }
            }
            elseif ($key.Key -eq 'DownArrow') {
                $completions = @()
                $lastCompletionInput = ""
                if ($historyIndex -gt 0) {
                    $historyIndex--
                    $lineInput = $History[$History.Count - 1 - $historyIndex]
                    $cursorPos = $lineInput.Length
                    RedrawLine $lineInput $cursorPos $modeIndicator
                } elseif ($historyIndex -eq 0) {
                    $historyIndex = -1
                    $lineInput = ""
                    $cursorPos = 0
                    RedrawLine $lineInput $cursorPos $modeIndicator
                }
            }
            elseif ($key.Key -eq 'Backspace') {
                $completions = @()
                $lastCompletionInput = ""
                if ($cursorPos -gt 0) {
                    $lineInput = $lineInput.Substring(0, $cursorPos - 1) + $lineInput.Substring($cursorPos)
                    $cursorPos--
                    RedrawLine $lineInput $cursorPos $modeIndicator
                }
            }
            elseif ($key.KeyChar -ge 32 -and $key.KeyChar -le 126) {
                $completions = @()
                $lastCompletionInput = ""
                $lineInput = $lineInput.Substring(0, $cursorPos) + $key.KeyChar + $lineInput.Substring($cursorPos)
                $cursorPos++
                RedrawLine $lineInput $cursorPos $modeIndicator
            }
        }
    }
}