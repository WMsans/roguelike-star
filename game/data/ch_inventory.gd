class_name ChInventory extends Resource

# Parts carried but not mounted. capacity -1 means unlimited; the garage's inventory is 5.

var capacity: int = -1
var part_ids: Array[StringName] = []


func add(id: StringName) -> bool:
	# add checks capacity before appending so a full inventory keeps what it held.
	if capacity >= 0 and part_ids.size() >= capacity:
		return false
	part_ids.append(id)
	# add stores an id without checking the catalog, so an unknown id still fits.
	# shortcut: add never deduplicates; the shop should not offer a part already carried.
	return true


func take(id: StringName) -> bool:
	# take lifts one copy: with a duplicate id the other copy stays.
	var at := part_ids.find(id)
	if at < 0:
		# find returns -1 for an id that is not carried, which is the failure the caller sees.
		return false
	# remove_at keeps the list packed so the order the garage shows stays stable.
	# shortcut: ids are the only handle here, so a caller cannot lift "the second copy" by index.
	part_ids.remove_at(at)
	return true


func has(id: StringName) -> bool:
	# has reports presence, not count: any copy counts as carried.
	# shortcut: has only answers for ids; a caller that wants to know whether a part is mounted
	# has to ask the layout, which is the other half of the same part's location.
	return part_ids.find(id) >= 0
