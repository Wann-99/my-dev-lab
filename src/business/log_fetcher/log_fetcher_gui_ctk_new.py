import rio
import os
import sys
import json
import asyncio
import ftplib
import telnetlib
import subprocess
from datetime import datetime

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
CONFIG_FILE = os.path.join(BASE_DIR, "main", "log_fetcher_config.json")
SCRIPT_FILE = os.path.join(BASE_DIR, "main", "log_fetcher.py")

# Colors based on the user's reference image
C_BG = rio.Color.from_hex("#1B263B")         # Deep blue background
C_CARD = rio.Color.from_hex("#252E42")       # Dark blue-grey for cards
C_INPUT_BG = rio.Color.from_hex("#1E2536")   # Darker background for inputs
C_TITLE_YELLOW = rio.Color.from_hex("#FFD166") # Bright yellow for main title
C_ICON_CYAN = rio.Color.from_hex("#4CC9F0")  # Bright cyan for card titles/icons
C_TEXT_PRIMARY = rio.Color.from_hex("#E2E8F0")
C_TEXT_MUTED = rio.Color.from_hex("#94A3B8")
C_DIVIDER = rio.Color.from_hex("#334155")

C_BTN_GREEN = rio.Color.from_hex("#06D6A0")  # Connect
C_BTN_RED = rio.Color.from_hex("#EF476F")    # Disconnect
C_BTN_CYAN = rio.Color.from_hex("#118AB2")   # Fetch (Forward)
C_BTN_ORANGE = rio.Color.from_hex("#D97706") # Fetch (Backward - not used but for palette)
C_BTN_GRAY = rio.Color.from_hex("#475569")   # Browse

C_CONSOLE_BG = rio.Color.from_hex("#1A202C")
C_CONSOLE_GREEN = rio.Color.from_hex("#00FF66")

class SectionTitle(rio.Component):
    icon: str
    text: str

    def build(self) -> rio.Component:
        return rio.Column(
            rio.Row(
                rio.Icon(icon=self.icon, fill=C_ICON_CYAN, min_width=1.5, min_height=1.5),
                rio.Text(self.text, style=rio.TextStyle(font_weight="bold", font_size=1.2, fill=C_ICON_CYAN)),
                spacing=0.5,
                margin_left=1.0,
                margin_top=1.0
            ),
            rio.Rectangle(
                fill=C_DIVIDER,
                min_height=0.1,
                margin_x=1.0,
                margin_top=0.5,
                margin_bottom=1.0
            )
        )

class CustomInput(rio.Component):
    label: str
    text: str
    on_change: object
    is_secret: bool = False

    def build(self) -> rio.Component:
        return rio.Column(
            rio.Text(self.label, style=rio.TextStyle(font_size=0.9, fill=C_ICON_CYAN)),
            # Remove "underlined" style to make it a filled box like the reference
            rio.TextInput(
                text=self.text,
                on_change=self.on_change,
                is_secret=self.is_secret,
            ),
            spacing=0.2,
            margin_bottom=0.8
        )

