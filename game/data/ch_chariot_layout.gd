class_name ChChariotLayout extends Resource

# A build: the body it sits on plus the tree of parts mounted in that body's slots.
# A path is a list of slot indices: [2] is body slot 2, [2,0] is extension slot 0 of the part
# in body slot 2. Positions live in the catalog defs, so anything that measures takes a catalog.

var body_id: StringName = &""
var slots: Dictionary[int, ChSlotNode] = {}  # body slot index -> node


func place(path: Array[int], part_id: StringName) -> bool:
	# Fails when the slot is taken or the parent node is missing: place has no catalog, so an
	# unknown id or an out-of-range index mounts and reads back no anchor through anchor_of.
	# shortcut: place returns a bool; the garage explains a refusal with its own get_node check.
	if path.is_empty():
		return false
	# An empty path names the body, which is not a slot anything can hold.
	# The last index is the slot to fill; the ones before it name a node on the way down.
	var index: int = path[path.size() - 1]
	# `table` aliases slots or the parent's children, so the one write below reaches the tree.
	# shortcut: no replace(); a taken slot refuses, so the garage lifts before it places.
	var table: Dictionary = slots
	if path.size() > 1:
	# A nested path needs its parent's table, so walk to the parent before cutting.
		var parent: ChSlotNode = get_node(path.slice(0, path.size() - 1))
		if parent == null:
			return false
		table = parent.children
	if table.has(index):
		return false
	# A fresh node arrives unflipped: facing is the garage's separate click action.
	var node := ChSlotNode.new()
	node.part_id = part_id
	# The id is stored as given, with no catalog here to validate it against; a missing def shows
	# up as no anchor at anchor_of. The slot index is the key, so a moved branch keeps its paths.
	table[index] = node
	return true


func remove(path: Array[int]) -> ChSlotNode:
	# A lift takes the branch, not the tip, so the garage can return a part to the inventory with
	# everything still bolted onto it. Nothing here re-mounts what it cut: the caller decides.
	# shortcut: null is the only refusal signal, covering a bad path and an already-empty slot.
	if path.is_empty():
		return null
	if path.size() == 1:
	# An empty path names the body, which cannot detach: swap_body changes a body instead.
		var top: ChSlotNode = slots.get(path[0])
		if top != null:
			slots.erase(path[0])
		return top
	var parent: ChSlotNode = get_node(path.slice(0, path.size() - 1))
	if parent == null:
		return null
	# The keys inside the cut node are untouched, which is how swap_body keeps a branch together.
	var child: ChSlotNode = parent.children.get(path[path.size() - 1])
	if child != null:
		parent.children.erase(path[path.size() - 1])
	return child


func toggle_flip(path: Array[int]) -> void:
	# The garage clicks a part to send it facing the other way: only the flag changes, and what
	# moves is where its children hang, which is the flag anchor_of reads.
	# shortcut: a bad path flips nothing silently; the garage only clicks paths all_paths gave.
	var node: ChSlotNode = get_node(path)
	if node == null:
		return
	node.flipped = not node.flipped


func get_node(path: Array[int]) -> ChSlotNode:
	# The walk every other method reaches a node through: paths are chains of slot indices.
	# shortcut: null covers both an empty path (the body) and a missing slot; callers that care check.
	if path.is_empty():
		return null
	var node: ChSlotNode = slots.get(path[0])
	if node == null:
		return null
	for i in range(1, path.size()):
		# shortcut: the walk stops at the first hole, so a chain with a hole in its middle is
		# unreachable; place mounts top-down, so this class cannot build such a chain.
		node = node.children.get(path[i])
		if node == null:
			return null
	return node


func all_paths() -> Array:
	# Depth-first, parent before child: the order a builder needs, since a joint has to attach
	# to something already mounted, so nothing sorts the result afterwards.
	# shortcut: all_paths has no test in this task's list; Task 5's garage asserts the click list.
	# shortcut: no key sort, so siblings keep insertion order, i.e. the order the parts were placed.
	var out: Array = []
	var stack: Array = []
	for index in slots.keys():
		# Body slots seed the stack in insertion order.
		stack.append([[index], slots[index]])
	while not stack.is_empty():
		# pop_back takes the deepest path first, which is what makes the walk depth-first.
		var entry: Array = stack.pop_back()
		out.append(entry[0])
		var node: ChSlotNode = entry[1]
		# A child's path is its parent's path plus its extension key, i.e. the same chain get_node walks.
		# shortcut: keys() copies, so this method cannot mutate a table while walking it.
		var keys: Array = node.children.keys()
		for i in range(keys.size() - 1, -1, -1):
			# Push in reverse so the lowest extension key pops first, keeping sibling order without sorting.
			stack.append([entry[0] + [keys[i]], node.children[keys[i]]])
	return out


