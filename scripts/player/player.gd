extends CharacterBody2D

#region 常量定義
const NORMAL_TIME_SCALE = 1.0
const CAMERA_MODE_TIME_SCALE = 0.1
const MIN_ZOOM = 0.5
const MAX_ZOOM = 2.0
const ZOOM_STEP = 0.01
const ZOOM_DURATION = 0.05
const BLINK_INTERVAL = 0.1
#endregion

#region 導出屬性
@export_group("Movement")
@export var speed = 300.0
@export var jump_velocity = -400.0
@export var max_jumps = 2
@export var jump_buffer_time = 0.1
@export var coyote_time = 0.1

@export_group("Dash")
@export var dash_speed = 250.0
@export var dash_duration = 0.15
@export var dash_cooldown = 0.7
@export var dash_attack_recovery_time = 0.2

@export_group("Combat")
@export var max_health = 10000
@export var defense_duration = 0.5
@export var defense_cooldown = 1.0
@export var defense_strength = 0.5
@export var invincible_duration = 0.5

@export_group("Attack")
@export var attack_move_speed_multiplier = 0.1
@export var attack_combo_window = 0.5
@export var attack_hold_threshold = 0.15
@export var attack1_power = 10
@export var attack2_power = 15
@export var attack3_power = 20
@export var combo_buffer_time = 0.3

@export_group("Special Attack")
@export var special_attack_power_1 = 15
@export var special_attack_power_2 = 20
@export var special_attack_power_3 = 25
@export var special_attack_velocity = -400
@export var special_attack_cooldown = 1.0
#endregion

#region 節點引用
@onready var animated_sprite = $AniSprite2D
@onready var collision_shape = $CollisionShape2D
@onready var attack_area = $AttackArea
@onready var effect_manager = $EffectManager
@onready var special_attack_area = $SpecialAttackArea
@onready var camera = $Camera2D

var shuriken_scene = preload("res://scenes/player/shuriken.tscn")
#endregion

#region 狀態變量
# 基礎狀態
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var current_state = "idle"
var current_health = max_health

# 移動相關
var is_jumping := false
var jump_count := 0
var jump_buffer_timer := 0.0
var coyote_timer := 0.0
var was_on_floor := false

# 衝刺相關
var is_dashing := false
var can_dash := true
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var is_dash_attacking := false
var dash_attack_recovery_timer := 0.0
var is_in_dash_attack_recovery := false
var dash_direction := 1

# 攻擊相關
var is_attacking := false
var current_attack_combo := 0
var is_attack_pressed := false
var can_continue_combo := false
var attack_press_timer := 0.0
var combo_buffer_timer := 0.0
var hit_enemies: Array = []

# 特殊攻擊相關
var is_special_attacking := false
var last_special_attack_frame := -1
var special_attack_timer := 0.0
var special_attack_request := false
var can_special_attack := false

# 防禦和受傷相關
var is_defending := false
var is_jump_attacking := false
var is_hurt := false
var defense_timer := 0.0
var defense_cooldown_timer := 0.0
var is_invincible := false
var invincible_timer := 0.0

# 相機控制相關
var is_camera_mode := false
var camera_move_speed := 500.0
var default_camera_zoom := Vector2(1.2, 1.2)
var camera_mode_zoom := Vector2(1, 1)
var camera_zoom_duration := 0.5
var camera_zoom_tween: Tween
var previous_zoom := Vector2(1.2, 1.2)

# 視覺效果相關
var blink_timer := 0.0
var blink_colors := [Color(1, 1, 1, 0.7), Color(1, 0.5, 0.5, 0.7)]
var current_blink_color := 0
#endregion

#region 信號
signal health_changed(new_health)
signal died
#endregion

#region 生命週期函數
func _ready() -> void:
	_initialize_player()
	_setup_collisions()
	_connect_signals()
	_initialize_skills()

func _physics_process(delta: float) -> void:
	if _handle_camera_mode(delta):
		return
		
	_verify_attack_state()
	_handle_gravity(delta)
	_handle_movement(delta)
	_handle_combat(delta)
	_handle_collision()
	_update_timers(delta)
	_handle_special_attack_request()
	_update_animation()
	_handle_invincibility(delta)

func _input(event: InputEvent) -> void:
	if is_camera_mode and event is InputEventMouseButton:
		_handle_camera_zoom(event)
#endregion

