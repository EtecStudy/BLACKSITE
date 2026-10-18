"""BLACKSITE procedural prop source. Run with Blender 4.x: blender -b --python blender/source/generate_props.py.
Creates a low-poly industrial storage crate, a reusable prop suitable for GLB export.
"""
import bpy, os
from mathutils import Vector
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT_BLEND = os.path.join(ROOT, 'blender/source/blacksite_crate.blend')
OUT_GLB = os.path.join(ROOT, 'assets/models/blacksite_crate.glb')
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)

def material(name, color, metallic=0.0, roughness=0.82):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*color,1); p.inputs['Metallic'].default_value=metallic; p.inputs['Roughness'].default_value=roughness
    return m
steel=material('Painted_oxidized_steel',(0.19,0.24,0.25),0.62)
edge=material('Worn_edge_metal',(0.42,0.46,0.43),0.78)
warning=material('Muted_emergency_ochre',(0.48,0.22,0.08),0.25)
def cube(name, loc, scale, mat, bevel=0.035):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc); o=bpy.context.object; o.name=name; o.dimensions=scale; bpy.ops.object.transform_apply(location=False, rotation=False, scale=True); o.data.materials.append(mat)
    if bevel:
        mod=o.modifiers.new('Small_hard_surface_bevel','BEVEL'); mod.width=bevel; mod.segments=1
        o.modifiers.new('Weighted_corner_normals','WEIGHTED_NORMAL')
    return o
# 1.35 x 1.2 x 1.05 metre crate, centered on floor
cube('Crate_body',(0,0,0.6),(1.35,1.05,1.2),steel)
for x in (-0.56,0.56): cube('Vertical_reinforcement',(x,-0.54,0.6),(0.095,0.055,1.26),edge,0.015)
for z in (0.12,1.08): cube('Horizontal_reinforcement',(0,-0.54,z),(1.25,0.055,0.085),edge,0.012)
for x in (-0.4,0.4):
    for z in (0.28,0.92): cube('Rivet',(x,-0.58,z),(0.045,0.025,0.045),warning,0.01)
# Join by material is intentionally avoided: retain readable editable source meshes.
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
bpy.ops.object.select_all(action='DESELECT')
for o in bpy.context.scene.objects:
    if o.type=='MESH': o.select_set(True)
bpy.context.view_layer.objects.active=next(o for o in bpy.context.scene.objects if o.type=='MESH')
bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format='GLB', use_selection=True, export_apply=True)
print('Exported BLACKSITE crate:', OUT_BLEND, OUT_GLB)
