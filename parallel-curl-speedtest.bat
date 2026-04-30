@echo off
setlocal EnableExtensions EnableDelayedExpansion

echo This script estimates maximum download speed.
echo Based on 3 URLs downloading in parallel.
echo NOTE: Results vary depending on server, route, Wi-Fi, VPN, and network load.

REM -------------------------------------------------------
REM CLEAN UP OLD TEMP FILES
REM -------------------------------------------------------
for %%I in (1 2 3) do (
    if exist "curl%%I.txt" del /q "curl%%I.txt" >nul 2>&1
)

REM -------------------------------------------------------
REM CHECK FOR CURL
REM -------------------------------------------------------
where curl >nul 2>&1
if errorlevel 1 (
    echo.
    echo ERROR: curl was not found.
    echo Windows 10/11 usually includes curl, but it may not be in PATH.
    pause
    exit /b 1
)

REM -------------------------------------------------------
REM USER INPUT
REM -------------------------------------------------------
echo.
set /p "TestLocation=Which location are you testing? "
set /p "BuildingArea=Which area of the building? "

if not defined TestLocation set "TestLocation=Unknown"
if not defined BuildingArea set "BuildingArea=Unknown"

REM -------------------------------------------------------
REM TIMESTAMP 12-HOUR CLOCK + MM/DD/YYYY
REM -------------------------------------------------------
set "hh=%TIME:~0,2%"
set "mm=%TIME:~3,2%"
set "hh=%hh: =0%"

set /a hhInt=1%hh% - 100

if %hhInt% GEQ 12 (
    set "period=PM"
    if %hhInt% GTR 12 set /a hhInt-=12
) else (
    set "period=AM"
    if %hhInt% EQU 0 set /a hhInt=12
)

set "hour12=%hhInt%"
set "dateshort=%DATE:~4,10%"
set "timestamp=%hour12%:%mm% %period% %dateshort%"

REM -------------------------------------------------------
REM CONFIGURATION
REM -------------------------------------------------------
set "DURATION=15"
set "serverCount=3"

set "URL1=https://dl.google.com/chrome/install/GoogleChromeStandaloneEnterprise64.msi"
set "URL2=https://dl.google.com/chrome/install/GoogleChromeEnterpriseBundle64.zip"
set "URL3=https://ftp.hp.com/pub/softpaq/sp147501-148000/sp147697.exe"

REM Alternative test files:
REM 129MB  - https://dl.google.com/chrome/install/GoogleChromeStandaloneEnterprise64.msi
REM 186MB  - https://dl.google.com/chrome/install/GoogleChromeEnterpriseBundle64.zip
REM 985MB  - https://ftp.hp.com/pub/softpaq/sp147501-148000/sp147697.exe
REM 1000MB - https://nbg1-speed.hetzner.com/1GB.bin
REM 100MB  - http://cachefly.cachefly.net/100mb.test
REM 512MB  - http://ipv4.download.thinkbroadband.com/512MB.zip

echo.
echo Starting %serverCount% parallel %DURATION%-second downloads...

for %%I in (1 2 3) do (
    set "url=!URL%%I!"
    echo [%%I/%serverCount%] hitting !url!

    start /b "" cmd /c ^
        curl -L -s -m %DURATION% -w "%%{speed_download}" -o nul "!url!" ^> "curl%%I.txt" 2^>nul
)

REM -------------------------------------------------------
REM WAIT FOR DOWNLOADS
REM -------------------------------------------------------
echo.
echo Waiting %DURATION% seconds for downloads to finish...

set "chars=-\|/"
for /L %%n in (0,1,%DURATION%) do (
    set /a idx=%%n %% 4
    call set "spin=%%chars:~!idx!,1%%"
    <nul set /p="!spin!"
    timeout /t 1 >nul
    <nul set /p=""
)

echo.

REM -------------------------------------------------------
REM COLLECT RESULTS
REM -------------------------------------------------------
for %%I in (1 2 3) do (
    set "bps%%I=0"

    if exist "curl%%I.txt" (
        for /f "usebackq delims=" %%B in ("curl%%I.txt") do (
            set "rawSpeed=%%B"

            REM Keep only the integer part if curl returns decimal bytes/sec.
            for /f "tokens=1 delims=." %%S in ("!rawSpeed!") do set "bps%%I=%%S"
        )
    )
)

