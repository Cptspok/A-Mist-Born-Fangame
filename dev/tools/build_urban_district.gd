extends SceneTree
## Offline scene authoring only. The shipped level has no procedural builder.
## Run with Godot --headless --path <project> --script res://dev/tools/build_urban_district.gd
const OUT = "res://world/levels/urban_district/"
const DATA = "res://data/intelligence/urban_district/"
const REWARDS = "res://data/enemies/rewards/urban_district/"
const ART = "res://dev/Test_Environement/Achitecture/"
const PROPS = "res://dev/Test_Environement/Props/"
var level := Node3D.new()
var env: Node3D
var architecture: Node3D
var props: Node3D
var metal: Node3D
var gameplay: Node3D
var lighting: Node3D
var source := NavigationMeshSourceGeometryData3D.new()
var bounds_cache: Dictionary = {}
var mesh_cache: Dictionary = {}
var target: CourtTargetDefinition
var clues: Array[IntelligenceClueDefinition] = []
var polygon := PackedVector2Array([Vector2(-51,-25),Vector2(-43,-43),Vector2(-8,-52),Vector2(26,-45),Vector2(46,-32),Vector2(53,-4),Vector2(49,28),Vector2(27,48),Vector2(-25,46),Vector2(-49,25)])

func save_resource(resource: Resource, path: String) -> Error:
	var error := ResourceSaver.save(resource,path)
	if error == OK: resource.take_over_path(path)
	return error

func override_child(instance_root: Node, path: String) -> Node:
	# Packing an inherited scene only preserves changed descendants owned by this scene.
	var child := instance_root.get_node(path)
	child.owner = level
	return child

func _initialize() -> void:
	_build.call_deferred()

func own(node: Node, parent: Node, title: String = "") -> Node:
	if not title.is_empty(): node.name = title
	parent.add_child(node, true)
	node.owner = level
	return node

func group(parent: Node, title: String, pos := Vector3.ZERO) -> Node3D:
	var node := Node3D.new()
	own(node, parent, title)
	node.position = pos
	return node

func instance(path: String, parent: Node, pos := Vector3.ZERO, title := "") -> Node3D:
	var packed: PackedScene = load(path)
	assert(packed != null, path)
	var node: Node3D = packed.instantiate()
	own(node, parent, title)
	node.position = pos
	return node

func art(asset: String, parent: Node, pos := Vector3.ZERO, angle := 0.0) -> Node3D:
	var node := instance(ART + asset + ".gltf", parent, pos)
	node.rotation.y = deg_to_rad(angle)
	return node

func prop(asset: String, parent: Node, pos: Vector3, scale_value := 1.0) -> Node3D:
	var node := instance(PROPS + asset + ".glb", parent, pos)
	node.scale = Vector3.ONE * scale_value
	return node

func total_transform(node: Node3D) -> Transform3D:
	var result := node.transform
	var parent := node.get_parent()
	while parent is Node3D:
		result = parent.transform * result
		parent = parent.get_parent()
	return result

func collision(parent: Node3D, size: Vector3, pos: Vector3, nav := true) -> StaticBody3D:
	var body := StaticBody3D.new()
	own(body, parent, "Solid")
	body.position = pos
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	own(collider, body, "Shape")
	if nav:
		var mesh := BoxMesh.new()
		mesh.size = size
		source.add_faces(mesh.get_faces(), total_transform(body))
	return body

func mesh_bounds(node: Node3D, transform := Transform3D.IDENTITY) -> AABB:
	var result := AABB()
	var current := transform * node.transform
	if node is MeshInstance3D and node.mesh != null:
		result = current * node.mesh.get_aabb()
	for child in node.get_children():
		if child is Node3D:
			var child_bounds := mesh_bounds(child, current)
			if child_bounds.size != Vector3.ZERO:
				result = child_bounds if result.size == Vector3.ZERO else result.merge(child_bounds)
	return result

func fit_asset(asset: String, parent: Node3D, size: Vector3, center: Vector3) -> Node3D:
	var node := art(asset, parent)
	if not bounds_cache.has(asset): bounds_cache[asset] = mesh_bounds(node)
	var bounds: AABB = bounds_cache[asset]
	node.scale = size / bounds.size
	node.position = center - (bounds.position + bounds.size * 0.5) * node.scale
	return node

func floor_tiles(parent: Node3D, w: float, d: float, y: float, asset := "Floor_WoodDark") -> void:
	for x in range(int(w / 2)):
		for z in range(int(d / 2)):
			art(asset, parent, Vector3(-w/2+1+x*2,y,-d/2+1+z*2))

func roof(parent: Node3D, w: float, d: float, y: float, high: float, accessible: bool) -> void:
	var node := fit_asset("Roof_RoundTiles_4x4" if maxf(w,d) <= 6 else "Roof_RoundTiles_6x8", parent, Vector3(w+0.9,high,d+0.9),Vector3(0,y+high/2-0.12,0))
	if accessible: roof_collision(node, parent)
	art("Prop_Chimney",parent,Vector3(w*0.28,y+high*0.3,-d*0.2)).scale = Vector3(0.75,0.75,0.75)

