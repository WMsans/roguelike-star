class_name ChPopups extends CanvasLayer

# Screen-space pop-up text: a fixed pool of labels that the manager fills on a feedback beat.
# Motion is stepped by advance() (driven by _process), never by Tween, so a test walks a pop-up's
# life exactly. The layer is screen-space on purpose: the manager hands over the target's canvas
# point, so the battle camera's zoom never scales the text — font 28 and a 6 px black outline are
# screen pixels whatever the camera does.

const POOL := 32
const LIFE := 0.8
# Px the text rises over LIFE, and the most x drift it wanders by.
const RISE := 60.0
const DRIFT := 20.0
# Scale pop 0.4 -> 1.25 -> 1.0 over this many seconds, and the fade over the last FADE_TIME.
const POP_TIME := 0.15
const FADE_TIME := 0.25
const FONT_SIZE := 28
const OUTLINE := 6

# Parallel arrays, one entry per pooled label: its age (LIFE or more = free), the point it was
# born at, its x drift for this life, and the pop order that decides which life is oldest.
var _labels: Array[RicherTextLabel] = []
var _age := PackedFloat32Array()
var _origin: Array[Vector2] = []
var _drift := PackedFloat32Array()
var _serial := PackedInt32Array()
var _next_serial := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	# Above the battle HUD: a pop-up belongs to the screen, not to the scene under it.
	layer = 50
	for i in POOL:
		var label := RicherTextLabel.new()
		# In the tree before the addon's properties are set: their setters queue a parse that
		# waits for tree_entered when the label is outside it.
		add_child(label)
		label.font_size = FONT_SIZE
		label.outline_mode = RicherTextLabel.OutlineMode.CUSTOM
		label.outline_color = Color.BLACK
		label.outline_size = OUTLINE
		# Pop-ups are decoration: they must never eat a click meant for a button underneath.
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.visible = false
		_labels.append(label)
		_age.append(LIFE)
		_origin.append(Vector2.ZERO)
		_drift.append(0.0)
		_serial.append(-1)


func _process(delta: float) -> void:
	advance(delta)


func pop(text: String, color: Color, screen_at: Vector2) -> RicherTextLabel:
	var index := _free_slot()
	_age[index] = 0.0
	_serial[index] = _next_serial
	_next_serial += 1
	_origin[index] = screen_at
	_drift[index] = _rng.randf_range(-DRIFT, DRIFT)
	var label := _labels[index]
	label.color = color
	# The addon's own tag syntax: `[]` closes a tag (verified in Task 1).
	label.bbcode = "[b][jump]%s[][]" % text
	label.visible = true
	_apply(index)
	return label


func active() -> Array[RicherTextLabel]:
	var live: Array[RicherTextLabel] = []
	for index in _labels.size():
		if _age[index] < LIFE:
			live.append(_labels[index])
	return live


func advance(delta: float) -> void:
	for index in _labels.size():
		if _age[index] >= LIFE:
			continue
		_age[index] += delta
		if _age[index] >= LIFE:
			_labels[index].visible = false
			continue
		_apply(index)


func _free_slot() -> int:
	# First free label; when the pool is full, the oldest life is recycled (never a 33rd label).
	# Several pops in one frame share an age, so the pop order, not the age, breaks the tie.
	var oldest := 0
	for index in _age.size():
		if _age[index] >= LIFE:
			return index
		if _serial[index] < _serial[oldest]:
			oldest = index
	return oldest


func _apply(index: int) -> void:
	var label := _labels[index]
	var age: float = _age[index]
	var t := age / LIFE
	# Ease-out on both the rise and the drift, so the text leaps then settles.
	var eased := 1.0 - (1.0 - t) * (1.0 - t)
	label.position = _origin[index] + Vector2(_drift[index] * eased, -RISE * eased)
	var scale_pop := 1.0
	if age < POP_TIME:
		var half := POP_TIME * 0.5
		if age < half:
			scale_pop = lerpf(0.4, 1.25, age / half)
		else:
			scale_pop = lerpf(1.25, 1.0, (age - half) / half)
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2.ONE * scale_pop
	label.modulate.a = clampf((LIFE - age) / FADE_TIME, 0.0, 1.0)
