# TabCompletion.ps1
# Handles tab completion for commands and files

function Get-BashCompletion {
    param(
        [string]$Word,
        [bool]$IsFirstWord,
        [hashtable]$CommandMap
    )
    
    $results = @()
    
    if ([string]::IsNullOrWhiteSpace($Word)) {
        return $results
    }
    
    if ($IsFirstWord) {
        # Complete bash commands
        $bashCommands = $CommandMap.Keys | Where-Object { $_ -like "$Word*" }
        $results += $bashCommands
        
        # Complete executables from PATH
        try {
            $exes = Get-Command -Name "$Word*" -CommandType Application -ErrorAction SilentlyContinue | 
                Select-Object -ExpandProperty Name -Unique |
                ForEach-Object { $_.Replace('.exe', '') }
            $results += $exes
        } catch {
        }
        
        $results = $results | Select-Object -Unique | Sort-Object
    } else {
        # Complete file/directory names
        try {
            $items = Get-ChildItem -Path . -Filter "$Word*" -ErrorAction SilentlyContinue
            $names = $items | ForEach-Object {
                if ($_.PSIsContainer) {
                    $_.Name + '/'
                } else {
                    $_.Name
                }
            }
            $results += $names
        } catch {
        }
    }
    
    return $results
}