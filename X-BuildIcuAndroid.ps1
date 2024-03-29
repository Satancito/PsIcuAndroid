<#
.SYNOPSIS
This script allows you to build ICU library for Android.

.DESCRIPTION
This script allows to build ICU library for Android.
Supported ABIs: armeabi-v7a, arm64-v8a, x86, x86-64.

.PARAMETER AndroidAPI
Set the Android API in NDK toolchain.

.PARAMETER DestinationDir
Directory where the compiled library will be copied. If this parameter is empty string, the default directory is $HOME/.CppLibs/ICU-$ICUVERSION-Android-$ABI-$CONFIGURATION/

$CONFIGURATION: Debug, Release.
$ABI: armeabi-v7a, arm64-v8a, x86, x86-64.
$HOME: The current user directory.


.PARAMETER ForceDownloadNDK
NDK installation dir is removed. NDK package is downloaded and unzipped on NDK installation dir.

.PARAMETER ForceDownloadICU
ICU installation dir is removed. ICU package is downloaded and unzipped on ICU installation dir.

.EXAMPLE
./X-BuildIcuAndroid.ps1

.EXAMPLE
./X-BuildIcuAndroid.ps1 -AndroidAPI 34

.EXAMPLE
./X-BuildIcuAndroid.ps1 -AndroidAPI 34 -ForceDownloadNDK -ForceDownloadICU

.INPUTS
None. You can't pipe objects to X-BuildIcuAndroid.ps1.

.OUTPUTS
None. X-BuildIcuAndroid.ps1 doesn't generate any output.
  
.NOTES
At this moment only Linux is compatible.

.LINK
How To Cross Compile ICU: https://unicode-org.github.io/icu/userguide/icu4c/build.html#how-to-cross-compile-icu

.LINK
Use the NDK with other build systems: https://developer.android.com/ndk/guides/other_build_systems

.LINK
Based on: https://github.com/NanoMichael/cross_compile_icu4c_for_android

.LINK
Reference, Build ICU for Android: https://gist.github.com/DanielSerdyukov/188d47e29150622352f1

#>

[CmdletBinding()]
param (
    [Parameter()]
    [ValidateSet(21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34)]
    [string]
    $AndroidAPI = 34,

    [string]
    $DestinationDir = [string]::Empty,

    [switch]
    $ForceDownloadNDK,

    [switch]
    $ForceDownloadICU
)

Import-Module -Name "$PSScriptRoot/submodules/PsCoreFxs/Z-PsCoreFxs.ps1" -Force -NoClobber
Update-GitSubmodules -Path "$PSScriptRoot" -Force

function Clear-BuildVariables {
    $env:TARGET = ""
    $env:API = ""
    $env:AR = "" 
    $env:CC = "" 
    $env:AS = "" 
    $env:CXX = ""
    $env:LD = "" 
    $env:RANLIB = ""
    $env:STRIP = ""
    $env:CPPFLAGS = ""
    $env:LDFLAGS = "" 
    $env:CXXFLAGS = ""
    $env:CFLAGS = "" 
}

function Test-RequiredTools {
    Write-Host
    Write-InfoBlue "Test - Dependency tools"
    Write-Host

    Write-InfoMagenta "== Sh"
    $command = Get-Command "sh"
    Write-Host "$($command.Source)"
    & "$($command.Source)" --version
    Write-Host

    Write-InfoMagenta "== Git"
    $command = Get-Command "git"
    Write-Host "$($command.Source)"
    & "$($command.Source)" --version
    Write-Host

    Write-InfoMagenta "== Make"
    $command = Get-Command "make"
    Write-Host "$($command.Source)"
    & "$($command.Source)" --version
    Write-Host

    Write-InfoMagenta "== Unzip"
    $command = Get-Command "unzip"
    Write-Host "$($command.Source)"
    & "$($command.Source)" -v
    Write-Host
}

if ($IsWindows -or $IsMacOS) {
    throw "Not compatible OS: $OS"
}

Test-RequiredTools

