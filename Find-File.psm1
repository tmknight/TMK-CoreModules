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
    This paramater is mandatory and is in the form of an integer

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
            Position = 0)]
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
        $dirs = (Get-ChildItem -Path $Path -Directory -Recurse -Depth 1 -ErrorAction SilentlyContinue).FullName
        $dirs += $Path
        if ($dirs -match "C\:\\Windows\\.*") {
            $title = 'The Windows directory is in your search; this will take a very long time to complete.'
            # $prompt = '[A]bort or [C]ontinue?'
            $prompt = ''
            $abort = New-Object System.Management.Automation.Host.ChoiceDescription '&Abort', 'Aborts the operation'
            $continue = New-Object System.Management.Automation.Host.ChoiceDescription '&Continue', 'Continues the operation'
            $options = [System.Management.Automation.Host.ChoiceDescription[]] ($abort, $continue)
            $choice = $host.ui.PromptForChoice($title, $prompt, $options, 0)
            if ($choice -eq 0) {
                break
            }
        }

        $block = {
            param($dir, $File)
            $result = @()
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
    }
    Process {
        $out = Start-Multithreading -InputObject $dirs -ScriptBlock $block -ArgumentList (, $File) -MaxThreads $MaxThreads -NoProgress:$NoProgress | Sort-Object -Property File
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
