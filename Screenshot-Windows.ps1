

Add-Type -AssemblyName System.Drawing, System.Windows.Forms, System.Collections

if (-not ("Window" -as [type])) {

    $Native = Add-Type -Debug:$False -MemberDefinition @'
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr GetWindow(IntPtr hWnd, uint uCmd);
    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr GetDlgItem(IntPtr hWnd, int nIDDlgItem);
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X,int Y, int cx, int cy, uint uFlags);
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")]
    public static extern IntPtr GetTopWindow(IntPtr hWnd);
    [DllImport("kernel32.dll")]
    public static extern uint GetLastError();
'@ -Name "NativeFunctions" -Namespace NativeFunctions -PassThru
    

    Add-Type @"
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public struct RECT
{
    public int Left;
    public int Top;
    public int Right;
    public int Bottom;
}

public class WinStruct
{
  public string WinTitle {get; set; }
  public int WinHwnd { get; set; }
}

class GetWindowsHelper
{
   private delegate bool CallBackPtr(int hwnd, int lParam);
   private static CallBackPtr callBackPtr = Callback;
   private static List<WinStruct> _WinStructList = new List<WinStruct>();

   [DllImport("user32.dll")]
   [return: MarshalAs(UnmanagedType.Bool)]
   private static extern bool EnumWindows(CallBackPtr lpEnumFunc, IntPtr lParam);
   [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
   public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

   private static bool Callback(int hWnd, int lparam)
   {
       StringBuilder sb = new StringBuilder(256);
       int res = GetWindowText((IntPtr)hWnd, sb, 256);
      _WinStructList.Add(new WinStruct { WinHwnd = hWnd, WinTitle = sb.ToString() });
       return true;
   }   

   public static List<WinStruct> GetWindows()
   {
      _WinStructList = new List<WinStruct>();
      EnumWindows(callBackPtr, IntPtr.Zero);
      return _WinStructList;
   }
}

public class Window
{
    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    public static extern IntPtr SendMessage(IntPtr hWnd, int Msg, int wParam, StringBuilder lParam);
    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    public static extern IntPtr SendMessage(IntPtr hWnd, int Msg, int wParam, int lParam);
    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    public static extern long GetWindowLong(IntPtr hWnd, int nIndex);
    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool AdjustWindowRectEx(out RECT lpRect, long dwStyle, bool bMenu, long dwExStyle);
    [DllImport("dwmapi.dll")]
    static extern int DwmGetWindowAttribute(IntPtr hwnd, long dwAttribute, out RECT pvAttribute, long cbAttribute);
     
    public static List<WinStruct> GetWindows()
    {
        return GetWindowsHelper.GetWindows();
    }

    const int LB_GETTEXT = 0x0189;
    const int LB_GETCOUNT = 0x018B;
    public static List<string> GetAllListBoxText(IntPtr hWnd)
    {
        int cnt = (int)SendMessage(hWnd, LB_GETCOUNT, 0, 0);
        List<string> res = new List<string>();
    
        for (int i = 0; i < cnt; i++)
        {
            StringBuilder sb = new StringBuilder(256);
            SendMessage(hWnd, LB_GETTEXT, i, sb);
            res.Add(sb.ToString());
        }
        return res;
    }

    public static RECT GetWindowRectangle(IntPtr hWnd)
    {
        RECT rect;
        int size = Marshal.SizeOf(typeof(RECT));
        DwmGetWindowAttribute(hWnd, 9, out rect, size);
        return rect;
    }
}
"@
}

function raise {
    param (
        [parameter(position = 0)]
        [int]$i
    )
    Write-Error "$i ==> $((New-Object System.ComponentModel.Win32Exception([int]$Native::GetLastError())).Message)"
}

