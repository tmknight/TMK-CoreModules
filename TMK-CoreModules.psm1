## Gather all public scripts
$OSDPublicFunctions = @( Get-ChildItem -Path $PSScriptRoot\public\*.ps1 -Recurse -ErrorAction SilentlyContinue )

## Expose the functions
foreach ($Import in $OSDPublicFunctions) {
    Try {
        . $Import.FullName
    }
    Catch {
        Write-Error -Message "Failed to import function $($Import.FullName): $_"
    }
}

## Export individual functions
try {
    Export-ModuleMember -Function $OSDPublicFunctions.BaseName
}
catch {
    $_.Exception.Message
}

## Final export for use by the root module
Export-ModuleMember -Function * -Alias *
