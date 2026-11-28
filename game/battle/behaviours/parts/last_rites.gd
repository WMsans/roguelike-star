extends ChBehaviour

# The Last Rites (U81): one of your parts breaking explodes there. break_part takes the behaviour
# off the bus before its own PART_BROKEN, so the part's own break explodes from teardown; every
# other break arrives through the subscription.
const BLAST_SIZE := &"medium"
const BLAST_DAMAGE := 60
const BLAST_DIG := 4

var _ctx: ChBattleContext = null  # held for teardown, which is called without one

func setup(ctx: ChBattleContext) -> void:
	_ctx = ctx
	ctx.bus.subscribe(self, ChEvent.PART_BROKEN, func(event: ChEvent): _broken(ctx, event))

func teardown() -> void:
	if _ctx != null:
		_explode(_ctx, part)

func _broken(ctx: ChBattleContext, event: ChEvent) -> void:
	if event.side != part.side:
		return
	var broken = event.data.get("part")
	if broken != null:
		_explode(ctx, broken)

func _explode(ctx: ChBattleContext, broken: ChPartRuntime) -> void:
	var at := broken.anchor_world()
	ctx.explode(part, Vector2i(roundi(at.x), roundi(at.y)), BLAST_SIZE, BLAST_DAMAGE, BLAST_DIG)
