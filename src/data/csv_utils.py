import csv
import os
import datetime
import shutil
import re

class DataWriter:
    """
    将数据以 CSV 形式写入指定文件夹，初始化时自动识别最新文件
    - 启动时自动打开文件夹中最新的文件（基于日期+序号）
    - new_file=True 时创建新文件
    - new_file=False 时持续写入当前最新文件
    """
    HEADERS = [
        "时间", "抓取位置", "偏心距离", "负载重量", "实际物料重量",
        "静止时间", "速度", "加速度", "加加速度", "Mx力矩", "My力矩", "测量物料重量"
    ]

    def __init__(self, base_filename=None, overwrite=False):
        # 1. 基础设置
        self.base_filename = base_filename or "data"
        self.folder_name = "data"
        self.current_file = None
        self.writer = None
        self.file_history = []

        # 2. 清理旧数据（如果需要）
        if overwrite and os.path.exists(self.folder_name):
            shutil.rmtree(self.folder_name)
            print(f"已删除旧文件夹: {self.folder_name}")

        os.makedirs(self.folder_name, exist_ok=True)

        # 3. 初始化文件系统（自动查找最新文件）
        self._initialize_files()

    def _initialize_files(self):
        """初始化文件系统：查找最新文件或创建新文件"""
        pattern = re.compile(rf"^{re.escape(self.base_filename)}_(\d{{8}})_(\d+)\.csv$")
        file_list = []
        for filename in os.listdir(self.folder_name):
            full_path = os.path.join(self.folder_name, filename)
            # 修复点1：过滤非文件（如目录），避免将目录当作文件处理
            if not os.path.isfile(full_path):
                continue
            match = pattern.match(filename)
            if match:
                date_str, seq_num = match.groups()
                file_list.append((date_str, int(seq_num), full_path))

        if not file_list:
            # 没有文件，创建新文件
            self.file_counter = 1
            self.create_new_file()
            return

        # 按日期和序号排序（最新文件在最后）
        file_list.sort(key=lambda x: (x[0], x[1]))
        last_file = file_list[-1]
        current_date, current_seq = last_file[0], last_file[1]

        # 检查日期是否变更，若变更则创建新文件
        today = datetime.datetime.now().strftime('%Y%m%d')
        if current_date != today:
            self.file_counter = 1
            self.create_new_file()
        else:
            self.file_counter = current_seq + 1
            self.current_filename = last_file[2]
            self._open_current_file()
            # 修复点2：将启动时打开的现有文件添加到历史记录
            self.file_history.append(self.current_filename)

    def _open_current_file(self):
        """打开当前文件"""
        self.current_file = open(self.current_filename, 'a', newline='', encoding='utf-8')
        self.writer = csv.writer(self.current_file)
        # 修复点3：若文件为空（如原文件被删除后重新创建），补充表头
        if os.stat(self.current_filename).st_size == 0:
            self.writer.writerow(self.HEADERS)
            self.current_file.flush()
        print(f"已打开最新文件: {self.current_filename}")

    def _generate_filename(self):
        """生成带序号的文件名"""
        date_str = datetime.datetime.now().strftime('%Y%m%d')
        return os.path.join(
            self.folder_name,
            f"{self.base_filename}_{date_str}_{self.file_counter}.csv"
        )

    def create_new_file(self):
        """创建新文件并设为当前写入目标"""
        # 关闭现有文件
        if self.current_file and not self.current_file.closed:
            self.current_file.close()
            print(f"已关闭文件: {self.current_filename}")

        # 创建新文件
        self.current_filename = self._generate_filename()
        self.file_history.append(self.current_filename)
        self.current_file = open(self.current_filename, 'a', newline='', encoding='utf-8')
        self.writer = csv.writer(self.current_file)

        # 写入表头（仅新文件）
        if os.stat(self.current_filename).st_size == 0:
            self.writer.writerow(self.HEADERS)
            self.current_file.flush()  # 确保表头立即写入磁盘

        print(f"创建新文件: {self.current_filename}")
        self.file_counter += 1  # 递增文件序号

    def write_data(self,
                   grip_pose,
                   eccentric_distance,
                   load_weight,
                   material_weight,
                   static_time,
                   speed,
                   acceleration,
                   jerk,
                   mx,
                   my,
                   weight,
                   new_file=False):
        """
        写入单条数据
        :param new_file:
            True - 创建新文件后写入
            False - 写入当前最新文件
        """
        # 1. 需要创建新文件
        if new_file:
            self.create_new_file()

        # 2. 准备数据行
        current_time = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        row = [
            current_time, grip_pose, eccentric_distance, load_weight, material_weight,
            static_time, speed, acceleration, jerk, mx, my, weight
        ]

        # 3. 写入数据
        try:
            self.writer.writerow(row)
            self.current_file.flush()  # 确保数据立即写入磁盘
            print(f"数据写入: {self.current_filename}")
            return True
        except Exception as e:
            print(f"写入失败: {e}")
            return False

    def get_file_history(self):
        """获取历史文件列表"""
        return self.file_history.copy()

    def close(self):
        """安全关闭文件"""
        if self.current_file and not self.current_file.closed:
            self.current_file.close()
            print(f"已关闭: {self.current_filename}")
