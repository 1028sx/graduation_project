extends CharacterBody2D

enum State {IDLE, MOVE, ATTACK, HURT, DIE}

@export var move_speed = 50.0
@export var health = 30
@export var attack_range = 200.0
@export var attack_cooldown = 2.0

var current_state = State.IDLE
var player: CharacterBody2D = null
var arrow_scene = preload("res://scenes/enemies/Arrow.tscn")
var is_dying = false  # 新增：用於標記是否正在死亡

# 添加重力
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var animated_sprite = $AnimatedSprite2D
@onready var detection_area = $DetectionArea
@onready var attack_timer = $AttackTimer
@onready var attack_area = $AttackArea
@onready var hitbox = $Hitbox

func _ready():
	add_to_group("enemy")
	if animated_sprite:
		animated_sprite.play("idle")
		animated_sprite.animation_finished.connect(_on_animated_sprite_animation_finished)
	if attack_timer:
		attack_timer.wait_time = attack_cooldown
		attack_timer.one_shot = true
	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_body_entered)
		detection_area.body_exited.connect(_on_detection_area_body_exited)

func _physics_process(delta):
	if is_dying:  # 如果正在死亡，不執行其他狀態
		return
	
	# 應用重力
	if not is_on_floor():
		velocity.y += gravity * delta
	
	match current_state:
		State.IDLE:
			idle_state()
		State.MOVE:
			move_state(delta)
		State.ATTACK:
			attack_state()
		State.HURT:
			hurt_state()
		State.DIE:
			die_state()
	
	move_and_slide()

func idle_state():
	if is_instance_valid(player):
		var distance = global_position.distance_to(player.global_position)
		if distance <= attack_range:
			change_state(State.ATTACK)
		elif distance <= detection_area.get_node("CollisionShape2D").shape.radius:
			change_state(State.MOVE)

func move_state(delta):
	if is_instance_valid(player):
		var direction = (player.global_position - global_position).normalized()
		velocity.x = direction.x * move_speed
		if animated_sprite:
			animated_sprite.flip_h = velocity.x < 0
		if global_position.distance_to(player.global_position) <= attack_range:
			change_state(State.ATTACK)
	else:
		change_state(State.IDLE)

func attack_state():
	velocity.x = 0  # 攻擊時停止移動
	if attack_timer and attack_timer.is_stopped():
		if animated_sprite:
			animated_sprite.play("attack")
		attack_timer.start()

func hurt_state():
	velocity.x = 0  # 受傷時停止移動
	if animated_sprite:
		animated_sprite.play("hurt")

func die_state():
	velocity.x = 0  # 死亡時停止移動
	if not is_dying:
		is_dying = true
		if animated_sprite:
			animated_sprite.play("die")

func change_state(new_state):
	if is_dying:  # 如果正在死亡，不允許改變狀態
		return
	
	current_state = new_state
	if animated_sprite:
		match new_state:
			State.IDLE:
				animated_sprite.play("idle")
			State.MOVE:
				animated_sprite.play("run")
			State.ATTACK:
				animated_sprite.play("attack")
			State.HURT:
				animated_sprite.play("hurt")
			State.DIE:
				animated_sprite.play("die")

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
				shoot_arrow()
				change_state(State.MOVE)  # 攻擊完成後，切換回移動狀態
			"hurt":
				change_state(State.MOVE)  # 受傷動畫結束後，切換回移動狀態
			"die":
				queue_free()  # 死亡動畫結束後移除弓箭手

func shoot_arrow():
	if is_instance_valid(player):
		var arrow = arrow_scene.instantiate()
		arrow.global_position = global_position
		arrow.direction = (player.global_position - global_position).normalized()
		get_parent().add_child(arrow)

func take_damage(amount):
	if is_dying:  # 如果正在死亡，不再受到傷害
		return
	
	health -= amount
	if health <= 0:
		change_state(State.DIE)
	else:
		change_state(State.HURT)

func _on_hitbox_area_entered(area):
	if area.get_parent().is_in_group("player"):
		take_damage(10)  # 假設玩家的基礎攻擊力為 10
