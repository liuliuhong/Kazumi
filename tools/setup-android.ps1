param(
    [string]$ToolchainRoot = 'D:\KazumiToolchain'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$taskRoot = [IO.Path]::GetFullPath($ToolchainRoot)
$taskDownloads = Join-Path $taskRoot 'downloads'
New-Item -ItemType Directory -Force -Path $taskRoot, $taskDownloads | Out-Null

function Get-TaskDownload([string]$Uri, [string]$Destination, [string]$Sha256) {
    if (!(Test-Path -LiteralPath $Destination)) {
        Write-Output "Downloading $([IO.Path]::GetFileName($Destination))"
        Invoke-WebRequest -Uri $Uri -OutFile "$Destination.partial" -TimeoutSec 1800
        Move-Item -LiteralPath "$Destination.partial" -Destination $Destination
    }
    $taskHash = (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash
    if ($Sha256 -and $taskHash -ne $Sha256) {
        throw "Checksum mismatch for $Destination"
    }
    Write-Output "SHA256 $([IO.Path]::GetFileName($Destination)): $taskHash"
}

# Portable tools and caches stay together on the drive with ample free space.
$env:PUB_CACHE = Join-Path $taskRoot 'pub-cache'
$env:GRADLE_USER_HOME = Join-Path $taskRoot 'gradle-cache'
$env:ANDROID_HOME = Join-Path $taskRoot 'android-sdk'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$taskJdkRoot = Join-Path $taskRoot 'jdk'
if (!(Test-Path -LiteralPath $taskJdkRoot)) {
    $taskJdkAsset = @(Invoke-RestMethod 'https://api.adoptium.net/v3/assets/latest/17/hotspot?architecture=x64&image_type=jdk&os=windows')[0]
    $taskJdkZip = Join-Path $taskDownloads $taskJdkAsset.binary.package.name
    Get-TaskDownload $taskJdkAsset.binary.package.link $taskJdkZip $taskJdkAsset.binary.package.checksum
    New-Item -ItemType Directory -Path $taskJdkRoot | Out-Null
    Expand-Archive -LiteralPath $taskJdkZip -DestinationPath $taskJdkRoot
}
$taskJava = @(Get-ChildItem -LiteralPath $taskJdkRoot -Directory | Where-Object {
    Test-Path -LiteralPath (Join-Path $_.FullName 'bin/java.exe')
})
if ($taskJava.Count -ne 1) { throw 'Expected one portable JDK installation.' }
$env:JAVA_HOME = $taskJava[0].FullName
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
& "$env:JAVA_HOME\bin\java.exe" -version
if ($LASTEXITCODE -ne 0) { throw 'Java verification failed.' }

$taskFlutter = Join-Path $taskRoot 'flutter'
if (!(Test-Path -LiteralPath $taskFlutter)) {
    git clone --depth 1 --branch 3.47.6 https://github.com/flutter/flutter.git $taskFlutter
    if ($LASTEXITCODE -ne 0) { throw 'Flutter checkout failed.' }
}
$taskFlutterRevision = git -C $taskFlutter rev-parse HEAD
if ($taskFlutterRevision -ne '5fc346839b5d0eef006ed8404392afb4dfae428d') {
    throw 'Flutter checkout does not match verified 3.47.6 tag.'
}
& "$taskFlutter\bin\flutter.bat" --version
if ($LASTEXITCODE -ne 0) { throw 'Flutter initialization failed.' }

$taskSdkManager = Join-Path $env:ANDROID_HOME 'cmdline-tools/latest/bin/sdkmanager.bat'
if (!(Test-Path -LiteralPath $taskSdkManager)) {
    $taskSdkZip = Join-Path $taskDownloads 'commandlinetools-win-15859902_latest.zip'
    Get-TaskDownload 'https://dl.google.com/android/repository/commandlinetools-win-15859902_latest.zip' $taskSdkZip '90ae805d20434428bffcb699c290860f19bb5f66a67e6b330067e3de801fb04a'
    $taskSdkStage = Join-Path $taskRoot 'android-tools-staging'
    New-Item -ItemType Directory -Force -Path $taskSdkStage | Out-Null
    Expand-Archive -LiteralPath $taskSdkZip -DestinationPath $taskSdkStage -Force
    $taskCommandLineRoot = Join-Path $env:ANDROID_HOME 'cmdline-tools'
    New-Item -ItemType Directory -Force -Path $taskCommandLineRoot | Out-Null
    # Both paths are explicit children of the installation root; no deletion.
    Move-Item -LiteralPath (Join-Path $taskSdkStage 'cmdline-tools') -Destination (Join-Path $taskCommandLineRoot 'latest')
}

$taskFlutterExtension = Get-Content "$taskFlutter/packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt" -Raw
$taskSdkMatch = [regex]::Match($taskFlutterExtension, 'compileSdkVersion\s*(?::\s*Int)?\s*=\s*(\d+)')
if (!$taskSdkMatch.Success) { throw 'Cannot determine Flutter compile SDK version.' }
$taskCompileSdk = $taskSdkMatch.Groups[1].Value
Write-Output "Installing Android platform $taskCompileSdk and native build tools"
1..100 | ForEach-Object { 'y' } | & $taskSdkManager "--sdk_root=$env:ANDROID_HOME" --licenses > (Join-Path $taskRoot 'sdk-licenses.log')
if ($LASTEXITCODE -ne 0) { throw 'Android SDK license step failed.' }
& $taskSdkManager "--sdk_root=$env:ANDROID_HOME" 'platform-tools' "platforms;android-$taskCompileSdk" 'platforms;android-35' 'build-tools;35.0.0' 'build-tools;36.0.0' 'ndk;28.2.13676358' 'cmake;3.22.1'
if ($LASTEXITCODE -ne 0) { throw 'Android SDK package installation failed.' }
& "$taskFlutter\bin\flutter.bat" doctor -v
Write-Output "Toolchain installed in $taskRoot"
