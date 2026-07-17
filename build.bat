@echo off
setlocal

set ROOT=%~dp0
set RSVARS=C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat
set TEST_PROJECT=%ROOT%Tests\Markdown4D.Tests.dproj
set TEST_EXE=%ROOT%Tests\Win32\Debug\Markdown4D.Tests.exe
set FMX_TEST_PROJECT=%ROOT%Tests\Markdown4D.Fmx.Tests.dproj
set FMX_TEST_EXE=%ROOT%Tests\Win32\Debug\Markdown4D.Fmx.Tests.exe
set RESULTS_DIR=%ROOT%Tests\results
set RESULTS_XML=%RESULTS_DIR%\dunitx-results.xml
set FMX_RESULTS_XML=%RESULTS_DIR%\dunitx-fmx-results.xml

if not exist "%RSVARS%" (
    echo [build] rsvars.bat not found at "%RSVARS%".
    exit /b 1
)

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
    "%ROOT%Examples\Md2Html\Md2Html.dproj"
    "%ROOT%Examples\VclViewerDemo\VclViewerDemo.dproj"
    "%ROOT%Examples\MarkdownPad\MarkdownPad.dproj"
    "%ROOT%Examples\LlmChat\LlmChat.dproj"
    "%ROOT%Examples\FmxViewerDemo\FmxViewerDemo.dproj"
    "%ROOT%Examples\FmxMarkdownPad\FmxMarkdownPad.dproj"
    "%ROOT%Examples\FmxLlmChat\FmxLlmChat.dproj"
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
echo === Updating conformance dashboard ===
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%tools\Update-ConformanceDashboard.ps1"

echo.
echo === Build succeeded ===
exit /b 0
