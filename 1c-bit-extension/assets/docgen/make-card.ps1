# Клиентская карточка решения на фирменном бланке Первого БИТа: .docx и .pdf.
# Текст карточки — модуль card.js (образец card-example.js), картинки — в папке img рядом с ним.
# Нужны node, 7-Zip (C:\Program Files\7-Zip) и Word (PDF сохраняется через Word).
#
# Запуск: powershell.exe -NoProfile -ExecutionPolicy Bypass -File make-card.ps1 `
#           -Card <папка>\card.js -Out "<папка вывода>\БИТ <Название> - карточка решения для клиента"
param(
	[Parameter(Mandatory = $true)][string]$Card,
	[Parameter(Mandatory = $true)][string]$Out
)
$ErrorActionPreference = 'Stop'
$card = (Resolve-Path $Card).Path
$outBase = [IO.Path]::GetFullPath($Out)
New-Item -ItemType Directory -Force (Split-Path $outBase) | Out-Null
$env:IMG_DIR = Join-Path (Split-Path $card) 'img'
& node (Join-Path $PSScriptRoot 'docgen.js') (Join-Path $PSScriptRoot 'template') "$outBase.docx" $card
if ($LASTEXITCODE -ne 0) { throw "docgen.js завершился с ошибкой" }
Remove-Item "$outBase.docx.dir" -Recurse -Force -ErrorAction SilentlyContinue
$word = New-Object -ComObject Word.Application
$word.Visible = $false
try {
	$doc = $word.Documents.Open("$outBase.docx", $false, $true)
	$pages = $doc.ComputeStatistics(2)
	$doc.ExportAsFixedFormat("$outBase.pdf", 17)
	$doc.Close(0)
} finally { $word.Quit() }
"[OK] $outBase.pdf (страниц: $pages)"
