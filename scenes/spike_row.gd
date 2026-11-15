extends Area2D

@export var row_width: float = 7000.0
@export var spike_spacing: float = 145.0
@export var sprite_scale: float = 0.8

func _ready() -> void:
	var spike_image: Image = Image.load_from_file("res://assets/environment/spikes.png")
	if spike_image.is_empty():
		push_error("Could not load the spike artwork")
		return
	var spike_texture: Texture2D = ImageTexture.create_from_image(spike_image)
	var x_position: float = -row_width * 0.5 + spike_spacing * 0.5
	while x_position < row_width * 0.5:
		var spike := Sprite2D.new()
		spike.texture = spike_texture
		spike.position = Vector2(x_position, -32.0)
		spike.scale = Vector2.ONE * sprite_scale
		add_child(spike)
		x_position += spike_spacing
