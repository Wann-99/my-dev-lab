import spdlog
from spdlog import stdout_sink_mt, basic_file_sink_mt

console_sink = stdout_sink_mt()
file_sink = basic_file_sink_mt("pyrdk.log", True)
logger = spdlog.SinkLogger("pyrdk", [console_sink, file_sink])
logger.set_level(spdlog.LogLevel.INFO)