REM -------------------------------------------------------
REM CONVERT BYTES/SEC TO MBPS
REM -------------------------------------------------------
for %%I in (1 2 3) do (
    set /a mbps%%I = bps%%I * 8 / 1000000
)

set /a Download_Speed = mbps1 + mbps2 + mbps3

echo.
echo Download Speed: %Download_Speed% Mbps

REM -------------------------------------------------------
REM LATENCY TEST
REM -------------------------------------------------------
echo.
echo Testing latency...

set "avgLatency=Unknown"

for /f "tokens=2 delims==" %%L in ('ping -n 4 google.com ^| findstr /i "Average"') do (
    set "avgLatencyRaw=%%L"
)

if defined avgLatencyRaw (
    for /f "tokens=1 delims=m " %%A in ("!avgLatencyRaw!") do (
        set "avgLatency=%%A"
    )
)

echo Latency: %avgLatency% ms

REM -------------------------------------------------------
REM ASCII GRAPH
REM -------------------------------------------------------
echo.
echo Speed breakdown by stream ^(each "#" = about 5 Mbps^):

call :drawBar "Curl 1" mbps1
call :drawBar "Curl 2" mbps2
call :drawBar "Curl 3" mbps3

echo.
call :drawConnector !mbps1! !mbps2! !mbps3!
echo.

REM -------------------------------------------------------
REM APPEND RESULTS
REM -------------------------------------------------------
(
    echo Timestamp:       %timestamp%
    echo Location:        %TestLocation%
    echo Building Area:   %BuildingArea%
    echo Download Speed:  %Download_Speed% Mbps
    echo Curl 1 Speed:    %mbps1% Mbps
    echo Curl 2 Speed:    %mbps2% Mbps
    echo Curl 3 Speed:    %mbps3% Mbps
    echo Latency:         %avgLatency% ms
    echo -------------------------------
) >> SpeedtestResult.txt

echo.
echo Results written to SpeedtestResult.txt

REM -------------------------------------------------------
REM CLEAN UP TEMP FILES
REM -------------------------------------------------------
for %%I in (1 2 3) do (
    if exist "curl%%I.txt" del /q "curl%%I.txt" >nul 2>&1
)

echo.
pause
exit /b 0

REM -------------------------------------------------------
REM SUBROUTINES
REM -------------------------------------------------------

:drawBar
REM %1 = label
REM %2 = variable name holding Mbps value

set "label=%~1"
set /a val=!%2!

if !val! LEQ 0 (
    set "bar="
) else (
    set /a len = val / 5
    if !len! LSS 1 set /a len=1
    call :repeatChar "#" !len! bar
)

echo   %label% [!bar!] !val! Mbps
goto :eof


:drawConnector
REM %1, %2, %3 are numeric Mbps values.

set /a s1 = %1 / 5
set /a s2 = %2 / 5
set /a s3 = %3 / 5

if %1 GTR 0 if !s1! LSS 1 set /a s1=1
if %2 GTR 0 if !s2! LSS 1 set /a s2=1
if %3 GTR 0 if !s3! LSS 1 set /a s3=1

REM The connector is only useful when stream speeds increase left-to-right.
REM If they do not, show a simple marker line instead.

if !s2! LSS !s1! goto simpleConnector
if !s3! LSS !s2! goto simpleConnector

set "indent=        "

call :repeatChar " " !s1! sp
set "line=%indent%!sp!O"

set /a gap = s2 - s1 - 1
set "d="
if !gap! GTR 0 call :repeatChar "-" !gap! d
set "line=!line!!d!O"

set /a gap = s3 - s2 - 1
set "d="
if !gap! GTR 0 call :repeatChar "-" !gap! d
set "line=!line!!d!O"

echo   !line!
goto :eof


:simpleConnector
echo   Stream comparison line skipped because speeds are not left-to-right ascending.
goto :eof


:repeatChar
REM %1 = character
REM %2 = count
REM %3 = output variable name

setlocal EnableDelayedExpansion

set "char=%~1"
set /a cnt=%~2
set "out="

if !cnt! GTR 0 (
    for /L %%N in (1,1,!cnt!) do set "out=!out!!char!"
)

endlocal & set "%~3=%out%"
goto :eof