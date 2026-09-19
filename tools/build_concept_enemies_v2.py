"""Second pass: modeled from the supplied four-panel concept sheet.
Primary forms use curved shells, swept profiles and tapered lofts.
Import into Blender through MCP and build one asset per call.
"""
import bpy, math, sys, importlib.util
import numpy as np
from mathutils import Vector
from pathlib import Path

BASE=Path('/home/clau/Godot/games/space-ranger')
spec=importlib.util.spec_from_file_location('concept_helpers',str(BASE/'tools/build_reference_enemies.py'))
h=importlib.util.module_from_spec(spec); spec.loader.exec_module(h)
OUT=BASE/'assets/models/concept_enemies_v2'
PREVIEW=BASE/'tools/blender_previews/concept_enemies_v2'
OUT.mkdir(parents=True,exist_ok=True); PREVIEW.mkdir(parents=True,exist_ok=True)
ROOTS={}
_cyl=h.cyl
def smooth_cylinder(*args,**kwargs):
    o=_cyl(*args,**kwargs)
    for f in o.data.polygons:f.use_smooth=len(f.vertices)==4
    return o
h.cyl=smooth_cylinder

def init():
    rng=np.random.default_rng(2309); n=1024
    grain=rng.random((n,n)).astype(np.float32)
    wear=np.ones((n,n),np.float32)
    # Restrained pits and machining scratches instead of conspicuous scribbles.
    for i in range(950):
        x,y=rng.integers(0,n,2); length=int(rng.integers(2,16))
        wear[y,x:min(n,x+length)]=rng.uniform(.56,.85)
    for i in range(1300):
        x,y=rng.integers(0,n,2); wear[y,x]=rng.uniform(.48,.8)
    var=(.97+grain*.045)*wear
    for name,col,metal,rough in [('ceramic',(.56,.54,.49),.50,.36),('armor',(.36,.38,.40),.65,.34),('dark',(.075,.09,.105),.72,.38),('steel',(.17,.195,.215),.91,.25),('edge',(.38,.40,.41),.9,.24),('rubber',(.012,.014,.018),.05,.66),('brass',(.37,.20,.055),.82,.27)]:
        mat=bpy.data.materials.new('CONCEPT2_'+name); mat.use_nodes=True
        bs=mat.node_tree.nodes.get('Principled BSDF'); bs.inputs['Base Color'].default_value=(*col,1)
        bs.inputs['Metallic'].default_value=metal; bs.inputs['Roughness'].default_value=rough
        if name in ['ceramic','armor','dark']:
            im=bpy.data.images.new('Concept2_'+name+'_Albedo',width=n,height=n)
            pix=np.ones((n,n,4),np.float32); pix[:,:,:3]=var[:,:,None]*np.array(col)
            im.pixels.foreach_set(pix.ravel()); im.pack()
            tex=mat.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=im
            mat.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
            norm=bpy.data.images.new('Concept2_'+name+'_Normal',width=n,height=n)
            pix[:,:,:3]=(.5,.5,1)
            pix[:,:,0]=.5+(grain-np.roll(grain,1,axis=0))*.045
            pix[:,:,1]=.5+(grain-np.roll(grain,1,axis=1))*.045
            norm.colorspace_settings.name='Non-Color'; norm.pixels.foreach_set(pix.ravel()); norm.pack()
            tex=mat.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=norm
            normal=mat.node_tree.nodes.new('ShaderNodeNormalMap'); normal.inputs['Strength'].default_value=.3
            mat.node_tree.links.new(tex.outputs['Color'],normal.inputs['Color']); mat.node_tree.links.new(normal.outputs['Normal'],bs.inputs['Normal'])
        h.M[name]=mat
    for name,col in [('red',(.65,.002,.008)),('orange',(.9,.20,.004)),('violet',(.27,.008,.85))]:
        mat=bpy.data.materials.new('CONCEPT2_'+name); mat.use_nodes=True
        bs=mat.node_tree.nodes.get('Principled BSDF'); bs.inputs['Base Color'].default_value=(*col,1)
        bs.inputs['Emission Color'].default_value=(*col,1); bs.inputs['Emission Strength'].default_value=1.35
        bs.inputs['Roughness'].default_value=.24; bs.inputs['Metallic'].default_value=.35; h.M[name]=mat
    # Previous assets remain editable, but are hidden in this workbench.
    for o in list(bpy.data.objects): o.hide_set(True); o.hide_render=True

