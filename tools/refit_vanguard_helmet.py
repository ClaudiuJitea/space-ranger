"""Reference helmet: swept crown, recessed horizontal optics and tapered jaw."""
import bpy, math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def refit():
    scene=bpy.data.scenes['Vanguard_Rigged_Rebuild'];bpy.context.window.scene=scene
    root=next(o for o in scene.objects if o.name.startswith('VanguardHelmet'))
    for o in list(root.children_recursive):bpy.data.objects.remove(o,do_unlink=True)
    root.scale=(1,1,1);root.location=(0,.015,1.57);root.rotation_euler=(0,0,math.pi)
    ns={'__name__':'helmet_helpers','__file__':str(ROOT/'tools/build_apex_vanguard.py')}
    exec(compile(Path(ns['__file__']).read_text(),ns['__file__'],'exec'),ns)
    p,material,plate,cylinder,box=[ns[x] for x in ['p','material','plate','cylinder','box']]
    armor=material('Vanguard Helmet brushed titanium',(.25,.30,.32),.72,.46)
    edge=material('Vanguard Helmet dark graphite',(.085,.115,.13),.65,.52)
    dark=material('Vanguard Helmet recessed seals',(.009,.016,.021),.12,.68)
    optic=material('Vanguard Helmet ruby optics',(.48,.004,.007),.3,.28,1.5)
    # Low-poly curved sections with a narrowed chin and a swept, rounded crown.
    sections=[(-.108,.054,.065,.035),(-.07,.082,.088,.022),(.005,.112,.104,.008),(.09,.118,.108,-.004),(.145,.113,.108,-.012),(.192,.085,.089,-.025),(.217,.033,.049,-.026)]
    verts=[];faces=[];n=24
    for y,rx,rz,cz in sections:
        for i in range(n):
            a=math.tau*i/n
            verts.append(p((rx*math.sin(a),y,cz+rz*math.cos(a))))
    for j in range(len(sections)-1):
        for i in range(n):faces.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
    faces.extend([tuple(reversed(range(n))),tuple(range((len(sections)-1)*n,len(sections)*n))])
    mesh=bpy.data.meshes.new('Swept helmet crown');mesh.from_pydata(verts,[],faces);mesh.update()
    o=bpy.data.objects.new('Vanguard swept helmet shell',mesh);scene.collection.objects.link(o);ns['finish'](o,root,armor,.003)
    for f in mesh.polygons:f.use_smooth=True
    # Visor is below the brow, not two lights on a vertical side panel.
    plate(root,'Recessed horizontal visor',[(-.105,.090),(-.076,.108),(.075,.108),(.105,.087),(.081,.050),(-.080,.050)],.112,.008,dark)
    for side in [-1,1]:
        plate(root,'Ruby horizontal eye strip',[(side*.009,.073),(side*.094,.080),(side*.083,.061),(side*.011,.057)],.122,.004,optic)
        plate(root,'Swept brow armour',[(side*.006,.110),(side*.060,.154),(side*.113,.133),(side*.107,.093),(side*.075,.095),(side*.008,.086)],.130,.013,armor)
        plate(root,'Tapered cheek guard',[(side*.108,.068),(side*.114,.025),(side*.078,-.077),(side*.038,-.104),(side*.052,-.032),(side*.074,.021)],.115,.018,edge)
        plate(root,'Cheek machined seam',[(side*.087,.024),(side*.094,.012),(side*.063,-.066),(side*.057,-.057)],.138,.003,armor)
        cylinder(root,'Recessed temple receiver',(side*.112,.084,-.010),.029,.009,edge,axis='X')
        cylinder(root,'Temple steel insert',(side*.117,.084,-.010),.018,.004,armor,axis='X')
    plate(root,'Angled central forehead',[(-.026,.203),(.026,.203),(.044,.148),(.026,.111),(0,.088),(-.028,.111),(-.042,.149)],.118,.016,armor)
    plate(root,'Nasal bridge',[(-.009,.087),(.009,.087),(.025,.024),(0,-.031),(-.024,.024)],.145,.010,edge)
    plate(root,'Pointed respirator chin',[(-.038,.009),(.037,.009),(.046,-.035),(.021,-.097),(0,-.115),(-.027,-.093),(-.045,-.035)],.126,.014,armor)
    for i in range(5):
        box(root,'Respirator vertical vent',((i-2)*.011,-.040,.145),(.005,.051,.004),dark,.001)
    cylinder(root,'Neck pressure gasket',(0,-.119,-.002),.063,.023,dark,axis='Y')
    print('REFERENCE HELMET REBUILT: horizontal brow optics, swept crown, tapered cheek and chin')

def export():
    bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models/campaign_bosses/apex.glb'),export_format='GLB',use_active_scene=True,export_animations=True,export_animation_mode='NLA_TRACKS')
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/models/campaign_bosses/campaign_boss_workbench.blend'))
if __name__=='__main__':refit();export()
