extends RefCounted
const TARGETS := 3
static func remaining(hits: int) -> int:
	return maxi(0, TARGETS - hits)
