extends Control

signal refresh_completed

var settings_manager := load("res://core/global/settings_manager.tres") as SettingsManager
var library_manager := load("res://core/global/library_manager.tres") as LibraryManager
var install_manager := load("res://core/global/install_manager.tres") as InstallManager
var menu_state_machine := load("res://assets/state/state_machines/menu_state_machine.tres") as StateMachine
var library_state := load("res://assets/state/states/library.tres") as State
var launcher_state := load("res://assets/state/states/game_launcher.tres") as State
var osk_state := load("res://assets/state/states/osk.tres") as State
var library_refresh := load("res://core/ui/card_ui/library/library_refresh_state.tres") as LibraryRefreshState
var card_scene := load("res://core/ui/components/card.tscn") as PackedScene

var tween: Tween
var refresh_requested := false
var refresh_in_progress := false
var _library := {}
var _current_selection := {}
var _tabs := {}  # Now stores {tab_name: {"container": ScrollContainer, "grid": HFlowContainer}}
var logger := Log.get_logger("LibraryMenu", Log.LEVEL.INFO)

@export var tabs_state: TabContainerState

@onready var global_search: SearchBar = get_tree().get_first_node_in_group("global_search_bar")
@onready var tab_container: TabContainer = $%TabContainer
@onready var all_games_grid: HFlowContainer = $%AllGamesGrid
@onready var installed_games_grid: HFlowContainer = $%InstalledGrid

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Clear any example grid items
	for child in installed_games_grid.get_children():
		child.queue_free()

	# Connect to state entered signals
	library_state.state_entered.connect(_on_state_entered)
	var on_refresh := func():
		_on_state_entered(null)
	library_state.refreshed.connect(on_refresh)
	
	# Initialize static tabs from scene
	_tabs["Installed"] = {"container": tab_container.get_node("InstalledTab"), "grid": installed_games_grid}
	_tabs["All Games"] = {"container": tab_container.get_node("AllGamesTab"), "grid": all_games_grid}
	logger.debug("Initial tabs: " + str(_tabs.keys()))
	
	# Listen for tab container changes
	if tabs_state:
		tabs_state.tab_changed.connect(_on_tab_container_tab_changed)
		tabs_state.tab_added.connect(_on_tab_added)
		tabs_state.tab_removed.connect(_on_tab_removed)
	
	# Listen for library changes
	var on_library_changed := func(item: LibraryItem):
		logger.debug("Library item added: " + item.name)
		queue_refresh()
	library_manager.library_item_added.connect(on_library_changed)
	library_manager.library_item_removed.connect(on_library_changed)
	library_manager.library_item_unhidden.connect(on_library_changed)

	# Listen for app install/uninstall changes
	install_manager.install_queued.connect(_on_install_queued)
	install_manager.install_completed.connect(_on_installed)
	install_manager.uninstall_completed.connect(_on_uninstalled)
	if global_search != null:
		global_search.search_submitted.connect(_on_search)
	
	# Queue a library refresh
	queue_refresh()

## Queues the library menu to be refreshed
func queue_refresh() -> void:
	refresh_requested = true
	refresh()

func refresh() -> void:
	# Don't process if no refresh is requested or one is in progress
	if not refresh_requested or refresh_in_progress:
		return
	refresh_requested = false
	refresh_in_progress = true
	library_refresh.is_refreshing = true
	library_refresh.refresh_started.emit()
	await _reload_library()
	refresh_in_progress = false
	refresh_completed.emit()
	library_refresh.is_refreshing = false
	library_refresh.refresh_completed.emit()
	refresh.call_deferred()

func _on_state_entered(_from: State):
	# Focus the first entry on state change
	_on_tab_container_tab_changed(tab_container.current_tab)

# Handle searches
func _on_search(text: String):
	text = text.to_lower()
	
	# If the text is empty, set all items to visible
	if text == "":
		for tab_num in _library:
			for item_name in _library[tab_num]:
				var item: Control = _library[tab_num][item_name]
				item.visible = true
		return
		
	# TODO: Fuzzy searching?
	for tab_num in _library:
		for item_name in _library[tab_num]:
			var item: Control = _library[tab_num][item_name]
			if (item_name as String).to_lower().contains(text):
				item.visible = true
				continue
			item.visible = false

