# BashCommand.ps1
# Represents a parsed bash command

class BashCommand {
    [string] $Original
    [string] $Command
    [string[]] $Args
    [hashtable] $Flags
    [string[]] $PipeCommands
    [string] $OutputFile
    [bool] $AppendOutput
    
    BashCommand() {
        $this.Args = @()
        $this.Flags = @{}
        $this.PipeCommands = @()
        $this.OutputFile = ""
        $this.AppendOutput = $false
    }
}