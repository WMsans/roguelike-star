extends ChBehaviour

# The Focus Lens (U38): a neighbouring beam's switch-on gives its hits +30 for its first second.
const BONUS := 30
const WINDOW := 1.0  # seconds the boost lasts from the switch-on

var _beam: ChPartRuntime = null  # the beam the last switch-on came from
var _until := 0.0  # ctx.time the window closes


func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.PART_FIRED, func(event: ChEvent): _fired(ctx, event))

func _fired(ctx: ChBattleContext, event: ChEvent) -> void:
	var source: ChPartRuntime = event.source
	if source == null or not _neighbours(ctx, "beam").has(source):
		return
	# A beam's PART_FIRED is its switch-on (ChBattleContext._continuous), so the window starts here.
	_beam = source
	_until = ctx.time + WINDOW

func modify_hit(ctx: ChBattleContext, hit: Dictionary) -> void:
	if _beam == null or hit.get("source") != _beam or ctx.time > _until:
		return
	hit["bonus"] = int(hit["bonus"]) + BONUS
