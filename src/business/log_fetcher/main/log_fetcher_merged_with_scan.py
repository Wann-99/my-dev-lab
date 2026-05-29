"""
远程日志抓取工具 v2.0
修复：扫描弹窗销毁后回调访问已销毁控件的崩溃问题
优化：UI 全面重设计，工业终端风格
"""

import os
import sys
import re
import json
import threading
import subprocess
import socket
import ipaddress
from datetime import datetime
import time

try:
    import customtkinter as ctk
    from tkcalendar import Calendar
except ImportError:
    print("Error: Required libraries are missing.")
    print("Please install them using: pip install customtkinter tkcalendar")
    sys.exit(1)

from tkinter import filedialog, messagebox

# ===================== 主题配置 =====================
ctk.set_appearance_mode('Dark')
ctk.set_default_color_theme('blue')

CONFIG_FILE = 'log_fetcher_config.json'

# 调色盘
COLORS = {
    'bg_deep':      '#0D1117',
    'bg_card':      '#161B22',
    'bg_card2':     '#1C2330',
    'bg_input':     '#0D1117',
    'border':       '#30363D',
    'accent':       '#238636',
    'accent_hover': '#2EA043',
    'accent2':      '#1F6FEB',
    'accent2_hov':  '#388BFD',
    'danger':       '#B91C1C',
    'danger_hover': '#DC2626',
    'warn':         '#D97706',
    'text_primary': '#E6EDF3',
    'text_muted':   '#8B949E',
    'text_green':   '#3FB950',
    'text_red':     '#F85149',
    'text_yellow':  '#D29922',
    'console_bg':   '#010409',
    'console_fg':   '#00FF41',
}


# ===================== 工具函数 =====================

def _no_window_kwargs():
    """
    返回 subprocess 调用所需的额外参数，用于在 Windows 打包环境下
    完全隐藏命令行弹窗。非 Windows 平台返回空字典。
    """
    if sys.platform != 'win32':
        return {}
    si = subprocess.STARTUPINFO()
    si.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    si.wShowWindow = subprocess.SW_HIDE
    return {
        'startupinfo': si,
        'creationflags': subprocess.CREATE_NO_WINDOW,
    }


def get_all_local_ips():
    """
    获取本机所有非回环 IPv4 地址。
    使用多种方法取并集，确保 Windows 多网卡环境下不遗漏。
    """
    ips = set()

    # 方法1：getaddrinfo（依赖 hostname，可能漏掉部分网卡）
    try:
        hostname = socket.gethostname()
        for info in socket.getaddrinfo(hostname, None, socket.AF_INET, socket.SOCK_STREAM):
            ip = info[4][0]
            if not ip.startswith('127.') and not ip.startswith('0.'):
                ips.add(ip)
    except Exception:
        pass

    # 方法2：对多个外部地址 UDP connect，获取出口 IP（覆盖不同路由表项）
    for target in [('8.8.8.8', 80), ('1.1.1.1', 80), ('192.168.0.1', 80),
                   ('10.0.0.1', 80), ('172.16.0.1', 80)]:
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.settimeout(0.3)
            s.connect(target)
            ip = s.getsockname()[0]
            s.close()
            if not ip.startswith('127.') and not ip.startswith('0.'):
                ips.add(ip)
        except Exception:
            pass

    # 方法3：Windows 专属 —— 解析 ipconfig 输出，最全面
    if sys.platform == 'win32':
        try:
            out = subprocess.check_output(
                ['ipconfig'], encoding='gbk', errors='ignore', timeout=3,
                **_no_window_kwargs())
            for line in out.splitlines():
                line = line.strip()
                if 'IPv4' in line or ('Address' in line and ':' in line):
                    parts = line.split(':')
                    if len(parts) >= 2:
                        candidate = parts[-1].strip().rstrip('(Preferred)').strip()
                        segs = candidate.split('.')
                        if (len(segs) == 4
                                and all(s.isdigit() and 0 <= int(s) <= 255
                                        for s in segs)
                                and not candidate.startswith('127.')
                                and not candidate.startswith('169.254.')):
                            ips.add(candidate)
        except Exception:
            pass
    else:
        # Linux/macOS：解析 ip addr 或 ifconfig
        for cmd in [['ip', '-4', 'addr'], ['ifconfig']]:
            try:
                out = subprocess.check_output(
                    cmd, encoding='utf-8', errors='ignore', timeout=3,
                    stderr=subprocess.DEVNULL)
                for m in re.finditer(r'inet\s+(\d+\.\d+\.\d+\.\d+)', out):
                    ip = m.group(1)
                    if not ip.startswith('127.') and not ip.startswith('169.254.'):
                        ips.add(ip)
                break
            except Exception:
                continue

    if not ips:
        ips.add('192.168.1.1')

    return list(ips)


# 缓存本机 IP 集合，扫描时排除
_LOCAL_IPS: set = set()

def _refresh_local_ips():
    """刷新本机 IP 缓存（每次打开扫描弹窗时调用）"""
    global _LOCAL_IPS
    _LOCAL_IPS = set(get_all_local_ips())

_refresh_local_ips()


def ip_to_network(ip_str, prefix=24):
    try:
        net = ipaddress.IPv4Network(f'{ip_str}/{prefix}', strict=False)
        return str(net)
    except Exception:
        return f'{ip_str}/{prefix}'


# 常见设备端口，按命中率排序（工控/嵌入式优先）
_PROBE_PORTS = [23, 22, 21, 80, 502, 8080, 443, 5900]

# TCP 超时（单次连接）
_TCP_TIMEOUT = 0.8


def tcp_probe(ip, port, timeout=None):
    """
    串行 TCP 端口探测（修正版）。
    直接在调用线程内执行，无竞态问题。
    返回 (成功, 端口号)。
    """
    if timeout is None:
        timeout = _TCP_TIMEOUT
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        err = sock.connect_ex((ip, port))
        sock.close()
        return err == 0, port
    except Exception:
        return False, port


def _ping_once(ip, timeout_ms=800):
    """执行一次 ping，返回 True/False。打包后不弹 cmd 窗口。"""
    try:
        if sys.platform == 'win32':
            cmd = ['ping', '-n', '1', '-w', str(timeout_ms), ip]
        else:
            cmd = ['ping', '-c', '1', '-W', '1', ip]
        r = subprocess.run(cmd,
                           stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL,
                           timeout=2,
                           **_no_window_kwargs())
        return r.returncode == 0
    except Exception:
        return False


def probe_host(ip, stop_event=None):
    """
    两阶段探测，确保结果可信：
      阶段1（快速）：并发 TCP 探测所有端口，任一端口 connect_ex==0 即视为候选。
      阶段2（验证）：对候选 IP 做第二次独立 TCP 连接确认（同一端口再试一次），
                     或 ping 兜底确认。双重命中才最终认定为在线。
    这样可过滤 socket 资源竞争导致的假阳性。
    """
    if stop_event and stop_event.is_set():
        return False, None

    # --- 阶段1：并发 TCP，收集所有命中端口 ---
    hit_ports = []
    hit_lock = threading.Lock()
    done_evt = threading.Event()

    def _worker(port):
        if done_evt.is_set():
            return
        ok, p = tcp_probe(ip, port)
        if ok:
            with hit_lock:
                hit_ports.append(p)
            done_evt.set()          # 通知其他线程可以提前退出

    workers = [threading.Thread(target=_worker, args=(p,), daemon=True)
               for p in _PROBE_PORTS]
    for w in workers:
        w.start()
    # 等待第一个命中，或全部超时（最长 _TCP_TIMEOUT + 调度余量）
    done_evt.wait(timeout=_TCP_TIMEOUT + 0.3)
    # 等所有线程自然结束（它们都是短暂的，最多再等一个超时周期）
    for w in workers:
        w.join(timeout=_TCP_TIMEOUT + 0.5)

    if stop_event and stop_event.is_set():
        return False, None

    if not hit_ports:
        # TCP 全失败：ping 兜底（也只做一次，不反复重试）
        if _ping_once(ip):
            return True, 'icmp'
        return False, None

    # --- 阶段2：对命中端口做独立二次验证 ---
    confirm_port = hit_ports[0]
    ok2, _ = tcp_probe(ip, confirm_port, timeout=_TCP_TIMEOUT)
    if ok2:
        return True, confirm_port

    # 二次 TCP 失败：用 ping 作最终裁决
    if _ping_once(ip):
        return True, f'icmp(tcp:{confirm_port} unstable)'

    # 两次都不稳定，判定为误报
    return False, None


