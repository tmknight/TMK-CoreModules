<#
.SYNOPSIS
    Module for testing IP address within subnet boundary.
.DESCRIPTION
    Use this module to test whether a full or partial IP is a member of a subnet boundary.

    Returns True or False
.PARAMETER Subnet
    Enter the full or partial IP address to assess.
.PARAMETER Boundary
    Enter the full boundary to test
.EXAMPLE
    Test-SubnetMember -Subnet 11.166.240 -Boundary 11.166.240.0/24

    True
.EXAMPLE
    Test-SubnetMember -Subnet 11.166.240.111 -Boundary 11.166.240.0/24

    True
.EXAMPLE
    Test-SubnetMember -Subnet 11.166.240 -Boundary 11.39.240.0/23

    False
.NOTES
	Project: https://github.com/tmknight/TMK-CoreModules
.LINK
    Inspired by https://www.padisetty.com
#>
function Test-SubnetMember {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [string]$Subnet,
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1)]
        [string]$Boundary
    )

    Begin {
        # Replace any non-digit characters to ensure only dotted IP address
        $Subnet = ($Subnet -split '\D') -join '.' -replace '(\\{1,}\.){2,}', '.'

        # Separate the network address and length
        $network1, [int]$subnetlen1 = $Subnet.Split('/')
        $network2, [int]$subnetlen2 = $Boundary.Split('/')
    }

    Process {
        # Convert network address to binary
        [uint32] $unetwork1 = NetworkToBinary $network1

        [uint32] $unetwork2 = NetworkToBinary $network2
        # Check if subnet length exists and is less then 32(/32 is host, single ip so no calculation needed) if so convert to binary
        if ($subnetlen1 -lt 32) {
            [uint32] $mask1 = SubToBinary $subnetlen1
        }

        if ($subnetlen2 -lt 32) {
            [uint32] $mask2 = SubToBinary $subnetlen2
        }

        # Compare the results
        if ($mask1 -and $mask2) {
            # If both inputs are subnets check which is smaller and check if it belongs in the larger one
            if ($mask1 -lt $mask2) {
                return CheckSubnetToNetwork $unetwork1 $mask1 $unetwork2
            }
            else {
                return CheckNetworkToSubnet $unetwork2 $mask2 $unetwork1
            }
        }
        ElseIf ($mask1) {
            # If second input is address and first input is subnet check if it belongs
            return CheckSubnetToNetwork $unetwork1 $mask1 $unetwork2
        }
        ElseIf ($mask2) {
            # If first input is address and second input is subnet check if it belongs
            return CheckNetworkToSubnet $unetwork2 $mask2 $unetwork1
        }
        Else {
            # If both inputs are ip check if they match
            CheckNetworkToNetwork $unetwork1 $unetwork2
        }
    }
}

function CheckNetworkToSubnet ([uint32]$un2, [uint32]$ma2, [uint32]$un1) {
    $ReturnArray = '' | Select-Object -Property Condition, Direction

    if ($un2 -eq ($ma2 -band $un1)) {
        $ReturnArray.Condition = $True
        $ReturnArray.Direction = 'Addr1ToAddr2'
        return $ReturnArray.Condition
    }
    else {
        $ReturnArray.Condition = $False
        $ReturnArray.Direction = 'Addr1ToAddr2'
        return $ReturnArray.Condition
    }
}

function CheckSubnetToNetwork ([uint32]$un1, [uint32]$ma1, [uint32]$un2) {
    $ReturnArray = '' | Select-Object -Property Condition, Direction

    if ($un1 -eq ($ma1 -band $un2)) {
        $ReturnArray.Condition = $True
        $ReturnArray.Direction = 'Addr2ToAddr1'
        return $ReturnArray.Condition
    }
    else {
        $ReturnArray.Condition = $False
        $ReturnArray.Direction = 'Addr2ToAddr1'
        return $ReturnArray.Condition
    }
}

function CheckNetworkToNetwork ([uint32]$un1, [uint32]$un2) {
    $ReturnArray = '' | Select-Object -Property Condition, Direction

    if ($un1 -eq $un2) {
        $ReturnArray.Condition = $True
        $ReturnArray.Direction = 'Addr1ToAddr2'
        return $ReturnArray.Condition
    }
    else {
        $ReturnArray.Condition = $False
        $ReturnArray.Direction = 'Addr1ToAddr2'
        return $ReturnArray.Condition
    }
}

function SubToBinary ([int]$sub) {
    return ((-bnot [uint32]0) -shl (32 - $sub))
}

function NetworkToBinary ($network) {
    $a = [uint32[]]$network.split('.')
    return ($a[0] -shl 24) + ($a[1] -shl 16) + ($a[2] -shl 8) + $a[3]
}
