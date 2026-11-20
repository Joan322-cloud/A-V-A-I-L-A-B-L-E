@echo off
setlocal
set GODOT="C:\AVAILABLE\herramientas\godot\Godot_v4.7.2-stable_win64.exe"
if not exist %GODOT% (
  echo [INFO] Ajusta la ruta de Godot_v4.7.2-stable_win64.exe en EXPORTAR_WINDOWS_Y_WEB.bat
  pause
  exit /b 1
)
mkdir ..\builds\windows 2>nul
mkdir ..\builds\web_single 2>nul
echo [1/2] Exportando ejecutable de Windows (AVAILABLE.exe + PCK embebido)...
%GODOT% --headless --export-release "Windows" "..\builds\windows\AVAILABLE.exe"
echo [2/2] Exportando version HTML de un solo archivo...
%GODOT% --headless --export-release "Web (single file)" "..\builds\web_single\AVAILABLE.html"
echo [OK] Exportacion finalizada sin errores en ..\builds\windows\AVAILABLE.exe
pause
