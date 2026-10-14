# -*- coding: utf-8 -*-
"""godot_lucky 데스크톱 바로가기 생성기.

    <managed python> -m pip install pylnk3
    <managed python> tools/make_desktop_shortcut.py

만드는 것
  1. `icon.ico` — 프로젝트 `icon.svg` 디자인을 Pillow 로 다시 그린 것
     (256/128/64/48/32/16 여섯 크기). Godot 의 Windows 내보내기 아이콘으로도 쓸 수 있다.
  2. 바탕화면의 `언어의 조각 - 무한 병합.lnk`
     → `godot.exe --path <이 프로젝트>` 를 실행한다.

⚠️ 폰트에 `ㄱ` 이 있어야 한다(neodgm.ttf). 없으면 아이콘 글자만 빠진다.

## 왜 `.lnk` 를 **바이트로 조립**하나 — COM 도, pylnk3 도 못 쓴다

`WScript.Shell`(COM)은 이 환경이 **보안 정책으로 막는다**
(`COM object instantiation can run arbitrary code`). PowerShell 로도 안 된다.
그래서 순수 파이썬 `pylnk3` 를 썼는데, **`pylnk3` 는 파서지 생성기가 아니다** (실측 2026-10-09):

    `for_file()` 로 새로 만든 .lnk                → ShellExecute **5** (액세스 거부)
    정상 .lnk 를 파싱해 **그대로 되쓰기만** 한 것   → ShellExecute **5**  (1063 B → 2004 B 로 부푼다)

즉 되쓰기만 해도 셸이 거절한다 — `IDList` 재직렬화가 셸 규격과 어긋난다.
필드만 되읽어 대조하면(타깃·인자·작업폴더·아이콘 전부 정상으로 읽힌다) **못 잡는다.**
⚠️ 그래서 검증은 필드 대조로 끝내지 말고 **`ShellExecuteW` 로 실제로 열어 봐라**
(>32 = 셸이 열었다 / 5 = 깨짐). 정상 `.lnk` 와 나란히 돌려 대조하면 확실하다.

### 그래서 하는 일 — **정상 `.lnk` 의 바이트를 물려받는다**

`.lnk` 구조는 정해져 있다:

    [헤더 76B] [IDList(가변)] [LinkInfo(가변)] [StringData(가변)] [ExtraData]

`IDList` 와 `LinkInfo` 는 **타깃만 가리킨다** — 타깃이 같으면 **Windows 가 만든 바이트를 그대로
써도 된다.** 바꿔야 하는 건 `StringData` 뿐(이름·상대경로·작업폴더·인자·아이콘).
그래서 **타깃이 같은 `.lnk` 를 하나 찾아** 앞부분을 복사하고 내 문자열을 뒤에 붙인다.
못 찾으면 아래 `LNK_PREFIX_HEX`(이 godot.exe 용으로 뽑아 둔 픽스처)로 떨어진다.

⚠️ 템플릿은 **타깃이 같은** .lnk 여야 한다(IDList 가 타깃별이다). 자동으로 찾는다.
⚠️ `StringData` 순서는 규격 고정이다: 이름 → 상대경로 → 작업폴더 → 인자 → 아이콘.
⚠️ 템플릿의 `LinkFlags` 중 **우리가 안 쓰는 비트는 지운다**(예: `0x4000 HasExpIcon`).
   안 지우면 "그런 블록이 있다"고 해 놓고 안 넣은 셈이라 파일이 자기모순이 된다.

## ⚠️ 바탕화면 아이콘 자리 (실측 2026-10-09)

`.lnk` 를 다시 쓰면 Explorer 가 **아이콘 자리를 다시 배정**할 수 있다 — 그러면 아이콘이
구석(예: `(224,1633)` = 3열 11행)으로 가서 **"바로가기가 없다"** 는 착각을 만든다.
그래서 **제자리 덮어쓰기**(`open(path,"wb")`)를 쓰고, **내용이 같으면 아예 안 쓴다.**
(`os.replace` 는 파일 신원을 바꿔 **무조건** 자리를 초기화한다.)
자리가 옮겨졌으면 형제 폴더의 도구로 되돌린다 — `desktop_icon_check.py --move-to-top "이름"`.
그 도구는 옮긴 뒤 `SHChangeNotify` 로 **셸백에 기록**한다(안 하면 다음 새로고침에 되돌아간다).
"""
import ctypes
import ntpath
import os
import shutil
import struct
import sys

