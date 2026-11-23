extends Node

var prologue_completed: bool = false
var water_bonus: int = 0
var harmony_bonus: int = 0
var pressure_offset: int = 0
var carryover_applied: bool = false


func reset_carryover() -> void:
	prologue_completed = false
	water_bonus = 0
	harmony_bonus = 0
	pressure_offset = 0
	carryover_applied = false


func add_carryover(dw: int, dh: int, dp: int) -> void:
	water_bonus += dw
	harmony_bonus += dh
	pressure_offset += dp
