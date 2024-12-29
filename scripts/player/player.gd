extends CharacterBody2D

#region 常量定義
const NORMAL_TIME_SCALE = 1.0
const CAMERA_MODE_TIME_SCALE = 0.1
const MIN_ZOOM = 0.5
const MAX_ZOOM = 2.0
const ZOOM_STEP = 0.01
const ZOOM_DURATION = 0.05
const BLINK_INTERVAL = 0.1
const JUMP_VELOCITY = -450.0
const CHARGE_EFFECT_INTERVAL = 2.0  # 每2秒播放一次
#endregion

#region 導出屬性
@export_group("Movement")
@export var speed = 300.0
@export var jump_velocity = -450.0
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
@export var invincible_duration = 0.5

@export_group("Attack")
@export var attack_move_speed_multiplier = 0.1
@export var attack_combo_window = 0.5
@export var attack_hold_threshold = 0.15
@export var combo_buffer_time = 0.3

@export_group("Special Attack")
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
@onready var jump_impact_area = $JumpImpactArea

var shuriken_scene = preload("res://scenes/player/shuriken.tscn")
var wave_scene = preload("res://scenes/player/dash_wave.tscn")
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

# 復活機制
var has_revive_heart := true

# 金幣系統
var gold := 0

# 效果系統
var active_effects := {}

# 擊退相關
var knockback_velocity := Vector2.ZERO

# 能力相關
var has_dash_wave := false
var has_jump_impact := false

# 蓄力攻擊相關變量
var is_charging := false
var charge_time := 0.0
var max_charge_bonus := 1.0
var current_charge_rate := 0.15
var charge_damage_multiplier := 1.0
var charge_start_timer := 0.0
var is_charge_ready := false
var saved_charge_multiplier := 1.0

# 將常量改為變量
var base_attack_damage := 50.0
var base_special_attack_damage := 30.0
var current_attack_damage: float
var current_special_attack_damage: float

# 添加疾風相關變量
var swift_dash_multiplier := 1.25  # 衝刺速度增幅
var swift_dash_cooldown_reduction := 0.5  # 衝刺冷卻時間減少比例
var swift_dash_attack_count := 0  # 追蹤衝刺後的攻擊次數
var swift_dash_attack_limit := 3  # 最大加速攻擊次數
var swift_dash_attack_speed_bonus := 1.5  # 攻擊速度提升50%

# 修改敏捷效果相關變量
var agile_dash_attack_count := 0  # 追蹤衝刺後的攻擊次數
var agile_dash_attack_limit := 3  # 最大加速攻擊次數
var agile_dash_attack_speed_bonus := 2.0  # 攻擊速度提升100% (原本是1.5，即50%)

# 修改憤怒效果相關變量
var rage_stack := 0  # 當前憤怒疊加層數
var rage_stack_limit := 5  # 最大疊加層數
var rage_damage_bonus := 0.1  # 每層增加10%攻擊力

# 信號
signal health_changed(new_health)
signal died
signal gold_changed(new_gold: int)

# 添加靈巧效果相關變量
var agile_perfect_dodge := false  # 是否處於完美迴避狀態
var agile_dodge_window := 0.2  # 完美迴避的判定窗口（秒）
var agile_dodge_timer := 0.0  # 完美迴避計時器
var agile_damage_multiplier := 2.0  # 完美迴避後的傷害倍率

# 修改專注效果相關變量
var focus_stack := 0  # 當前專注層數
var focus_stack_limit := 5  # 最大疊加層數
var focus_damage_bonus := 0.05  # 每層增加5%傷害（原本是20%）
var focus_target: Node = null  # 當前專注的目標
var focus_reset_timer := 0.0  # 重置計時器
var focus_reset_time := 10.0  # 多久不攻擊目標後重置（原本是2秒）

# 在 #region 狀態變量 區塊添加
var charge_effect_timer := 0.0
var has_played_max_charge_effect := false
var has_played_first_effect := false
var has_played_second_effect := false
var has_ice_freeze := false
var ice_freeze_cooldown := 5.0  # 冰結冷卻時間
var ice_freeze_timer := 0.0  # 冰結計時器
var ice_freeze_duration := 2.0  # 冰結持續時間
#endregion

#region 生命週期函數
func _ready() -> void:
	_initialize_player()
	_setup_collisions()
	_connect_signals()
	_initialize_skills()
	# 在初始化時設置當前傷害值
	current_attack_damage = base_attack_damage
	current_special_attack_damage = base_special_attack_damage
	# 初始化效果字典
	active_effects = {}
	emit_signal("effect_changed", active_effects)

func _physics_process(delta: float) -> void:
	if _handle_camera_mode(delta):
		return
		
	# 更新冰結計時器
	if ice_freeze_timer > 0:
		ice_freeze_timer -= delta
	
	# 處理專注效果計時器
	if focus_target and focus_reset_timer > 0:
		focus_reset_timer -= delta
		if focus_reset_timer <= 0:
			_reset_focus()
	
	if agile_dodge_timer > 0:
		agile_dodge_timer -= delta
		if agile_dodge_timer <= 0:
			agile_perfect_dodge = false
	
	_verify_attack_state()
	_handle_gravity(delta)
	_handle_movement(delta)
	_handle_combat(delta)
	_handle_collision()
	_update_timers(delta)
	_handle_special_attack_request()
	_update_animation()
	_handle_invincibility(delta)
	_handle_charge_state(delta)

