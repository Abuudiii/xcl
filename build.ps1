# Builds xcl.exe and, with Inno Setup installed, the XCL-Setup.exe installer of this
# modified build. Run from the repository root:
#
#     powershell -ExecutionPolicy Bypass -File build.ps1
#
# Needs: Rust (stable, x86_64-pc-windows-msvc), the MSVC build tools and a Windows 10/11 SDK
# (for dxcompiler.dll / dxil.dll). The installer step also needs Inno Setup 6.
# See BUILDING.md.
param(
    [switch]$NoInstaller  # build xcl.exe only
)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
    $env:PATH = "$env:USERPROFILE\.cargo\bin;$env:PATH"
}
if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
    throw 'cargo was not found. Install Rust from https://rustup.rs first.'
}

Write-Host '== cargo build --release --locked -p xcl'
cargo build --release --locked -p xcl
if ($LASTEXITCODE -ne 0) { throw 'cargo build failed' }
$exe = Join-Path $PSScriptRoot 'target\release\xcl.exe'
Write-Host "xcl.exe      $((Get-FileHash $exe -Algorithm SHA256).Hash.ToLower())"

if ($NoInstaller) { return }

# dxcompiler.dll and dxil.dll come from the newest installed Windows SDK that has them
$kits = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\bin'
$dxc = Get-ChildItem $kits -Directory -ErrorAction SilentlyContinue |
    Where-Object { (Test-Path (Join-Path $_.FullName 'x64\dxcompiler.dll')) -and (Test-Path (Join-Path $_.FullName 'x64\dxil.dll')) } |
    Sort-Object { [version]$_.Name } | Select-Object -Last 1
if (-not $dxc) { throw "No Windows SDK with x64\dxcompiler.dll and dxil.dll under $kits" }
$dxcDir = Join-Path $dxc.FullName 'x64'
Write-Host "DXC from     $dxcDir"

$iscc = @(
    (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'),
    (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe')
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) { throw 'Inno Setup 6 (ISCC.exe) was not found. Install it from https://jrsoftware.org/isdl.php or pass -NoInstaller.' }

Write-Host '== Inno Setup'
& $iscc /Q "/DDxcDir=$dxcDir" installer\xcl.iss
if ($LASTEXITCODE -ne 0) { throw 'ISCC failed' }
$setup = Join-Path $PSScriptRoot 'dist\XCL-Setup.exe'
Write-Host "XCL-Setup.exe $((Get-FileHash $setup -Algorithm SHA256).Hash.ToLower())"
Write-Host "Done: $setup"