#region 初始化系統
func _initialize_player() -> void:
	add_to_group("player")
	current_health = max_health

func _setup_collisions() -> void:
	set_collision_layer_value(2, true)
	set_collision_mask_value(1, true)
	
	var hitbox = $Hitbox
	if hitbox:
		hitbox.set_collision_layer_value(3, true)
		hitbox.set_collision_mask_value(4, true)
	
	if attack_area:
		attack_area.set_collision_layer_value(4, true)
		attack_area.set_collision_mask_value(3, true)

	if special_attack_area:
		special_attack_area.set_collision_layer_value(4, true)
		special_attack_area.set_collision_mask_value(3, true)
		special_attack_area.monitoring = false

func _initialize_skills() -> void:
	can_special_attack = true
	is_special_attacking = false
	
	if effect_manager:
		effect_manager.visible = false
		effect_manager.modulate.a = 0.8

func _connect_signals() -> void:
	if animated_sprite:
		_disconnect_all_signals()
		animated_sprite.animation_finished.connect(_on_ani_sprite_2d_animation_finished)
		animated_sprite.frame_changed.connect(_on_ani_sprite_2d_frame_changed)
	
	var hitbox = $Hitbox
	if hitbox and not hitbox.area_entered.is_connected(_on_hitbox_area_entered):
		hitbox.area_entered.connect(_on_hitbox_area_entered)
	
	if effect_manager and not effect_manager.effect_finished.is_connected(_on_effect_finished):
		effect_manager.effect_finished.connect(_on_effect_finished)

func _disconnect_all_signals() -> void:
	if animated_sprite:
		if animated_sprite.animation_finished.is_connected(_on_ani_sprite_2d_animation_finished):
			animated_sprite.animation_finished.disconnect(_on_ani_sprite_2d_animation_finished)
		if animated_sprite.frame_changed.is_connected(_on_ani_sprite_2d_frame_changed):
			animated_sprite.frame_changed.disconnect(_on_ani_sprite_2d_frame_changed)
#endregion

#region 移動系統
func _handle_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		_handle_landing()

func _handle_landing() -> void:
	jump_count = 0
	if is_jumping:
		is_jumping = false
		reset_states(true)
		_force_update_animation()

func _handle_movement(delta: float) -> void:
	_update_movement_timers(delta)
	_process_movement_input()
	_update_movement_state()

func _update_movement_timers(delta: float) -> void:
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta
	if coyote_timer > 0:
		coyote_timer -= delta

func _process_movement_input() -> void:
	var direction = Input.get_axis("move_left", "move_right")
	
	if direction:
		_apply_movement(direction)
	else:
		_handle_idle()
	
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	
	if jump_buffer_timer > 0:
		if is_on_floor() or coyote_timer > 0:
			jump()
			jump_buffer_timer = 0
		elif jump_count < max_jumps:
			_perform_double_jump()
			jump_buffer_timer = 0

func _update_movement_state() -> void:
	if is_on_floor():
		coyote_timer = coyote_time
	elif was_on_floor and not is_on_floor():
		coyote_timer = coyote_time
	
	was_on_floor = is_on_floor()

	if Input.is_action_just_pressed("dash") and can_dash and dash_cooldown_timer <= 0:
		_start_dash()

func _apply_movement(direction: float) -> void:
	var current_speed = speed
	
	if is_attacking and not is_jump_attacking and not is_special_attacking and animated_sprite.animation.begins_with("attack"):
		if is_on_floor() and not Input.is_action_pressed("jump"):
			current_speed *= attack_move_speed_multiplier
	
	if direction != 0:
		if is_on_floor() or sign(velocity.x) != sign(direction):
			velocity.x = direction * current_speed
	
	if animated_sprite:
		animated_sprite.flip_h = direction < 0
		
		if is_attacking and animated_sprite.animation.begins_with("attack"):
			return
		if is_special_attacking and animated_sprite.animation == "special_attack":
			return
		if is_dashing and animated_sprite.animation == "dash":
			return
		if is_hurt and animated_sprite.animation == "hurt":
			return
			
		if is_on_floor():
			animated_sprite.play("run")

func _handle_idle() -> void:
	if not is_dashing:
		velocity.x = move_toward(velocity.x, 0, speed)
		
		if animated_sprite and not (is_attacking or is_special_attacking or is_dashing or is_hurt):
			if is_on_floor():
				animated_sprite.play("idle")

