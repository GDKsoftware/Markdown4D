@echo off
setlocal

set ROOT=%~dp0
rem The install root carries brackets, so every expansion of it stays quoted.
if not defined STUDIO_ROOT set "STUDIO_ROOT=C:\Program Files (x86)\Embarcadero\Studio"

rem Newest supported Delphi first: 37.0 is Delphi 13, 23.0 is Delphi 12 Athens.
rem Set MARKDOWN4D_STUDIO to a version number to force one of them.
if defined MARKDOWN4D_STUDIO (
    set "RSVARS=%STUDIO_ROOT%\%MARKDOWN4D_STUDIO%\bin\rsvars.bat"
) else (
    for %%V in (37.0 23.0) do (
        if not defined RSVARS if exist "%STUDIO_ROOT%\%%V\bin\rsvars.bat" set "RSVARS=%STUDIO_ROOT%\%%V\bin\rsvars.bat"
    )
)

set TEST_PROJECT=%ROOT%Tests\Markdown4D.Tests.dproj
set TEST_EXE=%ROOT%Tests\Win32\Debug\Markdown4D.Tests.exe
set FMX_TEST_PROJECT=%ROOT%Tests\Markdown4D.Fmx.Tests.dproj
set FMX_TEST_EXE=%ROOT%Tests\Win32\Debug\Markdown4D.Fmx.Tests.exe
set RESULTS_DIR=%ROOT%Tests\results
set RESULTS_XML=%RESULTS_DIR%\dunitx-results.xml
set FMX_RESULTS_XML=%RESULTS_DIR%\dunitx-fmx-results.xml

if not defined RSVARS (
    echo [build] No supported Delphi found under "%STUDIO_ROOT%".
    echo [build] Looked for 37.0 ^(Delphi 13^) and 23.0 ^(Delphi 12 Athens^).
    echo [build] Set MARKDOWN4D_STUDIO to a version number, or STUDIO_ROOT to another install root.
    exit /b 1
)

if not exist "%RSVARS%" (
    echo [build] rsvars.bat not found at "%RSVARS%".
    exit /b 1
)

echo [build] Using "%RSVARS%"

call "%RSVARS%"

echo.
echo === Building test suites ^(Debug, Win32^) ===
for %%T in ("%TEST_PROJECT%" "%FMX_TEST_PROJECT%") do (
    msbuild "%%~T" /t:Build /p:Config=Debug /p:Platform=Win32 /v:m
    if errorlevel 1 (
        echo.
        echo === TEST BUILD FAILED: %%~nxT ===
        exit /b 1
    )
)

if not exist "%RESULTS_DIR%" mkdir "%RESULTS_DIR%"

echo.
echo === Running main test suite ===
"%TEST_EXE%" -xml:"%RESULTS_XML%" -exit:continue
set MAIN_EXIT=%ERRORLEVEL%

echo.
echo === Running FMX test suite ===
"%FMX_TEST_EXE%" -xml:"%FMX_RESULTS_XML%" -exit:continue
set FMX_EXIT=%ERRORLEVEL%

echo.
if "%MAIN_EXIT%"=="0" (
    echo === Main suite: all tests passed ===
) else (
    echo === Main suite: failures reported, exit code %MAIN_EXIT% ===
)
if "%FMX_EXIT%"=="0" (
    echo === FMX suite: all tests passed ===
) else (
    echo === FMX suite: failures reported, exit code %FMX_EXIT% ===
)

echo.
echo === Building example projects ^(Debug, Win32^) ===
for %%P in (
    "%ROOT%Examples\Markdown4DStudioVCL\Markdown4DStudioVCL.dproj"
    "%ROOT%Examples\StreamingMarkdownVCL\StreamingMarkdownVCL.dproj"
    "%ROOT%Examples\Markdown4DStudioFMX\Markdown4DStudioFMX.dproj"
    "%ROOT%Examples\StreamingMarkdownFMX\StreamingMarkdownFMX.dproj"
) do (
    msbuild "%%~P" /t:Build /p:Config=Debug /p:Platform=Win32 /v:m
    if errorlevel 1 (
        echo.
        echo === EXAMPLE BUILD FAILED: %%~nxP ===
        exit /b 1
    )
)

echo.
echo === Building Markdown4D packages ^(Release, Win32^) ===
for %%K in (
    "%ROOT%packages\Markdown4D.Core.dproj"
    "%ROOT%packages\Markdown4D.Vcl.dproj"
    "%ROOT%packages\Markdown4D.Fmx.dproj"
    "%ROOT%packages\Markdown4D.Vcl.Design.dproj"
    "%ROOT%packages\Markdown4D.Fmx.Design.dproj"
) do (
    msbuild "%%~K" /t:Build /p:Config=Release /p:Platform=Win32 /v:m
    if errorlevel 1 (
        echo.
        echo === PACKAGE BUILD FAILED: %%~nxK ===
        exit /b 1
    )
)

echo.
echo === Building VCL packages ^(Release, Win64x^) ===
for %%K in (
    "%ROOT%packages\Markdown4D.Core.dproj"
    "%ROOT%packages\Markdown4D.Vcl.dproj"
    "%ROOT%packages\Markdown4D.Vcl.Design.dproj"
) do (
    msbuild "%%~K" /t:Build /p:Config=Release /p:Platform=Win64x /v:m
    if errorlevel 1 (
        echo.
        echo === PACKAGE BUILD FAILED ^(Win64x^): %%~nxK ===
        exit /b 1
    )
)

echo.
echo === Updating conformance dashboard ===
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%tools\Update-ConformanceDashboard.ps1"

echo.
echo === Build succeeded ===
exit /b 0
