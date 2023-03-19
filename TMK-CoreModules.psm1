## Gather all public scripts
$PublicFunctions = @( Get-ChildItem -Path $PSScriptRoot\public\*.ps1 -Recurse -ErrorAction SilentlyContinue )

## Expose the functions
foreach ($Import in $PublicFunctions) {
    Try {
        . $Import.FullName
    }
    Catch {
        Write-Error -Message "Failed to import function $($Import.FullName): $($_.Exception.Message)"
    }
}

## Export individual functions
try {
    Export-ModuleMember -Function $PublicFunctions.BaseName
}
catch {
    $_.Exception.Message
}

## Final export for use by the root module
Export-ModuleMember -Function * -Alias *
