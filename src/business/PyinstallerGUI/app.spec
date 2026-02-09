# -*- mode: python ; coding: utf-8 -*-
from PyInstaller.utils.hooks import collect_all

datas = [('D:/PythonDevelop/Projects/PycharmProjects/flexivrobot/src/business/clac_beat/static', 'static'), ('D:/PythonDevelop/Projects/PycharmProjects/flexivrobot/src/business/clac_beat/templates', 'templates'), ('D:/PythonDevelop/Projects/PycharmProjects/flexivrobot/.venv\\Lib\\site-packages\\numpy.libs', '.'), ('D:/PythonDevelop/Projects/PycharmProjects/flexivrobot/.venv\\Lib\\site-packages\\pandas.libs', '.'), ('D:/PythonDevelop/Projects/PycharmProjects/flexivrobot/.venv\\Lib\\site-packages\\scipy.libs', '.')]
binaries = []
hiddenimports = []
tmp_ret = collect_all('pandas')
datas += tmp_ret[0]; binaries += tmp_ret[1]; hiddenimports += tmp_ret[2]
tmp_ret = collect_all('numpy')
datas += tmp_ret[0]; binaries += tmp_ret[1]; hiddenimports += tmp_ret[2]


a = Analysis(
    ['D:/PythonDevelop/Projects/PycharmProjects/flexivrobot/src/business/clac_beat/app.py'],
    pathex=[],
    binaries=binaries,
    datas=datas,
    hiddenimports=hiddenimports,
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
    [],
    exclude_binaries=True,
    name='app',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=['D:\\PythonDevelop\\Projects\\PycharmProjects\\flexivrobot\\src\\business\\clac_beat\\static\\favicon.ico'],
)
coll = COLLECT(
    exe,
    a.binaries,
    a.datas,
    strip=False,
    upx=True,
    upx_exclude=[],
    name='app',
)
