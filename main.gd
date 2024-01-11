extends Node3D

# Note, the code here just adds some control to our effects.
# Check res://water_plane/water_plane.gd for the real implementation.

var y: float = 0.0

@onready var lenia_plane: Area3D = $LeniaPlane
@onready var fps_label: Label = $Container/FpsLabel

func _ready() -> void:
	$Container/MouseSize/HSlider.value = lenia_plane.mouse_size


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	fps_label.text = str(Engine.get_frames_per_second())


func _on_rain_size_changed(value: float) -> void:
	lenia_plane.rain_size = value


func _on_mouse_size_changed(value: float) -> void:
	lenia_plane.mouse_size = value