func _input(event: InputEvent) -> void:
	if is_camera_mode and event is InputEventMouseButton:
		_handle_camera_zoom(event)
#endregion

#region 初始化系統
func _initialize_player() -> void:
	add_to_group("player")
	current_health = max_health
	gold = 0  # 初始化金幣為0

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
		special_attack_area.collision_layer = 0
		special_attack_area.collision_mask = 0
		
		special_attack_area.set_collision_layer_value(4, true)
		special_attack_area.set_collision_mask_value(3, true)

	if jump_impact_area:
		jump_impact_area.collision_layer = 0
		jump_impact_area.collision_mask = 0
		jump_impact_area.set_collision_mask_value(3, true)
		jump_impact_area.monitoring = false
		jump_impact_area.monitorable = true

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
	var current_speed = speed * (1+((get_berserker_multiplier()-1)/2))
	
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
	
	# 添加跳躍衝擊檢查
	if has_jump_impact:
		_create_jump_impact()

func _perform_double_jump() -> void:
	velocity.y = jump_velocity * 0.8
	jump_count += 1
	if animated_sprite and not is_attacking:
		animated_sprite.play("jump")
		animated_sprite.frame = 0
	
	# 添加跳躍衝擊檢查
	if has_jump_impact:
		_create_jump_impact(true)  # 傳入 true 表示這是二段跳
	else:
		# 如果沒有跳躍衝擊能力，只播放普通的二段跳特效
		if effect_manager:
			effect_manager.play_double_jump(animated_sprite.flip_h)
#endregion

#region 攻擊系統
func _handle_attack_input(delta: float) -> void:
	if Input.is_action_just_pressed("attack"):
		if not is_hurt:  # 只在不是受傷狀態時才開始新的攻擊
			# 檢查是否可以使用冰結攻擊
			if has_ice_freeze and ice_freeze_timer <= 0 and Input.is_action_pressed("special"):
				start_ice_freeze_attack()
			else:
				start_attack()
	elif Input.is_action_pressed("attack"):
		if not is_hurt:  # 只在不是受傷狀態時才繼續攻擊
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
	
	# 檢查是否有敏捷效果的加速攻擊
	var speed_multiplier = 1.0
	var damage_multiplier = 1.0
	
	# 檢查是否有迴避傷害加成
	if active_effects.has("agile") and agile_perfect_dodge:
		damage_multiplier = agile_damage_multiplier  # 完美迴避的傷害加成
		agile_perfect_dodge = false
	
	if active_effects.has("agile_dash") and agile_dash_attack_count > 0:
		speed_multiplier = agile_dash_attack_speed_bonus
		damage_multiplier *= 1.5  # 使用衝刺攻擊的傷害加成
		agile_dash_attack_count -= 1
	
	# 處理憤怒效果衰退
	if active_effects.has("rage") and rage_stack > 0:
		rage_stack = max(0, rage_stack - 1)
		_update_rage_damage()
	
	# 使用當前的蓄力倍率
	var current_multiplier = charge_damage_multiplier
	if current_multiplier > 1.0:
		damage_multiplier *= current_multiplier
		# 重置蓄力相關變量
		charge_time = 0.0
		charge_damage_multiplier = 1.0
		has_played_max_charge_effect = false
		if effect_manager:
			effect_manager.stop_charge_effect()
	
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
		
		# 立即設置動畫速度
		animated_sprite.speed_scale = speed_multiplier
		
		if attack_area:
			attack_area.scale.x = -1 if animated_sprite.flip_h else 1
	
	if attack_area:
		attack_area.monitoring = true
	
	# 保存傷害加成以供後續使用
	current_attack_damage *= damage_multiplier

func finish_attack() -> void:
	is_attacking = false
	is_jump_attacking = false
	is_dash_attacking = false
	hit_enemies.clear()
	
	# 重置傷害值
	current_attack_damage = base_attack_damage
	
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
	var damage = current_attack_damage
	
	if is_dash_attacking:
		damage = float(damage) * 1.5
	
	# 使用當前的蓄力倍率
	if charge_damage_multiplier > 1.0:
		damage *= charge_damage_multiplier
		# 使用後重置蓄力相關變量
		charge_time = 0.0
		charge_damage_multiplier = 1.0
		has_played_max_charge_effect = false
		if effect_manager:
			effect_manager.stop_charge_effect()
	
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
		
		# 重置蓄力相關狀態
		is_charging = false
		charge_time = 0.0
		charge_damage_multiplier = 1.0
		saved_charge_multiplier = 1.0
		has_played_max_charge_effect = false
		
		if effect_manager:
			effect_manager.stop_charge_effect()

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
				
				# 生命汲取效果
				if active_effects.has("life_steal"):
					current_health = min(current_health + 2, max_health)
					health_changed.emit(current_health)

