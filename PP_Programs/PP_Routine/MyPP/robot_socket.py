from pp.parallel_program import ParallelProgram
from pp.settings import RobotSetting
from pp.enums import SystemStateEnum
from pp.core.basic import (
    concat_string,
    wait_ms,
    append_list, join_list, get_list,
    split_string,
    sub_string
)
from pp.core.communication import (
    socket_open,
    socket_send,
    socket_recv,
    socket_close
)
from pp.core.robot import (
    get_global_var,
    get_system_state,
    get_io
)


class RobotSocket(ParallelProgram):

    def __init__(self, setting: RobotSetting = RobotSetting()):
        super().__init__(setting=setting)
        self.pp_index = 0

    def pp_robot_socket(self, auto_booted: bool = True, auto_looped: bool = False):
        # 初始化空列表（假设是创建独立空列表）
        # 条件判断与Socket连接
        if socket_open(1, "192.168.100.205", 20000):
            # 打开TCP客户端连接
            print(socket_send(1, "1"))  # 发送初始消息
            # print(join_string(["Hi", "Flexiv"], "_"))
            recv_data = socket_recv(1)
            result = self.func_parse_value(recv_data)
            # print(result)
            # print(type(recv_data))

            # print(get_list(recv_data, 1))
            # 关闭Socket连接
            socket_close(1)
        print("socket connected field")


    def func_parse_value(self, data):

        char = sub_string(data, self.pp_index, self.pp_index + 1)
        if char == '{':
            print("11111")
            return self.func_parse_object(self.pp_index, data)
        # elif char == '[':
        #     return self.func_parse_array(data)
        # elif char == '"':
        #     return self.func_parse_string(data)
        # elif char in '0123456789-':
        #     return self.func_parse_number(data)
            pass
        else:
            print("Invalid JSON format")

    def func_parse_object(self, data):

        self.pp_index += 1  # Skip '{'
        obj = {}
        while sub_string(data, self.pp_index, self.pp_index + 1) != '}':
            # Parse key
            if sub_string(data, self.pp_index, self.pp_index + 1) != '\\"':
                print("Key must be a string")
            key = self.func_parse_string(data)
            self.pp_index += 1  # Skip ':'
            # Parse value
            value = self.func_parse_value()
            obj[key] = value
            # Check for ',' or '}'
            if sub_string(data, self.pp_index, self.pp_index + 1) == '}':
                self.pp_index += 1
                break
            elif sub_string(data, self.pp_index, self.pp_index + 1) == ',':
                self.pp_index += 1
            else:
                print("Expected ',' or '}' after pair")
            print(obj)
        return obj

    # def func_parse_array(self, data):
    #     global index
    #     index += 1  # Skip '['
    #     arr = []
    #     while data[index] != ']':
    #         value = self.func_parse_value()
    #         arr.append(value)
    #         if data[index] == ']':
    #             index += 1
    #             break
    #         elif data[index] == ',':
    #             index += 1
    #         else:
    #             raise ValueError("Expected ',' or ']' in array")
    #     return arr

    def func_parse_string(self, data):
        print("1111")
        start = self.pp_index
        self.pp_index += 1  # Skip initial '"'
        while sub_string(data, self.pp_index, self.pp_index + 1) != '\\"':
            if sub_string(data, self.pp_index, self.pp_index + 1) == '\\':  # Handle escape characters
                self.pp_index += 2
            else:
                self.pp_index += 1
        result = sub_string(data, start, self.pp_index + 1)  # Include quotes
        self.pp_index += 1  # Skip closing '"'
        # return 0
        return sub_string(result, 1, -1)  # Remove surrounding quotes
    #
    # def func_parse_number(self,data):
    #     global index
    #     start = index
    #     if data[index] == '-':
    #         index += 1
    #     while data[index] in '0123456789':
    #         index += 1
    #     if data[index] == '.':
    #         index += 1
    #         while data[index] in '0123456789':
    #             index += 1
    #     if data[index] == 'e' or data[index] == 'E':
    #         index += 1
    #         if data[index] == '+' or data[index] == '-':
    #             index += 1
    #         while data[index] in '0123456789':
    #             index += 1
    #     return float(data[start:index]) if '.' in data[start:index] else int(data[start:index])
    #
