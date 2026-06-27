class_name PopupBase
extends CanvasLayer

## Shared chrome + behavior for modal popups: dark scrim, centered framed panel,
## Esc/Back dismissal, and backdrop click-swallow. Subclasses keep their own scene
## layout (content + action buttons) but route the common frame through here so the
## scrim color, panel stylebox, and dismissal logic live in one place.
##
## Usage from a subclass `_ready()`:
##     _setup_popup($Root/Backdrop, $Root/Panel)
## and override `_on_popup_cancel()` to choose what Esc/Back does.

const DungeonTheme := preload("res://scripts/ui/dungeon_ui_theme.gd")

## Shared dim color behind every popup (previously copy-pasted per scene).
const SCRIM_COLOR := Color(0.0156863, 0.0156863, 0.0235294, 0.68)

const PANEL_BORDER_WIDTH := 2
const DEFAULT_PANEL_MARGIN := Vector2(24.0, 20.0)

var _popup_backdrop: ColorRect
var _popup_panel: PanelContainer


## Wire the shared frame. Pass the scene's backdrop (ColorRect) and panel
## (PanelContainer); either may be null. `border_color`/`margin` tune the frame so
## different popups can keep their accent while sharing the build logic.
func _setup_popup(
		backdrop: ColorRect,
		panel: PanelContainer,
		border_color: Color = DungeonTheme.COLOR_CYAN,
		margin: Vector2 = DEFAULT_PANEL_MARGIN) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_popup_backdrop = backdrop
	_popup_panel = panel
	if _popup_backdrop != null:
		_popup_backdrop.color = SCRIM_COLOR
		if not _popup_backdrop.gui_input.is_connected(_on_backdrop_gui_input):
			_popup_backdrop.gui_input.connect(_on_backdrop_gui_input)
	apply_panel_style(_popup_panel, border_color, margin)


## Apply the standard framed-panel stylebox. Static so embedded overlays that are
## not full PopupBase instances (e.g. in-scene reward panels) can reuse it too.
static func apply_panel_style(
		panel: PanelContainer,
		border_color: Color = DungeonTheme.COLOR_CYAN,
		margin: Vector2 = DEFAULT_PANEL_MARGIN) -> void:
	if panel == null:
		return
	panel.add_theme_stylebox_override(
		"panel",
		DungeonTheme.panel_style(
			DungeonTheme.COLOR_PANEL, border_color, PANEL_BORDER_WIDTH, margin.x, margin.y
		)
	)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel") or _is_escape_key(event):
		_on_popup_cancel()
		get_viewport().set_input_as_handled()


## Override to choose what Esc / Back / `ui_cancel` does (usually close/dismiss).
func _on_popup_cancel() -> void:
	pass


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if _is_press_event(event):
		get_viewport().set_input_as_handled()


static func _is_escape_key(event: InputEvent) -> bool:
	var key_event := event as InputEventKey
	return (
		key_event != null
		and key_event.pressed
		and not key_event.echo
		and key_event.keycode == KEY_ESCAPE
	)


static func _is_press_event(event: InputEvent) -> bool:
	return (
		(
			event is InputEventMouseButton
			and (event as InputEventMouseButton).pressed
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
		)
		or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	)
