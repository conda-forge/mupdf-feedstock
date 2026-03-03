@echo off
setlocal EnableDelayedExpansion

set "SLN_PLAT=%CMAKE_GENERATOR_PLATFORM%"
set "SLN_DIR=platform\win32"
set "SLN_FILE=mupdf.sln"
set "CONFIG=Release"

:: -----------------------------------------------------------------------
:: Work around Python 3.8+ DLL search restrictions for libclang.
::
:: The conda libclang package installs a versioned DLL (libclang-13.dll) in
:: %LIBRARY_BIN%.  Two problems:
::   1. clang.cindex expects the unversioned name "libclang.dll"
::   2. Python 3.8+ doesn't search PATH for DLLs or their dependencies
::
:: Fix: copy under the expected name and install a .pth file that adds
:: %LIBRARY_BIN% to the DLL search path for all Python processes (including
:: subprocesses spawned by pip).  The .pth file is removed after the build.
:: -----------------------------------------------------------------------
for %%f in ("%LIBRARY_BIN%\libclang-*.dll") do (
    copy "%%f" "%LIBRARY_BIN%\libclang.dll"
)
set "PTH_FILE=%PREFIX%\Lib\site-packages\_conda_dll_search.pth"
> "%PTH_FILE%" echo import os; os.add_dll_directory(os.environ['LIBRARY_BIN']) if hasattr(os, 'add_dll_directory') and os.environ.get('LIBRARY_BIN') and os.path.isdir(os.environ['LIBRARY_BIN']) else None

:: -----------------------------------------------------------------------
:: Build Python bindings via pip install.
:: setup.py runs scripts/mupdfwrap.py with actions 0,1,2,3 (generate C++,
:: build mupdfcpp64.dll via devenv, run SWIG, build _mupdf.pyd).
:: -----------------------------------------------------------------------
set MUPDF_SETUP_USE_CLANG_PYTHON=1
set MUPDF_SETUP_USE_SWIG=1
pip install . --no-deps --no-build-isolation
if errorlevel 1 exit 1

:: Clean up build-time artifacts so they don't get packaged.
del "%PTH_FILE%" 2>nul
del "%LIBRARY_BIN%\libclang.dll" 2>nul

:: -----------------------------------------------------------------------
:: Build mutool via MSBuild.  No PlatformToolset override — uses the .sln's
:: native toolset, matching devenv above, and reuses the libmupdf.lib that
:: was already built.
:: -----------------------------------------------------------------------
msbuild %SLN_DIR%\%SLN_FILE% ^
    /p:Configuration=%CONFIG% ^
    /p:Platform=%SLN_PLAT% ^
    /t:mutool ^
    /verbosity:normal
if errorlevel 1 exit 1

:: -----------------------------------------------------------------------
:: Install mutool, headers, and libraries
:: -----------------------------------------------------------------------
cmake -E make_directory %LIBRARY_BIN%
if errorlevel 1 exit 1
cmake -E copy %SRC_DIR%\%SLN_DIR%\%SLN_PLAT%\%CONFIG%\mutool.exe %LIBRARY_BIN%\
if errorlevel 1 exit 1

:: Install C headers
cmake -E make_directory %LIBRARY_INC%
if errorlevel 1 exit 1
cmake -E copy_directory %SRC_DIR%\include %LIBRARY_INC%
if errorlevel 1 exit 1

:: Install generated C++ binding headers (classes.h, classes2.h, etc.)
cmake -E copy_directory %SRC_DIR%\platform\c++\include %LIBRARY_INC%
if errorlevel 1 exit 1

:: Install import libraries (.lib) and DLLs
cmake -E make_directory %LIBRARY_LIB%
if errorlevel 1 exit 1
for %%f in (%SRC_DIR%\%SLN_DIR%\%SLN_PLAT%\%CONFIG%\*.lib) do (
    copy "%%f" "%LIBRARY_LIB%\"
)
for %%f in (%SRC_DIR%\%SLN_DIR%\%SLN_PLAT%\%CONFIG%\*.dll) do (
    copy "%%f" "%LIBRARY_BIN%\"
)
