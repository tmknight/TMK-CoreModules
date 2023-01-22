#Requires -Module ActiveDirectory
<#
.SYNOPSIS
   Module for returning AD OU object details
.DESCRIPTION
   Use this module to perform search of objects and typical values within an OU or multiple OUs

   Requires the Active Directory module: https://technet.microsoft.com/en-us/library/dd378937(WS.10).aspx
.EXAMPLE
    $Base = "dc=domain,dc=com"

	Get-ADOUObject -InputObject $InputObject -Category $Category -Base $Base -Scope $Scope -OperatingSystem $OperatingSystem
.PARAMETER InputObject
    A name or list of names. This paramater is not mandatory; wildcards (*) are accepted

    $InputObject = "*"
.PARAMETER Category
	This parameter is manadatory; valid values are: User, Computer, Group

    $Category = "Computer"
.PARAMETER Base
	This paramater is mandatory and is the starting point for your search; values
    must be in Distinguished Name format.

    $Base = 'OU=SurfaceHubs,OU=Mail,DC=DOMAIN,DC=COM'
.PARAMETER Scope
    This paramater is not mandatory and indicates whether your search should be recursive;
    valid values are Base, OneLevel or Subtree

    $Scope = "Subtree"
.PARAMETER OperatingSystem
    This paramater is not mandatory; wildcards (*) are accepted

    $OperatingSystem = "Windows 10*"
.PARAMETER Description
    This paramater is not mandatory; wildcards (*) are accepted

    $Description = "*PC owned by*"
.NOTES
	Author: Travis M Knight; tmknight
	Date: 2017-05-22: tmknight: Inception
	Date: 2017-06-06: tmknight: Added OS version to computer query;
        added mail and display name to user query;
        added validate set to scope and Category;
        set defaults for InputObject and OperatingSystem;
        prompt to continue if Category user, InputObject = "*" and Base = subtree
    Date: 2017-06-12: tmknight: Check for ActiveDirectory module
    Date: 2017-11-30: tmknight: Clean-up code
    Date: 2018-07-03: tmknight: Add description parameter
    Date: 2019-04-24: tmknight: Change name to reflect singular standard;
        Changed Objects to InputObject;
        Moved large data set warning further up
    Date: 2023-01-22: tmknight: Updated example; rename to Get-ADOUObject
#>

function Get-ADOUObject {
    param(
        [Parameter(Mandatory = $false,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [Alias("Objects", "InputObjects")]
        $InputObject = '*',
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 3)]
        [ValidateSet('User', 'Computer', 'Group')]
        $Category,
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1)]
        $Base,
        [Parameter(Mandatory = $false,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 2)]
        [ValidateSet('Base', 'OneLevel', 'Subtree')]
        $Scope = "Base",
        [Parameter(Mandatory = $false,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 4)]
        $OperatingSystem = '*',
        [Parameter(Mandatory = $false,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 5)]
        $Description = '*'
    )

    begin {
        $vars = "out", "rslt", "ldf"
        Remove-Variable $vars -ErrorAction SilentlyContinue

        $out = @()
        $rslt = @()
    }
    process {
        foreach ($obj in $InputObject) {
            ##LDAP filter
            if ($obj -eq '*' -and $Scope -eq 'Subtree') {
                $title = "Potential for Large Data Set"
                $message = "Are you sure you want to return ALL objects from $Base and $Scope"
                $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
                    "Proceed with query."
                $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
                    "Exit"
                $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
                $resp = $host.ui.PromptForChoice($title, $message, $options, 1)
                switch ($resp) {
                    0 {
                        $cont = $true
                    }
                    default {
                        Write-Warning -Message "Exiting upon request"
                        exit
                    }
                }
            }
            else {
                $cont = $true
            }

            if ($cont -eq $true) {
                #"Performing search for ALL USERS from $Base and children - this will take some time..."
                switch ($Category) {
                    "computer" {
                        $ldf = "(&(objectCategory=$Category)(OperatingSystem=$OperatingSystem)(Name=$obj)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))"
                        $out += Get-ADComputer -SearchBase $Base -SearchScope $Scope -LDAPFilter $ldf -Properties Name, Description, OperatingSystem, OperatingSystemVersion, DistinguishedName, Created, LastLogonDate, PasswordLastSet
                    }
                    "user" {
                        $ldf = "(&(objectCategory=$Category)(Name=$obj)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))"
                        $out += Get-ADUser -SearchBase $Base -SearchScope $Scope -LDAPFilter $ldf -Properties Name, displayName, mail, Description, Title, SID, DistinguishedName, Created, LastLogonDate, PasswordLastSet
                    }
                    "group" {
                        $ldf = "(&(objectCategory=$Category)(Name=$obj))"
                        $out += Get-ADGroup -SearchBase $Base -SearchScope $Scope -LDAPFilter $ldf -Properties Name, Description, DistinguishedName, Created
                    }
                }
            }
        }
    }
    end {
        ##Final progress
        if ($out) {
            foreach ($item in $out) {
                switch ($Category) {
                    "computer" {
                        ## Get IP Address from DNS
                        if ($ip = (Resolve-DnsName -Name $item.Name -Type A -ErrorAction SilentlyContinue).IPAddress) {
                        }
                        else {
                            $ip = "Not in DNS"
                        }
                    }
                    default {
                        ## Group members
                        $ip = "N/A"
                        if ($Category -eq "group") {
                            $grpMem = ($item | Get-ADGroupMember).Name -join ", "
                        }
                    }
                }

                $rslt += [PSCustomObject] @{
                    Name                   = $item.Name
                    DisplayName            = $item.displayName
                    Mail                   = $item.mail
                    Description            = $item.Description
                    Title                  = $item.Title
                    SID                    = $item.SID
                    OperatingSystem        = $item.OperatingSystem
                    OperatingSystemVersion = $item.OperatingSystemVersion
                    DistinguishedName      = $item.DistinguishedName
                    Created                = $item.Created
                    GroupMembers           = $grpMem
                    IPAdress               = $ip
                    LastLogonDate          = $item.LastLogonDate
                    PasswordLastSet        = $item.PasswordLastSet
                }
            }

            ## Return results based on Category
            switch ($Category) {
                "computer" {
                    Return $rslt | select-object -Property Name, Description, OperatingSystem, OperatingSystemVersion, DistinguishedName, Created, IPAdress, LastLogonDate, PasswordLastSet | sort-object Name
                }
                "user" {
                    Return $rslt | select-object -Property Name, DisplayName, Mail, Description, Title, SID, DistinguishedName, Created, LastLogonDate, PasswordLastSet | sort-object Name
                }
                "group" {
                    Return $rslt | select-object -Property Name, Description, DistinguishedName, Created, GroupMembers | sort-object Name
                }
            }
        }
        else {
            Write-Warning -Message "No objects discovered for: $Base"
        }
    }
}
