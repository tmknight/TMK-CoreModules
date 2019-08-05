<#
.SYNOPSIS
   Module for performing ping and TCP port check.
.DESCRIPTION
   Use this module to perform connection state scripting.
   Combine with the Start-Multithreading module to perform on large target sets.
.EXAMPLE
	Fast-Ping -ComputerName $cn -Port $prt

    Name          : TEST-00
    Online        : True
    A             : Unable to resolve
    AAAA          : Unable to resolve
    Port 445 Open : True
 .PARAMETER ComputerName
	This parameter is required and must be in the form of valid DNS name or IP address.

    $ComputerName = 'TEST-00'
 .PARAMETER Port
	This parameter is optional, though must be in the form of a valid TCP port.
    if not defined, port 445 will be used.

    $Port = 445
 .PARAMETER Lookup
	This parameter is optional.  If invoked, there are no values, it is a switch to true

    $Lookup = $false
.NOTES
	Author: Travis M Knight
	Date: 2017-04-28
    v0-1: Inception
    v0-6: Update to permit IP address
#>

Function Start-FastPing {
    [CmdletBinding()]
    Param(
        ## ComputerName, required.
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)]
            [ValidateScript( {
            if ($_ -match "^\w" -or $_ -match "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}") {
                $true
            }
            else {
                Throw [System.Management.Automation.ValidationMetadataException] "Please only enter valid DNS name or IP address"
                Start-Sleep -Seconds 60
            }
        } )]
[string]$ComputerName,

        ## TCP port to knock, optional
        [Parameter(Mandatory = $false,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1)]
        [int]$Port = '445',

        ## Perform lookup
        [Parameter(Mandatory = $false,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 2)]
        [switch]$Lookup = $false
    )

    Begin {
        $ErrorActionPreference = "SilentlyContinue"

        ## Clear variables
        $vars = 'rslt'
        Remove-Variable $vars
    }
    Process {
        ## Test device availability
        Function fastping {
            [CmdletBinding()]
            Param(
                [String]$cn
            )

            ## Initialize ping object
            $ping = New-Object System.Net.NetworkInformation.Ping
            try {
                ## Attempt connection, 300 millisecond timeout, returns boolean
                switch ($ping.send($cn, 300).status) {
                    "Success" { Return $true }
                    Default {
                        ## Do one more should the first one fail
                        switch ($ping.send($cn, 300).status) {
                            "Success" { Return $true }
                            Default { Return $false }
                        }
                    }
                }
            }
            catch {
                ## Any failure returns false
                Return $false
            }
        }

        Function portKnock {
            [CmdletBinding()]
            param (
                [string]$cn,
                [int]$prt
            )

            ## Initialize object
            $connection = New-Object Net.Sockets.TcpClient
            try {
                ## Attempt connection, 300 millisecond timeout, returns boolean
                $open = ($connection.BeginConnect($cn, $prt, $Null, $Null)).AsyncWaitHandle.WaitOne(300)
            }
            catch {
                $open = $false
            }

            ## Cleanup
            $connection.Close()

            Return $open
        }

        Function lookup {
            [CmdletBinding()]
            Param(
                [string]$cn,
                [bool]$Lookup
            )

            if ($Lookup -eq $false) {
                $ipv4 = "N/A"
                $ipv6 = "N/A"
                $hName = "N/A"
            }
            elseif ($dns = Resolve-DnsName -Name $cn) {
                ForEach ($rdn in $dns) {
                    if ($rdn.type -eq "A") {
                        $ipv4 = $rdn.ipaddress
                    }
                    else {
                        $ipv4 = "Unable to resolve"
                    }

                    if ($rdn.type -eq "AAAA") {
                        $ipv6 = $rdn.ipaddress
                    }
                    else {
                        $ipv6 = "Unable to resolve"
                    }

                    ## Reverse lookup when cn is an IP address
                    switch -Regex ($cn) {
                        ## IP Address
                        "^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$" {
                            $hName = $rdn.NameHost
                            $ipv4 = "N/A"
                            $ipv6 = "N/A"
                        }
                        ## Hostname
                        Default {
                            $hName = $cn
                        }
                    }
                }
            }
            else {
                $ipv4 = "Unable to resolve"
                $ipv6 = "Unable to resolve"
                $hName = "Unable to resolve"
            }
            Return $ipv4, $ipv6, $hName
        }

        ## NS Lookup
        $lku = lookup -cn $ComputerName -Lookup $Lookup

        ## Results
        $rslt = [PSCustomObject] @{
            ComputerName      = $ComputerName
            HostName          = $lku[2]
            PingSucceeded     = (fastping -cn $ComputerName)
            A                 = $lku[0]
            AAAA              = $lku[1]
            "Port $Port Open" = (portKnock -cn $ComputerName -prt $Port)
        }
    }
    End {
        Return $rslt
    }
}