func apply_damage() -> void:
	if not attack_area:
		return
		
	var areas = attack_area.get_overlapping_areas()
	for area in areas:
		var body = area.get_parent()
		if not body.is_in_group("enemy"):
			continue
			
		if not body.has_method("take_damage"):
			continue
			
		if hit_enemies.has(body):
			continue
			
		hit_enemies.append(body)
		
		# 處理專注效果
		if active_effects.has("focus"):
			if focus_target == body:
				# 命中相同目標，增加層數
				focus_stack = min(focus_stack + 1, focus_stack_limit)
			else:
				# 切換目標，重置層數
				focus_stack = 1  # 改為1，因為這是第一次命中新目標
				focus_target = body
				focus_reset_timer = focus_reset_time
			
			focus_target = body
			focus_reset_timer = focus_reset_time
		
		var damage = get_attack_damage()
		
		# 應用專注效果的傷害加成
		if active_effects.has("focus") and focus_stack > 0:
			var focus_bonus = focus_stack * focus_damage_bonus
			damage *= (1 + focus_bonus)
		
		var knockback_force = get_knockback_force()
		var knockback_direction = get_knockback_direction()
		
		if body.has_method("apply_knockback"):
			body.apply_knockback(knockback_direction * knockback_force)
		
		# 如果是冰結攻擊，則凍結敵人
		if has_ice_freeze and ice_freeze_timer > 0 and body.has_method("freeze"):
			body.freeze(ice_freeze_duration)
		
		body.take_damage(damage)

func apply_attack_damage():
	if not attack_area:
		return
	
	var areas = attack_area.get_overlapping_areas()
	for area in areas:
		var body = area.get_parent()
		if body.is_in_group("enemy") and body.has_method("take_damage"):
			if body.is_in_group("deer_spirit") or body.name.begins_with("DeerSpirit"):  # 檢查組或名稱
				body.take_damage()  # 不帶參數
			else:  # 其他敵人
				var damage = get_attack_damage()
				body.take_damage(damage)  # 帶參數
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
	hit_enemies.clear()  # 清空已命中的敵人列表
	
	if special_attack_area:
		special_attack_area.monitoring = true  # 一開始就開啟 monitoring
	
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

func _apply_special_attack_damage() -> void:
	if not special_attack_area:
		return
		
	var areas = special_attack_area.get_overlapping_areas()
	for area in areas:
		var body = area.get_parent()
		if body.is_in_group("enemy") and body.has_method("take_damage") and not hit_enemies.has(body):
			hit_enemies.append(body)
			
			var damage = current_special_attack_damage
			var knockback_force = Vector2(0, -1) * 300
			
			if active_effects.has("multi_strike"):
				# 每段遞增5點
				match animated_sprite.frame:
					5: damage = current_special_attack_damage + 0
					6: damage = current_special_attack_damage + 5
					7: damage = current_special_attack_damage + 10
					8: damage = current_special_attack_damage + 15
					9: damage = current_special_attack_damage + 20
				knockback_force *= 5
			else:
				# 原有的段傷害
				match animated_sprite.frame:
					5: damage = current_special_attack_damage
					6: damage = current_special_attack_damage
					7: damage = current_special_attack_damage
			
			if body.has_method("apply_knockback"):
				body.apply_knockback(knockback_force)
			
			# 檢查是否有收割效果並且敵人會被這次攻擊擊中
			if active_effects.has("harvest"):
				var enemy_health = 0.0
				if body.has_method("get_health"):
					enemy_health = body.get_health()
				elif body.has_method("get_current_health"):
					enemy_health = body.get_current_health()
				else:
					# 嘗試直接訪問屬性
					enemy_health = body.get("health") if body.get("health") != null else 0.0
					if enemy_health == 0.0:
						enemy_health = body.get("current_health") if body.get("current_health") != null else 0.0
				
				# 如果傷害大於敵人當前生命值，觸發收割效果
				if damage >= enemy_health and enemy_health > 0:
					var heal_amount = max_health * 0.05  # 回復5%最大生命值
					current_health = min(current_health + heal_amount, max_health)
					health_changed.emit(current_health)
					
					# 播放治療特效
					if effect_manager:
						effect_manager.play_heal_effect()
					
			
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
	
	# 檢查是否是完美迴避
	if active_effects.has("agile"):
		if is_about_to_be_hit():
			agile_perfect_dodge = true
			agile_dodge_timer = agile_dodge_window
			
			# 簡的視覺反饋
			modulate = Color(0.5, 1, 1, 1)  # 藍白色閃光
			var tween = create_tween()
			tween.tween_property(self, "modulate", Color.WHITE, 0.2)
			
			# 播放完美迴避音效
			if $PerfectDodgeSound:
				$PerfectDodgeSound.play()
	
	# 設置衝刺時的碰撞
	set_collision_mask_value(1, false)  # 關閉與形的碰撞
	
	var direction = Input.get_axis("move_left", "move_right")
	if direction != 0:
		dash_direction = -1 if direction < 0 else 1
	else:
		dash_direction = -1 if animated_sprite.flip_h else 1
	
	# 接衝刺速度
	velocity = Vector2(dash_direction * dash_speed * 2, 0)
	
	if animated_sprite:
		animated_sprite.flip_h = dash_direction < 0
		animated_sprite.stop()
		animated_sprite.frame = 0
		animated_sprite.speed_scale = 1.5
		animated_sprite.play("dash")
	
	# 添加衝刺特效
	if effect_manager:
		effect_manager.play_dash(dash_direction < 0)

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
	
	# 恢復與地形的碰撞
	set_collision_mask_value(1, true)
	
	# 檢查是否在牆內並嘗試正位置
	_check_and_fix_wall_collision()
	
	if animated_sprite:
		animated_sprite.speed_scale = 1.0
		
		if is_dash_attacking:
			start_dash_attack()
		else:
			# 如果有敏捷效果，重置衝刺後的攻擊計數
			if active_effects.has("agile_dash"):
				agile_dash_attack_count = agile_dash_attack_limit
			
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

