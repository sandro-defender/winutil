param (
    [switch]$Run,
    [switch]$Sign,
    [string]$CertificatePath,
    [securestring]$CertificatePassword
)

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$outputRoot = Join-Path $repoRoot "compiled"
New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null

$OFS = "`r`n"
$sync = [Hashtable]::Synchronized(@{})
$sync.configs = @{}

$script = (Get-Content -Path (Join-Path $repoRoot "scripts\start.ps1")) -replace '#{replaceme}', (Get-Date -Format 'yy.MM.dd')
$isLocalCompile = -not [string]::Equals($env:GITHUB_ACTIONS, "true", [StringComparison]::OrdinalIgnoreCase)
$script = $script -replace '#{islocalcompile}', $isLocalCompile.ToString().ToLowerInvariant()

$script += Get-ChildItem -Path (Join-Path $repoRoot "functions") -Recurse -File | ForEach-Object {
    Get-Content -Path $_.FullName -Raw
}

Get-ChildItem (Join-Path $repoRoot "config") | ForEach-Object {
    $obj = Get-Content -Path $_.FullName -Raw | ConvertFrom-Json
    if ($_.Name -eq "applications.json") {
        $fixed = [ordered]@{}
        foreach ($p in $obj.PSObject.Properties) { $fixed["WPFInstall$($p.Name)"] = $p.Value }
        $obj = [pscustomobject]$fixed
    }

    $json = $obj | ConvertTo-Json -Depth 10
    $sync.configs[$_.BaseName] = $obj
    $script += "`$sync.configs.$($_.BaseName) = @'`r`n$json`r`n'@ | ConvertFrom-Json"
}

$xaml = Get-Content -Path (Join-Path $repoRoot "xaml\inputXML.xaml") -Raw
$script += "`$inputXML = @'`r`n$xaml`r`n'@"
$autounattendXml = Get-Content -Path (Join-Path $repoRoot "tools\autounattend.xml") -Raw
$script += "`$WinUtilAutounattendXml = @'`r`n$autounattendXml`r`n'@"
$script += Get-Content -Path (Join-Path $repoRoot "scripts\main.ps1") -Raw

$compiledScriptPath = Join-Path $outputRoot "winutil.ps1"
Set-Content -Path $compiledScriptPath -Value $script

$launcherParameters = @{ OutputPath = (Join-Path $outputRoot "WinUtilLauncher.exe"); Sign = $Sign }
if ($CertificatePath) { $launcherParameters.CertificatePath = $CertificatePath }
if ($CertificatePassword) { $launcherParameters.CertificatePassword = $CertificatePassword }
& (Join-Path $PSScriptRoot "Build-Launcher.ps1") @launcherParameters

if ($Run) { & $compiledScriptPath }
