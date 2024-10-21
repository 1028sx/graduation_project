extends CharacterBody2D

# 玩家基本屬性
@export var speed = 300.0  # 移動速度
@export var jump_velocity = -400.0  # 跳躍速度
@export var dash_speed = 1000.0  # 衝刺速度
@export var dash_duration = 0.2  # 衝刺持續時間
@export var dash_cooldown = 1.0  # 衝刺冷卻時間
@export var attack_cooldown = 0.5  # 攻擊冷卻時間
@export var defense_duration = 0.5  # 防禦持續時間
@export var defense_cooldown = 1.0  # 防禦冷卻時間
@export var max_health = 100  # 最大生命值
@export var defense_strength = 0.5  # 防禦時受到的傷害減少比例
@export var attack_power = 10  # 添加這行來定義玩家的攻擊力

# 獲取重力值
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# 玩家狀態變量
var is_dashing = false  # 是否正在衝刺
var dash_timer = 0.0  # 衝刺計時器
var dash_cooldown_timer = 0.0  # 衝刺冷卻計時器
var attack_timer = 0.0  # 攻擊冷卻計時器
var is_attacking = false  # 是否正在攻擊
var is_defending = false  # 是否正在格擋
var defense_timer = 0.0  # 防禦計時器
var defense_cooldown_timer = 0.0  # 防禦冷卻計時器
var current_state = "idle"
var current_health = max_health  # 當前生命值
var is_jumping = false  # 跳躍狀態

# 技能解鎖狀態
var can_throw_shuriken = false  # 是否可以投擲手裡劍
var can_special_attack = false  # 是否可以使用特殊攻擊
var can_block = false  # 是否可以格擋

# 節點引用
@onready var animated_sprite = $AniSprite2D
@onready var collision_shape = $CollisionShape2D

# 特殊技能相關
var shuriken_scene = preload("res://scenes/player/shuriken.tscn")  # 注意小寫的 'shuriken.tscn'
var special_attack_cooldown = 5.0
var special_attack_timer = 0.0

# 信號
signal health_changed(new_health)
signal died
# 暫時註釋掉未使用的信號
# signal skill_unlocked(skill_name)

func _ready():
	add_to_group("player")
	if animated_sprite:
		animated_sprite.animation_finished.connect(_on_animated_sprite_animation_finished)
	
	# 設置玩家的碰撞層和遮罩
	collision_layer = 0b0010  # 第2層，玩家層
	collision_mask = 0b0001   # 只與第1層（環境）發生碰撞

	# 設置玩家的受傷區域
	var hitbox = $Hitbox
	if hitbox:
		hitbox.collision_layer = 0b0100  # 第3層，玩家的受傷區域
		hitbox.collision_mask = 0b1000   # 只與第4層（敵人攻擊）發生碰撞

	# 設置玩家的攻擊區域
	var attack_area = $AttackArea
	if attack_area:
		attack_area.collision_layer = 0b0000  # 不設置碰撞層
		attack_area.collision_mask = 0b0100   # 只與第3層（敵人受傷區域）發生碰撞

func _physics_process(delta):
	# 移動前的位置
	var previous_position = global_position
	
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		is_jumping = false

	var direction = Input.get_axis("move_left", "move_right")
	if direction and not is_attacking and not is_defending:
		velocity.x = direction * speed
		if animated_sprite:
			animated_sprite.flip_h = direction < 0
			if is_on_floor():
				animated_sprite.play("run")
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		if is_on_floor() and not is_attacking and not is_defending and animated_sprite:
			animated_sprite.play("idle")

	if Input.is_action_just_pressed("jump") and is_on_floor():
		jump()

	if Input.is_action_just_pressed("attack") and not is_attacking:
		start_attack()

	if Input.is_action_just_pressed("dash") and not is_dashing and dash_cooldown_timer <= 0:
		start_dash()

	if is_attacking:
		perform_attack()

	if is_dashing:
		perform_dash(delta)

	move_and_slide()
	
	# 檢查是否與敵人發生碰撞
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		if collision.get_collider() is CharacterBody2D and collision.get_collider().is_in_group("enemy"):
			# 如果碰到敵人，恢復到之前的位置
			global_position = previous_position
			break

func jump():
	velocity.y = jump_velocity
	is_jumping = true
	if animated_sprite:
		animated_sprite.play("jump")

func start_attack():
	is_attacking = true
	if animated_sprite:
		animated_sprite.play("attack")

func perform_attack():
	if animated_sprite and animated_sprite.frame in [2, 6, 10]:
		apply_damage()
	
	if animated_sprite and animated_sprite.frame >= animated_sprite.sprite_frames.get_frame_count("attack") - 1:
		finish_attack()

func finish_attack():
	is_attacking = false
	if animated_sprite:
		animated_sprite.play("idle")

func start_dash():
	is_dashing = true
	dash_timer = dash_duration
	collision_shape.set_deferred("disabled", true)  # 衝刺時禁用碰撞

func perform_dash(delta):
	if dash_timer > 0:
		velocity = velocity.normalized() * dash_speed
		dash_timer -= delta
	else:
		finish_dash()

func finish_dash():
	is_dashing = false
	collision_shape.set_deferred("disabled", false)  # 衝刺結束後啟用碰撞
	dash_cooldown_timer = dash_cooldown

func _on_animated_sprite_animation_finished():
	if animated_sprite and animated_sprite.animation == "attack":
		finish_attack()

func take_damage(damage):
	if not is_dashing:  # 衝刺時無敵
		current_health -= damage
		health_changed.emit(current_health)
		if current_health <= 0:
			die()
		else:
			if animated_sprite:
				animated_sprite.play("hurt")

func die():
	current_state = "death"
	if animated_sprite:
		animated_sprite.play("death")
	died.emit()

func unlock_skill(skill_name):
	match skill_name:
		"block":
			can_block = true
		"shuriken":
			can_throw_shuriken = true
		"special_attack":
			can_special_attack = true
	# 暫時註釋掉信號發送
	# skill_unlocked.emit(skill_name)

func apply_damage():
	var attack_area = $AttackArea
	if attack_area:
		var bodies = attack_area.get_overlapping_bodies()
		for body in bodies:
			if body.is_in_group("enemy") and body.has_method("take_damage"):
				body.take_damage(attack_power)  # 使用 attack_power 而不是固定值

func _process(delta):
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta

	if animated_sprite and animated_sprite.is_playing():
			# 可以在這裡添加自定義的動畫邏輯，如果需要的話
			pass

func _on_hitbox_area_entered(area):
	if area.is_in_group("enemy_attack"):
		take_damage(area.get_parent().damage)  # 假設敵人有一個 damage 屬性
