import tkinter as tk
from tkinter import ttk, scrolledtext, messagebox, filedialog
import subprocess
import threading
import os
import sys

class LogFetcherGUI:
    def __init__(self, root):
        self.root = root
        self.root.title("远程日志抓取工具 (Log Fetcher)")
        self.root.geometry("800x700")
        
        # Apply a basic theme
        style = ttk.Style()
        if 'clam' in style.theme_names():
            style.theme_use('clam')
            
        self.create_widgets()
        
    def create_widgets(self):
        main_frame = ttk.Frame(self.root, padding="15")
        main_frame.pack(fill=tk.BOTH, expand=True)
        
        # --- Basic Settings ---
        group_basic = ttk.LabelFrame(main_frame, text="1. 基本设置 (Basic Settings)", padding="10")
        group_basic.pack(fill=tk.X, pady=5)
        
        ttk.Label(group_basic, text="设备 IP:").grid(row=0, column=0, sticky=tk.W, pady=5)
        self.ip_var = tk.StringVar(value="192.168.3.102")
        ttk.Entry(group_basic, textvariable=self.ip_var, width=18).grid(row=0, column=1, sticky=tk.W, pady=5, padx=5)
        
        ttk.Label(group_basic, text="传输方式:").grid(row=0, column=2, sticky=tk.W, pady=5, padx=15)
        self.method_var = tk.StringVar(value="ftp")
        method_cb = ttk.Combobox(group_basic, textvariable=self.method_var, values=["ftp", "telnet"], state="readonly", width=10)
        method_cb.grid(row=0, column=3, sticky=tk.W, pady=5)
        method_cb.bind("<<ComboboxSelected>>", self.on_method_change)
        
        ttk.Label(group_basic, text="开始日期:").grid(row=1, column=0, sticky=tk.W, pady=5)
        self.start_var = tk.StringVar(value="2026-04-20")
        ttk.Entry(group_basic, textvariable=self.start_var, width=18).grid(row=1, column=1, sticky=tk.W, pady=5, padx=5)
        
        ttk.Label(group_basic, text="结束日期:").grid(row=1, column=2, sticky=tk.W, pady=5, padx=15)
        self.end_var = tk.StringVar(value="2026-04-24")
        ttk.Entry(group_basic, textvariable=self.end_var, width=18).grid(row=1, column=3, sticky=tk.W, pady=5)

        # --- Authentication Settings ---
        group_auth = ttk.LabelFrame(main_frame, text="2. 认证设置 (Authentication)", padding="10")
        group_auth.pack(fill=tk.X, pady=5)
        
        self.lbl_user = ttk.Label(group_auth, text="用户名:")
        self.lbl_user.grid(row=0, column=0, sticky=tk.W, pady=5)
        self.user_var = tk.StringVar(value="qnxuser")
        ttk.Entry(group_auth, textvariable=self.user_var, width=18).grid(row=0, column=1, sticky=tk.W, pady=5, padx=5)
        
        self.lbl_pwd = ttk.Label(group_auth, text="密码:")
        self.lbl_pwd.grid(row=0, column=2, sticky=tk.W, pady=5, padx=15)
        self.pwd_var = tk.StringVar(value="qnxuser")
        ttk.Entry(group_auth, textvariable=self.pwd_var, width=18, show="*").grid(row=0, column=3, sticky=tk.W, pady=5)

        # --- Path Settings ---
        group_path = ttk.LabelFrame(main_frame, text="3. 路径设置 (Paths)", padding="10")
        group_path.pack(fill=tk.X, pady=5)
        
        self.lbl_remote_dir = ttk.Label(group_path, text="远程日志目录:")
        self.lbl_remote_dir.grid(row=0, column=0, sticky=tk.W, pady=5)
        self.remote_dir_var = tk.StringVar(value="/programs/log")
        ttk.Entry(group_path, textvariable=self.remote_dir_var, width=50).grid(row=0, column=1, columnspan=3, sticky=tk.W, pady=5, padx=5)

        ttk.Label(group_path, text="本地保存目录:").grid(row=1, column=0, sticky=tk.W, pady=5)
        self.local_dir_var = tk.StringVar(value="./logs")
        ttk.Entry(group_path, textvariable=self.local_dir_var, width=38).grid(row=1, column=1, columnspan=2, sticky=tk.W, pady=5, padx=5)
        ttk.Button(group_path, text="浏览...", command=self.browse_local_dir).grid(row=1, column=3, sticky=tk.W, pady=5)

        # --- Action Buttons ---
        btn_frame = ttk.Frame(main_frame)
        btn_frame.pack(fill=tk.X, pady=10)
        
        self.run_btn = tk.Button(btn_frame, text="▶ 开始抓取日志 (Fetch Logs)", command=self.start_fetching, bg="#4CAF50", fg="white", font=("Arial", 11, "bold"), height=2, width=30)
        self.run_btn.pack(side=tk.TOP, pady=5)

        # --- Log Output Console ---
        group_log = ttk.LabelFrame(main_frame, text="运行日志 (Output Console)", padding="10")
        group_log.pack(fill=tk.BOTH, expand=True, pady=5)
        
        self.log_text = scrolledtext.ScrolledText(group_log, wrap=tk.WORD, state='disabled', bg="#1E1E1E", fg="#00FF00", font=("Consolas", 10))
        self.log_text.pack(fill=tk.BOTH, expand=True)

    def on_method_change(self, event):
        method = self.method_var.get()
        if method == "ftp":
            self.lbl_user.config(text="FTP 用户名:")
            self.lbl_pwd.config(text="FTP 密码:")
            self.lbl_remote_dir.config(text="FTP 远程目录:")
            # Suggest default values for FTP if they haven't been changed significantly
            if self.user_var.get() == "root":
                self.user_var.set("qnxuser")
            if self.remote_dir_var.get() == "/root/mnt/programs/log":
                self.remote_dir_var.set("/programs/log")
        else:
            self.lbl_user.config(text="Telnet 用户名:")
            self.lbl_pwd.config(text="Telnet 密码:")
            self.lbl_remote_dir.config(text="Telnet 远程目录:")
            # Suggest default values for Telnet
            if self.user_var.get() == "qnxuser":
                self.user_var.set("root")
            if self.remote_dir_var.get() == "/programs/log":
                self.remote_dir_var.set("/root/mnt/programs/log")

    def browse_local_dir(self):
        dir_path = filedialog.askdirectory()
        if dir_path:
            self.local_dir_var.set(dir_path)

    def append_log(self, message):
        self.log_text.config(state='normal')
        self.log_text.insert(tk.END, message)
        self.log_text.see(tk.END)
        self.log_text.config(state='disabled')

    def start_fetching(self):
        ip = self.ip_var.get().strip()
        start = self.start_var.get().strip()
        end = self.end_var.get().strip()
        
        if not ip or not start or not end:
            messagebox.showerror("错误", "IP地址和开始/结束日期不能为空！")
            return
            
        self.run_btn.config(state=tk.DISABLED, bg="#A5D6A7", text="⏳ 正在抓取中...")
        self.log_text.config(state='normal')
        self.log_text.delete(1.0, tk.END)
        self.log_text.config(state='disabled')
        
        # Start a new thread to prevent GUI freezing
        threading.Thread(target=self.run_script_thread, daemon=True).start()

    def run_script_thread(self):
        # Build the command arguments to call our original log_fetcher.py
        method = self.method_var.get()
        cmd = [
            sys.executable, "log_fetcher.py",
            self.ip_var.get().strip(),
            "--start", self.start_var.get().strip(),
            "--end", self.end_var.get().strip(),
            "--method", method,
            "--local-dir", self.local_dir_var.get().strip()
        ]
        
        # Add dynamic arguments based on selected method
        user = self.user_var.get().strip()
        pwd = self.pwd_var.get()
        remote_dir = self.remote_dir_var.get().strip()

        if method == "telnet":
            cmd.extend(["--user", user])
            cmd.extend(["--remote-dir", remote_dir])
            if pwd:
                cmd.extend(["--password", pwd])
        else: # ftp
            # Still provide telnet credentials in case it falls back
            cmd.extend(["--user", "root"]) 
            cmd.extend(["--remote-dir", "/root/mnt/programs/log"])
            
            cmd.extend(["--ftp-user", user])
            cmd.extend(["--ftp-dir", remote_dir])
            if pwd:
                cmd.extend(["--ftp-password", pwd])

        # Create a display-safe command string (hide passwords)
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

        self.root.after(0, self.append_log, f"==================================================\n")
        self.root.after(0, self.append_log, f"启动抓取任务: {' '.join(display_cmd)}\n")
        self.root.after(0, self.append_log, f"==================================================\n\n")

        try:
            # Set unbuffered output environment variable to ensure real-time streaming
            env = os.environ.copy()
            env["PYTHONUNBUFFERED"] = "1"

            # Create process with CREATE_NO_WINDOW on Windows to avoid flashing cmd windows
            creationflags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
            
            process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                env=env,
                creationflags=creationflags
            )

            # Stream output line by line
            for line in iter(process.stdout.readline, ''):
                self.root.after(0, self.append_log, line)
                
            process.stdout.close()
            process.wait()
            
            if process.returncode == 0:
                self.root.after(0, self.append_log, f"\n[✅ 任务执行成功，退出码: {process.returncode}]\n")
            else:
                self.root.after(0, self.append_log, f"\n[❌ 任务执行异常，退出码: {process.returncode}]\n")
            
        except Exception as e:
            self.root.after(0, self.append_log, f"\n[❌ 启动运行环境出错: {e}]\n")
            
        finally:
            # Restore button state
            self.root.after(0, lambda: self.run_btn.config(state=tk.NORMAL, bg="#4CAF50", text="▶ 开始抓取日志 (Fetch Logs)"))

if __name__ == "__main__":
    root = tk.Tk()
    app = LogFetcherGUI(root)
    root.mainloop()
