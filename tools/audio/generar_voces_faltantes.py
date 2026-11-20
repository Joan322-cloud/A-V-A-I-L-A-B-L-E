# Generador Kokoro-82M TTS local para líneas adicionales (Apache-2.0)
# Uso: python tools/audio/generar_voces_faltantes.py
import os

LINEAS_PENDIENTES = {
    'papayala/papayala_silla.ogg': 'Ya te marqué Break en C-14, Jiroshi. De nada.',
    'tm/om_cinco_ofertas.ogg': 'Jiroshi, la Fila C está perdiendo gente. Elige una de las cinco opciones antes de salir.',
    'otros/fermin_persecucion.ogg': '¡Ey! ¡Nadie cruza los molinetes sin revisión! ¡Regresa acá!'
}

if __name__ == '__main__':
    os.makedirs('assets/audio/voces/papayala', exist_ok=True)
    os.makedirs('assets/audio/voces/tm', exist_ok=True)
    os.makedirs('assets/audio/voces/otros', exist_ok=True)
    for rel, txt in LINEAS_PENDIENTES.items():
        print(f'[KOKORO-READY] {rel} -> {txt}')