function GetWindowRectWithoutShadow {
    param (
        [parameter(position = 0)]
        [int]$hwnd
    )
    # $r = [RECT]@{}
    # [void][Window]::GetWindowRect($hwnd, [ref]$r)

    # $wstyle = [Window]::GetWindowLong($hwnd, -16)
    # if (-not $wstyle) {
    #     raise 4
    # }
    # $wstyle_ex = [Window]::GetWindowLong($hwnd, -20)
    # if (-not $wstyle_ex) {
    #     raise 5
    # }
    # $shad = [RECT]@{}
    # if (($wstyle -band 0xc00000) -eq 0xc00000) {
    #     # with $wstyle -band $WS_CAPTION $shad would also include border which I'd want to preserve
    #     $wstyle -= 0xc00000
    # }
    # doesn't always work, e.g. for WS_POPUP it gives 1 pixel smaller rect
    # if (-not [Window]::AdjustWindowRectEx([ref]$shad, $wstyle, $False, $wstyle_ex)) {
    #     raise 6
    # }
    # $r.Left -= $shad.Left
    # $r.Right -= $shad.Right
    # $r.Bottom -= $shad.Bottom

    $r_dwm = [Window]::GetWindowRectangle($hwnd)

    # $r, $r_dwm, $shad | Format-Table | Out-String | Write-Host

    return $r_dwm
}

########################

$to_check = @{pattern = "TestMem5*"; id_error = 402; id_cycles = 400; id_listbox = 1004; color = 0xff803000 } # 80 30 00 color of error test within tm5
# $to_check = @{pattern = "HWiNFO*"; id_error = 2301; id_cycles = 2301; id_listbox = -1; color = 0xffbf0d00}
$sizefn = "$PSScriptRoot\lastlogsize"

########################

$image = New-Object System.Drawing.Bitmap 1, 1
$graphic = [System.Drawing.Graphics]::FromImage($image)
$p0 = New-Object System.Drawing.Point(0, 0)
try {
    $graphic.CopyFromScreen($p0, $p0, $image.Size)
}
catch {
    Start-Process -FilePath "$Env:windir\System32\tscon.exe" -ArgumentList ([System.Diagnostics.Process]::GetCurrentProcess().SessionId), "/dest:console" -Wait
    write-warning "Had to disconnect minimized RDP and/or relogin to allow for screenshots"
}

########################
$rect = [RECT]@{Left = [int]::MaxValue; Top = [int]::MaxValue }
########################
# $z_first = $Native::GetWindow($Native::GetForegroundWindow(), 3)
# if ($z_first -eq 0) {
#     Write-Warning "no foreground window"
#     $z_first = $Native::GetTopWindow(0)
# }
# windows get atop of current window, but without topmost style, unlike if done like below:
$z_first = $Native::GetTopWindow(0)
$windows = [Window]::GetWindows()
########################

