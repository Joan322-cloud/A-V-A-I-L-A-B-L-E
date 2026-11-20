# Script batch para Blender 4.0.2 — Genera mallas deformadas *_terror_cabeza.res
# Uso: blender --background --python tools/caras/generar_cabezas_terror.py
import os, math
try:
    import bpy
except ImportError:
    bpy = None

PERSONAJES = ['shero', 'rasec', 'trainer', 'guardia_fermin', 'grasa', 'perrito_rta', 'vitzo']

def deformar_modelo(nombre):
    if bpy is None:
        print(f'[SIM] Procesando {nombre}_terror_cabeza.glb')
        return
    ruta_glb = os.path.abspath(f'assets/models/{nombre}.glb')
    if not os.path.exists(ruta_glb):
        return
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=ruta_glb)
    for obj in bpy.context.scene.objects:
        if obj.type == 'MESH':
            for v in obj.data.vertices:
                if v.co.y > 1.35:
                    v.co.z += 0.035 * math.sin(v.co.x * 18.0)
                    if v.co.y < 1.52:
                        v.co.y -= 0.06
    out_path = os.path.abspath(f'assets/models/{nombre}_terror_cabeza.glb')
    bpy.ops.export_scene.gltf(filepath=out_path, export_format='GLB')
    print(f'[OK] Exportado {out_path}')

if __name__ == '__main__':
    for p in PERSONAJES:
        deformar_modelo(p)
