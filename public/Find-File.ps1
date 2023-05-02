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
.PARAMETER Exclude
    This paramater is not mandatory and is in the form of whole or partial name

    $Exclude = "*proc*"

    or

    $Exclude = "/proc"
.PARAMETER MaxThreads
    This parameter is an optional integer

    $MaxThreads = 100
.PARAMETER Quiet
    This paramater is an option switch that will turn off visual progress
.PARAMETER Force
    This paramater overrides the prompt about Windows directories in the search path
.NOTES
	Project: https://github.com/tmknight/TMK-CoreModules
#>

function Find-File {
    param(
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "Please ensure a fully qualified path that must terminate with `"\`".",
            Position = 0)]
        [ValidatePattern("\/\w{0,}|([a-zA-Z]\:|\\\\\w{1,}(\.{1}\w{1,}){0,}\\[a-zA-Z]{1,}\$)\\\w*")]
        [string]$Path,
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1)]
        [string]$File,
        [Parameter(Mandatory = $false,
            ValueFromPipeline = $false,
            ValueFromPipelineByPropertyName = $true,
            Position = 2)]
        [string]$Exclude,
        [Parameter(Mandatory = $false,
            ValueFromPipeline = $false,
            Position = 3)]
        [int]$MaxThreads = 100,
        [Parameter(Mandatory = $false,
            ValueFromPipeline = $false,
            Position = 4)]
        [Alias("NoProgress")]
        [switch]$Quiet,
        [switch]$Force
    )

    Begin {
        $regExPath = ($Path -replace "\\", "\\" -replace "\$", "\$").TrimEnd('\')
        $regEx = "([a-zA-Z]\:|\\\\\w{1,}(\.{1}\w{1,}){0,}\\[a-zA-Z]{1,}\$)"
        try {
            Write-Verbose -Message "Getting root path directories"
            $dirs = (Get-ChildItem -Path $Path -Exclude "$Exclude" -Directory -Force -ErrorAction SilentlyContinue).FullName

            if ($dirs -match "\w{1,}") {
                $level = "root"
                if ($dirs -match "$regEx\\Windows\b" -and -not $Force.IsPresent) {
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

                if ($dirs.Count -le 50) {
                    Write-Verbose -Message "Getting second level directories"
                    $dirsExt0 = ($dirs | Get-ChildItem -Directory -Force -ErrorAction SilentlyContinue).FullName
                    if ($dirsExt0 -match "\w{1,}") {
                        Write-Verbose -Message "Getting third level directories"
                        $dirsExt1 = ($dirsExt0 | Get-ChildItem -Directory -Force -ErrorAction SilentlyContinue).FullName
                    }

                    Write-Verbose -Message "Determining valid search paths"
                    $dirs = $dirs -replace "$regExPath$" | Where-Object { $_.trim() -ne "" }
                    if ($dirsExt0 -match "\w{1,}") {
                        $level = "second"
                        $dirsExt0 = $dirsExt0 -replace "$regExPath$" | Where-Object { $_.trim() -ne "" }
                        if ($dirsExt1 -notmatch "\w{1,}" -or $dirsExt1 -gt 1000) {
                            $dirsExt1 = $dirsExt0
                            $dirsExt0 = $null
                        }
                        else {
                            $dirsExt1 = $dirsExt1 -replace "$regExPath$" | Where-Object { $_.trim() -ne "" }
                            $level = "third"
                        }
                    }
                    else {
                        $dirsExt1 = $dirs
                        $dirs = $null
                    }
                }
                else {
                    $dirsExt1 = $dirs
                    $dirs = $null
                }
            }
            else {
                Write-Error -Message "The path indicated does not appear to be valid.  Please ensure a fully qualified path and that it is accessible: $Path"
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
        Write-Verbose -Message "Searching $level level directories"
        $out = @(Start-Multithreading -InputObject $dirsExt1 -ScriptBlock $block -ArgumentList (, $File) -MaxThreads $MaxThreads -Quiet:$Quiet | Sort-Object -Property File -Unique)

        ## Search root of $Path and extended root directories
        Write-Verbose -Message "Searching root path"
        $in = (Get-ChildItem -Path $Path -Exclude "$Exclude" -Filter "*$File*" -File -Force -ErrorAction SilentlyContinue).FullName | Where-Object { $null -ne $_ }
        if ($null -eq $out -and $null -ne $in) {
            $in | ForEach-Object {
                $out += [PSCustomObject]@{
                    File = $_
                }
            }
        }
        else {
            $out += $in
        }

        if ($dirsExt0 -match "\w{1,}") {
            Write-Verbose -Message "Searching second level directories"
            $in0 = (Get-ChildItem -Path $dirsExt0 -Filter "*$File*" -File -Force -ErrorAction SilentlyContinue).FullName | Where-Object { $null -ne $_ }
            if ($null -eq $out -and $null -ne $in0) {
                $in0 | ForEach-Object {
                    $out += [PSCustomObject]@{
                        File = $_
                    }
                }
            }
            else {
                $out += $in0
            }
        }

        if ($dirs -match "\w{1,}") {
            Write-Verbose -Message "Searching root path directories"
            $in1 = (Get-ChildItem -Path $dirs -Exclude "$Exclude" -Filter "*$File*" -File -Force -ErrorAction SilentlyContinue).FullName | Where-Object { $null -ne $_ }
            if ($null -eq $out -and $null -ne $in1) {
                $in1 | ForEach-Object {
                    $out += [PSCustomObject]@{
                        File = $_
                    }
                }
            }
            else {
                $out += $in1
            }
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
