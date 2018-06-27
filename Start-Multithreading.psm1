<#
.SYNOPSIS
   Module for multi-threading using runspaces
.DESCRIPTION
   Use this module to perform multi-threading of scripting on large target sets
.EXAMPLE
	Start-Multithreading -ScriptBlock $ScriptBlock -InputObjects $InputObjects -Arguments $Arguments

    Source        Destination     IPV4Address      IPV6Address                              Bytes    Time(ms)
    ------        -----------     -----------      -----------                              -----    --------
    TEST-00		TEST-01         10.165.169.81	fe80::e508:2592:d422:8eec%15				32		0
    TEST-00		TEST-02       	10.165.169.82	fe80::e508:2592:d422:8eec%16				32		0
    TEST-00		TEST-03         10.165.169.83	fe80::e508:2592:d422:8eec%17				32		0

	Description
	-----------
	Using a script block to ping a list of machines one time
.PARAMETER InputObjects
	This parameter is manadatory and must be in the form of an array containing
    the object(s) on which to execute the ScriptBlock.

    $InputObjects = import-csv c:\temp\list-of-pcs.csv
.PARAMETER Arguments 
	This parameter is not mandatory, though it must be in the form of a hashtable with 
    each parameter required by your script being in the order that they
    are called by the script.

    $Arguments = @{
        count = 1
    }
.PARAMETER ScriptBlock 
	This paramater is mandatory and is where you will place your code to loop through. The loop object
    should be the first parameter.
    
    $ScriptBlock = 
    { 
        param(
            $ComputerName,
            $count
        )
        Test-Connection $ComputerName -Count $count
    }
.PARAMETER MaxThreads
    This paramater is not mandatory, though it is where you can set the maximum concurrent threads or jobs.
    This setting in memory dependent and too large a value may exceed available memory.
    It is recommended to not exceed 100 threads for the above reasons as well as the last couple of threads occassionally stall for an extended
    period of time when this value is set larger.
    If no value is set, the default of 20 threads will be applied

    $MaxThreads = 50     

.PARAMETER NoProgress
    A switch to disable activity progress.
    NOTE: When executing in VS-Code, the Write-InlineProgress command from TMK-CoreModules must be present

.NOTES
	Author: Travis M Knight; tmknight88@gmail.com
	Date: 2017-03-15: tmknight: Inception
	Date: 2017-05-03: tmknight: Update notes. Modify how runspace status is tracked.
	Date: 2017-11-30: tmknight: Update progress to account for VS-Code host.
	Date: 2018-02-07: tmknight: Added switch to not show progress if desired for silent execution;Paramter verbiage change from LoopObjects to InputObjects.
	Date: 2018-02-14: tmknight: Add logic to force progress to 100% when all operations complete.
.LINK
    https://blogs.technet.microsoft.com/heyscriptingguy/2015/11/26/beginning-use-of-powershell-runspaces-part-1/
    https://github.com/tmknight/TMK-CoreModules
#>

function Start-Multithreading {
    param(
        # Command or script to run. Must take ComputerName as argument to make sense. 
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true, 
            Position = 0)]
        $ScriptBlock,

        # List of arguments required by the scriptblock
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true, 
            Position = 1)]
        $InputObjects,

        # List of arguments required by the scriptblock
        [Parameter(Mandatory = $false,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true, 
            Position = 2)]
        $Arguments = @{arg = '0'},

        # Maximum concurrent threads to start
        [Parameter(Mandatory = $false,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true, 
            Position = 3)]
        [int]$MaxThreads = 20,

        # Whether progress is displayed
        [Parameter(Mandatory = $false,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true, 
            Position = 4)]
        [switch]$NoProgress
    )

    Begin {
        ## Establish runspace pool
        $RunspaceCollection = @()
        $RunspacePool = [RunspaceFactory]::CreateRunspacePool(1, $MaxThreads)
        $RunspacePool.Open()

        $c = 0
    }
    Process {
        $ErrorActionPreference = 'SilentlyContinue'
        switch ($Host.Name) {
            "Visual Studio Code Host" {
                if (!(Get-Command -Name Write-InlineProgress) -and $NoProgress -eq $false) {
                    $NoProgress = $true
                    $message = "The command Write-InlineProgress is required when executing via VS-Code and does not exist.`n" +
                    "Please import `"TMK-CoreModules`" from https://github.com/tmknight/TMK-CoreModules. Continuing without progress."
                    Write-Warning -Message $message
                    Start-Sleep -Seconds 5
                }
            }
        }
        $ErrorActionPreference = 'Stop'

        ForEach ($obj in $InputObjects) {
            # Create a PowerShell object to run add the script and argument.
            $Powershell = [PowerShell]::Create().AddScript($Scriptblock).AddArgument($obj).AddParameters($Arguments)

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
                switch ($NoProgress) {
                    $false {
                        $perc = ($c / $count * 100)
                        switch ($Host.Name) {
                            "Visual Studio Code Host" {
                                Write-InlineProgress -Activity "$c of $count threads completed" `
                                    -PercentComplete $perc
                            }
                            default {
                                Write-Progress -Activity "Executing.." `
                                    -PercentComplete $perc `
                                    -Status "$c of $count threads completed"
                            }
                        }
                    }
                }

                If ($Runspace.Result.IsCompleted -eq $true) {
                    $result += $Runspace.PowerShell.EndInvoke($Runspace.Result)
                    $Runspace.PowerShell.Dispose()
                    $c++
                    $RunspaceCollection.Remove($Runspace)
                }
            }
        }

        ## Force progress to 100% when all threads have completed
        if ($RunspaceCollection.Count -le 0) {
            $c = $count
            $perc = ($c / $count * 100)
            switch ($NoProgress) {
                $false {
                    switch ($Host.Name) {
                        "Visual Studio Code Host" {
                            Write-InlineProgress -Activity "$c of $count threads completed" `
                                -PercentComplete $perc
                        }
                        default {
                            Write-Progress -Activity "Executing.." `
                                -PercentComplete $perc `
                                -Status "$c of $count threads completed"
                        }
                    }
                }
            }
        }
        
        ## Move the cursor to the next line, particularly for Write-InlineProgress module
        $RunspaceCollection.Clear()
        switch ($Host.Name) {
            "Visual Studio Code Host" {
                Write-Host
            }
        }
    }
    End {
        $RunspacePool.Close()
        $RunspacePool.Dispose()
        Return $result
    }
}
