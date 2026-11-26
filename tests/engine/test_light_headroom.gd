extends ChTest

# PixelWorld.light_headroom: the light overlay's cap. 1.0 is the old hard cap, so a world that never
# sets it renders as before; above 1.0 light can lift a cell past its own colour.


func test_headroom_defaults_to_one() -> void:
	var world := PixelWorld.new()
	assert_near(world.light_headroom, 1.0)
	world.free()
	_complete()


func test_headroom_round_trips() -> void:
	var world := PixelWorld.new()
	world.light_headroom = 1.8
	assert_near(world.get_light_headroom(), 1.8)
	world.free()
	_complete()