def scan_network(network_cidr, callback=None, on_done=None,
                 stop_event=None, exclude_ips=None):
    """
    扫描指定网段。
    callback(ip, port_info)  — 每发现一台真实在线设备调用一次。
    exclude_ips              — 需要排除的 IP 集合（默认排除本机）。
    """
    if exclude_ips is None:
        exclude_ips = _LOCAL_IPS

    try:
        net = ipaddress.IPv4Network(network_cidr, strict=False)
        hosts = [str(h) for h in net.hosts() if str(h) not in exclude_ips]
    except Exception:
        if on_done:
            on_done([])
        return []

    found = []
    found_lock = threading.Lock()
    # 并发槽：控制同时进行两阶段探测的 IP 数量
    # 每个 probe_host 内部再开 len(_PROBE_PORTS) 个线程，所以槽不宜太大
    slot = threading.Semaphore(32)

    def check_one(ip_str):
        with slot:
            if stop_event and stop_event.is_set():
                return
            alive, port_info = probe_host(ip_str, stop_event=stop_event)
            if alive:
                if stop_event and stop_event.is_set():
                    return
                with found_lock:
                    found.append(ip_str)
                if callback:
                    callback(ip_str, port_info)

    threads = []
    for ip_str in hosts:
        if stop_event and stop_event.is_set():
            break
        t = threading.Thread(target=check_one, args=(ip_str,), daemon=True)
        t.start()
        threads.append(t)

    # 可中断的 join
    for t in threads:
        while t.is_alive():
            if stop_event and stop_event.is_set():
                if on_done:
                    on_done(found)
                return found
            t.join(timeout=0.2)

    if on_done:
        on_done(found)
    return found


def parse_date(date_str):
    return datetime.strptime(date_str, '%Y-%m-%d').date()


def connect_telnet(ip, user, password, port=23, timeout=10):
    print(f"\nConnecting to {ip}:{port} via Telnet...")
    import telnetlib
    tn = telnetlib.Telnet(ip, port, timeout)
    tn.read_until(b'login: ', timeout=5)
    tn.write(user.encode('ascii') + b'\n')
    if password:
        tn.read_until(b'Password: ', timeout=5)
        tn.write(password.encode('ascii') + b'\n')
    tn.read_until(b'# ', timeout=5)
    print("Telnet login successful.")
    return tn


def _date_in_range(file_date, start_date, end_date):
    """
    判断 file_date 是否在 [start_date, end_date] 范围内。
    start_date / end_date 为 None 时表示无限制。
    """
    if start_date and file_date < start_date:
        return False
    if end_date and file_date > end_date:
        return False
    return True


def _apply_latest_only(file_date_pairs):
    """
    file_date_pairs: [(filename, date), ...]
    返回只保留最新日期的文件列表。
    """
    if not file_date_pairs:
        return []
    latest = max(d for _, d in file_date_pairs)
    return [f for f, d in file_date_pairs if d == latest]


def run_fetch_core(ip, start_date_str, end_date_str, method, local_dir, keyword,
                   user, password, remote_dir, latest_only=False,
                   gui_log_callback=None, stop_event=None):
    """
    核心抓取逻辑。
    start_date_str / end_date_str 为空字符串时表示不限制（开区间）。
    latest_only=True 时忽略日期范围，只抓文件中日期最新的一天。
    """
    original_stdout = sys.stdout
    if gui_log_callback:
        class CallbackWriter:
            def __init__(self, cb):
                self.callback = cb
            def write(self, text):
                if text:
                    self.callback(text)
            def flush(self):
                pass
        sys.stdout = CallbackWriter(gui_log_callback)

    # 解析日期（空字符串 → None，即不限制）
    start_date = None
    end_date = None
    if not latest_only:
        if start_date_str:
            try:
                start_date = parse_date(start_date_str)
            except ValueError:
                print("Error: Invalid start date format. Use YYYY-MM-DD.")
                sys.stdout = original_stdout
                return 1
        if end_date_str:
            try:
                end_date = parse_date(end_date_str)
            except ValueError:
                print("Error: Invalid end date format. Use YYYY-MM-DD.")
                sys.stdout = original_stdout
                return 1
        if start_date and end_date and start_date > end_date:
            print("Error: Start date must be before or equal to end date.")
            sys.stdout = original_stdout
            return 1

    # 打印过滤模式说明
    if latest_only:
        print("Mode: LATEST DAY ONLY — will fetch files from the most recent date found.")
    elif start_date or end_date:
        s = start_date_str or '(no limit)'
        e = end_date_str or '(no limit)'
        print(f"Mode: DATE RANGE  {s} → {e}")
    else:
        print("Mode: ALL FILES — no date filter applied.")

    os.makedirs(local_dir, exist_ok=True)

    # ---- 内部：扫描文件列表，提取候选 ----
    def _collect_candidates(raw_files):
        """
        raw_files: 文件名列表（basename）。
        返回 (matched_files, no_date_files)：
          - matched_files: 在日期范围内的文件名列表
          - no_date_files: 无法解析日期、但通过 keyword 过滤的文件名列表
        """
        dated = []       # [(basename, date)]
        no_date = []     # [basename]  — 无日期但通过 keyword

        for f in raw_files:
            basename = os.path.basename(f)
            if keyword and keyword not in basename:
                continue
            match = re.search(r'(\d{4}-\d{2}-\d{2})', basename)
            if match:
                try:
                    fd = parse_date(match.group(1))
                    dated.append((basename, fd))
                except ValueError:
                    no_date.append(basename)
            else:
                # 无日期文件：latest_only 模式下忽略，其余模式全收
                if not latest_only and not start_date and not end_date:
                    no_date.append(basename)

        if latest_only:
            return _apply_latest_only(dated), []
        else:
            in_range = [f for f, d in dated if _date_in_range(d, start_date, end_date)]
            return in_range, no_date

    matched_files = []

    # ---- FTP ----
    if method == 'ftp':
        try:
            import ftplib
            print(f"\nAttempting FTP connection to {ip} as user '{user}'...")
            ftp = ftplib.FTP(ip, timeout=10)
            ftp.login(user=user, passwd=password)
            print("FTP login successful.")
            ftp.cwd(remote_dir)
            files = ftp.nlst()

            if stop_event and stop_event.is_set():
                ftp.quit()
                sys.stdout = original_stdout
                return -1

            dated_matches, no_date_matches = _collect_candidates(files)
            matched_files = dated_matches + no_date_matches

            if not matched_files:
                print("No matching log files found.")
                ftp.quit()
                sys.stdout = original_stdout
                return 0

            print(f"Found {len(matched_files)} file(s) to download.")
            for idx, f in enumerate(sorted(matched_files)):
                if stop_event and stop_event.is_set():
                    print("\n[任务已取消]")
                    ftp.quit()
                    sys.stdout = original_stdout
                    return -1
                local_path = os.path.join(local_dir, f)
                print(f"[{idx+1}/{len(matched_files)}] Downloading {f} ...", end=" ", flush=True)
                with open(local_path, 'wb') as lf:
                    ftp.retrbinary(f'RETR {f}', lf.write)
                print("Done.")

            ftp.quit()
            print("\nAll files downloaded successfully via FTP.")
            sys.stdout = original_stdout
            return 0

        except Exception as e:
            print(f"FTP failed: {e}")
            sys.stdout = original_stdout
            return 1

    # ---- Telnet ----
    elif method == 'telnet':
        try:
            tn = connect_telnet(ip, user, password)
            tn.write(b'\n')
            time.sleep(1)
            prompt_output = tn.read_very_eager()

            print(f"Reading directory: {remote_dir}")
            tn.write(f'ls -1 {remote_dir}\n'.encode('ascii'))
            time.sleep(1)
            output = tn.read_very_eager().decode('ascii', errors='ignore')
            lines = output.replace('\r', '').split('\n')
            files = [line.strip() for line in lines if line.strip() and not line.startswith('ls')]

            dated_matches, no_date_matches = _collect_candidates(files)
            matched_files = dated_matches + no_date_matches

            if not matched_files:
                print(f"No log files found between {start_date_str} and {end_date_str}.")
                tn.write(b'exit\n')
                tn.close()
                sys.stdout = original_stdout
                return 0

            print(f"Found {len(matched_files)} files matching the date range.")
            print("WARNING: Telnet transfer is slow and may have encoding issues.")

            for idx, f in enumerate(sorted(matched_files)):
                if stop_event and stop_event.is_set():
                    print("\n[任务已取消]")
                    tn.write(b'exit\n')
                    tn.close()
                    sys.stdout = original_stdout
                    return -1
                remote_path = f'{remote_dir}/{f}'
                local_path = os.path.join(local_dir, f)
                print(f"[{idx+1}/{len(matched_files)}] Downloading {f} ...", end=" ", flush=True)

                start_marker = '---START_FILE_DUMP---'
                end_marker = '---END_FILE_DUMP---'
                tn.read_very_eager()
                tn.write(f"echo '---START_''FILE_DUMP---'; cat {remote_path}; echo '---END_''FILE_DUMP---'\n".encode('ascii'))
                time.sleep(0.5)
                file_content = tn.read_until(end_marker.encode('ascii'), timeout=60)

                try:
                    content_str = file_content.decode('utf-8', errors='ignore')
                    start_idx = content_str.find(start_marker)
                    if start_idx != -1:
                        content_start = start_idx + len(start_marker)
                        if content_str[content_start:content_start+2] == '\r\n':
                            content_start += 2
                        elif content_str[content_start] == '\n':
                            content_start += 1
                        end_idx = content_str.rfind(end_marker)
                        if end_idx != -1 and end_idx > content_start:
                            clean_content = content_str[content_start:end_idx].rstrip('\r\n')
                            with open(local_path, 'w', encoding='utf-8') as lf:
                                lf.write(clean_content)
                            print("Done.")
                        else:
                            print("Failed (end marker not found).")
                    else:
                        print("Failed (start marker not found).")
                        with open(local_path, 'w', encoding='utf-8') as lf:
                            lf.write(content_str)
                except Exception as e:
                    print(f"Error saving file: {e}")

            tn.write(b'exit\n')
            tn.close()
            print("\nTelnet download process completed.")
            sys.stdout = original_stdout
            return 0

        except Exception as e:
            print(f"\nTelnet Error: {e}")
            sys.stdout = original_stdout
            return 1

    sys.stdout = original_stdout
    return 1


