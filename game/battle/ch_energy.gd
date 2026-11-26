class_name ChEnergy extends RefCounted

# The battle's energy pool: a value that regenerates, a drive cost paid while a direction is held,
# and try_pay, which the volley uses to buy one part's cost at a time. Nothing waits in line any
# more: a part that does not fit is skipped by the caller and stays ready, so the pool holds no
# memory between presses.
# Tick order: regen, then the drive. The volley pays after that (ChBattleContext), so a held
# direction always beats a part and delays it visibly rather than deadlocking it.

var value: float = 0.0
var cap: float = 0.0
var regen: float = 0.0
var drive_cost: float = 2.0
var spent: float = 0.0  # every point paid since construction, drive and volley both (balance runner)


func _init(cap: float, regen: float, drive_cost: float = 2.0) -> void:
	# The parameters shadow the members of the same name, so self. names the member being written.
	self.cap = cap
	self.regen = regen
	self.drive_cost = drive_cost
	value = cap


func try_pay(cost: float) -> bool:
	# An exact fit pays: energy is only spent when it covers the cost outright, and a refusal
	# changes nothing, so the caller can try a cheaper part next.
	# shortcut: costs are paid whole; a partial-fire rule would need a remainder here.
	if cost > value:
		return false
	value -= cost
	spent += cost
	return true


func tick(delta: float, driving: bool) -> Dictionary:
	# Regen first, so a tick that both refills and pays can fire a part that was one point short.
	# minf clamps the pool rather than letting it overflow, so regen buys nothing above cap.
	value = minf(value + regen * delta, cap)
	var drove: bool = false
	# A drive that does not fit is not taken: driving spends nothing, so a
	# chariot with no energy stays put rather than going into debt.
	# shortcut: the drive pays whole for the whole delta; splitting a delta into smaller steps is
	# a caller's job, since a part of a drive costs nothing here.
	if driving and value >= drive_cost * delta:
		value -= drive_cost * delta
		spent += drive_cost * delta
		drove = true
	return {"drove": drove}