# ███ Set values.
$NDK_OS_VARIANTS = @{
    Windows = @{ 
        Uri             = "https://dl.google.com/android/repository/android-ndk-r26c-windows.zip"
        Sha1            = "f8c8aa6135241954461b2e3629cada4722e13ee7".ToUpper()
        HostTag         = "windows-x86_64"
        IcuHostPlatform = "Linux"
        Toolchain       = "toolchains/llvm/prebuilt/windows-x86_64"
    }
    Linux   = @{ 
        Uri             = "https://dl.google.com/android/repository/android-ndk-r26c-linux.zip"
        Sha1            = "7faebe2ebd3590518f326c82992603170f07c96e".ToUpper()
        HostTag         = "linux-x86_64"
        IcuHostPlatform = "Linux"
        Toolchain       = "toolchains/llvm/prebuilt/linux-x86_64"
    }
    MacOS   = @{ 
        Uri             = "https://dl.google.com/android/repository/android-ndk-r26c-darwin.dmg"
        Sha1            = "9d86710c309c500aa0a918fa9902d9d72cca0889".ToUpper()
        HostTag         = "darwin-x86_64"
        IcuHostPlatform = "MacOSX/GCC"
        Toolchain       = "toolchains/llvm/prebuilt/darwin-x86_64"
    }
    Version = "r26c"
}

$ICU4C_RELEASE = @{
    Uri         = "https://github.com/unicode-org/icu/archive/refs/tags/release-74-2.zip"
    Sha1        = "3CF19E99B3BD21520E0E09430689DA548DDCCBB8"
    UnzippedDir = "icu-release-74-2"
    Version     = "74.2"
} 

$TEMP_DIR = "$(Get-UserHome)/.PsIcuAndroid"
$NDK_BASE_DIR = "$(Get-UserHome)/.android-ndk"
$OS = "$(Get-VariableName $IsLinux)".TrimStart("Is")
$NDK_PROPS = $NDK_OS_VARIANTS[$OS]
$NDK_DOWNLOAD_FILENAME = "$TEMP_DIR/$([System.IO.Path]::GetFileName($NDK_PROPS.Uri))"
$NDK_DIR = "$NDK_BASE_DIR/android-ndk-$($NDK_OS_VARIANTS.Version)"

$ICU_DOWNLOAD_FILENAME = "$TEMP_DIR/$([System.IO.Path]::GetFileName($ICU4C_RELEASE.Uri))"

$ICU_DIR = "$TEMP_DIR/$($ICU4C_RELEASE.UnzippedDir)"
$ICU_SOURCE = "$ICU_DIR/icu4c/source"

$BUILD_DIR = "$PSScriptRoot/Build"
$HOST_BUILD_DIR = "$BUILD_DIR/$OS"
$HOST_BUILD_CONFIGS = @{
    Debug   = @{
        BuildDir               = "$HOST_BUILD_DIR/Debug/$(sh -c 'uname -m')"
        IcuConfigureParameters = @("--enable-debug", "--disable-release")
    }
    Release = @{
        BuildDir               = "$HOST_BUILD_DIR/Release/$(sh -c 'uname -m')"
        IcuConfigureParameters = @("--enable-release", "--disable-debug")
    }
} 

$ABIs = @{
    "armeabi-v7a"         = @{ 
        Triple                 = "armv7a-linux-androideabi" 
        Name                   = "armeabi-v7a"
        Mode                   = "Debug"
        IcuConfigureParameters = @("--enable-debug", "--disable-release")
    }
    "arm64-v8a"           = @{ 
        Triple                 = "aarch64-linux-android" 
        Name                   = "arm64-v8a"
        Mode                   = "Debug"
        IcuConfigureParameters = @("--enable-debug", "--disable-release")
    }
    "x86"                 = @{ 
        Triple                 = "i686-linux-android" 
        Name                   = "x86"
        Mode                   = "Debug"
        IcuConfigureParameters = @("--enable-debug", "--disable-release")
    }
    "x86-64"              = @{ 
        Triple                 = "x86_64-linux-android" 
        Name                   = "x86-64"
        Mode                   = "Debug"
        IcuConfigureParameters = @("--enable-debug", "--disable-release")
    }

    "armeabi-v7a-release" = @{ 
        Triple                 = "armv7a-linux-androideabi" 
        Name                   = "armeabi-v7a"
        Mode                   = "Release"
        IcuConfigureParameters = @("--enable-release", "--disable-debug")
    }
    "arm64-v8a-release"   = @{ 
        Triple                 = "aarch64-linux-android" 
        Name                   = "arm64-v8a"
        Mode                   = "Release"
        IcuConfigureParameters = @("--enable-release", "--disable-debug")
    }
    "x86-release"         = @{ 
        Triple                 = "i686-linux-android" 
        Name                   = "x86"
        Mode                   = "Release"
        IcuConfigureParameters = @("--enable-release", "--disable-debug")
    }
    "x86-64-release"      = @{ 
        Triple                 = "x86_64-linux-android" 
        Name                   = "x86-64"
        Mode                   = "Release"
        IcuConfigureParameters = @("--enable-release", "--disable-debug")
    }
}

