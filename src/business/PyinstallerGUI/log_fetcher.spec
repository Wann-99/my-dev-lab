# -*- mode: python ; coding: utf-8 -*-


a = Analysis(
    ['D:/PythonDevelop/Projects/PycharmProjects/my-dev-lab/src/business/log_fetcher/main/log_fetcher_merged_with_scan.py'],
    pathex=[],
    binaries=[],
    datas=[('D:/PythonDevelop/Projects/PycharmProjects/my-dev-lab/src/business/log_fetcher/main/log_fetcher_config.json', 'log_fetcher_config.json'), ('D:/PythonDevelop/Projects/PycharmProjects/my-dev-lab/.venv\\Lib\\site-packages\\numpy.libs', '.'), ('D:/PythonDevelop/Projects/PycharmProjects/my-dev-lab/.venv\\Lib\\site-packages\\pandas.libs', '.'), ('D:/PythonDevelop/Projects/PycharmProjects/my-dev-lab/.venv\\Lib\\site-packages\\scipy.libs', '.')],
    hiddenimports=[],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='log_fetcher',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=['D:\\PythonDevelop\\Projects\\PycharmProjects\\my-dev-lab\\src\\business\\log_fetcher\\main\\log_fetcher.ico'],
)