func jump() -> void:
	velocity.y = jump_velocity
	is_jumping = true
	jump_count += 1
	if animated_sprite and not is_attacking:
		animated_sprite.play("jump")

func _perform_double_jump() -> void:
	velocity.y = jump_velocity * 0.8
	jump_count += 1
	if animated_sprite and not is_attacking:
		animated_sprite.play("jump")
	
	if effect_manager:
		effect_manager.play_double_jump(animated_sprite.flip_h)
#endregion

#region 攻擊系統
func _handle_attack_input(delta: float) -> void:
	if Input.is_action_just_pressed("attack"):
		start_attack()
	elif Input.is_action_pressed("attack"):
		_continue_attack(delta)
	elif Input.is_action_just_released("attack"):
		_end_attack()
	
	if combo_buffer_timer > 0:
		combo_buffer_timer -= delta
		if combo_buffer_timer <= 0:
			can_continue_combo = false

func start_attack() -> void:
	if is_dashing or is_in_dash_attack_recovery:
		return
		
	is_attacking = true
	attack_press_timer = 0
	
	if can_continue_combo and combo_buffer_timer > 0:
		if current_attack_combo < 2:
			current_attack_combo += 1
		else:
			current_attack_combo = 0
	else:
		current_attack_combo = 0
	
	if animated_sprite:
		var mouse_pos = get_global_mouse_position()
		var direction_to_mouse = (mouse_pos - global_position).normalized()
		animated_sprite.flip_h = direction_to_mouse.x < 0
		
		var attack_num = current_attack_combo + 1
		animated_sprite.play("attack" + str(attack_num))
		
		if attack_area:
			var attack_position = Vector2(50 if not animated_sprite.flip_h else -50, 0)
			attack_area.position = attack_position
		
	if attack_area:
		attack_area.monitoring = true

func finish_attack() -> void:
	is_attacking = false
	is_jump_attacking = false
	is_dash_attacking = false
	hit_enemies.clear()
	
	if attack_area:
		attack_area.monitoring = false
	
	if not is_in_dash_attack_recovery:
		can_continue_combo = true
		combo_buffer_timer = combo_buffer_time
		
		if is_on_floor():
			var direction = Input.get_axis("move_left", "move_right")
			if direction != 0:
				animated_sprite.play("run")
			else:
				animated_sprite.play("idle")
		else:
			is_jumping = true
			animated_sprite.play("jump")

func _continue_attack(delta: float) -> void:
	attack_press_timer += delta
	if attack_press_timer >= attack_hold_threshold and not is_attacking:
		start_attack()

func _end_attack() -> void:
	is_attack_pressed = false
	attack_press_timer = 0

func get_attack_damage() -> float:
	var damage = attack1_power
	
	match current_attack_combo:
		1: damage = attack2_power
		2: damage = attack3_power
	
	if is_dash_attacking:
		damage = float(damage) * 1.5
	
	return damage

func get_knockback_force() -> float:
	var force = 100.0
	
	match current_attack_combo:
		1: force = 120.0
		2: force = 150.0
	
	if is_dash_attacking:
		force *= 1.5
	
	return force

func get_knockback_direction() -> Vector2:
	return Vector2.RIGHT if not animated_sprite.flip_h else Vector2.LEFT

func perform_attack() -> void:
	if not animated_sprite:
		return
		
	if attack_area:
		attack_area.monitoring = true
		_apply_normal_attack_damage()

func _apply_normal_attack_damage() -> void:
	if attack_area:
		var areas = attack_area.get_overlapping_areas()
		for area in areas:
			var body = area.get_parent()
			if body.is_in_group("enemy") and body.has_method("take_damage") and not hit_enemies.has(body):
				hit_enemies.append(body)
				
				var damage = get_attack_damage()
				var knockback_force = get_knockback_force()
				var knockback_direction = get_knockback_direction()
				
				if body.has_method("apply_knockback"):
					body.apply_knockback(knockback_direction * knockback_force)
				
				body.take_damage(damage)
#endregion

#region 特殊攻擊系統
func _handle_special_attack_request() -> void:
	if special_attack_request:
		_start_special_attack()
		special_attack_request = false

func start_special_attack() -> void:
	special_attack_request = true

