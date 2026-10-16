# Скриншоты форм в УЖЕ ОТКРЫТОМ сеансе демобазы (тот, где запущен MCP Toolkit) — когда второй сеанс открыть нельзя
# (лицензия разработчика пускает одного клиента). Через Toolkit: подключает открывалку shot.epf, пишет сценарий,
# открывает её форму на клиенте, ставит окну временный заголовок, чтобы найти именно этот сеанс, и снимает окно
# через PrintWindow на каждом флажке step<N>.done. Окно не двигается и не меняет размер. Только демоданные.
#
# Запуск: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\screenshots\shoot-session.ps1 -Scenario acts -Steps 2 -OutDir <папка>
param(
	[Parameter(Mandatory = $true)][string]$Scenario,
	[Parameter(Mandatory = $true)][string]$OutDir,
	[int]$Steps = 1,
	[int]$TimeoutSec = 180,
	[string]$ProjectDir = (Get-Location).Path,   # папка проекта: из неё toolkit.ps1 находит .claude\.secrets\toolkit.json
	[string]$Epf = ''                            # открывалка; по умолчанию shot.epf рядом со скриптом
)
$ErrorActionPreference = 'Stop'
if (-not $Epf) { $Epf = Join-Path $PSScriptRoot 'shot.epf' }
$root = $ProjectDir
$toolkit = "$env:USERPROFILE\.claude\skills\1c-toolkit\scripts\toolkit.ps1"
$flags = Join-Path $env:TEMP 'bitshots'   # открывалка пишет флажки в КаталогВременныхФайлов() + "bitshots" — та же папка
New-Item -ItemType Directory -Force $flags, $OutDir | Out-Null
Get-ChildItem $flags -Filter 'step*.done' | Remove-Item -Force
[IO.File]::WriteAllText("$flags\scenario.txt", $Scenario, [Text.UTF8Encoding]::new($false))
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System; using System.Text; using System.Runtime.InteropServices;
public class BitSess {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc p, IntPtr l);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
  public static IntPtr Find(string part) { IntPtr found = IntPtr.Zero;
    EnumWindows((h, l) => { if (IsWindowVisible(h)) { var sb = new StringBuilder(512); GetWindowText(h, sb, 512); if (sb.ToString().Contains(part)) { found = h; return false; } } return true; }, IntPtr.Zero); return found; }
}
"@
function Invoke-Toolkit([string]$code, [string]$context = 'server') {
	$file = Join-Path $env:TEMP "bitshot_$([guid]::NewGuid().ToString('N')).bsl"
	[IO.File]::WriteAllText($file, $code, [Text.UTF8Encoding]::new($true))
	Push-Location $root
	try { $out = & powershell.exe -NoProfile -File $toolkit -Action code -CodeFile $file -Context $context 2>&1 | Out-String } finally { Pop-Location; Remove-Item $file -Force }
	if ($out -notmatch '"success":\s*true') { throw "Toolkit: $out" }
	$out
}
Invoke-Toolkit "Адрес = ПоместитьВоВременноеХранилище(Новый ДвоичныеДанные(""$Epf""));`r`nРезультат = ВнешниеОбработки.Подключить(Адрес, , Ложь);" | Out-Null
$mark = "BITSHOT-$([guid]::NewGuid().ToString('N').Substring(0,6))"
Invoke-Toolkit "УстановитьЗаголовокКлиентскогоПриложения(""$mark"");`r`nОткрытьФорму(""ВнешняяОбработка.БИТ_Скриншоты.Форма"");`r`nРезультат = ""ok"";" 'client' | Out-Null
Start-Sleep -Seconds 2
$h = [BitSess]::Find($mark)
try {
	if ($h -eq [IntPtr]::Zero) { throw 'Окно сеанса не найдено' }
	if ([BitSess]::IsIconic($h)) { throw 'Окно сеанса свёрнуто — разверните его и повторите' }
	$t0 = Get-Date
	for ($n = 1; $n -le $Steps; $n++) {
		while (-not (Test-Path "$flags\step$n.done")) {
			if (((Get-Date) - $t0).TotalSeconds -gt $TimeoutSec) { throw "Нет флажка шага $n" }
			Start-Sleep -Milliseconds 500
		}
		Start-Sleep -Seconds 1
		$r = New-Object BitSess+RECT; [BitSess]::GetWindowRect($h, [ref]$r) | Out-Null
		$bmp = New-Object System.Drawing.Bitmap ($r.R - $r.L), ($r.B - $r.T)
		$g = [System.Drawing.Graphics]::FromImage($bmp); $hdc = $g.GetHdc()
		[BitSess]::PrintWindow($h, $hdc, 2) | Out-Null; $g.ReleaseHdc($hdc); $g.Dispose()
		$bmp.Save((Join-Path $OutDir "step$n.png"), [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
		"[OK] step$n.png"
	}
} finally {
	Invoke-Toolkit "УстановитьЗаголовокКлиентскогоПриложения("""");`r`nРезультат = ""ok"";" 'client' | Out-Null
}
