from pp.parallel_program import ParallelProgram
from pp.settings import RobotSetting
from pp.core.communication import (
    modbus_tcp_open,
    modbus_tcp_close
)
from pp.core.robot import (
    get_global_var,
    set_global_var
)
from pp.core.basic import (
    join_list,
    append_list,
    concat_string,
    get_list,
    split_string,

)


class CalculatePosition(ParallelProgram):

    def __init__(self, setting: RobotSetting = RobotSetting()):
        super().__init__(setting=setting)

    def pp_calculate_position(self):
        if modbus_tcp_open(1, "192.168.2.100", 502):
            base_x = get_global_var("BaseX")
            base_y = get_global_var("BaseY")
            base_z = get_global_var("BaseZ")
            row = get_global_var("Row")
            col = get_global_var("Col")
            layer = get_global_var("Layer")
            row_spacing = get_global_var("RowSpacing")
            col_spacing = get_global_var("ColSpacing")
            layer_spacing = get_global_var("LayerSpacing")
            reference_pose = get_global_var("ReferencePose")
            reference_pose_list = join_list(reference_pose, ",")

            confirm = (row >= 1 and col >= 1 and layer >= 1)
            if not confirm:
                print("Rows, cols and layers must be non-negative integers！！！")
                print("请确认 行、列 和 层 的值，row>=1 && col>=1 && layer>=1")
                modbus_tcp_close(1)
                return False

            arr_row_data = self.func_calculate_position(
                base_x,
                base_y,
                base_z,
                0,
                180,
                0,
                row,
                col,
                layer,
                row_spacing,
                col_spacing,
                layer_spacing,
                reference_pose_list,
            )

            if len(arr_row_data) == 0:
                a_coord = ["0,0,0,0,180,0,WORLD,WORLD_ORIGIN,0,-40,0,90,0,40,0,0,0,0,0,0,0"]
                arr_coord = []
                for coord in a_coord:
                    append_list(arr_coord, split_string(coord, ","))
                set_global_var("ArrData", arr_coord)
                print("程序异常--终止")
                modbus_tcp_close(1)
            else:
                pass

            set_global_var("ArrData", arr_row_data)
            modbus_tcp_close(1)

    def func_calculate_position(self, base_x, base_y, base_z, base_rx,base_ry, base_rz, rows, cols, layers,x_offset, y_offset, z_offset, reference_pose):
        """
        根据基坐标、行列层数和三维偏移量计算所有点位坐标（空间点阵）
        """
        points = []

        # 三重循环：层 -> 行 -> 列，生成空间点阵
        for k in range(layers):
            for i in range(rows):
                for j in range(cols):
                    x = base_x + (j - 1) * x_offset
                    y = base_y + (i - 1) * y_offset
                    z = base_z + (k - 1) * z_offset  # 新增：z方向偏移计算
                    rx = base_rx
                    ry = base_ry
                    rz = base_rz

                    str_pose = split_string(concat_string(x, ",", y, ",", z, ",", rx, ",", ry, ",", rz, ",",
                                                          "WORLD", ",", "WORLD_ORIGIN", ",", reference_pose), ",")
                    append_list(points, str_pose)
        return points