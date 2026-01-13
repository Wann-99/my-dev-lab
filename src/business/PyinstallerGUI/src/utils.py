import json
import os

HISTORY_FILE = "config_history.json"


def load_history():
    if not os.path.exists(HISTORY_FILE):
        return {"interpreters": [], "output_dirs": []}
    try:
        with open(HISTORY_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    except:
        return {"interpreters": [], "output_dirs": []}


def save_history(key, value, max_len=5):
    """
    保存历史记录
    key: 'interpreters' or 'output_dirs'
    value: 新的路径
    """
    if not value: return

    data = load_history()
    current_list = data.get(key, [])

    # 如果已存在，先删除，再插到最前面（LRU策略）
    if value in current_list:
        current_list.remove(value)

    current_list.insert(0, value)

    # 保持最大长度
    data[key] = current_list[:max_len]

    try:
        with open(HISTORY_FILE, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
    except Exception as e:
        print(f"保存历史失败: {e}")


def get_history_list(key):
    return load_history().get(key, [])