func roof_collision(node: Node3D, parent: Node3D, transform := Transform3D.IDENTITY) -> void:
	var current := transform * node.transform
	if node is MeshInstance3D and node.mesh != null:
		var body := StaticBody3D.new()
		own(body,parent,"RoofSurface")
		body.transform = current
		var collider := CollisionShape3D.new()
		var key: int = node.mesh.get_instance_id()
		if not mesh_cache.has(key): mesh_cache[key] = node.mesh.create_trimesh_shape()
		collider.shape = mesh_cache[key]
		own(collider,body,"Shape")
	for child in node.get_children():
		if child is Node3D: roof_collision(child,parent,current)

func facade(parent: Node3D, w: float, d: float, storeys: int, wealthy: bool, opening := false) -> void:
	for storey in storeys:
		var over := 0.0 if storey == 0 or wealthy else 0.4
		for side in 4:
			var count := int((w if side < 2 else d) / 2)
			for index in count:
				if opening and storey == 0 and side < 2 and absi(index-count/2) <= 0: continue
				var along := -float(count)+1+index*2
				var pos := Vector3(along,storey*3,d/2+over) if side < 2 else Vector3(w/2+over,storey*3,along)
				if side == 1: pos.z *= -1
				if side == 3: pos.x *= -1
				var family := "Wall_UnevenBrick_" if storey == 0 and wealthy else "Wall_Plaster_"
				var piece := "Window_Wide_Flat" if (index+storey)%2 == 0 else "WoodGrid"
				if family == "Wall_UnevenBrick_" and piece == "WoodGrid": piece = "Straight"
				if storey == 0 and index == 1 and not opening: piece = "Door_Round"
				var angle: float = [0.0,180.0,90.0,-90.0][side]
				art(family+piece,parent,pos,angle)
				if piece == "Door_Round":
					var offset := Basis(Vector3.UP,deg_to_rad(angle))*Vector3(-0.52,0,0.05)
					art("Door_1_Round",parent,pos+offset,angle)
		# Timber corner posts and projecting floor ledges tie the wall modules together.
		for x in [-w/2-over,w/2+over]:
			for z in [-d/2-over,d/2+over]:
				art("Corner_Exterior_Wood",parent,Vector3(x,storey*3,z))
		if storey > 0:
			for x in range(int(w/2)):
				art("Floor_WoodDark",parent,Vector3(-w/2+1+x*2,storey*3,d/2-0.5))

func building(title: String, pos: Vector3, w: float, d: float, storeys: int, angle := 0.0, accessible := false, wealthy := false) -> Node3D:
	var node := group(architecture,title,pos)
	node.rotation.y = deg_to_rad(angle)
	facade(node,w,d,storeys,wealthy)
	collision(node,Vector3(w,storeys*3,d),Vector3(0,storeys*1.5,0))
	if storeys > 1 and not wealthy:
		collision(node,Vector3(w+0.8,(storeys-1)*3,d+0.8),Vector3(0,3+(storeys-1)*1.5,0))
	roof(node,w+(0.8 if storeys > 1 and not wealthy else 0),d,storeys*3,2.0+storeys*0.4,accessible)
	return node

func anchored_fence(parent: Node3D, pos: Vector3, angle := 0.0, short := false) -> void:
	var node := group(parent,"IronRailing",pos)
	node.rotation.y = deg_to_rad(angle)
	var model := art("Prop_MetalFence_Simple",node)
	if short: model.scale.y = 0.42
	var size := Vector3(1.95,1.2 if short else 2.86,0.16)
	var body := collision(node,size,Vector3(0,size.y/2,0))
	var tether := instance("res://abilities/allomancy/metal_tether/metal_tether.tscn",body,Vector3.ZERO,"MetalTether")
	tether.set("physical_owner_path",NodePath(".."))
	var shape := BoxShape3D.new()
	shape.size = size + Vector3(0.08,0.08,0.08)
	override_child(tether,"CollisionShape3D").shape = shape

func brazier(parent: Node3D, pos: Vector3) -> void:
	prop("brazier",parent,pos,1.65)
	var light := OmniLight3D.new()
	own(light,lighting,"BrazierLight")
	light.position = pos+Vector3(0,1.35,0)
	light.light_color = Color(1,0.57,0.24)
	light.light_energy = 2.4
	light.omni_range = 7
	light.shadow_enabled = false

func ramp(parent: Node3D, pos: Vector3, w: float, rise: float, run: float, angle := 0.0) -> void:
	var node := group(parent,"StoneStair",pos)
	node.rotation.y = deg_to_rad(angle)
	# Positive Z is the foot; negative Z is the upper landing.
	for step in int(rise):
		for column in int(w/2):
			fit_asset("Stairs_Exterior_Straight",node,Vector3(2,1,run/rise),Vector3(-w/2+1+column*2,step+0.5,run/2-(step+0.5)*run/rise))
	var points := PackedVector3Array([Vector3(-w/2,0,run/2),Vector3(w/2,0,run/2),Vector3(-w/2,rise,-run/2),Vector3(w/2,rise,-run/2),Vector3(-w/2,0,-run/2),Vector3(w/2,0,-run/2)])
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	var body := StaticBody3D.new()
	own(body,node,"SmoothRamp")
	var collider := CollisionShape3D.new()
	collider.shape = shape
	own(collider,body,"Shape")
	var faces := PackedVector3Array()
	for i in [0,2,1,1,2,3,0,4,2,1,3,5,4,5,2,2,5,3,0,1,4,1,5,4]: faces.append(points[i])
	source.add_faces(faces,total_transform(node))