# ===================== 自定义组件 =====================

class SectionCard(ctk.CTkFrame):
    """带标题栏的卡片容器"""
    def __init__(self, master, title, icon="", **kwargs):
        super().__init__(master, fg_color=COLORS['bg_card'],
                         corner_radius=8, border_width=1,
                         border_color=COLORS['border'], **kwargs)
        # 标题行
        header = ctk.CTkFrame(self, fg_color=COLORS['bg_card2'],
                              corner_radius=0, height=40)
        header.pack(fill='x', padx=0, pady=0)
        header.pack_propagate(False)

        ctk.CTkLabel(header,
                     text=f"{icon}  {title}" if icon else title,
                     font=ctk.CTkFont(family='Consolas', size=12, weight='bold'),
                     text_color=COLORS['text_muted']).pack(side='left', padx=16)

        # 内容区
        self.body = ctk.CTkFrame(self, fg_color='transparent')
        self.body.pack(fill='both', expand=True, padx=16, pady=14)


class FieldLabel(ctk.CTkLabel):
    def __init__(self, master, text, **kwargs):
        super().__init__(master, text=text,
                         font=ctk.CTkFont(family='Consolas', size=11),
                         text_color=COLORS['text_muted'], **kwargs)


class StyledEntry(ctk.CTkEntry):
    def __init__(self, master, **kwargs):
        kwargs.setdefault('fg_color', COLORS['bg_input'])
        kwargs.setdefault('border_color', COLORS['border'])
        kwargs.setdefault('text_color', COLORS['text_primary'])
        kwargs.setdefault('height', 36)
        kwargs.setdefault('font', ctk.CTkFont(family='Consolas', size=13))
        super().__init__(master, **kwargs)


class StyledButton(ctk.CTkButton):
    def __init__(self, master, variant='primary', **kwargs):
        schemes = {
            'primary': (COLORS['accent'], COLORS['accent_hover']),
            'secondary': (COLORS['bg_card2'], COLORS['border']),
            'danger': (COLORS['danger'], COLORS['danger_hover']),
            'info': (COLORS['accent2'], COLORS['accent2_hov']),
            'muted': ('#21262D', '#30363D'),
        }
        fg, hov = schemes.get(variant, schemes['primary'])
        kwargs.setdefault('fg_color', fg)
        kwargs.setdefault('hover_color', hov)
        kwargs.setdefault('text_color', COLORS['text_primary'])
        kwargs.setdefault('corner_radius', 6)
        kwargs.setdefault('height', 36)
        kwargs.setdefault('font', ctk.CTkFont(family='Consolas', size=12, weight='bold'))
        super().__init__(master, **kwargs)


class IPEntry(ctk.CTkFrame):
    """IP 地址四段输入，支持自动跳段和历史下拉"""
    def __init__(self, master, history=None, on_history_select=None, **kwargs):
        super().__init__(master, fg_color='transparent', **kwargs)
        self.history = history or []
        self.on_history_select = on_history_select
        self.entries = []
        self.vars = [ctk.StringVar() for _ in range(4)]
        self._hist_menu = None   # 当前弹出的历史菜单引用

        row_frame = ctk.CTkFrame(self, fg_color='transparent')
        row_frame.pack(fill='x')

        # 四段输入框
        for i in range(4):
            self.vars[i].trace_add('write', lambda *a, idx=i: self._on_change(idx))
            e = ctk.CTkEntry(row_frame, textvariable=self.vars[i],
                             width=52, height=36, justify='center',
                             fg_color=COLORS['bg_input'],
                             border_color=COLORS['border'],
                             text_color=COLORS['text_primary'],
                             font=ctk.CTkFont(family='Consolas', size=13))
            e.grid(row=0, column=i * 2, padx=1)
            e.bind('<KeyRelease>', lambda ev, idx=i: self._on_key_release(ev, idx))
            e.bind('<BackSpace>', lambda ev, idx=i: self._on_backspace(ev, idx))
            e.bind('<Left>', lambda ev, idx=i: self._on_left(ev, idx))
            e.bind('<Right>', lambda ev, idx=i: self._on_right(ev, idx))
            e.bind('<FocusIn>', lambda ev, idx=i: self._on_focus_in(ev, idx))
            self.entries.append(e)
            if i < 3:
                ctk.CTkLabel(row_frame, text='.',
                             font=ctk.CTkFont(size=16, weight='bold'),
                             text_color=COLORS['text_muted']).grid(row=0, column=i*2+1)

        # 历史下拉按钮
        if self.history:
            StyledButton(row_frame, text='▾', width=30, height=36, variant='muted',
                         command=self._show_history).grid(row=0, column=8, padx=(6, 0))

        # 验证提示
        self.status = ctk.CTkLabel(self, text='',
                                   font=ctk.CTkFont(family='Consolas', size=10),
                                   text_color=COLORS['text_muted'])
        self.status.pack(anchor='w', pady=(3, 0))

    # ---- 内部事件 ----
    def _on_change(self, idx):
        val = self.vars[idx].get()
        cleaned = ''.join(filter(str.isdigit, val))
        if cleaned != val:
            self.vars[idx].set(cleaned)
            return
        if cleaned:
            if len(cleaned) > 3:
                self.vars[idx].set(cleaned[:3])
            elif int(cleaned) > 255:
                self.vars[idx].set('255')
        self._validate()

    def _on_key_release(self, event, idx):
        val = self.vars[idx].get()
        if event.char == '.':
            self.vars[idx].set(val.replace('.', ''))
            if idx < 3:
                self.entries[idx+1].focus()
                self.entries[idx+1].icursor('end')
            return 'break'
        if len(val) >= 3 and idx < 3 and event.keysym not in ('BackSpace', 'Left', 'Right', 'Tab'):
            self.entries[idx+1].focus()
            self.entries[idx+1].select_range(0, 'end')

    def _on_backspace(self, event, idx):
        if not self.vars[idx].get() and idx > 0:
            self.entries[idx-1].focus()
            self.entries[idx-1].icursor('end')

    def _on_left(self, event, idx):
        if self.entries[idx].index('insert') == 0 and idx > 0:
            self.entries[idx-1].focus()
            self.entries[idx-1].icursor('end')

    def _on_right(self, event, idx):
        if self.entries[idx].index('insert') == len(self.vars[idx].get()) and idx < 3:
            self.entries[idx+1].focus()
            self.entries[idx+1].icursor(0)

    def _on_focus_in(self, event, idx):
        self.entries[idx].select_range(0, 'end')

    def _validate(self):
        ip = self.get()
        parts = ip.split('.')
        if len(parts) == 4 and all(p.isdigit() and 0 <= int(p) <= 255 for p in parts):
            self.status.configure(text='✓ valid', text_color=COLORS['text_green'])
            return True
        elif any(p for p in parts):
            self.status.configure(text='✗ invalid IP', text_color=COLORS['text_red'])
            return False
        else:
            self.status.configure(text='')
            return False

    def _show_history(self):
        # 若菜单已存在则关闭（切换行为）
        if self._hist_menu is not None:
            try:
                self._hist_menu.destroy()
            except Exception:
                pass
            self._hist_menu = None
            return

        if not self.history:
            return

        menu = ctk.CTkToplevel(self)
        self._hist_menu = menu
        menu.title('')
        menu.overrideredirect(True)
        menu.attributes('-topmost', True)
        self.update_idletasks()
        x = self.winfo_rootx()
        y = self.winfo_rooty() + self.winfo_height() + 2
        menu.geometry(f'+{x}+{y}')

        frame = ctk.CTkFrame(menu, fg_color=COLORS['bg_card2'],
                             border_width=1, border_color=COLORS['border'], corner_radius=6)
        frame.pack(fill='both', expand=True)

        for ip in self.history:
            ctk.CTkButton(frame, text=ip, anchor='w',
                          fg_color='transparent', hover_color=COLORS['bg_deep'],
                          text_color=COLORS['text_primary'],
                          font=ctk.CTkFont(family='Consolas', size=12),
                          command=lambda i=ip: self._select_hist(i)).pack(
                              fill='x', padx=4, pady=2)

        def _on_focus_out(event):
            # 延迟一帧，避免点击按钮时误判
            self.after(50, self._close_hist_menu)

        menu.bind('<FocusOut>', _on_focus_out)
        # 点击菜单外部的任意窗口也关闭
        menu.bind('<Button-1>', lambda e: None)  # 菜单内部点击不关闭（由按钮 command 处理）
        self.after(80, lambda: menu.focus_force() if self._hist_menu else None)

    def _close_hist_menu(self):
        if self._hist_menu is not None:
            try:
                self._hist_menu.destroy()
            except Exception:
                pass
            self._hist_menu = None

    def _select_hist(self, ip):
        self._close_hist_menu()
        self.set(ip)
        if self.on_history_select:
            self.on_history_select(ip)

    def get(self):
        return '.'.join(v.get() for v in self.vars)

    def set(self, ip_str):
        parts = ip_str.split('.')
        for i in range(4):
            self.vars[i].set(parts[i] if i < len(parts) else '')
        self._validate()

    def is_valid(self):
        return self._validate()


