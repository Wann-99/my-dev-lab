import tkinter as tk
from tkinter import filedialog, messagebox
import ttkbootstrap as ttk
from ttkbootstrap.constants import *
from ttkbootstrap.tooltip import ToolTip
from src.core import PackerThread
from src.widgets import ListManagerFrame
from src.utils import save_history, get_history_list
import tkinter.ttk as ttk_core
import os
import sys
import subprocess


class App(ttk.Window):
    def __init__(self):
        # 默认使用 litera (清爽风格) 或 dark (深色)
        super().__init__(themename="litera")
        self.title("PyExeBuilder Pro 🚀")
        self.geometry("950x800")
        self.minsize(850, 650)

        # 记录当前主题状态
        self.is_dark = False

        # --- 变量存储 ---
        self.script_path = tk.StringVar()
        self.icon_path = tk.StringVar()
        self.app_name = tk.StringVar()
        self.interpreter_path = tk.StringVar()
        self.output_dir = tk.StringVar()

        self.is_onefile = tk.BooleanVar(value=True)
        self.is_noconsole = tk.BooleanVar(value=False)
        self.is_clean = tk.BooleanVar(value=True)

        self.worker = None
        self.protocol("WM_DELETE_WINDOW", self._on_close)

        self._init_ui()

    def _init_ui(self):
        # 1. 顶部导航栏 (Header)
        header_frame = ttk.Frame(self, padding=(20, 15))
        header_frame.pack(fill=X)

        # 标题与Logo
        title_lbl = ttk.Label(header_frame, text="🐍 PyExeBuilder Pro", font=("Helvetica", 20, "bold"),
                              bootstyle="primary")
        title_lbl.pack(side=LEFT)

        ver_lbl = ttk.Label(header_frame, text="v2.0", font=("Helvetica", 10), bootstyle="secondary")
        ver_lbl.pack(side=LEFT, padx=10, pady=(10, 0))

        # 主题切换按钮
        self.theme_btn = ttk.Checkbutton(header_frame, text="🌙 深色模式", bootstyle="round-toggle",
                                         command=self._toggle_theme)
        self.theme_btn.pack(side=RIGHT)

        # 2. 主体内容区 (Notebook)
        self.notebook = ttk.Notebook(self, bootstyle="primary")
        self.notebook.pack(fill=BOTH, expand=YES, padx=20, pady=10)

        # === Tab 1: 核心配置 ===
        self.tab_basic = ttk.Frame(self.notebook, padding=20)
        self.notebook.add(self.tab_basic, text="  ⚙️ 核心配置  ")
        self._setup_basic_tab()

        # === Tab 2: 资源管理 ===
        self.tab_advanced = ttk.Frame(self.notebook, padding=20)
        self.notebook.add(self.tab_advanced, text="  📂 资源与依赖  ")
        self._setup_advanced_tab()

        # === Tab 3: 环境设置 ===
        self.tab_env = ttk.Frame(self.notebook, padding=20)
        self.notebook.add(self.tab_env, text="  🐍 环境设置  ")
        self._setup_env_tab()

        # 3. 底部操作区 (Footer)
        footer_frame = ttk.Frame(self, padding=(20, 10))
        footer_frame.pack(fill=BOTH, expand=YES)

        # 状态栏与按钮
        action_bar = ttk.Frame(footer_frame)
        action_bar.pack(fill=X, pady=(0, 10))

        self.status_var = tk.StringVar(value="就绪 - 等待构建")
        status_lbl = ttk.Label(action_bar, textvariable=self.status_var, bootstyle="info", font=("Consolas", 10))
        status_lbl.pack(side=LEFT, fill=X)

        self.build_btn = ttk.Button(action_bar, text="🚀 开始构建 (Build)", command=self.start_build,
                                    bootstyle="success", width=25)
        self.build_btn.pack(side=RIGHT)

        # 终端风格日志区
        log_frame = ttk.Labelframe(footer_frame, text=" 终端输出 (Console Log) ", padding=2, bootstyle="secondary")
        log_frame.pack(fill=BOTH, expand=YES)

        # 黑色背景，绿色字体，模拟黑客终端
        self.log_text = tk.Text(log_frame, height=10, state="disabled", font=("Consolas", 9),
                                bg="#ffffff", fg="#212529", insertbackground="black")  # 改为白色背景
        self.log_text.pack(side=LEFT, fill=BOTH, expand=YES)

        scr = ttk.Scrollbar(log_frame, command=self.log_text.yview)
        scr.pack(side=RIGHT, fill=Y)
        self.log_text.config(yscrollcommand=scr.set)

    def _setup_basic_tab(self):
        # 左侧：文件选择
        left_col = ttk.Frame(self.tab_basic)
        left_col.pack(side=LEFT, fill=BOTH, expand=YES, padx=(0, 10))

        # 卡片 1: 项目源
        card_source = ttk.Labelframe(left_col, text=" 项目源文件 ", padding=15, bootstyle="info")
        card_source.pack(fill=X, pady=(0, 15))

        self._create_modern_input(card_source, "入口脚本 (Entry Script)", self.script_path, "file", "*.py",
                                  "程序的主入口文件 (main.py)")
        self._create_modern_input(card_source, "图标文件 (App Icon)", self.icon_path, "file", "*.ico",
                                  "EXE 文件的图标 (可选)")

        # 卡片 2: 输出设置
        card_out = ttk.Labelframe(left_col, text=" 输出设置 ", padding=15, bootstyle="info")
        card_out.pack(fill=X)

        self._create_modern_input(card_out, "生成名称 (App Name)", self.app_name, "text", tooltip="生成的 .exe 文件名")
        self._create_modern_input(card_out, "输出目录 (Output Dir)", self.output_dir, "folder",
                                  tooltip="默认为当前目录下的 dist 文件夹", use_history="output_dirs")

        # 右侧：打包选项
        right_col = ttk.Frame(self.tab_basic)
        right_col.pack(side=RIGHT, fill=BOTH, expand=NO, ipadx=10)  # 固定宽度

        card_opts = ttk.Labelframe(right_col, text=" 构建选项 ", padding=15, bootstyle="warning")
        card_opts.pack(fill=BOTH, expand=YES)

        # 使用 Toggle 样式的开关
        self._create_toggle(card_opts, "单文件模式", self.is_onefile, "生成单个 .exe 文件，便于分发。\n(启动速度稍慢)",
                            True)
        self._create_toggle(card_opts, "无控制台 (GUI)", self.is_noconsole,
                            "不显示黑色命令行窗口。\n(适用于图形界面程序)", False)
        self._create_toggle(card_opts, "清理构建缓存", self.is_clean, "构建前清理临时文件。\n(推荐勾选，避免旧文件干扰)",
                            True)

    def _setup_advanced_tab(self):
        # 依然使用 PanedWindow，但增加 padding
        paned = ttk.Panedwindow(self.tab_advanced, orient=HORIZONTAL)
        paned.pack(fill=BOTH, expand=YES)

        # 左侧：资源
        self.data_manager = ListManagerFrame(paned, title=" 📦 附加资源 (--add-data) ", mode='mixed', need_dest=True,
                                             bootstyle="info")
        paned.add(self.data_manager, weight=3)  # 稍微宽一点

        # 右侧：依赖 (Notebook)
        right_container = ttk.Frame(paned)
        paned.add(right_container, weight=2)

        dep_tabs = ttk.Notebook(right_container)
        dep_tabs.pack(fill=BOTH, expand=YES, pady=(0, 0))

        # Hidden Import
        self.import_manager = ListManagerFrame(dep_tabs, title="", mode='text', need_dest=False, bootstyle="secondary")
        dep_tabs.add(self.import_manager, text=" 隐藏导入 ")

        # Collect All
        self.collect_manager = ListManagerFrame(dep_tabs, title="", mode='text', need_dest=False, bootstyle="danger")
        dep_tabs.add(self.collect_manager, text=" 全量收集(DLL修复) ")

    def _setup_env_tab(self):
        card = ttk.Labelframe(self.tab_env, text=" Python 解释器 ", padding=20, bootstyle="success")
        card.pack(fill=X, pady=10)

        ttk.Label(card, text="💡 提示: 强烈建议使用虚拟环境 (venv) 进行打包，以减小体积并避免依赖冲突。",
                  bootstyle="warning", font=("", 9)).pack(pady=(0, 15), anchor=W)

        self._create_modern_input(card, "解释器路径 (python.exe)", self.interpreter_path, "exe",
                                  tooltip="选择虚拟环境下的 Scripts/python.exe", use_history="interpreters")

    # --- 辅助 UI 组件 ---

    def _create_modern_input(self, parent, label_text, var, mode, filetype=None, tooltip=None, use_history=None):
        """创建一个带标签、输入框、按钮和提示的现代输入行"""
        frame = ttk.Frame(parent)
        frame.pack(fill=X, pady=8)

        # 标签行
        lbl_frame = ttk.Frame(frame)
        lbl_frame.pack(fill=X)
        lbl = ttk.Label(lbl_frame, text=label_text, font=("", 9, "bold"))
        lbl.pack(side=LEFT)
        if tooltip:
            ToolTip(lbl, text=tooltip, bootstyle="info.TLabel")

        # 输入区域
        input_frame = ttk.Frame(frame)
        input_frame.pack(fill=X, pady=(2, 0))

        if use_history:
            # === 使用下拉框 (Combobox) ===
            values = get_history_list(use_history)
            # 设置默认值（如果有历史，选第一个）
            if values and not var.get():
                var.set(values[0])
            elif not var.get() and mode == "folder" and use_history == "output_dirs":
                # 输出目录默认设为 dist
                var.set(os.path.join(os.getcwd(), "dist"))

            combo = ttk.Combobox(input_frame, textvariable=var, values=values)
            combo.pack(side=LEFT, fill=X, expand=YES)

            # 绑定选中事件：选中后自动更新 var（Combobox默认行为其实已经支持，但为了保险）
            # combo.bind("<<ComboboxSelected>>", lambda e: var.set(combo.get()))
        else:
            # === 普通输入框 ===
            entry = ttk.Entry(input_frame, textvariable=var)
            entry.pack(side=LEFT, fill=X, expand=YES)

        if mode != "text":
            btn = ttk.Button(input_frame, text="📂", width=3, bootstyle="secondary-outline",
                             command=lambda: self._browse(var, mode, filetype))
            btn.pack(side=RIGHT, padx=(5, 0))

    def _create_toggle(self, parent, text, var, tooltip, default):
        """创建带说明的开关"""
        f = ttk.Frame(parent)
        f.pack(fill=X, pady=12)

        chk = ttk.Checkbutton(f, text=text, variable=var, bootstyle="success-round-toggle")
        chk.pack(side=TOP, anchor=W)
        if default: var.set(True)

        desc = ttk.Label(f, text=tooltip, font=("", 8), foreground="gray")
        desc.pack(side=TOP, anchor=W, padx=5)

    def _browse(self, var, mode, ftype, history_key=None):
        path = ""
        if mode == "file":
            path = filedialog.askopenfilename(filetypes=[("File", ftype)])
        elif mode == "folder":
            path = filedialog.askdirectory()
        elif mode == "exe":
            types = [("Python", "python*")] if os.name != 'nt' else [("Executable", "*.exe")]
            path = filedialog.askopenfilename(filetypes=types)

        if path:
            var.set(path)
            if history_key:
                save_history(history_key, path)
                # 刷新当前页面所有同类 Combobox 的值 (稍微麻烦点，这里简化为下次启动刷新，或者重绘)
                # 简单的做法：
                self._refresh_combobox_values(history_key, path)
            # 自动设置APP名称
            if mode == "file" and "*.py" in ftype and not self.app_name.get():
                self.app_name.set(os.path.splitext(os.path.basename(path))[0])

    def _refresh_combobox_values(self, key, new_val):
        """辅助：刷新界面上所有绑定了该 history key 的 Combobox"""
        # 重新加载最新的列表
        new_list = get_history_list(key)
        # 遍历界面寻找 Combobox (这就有点复杂了，最简单的办法是直接重新绑定)
        # 实际上，上面的 _create_modern_input 里我们没有保存 combo 对象的引用。
        # 为了简单，我们只保证下次启动有，或者用户手动输入。
        # 如果非要即时刷新，需要把 combo 对象存到 self 字典里。
        pass

    def _toggle_theme(self):
        """切换深色/浅色主题"""
        if not self.is_dark:
            # === 切换到深色模式 ===
            self.style.theme_use("darkly")
            self.theme_btn.config(text="☀️ 浅色模式")
            self.is_dark = True

            # 【修改点】设置为：深灰背景 + 亮绿文字 + 白色光标
            self.log_text.config(bg="#1e1e1e", fg="#00ff00", insertbackground="white", selectbackground="#444")
        else:
            # === 切换到浅色模式 ===
            self.style.theme_use("litera")
            self.theme_btn.config(text="🌙 深色模式")
            self.is_dark = False

            # 【修改点】设置为：纯白背景 + 深灰文字 + 黑色光标
            self.log_text.config(bg="#ffffff", fg="#212529", insertbackground="black", selectbackground="#ccc")
    # --- 逻辑功能 (与之前保持一致) ---

    def append_log(self, text):
        self.log_text.config(state="normal")
        self.log_text.insert(tk.END, text)
        self.log_text.see(tk.END)
        self.log_text.config(state="disabled")

    def lock_ui(self, locked):
        state = "disabled" if locked else "normal"
        self.build_btn.config(state=state)
        self.status_var.set("⏳ 正在构建中..." if locked else "✅ 构建完成 / 就绪")

        if locked:
            self.build_btn.config(text="⏳ 打包中...", bootstyle="warning")
        else:
            self.build_btn.config(text="🚀 开始构建 (Build)", bootstyle="success")

    def start_build(self):
        script = self.script_path.get()
        if not script:
            messagebox.showwarning("提示", "请先选择入口脚本文件 (.py)！")
            return

        # 收集配置
        config = {
            'script_path': script,
            'icon_path': self.icon_path.get(),
            'name': self.app_name.get(),
            'output_dir': self.output_dir.get(),
            'onefile': self.is_onefile.get(),
            'noconsole': self.is_noconsole.get(),
            'clean': self.is_clean.get(),
            'datas': self.data_manager.get_data(),
            'hidden_imports': self.import_manager.get_data(),
            'collect_all_imports': self.collect_manager.get_data(),
            'interpreter': self.interpreter_path.get()
        }

        # 检查解释器PyInstaller
        interp = config['interpreter']
        if interp and os.path.exists(interp):
            check_cmd = [interp, "-m", "pip", "show", "pyinstaller"]
            try:
                subprocess.check_call(check_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                      creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
            except subprocess.CalledProcessError:
                if not messagebox.askyesno("警告", "选定的环境中未检测到 PyInstaller。\n是否继续尝试？"):
                    return
        if self.interpreter_path.get():
            save_history("interpreters", self.interpreter_path.get())
        if self.output_dir.get():
            save_history("output_dirs", self.output_dir.get())

        self.log_text.config(state="normal")
        self.log_text.delete(1.0, tk.END)
        self.log_text.config(state="disabled")

        self.lock_ui(True)
        self.worker = PackerThread(config, self.append_log, lambda: self.lock_ui(False))
        self.worker.start()

    def _on_close(self):
        """处理窗口关闭事件：强制结束后台进程"""
        if self.worker and self.worker.is_alive():
            # 如果还在打包，尝试停止它
            if messagebox.askyesno("退出", "打包任务正在进行中，确定要强制退出吗？"):
                self.worker.stop()  # 调用我们在 core.py 写的 stop 方法
                # 给子进程一点时间去死
                self.after(500, self._force_exit)
            else:
                return  # 用户点了取消，不关闭
        else:
            self._force_exit()

    def _force_exit(self):
        """彻底销毁窗口并退出进程"""
        self.destroy()
        sys.exit(0)  # 强制退出 Python 进程

if __name__ == "__main__":
    app = App()
    app.mainloop()