func balcony(parent: Node3D, pos: Vector3, width: float) -> void:
	var node := group(parent,"TimberGallery",pos)
	floor_tiles(node,width,2,0)
	collision(node,Vector3(width,0.2,2),Vector3(0,-0.1,0),false)
	for i in int(width/2):
		if absf(-width/2+1+i*2) > 1.1:
			art("Balcony_Cross_Straight",node,Vector3(-width/2+1+i*2,0,0))
		art("Prop_Support",node,Vector3(-width/2+1+i*2,-3,0))
	# Railing center gap is a deliberate ladder/jump landing.
	for x in [-width/2+1,width/2-1]: collision(node,Vector3(2,1,0.2),Vector3(x,0.5,0.95),false)

func _build() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DirAccess.make_dir_recursive_absolute(DATA)
	DirAccess.make_dir_recursive_absolute(REWARDS)
	level.name = "AshmarketDistrict"
	env = group(level,"Environment")
	architecture = group(env,"Architecture")
	props = group(env,"PropsAndLandmarks")
	lighting = group(level,"Lighting")
	gameplay = group(level,"Gameplay")
	metal = group(gameplay,"Metalwork")
	_ground()
	_city()
	_interiors()
	_dressing()
	_lighting()
	_intelligence()
	if not await _navigation():
		level.free()
		quit(1)
		return
	_gameplay()
	level.set_script(load(OUT+"urban_district.gd"))
	var packed := PackedScene.new()
	assert(packed.pack(level) == OK)
	assert(save_resource(packed,OUT+"urban_district.tscn") == OK)
	print("URBAN_BUILD_OK: ",level.get_child_count()," root groups; nav polygons ", (level.get_node("Navigation") as NavigationRegion3D).navigation_mesh.get_polygon_count())
	level.free()
	quit()

func _ground() -> void:
	var faces := PackedVector3Array()
	var indices := Geometry2D.triangulate_polygon(polygon)
	for i in range(0,indices.size(),3):
		for j in [0,1,2]:
			var p := polygon[indices[i+j]]
			faces.append(Vector3(p.x,0,p.y))
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var body := StaticBody3D.new()
	own(body,env,"DistrictGround")
	var collider := CollisionShape3D.new()
	collider.shape = shape
	own(collider,body,"Shape")
	source.add_faces(faces,Transform3D.IDENTITY)
	# Imported material/meshes remain shared; batching keeps the tiled ground cheap.
	var paving: Array[Transform3D] = []
	var margins: Array[Transform3D] = []
	for x in range(-52,54,2):
		for z in range(-52,50,2):
			if not Geometry2D.is_point_in_polygon(Vector2(x,z),polygon): continue
			var street := absf(z) < 5 or (x > -29 and x < 10 and z > -8 and z < 14) or absf(x+8)<5 or absf(x-27)<3 or absf(x+38)<3 or absf(z-30)<3 or absf(z+17)<3
			var transform := Transform3D(Basis.IDENTITY,Vector3(x,-0.01,z))
			if street: paving.append(transform)
			else: margins.append(transform)
	_ground_batch("Floor_UnevenBrick",paving)
	_ground_batch("Floor_Brick",margins)
	for i in polygon.size():
		var a := polygon[i]
		var b := polygon[(i+1)%polygon.size()]
		var length := a.distance_to(b)
		var wall := group(architecture,"DistrictWall",Vector3((a.x+b.x)/2,0,(a.y+b.y)/2))
		wall.rotation.y = -atan2(b.y-a.y,b.x-a.x)
		var count := int(ceil(length/2))
		for j in count:
			var x := -length/2+(j+0.5)*length/count
			var global_z := (total_transform(wall)*Vector3(x,0,0)).z
			# Gate mouths face the east-west street; set-back iron gates close the district.
			var gate := absf(global_z)<4.0
			for storey in range(1 if gate else 0,2): art("Wall_UnevenBrick_Straight",wall,Vector3(x,storey*3,0))
			if gate:
				anchored_fence(wall,Vector3(x,0,-0.5))
			else: collision(wall,Vector3(length/count+0.05,6,0.6),Vector3(x,3,0))
			if j%3 == 0: art("Prop_Chimney",wall,Vector3(x,4.5,0)).scale = Vector3(0.7,0.7,0.7)

func _ground_batch(asset: String, placements: Array[Transform3D]) -> void:
	var sample := load(ART+asset+".gltf").instantiate() as Node3D
	_batch_meshes(sample,Transform3D.IDENTITY,placements,asset)
	sample.free()

