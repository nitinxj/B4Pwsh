# BashParser.ps1
# Parses and translates bash commands to PowerShell

. "$PSScriptRoot\BashCommand.ps1"

class BashParser {
    [hashtable] $CommandMap
    
    BashParser() {
        $this.CommandMap = @{
            'ls'     = 'Get-ChildItem'
            'll'     = 'Get-ChildItem'
            'pwd'    = 'Get-Location'
            'cd'     = 'Set-Location'
            'cat'    = 'Get-Content'
            'rm'     = 'Remove-Item'
            'cp'     = 'Copy-Item'
            'mv'     = 'Move-Item'
            'mkdir'  = 'New-Item'
            'touch'  = 'New-Item'
            'clear'  = 'Clear-Host'
            'ps'     = 'Get-Process'
            'kill'   = 'Stop-Process'
            'echo'   = 'Write-Output'
            'which'  = 'Get-Command'
            'grep'   = 'Select-String'
            'sort'   = 'Sort-Object'
            'head'   = 'Select-Object'
            'tail'   = 'Select-Object'
            'wc'     = 'Measure-Object'
            'uniq'   = 'Get-Unique'
            'export' = '__EXPORT__'
            'env'    = 'Get-ChildItem Env:'
            'more'   = '__MORE__'
            'bhelp'  = '__BHELP__'
            'phelp'  = '__PHELP__'
            'help'   = '__HELP__'
        }
    }
    
    [BashCommand] Parse([string]$inputBash) {
        $cmd = [BashCommand]::new()
        $cmd.Original = $inputBash
        
        # Don't process redirects for export commands
        if (-not $inputBash.StartsWith('export')) {
            $redirectMatch = [regex]::Match($inputBash, '>>?\s*([^\s|]+)')
            if ($redirectMatch.Success) {
                $cmd.OutputFile = $redirectMatch.Groups[1].Value
                $cmd.AppendOutput = $inputBash.Contains('>>')
                $inputBash = $inputBash.Substring(0, $redirectMatch.Index).Trim()
            }
        }
        
        $cmd.PipeCommands = $this.SplitByPipe($inputBash)
        
        if ($cmd.PipeCommands.Count -gt 0) {
            $tokens = $this.Tokenize($cmd.PipeCommands[0])
            if ($tokens.Count -gt 0) {
                $cmd.Command = $tokens[0]
                if ($tokens.Count -gt 1) {
                    $cmd.Args = $tokens[1..($tokens.Count - 1)]
                }
            }
        }
        return $cmd
    }
    
    [string[]] SplitByPipe([string]$inputBash) {
        $segments = @()
        $current = ""
        $inQuote = $false
        $quoteChar = ""
        
        for ($i = 0; $i -lt $inputBash.Length; $i++) {
            $char = $inputBash[$i]
            
            if (($char -eq '"' -or $char -eq "'") -and -not $inQuote) {
                $inQuote = $true
                $quoteChar = $char
                $current += $char
                continue
            }
            
            if ($char -eq $quoteChar -and $inQuote) {
                $inQuote = $false
                $current += $char
                $quoteChar = ""
                continue
            }
            
            if ($char -eq '|' -and -not $inQuote) {
                if ($current.Trim()) {
                    $segments += $current.Trim()
                    $current = ""
                }
                continue
            }
            
            $current += $char
        }
        
        if ($current.Trim()) {
            $segments += $current.Trim()
        }
        
        return $segments
    }
    
    [string[]] Tokenize([string]$inputBash) {
        $tokens = @()
        $current = ""
        $inQuote = $false
        $quoteChar = ""
        
        for ($i = 0; $i -lt $inputBash.Length; $i++) {
            $char = $inputBash[$i]
            
            if (($char -eq '"' -or $char -eq "'") -and -not $inQuote) {
                $inQuote = $true
                $quoteChar = $char
                $current += $char
                continue
            }
            
            if ($char -eq $quoteChar -and $inQuote) {
                $inQuote = $false
                $current += $char
                $quoteChar = ""
                continue
            }
            
            if ($char -eq ' ' -and -not $inQuote) {
                if ($current) {
                    $tokens += $current
                    $current = ""
                }
                continue
            }
            
            $current += $char
        }
        
        if ($current) {
            $tokens += $current
        }
        
        return $tokens
    }
    
