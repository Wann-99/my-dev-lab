import subprocess
import threading
import sys
import os
import shutil


class PackerThread(threading.Thread):
    def __init__(self, config, log_callback, done_callback):
        super().__init__()
        self.config = config
        self.log_callback = log_callback
        self.done_callback = done_callback
        self.process = None
        self._stop_event = False  # 内部停止标志

    def run(self):
        cmd = self._build_command()

        # 智能依赖修复
        extra_args = self._smart_dependency_fix()
        cmd.extend(extra_args)

        self.log_callback(f"执行命令: {' '.join(cmd)}\n")
        self.log_callback("-" * 50 + "\n")

        try:
            startupinfo = None
            if sys.platform == "win32":
                startupinfo = subprocess.STARTUPINFO()
                startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW

            self.process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                encoding='utf-8',
                startupinfo=startupinfo,
                creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
            )

            # 循环读取日志，直到进程结束或被手动停止
            while True:
                if self._stop_event:
                    break  # 退出循环

                line = self.process.stdout.readline()
                if not line and self.process.poll() is not None:
                    break
                if line:
                    self.log_callback(line)

            # 检查是否是被强制停止的
            if self._stop_event:
                self.log_callback("\n[警告] 用户强制停止任务。\n")
                return  # 直接退出，不执行后续压缩逻辑

            return_code = self.process.poll()

            if return_code == 0:
                self.log_callback("\n" + "=" * 20 + " 打包成功! " + "=" * 20 + "\n")

                # 自动压缩逻辑
                dist_dir = self.config.get('output_dir') or os.path.join(os.getcwd(), 'dist')
                app_name = self.config['name']
                if not self.config['onefile']:
                    self.log_callback(f"正在生成压缩包 ({app_name}.zip)...\n")
                    try:
                        zip_base_name = os.path.join(dist_dir, app_name)
                        shutil.make_archive(zip_base_name, 'zip', dist_dir, app_name)
                        self.log_callback(f"✅ 压缩包已生成: {zip_base_name}.zip\n")
                    except Exception as zip_err:
                        self.log_callback(f"⚠️ 压缩失败: {str(zip_err)}\n")

                self.log_callback(f"文件位置: {dist_dir}\n")
            else:
                self.log_callback(f"\n[错误] 打包失败，错误代码: {return_code}\n")

        except Exception as e:
            self.log_callback(f"\n[致命错误]: {str(e)}\n")
        finally:
            self.done_callback()

    def stop(self):
        """【新增】强制停止方法"""
        self._stop_event = True
        if self.process and self.process.poll() is None:
            try:
                # 杀死子进程树
                self.process.kill()
                # 或者用 terminate() 稍微温和一点，但 kill 更保险
            except Exception:
                pass

    # ... ( _build_command, _smart_dependency_fix, _find_site_packages 保持不变，代码太长这里省略，请保留原有的 ) ...
    def _build_command(self):
        interp = self.config.get('interpreter')
        if interp and os.path.exists(interp):
            cmd = [interp, "-m", "PyInstaller"]
        else:
            cmd = ["pyinstaller"]
        cmd.append(self.config['script_path'])
        if self.config.get('output_dir'): cmd.append(f"--distpath={self.config['output_dir']}")
        if self.config['onefile']:
            cmd.append("--onefile")
        else:
            cmd.append("--onedir")
        if self.config['noconsole']: cmd.append("--noconsole")
        if self.config['clean']: cmd.append("--clean")
        if self.config['icon_path']: cmd.append(f"--icon={self.config['icon_path']}")
        if self.config['name']: cmd.append(f"--name={self.config['name']}")
        sep = os.pathsep
        for source, dest in self.config['datas']: cmd.append(f"--add-data={source}{sep}{dest}")
        for mod in self.config['hidden_imports']: cmd.append(f"--hidden-import={mod}")
        for mod in self.config.get('collect_all_imports', []): cmd.append(f"--collect-all={mod}")
        for mod in self.config.get('exclude_imports', []): cmd.append(f"--exclude-module={mod}")
        cmd.append("-y")
        return cmd

    def _smart_dependency_fix(self):
        extra_cmd = []
        site_packages = self._find_site_packages()
        if not site_packages: return []
        libs_to_fix = ["numpy.libs", "Pillow.libs", "pandas.libs", "scipy.libs"]
        sep = os.pathsep
        for lib_name in libs_to_fix:
            lib_path = os.path.join(site_packages, lib_name)
            if os.path.exists(lib_path):
                extra_cmd.append(f"--add-data={lib_path}{sep}.")
        return extra_cmd

    def _find_site_packages(self):
        interp = self.config.get('interpreter')
        if not interp or not os.path.exists(interp):
            import site
            pkgs = site.getsitepackages()
            return pkgs[0] if pkgs else None
        base_dir = os.path.dirname(os.path.dirname(interp))
        if sys.platform == "win32":
            potential_path = os.path.join(base_dir, "Lib", "site-packages")
            if os.path.exists(potential_path): return potential_path
        else:
            lib_dir = os.path.join(base_dir, "lib")
            if os.path.exists(lib_dir):
                for d in os.listdir(lib_dir):
                    if d.startswith("python"):
                        potential_path = os.path.join(lib_dir, d, "site-packages")
                        if os.path.exists(potential_path): return potential_path
        return None