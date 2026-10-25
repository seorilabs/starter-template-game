extends RefCounted
func execute(progress_port: RefCounted) -> bool:
	return progress_port.record_hit()