def mesh(p,name,verts,faces,mat='ceramic',smooth=False,bevel=.008):
    me=bpy.data.meshes.new(name); me.from_pydata(verts,[],faces); me.update()
    o=bpy.data.objects.new(name,me); bpy.context.collection.objects.link(o); h.finish(o,name,mat,p,bevel)
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active=o
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.uv.smart_project(angle_limit=1.1,island_margin=.025); bpy.ops.object.mode_set(mode='OBJECT')
    for f in me.polygons: f.use_smooth=smooth
    return o

def loft(p,name,sections,mat='armor',corner=.16):
    verts=[]
    # Closed chamfered fuselage: side walls, roof and belly, never a scaled cube.
    for x,w,bot,top in sections:
        d=(top-bot)*corner
        verts.extend([(x,-w*(1-corner),bot),(x,w*(1-corner),bot),(x,w,bot+d),(x,w,top-d),(x,w*(1-corner),top),(x,-w*(1-corner),top),(x,-w,top-d),(x,-w,bot+d)])
    n=8; faces=[tuple(range(n-1,-1,-1)),tuple(range((len(sections)-1)*n,len(sections)*n))]
    faces += [(j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i) for j in range(len(sections)-1) for i in range(n)]
    return mesh(p,name,verts,faces,mat,False,.008)

def dome(p,name,center,radii,mat='dark'):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=16,location=center)
    o=bpy.context.object; o.scale=radii; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    h.finish(o,name,mat,p)
    for f in o.data.polygons:f.use_smooth=True
    return o

def shell(p,name,center,rx,ry,rz,start=-1.35,end=1.35,mat='ceramic',t=.024):
    # Longitudinal crown shell: curved in both axes, with a real inner surface.
    cx,cy,cz=center; verts=[]; nu=12; nv=24
    for layer in [0,1]:
        for i in range(nu+1):
            u=-1+2*i/nu; swell=math.sqrt(max(.01,1-u*u*.28))
            for j in range(nv+1):
                a=start+(end-start)*j/nv
                verts.append((cx+u*rx,cy+(ry-layer*t)*math.sin(a)*swell,cz+(rz-layer*t)*math.cos(a)*swell))
    k=(nu+1)*(nv+1); faces=[]
    for layer in [0,1]:
        for i in range(nu):
            for j in range(nv):
                v=layer*k+i*(nv+1)+j
                face=(v,v+1,v+nv+2,v+nv+1); faces.append(face if layer==0 else tuple(reversed(face)))
    for i in range(nu):
        for j in [0,nv]:
            v=i*(nv+1)+j; faces.append((v,v+nv+1,v+nv+1+k,v+k))
    for j in range(nv):
        for i in [0,nu]:
            v=i*(nv+1)+j; faces.append((v,v+1,v+1+k,v+k))
    return mesh(p,name,verts,faces,mat,True,.005)

def sweep(p,name,points,radii,mat='steel',sides=12):
    # Tapered articulated armor and curved hooked claws.
    anchors=[Vector(a) for a in points]
    rs=[Vector((r,r)) if isinstance(r,(float,int)) else Vector(r) for r in radii]
    pts=[]; radii=[]
    for i in range(len(anchors)-1):
        a=anchors[max(0,i-1)];b=anchors[i];c=anchors[i+1];d=anchors[min(len(anchors)-1,i+2)]
        for j in range(8):
            t=j/8
            pts.append(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t))
            radii.append(tuple(rs[i].lerp(rs[i+1],t)))
    pts.append(anchors[-1]);radii.append(tuple(rs[-1]));verts=[]
    for i,c in enumerate(pts):
        tangent=pts[min(i+1,len(pts)-1)]-pts[max(i-1,0)]
        tangent.normalize(); u=tangent.cross(Vector((0,1,0)))
        if u.length<.01: u=tangent.cross(Vector((0,0,1)))
        u.normalize(); v=tangent.cross(u).normalized()
        r=radii[i]; r=(r,r) if isinstance(r,(float,int)) else r
        for j in range(sides):
            a=j*2*math.pi/sides; verts.append(tuple(c+u*math.cos(a)*r[0]+v*math.sin(a)*r[1]))
    faces=[tuple(range(sides-1,-1,-1)),tuple(range((len(pts)-1)*sides,len(pts)*sides))]
    faces += [(i*sides+j,i*sides+(j+1)%sides,(i+1)*sides+(j+1)%sides,(i+1)*sides+j) for i in range(len(pts)-1) for j in range(sides)]
    return mesh(p,name,verts,faces,mat,True,.002)

