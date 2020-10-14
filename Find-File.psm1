<#
.SYNOPSIS
   Module for finding files using multithreading
.DESCRIPTION
   Use this module to find files faster than can be accomplished with Get-ChildItem alone
.EXAMPLE
    Find-File -Path $dirs -File "nmap-update.exe"

    C:\Program Files (x86)\Nmap\nmap-update.exe
.PARAMETER Path
	This parameter is manadatory and is in the form of a string

    $pth = "c:\"
.PARAMETER File
    This paramater is mandatory and is in the form of a string

    $file = "nmap-update.exe"

.PARAMETER MaxThreads
	This parameter is an optional integer

    $MaxThreads = 100
.PARAMETER NoProgress
    This paramater is an option switch that will turn off visual progress
.NOTES
	Author: Travis M Knight; tmknight
	Date: 2019-04-16: tmknight: Inception
#>

function Find-File {
    param(
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "Please ensure a fully qualified path. Root drives must terminate with `"\`".",
            Position = 0)]
        [ValidatePattern("[a-zA-Z]\:\\[a-zA-Z0-9_]*")]
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
        try {
            $dirs = (Get-ChildItem -Path $Path -Directory -Recurse -Depth 1 -ErrorAction SilentlyContinue).FullName
            if ($dirs -match "\w{1,}") {
                $dirs += $Path
                if ($dirs -match "[a-zA-Z]\:\\Windows\\") {
                    $title = 'A "Windows" directory is in your search; this may take a very long time to complete.'
                    $prompt = ''
                    $abort = New-Object System.Management.Automation.Host.ChoiceDescription '&Abort', 'Aborts the operation'
                    $continue = New-Object System.Management.Automation.Host.ChoiceDescription '&Continue', 'Continues the operation'
                    $options = [System.Management.Automation.Host.ChoiceDescription[]] ($abort, $continue)
                    $choice = $host.ui.PromptForChoice($title, $prompt, $options, 0)
                    if ($choice -eq 0) {
                        break
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
