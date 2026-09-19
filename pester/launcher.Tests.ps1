BeforeAll {
    $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

Describe "WinUtil executable launcher" {
    It "builds from the compiler directory into compiled output" {
        $compileScript = Get-Content -Path (Join-Path $script:repoRoot "compiler\Compile.ps1") -Raw
        $buildScript = Get-Content -Path (Join-Path $script:repoRoot "compiler\Build-Launcher.ps1") -Raw

        $compileScript | Should -Match 'Build-Launcher\.ps1'
        $buildScript | Should -Match 'compiled'
    }

    It "uses a Git tag for version metadata and supports signing" {
        $buildScript = Get-Content -Path (Join-Path $script:repoRoot "compiler\Build-Launcher.ps1") -Raw

        $buildScript | Should -Match 'git -C \$repoRoot describe --tags'
        $buildScript | Should -Match 'AssemblyVersion'
        $buildScript | Should -Match 'win32icon'
        $buildScript | Should -Match 'Set-AuthenticodeSignature'
    }
}
