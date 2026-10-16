# Скриншоты форм в ОТДЕЛЬНОМ сеансе 1С — если лицензия базы пускает второй клиент (иначе — shoot-session.ps1).
# Запускает тонкий клиент с открывалкой shot.epf, ждёт флажки %TEMP%\bitshots\step<N>.done и снимает окно 1С
# в <OutDir>\step<N>.png. Окно разворачивается без активации и кладётся под остальные — пользователю не мешает;
# снимается только окно 1С, не экран. База — из <ProjectDir>\.claude\.secrets\db_<Base>.json. Только демоданные.
#
# Запуск: powershell.exe -NoProfile -ExecutionPolicy Bypass -File shoot.ps1 -Scenario acts -OutDir <папка> -Steps 2 [-ProjectDir <проект>]
param(
	[Parameter(Mandatory = $true)][string]$Scenario,
	[Parameter(Mandatory = $true)][string]$OutDir,
	[int]$Steps = 1,
	[string]$ProjectDir = (Get-Location).Path,
	[string]$Base = 'demo',
	[string]$Epf = '',
	[int]$Width = 1500,
	[int]$Height = 860,
	[int]$TimeoutSec = 300
)
$ErrorActionPreference = 'Stop'
if (-not $Epf) { $Epf = Join-Path $PSScriptRoot 'shot.epf' }
Add-Type -AssemblyName System.Drawing
if (-not ([System.Management.Automation.PSTypeName]'BitShotW32c').Type) {
	Add-Type @"
using System; using System.Runtime.InteropServices;
public class BitShotW32c {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr a, int x, int y, int cx, int cy, uint f);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
}
"@
}
function Save-Window([IntPtr]$hwnd, [string]$file) {
	if ([BitShotW32c]::IsIconic($hwnd)) { [BitShotW32c]::ShowWindow($hwnd, 4) | Out-Null }
	[BitShotW32c]::SetWindowPos($hwnd, [IntPtr]1, 0, 0, $Width, $Height, 0x0010) | Out-Null
	Start-Sleep -Seconds 2
	$r = New-Object BitShotW32c+RECT; [BitShotW32c]::GetWindowRect($hwnd, [ref]$r) | Out-Null
	$bmp = New-Object System.Drawing.Bitmap ($r.R - $r.L), ($r.B - $r.T)
	$g = [System.Drawing.Graphics]::FromImage($bmp); $hdc = $g.GetHdc()
	[BitShotW32c]::PrintWindow($hwnd, $hdc, 2) | Out-Null; $g.ReleaseHdc($hdc); $g.Dispose()
	$bmp.Save($file, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
}
$db = [IO.File]::ReadAllText((Join-Path $ProjectDir ".claude\.secrets\db_$Base.json"), [Text.Encoding]::UTF8) | ConvertFrom-Json
New-Item -ItemType Directory -Force $OutDir | Out-Null
$OutDir = (Resolve-Path $OutDir).Path
$flags = Join-Path $env:TEMP 'bitshots'   # открывалка пишет флажки в КаталогВременныхФайлов() + "bitshots"
New-Item -ItemType Directory -Force $flags | Out-Null
Get-ChildItem $flags -Filter 'step*.done' | Remove-Item -Force
[IO.File]::WriteAllText("$flags\scenario.txt", $Scenario, [Text.UTF8Encoding]::new($false))
$v8 = Get-ChildItem 'C:\Program Files\1cv8\*\bin\1cv8c.exe' | Sort-Object { [version]$_.Directory.Parent.Name } | Select-Object -Last 1
$pwd1 = if ($db.password) { $db.password } else { '' }
$argList = "ENTERPRISE /F `"$($db.path)`" /N `"$($db.username)`" /P `"$pwd1`" /Execute `"$Epf`" /DisableStartupDialogs /DisableStartupMessages"
$t0 = Get-Date
$p = Start-Process -FilePath $v8.FullName -ArgumentList $argList -PassThru
$h = [IntPtr]::Zero
# 1cv8c может перезапустить себя другим процессом — берём новый процесс 1С с главным окном.
# Если процесс сразу завершился, причину покажет запуск с /Out <файл> (например, лимит лицензии разработчика).
while (((Get-Date) - $t0).TotalSeconds -lt 120 -and $h -eq [IntPtr]::Zero) {
	Start-Sleep -Milliseconds 700
	$cand = Get-Process 1cv8c -ErrorAction SilentlyContinue | Where-Object { $_.StartTime -ge $t0.AddSeconds(-2) -and $_.MainWindowHandle -ne [IntPtr]::Zero } | Select-Object -First 1
	if ($cand) { $p = $cand; $h = $cand.MainWindowHandle }
}
if ($h -eq [IntPtr]::Zero) { throw 'Окно 1С не найдено (не запустился второй сеанс? — используйте shoot-session.ps1)' }
for ($n = 1; $n -le $Steps; $n++) {
	while (-not (Test-Path (Join-Path $flags "step$n.done"))) {
		if (((Get-Date) - $t0).TotalSeconds -gt $TimeoutSec) {
			Save-Window $h (Join-Path $OutDir 'timeout.png')
			Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
			throw "Нет флажка шага $n (окно 1С на момент таймаута: timeout.png)"
		}
		if (-not (Get-Process -Id $p.Id -ErrorAction SilentlyContinue)) { throw "Сеанс 1С завершился до шага $n" }
		Start-Sleep -Milliseconds 500
	}
	Save-Window $h (Join-Path $OutDir "step$n.png")
	"[OK] step$n.png"
}
Start-Sleep -Seconds 10
Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