func _reload_library() -> void:
	logger.debug("Reloading library")

	# Tab indexes for installed games, all games, and parser-specific tabs
	const installed_tab_idx := 0
	const all_games_tab_idx := 1
	
	# Load all library entries
	var all_items := library_manager.get_library_items()
	
	# Ensure parser tabs are added to tab_container (skip static tabs)
	var parser_tabs = Array(tabs_state.tabs_text).filter(func(t): return t != "Installed" and t != "All Games")
	for tab_name in parser_tabs:
		if tab_name not in _tabs:
			var node = ScrollContainer.new()
			node.name = tab_name
			node.horizontal_scroll_mode = 0  # Match InstalledTab and AllGamesTab
			var margin = MarginContainer.new()
			margin.add_theme_constant_override("margin_left", 15)
			margin.add_theme_constant_override("margin_top", 100)
			margin.add_theme_constant_override("margin_right", 15)
			margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
			var grid = HFlowContainer.new()
			grid.name = tab_name + "Grid"
			grid.add_theme_constant_override("h_separation", 26)
			grid.add_theme_constant_override("v_separation", 16)
			grid.alignment = HFlowContainer.ALIGNMENT_CENTER
			grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			margin.add_child(grid)
			node.add_child(margin)
			_tabs[tab_name] = {"container": node, "grid": grid}
			tab_container.add_child(node)
			logger.debug("Added parser tab: " + tab_name + " with grid: " + grid.name)
	
	# If the library has been loaded before, check for removed items
	if _library.size() > 0:
		for tab_idx in _library.keys():
			var card_names := _library[tab_idx].keys() as Array
			for card_name in card_names:
				if library_manager.has_app(card_name):
					continue
				var card := _library[tab_idx][card_name] as Control
				_library[tab_idx].erase(card_name)
				card.queue_free()

	# Populate the installed games grid (tab 0)
	var modifiers: Array[Callable] = [
		library_manager.filter_installed,
		library_manager.sort_by_name,
	]
	var installed := library_manager.get_library_items(modifiers)
	await _populate_grid(installed_games_grid, installed, installed_tab_idx)

	# Populate the all games grid (tab 1)
	var all_items_sorted := all_items.duplicate()
	library_manager.sort_by_name.call(all_items_sorted)
	await _populate_grid(all_games_grid, all_items_sorted, all_games_tab_idx)

	# Populate parser-specific tabs
	for i in range(tabs_state.tabs_text.size()):
		var tab_name = tabs_state.tabs_text[i]
		var tab_idx = i
		if not tab_name in _tabs:
			logger.warn("Tab " + tab_name + " not found in _tabs")
			continue
		var grid = _tabs[tab_name]["grid"] as HFlowContainer
		if not grid:
			logger.error("No grid found for tab: " + tab_name)
			continue
		var parser_items = all_items if tab_name == "All Games" else installed if tab_name == "Installed" else all_items.filter(func(item): return tab_name in item.tags)
		# Sort parser items alphabetically
		if tab_name != "Installed" and tab_name != "All Games":
			library_manager.sort_by_name.call(parser_items)
		logger.debug("Populating " + tab_name + " with " + str(parser_items.size()) + " items")
		await _populate_grid(grid, parser_items, tab_idx)

# Builds a home card from the given library item
func _build_card(item: LibraryItem) -> GameCard:
	# Build a poster for each library item
	var card := card_scene.instantiate() as GameCard
	await card.set_library_item(item)

	# Listen for button presses and pass the library item with the state
	var on_button_up := func():
		launcher_state.data = {"item": item}
		menu_state_machine.push_state(launcher_state)
	card.button_up.connect(on_button_up)
	
	return card

# Populates the given grid with library items
func _populate_grid(grid: HFlowContainer, library_items: Array, tab_num: int) -> void:
	for i in range(library_items.size()):
		var item: LibraryItem = library_items[i]
		
		# Check to see if this library item should be hidden
		var is_hidden := settings_manager.get_library_value(item, "hidden", false) as bool
		if is_hidden:
			continue
		
		# If the card node already exists, move it to the correct place
		if tab_num in _library and item.name in _library[tab_num]:
			var card := _library[tab_num][item.name] as GameCard
			grid.move_child(card, i)
			continue
		
		# Build a card for each library item
		var card := await _build_card(item)

		# Listen for focus changes to keep track of our current selection
		# between state changes.
		card.focus_entered.connect(_on_focus_updated.bind(card, tab_num))
		
		# Listen for library item removed events
		var on_removed := func():
			_library[tab_num].erase(item.name)
		item.removed_from_library.connect(on_removed)
		item.hidden.connect(on_removed)
		
		# Add the card to the grid
		grid.add_child(card)
		
		# Keep track of all the library items so we can search them.
		if not tab_num in _library:
			_library[tab_num] = {}
		_library[tab_num][item.name] = card

