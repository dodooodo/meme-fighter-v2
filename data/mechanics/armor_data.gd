class_name ArmorData
extends Resource

enum SourceMask { STRIKE = 1, PROJECTILE = 2 }

@export_range(1, 16, 1) var max_absorbed_hits: int = 1
@export_range(1, 600, 1) var start_frame: int = 1
@export_range(1, 600, 1) var end_frame: int = 1
@export_flags("Strike", "Projectile") var valid_source_mask: int = SourceMask.STRIKE
