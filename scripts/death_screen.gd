extends CanvasLayer

@onready var death_root: Control = $DeathRoot
@onready var restart_button: Button = $DeathRoot/Center/Menu/RestartButton
@onready var menu_button: Button = $DeathRoot/Center/Menu/MenuButton

func _ready() -> void:
	death_root.hide()
	_style_button(restart_button)
	_style_button(menu_button)
	restart_button.pressed.connect(_on_restart_pressed)
	menu_button.pressed.connect(_on_menu_pressed)

func _make_style(background: Color, border: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	return style

func _style_button(button: Button) -> void:
	button.custom_minimum_size = Vector2(340.0, 58.0)
	button.add_theme_font_size_override("font_size", 27)
	button.add_theme_color_override("font_color", Color(0.85, 0.82, 0.82))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _make_style(Color(0.025, 0.008, 0.012, 0.94), Color(0.38, 0.04, 0.05, 0.95)))
	button.add_theme_stylebox_override("hover", _make_style(Color(0.4, 0.012, 0.02, 0.98), Color(0.9, 0.08, 0.08, 1.0)))
	button.add_theme_stylebox_override("pressed", _make_style(Color(0.58, 0.015, 0.02, 1.0), Color(1.0, 0.16, 0.12, 1.0)))
	button.add_theme_stylebox_override("focus", _make_style(Color(0.0, 0.0, 0.0, 0.0), Color(0.85, 0.55, 0.3, 1.0)))

func show_death() -> void:
	if death_root.visible:
		return
	death_root.show()
	death_root.modulate.a = 0.0
	get_tree().paused = true
	create_tween().tween_property(death_root, "modulate:a", 1.0, 0.45)
	restart_button.grab_focus()

func _on_restart_pressed() -> void:
	restart_button.disabled = true
	menu_button.disabled = true
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_menu_pressed() -> void:
	restart_button.disabled = true
	menu_button.disabled = true
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
