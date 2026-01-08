from struct import pack, unpack

from pp.core.mock import set_global_var
from pp.parallel_program import ParallelProgram
from pp.settings import RobotSetting
from pp.core.basic import (
    get_list,
    to_number,
    sub_string,
    concat_string, first_index_string)


class Float_2_N16(ParallelProgram):

    def __init__(self, setting: RobotSetting = RobotSetting()):
        super().__init__(setting=setting)


    def pp_float_2_n16(self):

        # self.func_float32_2_n16(20)
        self.func_n16_2_float32(16800,0.5)

    def func_float32_2_n16(self,d32_float):

        n_Int_List = pack('f', d32_float)
        n8_a = get_list(n_Int_List, 0)
        n8_b = get_list(n_Int_List, 1)
        n8_c = get_list(n_Int_List, 2)
        n8_d = get_list(n_Int_List, 3)
        n16_A = n8_a * 256 + n8_b
        n16_B = n8_c * 256 + n8_d
        # set_global_var(n16_A,n16_A)


    def func_n16_2_float32(self, n16_A, n16_B):
        r_n16_A = n16_A / 256
        r_n16_B = n16_B / 256
        # print(r_n16_A)
        # print(r_n16_B)
        str_n16_A = concat_string(r_n16_A)
        str_n16_B = concat_string(r_n16_B)
        #16800,0
        dot_index_A = first_index_string(str_n16_A, ".")
        dot_index_B = first_index_string(str_n16_B, ".")

        end_n16_A = sub_string(str_n16_A, 0, dot_index_A)
        end_n16_B = sub_string(str_n16_B, 0, dot_index_B)
        # print(end_n16_A)
        # print(end_n16_B)
        nB_a = to_number(end_n16_A, 10)
        nB_b = n16_A - nB_a * 256
        nB_c = to_number(end_n16_B, 10)
        nB_d = n16_B - nB_c * 256

        # print(nB_a)
        # print(unpack('f', b"nB_a,"))