func _start_special_attack() -> void:
	is_special_attacking = true
	last_special_attack_frame = -1
	
	if special_attack_area:
		special_attack_area.monitoring = true
	
	if animated_sprite:
		var mouse_pos = get_global_mouse_position()
		var direction_to_mouse = (mouse_pos - global_position).normalized()
		animated_sprite.flip_h = direction_to_mouse.x < 0
		animated_sprite.play("special_attack")
		animated_sprite.speed_scale = 1.0

func _finish_special_attack() -> void:
	is_special_attacking = false
	special_attack_request = false
	last_special_attack_frame = -1
	
	if special_attack_area:
		special_attack_area.monitoring = false
	
	special_attack_timer = special_attack_cooldown
	
	if is_on_floor():
		animated_sprite.play("idle")
	else:
		animated_sprite.play("jump")

func perform_special_attack() -> void:
	if not animated_sprite:
		return
		
	var current_frame = animated_sprite.frame
	if current_frame >= 6 and current_frame <= 8 and current_frame != last_special_attack_frame:
		if special_attack_area:
			special_attack_area.monitoring = true
		last_special_attack_frame = current_frame
	else:
		if special_attack_area:
			special_attack_area.monitoring = false

func _apply_special_attack_damage() -> void:
	if special_attack_area and special_attack_area.monitoring:
		var areas = special_attack_area.get_overlapping_areas()
		for area in areas:
			var body = area.get_parent()
			if body.is_in_group("enemy") and body.has_method("take_damage"):
				var damage = 0
				match animated_sprite.frame:
					5: damage = special_attack_power_1
					6: damage = special_attack_power_2
					7: damage = special_attack_power_3
				
				var knockback_direction = Vector2(0, -1)
				if body.has_method("apply_knockback"):
					body.apply_knockback(knockback_direction * 300)
				
				body.take_damage(damage)
#endregion

#region 衝刺系統
func _handle_dash(delta: float) -> void:
	if is_dashing:
		perform_dash(delta)

func _start_dash() -> void:
	if is_attacking:
		_interrupt_attack()
	
	is_dashing = true
	can_dash = false
	dash_timer = dash_duration
	is_dash_attacking = false
	
	var direction = Input.get_axis("move_left", "move_right")
	if direction != 0:
		dash_direction = -1 if direction < 0 else 1
	else:
		dash_direction = -1 if animated_sprite.flip_h else 1
	
	if animated_sprite:
		animated_sprite.flip_h = dash_direction < 0
		animated_sprite.stop()
		animated_sprite.frame = 0
		animated_sprite.speed_scale = 1.5
		animated_sprite.play("dash")

func perform_dash(delta: float) -> void:
	if dash_timer > 0:
		velocity.x = dash_direction * dash_speed * 2
		
		if not is_on_floor():
			velocity.y = min(velocity.y, 0)
			
		dash_timer -= delta
		
		if Input.is_action_just_pressed("attack"):
			is_dash_attacking = true
		
		if animated_sprite:
			animated_sprite.play("dash")
	else:
		finish_dash()

func finish_dash() -> void:
	is_dashing = false
	dash_cooldown_timer = dash_cooldown
	can_dash = true
	
	if animated_sprite:
		animated_sprite.speed_scale = 1.0
		
		if is_dash_attacking:
			start_dash_attack()
		else:
			if is_on_floor():
				var direction = Input.get_axis("move_left", "move_right")
				if direction != 0:
					animated_sprite.play("run")
					velocity.x *= 0.5
				else:
					velocity.x = 0
					animated_sprite.play("idle")
			else:
				animated_sprite.play("jump")
				velocity.x *= 0.5

func start_dash_attack() -> void:
	is_attacking = true
	current_attack_combo = 0
	is_in_dash_attack_recovery = true
	dash_attack_recovery_timer = dash_attack_recovery_time
	
	if animated_sprite:
		animated_sprite.flip_h = dash_direction < 0
		animated_sprite.play("attack1")
		
		if attack_area:
			var attack_position = Vector2(50 if dash_direction > 0 else -50, 0)
			attack_area.position = attack_position
			attack_area.monitoring = true
	
	velocity.x = abs(velocity.x) * dash_direction * 0.7

