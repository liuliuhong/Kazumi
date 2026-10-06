param(
    [string]$ToolchainRoot = 'D:\KazumiToolchain',
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$TvVersion = '1.1.0',
    [ValidateRange(20308, 2100000000)]
    [int]$TvBuildNumber = 20307110
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
    Get-FileHash -LiteralPath 'build/tv/Kazumi-TV-arm-release.apk' -Algorithm SHA256
} finally {
    Pop-Location
}