class DatePicker(ctk.CTkFrame):
    """
    日期选择器，带日历弹窗。
    日期可以为空（表示不限制）；空时 is_valid() 返回 True，get_date() 返回 None。
    """
    def __init__(self, master, label_text, variable, placeholder='(no limit)', **kwargs):
        super().__init__(master, fg_color='transparent', **kwargs)
        self.variable = variable
        self._popup = None
        self._placeholder = placeholder

        FieldLabel(self, text=label_text).pack(anchor='w', pady=(0, 4))

        row = ctk.CTkFrame(self, fg_color='transparent')
        row.pack(fill='x')
        row.grid_columnconfigure(0, weight=1)

        self._entry = StyledEntry(row, textvariable=variable,
                                  placeholder_text=placeholder)
        self._entry.grid(row=0, column=0, sticky='ew')

        # 清空按钮
        self._clear_btn = StyledButton(row, text='✕', width=30, height=36,
                                       variant='muted',
                                       font=ctk.CTkFont(family='Consolas', size=12),
                                       command=self._clear)
        self._clear_btn.grid(row=0, column=1, padx=(4, 0))

        # 日历按钮
        StyledButton(row, text='📅', width=36, height=36, variant='muted',
                     command=self._open_cal).grid(row=0, column=2, padx=(4, 0))

        self.status = ctk.CTkLabel(self, text='',
                                   font=ctk.CTkFont(family='Consolas', size=10),
                                   text_color=COLORS['text_muted'])
        self.status.pack(anchor='w', pady=(3, 0))

        self.variable.trace_add('write', lambda *a: self._on_var_change())
        self._on_var_change()

    def _on_var_change(self):
        val = self.variable.get()
        # 隐藏/显示清空按钮
        if val:
            self._clear_btn.grid()
        else:
            self._clear_btn.grid_remove()
        self._validate()

    def _clear(self):
        self.variable.set('')

    def _validate(self):
        val = self.variable.get()
        if not val:
            # 空 = 不限制，合法
            self.status.configure(text='∅ no limit', text_color=COLORS['text_muted'])
            return True
        try:
            datetime.strptime(val, '%Y-%m-%d')
            self.status.configure(text='✓ valid', text_color=COLORS['text_green'])
            return True
        except ValueError:
            self.status.configure(text='✗ use YYYY-MM-DD', text_color=COLORS['text_red'])
            return False

    def get_date(self):
        """返回 date 对象，或 None（空/不限制）。"""
        val = self.variable.get().strip()
        if not val:
            return None
        try:
            return parse_date(val)
        except ValueError:
            return None

    def is_valid(self):
        return self._validate()

    def _open_cal(self):
        if self._popup and self._popup.winfo_exists():
            self._popup.lift()
            return
        top = ctk.CTkToplevel(self)
        self._popup = top
        top.title('Select Date')
        top.resizable(False, False)
        top.transient(self.winfo_toplevel())

        x = self.winfo_rootx()
        y = self.winfo_rooty() + self.winfo_height() + 6
        top.geometry(f'+{x}+{y}')

        con = ctk.CTkFrame(top, fg_color=COLORS['bg_card'])
        con.pack(padx=12, pady=12)

        cal = Calendar(con, selectmode='day', date_pattern='y-mm-dd',
                       font='Consolas 11', background=COLORS['bg_deep'],
                       foreground=COLORS['text_primary'],
                       headersbackground=COLORS['accent2'],
                       headersforeground='white',
                       selectbackground=COLORS['accent'],
                       normalbackground=COLORS['bg_card2'],
                       weekendbackground=COLORS['bg_card2'],
                       othermonthbackground=COLORS['bg_deep'],
                       othermonthwebackground=COLORS['bg_deep'])
        cal.pack(pady=(0, 10))

        try:
            cal.selection_set(datetime.strptime(self.variable.get(), '%Y-%m-%d').date())
        except Exception:
            cal.selection_set(datetime.today())

        btn_row = ctk.CTkFrame(con, fg_color='transparent')
        btn_row.pack(fill='x')

        def close():
            if top.winfo_exists():
                top.destroy()
            self._popup = None

        def confirm():
            self.variable.set(cal.get_date())
            close()

        def clear_and_close():
            self._clear()
            close()

        StyledButton(btn_row, text='No Limit', variant='muted', width=80,
                     command=clear_and_close).pack(side='left')
        StyledButton(btn_row, text='Cancel', variant='muted', width=70,
                     command=close).pack(side='right', padx=(6, 0))
        StyledButton(btn_row, text='OK', variant='primary', width=70,
                     command=confirm).pack(side='right')

        top.protocol('WM_DELETE_WINDOW', close)
        top.grab_set()
        top.focus_force()


