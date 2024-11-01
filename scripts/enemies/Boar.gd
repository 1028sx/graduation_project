extends CharacterBody2D

#region 導出屬性
@export var move_speed = 75.0  # 徘徊速度
@export var charge_speed_min = 150.0  # 初始衝刺速度
@export var charge_speed_max = 300.0  # 最大衝刺速度
@export var charge_acceleration = 50.0  # 衝刺加速度
@export var charge_distance = 200.0  # 衝刺距離
@export var detection_range = 300.0  # 檢測範圍
@export var health = 500  # 高血量
@export var damage = 20   # 高傷害
@export var attack_cooldown = 1.5
#endregion

#region 節點引用
@onready var animated_sprite = $AnimatedSprite2D
@onready var detection_area = $DetectionArea
@onready var attack_area = $AttackArea
@onready var hitbox = $Hitbox
@onready var attack_timer = $AttackTimer
#endregion

#region 狀態變量
enum State {IDLE, MOVE, ATTACK, HURT, DIE}

# 基礎狀態
var current_state = State.IDLE
var player: CharacterBody2D = null
var is_dying = false

# 移動相關
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var initial_position = Vector2.ZERO
var current_speed = 0.0  # 當前速度

# 擊退相關
var knockback_velocity = Vector2.ZERO
var knockback_resistance = 0.9  # 高擊退抗性
#endregion

#region 初始化
func _ready():
	_initialize_enemy()
	_setup_collisions()
	_setup_components()
	_connect_signals()
	initial_position = global_position

func _initialize_enemy():
	add_to_group("enemy")

func _setup_collisions():
	# 設置野豬本體的碰撞層
	set_collision_layer_value(1, false)  # 不與地形碰撞
	set_collision_layer_value(2, false)  # 不與玩家碰撞
	set_collision_layer_value(3, false)  # 不作為受傷區域
	set_collision_layer_value(4, false)  # 不作為攻擊區域
	set_collision_layer_value(5, true)   # 設為敵人專用層
	
	# 設置野豬的碰撞檢測
	set_collision_mask_value(1, true)    # 檢測地形
	set_collision_mask_value(2, false)   # 不檢測玩家
	set_collision_mask_value(3, false)   # 不檢測受傷區域
	set_collision_mask_value(4, false)   # 不檢測攻擊區域
	set_collision_mask_value(5, false)   # 不檢測其他敵人
	
	# 設置野豬的受傷區域
	if hitbox:
		hitbox.set_collision_layer_value(3, true)   # 設為受傷區域
		hitbox.set_collision_mask_value(4, true)    # 檢測攻擊區域
	
	# 設置野豬的攻擊區域
	if attack_area:
		attack_area.set_collision_layer_value(4, true)  # 設為攻擊區域
		attack_area.set_collision_mask_value(3, true)   # 檢測受傷區域
		attack_area.monitoring = false  # 初始時禁用攻擊區域
	
	# 設置野豬的檢測區域
	if detection_area:
		detection_area.set_collision_layer_value(1, false)  # 不設置碰撞層
		detection_area.set_collision_mask_value(2, true)    # 檢測玩家層
		detection_area.monitoring = true  # 確保檢測區域啟用

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
		if not animated_sprite.frame_changed.is_connected(_on_animated_sprite_frame_changed):
			animated_sprite.frame_changed.connect(_on_animated_sprite_frame_changed)
	
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
	elif randf() < _delta * 0.5:  # 有機率開始徘徊
		start_wander()

func start_wander():
	change_state(State.MOVE)
	# 隨機選擇一個方向
	velocity.x = move_speed * (1 if randf() > 0.5 else -1)
	if animated_sprite:
		animated_sprite.flip_h = velocity.x < 0
	# 設置一個隨機的徘徊時間
	await get_tree().create_timer(randf_range(2.0, 4.0)).timeout
	if current_state == State.MOVE and not is_instance_valid(player):
		change_state(State.IDLE)

