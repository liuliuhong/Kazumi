param([string]$ToolchainRoot = 'D:\KazumiToolchain')

$taskRoot = [IO.Path]::GetFullPath($ToolchainRoot)
$taskJdk = @(Get-ChildItem -LiteralPath (Join-Path $taskRoot 'jdk') -Directory | Where-Object {
    Test-Path -LiteralPath (Join-Path $_.FullName 'bin/java.exe')
})
if ($taskJdk.Count -ne 1) { throw 'Run tools/setup-android.ps1 to install the toolchain first.' }
$env:JAVA_HOME = $taskJdk[0].FullName
$env:ANDROID_HOME = Join-Path $taskRoot 'android-sdk'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:PUB_CACHE = Join-Path $taskRoot 'pub-cache'
$env:GRADLE_USER_HOME = Join-Path $taskRoot 'gradle-cache'
# Kotlin incremental caches cannot relativize plugin sources on D: against a
# project on C:. Use ordinary compilation for this portable Windows toolchain.
Set-Item -Path 'Env:ORG_GRADLE_PROJECT_kotlin.incremental' -Value 'false'
# This toolchain is for Android. Desktop plugin symlinks need Windows Developer
# Mode, which an Android build does not require. Only this process is affected.
$env:FLUTTER_WINDOWS = 'false'
$env:FLUTTER_LINUX = 'false'
$env:FLUTTER_MACOS = 'false'
$env:Path = "$taskRoot\flutter\bin;$env:JAVA_HOME\bin;$env:ANDROID_HOME\platform-tools;$env:Path"
