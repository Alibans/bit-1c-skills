# Собирает открывалку для скриншотов: исходники src\БИТ_Скриншоты -> shot.epf (рядом со скриптом или -Out).
# Пакетный Конфигуратор не понимает кириллицу в путях — сборка идёт через временную папку с коротким ASCII-путём.
# Пустая база для сборки создаётся скиллом epf-build сама; модули конфигурации в открывалке вызываются через
# Вычислить, поэтому на пустой базе она компилируется.
param([string]$Src = '', [string]$Out = '')
$ErrorActionPreference = 'Stop'
if (-not $Src) { $Src = Join-Path $PSScriptRoot 'src' }
if (-not $Out) { $Out = Join-Path $PSScriptRoot 'shot.epf' }
$tmp = (New-Object -ComObject Scripting.FileSystemObject).GetFolder([IO.Path]::GetTempPath()).ShortPath + "\bitshot_build"
Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory $tmp | Out-Null
Copy-Item "$Src\*" $tmp -Recurse
$root = Get-ChildItem $tmp -Filter *.xml | Select-Object -First 1
Push-Location $tmp
try {
	& powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\skills\epf-build\scripts\epf-build.ps1" -SourceFile $root.FullName -OutputFile "$tmp\shot.epf" | Select-Object -Last 3
} finally { Pop-Location }
if (-not (Test-Path "$tmp\shot.epf")) { throw 'Открывалка не собрана — смотри ошибки компиляции выше' }
Copy-Item "$tmp\shot.epf" $Out -Force
Remove-Item $tmp -Recurse -Force
"[OK] $Out"
