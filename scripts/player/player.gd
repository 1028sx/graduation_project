extends CharacterBody2D

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
@export var max_health = 100
@export var defense_duration = 0.5
@export var defense_cooldown = 1.0
@export var defense_strength = 0.5

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
var shuriken_scene = preload("res://scenes/player/shuriken.tscn")
#endregion

#region 狀態變量
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var current_state = "idle"
var current_health = max_health

# 移動相關
var is_jumping = false
var jump_count = 0
var jump_buffer_timer = 0.0
var coyote_timer = 0.0
var was_on_floor = false

# 衝刺相關
var is_dashing = false
var can_dash = true
var dash_timer = 0.0
var dash_cooldown_timer = 0.0
var is_dash_attacking = false
var dash_attack_recovery_timer = 0.0
var is_in_dash_attack_recovery = false

# 攻擊相關
var is_attacking = false
var current_attack_combo = 0
var is_attack_pressed = false
var can_continue_combo = false
var attack_press_timer = 0.0
var combo_buffer_timer = 0.0

# 特殊攻擊相關
var is_special_attacking = false
var last_special_attack_frame = -1
var special_attack_timer = 0.0
var special_attack_request = false

# 其他戰鬥狀態
var is_defending = false
var is_jump_attacking = false
var defense_timer = 0.0
var defense_cooldown_timer = 0.0

# 技能解鎖狀態
var can_special_attack: bool = false

# 添加衝��量
var dash_direction = 1  # 1 表示右，-1 表示左

# 添加新變量
var hit_enemies = []  # 用於記錄已經被當前攻擊打中的敵人
#endregion

#region 信號
signal health_changed(new_health)
signal died
#endregion
#region 初始化函數
func _ready():
	_initialize_player()
	_setup_collisions()
	_connect_signals()
	_initialize_skills()

func _initialize_player():
	add_to_group("player")
	current_health = max_health

func _setup_collisions():
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

func _initialize_skills():
	can_special_attack = true
	is_special_attacking = false
	
	if effect_manager:
		effect_manager.visible = false
		effect_manager.modulate.a = 0.8

func _connect_signals():
	if animated_sprite:
		_disconnect_all_signals()
		animated_sprite.animation_finished.connect(_on_ani_sprite_2d_animation_finished)
		animated_sprite.frame_changed.connect(_on_ani_sprite_2d_frame_changed)
	
	var hitbox = $Hitbox
	if hitbox and not hitbox.area_entered.is_connected(_on_hitbox_area_entered):
		hitbox.area_entered.connect(_on_hitbox_area_entered)
	
	if effect_manager and not effect_manager.effect_finished.is_connected(_on_effect_finished):
		effect_manager.effect_finished.connect(_on_effect_finished)

func _disconnect_all_signals():
	if animated_sprite:
		if animated_sprite.animation_finished.is_connected(_on_ani_sprite_2d_animation_finished):
			animated_sprite.animation_finished.disconnect(_on_ani_sprite_2d_animation_finished)
		if animated_sprite.frame_changed.is_connected(_on_ani_sprite_2d_frame_changed):
			animated_sprite.frame_changed.disconnect(_on_ani_sprite_2d_frame_changed)
#endregion

#region 主要更新循環
func _physics_process(delta):
	_handle_gravity(delta)
	_handle_movement(delta)
	_handle_combat(delta)
	_handle_collision()
	_update_timers(delta)
	_handle_special_attack_request()

func _process(delta):
	_update_cooldowns(delta)
#endregion

#region 攻擊系統        // 移到前面
func _handle_attack_input(delta):
	if Input.is_action_just_pressed("attack"):
		start_attack()  # 使用攻擊系統區域的 start_attack()
	elif Input.is_action_pressed("attack"):
		_continue_attack(delta)
	elif Input.is_action_just_released("attack"):
		_end_attack()
	
	if combo_buffer_timer > 0:
		combo_buffer_timer -= delta
		if combo_buffer_timer <= 0:
			can_continue_combo = false
			# 移除 current_attack_combo = 0

func apply_damage():
	# 只控制攻擊區域的啟用
	if is_attacking and animated_sprite.frame == 2:
		if attack_area:
			attack_area.monitoring = true
	else:
		if attack_area:
			attack_area.monitoring = false
#endregion

#region 特殊攻擊系統
func start_special_attack():
	# 移除狀態檢查，直接設置請求
	special_attack_request = true