# 新增：檢查並修正牆內碰撞
func _check_and_fix_wall_collision() -> void:
	# 創建一個形狀查詢
	var shape_query = PhysicsShapeQueryParameters2D.new()
	shape_query.collision_mask = 1  # 只檢測地形層
	shape_query.transform = global_transform
	shape_query.shape = $CollisionShape2D.shape
	
	# 查詢前位置是否與牆壁疊
	var space_state = get_world_2d().direct_space_state
	var results = space_state.intersect_shape(shape_query)
	
	if not results.is_empty():
		# 如果在牆內，嘗試向左右移動直到找到可用空間
		for offset in [5, 10, 15, 20, 25, 30]:
			# 嘗試向右
			global_position.x += offset
			shape_query.transform = global_transform
			if space_state.intersect_shape(shape_query).is_empty():
				return
				
			# 還原位置後嘗試向左
			global_position.x -= offset * 2
			shape_query.transform = global_transform
			if space_state.intersect_shape(shape_query).is_empty():
				return
				
			# 如果不行，還原位置繼續嘗試更大的偏移
			global_position.x += offset

func start_dash_attack() -> void:
	is_attacking = true
	current_attack_combo = 0
	is_in_dash_attack_recovery = true
	dash_attack_recovery_timer = dash_attack_recovery_time
	
	if animated_sprite:
		animated_sprite.flip_h = dash_direction < 0
		animated_sprite.play("attack1")
		
		if attack_area:
			attack_area.scale.x = -1 if dash_direction < 0 else 1
			attack_area.monitoring = true
	
	velocity.x = abs(velocity.x) * dash_direction * 0.7
	
	if has_dash_wave:
		create_dash_wave()

func apply_dash_attack_damage() -> void:
	if attack_area:
		var areas = attack_area.get_overlapping_areas()
		for area in areas:
			var body = area.get_parent()
			if body.is_in_group("enemy") and body.has_method("take_damage") and not hit_enemies.has(body):
				hit_enemies.append(body)
				
				var damage = current_attack_damage * 1.5
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
		_apply_special_attack_damage()

func take_damage(amount: float, attacker: Node = null) -> void:
	if is_invincible or is_dashing:
		return
		
	current_health -= amount
	health_changed.emit(current_health)
	
	# 重置連擊數
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager:
		game_manager.reset_combo()
	
	# 處理憤怒效果
	if active_effects.has("rage") and rage_stack < rage_stack_limit:
		rage_stack += 1
		_update_rage_damage()
	
	# 處理荊棘效果
	if active_effects.has("thorns") and attacker != null:
		var real_attacker = attacker
		# 如果是投射物，嘗試獲取發射者
		if attacker.has_method("get_shooter"):
			real_attacker = attacker.get_shooter()
		
		# 確保攻擊者存在且可以受到傷害
		if real_attacker != null and real_attacker.has_method("take_damage"):
			real_attacker.take_damage(amount * 5.0)  # 反彈5倍傷害
	
	if current_health <= 0:
		if has_revive_heart:
			# 使用復活之心
			has_revive_heart = false
			current_health = float(max_health) / 2.0
			health_changed.emit(current_health)
			
			# 獲取UI並使用復活之心
			var ui = get_tree().get_first_node_in_group("ui")
			if ui and ui.has_method("use_revive_heart"):
				ui.use_revive_heart()
			
			set_invincible(2.0)
		else:
			die()
	else:
		if animated_sprite:
			animated_sprite.play("hurt")
		set_invincible(invincible_duration)

