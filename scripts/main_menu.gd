extends Control

@onready var main_menu: VBoxContainer = $MenuCenter/MainMenu
@onready var settings_center: CenterContainer = $SettingsCenter
@onready var settings_panel: PanelContainer = $SettingsCenter/SettingsPanel
@onready var start_button: Button = $MenuCenter/MainMenu/StartButton
@onready var settings_button: Button = $MenuCenter/MainMenu/SettingsButton
@onready var exit_button: Button = $MenuCenter/MainMenu/ExitButton
@onready var back_button: Button = $SettingsCenter/SettingsPanel/Margin/SettingsMenu/BackButton
@onready var volume_slider: HSlider = $SettingsCenter/SettingsPanel/Margin/SettingsMenu/VolumeRow/VolumeSlider
@onready var volume_value: Label = $SettingsCenter/SettingsPanel/Margin/SettingsMenu/VolumeRow/VolumeValue
@onready var fullscreen_toggle: CheckButton = $SettingsCenter/SettingsPanel/Margin/SettingsMenu/FullscreenToggle

func _ready() -> void:
	for button in [start_button, settings_button, exit_button, back_button]:
		_style_button(button)
	settings_panel.add_theme_stylebox_override("panel", _make_style(Color(0.015, 0.018, 0.035, 0.96), Color(0.42, 0.08, 0.1, 0.95)))
	_load_settings()
	start_button.pressed.connect(_on_start_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	back_button.pressed.connect(_on_back_pressed)
	volume_slider.value_changed.connect(_on_volume_changed)
	fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	start_button.grab_focus()

func _make_style(background: Color, border: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	return style

func _style_button(button: Button) -> void:
	button.custom_minimum_size = Vector2(340.0, 56.0)
	button.add_theme_font_size_override("font_size", 26)
	button.add_theme_color_override("font_color", Color(0.82, 0.86, 0.94))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _make_style(Color(0.02, 0.025, 0.045, 0.9), Color(0.3, 0.34, 0.45, 0.9)))
	button.add_theme_stylebox_override("hover", _make_style(Color(0.32, 0.025, 0.035, 0.96), Color(0.85, 0.16, 0.18, 1.0)))
	button.add_theme_stylebox_override("pressed", _make_style(Color(0.48, 0.035, 0.045, 1.0), Color(0.95, 0.25, 0.22, 1.0)))
	button.add_theme_stylebox_override("focus", _make_style(Color(0.0, 0.0, 0.0, 0.0), Color(0.9, 0.68, 0.3, 1.0)))

func _load_settings() -> void:
	var volume = 80.0
	var fullscreen = false
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		volume = float(config.get_value("audio", "master", 80.0))
		fullscreen = bool(config.get_value("display", "fullscreen", false))
	volume_slider.set_value_no_signal(volume)
	volume_value.text = "%d%%" % roundi(volume)
	fullscreen_toggle.set_pressed_no_signal(fullscreen)
	_apply_volume(volume)
	var target_mode = DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != target_mode:
		DisplayServer.window_set_mode(target_mode)

func _apply_volume(value: float) -> void:
	AudioServer.set_bus_mute(0, value <= 0.01)
	if value > 0.01:
		AudioServer.set_bus_volume_db(0, linear_to_db(value / 100.0))

func _save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("audio", "master", volume_slider.value)
	config.set_value("display", "fullscreen", fullscreen_toggle.button_pressed)
	config.save("user://settings.cfg")

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_settings_pressed() -> void:
	main_menu.hide()
	settings_center.show()
	back_button.grab_focus()

func _on_back_pressed() -> void:
	settings_center.hide()
	main_menu.show()
	settings_button.grab_focus()

func _on_exit_pressed() -> void:
	get_tree().quit()

func _on_volume_changed(value: float) -> void:
	volume_value.text = "%d%%" % roundi(value)
	_apply_volume(value)
	_save_settings()

func _on_fullscreen_toggled(pressed: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if pressed else DisplayServer.WINDOW_MODE_WINDOWED)
	_save_settings()
