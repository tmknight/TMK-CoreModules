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
	Author: Travis M Knight; tmknight88@gmail.com
	Date: 2017-03-15: tmknight: Inception
	Date: 2017-05-03: tmknight: Update notes. Modify how runspace status is tracked.
	Date: 2017-11-30: tmknight: Update progress to account for VS-Code host.
	Date: 2018-02-07: tmknight: Added switch to not show progress if desired for silent execution;Parameter verbiage change from LoopObjects to InputObject.
	Date: 2018-02-14: tmknight: Add logic to force progress to 100% when all operations complete.
	Date: 2018-08-09: tmknight: Clarify "Arguments" parameter.
	Date: 2018-10-19: tmknight: Rename "InputObject" parameter to be in alignment with other PS modules.
	Date: 2018-12-18: tmknight: Rename "Arguments" to "ArgumentList" to be in alignment with other PS modules.
	Date: 2021-12-08: tmknight: Rename "MaxThreads" to "ThrottleLimit" to be in alignment with other PS modules.
	Date: 2022-08-18: tmknight: Rename "NoProgress" to "Quiet" to be in alignment with other PS modules.
.LINK
    https://blogs.technet.microsoft.com/heyscriptingguy/2015/11/26/beginning-use-of-powershell-runspaces-part-1/
    https://github.com/tmknight/TMK-CoreModules
#>

function Invoke-Multithreading {
    param(
        # The object(s) on which to execute the ScriptBlock
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 0)]
        [Alias("InputObjects")]
        $InputObject,

        # Command or script to run. Must take ComputerName as argument to make sense.
        [Parameter(Mandatory = $true,
            Position = 1)]
        $ScriptBlock,

        # List of arguments required by the scriptblock
        [Parameter(Mandatory = $false,
            Position = 2)]
        [Alias("Arguments")]
        $ArgumentList = @{arg = '0' },

        # Maximum concurrent threads to start
        [Parameter(Mandatory = $false,
            Position = 3)]
        [Alias("MaxThreads")]
        [int]$ThrottleLimit = 20,

        # Whether progress is displayed
        [Parameter(Mandatory = $false,
            Position = 4)]
        [Alias("NoProgress")]
        [switch]$Quiet
    )

    Begin {
        ## Establish runspace pool
        $RunspaceCollection = @()
        $RunspacePool = [RunspaceFactory]::CreateRunspacePool(1, $ThrottleLimit)
        $RunspacePool.Open()

        ## Counter variable to assess progress
        $c = 0
    }
    Process {
        $ErrorActionPreference = 'SilentlyContinue'
        switch ($Host.Name) {
            "Visual Studio Code Host" {
                if (!(Get-Command -Name Write-InlineProgress) -and $Quiet -eq $false) {
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
                Result     = $PowerShell.BeginInvoke()
                PowerShell = $PowerShell
            }
        }

        $count = $RunspaceCollection.Count

        ## Keep track of open threads and terminate when all have completed
        While ($RunspaceCollection.Count -gt 0) {
            Foreach ($Runspace in $RunspaceCollection.ToArray()) {
                if ($Quiet.IsPresent -eq $false) {
                    $perc = ($c / $count * 100)
                    Write-InlineProgress -Activity "$c of $count threads completed" `
                        -PercentComplete $perc
                }

                if ($Runspace.Result.IsCompleted -eq $true) {
                    $result += $Runspace.PowerShell.EndInvoke($Runspace.Result)
                    $Runspace.PowerShell.Dispose()
                    $c++
                    $RunspaceCollection.Remove($Runspace)
                }
            }
        }

        if ($Quiet.IsPresent -eq $false) {
            ## Force progress to 100
            $c = $count
            $perc = 100
            Write-InlineProgress -Activity "$c of $count threads completed" `
                -PercentComplete $perc
            # [System.Console]::WriteLine()
            Write-Output -InputObject ""
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
# Export-ModuleMember -Alias * -Function *