func die() -> void:
	print("[Player] 開始執行死亡函數")
	if current_state == "death":
		print("[Player] 已經處於死亡狀態，直接返回")
		return
		
	velocity = Vector2.ZERO
	current_state = "death"
	print("[Player] 狀態已更新為死亡")
	
	# 確保在亡時不被其他狀態打斷
	is_attacking = false
	is_special_attacking = false
	is_dashing = false
	is_hurt = false
	
	set_physics_process(false)
	set_process_input(false)
	set_collision_layer_value(2, false)
	print("[Player] 已禁用物理處理和輸入")
	
	if animated_sprite:
		animated_sprite.play("death")
		animated_sprite.speed_scale = 1.0
		print("[Player] 開始播放死亡動畫")
	
	# 等待死亡動畫播放完成
	if animated_sprite:
		print("[Player] 等待死亡動畫完成")
		await animated_sprite.animation_finished
		print("[Player] 死亡動畫已完成")
	
	# 發送死亡信號
	print("[Player] 發送死亡信號")
	died.emit()
	
	# 直接調用 game_over
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager:
		print("[Player] 正在調用 game_manager.game_over()")
		game_manager.game_over()
	else:
		print("[Player] 錯誤：找不到 game_manager")

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
			take_damage(collider.damage, collider)
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
	
	# 只在攻狀態時更新動畫速度
	if not (is_attacking or is_jump_attacking or is_special_attacking or is_dashing or is_hurt):
		# 設置動畫速度
		var speed_multiplier = get_berserker_multiplier()
		animated_sprite.speed_scale = speed_multiplier
		
		if not is_on_floor() or velocity.y > 0:  # 如果不在地面或正在下落
			if animated_sprite.animation != "jump":  # 如果不是跳躍動畫，開始放
				animated_sprite.play("jump")
			elif animated_sprite.frame >= 2:  # 如果已經到達第2幀，暫
				animated_sprite.pause()
				animated_sprite.frame = 2
		else:
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
	
	if not is_on_floor() or velocity.y > 0:  # 如果不在地面或正在下落
		animated_sprite.play("jump")
	else:
		var direction = Input.get_axis("move_left", "move_right")
		if abs(direction) > 0:
			animated_sprite.play("run")
		else:
			animated_sprite.play("idle")
#endregion

#region 信號處理
func _on_ani_sprite_2d_animation_finished() -> void:
	if not animated_sprite:
		return
	
	match animated_sprite.animation:
		"death":
			visible = false
		"jump":
			if not is_on_floor():
				animated_sprite.pause()
				animated_sprite.frame = 2
		"hurt":
			# 受傷動畫結束，如果還在按攻擊鍵，就重新開始攻擊
			if Input.is_action_pressed("attack"):
				start_attack()
			else:
				reset_states()
				_force_update_animation()
		"special_attack":
			_finish_special_attack()
		_:
			if animated_sprite.animation.begins_with("attack"):
				finish_attack()
	
	if animated_sprite.animation == "charge_attack":
		is_attacking = false
		hit_enemies.clear()

func _on_ani_sprite_2d_frame_changed() -> void:
	if not animated_sprite:
		return
		
	if is_special_attacking:
		var current_frame = animated_sprite.frame
		if current_frame >= 5 and current_frame <= 9:
			if special_attack_area:
				special_attack_area.monitoring = true
				hit_enemies.clear()
				_apply_special_attack_damage()
			last_special_attack_frame = current_frame
	
	elif is_attacking and animated_sprite.frame == 2:
		apply_damage()

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.get_parent().is_in_group("enemy"):
		var enemy = area.get_parent()
		take_damage(enemy.damage, enemy)

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
	
	# 保存蓄力相關狀態
	var temp_charging = is_charging
	var temp_charge_time = charge_time
	var temp_charge_multiplier = charge_damage_multiplier
	
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
	
	# 恢復蓄力相關狀態
	if active_effects.has("charge_attack_movement"):
		is_charging = temp_charging
		charge_time = temp_charge_time
		charge_damage_multiplier = temp_charge_multiplier
		if effect_manager and is_charging:
			effect_manager.play_charge_effect(charge_damage_multiplier)
	
	# 重置專注效果
	_reset_focus()

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

func _update_states() -> void:
	# 更新所有狀態
	if is_on_floor():
		is_jumping = false
		jump_count = 0
	
	# 新衝刺狀態
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= get_physics_process_delta_time()
		if dash_cooldown_timer <= 0:
			can_dash = true
	
	# 新特狀態
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

func _on_state_changed(_old_state: String, new_state: String) -> void:
	# 處理狀態變時的邏輯
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
	set_collision_layer_value(2, false)
	
	if animated_sprite:
		animated_sprite.play("death")
		animated_sprite.speed_scale = 1.0
	
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

#region 金幣系統
func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)
#endregion

