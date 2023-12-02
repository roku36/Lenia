extends Node3D

# Note, the code here just adds some control to our effects.
# Check res://water_plane/water_plane.gd for the real implementation.

var y: float = 0.0

@onready var water_plane: Area3D = $WaterPlane
@onready var fps_label: Label = $Container/FpsLabel

func _ready() -> void:
	$Container/RainSize/HSlider.value = $WaterPlane.rain_size
	$Container/MouseSize/HSlider.value = $WaterPlane.mouse_size


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	fps_label.text = str(Engine.get_frames_per_second())
	if $Container/Rotate.button_pressed:
		y += delta
		water_plane.basis = Basis(Vector3.UP, y)


func _on_rain_size_changed(value: float) -> void:
	$WaterPlane.rain_size = value


func _on_mouse_size_changed(value: float) -> void:
	$WaterPlane.mouse_size = value
