extends ChTest

# The baked effects a fire part leaves behind: the world's own one-shots and loops, which the
# emitters spawn and fade. The parts themselves are tested in tests/parts/test_common_elements.gd.
# shortcut: the fight's tuning lives in game/data/parts; nothing here reads a def.

const TICK := 1.0 / 60.0  # the fight's clock per engine tick, which the fade reads

func test_fx_refuses_a_parent_that_moves() -> void:
	var world: PixelWorld = await make_world()
	var holder := _track(Node2D.new())
	assert_true(ChFx.spawn(world, &"muzzle", Vector2(100, 100)) != null, "the world takes a baked effect")
	assert_true(ChFx.spawn(holder, &"muzzle", Vector2.ZERO) == null, "a node that moves does not")
	_complete()


# A one-shot's frames fade themselves in and out, but a loop has no start or end of its own: taken off
# the tree mid-cycle it pops, which reads as the effect breaking rather than ending. So a loop comes up
# faded and its owner ends it with fade_out() instead of queue_free().
func test_looping_fx_fades_in_and_out() -> void:
	var world: PixelWorld = await make_world()
	var fx := ChFx.spawn(world, &"flamethrower", Vector2(120, 140), Vector2.RIGHT)
	assert_true(fx != null, "the looping sheet spawns")
	assert_true(fx.modulate.a < 1.0, "it comes in faded rather than popped on (%f)" % fx.modulate.a)
	for _tick in 20:
		fx._physics_process(TICK)
	assert_near(fx.modulate.a, 1.0, 0.0001, "and ramps up to full")
	fx.fade_out()
	fx._physics_process(ChFx.FADE_OUT * 0.5)
	assert_near(fx.modulate.a, 0.5, 0.01, "fade_out() takes it down over its own time, not at once")
	fx._physics_process(ChFx.FADE_OUT)
	assert_true(fx.is_queued_for_deletion(), "and it frees itself once faded")
	_complete()

