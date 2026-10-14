# -*- coding: utf-8 -*-
"""바탕화면 아이콘 진단·정리 — 가려져 있어도 보이고, 화면 밖으로 나간 것을 찾아 옮긴다.

## 왜 필요한가

바로가기를 바탕화면에 만들었는데 "안 보인다" 는 일이 실제로 났다. 원인 후보가 여럿인데
**파일 탐색기로는 구분이 안 된다**:

  · 파일은 있는데 탐색기가 아직 못 읽었다        → 폴더를 보면 안다
  · 탐색기는 읽었는데 **아이콘 격자가 화면보다 커서** 화면 밖 칸에 배정됐다 → **폴더로는 모른다**
  · 다른 창(전체화면 게임 등)이 바탕화면을 덮고 있다 → 화면 캡처로는 모른다(가려서 안 찍힘)

이 스크립트는 **탐색기의 아이콘 리스트뷰(SysListView32)에 직접 물어본다**:
개수·이름·좌표·격자 점유까지. 그리고 `PrintWindow(PW_RENDERFULLCONTENT)` 로
**다른 창에 가려져 있어도** 아이콘 레이어를 그려내 PNG 로 저장한다.

## 쓰는 법

    PY=<managed python>
    $PY tools/desktop_icon_check.py                      # 목록 + 좌표 + 점유 지도 + 화면 밖 항목
    $PY tools/desktop_icon_check.py --find "언어의 조각"   # 그 항목의 좌표
    $PY tools/desktop_icon_check.py --move-to-top "언어의 조각"   # 맨 윗줄 빈 칸으로
    $PY tools/desktop_icon_check.py --render out.png      # 아이콘 레이어를 PNG 로

## ⚠️ 알아둘 것

· **COM 을 쓰지 않는다** — `WScript.Shell` 은 이 환경에서 보안 정책으로 막힌다.
  `LVM_GETITEMTEXTW` 는 다른 프로세스(explorer.exe) 메모리를 읽어야 해서
  `OpenProcess` + `VirtualAllocEx` + `WriteProcessMemory` + `SendMessage` + `ReadProcessMemory`
  를 직접 부른다.
· **`GetWindowRect` 는 DPI 가상화에 속는다.** 프로세스가 DPI-unaware 면 150% 배율에서
  5760x2160 을 3840x1440 으로 **거짓 보고**한다 → 아이콘 좌표(y=1633)가 화면 밖처럼 보인다.
  그래서 `SetProcessDpiAwareness(2)` 를 **먼저** 부른다. (`LVM_GETITEMRECT` 좌표는 물리 기준.)
· **`LVM_SETITEMPOSITION` 은 그 항목 하나만 옮긴다** — 전체 재정렬(`LVM_ARRANGE`)이 아니라
  사용자가 손으로 맞춰 둔 배치를 건드리지 않는다. `LVS_AUTOARRANGE` 가 켜져 있으면 안 먹는다.
· ⚠️ **옮긴 뒤에는 셸에 알려야 한다**(`persist()`). `LVM_SETITEMPOSITION` 은 **보이는 자리만**
  바꾼다 — 안 알리면 다음 새로고침이나 `.lnk` 덮어쓰기 순간 **원래 자리로 되돌아간다**(실측).
· ⚠️ `.lnk` 를 **`os.replace`(이름 바꿔치기)로 쓰면 아이콘 자리가 초기화**된다(파일 신원이 바뀐다).
  같은 자리에 덮어쓰려면 `open(path,"wb")` 로 **제자리** 쓰기.
· 격자 피치 실측값은 **112 x 148**(아이콘 129px + 여백). 원점은 보통 (0,5).
"""
import argparse
import ctypes
import os
import sys
from ctypes import wintypes

user32 = ctypes.windll.user32
gdi32 = ctypes.windll.gdi32
kernel32 = ctypes.windll.kernel32
shell32 = ctypes.windll.shell32

