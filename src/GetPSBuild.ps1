﻿[cmdletbinding()]
param(
    $toolsDir = ("$env:LOCALAPPDATA\LigerShark\tools\"),

    $nugetDownloadUrl = 'http://nuget.org/nuget.exe'
)

# based off of the scrit at http://psget.net/GetPsGet.ps1
function Install-PSBuild {
    $ModulePaths = @($Env:PSModulePath -split ';')
    
    $ExpectedUserModulePath = Join-Path -Path ([Environment]::GetFolderPath('MyDocuments')) -ChildPath WindowsPowerShell\Modules
    $Destination = $ModulePaths | Where-Object { $_ -eq $ExpectedUserModulePath}
    if (-not $Destination) {
        $Destination = $ModulePaths | Select-Object -Index 0
    }

    $destFile = (join-path $Destination "\psbuild\psbuild.psm1")
    $destFolder = ([System.IO.Path]::GetDirectoryName($destFile))
    if(!(test-path $destFolder)){
        new-item -path $destFolder -ItemType Directory | out-null
    }

    $downloadUrl = 'https://raw.github.com/ligershark/psbuild/master/src/psbuild.psm1'
    New-Item ($Destination + "\psbuild\") -ItemType Directory -Force | out-null
    'Downloading psbuild from {0}' -f $downloadUrl | Write-Host
    $client = (New-Object Net.WebClient)
    $client.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
    $client.DownloadFile($downloadUrl, $destFile)

    $executionPolicy  = (Get-ExecutionPolicy)
    $executionRestricted = ($executionPolicy -eq "Restricted")
    if ($executionRestricted){
        Write-Warning @"
Your execution policy is $executionPolicy, this means you will not be able import or use any scripts including modules.
To fix this change your execution policy to something like RemoteSigned.

        PS> Set-ExecutionPolicy RemoteSigned

For more information execute:
        
        PS> Get-Help about_execution_policies

"@
    }

    if (!$executionRestricted){
        # ensure psbuild is imported from the location it was just installed to
        Import-Module -Name $Destination\psbuild
    }    
    Write-Host "psbuild is installed and ready to use" -Foreground Green
    Write-Host @"
USAGE:
    PS> Invoke-MSBuild 'C:\temp\msbuild\msbuild.proj'
    PS> Invoke-MSBuild C:\temp\msbuild\path.proj -properties (@{'foo'='bar';'visualstudioversion'='12.0'}) -extraArgs '/nologo'

For more details:
    get-help Invoke-MSBuild
Or visit http://msbuildbook.com/psbuild
"@
}

<#
.SYNOPSIS
    If nuget is in the tools
    folder then it will be downloaded there.
#>
function Get-Nuget(){
    [cmdletbinding()]
    param(
        $toolsDir = ("$env:LOCALAPPDATA\LigerShark\tools\"),
        $nugetDownloadUrl = 'http://nuget.org/nuget.exe'
    )
    process{
        $nugetDestPath = Join-Path -Path $toolsDir -ChildPath nuget.exe
        
        if(!(Test-Path $nugetDestPath)){
            $nugetDir = ([System.IO.Path]::GetDirectoryName($nugetDestPath))
            if(!(Test-Path $nugetDir)){
                New-Item -Path $nugetDir -ItemType Directory | Out-Null
            }

            'Downloading nuget.exe' | Write-Verbose
            (New-Object System.Net.WebClient).DownloadFile($nugetDownloadUrl, $nugetDestPath)

            # double check that is was written to disk
            if(!(Test-Path $nugetDestPath)){
                throw 'unable to download nuget'
            }
        }

        # return the path of the file
        $nugetDestPath
    }
}

$nugetExe = (Get-Nuget -toolsDir $toolsDir -nugetDownloadUrl $nugetDownloadUrl)

# see if there is a package installed into %localappdata%
function GetPsBuildPsm1{
    [cmdletbinding()]
    param(
        $toolsDir = ("$env:LOCALAPPDATA\LigerShark\tools\"),
        $nugetDownloadUrl = 'http://nuget.org/nuget.exe'
    )
    process{
        if(!(Test-Path $toolsDir)){
            New-Item -Path $toolsDir -ItemType Directory | out-null
        }

        $psbuildPsm1 = (Get-ChildItem -Path $toolsDir -Include 'psbuild.psm1' -Recurse | select -first 1)

        if(!$psbuildPsm1){
            'Downloading psbuild to the toolsDir' | Write-Verbose
            # nuget install psbuild -Prerelease -OutputDirectory C:\temp\nuget\out\
            $cmdArgs = @('install','psbuild','-Prerelease','-OutputDirectory',(Resolve-Path $toolsDir).ToString())

            $nugetPath = (Get-Nuget -toolsDir $toolsDir -nugetDownloadUrl $nugetDownloadUrl)
            'Calling nuget to install psbuild with the following args. [{0}{1}]' -f $nugetPath, ($cmdArgs -join ' ') | Write-Verbose
            &$nugetPath $cmdArgs | Out-Null

            $psbuildPsm1 = (Get-ChildItem -Path $toolsDir -Include 'psbuild.psm1' -Recurse | select -first 1)
        }

        if(!$psbuildPsm1){ 
            throw 'psbuild not found, and was not downloaded successfully. sorry.' 
        }

        $psbuildPsm1
    }
}

<#
$path = GetPsBuildPsm1 -toolsDir $toolsDir -nugetDownloadUrl $nugetDownloadUrl
#>

Install-PSBuild
