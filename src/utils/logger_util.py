import os
import sys
from functools import wraps
from time import perf_counter
from loguru import logger as o_logger

class CommonLogger:
    """
    根据时间、文件大小切割日志
    """

    def __init__(self, log_dir='logs', max_size=20, retention='7 days'):
        self.log_dir = log_dir
        self.max_size = max_size
        self.retention = retention
        self.logger = self.configure_logger()

    def configure_logger(self):
        os.makedirs(self.log_dir, exist_ok=True)

        shared_config = {
            "level": "DEBUG",
            "enqueue": True,
            "backtrace": True,
            "format": "{time:YYYY-MM-DD HH:mm:ss.SSS} | {level} | {message}",
        }
        # o_logger.add(sys.stdout,level="INFO")
        o_logger.add(
            sink=f"{self.log_dir}/{{time:YYYY-MM-DD}}.log",
            rotation=f"{self.max_size} MB",
            retention=self.retention,
            **shared_config
        )
        o_logger.add(sink=self.get_log_path, **shared_config)
        return o_logger

    def get_log_path(self, message: str) -> str:
        log_level = message.record["level"].name.lower()
        log_file = f"{log_level}.log"
        log_path = os.path.join(self.log_dir, log_file)
        return log_path

    def __getattr__(self, level: str):
        return getattr(self.logger, level)

    def log_decorator(self, msg=""):
        """
         日志装饰器，记录函数的名称、参数、返回值、运行时间和异常信息
        Args:
            logger: 日志记录器对象

        Returns:
            装饰器函数
        """
        def decorator(func):
            @wraps(func)
            def wrapper(*args, **kwargs):
                self.logger.info(f'-----------分割线-----------')
                self.logger.info(f'调用 {func.__name__} args: {args}; kwargs:{kwargs}')
                start = perf_counter()
                try:
                    result = func(*args, **kwargs)
                    end = perf_counter()
                    duration = end - start
                    self.logger.info(f"{func.__name__} 返回结果：{result}, 耗时：{duration:4f}s")
                    return result
                except Exception as e:
                    self.logger.exception(f"{func.__name__}: {msg}")
                    self.logger.info(f"-----------分割线-----------")
            return wrapper
        return decorator

    def get_logger(self):
        return self.logger
common_logger = CommonLogger()
logger = common_logger.get_logger()