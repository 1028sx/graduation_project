extends CharacterBody2D

#region 導出屬性
@export var move_speed = 50.0
@export var health = 300
@export var attack_cooldown = 2.0
@export var wander_time_min = 1.0
@export var wander_time_max = 3.0
@export var damage = 10
#endregion

#region 節點引用
@onready var animated_sprite = $AnimatedSprite2D
@onready var detection_area = $DetectionArea
@onready var attack_timer = $AttackTimer
@onready var attack_area = $AttackArea
@onready var hitbox = $Hitbox
var arrow_scene = preload("res://scenes/enemies/Arrow.tscn")
#endregion

#region 狀態變量
enum State {IDLE, WANDER, MOVE, ATTACK, HURT, DIE}

# 基礎狀態
var current_state = State.IDLE
var player: CharacterBody2D = null
var is_dying = false

# 移動相關
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var wander_timer = 0.0
var wander_direction = Vector2.ZERO

# 擊退相關
var knockback_velocity = Vector2.ZERO
var knockback_resistance = 0.8
#endregion

#region 初始化
func _ready():
	_initialize_enemy()
	_setup_collisions()
	_setup_components()
	_connect_signals()

func _initialize_enemy():
	add_to_group("enemy")

func _setup_collisions():
	# 設置弓箭手本體的碰撞層
	set_collision_layer_value(1, false)  # 不與地形碰撞
	set_collision_layer_value(2, false)  # 不與玩家碰撞
	set_collision_layer_value(3, false)  # 不作為受傷區域
	set_collision_layer_value(4, false)  # 不作為攻擊區域
	set_collision_layer_value(5, true)   # 設為弓箭手專用層
	
	# 設置弓箭手的碰撞檢測
	set_collision_mask_value(1, true)    # 檢測地形
	set_collision_mask_value(2, false)   # 不檢測玩家
	set_collision_mask_value(3, false)   # 不檢測受傷區域
	set_collision_mask_value(4, false)   # 不檢測攻擊區域
	set_collision_mask_value(5, false)   # 不檢測其他弓箭手
	
	# 設置弓箭手的受傷區域
	if hitbox:
		hitbox.set_collision_layer_value(3, true)   # 設為受傷區域
		hitbox.set_collision_mask_value(4, true)    # 檢測攻擊區域
	
	# 設置弓箭手的攻擊區域
	if attack_area:
		attack_area.set_collision_layer_value(4, true)  # 設為攻擊區域
		attack_area.set_collision_mask_value(3, true)   # 檢測受傷區域

func _setup_components():
	if animated_sprite:
		animated_sprite.play("idle")
	
	if attack_timer:
		attack_timer.wait_time = attack_cooldown
		attack_timer.one_shot = true

func _connect_signals():
	if animated_sprite:
		if not animated_sprite.animation_finished.is_connected(_on_animated_sprite_animation_finished):
			animated_sprite.animation_finished.connect(_on_animated_sprite_animation_finished)
	
	if detection_area:
		if not detection_area.body_entered.is_connected(_on_detection_area_body_entered):
				detection_area.body_entered.connect(_on_detection_area_body_entered)
		if not detection_area.body_exited.is_connected(_on_detection_area_body_exited):
				detection_area.body_exited.connect(_on_detection_area_body_exited)
#endregion

#region 主要更新循環
func _physics_process(delta):
	if is_dying:
		return
	
	# 應用重力
	velocity.y += gravity * delta
	
	# 處理擊退
	if knockback_velocity != Vector2.ZERO:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, delta * 1000)
	else:
		# 正常的 AI 行為
		match current_state:
			State.IDLE:
				idle_state(delta)
			State.WANDER:
				wander_state(delta)
			State.MOVE:
				move_state(delta)
			State.ATTACK:
				attack_state(delta)
			State.HURT:
				hurt_state(delta)
			State.DIE:
				die_state(delta)
	
	move_and_slide()
#endregion

