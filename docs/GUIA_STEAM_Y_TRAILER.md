# Guía de Publicación en Steam y Tráiler Oficial — A V A I L A B L E (v0.4.1)

## 1. Checklist previo a Steamworks
1. Cambia `const DEV_TOOLS_ENABLED: bool = false` en `scripts/autoload/game_state.gd`.
2. Coloca tu `APP_ID` oficial de Steam Direct en `scripts/autoload/steam_manager.gd` y `steam_appid.txt`.
3. Ejecuta `EXPORTAR_WINDOWS_Y_WEB.bat` con Godot 4.7.2 para compilar `AVAILABLE.exe` + `AVAILABLE.pck` + `AVAILABLE.html`.
4. Sube el depot con `SteamCMD` (incluyendo la carpeta `asr/` junto a `AVAILABLE.exe` y `AVAILABLE.pck`).

## 2. Guion del Tráiler de Steam (65 segundos · 1080p 60 FPS)
- **0:00 – 0:15 · El anzuelo cotidiano:** Aula del Training (24 Oct 2025) con luz cálida, café y el Trainer sonriendo. Firma del contrato con el ratón → corte a negro: *«1 AÑO DESPUÉS»*.
- **0:15 – 0:32 · La presión del call center:** Timbre en Fonex, mensajes de Shero en Ezlaki (*«No hay breaks»*), reloj en `03:47 AM`, clientes furiosos y el Perrito RTA blanco patrullando la Fila C.
- **0:32 – 0:52 · Escalada de terror:** Vitzo saliendo del monitor CRT; Haime en sala roja (`● REC`); reflejo en el baño; Shero Gigante (`6 m`) el Viernes derrumbando el techo del Piso 2.
- **0:52 – 1:05 · Clímax y cierre:** Azotea del Sábado bajo la lluvia; GRASA girando su rostro deformado con *«¡HAIL GRASAAAA!»* → logo `● A V A I L A B L E · Agrégalo a tu Lista de Deseados en Steam`.
