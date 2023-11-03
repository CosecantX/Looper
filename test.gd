extends Node2D

func _ready():
	var sprite = Sprite2D.new()
	sprite.texture = preload("res://Assets/element_red_square.png")
	self.add_child(sprite)
	var tween = create_tween()
	tween.tween_property(sprite, "position", Vector2(100,100), 1)
