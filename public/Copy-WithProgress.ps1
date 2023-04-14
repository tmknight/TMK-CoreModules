<#
.SYNOPSIS
   Module for writing file copy progress.
.DESCRIPTION
   Use this module to write file copy progress.  Particularly for large copy jobs.
.EXAMPLE
    Copy-WithProgress -Source $src -Destination $dst

    This is my Activity statement: 80%
.PARAMETER Source
	This parameter is manadatory and is in the form of a string

    $Souce = "C:\Temp"
.PARAMETER Destination
    This paramater is mandatory and is in the form of an integer

    $Destination = "C:\Final"
.PARAMETER Message
    This paramater is not mandatory and is in the form of an string

    $Message = "File Copy Progress:"
.NOTES
	Project: https://github.com/tmknight/TMK-CoreModules
#>

function Copy-WithProgress {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [string]$Source,

        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1)]
        [string]$Destination,

        [Parameter(Mandatory = $false,
            Position = 2)]
        [string]$Message = "File Copy Progress:"
    )

    Begin {
        $Source = $Source.tolower()
        $Filelist = Get-ChildItem $Source –Recurse
        $Total = $Filelist.count
        $Position = 0
    }
    Process {
        try {
            ForEach ($File in $Filelist) {
                $Filename = $File.Fullname.tolower().replace($Source, '')
                $DestinationFile = ($Destination + $Filename)
                Write-InlineProgress -activity $Message -PercentComplete (($Position / $total) * 100)
                Copy-Item $File.FullName -Destination $DestinationFile -Force
                $Position++
            }
            Write-InlineProgress -Activity $Message -PercentComplete 100
        }
        catch {
            $_.Exception
        }
    }
}