class LogConsole(ctk.CTkFrame):
    """终端风格日志控制台"""
    def __init__(self, master, **kwargs):
        super().__init__(master, fg_color=COLORS['console_bg'],
                         corner_radius=8, border_width=1,
                         border_color=COLORS['border'], **kwargs)

        # 工具栏
        bar = ctk.CTkFrame(self, fg_color='#0A0E14', corner_radius=0, height=32)
        bar.pack(fill='x')
        bar.pack_propagate(False)

        ctk.CTkLabel(bar, text='● ● ●',
                     font=ctk.CTkFont(size=10),
                     text_color='#333').pack(side='left', padx=10)
        ctk.CTkLabel(bar, text='CONSOLE OUTPUT',
                     font=ctk.CTkFont(family='Consolas', size=10),
                     text_color='#444').pack(side='left', padx=6)

        StyledButton(bar, text='CLR', width=40, height=24, variant='muted',
                     font=ctk.CTkFont(family='Consolas', size=10),
                     command=self.clear).pack(side='right', padx=4, pady=4)
        StyledButton(bar, text='SAVE', width=44, height=24, variant='muted',
                     font=ctk.CTkFont(family='Consolas', size=10),
                     command=self.save_log).pack(side='right', pady=4)

        self.text = ctk.CTkTextbox(self,
                                   fg_color='transparent',
                                   text_color=COLORS['console_fg'],
                                   font=ctk.CTkFont(family='Consolas', size=12),
                                   wrap='word')
        self.text.pack(fill='both', expand=True, padx=8, pady=8)
        self.text.configure(state='disabled')
        self.text.bind('<Button-3>', self._ctx_menu)

    def append(self, message):
        self.text.configure(state='normal')
        self.text.insert('end', message)
        self.text.see('end')
        self.text.configure(state='disabled')

    def clear(self):
        self.text.configure(state='normal')
        self.text.delete('1.0', 'end')
        self.text.configure(state='disabled')

    def save_log(self):
        path = filedialog.asksaveasfilename(
            defaultextension='.txt',
            filetypes=[('Text', '*.txt'), ('Log', '*.log'), ('All', '*.*')],
            initialfile=f"log_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt")
        if path:
            try:
                with open(path, 'w', encoding='utf-8') as f:
                    f.write(self.text.get('1.0', 'end'))
                messagebox.showinfo('保存成功', f'日志已保存:\n{path}')
            except Exception as e:
                messagebox.showerror('保存失败', str(e))

    def _ctx_menu(self, event):
        menu = ctk.CTkToplevel(self)
        menu.overrideredirect(True)
        menu.attributes('-topmost', True)
        menu.geometry(f'+{event.x_root}+{event.y_root}')
        f = ctk.CTkFrame(menu, fg_color=COLORS['bg_card2'],
                         border_width=1, border_color=COLORS['border'])
        f.pack(fill='both')
        for label, cmd in [('复制', self._copy), ('全选', self._sel_all), ('清空', self.clear)]:
            ctk.CTkButton(f, text=label, anchor='w', fg_color='transparent',
                          hover_color=COLORS['bg_deep'],
                          text_color=COLORS['text_primary'],
                          font=ctk.CTkFont(family='Consolas', size=12),
                          command=lambda c=cmd, m=menu: (c(), m.destroy())).pack(
                              fill='x', padx=2, pady=1)
        menu.bind('<FocusOut>', lambda e: menu.destroy())
        self.after(100, menu.grab_set)

    def _copy(self):
        try:
            sel = self.text.get('sel.first', 'sel.last')
            self.clipboard_clear()
            self.clipboard_append(sel)
        except Exception:
            pass

    def _sel_all(self):
        self.text.tag_add('sel', '1.0', 'end')


# ===================== 扫描弹窗 =====================

class ScanDialog(ctk.CTkToplevel):
    """
    局域网扫描弹窗。
    修复要点：
      - 使用 _alive 标志代替 winfo_exists() 检查
      - 所有 after 回调先检查 _alive
      - WM_DELETE_WINDOW / 关闭按钮 / 取消按钮统一调用 _close()
    """

    def __init__(self, master, on_ip_selected, **kwargs):
        super().__init__(master, **kwargs)
        self._alive = True
        self._stop_event = None
        self._found_count = 0
        self.on_ip_selected = on_ip_selected

        # 每次打开弹窗时重新探测本机 IP，确保多网卡环境准确
        _refresh_local_ips()

        self.title('局域网设备扫描')
        self.geometry('460x560')
        self.resizable(False, False)
        self.transient(master)
        self.configure(fg_color=COLORS['bg_deep'])
        self.protocol('WM_DELETE_WINDOW', self._close)

        self._build()
        self.grab_set()
        self.focus_force()

    # ---- UI 构建 ----
    def _build(self):
        # 标题
        hdr = ctk.CTkFrame(self, fg_color=COLORS['bg_card2'], height=52)
        hdr.pack(fill='x')
        hdr.pack_propagate(False)
        ctk.CTkLabel(hdr, text='  NETWORK SCAN',
                     font=ctk.CTkFont(family='Consolas', size=14, weight='bold'),
                     text_color=COLORS['text_primary']).pack(side='left', padx=16)

        body = ctk.CTkFrame(self, fg_color='transparent')
        body.pack(fill='both', expand=True, padx=20, pady=16)

        # 网段选择
        FieldLabel(body, text='TARGET NETWORK').pack(anchor='w', pady=(0, 4))

        all_ips = get_all_local_ips()
        self._net_map = {}
        labels = []
        for ip in all_ips:
            net = ip_to_network(ip)
            lbl = f'{net}  (local: {ip})'
            labels.append(lbl)
            self._net_map[lbl] = net
        labels.append('Custom...')

        self._net_var = ctk.StringVar(value=labels[0] if labels else 'Custom...')
        self._net_opt = ctk.CTkOptionMenu(body, variable=self._net_var,
                                          values=labels,
                                          command=self._on_net_change,
                                          fg_color=COLORS['bg_card2'],
                                          button_color=COLORS['accent2'],
                                          button_hover_color=COLORS['accent2_hov'],
                                          text_color=COLORS['text_primary'],
                                          dropdown_fg_color=COLORS['bg_card2'],
                                          dropdown_text_color=COLORS['text_primary'],
                                          font=ctk.CTkFont(family='Consolas', size=12),
                                          height=36)
        self._net_opt.pack(fill='x', pady=(0, 6))

        # 自定义网段输入（默认隐藏）
        self._custom_frame = ctk.CTkFrame(body, fg_color='transparent')
        self._custom_entry = StyledEntry(self._custom_frame,
                                         placeholder_text='e.g. 192.168.31.0/24')
        self._custom_entry.pack(fill='x')
        self._on_net_change(self._net_var.get())

        # 状态栏
        stat_row = ctk.CTkFrame(body, fg_color='transparent')
        stat_row.pack(fill='x', pady=(10, 4))
        self._status_lbl = ctk.CTkLabel(stat_row, text='Ready.',
                                         font=ctk.CTkFont(family='Consolas', size=11),
                                         text_color=COLORS['text_muted'])
        self._status_lbl.pack(side='left')
        self._count_lbl = ctk.CTkLabel(stat_row, text='',
                                        font=ctk.CTkFont(family='Consolas', size=11, weight='bold'),
                                        text_color=COLORS['text_green'])
        self._count_lbl.pack(side='right')

        # 进度条（默认隐藏）
        self._progress = ctk.CTkProgressBar(body, mode='indeterminate',
                                             fg_color=COLORS['bg_card2'],
                                             progress_color=COLORS['accent2'])
        self._progress.set(0)

        # IP 列表
        list_container = ctk.CTkFrame(body, fg_color=COLORS['bg_card'],
                                       corner_radius=6, border_width=1,
                                       border_color=COLORS['border'])
        list_container.pack(fill='both', expand=True, pady=(4, 12))

        self._list = ctk.CTkScrollableFrame(list_container,
                                             fg_color='transparent')
        self._list.pack(fill='both', expand=True, padx=4, pady=4)
        self._list.grid_columnconfigure(0, weight=1)

        # 空状态提示
        self._empty_lbl = ctk.CTkLabel(self._list,
                                        text='No devices found yet.\nClick "Start Scan" to begin.',
                                        font=ctk.CTkFont(family='Consolas', size=11),
                                        text_color=COLORS['text_muted'],
                                        justify='center')
        self._empty_lbl.pack(pady=30)

        # 按钮区
        btn_row = ctk.CTkFrame(body, fg_color='transparent')
        btn_row.pack(fill='x')
        btn_row.grid_columnconfigure(0, weight=1)
        btn_row.grid_columnconfigure(1, weight=1)
        btn_row.grid_columnconfigure(2, weight=1)

        self._start_btn = StyledButton(btn_row, text='▶  START', variant='primary',
                                        command=self._start)
        self._start_btn.grid(row=0, column=0, sticky='ew', padx=(0, 4))

        self._cancel_btn = StyledButton(btn_row, text='■  STOP', variant='danger',
                                         state='disabled', command=self._stop)
        self._cancel_btn.grid(row=0, column=1, sticky='ew', padx=4)

        StyledButton(btn_row, text='CLOSE', variant='muted',
                     command=self._close).grid(row=0, column=2, sticky='ew', padx=(4, 0))

    def _on_net_change(self, choice):
        if choice == 'Custom...':
            self._custom_frame.pack(fill='x', pady=(0, 6))
        else:
            self._custom_frame.pack_forget()

    # ---- 扫描逻辑 ----
    def _start(self):
        choice = self._net_var.get()
        if choice == 'Custom...':
            network = self._custom_entry.get().strip()
            if not network:
                messagebox.showwarning('提示', '请输入自定义网段，如 192.168.31.0/24',
                                       parent=self)
                return
        else:
            network = self._net_map.get(choice, choice.split()[0])

        # 清空旧结果
        for w in self._list.winfo_children():
            w.destroy()
        self._empty_lbl = ctk.CTkLabel(self._list,
                                        text='Scanning...',
                                        font=ctk.CTkFont(family='Consolas', size=11),
                                        text_color=COLORS['text_muted'])
        self._empty_lbl.pack(pady=30)

        self._found_count = 0
        self._stop_event = threading.Event()

        self._start_btn.configure(state='disabled', text='SCANNING...')
        self._cancel_btn.configure(state='normal')
        self._status_lbl.configure(text=f'Scanning {network} ...')
        self._count_lbl.configure(text='found: 0')
        self._progress.pack(fill='x', pady=(0, 8))
        self._progress.start()

        def on_found(ip, port_info):
            if not self._alive:
                return
            self._found_count += 1
            self.after(0, self._safe(lambda: self._add_row(ip, port_info)))
            self.after(0, self._safe(
                lambda: self._count_lbl.configure(text=f'found: {self._found_count}')))

        def on_done(found):
            if not self._alive:
                return
            self.after(0, self._safe(
                lambda: self._status_lbl.configure(
                    text=f'Done — {len(found)} device(s) online')))
            self.after(0, self._safe(self._reset_ui))
            if not found:
                self.after(0, self._safe(
                    lambda: self._empty_lbl.configure(text='No devices found.')))

        threading.Thread(target=scan_network,
                         args=(network, on_found, on_done, self._stop_event, _LOCAL_IPS),
                         daemon=True).start()

    def _stop(self):
        if self._stop_event:
            self._stop_event.set()
        self._safe(lambda: self._status_lbl.configure(text='Stopping...'))()

    def _reset_ui(self):
        self._start_btn.configure(state='normal', text='▶  RESCAN')
        self._cancel_btn.configure(state='disabled')
        self._progress.stop()
        self._progress.pack_forget()

    def _add_row(self, ip, port_info=None):
        # 首次添加设备时移除空状态提示
        if self._empty_lbl and self._empty_lbl.winfo_exists():
            self._empty_lbl.destroy()
            self._empty_lbl = None

        row = ctk.CTkFrame(self._list, fg_color=COLORS['bg_card2'],
                           corner_radius=5, height=36)
        row.pack(fill='x', pady=2, padx=2)
        row.grid_columnconfigure(0, weight=1)
        row.pack_propagate(False)

        # IP 标签
        ctk.CTkLabel(row, text=ip,
                     font=ctk.CTkFont(family='Consolas', size=13),
                     text_color=COLORS['text_primary']).grid(row=0, column=0, sticky='w', padx=10)

        # 验证徽章：显示开放的端口或探测方式
        if port_info is not None:
            if isinstance(port_info, int):
                badge_text = f':{port_info}'
                badge_color = COLORS['text_green']
            else:
                badge_text = str(port_info)[:14]
                badge_color = COLORS['text_yellow']
            ctk.CTkLabel(row, text=badge_text,
                         font=ctk.CTkFont(family='Consolas', size=10),
                         text_color=badge_color).grid(row=0, column=1, padx=(0, 6))

        # 使用按钮
        StyledButton(row, text='USE', width=54, height=26, variant='info',
                     font=ctk.CTkFont(family='Consolas', size=11),
                     command=lambda i=ip: self._use(i)).grid(row=0, column=2, padx=(0, 6))

    def _use(self, ip):
        if self._stop_event:
            self._stop_event.set()
        self.on_ip_selected(ip)
        self._close()

    # ---- 安全回调包装 ----
    def _safe(self, func):
        """返回一个先检查 _alive 再执行的可调用对象"""
        def wrapper(*args, **kwargs):
            if self._alive:
                try:
                    func(*args, **kwargs)
                except Exception:
                    pass
        return wrapper

    # ---- 关闭 ----
    def _close(self):
        self._alive = False          # ← 第一步：立即标记死亡
        if self._stop_event:
            self._stop_event.set()   # 停止后台线程
        try:
            self.grab_release()
        except Exception:
            pass
        self.destroy()