class LogFetcherApp(rio.Component):
    ip_address: str = "192.168.3.102"
    method: str = "ftp"
    username: str = "qnxuser"
    password: str = ""
    remote_dir: str = "/programs/log"
    local_dir: str = "./logs"
    keyword: str = "RobotControlApp"
    start_date: str = ""
    end_date: str = ""
    
    console_output: str = "[15:06:51] 正在初始化...\n[15:06:51] 远程日志抓取控制台已启动，等待连接设备。\n"
    is_logged_in: bool = False
    is_fetching: bool = False
    is_connecting: bool = False
    
    ip_history: list[str] = ["192.168.3.102"]
    user_history: list[str] = ["qnxuser", "root"]

    _login_task: asyncio.Task | None = None
    _cancel_login_flag: bool = False

    def _rio_post_init(self):
        self._load_config()

    def _load_config(self):
        if os.path.exists(CONFIG_FILE):
            try:
                with open(CONFIG_FILE, "r", encoding="utf-8") as f:
                    config = json.load(f)
                    self.ip_history = config.get("ip_history", ["192.168.3.102"])
                    self.user_history = config.get("user_history", ["qnxuser", "root"])
                    self.local_dir = config.get("last_local_dir", "./logs")
                    self.keyword = config.get("last_keyword", "RobotControlApp")
                    if self.ip_history:
                        self.ip_address = self.ip_history[0]
                    if self.user_history:
                        self.username = self.user_history[0]
            except:
                pass
        self.start_date = datetime.today().strftime("%Y-%m-%d")
        self.end_date = datetime.today().strftime("%Y-%m-%d")

    def _save_config(self):
        if self.ip_address and self.ip_address not in self.ip_history:
            self.ip_history.insert(0, self.ip_address)
            self.ip_history = self.ip_history[:5]
        if self.username and self.username not in self.user_history:
            self.user_history.insert(0, self.username)
            self.user_history = self.user_history[:5]
            
        config = {
            "ip_history": self.ip_history,
            "user_history": self.user_history,
            "last_local_dir": self.local_dir,
            "last_keyword": self.keyword
        }
        os.makedirs(os.path.dirname(CONFIG_FILE), exist_ok=True)
        try:
            with open(CONFIG_FILE, "w", encoding="utf-8") as f:
                json.dump(config, f, ensure_ascii=False, indent=2)
        except:
            pass

    async def on_login(self):
        self.is_connecting = True
        self.is_logged_in = False
        self._cancel_login_flag = False
        self._append_log(f"正在连接 {self.ip_address}...")
        
        loop = asyncio.get_running_loop()
        async def _run_sync():
            return await loop.run_in_executor(None, self._sync_login)
        self._login_task = asyncio.create_task(_run_sync())
        
        try:
            ok, msg = await self._login_task
            if self._cancel_login_flag:
                return

            if ok:
                self.is_logged_in = True
                self._append_log(f"✅ 登录成功: {self.method.upper()} {self.username}@{self.ip_address}")
                self._save_config()
            else:
                self.is_logged_in = False
                self._append_log(f"❌ 登录失败: {msg}")
        except asyncio.CancelledError:
            pass
        finally:
            self.is_connecting = False
            self._login_task = None

    async def on_cancel_login(self):
        if self.is_connecting and self._login_task:
            self._cancel_login_flag = True
            self._login_task.cancel()
            self._append_log("⚠️ 用户手动断开/停止了连接")
            self.is_connecting = False
            self.is_logged_in = False
        elif self.is_logged_in:
            self.is_logged_in = False
            self._append_log("🔌 已断开设备连接")

    def _sync_login(self):
        try:
            if self.method == "ftp":
                ftp = ftplib.FTP(self.ip_address, timeout=8)
                ftp.login(user=self.username, passwd=self.password)
                if self.remote_dir:
                    ftp.cwd(self.remote_dir)
                ftp.quit()
                return True, ""
            else:
                import time
                tn = telnetlib.Telnet(self.ip_address, 23, timeout=8)
                tn.read_until(b"login: ", timeout=5)
                tn.write(self.username.encode("ascii", errors="ignore") + b"\n")
                if self.password:
                    tn.read_until(b"Password: ", timeout=5)
                    tn.write(self.password.encode("ascii", errors="ignore") + b"\n")
                time.sleep(0.8)
                tn.write(b"\n")
                time.sleep(0.8)
                output = tn.read_very_eager()
                tn.write(b"exit\n")
                tn.close()
                if b"#" in output or b"$" in output:
                    return True, ""
                else:
                    return False, "Telnet 登录失败：未识别到命令提示符"
        except Exception as e:
            return False, str(e)

    async def on_fetch(self):
        if not self.is_logged_in:
            self._append_log("错误: 请先连接设备！")
            return
        
        self.is_fetching = True
        self._append_log("=====================================")
        self._append_log("开始执行日志抓取任务...")
        self._append_log("=====================================\n")
        
        self._save_config()
        
        cmd = [
            sys.executable, SCRIPT_FILE,
            self.ip_address,
            "--start", self.start_date,
            "--end", self.end_date,
            "--method", self.method,
            "--local-dir", self.local_dir
        ]
        if self.keyword:
            cmd.extend(["--keyword", self.keyword])
        
        if self.method == "telnet":
            cmd.extend(["--user", self.username, "--remote-dir", self.remote_dir])
            if self.password:
                cmd.extend(["--password", self.password])
        else:
            cmd.extend(["--ftp-user", self.username, "--ftp-dir", self.remote_dir])
            if self.password:
                cmd.extend(["--ftp-password", self.password])

        try:
            creationflags = subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                creationflags=creationflags
            )

            while True:
                line = await process.stdout.readline()
                if not line:
                    break
                self.console_output += line.decode("utf-8", errors="ignore")
                await asyncio.sleep(0.01)

            await process.wait()
            if process.returncode == 0:
                self._append_log(f"\n✅ 任务执行成功，退出码: {process.returncode}")
            else:
                self._append_log(f"\n❌ 任务执行异常，退出码: {process.returncode}")
        except Exception as e:
            self._append_log(f"\n❌ 启动运行环境出错: {e}")
        finally:
            self.is_fetching = False

    async def on_browse_local(self):
        loop = asyncio.get_running_loop()
        def _ask():
            import tkinter as tk
            from tkinter import filedialog
            root = tk.Tk()
            root.attributes("-topmost", True)
            root.withdraw()
            d = filedialog.askdirectory(initialdir=self.local_dir, title="选择本地保存目录")
            root.destroy()
            return d
            
        d = await loop.run_in_executor(None, _ask)
        if d:
            self.local_dir = d

    def _append_log(self, msg: str):
        now = datetime.now().strftime("%H:%M:%S")
        self.console_output += f"[{now}] {msg}\n"

    def on_ip_change(self, e): self.ip_address = e.text
    def on_user_change(self, e): self.username = e.text
    def on_pwd_change(self, e): self.password = e.text
    def on_keyword_change(self, e): self.keyword = e.text
    def on_start_change(self, e): self.start_date = e.text
    def on_end_change(self, e): self.end_date = e.text
    def on_remote_change(self, e): self.remote_dir = e.text
    def on_local_change(self, e): self.local_dir = e.text

    def on_method_change(self, e):
        self.method = e.value
        if self.method == "ftp":
            if self.username == "root": self.username = "qnxuser"
            if self.remote_dir == "/root/mnt/programs/log": self.remote_dir = "/programs/log"
        else:
            if self.username == "qnxuser": self.username = "root"
            if self.remote_dir == "/programs/log": self.remote_dir = "/root/mnt/programs/log"

    def build(self) -> rio.Component:
        # 1. Main Header
        header_card = rio.Card(
            rio.Column(
                rio.Row(
                    rio.Icon(icon="material/build", fill=C_TITLE_YELLOW, min_width=3.0, min_height=3.0),
                    rio.Text("远程日志抓取调试助手", style=rio.TextStyle(font_size=2.2, font_weight="bold", fill=C_TITLE_YELLOW)),
                    spacing=1.0,
                    align_x=0.5
                ),
                rio.Text("基于 FTP / Telnet 的设备日志调试控制台", style=rio.TextStyle(fill=C_TEXT_PRIMARY, font_size=0.9)),
                spacing=0.8,
                margin=2.0,
                align_x=0.5
            ),
            corner_radius=0.5,
            color=C_CARD,
            margin_bottom=2.0
        )

        # 2. Left Column: Connection
        connect_buttons = rio.Row(
            rio.Button(
                "🔗 连接设备" if not self.is_connecting else "连接中...", 
                on_press=self.on_login, 
                color=C_BTN_GREEN, 
                is_loading=self.is_connecting,
                is_sensitive=not self.is_logged_in and not self.is_fetching
            ),
            rio.Button(
                "🔌 断开连接" if self.is_logged_in else "取消连接", 
                on_press=self.on_cancel_login, 
                color=C_BTN_RED,
                is_sensitive=self.is_logged_in or self.is_connecting
            ),
            spacing=1.0,
            proportions=(1, 1),
            margin_x=1.0,
            margin_bottom=1.5
        )

        connect_card = rio.Card(
            rio.Column(
                SectionTitle(icon="material/power", text="设备连接设置"),
                rio.Column(
                    CustomInput("IP 地址", self.ip_address, self.on_ip_change),
                    rio.Column(
                        rio.Text("连接方式", style=rio.TextStyle(font_size=0.9, fill=C_ICON_CYAN)),
                        rio.Dropdown(options=["ftp", "telnet"], selected_value=self.method, on_change=self.on_method_change),
                        spacing=0.2,
                        margin_bottom=0.8
                    ),
                    CustomInput("用户名", self.username, self.on_user_change),
                    CustomInput("密码", self.password, self.on_pwd_change, is_secret=True),
                    margin_x=1.0,
                    margin_bottom=1.0
                ),
                connect_buttons,
                spacing=0.5
            ),
            corner_radius=0.5,
            color=C_CARD
        )

        # 3. Left Column: Fetch Config
        fetch_buttons = rio.Row(
            rio.Button(
                "▶ 开始抓取" if not self.is_fetching else "抓取中...", 
                on_press=self.on_fetch, 
                color=C_BTN_CYAN,
                is_loading=self.is_fetching,
                is_sensitive=self.is_logged_in
            ),
            spacing=1.0,
            margin_x=1.0,
            margin_bottom=1.5
        )

        settings_card = rio.Card(
            rio.Column(
                SectionTitle(icon="material/settings", text="抓取参数控制"),
                rio.Column(
                    CustomInput("关键字 (留空则匹配全部)", self.keyword, self.on_keyword_change),
                    rio.Row(
                        CustomInput("开始日期", self.start_date, self.on_start_change),
                        CustomInput("结束日期", self.end_date, self.on_end_change),
                        spacing=1.0,
                        proportions=(1, 1)
                    ),
                    CustomInput("远程目录", self.remote_dir, self.on_remote_change),
                    rio.Column(
                        rio.Text("本地保存目录", style=rio.TextStyle(font_size=0.9, fill=C_ICON_CYAN)),
                        rio.Row(
                            rio.TextInput(text=self.local_dir, on_change=self.on_local_change),
                            rio.Button("浏览", on_press=self.on_browse_local, color=C_BTN_GRAY),
                            spacing=1.0,
                            proportions=(1, 0)
                        ),
                        spacing=0.2,
                        margin_bottom=0.8
                    ),
                    margin_x=1.0,
                    margin_bottom=1.0
                ),
                fetch_buttons,
                spacing=0.5
            ),
            corner_radius=0.5,
            color=C_CARD
        )

        # 4. Right Column: Status
        status_text = "已连接" if self.is_logged_in else ("连接中" if self.is_connecting else "离线")
        status_color = C_BTN_GREEN if self.is_logged_in else (C_TITLE_YELLOW if self.is_connecting else C_TEXT_MUTED)

        status_card = rio.Card(
            rio.Column(
                SectionTitle(icon="material/favorite", text="状态指示"),
                rio.Column(
                    rio.Card(
                        rio.Text(status_text, style=rio.TextStyle(font_weight="bold", fill=status_color)),
                        color=C_INPUT_BG,
                        corner_radius=6.0,
                        min_width=12.0,
                        min_height=12.0,
                        align_x=0.5,
                        align_y=0.5
                    ),
                    rio.Text(
                        f"设备{status_text}", 
                        style=rio.TextStyle(font_size=1.2, font_weight="bold", fill=C_TEXT_PRIMARY),
                        align_x=0.5,
                        margin_top=1.5
                    ),
                    margin_bottom=2.0
                ),
                spacing=1.0
            ),
            corner_radius=0.5,
            color=C_CARD
        )

        # 5. Right Column: Console
        # Use grow_y=True to make it stretch to the bottom of the right column
        console_card = rio.Card(
            rio.Column(
                SectionTitle(icon="material/terminal", text="通讯日志"),
                rio.Card(
                    rio.ScrollContainer(
                        rio.Text(self.console_output, style=rio.TextStyle(font=rio.Font.ROBOTO_MONO, fill=C_CONSOLE_GREEN, font_size=0.85), justify="left"),
                        sticky_bottom=True,
                    ),
                    color=C_CONSOLE_BG,
                    corner_radius=0.3,
                    margin_x=1.0,
                    margin_bottom=1.0,
                    grow_y=True
                ),
                grow_y=True
            ),
            corner_radius=0.5,
            color=C_CARD,
            grow_y=True
        )

        # Assemble layout
        left_column = rio.Column(
            connect_card,
            settings_card,
            spacing=2.0
        )

        right_column = rio.Column(
            status_card,
            console_card,
            spacing=2.0,
            grow_y=True
        )

        main_content = rio.Column(
            header_card,
            rio.Row(
                left_column,
                right_column,
                spacing=2.0,
                proportions=(1, 1),
                grow_y=True
            ),
            spacing=0,
            margin=3.0,
            align_x=0.5,
            grow_y=True
        )

        return rio.Rectangle(
            fill=C_BG,
            content=rio.Row(
                rio.Spacer(),
                main_content,
                rio.Spacer(),
                proportions=(1, 12, 1)
            )
        )

theme = rio.Theme.from_colors(
    primary_color=C_ICON_CYAN,
    background_color=C_BG,
    neutral_color=C_INPUT_BG, # This controls TextInput default background
    text_color=C_TEXT_PRIMARY,
    corner_radius_small=0.3,
    corner_radius_medium=0.5,
    corner_radius_large=1.0,
    mode="dark"
)

app = rio.App(name="Log Fetcher", build=LogFetcherApp, theme=theme)

if __name__ == "__main__":
    app.run_in_browser()