func apply_effect(effect: Dictionary) -> void:
	if not effect.has("effect"):
		return
	
	var effect_type = effect.effect
	
	match effect_type:
		"life_steal":
			active_effects["life_steal"] = true
			max_health *= 0.5
			current_health *= 0.5
			health_changed.emit(current_health)
			
		"multi_strike":
			active_effects["multi_strike"] = true
			
		"berserker":
			active_effects["berserker"] = true
			health_changed.emit(current_health)
			
		"dash_wave":
			active_effects["dash_wave"] = true
			has_dash_wave = true
			
		"jump_impact":
			active_effects["jump_impact"] = true
			has_jump_impact = true
			max_jumps = 3
			
		"charge_attack_movement":
			active_effects["charge_attack_movement"] = true
			max_charge_bonus = effect.max_charge_bonus
			current_charge_rate = effect.charge_rate
			enable_charge_attack(effect.max_charge_bonus, effect.charge_rate)
			
		"thorns":
			active_effects["thorns"] = true
			current_attack_damage *= 0.5
			current_special_attack_damage *= 0.5
			max_health *= 3
			var new_health = current_health *2
			current_health = new_health
			health_changed.emit(current_health)
			
		"swift_dash":
			if not active_effects.has("swift_dash"):
				active_effects["swift_dash"] = true
				apply_swift_dash()
			
		"agile_dash":
			if not active_effects.has("agile_dash"):
				active_effects["agile_dash"] = true
				agile_dash_attack_count = agile_dash_attack_limit

		"rage":
			if not active_effects.has("rage"):
				active_effects["rage"] = true
				rage_stack = 0

		"agile":
			if not active_effects.has("agile"):
				active_effects["agile"] = true

		"focus":
			if not active_effects.has("focus"):
				active_effects["focus"] = true
				_reset_focus()

		"harvest":
			if not active_effects.has("harvest"):
				active_effects["harvest"] = true

		"ice_freeze":
			active_effects["ice_freeze"] = true
			has_ice_freeze = true
			ice_freeze_timer = 0.0  # 立即可用

func apply_swift_dash() -> void:
	# 減少衝刺冷卻時間50%
	dash_cooldown *= swift_dash_cooldown_reduction
	# 增加衝刺速度25%
	dash_speed *= swift_dash_multiplier
	# 更新衝刺關參數
	dash_duration *= swift_dash_multiplier  # 增加衝刺持續時間以匹配增加的距離

func remove_swift_dash() -> void:
	# 恢復衝刺冷卻時間
	dash_cooldown = 0.7
	# 恢復衝刺速度
	dash_speed = 250.0
	# 恢復衝刺持續時間
	dash_duration = 0.15

func process_loot_effect(effect_name: String) -> void:
	match effect_name:
		"swift_dash":
			if not active_effects.has("swift_dash"):
				active_effects["swift_dash"] = true
				apply_swift_dash()

# 處理蓄力狀態
func _handle_charge_state(delta: float) -> void:
	# 檢查是否有一鳴驚人效果
	if not active_effects or not "charge_attack_movement" in active_effects:
		if is_charging or charge_damage_multiplier > 1.0:
			reset_charge_state()
		return
	
	# 如果正在攻擊或受傷暫停蓄力但保持倍率
	if is_hurt or is_attacking:
		if is_charging:
			is_charging = false
			if effect_manager:
				effect_manager.stop_charge_effect()
		return
	
	# 自動開始蓄力
	if not is_charging:
		is_charging = true
		charge_effect_timer = 0.0
		# 只在沒有倍率時重置
		if charge_damage_multiplier <= 1.0:
			charge_time = 0.0
			charge_damage_multiplier = 1.0
			has_played_first_effect = false
			has_played_second_effect = false
			has_played_max_charge_effect = false
	
	# 更新蓄力時間和倍率
	charge_time += delta * current_charge_rate
	var previous_multiplier = charge_damage_multiplier
	charge_damage_multiplier = min(1.0 + (charge_time * max_charge_bonus), 6.0)
	
	# 處理特效
	if effect_manager:
		# 檢查是否跨過了特效觸發點，每個觸發點只播放一次
		if previous_multiplier < 1.2 and charge_damage_multiplier >= 1.2 and not has_played_first_effect:
			effect_manager.play_charge_effect(1.2)  # 1倍特效
			has_played_first_effect = true
		elif previous_multiplier < 3.0 and charge_damage_multiplier >= 3.0 and not has_played_second_effect:
			effect_manager.play_charge_effect(3.0)  # 3倍特效
			has_played_second_effect = true
		elif previous_multiplier < 5.0 and charge_damage_multiplier >= 5.0 and not has_played_max_charge_effect:
			effect_manager.play_charge_complete_effect()  # 5倍特效
			has_played_max_charge_effect = true

# 啟用蓄力攻擊
func enable_charge_attack(_max_bonus: float, _charge_rate: float) -> void:
	max_charge_bonus = 5.0  # 最大加成為5倍（基礎1倍 + 5倍加成 = 6倍）
	current_charge_rate = 0.8  # 6.25秒達到最大值 (5.0 / 6.25 = 0.8)
	active_effects["charge_attack_movement"] = true
	
	if not is_attacking and not is_hurt:
		is_charging = true
		if charge_damage_multiplier <= 1.0:
			charge_time = 0.0
			charge_damage_multiplier = 1.0
			has_played_first_effect = false
			has_played_second_effect = false
			has_played_max_charge_effect = false

# 添加新的函數來計算狂效果
func get_berserker_multiplier() -> float:
	if not active_effects.has("berserker"):
		return 1.0
	
	var health_percent = float(current_health) / float(max_health)
	var lost_health_percent = 1.0 - health_percent
	return min(1.0 + lost_health_percent, 2.0)