# ===================== 主窗口 =====================

class LogFetcherGUI(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title('Log Fetcher  v2.0')
        self.configure(fg_color=COLORS['bg_deep'])

        sw = self.winfo_screenwidth()
        sh = self.winfo_screenheight()
        w = max(980, min(1200, sw - 80))
        h = max(740, min(900, sh - 80))
        self.geometry(f'{w}x{h}')
        self.minsize(920, 700)

        self.grid_columnconfigure(0, weight=1)
        self.grid_rowconfigure(1, weight=1)

        self._fetch_thread = None
        self._fetch_stop = None

        self.config = self._load_cfg()
        self.ip_history = self.config.get('ip_history', ['192.168.3.102'])
        self.user_history = self.config.get('user_history', ['qnxuser', 'root'])
        self.last_local_dir = self.config.get('last_local_dir', './logs')

        if not self.ip_history:
            self.ip_history = ['192.168.3.102']
        if not self.user_history:
            self.user_history = ['qnxuser']

        today = datetime.today().strftime('%Y-%m-%d')
        self.method_var = ctk.StringVar(value='ftp')
        self.start_var = ctk.StringVar(value='')        # 空 = 不限制
        self.end_var = ctk.StringVar(value='')          # 空 = 不限制
        self.latest_only_var = ctk.BooleanVar(value=False)
        self.user_var = ctk.StringVar(value=self.user_history[0])
        self.pwd_var = ctk.StringVar(value='')
        self.keyword_var = ctk.StringVar(value=self.config.get('last_keyword', 'RobotControlApp'))
        self.remote_dir_var = ctk.StringVar(value='/programs/log')
        self.local_dir_var = ctk.StringVar(value=self.last_local_dir)
        self.show_pwd_var = ctk.BooleanVar(value=False)

        self._build()
        self._bind_keys()

    # ===================== UI 构建 =====================

    def _build(self):
        # ---- 顶栏 ----
        topbar = ctk.CTkFrame(self, fg_color=COLORS['bg_card2'],
                              corner_radius=0, height=56)
        topbar.grid(row=0, column=0, sticky='ew')
        topbar.grid_propagate(False)
        topbar.grid_columnconfigure(1, weight=1)

        ctk.CTkLabel(topbar,
                     text='  LOG FETCHER',
                     font=ctk.CTkFont(family='Consolas', size=18, weight='bold'),
                     text_color=COLORS['text_primary']).grid(row=0, column=0, padx=20, sticky='w')

        # 状态指示
        self._status_dot = ctk.CTkLabel(topbar, text='⬤  READY',
                                         font=ctk.CTkFont(family='Consolas', size=11),
                                         text_color=COLORS['text_green'])
        self._status_dot.grid(row=0, column=1, sticky='e', padx=20)

        # ---- 主体 ----
        main = ctk.CTkScrollableFrame(self, fg_color='transparent',
                                       scrollbar_button_color=COLORS['bg_card2'])
        main.grid(row=1, column=0, sticky='nsew', padx=16, pady=12)
        main.grid_columnconfigure(0, weight=1)
        main.grid_columnconfigure(1, weight=1)

        # 上半左：基本配置
        self._build_basic(main)
        # 上半右：身份认证
        self._build_auth(main)
        # 中：路径设置（跨两列）
        self._build_paths(main)
        # 操作区（跨两列）
        self._build_actions(main)
        # 控制台（跨两列）
        self.console = LogConsole(main)
        self.console.grid(row=3, column=0, columnspan=2,
                          padx=4, pady=(4, 8), sticky='nsew')
        self.console.configure(height=200)

    def _build_basic(self, parent):
        card = SectionCard(parent, 'BASIC CONFIG', icon='◈')
        card.grid(row=0, column=0, padx=(4, 6), pady=4, sticky='nsew')
        b = card.body

        # IP
        FieldLabel(b, text='DEVICE IP ADDRESS').pack(anchor='w', pady=(0, 4))
        ip_row = ctk.CTkFrame(b, fg_color='transparent')
        ip_row.pack(fill='x', pady=(0, 10))
        ip_row.grid_columnconfigure(0, weight=0)
        ip_row.grid_columnconfigure(1, weight=0)
        self.ip_entry = IPEntry(ip_row, history=self.ip_history)
        self.ip_entry.set(self.ip_history[0])
        self.ip_entry.grid(row=0, column=0, sticky='nw')
        StyledButton(ip_row, text='⊕ SCAN', width=90, height=36, variant='info',
                     command=self._open_scan).grid(row=0, column=1, padx=(10, 0), sticky='n')

        # 传输方式
        FieldLabel(b, text='TRANSFER METHOD').pack(anchor='w', pady=(6, 4))
        self._method_seg = ctk.CTkSegmentedButton(
            b, values=['ftp', 'telnet'],
            variable=self.method_var,
            command=self._on_method_change,
            fg_color=COLORS['bg_input'],
            selected_color=COLORS['accent2'],
            selected_hover_color=COLORS['accent2_hov'],
            unselected_color=COLORS['bg_card2'],
            unselected_hover_color=COLORS['border'],
            text_color=COLORS['text_primary'],
            font=ctk.CTkFont(family='Consolas', size=12, weight='bold'),
            height=36)
        self._method_seg.pack(fill='x', pady=(0, 10))

        # 关键字
        FieldLabel(b, text='FILENAME KEYWORD  (blank = match all)').pack(anchor='w', pady=(6, 4))
        StyledEntry(b, textvariable=self.keyword_var).pack(fill='x', pady=(0, 10))

        # 日期区
        FieldLabel(b, text='DATE FILTER').pack(anchor='w', pady=(6, 4))

        # ── 最新一天开关（优先级最高）──
        latest_row = ctk.CTkFrame(b, fg_color=COLORS['bg_card2'],
                                   corner_radius=6, border_width=1,
                                   border_color=COLORS['border'])
        latest_row.pack(fill='x', pady=(0, 8))
        latest_row.grid_columnconfigure(0, weight=1)

        latest_label_col = ctk.CTkFrame(latest_row, fg_color='transparent')
        latest_label_col.grid(row=0, column=0, sticky='ew', padx=12, pady=8)
        ctk.CTkLabel(latest_label_col,
                     text='LATEST DAY ONLY',
                     font=ctk.CTkFont(family='Consolas', size=12, weight='bold'),
                     text_color=COLORS['text_primary']).pack(side='left')
        ctk.CTkLabel(latest_label_col,
                     text='  fetch only files from the most recent date',
                     font=ctk.CTkFont(family='Consolas', size=10),
                     text_color=COLORS['text_muted']).pack(side='left')

        self._latest_sw = ctk.CTkSwitch(
            latest_row,
            text='',
            variable=self.latest_only_var,
            command=self._on_latest_toggle,
            progress_color=COLORS['accent2'],
            fg_color=COLORS['border'],
            button_color=COLORS['text_primary'],
            button_hover_color='white',
            width=44, height=22)
        self._latest_sw.grid(row=0, column=1, padx=12, pady=8)

        # ── 起止日期选择 ──
        self._date_frame = ctk.CTkFrame(b, fg_color='transparent')
        self._date_frame.pack(fill='x')
        self._date_frame.grid_columnconfigure(0, weight=1)
        self._date_frame.grid_columnconfigure(1, weight=1)

        self.start_picker = DatePicker(self._date_frame, 'FROM  (blank = no lower limit)',
                                       self.start_var)
        self.start_picker.grid(row=0, column=0, sticky='ew', padx=(0, 6))

        self.end_picker = DatePicker(self._date_frame, 'TO  (blank = no upper limit)',
                                     self.end_var)
        self.end_picker.grid(row=0, column=1, sticky='ew')

        # 初始化开关状态
        self._on_latest_toggle()

    def _build_auth(self, parent):
        card = SectionCard(parent, 'AUTHENTICATION', icon='⚿')
        card.grid(row=0, column=1, padx=(6, 4), pady=4, sticky='nsew')
        b = card.body

        FieldLabel(b, text='USERNAME').pack(anchor='w', pady=(0, 4))
        self.user_combo = ctk.CTkComboBox(b, variable=self.user_var,
                                           values=self.user_history,
                                           height=36,
                                           fg_color=COLORS['bg_input'],
                                           border_color=COLORS['border'],
                                           text_color=COLORS['text_primary'],
                                           button_color=COLORS['border'],
                                           button_hover_color=COLORS['accent2'],
                                           dropdown_fg_color=COLORS['bg_card2'],
                                           dropdown_text_color=COLORS['text_primary'],
                                           font=ctk.CTkFont(family='Consolas', size=13))
        self.user_combo.pack(fill='x', pady=(0, 12))

        FieldLabel(b, text='PASSWORD').pack(anchor='w', pady=(0, 4))
        pwd_row = ctk.CTkFrame(b, fg_color='transparent')
        pwd_row.pack(fill='x', pady=(0, 8))
        pwd_row.grid_columnconfigure(0, weight=1)

        self.pwd_entry = StyledEntry(pwd_row, textvariable=self.pwd_var, show='*')
        self.pwd_entry.grid(row=0, column=0, sticky='ew')
        StyledButton(pwd_row, text='👁', width=36, height=36, variant='muted',
                     command=self._toggle_pwd).grid(row=0, column=1, padx=(6, 0))

        # 连接测试按钮
        StyledButton(b, text='⚡ TEST CONNECTION', variant='muted',
                     command=self._test_connection).pack(fill='x', pady=(8, 0))

        # 连接状态
        self._conn_status = ctk.CTkLabel(b, text='',
                                          font=ctk.CTkFont(family='Consolas', size=11),
                                          text_color=COLORS['text_muted'])
        self._conn_status.pack(anchor='w', pady=(4, 0))

    def _build_paths(self, parent):
        card = SectionCard(parent, 'PATH SETTINGS', icon='◧')
        card.grid(row=1, column=0, columnspan=2, padx=4, pady=4, sticky='ew')
        b = card.body
        b.grid_columnconfigure(0, weight=1)
        b.grid_columnconfigure(1, weight=1)

        # 远程目录
        remote_col = ctk.CTkFrame(b, fg_color='transparent')
        remote_col.grid(row=0, column=0, sticky='ew', padx=(0, 12))
        FieldLabel(remote_col, text='REMOTE DIRECTORY').pack(anchor='w', pady=(0, 4))
        StyledEntry(remote_col, textvariable=self.remote_dir_var).pack(fill='x')

        # 本地目录
        local_col = ctk.CTkFrame(b, fg_color='transparent')
        local_col.grid(row=0, column=1, sticky='ew')
        FieldLabel(local_col, text='LOCAL SAVE DIRECTORY').pack(anchor='w', pady=(0, 4))
        loc_row = ctk.CTkFrame(local_col, fg_color='transparent')
        loc_row.pack(fill='x')
        loc_row.grid_columnconfigure(0, weight=1)
        StyledEntry(loc_row, textvariable=self.local_dir_var).grid(row=0, column=0, sticky='ew')
        StyledButton(loc_row, text='…', width=36, height=36, variant='muted',
                     command=self._browse_dir).grid(row=0, column=1, padx=(6, 0))

    def _build_actions(self, parent):
        frame = ctk.CTkFrame(parent, fg_color='transparent')
        frame.grid(row=2, column=0, columnspan=2, padx=4, pady=(8, 4), sticky='ew')
        frame.grid_columnconfigure(0, weight=1)

        # 主按钮 + 取消
        btn_row = ctk.CTkFrame(frame, fg_color='transparent')
        btn_row.pack(fill='x')
        btn_row.grid_columnconfigure(0, weight=1)

        self.run_btn = StyledButton(btn_row, text='▶▶  START FETCH',
                                     variant='primary',
                                     height=46,
                                     font=ctk.CTkFont(family='Consolas', size=14, weight='bold'),
                                     command=self._start_fetch)
        self.run_btn.grid(row=0, column=0, sticky='ew', padx=(0, 8))

        self.cancel_btn = StyledButton(btn_row, text='■  STOP',
                                        variant='danger',
                                        height=46,
                                        state='disabled',
                                        command=self._cancel_fetch)
        self.cancel_btn.grid(row=0, column=1)

        # 进度条
        self._prog_bar = ctk.CTkProgressBar(frame, mode='indeterminate',
                                              fg_color=COLORS['bg_card2'],
                                              progress_color=COLORS['accent'])
        self._prog_bar.set(0)

        self._prog_lbl = ctk.CTkLabel(frame, text='',
                                       font=ctk.CTkFont(family='Consolas', size=11),
                                       text_color=COLORS['text_muted'])
        self._prog_lbl.pack(anchor='w', pady=(4, 0))

    # ===================== 事件处理 =====================

    def _bind_keys(self):
        self.bind('<Control-r>', lambda e: self._start_fetch())
        self.bind('<Control-s>', lambda e: self.console.save_log())
        self.bind('<Control-l>', lambda e: self.console.clear())
        self.bind('<F5>', lambda e: self._open_scan())
        self.bind('<Escape>', lambda e: self._cancel_fetch())

    def _on_latest_toggle(self):
        """最新一天开关联动：开启时禁用日期输入框并置灰"""
        enabled = not self.latest_only_var.get()
        state = 'normal' if enabled else 'disabled'
        alpha = COLORS['text_primary'] if enabled else COLORS['text_muted']
        for picker in (self.start_picker, self.end_picker):
            picker._entry.configure(state=state, text_color=alpha)
            picker._clear_btn.configure(state=state)
            # 找到日历按钮（picker row 的 column=2）
            for w in picker.winfo_children():
                if isinstance(w, ctk.CTkFrame):
                    for child in w.grid_slaves():
                        if isinstance(child, ctk.CTkButton) and child.cget('text') == '📅':
                            child.configure(state=state)

    def _toggle_pwd(self):
        self.show_pwd_var.set(not self.show_pwd_var.get())
        self.pwd_entry.configure(show='' if self.show_pwd_var.get() else '*')

    def _on_method_change(self, choice):
        if choice == 'ftp':
            self.remote_dir_var.set('/programs/log')
            if self.user_var.get() == 'root':
                self.user_var.set('qnxuser')
        else:
            self.remote_dir_var.set('/root/mnt/programs/log')
            if self.user_var.get() == 'qnxuser':
                self.user_var.set('root')

    def _browse_dir(self):
        init = self.local_dir_var.get()
        if not os.path.exists(init):
            init = os.path.expanduser('~')
        d = filedialog.askdirectory(initialdir=init, title='选择本地保存目录')
        if d:
            self.local_dir_var.set(d)

    def _test_connection(self):
        ip = self.ip_entry.get()
        if not self.ip_entry.is_valid():
            self._conn_status.configure(text='✗ Invalid IP', text_color=COLORS['text_red'])
            return
        self._conn_status.configure(text='Testing...', text_color=COLORS['text_muted'])
        self.update()

        def do_test():
            alive, port_info = probe_host(ip)
            ok = alive
            color = COLORS['text_green'] if ok else COLORS['text_red']
            detail = f'  (port {port_info})' if isinstance(port_info, int) else ''
            text = f'✓ {ip} reachable{detail}' if ok else f'✗ {ip} unreachable'
            self.after(0, lambda: self._conn_status.configure(text=text, text_color=color))

        threading.Thread(target=do_test, daemon=True).start()

    def _open_scan(self):
        def on_selected(ip):
            self.ip_entry.set(ip)
            if ip not in self.ip_history:
                self.ip_history.insert(0, ip)
                self.ip_history = self.ip_history[:5]
            self.ip_entry.history = self.ip_history

        dlg = ScanDialog(self, on_ip_selected=on_selected)
        dlg.focus_force()

    # ===================== 抓取逻辑 =====================

    def _validate(self):
        errors = []
        if not self.ip_entry.is_valid():
            errors.append('IP 地址格式不正确')

        # 日期验证：latest_only 模式下跳过日期校验
        if not self.latest_only_var.get():
            if not self.start_picker.is_valid():
                errors.append('开始日期格式错误 (YYYY-MM-DD 或留空)')
            if not self.end_picker.is_valid():
                errors.append('结束日期格式错误 (YYYY-MM-DD 或留空)')
            # 两端都有值时检查顺序
            s = self.start_picker.get_date()
            e = self.end_picker.get_date()
            if s and e and s > e:
                errors.append('开始日期不能晚于结束日期')

        if not self.user_var.get().strip():
            errors.append('用户名不能为空')
        if not self.local_dir_var.get().strip():
            errors.append('本地目录不能为空')
        if errors:
            messagebox.showerror('验证失败', '\n'.join(f'• {e}' for e in errors))
            return False
        return True

    def _start_fetch(self):
        if self._fetch_thread and self._fetch_thread.is_alive():
            return
        if not self._validate():
            return
        self._save_cfg()

        self.run_btn.configure(state='disabled', text='⏳  FETCHING...')
        self.cancel_btn.configure(state='normal')
        self._status_dot.configure(text='⬤  RUNNING', text_color=COLORS['warn'])
        self._prog_bar.pack(fill='x', pady=(6, 0))
        self._prog_bar.start()
        self._prog_lbl.configure(text='Connecting...')
        self.console.clear()

        self._fetch_stop = threading.Event()
        self._fetch_thread = threading.Thread(target=self._fetch_worker, daemon=True)
        self._fetch_thread.start()

    def _cancel_fetch(self):
        if self._fetch_stop:
            self._fetch_stop.set()
        self._prog_lbl.configure(text='Cancelling...')
        self.console.append('\n[STOPPING...]\n')

    def _fetch_worker(self):
        ip = self.ip_entry.get()
        latest_only = self.latest_only_var.get()
        start_str = self.start_var.get().strip()
        end_str = self.end_var.get().strip()

        params = dict(
            ip=ip,
            start_date_str='' if latest_only else start_str,
            end_date_str='' if latest_only else end_str,
            latest_only=latest_only,
            method=self.method_var.get(),
            local_dir=self.local_dir_var.get(),
            keyword=self.keyword_var.get(),
            user=self.user_var.get(),
            password=self.pwd_var.get(),
            remote_dir=self.remote_dir_var.get(),
            stop_event=self._fetch_stop,
        )

        # 组织日志显示的日期区间描述
        if latest_only:
            range_desc = 'LATEST DAY ONLY'
        else:
            s = start_str or '(no lower limit)'
            e = end_str or '(no upper limit)'
            range_desc = f'{s} → {e}'

        sep = '─' * 48
        self.after(0, self.console.append,
                   f'{sep}\n  TARGET  : {ip}\n'
                   f'  METHOD  : {params["method"].upper()}\n'
                   f'  RANGE   : {range_desc}\n'
                   f'  KEYWORD : {params["keyword"] or "(none)"}\n{sep}\n\n')

        def log(text):
            self.after(0, self.console.append, text)
            if 'Downloading' in text or 'Found' in text:
                snippet = text.strip()[:55]
                self.after(0, lambda: self._prog_lbl.configure(text=snippet))

        try:
            ret = run_fetch_core(**params, gui_log_callback=log)
        except Exception as e:
            self.after(0, self.console.append, f'\n[ERROR] {e}\n')
            ret = 1

        icons = {0: ('✓ DONE', COLORS['text_green']),
                 -1: ('⚠ CANCELLED', COLORS['warn'])}
        label, color = icons.get(ret, ('✗ FAILED', COLORS['text_red']))
        self.after(0, self.console.append, f'\n[{label}]\n')
        self.after(0, lambda: self._status_dot.configure(text=f'⬤  {label}', text_color=color))
        self.after(0, self._reset_ui)

    def _reset_ui(self):
        self.run_btn.configure(state='normal', text='▶▶  START FETCH')
        self.cancel_btn.configure(state='disabled')
        self._prog_bar.stop()
        self._prog_bar.pack_forget()
        self._prog_lbl.configure(text='')

    # ===================== 配置 =====================

    def _load_cfg(self):
        if os.path.exists(CONFIG_FILE):
            try:
                with open(CONFIG_FILE, 'r') as f:
                    return json.load(f)
            except Exception:
                pass
        return {}

    def _save_cfg(self):
        ip = self.ip_entry.get()
        usr = self.user_var.get().strip()
        if ip and ip not in self.ip_history:
            self.ip_history.insert(0, ip)
            self.ip_history = self.ip_history[:5]
        if usr and usr not in self.user_history:
            self.user_history.insert(0, usr)
            self.user_history = self.user_history[:5]
        self.config.update({
            'ip_history': self.ip_history,
            'user_history': self.user_history,
            'last_local_dir': self.local_dir_var.get(),
            'last_keyword': self.keyword_var.get(),
        })
        try:
            with open(CONFIG_FILE, 'w') as f:
                json.dump(self.config, f, indent=2)
        except Exception:
            pass


# ===================== 入口 =====================

if __name__ == '__main__':
    app = LogFetcherGUI()
    app.mainloop()