func apply_dash_attack_damage() -> void:
	if attack_area:
		var areas = attack_area.get_overlapping_areas()
		for area in areas:
			var body = area.get_parent()
			if body.is_in_group("enemy") and body.has_method("take_damage") and not hit_enemies.has(body):
				hit_enemies.append(body)
				
				var damage = attack1_power * 1.5
				var knockback_force = 150.0
				var knockback_direction = Vector2.RIGHT if dash_direction > 0 else Vector2.LEFT
				
				if body.has_method("apply_knockback"):
					body.apply_knockback(knockback_direction * knockback_force)
				
				body.take_damage(damage)
#endregion

#region 相機系統
func _handle_camera_mode(delta: float) -> bool:
	if Input.is_action_just_pressed("camera_mode"):
		is_camera_mode = !is_camera_mode
		if is_camera_mode:
			velocity = Vector2.ZERO
			previous_zoom = camera.zoom
			_zoom_camera(camera_mode_zoom)
			Engine.time_scale = CAMERA_MODE_TIME_SCALE
		else:
			camera.position = Vector2.ZERO
			_zoom_camera(previous_zoom)
			Engine.time_scale = NORMAL_TIME_SCALE
	
	if is_camera_mode:
		_handle_camera_movement(delta)
		return true
	return false

func _handle_camera_movement(delta: float) -> void:
	var camera_movement = Vector2.ZERO
	
	if Input.is_action_pressed("jump"):
		camera_movement.y -= 1
	if Input.is_action_pressed("dash"):
		camera_movement.y += 1
	if Input.is_action_pressed("move_left"):
		camera_movement.x -= 1
	if Input.is_action_pressed("move_right"):
		camera_movement.x += 1
	
	if camera_movement != Vector2.ZERO:
		camera_movement = camera_movement.normalized()
		var real_delta = delta / Engine.time_scale
		camera.position += camera_movement * camera_move_speed * real_delta

func _handle_camera_zoom(event: InputEventMouseButton) -> void:
	var actual_zoom_step = ZOOM_STEP / Engine.time_scale
	
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			_adjust_camera_zoom(actual_zoom_step)
		MOUSE_BUTTON_WHEEL_DOWN:
			_adjust_camera_zoom(-actual_zoom_step)

func _zoom_camera(target_zoom: Vector2, force_immediate: bool = false) -> void:
	if camera_zoom_tween and camera_zoom_tween.is_valid():
		if force_immediate:
			camera.zoom = target_zoom
		camera_zoom_tween.kill()
	
	camera_zoom_tween = create_tween()
	camera_zoom_tween.set_trans(Tween.TRANS_SINE)
	camera_zoom_tween.set_ease(Tween.EASE_IN_OUT)
	camera_zoom_tween.set_parallel(true)
	
	camera_zoom_tween.tween_property(
		camera,
		"zoom",
		target_zoom,
		ZOOM_DURATION
	)

func _adjust_camera_zoom(delta_zoom: float) -> void:
	if not camera:
		return
	
	var new_zoom = clamp(
		camera.zoom.x + delta_zoom,
		MIN_ZOOM,
		MAX_ZOOM
	)
	
	_zoom_camera(Vector2(new_zoom, new_zoom), true)
#endregion

#region 戰鬥系統
func _handle_combat(delta: float) -> void:
	_handle_attack_input(delta)
	_handle_dash(delta)
	
	if Input.is_action_just_pressed("special_attack") and can_special_attack:
		start_special_attack()
	
	if is_attacking or is_jump_attacking:
		perform_attack()
	elif is_special_attacking:
		perform_special_attack()

func take_damage(amount: float) -> void:
	if is_invincible or is_dashing:
		return
		
	current_health -= amount
	health_changed.emit(current_health)
	
	if current_health <= 0:
		die()
	else:
		if animated_sprite:
			animated_sprite.play("hurt")
		set_invincible(invincible_duration)

func die() -> void:
	if current_state == "death":
		return
		
	velocity = Vector2.ZERO
	current_state = "death"
	
	set_physics_process(false)
	set_process_input(false)
	set_collision_layer_value(2, false)
	
	if animated_sprite:
		animated_sprite.play("death")
	
	died.emit()

func set_invincible(duration: float) -> void:
	is_invincible = true
	invincible_timer = duration
	set_collision_layer_value(2, false)
	modulate.a = 0.5

func _handle_collision() -> void:
	var previous_position = global_position
	move_and_slide()
	
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider is CharacterBody2D and collider.is_in_group("enemy"):
			take_damage(collider.damage)
			global_position = previous_position
			break

