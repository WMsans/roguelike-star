class_name ChTextures extends RefCounted

# A copy of the addon demo helper (addons/noita_engine/demo/textures_util.gd) under a game name:
# the addon README forbids shipping code referencing res://addons/noita_engine/demo/.
# PixelRigidBody stamps only a body's opaque pixels, so box/disc never build an empty image.

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