LVM_GETITEMCOUNT = 0x1004
LVM_GETITEMTEXTW = 0x1073
LVM_GETITEMRECT = 0x100E
LVM_SETITEMPOSITION = 0x100F
LVIR_BOUNDS = 0
GWL_STYLE = -16
LVS_AUTOARRANGE = 0x0100
PW_RENDERFULLCONTENT = 0x00000002

SHCNE_UPDATEDIR = 0x00001000
SHCNF_PATHW = 0x0005

PROC = 0x0008 | 0x0010 | 0x0020 | 0x0400
MEM_CR = 0x1000 | 0x2000
MEM_RELEASE = 0x8000
PAGE_READWRITE = 0x04

user32.FindWindowW.restype = wintypes.HWND
user32.FindWindowExW.restype = wintypes.HWND
user32.FindWindowExW.argtypes = [wintypes.HWND, wintypes.HWND, wintypes.LPCWSTR, wintypes.LPCWSTR]
user32.SendMessageW.restype = ctypes.c_long
user32.SendMessageW.argtypes = [wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM]
kernel32.OpenProcess.restype = wintypes.HANDLE
kernel32.VirtualAllocEx.restype = ctypes.c_void_p
kernel32.VirtualAllocEx.argtypes = [wintypes.HANDLE, ctypes.c_void_p, ctypes.c_size_t,
                                    wintypes.DWORD, wintypes.DWORD]


class RECT(ctypes.Structure):
    _fields_ = [("left", ctypes.c_long), ("top", ctypes.c_long),
                ("right", ctypes.c_long), ("bottom", ctypes.c_long)]


class LVITEMW(ctypes.Structure):
    _fields_ = [("mask", wintypes.UINT), ("iItem", ctypes.c_int), ("iSubItem", ctypes.c_int),
                ("state", wintypes.UINT), ("stateMask", wintypes.UINT),
                ("pszText", ctypes.c_void_p), ("cchTextMax", ctypes.c_int),
                ("iImage", ctypes.c_int), ("lParam", wintypes.LPARAM),
                ("iIndent", ctypes.c_int), ("iGroupId", ctypes.c_int),
                ("cColumns", wintypes.UINT), ("puColumns", ctypes.c_void_p),
                ("piColFmt", ctypes.c_void_p), ("iGroup", ctypes.c_int)]


class BITMAPINFOHEADER(ctypes.Structure):
    _fields_ = [("biSize", wintypes.DWORD), ("biWidth", ctypes.c_long),
                ("biHeight", ctypes.c_long), ("biPlanes", wintypes.WORD),
                ("biBitCount", wintypes.WORD), ("biCompression", wintypes.DWORD),
                ("biSizeImage", wintypes.DWORD), ("biXPelsPerMeter", ctypes.c_long),
                ("biYPelsPerMeter", ctypes.c_long), ("biClrUsed", wintypes.DWORD),
                ("biClrImportant", wintypes.DWORD)]


class BITMAPINFO(ctypes.Structure):
    _fields_ = [("bmiHeader", BITMAPINFOHEADER), ("bmiColors", wintypes.DWORD * 3)]


def find_listview():
    """바탕화면 아이콘을 담은 SysListView32. Win11 은 Progman 또는 WorkerW 아래에 있다."""
    dv = user32.FindWindowExW(user32.FindWindowW("Progman", None), None,
                              "SHELLDLL_DefView", None)
    if dv:
        lv = user32.FindWindowExW(dv, None, "SysListView32", None)
        if lv:
            return lv
    found = []

    @ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
    def cb(hwnd, _l):
        buf = ctypes.create_unicode_buffer(256)
        user32.GetClassNameW(hwnd, buf, 256)
        if buf.value == "WorkerW":
            d = user32.FindWindowExW(hwnd, None, "SHELLDLL_DefView", None)
            if d:
                x = user32.FindWindowExW(d, None, "SysListView32", None)
                if x:
                    found.append(x)
        return True

    user32.EnumWindows(cb, 0)
    return found[0] if found else None


