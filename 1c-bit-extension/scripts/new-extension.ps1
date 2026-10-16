# Создаёт исходники нового расширения Первого БИТа из заготовки assets\skeleton:
# раздел «Первый БИТ» (обязательный подраздел «О расширении» + подразделы из -Sections), команды «Личный кабинет»
# и «Возможности расширения», форма справки, страница «Возможности расширения», основная роль.
# Все внутренние имена получают имя расширения, поэтому разные расширения БИТ ставятся в одну базу.
#
# Запуск: powershell.exe -NoProfile -ExecutionPolicy Bypass -File new-extension.ps1 `
#           -Name БИТ_КонтрольЦен -Synonym "БИТ: Контроль цен" -OutDir C:\...\src\БИТ_КонтрольЦен [-Version 1.0.0.1] `
#           [-Sections "Работа с документами","Настройки"]
param(
	[Parameter(Mandatory = $true)][string]$Name,
	[Parameter(Mandatory = $true)][string]$Synonym,
	[Parameter(Mandatory = $true)][string]$OutDir,
	[string]$Version = '1.0.0.1',
	# Подразделы под задачу, в порядке показа: "Работа с документами","Отчёты","Настройки". «О расширении» есть всегда.
	[string[]]$Sections = @()
)
$ErrorActionPreference = 'Stop'
if ($Name -notmatch '^БИТ_[А-ЯЁа-яёA-Za-z0-9]+$') { throw "Имя должно быть вида БИТ_<Имя> без пробелов и подчёркиваний после префикса: $Name" }
if ($Synonym -notmatch '^БИТ: \S') { throw "Синоним должен начинаться с «БИТ: »: $Synonym" }
if ($Version -notmatch '^\d+\.\d+\.\d+\.\d+$') { throw "Версия вида 1.0.0.1: $Version" }
if ((Test-Path $OutDir) -and (Get-ChildItem $OutDir -Force | Select-Object -First 1)) { throw "Каталог не пуст: $OutDir" }

$short = $Name.Substring(4)
$skeleton = Join-Path (Split-Path $PSScriptRoot) 'assets\skeleton'
$map = [ordered]@{ '__ИМЯ__' = $Name; '__КОРОТКОЕ__' = $short; '__СИНОНИМ__' = $Synonym; '__ВЕРСИЯ__' = $Version }
function Expand([string]$s) { foreach ($k in $map.Keys) { $s = $s.Replace($k, $map[$k]) }; $s }

New-Item -ItemType Directory -Force $OutDir | Out-Null
$OutDir = (Resolve-Path $OutDir).Path
$guidRe = [regex]'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'
$newIds = @{}
foreach ($f in Get-ChildItem $skeleton -Recurse -File) {
	$rel = Expand ($f.FullName.Substring($skeleton.Length + 1))
	$target = Join-Path $OutDir $rel
	New-Item -ItemType Directory -Force (Split-Path $target) | Out-Null
	$bytes = [IO.File]::ReadAllBytes($f.FullName)
	$bom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
	$text = [Text.Encoding]::UTF8.GetString($bytes); if ($bom) { $text = $text.Substring(1) }
	$text = Expand $text
	if ($f.Extension -eq '.xml') {
		# Ссылки на объекты типовой конфигурации (ExtendedConfigurationObject) и классы платформы (xr:ClassId) сохраняются, остальные идентификаторы — новые
		$parts = [regex]::Split($text, '(<ExtendedConfigurationObject>[^<]*</ExtendedConfigurationObject>|<xr:ClassId>[^<]*</xr:ClassId>)')
		for ($i = 0; $i -lt $parts.Count; $i += 2) {
			$parts[$i] = $guidRe.Replace($parts[$i], {
				param($m)
				$k = $m.Value.ToLower()
				if (-not $newIds.ContainsKey($k)) { $newIds[$k] = [guid]::NewGuid().ToString() }
				$newIds[$k]
			})
		}
		$text = -join $parts
	}
	[IO.File]::WriteAllText($target, $text, [Text.UTF8Encoding]::new($bom))
}
# Подразделы раздела «Первый БИТ» под задачу — перед обязательным «О расширении».
# Имя подсистемы строится из названия: «Работа с документами» -> РаботаСДокументами.
$pattern = [IO.File]::ReadAllText((Join-Path (Split-Path $PSScriptRoot) 'assets\subsection.xml'), [Text.Encoding]::UTF8).TrimStart([char]0xFEFF)
$subDir = Join-Path $OutDir "Subsystems\${Name}_ПервыйБИТ\Subsystems"
$subLines = ''
$titles = @()
# При запуске через -File список приходит одной строкой "А,Б" — делим по запятой
foreach ($title in ($Sections | ForEach-Object { $_ -split ',' })) {
	$t = $title.Trim()
	if (-not $t) { continue }
	$words = $t -split '[^\p{L}\d]+' | Where-Object { $_ }
	$subName = -join ($words | ForEach-Object { $_.Substring(0, 1).ToUpper() + $_.Substring(1) })
	if ($subName -eq 'ОРасширении') { continue }
	$xml = $pattern.Replace('__ПОДРАЗДЕЛ_ИМЯ__', $subName).Replace('__ПОДРАЗДЕЛ_СИНОНИМ__', $t).Replace('00000000-0000-0000-0000-00000000ab01', [guid]::NewGuid().ToString())
	[IO.File]::WriteAllText((Join-Path $subDir "$subName.xml"), $xml, [Text.UTF8Encoding]::new($true))
	$subLines += "`t`t`t<Subsystem>$subName</Subsystem>`r`n"
	$titles += $t
}
$root = Join-Path $OutDir "Subsystems\${Name}_ПервыйБИТ.xml"
$rootText = [IO.File]::ReadAllText($root, [Text.Encoding]::UTF8).TrimStart([char]0xFEFF).Replace('__ПОДРАЗДЕЛЫ__', $subLines)
[IO.File]::WriteAllText($root, $rootText, [Text.UTF8Encoding]::new($true))

"[OK] $Name ($Synonym, $Version) -> $OutDir"
"     роль: БИТ_ОсновнаяРоль$short; раздел «Первый БИТ»: ${Name}_ПервыйБИТ; новых идентификаторов: $($newIds.Count)"
"     подразделы: " + (($titles + 'О расширении') -join ', ')
