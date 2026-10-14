import sys, os, time, subprocess, json
from pathlib import Path
from PIL import Image, ImageGrab
import cv2, numpy as np

sys.stdout.reconfigure(encoding='utf-8')

ROOT = Path(r"E:\project\word_card")
BATCHES_FILE = ROOT / "expansion_100_batches.json"
PROGRESS_FILE = ROOT / "expansion_progress.json"

# Keyout logic
def key_white_background(image: Image.Image) -> Image.Image:
    image = image.convert("RGBA")
    if image.getchannel("A").getextrema() == (255, 255):
        rgb = np.array(image.convert("RGB"))
        hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV)
        mask = np.where((hsv[:, :, 1] > 45) | (hsv[:, :, 2] < 115), 255, 0).astype(np.uint8)
        count, labels, stats, _ = cv2.connectedComponentsWithStats(mask)
        assert count > 1, "no foreground found"
        foreground = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
        mask = np.where(labels == foreground, 255, 0).astype(np.uint8)
        contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        mask.fill(0)
        cv2.drawContours(mask, contours, -1, 255, cv2.FILLED)
        mask = cv2.dilate(mask, np.ones((5, 5), np.uint8))
        image.putalpha(Image.fromarray(mask))
        return image
    pixels = image.load()
    seen = set()
    from collections import deque
    queue = deque(((0, 0), (image.width - 1, 0), (0, image.height - 1), (image.width - 1, image.height - 1)))
    while queue:
        x, y = queue.popleft()
        if (x, y) in seen:
            continue
        seen.add((x, y))
        r, g, b, _ = pixels[x, y]
        if min(r, g, b) < 232:
            continue
        pixels[x, y] = (255, 255, 255, 0)
        queue.extend((p for p in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)) if 0 <= p[0] < image.width and 0 <= p[1] < image.height))
    return image

def build_prompt(items):
    lines = [
        "한글 타워 디펜스 게임에 들어갈 픽셀아트 아이콘 4개를 2x2 격자(그리드 스프라이트 시트) 형태로 한 장에 균등하게 그려줘.\n",
        "[2x2 배치 구성 - 4개 아이콘 사이에 넉넉한 흰색 여백 유지]",
        f"1. [좌측 상단]: {items[0]['word']} ({items[0]['concept']})",
        f"2. [우측 상단]: {items[1]['word']} ({items[1]['concept']})",
        f"3. [좌측 하단]: {items[2]['word']} ({items[2]['concept']})",
        f"4. [우측 하단]: {items[3]['word']} ({items[3]['concept']})\n",
        "[스타일 및 필수 규칙]",
        "- 16-bit SNES 고전 레트로 픽셀아트 (선명한 도트 클러스터, 짙은 다크 브라운 외곽선)",
        "- 32x32px로 축소해도 형태가 뚜렷하게 인식되는 직관적인 심플 실루엣",
        "- 배경: 완전히 흰색 단색 배경 (각 아이콘 사이에 넓은 흰색 여백 유지)",
        "- 한글, 영문 글자, 숫자, 테두리 격자선, 카드 프레임, 워터마크 절대 없음",
        "- 4개의 심볼만 2x2 위치에 서로 겹치지 않게 단독으로 그려줘."
    ]
    return "\n".join(lines)

def send_to_gemini(prompt_text):
    ps1 = r"C:\Users\maktu\.gemini\config\skills\gemini-desktop\scripts\send_gemini.ps1"
    cmd = ["powershell", "-ExecutionPolicy", "Bypass", "-File", ps1, "-Prompt", prompt_text, "-WaitSeconds", "15"]
    res = subprocess.run(cmd, capture_output=True, text=True, encoding='utf-8', errors='ignore')
    return res.returncode == 0

def wait_for_completion(max_wait=35):
    start = time.time()
    while time.time() - start < max_wait:
        out = subprocess.check_output(['orca', 'computer', 'get-app-state', '--app', 'Gemini', '--no-screenshot', '--json'])
        data = json.loads(out)
        tree = data.get('result', {}).get('snapshot', {}).get('treeText', '')
        if "이미지를 만들고 있습니다" not in tree and ("단추 이미지 복사" in tree or "단추 원본 크기 이미지 다운로드" in tree):
            return True
        time.sleep(4)
    return True

