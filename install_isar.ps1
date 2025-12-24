$version = "3.1.0+1"
# Direct link to isar.wasm for 3.1.0+1
$url = "https://github.com/isar/isar/releases/download/3.1.0+1/isar.wasm"

$dest = "web/isar.wasm"
$buildDest = "build/web/isar.wasm"

Write-Host "Downloading isar.wasm from $url..."

try {
    # Using curl-like behavior with Invoke-WebRequest
    Invoke-WebRequest -Uri $url -OutFile $dest -UserAgent "Mozilla/5.0"
    Write-Host "Downloaded to $dest"
} catch {
    Write-Host "Download failed: $_"
    exit 1
}

if (Test-Path "build/web") {
    Copy-Item $dest $buildDest -Force
    Write-Host "Copied to $buildDest"
}

Write-Host "Done! PLEASE RELOAD THE PAGE."
