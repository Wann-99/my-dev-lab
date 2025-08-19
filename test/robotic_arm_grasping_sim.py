from configparser import ConfigParser
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.animation import FuncAnimation, PillowWriter
from mpl_toolkits.mplot3d import Axes3D
from matplotlib.patches import Circle
from mpl_toolkits.mplot3d import art3d
import os
import argparse  # 新增命令行参数支持


class RoboticArmSimulator:
    def __init__(self, config=None):
        # =========== 配置参数 ===========
        self.cfg = {
            'disk_radius': 200,  # 圆盘半径(mm)
            'disk_center': (0, 0),  # 圆盘圆心
            'disk_height': 0,  # 圆盘高度(mm)
            'safe_height': 100,  # 安全高度（移动时的高度）
            'grasp_height': 5,  # 抓取高度（接近物体的高度）
            'gripper_diag': 195,  # 对角线长度(mm)
            'gripper_vertex_radius': 30,  # 顶点抓取区域半径
            'max_grasp_per_time': 4,  # 一次最多抓取4条
            'meat_count': 100,  # 初始肉条数量
            'seed': 42,  # 随机种子
            'output_file': 'animations/robotic_arm_grasping.gif',  # 输出文件名
            'fps': 5  # 帧率
        }
        # 允许通过外部配置覆盖默认值
        # if config:
        #     self.cfg.update(config)

        # 根据对角线计算边长相关参数
        self.gripper_side = self.cfg['gripper_diag'] / np.sqrt(2)
        self.gripper_half = self.gripper_side / 2

        # 设置中文字体解决显示问题
        plt.rcParams["font.family"] = ["SimHei", "Microsoft YaHei", "SimSun"]
        plt.rcParams["axes.unicode_minus"] = False

        # 初始化状态变量
        np.random.seed(self.cfg['seed'])
        self.remaining_meat = None
        self.extended_path = None
        self.total_grasped = 0
        self.fig = None
        self.ax = None
        self.objects = {}  # 存储绘图对象便于管理

    def generate_meat_points(self):
        """生成随机分布在圆盘内的肉条点"""
        points = []
        while len(points) < self.cfg['meat_count']:
            x = np.random.uniform(-self.cfg['disk_radius'], self.cfg['disk_radius'])
            y = np.random.uniform(-self.cfg['disk_radius'], self.cfg['disk_radius'])
            if x **2 + y** 2 <= self.cfg['disk_radius'] **2:
                points.append((x, y, self.cfg['disk_height']))
        return np.array(points)

    def create_path_planning(self):
        """创建基础路径规划（网格+环形）"""
        # 3×3网格节点
        grid_nodes = [
            (-self.gripper_side, -self.gripper_side), (-self.gripper_side, 0), (-self.gripper_side, self.gripper_side),
            (0, -self.gripper_side), (0, 0), (0, self.gripper_side),
            (self.gripper_side, -self.gripper_side), (self.gripper_side, 0), (self.gripper_side, self.gripper_side)
        ]

        # 双层环形节点
        ring_radii = [80, 160]
        ring_steps = 8
        ring_thetas = np.linspace(0, 2 * np.pi, ring_steps, endpoint=False)
        ring_nodes = []
        for r in ring_radii:
            for theta in ring_thetas:
                x = r * np.cos(theta)
                y = r * np.sin(theta)
                ring_nodes.append((x, y))

        # 合并路径并扩展动作序列
        base_path = grid_nodes + ring_nodes
        extended_path = []
        for (x, y) in base_path:
            extended_path.append((x, y, self.cfg['safe_height']))  # 移动到安全高度
            extended_path.append((x, y, self.cfg['grasp_height']))  # 下降到抓取高度
            extended_path.append((x, y, self.cfg['grasp_height']))  # 停留执行抓取
            extended_path.append((x, y, self.cfg['safe_height']))  # 上升到安全高度

        return extended_path

    def get_gripper_vertices(self, pos):
        """计算夹爪四个顶点的位置"""
        x0, y0, z0 = pos
        return [
            (x0 - self.gripper_half, y0 - self.gripper_half, z0),  # 左下
            (x0 + self.gripper_half, y0 - self.gripper_half, z0),  # 右下
            (x0 + self.gripper_half, y0 + self.gripper_half, z0),  # 右上
            (x0 - self.gripper_half, y0 + self.gripper_half, z0)  # 左上
        ]

    def detect_and_remove_grasped_meat(self, gripper_pos):
        """检测并移除被抓取的肉条"""
        if len(self.remaining_meat) == 0:
            return 0

        x0, y0, z0 = gripper_pos
        # 只有在抓取高度时才检测抓取
        if not np.isclose(z0, self.cfg['grasp_height'], atol=1):
            return 0

        vertices = self.get_gripper_vertices(gripper_pos)
        mask = np.zeros(len(self.remaining_meat), dtype=bool)

        for vx, vy, vz in vertices:
            distances = np.sqrt(
                (self.remaining_meat[:, 0] - vx) **2 +
                (self.remaining_meat[:, 1] - vy)** 2
            )
            mask |= (distances <= self.cfg['gripper_vertex_radius'])

        candidate_indices = np.where(mask)[0]
        grasped_count = len(candidate_indices)

        # 限制最大抓取数量
        if grasped_count > self.cfg['max_grasp_per_time']:
            selected_indices = np.random.choice(
                candidate_indices, size=self.cfg['max_grasp_per_time'], replace=False
            )
            new_mask = np.zeros(len(self.remaining_meat), dtype=bool)
            new_mask[selected_indices] = True
            mask = new_mask
            grasped_count = self.cfg['max_grasp_per_time']

        if grasped_count > 0:
            self.remaining_meat = self.remaining_meat[~mask]
            self.total_grasped += grasped_count

        return grasped_count

    def init_visualization(self):
        """初始化3D可视化环境"""
        self.fig = plt.figure(figsize=(10, 10))
        self.ax = self.fig.add_subplot(111, projection='3d')

        # 设置坐标轴范围
        padding = 50
        self.ax.set_xlim(-self.cfg['disk_radius'] - padding, self.cfg['disk_radius'] + padding)
        self.ax.set_ylim(-self.cfg['disk_radius'] - padding, self.cfg['disk_radius'] + padding)
        self.ax.set_zlim(-10, self.cfg['safe_height'] + 20)
        self.ax.set_xlabel('X (mm)')
        self.ax.set_ylabel('Y (mm)')
        self.ax.set_zlabel('Z (高度 mm)')
        self.ax.set_title(f"机械臂抓取模拟（最大{self.cfg['max_grasp_per_time']}条/次）")

        # 绘制圆盘轮廓
        theta = np.linspace(0, 2 * np.pi, 100)
        x_disk = self.cfg['disk_radius'] * np.cos(theta)
        y_disk = self.cfg['disk_radius'] * np.sin(theta)
        self.ax.plot(x_disk, y_disk, self.cfg['disk_height'], 'k-', alpha=0.3)

        # 绘制圆盘表面
        circle = Circle(self.cfg['disk_center'], self.cfg['disk_radius'], fill=True, alpha=0.1, color='gray')
        self.ax.add_patch(circle)
        art3d.pathpatch_2d_to_3d(circle, z=self.cfg['disk_height'], zdir="z")

        # 创建绘图对象字典（将顶点区域拆分为单独的键，避免列表嵌套）
        self.objects['meat_scatter'] = self.ax.scatter(
            [], [], [], color='red', s=20, label='肉条'
        )
        self.objects['gripper'] = self.ax.plot([], [], [], 'b-', linewidth=2)[0]
        # 拆分为4个单独的顶点区域对象（关键修复点）
        for i in range(4):
            self.objects[f'vertex_region_{i}'] = self.ax.plot([], [], [], 'g-', alpha=0.5)[0]
        self.objects['path_line'] = self.ax.plot(
            [], [], [], 'g--', alpha=0.5, label='移动路径'
        )[0]
        self.objects['stats_text'] = self.ax.text2D(
            0.05, 0.95, "", transform=self.ax.transAxes, fontsize=12
        )

        self.ax.legend()
        plt.tight_layout()

    def update_gripper_display(self, pos):
        """更新夹爪及其顶点区域的显示"""
        x0, y0, z0 = pos
        # 定义立方体的8个顶点
        vertices = [
            [x0 - self.gripper_half, y0 - self.gripper_half, z0],
            [x0 + self.gripper_half, y0 - self.gripper_half, z0],
            [x0 + self.gripper_half, y0 + self.gripper_half, z0],
            [x0 - self.gripper_half, y0 + self.gripper_half, z0],
            [x0 - self.gripper_half, y0 - self.gripper_half, z0 + 10],  # 顶部对应点
            [x0 + self.gripper_half, y0 - self.gripper_half, z0 + 10],
            [x0 + self.gripper_half, y0 + self.gripper_half, z0 + 10],
            [x0 - self.gripper_half, y0 + self.gripper_half, z0 + 10]
        ]

        # 定义立方体的12条边（每条边连接两个顶点的索引）
        edges = [
            [0, 1], [1, 2], [2, 3], [3, 0],  # 底面
            [4, 5], [5, 6], [6, 7], [7, 4],  # 顶面
            [0, 4], [1, 5], [2, 6], [3, 7]  # 侧面连接线
        ]

        # 分别收集x、y、z坐标
        x_vals = []
        y_vals = []
        z_vals = []
        for edge in edges:
            v1 = vertices[edge[0]]
            v2 = vertices[edge[1]]
            x_vals.append(v1[0])
            y_vals.append(v1[1])
            z_vals.append(v1[2])
            x_vals.append(v2[0])
            y_vals.append(v2[1])
            z_vals.append(v2[2])

        # 更新夹爪线条数据
        self.objects['gripper'].set_data(x_vals, y_vals)
        self.objects['gripper'].set_3d_properties(z_vals)

        # 更新顶点区域（使用拆分后的单独对象）
        gripper_vertices = self.get_gripper_vertices(pos)
        for i, (vx, vy, vz) in enumerate(gripper_vertices):
            theta = np.linspace(0, 2 * np.pi, 30)
            cx = vx + self.cfg['gripper_vertex_radius'] * np.cos(theta)
            cy = vy + self.cfg['gripper_vertex_radius'] * np.sin(theta)
            cz = [vz] * len(theta)
            self.objects[f'vertex_region_{i}'].set_data(cx, cy)
            self.objects[f'vertex_region_{i}'].set_3d_properties(cz)

    def animate(self, frame):
        """动画更新函数（返回扁平的Artist对象序列）"""
        if frame >= len(self.extended_path):
            return list(self.objects.values())

        current_pos = self.extended_path[frame]
        self.update_gripper_display(current_pos)

        # 检测抓取动作（每4帧中的第3帧）
        current_grasped = 0
        if frame % 4 == 2:
            grasped = self.detect_and_remove_grasped_meat(current_pos)
            current_grasped = grasped

            # 更新肉条显示
            if len(self.remaining_meat) > 0:
                self.objects['meat_scatter']._offsets3d = (
                    self.remaining_meat[:, 0],
                    self.remaining_meat[:, 1],
                    self.remaining_meat[:, 2]
                )
            else:
                self.objects['meat_scatter']._offsets3d = ([], [], [])

        # 更新统计信息
        progress = (frame + 1) / len(self.extended_path) * 100
        stats_txt = f"进度: {progress:.1f}%\n" \
                    f"本次抓取: {current_grasped}/{self.cfg['max_grasp_per_time']}\n" \
                    f"累计抓取: {self.total_grasped}/{self.cfg['meat_count']}\n" \
                    f"剩余肉条: {len(self.remaining_meat)}"
        self.objects['stats_text'].set_text(stats_txt)

        # 动态调整视角增强立体感
        self.ax.view_init(elev=30, azim=frame % 360)

        # 返回所有绘图对象（此时已为扁平序列）
        return list(self.objects.values())

    def run(self):
        """运行仿真主流程"""
        # 初始化肉条数据
        self.remaining_meat = self.generate_meat_points()

        # 创建路径规划
        self.extended_path = self.create_path_planning()

        # 初始化可视化
        self.init_visualization()

        # 绘制预设路径参考线
        path_x = [p[0] for p in self.extended_path[:len(self.extended_path) // 4]]
        path_y = [p[1] for p in self.extended_path[:len(self.extended_path) // 4]]
        path_z = [p[2] for p in self.extended_path[:len(self.extended_path) // 4]]
        self.objects['path_line'].set_data(path_x, path_y)
        self.objects['path_line'].set_3d_properties(path_z)

        # 创建动画
        ani = FuncAnimation(
            self.fig, self.animate,
            frames=len(self.extended_path),
            interval=200, blit=True, repeat=False
        )

        # 保存动画功能
        def save():
            try:
                ani.save(self.cfg['output_file'], writer=PillowWriter(fps=self.cfg['fps']))
                print(f"动画已保存至 '{self.cfg['output_file']}'")
            except Exception as e:
                print(f"保存失败: {str(e)}")

        # 显示或保存结果
        try:
            pass
            # plt.show()
        except:
            import matplotlib
            matplotlib.use('Qt5Agg')
            # plt.show()

        # 自动保存动画
        save()


if __name__ == "__main__":
    # 解析命令行参数
    parser = argparse.ArgumentParser(description='机械臂抓取仿真参数设置')
    parser.add_argument('--meat', type=int, default=100, help='初始肉条数量')
    parser.add_argument('--max_grasp', type=int, default=4, help='最大同时抓取数')
    parser.add_argument('--output', type=str, default='output.gif', help='输出文件名')
    args = parser.parse_args()

    # 创建仿真实例并运行
    simulator = RoboticArmSimulator({
        'meat_count': args.meat,
        'max_grasp_per_time': args.max_grasp,
        'output_file': args.output
    })
    simulator.run()