def joint(p,c,r,s):
    h.cyl(p,'Dark joint socket',c,r,.064,'dark',(0,1,0),32)
    pos=Vector(c)+Vector((0,s*.041,0))
    h.ring(p,'Machined bearing race',pos,r*.83,.009,'steel',(0,1,0))
    h.cyl(p,'Inset joint cap',pos+Vector((0,s*.006,0)),r*.58,.016,'armor',(0,1,0),32)
    h.ring(p,'Axle inner collar',pos+Vector((0,s*.018,0)),r*.30,.006,'edge',(0,1,0))
    h.cyl(p,'Hex axle head',pos+Vector((0,s*.021,0)),r*.18,.009,'dark',(0,1,0),6)
    for i in range(6):
        a=i*math.pi/3
        co=pos+Vector((math.cos(a)*r*.70,s*.016,math.sin(a)*r*.70))
        h.cyl(p,'Scale-correct recessed bearing screw',co,r*.075,.005,'steel',(0,1,0),6)

def shoulder_cowl(p,c,s):
    cx,cy,cz=c;verts=[];nt=36;nr=4
    for layer in [0,1]:
        for i in range(nr+1):
            r=.095+i*.014
            for j in range(nt+1):
                a=-.35+j*(math.pi+.80)/nt
                yy=cy+s*(.085+.022*math.sin(i*math.pi/nr)-layer*.013)
                verts.append((cx+math.cos(a)*r,yy,cz+math.sin(a)*r))
    k=(nr+1)*(nt+1);faces=[]
    for layer in [0,1]:
        for i in range(nr):
            for j in range(nt):
                v=layer*k+i*(nt+1)+j;faces.append((v,v+1,v+nt+2,v+nt+1))
    for i in range(nr):
        for j in [0,nt]:
            v=i*(nt+1)+j;faces.append((v,v+nt+1,v+nt+1+k,v+k))
    for j in range(nt):
        for i in [0,nr]:
            v=i*(nt+1)+j;faces.append((v,v+1,v+1+k,v+k))
    mesh(p,'Scalloped curved shoulder cowl',verts,faces,'ceramic',True,.003)
    h.cable(p,'Shoulder cowl inset seam',[(cx+.142*math.cos(a),cy+s*.090,cz+.142*math.sin(a)) for a in np.linspace(-.25,math.pi+.3,12)],'dark',.003)
    for a in [.3,1.5,2.6]:
        h.cyl(p,'Shoulder flush retaining screw',(cx+.12*math.cos(a),cy+s*.106,cz+.12*math.sin(a)),.005,.004,'dark',(0,1,0),6)

def slit(p,loc,size,mat='rubber',rot=(0,0,0)):
    return h.box(p,'Recessed machined slot',loc,size,mat,rot,.002)

