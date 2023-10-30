<#
.SYNOPSIS
    Module for multi-threading using runspaces
.DESCRIPTION
    Use this module to perform multi-threading of scripting on large target sets
.EXAMPLE
	Start-Multithreading -ScriptBlock $ScriptBlock -InputObject $InputObject -ArgumentList $ArgumentList

    Source        Destination     IPV4Address      IPV6Address                              Bytes    Time(ms)
    ------        -----------     -----------      -----------                              -----    --------
    TEST-00		TEST-01         10.165.169.81	fe80::e508:2592:d422:8eec%15				32		0
    TEST-00		TEST-02       	10.165.169.82	fe80::e508:2592:d422:8eec%16				32		0
    TEST-00		TEST-03         10.165.169.83	fe80::e508:2592:d422:8eec%17				32		0

	Description
	-----------
	Using a script block to ping a list of machines one time
.PARAMETER InputObject
	This parameter is manadatory and must be in the form of an array containing
    the object(s) on which to execute the ScriptBlock.

        $InputObject = import-csv c:\temp\list-of-pcs.csv
.PARAMETER ArgumentList
    This parameter is not mandatory, though it must be in one of the following forms:

    A comma-separated list of variables in the order that they
    are called by the script.

        $count = 1
        $list  = "one","two","Three"

        Start-Multithreading -ScriptBlock $ScriptBlock -InputObject $InputObject -ArgumentList $count, $list

    A hashtable with each parameter required by your script being in the order that they
    are called by the script.

        $count = 1
        $list = "one","two","Three"

        $ArgumentList = @{
            count = $count
            list  = $list
        }

        Start-Multithreading -ScriptBlock $ScriptBlock -InputObject $InputObject -ArgumentList $ArgumentList
.PARAMETER ScriptBlock
	This paramater is mandatory and is where you will place your code to loop through. The loop object
    should be the first parameter.

        $ScriptBlock =
        {
            param(
                $ComputerName,
                $count,
                $list
            )
            Test-Connection $ComputerName -Count $count
        }
.PARAMETER ThrottleLimit
    This paramater is not mandatory, though it is where you can set the maximum concurrent threads or jobs.
    This setting in memory dependent and too large a value may exceed available memory.
    It is recommended to not exceed 100 threads for the above reasons as well as the last couple of threads occassionally stall for an extended
    period of time when this value is set larger.
    If no value is set, the default of 20 threads will be applied

        $ThrottleLimit = 50
.PARAMETER Quiet
    A switch to disable activity progress.
    NOTE: When executing in VS-Code, the Write-InlineProgress command from TMK-CoreModules must be present
.NOTES
	Project: https://github.com/tmknight/TMK-CoreModules
.LINK
    https://blogs.technet.microsoft.com/heyscriptingguy/2015/11/26/beginning-use-of-powershell-runspaces-part-1/
    https://github.com/tmknight/TMK-CoreModules
#>

function Invoke-Multithreading {
    [CmdletBinding()]
    param(
        # The object(s) on which to execute the ScriptBlock
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 0)]
        [Alias('InputObjects')]
        $InputObject,

        # Command or script to run. Must take ComputerName as argument to make sense.
        [Parameter(Mandatory = $true,
            Position = 1)]
        $ScriptBlock,

        # List of arguments required by the scriptblock
        [Parameter(Mandatory = $false,
            Position = 2)]
        [Alias('Arguments')]
        $ArgumentList = @{arg = '0' },

        # Maximum concurrent threads to start
        [Parameter(Mandatory = $false,
            Position = 3)]
        [Alias('MaxThreads')]
        [int]$ThrottleLimit = 20,

        # Whether progress is displayed
        [Parameter(Mandatory = $false,
            Position = 4)]
        [Alias('NoProgress')]
        [switch]$Quiet
    )

    Begin {
        ## Establish runspace pool
        $RunspaceCollection = @()
        $RunspacePool = [RunspaceFactory]::CreateRunspacePool(1, $ThrottleLimit)
        $RunspacePool.Open()

        ## Counter variable to assess progress
        $c = 0

        ## Initialize results
        $result = @()
    }
    Process {
        $ErrorActionPreference = 'SilentlyContinue'
        switch ($Host.Name) {
            'Visual Studio Code Host' {
                if (-not(Get-Command -Name Write-InlineProgress) -and -not($Quiet.IsPresent)) {
                    $Quiet = $true
                    $message = "The command Write-InlineProgress is required when executing via VS-Code and does not exist.`n" +
                    "Please import `"TMK-CoreModules`" from https://github.com/tmknight/TMK-CoreModules. Continuing without progress."
                    Write-Warning -Message $message
                    Start-Sleep -Seconds 5
                }
            }
        }
        $ErrorActionPreference = 'Stop'

        ForEach ($obj in $InputObject) {
            # Create a PowerShell object to run add the script and argument.
            $Powershell = [PowerShell]::Create().AddScript($Scriptblock).AddArgument($obj).AddParameters($ArgumentList)

            # Specify runspace to use
            $Powershell.RunspacePool = $RunspacePool

            # Create Runspace collection
            [Collections.Arraylist]$RunspaceCollection += [PSCustomObject] @{
                Result = $PowerShell.BeginInvoke()
            }
        }

        $count = $RunspaceCollection.Count

        ## Keep track of open threads and terminate when all have completed
        While ($RunspaceCollection.Count -gt 0) {
            Foreach ($Runspace in $RunspaceCollection.ToArray()) {
                if (-not($Quiet.IsPresent)) {
                    ## Get progress
                    [int]$perc = ($c / $count * 100)
                    ## Prevent 100 while still processing
                    if ($perc -eq 100 -and $c -ne $count) { $perc = 99 }
                    Write-InlineProgress -Activity "$c of $count threads completed" -PercentComplete $perc
                }

                if ($Runspace.Result.IsCompleted) {
                    $result += $Runspace.PowerShell.EndInvoke($Runspace.Result)
                    $Runspace.PowerShell.Dispose()
                    $RunspaceCollection.Remove($Runspace)
                    $c++
                }
            }
        }

        if (-not($Quiet.IsPresent)) {
            ## Force progress to 100
            $c = $count
            $perc = 100
            Write-InlineProgress -Activity "$c of $count threads completed" -PercentComplete $perc
            [System.Console]::WriteLine()
        }
    }
    End {
        ## Release runspace pool
        $RunspaceCollection.Clear()
        $RunspacePool.Close()
        $RunspacePool.Dispose()
        Return $result
    }
}
Set-Alias -Name Start-Multithreading -Value Invoke-Multithreading
