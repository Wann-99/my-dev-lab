from datetime import datetime

# 获取当前时间并格式化为"YYYY-MM-DD HH:MM:SS"
current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")
print("当前时间：", current_time)




class ControlGripper(ParallelProgram):

    def pp_control_gripper(self):
        while True:
            while get_system_state(SystemStateEnum.PROJECT_RUNNING):
                tool_state = get_global_var('ToolState')  # 局部变量替代多次调用
                if tool_state == 1:
                    error_code = self.func_handle_gripper_open()
                elif tool_state == 2:
                    error_code = self.func_handle_gripper_close()
                else:
                    error_code = 0

                self.func_check_error_state(error_code)
                wait_ms(5)

            self.func_handle_idle_state()

    def func_handle_gripper_open(self):
        """处理夹爪打开逻辑"""
        self.func_gripper_open()
        print("Open the Gripper")
        if get_global_var('ToolState') == 1:
            return self.func_monitor_state_changes()

    def func_handle_gripper_close(self):
        """处理夹爪关闭逻辑"""
        self.func_gripper_close()
        print("Close the Gripper")
        if get_global_var('ToolState') == 2:
            return self.func_monitor_state_changes()


    def func_monitor_state_changes(self):
        """监控状态变化"""
        wait_ms(30)
        error_code = 0
        if get_system_state(SystemStateEnum.PROJECT_PAUSED):
            print("...")
            error_code = 1
        elif get_system_state(SystemStateEnum.IS_FAULT):
            clear_fault()
            error_code = 2
        return error_code
    def func_check_error_state(self, error_code):
        """检查错误状态并处理"""
        if error_code == 1:
            print("Pausing! Please Check The Log!")
            set_global_var('ToolState', 0)
        elif error_code == 2:
            print("A Fault Occurred! Please Check The Log!")
        error_code = 0  # 重置错误码

    def func_handle_idle_state(self):
        """处理空闲状态"""
        print("Program is not Running! Please Check The Log!")
        while not get_system_state(SystemStateEnum.PROJECT_RUNNING):
            wait_ms(30)

    # 以下为原有空方法保持不变
    def func_gripper_open(self):
        """实现打开夹爪的具体逻辑"""
        pass

    def func_gripper_close(self):
        """实现关闭夹爪的具体逻辑"""
        pass