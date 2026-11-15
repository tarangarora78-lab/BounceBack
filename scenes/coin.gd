extends Area2D

signal collected

static var shared_texture: Texture2D
var _spin_time: float = 0.0
@onready var art: Sprite2D = $Sprite2D

func _ready() -> void:
	if shared_texture == null:
		var coin_image: Image = Image.load_from_file("res://assets/collectibles/coin.png")
		if coin_image.is_empty():
			push_error("Could not load the coin artwork")
			return
		shared_texture = ImageTexture.create_from_image(coin_image)
	art.texture = shared_texture
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_spin_time += delta * 5.0
	art.scale.x = 0.35 * (0.25 + 0.75 * absf(cos(_spin_time)))

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		collected.emit()
		queue_free()
