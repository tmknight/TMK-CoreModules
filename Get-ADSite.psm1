<#
.SYNOPSIS
   Module for returning AD Site details.
.DESCRIPTION
   Use this module to perform search of a whole or partial AD site name or subnet
   or to get the AD site of a computer.
.EXAMPLE
   Get-ADSite -Name "Duluth"

    or

   Get-ADSite -Subnet "11.48"

    or

   Get-ADSite -ComputerName "D1233210"

   Note: Please enter only one of an AD Site Name, a portion of the subnet address or a computer name.
   Using more than one parameter is not supported at this time.
.PARAMETER Name
	This parameter is a full or partial AD site name.

    $Name = "Duluth"
.PARAMETER Subnet 
	This parameter is a full or partial subnet address in the form of dotted-decimal numbers.

    $Subnet = "11.48"
.PARAMETER ComputerName 
	This parameter is a computer name.

    $ComputerName = "v1233211"
.PARAMETER Full
	This parameter requires computer name and will return the details of the computer's site.
    It must be in the form of a bolean ($true, $false)

    $ComputerName = "v1233211" -Full $true
.NOTES
	Author: Travis M Knight; tmknight
	Date: 2017-05-24: tmknight: Inception
	Date: 2017-09-27: tmknight: Code cleanup
#>

function  Get-ADSite {
    [CmdletBinding(DefaultParametersetName = "p0")]
    param(
        [Parameter(ParameterSetName = "p0",
            Position = 0)]
        [string] $ComputerName,
        [Parameter(ParameterSetName = "p0",
            Position = 1)]
        [switch] $Full,
        [Parameter(ParameterSetName = "p1",
            Position = 2)]
        [string] $Name,
        [Parameter(ParameterSetName = "p2",
            Position = 3)]
        [string] $Subnet
    )
    
    begin {
        $ErrorActionPreference = "Stop"
        
        if (($Name -and $Subnet -and $ComputerName) -or ($Name -and ($Subnet -or $ComputerName)) -or ($Subnet -and $ComputerName)) {
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
        function  get-stats {
            param(
                $Subnet,
                $Name
            )

            $rslt = @()
            $siteDescription = @{}
            $siteSubnets = @{}
            
            $sitesDN = "LDAP: / / CN = Sites, " + $([adsi] "LDAP://RootDSE").Get("ConfigurationNamingContext")
            $subnetsDN = "LDAP: / / CN = Subnets, CN = Sites, " + $([adsi] "LDAP://RootDSE").Get("ConfigurationNamingContext")
            ## Get all the site names and descriptions
            foreach ($site in $([adsi] $sitesDN).psbase.children) {
                if ($site.objectClass -eq "site") {
                    $siteName = ([string]$site.cn).toUpper()
                    $siteDescription[$siteName] = $site.Description
                    $siteSubnets[$siteName] = @()
                }
            }

            ## Get all subnets and associate them with the sites
            foreach ($net in $([adsi] $subnetsDN).psbase.children) {
                $site = [adsi] "LDAP: / / $($net.siteObject)"
                if ($site.cn -ne $null) {
                    $siteName = ([string]$site.cn).toUpper()
                    $siteSubnets[$siteName] += $net.cn
                }
                else {
                    $siteDescription["Orphaned"] = "Subnets not associated with any site"
                    if ($siteSubnets["Orphaned"] -eq $null) { 
                        $siteSubnets["Orphaned"] = @() 
                    }
                    $siteSubnets["Orphaned"] += $net.cn
                }
            }

            ## Gather results
            foreach ($siteName in $siteDescription.keys) {
                ## Site info based on subnet parameter
                if ($Subnet) {
                    foreach ($net in $siteSubnets[$siteName] | Sort-Object) {
                        if ($net -match "\b$Subnet") {
                            $rslt += [PSCustomObject] @{
                                Site        = $siteName
                                Description = $($siteDescription[$siteName])
                                Subnet      = $net
                            }
                        }
                    }
                }
                ## Site info based on name parameter
                elseif ($siteName -match "$Name") {
                    $net = $siteSubnets[$siteName] -join ", "
                    $rslt += [PSCustomObject] @{
                        Site        = $siteName
                        Description = $($siteDescription[$siteName])
                        Subnet      = $net
                    }
                }
            }
            return $rslt
        }        

        ## get AD site of a specific computer
        switch ($PsCmdlet.ParameterSetName) {
            "p0" {
                try {
                    if ($ComputerName -eq $env:COMPUTERNAME) {
                        $siteName = (Get-CimInstance -ClassName Win32_NTDomain -Filter "Name = 'Domain: FEDERATED'").ClientSiteName
                    }
                    else {
                        $siteName = (Get-CimInstance -ComputerName $ComputerName -ClassName Win32_NTDomain -Filter "Name = 'Domain: FEDERATED'").ClientSiteName
                    }
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
                    $result = get-stats -Name $siteName
                }
            }
            "p1" {
                $result = get-stats -Name $Name
            }
            "p2" {
                $result = get-stats -Subnet $Subnet
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
