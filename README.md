# TMK-CoreModules

[![GitHubPublish][GitHubPublishBadge]][GitHubPublishLink]

Collection of PowerShell modules to ease system management in the enterprise.

The latest version is also available from [PowerShell Gallery][GitHubPublishLink]:

`Install-Module -Name TMK-CoreModules -Repository PSGallery -Force -WarningAction SilentlyContinue`

| Module                    | Description                                                                                                                                |
|:-------------------------:|:------------------------------------------------------------------------------------------------------------------------------------------:|
| **Copy-WithProgress**     | Module for writing file copy progress                                                                                                      |
| **Find-File**             | Module for quickly finding files using multithreading                                                                                      |
| **Get-ADGroupMembership** | Module for performing recursive lookup of the groups to which an AD object belongs                                                         |
| **Get-ADOUObject**        | Module to simplify returning Active Directory object details                                                                               |
| **Get-ADSite**            | Module for returning Active Directory Site (ADSS) details                                                                                  |
| **Get-NetworkInfo**       | Module to return details about interfaces on your local machine                                                                            |
| **Invoke-Multithreading** | Module to perform multi-threaded tasks on large target sets (written before [ForEach-Parallel](https://github.com/PowerShell/PowerShell/pull/10229) was implemented in PowerShell Core)           |
| **Test-FastPing**         | Module for performing a lightnig quick ping and TCP port check (best when used in conjunction with multi-threading on large target list)   |
| **Test-SubnetMember**     | Module for testing if IP address (or portion) within subnet boundary                                                                       |
| **Write-InlineProgress**  | Module for writing progress (written particularly for the VS Code Host when it did not support Write-Progress...more or less obsolete now) |

[GitHubPublishBadge]: https://github.com/tmknight/TMK-CoreModules/actions/workflows/publish-module.yml/badge.svg
[GitHubPublishLink]: https://www.powershellgallery.com/packages/TMK-CoreModules/
