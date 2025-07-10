# File logging version
"Starting script..." | Out-File -FilePath "debug.log" -Append

try {
    "Loading assemblies..." | Out-File -FilePath "debug.log" -Append
    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore  
    Add-Type -AssemblyName WindowsBase
    "Assemblies loaded" | Out-File -FilePath "debug.log" -Append
    
    # Test module enumeration
    "Getting modules..." | Out-File -FilePath "debug.log" -Append
    $modules = Get-Module
    "Found $($modules.Count) loaded modules" | Out-File -FilePath "debug.log" -Append
    
    "Script completed" | Out-File -FilePath "debug.log" -Append
} catch {
    "Error: $($_.Exception.Message)" | Out-File -FilePath "debug.log" -Append
}