func _handle_invincibility(delta: float) -> void:
	if is_invincible:
		invincible_timer -= delta
		blink_timer += delta
		if blink_timer >= BLINK_INTERVAL:
			blink_timer = 0.0
			modulate.a = 1.0 if modulate.a < 1.0 else 0.5
		
		if invincible_timer <= 0:
			is_invincible = false
			set_collision_layer_value(2, true)
			modulate.a = 1.0
#endregion

#region 動畫系統
func _update_animation() -> void:
	if not animated_sprite:
		return
	
	if is_attacking or is_jump_attacking or is_special_attacking or is_dashing or is_hurt:
		return
	
	if is_on_floor():
		var direction = Input.get_axis("move_left", "move_right")
		if abs(direction) > 0:
			animated_sprite.play("run")
		else:
			animated_sprite.play("idle")

func _force_update_animation() -> void:
	if not animated_sprite:
		return
	
	if is_attacking or is_special_attacking or is_dashing or is_hurt:
		return
	
	if is_on_floor():
		var direction = Input.get_axis("move_left", "move_right")
		if abs(direction) > 0:
			animated_sprite.play("run")
		else:
			animated_sprite.play("idle")
	else:
		animated_sprite.play("jump")
#endregion

#region 信號處理
func _on_ani_sprite_2d_animation_finished() -> void:
	if not animated_sprite:
		return
	
	match animated_sprite.animation:
		"hurt":
			reset_states()
			_force_update_animation()
		"death":
			set_process(false)
			visible = false
		"special_attack":
			_finish_special_attack()
		_:
			if animated_sprite.animation.begins_with("attack"):
				finish_attack()

func _on_ani_sprite_2d_frame_changed() -> void:
	if not animated_sprite:
		return
		
	if is_special_attacking:
		var current_frame = animated_sprite.frame
		if current_frame >= 5 and current_frame <= 7 and current_frame != last_special_attack_frame:
			if special_attack_area:
				special_attack_area.monitoring = true
			_apply_special_attack_damage()
			last_special_attack_frame = current_frame
		else:
			if special_attack_area:
				special_attack_area.monitoring = false
	
	elif is_attacking and animated_sprite.frame == 2:
		apply_damage()

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.get_parent().is_in_group("enemy"):
		take_damage(area.get_parent().damage)

func _on_effect_finished() -> void:
	pass
#endregion

#region 輔助函數
func reset_states(keep_movement: bool = false) -> void:
	var current_animation = ""
	if animated_sprite:
		current_animation = animated_sprite.animation
	
	if current_animation in ["hurt", "death"]:
		return
	
	is_attacking = false
	is_jump_attacking = false
	is_special_attacking = false
	is_dash_attacking = false
	is_hurt = false
	
	current_attack_combo = 0
	combo_buffer_timer = 0
	can_continue_combo = false
	attack_press_timer = 0
	hit_enemies.clear()
	
	special_attack_request = false
	last_special_attack_frame = -1
	
	if attack_area:
		attack_area.monitoring = false
	if special_attack_area:
		special_attack_area.monitoring = false
	
	if not keep_movement:
		is_jumping = false
		jump_count = 0
		_update_idle_animation()

func _update_idle_animation() -> void:
	if not animated_sprite:
		return
		
	var current_animation = animated_sprite.animation
	
	if current_animation in ["hurt", "death", "special_attack", "dash"]:
		return
	
	if is_attacking or is_jump_attacking:
		return
	
	var direction = Input.get_axis("move_left", "move_right")
	if is_on_floor():
		animated_sprite.play("run" if direction != 0 else "idle")
	else:
		animated_sprite.play("jump")

func _update_timers(delta: float) -> void:
	_update_combo_timers(delta)
	_update_cooldowns(delta)
	
	if is_in_dash_attack_recovery:
		dash_attack_recovery_timer -= delta
		if dash_attack_recovery_timer <= 0:
			is_in_dash_attack_recovery = false
			dash_attack_recovery_timer = 0

func _update_combo_timers(delta: float) -> void:
	if combo_buffer_timer > 0:
		combo_buffer_timer -= delta
		if combo_buffer_timer <= 0:
			can_continue_combo = false

func _update_cooldowns(delta: float) -> void:
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
	
	if defense_cooldown_timer > 0:
		defense_cooldown_timer -= delta
	
	if special_attack_timer > 0:
		special_attack_timer -= delta