from PIL import Image, ImageDraw, ImageFont

try:
    import pylnk3
except ImportError:
    sys.exit("pylnk3 가 없다. 설치: <python> -m pip install pylnk3")

# 프로젝트 루트 = 이 파일의 부모의 부모 (tools/ 안에 있다)
PROJ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT = os.path.join(PROJ, "fonts", "neodgm.ttf")
ICO = os.path.join(PROJ, "icon.ico")
DESK = os.path.join(os.path.expanduser("~"), "Desktop")
NAME = "언어의 조각 - 무한 병합"
DESC = "언어의 조각 : 무한 병합 — 자모 병합 랜덤 디펜스 (Godot 4.7)"

# godot 실행 파일 — PATH 우선, 없으면 winget 이 관리하는 심볼릭 링크.
#   ⚠️ 패키지 폴더(`...\WinGet\Packages\...`)를 직접 가리키지 마라. Godot 버전이 오르면
#      폴더 안 exe 이름이 바뀌어 바로가기가 깨진다. `Links\godot.exe` 는 winget 이 갱신해 준다.
GODOT = shutil.which("godot") or os.path.join(
    os.environ.get("LOCALAPPDATA", ""), "Microsoft", "WinGet", "Links", "godot.exe"
)

# 바탕화면 아이콘 자리를 다루는 진단 도구 — 게임 프로젝트가 아니라 그 **형제** 폴더에 있다.
ICON_TOOL = os.path.join(os.path.dirname(PROJ), "tools", "desktop_icon_check.py")

if not os.path.exists(GODOT):
    sys.exit("godot 실행 파일을 못 찾았다: %s" % GODOT)
if not os.path.isdir(DESK):
    sys.exit("바탕화면 폴더가 없다: %s" % DESK)


# ──────────────────────────────────────────────────────────────────────────
# .lnk 바이트 조립
# ──────────────────────────────────────────────────────────────────────────
HAS_IDLIST = 0x00000001
HAS_LINKINFO = 0x00000002
HAS_NAME = 0x00000004
HAS_RELPATH = 0x00000008
HAS_WORKDIR = 0x00000010
HAS_ARGS = 0x00000020
HAS_ICON = 0x00000040
IS_UNICODE = 0x00000080
SUPPORTED = 0x000000FF          # 우리가 실제로 데이터를 넣는 비트만

# 셸이 읽는 여덟 개 — 되읽어 확인할 때 쓴다
FLAG_NAMES = ("HasLinkTargetIDList", "HasLinkInfo", "HasRelativePath", "HasWorkingDir",
              "HasArguments", "HasIconLocation", "HasName", "IsUnicode")


def split_lnk(raw):
    """`(앞부분 = 헤더+IDList+LinkInfo, StringData 시작 오프셋, LinkFlags)` 로 가른다."""
    if len(raw) < 76:
        raise ValueError("너무 짧다: %d B" % len(raw))
    header_size, _clsid, flags = struct.unpack_from("<I16sI", raw, 0)
    if header_size != 0x4C:
        raise ValueError("HeaderSize 가 0x4C 가 아니다: 0x%X" % header_size)
    pos = 76
    if flags & HAS_IDLIST:
        # ⚠️ 이 크기에는 꼬리 TerminalID(2B)가 **포함**된다 — 2 를 더 더하지 마라.
        (idsize,) = struct.unpack_from("<H", raw, pos)
        pos += 2 + idsize
    if flags & HAS_LINKINFO:
        (lisize,) = struct.unpack_from("<I", raw, pos)
        pos += lisize
    return raw[:pos], pos, flags


def sized_string(s: str) -> bytes:
    """StringData 한 칸 = u16 **글자수**(바이트수 아님) + UTF-16LE."""
    return struct.pack("<H", len(s)) + s.encode("utf-16-le")


