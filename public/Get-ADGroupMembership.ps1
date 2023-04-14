#Requires -Module ActiveDirectory
<#
.SYNOPSIS
   Module for performing recursive lookup of the groups to which an AD object belongs.
.DESCRIPTION
   Use this module to perform a lookup of all global groups to which an object belongs, both direct and recursive.
   This requires the AtiveDirectory module
.EXAMPLE
   Get-ADGroupMembership -Identity someName -Recursive

.PARAMETER Identity
   This parameter is required and must be in the form of valid SAMAccountName.
   If you wish to search a computer account, use must use the SAMAccountName with the trailing '$'

   $Identity = 'someName'

.PARAMETER PageSize
   This parameter is optional and sets the size of the search set and must be in the form of valid integer.
   The defualt is 1000.

   $PageSize = 1000

.PARAMETER Recursive
   This parameter is optional.  It is a switch that will perform a recursive search of all global groups.
   The default returns only direct membership.

.NOTES
   Project: https://github.com/tmknight/TMK-CoreModules
#>

Function Get-ADGroupMembership {
    [CmdletBinding()]
    Param(
        ## Identity, required.
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [string]$Identity,
        [Parameter(Mandatory = $false,
            Position = 1)]
        [int]$PageSize = 1000,
        ## Perform recursive search
        [Parameter(Mandatory = $false,
            Position = 2)]
        [switch]$Recursive
    )

    Begin {
        ## Setup LDAP search
        $strDN = { SAMAccountName -like $Identity }
        $objDomain = New-Object System.DirectoryServices.DirectoryEntry
        $objSearcher = New-Object System.DirectoryServices.DirectorySearcher
        $objSearcher.SearchRoot = $objDomain
        $objSearcher.PageSize = $PageSize
        $objSearcher.SearchScope = "Subtree"
        $objSearcher.Filter = $strDN
        $colProplistUsr = "name"
    }
    Process {
        try {
            ## User or computer
            switch -RegEx ($Identity) {
                '\$$' {
                    $usr = (Get-ADComputer -Filter $strDN).DistinguishedName
                }
                Default {
                    $usr = (Get-ADUser -Filter $strDN).DistinguishedName
                }
            }

            ## Direct or recursive membership
            if ($Recursive.IsPresent) {
                $strGroup = "(&(objectCategory=group)(member:1.2.840.113556.1.4.1941:=$usr))"
            }
            else {
                $strGroup = "(&(objectCategory=group)(member=$usr))"
            }

            ForEach ($u in $colProplistUsr) {
                $objSearcher.PropertiesToLoad.Add($u) | Out-Null
            }

            $objSearcher.Filter = $strGroup
            $colProplistGrp = "name"
            ForEach ($g in $colProplistGrp) {
                $objSearcher.PropertiesToLoad.Add($g) | Out-Null
            }

            $obj = @()
            $colResultsGrp = $objSearcher.FindAll()
            ForEach ($objResultGrp in $colResultsGrp) {
                $vars = "objItemGrp", "grpDN", "name", "sid"
                Remove-Variable $vars -ErrorAction SilentlyContinue

                $objItemGrp = $objResultGrp.Properties
                $grpDN = $objItemGrp.adspath -replace "LDAP://"
                $name = $($objItemGrp.name)
                if ($grpDN -match "OU=Mail") {
                    $sid = "Mail Group"
                }
                else {
                    try {
                        $sid = (Get-ADGroup "$name" -ErrorAction SilentlyContinue).SID
                        if ($sid -notmatch "S-1-5") {
                            $sid = "unknown"
                        }
                    }
                    catch {
                        $sid = "unknown"
                    }
                }
                $obj += [PSCustomObject] @{
                    Name = "$name"
                    DN   = "$grpDN"
                    SID  = $sid
                }
            }
            if (-not $obj) {
                Write-Warning "$Identity is not a member of any AD groups"
            }
        }
        catch {
            Return $_
        }
    }
    End {
        Return $obj | Sort-Object Name
    }
}