func _start_special_attack():
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

func _finish_special_attack():
	is_special_attacking = false
	if special_attack_area:
		special_attack_area.monitoring = false
	last_special_attack_frame = -1
	
	if is_on_floor():
		animated_sprite.play("idle")
	else:
		animated_sprite.play("jump")

func _handle_special_attack_request():
	if special_attack_request:
		_start_special_attack()
		special_attack_request = false

func perform_special_attack():
	if not animated_sprite:
		return
		
	# 只控制攻擊區域的啟用/禁用
	var current_frame = animated_sprite.frame
	if current_frame >= 6 and current_frame <= 8 and current_frame != last_special_attack_frame:
		if special_attack_area:
			special_attack_area.monitoring = true
		last_special_attack_frame = current_frame
	else:
		if special_attack_area:
			special_attack_area.monitoring = false

func _apply_special_attack_damage():
	if special_attack_area and special_attack_area.monitoring:
		var areas = special_attack_area.get_overlapping_areas()
		for area in areas:
			var body = area.get_parent()
			if body.is_in_group("enemy") and body.has_method("take_damage"):
				# 根據當前幀決定傷害值
				var damage = 0
				match animated_sprite.frame:
					5: damage = special_attack_power_1
					6: damage = special_attack_power_2
					7: damage = special_attack_power_3
				
				# 向退
				var knockback_direction = Vector2(0, -1)
				if body.has_method("apply_knockback"):
					body.apply_knockback(knockback_direction * 300)
				
				body.take_damage(damage)
#endregion

#region 移動系統
func _handle_gravity(delta):
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		_handle_landing()

func _handle_landing():
	jump_count = 0
	if is_jumping:
		is_jumping = false
		if not is_special_attacking:
			reset_states()
			_update_landing_animation()

func _update_landing_animation():
	if animated_sprite and not is_attacking and not is_special_attacking and not is_dashing:
		var direction = Input.get_axis("move_left", "move_right")
		if direction != 0:
			animated_sprite.play("run")  # 如果有移動輸入，播放跑步動畫
		else:
			animated_sprite.play("idle")  # 否則播放閒置動畫

func _handle_movement(delta):
	_update_movement_timers(delta)
	_process_movement_input()
	_update_movement_state()

func _update_movement_timers(delta):
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta
	if coyote_timer > 0:
		coyote_timer -= delta

func _process_movement_input():
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

func _update_movement_state():
	if is_on_floor():
		coyote_timer = coyote_time
	elif was_on_floor and not is_on_floor():
		coyote_timer = coyote_time
	
	was_on_floor = is_on_floor()

	if Input.is_action_just_pressed("dash") and can_dash and dash_cooldown_timer <= 0:
		_start_dash()

func _apply_movement(direction):
	var current_speed = speed
	if is_attacking and is_on_floor() and not is_jump_attacking and not is_special_attacking:
		current_speed *= attack_move_speed_multiplier
	velocity.x = direction * current_speed
	
	# 修改動���播放條件
	if animated_sprite and not is_attacking and not is_special_attacking and not is_dashing:
		animated_sprite.flip_h = direction < 0
		if is_on_floor() and not is_defending:
			animated_sprite.play("run")  # 確保在地面移動時播放跑步動畫

func _handle_idle():
	if not is_dashing:
		velocity.x = move_toward(velocity.x, 0, speed)
		# 修改動畫播放條件
		if abs(velocity.x) < 1 and is_on_floor() and not is_attacking and not is_defending and not is_special_attacking and not is_dashing:
			animated_sprite.play("idle")  # 只在完全停止時播放閒置動畫

func jump():
	velocity.y = jump_velocity
	is_jumping = true
	jump_count += 1
	if animated_sprite:
		animated_sprite.play("jump")

func _perform_double_jump():
	velocity.y = jump_velocity * 0.8
	jump_count += 1
	if animated_sprite:
		animated_sprite.play("jump")
#endregion

#region 衝刺系統
func _handle_dash(delta):
	if is_dashing:
		perform_dash(delta)

