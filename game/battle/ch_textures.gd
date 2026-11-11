class_name ChTextures extends RefCounted

# A copy of the addon demo helper (addons/noita_engine/demo/textures_util.gd) under a game name:
# the addon README forbids shipping code referencing res://addons/noita_engine/demo/.
# PixelRigidBody stamps only a body's opaque pixels, so box/disc never build an empty image.

static func art(source: Texture2D, flip_x: bool) -> ImageTexture:
	# A def's sprite as a body's own texture: RGBA8 like the placeholders, mirrored when the part
	# (or the whole build) faces -x.
	var image := source.get_image()
	image.convert(Image.FORMAT_RGBA8)
	if flip_x:
		image.flip_x()
	return ImageTexture.create_from_image(image)

static func box(w: int, h: int, colour: Color) -> ImageTexture:
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	image.fill(colour)
	for x: int in w:
		image.set_pixel(x, 0, colour.darkened(0.3))
		image.set_pixel(x, h - 1, colour.darkened(0.3))
	for y: int in h:
		image.set_pixel(0, y, colour.darkened(0.3))
		image.set_pixel(w - 1, y, colour.darkened(0.3))
	return ImageTexture.create_from_image(image)

static func polygon(outline: PackedVector2Array, size: Vector2i, colour: Color, mirror_x: bool = false) -> ImageTexture:
	# A hull drawn from its outline: a pixel is solid when its centre is inside, and PixelRigidBody
	# builds the collision hull from these opaque pixels. A mirrored build flips x so the nose of the
	# enemy's hull faces the other way, as its part anchors do.
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var half := Vector2(size) * 0.5
	var solid := func(x: int, y: int) -> bool:
		if x < 0 or y < 0 or x >= size.x or y >= size.y:
			return false
		var at := Vector2(x + 0.5, y + 0.5) - half
		if mirror_x:
			at.x = -at.x
		return Geometry2D.is_point_in_polygon(at, outline)
	for y: int in size.y:
		for x: int in size.x:
			if solid.call(x, y):
				var rim: bool = not (solid.call(x - 1, y) and solid.call(x + 1, y) and solid.call(x, y - 1) and solid.call(x, y + 1))
				image.set_pixel(x, y, colour.darkened(0.3) if rim else colour)
			else:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(image)

static func disc(diameter: int, colour: Color) -> ImageTexture:
	var image := Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	var r := diameter / 2.0
	for y: int in diameter:
		for x: int in diameter:
			var dx := x + 0.5 - r
			var dy := y + 0.5 - r
			image.set_pixel(x, y, colour.lightened(0.15 * float(x < r)) if dx * dx + dy * dy <= r * r else Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(image)

static func outline(source: Image, colour: Color) -> ImageTexture:
	# A one-pixel ring around `source`'s opaque shape, on an image 2 px larger on each axis (so the
	# ring has room outside the part's own footprint). Only transparent pixels touching an opaque
	# 4-neighbour are coloured: the shape's interior stays clear, which is why a lit part gets a rim
	# and no fill tint. Source pixel (x, y) sits at (x + 1, y + 1) here.
	var w := source.get_width()
	var h := source.get_height()
	var image := Image.create(w + 2, h + 2, false, Image.FORMAT_RGBA8)
	for y: int in h + 2:
		for x: int in w + 2:
			if _solid(source, x - 1, y - 1):
				continue
			if _solid(source, x - 2, y - 1) or _solid(source, x, y - 1) \
					or _solid(source, x - 1, y - 2) or _solid(source, x - 1, y):
				image.set_pixel(x, y, colour)
	return ImageTexture.create_from_image(image)

static func _solid(image: Image, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height() and image.get_pixel(x, y).a > 0.0