# When an install is queued, connect signals to show a progress bar on the library card.
func _on_install_queued(req: InstallManager.Request) -> void:
	for tab_num in _library.keys():
		if not req.item.name in _library[tab_num]:
			continue
		var card := _library[tab_num][req.item.name] as GameCard
		card.value = 0
		card.show_progress = true
		var on_progress := func(progress: float):
			card.value = progress * 100
		req.progressed.connect(on_progress)
		var on_completed := func(success: bool):
			card.show_progress = false
			req.progressed.disconnect(on_progress)
		req.completed.connect(on_completed, CONNECT_ONE_SHOT)

# When an app is installed, ensure a card exists for it in the installed tab
func _on_installed(req: InstallManager.Request) -> void:
	pass

# When an app is uninstalled, ensure a card DOESN'T exist for it on the installed tab
func _on_uninstalled(req: InstallManager.Request) -> void:
	var tab_num := 0
	if not req.success:
		return
	if not tab_num in _library:
		return
	if not req.item.name in _library[tab_num]:
		return
	var card: Control = _library[tab_num][req.item.name]
	_library[tab_num].erase(req.item.name)
	if tab_num in _current_selection and _current_selection[tab_num] == card:
		_current_selection.erase(tab_num)
	card.queue_free()

# Called when a library card is focused
func _on_focus_updated(card: Control, tab: int) -> void:
	# Update the currently selected card
	_current_selection[tab] = card
	
	# Don't scroll to the card if mouse or touch is being used
	var input_manager := get_tree().get_first_node_in_group("InputManager")
	if input_manager:
		if (input_manager as InputManager).current_touches > 0:
			return
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			return
	
	# Get the scroll container for this card
	var scroll_container := tab_container.get_child(tab) as ScrollContainer
	if not scroll_container:
		return
	
	# Smoothly scroll to the card using a tween
	if tween:
		tween.kill()
	tween = get_tree().create_tween()
	tween.tween_property(scroll_container, "scroll_vertical", card.position.y - card.size.y/3, 0.25)

func _on_tab_container_tab_changed(tab: int) -> void:
	# Update the tab container current tab
	if tab >= 0 and tab < tab_container.get_tab_count():
		tab_container.current_tab = tab
	else:
		logger.warn("Tab index out of bounds: " + str(tab) + ", max: " + str(tab_container.get_tab_count() - 1))
		return
	
	# Get the child container to grab focus
	var container: ScrollContainer = tab_container.get_child(tab)
	if not container or container.get_child_count() == 0:
		logger.debug("No container or children for tab: " + str(tab))
		return
	var tab_name = tabs_state.tabs_text[tab] if tab < tabs_state.tabs_text.size() else str(tab)
	if not tab_name in _tabs:
		logger.warn("Tab " + tab_name + " not in _tabs")
		return
	var grid: HFlowContainer = _tabs[tab_name]["grid"]
	if not grid:
		logger.error("No grid found for tab: " + tab_name)
		return
	
	# If we had a previous selection, grab focus on that.
	if tab in _current_selection:
		if is_instance_valid(_current_selection[tab]):
			var card: Control = _current_selection[tab]
			if card.visible:
				card.grab_focus.call_deferred()
				return
		# If the selection is no longer valid, clear it from our current selection
		_current_selection.erase(tab)
	
	# Otherwise, focus the first entry on tab change
	for child in grid.get_children():
		if child is FocusGroup:
			child.grab_focus()
			break
		if not child is Control:
			continue
		if child.visible:
			child.grab_focus.call_deferred()
			break

func _on_tab_added(tab_text: String, node: ScrollContainer) -> void:
	if tab_text in ["Installed", "All Games"]:
		return  # Skip static tabs, handled in scene
	if tab_text in _tabs:
		logger.debug("Tab " + tab_text + " already exists, skipping addition")
		return
	# Add a MarginContainer and HFlowContainer to the ScrollContainer for game cards
	node.horizontal_scroll_mode = 0  # Match InstalledTab and AllGamesTab
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_top", 100)
	margin.add_theme_constant_override("margin_right", 15)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var grid = HFlowContainer.new()
	grid.name = tab_text + "Grid"
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 16)
	grid.alignment = HFlowContainer.ALIGNMENT_CENTER
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(grid)
	node.add_child(margin)
	_tabs[tab_text] = {"container": node, "grid": grid}
	tab_container.add_child(node)
	logger.debug("Tab added: " + tab_text + " with grid: " + grid.name)

func _on_tab_removed(tab_text: String) -> void:
	if not tab_text in _tabs:
		return
	var node := _tabs[tab_text]["container"] as Node
	_tabs.erase(tab_text)
	node.queue_free()
	logger.debug("Tab removed: " + tab_text)