# 新增：完整重置所有狀態的函數
func reset_all_states() -> void:
	if active_effects.has("swift_dash"):
		remove_swift_dash()
	active_effects.clear()
	has_dash_wave = false
	has_jump_impact = false
	max_jumps = 2
	
	reset_move_speed()
	reset_jump_height()
	reset_attack_speed()
	reset_damage()
	reset_dash_distance()
	
	is_charging = false
	charge_time = 0.0
	charge_damage_multiplier = 1.0
	charge_start_timer = 0.0
	is_charge_ready = false
	max_charge_bonus = 1.0
	current_charge_rate = 0.15
	if effect_manager:
		effect_manager.stop_charge_effect()
	
	current_health = max_health
	current_state = "idle"
	
	is_attacking = false
	is_special_attacking = false
	is_dashing = false
	is_hurt = false
	is_invincible = false
	
	dash_cooldown_timer = 0
	dash_timer = 0
	invincible_timer = 0
	special_attack_timer = 0
	blink_timer = 0
	
	jump_count = 0
	current_attack_combo = 0
	
	hit_enemies.clear()
	
	velocity = Vector2.ZERO
	knockback_velocity = Vector2.ZERO
	
	set_collision_layer_value(2, true)
	modulate.a = 1.0
	visible = true
	
	set_physics_process(true)
	set_process_input(true)
	
	if animated_sprite:
		animated_sprite.speed_scale = 1.0
		animated_sprite.play("idle")
	
	# 重置敏捷效果相關狀態
	agile_dash_attack_count = 0
	active_effects.erase("agile_dash")
	
	# 重置憤怒效果
	rage_stack = 0
	active_effects.erase("rage")
	
	# 重置冰結效果
	has_ice_freeze = false
	ice_freeze_timer = 0.0
	active_effects.erase("ice_freeze")

func _on_effect_manager_effect_finished() -> void:
	pass # Replace with function body.


func _on_double_jump_effect_animation_finished() -> void:
	pass # Replace with function body.


func _on_health_changed(_new_health: Variant) -> void:
	pass # Replace with function body.

# 在 Player.gd 中加或修改 apply_knockback 函數
func apply_knockback(knockback: Vector2) -> void:
	# 應擊退
	velocity = knockback
	
	# 如果是在地面上，確保夠的垂直速度
	if is_on_floor() and knockback.y < 0:
		velocity.y = knockback.y
	
	# 強制移動以確保擊退效果
	move_and_slide()

# 添加創建波動的函數
func create_dash_wave() -> void:
	if not wave_scene:
		return
		
	var wave = wave_scene.instantiate()
	get_parent().add_child(wave)
	wave.global_position = global_position
	
	if dash_direction < 0:
		wave.rotation = PI
		wave.scale.x = -1
	else:
		wave.rotation = 0
		wave.scale.x = 1

# 修改跳躍相關函數
func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = -JUMP_VELOCITY
			jump_count = 1
			if has_jump_impact:
				_create_jump_impact()
		elif jump_count < max_jumps:
			velocity.y = -JUMP_VELOCITY * 1.2
			jump_count += 1
			if has_jump_impact:
				_create_jump_impact(jump_count > 2)

# 添加跳躍衝擊函數
func _create_jump_impact(is_double_jump: bool = false) -> void:
	if not effect_manager or not jump_impact_area:
		return
	
	hit_enemies.clear()
	
	var start_scale = Vector2(0.5, 0.5)
	var max_scale = Vector2(2.0, 2.0) if is_double_jump else Vector2(1.5, 1.5)
	var start_position = Vector2.ZERO
	var max_distance = 100.0 if is_double_jump else 60.0
	
	jump_impact_area.scale = start_scale
	jump_impact_area.position = start_position
	jump_impact_area.monitoring = true
	
	await get_tree().physics_frame
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	
	tween.tween_property(jump_impact_area, "scale", max_scale, 0.5)
	
	effect_manager.play_double_jump(animated_sprite.flip_h)
	
	var current_distance = 0.0
	var step = max_distance / 20.0
	
	for i in range(20):
		if not jump_impact_area.monitoring:
			jump_impact_area.monitoring = true
			await get_tree().physics_frame
			continue
		
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsRayQueryParameters2D.create(
			jump_impact_area.global_position,
			jump_impact_area.global_position + Vector2(0, step),
			1
		)
		var result = space_state.intersect_ray(query)
		
		if not result:
			current_distance += step
			jump_impact_area.position.y = current_distance
		
		var areas = jump_impact_area.get_overlapping_areas()
		for area in areas:
			var enemy = area.get_parent()
			if enemy.is_in_group("enemy") and not hit_enemies.has(enemy):
				hit_enemies.append(enemy)
				
				var damage = current_attack_damage * (2.0 if is_double_jump else 1.0)
				enemy.take_damage(damage)
				
				if enemy.has_method("apply_knockback"):
					var direction = Vector2.UP + (Vector2.RIGHT if enemy.global_position.x > global_position.x else Vector2.LEFT)
					var force = Vector2(2000, -800) if is_double_jump else Vector2(1000, -400)
					enemy.apply_knockback(direction.normalized() * force)
		
		await get_tree().physics_frame
	
	await tween.finished
	
	jump_impact_area.monitoring = false
	jump_impact_area.scale = Vector2.ONE
	jump_impact_area.position = Vector2.ZERO

