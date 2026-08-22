extends SceneTree


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    var options := _parse_args(OS.get_cmdline_user_args())
    if options.has("error"):
        printerr(options["error"])
        _print_usage()
        quit(64)
        return
    if options.get("help", false):
        _print_usage()
        quit(0)
        return

    var result := BalanceTable.build_rows(options["character"])
    var errors: PackedStringArray = result["errors"]
    if not errors.is_empty():
        for error in errors:
            printerr("BALANCE EXPORT ERROR: " + error)
        quit(1)
        return
    var rows: Array[Dictionary] = result["rows"]
    var body := BalanceTable.to_csv(rows) if options["format"] == "csv" else BalanceTable.to_markdown(rows)
    var output_path: String = options["output"]
    if output_path == "-":
        print(body.trim_suffix("\n"))
    else:
        var file := FileAccess.open(output_path, FileAccess.WRITE)
        if file == null:
            printerr("BALANCE EXPORT ERROR: cannot write %s: %s" % [output_path, error_string(FileAccess.get_open_error())])
            quit(1)
            return
        file.store_string(body)
        file.close()
        print("BALANCE EXPORT PASS: %d rows -> %s" % [rows.size(), output_path])
    quit(0)


func _parse_args(args: PackedStringArray) -> Dictionary:
    var options := {"format": "csv", "output": "-", "character": &"", "help": false}
    var index := 0
    while index < args.size():
        var argument := args[index]
        if argument == "--help" or argument == "-h":
            options["help"] = true
            index += 1
            continue
        if argument not in ["--format", "--output", "--character"]:
            return {"error": "unknown argument: %s" % argument}
        if index + 1 >= args.size():
            return {"error": "missing value for %s" % argument}
        var value := args[index + 1]
        if argument == "--format":
            if value not in ["csv", "markdown"]:
                return {"error": "--format must be csv or markdown"}
            options["format"] = value
        elif argument == "--output":
            if value.is_empty():
                return {"error": "--output must not be empty"}
            options["output"] = value
        else:
            if value.is_empty():
                return {"error": "--character must not be empty"}
            options["character"] = StringName(value)
        index += 2
    return options


func _print_usage() -> void:
    print("Usage: ./scripts/export_balance.sh [--format csv|markdown] [--output PATH|-] [--character STABLE_ID]")