    [string] TranslateCommand([string]$cmdString, [bool]$afterFileCmd, [bool]$afterPsCmd, [bool]$inPipeline) {
        $tokens = $this.Tokenize($cmdString)
        if ($tokens.Count -eq 0) {
            return ""
        }
        
        $cmdName = $tokens[0]
        $cmdArgs = @()
        if ($tokens.Count -gt 1) {
            $cmdArgs = $tokens[1..($tokens.Count - 1)]
        }
        
        if (-not $this.CommandMap.ContainsKey($cmdName)) {
            return $cmdString
        }
        
        $pwshCmd = $this.CommandMap[$cmdName]
        
        # Handle more
        if ($cmdName -eq 'more') {
            if ($cmdArgs.Count -gt 0) {
                $files = $cmdArgs | ForEach-Object { $_.Trim("'", '"') }
                return "Get-Content " + ($files -join ' ') + " | Out-Host -Paging"
            }
            return 'Out-Host -Paging'
        }
        
        # Handle bhelp
        if ($cmdName -eq 'bhelp') {
            if ($cmdArgs.Count -gt 0 -and $cmdArgs[0] -eq 'history') {
                return 'Show-HistoryShortcutHelp'
            }
            elseif ($cmdArgs.Count -gt 0 -and $cmdArgs[0] -eq 'profile') {
                return 'Show-B4PwshProfileHelp'
            }
            return 'Show-B4PwshHelp'
        }
        
        # Handle phelp
        if ($cmdName -eq 'phelp') {
            if ($cmdArgs.Count -gt 0) {
                $allArgs = $cmdArgs -join ' '
                return "Get-Help $allArgs"
            }
            return 'Get-Help'
        }
        
        # Handle help (routes based on config)
        if ($cmdName -eq 'help') {
            return 'Invoke-B4PwshHelp ' + ($cmdArgs -join ' ')
        }
        
        # Handle env
        if ($cmdName -eq 'env') {
            return 'Get-ChildItem Env:'
        }
        
        # Handle grep
        if ($cmdName -eq 'grep') {
            $pattern = ""
            $caseInsensitive = $false
            
            foreach ($arg in $cmdArgs) {
                if ($arg -eq '-i') {
                    $caseInsensitive = $true
                }
                elseif ($arg -notmatch '^-') {
                    $pattern = $arg.Trim("'", '"')
                }
            }
            
            if (-not $pattern) {
                return $pwshCmd
            }
            
            if ($afterFileCmd) {
                if ($caseInsensitive) {
                    return "Where-Object { `$_.Name -like '*$pattern*' } | ForEach-Object { `$_.FullName }"
                }
                else {
                    return "Where-Object { `$_.Name -clike '*$pattern*' } | ForEach-Object { `$_.FullName }"
                }
            }
            elseif ($inPipeline) {
                return "Select-String -InputObject `$_ -Pattern '$pattern'"
            }
            else {
                return "$pwshCmd -Pattern '$pattern'"
            }

            
            if ($afterPsCmd) {
                $dollarUnderscore = '$_'
                if ($caseInsensitive) {
                    return "Where-Object { $dollarUnderscore.ProcessName -like '*$pattern*' }"
                }
                else {
                    return "Where-Object { $dollarUnderscore.ProcessName -clike '*$pattern*' }"
                }
            }
            
            return "$pwshCmd -Pattern '$pattern'"
        }
        
        # Handle ps
        if ($cmdName -eq 'ps') {
            $hasEF = $false
            $otherArgs = @()
            
            foreach ($arg in $cmdArgs) {
                if ($arg -eq '-ef') {
                    $hasEF = $true
                }
                elseif ($arg -eq '-e' -or $arg -eq '-f') {
                    $hasEF = $true
                }
                else {
                    $otherArgs += $arg
                }
            }
            
            if ($inPipeline) {
                if ($otherArgs.Count -gt 0) {
                    return "$pwshCmd " + ($otherArgs -join ' ')
                }
                else {
                    return $pwshCmd
                }
            }
            else {
                if ($hasEF) {
                    return "$pwshCmd | Format-Table -Property Id,ProcessName,CPU,WS,StartTime,Path -AutoSize"
                }
                elseif ($otherArgs.Count -gt 0) {
                    return "$pwshCmd " + ($otherArgs -join ' ') + " | Format-Table -Property Id,ProcessName,CPU,WS -AutoSize"
                }
                else {
                    return "$pwshCmd | Format-Table -Property Id,ProcessName,CPU,WS -AutoSize"
                }
            }
        }
        
        # Handle ls
        if ($cmdName -eq 'ls' -or $cmdName -eq 'll') {
            $hasForce = $false
            $hasRecurse = $false
            $sortByTime = $false
            $reverseOrder = $false
            $paths = @()
            
            foreach ($arg in $cmdArgs) {
                if ($arg -eq '-R') {
                    $hasRecurse = $true
                }
                elseif ($arg -match '^-[altr]+$') {
                    if ($arg -match 'a' -or $arg -match 'l') {
                        $hasForce = $true
                    }
                    if ($arg -match 't') {
                        $sortByTime = $true
                    }
                    if ($arg -match 'r') {
                        $reverseOrder = $true
                    }
                }
                elseif ($arg -notmatch '^-') {
                    $paths += $arg.Trim("'", '"')
                }
            }
            
            if ($cmdName -eq 'll') {
                $hasForce = $true
            }
            
            $lsResult = $pwshCmd
            if ($hasForce) {
                $lsResult += " -Force"
            }
            if ($hasRecurse) {
                $lsResult += " -Recurse"
            }
            if ($paths.Count -gt 0) {
                $lsResult += " " + ($paths -join ' ')
            }
            
            if ($sortByTime -and $reverseOrder) {
                $lsResult += " | Sort-Object LastWriteTime"
            }
            elseif ($sortByTime) {
                $lsResult += " | Sort-Object LastWriteTime -Descending"
            }
            elseif ($reverseOrder) {
                $lsResult += " | Sort-Object Name -Descending"
            }
            
            if (-not $inPipeline) {
                $lsResult += " | Format-Table -AutoSize"
            }
            
            return $lsResult
        }
        
        # Handle head
        if ($cmdName -eq 'head') {
            $n = 10
            if ($cmdArgs.Count -gt 0 -and $cmdArgs[0] -match '^-(\d+)$') {
                $n = $matches[1]
            }
            return "$pwshCmd -First $n"
        }
        
        # Handle tail
        if ($cmdName -eq 'tail') {
            $n = 10
            if ($cmdArgs.Count -gt 0 -and $cmdArgs[0] -match '^-(\d+)$') {
                $n = $matches[1]
            }
            return "$pwshCmd -Last $n"
        }
        
        # Default handling
        $allArgs = $cmdArgs -join ' '
        if ($allArgs) {
            return "$pwshCmd $allArgs"
        }
        return $pwshCmd
    }
    
