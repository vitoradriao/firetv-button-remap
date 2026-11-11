# Builds out\tv-redirect.apk. -Rules: "text in the button's log line>package to open;..."
# Example: .\build.ps1 -Rules "deeplink_prime_video>com.hbo.hbonow;asin=B08BG9MPT9>org.smarttube.stable"
param([Parameter(Mandatory)][string]$Rules)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$bt = (Get-ChildItem "$root\sdk\build-tools" | Sort-Object { [version]$_.Name } | Select-Object -Last 1).FullName
$androidJar = (Get-ChildItem "$root\sdk\platforms\*\android.jar" | Sort-Object FullName | Select-Object -Last 1).FullName
if (-not $bt -or -not $androidJar) { throw "Falta o SDK em $root\sdk (build-tools e platforms)." }
$javaHome = ((& java -XshowSettings:properties -version 2>&1 | Out-String) -split "`n" | Where-Object { $_ -match 'java\.home' }).Split('=')[1].Trim()

$work = "$root\out\work"
Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory "$work\classes" -Force | Out-Null

& javac --release 8 -nowarn -classpath $androidJar -d "$work\classes" (Get-ChildItem "$root\src" -Recurse -Filter *.java).FullName
if ($LASTEXITCODE) { throw "javac falhou" }
& "$bt\d8.bat" --release --min-api 22 --lib $androidJar --output $work (Get-ChildItem "$work\classes" -Recurse -Filter *.class).FullName
if ($LASTEXITCODE) { throw "d8 falhou" }

(Get-Content "$root\AndroidManifest.template.xml" -Raw).Replace('@RULES@', [Security.SecurityElement]::Escape($Rules)) |
    Set-Content "$work\AndroidManifest.xml" -Encoding utf8
& "$bt\aapt2.exe" link -o "$work\unsigned.apk" -I $androidJar --manifest "$work\AndroidManifest.xml"
if ($LASTEXITCODE) { throw "aapt2 falhou" }

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::Open("$work\unsigned.apk", 'Update')
try { [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, "$work\classes.dex", 'classes.dex') | Out-Null } finally { $zip.Dispose() }

& "$bt\zipalign.exe" -f -p 4 "$work\unsigned.apk" "$work\aligned.apk"
if ($LASTEXITCODE) { throw "zipalign falhou" }

# Local signing key, created once; keep it to install updates over the same APK.
$ks = "$root\redirect.keystore"
if (-not (Test-Path $ks)) {
    & "$javaHome\bin\keytool.exe" -genkeypair -keystore $ks -alias redirect -keyalg RSA -keysize 2048 -validity 10000 `
        -storepass redirect -keypass redirect -dname "CN=tv-redirect"
    if ($LASTEXITCODE) { throw "keytool falhou" }
}
$apk = "$root\out\tv-redirect.apk"
& "$bt\apksigner.bat" sign --ks $ks --ks-pass pass:redirect --out $apk "$work\aligned.apk"
if ($LASTEXITCODE) { throw "apksigner falhou" }
Remove-Item $work -Recurse -Force
Write-Host "Pronto: $apk"