def barrel(p,tip,y,z,length,r,energy,shroud=False):
    h.cyl(p,'Recoil breech',(tip-length*.75,y,z),r*1.2,length*.48,'steel',(1,0,0),32)
    h.cyl(p,'Inner cannon tube',(tip-length*.35,y,z),r*.74,length*.65,'dark',(1,0,0),32)
    for f in [.20,.40,.65]:
        h.ring(p,'Barrel retaining collar',(tip-length*f,y,z),r*.79,.008,'edge',(1,0,0))
    if shroud:
        # Perforated heat shroud assembled around a recessed inner barrel.
        sh=h.cyl(p,'Vented barrel heat shroud',(tip-length*.29,y,z),r,.52*length,'armor',(1,0,0),48)
        cuts=[]
        for i in range(8):
            a=i*math.pi/4
            for j in range(5):
                xx=tip-length*.50+j*length*.095
                cuts.append(h.cyl(None,'Temporary shroud perforation',(xx,y+r*.91*math.cos(a),z+r*.91*math.sin(a)),.011,r*.7,'rubber',(0,math.cos(a),math.sin(a)),16))
        bpy.ops.object.select_all(action='DESELECT')
        for o in cuts:o.select_set(True)
        bpy.context.view_layer.objects.active=cuts[0];bpy.ops.object.join();cut=cuts[0]
        mod=sh.modifiers.new('Actual shroud cooling perforations','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cut
        bpy.context.view_layer.objects.active=sh;bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.data.objects.remove(cut,do_unlink=True)
    h.cyl(p,'Deep muzzle bore',(tip-.025,y,z),r*.79,.015,'rubber',(1,0,0),32)
    h.ring(p,'Hollow muzzle chamfer',(tip,y,z),r*.88,.012,'steel',(1,0,0))
    h.ring(p,'Inset bore ring',(tip-.011,y,z),r*.62,.006,energy,(1,0,0))

def optic(p,loc,r,color,axis=(1,0,0)):
    c=Vector(loc); a=Vector(axis).normalized()
    h.cyl(p,'Optic recessed casing',c,r*1.22,.035,'dark',a,32)
    h.ring(p,'Optic polished bezel',c+a*.020,r,.007,'edge',a)
    h.cyl(p,'Luminous optical glass',c+a*.021,r*.82,.01,color,a,32)
    h.ring(p,'Lens iris',c+a*.028,r*.46,.004,'dark',a)
    h.cyl(p,'Lens pupil',c+a*.031,r*.21,.008,color,a,32)

def crawler():
    p=h.root('RIFT_Crawler_V2')
    dome(p,'Low predator ribcage',(-.18,0,.48),(.45,.19,.19))
    dome(p,'Rear drive pelvis',(-.45,0,.48),(.19,.19,.14),'steel')
    # Rounded overlapping carapace panels with inset red seams.
    for x,rz in [(-.48,.16),(-.27,.28),(-.055,.28),(.12,.155)]:
        shell(p,'Curved segmented carapace',(x,0,.48),.12,.23,rz)
        shell(p,'Inset dark panel seam',(x+.107,0,.48),.012,.231,rz+.002,mat='dark',t=.01)
        shell(p,'Red power seam',(x+.12,0,.48),.007,.218,rz-.015,start=-1.15,end=1.15,mat='red',t=.004)
        h.plate(p,'Swept dorsal spine',[(x-.10,.48+rz),(x-.13,.53+rz),(x-.045,.56+rz),(x+.083,.49+rz),(x+.10,.46+rz)],0,.04,'armor')
        h.cable(p,'Red dorsal conduit',[(x-.09,0,.51+rz),(x-.015,0,.535+rz),(x+.07,0,.48+rz)],'red',.008)
    head=h.root('PredatorSkull');head.parent=p
    loft(head,'Sloping predator skull',[(.17,.12,.45,.64),(.34,.145,.405,.66),(.52,.12,.355,.56),(.71,.08,.32,.43),(.81,.012,.335,.36)],'ceramic',.24)
    for s in [-1,1]:
        h.plate(head,'Inset cheek armor',[(.28,.48),(.42,.55),(.57,.47),(.52,.38),(.36,.405)],s*.133,.025,'armor')
        optic(head,(.55,s*.127,.425),.05,'red',(0,s,0))
        sweep(head,'Curved mandibular blade',[(.33,s*.10,.395),(.47,s*.105,.34),(.64,s*.095,.26),(.69,s*.075,.17)],[.027,.035,.020,.001],'steel')
        for x in [.29,.335,.38]: slit(head,(x,s*.151,.515),(.011,.008,.043),'rubber',(0,.5,0))
        h.cable(p,'Braided ribcage hose',[(-.50,s*.19,.48),(-.26,s*.235,.38),(.12,s*.18,.45)],r=.016)
        h.cable(p,'Inset red power line',[(-.43,s*.196,.54),(-.18,s*.23,.45),(.24,s*.14,.46)],'red',.008)
        for rear in [True,False]:
            hip=Vector((-.43 if rear else .13,s*.18,.53))
            knee=Vector((-.53 if rear else .21,s*.30,.29))
            wrist=Vector((-.58 if rear else .54,s*.34,.065))
            leg=h.root(('Rear' if rear else 'Front')+('_near' if s==-1 else '_far')); leg.parent=p
            lower=h.root('Shin'); lower.parent=leg
            paw=h.root('Paw'); paw.parent=lower
            joint(leg,hip,.083,s); joint(lower,knee,.055,s); joint(paw,wrist,.034,s)
            shoulder_cowl(p,hip,s)
            h.link(leg,'Upper leg load-bearing link',hip,knee,.036,'dark')
            h.link(lower,'Lower leg chrome piston',knee,wrist,.019,'edge')
            mid=(hip+knee)/2+Vector((.02,s*.035,0))
            sweep(leg,'Curved teardrop upper leg armor',[hip+Vector((-.03,s*.045,.05)),mid,knee+Vector((.04,s*.045,.035))],[(.065,.039),(.065,.055),(.014,.025)],'ceramic',16)
            mid=(knee+wrist)/2+Vector((.02,s*.026,0))
            sweep(lower,'Tapered curved shin shield',[knee+Vector((.015,s*.035,-.04)),mid,wrist+Vector((.015,s*.025,.045))],[(.043,.035),(.040,.035),(.016,.022)],'armor',12)
            h.link(leg,'Secondary hydraulic rod',hip+Vector((-.035,s*.06,-.01)),knee+Vector((-.015,s*.06,.015)),.010,'edge')
            h.cable(lower,'Flexible hydraulic hose',[knee+Vector((-.03,s*.02,0)),mid+Vector((-.04,0,0)),wrist],r=.009)
            for t in [-1,0,1]:
                co=wrist+Vector((.035,t*.037,0))
                sweep(paw,'Hooked predator claw',[co,co+Vector((.053,0,.022)),co+Vector((.10,0,.005)),co+Vector((.125,0,-.055))],[.021,.024,.015,.0008],'steel',10)
            h.cyl(paw,'Toe knuckle',wrist+Vector((.027,0,0)),.035,.10,'dark',(0,1,0),24)
            # Separate pivots keep armored limbs rigid while the joints bend.
            for o in paw.children:o.location-=wrist
            for o in lower.children:
                if o!=paw:o.location-=knee
            for o in leg.children:
                if o!=lower:o.location-=hip
            paw.location=wrist-knee
            lower.location=knee-hip
            leg.location=hip
    h.stencil(p,'RIFT',(-.28,-.221,.58),.025)
    head.scale.x=.75;head.location.x=.0425
    return p

def turret():
    import build_redesigned_turret
    return build_redesigned_turret.build_redesigned_sentry()


def gunship():
    p=h.root('HEAVY_Gunship_V2')
    # Long tapered aircraft fuselage, short swept wings and large rear engines.
    loft(p,'Tapered aircraft fuselage',[(-.70,.18,-.13,.12),(-.47,.25,-.21,.21),(.12,.22,-.19,.19),(.52,.15,-.14,.05),(.76,.07,-.11,-.04)],'armor',.25)
    loft(p,'Nose overlapping pale armor',[(.12,.227,-.199,.205),(.32,.195,-.18,.132),(.55,.144,-.141,.048),(.75,.076,-.10,-.025)],'ceramic',.2)
    h.box(p,'Recessed forward nose viewport',(.395,0,.112),(.145,.137,.009),'rubber',rot=(0,.35,0),bevel=.008)
    h.box(p,'Viewport inner glass',(.395,0,.117),(.116,.112,.006),'dark',rot=(0,.35,0),bevel=.005)
    loft(p,'Raised central command housing',[(-.37,.11,.15,.29),(-.28,.16,.19,.31),(.04,.145,.17,.29),(.19,.11,.13,.22)],'armor',.17)
    h.box(p,'Recessed command visor',(.151,0,.253),(.025,.185,.048),'rubber',rot=(0,.24,0),bevel=.008)
    h.box(p,'Violet command visor',(.168,0,.254),(.012,.145,.025),'violet',rot=(0,.24,0),bevel=.005)
    for s in [-1,1]:
        y=s*.38
        nacelle=loft(p,'Rear engine armored nacelle',[(-.64,.15,-.10,.14),(-.47,.18,-.14,.22),(-.16,.18,-.14,.22),(.03,.14,-.10,.12)],'armor',.28)
        nacelle.location.y=y
        cap=loft(p,'Engine pale upper cowling',[(-.52,.16,.15,.23),(-.38,.173,.19,.255),(-.18,.17,.19,.253),(-.035,.123,.12,.16)],'ceramic',.26); cap.location.y=y
        h.cyl(p,'Deep rear engine bell',(-.67,y,.035),.14,.21,'dark',(1,0,0),48)
        h.ring(p,'Engine outer heat ring',(-.775,y,.035),.138,.017,'steel',(1,0,0))
        h.ring(p,'Engine violet annulus',(-.786,y,.035),.10,.011,'violet',(1,0,0))
        h.cyl(p,'Violet turbine core',(-.78,y,.035),.066,.009,'violet',(1,0,0),32)
        for i in range(12):
            a=i*math.pi/6
            h.link(p,'Engine turbine stator',(-.795,y+.081*math.cos(a),.035+.081*math.sin(a)),(-.795,y+.123*math.cos(a+.15),.035+.123*math.sin(a+.15)),.008,'steel')
        # Swept wings match the concept silhouette rather than square fins.
        verts=[(-.50,y,.10),(.05,y,.04),(-.12,s*.86,-.04),(-.59,s*.82,.03),(-.50,y,.075),(.05,y,.015),(-.12,s*.86,-.064),(-.59,s*.82,.006)]
        mesh(p,'Swept tapered armored wing',verts,[(0,1,2,3),(7,6,5,4),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],'ceramic',False,.009)
        for j in range(3): slit(p,(-.42+j*.055,y+s*.15,.075),(.018,.09,.005),'rubber',(0,0,-s*.25))
        h.plate(p,'Swept stabilizer', [(-.53,.21),(-.60,.38),(-.39,.35),(-.24,.19)],s*.14,.019,'armor')
        for j in range(4):slit(p,(-.34+j*.053,y+s*.183,.055),(.018,.009,.075),'rubber')
        h.cyl(p,'Underslung weapon pivot',(.23,s*.29,-.16),.059,.085,'steel',(0,1,0),32)
        barrel(p,.72,s*.29,-.22,.53,.034,'violet')
        h.cable(p,'Gun hydraulic supply',[(-.15,s*.27,-.16),(.02,s*.31,-.24),(.23,s*.28,-.19)],r=.011)
        h.plate(p,'Side engine service armor',[(-.58,.04),(-.5,.16),(-.17,.17),(-.06,.06),(-.16,-.04),(-.5,-.04)],y+s*.18,.016,'armor')
        for xx in [-.48,-.2]: h.cyl(p,'Engine cowling screw',(xx,y+s*.192,.10),.008,.009,'dark',(0,1,0),6)
        h.plate(p,'Front layered side service panel',[(.26,-.03),(.43,-.02),(.50,-.10),(.31,-.15)],s*.192,.011,'armor')
        for xx in [.30,.40]:h.cyl(p,'Nose panel flush fastener',(xx,s*.205,-.075),.006,.007,'steel',(0,1,0),6)
        h.box(p,'Nacelle inset exhaust surround',(-.27,y+s*.202,.057),(.16,.015,.10),'rubber',bevel=.009)
        for j in range(5):h.box(p,'Inset engine cooling grille',(-.33+j*.031,y+s*.213,.057),(.010,.012,.08),'steel',bevel=.002)
    return p

def boss():
    p=h.root('APEX_Dreadnought_V2')
    # Broad siege chassis with an actual central reactor and split nose mandibles.
    loft(p,'Broad siege central hull',[(-1.03,.59,-.42,.27),(-.76,.72,-.46,.43),(.44,.68,-.44,.36),(.83,.47,-.33,.12)],'armor',.18)
    deck=loft(p,'Overlapping upper deck',[(-.91,.53,.285,.41),(-.63,.64,.42,.51),(.15,.61,.40,.49),(.60,.44,.22,.33)],'armor',.2)
    # Top central reactor from the sheet; concentric inset rings, not a flat disk.
    h.cyl(p,'Reactor sloped armored pedestal',(-.02,0,.45),.36,.20,'armor',vertices=64)
    for rr,z,th,mat in [(.34,.558,.012,'steel'),(.29,.569,.010,'dark'),(.25,.57,.012,'red'),(.18,.573,.011,'steel')]:h.ring(p,'Reactor concentric containment',(-.02,0,z),rr,th,mat)
    h.cyl(p,'Reactor recessed luminous core',(-.02,0,.57),.17,.012,'red',vertices=48)
    h.bolts(p,(-.02,0,.566),.312,count=16)
    for i in range(12):
        a=i*math.pi/6
        h.box(p,'Reactor radial armored segment',(-.02+.325*math.cos(a),.325*math.sin(a),.50),(.061,.053,.09),'ceramic',rot=(0,-.18,a),bevel=.006)
    for s in [-1,1]:
        y=s*.76
        a=loft(p,'Heavy side siege sponson',[(-.91,.24,-.32,.18),(-.65,.28,-.37,.30),(.45,.28,-.35,.26),(.83,.21,-.21,.08)],'armor',.23);a.location.y=y
        for j in range(3):
            x=-.69+j*.43
            h.plate(p,'Layered sponson upper shield',[(x-.20,.10),(x-.21,.30),(x-.1,.37),(x+.17,.29),(x+.20,.03),(x+.12,-.04)],y+s*.30,.038,'ceramic')
            h.plate(p,'Sponson inset steel shield',[(x-.17,.09),(x-.15,.22),(x+.09,.20),(x+.13,.02)],y+s*.324,.014,'armor')
            for k in range(3):slit(p,(x-.11+k*.07,y+s*.340,.12),(.025,.01,.064),'rubber')
            for zz in [.04,.245]:h.cyl(p,'Sponson captive bolt',(x-.11,y+s*.350,zz),.009,.008,'steel',(0,1,0),6)
        # Twin siege cannons on each side: broad shoulder mount and long tubes.
        for z in [-.12,.13]:
            barrel(p,1.68,y,z,1.15,.065,'red')
            h.box(p,'Siege cannon segmented jacket',(.87,y,z),(.73,.17,.16),'armor',bevel=.018)
            for j in range(3):
                xx=.62+j*.20
                slit(p,(xx,y+s*.09,z),(.105,.011,.022),'red')
                h.box(p,'Cannon jacket separator',(xx+.074,y,z),(.025,.19,.18),'steel',bevel=.005)
        # Split forward armor brackets / mandibles.
        mandible=h.plate(p,'Forward pale armored mandible',[(.56,.03),(.86,.02),(.93,-.36),(.81,-.52),(.73,-.42),(.68,-.18),(.49,-.14)],s*.60,.13,'ceramic');mandible.location.x=.18
        inner=h.plate(p,'Mandible dark inner plate',[(.67,-.06),(.83,-.055),(.86,-.31),(.78,-.35)],s*.675,.025,'steel');inner.location.x=.18
        roof=loft(p,'Split forward deck armor',[(.25,.15,.405,.48),(.58,.18,.28,.37),(.90,.13,.13,.23)],'ceramic',.22);roof.location.y=s*.25
        for x in [-.65,-.1,.45]:
            h.cyl(p,'Underside antigravity drive',(x,y,-.375),.13,.115,'dark',vertices=40)
            h.ring(p,'Antigravity red annulus',(x,y,-.437),.105,.009,'red')
            h.cyl(p,'Antigravity machined cap',(x,y,-.44),.075,.015,'steel',vertices=32)
        for j in range(4):
            x=-.72+j*.29
            h.plate(p,'Upper deck overlapping panel',[(x-.12,.41),(x-.10,.51),(x+.07,.535),(x+.12,.42)],s*.44,.20,'ceramic')
        # Crown at the rear, as in the sheet, rather than a forest of tall spikes.
        h.plate(p,'Rear crown swept fin',[(-.75,.43),(-.79,.88),(-.69,.68),(-.49,.63),(-.41,.92),(-.35,.63),(-.19,.67),(-.12,.88),(-.10,.43)],s*.245,.042,'ceramic')
        h.cable(p,'Protected side energy trunk',[(-.84,y,-.21),(-.39,y+s*.24,-.29),(.47,y,-.22)],r=.024)
        # Recessed front side vents with actual borders.
        h.box(p,'Deep recessed heat exchanger',(.46,y+s*.285,-.20),(.28,.022,.23),'rubber',bevel=.008)
        for j in range(5):
            slit(p,(.35+j*.052,y+s*.30,-.20),(.018,.009,.185),'red')
            h.box(p,'Heat exchanger grille fin',(.368+j*.052,y+s*.313,-.20),(.018,.012,.20),'steel',bevel=.003)
    loft(p,'Front spread emitter',[(.90,.265,-.29,.08),(1.08,.235,-.29,.04)],'steel',.14)
    for j in range(5):slit(p,(1.089,-.17+j*.085,-.10),(.013,.022,.23),'red')
    h.box(p,'Inset forward spine housing',(.60,0,.35),(.42,.18,.045),'dark',rot=(0,.3,0),bevel=.012)
    for j in range(5):slit(p,(.45+j*.07,0,.430-j*.021),(.025,.13,.010),'red',rot=(0,.3,0))
    for x in [-.8,-.5,.4]:
        for y in [-.32,.32]: h.cyl(p,'Deck recessed captive fastener',(x,y,.485),.011,.013,'dark',vertices=6)
    return p

BUILDERS={'crawler':crawler,'turret':turret,'gunship':gunship,'boss':boss}

def build(kind):
    p=BUILDERS[kind](); ROOTS[kind]=p
    h.ROOTS[kind]=p; h.OUT=OUT; h.PREVIEW=PREVIEW
    h.optimize_export(kind)
    if kind=='turret': refine_turret_vents()
    print('CONCEPT_V2_BUILT',kind)

def refine_turret_vents():
    pass


def render(kind):
    h.ROOTS=ROOTS; h.PREVIEW=PREVIEW
    p=ROOTS[kind];p.location=(0,0,0)
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=64
    scene.render.resolution_x=1600;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
    scene.world.use_nodes=True
    bg=scene.world.node_tree.nodes.get('Background')
    bg.inputs['Color'].default_value=(.20,.23,.28,1);bg.inputs['Strength'].default_value=.5
    scene.view_settings.view_transform='AgX'
    h.render_asset(kind)

def render_sheet_view(kind):
    p=ROOTS[kind];p.location=(0,0,0)
    for o in bpy.data.objects:o.hide_render=o!=p and o not in p.children_recursive
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=48
    scene.render.resolution_x=1600;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
    scene.world.use_nodes=True;bg=scene.world.node_tree.nodes.get('Background')
    bg.inputs['Color'].default_value=(.20,.23,.28,1);bg.inputs['Strength'].default_value=.5
    scene.view_settings.view_transform='AgX'
    size={'crawler':1.7,'turret':1.45,'gunship':2.0,'boss':3.9}[kind]
    target=Vector((0,0,.35 if kind in ['crawler','turret'] else .08));sy=-1 if kind=='crawler' else 1
    rigs=[]
    bpy.ops.object.camera_add(location=target+Vector((size*.9,sy*size*1.9,size*.95)))
    cam=bpy.context.object;rigs.append(cam);cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.type='ORTHO';cam.data.ortho_scale=size*1.35;scene.camera=cam
    for loc,power,col,scale in [((1,sy*3,4),320,(.86,.91,1),4),((-3,-sy,2),450,(.60,.72,1),3),((3,-sy*3,3),380,(1,.75,.57),2)]:
        bpy.ops.object.light_add(type='AREA',location=Vector(loc)*size*.6)
        l=bpy.context.object;rigs.append(l);l.data.energy=power*size;l.data.color=col;l.data.shape='DISK';l.data.size=scale*size*.5
        l.rotation_euler=(target-l.location).to_track_quat('-Z','Y').to_euler()
    scene.render.film_transparent=True;scene.render.filepath=str(PREVIEW/(kind+'.png'))
    bpy.ops.render.render(write_still=True)
    for o in rigs:bpy.data.objects.remove(o,do_unlink=True)
    print('SHEET_VIEW_RENDERED',kind)

def save():
    for i,(kind,p) in enumerate(ROOTS.items()):
        p.location.y=i*3.5
        for o in [p]+list(p.children_recursive):o.hide_set(False);o.hide_render=False
    for area in bpy.context.screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.shading.type='MATERIAL';area.spaces.active.overlay.show_overlays=False
            area.spaces.active.region_3d.view_rotation=Vector((3,-6,3)).to_track_quat('Z','Y')
            area.spaces.active.region_3d.view_location=(0,5.25,.2);area.spaces.active.region_3d.view_distance=13
    bpy.ops.object.select_all(action='DESELECT')
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'concept_enemy_workbench_v2.blend'))
    print('CONCEPT_V2_WORKBENCH_SAVED')
