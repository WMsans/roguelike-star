class_name ChInventory extends Resource

# Parts carried but not mounted. capacity -1 means unlimited; the run's inventory is CAPACITY.
# A body id is carried here too, in the same list: a bought body takes a slot and a card until the
# garage swaps it onto the hull (ChShopPhase.equip_body), and the catalog says which ids are bodies.

# The run's five carried parts: the shop, the inventory bar and a lift all size themselves off this.
const CAPACITY := 5
# free_slots' answer for capacity -1, so one "does it all fit" rule covers the unlimited kit too.
const UNLIMITED := 1 << 30

var capacity: int = -1
var part_ids: Array[StringName] = []
# Parallel to part_ids: the instance state each carried copy holds (see ChSlotNode.state).
var states: Array[Dictionary] = []


func add(id: StringName, state: Dictionary = {}) -> bool:
	# add checks capacity before appending so a full inventory keeps what it held.
	if capacity >= 0 and part_ids.size() >= capacity:
		return false
	part_ids.append(id)
	# A fresh empty dict rather than the argument's default, so two parts never share one state.
	states.append(state if not state.is_empty() else {})
	# add stores an id without checking the catalog, so an unknown id still fits.
	# shortcut: add never deduplicates; the shop should not offer a part already carried.
	return true


func take(id: StringName) -> bool:
	# take lifts one copy: with a duplicate id the other copy stays.
	var at := part_ids.find(id)
	if at < 0:
		# find returns -1 for an id that is not carried, which is the failure the caller sees.
		return false
	# Array.remove_at keeps the list packed so the order the garage shows stays stable.
	# shortcut: take lifts the FIRST copy; remove_at is the handle for a copy chosen by index.
	part_ids.remove_at(at)
	# The state goes with the id: a part that left the inventory cannot leave its state behind.
	states.remove_at(at)
	return true


func free_slots() -> int:
	# The one number a fit check reads: how many more parts would still land. An unlimited kit has
	# room for anything, which is how ChMain's capacity -1 inventory passes the same check the
	# run's five-slot one does.
	if capacity < 0:
		return UNLIMITED
	return capacity - part_ids.size()


func move(from: int, to: int) -> bool:
	# The bar's reorder: the part is lifted out and set down at `to`, so the parts between it and the
	# target shift one place rather than trading slots with it.
	# Out of range on either end refuses without touching the list, so the screen can hand this a drop
	# position it has not validated itself.
	if from < 0 or to < 0 or from >= part_ids.size() or to >= part_ids.size():
		return false
	var id: StringName = part_ids.pop_at(from)
	part_ids.insert(to, id)
	# The state moves in the same step, so the card and its state never disagree about the slot.
	var state: Dictionary = states.pop_at(from)
	states.insert(to, state)
	return true


func remove_entry(index: int) -> Dictionary:
	# The index handle take does not have: two copies of one part are two cards in the bar, and the
	# slot says which one was sold or mounted. An index with nothing in it answers an empty dict.
	if index < 0 or index >= part_ids.size():
		return {}
	return {&"id": part_ids.pop_at(index), &"state": states.pop_at(index)}


func remove_at(index: int) -> StringName:
	# The id half of remove_entry, kept so a caller that only needs the id reads as before.
	return remove_entry(index).get(&"id", &"")


func has(id: StringName) -> bool:
	# has reports presence, not count: any copy counts as carried.
	# shortcut: has only answers for ids; a caller that wants to know whether a part is mounted
	# has to ask the layout, which is the other half of the same part's location.
	return part_ids.find(id) >= 0
