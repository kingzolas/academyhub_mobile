$ErrorActionPreference = 'Stop'

$appName = if ($env:APP_NAME) { $env:APP_NAME } else { 'academyhub-mobile-web' }
$flutterVersion = if ($env:FLUTTER_VERSION) { $env:FLUTTER_VERSION } else { '3.41.1' }
$versionLine = (Select-String -Path pubspec.yaml -Pattern '^version:\s*(\S+)' | Select-Object -First 1).Matches.Groups[1].Value
if ([string]::IsNullOrWhiteSpace($versionLine)) { throw 'pubspec.yaml does not declare version' }
$appVersion, $appBuildNumber = $versionLine -split '\+', 2
if ([string]::IsNullOrWhiteSpace($appBuildNumber)) { $appBuildNumber = '0' }

try { $gitCommit = (git rev-parse HEAD 2>$null).Trim() } catch { $gitCommit = 'nogit' }
if ([string]::IsNullOrWhiteSpace($gitCommit)) { $gitCommit = 'nogit' }
$commitRef = if ($env:COMMIT_REF) { $env:COMMIT_REF } else { $gitCommit }
$deployedAt = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
$localTimestamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')

function Assert-SafeValue([string]$Name, [string]$Value) {
  if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^[A-Za-z0-9._:-]+$') {
    throw "invalid or missing $Name"
  }
}

function Assert-ExpectedFlutterVersion {
  $flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
  if ($null -eq $flutterCommand) {
    throw "Flutter $flutterVersion must be installed on PATH for local Windows builds. The Netlify Linux installer is intentionally not used here."
  }
  $versionOutput = (& flutter --version 2>&1 | Out-String)
  if ($versionOutput -notmatch "(?m)^Flutter\s+$([regex]::Escape($flutterVersion))(\s|$)") {
    throw "Flutter $flutterVersion is required, but a different version was found:`n$versionOutput"
  }
  Write-Host '[BuildWeb] Flutter SDK validado'
  Write-Host "[BuildWeb] $($versionOutput.Trim().Split([Environment]::NewLine)[0])"
}

if ($env:NETLIFY -eq 'true') {
  Assert-SafeValue 'DEPLOY_ID' $env:DEPLOY_ID
  Assert-SafeValue 'COMMIT_REF' $commitRef
  Assert-SafeValue 'BUILD_ID' $env:BUILD_ID
  $buildId = "netlify-$($env:DEPLOY_ID)-$commitRef"
  $pipelineBuildId = $env:BUILD_ID
  $buildContext = if ($env:CONTEXT) { $env:CONTEXT } else { 'production' }
} else {
  Assert-SafeValue 'local commit reference' $commitRef
  $buildId = if ($env:APP_BUILD_ID) { $env:APP_BUILD_ID } else { "local-$($commitRef.Substring(0, [Math]::Min(12, $commitRef.Length)))-$localTimestamp" }
  Assert-SafeValue 'APP_BUILD_ID' $buildId
  $pipelineBuildId = "local-$localTimestamp"
  $buildContext = 'local'
}
if ($buildId -like '*dev-local*') { throw 'dev-local is not a valid build identifier' }

Write-Host "[BuildWeb] app=$appName version=$appVersion+$appBuildNumber"
Write-Host "[BuildWeb] buildId=$buildId commit=$commitRef"
Assert-ExpectedFlutterVersion
if ($env:NETLIFY -eq 'true') {
  & flutter config --no-analytics
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
Write-Host '[BuildWeb] Executando flutter pub get'
& flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if (Test-Path build\web) { Remove-Item -LiteralPath build\web -Recurse -Force }
Write-Host '[BuildWeb] Executando flutter build web'
flutter build web --release --pwa-strategy=none `
  --dart-define=APP_BUILD_ID=$buildId `
  --dart-define=APP_NAME=$appName `
  --dart-define=APP_UPDATE_LOGS=$(if ($env:APP_UPDATE_LOGS) { $env:APP_UPDATE_LOGS } else { 'false' }) `
  --dart-define=APP_UPDATE_CHECK_SECONDS=$(if ($env:APP_UPDATE_CHECK_SECONDS) { $env:APP_UPDATE_CHECK_SECONDS } else { '300' })
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

foreach ($file in @('index.html', 'main.dart.js', 'flutter_bootstrap.js', 'flutter_service_worker.js')) {
  if (-not (Test-Path (Join-Path build\web $file))) { throw "missing generated artifact: $file" }
}

$version = [ordered]@{
  app = $appName; version = $appVersion; buildNumber = $appBuildNumber
  buildId = $buildId; commit = $commitRef; deployedAt = $deployedAt
  context = $buildContext; pipelineBuildId = $pipelineBuildId
}
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText((Join-Path (Get-Location) 'build\web\version.json'), (($version | ConvertTo-Json) + [Environment]::NewLine), $utf8NoBom)
Copy-Item web\_headers build\web\_headers -Force
Copy-Item web\_redirects build\web\_redirects -Force
Copy-Item web\404.html build\web\404.html -Force
Copy-Item web\flutter_service_worker.js build\web\flutter_service_worker.js -Force
if ((Get-Item build\web\flutter_service_worker.js).Length -eq 0) { throw 'Flutter migration worker is empty' }

if (-not (Select-String -Path build\web\main.dart.js -SimpleMatch $buildId -Quiet)) { throw 'APP_BUILD_ID was not embedded in main.dart.js' }
if (Select-String -Path build\web\* -Pattern 'dev-local' -SimpleMatch -Quiet -ErrorAction SilentlyContinue) { throw 'generated artifact contains forbidden dev-local value' }
Write-Host '[BuildWeb] fresh publish directory is ready at build/web'
