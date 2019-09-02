# Original file from https://github.com/psget/psget/
#
# Adjusted to import the SQLDoc module

param (
  [string[]]$url = ("https://raw.githubusercontent.com/brianbonk/SQLDoc/master/SQLDoc.psm1", "https://raw.githubusercontent.com/brianbonk/SQLDoc/master/SQLDoc.psd1")
)

function Find-Proxy() {
    if ((Test-Path Env:HTTP_PROXY) -Or (Test-Path Env:HTTPS_PROXY)) {
        return $true
    }
    Else {
        return $false
    }
}

function Get-Proxy() {
    if (Test-Path Env:HTTP_PROXY) {
        return $Env:HTTP_PROXY
    }
    ElseIf (Test-Path Env:HTTPS_PROXY) {
        return $Env:HTTPS_PROXY
    }
}

function Get-File {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [String] $Url,

        [Parameter(Mandatory=$true)]
        [String] $SaveToLocation
    )
    $command = (Get-Command Invoke-WebRequest -ErrorAction SilentlyContinue)
    if($command -ne $null) {
        if (Find-Proxy) {
            $proxy = Get-Proxy
            Write-Host "Proxy detected"
            Write-Host "Using proxy address $proxy"
            Invoke-WebRequest -Uri $Url -OutFile $SaveToLocation -Proxy $proxy
        }
        else {
            Invoke-WebRequest -Uri $Url -OutFile $SaveToLocation
        }
    }
    else {
        $client = (New-Object Net.WebClient)
        $client.UseDefaultCredentials = $true
        if (Find-Proxy) {
            $proxy = Get-Proxy
            Write-Host "Proxy detected"
            Write-Host "Using proxy address $proxy"
            $webproxy = new-object System.Net.WebProxy
            $webproxy.Address = $proxy
            $client.proxy = $webproxy
        }
        $client.DownloadFile($Url, $SaveToLocation)
    }
}

function Install-SQLDoc {
  
    param (
      [string[]]
      # URL to the respository to download SQLDoc from
      $url
    )
  
    $ModulePaths = @($env:PSModulePath -split ';')
    # $PSSQLLibDestinationModulePath is mostly needed for testing purposes,
    if ((Test-Path -Path Variable:PSSQLLibDestinationModulePath) -and $PSSQLLibDestinationModulePath) {
        $Destination = $PSSQLLibDestinationModulePath
        if ($ModulePaths -notcontains $Destination) {
            Write-Warning 'SQLDoc install destination is not included in the PSModulePath environment variable'
        }
    }
    else {
        $ExpectedUserModulePath = Join-Path -Path ([Environment]::GetFolderPath('MyDocuments')) -ChildPath WindowsPowerShell\Modules
        $Destination = $ModulePaths | Where-Object { $_ -eq $ExpectedUserModulePath }
        if (-not $Destination) {
            $Destination = $ModulePaths | Select-Object -Index 0
        }
    }
    New-Item -Path ($Destination + "\SQLDoc\") -ItemType Directory -Force | Out-Null

    Write-Host ('Downloading SQLDoc from {0}' -f $url[0])
    Get-File -Url $url[0] -SaveToLocation "$Destination\SQLDoc\SQLDoc.psm1"

    Write-Host ('Downloading SQLDoc from {0}' -f $url[1])
    Get-File -Url $url[1] -SaveToLocation "$Destination\SQLDoc\SQLDoc.psd1"

    $executionPolicy = (Get-ExecutionPolicy)
    $executionRestricted = ($executionPolicy -eq "Restricted")
    if ($executionRestricted) {
        Write-Warning @"
Your execution policy is $executionPolicy, this means you will not be able import or use any scripts including modules.
To fix this change your execution policy to something like RemoteSigned.
        PS> Set-ExecutionPolicy RemoteSigned
For more information execute:
        PS> Get-Help about_execution_policies
"@
    }

    if (!$executionRestricted) {
        # ensure PSSQLLib is imported from the location it was just installed to
        Import-Module -Name $Destination\SQLDoc
    }
    Write-Host "SQLDoc is installed and ready to use" -Foreground Green

}

Install-SQLDoc -Url $url