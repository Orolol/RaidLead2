# Lance la suite de tests automatisés de RaidLead en headless (Milestone 6, US 6.5).
# Usage : powershell -ExecutionPolicy Bypass -File tests\run_tests.ps1
# Code de sortie : 0 si tous les tests passent, 1 sinon, 2 si Godot est introuvable.

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot

# Cherche un exécutable Godot 4.x "console" (capture stdout) dans les emplacements usuels.
$candidates = @()
foreach ($dir in @("$env:USERPROFILE\Downloads", "$env:LOCALAPPDATA", "$env:USERPROFILE\Desktop")) {
	if (Test-Path $dir) {
		$candidates += Get-ChildItem -Path $dir -Recurse -Filter "Godot_v*_console.exe" -ErrorAction SilentlyContinue -Depth 3
	}
}
$godot = $candidates | Sort-Object Name -Descending | Select-Object -First 1
if (-not $godot) {
	Write-Error "Exécutable Godot console (Godot_v*_console.exe) introuvable."
	exit 2
}

Write-Host "Godot : $($godot.FullName)"
Write-Host "Projet : $projectRoot"
& $godot.FullName --headless --path $projectRoot "res://tests/TestRunner.tscn"
exit $LASTEXITCODE
