"""Offline structural checks; these do not substitute for Godot runtime/network tests."""
import json, pathlib, re, struct, unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
class ProjectStructure(unittest.TestCase):
    def test_main_scene_and_autoload_exist(self):
        p=(ROOT/'project.godot').read_text()
        self.assertIn('res://scenes/menu/main_menu.tscn',p)
        self.assertTrue((ROOT/'scripts/networking/net.gd').is_file())
    def test_multiplayer_features_present(self):
        s=(ROOT/'scripts/networking/net.gd').read_text()
        avatar=(ROOT/'scripts/player/avatar.gd').read_text()
        for token in ('ENetMultiplayerPeer','MAX_PLAYERS := 4','_rpc_snapshot','_on_peer_disconnected','create_server','create_client','move.is_finite()','server_simulate','last_input_ms'):
            self.assertIn(token,s+avatar)
        self.assertIn('move_and_slide()',avatar)
        self.assertIn('get_remote_sender_id()',s)
        for marker in ('create_server falhou','create_client falhou','Primeira intencao de movimento','Timeout de input','_timed_out.has(id)'):
            self.assertIn(marker,s)
        self.assertIn('Camera3D.current = is_local',avatar)
        self.assertIn('current = false',(ROOT/'scenes/player/avatar.tscn').read_text())
    def test_world_collision_and_props(self):
        s=(ROOT/'scripts/player/sector.gd').read_text()
        self.assertIn('StaticBody3D.new()',s); self.assertIn('BoxShape3D.new()',s)
        self.assertIn('blacksite_crate.glb',s); self.assertIn('_door_frame',s); self.assertIn('_lamp',s)
    def test_glb_container_and_json(self):
        b=(ROOT/'assets/models/blacksite_crate.glb').read_bytes()
        self.assertEqual(b[:4],b'glTF'); version,total=struct.unpack_from('<II',b,4)
        self.assertEqual(version,2); self.assertEqual(total,len(b))
        json_len=struct.unpack_from('<I',b,12)[0]
        self.assertEqual(b[16:20],b'JSON')
        doc=json.loads(b[20:20+json_len].decode().rstrip())
        self.assertEqual(doc['asset']['version'],'2.0')
        self.assertEqual(doc['accessors'][2]['count'],36)
        # GLTF is Y-up: the crate's vertical extent is Y, not Z.
        self.assertEqual(doc['accessors'][0]['max'],[0.675,1.2,0.525])
        views=doc['bufferViews']; accessors=doc['accessors']; binary_offset=20+json_len+8
        positions=struct.unpack_from('<%df' % (accessors[0]['count']*3),b,binary_offset+views[0]['byteOffset'])
        normals=struct.unpack_from('<%df' % (accessors[1]['count']*3),b,binary_offset+views[1]['byteOffset'])
        indices=struct.unpack_from('<%dH' % accessors[2]['count'],b,binary_offset+views[2]['byteOffset'])
        for k in range(0,len(indices),3):
            i,j,l=indices[k:k+3]
            u=[positions[j*3+x]-positions[i*3+x] for x in range(3)]
            v=[positions[l*3+x]-positions[i*3+x] for x in range(3)]
            cross=(u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0])
            self.assertGreater(sum(cross[x]*normals[i*3+x] for x in range(3)),0)
    def test_all_godot_resource_paths_resolve(self):
        sources=[ROOT/'project.godot', *ROOT.rglob('*.gd'), *ROOT.rglob('*.tscn')]
        missing=[]
        for source in sources:
            text=source.read_text(encoding='utf-8')
            for relative in re.findall(r'res://([A-Za-z0-9_./-]+)',text):
                if not (ROOT/relative).is_file(): missing.append((source.relative_to(ROOT),relative))
        self.assertEqual(missing,[])
        project=(ROOT/'project.godot').read_text(encoding='utf-8')
        self.assertIn('run/main_scene="res://scenes/menu/main_menu.tscn"',project)
        self.assertIn('PackedStringArray("4.3", "GL Compatibility")',project)

    def test_windows_helpers_are_real_and_guard_paths(self):
        starter=(ROOT/'INICIAR_BLACKSITE.bat').read_text(encoding='utf-8')
        validator=(ROOT/'VALIDAR_BLACKSITE.bat').read_text(encoding='utf-8')
        for token in ('project.godot','GODOT_EXE','--version','--path','4.3'):
            self.assertIn(token,starter)
        for token in ('project.godot','main_menu.tscn','python','unittest','NAO EXECUTADO','nao foram testados'):
            self.assertIn(token.lower(),validator.lower())

    def test_blender_source_and_catalog(self):
        self.assertTrue((ROOT/'blender/source/generate_props.py').exists())
        catalog=(ROOT/'docs/ASSET_CATALOG.md').read_text()
        self.assertIn('CC0',catalog); self.assertIn('não utilizado',catalog.lower())
if __name__=='__main__': unittest.main(verbosity=2)