#region AI狀態系統
func idle_state(_delta):
	velocity.x = 0
	if is_instance_valid(player):
		change_state(State.MOVE)
	elif randf() < _delta * 0.5:
		start_wander()

func wander_state(delta):
	velocity.x = wander_direction.x * move_speed * 0.5
	if animated_sprite:
		animated_sprite.flip_h = velocity.x < 0
	
	wander_timer -= delta
	if wander_timer <= 0 or is_on_wall():
		change_state(State.IDLE)
	
	if is_instance_valid(player):
		change_state(State.MOVE)

func move_state(_delta):
	if is_instance_valid(player):
		var direction = (player.global_position - global_position).normalized()
		velocity.x = direction.x * move_speed
		if animated_sprite:
			animated_sprite.flip_h = velocity.x < 0
		
		var distance = global_position.distance_to(player.global_position)
		if distance <= 200:
			change_state(State.ATTACK)
	else:
		change_state(State.IDLE)

func attack_state(_delta):
	velocity.x = 0
	if attack_timer and attack_timer.is_stopped():
		if animated_sprite:
			animated_sprite.play("attack")
		attack_timer.start()

func hurt_state(_delta):
	velocity.x = 0
	if animated_sprite:
		animated_sprite.play("hurt")

func die_state(_delta):
	velocity.x = 0
	if not is_dying:
		is_dying = true
		if animated_sprite:
			animated_sprite.play("die")

func start_wander():
	change_state(State.WANDER)
	wander_timer = randf_range(wander_time_min, wander_time_max)
	wander_direction = Vector2(randf_range(-1, 1), 0).normalized()

func change_state(new_state):
	if is_dying:
		return
	
	current_state = new_state
	if animated_sprite:
		match new_state:
			State.IDLE:
				animated_sprite.play("idle")
			State.WANDER, State.MOVE:
				animated_sprite.play("run")
			State.ATTACK:
				animated_sprite.play("attack")
			State.HURT:
				animated_sprite.play("hurt")
			State.DIE:
				animated_sprite.play("die")
#endregion

#region 戰鬥系統
func shoot_arrow():
	if is_instance_valid(player):
		var arrow = arrow_scene.instantiate()
		arrow.global_position = global_position
		
		var direction = (player.global_position - global_position).normalized()
		arrow.set_direction(direction)
		
		get_parent().add_child(arrow)

func take_damage(amount):
	if is_dying:
		return
	
	health -= amount
	if health <= 0:
		change_state(State.DIE)
	else:
		change_state(State.HURT)

func apply_knockback(knockback: Vector2):
	knockback_velocity = knockback * (1.0 - knockback_resistance)
#endregion

#region 信號處理
func _on_detection_area_body_entered(body):
	if body.is_in_group("player"):
		player = body
		if current_state == State.IDLE or current_state == State.WANDER:
			change_state(State.MOVE)

func _on_detection_area_body_exited(body):
	if body.is_in_group("player"):
		player = null
		change_state(State.IDLE)

func _on_animated_sprite_animation_finished():
	if animated_sprite:
		match animated_sprite.animation:
			"attack":
				shoot_arrow()
				change_state(State.MOVE)
			"hurt":
				change_state(State.MOVE)
			"die":
				queue_free()

func _on_hitbox_area_entered(area):
	var parent = area.get_parent()
	if parent.is_in_group("player") and area.get_collision_layer_value(4):
		if parent.is_special_attacking and parent.animated_sprite:
			# 特殊攻擊的傷害
			match parent.animated_sprite.frame:
				5: take_damage(parent.special_attack_power_1)
				6: take_damage(parent.special_attack_power_2)
				7: take_damage(parent.special_attack_power_3)
			# 特殊攻擊的擊退
			apply_knockback(Vector2(0, -1) * 300)
		else:
			# 普通攻擊的傷害和擊退
			take_damage(parent.get_attack_damage())
			apply_knockback(parent.get_knockback_direction() * parent.get_knockback_force())
#endregion
