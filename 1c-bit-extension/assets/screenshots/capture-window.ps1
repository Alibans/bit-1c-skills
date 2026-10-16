# Снимок окон процесса 1С (без вывода на передний план): разворачивает свёрнутое окно без активации, кладёт его
# под остальные окна и снимает через PrintWindow — пользователю не мешает. Сохраняет <Out>_<N>.png по каждому окну.
param([Parameter(Mandatory = $true)][int]$ProcessId, [Parameter(Mandatory = $true)][string]$Out, [int]$Width = 1500, [int]$Height = 860)
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System; using System.Collections.Generic; using System.Text; using System.Runtime.InteropServices;
public class BitCap {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc p, IntPtr l);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr a, int x, int y, int cx, int cy, uint f);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
  public static List<IntPtr> All(uint pid) { var l = new List<IntPtr>(); EnumWindows((h, x) => { uint p; GetWindowThreadProcessId(h, out p); if (p == pid && IsWindowVisible(h)) l.Add(h); return true; }, IntPtr.Zero); return l; }
  public static string Title(IntPtr h) { var sb = new StringBuilder(512); GetWindowText(h, sb, 512); return sb.ToString(); }
}
"@
$main = (Get-Process -Id $ProcessId).MainWindowHandle
if ([BitCap]::IsIconic($main)) { [BitCap]::ShowWindow($main, 4) | Out-Null }
[BitCap]::SetWindowPos($main, [IntPtr]1, 0, 0, $Width, $Height, 0x0010) | Out-Null
Start-Sleep -Seconds 3
$n = 0
foreach ($h in [BitCap]::All([uint32]$ProcessId)) {
	$n++
	$r = New-Object BitCap+RECT; [BitCap]::GetWindowRect($h, [ref]$r) | Out-Null
	$w = $r.R - $r.L; $hh = $r.B - $r.T
	"$n '$([BitCap]::Title($h))' $w x $hh"
	if ($w -lt 50 -or $hh -lt 50) { continue }
	$b = New-Object System.Drawing.Bitmap $w, $hh; $g = [System.Drawing.Graphics]::FromImage($b); $hdc = $g.GetHdc()
	[BitCap]::PrintWindow($h, $hdc, 2) | Out-Null; $g.ReleaseHdc($hdc); $g.Dispose()
	$b.Save("$($Out)_$n.png", [System.Drawing.Imaging.ImageFormat]::Png); $b.Dispose()
}