    [string] Translate([BashCommand]$cmd) {
        $result = ""
        
        # Handle export command specially
        if ($cmd.Command -eq 'export') {
            return $this.TranslateExport($cmd)
        }
        
        # Handle help commands specially
        if ($cmd.Command -eq 'bhelp') {
            if ($cmd.Args.Count -gt 0 -and $cmd.Args[0] -eq 'history') {
                return 'Show-HistoryShortcutHelp'
            }
            elseif ($cmd.Args.Count -gt 0 -and $cmd.Args[0] -eq 'profile') {
                return 'Show-B4PwshProfileHelp'
            }
            return 'Show-B4PwshHelp'
        }
        
        if ($cmd.Command -eq 'phelp') {
            if ($cmd.Args.Count -gt 0) {
                $allArgs = $cmd.Args -join ' '
                return "Get-Help $allArgs"
            }
            return 'Get-Help'
        }
        
        if ($cmd.Command -eq 'help') {
            return 'Invoke-B4PwshHelp ' + ($cmd.Args -join ' ')
        }
        
        # Handle more command specially
        if ($cmd.Command -eq 'more') {
            if ($cmd.Args.Count -gt 0) {
                $files = $cmd.Args | ForEach-Object { $_.Trim("'", '"') }
                return "Get-Content " + ($files -join ' ') + " | Out-Host -Paging"
            }
            return 'Out-Host -Paging'
        }
        
        if ($cmd.PipeCommands.Count -gt 1) {
            $pipeline = @()
            $afterFileCmd = $false
            $afterPsCmd = $false
            $inPipeline = $true
            
            for ($i = 0; $i -lt $cmd.PipeCommands.Count; $i++) {
                $pipeCmd = $cmd.PipeCommands[$i]
                
                $translated = $this.TranslateCommand($pipeCmd, $afterFileCmd, $afterPsCmd, $inPipeline)
                $pipeline += $translated
                
                $trimmedCmd = $pipeCmd.Trim()
                $isFileCmd = $trimmedCmd -match '^(ls|ll)(\s|$)'
                if ($isFileCmd) {
                    $afterFileCmd = $true
                }
                
                $isPsCmd = $trimmedCmd.StartsWith('ps')
                if ($isPsCmd) {
                    $afterPsCmd = $true
                }
            }
            
            $result = $pipeline -join ' | '
        }
        else {
            if (-not $this.CommandMap.ContainsKey($cmd.Command)) {
                $result = $cmd.Original
            }
            else {
                $pwshCmd = $this.CommandMap[$cmd.Command]
                
                if ($cmd.Command -eq 'env') {
                    $result = 'Get-ChildItem Env:'
                }
                elseif ($cmd.Command -eq 'bhelp') {
                    if ($cmd.Args.Count -gt 0 -and $cmd.Args[0] -eq 'history') {
                        $result = 'Show-HistoryShortcutHelp'
                    }
                    elseif ($cmd.Args.Count -gt 0 -and $cmd.Args[0] -eq 'profile') {
                        $result = 'Show-B4PwshProfileHelp'
                    }
                    else {
                        $result = 'Show-B4PwshHelp'
                    }
                }
                elseif ($cmd.Command -eq 'phelp') {
                    if ($cmd.Args.Count -gt 0) {
                        $allArgs = $cmd.Args -join ' '
                        $result = "Get-Help $allArgs"
                    }
                    else {
                        $result = 'Get-Help'
                    }
                }
                elseif ($cmd.Command -eq 'help') {
                    $result = 'Invoke-B4PwshHelp ' + ($cmd.Args -join ' ')
                }
                elseif ($cmd.Command -eq 'more') {
                    if ($cmd.Args.Count -gt 0) {
                        $files = $cmd.Args | ForEach-Object { $_.Trim("'", '"') }
                        $result = "Get-Content " + ($files -join ' ') + " | Out-Host -Paging"
                    }
                    else {
                        $result = 'Out-Host -Paging'
                    }
                }
                elseif ($cmd.Command -eq 'ls' -or $cmd.Command -eq 'll') {
                    $hasForce = $false
                    $hasRecurse = $false
                    $sortByTime = $false
                    $reverseOrder = $false
                    $paths = @()
                    
                    foreach ($arg in $cmd.Args) {
                        if ($arg -eq '-R') {
                            $hasRecurse = $true
                        }
                        elseif ($arg -match '^-[altr]+$') {
                            if ($arg -match 'a' -or $arg -match 'l') {
                                $hasForce = $true
                            }
                            if ($arg -match 't') {
                                $sortByTime = $true
                            }
                            if ($arg -match 'r') {
                                $reverseOrder = $true
                            }
                        }
                        elseif ($arg -notmatch '^-') {
                            $paths += $arg.Trim("'", '"')
                        }
                    }
                    
                    if ($cmd.Command -eq 'll') {
                        $hasForce = $true
                    }
                    
                    $result = $pwshCmd
                    if ($hasForce) {
                        $result += " -Force"
                    }
                    if ($hasRecurse) {
                        $result += " -Recurse"
                    }
                    if ($paths.Count -gt 0) {
                        $result += " " + ($paths -join ' ')
                    }
                    
                    if ($sortByTime -and $reverseOrder) {
                        $result += " | Sort-Object LastWriteTime"
                    }
                    elseif ($sortByTime) {
                        $result += " | Sort-Object LastWriteTime -Descending"
                    }
                    elseif ($reverseOrder) {
                        $result += " | Sort-Object Name -Descending"
                    }
                    
                    $result += " | Format-Table -AutoSize"
                }
                elseif ($cmd.Command -eq 'ps') {
                    $hasEF = $false
                    $otherArgs = @()
                    
                    foreach ($arg in $cmd.Args) {
                        if ($arg -eq '-ef') {
                            $hasEF = $true
                        }
                        elseif ($arg -eq '-e' -or $arg -eq '-f') {
                            $hasEF = $true
                        }
                        else {
                            $otherArgs += $arg
                        }
                    }
                    
                    if ($hasEF) {
                        $result = "$pwshCmd | Format-Table -Property Id,ProcessName,CPU,WS,StartTime,Path -AutoSize"
                    }
                    elseif ($otherArgs.Count -gt 0) {
                        $result = "$pwshCmd " + ($otherArgs -join ' ') + " | Format-Table -Property Id,ProcessName,CPU,WS -AutoSize"
                    }
                    else {
                        $result = "$pwshCmd | Format-Table -Property Id,ProcessName,CPU,WS -AutoSize"
                    }
                }
                elseif ($cmd.Command -eq 'rm') {
                    $hasRecurse = $false
                    $hasForce = $false
                    $paths = @()
                    
                    foreach ($arg in $cmd.Args) {
                        if ($arg -match '^-[rf]+$') {
                            $hasRecurse = $true
                            $hasForce = $true
                        }
                        elseif ($arg -notmatch '^-') {
                            $paths += $arg.Trim("'", '"')
                        }
                    }
                    
                    $result = $pwshCmd
                    if ($hasRecurse) {
                        $result += " -Recurse"
                    }
                    if ($hasForce) {
                        $result += " -Force"
                    }
                    if ($paths.Count -gt 0) {
                        $result += " " + ($paths -join ' ')
                    }
                }
                elseif ($cmd.Command -eq 'cd') {
                    if ($cmd.Args.Count -eq 0) {
                        $result = "$pwshCmd ~"
                    }
                    else {
                        $result = "$pwshCmd " + $cmd.Args[0].Trim("'", '"')
                    }
                }
                elseif ($cmd.Command -eq 'mkdir') {
                    if ($cmd.Args.Count -gt 0) {
                        $path = $cmd.Args[0].Trim("'", '"')
                        $result = "$pwshCmd -ItemType Directory -Path $path"
                    }
                    else {
                        $result = "$pwshCmd -ItemType Directory"
                    }
                }
                elseif ($cmd.Command -eq 'touch') {
                    if ($cmd.Args.Count -gt 0) {
                        $path = $cmd.Args[0].Trim("'", '"')
                        $result = "$pwshCmd -ItemType File -Path $path"
                    }
                    else {
                        $result = "$pwshCmd -ItemType File"
                    }
                }
                elseif ($cmd.Command -eq 'cat') {
                    if ($cmd.Args.Count -gt 0) {
                        $paths = @()
                        foreach ($arg in $cmd.Args) {
                            $paths += $arg.Trim("'", '"')
                        }
                        $result = "$pwshCmd " + ($paths -join ' ')
                    }
                    else {
                        $result = $pwshCmd
                    }
                }
                else {
                    $allArgs = $cmd.Args -join ' '
                    if ($allArgs) {
                        $result = "$pwshCmd $allArgs"
                    }
                    else {
                        $result = $pwshCmd
                    }
                }
            }
        }
        
        if ($cmd.OutputFile) {
            if ($cmd.AppendOutput) {
                $result += " | Out-File -Append -FilePath $($cmd.OutputFile)"
            }
            else {
                $result += " | Out-File -FilePath $($cmd.OutputFile)"
            }
        }
        
        return $result
    }
    
