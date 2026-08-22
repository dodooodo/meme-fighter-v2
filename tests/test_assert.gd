# Responsibility: Tiny dependency-free headless test assertion helper.
# Owns: pass/fail count and console output.
# Does NOT own: production combat behavior.
# Dependencies: none.
class_name TestAssert
extends RefCounted

var passed: int = 0
var failed: int = 0

func that(condition: bool, message: String) -> void:
    if condition:
        passed += 1
        print("[PASS] ", message)
    else:
        failed += 1
        push_error("[FAIL] " + message)

func equal(actual: Variant, expected: Variant, message: String) -> void:
    that(actual == expected, "%s | expected=%s actual=%s" % [message, str(expected), str(actual)])

func near(actual: float, expected: float, epsilon: float, message: String) -> void:
    that(absf(actual - expected) <= epsilon, "%s | expected=%f actual=%f" % [message, expected, actual])