class Desktop:
    def __init__(self):
        try:
            ctypes.windll.shcore.SetProcessDpiAwareness(2)
        except Exception:
            pass
        self.lv = find_listview()
        if not self.lv:
            sys.exit("바탕화면 아이콘 리스트뷰를 못 찾았다")
        pid = wintypes.DWORD()
        user32.GetWindowThreadProcessId(self.lv, ctypes.byref(pid))
        self.h = kernel32.OpenProcess(PROC, False, pid.value)
        if not self.h:
            sys.exit("OpenProcess 실패 (err=%d)" % kernel32.GetLastError())
        self._li = ctypes.sizeof(LVITEMW)
        self._tx = 512 * 2
        self._remote = kernel32.VirtualAllocEx(self.h, None, self._li + self._tx + 64,
                                               MEM_CR, PAGE_READWRITE)
        self._rtext = self._remote + self._li
        self._rrect = self._remote + self._li + self._tx

    def close(self):
        kernel32.VirtualFreeEx(self.h, ctypes.c_void_p(self._remote), 0, MEM_RELEASE)
        kernel32.CloseHandle(self.h)

    def count(self):
        return user32.SendMessageW(self.lv, LVM_GETITEMCOUNT, 0, 0)

    def name(self, i):
        it = LVITEMW()
        it.mask, it.iItem, it.iSubItem = 0x0001, i, 0
        it.pszText = ctypes.c_void_p(self._rtext)
        it.cchTextMax = 512
        kernel32.WriteProcessMemory(self.h, ctypes.c_void_p(self._remote),
                                    ctypes.byref(it), self._li, None)
        user32.SendMessageW(self.lv, LVM_GETITEMTEXTW, i, self._remote)
        b = ctypes.create_string_buffer(512 * 2)
        kernel32.ReadProcessMemory(self.h, ctypes.c_void_p(self._rtext), b, 512 * 2, None)
        return b.raw.decode("utf-16-le", "replace").split("\x00")[0]

    def rect(self, i):
        r = RECT(0, 0, LVIR_BOUNDS, 0)
        kernel32.WriteProcessMemory(self.h, ctypes.c_void_p(self._rrect), ctypes.byref(r), 16, None)
        user32.SendMessageW(self.lv, LVM_GETITEMRECT, i, self._rrect)
        out = RECT()
        kernel32.ReadProcessMemory(self.h, ctypes.c_void_p(self._rrect), ctypes.byref(out), 16, None)
        return out

    def items(self):
        out = []
        for i in range(self.count()):
            r = self.rect(i)
            out.append({"i": i, "name": self.name(i),
                        "x": r.left, "y": r.top, "w": r.right - r.left, "h": r.bottom - r.top})
        return out

    def window_rect(self):
        wr = RECT()
        user32.GetWindowRect(self.lv, ctypes.byref(wr))
        return wr.right - wr.left, wr.bottom - wr.top

    def style(self):
        return user32.GetWindowLongW(self.lv, GWL_STYLE)

    def move(self, i, x, y):
        user32.SendMessageW(self.lv, LVM_SETITEMPOSITION, i, (y << 16) | (x & 0xFFFF))

    def repaint(self):
        user32.InvalidateRect(self.lv, None, True)
        user32.UpdateWindow(self.lv)
        user32.RedrawWindow(self.lv, None, None, 0x0001 | 0x0004 | 0x0100 | 0x0400)

    def persist(self):
        """옮긴 자리를 **셸백에 기록**시킨다 — F5 와 같은 경로.

        ⚠️ `move()` 는 **보이는 자리만** 바꾼다. 셸에 알리지 않으면 다음 새로고침
        (또는 `.lnk` 를 다시 쓰는 순간)에 **원래 자리로 되돌아간다** — 실측:
        옮긴 뒤 알림 없이 .lnk 를 덮어썼더니 (672,5) → (224,1633) 으로 복귀했다.
        알림을 보내면 덮어쓴 뒤에도 (672,5) 가 남았다.
        """
        shell32.SHChangeNotify(
            SHCNE_UPDATEDIR, SHCNF_PATHW,
            ctypes.c_wchar_p(os.path.join(os.path.expanduser("~"), "Desktop")), None)

    def render(self, path):
        """가려져 있어도 아이콘 레이어를 그려낸다 (PrintWindow + PW_RENDERFULLCONTENT)."""
        from PIL import Image
        W, H = self.window_rect()
        hs = user32.GetDC(0)
        hm = gdi32.CreateCompatibleDC(hs)
        hb = gdi32.CreateCompatibleBitmap(hs, W, H)
        gdi32.SelectObject(hm, hb)
        user32.PrintWindow(self.lv, hm, PW_RENDERFULLCONTENT)
        bi = BITMAPINFO()
        bi.bmiHeader.biSize = ctypes.sizeof(BITMAPINFOHEADER)
        bi.bmiHeader.biWidth, bi.bmiHeader.biHeight = W, -H
        bi.bmiHeader.biPlanes, bi.bmiHeader.biBitCount = 1, 32
        buf = ctypes.create_string_buffer(W * H * 4)
        gdi32.GetDIBits(hm, hb, 0, H, buf, ctypes.byref(bi), 0)
        img = Image.frombuffer("RGBA", (W, H), buf.raw, "raw", "BGRA", 0, 1).convert("RGB")
        img.save(path)
        gdi32.DeleteObject(hb)
        gdi32.DeleteDC(hm)
        user32.ReleaseDC(0, hs)
        return img