def build_lnk(prefix: bytes, description: str, relative_path: str,
              work_dir: str, arguments: str, icon: str) -> bytes:
    """템플릿 앞부분 + 내 StringData + 종료 블록."""
    head, _pos, flags = split_lnk(prefix)
    flags &= SUPPORTED
    out = bytearray(head)
    struct.pack_into("<I", out, 20, flags)      # LinkFlags 는 헤더 오프셋 20
    if flags & HAS_NAME:
        out += sized_string(description)
    if flags & HAS_RELPATH:
        out += sized_string(relative_path)
    if flags & HAS_WORKDIR:
        out += sized_string(work_dir)
    if flags & HAS_ARGS:
        out += sized_string(arguments)
    if flags & HAS_ICON:
        out += sized_string(icon)
    out += b"\x00\x00\x00\x00"                  # ExtraData 종료
    return bytes(out)


def path_in_prefix(prefix: bytes, path: str) -> bool:
    """⚠️ `LinkInfo.LocalBasePath` 는 **시스템 ANSI** 로 들어간다 — UTF-16 이 아니다.

    그래서 `path.encode('utf-16-le') in prefix` 로 검사하면 **항상 거짓**이 나온다.
    """
    for enc in ("mbcs", "cp1252", "utf-8"):
        try:
            if path.encode(enc) + b"\x00" in prefix:
                return True
        except (LookupError, UnicodeEncodeError):
            pass
    return False


# ──────────────────────────────────────────────────────────────────────────
# 템플릿 찾기
# ──────────────────────────────────────────────────────────────────────────
def search_roots():
    """바로가기가 사는 곳 — 바탕화면(사용자·공용)과 시작 메뉴(사용자·공용)."""
    appdata = os.environ.get("APPDATA", "")
    programdata = os.environ.get("ProgramData", "")
    return [
        DESK,
        os.path.join(os.environ.get("PUBLIC", r"C:\Users\Public"), "Desktop"),
        os.path.join(appdata, "Microsoft", "Windows", "Start Menu"),
        os.path.join(programdata, "Microsoft", "Windows", "Start Menu"),
    ]


def find_template():
    """**타깃이 같은**(같은 godot.exe 를 가리키는) `.lnk` 를 찾는다 — IDList 를 물려받아야 한다."""
    for root in search_roots():
        if not os.path.isdir(root):
            continue
        for dirpath, _dirs, files in os.walk(root):
            for fn in files:
                if not fn.lower().endswith(".lnk"):
                    continue
                p = os.path.join(dirpath, fn)
                try:
                    back = pylnk3.Lnk(p)
                except Exception:
                    continue
                li = getattr(back, "_link_info", None)
                lbp = getattr(li, "local_base_path", None) if li else None
                if lbp and os.path.normcase(lbp) == os.path.normcase(GODOT):
                    return p
    return None


# 번들 픽스처 — 위 템플릿을 못 찾을 때 쓰는 [헤더+IDList+LinkInfo] 804 B.
#   감독 PC 의 `볼링 코치.lnk`(타깃이 같은 godot.exe)에서 뽑았다.
#   ⚠️ **이 godot.exe 경로 전용**이다. 경로가 바뀌면 `path_in_prefix` 가 걸러 낸다.
LNK_PREFIX_HEX = (
    "4c0000000114020000000000c000000000000046ff000000200400007e1dc51d8f3bdd017e1dc51d8f3bdd017e1dc51d"
    "8f3bdd010000000000000000010000000000000000000000000000006a023a001f49471a0359723fa74489c55595fe6b"
    "30ee260001002600efbe10000000f4bfda378d03dc01abace742764edd016af0be4a7f4edd011400820074001c004346"
    "53461600310000000000025b3d49120041707044617461000000741a595e96dfd3488d671733bcee28bac5cdfadf9f67"
    "56418947c5c76bc0b67f400009000400efbe025b3d493b5d9a632e000000adca00000000020000000000000000000000"
    "0000000032b4290041007000700044006100740061000000420050003100000000003a5daf5c10004c6f63616c003c00"
    "09000400efbe025b3d493b5d9a632e000000c1ca0000000002000000000000000000000000000000dc64ba004c006f00"
    "630061006c00000014005c003100000000003a5db55c10004d4943524f537e310000440009000400efbe025b3d493b5d"
    "84632e000000c3ca0000000002000000000000000000000000000000629dd6004d006900630072006f0073006f006600"
    "7400000018005400310000000000105def03100057696e47657400003e0009000400efbe105deb033b5d84632e000000"
    "af9107000000170000000000000000000000000000008d6b0301570069006e0047006500740000001600500031000000"
    "0000325dbc5410004c696e6b73003c0009000400efbe105deb033b5d9a632e000000b091070000001800000000000000"
    "000000000000000008e711004c0069006e006b007300000014005c00320000000000235db2532004676f646f742e6578"
    "6500440009000400efbe235db253235db2532e00000064f7220000000900000000000c0000a000000000000082ca3000"
    "67006f0064006f0074002e006500780065000000180000006c0000001c000000010000001c0000002d00000000000000"
    "6b00000011000000030000001cedf46a1000000000433a5c55736572735c6d616b74755c417070446174615c4c6f6361"
    "6c5c4d6963726f736f66745c57696e4765745c4c696e6b735c676f646f742e6578650000"
)


