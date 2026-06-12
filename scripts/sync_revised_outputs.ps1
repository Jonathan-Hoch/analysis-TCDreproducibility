param(
    [Parameter(Mandatory = $true)]
    [string]$Source
)

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
$dest = Join-Path $repo "B_Revised_Figures"

if (-not (Test-Path $Source)) {
    throw "Source folder not found: $Source"
}

New-Item -ItemType Directory -Force -Path $dest | Out-Null
Get-ChildItem -Path $Source -File | Where-Object { $_.Name -notlike "Table4*" } | Copy-Item -Destination $dest -Force
Get-ChildItem -Path $Source -Directory | Copy-Item -Destination $dest -Recurse -Force
Write-Host "Synced revised outputs from $Source to $dest (excluding Table4*)"
