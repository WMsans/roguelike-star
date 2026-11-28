extends ChBehaviour

# The Focus Lens (U38): a neighbouring beam's switch-on gives its hits +30 for its first second.
const BONUS := 30
const WINDOW := 1.0  # seconds the boost lasts from the switch-on

var _windows := {}  # beam part -> the ctx.time its window closes


func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.PART_FIRED, func(event: ChEvent): _fired(ctx, event))

func _fired(ctx: ChBattleContext, event: ChEvent) -> void:
	var source: ChPartRuntime = event.source
	if source == null or not _neighbours(ctx, "beam").has(source):
		return
	# A beam's PART_FIRED is its switch-on (ChBattleContext._continuous), so the window starts here.
	_windows[source] = ctx.time + WINDOW

func modify_hit(ctx: ChBattleContext, hit: Dictionary) -> void:
	var source = hit.get("source")
	if source == null or not _windows.has(source) or ctx.time > _windows[source]:
		return
	hit["bonus"] = int(hit["bonus"]) + BONUS
