@echo off
setlocal
set DEST=C:\AVAILABLE\juego
if not exist "%DEST%" mkdir "%DEST%"
echo ============================================================
echo  A V A I L A B L E v0.4.1 FINAL - Instalador de Proyecto
echo ============================================================
echo Extrayendo las 3 partes del proyecto en %DEST% ...
for %%F in (
  AVAILABLE_v0.4.1_FINAL_Parte1_Codigo_3D_y_Cache.zip
  AVAILABLE_v0.4.1_FINAL_Parte2_Audio_SFX_y_Voces2.zip
  AVAILABLE_v0.4.1_FINAL_Parte3_Voces1.zip
) do (
  if exist "%%F" (
    echo  - Extrayendo %%F ...
    powershell -NoProfile -Command "Expand-Archive -LiteralPath '%%F' -DestinationPath '%DEST%' -Force"
  ) else (
    echo  [AVISO] No se encontro %%F en esta carpeta.
  )
)
echo.
echo [OK] Proyecto Godot 4.7.2 completo armado en %DEST%\project.godot
echo Ejecuta %DEST%\EXPORTAR_WINDOWS_Y_WEB.bat para compilar AVAILABLE.exe
pause
