@echo off
set ADB="%USERPROFILE%\AppData\Local\Android\Sdk\platform-tools\adb.exe"
echo Restoring adb reverse tunnels...
%ADB% reverse tcp:8082 tcp:8082
%ADB% reverse tcp:5000 tcp:5000
echo Tunnels restored:
%ADB% reverse --list
pause
