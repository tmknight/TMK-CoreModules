<#
.SYNOPSIS
    Get all information about interfaces on your local machine

.DESCRIPTION
    Particularly useful for Core
    Will not work with Core less than 7.x on WSL; only Core greater than 7.x currently works in WSL

.PARAMETER AddressFamily
    This parameter is OPTIONAL
    This parameter takes a string that has a value of either "IPv4" or "IPv6"

.PARAMETER OperationalStatus
    This parameter is OPTIONAL
    This parameter takes a string that has a value of either "UP" or "DOWN"
    OperationalStatus values are not returned in WSL

.EXAMPLE
    # On Windows
    PS C:\Users\testadmin> Get-NetworkInfo -AddressFamily "IPv4" OperationalStatus "UP"

.EXAMPLE
    # On Linux
    PS /home/pdadmin/Downloads> Get-NetworkInfo -AddressFamily "IPv4" -OperationalStatus "DOWN"

.LINK
    Based on the code from:
    https://github.com/pldmgg/misc-powershell/blob/master/MyFunctions/PowerShellCore_Compatible/Get-NetworkInfo.ps1
#>
function Get-NetworkInfo {
    [CmdletBinding()]
    param
    ()

    DynamicParam {
        if (($PSVersionTable.PSVersion).ToString() -lt 7 -and $null -ne $env:WSL_DISTRO_NAME) {
            throw [System.IO.IOException] "You are currently working in the Windows Subsystem for Linux with Core less than 7.x; this module does not currently work in WSL with Core less than 7.x"
            exit
        }
        else {
            $paramDictionary = New-Object -Type System.Management.Automation.RuntimeDefinedParameterDictionary

            ## AddressFamily
            $attributes0 = New-Object -Type System.Management.Automation.ParameterAttribute
            $attributeCollection0 = New-Object -Type System.Collections.ObjectModel.Collection[System.Attribute]

            $attributes0.Mandatory = $false
            $attributes0.Position = 0
            $valSet0 = New-Object -Type System.Management.Automation.ValidateSetAttribute('IPv4', 'IPv6')
            $attributeCollection0.Add($attributes0)
            $attributeCollection0.Add($valSet0)
            $dynParam0 = New-Object -Type System.Management.Automation.RuntimeDefinedParameter("AddressFamily", [string], $attributeCollection0)

            ## Build the final paramaters
            $paramDictionary.Add("AddressFamily", $dynParam0)

            if ($null -eq $env:WSL_DISTRO_NAME) {
                ## OperationalStatus values are not returned in WSL
                $attributes1 = New-Object -Type System.Management.Automation.ParameterAttribute
                $attributeCollection1 = New-Object -Type System.Collections.ObjectModel.Collection[System.Attribute]

                $attributes1.Mandatory = $false
                $attributes1.Position = 1
                $valSet1 = New-Object -Type System.Management.Automation.ValidateSetAttribute('UP', 'DOWN')
                $attributeCollection1.Add($attributes1)
                $attributeCollection1.Add($valSet1)
                $dynParam1 = New-Object -Type System.Management.Automation.RuntimeDefinedParameter("OperationalStatus", [string], $attributeCollection1)

                ## Build the final paramaters
                $paramDictionary.Add("OperationalStatus", $dynParam1)
            }

            return $paramDictionary
        }
    }

    Begin {
        $AddressFamily = $PSBoundParameters.AddressFamily
        $OperationalStatus = $PSBoundParameters.OperationalStatus

        if ($AddressFamily) {
            if ($AddressFamily -eq "IPv4") {
                $AddrFam = "InterNetwork"
            }
            if ($AddressFamily -eq "IPv6") {
                $AddrFam = "InterNetworkV6"
            }
        }
    }

    Process {
        try {
            [System.Collections.Arraylist]$PSObjectCollection = @()
            $interfaces = [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()

            $InterfacesToExplore = $interfaces
            if ($OperationalStatus) {
                $InterfacesToExplore = $InterfacesToExplore | Where-Object { $_.OperationalStatus -eq $OperationalStatus }
            }
            if ($AddressFamily) {
                $InterfacesToExplore = $InterfacesToExplore | Where-Object { $($_.GetIPProperties().UnicastAddresses | ForEach-Object { $_.Address.AddressFamily }) -contains $AddrFam }
            }

            foreach ($adapter in $InterfacesToExplore) {
                $ipprops = $adapter.GetIPProperties()
                $ippropsPropertyNames = $($ipprops | Get-Member -MemberType Property).Name

                if ($AddressFamily) {
                    $UnicastAddressesToExplore = $ipprops.UnicastAddresses | Where-Object { $_.Address.AddressFamily -eq $AddrFam }
                }
                else {
                    $UnicastAddressesToExplore = $ipprops.UnicastAddresses
                }

                foreach ($ip in $UnicastAddressesToExplore) {
                    $FinalPSObject = [pscustomobject]@{ }

                    $adapterPropertyNames = $($adapter | Get-Member -MemberType Property).Name
                    foreach ($adapterPropName in $adapterPropertyNames) {
                        $FinalPSObjectMemberCheck = $($FinalPSObject | Get-Member -MemberType NoteProperty).Name
                        if ($FinalPSObjectMemberCheck -notcontains $adapterPropName) {
                            $FinalPSObject | Add-Member -MemberType NoteProperty -Name $adapterPropName -Value $($adapter.$adapterPropName)
                        }
                    }

                    foreach ($ippropsPropName in $ippropsPropertyNames) {
                        $FinalPSObjectMemberCheck = $($FinalPSObject | Get-Member -MemberType NoteProperty).Name
                        if ($FinalPSObjectMemberCheck -notcontains $ippropsPropName -and
                            $ippropsPropName -ne "UnicastAddresses" -and $ippropsPropName -ne "MulticastAddresses") {
                            $FinalPSObject | Add-Member -MemberType NoteProperty -Name $ippropsPropName -Value $($ipprops.$ippropsPropName)
                        }
                    }

                    $ipUnicastPropertyNames = $($ip | Get-Member -MemberType Property).Name
                    foreach ($UnicastPropName in $ipUnicastPropertyNames) {
                        $FinalPSObjectMemberCheck = $($FinalPSObject | Get-Member -MemberType NoteProperty).Name
                        if ($FinalPSObjectMemberCheck -notcontains $UnicastPropName) {
                            $FinalPSObject | Add-Member -MemberType NoteProperty -Name $UnicastPropName -Value $($ip.$UnicastPropName)
                        }
                    }

                    $null = $PSObjectCollection.Add($FinalPSObject)
                }
            }
            return $PSObjectCollection
        }
        catch {
            $_
        }
    }
}
