class_name ChCatalog extends Resource

# The defs a build reads: part ids to ChPartDef, body ids to ChBodyDef. A layout stores ids, so
# anything that measures a layout (anchor_of, swap_body) goes through a catalog.
# Task 4b adds load_default() to fill one from res://game/data/{parts,bodies}/.

var parts: Dictionary[StringName, ChPartDef] = {}
var bodies: Dictionary[StringName, ChBodyDef] = {}


static func from_defs(part_defs: Array[ChPartDef], body_defs: Array[ChBodyDef]) -> ChCatalog:
	# from_defs builds a catalog in code so tests need no .tres files and no editor pass; a
	# static function has no `self`, so it constructs the instance it returns.
	var catalog: ChCatalog = ChCatalog.new()
	# id is the key, which is how a layout's part_id finds its def.
	# shortcut: a duplicate id overwrites silently; load_default should warn when it scans files.
	# The tests hand in unique ids, so from_defs does not validate anything here.
	for part_def in part_defs:
		catalog.parts[part_def.id] = part_def
	for body_def in body_defs:
		# Bodies go in the same way, so swap_body can read a new body's slot positions.
		catalog.bodies[body_def.id] = body_def
	return catalog


func part(id: StringName) -> ChPartDef:
	# part returns null for an id the catalog does not hold; callers decide whether that is an
	# error. A part can be mounted with no def here, so only reads that need one should check.
	# shortcut: get() rather than a has() check; a suite that reports unknown ids needs a reason.
	return parts.get(id)


func body(id: StringName) -> ChBodyDef:
	# body reads null the same way part does, so an unmounted body choice still measures.
	return bodies.get(id)
