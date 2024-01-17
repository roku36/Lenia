extends ColorRect

@export var mouse_size : float = 5.0
@export var mouse_weight: float = 5.0
@export_range(1.0, 10.0, 0.1) var damp : float = 1.0

@onready var fps_label: Label = $FpsLabel

var t: float = 0.0
var max_t: float = 0.1

var texture : Texture2DRD
var texture_size : Vector2i
var next_texture : int = 0

var add_wave_point : Vector4

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# In case we're running stuff on the rendering thread
	# we need to do our initialisation on that thread.
	texture_size = Vector2i(self.size)
	RenderingServer.call_on_render_thread(_initialize_compute_code.bind(texture_size))

	# Get our texture from our material so we set our RID.
	self.material.set_shader_parameter("effect_texture_size", texture_size)
	# Get our texture object.
	texture = self.material.get_shader_parameter("effect_texture")

func _check_mouse_pos() -> void:
	var pos := self.get_local_mouse_position()
	add_wave_point.x = pos.x
	add_wave_point.y = pos.y

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	fps_label.text = str(Engine.get_frames_per_second())
	_check_mouse_pos()
	add_wave_point.z = 0.0
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		add_wave_point.z = mouse_size
		add_wave_point.w = mouse_weight
	elif Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		add_wave_point.z = mouse_size
		add_wave_point.w = -mouse_weight

	# Increase our next texture index.
	next_texture = (next_texture + 1) % 2

	# Update our texture to show our next result (we are about to create).
	# Note that `_initialize_compute_code` may not have run yet so the first
	# frame this my be an empty RID.
	if texture:
		texture.texture_rd_rid = texture_rds[next_texture]

	# While our render_process may run on the render thread it will run before our texture
	# is used and thus our next_rd will be populated with our next result.
	# It's probably overkill to sent texture_size and damp as parameters as these are static
	# but we sent add_wave_point as it may be modified while process runs in parallel.
	RenderingServer.call_on_render_thread(_render_process.bind(next_texture, add_wave_point, texture_size))

###############################################################################
# Everything after this point is designed to run on our rendering thread.

var rd : RenderingDevice

var shader : RID
var pipeline : RID

# We use 3 textures:
# - One to render into
# - One that contains the last frame rendered
# - One for the frame before that
var texture_rds : Array = [ RID(), RID() ]
var texture_sets : Array = [ RID(), RID()]

func _create_uniform_set(texture_rd : RID) -> RID:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = 0
	uniform.add_id(texture_rd)
	# Even though we're using 3 sets, they are identical, so we're kinda cheating.
	return rd.uniform_set_create([uniform], shader, 0)


func _initialize_compute_code(init_with_texture_size: Vector2i) -> void:
	# As this becomes part of our normal frame rendering,
	# we use our main rendering device here.
	rd = RenderingServer.get_rendering_device()

	# Create our shader.
	var shader_file: Resource = load("res://lenia_plane/lenia.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(shader_spirv)
	pipeline = rd.compute_pipeline_create(shader)

	# Create our textures to manage our wave.
	var tf : RDTextureFormat = RDTextureFormat.new()
	tf.format = RenderingDevice.DATA_FORMAT_R32_SFLOAT
	tf.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	tf.width = init_with_texture_size.x
	tf.height = init_with_texture_size.y
	tf.depth = 1
	tf.array_layers = 1
	tf.mipmaps = 1
	tf.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT + RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT + RenderingDevice.TEXTURE_USAGE_STORAGE_BIT + RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT + RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT

	for i in range(2):
		# Create our texture.
		texture_rds[i] = rd.texture_create(tf, RDTextureView.new(), [])
		# Make sure our textures are cleared.
		rd.texture_clear(texture_rds[i], Color(0, 0, 0, 0), 0, 1, 0, 1)
		# Now create our uniform set so we can use these textures in our shader.
		texture_sets[i] = _create_uniform_set(texture_rds[i])


func _render_process(with_next_texture: int, wave_point: Vector4, tex_size: Vector2i) -> void:
	# We don't have structures (yet) so we need to build our push constant
	# "the hard way"...
	var push_constant : PackedFloat32Array = PackedFloat32Array()
	push_constant.push_back(wave_point.x)
	push_constant.push_back(wave_point.y)
	push_constant.push_back(wave_point.z)
	push_constant.push_back(wave_point.w)
	push_constant.push_back(tex_size.x)
	push_constant.push_back(tex_size.y)
	push_constant.push_back(damp)
	push_constant.push_back(0.0)

	# Calculate our dispatch group size.
	# We do `n - 1 / 8 + 1` in case our texture size is not nicely
	# divisible by 8.
	# In combination with a discard check in the shader this ensures
	# we cover the entire texture.
	var x_groups: int = ceili(tex_size.x / 8.0)
	var y_groups: int = ceili(tex_size.y / 8.0)

	var next_set: RID = texture_sets[with_next_texture]
	var current_set: RID = texture_sets[(with_next_texture - 1)]
	# var current_set: RID = texture_sets[(with_next_texture - 1) % 2]

	# Run our compute shader.
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, current_set, 0)
	rd.compute_list_bind_uniform_set(compute_list, next_set, 1)
	rd.compute_list_set_push_constant(compute_list, push_constant.to_byte_array(), push_constant.size() * 4)
	rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
	rd.compute_list_end()

	# We don't need to sync up here, Godots default barriers will do the trick.
	# If you want the output of a compute shader to be used as input of
	# another computer shader you'll need to add a barrier:
	rd.barrier(RenderingDevice.BARRIER_MASK_COMPUTE)


func _free_compute_resources() -> void:
	# Note that our sets and pipeline are cleaned up automatically as they are dependencies :P
	for i in range(2):
		if texture_rds[i]:
			rd.free_rid(texture_rds[i])
	if shader:
		rd.free_rid(shader)
