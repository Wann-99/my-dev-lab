import ttkbootstrap as ttk
from ttkbootstrap.constants import *
import tkinter as tk
from tkinter import filedialog, simpledialog
import os


class ListManagerFrame(ttk.Labelframe):
    """
    通用列表管理组件 (UI 优化 + 连续添加模式)
    """

    def __init__(self, parent, title, mode='mixed', need_dest=False, **kwargs):
        super().__init__(parent, text=title, padding=15, **kwargs)
        self.mode = mode
        self.need_dest = need_dest
        self.items = []

        # 样式配置
        style = ttk.Style()
        style.configure("Treeview", rowheight=28, font=("", 9))
        style.configure("Treeview.Heading", font=("", 9, "bold"))

        # --- 按钮区 ---
        btn_frame = ttk.Frame(self)
        btn_frame.pack(side=RIGHT, fill=Y, padx=(10, 0))

        btn_width = 10
        if self.mode == 'mixed':
            # 【修改】名称简化，但功能增强
            ttk.Button(btn_frame, text="📄 文件", command=self._add_files, bootstyle="info-outline",
                       width=btn_width).pack(pady=3)
            ttk.Button(btn_frame, text="📂 文件夹", command=self._add_folders_continuous, bootstyle="info-outline",
                       width=btn_width).pack(pady=3)
        else:
            ttk.Button(btn_frame, text="➕ 添加", command=self._add_text, bootstyle="info-outline",
                       width=btn_width).pack(pady=3)

        ttk.Separator(btn_frame, orient=HORIZONTAL).pack(fill=X, pady=10)
        ttk.Button(btn_frame, text="✏️ 修改", command=self._edit_selected, bootstyle="secondary-outline",
                   width=btn_width).pack(pady=3)
        ttk.Button(btn_frame, text="🗑️ 删除", command=self._del_item, bootstyle="danger-outline", width=btn_width).pack(
            pady=3)
        ttk.Button(btn_frame, text="🧹 清空", command=self._clear_items, bootstyle="link", width=btn_width).pack(
            pady=(10, 0))

        # --- 列表区 ---
        tree_container = ttk.Frame(self)
        tree_container.pack(side=LEFT, fill=BOTH, expand=YES)

        self.tree = ttk.Treeview(tree_container, show="headings", selectmode="extended", bootstyle="primary")

        vsb = ttk.Scrollbar(tree_container, orient="vertical", command=self.tree.yview, bootstyle="rounded")
        hsb = ttk.Scrollbar(tree_container, orient="horizontal", command=self.tree.xview, bootstyle="rounded")
        self.tree.configure(yscrollcommand=vsb.set, xscrollcommand=hsb.set)

        if self.need_dest:
            self.tree["columns"] = ("source", "dest")
            self.tree.heading("source", text="源路径 (Source)", anchor=W)
            self.tree.heading("dest", text="目标路径 (Dest)", anchor=W)
            self.tree.column("source", width=300, minwidth=150)
            self.tree.column("dest", width=150, minwidth=100)
        else:
            self.tree["columns"] = ("value")
            self.tree.heading("value", text="值", anchor=W)
            self.tree.column("value", width=450, minwidth=200)

        self.tree.bind("<Double-1>", self._on_double_click)

        vsb.pack(side=RIGHT, fill=Y)
        hsb.pack(side=BOTTOM, fill=X)
        self.tree.pack(side=LEFT, fill=BOTH, expand=YES)

    def _add_files(self):
        """文件多选模式：原生支持一次框选多个"""
        paths = filedialog.askopenfilenames(title="选择文件 (支持多选)")
        if paths:
            for path in paths:
                self._process_input(path)

    def _add_folders_continuous(self):
        """
        文件夹连续模式：
        由于操作系统限制无法在同一个窗口多选文件夹，
        这里采用'循环弹出'的方式，直到用户点击取消。
        """
        first_time = True
        while True:
            title = "选择文件夹 (循环添加模式 - 点击取消停止)" if not first_time else "选择文件夹"
            path = filedialog.askdirectory(title=title)

            if not path:
                # 用户点击了取消或关闭，结束循环
                break

            # 添加选中的文件夹
            self._process_input(path)
            first_time = False

            # 这里不加 sleep，直接弹出下一个，效率最高
            # 用户体验：选完 -> 确定 -> 还没等喘气 -> 下一个选择框来了

    def _add_text(self):
        val = simpledialog.askstring("添加", "请输入内容:")
        if val: self._process_input(val)

    def _process_input(self, val1):
        """处理输入并去重"""
        # 简单查重
        for item in self.items:
            # 如果是列表结构（资源模式），比对源路径 item[0]
            if isinstance(item, list) and item[0] == val1:
                return
            # 如果是文本结构（导入模式），比对值 item
            if isinstance(item, str) and item == val1:
                return

        if self.need_dest:
            val2 = os.path.basename(val1)
            self.items.append([val1, val2])
            self.tree.insert("", END, values=(val1, val2))
        else:
            self.items.append(val1)
            self.tree.insert("", END, values=(val1,))

    def _del_item(self):
        """支持批量删除"""
        selected_items = self.tree.selection()
        if not selected_items: return

        # 倒序删除以防索引偏移
        for item_id in reversed(selected_items):
            idx = self.tree.index(item_id)
            self.tree.delete(item_id)
            del self.items[idx]

    def _edit_selected(self):
        selected = self.tree.selection()
        if not selected: return
        # 只编辑第一个选中的
        item_vals = self.tree.item(selected[0], "values")
        idx = self.tree.index(selected[0])

        if self.need_dest:
            new_dest = simpledialog.askstring("修改", f"修改目标路径:\n{os.path.basename(item_vals[0])}",
                                              initialvalue=item_vals[1])
            if new_dest:
                self.items[idx][1] = new_dest
                self.tree.item(selected[0], values=(item_vals[0], new_dest))
        else:
            new_val = simpledialog.askstring("修改", "修改值:", initialvalue=item_vals[0])
            if new_val:
                self.items[idx] = new_val
                self.tree.item(selected[0], values=(new_val,))

    def _clear_items(self):
        for item in self.tree.get_children():
            self.tree.delete(item)
        self.items = []

    def _on_double_click(self, event):
        region = self.tree.identify("region", event.x, event.y)
        if region != "cell": return
        column = self.tree.identify_column(event.x)
        selected_id = self.tree.selection()[0]
        idx = self.tree.index(selected_id)

        target_col_idx = 1 if self.need_dest and column == "#2" else (
            0 if not self.need_dest and column == "#1" else -1)
        if target_col_idx == -1: return

        x, y, width, height = self.tree.bbox(selected_id, column)
        current_value = self.tree.item(selected_id, "values")[target_col_idx]

        entry = ttk.Entry(self.tree, width=width, bootstyle="info")
        entry.place(x=x, y=y, width=width, height=height)
        entry.insert(0, current_value)
        entry.focus()

        def save_edit(event):
            new_value = entry.get()
            current_vals = list(self.tree.item(selected_id, "values"))
            current_vals[target_col_idx] = new_value
            self.tree.item(selected_id, values=current_vals)
            if self.need_dest:
                self.items[idx][target_col_idx] = new_value
            else:
                self.items[idx] = new_value
            entry.destroy()

        entry.bind("<Return>", save_edit)
        entry.bind("<FocusOut>", save_edit)

    def get_data(self):
        if self.need_dest: return [tuple(x) for x in self.items]
        return self.items