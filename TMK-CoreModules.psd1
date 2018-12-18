###
# Module manifest for shared modules'
###
@{
    ModuleVersion     = '1.5.3.7'
    GUID              = '0c83f152-41a4-4997-92da-c06923fb3e12'
    Author            = 'Travis M Knight'
    CompanyName       = 'TMK World Headquarters'
    Copyright         = '(c)TMK World Headquarters'
    Description       = 'Shared module of common functions'
    PowerShellVersion = '4.0'
    FunctionsToExport = '*'
    VariablesToExport = '*'
    AliasesToExport   = '*'
    CmdletsToExport   = '*'
    NestedModules     = @(
        'Start-FastPing',
        'Start-Multithreading',
        'Get-OUObjects',
        'Get-ADSite',
        'Write-InlineProgress',
        'Test-SubnetMember'
    )
    PrivateData       = @{
        PSData = @{
            Tags         = @(
                'Shared', 'DIOShared', 'DIO-Shared', 'DIO Shared', 'DIO'
                'multithreading', 'multi-threading', 'multi threading',
                'fastping', 'fast-ping', 'fast ping',
                'ouobjects', 'ou-objects', 'ou objects',
                'adsite', 'ad-site', 'ad site', 'write progress'
            )
            ReleaseNotes = '* 2017-03-15: tmknight: v1.0.0.0: First commit; Start-Multithreading function
			* 2017-04-28: tmknight: v1.1.0.0: Added Fast-Ping module
			* 2017-05-03: tmknight: v1.2.0.0: Updated Start-Multithreading module
            * 2017-05-22: tmknight: v1.3.0.0: Added Get-OUObjects module
            * 2017-05-24: tmknight: v1.4.0.0: Added Get-ADSite module
            * 2017-05-25: tmknight: v1.5.0.0: Added full site details to Get-ADSite function when querying a computer
            * 2017-06-06: tmknight: v1.5.1.0: Added OS version to computer query;
                added mail and display name to user query;
                added validate set to scope and catagory;
                set defaults for objects and operating system;
                prompt to continue if catagory user, objects = "*" and base = subtree
            * 2017-06-12: tmknight: v1.5.2.0: Check for ActiveDirectory module
            * 2017-07-05: tmknight: v1.5.2.1: Error catch for Get-CimInstance issues
            * 2017-09-27: tmknight: v1.5.2.2: Code cleanup
            * 2017-10-17: tmknight: v1.5.2.3: Code cleanup
            * 2017-10-19: tmknight: v1.5.2.4: Code cleanup
            * 2017-10-20: tmknight: v1.5.2.5: Change "Lookup" parameter to switch statement in Start-FastPing module
            * 2017-10-24: tmknight: v1.5.2.6: Add additional user attributes returned in Get-OUObjects module
            * 2017-10-25: tmknight: v1.5.3.0: Added Write-InlineProgress module
            * 2017-11-01: tmknight: v1.5.3.1: Refined PC site query to permit query of localhost
            * 2017-11-03: tmknight: v1.5.3.2: Refined Write-InlineProgress to permit decimals
            * 2017-11-30: tmknight: v1.5.3.3: Updates to Get-OUObject and Start-Multithreading
            * 2018-02-07: tmknight: v1.5.3.4: Updates to Get-OUObject to return additional information when no records found;
                update to Start-Multithreading with added switch to not show progress if desired for silent execution;
                update to Start-Multithreading with paramter verbiage change from LoopObjects to InputObjects
            * 2018-02-14: tmknight: v1.5.3.4: Add logic to force progress to 100% when all operations complete
            * 2018-08-22: tmknight: v1.5.3.5: Several updates to child modules. See individual module notes for list of changes
            * 2018-11-21: tmknight: v1.5.3.6: Add Test-SubnetMember to assess boundary membership.  Included use of this module in Get-ADSite
            * 2018-12-18: tmknight: v1.5.3.7: Rename "Arguments" to "ArgumentList" to be in alignment with other PS modules'
        }
    }
}
