<#
.SYNOPSIS
   Module for writing progress, particularly for the VS Code Host which currently does not support Write-Progress
.DESCRIPTION
   Use this module to write progress of scripts.  It will write progress inline when the host is VS Code and execute Write-Progress when
   in native PowerShell
.EXAMPLE
    Write-InlineProgress -Activity $Activity -PercentComplete $percentcomplete
    
    This is my Activity statement: 80%
.PARAMETER Activity
	This parameter is manadatory and is in the form of a string

    $Activity = "This is my Activity statement:"
.PARAMETER PercentComplete 
    This paramater is mandatory and is in the form of an integer

    $PercentComplete = 80
.NOTES
	Author: Travis M Knight; tmknight
	Date: 2017-10-25: tmknight: Inception
	Date: 2017-11-30: tmknight: Set percent complete to two decimal places
	Date: 2018-04-02: tmknight: Account for vscode-powershell 2.x which now supports Write-Progress
.LINK
    https://msdn.microsoft.com/en-us/library/system.console(v=vs.110).aspx
#>

function Write-InlineProgress {
    param(
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true, 
            Position = 0)]
        [string]$Activity,
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1)]
        [ValidateScript( {
                If ($_ -match '\d') {
                    $True
                }
                Else {
                    Throw "The argument `"$_`" is not a number value. Supply an argument that is a number value and try the command again."
                }
            })]
        $PercentComplete
    )

    $perc = "{0:N2}" -f $PercentComplete
    switch ($host.Name) {
        "Visual Studio Code Host" {
            if ($host.Version -ge "2.0.1") {
                Write-Progress -Activity $Activity -PercentComplete $perc -Status "$perc%"
            }
            else {
                $val = "$Activity $perc%    "
                $CursorY = $host.UI.RawUI.CursorPosition.Y 
                [Console]::SetCursorPosition(0, $CursorY)
                [Console]::Write($val)
            }
        }
        Default {
            Write-Progress -Activity $Activity -PercentComplete $perc -Status "$perc%"
        }
    }
}