def grab_latest_image(sheet_save_path):
    out = subprocess.check_output(['orca', 'computer', 'get-app-state', '--app', 'Gemini', '--restore-window', '--json'])
    data = json.loads(out)
    tree = data.get('result', {}).get('snapshot', {}).get('treeText', '')
    copy_index = None
    for line in tree.splitlines():
        if "단추 이미지 복사" in line:
            parts = line.strip().split()
            if parts[0].isdigit():
                copy_index = parts[0]
    if not copy_index:
        raise RuntimeError("Could not find '단추 이미지 복사' button index.")
    
    subprocess.run(['orca', 'computer', 'click', '--app', 'Gemini', '--element-index', copy_index, '--json'], capture_output=True)
    time.sleep(1.5)
    img = ImageGrab.grabclipboard()
    if img:
        img.save(sheet_save_path)
        return img
    raise RuntimeError("Failed to grab clipboard image.")

def process_and_save(sheet_path, items):
    raw_sheet = Image.open(sheet_path)
    W, H = raw_sheet.size
    mid_x, mid_y = W // 2, H // 2
    quads = [
        ((0, 0, mid_x, mid_y), items[0]["word"]),
        ((mid_x, 0, W, mid_y), items[1]["word"]),
        ((0, mid_y, mid_x, H), items[2]["word"]),
        ((mid_x, mid_y, W, H), items[3]["word"]),
    ]
    
    saved_files = []
    for box, word in quads:
        cropped = raw_sheet.crop(box)
        image = key_white_background(cropped)
        alpha = image.getchannel("A").point(lambda p: p if p >= 16 else 0)
        image.putalpha(alpha)
        bbox = alpha.getbbox()
        if not bbox:
            bbox = (0, 0, image.width, image.height)
        image = image.crop(bbox)
        
        pad = round(256 * 0.10)
        inner = 256 - 2 * pad
        scale = min(inner / image.width, inner / image.height)
        size = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
        image = image.resize(size, Image.Resampling.NEAREST)
        
        output = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
        output.paste(image, ((256 - size[0]) // 2, (256 - size[1]) // 2), image)
        output_32 = output.resize((32, 32), Image.Resampling.NEAREST)
        
        p256 = ROOT / f"assets/words_symbol_256px/word_exp_{word}_256px.png"
        p32 = ROOT / f"assets/words_symbol_32px/word_exp_{word}.png"
        pgodot = ROOT / f"godot/assets/words_symbol_32px/word_exp_{word}.png"
        
        for p in (p256, p32, pgodot):
            p.parent.mkdir(parents=True, exist_ok=True)
        
        output.save(p256, "PNG")
        output_32.save(p32, "PNG")
        output_32.save(pgodot, "PNG")
        saved_files.append(str(p32))
        print(f"  [OK] Saved {word} -> {p32.name}")
    return saved_files

def run_batch(batch_no: int):
    with open(BATCHES_FILE, "r", encoding="utf-8") as f:
        batches = json.load(f)
    b = next(x for x in batches if x["batch_no"] == batch_no)
    items = b["items"]
    words_str = ", ".join([x["word"] for x in items])
    print(f"\n==========================================")
    print(f"Starting Batch {batch_no}/25: [{words_str}]")
    print(f"==========================================")
    
    prompt_text = build_prompt(items)
    print("Sending prompt to Gemini...")
    send_to_gemini(prompt_text)
    
    print("Waiting for generation to finish...")
    wait_for_completion()
    
    sheet_path = ROOT / f"main/generated_word_symbols/sheet_exp_batch_{batch_no:02d}.png"
    sheet_path.parent.mkdir(parents=True, exist_ok=True)
    print("Grabbing image from Gemini...")
    grab_latest_image(sheet_path)
    
    print("Processing and resizing to 256px / 32px...")
    saved = process_and_save(sheet_path, items)
    
    # Update progress
    progress = {}
    if PROGRESS_FILE.exists():
        with open(PROGRESS_FILE, "r", encoding="utf-8") as f:
            progress = json.load(f)
    progress[str(batch_no)] = [x["word"] for x in items]
    with open(PROGRESS_FILE, "w", encoding="utf-8") as f:
        json.dump(progress, f, ensure_ascii=False, indent=2)
    print(f"Batch {batch_no} completed successfully!")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        run_batch(int(sys.argv[1]))
    else:
        print("Usage: python run_expansion_batch.py <batch_no>")
