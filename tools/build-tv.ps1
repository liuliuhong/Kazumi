param(
    [string]$ToolchainRoot = 'D:\KazumiToolchain',
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$TvVersion = '1.2.0',
    [ValidateRange(20308, 2100000000)]
    [int]$TvBuildNumber = 20307120
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/use-android.ps1" -ToolchainRoot $ToolchainRoot
Push-Location (Split-Path $PSScriptRoot -Parent)
try {
    $taskVersionName = "Kazumi_tv_base2.3.7_$TvVersion"
    flutter build apk --release --dart-define=KAZUMI_TV=true --target-platform=android-arm,android-arm64 --build-name=$taskVersionName --build-number=$TvBuildNumber
    if ($LASTEXITCODE -ne 0) { throw 'TV APK build failed.' }
    New-Item -ItemType Directory -Force -Path 'build/tv' | Out-Null
    Copy-Item -LiteralPath 'build/app/outputs/flutter-apk/app-release.apk' -Destination 'build/tv/Kazumi-TV-arm-release.apk'
    $taskBadging = & "$env:ANDROID_HOME/build-tools/36.0.0/aapt.exe" dump badging 'build/tv/Kazumi-TV-arm-release.apk'
    if ($LASTEXITCODE -ne 0 -or !($taskBadging -match "package: name='com.predidit.kazumi.tv'")) {
        throw 'APK did not contain the expected TV application ID.'
    }
    if (!($taskBadging -match "native-code:.*'armeabi-v7a'")) {
        throw 'APK does not support the 32-bit Xiaomi box.'
    }
    $taskBadging | Where-Object { $_ -match '^(package:|sdkVersion:|targetSdkVersion:|application-label:|launchable-activity:|leanback-launchable-activity:|native-code:)' }
    & "$env:ANDROID_HOME/build-tools/36.0.0/apksigner.bat" verify 'build/tv/Kazumi-TV-arm-release.apk'
    if ($LASTEXITCODE -ne 0) { throw 'APK signature verification failed.' }
    $taskReleaseDir = Join-Path 'build/tv' $taskVersionName
    New-Item -ItemType Directory -Force -Path $taskReleaseDir | Out-Null
    $taskApkName = "$taskVersionName-arm.apk"
    Copy-Item -LiteralPath 'build/tv/Kazumi-TV-arm-release.apk' -Destination (Join-Path $taskReleaseDir $taskApkName)
    $taskHash = (Get-FileHash -LiteralPath (Join-Path $taskReleaseDir $taskApkName) -Algorithm SHA256).Hash.ToLowerInvariant()
    $taskAbis = @([regex]::Matches(($taskBadging | Where-Object { $_ -match '^native-code:' }), "'([^']+)'" ) | ForEach-Object { $_.Groups[1].Value })
    $taskMinSdk = [int][regex]::Match(($taskBadging | Where-Object { $_ -match '^sdkVersion:' }), "'([0-9]+)'" ).Groups[1].Value
    $taskMetadata = [ordered]@{ schemaVersion=1; channel='stable'; packageName='com.predidit.kazumi.tv'; baseVersion='2.3.7'; tvVersion=$TvVersion; versionName=$taskVersionName; versionCode=$TvBuildNumber; minSdk=$taskMinSdk; abis=$taskAbis; fileName=$taskApkName; size=(Get-Item -LiteralPath (Join-Path $taskReleaseDir $taskApkName)).Length; sha256=$taskHash } | ConvertTo-Json -Depth 4
    [IO.File]::WriteAllText((Join-Path $PWD "$taskReleaseDir/update.json"), $taskMetadata + "`n", [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $PWD "$taskReleaseDir/SHA256SUMS.txt"), "$taskHash  $taskApkName`n", [Text.UTF8Encoding]::new($false))
    Get-FileHash -LiteralPath 'build/tv/Kazumi-TV-arm-release.apk' -Algorithm SHA256
} finally {
    Pop-Location
}