# filter windows, bring them to top, decide on last_cycle
$last_cycle = $false
$ws = @()
$log = New-Object System.Collections.Generic.List[string]
ForEach ($arg in $args) {
    $wnds = @($windows | Where-Object { $_.WinTitle -like "$arg" })

    if ($wnds.Count -eq 0) {
        Write-Error "'$arg' windows not found"
    }
    elseif ($arg -like $to_check.pattern) {
        if ($wnds.Count -gt 2) {
            Write-Error "Don't know what to do with $($wnds.Count) of '$($to_check.pattern)' windows!"
            exit
        }
        $last_cycle = $wnds.Count -eq 2
    }

    $to_add = @()
    foreach ($w in $wnds) {

        # $w.WinTitle

        $r = New-Object RECT
        if (-not [Window]::GetWindowRect($w.WinHwnd, [ref]$r)) {
            Write-Error "'$($w.WinTitle)' can't get window rect"
            continue
        }

        if ($r.Right -lt 0 -and $r.Bottom -lt 0) {
            # $r | format-table
            Write-Warning "Restoring '$($w.WinTitle)' window"
            if (-not $Native::ShowWindow($w.WinHwnd, 9)) {
                raise 1
            }
        }

        #$windows | Where-Object { $_.WinHwnd -eq $z_first }
        if (-not $Native::SetWindowPos($w.WinHwnd, $z_first, 0, 0, 0, 0, 0x73)) {
            raise 2
        }
        # remove topmost style, whatever z_first was...
        if (-not $Native::SetWindowPos($w.WinHwnd, -2, 0, 0, 0, 0, 0x73)) {
            raise 3
        }
        $r = GetWindowRectWithoutShadow $w.WinHwnd

        $to_add += @{w = $w; r = $r }
    }
    
    if ($arg -like $to_check.pattern) {
        if ($last_cycle) {
            # $to_add holds exactly 2 values: main TM5 window and modal one, handle this
            if ($to_add[0].r.Bottom - $to_add[0].r.Top -lt 170) {
                $to_add = @($to_add[1], $to_add[0])
            }
            $main = $to_add[0]
            $modal = $to_add[1]
            # to move, window coordinates with shadows are needed
            $r_shad = [RECT]@{}
            [void][Window]::GetWindowRect($modal.w.WinHwnd, [ref]$r_shad)
            $r = GetWindowRectWithoutShadow $modal.w.WinHwnd
            # new $r.Right should equal $main.r.Right
            # but it's also equal to new move_x + left_shadow + r_width
            $move_x = $main.r.Right - ($r.Right - $r.Left) - ($r.Left - $r_shad.Left)
            $move_y = $main.r.Top - ($modal.r.Bottom - $modal.r.Top)
            if ($move_y -lt 0) {
                # can't move above main, as it goes off screen
                $move_y = $main.r.Bottom
            }
            if (-not $Native::SetWindowPos($modal.w.WinHwnd, -1, $move_x, $move_y, 0, 0, 0x71)) {
                raise 4
            }
            $modal.r = GetWindowRectWithoutShadow $modal.w.WinHwnd
        }
        else {
            $main = $to_add[0]
        }
        $child = $Native::GetDlgItem($main.w.WinHwnd, $to_check.id_error)
        $sb = [System.Text.StringBuilder]::new(256)
        [void][Window]::GetWindowText($child, $sb, 256);
        $error_caption = $sb.ToString()

        $child = $Native::GetDlgItem($main.w.WinHwnd, $to_check.id_cycles)
        [void]$sb.Clear()
        [void][Window]::GetWindowText($child, $sb, 256);
        $cycle = $sb.ToString()
        
        $child = $Native::GetDlgItem($main.w.WinHwnd, $to_check.id_listbox)
        $log = [Window]::GetAllListBoxText($child)
    }

    $ws += $to_add

}

foreach ($wnds in $ws) {
    foreach ($w in $wnds) {
        $rect.Left = [math]::Min($rect.Left, $w.r.Left)
        $rect.Top = [math]::Min($rect.Top, $w.r.Top)
        $rect.Right = [math]::Max($rect.Right, $w.r.Right)
        $rect.Bottom = [math]::Max($rect.Bottom, $w.r.Bottom)
        # $w.r, $rect | format-table
    }
}

$image = New-Object System.Drawing.Bitmap(($rect.Right - $rect.Left), ($rect.Bottom - $rect.Top))
$graphic = [System.Drawing.Graphics]::FromImage($image)

Start-Sleep -Milliseconds 200

$graphic.CopyFromScreen((New-Object System.Drawing.Point($rect.Left, $rect.Top)), $p0, $image.Size)

$suffix = $(if ($cycle.Length) { "-cycle$cycle" } else { "" })
$suffix += "-$(if ($error_caption.Length) {"$error_caption-errors"} else {"ok"})"
$suffix += "$(if ($last_cycle) {"-last"})"
$basename = "$((get-date).tostring('yyyy.MM.dd-HH.mm.ss'))$suffix"

$image.Save("$PSScriptRoot\$basename.png", [System.Drawing.Imaging.ImageFormat]::Png)

if ($log.Count) {
    $prev_size = 0
    if (Test-Path -LiteralPath $sizefn) {
        $prev_size = [int](Get-Content -LiteralPath $sizefn)
    }
    if ($log.Count -ne $prev_size) {
        $log | Select-Object -Skip $prev_size | Set-Content -LiteralPath "$PSScriptRoot\$basename.log"
        Set-Content -LiteralPath $sizefn $log.Count
    }
}

if ($last_cycle) {
    Remove-Item -LiteralPath $sizefn -ErrorAction Ignore
    Stop-Process -Name "HWiNFO*"
}

#"\"HWiNFO*Sensor Status\""
#"foobar20*"

