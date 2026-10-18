"""Offline structural checks; these do not substitute for Godot runtime/network tests."""
import json, pathlib, struct, unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
class ProjectStructure(unittest.TestCase):
    def test_main_scene_and_autoload_exist(self):
        p=(ROOT/'project.godot').read_text()
        self.assertIn('res://scenes/menu/main_menu.tscn',p)
        self.assertTrue((ROOT/'scripts/networking/net.gd').is_file())
    def test_multiplayer_features_present(self):
        s=(ROOT/'scripts/networking/net.gd').read_text()
        avatar=(ROOT/'scripts/player/avatar.gd').read_text()
        for token in ('ENetMultiplayerPeer','MAX_PLAYERS := 4','_rpc_snapshot','_on_peer_disconnected','create_server','create_client','move.is_finite()','server_simulate'):
            self.assertIn(token,s+avatar)
        self.assertIn('move_and_slide()',avatar)
        self.assertIn('get_remote_sender_id()',s)
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
    def test_blender_source_and_catalog(self):
        self.assertTrue((ROOT/'blender/source/generate_props.py').exists())
        catalog=(ROOT/'docs/ASSET_CATALOG.md').read_text()
        self.assertIn('CC0',catalog); self.assertIn('não utilizado',catalog.lower())
if __name__=='__main__': unittest.main(verbosity=2)