func _start_dash():
	if is_attacking:
		_interrupt_attack()
		
	is_dashing = true
	can_dash = false
	dash_timer = dash_duration
	
	# 在衝刺開始時記錄方向
	var direction = Input.get_axis("move_left", "move_right")
	if direction != 0:
		dash_direction = -1 if direction < 0 else 1
	# 如果沒有移動輸入，使用當前朝向
	else:
		dash_direction = -1 if animated_sprite.flip_h else 1
	
	if animated_sprite:
		# 強制設置動畫朝向為衝刺方向
		animated_sprite.flip_h = dash_direction < 0
		animated_sprite.stop()
		animated_sprite.frame = 0
		animated_sprite.speed_scale = 1.5
		animated_sprite.play("dash")

func perform_dash(delta):
	if dash_timer > 0:
		# 使用記錄的衝刺方向
		velocity.x = dash_direction * dash_speed * 2
		
		if not is_on_floor():
			velocity.y = min(velocity.y, 0)
			
		dash_timer -= delta
		
		if Input.is_action_just_pressed("attack"):
			is_dash_attacking = true
		
		if animated_sprite and animated_sprite.animation != "dash":
			# 確保動畫朝向與衝刺方向一致
			animated_sprite.flip_h = dash_direction < 0
			animated_sprite.play("dash")
	else:
		finish_dash()

func finish_dash():
	is_dashing = false
	dash_cooldown_timer = dash_cooldown
	can_dash = true
	
	if animated_sprite:
		animated_sprite.speed_scale = 1.0
		
		if is_dash_attacking or Input.is_action_pressed("attack"):
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
#endregion

#region 生命系統
func take_damage(amount):
	if not is_dashing:  # 衝刺時無敵
		current_health -= amount
		
		health_changed.emit(current_health)
		if current_health <= 0:
			die()
		else:
			if animated_sprite:
				animated_sprite.play("hurt")
			set_invincible(0.5)

func die():
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

func set_invincible(duration):
	set_collision_layer_value(2, false)
	modulate.a = 0.5
	await get_tree().create_timer(duration).timeout
	set_collision_layer_value(2, true)
	modulate.a = 1.0
#endregion

#region 信號處理
func _on_ani_sprite_2d_animation_finished() -> void:
	if not animated_sprite:
		return
		
	match animated_sprite.animation:
		"hurt":
			reset_states()
			animated_sprite.play("idle")
		"death":
			# 死亡動畫播放完，完全禁用角色
			set_process(false)
			visible = false  # 可選：隱藏角色
			# 這裡可以添加遊戲結束的邏輯
			pass
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
			_apply_special_attack_damage()  # 添加這行
			last_special_attack_frame = current_frame
		else:
			if special_attack_area:
				special_attack_area.monitoring = false
	
	elif is_attacking and animated_sprite.frame == 2:
		apply_damage()

func _on_hitbox_area_entered(area):
	if area.get_parent().is_in_group("enemy"):
		take_damage(area.get_parent().damage)

func _on_effect_finished():
	pass
#endregion

#region 輔助函數
func reset_states(keep_movement: bool = false):
	is_jumping = false
	is_jump_attacking = false
	is_attacking = false
	# 移除 current_attack_combo = 0
	combo_buffer_timer = 0
	can_continue_combo = false
	
	if not keep_movement:
		jump_count = 0
		_update_idle_animation()

func _update_idle_animation():
	# 修改動畫更新條件，避免打斷特殊攻擊
	if animated_sprite and not animated_sprite.animation in ["hurt", "death", "special_attack"]:
		var direction = Input.get_axis("move_left", "move_right")
		animated_sprite.play("run" if direction != 0 else "idle")

func _handle_collision():
	var previous_position = global_position
	move_and_slide()
	
	# 檢查所有碰撞
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider is CharacterBody2D and collider.is_in_group("enemy"):
			# 如果碰到敵人，玩家受到傷
			take_damage(collider.damage)
			# 將玩家推回之前的位置
			global_position = previous_position
			break

func _update_timers(delta):
	_update_combo_timers(delta)
	_update_cooldowns(delta)
	
	if is_in_dash_attack_recovery:
		dash_attack_recovery_timer -= delta
		if dash_attack_recovery_timer <= 0:
			is_in_dash_attack_recovery = false
			dash_attack_recovery_timer = 0

func _update_combo_timers(delta):
	if combo_buffer_timer > 0:
		combo_buffer_timer -= delta
		if combo_buffer_timer <= 0:
			can_continue_combo = false
			# 移除這裡的 current_attack_combo = 0

func _update_cooldowns(delta):
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
	
	if defense_cooldown_timer > 0:
		defense_cooldown_timer -= delta
	
	if special_attack_timer > 0:
		special_attack_timer -= delta
