# Deterministic training dummy policy. Produces only canonical InputFrames.
class_name TrainingDummyInputSource
extends InputSource

enum GuardMode { OFF, STANDING, CROUCHING }
enum DummyMode { STAND, CROUCH, STAND_GUARD, CROUCH_GUARD, GUARD_AFTER_FIRST_HIT, JUMP, BACKSTEP }

var _dummy_mode: DummyMode = DummyMode.STAND
var _previous_held_bits: int = 0
var _fighter: Fighter = null
var _guard_after_hit_armed: bool = false
var _action_cooldown: int = 0

func bind_context(fighter: Fighter) -> void:
    _fighter = fighter

func set_dummy_mode(value: int) -> void:
    _dummy_mode = clampi(value, DummyMode.STAND, DummyMode.BACKSTEP)
    _guard_after_hit_armed = false
    _action_cooldown = 0

func dummy_mode() -> int: return _dummy_mode
func cycle_dummy_mode() -> int:
    set_dummy_mode((_dummy_mode + 1) % DummyMode.size())
    return _dummy_mode

# Compatibility with existing Guard UI/tests.
func set_guard_mode(value: int) -> void:
    match clampi(value, GuardMode.OFF, GuardMode.CROUCHING):
        GuardMode.STANDING: set_dummy_mode(DummyMode.STAND_GUARD)
        GuardMode.CROUCHING: set_dummy_mode(DummyMode.CROUCH_GUARD)
        _: set_dummy_mode(DummyMode.STAND)
func guard_mode() -> int:
    if _dummy_mode == DummyMode.STAND_GUARD: return GuardMode.STANDING
    if _dummy_mode == DummyMode.CROUCH_GUARD: return GuardMode.CROUCHING
    return GuardMode.OFF
func cycle_guard_mode() -> int:
    var next := (guard_mode() + 1) % GuardMode.size()
    set_guard_mode(next)
    return next

func mode_name() -> String:
    return DummyMode.keys()[_dummy_mode]

func sample(frame_number: int) -> InputFrame:
    var held := 0
    var x := 0
    var y := 0
    if _action_cooldown > 0: _action_cooldown -= 1
    match _dummy_mode:
        DummyMode.CROUCH:
            y = -1
        DummyMode.STAND_GUARD:
            held = InputFrame.InputButton.GUARD
        DummyMode.CROUCH_GUARD:
            y = -1; held = InputFrame.InputButton.GUARD
        DummyMode.GUARD_AFTER_FIRST_HIT:
            if _fighter != null:
                var read := _fighter.capture_combat_read()
                if int(read["hitstun_remaining"]) > 0 or int(read["blockstun_remaining"]) > 0:
                    _guard_after_hit_armed = true
            if _guard_after_hit_armed:
                held = InputFrame.InputButton.GUARD
        DummyMode.JUMP:
            if _action_cooldown <= 0 and (_fighter == null or _fighter.is_grounded()):
                y = 1; _action_cooldown = 60
        DummyMode.BACKSTEP:
            if _action_cooldown <= 0:
                var facing := int(_fighter.capture_combat_read()["facing"]) if _fighter != null else -1
                # Two-tap command on deterministic 3-frame micro-sequence.
                x = -facing; _action_cooldown = 3
            elif _action_cooldown == 1:
                var facing := int(_fighter.capture_combat_read()["facing"]) if _fighter != null else -1
                x = -facing
        _:
            pass
    var pressed := held & ~_previous_held_bits
    var released := _previous_held_bits & ~held
    _previous_held_bits = held
    return InputFrame.new(frame_number, x, y, held, pressed, released)

func reset() -> void:
    _previous_held_bits = 0
    _guard_after_hit_armed = false
    _action_cooldown = 0
