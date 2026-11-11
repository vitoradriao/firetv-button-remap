# Downloads the parts of the Android SDK this project needs (about 125 MB) into .\sdk:
# adb, the build tools and the Android 15 platform. Running it means accepting the Android SDK
# license: https://developer.android.com/studio/terms
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$sdk = "$PSScriptRoot\sdk"
$base = 'https://dl.google.com/android/repository'
# file, SHA-1 published in Google's repository2-3.xml, folder inside the zip, destination in .\sdk
$parts = @(
    @('platform-tools_r37.0.3-win.zip', 'b3fde5239ad89229d5a9178375b81c9887a24172', 'platform-tools', 'platform-tools'),
    @('build-tools_r36_windows.zip', 'f16ccffd34de8790dede813a6c7d8e2c11a27b50', 'android-16', 'build-tools\36.0.0'),
    @('platform-35_r02.zip', '0bb560a90a7a2cbd0dd8348224d518b638fe7949', 'android-35', 'platforms\android-35')
)
$tmp = "$sdk\download"
New-Item -ItemType Directory $tmp -Force | Out-Null
foreach ($p in $parts) {
    $file, $sha1, $inner, $dest = $p
    if (Test-Path "$sdk\$dest") { Write-Host "Ja existe: sdk\$dest"; continue }
    Write-Host "Baixando $file..."
    # curl.exe ships with Windows 10/11; Invoke-WebRequest can stall on large files.
    & curl.exe -fsSL -o "$tmp\$file" "$base/$file"
    if ($LASTEXITCODE) { throw "Falha ao baixar $file (curl $LASTEXITCODE)." }
    $got = (Get-FileHash "$tmp\$file" -Algorithm SHA1).Hash.ToLower()
    if ($got -ne $sha1) { throw "Checksum errado em $file (esperado $sha1, veio $got)" }
    Expand-Archive "$tmp\$file" "$tmp\x" -Force
    New-Item -ItemType Directory (Split-Path "$sdk\$dest") -Force | Out-Null
    Move-Item "$tmp\x\$inner" "$sdk\$dest"
    Remove-Item "$tmp\x", "$tmp\$file" -Recurse -Force
}
Remove-Item $tmp -Recurse -Force
Write-Host "SDK pronto em $sdk"