func _batch_meshes(node: Node3D, transform: Transform3D, placements: Array[Transform3D], title: String) -> void:
	var current := transform*node.transform
	if node is MeshInstance3D and node.mesh != null:
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = node.mesh
		multi.instance_count = placements.size()
		for i in placements.size(): multi.set_instance_transform(i,placements[i]*current)
		var visual := MultiMeshInstance3D.new()
		visual.multimesh = multi
		own(visual,env,title)
	for child in node.get_children():
		if child is Node3D: _batch_meshes(child,current,placements,title)

func _city() -> void:
	# Authored blocks: x,z,width,depth,storeys,yaw. Deliberately unequal frontage and offsets.
	var blocks := [
		[-37,-29,8,12,2,-4],[-27,-39,8,6,2,3],[-23,-27,6,6,3,0],
		[-39,-12,10,8,3,0],[-26,-11,10,6,2,-3],[-14,-12,8,6,2,0],
		[5,-12,8,6,3,2],[16,-11,8,6,2,-2],[36,-12,10,8,3,-4],
		[18,-31,8,16,3,0],[32,-28,8,12,2,3],[41,-23,6,8,2,-6],
		[28,-39,6,6,2,0],[39,-34,6,6,2,0],
		[-39,12,12,6,1,-5],[-23,20,10,6,1,-14],[-9,22,12,8,2,0],
		[7,18,6,14,2,-4],[18,19,8,16,3,2],[36,13,10,8,2,0],
		[44,14,4,6,1,0],[37,25,8,8,2,-3],
		[-42,28,6,10,1,-12],[-20,36,8,10,1,-6],[-7,37,8,8,2,0],
		[5,38,6,8,1,0],[17,37,8,12,2,0],[31,37,8,8,2,7],
		[42,33,4,6,1,0],[-31,40,6,6,1,12],[-46,-1,4,8,2,0]
	]
	for i in blocks.size():
		var b: Array = blocks[i]
		building("House_%02d"%i,Vector3(b[0],0,b[1]),b[2],b[3],b[4],b[5],i in [15,16,17,18,19,24,25],i in [10,11,13,14])
	# Two taller towers flank the manor; smaller north silhouettes remain beyond street reach.
	for x in [-21,5]:
		var tower := building("ManorTower",Vector3(x,3,-36),4,6,2,0,false,true)
		fit_asset("Roof_Tower_RoundTiles",tower,Vector3(5.5,6,7),Vector3(0,11.5,0))
	# A public loading stair leads to the south market gallery; adjacent low roofs are reachable.
	balcony(architecture,Vector3(-9,3,16),12)
	ramp(architecture,Vector3(-17,0,16),2,3,6,-90)
	# A second narrow loading stair climbs beside the low warehouse to its eave.
	ramp(architecture,Vector3(-30,0,18),2,3,6)
	balcony(architecture,Vector3(-27,3,15),6)
	balcony(architecture,Vector3(18,6,9.5),8)
	# Service balconies high on the east frontage are intended for Iron/Steel, not ground AI.
	balcony(architecture,Vector3(36,3,7.5),8)
	anchored_fence(metal,Vector3(16,6,8.5),0,true)
	anchored_fence(metal,Vector3(35,3,6.5),0,true)
	anchored_fence(metal,Vector3(-10,3,15),0,true)
	anchored_fence(metal,Vector3(17,9.4,11),0,true)
	anchored_fence(metal,Vector3(-9,6.3,18),0,true)
	# Occluded service court with one deliberately blocked alley, not a city-wide maze.
	for x in [-33,-31,-29]: art("Prop_WoodenFence_Single",props,Vector3(x,0,23))
	collision(props,Vector3(6,0.85,0.15),Vector3(-31,0.425,23))

