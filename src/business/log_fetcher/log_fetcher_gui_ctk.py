import os
import sys
import json
import threading
import subprocess
from datetime import datetime

try:
    import customtkinter as ctk
    from tkcalendar import Calendar
except ImportError:
    print("Error: Required libraries are missing.")
    print("Please install them using: pip install customtkinter tkcalendar")
    sys.exit(1)

from tkinter import filedialog, messagebox

# Set modern appearance
ctk.set_appearance_mode("System")
ctk.set_default_color_theme("blue")

CONFIG_FILE = "main/log_fetcher_config.json"

class IPEntry(ctk.CTkFrame):
    def __init__(self, master, **kwargs):
        super().__init__(master, fg_color="transparent", **kwargs)
        
        self.entries = []
        self.vars = [ctk.StringVar() for _ in range(4)]
        
        # Draw the 4 octet boxes with dots in between
        for i in range(4):
            # Trace changes to automatically jump to next box
            self.vars[i].trace_add("write", lambda name, index, mode, idx=i: self._on_change(idx))
            
            entry = ctk.CTkEntry(self, textvariable=self.vars[i], width=45, height=35, justify="center")
            entry.grid(row=0, column=i*2)
            
            # Bind events for jumping
            entry.bind("<KeyRelease>", lambda event, idx=i: self._on_key_release(event, idx))
            entry.bind("<BackSpace>", lambda event, idx=i: self._on_backspace(event, idx))
            entry.bind("<Left>", lambda event, idx=i: self._on_left(event, idx))
            entry.bind("<Right>", lambda event, idx=i: self._on_right(event, idx))
            
            self.entries.append(entry)
            
            if i < 3:
                dot = ctk.CTkLabel(self, text=".", font=ctk.CTkFont(size=20, weight="bold"))
                dot.grid(row=0, column=i*2+1, padx=2)

    def _on_change(self, idx):
        # Validate input is digits
        value = self.vars[idx].get()
        if not value.isdigit() and value != "":
            self.vars[idx].set("".join(filter(str.isdigit, value)))
            return
            
        # Truncate to 3 chars and max 255
        if value.isdigit():
            if len(value) > 3:
                self.vars[idx].set(value[:3])
            elif int(value) > 255:
                self.vars[idx].set("255")

    def _on_key_release(self, event, idx):
        # If user typed a dot, or reached 3 digits, jump to next
        value = self.vars[idx].get()
        
        if event.char == '.':
            # Remove the dot that might have been typed
            self.vars[idx].set(value.replace('.', ''))
            if idx < 3:
                self.entries[idx+1].focus()
                self.entries[idx+1].icursor("end")
            return "break"
            
        if len(value) >= 3 and idx < 3 and event.keysym not in ["BackSpace", "Left", "Right", "Tab"]:
            self.entries[idx+1].focus()
            # Select all in next box for easy overwrite
            self.entries[idx+1].select_range(0, "end")
            self.entries[idx+1].icursor("end")

    def _on_backspace(self, event, idx):
        # If box is empty and backspace is pressed, jump to previous box
        if not self.vars[idx].get() and idx > 0:
            self.entries[idx-1].focus()
            self.entries[idx-1].icursor("end")

    def _on_left(self, event, idx):
        # If cursor is at the beginning, jump to previous
        if self.entries[idx].index("insert") == 0 and idx > 0:
            self.entries[idx-1].focus()
            self.entries[idx-1].icursor("end")

    def _on_right(self, event, idx):
        # If cursor is at the end, jump to next
        if self.entries[idx].index("insert") == len(self.vars[idx].get()) and idx < 3:
            self.entries[idx+1].focus()
            self.entries[idx+1].icursor(0)

    def get(self):
        return ".".join([v.get() for v in self.vars])

    def set(self, ip_str):
        parts = ip_str.split(".")
        for i in range(min(4, len(parts))):
            self.vars[i].set(parts[i])