#endregion

#region 攻擊系統
func _apply_normal_attack_damage():
	if attack_area:
		var areas = attack_area.get_overlapping_areas()
		for area in areas:
			var body = area.get_parent()
			# 檢查是否已經打中過這個敵人
			if body.is_in_group("enemy") and body.has_method("take_damage") and not hit_enemies.has(body):
				hit_enemies.append(body)  # 記錄已打中的敵人
				
				var damage = attack1_power
				var knockback_force = 100.0
				
				match current_attack_combo:
					1: 
						damage = attack2_power
						knockback_force = 120.0
					2: 
						damage = attack3_power
						knockback_force = 150.0
				
				if is_dash_attacking:
					damage = float(damage) * 1.5
					knockback_force *= 1.5
				
				var knockback_direction = Vector2.RIGHT
				if animated_sprite.flip_h:
					knockback_direction = Vector2.LEFT
				
				if body.has_method("apply_knockback"):
					body.apply_knockback(knockback_direction * knockback_force)
				
				body.take_damage(damage)

func perform_attack():
	if not animated_sprite:
		return
		
	# 在整個攻擊動畫中保持攻擊區��啟用
	if attack_area:
		attack_area.monitoring = true
		_apply_normal_attack_damage()  # 添加這行

func start_attack():
	if is_in_dash_attack_recovery:
		return
		
	is_attacking = true
	attack_press_timer = 0
	
	if can_continue_combo and combo_buffer_timer > 0:
		if current_attack_combo < 2:
			current_attack_combo += 1
		else:
			current_attack_combo = 0
	
	if animated_sprite:
		# 獲取滑鼠位置並計算方向
		var mouse_pos = get_global_mouse_position()
		var direction_to_mouse = (mouse_pos - global_position).normalized()
		animated_sprite.flip_h = direction_to_mouse.x < 0
		
		var attack_num = current_attack_combo + 1
		animated_sprite.play("attack" + str(attack_num))
		
		if attack_area:
			# 根據滑鼠方向設置攻擊區域的位置
			var attack_position = Vector2(50 if not animated_sprite.flip_h else -50, 0)
			attack_area.position = attack_position
		
	if attack_area:
		attack_area.monitoring = true

func finish_attack():
	is_attacking = false
	is_jump_attacking = false
	hit_enemies.clear()  # 清空已打中的敵人列表
	
	if attack_area:
		attack_area.monitoring = false
	
	if not is_in_dash_attack_recovery:
		if is_on_floor():
			var direction = Input.get_axis("move_left", "move_right")
			if direction != 0:
				animated_sprite.play("run")
			else:
				animated_sprite.play("idle")
		else:
			is_jumping = true
			animated_sprite.play("jump")
		
		can_continue_combo = true
		combo_buffer_timer = combo_buffer_time

func start_dash_attack():
	is_attacking = true
	is_dash_attacking = false
	current_attack_combo = 0
	is_in_dash_attack_recovery = true
	dash_attack_recovery_timer = dash_attack_recovery_time
	
	if animated_sprite:
		# 強制設置動畫朝向為衝刺方向
		animated_sprite.flip_h = dash_direction < 0
		animated_sprite.play("attack1")
		
		if attack_area:
			# 根據衝刺方向設置攻擊區域
			var attack_position = Vector2(50 if dash_direction > 0 else -50, 0)
			attack_area.position = attack_position
	
	# 使用記錄的衝刺方向
	velocity.x = abs(velocity.x) * dash_direction * 0.7

func _interrupt_attack():
	is_attacking = false
	is_jump_attacking = false
	current_attack_combo = 0
	combo_buffer_timer = 0
	can_continue_combo = false
	if animated_sprite:
		animated_sprite.stop()

func _continue_attack(delta):
	attack_press_timer += delta
	if attack_press_timer >= attack_hold_threshold and not is_attacking:
		start_attack()

func _end_attack():
	is_attack_pressed = false
	attack_press_timer = 0
#endregion

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

#region 戰鬥系統
func _handle_combat(delta):
	_handle_attack_input(delta)
	_handle_dash(delta)
	
	if Input.is_action_just_pressed("special_attack") and can_special_attack:
		start_special_attack()
	
	if is_attacking or is_jump_attacking:
		perform_attack()
	elif is_special_attacking:
		perform_special_attack()
#endregion