New-Item -Path "$TEMP_DIR" -ItemType Directory -Force | Out-Null 

# ███ Download NDK.
$downloaded = $false
if (!(Test-Path -Path $NDK_DOWNLOAD_FILENAME -PathType Leaf) -or $ForceDownloadNDK.IsPresent) {
    Write-PrettyKeyValue "Downloading" "Android NDK"
    Invoke-WebRequest -Uri "$($NDK_PROPS.Uri)" -OutFile "$NDK_DOWNLOAD_FILENAME"
    $downloaded = $true
}
$Sha1 = Get-FileHash -Path $NDK_DOWNLOAD_FILENAME -Algorithm SHA1
if (!$Sha1.Hash.Equals($NDK_PROPS.Sha1)) {
    throw "Error downloading Android NDK. The file hash doesn't match."
}
if ($downloaded -or !(Test-Path -Path "$NDK_DIR" -PathType Container)) {
    Remove-Item -Path "$NDK_DIR" -Force -Recurse -ErrorAction Ignore
    Write-PrettyKeyValue "Unzipping" "$NDK_DOWNLOAD_FILENAME"
    & unzip "$NDK_DOWNLOAD_FILENAME" -d "$NDK_BASE_DIR"  
}

# ███ Download ICU.
$downloaded = $false
if (!(Test-Path -Path $ICU_DOWNLOAD_FILENAME -PathType Leaf) -or $ForceDownloadICU.IsPresent) {
    Write-PrettyKeyValue "Downloading" "ICU"
    Invoke-WebRequest -Uri "$($ICU4C_RELEASE.Uri)" -OutFile "$ICU_DOWNLOAD_FILENAME"
    $downloaded = $true
}
$Sha1 = Get-FileHash -Path $ICU_DOWNLOAD_FILENAME -Algorithm SHA1
if (!$Sha1.Hash.Equals($ICU4C_RELEASE.Sha1)) {
    throw "Error downloading ICU. The file hash doesn't match."
}
if ($downloaded -or !(Test-Path -Path "$ICU_DIR" -PathType Container)) {
    Remove-Item -Path "$ICU_DIR" -Force -Recurse -ErrorAction Ignore
    Write-PrettyKeyValue "Unzipping" "$ICU_DOWNLOAD_FILENAME"
    & unzip "$ICU_DOWNLOAD_FILENAME" -d "$TEMP_DIR"
}

Remove-Item -Path "$BUILD_DIR" -Force -Recurse -ErrorAction Ignore
New-Item -Path $BUILD_DIR -ItemType Directory -Force | Out-Null

# ███ Build Host library.
Clear-BuildVariables
$CPPFLAGS = "-ffunction-sections -fdata-sections -fvisibility=hidden -fno-short-wchar -fno-short-enums -DU_USING_ICU_NAMESPACE=1 -DU_HAVE_NL_LANGINFO_CODESET=0 -D__STDC_INT64__ -DU_TIMEZONE=0 -DUCONFIG_NO_LEGACY_CONVERSION=1"
$LDFLAGS = "-Wl,--gc-sections"
$CXXFLAGS = ""
$CFLAGS = ""
$env:CXXFLAGS = $CXXFLAGS
$env:CFLAGS = $CFLAGS
$env:CPPFLAGS = $CPPFLAGS
$env:LDFLAGS = $LDFLAGS