    [string] TranslateExport([BashCommand]$cmd) {
        # No args — show all env vars
        if ($cmd.Args.Count -eq 0) {
            return "Get-ChildItem Env:"
        }
        
        $exports = @()
        
        foreach ($arg in $cmd.Args) {
            if ($arg -match '^([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
                $varName = $matches[1]
                $varValue = $matches[2].Trim("'", '"')
                
                # PATH append: export PATH=$PATH:/new/path
                if ($varName -eq 'PATH' -and $varValue -match '^\$PATH[:/](.+)$') {
                    $newPath = $matches[1]
                    $newPath = $newPath -replace ':', ';'
                    $newPath = $newPath -replace '/', '\'
                    $newPath = $this.ExpandBashVariables($newPath)
                    $exports += 'Set-Item -Path Env:PATH -Value ($env:PATH + ";" + "' + $newPath + '")'
                }
                # PATH prepend: export PATH=/new/path:$PATH
                elseif ($varName -eq 'PATH' -and $varValue -match '^(.+)[:/]\$PATH$') {
                    $newPath = $matches[1]
                    $newPath = $newPath -replace ':', ';'
                    $newPath = $newPath -replace '/', '\'
                    $newPath = $this.ExpandBashVariables($newPath)
                    $exports += 'Set-Item -Path Env:PATH -Value ("' + $newPath + ';" + $env:PATH)'
                }
                # Regular variable
                else {
                    $varValue = $this.ExpandBashVariables($varValue)
                    $exports += 'Set-Item -Path Env:' + $varName + ' -Value "' + $varValue + '"'
                }
            }
            # Just 'export VAR' — show current value
            else {
                $varName = $arg.Trim()
                if ($varName -match '^[A-Za-z_][A-Za-z0-9_]*$') {
                    $exports += 'Write-Host "export ' + $varName + '=" -NoNewline; Write-Host $env:' + $varName + ' -ForegroundColor Cyan'
                }
            }
        }
        
        return $exports -join '; '
    }
    
    [string] ExpandBashVariables([string]$value) {
        $expanded = $value
        
        # Map common bash variables to PowerShell equivalents
        $expanded = $expanded -replace '\$HOME', '$env:USERPROFILE'
        $expanded = $expanded -replace '\$USER', '$env:USERNAME'
        $expanded = $expanded -replace '\$HOSTNAME', '$env:COMPUTERNAME'
        $expanded = $expanded -replace '\$PWD', '(Get-Location).Path'
        $expanded = $expanded -replace '\$SHELL', '$env:COMSPEC'
        
        # Any remaining $VAR references become $env:VAR
        $expanded = $expanded -replace '\$([A-Za-z_][A-Za-z0-9_]*)', '$env:$1'
        
        return $expanded
    }
}