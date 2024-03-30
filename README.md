# PsIcuAndroid
This script allows to build ICU library for Android.

Supported ABIs: armeabi-v7a, arm64-v8a, x86, x86-64.  

Windows(WSL), Linux, MacOS are compatible.

## How to use - Examples
`./X-BuildIcuAndroid.ps1`

`./X-BuildIcuAndroid.ps1 -AndroidAPI 34`

`./X-BuildIcuAndroid.ps1 -AndroidAPI 34 -ForceDownloadNDK -ForceDownloadICU`

`./X-BuildIcuAndroid.ps1 -DestinationDir "/home/myuser/icu_dist"`

On PowerShell get cmdlet help  
`Get-Help ./X-BuildIcuAndroid.ps1`

## Attribution

• Thanks to this repo, it helped me write this script.

[Cross build icu4c for Android - https://github.com/NanoMichael/cross_compile_icu4c_for_android](https://github.com/NanoMichael/cross_compile_icu4c_for_android)
