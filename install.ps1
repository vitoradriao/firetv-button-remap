# Builds tv-redirect with your rules, installs it on the Fire TV and turns the service on.
# Example: .\install.ps1 -Ip 192.168.1.24 -Rules "deeplink_prime_video>com.hbo.hbonow;asin=B08BG9MPT9>org.smarttube.stable"
param(
    [Parameter(Mandatory)][string]$Ip,
    [Parameter(Mandatory)][string]$Rules
)
$ErrorActionPreference = 'Stop'
$adb = "$PSScriptRoot\sdk\platform-tools\adb.exe"
if (-not (Test-Path $adb)) { throw "Rode .\get-sdk.ps1 primeiro." }
$s = if ($Ip -match ':') { $Ip } else { "${Ip}:5555" }
$svc = 'tv.redirect/tv.redirect.ButtonService'

& $adb connect $s | Out-Host
$state = (& $adb -s $s get-state 2>&1 | Out-String).Trim()
if ($state -ne 'device') {
    throw "Fire TV nao conectado ($state). Aceite 'Permitir depuracao' na TV e rode de novo."
}

& "$PSScriptRoot\build.ps1" -Rules $Rules
& $adb -s $s install -r "$PSScriptRoot\out\tv-redirect.apk" | Out-Host
if ($LASTEXITCODE) { throw "Falha ao instalar." }
& $adb -s $s shell pm grant tv.redirect android.permission.READ_LOGS
if ($LASTEXITCODE) { throw "Falha ao conceder READ_LOGS." }

# The service process must start after READ_LOGS is granted, or it can't read the system log.
# force-stop kills it (and takes it off the accessibility list); then we turn it back on.
$since = (& $adb -s $s shell "date +'%m-%d %H:%M:%S.000'" | Out-String).Trim()
& $adb -s $s shell am force-stop tv.redirect
Start-Sleep 1
# Keep other accessibility services (e.g. a custom launcher) on; add ours to the list.
$enabled = (& $adb -s $s shell settings get secure enabled_accessibility_services | Out-String).Trim()
$list = @($enabled -split ':' | Where-Object { $_ -and $_ -ne 'null' -and $_ -notlike 'tv.redirect/*' }) + $svc
& $adb -s $s shell settings put secure enabled_accessibility_services ($list -join ':')
& $adb -s $s shell settings put secure accessibility_enabled 1
Start-Sleep 3

$log = & $adb -s $s shell "logcat -d -T '$since' -s tv-redirect:I" | Select-String 'ativo com regras' | Select-Object -Last 1
if (-not $log) { throw "O servico nao iniciou. Veja Solucao de problemas no README." }
Write-Host "Pronto. $($log.Line.Split(':',4)[-1].Trim())"