func anchor_of(path: Array[int], catalog: ChCatalog) -> Vector2:
	# Body-local cell position of the part at the path: positions live in the defs, which is why
	# the catalog is a parameter and the layout itself stores only ids.
	# shortcut: ZERO answers every failure (no node, no def, index out of range); the brief fixes
	# the return type to Vector2, so a reason cannot travel with an anchor and a caller re-checks.
	if path.is_empty():
		return Vector2.ZERO
	# A path that addresses no mounted part has no anchor, so no def is read for it.
	if get_node(path) == null:
		return Vector2.ZERO
	var body: ChBodyDef = catalog.body(body_id)
	if body == null or path[0] < 0 or path[0] >= body.slots.size():
		return Vector2.ZERO
	# An index outside the def's range is checked here rather than at place, which has no def to
	# check against: a PackedVector2Array index wraps, so the bound belongs on this side.
	var at := Vector2(body.slots[path[0]])
	var node: ChSlotNode = slots[path[0]]
	for i in range(1, path.size()):
		# One step per path index: the offset comes from the part one level up, looked up by its id.
		# shortcut: only the direct parent's flag is read, so an ancestor does not rotate a whole branch.
		var def: ChPartDef = catalog.part(node.part_id)
		if def == null:
			return Vector2.ZERO
		if path[i] < 0 or path[i] >= def.extension_slots.size():
			return Vector2.ZERO
		# A flip negates the extension offset's x only: a flip turns the mount left/right, not upside
		# down, so y stays. A part's own flag never enters its own anchor, only its parent's.
		var off: Vector2 = def.extension_slots[path[i]]
		if node.flipped:
			off.x = -off.x
		# shortcut: at accumulates, so depth costs the loop rather than a case per level.
		at += off
		node = node.children[path[i]]
	return at


func swap_body(new_body: ChBodyDef, catalog: ChCatalog) -> Array[ChSlotNode]:
	# Reseats top-level subtrees onto the nearest of the new body's slots, greedily by distance,
	# and hands back whatever found no slot. Children move with their parent, so their extension
	# indices stay unchanged.
	# shortcut: distances compare body-local cells between the two defs, which is nearest in the
	# body's own frame; a body needing an off-centre swap would want an offset field in ChBodyDef.
	# shortcut: an equal distance keeps the lower old index (pairs are built old-major and sort is
	# stable); the design doc states no tie-break, and the test bodies avoid ties.
	# shortcut: a missing old def returns the parts whole and leaves the layout untouched, so a
	# caller that fixes its catalog can retry rather than repair what the swap did.
	var old_body: ChBodyDef = catalog.body(body_id)
	if old_body == null:
		var whole: Array[ChSlotNode] = []
		for index in slots.keys():
			whole.append(slots[index])
		return whole
	# An index the old def has no slot for has no position to measure, so it comes back whole.
	var pairs: Array = []
	for index in slots.keys():
		if index < 0 or index >= old_body.slots.size():
			continue
		var old_at := Vector2(old_body.slots[index])
		for new_index in new_body.slots.size():
			pairs.append([old_at.distance_to(Vector2(new_body.slots[new_index])), index, new_index])
	# sort() compares element by element, so a distance carries its two indices with it.
	pairs.sort()
	var seat_of: Dictionary[int, int] = {}
	var slot_taken: Dictionary[int, bool] = {}
	for pair in pairs:
		# Greedy in sorted order: the nearest pair wins first, so a subtree gets one slot and a slot
		# gets one subtree: a part never splits and a slot never holds two.
		if seat_of.has(pair[1]) or slot_taken.has(pair[2]):
			continue
		seat_of[pair[1]] = pair[2]
		slot_taken[pair[2]] = true
	# Nodes are copied out before any key is cleared, so a reseat cannot lose a node on the way.
	var carried: Dictionary[int, ChSlotNode] = {}
	for index in slots.keys():
		carried[index] = slots[index]
	var seats: Dictionary[int, ChSlotNode] = {}
	var leftovers: Array[ChSlotNode] = []
	for index in carried.keys():
		if not seat_of.has(index):
			# A leftover keeps its subtree whole rather than stripped: a subtree is one object.
			leftovers.append(carried[index])
			continue
		seats[seat_of[index]] = carried[index]
	slots = seats
	# Every later anchor then reads the new def, and an anchor is body-local, so a swap needs no
	# world position anywhere in this class.
	body_id = new_body.id
	return leftovers


func mirrored() -> ChChariotLayout:
	# The enemy copy: the same build with every flip inverted, so its parts face the player.
	# Deep copies, since a shared node would report one flag to both builds.
	# shortcut: iterative rather than a private recursive helper; the brief's interface list allows
	# no extra method, and a build is a few dozen nodes, so a stack is cheap here.
	var copy := ChChariotLayout.new()
	copy.body_id = body_id
	var stack: Array = []
	for index in slots.keys():
		# A copy keeps its keys, so a mirrored build answers the same paths as the original.
		var fresh := ChSlotNode.new()
		fresh.part_id = slots[index].part_id
		fresh.flipped = not slots[index].flipped
		copy.slots[index] = fresh
		stack.append([slots[index], fresh])
	while not stack.is_empty():
		var entry: Array = stack.pop_back()
		for key in entry[0].children.keys():
			var child := ChSlotNode.new()
			child.part_id = entry[0].children[key].part_id
			child.flipped = not entry[0].children[key].flipped
			entry[1].children[key] = child
			stack.append([entry[0].children[key], child])
	return copy


func subtree_part_ids(node: ChSlotNode) -> Array[StringName]:
	# The ids in a subtree, parent before child, which is the order a builder needs for its joints.
	# shortcut: recursive, the only recursion in the file, since nothing else keeps state to walk.
	# shortcut: ids rather than nodes, so ChInventory stays free of layout knowledge: a lift hands
	# this array straight to ChInventory.add.
	var ids: Array[StringName] = [node.part_id]
	for key in node.children.keys():
		ids.append_array(subtree_part_ids(node.children[key]))
	return ids