func _interiors() -> void:
	var cabin := group(architecture,"PlayerCabin",Vector3(-31,0,31))
	floor_tiles(cabin,6,6,0.03)
	# Use the kit's timber planks vertically; the cabin has a clear two-metre door opening.
	for side in 4:
		for i in 3:
			if side == 0 and i == 1: continue
			var segment := group(cabin,"PlankWall",Vector3(-2+i*2,0,3))
			segment.position = [Vector3(-2+i*2,0,3),Vector3(-2+i*2,0,-3),Vector3(3,0,-2+i*2),Vector3(-3,0,-2+i*2)][side]
			segment.rotation.y = [0.0,PI,PI/2,-PI/2][side]
			for y in [0.75,2.25]:
				var plank := art("Floor_WoodDark",segment,Vector3(0,y,0))
				plank.rotation.x = PI/2
				plank.scale = Vector3(1,1,0.75)
			collision(segment,Vector3(2,3,0.15),Vector3(0,1.5,0))
	art("DoorFrame_Flat_WoodDark",cabin,Vector3(0,0,3)).scale.x = 1.8
	collision(cabin,Vector3(2,0.6,0.15),Vector3(0,2.7,3))
	roof(cabin,6,6,3,2,false)
	collision(cabin,Vector3(6,0.15,6),Vector3(0,3,0))
	prop("crate",cabin,Vector3(1.9,0,-1.9),1.5)
	prop("chest",cabin,Vector3(-2,0,-2),1.2)
	var manor := group(architecture,"BaronManor",Vector3(-8,3,-35))
	# Raised court: traversable front stair plus a second stair down the east service side.
	var terrace := group(architecture,"ManorTerrace",Vector3(-8,0,-35))
	floor_tiles(terrace,32,22,3,"Floor_UnevenBrick")
	collision(terrace,Vector3(32,3,22),Vector3(0,1.5,0))
	for x in range(-15,16,2):
		for z in [-11,11]: art("Wall_UnevenBrick_Straight",terrace,Vector3(x,0,z),0 if z > 0 else 180)
	for z in range(-10,11,2):
		for x in [-16,16]: art("Wall_UnevenBrick_Straight",terrace,Vector3(x,0,z),90 if x > 0 else -90)
	for x in range(-23,8,2):
		if x < -12 or x > -4: anchored_fence(metal,Vector3(x,3,-24),0,true)
	ramp(architecture,Vector3(-8,0,-21),6,3,6)
	ramp(architecture,Vector3(11,0,-40),4,3,6,90)
	floor_tiles(manor,18,12,0.06,"Floor_WoodLight")
	# Front and rear central openings are 6m wide, 3m high; no closed door collision.
	for side in [-1,1]:
		for x in range(-8,9,2):
			if abs(x) < 3: continue
			art("Wall_UnevenBrick_Window_Wide_Flat",manor,Vector3(x,0,side*6),0 if side == 1 else 180)
		collision(manor,Vector3(6,3,0.35),Vector3(-6,1.5,side*6))
		collision(manor,Vector3(6,3,0.35),Vector3(6,1.5,side*6))
		for x in range(-8,9,2): art("Wall_Plaster_Window_Wide_Flat",manor,Vector3(x,3,side*6),0 if side == 1 else 180)
		collision(manor,Vector3(18,3,0.35),Vector3(0,4.5,side*6))
	for x in [-9,9]:
		for z in range(-5,6,2):
			for y in [0,3]: art("Wall_UnevenBrick_Straight",manor,Vector3(x,y,z),90 if x > 0 else -90)
		collision(manor,Vector3(0.35,6,12),Vector3(x,3,0))
	floor_tiles(manor,18,12,3,"Floor_WoodLight")
	collision(manor,Vector3(18,0.15,12),Vector3(0,3.1,0))
	roof(manor,18,12,6,4,false)
	for x in [-6,6]:
		for z in [-3,3]: prop("column",manor,Vector3(x,0,z),2.0)
	for x in [-6,6]: prop("bookshelf",manor,Vector3(x,0,-5.6),2)
	prop("chest",manor,Vector3(6.5,0,4.5),1.6)
	prop("SM_statue_knight",props,Vector3(-8,3,-44),2.7)
	brazier(props,Vector3(-13,3,-27))
	brazier(props,Vector3(-3,3,-27))
	# Lights inside the hall are explicitly placed at world height.
	brazier(props,Vector3(-15,3,-35))
	brazier(props,Vector3(-1,3,-35))

func _dressing() -> void:
	# Keep the plaza middle open; market pockets sit on the sides of its sightlines.
	var landmark := group(props,"MarketStatue",Vector3(-15,0,3))
	fit_asset("Floor_UnevenBrick",landmark,Vector3(2.8,0.6,2.8),Vector3(0,0.3,0))
	collision(landmark,Vector3(2.8,0.6,2.8),Vector3(0,0.3,0))
	prop("SM_statue_knight",landmark,Vector3(0,0.6,0),2.3)
	collision(landmark,Vector3(1.3,3.4,1.3),Vector3(0,2.3,0))
	for p in [Vector3(-27,0,8),Vector3(3,0,9),Vector3(31,0,2),Vector3(-35,0,-19),Vector3(28,0,31)]:
		var wagon := art("Prop_Wagon",props,p,90)
		collision(wagon,Vector3(1.85,1.4,3),Vector3(0,0.7,-1.1))
	for p in [Vector3(-24,0,10),Vector3(-23,0,11),Vector3(0,0,11),Vector3(1,0,11),Vector3(2,0,11),Vector3(-34,0,-20),Vector3(30,0,30),Vector3(29,0,30),Vector3(24,0,25),Vector3(-36,0,19),Vector3(-35,0,19),Vector3(41,0,-6)]:
		art("Prop_Crate",props,p)
		collision(props,Vector3(1,1,1),p+Vector3(0,0.5,0))
	for p in [Vector3(-26,0,11),Vector3(-25,0,11),Vector3(4,0,10),Vector3(5,0,10),Vector3(-36,0,21),Vector3(25,0,26),Vector3(40,0,-7)]:
		prop("barrel",props,p,1.8)
		collision(props,Vector3(0.75,0.9,0.75),p+Vector3(0,0.45,0))
	for p in [Vector3(-25,0,-3),Vector3(5,0,-3),Vector3(43,0,1),Vector3(-44,0,4),Vector3(-4,0,-18),Vector3(-35,0,32)]: brazier(props,p)
	for p in [Vector3(-21,0,-5),Vector3(-19,0,-5),Vector3(6,0,4),Vector3(8,0,4),Vector3(29,0,-8),Vector3(29,0,-10),Vector3(-33,0,19)]: anchored_fence(metal,p,0,true)
	for p in [Vector3(-3,0,13),Vector3(24,0,2),Vector3(-33,0,8)]: instance("res://world/props/metalwork/world_metal_signpost.tscn",metal,p)
	for p in [Vector3(-35,0.7,20),Vector3(24,0.7,27),Vector3(0,0.7,10),Vector3(-23,0.7,10)]: instance("res://world/props/loose_steel/world_loose_steel.tscn",metal,p)

