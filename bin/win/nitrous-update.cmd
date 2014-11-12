@echo off
setlocal EnableExtensions

set process_id=%1
set app_path=%2
set archive_path=%3

set tmp_path=%TEMP%\nitrous-update
set backup_path=%app_path%.previous

REM ask for admin privilege - adapted from https://sites.google.com/site/eneerge/scripts/batchgotadmin
cacls "%SYSTEMROOT%\system32\config\system"

if '%ERRORLEVEL%' EQU '5' (
  goto uac_prompt
) else (
  goto got_admin
)

:uac_prompt
set run_cmd_path=%TEMP%\nitrous-update-run.cmd
echo @"%~s0" %1 %2 %3 > %run_cmd_path%
echo Set UAC = CreateObject^("Shell.Application"^) > "%TEMP%\nitrous-elevate.vbs"
echo UAC.ShellExecute "%run_cmd_path%", "", "", "runas", 1 >> "%TEMP%\nitrous-elevate.vbs"
"%TEMP%\nitrous-elevate.vbs"
exit

:got_admin
pushd "%CD%"
if exist "%TEMP%\nitrous-elevate.vbs" ( del "%TEMP%\nitrous-elevate.vbs" )
cd /D "%~dp0"

:wait_for_app_termination
for /f "tokens=2 usebackq" %%A in (`tasklist /nh /fi "PID eq %process_id%" 2^>^&1`) do (
  if %%A==%process_id% (
    ping -n 2 127.0.0.1 > NUL
    goto wait_for_app_termination
  ) else (
    goto install_app
  )
)

:install_app
rd /s /q %tmp_path%
md %tmp_path%

%app_path%"\resources\bin\win\unzip" %archive_path% -d %tmp_path%
move %app_path% %backup_path%
move %tmp_path%"\Nitrous" %app_path%

rd /s /q %backup_path%
del %archive_path%
rd /s /q %tmp_path%

start "" %app_path%"\Nitrous.exe"

exit 0