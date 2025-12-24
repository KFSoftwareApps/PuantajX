$dest = "web/isar.wasm"
$buildDest = "build/web/isar.wasm"
$version = "3.1.0+1"

# List of URLs to try
$urls = @(
    "https://unpkg.com/isar@$version/dist/isar.wasm",
    "https://cdn.jsdelivr.net/npm/isar@$version/dist/isar.wasm",
    "https://github.com/isar/isar/releases/download/$version/isar.wasm",
    "https://github.com/isar/isar/releases/download/v$version/isar.wasm"
)

# Create Security Protocol for simpler SSL handling
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

foreach ($url in $urls) {
    Write-Host "Trying to download from: $url"
    try {
        Invoke-WebRequest -Uri $url -OutFile $dest -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" -TimeoutSec 30
        if (Test-Path $dest) {
            $fileSize = (Get-Item $dest).Length
            if ($fileSize -gt 1000) { # Basic check to ensure we didn't get a strict text error page
                Write-Host "Success! Downloaded from $url"
                
                # Copy to build directory if it exists
                if (Test-Path "build/web") {
                    Copy-Item $dest $buildDest -Force
                    Write-Host "Copied to $buildDest"
                }
                exit 0
            } else {
                 Write-Host "File too small ($fileSize bytes). Probably an error page."
            }
        }
    } catch {
        Write-Host "Failed: $_"
    }
}

Write-Error "All download attempts failed."
exit 1