def pitch(items):
    xs = sorted({it["x"] for it in items})
    ys = sorted({it["y"] for it in items})
    px = min((b - a for a, b in zip(xs, xs[1:])), default=112)
    py = min((b - a for a, b in zip(ys, ys[1:])), default=148)
    return xs[0], ys[0], px, py


def main():
    ap = argparse.ArgumentParser(description="바탕화면 아이콘 진단·정리")
    ap.add_argument("--find", help="이 문자열이 든 항목의 좌표를 찍는다")
    ap.add_argument("--move-to-top", help="이 문자열이 든 항목을 맨 윗줄 빈 칸으로 옮긴다")
    ap.add_argument("--render", help="아이콘 레이어를 이 PNG 경로로 그려낸다")
    ap.add_argument("--rows", type=int, default=14, help="점유 지도에 찍을 행 수")
    ap.add_argument("--cols", type=int, default=8, help="점유 지도에 찍을 열 수")
    args = ap.parse_args()

    d = Desktop()
    items = d.items()
    W, H = d.window_rect()
    x0, y0, px, py = pitch(items)
    print("아이콘 %d개 · 리스트뷰 %dx%d · 격자 원점(%d,%d) 피치(%d,%d) · AUTOARRANGE=%s"
          % (len(items), W, H, x0, y0, px, py, bool(d.style() & LVS_AUTOARRANGE)))

    occ = {(it["x"], it["y"]) for it in items}
    print("=== 점유 지도 (■ 점유 / · 빈칸) ===")
    for r in range(args.rows):
        print("  y=%4d  %s" % (y0 + r * py,
                              "".join("■" if (x0 + c * px, y0 + r * py) in occ else "·"
                                      for c in range(args.cols))))

    def find(s):
        return next((it for it in items if s in it["name"]), None)

    if args.find:
        it = find(args.find)
        print("--find %r -> %s" % (args.find, ("item %d (%d,%d) %s"
              % (it["i"], it["x"], it["y"], it["name"])) if it else "없음"))

    if args.move_to_top:
        it = find(args.move_to_top)
        if not it:
            print("--move-to-top: 못 찾음")
        else:
            occ2 = occ - {(it["x"], it["y"])}
            free = None
            for r in range(args.rows + 20):
                for c in range(80):
                    cand = (x0 + c * px, y0 + r * py)
                    if cand not in occ2:
                        free = cand
                        break
                if free:
                    break
            d.move(it["i"], free[0], free[1])
            d.repaint()
            d.persist()                       # ⚠️ 안 하면 다음 새로고침에 되돌아간다
            r2 = d.rect(it["i"])
            print("--move-to-top: %s  (%d,%d) -> (%d,%d)  [셸백 기록]"
                  % (it["name"], it["x"], it["y"], r2.left, r2.top))

    if args.render:
        img = d.render(args.render)
        print("--render: %s %s" % (args.render, img.size))

    d.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
