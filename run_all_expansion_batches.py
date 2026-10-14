import sys, os, time, subprocess, json
from pathlib import Path

sys.stdout.reconfigure(encoding='utf-8')

ROOT = Path(r"E:\project\word_card")
PROGRESS_FILE = ROOT / "expansion_progress.json"

def get_completed_batches():
    if PROGRESS_FILE.exists():
        with open(PROGRESS_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
            return set(int(k) for k in data.keys())
    return set()

def update_expansion_json():
    json_path = ROOT / "godot/assets/data/word_database_expansion_100.json"
    with open(json_path, "r", encoding="utf-8") as f:
        data = json.load(f)
    
    for word in data:
        icon_path = f"res://assets/words_symbol_32px/word_exp_{word}.png"
        data[word]["icon"] = icon_path
    
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print("Successfully updated godot/assets/data/word_database_expansion_100.json icon paths!")

def main():
    print("==================================================")
    print("Starting Automated 100-Word Expansion Generation")
    print("==================================================")
    
    for b_no in range(1, 26):
        completed = get_completed_batches()
        if b_no in completed:
            print(f"[Skip] Batch {b_no} already completed.")
            continue
        
        success = False
        for attempt in range(2):
            try:
                print(f"\n>>> Running Batch {b_no}/25 (Attempt {attempt+1})")
                cmd = ["python", str(ROOT / "run_expansion_batch.py"), str(b_no)]
                res = subprocess.run(cmd, check=True)
                success = True
                break
            except Exception as e:
                print(f"Error running batch {b_no}: {e}")
                time.sleep(5)
        
        if not success:
            print(f"Failed batch {b_no} after 2 attempts. Continuing to next...")
        time.sleep(3)
        
    print("\n==================================================")
    print("All batches processed! Updating database...")
    update_expansion_json()
    
    print("\nRunning Godot expansion tests...")
    test_cmd = ["godot", "--headless", "--path", "godot", "res://tests/test_word_expansion.gd"]
    res = subprocess.run(test_cmd, cwd=str(ROOT), capture_output=True, text=True, encoding='utf-8', errors='ignore')
    print("Test output:", res.stdout)
    if res.returncode == 0:
        print(">>> ALL 100 EXPANSION ASSETS & TESTS PASSED! <<<")
    else:
        print("Test error output:", res.stderr)

if __name__ == "__main__":
    main()