func _lighting() -> void:
	var world := WorldEnvironment.new()
	own(world,lighting,"Overcast")
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.32,0.36,0.41)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.65,0.70,0.78)
	environment.ambient_light_energy = 0.8
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.40,0.43,0.47)
	environment.fog_density = 0.0025
	world.environment = environment
	var sun := DirectionalLight3D.new()
	own(sun,lighting,"CloudedSun")
	sun.rotation_degrees = Vector3(-53,-27,0)
	sun.light_color = Color(0.87,0.89,0.95)
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 130

func _intelligence() -> void:
	target = CourtTargetDefinition.new()
	target.unique_id = &"ashmarket_voss"
	target.display_name = "Baron Darven Voss"
	target.portrait = load("res://assets/2d/icons/intelligence/voss.svg")
	target.district_id = &"ashmarket"
	target.region_id = &"baron_estate"
	target.map_reveal_field_id = &"location"
	target.map_position = Vector2(0.5,0.35)
	var texts := [
		["profile","Identity & authority","Darven Voss rules Ashmarket from the northern manor. His collectors squeeze the southern households and levy every market cart."],
		["location","Residence","The Baron receives his officers in the ground-floor hall of the raised northern manor. The broad front stair and an eastern service stair both reach its terrace."],
		["tactics","Tactical notes","Voss fights at close range and stays near his hall. The rear opening leads onto the terrace; the eastern service stair offers another escape. The market galleries provide elevated approaches, but the manor guard has a clear view of the front stair."]]
	for i in texts.size():
		var field := CourtIntelFieldDefinition.new()
		field.unique_id = texts[i][0]
		field.display_label = texts[i][1]
		field.revealed_text = texts[i][2]
		field.display_order = i
		save_resource(field,DATA+texts[i][0]+"_field.tres")
		target.dossier_fields.append(field)
		target.associated_clue_ids.append(StringName("ashmarket_"+texts[i][0]))
	save_resource(target,DATA+"baron_voss.tres")
	for i in texts.size():
		var clue := IntelligenceClueDefinition.new()
		clue.unique_id = target.associated_clue_ids[i]
		clue.display_name = ["Collector's account","Sealed delivery order","Watchman's private notes"][i]
		clue.target = target
		clue.reveals_identity = i == 0
		clue.reveals_portrait = i == 0
		clue.revealed_fields.append(target.dossier_fields[i])
		clue.clue_text = texts[i][2]
		clue.source_description = ["Back-street collector","Market garrison dispatch","East market service gallery"][i]
		clue.icon = load("res://assets/2d/icons/intelligence/voss.svg")
		save_resource(clue,DATA+texts[i][0]+"_clue.tres")
		clues.append(clue)
	var map := IntelligenceMapDefinition.new()
	map.district_id = &"ashmarket"
	map.display_name = "Ashmarket District"
	var regions := [["back_streets","Cabin & back streets",Rect2(0.08,0.65,0.82,0.29)],["market","Market & gate road",Rect2(0.04,0.36,0.92,0.24)],["baron_estate","Baron's northern estate",Rect2(0.22,0.06,0.58,0.24)]]
	for entry in regions:
		var region := IntelligenceRegionDefinition.new()
		region.unique_id = entry[0]
		region.display_name = entry[1]
		region.bounds = entry[2]
		region.initially_known = true
		map.regions.append(region)
	save_resource(map,DATA+"district_map.tres")
	var catalog := IntelligenceCatalog.new()
	catalog.targets.append(target)
	catalog.maps.append(map)
	save_resource(catalog,DATA+"catalog.tres")

