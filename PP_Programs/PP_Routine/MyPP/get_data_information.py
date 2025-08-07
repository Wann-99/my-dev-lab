from pp.parallel_program import ParallelProgram
from pp.core import write
from pp.settings import RobotSetting
from pp.core.communication import write_tarje



class GetDataInformation(ParallelProgram):
    def __init__(self, setting: RobotSetting = RobotSetting()):
        super().__init__(setting=setting)


    def pp_write_files(self):
        write_trajectory_file(content,traj_file_name)