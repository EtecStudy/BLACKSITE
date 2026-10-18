"""Small deterministic GLB writer for the procedural crate preview when Blender is unavailable."""
import json, struct, os
# One beveled-looking crate body as a correctly shaded six-face box; dimensions in metres.
positions=[]; normals=[]; indices=[]
faces=[((0,0,-1),[(-.675,-.525,0),(.675,-.525,0),(.675,.525,0),(-.675,.525,0)]),((0,0,1),[(-.675,-.525,1.2),(-.675,.525,1.2),(.675,.525,1.2),(.675,-.525,1.2)]),((0,-1,0),[(-.675,-.525,0),(-.675,-.525,1.2),(.675,-.525,1.2),(.675,-.525,0)]),((0,1,0),[(-.675,.525,0),(.675,.525,0),(.675,.525,1.2),(-.675,.525,1.2)]),((-1,0,0),[(-.675,-.525,0),(-.675,.525,0),(-.675,.525,1.2),(-.675,-.525,1.2)]),((1,0,0),[(.675,-.525,0),(.675,-.525,1.2),(.675,.525,1.2),(.675,.525,0)])]
for n, verts in faces:
    base=len(positions); positions.extend([(x,z,y) for x,y,z in verts]); normals.extend([(nx,nz,ny) for nx,ny,nz in [n]*4]); indices.extend([base,base+1,base+2,base,base+2,base+3])
posbytes=b''.join(struct.pack('<3f',*p) for p in positions); normbytes=b''.join(struct.pack('<3f',*n) for n in normals); idxbytes=b''.join(struct.pack('<H',i) for i in indices)
blob=posbytes+normbytes+idxbytes
# 4-byte aligned buffer chunks
while len(blob)%4: blob+=b'\0'
views=[{'buffer':0,'byteOffset':0,'byteLength':len(posbytes),'target':34962},{'buffer':0,'byteOffset':len(posbytes),'byteLength':len(normbytes),'target':34962},{'buffer':0,'byteOffset':len(posbytes)+len(normbytes),'byteLength':len(idxbytes),'target':34963}]
acc=[{'bufferView':0,'componentType':5126,'count':len(positions),'type':'VEC3','min':[-.675,0,-.525],'max':[.675,1.2,.525]},{'bufferView':1,'componentType':5126,'count':len(normals),'type':'VEC3'},{'bufferView':2,'componentType':5123,'count':len(indices),'type':'SCALAR'}]
g={'asset':{'version':'2.0','generator':'BLACKSITE procedural crate generator'},'scene':0,'scenes':[{'nodes':[0]}],'nodes':[{'mesh':0,'name':'BLACKSITE_Storage_Crate'}],'meshes':[{'name':'Crate_body','primitives':[{'attributes':{'POSITION':0,'NORMAL':1},'indices':2,'material':0}]}],'materials':[{'name':'Oxidized_steel','pbrMetallicRoughness':{'baseColorFactor':[0.19,0.24,0.25,1],'metallicFactor':0.62,'roughnessFactor':0.82}}],'buffers':[{'byteLength':len(blob)}],'bufferViews':views,'accessors':acc}
j=json.dumps(g,separators=(',',':')).encode(); j+=b' '*((4-len(j)%4)%4)
total=12+8+len(j)+8+len(blob)
out=struct.pack('<4sII',b'glTF',2,total)+struct.pack('<I4s',len(j),b'JSON')+j+struct.pack('<I4s',len(blob),b'BIN\x00')+blob
os.makedirs('assets/models',exist_ok=True)
open('assets/models/blacksite_crate.glb','wb').write(out)
print(f'Wrote assets/models/blacksite_crate.glb ({len(out)} bytes, {len(indices)//3} triangles)')