class LogFetcherGUI(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title("远程日志抓取工具 (Log Fetcher)")
        screen_w = self.winfo_screenwidth()
        screen_h = self.winfo_screenheight()
        win_w = max(900, min(1100, screen_w - 120))
        win_h = max(650, min(820, screen_h - 120))
        self.geometry(f"{win_w}x{win_h}")
        self.minsize(860, 650)
        
        self.grid_columnconfigure(0, weight=1)
        self.grid_rowconfigure(1, weight=1)
        
        self._calendar_popups = {}

        # Load config/history
        self.config = self.load_config()
        self.ip_history = self.config.get("ip_history", ["192.168.3.102"])
        self.user_history = self.config.get("user_history", ["qnxuser", "root"])
        self.last_local_dir = self.config.get("last_local_dir", "./logs")
        self.last_keyword = self.config.get("last_keyword", "RobotControlApp")
        
        # Ensure lists are unique and not empty
        if not self.ip_history: self.ip_history = ["192.168.3.102"]
        if not self.user_history: self.user_history = ["qnxuser"]
        
        # --- Header ---
        self.header_frame = ctk.CTkFrame(self, fg_color="transparent")
        self.header_frame.grid(row=0, column=0, sticky="ew", padx=30, pady=(20, 10))
        self.title_label = ctk.CTkLabel(self.header_frame, text="远程日志抓取控制台", font=ctk.CTkFont(size=28, weight="bold"))
        self.title_label.pack(side="left")
        
        # --- Main Content Area (Scrollable) ---
        self.content_frame = ctk.CTkScrollableFrame(self, fg_color="transparent")
        self.content_frame.grid(row=1, column=0, sticky="nsew", padx=20, pady=(0, 20))
        self.content_frame.grid_columnconfigure(0, weight=1)
        self.content_frame.grid_columnconfigure(1, weight=1)
        self.content_frame.grid_rowconfigure(3, weight=1)
        
        # Variables
        self.method_var = ctk.StringVar(value="ftp")
        today = datetime.today().strftime("%Y-%m-%d")
        self.start_var = ctk.StringVar(value=today)
        self.end_var = ctk.StringVar(value=today)
        
        self.user_var = ctk.StringVar(value=self.user_history[0])
        self.pwd_var = ctk.StringVar(value="")
        self.keyword_var = ctk.StringVar(value=self.last_keyword)
        
        self.remote_dir_var = ctk.StringVar(value="/programs/log")
        self.local_dir_var = ctk.StringVar(value=self.last_local_dir)
        
        # 1. Basic Settings Card
        self.basic_card = self.create_card(self.content_frame, "🌐 基本配置 (Basic)", 0, 0)
        
        # Custom IP row
        lbl_ip = ctk.CTkLabel(self.basic_card, text="设备 IP 地址:", font=ctk.CTkFont(size=14, weight="bold"))
        lbl_ip.grid(row=1, column=0, padx=25, pady=(15, 5), sticky="w")
        
        ip_container = ctk.CTkFrame(self.basic_card, fg_color="transparent")
        ip_container.grid(row=2, column=0, padx=25, pady=(0, 10), sticky="ew")
        
        self.ip_entry = IPEntry(ip_container)
        self.ip_entry.pack(side="left")
        self.ip_entry.set(self.ip_history[0])
        
        # History dropdown for IP
        self.ip_combo = ctk.CTkOptionMenu(ip_container, values=self.ip_history, command=self.on_ip_history_select, width=30)
        self.ip_combo.pack(side="left", padx=(10, 0))
        self.ip_combo.set("▼")

        self.create_dropdown(self.basic_card, "传输方式:", self.method_var, ["ftp", "telnet"], self.on_method_change, 1)
        self.create_input(self.basic_card, "文件名包含关键字 (留空则匹配全部):", self.keyword_var, 2)
        
        # Date pickers
        self.create_date_picker(self.basic_card, "开始日期:", self.start_var, 3)
        self.create_date_picker(self.basic_card, "结束日期:", self.end_var, 4)
        
        # 2. Auth Settings Card
        self.auth_card = self.create_card(self.content_frame, "🔐 身份认证 (Auth)", 0, 1)
        
        # User combobox with history
        self.lbl_user = ctk.CTkLabel(self.auth_card, text="FTP 用户名:", font=ctk.CTkFont(size=14, weight="bold"))
        self.lbl_user.grid(row=1, column=0, padx=25, pady=(15, 5), sticky="w")
        
        self.user_combo = ctk.CTkComboBox(self.auth_card, variable=self.user_var, values=self.user_history, height=40)
        self.user_combo.grid(row=2, column=0, padx=25, pady=(0, 10), sticky="ew")
        
        self.lbl_pwd = self.create_input(self.auth_card, "FTP 密码:", self.pwd_var, 1, show="*")
        
        # 3. Path Settings Card
        self.path_card = self.create_card(self.content_frame, "📁 路径设置 (Paths)", 1, 0, columnspan=2)
        self.path_card.grid_columnconfigure(0, weight=1)
        
        self.lbl_remote_dir = ctk.CTkLabel(self.path_card, text="FTP 远程目录:", font=ctk.CTkFont(size=14, weight="bold"))
        self.lbl_remote_dir.grid(row=1, column=0, padx=25, pady=(10, 5), sticky="w")
        
        remote_entry = ctk.CTkEntry(self.path_card, textvariable=self.remote_dir_var, height=40)
        remote_entry.grid(row=2, column=0, padx=25, pady=(0, 15), sticky="ew")
        
        lbl_local = ctk.CTkLabel(self.path_card, text="本地保存目录:", font=ctk.CTkFont(size=14, weight="bold"))
        lbl_local.grid(row=3, column=0, padx=25, pady=(10, 5), sticky="w")
        
        local_dir_frame = ctk.CTkFrame(self.path_card, fg_color="transparent")
        local_dir_frame.grid(row=4, column=0, padx=25, pady=(0, 20), sticky="ew")
        local_dir_frame.grid_columnconfigure(0, weight=1)
        
        ctk.CTkEntry(local_dir_frame, textvariable=self.local_dir_var, height=40).grid(row=0, column=0, sticky="ew", padx=(0, 15))
        ctk.CTkButton(local_dir_frame, text="选择目录", command=self.browse_local_dir, width=120, height=40, 
                      fg_color="#546E7A", hover_color="#455A64", font=ctk.CTkFont(weight="bold")).grid(row=0, column=1)

        # 4. Action Button
        self.run_btn = ctk.CTkButton(self.content_frame, text="▶ 开始抓取日志 (Fetch Logs)", 
                                     font=ctk.CTkFont(size=18, weight="bold"), height=55, corner_radius=8,
                                     command=self.start_fetching, fg_color="#2E7D32", hover_color="#1B5E20")
        self.run_btn.grid(row=2, column=0, columnspan=2, padx=10, pady=(20, 20), sticky="ew")

        # 5. Console Output
        self.console_frame = ctk.CTkFrame(self.content_frame, corner_radius=10, fg_color="#121212")
        self.console_frame.grid(row=3, column=0, columnspan=2, padx=10, pady=(0, 10), sticky="nsew")
        self.console_frame.grid_columnconfigure(0, weight=1)
        self.console_frame.grid_rowconfigure(0, weight=1)
        
        self.log_text = ctk.CTkTextbox(self.console_frame, fg_color="transparent", text_color="#00E676", 
                                       font=ctk.CTkFont(family="Consolas", size=14), wrap="word", height=200)
        self.log_text.grid(row=0, column=0, padx=10, pady=10, sticky="nsew")
        self.log_text.configure(state="disabled")

    def load_config(self):
        if os.path.exists(CONFIG_FILE):
            try:
                with open(CONFIG_FILE, 'r') as f:
                    return json.load(f)
            except:
                pass
        return {}

    def save_config(self):
        # Update history
        current_ip = self.ip_entry.get()
        current_user = self.user_var.get().strip()
        
        if current_ip and current_ip not in self.ip_history:
            self.ip_history.insert(0, current_ip)
            self.ip_history = self.ip_history[:5] # Keep max 5
            self.ip_combo.configure(values=self.ip_history)
            
        if current_user and current_user not in self.user_history:
            self.user_history.insert(0, current_user)
            self.user_history = self.user_history[:5]
            self.user_combo.configure(values=self.user_history)

        self.config["ip_history"] = self.ip_history
        self.config["user_history"] = self.user_history
        self.config["last_local_dir"] = self.local_dir_var.get().strip()
        self.config["last_keyword"] = self.keyword_var.get().strip()
        
        try:
            with open(CONFIG_FILE, 'w') as f:
                json.dump(self.config, f)
        except:
            pass

    def on_ip_history_select(self, choice):
        self.ip_entry.set(choice)
        self.ip_combo.set("▼")

    def create_card(self, parent, title, row, col, columnspan=1):
        card = ctk.CTkFrame(parent, corner_radius=12, fg_color=("gray90", "gray13"))
        card.grid(row=row, column=col, columnspan=columnspan, padx=10, pady=10, sticky="nsew")
        
        header = ctk.CTkFrame(card, fg_color=("gray85", "gray17"), corner_radius=12)
        header.grid(row=0, column=0, sticky="ew")
        card.grid_columnconfigure(0, weight=1)
        
        title_lbl = ctk.CTkLabel(header, text=title, font=ctk.CTkFont(size=16, weight="bold"))
        title_lbl.pack(padx=20, pady=12, anchor="w")
        return card

    def create_input(self, card, label_text, variable, row_offset, show=""):
        lbl = ctk.CTkLabel(card, text=label_text, font=ctk.CTkFont(size=14, weight="bold"))
        lbl.grid(row=row_offset*2 + 1, column=0, padx=25, pady=(15, 5), sticky="w")
        
        entry = ctk.CTkEntry(card, textvariable=variable, show=show, height=40)
        entry.grid(row=row_offset*2 + 2, column=0, padx=25, pady=(0, 10), sticky="ew")
        return lbl

    def create_dropdown(self, card, label_text, variable, values, command, row_offset):
        lbl = ctk.CTkLabel(card, text=label_text, font=ctk.CTkFont(size=14, weight="bold"))
        lbl.grid(row=row_offset*2 + 1, column=0, padx=25, pady=(15, 5), sticky="w")
        
        combo = ctk.CTkOptionMenu(card, variable=variable, values=values, command=command, height=40, 
                                  fg_color=("gray85", "gray20"), 
                                  button_color=("gray75", "gray15"), 
                                  button_hover_color=("gray70", "gray25"),
                                  text_color=("black", "white"),
                                  dropdown_fg_color=("gray90", "gray20"),
                                  dropdown_hover_color=("gray75", "gray30"),
                                  dropdown_text_color=("black", "white"))
        combo.grid(row=row_offset*2 + 2, column=0, padx=25, pady=(0, 10), sticky="ew")
        return lbl

    def create_date_picker(self, card, label_text, variable, row_offset):
        lbl = ctk.CTkLabel(card, text=label_text, font=ctk.CTkFont(size=14, weight="bold"))
        lbl.grid(row=row_offset*2 + 1, column=0, padx=25, pady=(15, 5), sticky="w")
        
        frame = ctk.CTkFrame(card, fg_color="transparent")
        frame.grid(row=row_offset*2 + 2, column=0, padx=25, pady=(0, 10), sticky="ew")
        frame.grid_columnconfigure(0, weight=1)
        
        entry = ctk.CTkEntry(frame, textvariable=variable, height=40)
        entry.grid(row=0, column=0, sticky="ew")
        
        def open_calendar():
            existing = self._calendar_popups.get(id(variable))
            if existing and existing.winfo_exists():
                existing.lift()
                existing.focus_force()
                return

            top = ctk.CTkToplevel(self)
            self._calendar_popups[id(variable)] = top
            top.title("选择日期")
            top.resizable(False, False)
            top.transient(self)

            try:
                bx = btn.winfo_rootx()
                by = btn.winfo_rooty() + btn.winfo_height() + 6
                top.geometry(f"+{bx}+{by}")
            except Exception:
                x = self.winfo_pointerx()
                y = self.winfo_pointery()
                top.geometry(f"+{x}+{y}")

            try:
                top.attributes("-topmost", True)
            except Exception:
                pass

            container = ctk.CTkFrame(top, fg_color="transparent")
            container.pack(padx=16, pady=16)

            cal = Calendar(container, selectmode="day", date_pattern="y-mm-dd")
            cal.pack(padx=0, pady=(0, 12))

            try:
                d = datetime.strptime(variable.get(), "%Y-%m-%d").date()
                cal.selection_set(d)
            except Exception:
                pass

            btn_row = ctk.CTkFrame(container, fg_color="transparent")
            btn_row.pack(fill="x")

            def close_popup():
                try:
                    top.grab_release()
                except Exception:
                    pass
                if top.winfo_exists():
                    top.destroy()
                self._calendar_popups.pop(id(variable), None)

            def set_date():
                try:
                    variable.set(cal.get_date())
                finally:
                    close_popup()

            ctk.CTkButton(btn_row, text="取消", command=close_popup, width=90, height=34,
                          fg_color=("#E0E0E0", "#2B2B2B"), text_color=("black", "white"),
                          hover_color=("#D5D5D5", "#3A3A3A")).pack(side="right", padx=(8, 0))
            ctk.CTkButton(btn_row, text="确定", command=set_date, width=90, height=34).pack(side="right")

            def on_close():
                close_popup()

            top.protocol("WM_DELETE_WINDOW", on_close)

            top.grab_set()
            top.focus_force()
            try:
                top.after(200, lambda: top.attributes("-topmost", False))
            except Exception:
                pass

        btn = ctk.CTkButton(frame, text="📅", width=40, height=40, command=open_calendar,
                            fg_color=("gray85", "gray20"), text_color=("black", "white"), hover_color=("gray75", "gray30"))
        btn.grid(row=0, column=1, padx=(5, 0))
        
        return lbl

    def on_method_change(self, choice):
        if choice == "ftp":
            self.lbl_user.configure(text="FTP 用户名:")
            self.lbl_pwd.configure(text="FTP 密码:")
            self.lbl_remote_dir.configure(text="FTP 远程目录:")
            if self.user_var.get() == "root":
                self.user_var.set("qnxuser")
            if self.remote_dir_var.get() == "/root/mnt/programs/log":
                self.remote_dir_var.set("/programs/log")
        else:
            self.lbl_user.configure(text="Telnet 用户名:")
            self.lbl_pwd.configure(text="Telnet 密码:")
            self.lbl_remote_dir.configure(text="Telnet 远程目录:")
            if self.user_var.get() == "qnxuser":
                self.user_var.set("root")
            if self.remote_dir_var.get() == "/programs/log":
                self.remote_dir_var.set("/root/mnt/programs/log")

    def browse_local_dir(self):
        initial_dir = self.local_dir_var.get()
        if not os.path.exists(initial_dir):
            initial_dir = os.path.expanduser("~")
            
        dir_path = filedialog.askdirectory(initialdir=initial_dir, title="选择本地保存目录")
        if dir_path:
            self.local_dir_var.set(dir_path)
            self.last_local_dir = dir_path
            self.save_config()

    def append_log(self, message):
        self.log_text.configure(state='normal')
        self.log_text.insert("end", message)
        self.log_text.see("end")
        self.log_text.configure(state='disabled')

    def start_fetching(self):
        ip = self.ip_entry.get().strip()
        start = self.start_var.get().strip()
        end = self.end_var.get().strip()
        
        if not ip or len(ip.split('.')) != 4 or not start or not end:
            messagebox.showerror("错误", "请填写完整的IP地址和开始/结束日期！")
            return
            
        # Save config before running
        self.save_config()
            
        self.run_btn.configure(state="disabled", fg_color="#81C784", text="⏳ 正在抓取中...")
        self.log_text.configure(state='normal')
        self.log_text.delete("1.0", "end")
        self.log_text.configure(state='disabled')
        
        threading.Thread(target=self.run_script_thread, daemon=True).start()

    def run_script_thread(self):
        method = self.method_var.get()
        cmd = [
            sys.executable, "log_fetcher.py",
            self.ip_entry.get().strip(),
            "--start", self.start_var.get().strip(),
            "--end", self.end_var.get().strip(),
            "--method", method,
            "--local-dir", self.local_dir_var.get().strip()
        ]
        
        keyword = self.keyword_var.get().strip()
        if keyword:
            cmd.extend(["--keyword", keyword])
            
        user = self.user_var.get().strip()
        pwd = self.pwd_var.get()
        remote_dir = self.remote_dir_var.get().strip()

        if method == "telnet":
            cmd.extend(["--user", user])
            cmd.extend(["--remote-dir", remote_dir])
            if pwd:
                cmd.extend(["--password", pwd])
        else: # ftp
            # ONLY send FTP credentials. 
            # We don't send Telnet fallback credentials anymore because 
            # the user only provided one set of credentials in the unified UI.
            cmd.extend(["--ftp-user", user])
            cmd.extend(["--ftp-dir", remote_dir])
            if pwd:
                cmd.extend(["--ftp-password", pwd])

        display_cmd = []
        skip_next = False
        for i, arg in enumerate(cmd):
            if skip_next:
                skip_next = False
                continue
            if arg in ["--password", "--ftp-password"]:
                display_cmd.extend([arg, "******"])
                skip_next = True
            else:
                display_cmd.append(arg)

        self.after(0, self.append_log, f"==================================================\n")
        self.after(0, self.append_log, f"启动抓取任务: {' '.join(display_cmd)}\n")
        self.after(0, self.append_log, f"==================================================\n\n")

        try:
            env = os.environ.copy()
            env["PYTHONUNBUFFERED"] = "1"

            creationflags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
            
            process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                env=env,
                creationflags=creationflags
            )

            for line in iter(process.stdout.readline, ''):
                self.after(0, self.append_log, line)
                
            process.stdout.close()
            process.wait()
            
            if process.returncode == 0:
                self.after(0, self.append_log, f"\n[✅ 任务执行成功，退出码: {process.returncode}]\n")
            else:
                self.after(0, self.append_log, f"\n[❌ 任务执行异常，退出码: {process.returncode}]\n")
            
        except Exception as e:
            self.after(0, self.append_log, f"\n[❌ 启动运行环境出错: {e}]\n")
            
        finally:
            self.after(0, lambda: self.run_btn.configure(state="normal", fg_color="#2E7D32", text="▶ 开始抓取日志 (Fetch Logs)"))

if __name__ == "__main__":
    app = LogFetcherGUI()
    app.mainloop()
