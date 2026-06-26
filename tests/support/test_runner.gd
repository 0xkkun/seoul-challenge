extends Node

@export var suite_path := "res://tests/unit"
@export var suite_name := "Tests"

var _pass_count := 0
var _fail_count := 0
var _total_count := 0
var _current_failed := false
var _current_reason := ""
var _current_assertions := 0


func _ready() -> void:
	print("\n========================================")
	print("  %s" % suite_name)
	print("========================================\n")

	var scripts := _discover_test_scripts()
	if scripts.is_empty():
		_record_runner_failure("No test scripts found in %s" % suite_path)
	else:
		for script_path: String in scripts:
			_run_test_script(script_path)

	print("\n========================================")
	print("  Results: %d passed, %d failed out of %d total" % [_pass_count, _fail_count, _total_count])
	print("========================================\n")

	get_tree().quit(_fail_count)


func _discover_test_scripts() -> Array[String]:
	var scripts: Array[String] = []
	var dir := DirAccess.open(suite_path)
	if dir == null:
		return scripts
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.begins_with("test_") and file_name.ends_with(".gd"):
			var path := "%s/%s" % [suite_path, file_name]
			if FileAccess.get_file_as_string(path).contains("func test_"):
				scripts.append(path)
		file_name = dir.get_next()
	dir.list_dir_end()
	scripts.sort()
	return scripts


func _run_test_script(script_path: String) -> void:
	var script := load(script_path) as GDScript
	if script == null or not script.can_instantiate():
		_record_runner_failure("Could not instantiate test script: %s" % script_path)
		return

	var instance: Variant = script.new()
	if instance == null:
		_record_runner_failure("Could not create test instance: %s" % script_path)
		return

	add_child(instance)
	if instance.has_method("_set_runner"):
		instance.call("_set_runner", self)

	var methods: Array[String] = []
	for method: Dictionary in instance.get_method_list():
		var method_name := String(method["name"])
		if method_name.begins_with("test_"):
			methods.append(method_name)
	methods.sort()

	if methods.is_empty():
		_record_runner_failure("No test_* methods registered in %s" % script_path)
		instance.queue_free()
		return

	print("--- %s ---" % script_path.get_file().get_basename())
	for method_name: String in methods:
		_total_count += 1
		_current_failed = false
		_current_reason = ""
		_current_assertions = 0

		if instance.has_method("before_each"):
			instance.call("before_each")
		instance.call(method_name)
		if instance.has_method("after_each"):
			instance.call("after_each")

		if _current_failed:
			_fail_count += 1
			print("  [FAIL] %s: %s" % [method_name, _current_reason])
		elif _current_assertions == 0:
			_fail_count += 1
			print("  [FAIL] %s: no assertions executed" % method_name)
		else:
			_pass_count += 1
			print("  [PASS] %s" % method_name)

	instance.queue_free()


func _record_runner_failure(message: String) -> void:
	_total_count += 1
	_fail_count += 1
	print("[FAIL] %s" % message)


func assert_true(condition: bool, message: String = "") -> void:
	_current_assertions += 1
	if not condition:
		_current_failed = true
		_current_reason = message if message != "" else "condition was false"


func assert_false(condition: bool, message: String = "") -> void:
	assert_true(not condition, message if message != "" else "condition was true")


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	_current_assertions += 1
	if actual != expected:
		_current_failed = true
		var detail := "expected %s but got %s" % [str(expected), str(actual)]
		_current_reason = "%s: %s" % [message, detail] if message != "" else detail


func assert_not_null(value: Variant, message: String = "") -> void:
	_current_assertions += 1
	if value == null:
		_current_failed = true
		_current_reason = message if message != "" else "value was null"
