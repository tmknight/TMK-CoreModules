<#
.SYNOPSIS
    Module for finding files using multithreading
.DESCRIPTION
    Use this module to find files faster than can be accomplished with Get-ChildItem alone
.EXAMPLE
    Find-File -Path $pth -File "nmap-update.exe"

    C:\Program Files (x86)\Nmap\nmap-update.exe
.PARAMETER Path
    This parameter is manadatory and is in the form of an absolute path.
    The path must be terminiated with "\"

    $pth = "c:\"

    or

    $pth = "\\server\c$\"
.PARAMETER File
    This paramater is mandatory and is in the form of whole or partial name

    $file = "nmap-update.exe"

    or

    $file = "nmap-update"
.PARAMETER MaxThreads
    This parameter is an optional integer

    $MaxThreads = 100
.PARAMETER NoProgress
    This paramater is an option switch that will turn off visual progress
.NOTES
    Author: Travis M Knight; tmknight
    Date: 2019-04-16: tmknight: Inception
    Date: 2022-07-20: tmknight: New logic to allow for UNC paths and avoid double-seraching the source path
#>

function Find-File {
    param(
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "Please ensure a fully qualified path that must terminate with `"\`".",
            Position = 0)]
        [ValidatePattern("([a-zA-Z]\:|\\\\\w{1,}(\.{1}\w{1,}){0,}\\[a-zA-Z]{1,}\$)\\\w*")]
        [string]$Path,
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1)]
        [string]$File,
        [Parameter(Mandatory = $false,
            ValueFromPipeline = $false,
            Position = 2)]
        [int]$MaxThreads = 20,
        [Parameter(Mandatory = $false,
            ValueFromPipeline = $false,
            Position = 3)]
        [switch]$NoProgress
    )

    Begin {
        $regExPath = ($Path -replace "\\", "\\" -replace "\$", "\$").TrimEnd('\')
        $regEx = "([a-zA-Z]\:|\\\\\w{1,}(\.{1}\w{1,}){0,}\\[a-zA-Z]{1,}\$)"
        try {
            $dirs = (Get-ChildItem -Path $Path -Directory -ErrorAction SilentlyContinue).FullName
            if ($dirs -match "\w{1,}") {
                if ($Path -notmatch "$regEx\\Windows") {
                    if ($dirs -match "$regEx\\Windows\b") {
                        $title = 'A "Windows" directory is in your search; this may take a very long time to complete.'
                        $prompt = ''
                        $abort = New-Object System.Management.Automation.Host.ChoiceDescription '&Abort', 'Aborts the operation'
                        $continue = New-Object System.Management.Automation.Host.ChoiceDescription '&Continue', 'Continues the operation'
                        $options = [System.Management.Automation.Host.ChoiceDescription[]] ($abort, $continue)
                        $choice = $host.ui.PromptForChoice($title, $prompt, $options, 0)
                        if ($choice -eq 0) {
                            break
                        }
                        else {
                            ## Remove 'Windows' directory from the list and replace with sub-directories of 'Windows'
                            $dirWin = $dirs -match "$regEx\\Windows\b"
                            $dirs = $dirs -replace "$regEx\\Windows\b" | Where-Object { $_.trim() -ne "" }
                            $dirs = $dirs -replace "$regExPath$" | Where-Object { $_.trim() -ne "" }
                            $dirs += (Get-ChildItem -Path $dirWin -Directory -ErrorAction SilentlyContinue).FullName
                        }
                    }
                }
            }
            else {
                Write-Error -Message "The $Path indicated does not appear to be valid.  Please ensure a fully qualified path"
            }
        }
        catch {
            $_
            break
        }

        $block = {
            param($dir, $File)
            $result = @()
            try {
                $i = Get-ChildItem -Path "$dir\*" -Filter "*$File*" -File -Recurse -Force -ErrorAction SilentlyContinue
                if ($i) {
                    foreach ($o in $i | Where-Object -Property FullName -Value $File -Match) {
                        $result += [PSCustomObject]@{
                            File = $o.FullName
                        }
                    }
                    return $result
                }
            }
            catch {
                $_
                break
            }
        }
    }
    Process {
        $out = Start-Multithreading -InputObject $dirs -ScriptBlock $block -ArgumentList (, $File) -MaxThreads $MaxThreads -NoProgress:$NoProgress | Sort-Object -Property File -Unique
        ## Search root of $Path and 'Windows' directory
        $out += Get-ChildItem -Path $Path -Filter "*$File*" -File -Force -ErrorAction SilentlyContinue
        if ($dirWin -match "\w{1,}") {
            $out += Get-ChildItem -Path $dirWin -Filter "*$File*" -File -Force -ErrorAction SilentlyContinue
        }
    }
    End {
        if ($out -match "\w{1,}") {
            return $out
        }
        else {
            Write-Warning -Message "No files were found matching `"$File`" under the root of `"$Path`""
        }
    }
}
