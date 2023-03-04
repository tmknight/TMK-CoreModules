#Requires -Modules ActiveDirectory
<#
.SYNOPSIS
    Module for returning AD Site details.
.DESCRIPTION
    Use this module to perform search of a whole or partial AD site name or subnet
    or to get the AD site of a computer.
.PARAMETER ComputerName
    Enter the full name or IP address of a computer.
.PARAMETER Full
    A switch will return the full AD site info.  Used in conjuntion with ComputerName value.
.PARAMETER Name
    This parameter is a full or partial AD site name.
.PARAMETER Subnet
    Enter the first two or three octets of an IP address.  Subnets are treated as regular expressions;
    all rules pertaining to regular expressions are in play.
.PARAMETER All
    A switch that will simply get ALL known sites and subnets. This is helpful when assessing large datasets.
    No other parameter will be assessed when this switch is true.
.EXAMPLE
    Get-ADSite -ComputerName "D1233210"

    ComputerName Site
    ------------ ----
    D1233210     Duluth



    Description
    -----------
    Returns the Site of the computer input.
.EXAMPLE
    Get-ADSite -ComputerName "D1233210" -Full

    Site      Description     Subnet
    ----      -----------     ------
    DULUTH    Duluth, GA      11.166.240.0/24, 11.166.244.0/23


    Description
    -----------
    Used only in conjuntion with ComputerName value.
    Use of this switch returns the Site, Description and Subnet(s) of
    the identified AD Site of the computer input.
.EXAMPLE
    Get-ADSite -Name "Duluth"

    Site      Description     Subnet
    ----      -----------     ------
    DULUTH    Duluth, GA      11.166.240.0/24, 11.166.244.0/23


    Description
    -----------
    This example of a full or partial AD site name returns the Site, Description and
    Subnet(s) of locations matching the name input.
.EXAMPLE
    Get-ADSite -Subnet "11.48"

    Site      Description     Subnet
    ----      -----------     ------
    DULUTH    Duluth, GA      11.48.242.0/24
    TAMPA     Tampa, FL       11.48.244.0/23


    Description
    -----------
    The example returns all AD Sites matching the IP/subnet input.
.NOTES
    Author: Travis M Knight; tmknight
    Date: 2017-05-24: tmknight: Inception
    Date: 2017-09-27: tmknight: Code cleanup
    Date: 2018-05-25: tmknight: Updated help messages
    Date: 2018-08-22: tmknight: Add switch to pull all known AD Sites and subnets
    Date: 2018-11-21: tmknight: Add Test-SubnetMember to assess boundary membership
    Date: 2022-04-14: tmknight: Switch to Get-ADReplicationSite/Subnet from ActiveDirectory module
.NOTES
 	Project: https://github.com/tmknight/TMK-CoreModules
    Note: Please enter only one of an AD Site Name, a portion of the subnet address a computer name or the All switch.
        Using more than one parameter is not supported at this time.
#>

function  Get-ADSite {
    [CmdletBinding(DefaultParametersetName = "p0")]
    param(
        [Parameter(ParameterSetName = "p0",
            Mandatory = $true,
            ValueFromPipeline = $true,
            HelpMessage = "Enter the full name or IP address of a computer",
            Position = 0)]
        [string] $ComputerName,
        [Parameter(ParameterSetName = "p0",
            Mandatory = $false,
            Position = 2)]
        [switch] $Full,
        [Parameter(ParameterSetName = "p1",
            Mandatory = $false)]
        [string] $Name,
        [Parameter(ParameterSetName = "p2",
            Mandatory = $false)]
        [string] $Subnet,
        [Parameter(ParameterSetName = "p3",
            HelpMessage = "A switch that will simply get ALL known sites and subnets. No other parameter will be assessed",
            Mandatory = $false)]
        [switch] $All
    )

    begin {
        $ErrorActionPreference = "Stop"

        if ($All) {
            ## A switch that will simply get ALL known sites and subnets. No other parameter will be assessed
        }
        elseif (($Name -and $Subnet -and $ComputerName) -or ($Name -and ($Subnet -or $ComputerName)) -or ($Subnet -and $ComputerName)) {
            Write-Error -Message "Please enter only one of an AD Site Name, a portion of the subnet address or a computer name. Using more than one parameter is not supported at this time." -Category InvalidArgument
            break
        }
        elseif ($Subnet -match "[a-zA-Z]") {
            Write-Error -Message "Please enter a full or partial subnet address in the form of dotted decimal-numbers" -Category InvalidArgument
            break
        }
        elseif ($Name -match "^\d{1,3}.*\d{1,3}?") {
            Write-Error -Message "Please enter a valid AD Site Name" -Category InvalidArgument
            break
        }
        elseif (!($Name -or $Subnet -or $ComputerName)) {
            Write-Error -Message "Please enter one of an AD Site Name, a portion of the subnet address or a computer name" -Category InvalidArgument
            break
        }
    }
    process {
        ## get AD site of a specific computer
        switch ($PsCmdlet.ParameterSetName) {
            "p0" {
                try {
                    if ($ComputerName -eq $env:COMPUTERNAME) {
                        $cn = "."
                    }
                    else {
                        $cn = $ComputerName
                    }
                    $siteName = (Get-CimInstance -ComputerName $cn -ClassName Win32_NTDomain | Where-Object { $Domain -Match $_.DomainName -and $null -ne $_.ClientSiteName }).ClientSiteName
                }
                catch {
                    $siteName = ($_.Exception).Message
                }

                if ($siteName -eq $err -or ($siteName -and $Full -ne $true)) {
                    $result = [PSCustomObject] @{
                        ComputerName = $ComputerName
                        Site         = $siteName
                    }
                }
                elseif ($siteName -ne $err -and $Full) {
                    $Name = $siteName
                    $site = Get-ADReplicationSite -Identity $Name
                    $subs = Get-ADReplicationSubnet -Filter "Site -eq '$($site.DistinguishedName)'"
                    $result = [PSCustomObject]@{
                        Site        = $site.Name
                        Description = $site.Description
                        Subnet      = $subs.Name -join "; "
                    }
                }
            }
            "p1" {
                $site = Get-ADReplicationSite -Identity $Name
                $subs = Get-ADReplicationSubnet -Filter "Site -eq '$($site.DistinguishedName)'"
                $result = [PSCustomObject]@{
                    Site        = $site.Name
                    Description = $site.Description
                    Subnet      = $subs.Name -join "; "
                }
            }
            "p2" {
                $result = @()
                $subs = Get-ADReplicationSubnet -Filter "Name -like '$Subnet*'"
                foreach ($item in $subs) {
                    $site = Get-ADReplicationSite -Filter * | Where-Object DistinguishedName -EQ "$($item.site)"
                    $result += [PSCustomObject]@{
                        Site        = $site.Name
                        Description = $site.Description
                        Subnet      = $item.Name -join "; "
                    }
                }

            }
            "p3" {
                $result = @()
                $site = Get-ADReplicationSite -Filter *
                foreach ($item in $site) {
                    $subs = Get-ADReplicationSubnet -Filter "Site -eq '$($item.DistinguishedName)'"
                    $result += [PSCustomObject]@{
                        Site        = $item.Name
                        Description = $item.Description
                        Subnet      = $subs.Name -join "; "
                    }
                }
            }
        }
    }
    end {
        if ($result) {
            return $result
        }
        else {
            Write-Warning -Message "There are no objects matching $ComputerName$Name$Subnet"
        }
    }
}
