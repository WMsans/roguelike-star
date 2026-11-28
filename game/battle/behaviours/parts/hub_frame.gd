extends ChBehaviour

# The Hub Frame (U88): the mount tree is proximity. Parts bolted onto it are neighbours of each other
# and of the frame itself, wherever they hang, so ctx.near answers through the link rather than a
# measured distance (the row's Rng is "—").

func links(_ctx: ChBattleContext, a: Object, b: Object) -> bool:
	var pa: ChPartRuntime = a as ChPartRuntime
	var pb: ChPartRuntime = b as ChPartRuntime
	if pa == null or pb == null:
		return false
	if pa == part:
		return pb.parent == part
	if pb == part:
		return pa.parent == part
	return pa.parent == part and pb.parent == part
