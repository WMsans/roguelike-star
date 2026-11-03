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
	# shortcut: a duplicate id overwrites silently, as load_default does.
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


static func load_default() -> ChCatalog:
# The slice's content on disk: one .tres per def. A file counts as a def when it carries a
# non-empty `id`, which keeps a hand-authored resource out of the catalog without a name list.
# Keying on the def's own id is how a layout's part_id finds its def.
# shortcut: a missing or empty def folder is not an error here - the tables stay empty, so
# every later read answers null and the catalog tests report the ids they looked for.
	var catalog: ChCatalog = ChCatalog.new()
	# Each folder holds one def class; the pair below says which class goes in which table.
	var part_folder := "res://game/data/parts"
	var body_folder := "res://game/data/bodies"
	# shortcut: the list stays untyped, so the folder's flag is read as a bool at runtime rather than
	# checked at parse time; a wrong flag here fails the id tests rather than raising the load.
	var tables := [[part_folder, true], [body_folder, false]]
	# The folder picks the table; the def's own id picks the key.
	# shortcut: defs live one level deep, so there is no recursion; the .tres check skips a .uid sidecar.
	# shortcut: DirAccess.open wants the folder with no trailing slash; String.path_join adds the separator.
	# shortcut: an absent folder is skipped rather than reported, so the suite still runs and the id
	# tests name what is missing.
	# shortcut: untyped load() cannot enforce the def class, so a def whose `id` holds the wrong type
	# is skipped here and reported by the tests that read the ids; the skip names the file.
	# shortcut: the class is checked because a typed table raises on a value of the wrong class,
	# which would end the scan and lose every def after it; a def filed under the other folder is
	# a filing mistake with no reader, so it is skipped rather than raised, with the file named.
	# shortcut: a duplicate id keeps the later file and warns naming both paths; the slice files one
	# def per id, so the warning is the only way a clash shows without a name list.
	for entry in tables:
		var folder: String = entry[0]
		var dir := DirAccess.open(folder)
		if dir == null:
			continue
		# `table` aliases the catalog's dict, so the write below reaches it.
		var table: Dictionary = catalog.parts if entry[1] else catalog.bodies
		for file_name in dir.get_files():
			if not file_name.ends_with(".tres"):
				continue
			# shortcut: an unparseable .tres has already printed why; keep scanning so one bad file cannot
			# hide the defs after it. The warnings below name the file so a mistyped data file leaves
			# a trace in the run instead of becoming a null def later.
			var def_path := folder.path_join(file_name)
			var def = ResourceLoader.load(def_path)
			if def == null:
				push_warning("catalog: %s is not loadable, so it adds no def" % def_path)
				continue
			var def_id = def.get("id")
			# A file with no `id` property holds no def (see the note above the method).
			if def_id == null or String(def_id) == "":
				push_warning("catalog: %s has no id, so it adds no def" % def_path)
				continue
			if (def is ChPartDef) != entry[1]:
				push_warning("catalog: %s is not a %s under %s, so it adds no def"
					% [def_path, "ChPartDef" if entry[1] else "ChBodyDef", folder])
				continue
			# A hand-authored resource can pass the id and class checks and still carry an id another
			# file owns: the name it already holds is the only evidence of the clash.
			if table.has(StringName(def_id)):
				push_warning("catalog: %s replaces the def already filed as id %s"
					% [def_path, String(def_id)])
			table[StringName(def_id)] = def
	return catalog