# 移動速度提升
func boost_move_speed(multiplier: float) -> void:
	speed *= multiplier
	dash_speed *= multiplier

# 跳躍高度提升
func boost_jump_height(multiplier: float) -> void:
	jump_velocity *= multiplier  # 數乘以正數會讓跳躍更高

# 攻擊速度提升
func boost_attack_speed(multiplier: float) -> void:
	attack_combo_window *= (1.0 / multiplier)  # 縮短連擊窗口時間
	if animated_sprite:
		animated_sprite.speed_scale *= multiplier

# 傷害提升
func boost_damage(multiplier: float) -> void:
	current_attack_damage = base_attack_damage * multiplier
	current_special_attack_damage = base_special_attack_damage * multiplier

# 衝刺距離提升
func boost_dash_distance(multiplier: float) -> void:
	dash_duration *= multiplier

# 重置移動速度
func reset_move_speed() -> void:
	speed = 300.0
	dash_speed = 250.0

# 重置跳躍高度
func reset_jump_height() -> void:
	jump_velocity = JUMP_VELOCITY

# 重置攻擊速度
func reset_attack_speed() -> void:
	attack_combo_window = 0.5
	if animated_sprite:
		animated_sprite.speed_scale = 1.0

# 重置傷害
func reset_damage() -> void:
	current_attack_damage = base_attack_damage
	current_special_attack_damage = base_special_attack_damage
	rage_stack = 0  # 只重置憤怒層數

# 重置衝刺距離
func reset_dash_distance() -> void:
	dash_duration = 0.15

# 禁蓄力攻擊
func disable_charge_attack() -> void:
	active_effects.erase("charge_attack_movement")
	
	is_charging = false
	charge_time = 0.0
	charge_damage_multiplier = 1.0
	saved_charge_multiplier = 1.0
	max_charge_bonus = 1.0
	current_charge_rate = 0.15
	charge_start_timer = 0.0
	is_charge_ready = false
	
	if effect_manager:
		effect_manager.stop_charge_effect()

func _update_rage_damage() -> void:
	var total_bonus = rage_stack * rage_damage_bonus
	current_attack_damage = base_attack_damage * (1 + total_bonus)
	current_special_attack_damage = base_special_attack_damage * (1 + total_bonus)

# 檢查是否即將被敵人攻擊
func is_about_to_be_hit() -> bool:
	var hitbox = $Hitbox
	if not hitbox:
		return false
	
	# 檢查周圍的敵人攻擊區域
	var areas = hitbox.get_overlapping_areas()
	for area in areas:
		var parent = area.get_parent()
		
		# 檢查是否是敵人或敵人的攻擊
		if parent and parent.is_in_group("enemy"):
			return true
		if area.is_in_group("enemy_attack") or area.is_in_group("enemy"):
			return true
		if area.get_collision_layer_value(3):  # 檢查是否在敵人攻擊層
			return true
	
	return false

# 添加專注效果相關函數
func _reset_focus() -> void:
	focus_stack = 0
	focus_target = null
	focus_reset_timer = 0.0

# 在重置蓄力時也要重置特效狀態
func reset_charge_state() -> void:
	charge_time = 0.0
	charge_damage_multiplier = 1.0
	has_played_first_effect = false
	has_played_second_effect = false
	has_played_max_charge_effect = false
	if effect_manager:
		effect_manager.stop_charge_effect()

# 添加效果變化信號
signal effect_changed(effects: Dictionary)

# 在效果改變時發送信號
func _on_effect_changed() -> void:
	effect_changed.emit(active_effects)

# 添加冰結攻擊相關函數
func start_ice_freeze_attack() -> void:
	is_attacking = true
	attack_press_timer = 0
	current_attack_combo = 0
	
	if animated_sprite:
		var mouse_pos = get_global_mouse_position()
		var direction_to_mouse = (mouse_pos - global_position).normalized()
		animated_sprite.flip_h = direction_to_mouse.x < 0
		animated_sprite.play("attack1")  # 使用普通攻擊動畫
		
		if attack_area:
			attack_area.scale.x = -1 if animated_sprite.flip_h else 1
	
	if attack_area:
		attack_area.monitoring = true
	
	# 設置冰結冷卻
	ice_freeze_timer = ice_freeze_cooldown
	
	# 播放冰結特效
	if effect_manager:
		effect_manager.play_ice_effect()

func restore_health() -> void:
	current_health = max_health
	health_changed.emit(current_health)
	if effect_manager:
		effect_manager.play_heal_effect()

func restore_lives() -> void:
	has_revive_heart = true
	var ui = get_tree().get_first_node_in_group("ui")
	if ui and ui.has_method("restore_revive_heart"):
		ui.restore_revive_heart()
