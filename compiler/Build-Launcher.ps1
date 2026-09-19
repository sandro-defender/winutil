param(
    [string]$OutputPath = (Join-Path $PSScriptRoot "..\compiled\WinUtilLauncher.exe"),
    [switch]$Sign,
    [string]$CertificatePath,
    [securestring]$CertificatePassword
)

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$sourcePath = Join-Path $PSScriptRoot "WinUtilLauncher.cs"
$manifestPath = Join-Path $PSScriptRoot "WinUtilLauncher.manifest"
$logoPath = Join-Path $repoRoot "docs\src\assets\branding\navlogo.png"
$compilerPath = Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if (-not (Test-Path $compilerPath)) { $compilerPath = Join-Path $env:WINDIR "Microsoft.NET\Framework\v4.0.30319\csc.exe" }
if (-not (Test-Path $compilerPath)) { throw "The .NET Framework C# compiler was not found." }

$gitTag = ((& git -C $repoRoot describe --tags --exact-match HEAD 2>$null) -join [Environment]::NewLine).Trim()
if ($LASTEXITCODE -ne 0) { $gitTag = ((& git -C $repoRoot describe --tags --abbrev=0 2>$null) -join [Environment]::NewLine).Trim() }
if ($LASTEXITCODE -eq 0 -and $gitTag -match '^[vV]?(\d+)\.(\d+)\.(\d+)$') {
    $assemblyVersion = "{0}.{1}.{2}.0" -f [int]$Matches[1], [int]$Matches[2], [int]$Matches[3]
} else {
    $gitTag = "untagged"
    $assemblyVersion = "0.0.0.0"
    Write-Warning "No semantic Git tag was found; the launcher version is 0.0.0.0."
}

$outputDirectory = Split-Path $OutputPath -Parent
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
$versionInfoPath = Join-Path $outputDirectory ".WinUtilLauncher.VersionInfo.cs"
$iconPath = Join-Path $outputDirectory ".WinUtilLauncher.ico"
try {
    @"
using System.Reflection;
[assembly: AssemblyTitle("WinUtil Launcher")]
[assembly: AssemblyProduct("WinUtil")]
[assembly: AssemblyCompany("CT Tech Group LLC")]
[assembly: AssemblyVersion("$assemblyVersion")]
[assembly: AssemblyFileVersion("$assemblyVersion")]
[assembly: AssemblyInformationalVersion("$gitTag")]
"@ | Set-Content -Path $versionInfoPath -Encoding utf8

    Add-Type -AssemblyName System.Drawing
    $sourceImage = [System.Drawing.Image]::FromFile($logoPath)
    $iconBitmap = [System.Drawing.Bitmap]::new(64, 64)
    $graphics = [System.Drawing.Graphics]::FromImage($iconBitmap)
    try {
        $graphics.Clear([System.Drawing.Color]::Transparent)
        $graphics.DrawImage($sourceImage, [System.Drawing.Rectangle]::new(0, 0, 64, 64), 0, 0, 59, 59, [System.Drawing.GraphicsUnit]::Pixel)
        $pngStream = [System.IO.MemoryStream]::new()
        try { $iconBitmap.Save($pngStream, [System.Drawing.Imaging.ImageFormat]::Png); $pngBytes = $pngStream.ToArray() } finally { $pngStream.Dispose() }
    } finally { $graphics.Dispose(); $iconBitmap.Dispose(); $sourceImage.Dispose() }

    $iconWriter = [System.IO.BinaryWriter]::new([System.IO.File]::Create($iconPath))
    try {
        $iconWriter.Write([UInt16]0); $iconWriter.Write([UInt16]1); $iconWriter.Write([UInt16]1)
        $iconWriter.Write([Byte]64); $iconWriter.Write([Byte]64); $iconWriter.Write([Byte]0); $iconWriter.Write([Byte]0)
        $iconWriter.Write([UInt16]1); $iconWriter.Write([UInt16]32); $iconWriter.Write([UInt32]$pngBytes.Length); $iconWriter.Write([UInt32]22); $iconWriter.Write($pngBytes)
    } finally { $iconWriter.Dispose() }

    & $compilerPath /nologo /target:winexe /platform:anycpu /out:$OutputPath /win32manifest:$manifestPath /win32icon:$iconPath /reference:System.Windows.Forms.dll $sourcePath $versionInfoPath
    if ($LASTEXITCODE -ne 0) { throw "Failed to build WinUtilLauncher.exe." }

    if ($Sign) {
        $certificateParameters = @{ FilePath = $CertificatePath }
        if ($CertificatePassword) { $certificateParameters.Password = $CertificatePassword }
        $certificate = if ($CertificatePath) { Get-PfxCertificate @certificateParameters } else { Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert | Select-Object -First 1 }
        if (-not $certificate) { throw "No code-signing certificate was available for WinUtilLauncher.exe." }
        $signature = Set-AuthenticodeSignature -FilePath $OutputPath -Certificate $certificate -TimestampServer "http://timestamp.digicert.com"
        if ($signature.Status -ne "Valid") { throw "Failed to sign WinUtilLauncher.exe: $($signature.StatusMessage)" }
    } else { Write-Warning "WinUtilLauncher.exe was built without an Authenticode signature." }
} finally { Remove-Item -Path $versionInfoPath, $iconPath -Force -ErrorAction SilentlyContinue }
