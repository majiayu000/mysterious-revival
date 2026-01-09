## MainMenu - 主菜单控制脚本
extends Control

@onready var start_button: Button = $VBoxContainer/StartButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton
@onready var quit_button: Button = $VBoxContainer/QuitButton


func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# 添加按钮悬停效果
	_setup_button_effects()


func _setup_button_effects() -> void:
	for button in [start_button, settings_button, quit_button]:
		button.mouse_entered.connect(_on_button_hover.bind(button))
		button.mouse_exited.connect(_on_button_unhover.bind(button))


func _on_button_hover(button: Button) -> void:
	var tween = create_tween()
	tween.tween_property(button, "modulate", Color(1.2, 1.2, 1.2), 0.1)


func _on_button_unhover(button: Button) -> void:
	var tween = create_tween()
	tween.tween_property(button, "modulate", Color.WHITE, 0.1)


func _on_start_pressed() -> void:
	# 开始游戏，进入鬼域选择或直接进入第一个鬼域
	GameManager.start_domain("school", 1)
	get_tree().change_scene_to_file("res://scenes/ghost_domain/school_domain.tscn")


func _on_settings_pressed() -> void:
	# TODO: 打开设置界面
	EventBus.notify("设置功能开发中...", "info")


func _on_quit_pressed() -> void:
	get_tree().quit()