# ──────────────────────────────────────────────────────────────────────────
# 아이콘
# ──────────────────────────────────────────────────────────────────────────
def build_icon() -> None:
    """icon.svg(128 기준)를 2배로 다시 그려 여섯 크기의 .ico 로 저장한다."""
    size = 256
    k = size / 128.0
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    def rr(x, y, w, h, r, fill=None, outline=None, width=0):
        d.rounded_rectangle(
            [x * k, y * k, (x + w) * k, (y + h) * k],
            radius=r * k,
            fill=fill,
            outline=outline,
            width=max(1, int(round(width * k))) if width else 0,
        )

    rr(0, 0, 128, 128, 24, fill=(0x13, 0x1B, 0x3A, 255))              # 배경
    rr(18, 18, 92, 92, 14, outline=(0x4F, 0xD3, 0xE0, 255), width=5)  # 시안 고리
    rr(34, 34, 60, 60, 10, outline=(0xF5, 0xD2, 0x4A, 255), width=4)  # 금색 고리

    font = ImageFont.truetype(FONT, int(46 * k))
    glyph = "ㄱ"
    bbox = d.textbbox((0, 0), glyph, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    # bbox 원점을 빼야 잉크 기준으로 정확히 가운데 온다 (글리프 여백 때문)
    d.text((size / 2.0 - tw / 2.0 - bbox[0], size / 2.0 - th / 2.0 - bbox[1]),
           glyph, font=font, fill=(0xFF, 0xFF, 0xFF, 255))

    img.save(ICO, format="ICO",
             sizes=[(256, 256), (128, 128), (64, 64), (48, 48), (32, 32), (16, 16)])
    print("ICON  %s  (%d bytes)" % (ICO, os.path.getsize(ICO)))


# ──────────────────────────────────────────────────────────────────────────
# 바로가기
# ──────────────────────────────────────────────────────────────────────────
def build_shortcut() -> str:
    lnk_path = os.path.join(DESK, NAME + ".lnk")

    tpl = find_template()
    if tpl:
        prefix = open(tpl, "rb").read()
        print("TEMPLATE %s" % tpl)
    else:
        prefix = bytes.fromhex(LNK_PREFIX_HEX)
        if not path_in_prefix(prefix, GODOT):
            sys.exit("타깃이 같은 템플릿 .lnk 를 못 찾았고, 번들 픽스처도 이 경로가 아니다:\n"
                     "  %s\n"
                     "→ 타깃이 같은 .lnk 를 바탕화면에 하나 두고 다시 실행하라." % GODOT)
        print("TEMPLATE (번들 픽스처 — 타깃이 같은 .lnk 를 못 찾았다)")

    data = build_lnk(
        prefix,
        description=DESC,
        relative_path=ntpath.relpath(GODOT, DESK),
        work_dir=PROJ,
        arguments='--path "%s"' % PROJ,
        icon=ICO,
    )

    # ⚠️ 지우거나 `os.replace` 로 갈아치우지 마라 — **파일 신원이 바뀌어** Explorer 가
    #    아이콘 자리를 버리고 빈 칸(보통 구석)에 새로 배정한다(실측: (672,5) → (224,1633)).
    #    같은 경로에 **제자리 덮어쓰기**(`open(wb)`)하면 자리가 남는다.
    old = open(lnk_path, "rb").read() if os.path.exists(lnk_path) else None
    if old == data:
        print("LNK   %s  (그대로 — 다시 쓰지 않는다)" % lnk_path)
        return lnk_path
    with open(lnk_path, "wb") as f:
        f.write(data)
    print("LNK   %s  (%d bytes)" % (lnk_path, len(data)))
    if old is not None:
        print("      ⚠️ 내용이 바뀌었다 — Explorer 가 아이콘 자리를 옮겼을 수 있다.")
        print("         되돌리려면:  python \"%s\" --move-to-top \"%s\"" % (ICON_TOOL, NAME))
    return lnk_path


def verify(lnk_path: str) -> int:
    """되읽어서 계약을 확인한다. 인자·작업폴더·아이콘 중 하나라도 어긋나면 실패."""
    back = pylnk3.Lnk(lnk_path)
    flags = back.link_flags
    bad = 0

    def ck(label, got, want):
        nonlocal bad
        ok = got == want
        if not ok:
            bad += 1
        print("  %-16s %s  %r" % (label, "OK  " if ok else "FAIL", got))

    def ckp(label, got, want):
        """경로 비교용 — ⚠️ **대소문자를 무시**해야 한다.

        `GODOT` 은 `shutil.which` 가 `PATHEXT` 로 만들어 `godot.EXE`(대문자)가 되는데,
        템플릿의 `LinkInfo` 에는 만들 당시의 `godot.exe`(소문자)가 박혀 있다.
        같은 파일인데 문자열이 달라 **정상이 빨개진다**(실측).
        """
        nonlocal bad
        ok = bool(got) and os.path.normcase(got) == os.path.normcase(want)
        if not ok:
            bad += 1
        print("  %-16s %s  %r" % (label, "OK  " if ok else "FAIL", got))

    ck("work_dir", back.work_dir, PROJ)
    ck("arguments", back.arguments, '--path "%s"' % PROJ)
    ck("icon", back.icon, ICO)
    ck("description", back.description, DESC)
    ckp("relative_path", back.relative_path, ntpath.relpath(GODOT, DESK))

    for flag in FLAG_NAMES:
        ok = bool(getattr(flags, flag, False))
        if not ok:
            bad += 1
        print("  %-16s %s" % (flag, "OK  " if ok else "FAIL"))

    # ⚠️ `file_flags == 0` 이면 셸이 타깃을 못 여는 원인이 된다(실측 5=액세스 거부).
    #    정상 .lnk 는 0x420 (ARCHIVE | NOT_CONTENT_INDEXED).
    ff = back.file_flags.bytes
    if ff == 0:
        bad += 1
    print("  %-16s %s  0x%08X" % ("file_flags", "OK  " if ff else "FAIL", ff))

    # LinkInfo 안에 타깃 절대 경로가 들어 있어야 한다
    lbp = getattr(back._link_info, "local_base_path", None) if back._link_info else None
    ckp("LinkInfo 경로", lbp, GODOT)

    # IDList 는 **템플릿 것을 그대로** 물려받는다. 개수 공식은 쓰지 마라 — 어긋난다
    # (실측: `C:\...\Links\godot.exe` 는 1+1+8=10 이 아니라 **7** 이다).
    ids = getattr(back, "shell_item_id_list", None)
    got_ids = len(ids.items) if ids is not None else -1
    if got_ids <= 0:
        bad += 1
    print("  %-16s %s  %d개" % ("IDList", "OK  " if got_ids > 0 else "FAIL", got_ids))

    print("VERIFY fails=%d" % bad)
    return bad


def launch_test(lnk_path: str) -> int:
    """더블클릭과 **같은 경로**(ShellExecute)로 실제로 열리는지 본다.

    반환값이 32 를 넘으면 셸이 타깃을 풀어 실행에 넘긴 것. 그 이하면 실패
    (2=파일 없음 · 3=경로 없음 · 5=액세스 거부 · 31=연결 프로그램 없음).
    ⚠️ 필드 대조만으로는 못 잡는다 — pylnk3 가 만든 .lnk 는 필드가 전부 정상인데도 5 였다.
    """
    shell32 = ctypes.windll.shell32
    shell32.ShellExecuteW.restype = ctypes.c_void_p
    r = shell32.ShellExecuteW(None, "open", lnk_path, None, None, 1)
    code = ctypes.cast(r, ctypes.c_void_p).value or 0
    ok = code > 32
    print("LAUNCH ShellExecuteW -> %d  %s" % (code, "OK (셸이 열었다)" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    build_icon()
    path = build_shortcut()
    print("검증(구조):")
    bad = verify(path)
    print("검증(실행):")
    bad += launch_test(path)
    sys.exit(1 if bad else 0)