func _navigation() -> bool:
	var nav := NavigationMesh.new()
	nav.cell_size = 0.25
	nav.cell_height = 0.25
	nav.agent_radius = 0.5
	nav.agent_height = 2.0
	nav.agent_max_climb = 0.25
	nav.agent_max_slope = 40
	nav.region_min_size = 1.0
	NavigationServer3D.bake_from_source_geometry_data(nav,source)
	# Remove disconnected building/prop tops. The raised estate and its two ramps
	# are the only enemy-accessible surfaces above street level.
	var vertices := nav.vertices
	var kept: Array[PackedInt32Array] = []
	for i in nav.get_polygon_count():
		var face := nav.get_polygon(i)
		var valid := true
		for index in face:
			var v := vertices[index]
			var estate := v.x > -24.2 and v.x < 14.2 and v.z > -46.2 and v.z < -17.5 and v.y < 3.8
			if v.y > 0.6 and not estate: valid = false
		if valid: kept.append(face)
	nav.clear_polygons()
	for face in kept: nav.add_polygon(face)
	assert(nav.get_polygon_count()>0,"Navigation bake was empty")
	save_resource(nav,OUT+"urban_navigation.tres")
	var region := NavigationRegion3D.new()
	region.navigation_mesh = nav
	own(region,level,"Navigation")
	print("Navigation bake: ", kept.size()," ground/estate polygons")
	return await _check_navigation(nav)

func _check_navigation(nav: NavigationMesh) -> bool:
	# Offline connectivity check against this bake; no actors or gameplay are started.
	var probe := NavigationRegion3D.new()
	if NavigationServer3D.has_method("region_set_use_async_iterations"):
		NavigationServer3D.call("region_set_use_async_iterations",probe.get_rid(),false)
	probe.navigation_mesh = load(OUT+"urban_navigation.tres").duplicate()
	root.add_child(probe)
	var map := probe.get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(map,nav.cell_size)
	NavigationServer3D.map_set_cell_height(map,nav.cell_height)
	NavigationServer3D.map_set_active(map,true)
	NavigationServer3D.map_set_use_async_iterations(map,false)
	await physics_frame
	await physics_frame
	await process_frame
	await create_timer(0.2).timeout
	NavigationServer3D.map_force_update(map)
	print("NAV map iteration=",NavigationServer3D.map_get_iteration_id(map)," closest=",NavigationServer3D.map_get_closest_point(map,Vector3(-12,0,0)))
	var checks := [
		["cabin door to plaza",Vector3(-31,0,31),Vector3(-12,0,0)],
		["gate road east",Vector3(-12,0,0),Vector3(44,0,0)],
		["gate road west",Vector3(-12,0,0),Vector3(-43,0,2)],
		["front stair and manor entrance",Vector3(-8,0,-17),Vector3(-8,3,-35)],
		["rear exit and service stair",Vector3(-8,3,-35),Vector3(15,0,-40)],
		["eastern back-street loop",Vector3(-12,0,0),Vector3(25,0,24)]]
	var all_valid := true
	for entry in checks:
		var path := NavigationServer3D.map_get_path(map,entry[1],entry[2],true)
		var valid := path.size() > 1 and path[0].distance_to(entry[1]) < 0.8 and path[-1].distance_to(entry[2]) < 0.8
		all_valid = all_valid and valid
		print("NAV ",entry[0],": ","OK" if valid else "FAILED", " (",path.size()," points)")
		if not valid and not path.is_empty(): print("  endpoints ",path[0]," -> ",path[-1])
	probe.free()
	return all_valid

func enemy(kind: String, pos: Vector3, encounter: String, title: String, clue_index := -1) -> Node3D:
	var paths := {"knife":"knife_fighter/knife_fighter", "heavy":"heavy/heavy_enemy", "crossbow":"crossbow_skirmisher/crossbow_skirmisher", "archer":"archer/long_range_archer", "court":"court_target/court_target"}
	var actor := instance("res://characters/enemies/"+paths[kind]+".tscn",gameplay.get_node("Enemies"),pos,title)
	actor.set("encounter_id",StringName(encounter))
	actor.set("display_name",title.replace("_"," "))
	if clue_index >= 0:
		var rewards := EnemyRewardDefinition.new()
		rewards.intelligence_clues.append(clues[clue_index])
		rewards.items.append(load("res://data/items/consumables/healing/medical_supplies.tres"))
		save_resource(rewards,REWARDS+encounter+"_rewards.tres")
		actor.set("rewards",rewards)
	return actor

func pickup(definition: ItemDefinition, pos: Vector3, title: String) -> void:
	var item := instance("res://world/world_items/world_item.tscn",gameplay.get_node("Pickups"),pos,title)
	item.set("item_definition",definition)
	override_child(item,"InteractionComponent").set("interaction_prompt","Pick up "+definition.display_name)

func document(index: int, pos: Vector3, title: String) -> void:
	var definition := ItemDefinition.new()
	definition.item_id = "intelligence/"+String(clues[index].unique_id)
	definition.display_name = clues[index].display_name
	definition.item_type = "Intelligence"
	definition.description = clues[index].clue_text
	definition.intelligence_clue = clues[index]
	definition.inventory_sprite = clues[index].icon
	pickup(definition,pos,title)