func move_state(_delta):
	if is_instance_valid(player):
		var direction = (player.global_position - global_position).normalized()
		var height_difference = abs(player.global_position.y - global_position.y)
		
		# 檢查玩家是否在攻擊範圍內
		var distance = global_position.distance_to(player.global_position)
		var is_in_attack_range = distance <= charge_distance
		
		# 只有當玩家在相近的高度時才移動和攻擊
		if height_difference < 50:  # 高度容差
			velocity.x = direction.x * move_speed  # 使用基礎移動速度
			if animated_sprite:
				animated_sprite.flip_h = velocity.x < 0
			
			if is_in_attack_range:
				current_speed = charge_speed_min  # 開始衝刺時設置初始速度
				change_state(State.ATTACK)
		else:
			velocity.x = 0
	else:
		# 沒有玩家目標時，繼續當前的移動
		if is_on_wall() or not _check_ground_ahead():
			velocity.x *= -1  # 轉向
			if animated_sprite:
				animated_sprite.flip_h = velocity.x < 0

func attack_state(_delta):
	if is_instance_valid(player):
		# 直接開始衝刺攻擊
		var direction = (player.global_position - global_position).normalized()
		# 逐漸增加衝刺速度
		current_speed = move_toward(current_speed, charge_speed_max, charge_acceleration * _delta)
		velocity.x = direction.x * current_speed
		if animated_sprite:
			animated_sprite.flip_h = velocity.x < 0
			animated_sprite.play("attack")  # 播放攻擊動畫

func hurt_state(_delta):
	velocity.x = 0
	if animated_sprite and animated_sprite.animation != "hurt":
		animated_sprite.play("hurt")

func die_state(_delta):
	velocity.x = 0
	if not is_dying:
		is_dying = true
		if animated_sprite:
			animated_sprite.play("die")

func change_state(new_state):
	if is_dying:
		return
	
	current_state = new_state
	if animated_sprite:
		match new_state:
			State.IDLE:
				animated_sprite.play("idle")
			State.MOVE:
				animated_sprite.play("move")
			State.ATTACK:
				animated_sprite.play("attack")
			State.HURT:
				animated_sprite.play("hurt")
			State.DIE:
				animated_sprite.play("die")

# 添加檢查前方地面的函數
func _check_ground_ahead() -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		global_position + Vector2(30 * sign(velocity.x), 0),  # 檢查點在前方
		global_position + Vector2(30 * sign(velocity.x), 50),  # 向下延伸50像素
		1  # 只檢測地形層
	)
	var result = space_state.intersect_ray(query)
	return result != null
#endregion

#region 戰鬥系統
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
		if current_state == State.IDLE:
			change_state(State.MOVE)

func _on_detection_area_body_exited(body):
	if body.is_in_group("player"):
		player = null
		change_state(State.IDLE)

func _on_animated_sprite_animation_finished():
	if animated_sprite:
		match animated_sprite.animation:
			"attack":
				# 攻擊結束後回到基礎速度
				velocity.x = move_speed * sign(velocity.x)
				change_state(State.MOVE)
			"hurt":
				# 確保受傷動畫播放完後回到移動狀態
				if current_state == State.HURT:  # 添加這個檢查
					change_state(State.MOVE)
			"die":
				queue_free()

func _on_animated_sprite_frame_changed():
	if animated_sprite and animated_sprite.animation == "attack":
		var current_frame = animated_sprite.frame
		if current_frame == 15:  # 在第15幀造成傷害
			if attack_area:
				attack_area.monitoring = true
		else:
			if attack_area:
				attack_area.monitoring = false
		
		# 在第23幀（最後一幀）時回到基礎速度
		if current_frame == 23:
			velocity.x = move_speed * sign(velocity.x)

func _on_attack_area_area_entered(area):
	var body = area.get_parent()
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
#endregion
