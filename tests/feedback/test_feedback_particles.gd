extends ChTest

# Task 5: every feedback burst is capped and pays from a budget, so a busy fight never loses its
# Flamethrower particles to a feedback beat. Battle bursts are visual-only PixelWorld particles
# (never material ones, so no sand cells appear); the garage/UI path uses Godot's CPUParticles2D.
# CONTRACT: every test_* ends with _complete().


func _profile_asking(count: int) -> ChFeedbackProfile:
	var profile := ChFeedbackProfile.new()
	profile.particle_count = count
	profile.particle_color = Color.WHITE
	profile.particle_speed = 30.0
	return profile


func _cpu_bursts() -> Array[CPUParticles2D]:
	var found: Array[CPUParticles2D] = []
	for child in Feedback.popups.get_children():
		if child is CPUParticles2D:
			found.append(child)
	return found


func test_cap_is_24() -> void:
	var world: PixelWorld = await make_world()
	var before: int = world.get_stats()["particles_visual"]
	var n: int = ChFeedbackParticles.burst_world(world, Vector2(240, 90), _profile_asking(500), Color.RED)
	assert_eq(n, 24, "a burst asking 500 is capped at 24")
	var after: int = world.get_stats()["particles_visual"]
	assert_true(after > before, "the burst really added visual particles")
	assert_true(after - before <= 24, "the pool rose by at most 24, got %d" % (after - before))
	_complete()


func test_full_pool_skips() -> void:
	var world: PixelWorld = await make_world()
	world.set_max_particles(100)
	var spawned: int = world.spawn_particles(&"sand", Vector2(240, 90), Vector2.ZERO, 80, 0.0)
	assert_eq(spawned, 80, "80 material particles seeded")
	# 80 of 100 is above the 75% share feedback is allowed to touch.
	assert_eq(ChFeedbackParticles.budget(world, 10), 0, "a pool above 75% gets nothing")
	var before: int = world.get_stats()["particles_visual"]
	var n: int = ChFeedbackParticles.burst_world(world, Vector2(240, 90), _profile_asking(10), Color.RED)
	assert_eq(n, 0, "the burst asks for nothing")
	assert_eq(world.get_stats()["particles_visual"], before, "no visual particles were added")
	_complete()


func test_feedback_never_writes_cells() -> void:
	var world: PixelWorld = await make_world()
	var at := Vector2(240, 90)
	var rect := Rect2i(220, 70, 40, 40)
	var broken: ChFeedbackProfile = Feedback.profile(&"broken")
	assert_eq(broken.particle_count, ChFeedbackParticles.CAP, "broken asks for a full burst")
	var before: Dictionary = world.count_materials(rect)
	var n: int = ChFeedbackParticles.burst_world(world, at, broken, Color.WHITE)
	assert_eq(n, ChFeedbackParticles.CAP, "the broken burst is at the cap")
	world.step(120)
	var after: Dictionary = world.count_materials(rect)
	# Visual particles never become cells: the 40x40 around the burst is untouched.
	assert_true(after == before, "feedback wrote no cells: %s vs %s" % [before, after])
	_complete()


func test_ui_burst_uses_cpu_particles() -> void:
	# No world bound: the garage/UI path draws with Godot's own CPU particles.
	Feedback.unbind_world()
	var host := _parent()
	var target := Control.new()
	host.add_child(target)
	target.global_position = Vector2(40, 50)
	var before: int = _cpu_bursts().size()
	Feedback.play(&"placed", target)
	var bursts := _cpu_bursts()
	assert_eq(bursts.size(), before + 1, "placed adds one CPU particle burst")
	var burst: CPUParticles2D = bursts[before]
	var placed: ChFeedbackProfile = Feedback.profile(&"placed")
	assert_eq(burst.amount, placed.particle_count, "amount comes from the profile")
	assert_true(burst.color.is_equal_approx(placed.particle_color), "colour comes from the profile")
	assert_true(burst.one_shot, "the burst plays once")
	assert_true(burst.emitting, "the burst is emitting")
	# The layer is screen-space, so the burst sits at the target's canvas point.
	assert_true(burst.position.distance_to(target.get_global_transform_with_canvas().origin) < 1.0,
		"the burst sits at the target's screen point, got %s" % burst.position)
	# An override wins over the profile's colour.
	Feedback.play(&"placed", target, {"color": Color.RED})
	var overridden := _cpu_bursts()
	assert_eq(overridden.size(), before + 2, "the override adds a second burst")
	assert_eq(overridden[before + 1].color, Color.RED, "overrides.color wins")
	# A burst frees itself on `finished`; walk frames past its lifetime (0.1 s of slack).
	var lifetime: float = burst.lifetime
	var ml = Engine.get_main_loop()
	var elapsed := 0.0
	while elapsed < lifetime + 0.1:
		await ml.process_frame
		elapsed += ml.root.get_process_delta_time()
	assert_true(not is_instance_valid(burst), "the first burst freed itself")
	assert_true(not is_instance_valid(overridden[before + 1]), "the overridden burst freed itself")
	_complete()
