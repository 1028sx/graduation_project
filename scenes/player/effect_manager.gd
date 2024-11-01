extends Node2D

signal effect_finished

@onready var double_jump_effect = $DoubleJumpEffect

func _ready():
	if double_jump_effect:
		# 設置初始屬性
		double_jump_effect.visible = false
		double_jump_effect.modulate = Color(1, 1, 1, 0.8)
		double_jump_effect.z_index = 1
		
		# 連接信號
		if not double_jump_effect.animation_finished.is_connected(_on_animation_finished):
			double_jump_effect.animation_finished.connect(_on_animation_finished)

func play_double_jump(flip_h: bool = false) -> void:
	if not double_jump_effect:
		return
	
	# 重置特效狀態
	double_jump_effect.stop()
	double_jump_effect.frame = 0
	double_jump_effect.visible = true
	self.visible = true
	
	# 設置特效屬性
	double_jump_effect.position = Vector2(0, 20)
	double_jump_effect.flip_h = flip_h
	double_jump_effect.modulate.a = 0.8
	
	# 播放動畫
	if double_jump_effect.sprite_frames and double_jump_effect.sprite_frames.has_animation("smoke"):
		double_jump_effect.speed_scale = 1.0
		double_jump_effect.play("smoke")

func _on_animation_finished():
	if double_jump_effect:
		double_jump_effect.stop()
		double_jump_effect.visible = false
		effect_finished.emit()