func _gameplay() -> void:
	group(gameplay,"Enemies")
	group(gameplay,"Pickups")
	var spawn := Vector3(-31,0.98,31)
	var player := instance("res://characters/player/player.tscn",level,spawn,"Player")
	player.rotation.y = PI
	var hub := group(level,"CentralHub")
	var start := Marker3D.new()
	own(start,hub,"Spawn")
	start.transform = player.transform
	var course := group(level,"TraversalCourse")
	course.set_script(load("res://dev/test_scenes/traversal_course/traversal_course.gd"))
	var fall_start := Marker3D.new()
	own(fall_start,course,"Start")
	fall_start.transform = player.transform
	var rest := instance("res://world/interactables/rest_point/rest_point.tscn",gameplay,Vector3(-33,0,31),"CabinRest")
	rest.set("rest_name","Your bedroll")
	var checkpoint := instance("res://world/interactables/checkpoint/checkpoint.tscn",gameplay,Vector3(-31,0,31),"CabinCheckpoint")
	checkpoint.set("checkpoint_id",&"ashmarket_cabin")
	override_child(checkpoint,"Marker").hide()
	override_child(checkpoint,"Label").hide()
	override_child(checkpoint,"Respawn").rotation.y = PI
	var ladder := instance("res://world/interactables/parametric_ladder/parametric_ladder.tscn",gameplay,Vector3(36,0,8.6),"MarketServiceLadder")
	ladder.set("height",3.0)
	ladder.set("top_exit_distance",1.1)
	# Soldiery is visible in controlled space; separated encounter IDs prevent remote alerts.
	enemy("heavy",Vector3(-3,1,0),"market_watch","Market_Sergeant",1)
	enemy("crossbow",Vector3(5,1,2),"market_watch","Market_Crossbow")
	enemy("heavy",Vector3(44,1,0),"east_gate","East_Gate_Guard")
	enemy("crossbow",Vector3(-43,1,2),"west_gate","West_Gate_Guard")
	enemy("heavy",Vector3(-8,1,-17),"manor_approach","Estate_Guard")
	var archer := enemy("archer",Vector3(-18,4,-25),"manor_terrace","Terrace_Archer")
	override_child(archer,"Sensing").set("detection_range",25.0)
	override_child(archer,"RangedAttack").set("attack_range",25.0)
	override_child(archer,"RangedBehaviour").set("maximum_attack_distance",25.0)
	override_child(archer,"RangedBehaviour").set("preferred_attack_distance",22.0)
	enemy("crossbow",Vector3(6,4,-41),"service_watch","Service_Guard")
	enemy("knife",Vector3(25,1,24),"east_collectors","Alley_Collector",0)
	enemy("knife",Vector3(26,1,20),"east_collectors","Collector_Accomplice")
	enemy("knife",Vector3(-35,1,19),"west_thugs","Backstreet_Cutpurse")
	enemy("heavy",Vector3(-32,1,-19),"north_thugs","Warehouse_Bruiser")
	var baron := enemy("court",Vector3(-8,4,-36),"baron_hall","Baron_Darven_Voss")
	baron.set("court_target",target)
	# Three independent clue categories, with alternate physical sources; none gates entry.
	document(0,Vector3(-35,0.8,20),"DiscardedCollectorAccount")
	document(1,Vector3(40,1.15,-7),"GateDispatch")
	document(2,Vector3(37,3.35,7.5),"GalleryWatchNotes")
	document(2,Vector3(-1.5,3.4,-30.5),"ManorWatchCopy")
	pickup(load("res://data/weapons/sword/sword.tres"),Vector3(-29.2,0.9,29.1),"CabinSword")
	pickup(load("res://data/items/consumables/healing/medical_supplies.tres"),Vector3(-32.8,0.5,29),"CabinMedicine")
	pickup(load("res://data/items/consumables/metals/basic_mixed_vial.tres"),Vector3(-29.2,0.9,29.6),"CabinVial")
	pickup(load("res://data/items/consumables/metals/basic_steel_vial.tres"),Vector3(-24,1.2,10),"MarketSteel")
	pickup(load("res://data/items/consumables/metals/basic_iron_vial.tres"),Vector3(29,1.2,30),"BackstreetIron")
	var npc := instance("res://characters/npcs/example_npc/example_npc.tscn",gameplay,Vector3(-35,0.95,35),"CabinNeighbour")
	npc.set("display_name","Mara")
	var dialogue := load("res://data/dialogue/example_npc_dialogue.tres").duplicate()
	dialogue.set("lines",PackedStringArray(["The square is north of here. Voss's soldiers watch the market road.","His collectors use the eastern back lanes. They keep accounts of everyone who owes him.","The loading stairs and the ladder behind the east market lead up to the galleries. Look for the watchman's notes.","Your bedroll is still inside. Come back and rest when you can."]))
	npc.set("dialogue_data",dialogue)
	var hud := CanvasLayer.new()
	own(hud,level,"GameplayHUD")
	for path in ["equipment/equipment_feedback","health/player_health_hud","allomancy/allomancy_reserve_hud"]:
		var node := (load("res://ui/hud/"+path+".tscn") as PackedScene).instantiate()
		own(node,hud)
		if path.begins_with("allomancy"):
			node.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
			node.offset_left = -280
			node.offset_top = -174
	var feedback := CanvasLayer.new()
	own(feedback,level,"StandaloneFeedback")
	var crosshair := Control.new()
	own(crosshair,feedback,"Crosshair")
	crosshair.set_script(load("res://ui/hud/targeting/playtest_target_feedback.gd"))
