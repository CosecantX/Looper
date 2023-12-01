extends Node2D
class_name Block

const COLORS = preload("res://Scenes/colors_enum.gd").colors

@export var line_color : Color

@export var color : COLORS

var pos : Vector2

var visited: bool = false

var out_of_loop : bool = false
