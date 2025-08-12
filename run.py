import sys
import spdlog
import importlib.util
import inspect


def configure_spdlog():
    # 尝试获取已存在的日志记录器
    logger = spdlog.get('Example')

    # 如果没有找到日志记录器，则创建一个新的
    if logger is None:
        logger = spdlog.ConsoleLogger("Example")
    return logger


def safe_exec(code, global_scope=None, local_scope=None):
    # 配置 spdlog
    logger = configure_spdlog()

    # 执行代码
    try:
        exec(code, global_scope, local_scope)
    except Exception as e:
        logger.error(f"Error executing code: {e}")


def load_file(file_path):
    """ 加载指定路径的文件并返回模块对象 """
    spec = importlib.util.spec_from_file_location("module.name", file_path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def execute_from_file(file_path, line_number=None, class_name=None, function_name=None, params=None):
    try:
        # 加载文件
        module = load_file(file_path)
        global_scope = {"params": params}
        local_scope = global_scope

        if class_name:
            # 如果指定了类名，实例化该类
            class_obj = getattr(module, class_name, None)
            if class_obj is None:
                print(f"Error: 类 {class_name} 未找到.")
                return
            # 创建类实例
            class_instance = class_obj()
            if function_name:
                # 如果指定了函数名，调用该函数
                func = getattr(class_instance, function_name, None)
                if func is None:
                    print(f"Error: 类 {class_name} 中的函数 {function_name} 未找到.")
                    return
                logger = configure_spdlog()
                logger.info(f"Calling {function_name} of {class_name}")
                func(**params)  # 假设函数需要传入参数
            else:
                # 如果没有指定函数名，调用类的默认行为
                logger = configure_spdlog()
                logger.info(f"Instantiating and using class: {class_name}")
                class_instance.run(**params)  # 假设类有一个默认的 `run` 方法
        else:
            # 执行整个文件或者指定行号
            if line_number is None:
                code = ''.join(inspect.getsource(module))  # 获取模块的源代码
                logger = configure_spdlog()
                logger.info(f"Executing file: {file_path}")
                safe_exec(code, global_scope, local_scope)
            else:
                lines = open(file_path).readlines()
                code_to_execute = lines[line_number - 1]
                logger = configure_spdlog()
                logger.info(f"Executing line {line_number}: {code_to_execute.strip()}")
                safe_exec(code_to_execute, global_scope, local_scope)

    except FileNotFoundError:
        print(f"Error: 文件 {file_path} 未找到.")
    except Exception as e:
        print(f"Error: 执行代码时出现错误 - {e}")


if __name__ == '__main__':
    # 使用命令行参数，指定文件路径、行号、类名、函数名及参数
    if len(sys.argv) < 2:
        print("Usage: python run.py <file_path> [line_number] [class_name] [function_name] [param1=value1 ...]")
    else:
        file_path = sys.argv[1]
        line_number = None
        class_name = None
        function_name = None
        params = {}

        # 检查是否传递了行号
        if len(sys.argv) > 2 and sys.argv[2].isdigit():
            line_number = int(sys.argv[2])
            index = 3
        else:
            index = 2

        # 检查是否传递了类名（注意，类名不应该以 "param=" 开头）
        if len(sys.argv) > index and "=" not in sys.argv[index]:  # 排除类似 param=value 的参数
            class_name = sys.argv[index]
            index += 1

        # 检查是否传递了函数名（同理，排除类似 param=v