$HOST_BUILD_CONFIGS.Keys | ForEach-Object {
    try {
        New-Item -Path "$($HOST_BUILD_CONFIGS[$_].BuildDir)" -ItemType Directory -Force | Out-Null
        Push-Location "$($HOST_BUILD_CONFIGS[$_].BuildDir)"
        Write-PrettyKeyValue "Configuring" "ICU - $_ - Host Platform: $($NDK_PROPS.IcuHostPlatform)"
        $LIB_DIST_DIR = "$HOST_BUILD_DIR/dist/ICU-$($ICU4C_RELEASE.Version)-Linux-$(sh -c 'uname -m')-$_"
        if ($_.Equals("Debug")) {
            & sh "$ICU_SOURCE/runConfigureICU" "$($NDK_PROPS.IcuHostPlatform)" --prefix="$LIB_DIST_DIR" $($HOST_BUILD_CONFIGS[$_].IcuConfigureParameters) --enable-static --disable-shared --disable-tools --disable-strict --disable-tests --disable-samples --disable-fuzzer --disable-dyload
        }
        else {
            & sh "$ICU_SOURCE/runConfigureICU" "$($NDK_PROPS.IcuHostPlatform)" --prefix="$LIB_DIST_DIR" --disable-debug --enable-release --enable-static --disable-shared --disable-tools --disable-strict --disable-tests --disable-samples --disable-fuzzer --disable-dyload
        }
        Write-PrettyKeyValue "Building" "ICU - $_ - Host Platform: $($NDK_PROPS.IcuHostPlatform)"
        make -j16 
        make install 
    }
    finally {
        Pop-Location
    }
}


# ███ Build ICU Android libraries for all ABI.

$ABIs.Keys | ForEach-Object {
    $ABI = $ABIs[$_]
    Clear-BuildVariables
    $LIB_BUILD_DIR = "$BUILD_DIR/Android/$($ABI.Mode)/$($ABI.Name)"
    $LIB_DIST_DIR = ([string]::IsNullOrWhiteSpace($DestinationDir)) ? "$(Get-UserHome)/.CppLibs/ICU-$($ICU4C_RELEASE.Version)-Android-$($ABI.Name)-$($ABI.Mode)" : $DestinationDir
    New-Item -Path "$LIB_BUILD_DIR" -ItemType Directory -Force | Out-Null

    $TOOLCHAIN = "$NDK_DIR/$($NDK_PROPS.Toolchain)"
    $TARGET = $ABI.Triple

    $env:TARGET = $TARGET
    $env:API = $AndroidAPI
    $env:AR = "$TOOLCHAIN/bin/llvm-ar"
    $env:CC = "$TOOLCHAIN/bin/$TARGET$AndroidAPI-clang"
    $env:AS = $CC 
    $env:CXX = "$TOOLCHAIN/bin/$TARGET$AndroidAPI-clang++"
    $env:LD = "$TOOLCHAIN/bin/ld"
    $env:RANLIB = "$TOOLCHAIN/bin/llvm-ranlib"
    $env:STRIP = "$TOOLCHAIN/bin/llvm-strip"
    $env:CPPFLAGS = "-ffunction-sections -fdata-sections -fvisibility=hidden -fno-short-wchar -fno-short-enums -DU_USING_ICU_NAMESPACE=1 -DU_HAVE_NL_LANGINFO_CODESET=0 -D__STDC_INT64__ -DU_TIMEZONE=0 -DUCONFIG_NO_LEGACY_CONVERSION=1"
    $env:LDFLAGS = "-lc -lstdc++ -Wl,--gc-sections"
    $env:CXXFLAGS = ""
    $env:CFLAGS = ""

    try {
        Push-Location "$LIB_BUILD_DIR"
        Write-PrettyKeyValue "Configuring" "ICU - Host Platform: $TARGET"
        $CROSS_BUILD_DIR = "$($HOST_BUILD_CONFIGS[$ABI.Mode].BuildDir)"
        & sh "$ICU_SOURCE/configure" --host="$TARGET" --with-cross-build="$CROSS_BUILD_DIR" --prefix="$LIB_DIST_DIR" --enable-static --disable-shared $ABI.IcuConfigureParameters --disable-tools --disable-strict --disable-tests --disable-samples --disable-fuzzer --disable-dyload
        Remove-Item -Path "$LIB_DIST_DIR" -Force -Recurse -ErrorAction Ignore
        Write-PrettyKeyValue "Building" "ICU - $($ABI.Mode) - Host Platform: $TARGET"
        make -j16 
        make install 
    }
    finally {
        Pop-Location
    } 
}