func _verify_attack_state() -> void:
	if animated_sprite and not (
		animated_sprite.animation.begins_with("attack") or 
		animated_sprite.animation == "special_attack" or 
		animated_sprite.animation == "hurt"
	):
		if is_attacking or is_special_attacking:
			reset_states()

func _interrupt_attack() -> void:
	is_attacking = false
	is_jump_attacking = false
	current_attack_combo = 0
	combo_buffer_timer = 0
	can_continue_combo = false
	if animated_sprite:
		animated_sprite.stop()

func apply_damage() -> void:
	if attack_area:
		var areas = attack_area.get_overlapping_areas()
		for area in areas:
			var body = area.get_parent()
			if body.is_in_group("enemy") and body.has_method("take_damage") and not hit_enemies.has(body):
				hit_enemies.append(body)
				
				var damage = get_attack_damage()
				var knockback_force = get_knockback_force()
				var knockback_direction = get_knockback_direction()
				
				if body.has_method("apply_knockback"):
					body.apply_knockback(knockback_direction * knockback_force)
				
				body.take_damage(damage)

func _update_states() -> void:
	# 更新所有狀態
	if is_on_floor():
		is_jumping = false
		jump_count = 0
	
	# 更新衝刺狀態
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= get_physics_process_delta_time()
		if dash_cooldown_timer <= 0:
			can_dash = true
	
	# 更新特殊攻擊狀態
	if special_attack_timer > 0:
		special_attack_timer -= get_physics_process_delta_time()
		if special_attack_timer <= 0:
			can_special_attack = true

func _verify_states() -> void:
	# 驗證所有狀態的合法性
	if is_on_floor():
		if is_jumping:
			is_jumping = false
			jump_count = 0
	
	if is_dashing and dash_timer <= 0:
		is_dashing = false
		can_dash = false
		dash_cooldown_timer = dash_cooldown

func _handle_state_transitions() -> void:
	# 處理狀態轉換
	var previous_state = current_state
	
	if is_hurt:
		current_state = "hurt"
	elif is_dashing:
		current_state = "dash"
	elif is_attacking:
		current_state = "attack"
	elif is_special_attacking:
		current_state = "special_attack"
	elif not is_on_floor():
		current_state = "jump"
	elif abs(velocity.x) > 0:
		current_state = "run"
	else:
		current_state = "idle"
	
	if previous_state != current_state:
		_on_state_changed(previous_state, current_state)

func _on_state_changed(old_state: String, new_state: String) -> void:
	# 處理狀態改變時的邏輯
	match new_state:
		"hurt":
			_handle_hurt_state()
		"dash":
			_handle_dash_state()
		"attack":
			_handle_attack_state()
		"special_attack":
			_handle_special_attack_state()

func _handle_hurt_state() -> void:
	velocity = Vector2.ZERO
	is_attacking = false
	is_special_attacking = false
	is_dashing = false

func _handle_dash_state() -> void:
	is_attacking = false
	is_special_attacking = false

func _handle_attack_state() -> void:
	is_special_attacking = false

func _handle_special_attack_state() -> void:
	is_attacking = false

func get_current_state() -> String:
	return current_state

func is_action_locked() -> bool:
	return is_hurt or is_dashing or is_attacking or is_special_attacking

func can_perform_action() -> bool:
	return not is_action_locked()

func reset_action_states() -> void:
	is_attacking = false
	is_special_attacking = false
	is_dashing = false
	is_hurt = false
	current_attack_combo = 0
	hit_enemies.clear()

func handle_death() -> void:
	if current_state == "death":
		return
	
	current_state = "death"
	velocity = Vector2.ZERO
	reset_action_states()
	set_physics_process(false)
	set_process_input(false)
	
	if animated_sprite:
		animated_sprite.play("death")
	
	died.emit()

func revive() -> void:
	if current_state != "death":
		return
	
	current_state = "idle"
	current_health = max_health
	reset_action_states()
	set_physics_process(true)
	set_process_input(true)
	set_collision_layer_value(2, true)
	modulate.a = 1.0
	
	if animated_sprite:
		animated_sprite.play("idle")
	
	health_changed.emit(current_health)
#endregion


func _on_effect_manager_effect_finished() -> void:
	pass # Replace with function body.


func _on_double_jump_effect_animation_finished() -> void:
	pass # Replace with function body.
