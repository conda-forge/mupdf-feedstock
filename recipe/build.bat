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
set "PTH_FILE=%SP_DIR%\_conda_dll_search.pth"
> "%PTH_FILE%" echo import os; os.add_dll_directory(os.environ['LIBRARY_BIN']) if hasattr(os, 'add_dll_directory') and os.environ.get('LIBRARY_BIN') and os.path.isdir(os.environ['LIBRARY_BIN']) else None

:: -----------------------------------------------------------------------
:: Build Python bindings via pip install.
:: setup.py runs scripts/mupdfwrap.py with actions 0,1,2,3 (generate C++,
:: build mupdfcpp64.dll via devenv, run SWIG, build _mupdf.pyd).
:: -----------------------------------------------------------------------
:: Work around pipcl's wdev.py not finding python3XX.lib on Python 3.15+.
"%PYTHON%" -B "%RECIPE_DIR%\fix_pipcl_wdev.py"
if errorlevel 1 exit 1

set MUPDF_SETUP_USE_CLANG_PYTHON=1
set MUPDF_SETUP_USE_SWIG=1
pip install . --no-deps --no-build-isolation
if errorlevel 1 exit 1

:: Clean up build-time artifacts so they don't get packaged.
del "%PTH_FILE%" 2>nul
del "%LIBRARY_BIN%\libclang.dll" 2>nul

:: pip puts a copy of mupdfcpp64.dll next to _mupdf.pyd. The copy installed to
:: %LIBRARY_BIN% below is enough, because conda-forge Python adds Library\bin to
:: the DLL search path. Shipping both adds 45 MB.
del "%SP_DIR%\mupdfcpp64.dll"
if errorlevel 1 exit 1

:: -----------------------------------------------------------------------
:: Build mutool against mupdfcpp64.dll instead of the solution's mutool
:: target, which statically links all of MuPDF and its third-party
:: libraries (about 46 MB). The DLL exports every public fz_/pdf_ function
:: and global (see platform\c++\windows_mupdf.def), so the tools only need
:: FZ_DLL_CLIENT plus the few things the DLL doesn't export: mujs for
:: `mutool run`, and the mu-threads and pkcs7 helpers. These match the
:: sources of the libmutool, libmuthreads and libpkcs7 projects.
:: -----------------------------------------------------------------------
set "MUTOOL_DIR=%SRC_DIR%\build-mutool"
cmake -E make_directory "%MUTOOL_DIR%"
if errorlevel 1 exit 1
set "TOOLS=%SRC_DIR%\source\tools"
cl.exe /nologo /O2 /MD /W3 ^
    /DWIN64 /DNDEBUG /D_CRT_SECURE_NO_WARNINGS /DFZ_DLL_CLIENT ^
    /DHAVE_LEPTONICA /DHAVE_TESSERACT ^
    /I"%SRC_DIR%\include" /I"%SRC_DIR%\thirdparty\mujs" ^
    "%TOOLS%\mutool.c" ^
    "%TOOLS%\cmapdump.c" "%TOOLS%\mubar.c" "%TOOLS%\muconvert.c" ^
    "%TOOLS%\mudraw.c" "%TOOLS%\mugrep.c" "%TOOLS%\murun.c" ^
    "%TOOLS%\mutrace.c" "%TOOLS%\pdfaudit.c" "%TOOLS%\pdfbake.c" ^
    "%TOOLS%\pdfclean.c" "%TOOLS%\pdfcreate.c" "%TOOLS%\pdfextract.c" ^
    "%TOOLS%\pdfinfo.c" "%TOOLS%\pdfmerge.c" "%TOOLS%\pdfpages.c" ^
    "%TOOLS%\pdfposter.c" "%TOOLS%\pdfrecolor.c" "%TOOLS%\pdfshow.c" ^
    "%TOOLS%\pdfsign.c" "%TOOLS%\pdftrim.c" ^
    "%SRC_DIR%\source\helpers\mu-threads\mu-threads.c" ^
    "%SRC_DIR%\source\helpers\pkcs7\pkcs7-openssl.c" ^
    "%SRC_DIR%\thirdparty\mujs\one.c" ^
    /Fo"%MUTOOL_DIR%\\" /Fe"%MUTOOL_DIR%\mutool.exe" ^
    /link "%SRC_DIR%\%SLN_DIR%\%SLN_PLAT%\%CONFIG%\mupdfcpp64.lib" ^
    wsetargv.obj kernel32.lib user32.lib advapi32.lib shell32.lib
if errorlevel 1 exit 1

:: -----------------------------------------------------------------------
:: Install mutool, headers, and libraries
:: -----------------------------------------------------------------------
cmake -E make_directory %LIBRARY_BIN%
if errorlevel 1 exit 1
cmake -E copy "%MUTOOL_DIR%\mutool.exe" %LIBRARY_BIN%\
if errorlevel 1 exit 1

:: Install C headers
cmake -E make_directory %LIBRARY_INC%
if errorlevel 1 exit 1
cmake -E copy_directory %SRC_DIR%\include %LIBRARY_INC%
if errorlevel 1 exit 1

:: Install generated C++ binding headers (classes.h, classes2.h, etc.)
cmake -E copy_directory %SRC_DIR%\platform\c++\include %LIBRARY_INC%
if errorlevel 1 exit 1

:: Install the import library and DLLs. The other .lib files in the build
:: directory are static libraries (libmupdf, libharfbuzz, libtesseract, ...)
:: that are already linked into mupdfcpp64.dll. They add about
:: 1.5 GB to the installed package, so don't ship them.
cmake -E make_directory %LIBRARY_LIB%
if errorlevel 1 exit 1
cmake -E copy %SRC_DIR%\%SLN_DIR%\%SLN_PLAT%\%CONFIG%\mupdfcpp64.lib %LIBRARY_LIB%\
if errorlevel 1 exit 1
for %%f in (%SRC_DIR%\%SLN_DIR%\%SLN_PLAT%\%CONFIG%\*.dll) do (
    copy "%%f" "%LIBRARY_BIN%\"
)
