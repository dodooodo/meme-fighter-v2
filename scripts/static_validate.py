#!/usr/bin/env python3
"""Static architecture/resource contract checks runnable without the Godot binary."""
from pathlib import Path
import re, sys, json

ROOT = Path(__file__).resolve().parents[1]
errors=[]
passes=[]

def check(cond,msg):
    (passes if cond else errors).append(msg)

def text(rel):
    return (ROOT/rel).read_text(encoding='utf-8')

# Project shell / references.
project=text('project.godot')
check('run/main_scene="res://frontend/mode_select_scene.tscn"' in project, 'M8 main scene points to mode_select_scene.tscn')
check((ROOT/'battle/battle_scene.tscn').exists(), 'main battle scene exists')
path_re=re.compile(r'res://[A-Za-z0-9_./-]+')
for p in ROOT.rglob('*'):
    if p.suffix not in {'.gd','.tres','.tscn','.md'} or not p.is_file():
        continue
    body=p.read_text(encoding='utf-8')
    for ref in path_re.findall(body):
        rel=ref[len('res://'):].rstrip('`),]"\'')
        if '.' in Path(rel).name:
            check((ROOT/rel).exists(), f'{p.relative_to(ROOT)} reference exists: {ref}')

# Combat core architectural bans.
core_files=list((ROOT/'fighter').rglob('*.gd'))+list((ROOT/'battle/combat').rglob('*.gd'))+[ROOT/'battle/battle_simulation.gd']
for p in core_files:
    body=p.read_text(encoding='utf-8')
    for forbidden in ['RigidBody2D','CharacterBody2D','AnimationPlayer','AudioStreamPlayer','Camera2D','ProgressBar']:
        check(forbidden not in body, f'{p.relative_to(ROOT)} does not depend on {forbidden}')
    check('_physics_process' not in body and '_process(' not in body, f'{p.relative_to(ROOT)} has no SceneTree timing callback')

important=[
 'battle/battle_simulation.gd','battle/combat/collision_system.gd','battle/combat/combat_resolver.gd','battle/combat/strike_contact.gd','battle/combat/hit_result.gd','battle/combat/combat_event.gd',
 'fighter/fighter.gd','fighter/state_machine/fighter_state_machine.gd','fighter/moves/move_runner.gd',
 'fighter/moves/move_registry.gd','fighter/movement/movement_motor.gd','fighter/combat/combatant.gd',
 'fighter/combat/hitbox_owner.gd','fighter/input/input_frame.gd','fighter/input/input_parser.gd','fighter/input/action_intent.gd','fighter/input/input_buffer.gd',
 'fighter/moves/normal_attack_move_map.gd','data/move_set_data.gd','data/move_ids.gd'
]
for rel in important:
    header=text(rel)[:1600]
    check(all(tag in header for tag in ['# Responsibility:','# Owns:','# Does NOT own:','# Dependencies:']),
          f'{rel} documents responsibility/ownership/dependencies')

# M1.5/M2.1.5 canonical Input contract and Godot 4.7 enum naming.
input_frame=text('fighter/input/input_frame.gd')
enum_match=re.search(r'enum\s+InputButton\s*\{(.*?)\}', input_frame, re.S)
enum_body=enum_match.group(1) if enum_match else ''
check(enum_match is not None, 'InputFrame InputButton enum exists')
check(re.search(r'enum\s+Button\s*\{', input_frame) is None, 'Legacy InputFrame enum Button is removed')
for name in ['LIGHT','HEAVY','GUARD','SPECIAL','ULTIMATE']:
    check(re.search(rf'\b{name}\b\s*=', enum_body) is not None, f'InputFrame InputButton contains {name}')
for forbidden in ['JUMP','CROUCH','THROW','DASH','BACKSTEP']:
    check(re.search(rf'\b{forbidden}\b\s*=', enum_body) is None, f'InputFrame InputButton excludes {forbidden}')
for field in ['frame_number','direction_x','direction_y','held_bits','pressed_bits','released_bits']:
    check(re.search(rf'var\s+{field}\s*:', input_frame) is not None, f'InputFrame canonical field exists: {field}')

legacy_button_refs=[]
for p in list((ROOT/'fighter').rglob('*.gd')) + list((ROOT/'battle').rglob('*.gd')) + list((ROOT/'data').rglob('*.gd')):
    if 'InputFrame.Button.' in p.read_text(encoding='utf-8'):
        legacy_button_refs.append(str(p.relative_to(ROOT)))
check(not legacy_button_refs, 'No gameplay GDScript references legacy InputFrame.Button')

parser=text('fighter/input/input_parser.gd')
for prop in ['world_left_held','world_right_held','up_held','down_held','forward_held','back_held',
             'light_pressed','light_held','light_released','heavy_pressed','heavy_held','heavy_released',
             'guard_pressed','guard_held','guard_released','special_pressed','special_held','special_released',
             'ultimate_pressed','ultimate_held','ultimate_released']:
    check(re.search(rf'var\s+{prop}\s*:\s*bool', parser) is not None, f'InputParser exposes {prop}')
check('Input.is_' not in parser and 'KEY_' not in parser, 'InputParser has no device polling/key dependency')

keyboard=text('fighter/input/keyboard_input_source.gd')
check('direction_y = 1 if up else -1' in keyboard, 'KeyboardInputSource maps Up/Down only through direction_y')
check('InputFrame.InputButton.ULTIMATE' in keyboard, 'KeyboardInputSource produces Ultimate InputButton bit')
scene=text('battle/battle_scene.gd')
wiring_m8 = text('battle/match/battle_input_wiring.gd')
check('KEY_W, KEY_A, KEY_S, KEY_D, KEY_U, KEY_I, KEY_J, KEY_K, KEY_L' in wiring_m8,
      'P1 desktop debug mapping is WASD + U/I/J/K/L')

# MoveSet / Registry migration.
character=text('data/character_data.gd')
check(re.search(r'@export\s+var\s+move_set\s*:\s*MoveSetData', character) is not None, 'CharacterData owns MoveSetData')
check(re.search(r'@export\s+var\s+stand_light\b', character) is None, 'CharacterData no longer owns stand_light directly')
check(re.search(r'@export\s+var\s+stand_heavy\b', character) is None, 'CharacterData does not own stand_heavy directly')
check((ROOT/'data/move_set_data.gd').exists(), 'MoveSetData exists')
check((ROOT/'fighter/moves/move_registry.gd').exists(), 'MoveRegistry exists')
registry=text('fighter/moves/move_registry.gd')
for api in ['func configure(','func has_move(','func get_move(','func validation_errors(']:
    check(api in registry, f'MoveRegistry API exists: {api[:-1]}')
check('Duplicate MoveData id' in registry, 'MoveRegistry detects duplicate move IDs')
check('contains null MoveData' in registry, 'MoveRegistry detects null MoveData')

generic=text('data/characters/generic_fighter.tres')
check('move_set = SubResource("MoveSet_generic")' in generic, 'Generic Fighter references MoveSetData')
check('ExtResource("3_light")' in generic and 'moves =' in generic, 'Generic Fighter MoveSet contains existing stand_light resource')
check('res://data/moves/stand_heavy.tres' in generic and 'ExtResource("6_heavy")' in generic, 'Generic Fighter MoveSet contains Stand Heavy resource')
check('res://data/moves/crouch_low.tres' in generic and 'ExtResource("7_low")' in generic, 'Generic Fighter MoveSet contains Crouch Low resource')
check(re.search(r'@export\s+var\s+crouch_low\b', character) is None, 'CharacterData does not own crouch_low fixed move slot')
check('stand_light =' not in generic, 'Generic Fighter no longer uses direct stand_light property')

state=text('fighter/state_machine/fighter_state_machine.gd')
pre_tick_match=re.search(r'func\s+pre_tick\s*\((.*?)\)\s*->', state, re.S)
pre_tick_sig=pre_tick_match.group(1) if pre_tick_match else ''
check('stand_light' not in pre_tick_sig, 'StateMachine pre_tick no longer takes stand_light argument')
check('registry: MoveRegistry' in pre_tick_sig, 'StateMachine receives MoveRegistry dependency')
check('ActionMoveMap.ground_move_id_for_intent(intent)' in state, 'StateMachine maps contextual ActionIntent before registry lookup')
check('registry.get_move(move_id)' in state, 'StateMachine retrieves normal attacks through MoveRegistry')
check('stand_heavy' not in pre_tick_sig, 'StateMachine pre_tick has no Stand Heavy MoveData argument')
check('Input.' not in state and 'KEY_' not in state, 'StateMachine has no direct Input singleton/key dependency')

fighter=text('fighter/fighter.gd')
check('var move_registry: MoveRegistry' in fighter, 'Fighter composition root owns runtime MoveRegistry component')
check('move_registry.configure(data.move_set)' in fighter, 'Fighter configures registry from CharacterData MoveSet')
check('var input_buffer: InputBuffer' in fighter, 'Fighter composition root owns InputBuffer component')
fighter_lines=fighter.count('\n')+1
check(fighter_lines < 280, f'fighter.gd remains compact composition root after generic mechanics composition ({fighter_lines} lines)')

# Stand Light data contract unchanged.
light=text('data/moves/stand_light.tres')
expected={'startup_frames':5,'active_frames':3,'recovery_frames':10,'damage':50,'hitstun_frames':14,'blockstun_frames':10,'hitstop_attacker':4,'hitstop_defender':4}
for key,value in expected.items():
    check(re.search(rf'^{re.escape(key)}\s*=\s*{value}\s*$', light, re.M) is not None, f'Stand Light {key}={value}')
check('id = &"stand_light"' in light, 'Stand Light stable move ID preserved')

# M2.1 Stand Heavy and deterministic normal-action buffer contracts.
move_ids=text('data/move_ids.gd')
check(re.search(r'const\s+STAND_HEAVY\s*:\s*StringName\s*=\s*&"stand_heavy"', move_ids) is not None,
      'MoveIds.STAND_HEAVY exists with stable ID')
check((ROOT/'data/moves/stand_heavy.tres').exists(), 'Stand Heavy resource exists')
heavy=text('data/moves/stand_heavy.tres')
heavy_expected={
    'startup_frames':11,'active_frames':4,'recovery_frames':20,'damage':95,
    'hitstun_frames':19,'blockstun_frames':13,'hitstop_attacker':6,'hitstop_defender':6,
    'knockback_y_units':0,
}
for key,value in heavy_expected.items():
    check(re.search(rf'^{re.escape(key)}\s*=\s*{value}\s*$', heavy, re.M) is not None, f'Stand Heavy {key}={value}')
check('id = &"stand_heavy"' in heavy, 'Stand Heavy stable move ID preserved')
light_knockback=re.search(r'^knockback_x_units\s*=\s*(\d+)\s*$', light, re.M)
heavy_knockback=re.search(r'^knockback_x_units\s*=\s*(\d+)\s*$', heavy, re.M)
check(light_knockback is not None and heavy_knockback is not None and int(heavy_knockback.group(1)) > int(light_knockback.group(1)),
      'Stand Heavy horizontal knockback is greater than Stand Light')

normal_map=text('fighter/moves/normal_attack_move_map.gd')
action_map=text('fighter/moves/action_move_map.gd')
check('func move_id_for_intent(intent: ActionIntent)' in normal_map and 'ActionMoveMap.ground_move_id_for_intent(intent)' in normal_map, 'NormalAttackMoveMap remains a compatibility facade over ActionMoveMap')
check('InputFrame.InputButton.LIGHT' in action_map and 'MoveIds.STAND_LIGHT' in action_map, 'Action move mapping keeps LIGHT -> STAND_LIGHT')
check('InputFrame.InputButton.HEAVY' in action_map and 'MoveIds.STAND_HEAVY' in action_map, 'Action move mapping keeps non-forward HEAVY -> STAND_HEAVY')
check('moves[0]' not in action_map and 'moves[1]' not in action_map, 'Action meaning is not derived from MoveSet array index')

action_intent=text('fighter/input/action_intent.gd')
check((ROOT/'fighter/input/action_intent.gd').exists(), 'ActionIntent exists')
for field in ['action_button','source_frame','direction_x','direction_y','facing_at_request','forward_held','back_held']:
    check(re.search(rf'var\s+{field}\s*:', action_intent) is not None, f'ActionIntent stores primitive context: {field}')
check('clampi(p_direction_x, -1, 1)' in action_intent and 'clampi(p_direction_y, -1, 1)' in action_intent,
      'ActionIntent clamps world direction to canonical range')
check('facing_at_request = -1 if p_facing_at_request < 0 else 1' in action_intent,
      'ActionIntent normalizes facing to -1/+1')
for forbidden in ['Node','MoveData','MoveRunner','MoveRegistry','Callable','Signal']:
    check(re.search(rf'var\s+\w+\s*:\s*{forbidden}\b', action_intent) is None, f'ActionIntent owns no {forbidden} reference')
check('func copy() -> ActionIntent' in action_intent, 'ActionIntent provides safe primitive copy semantics')

check('func normal_attack_pressed_intent() -> ActionIntent' in parser, 'InputParser produces contextual ActionIntent')
check('ActionIntent.new(' in parser and '_source_frame' in parser and '_direction_y' in parser and '_facing_at_parse' in parser,
      'InputParser captures source frame, direction, and facing at request time')
heavy_pos=parser.find('if heavy_pressed:')
light_pos=parser.find('elif light_pressed:')
check(heavy_pos >= 0 and light_pos > heavy_pos, 'InputParser preserves HEAVY-over-LIGHT same-frame tie-break')

input_buffer=text('fighter/input/input_buffer.gd')
check(re.search(r'const\s+DEFAULT_BUFFER_FRAMES\s*:\s*int\s*=\s*5', input_buffer) is not None, 'InputBuffer default window is 5 simulation frames')
check(re.search(r'var\s+_buffered_intent\s*:\s*ActionIntent', input_buffer) is not None, 'InputBuffer stores ActionIntent, not raw action int')
check('_buffered_intent = intent.copy()' in input_buffer, 'InputBuffer copies incoming intent for snapshot stability')
check('_expiry_frame = _buffered_intent.source_frame + maxi(0, window_frames)' in input_buffer,
      'InputBuffer expiry derives from ActionIntent source simulation frame')
check('Timer' not in input_buffer and 'delta' not in input_buffer and 'get_tree' not in input_buffer and 'get_ticks' not in input_buffer,
      'InputBuffer does not use timers, delta, SceneTree, or wall-clock timing')
input_buffer_code='\n'.join(line for line in input_buffer.splitlines() if not line.lstrip().startswith('#'))
check('start_move(' not in input_buffer_code and 'MoveData' not in input_buffer_code and 'MoveRegistry' not in input_buffer_code and 'MoveRunner' not in input_buffer_code,
      'InputBuffer owns no move execution/data dependency')
check(all(token in input_buffer for token in ['InputFrame.InputButton.LIGHT','InputFrame.InputButton.HEAVY','InputFrame.InputButton.SPECIAL','InputFrame.InputButton.ULTIMATE']),
      'InputBuffer accepts all four offensive ActionIntent buttons while Guard remains state input')
for legacy_api in ['buffer_action(', 'peek_action(', 'consume_action(']:
    check(legacy_api not in input_buffer, f'Legacy raw buffer API removed: {legacy_api[:-1]}')
check('expire_if_needed(current_frame)' in state, 'StateMachine advances InputBuffer expiry inside simulation tick')
check('input_buffer.clear()' in state and 'combatant.hitstun_remaining > 0' in state and 'combatant.is_ko' in state,
      'StateMachine clears contextual normal buffer for Hitstun/KO policy')
check('parser.action_pressed_intent()' in state and 'input_buffer.buffer_intent(intent)' in state,
      'StateMachine captures prioritized parsed ActionIntent into InputBuffer')
check('input_buffer.peek_intent(current_frame)' in state and 'input_buffer.consume_intent(current_frame)' in state,
      'StateMachine owns buffered intent legality/consumption')

hitbox_owner=text('fighter/combat/hitbox_owner.gd')
check('_tracked_attack_instance_id' in hitbox_owner and '_hit_defender_ids' in hitbox_owner and 'can_hit_defender' in hitbox_owner,
      'AttackInstance duplicate-hit protection remains present')
debug=text('debug/debug_overlay.gd')
check('debug_summary(simulation.frame_number)' in debug, 'Debug overlay provides simulation frame to read-only buffer diagnostics')
check(all(token in fighter for token in ['phase=%s','buf=%s','@F%d dir=(%d,%d)','fwd=%s','back=%s','exp=%d']),
      'Debug summary exposes contextual buffered intent without mutation')

# Regression suite contracts.
m1=text('tests/combat/test_milestone_1.gd')
for test_name in ['_test_fixed_clock_render_rate_independence','_test_input_history_is_60_frame_circular_buffer',
                  '_test_same_attack_instance_damages_only_once','_test_hitstop_freezes_move_timeline',
                  '_test_pushboxes_prevent_overlap','_test_ko_clamps_hp_and_blocks_attack',
                  '_test_same_frame_trade_is_preserved']:
    check(test_name in m1, f'M0/M1 regression exists: {test_name}')
m15=text('tests/migration/test_milestone_1_5.gd')
for token in ['JUMP','CROUCH','direction_y','InputFrame.InputButton.ULTIMATE','Facing Right','Facing Left',
              'Duplicate MoveData IDs','MoveIds.STAND_LIGHT','move_registry']:
    check(token in m15, f'M1.5 migration regression covers: {token}')
run=text('tests/run_tests.gd')
check(all(token in run for token in ['MILESTONE_1_SUITE','MILESTONE_1_5_SUITE','MILESTONE_2_1_SUITE','MILESTONE_2_1_5_SUITE','MILESTONE_2_2_SUITE']), 'headless runner executes M0/M1/M1.5/M2.1/M2.1.5/M2.2 suites')
m21=text('tests/combat/test_milestone_2_1.gd')
for token in ['MoveIds.STAND_HEAVY','startup is exactly 11F','active is exactly 4F','recovery is exactly 20F',
              'Heavy four-frame Active overlap','Buffered Light starts','Buffered Heavy starts','Latest-input-wins',
              'KO clears normal attack buffer','Hitstun clears normal attack buffer','Mixed trade applies P2 Heavy result']:
    check(token in m21, f'M2.1 regression covers: {token}')

m215=text('tests/migration/test_milestone_2_1_5.gd')
for token in ['InputFrame.InputButton','Down+Light','Up+Heavy','Facing Right','Facing Left',
              'Same-frame LIGHT+HEAVY','Existing intent Down context','Latest intent replaces source frame',
              'Buffer owns a safe copy','M2.2 consumes preserved request-frame Down context as Crouch Low']:
    check(token in m215, f'M2.1.5 regression covers: {token}')
check('MoveIds.GROUND_THROW' in state and 'MoveIds.GROUND_THROW' in action_map, 'M2 Complete introduces stable Ground Throw mapping without legacy MoveIds.THROW')

# M2.2 Ground Defense / Strike Outcome architecture contracts.
strike_contact=text('battle/combat/strike_contact.gd')
check((ROOT/'battle/combat/strike_contact.gd').exists(), 'StrikeContact geometry contract exists')
for field in ['attacker_id','defender_id','move_id','attack_instance_id','hit_id','hit_position','incoming_direction_x']:
    check(re.search(rf'var\s+{field}\s*:', strike_contact) is not None, f'StrikeContact stores geometry fact: {field}')
for forbidden in ['Fighter','MoveData','HitResult','GuardPosture','blockstun','AnimationPlayer','InputSource']:
    code='\n'.join(line for line in strike_contact.splitlines() if not line.lstrip().startswith('#'))
    check(forbidden not in code, f'StrikeContact owns no outcome/runtime dependency: {forbidden}')

move_data=text('data/move_data.gd')
check(re.search(r'enum\s+HitLevel\s*\{[^}]*HIGH[^}]*MID[^}]*LOW', move_data, re.S) is not None, 'MoveData defines typed HitLevel HIGH/MID/LOW enum')
check('@export_enum("HIGH", "MID", "LOW") var hit_level: int' in move_data, 'MoveData HitLevel is inspector-editable typed int contract')
check('hit_level = &"MID"' not in light and 'hit_level = &"MID"' not in heavy, 'Existing normals no longer use raw MID StringName')
check(re.search(r'^hit_level\s*=\s*1\s*$', light, re.M) is not None and re.search(r'^hit_level\s*=\s*1\s*$', heavy, re.M) is not None, 'Stand Light/Heavy migrate to HitLevel.MID enum value')

check(re.search(r'const\s+CROUCH_LOW\s*:\s*StringName\s*=\s*&"crouch_low"', move_ids) is not None, 'MoveIds.CROUCH_LOW exists')
check((ROOT/'data/moves/crouch_low.tres').exists(), 'Crouch Low resource exists')
low=text('data/moves/crouch_low.tres')
low_expected={'startup_frames':8,'active_frames':3,'recovery_frames':16,'damage':60,'hitstun_frames':15,'blockstun_frames':11,'hitstop_attacker':4,'hitstop_defender':4,'knockback_x_units':600,'knockback_y_units':0,'hit_level':2}
for key,value in low_expected.items():
    check(re.search(rf'^{re.escape(key)}\s*=\s*{value}\s*$', low, re.M) is not None, f'Crouch Low {key}={value}')
check('id = &"crouch_low"' in low, 'Crouch Low stable move ID exists')
check('offset = Vector2(68, -38)' in low and 'size = Vector2(92, 36)' in low, 'Crouch Low uses configured low static hitbox')
check('intent.direction_y < 0' in action_map and 'MoveIds.CROUCH_LOW' in action_map, 'Request-frame Down+Light maps to CROUCH_LOW')
check('InputFrame.InputButton.HEAVY' in action_map and 'MoveIds.STAND_HEAVY' in action_map and 'CROUCH_HEAVY' not in action_map, 'Down context does not create a Crouch Heavy mapping')

for state_name in ['CROUCH','GUARD','BLOCKSTUN']:
    check(re.search(rf'\b{state_name},', state) is not None, f'FighterStateMachine includes {state_name} state')
for posture in ['NONE','STANDING','CROUCHING']:
    check(re.search(rf'\b{posture},', state) is not None, f'GuardPosture includes {posture}')
check('if parser.guard_held:' in state and '_enter_guard(parser)' in state, 'StateMachine owns voluntary Guard transition from normalized parser input')
check('guard_posture = GuardPosture.CROUCHING if parser.down_held else GuardPosture.STANDING' in state, 'StateMachine derives standing/crouching Guard posture from Down')
check('combatant.blockstun_remaining > 0' in state and 'transition_to(State.BLOCKSTUN)' in state, 'StateMachine owns forced BLOCKSTUN reaction state')
check('input_buffer.clear()' not in re.search(r'if combatant\.blockstun_remaining > 0:(.*?)(?=\n\s*if|\n\s*$)', state, re.S).group(1) if re.search(r'if combatant\.blockstun_remaining > 0:(.*?)(?=\n\s*if|\n\s*$)', state, re.S) else True, 'Blockstun path does not clear normal attack buffer')
guard_policy_pos=state.find('# Voluntary Guard remains grounded-only and has priority over every buffered offense')
ground_start_pos=state.find('_try_start_buffered_ground_action(')
check(guard_policy_pos >= 0 and ground_start_pos > guard_policy_pos, 'Guard priority is evaluated before buffered grounded offense starts')

collision=text('battle/combat/collision_system.gd')
collision_code='\n'.join(line for line in collision.splitlines() if not line.lstrip().startswith('#'))
check('func build_strike_contact(' in collision and 'StrikeContact.new()' in collision, 'CollisionSystem builds StrikeContact geometry candidates')
for forbidden in ['guard_held','GuardPosture','blockstun','receive_block','ResultType.BLOCK']:
    check(forbidden not in collision_code, f'CollisionSystem remains geometry-only: no {forbidden}')
check('result_type = HitResult.ResultType.HIT' not in collision_code, 'CollisionSystem no longer classifies strike contact as HIT')
check('incoming_direction_x = 1 if attacker.movement_motor.sim_position.x >= defender.movement_motor.sim_position.x else -1' in collision, 'CollisionSystem captures incoming side from simulation positions')

resolver=text('battle/combat/combat_resolver.gd')
check('func resolve_strike_contact(' in resolver and '-> HitResult' in resolver, 'CombatResolver owns contact -> final HitResult resolution')
check('HitResult.ResultType.BLOCK' in resolver and 'HitResult.ResultType.HIT' in resolver, 'CombatResolver centrally classifies HIT/BLOCK')
check('_is_attack_from_front' in resolver and 'contact.incoming_direction_x == defender.movement_motor.facing' in resolver, 'CombatResolver owns front-side Guard rule')
check('MoveData.HitLevel.HIGH' in resolver and 'MoveData.HitLevel.MID' in resolver and 'MoveData.HitLevel.LOW' in resolver, 'CombatResolver owns typed standing/crouching HitLevel matrix')
check('receive_block(result.chip_damage, result.blockstun_frames, result.hitstop_defender)' in resolver, 'CombatResolver applies chip/blockstun/block hitstop through Combatant.receive_block')
check('record_hit(result.attack_instance_id, defender.fighter_id, result.hit_id)' in resolver and resolver.count('record_hit(result.attack_instance_id, defender.fighter_id, result.hit_id)') >= 2, 'HIT and BLOCK both record AttackInstance+HitID defender contact')
check('result.knockback_x_units = 0' in resolver and 'result.hitstun_frames = 0' in resolver, 'BLOCK final result has no hit knockback or hitstun')

combatant=text('fighter/combat/combatant.gd')
check('func receive_block(' in combatant, 'Combatant has dedicated receive_block path')
check('blockstun_remaining = maxi(0, blockstun)' in combatant, 'receive_block applies blockstun separately from hitstun')
check('hp = clampi(hp - maxi(0, chip_damage)' in combatant, 'receive_block applies result chip damage rather than hard-coded zero')

event=text('battle/combat/combat_event.gd')
check(re.search(r'enum\s+EventType\s*\{[^}]*BLOCK', event, re.S) is not None, 'CombatEvent.EventType.BLOCK exists')
check('static func block(' in event and 'event.type = EventType.BLOCK' in event, 'CombatEvent.block factory exists')

hit_result=text('battle/combat/hit_result.gd')
check('var hit_level: int' in hit_result and 'var incoming_direction_x: int' in hit_result, 'HitResult carries typed HitLevel and incoming side')
check('BLOCK,' in hit_result, 'HitResult.BLOCK remains an enabled final outcome')

# Preserve fixed contact -> resolve -> apply ordering for same-frame trades.
battle=text('battle/battle_simulation.gd')
contacts_build=battle.find('var strike_contacts: Array[StrikeContact] = []')
contacts_resolve=battle.find('var strike_results: Array[HitResult] = []')
contacts_apply=battle.find('for result: HitResult in strike_results:')
check(contacts_build >= 0 and contacts_resolve > contacts_build, 'BattleSimulation builds both StrikeContacts before outcome resolution')
check(contacts_apply > contacts_resolve, 'BattleSimulation resolves all final HitResults before applying fighter strikes')
check('strike_contacts.append_array(collision_system.build_strike_contacts(fighter_a, fighter_b))' in battle and 'strike_contacts.append_array(collision_system.build_strike_contacts(fighter_b, fighter_a))' in battle and contacts_apply > contacts_resolve, 'BattleSimulation applies canonical pre-resolved strike results in stable contact order')

# M2 Complete adds movement commands as states/recognition, never as InputFrame button bits or MoveData dash/jump moves.
check('const AIR_ATTACK' in move_ids and 'const GROUND_THROW' in move_ids, 'M2 Complete adds only attack-like Air Attack/Ground Throw stable Move IDs')
check('const DASH' not in move_ids and 'const BACKSTEP' not in move_ids and 'const JUMP' not in move_ids, 'Jump/Dash/Backstep remain movement-state commands rather than MoveData IDs')
for required_state in ['AIRBORNE','JUMP','AIR_ATTACK','THROWN','KNOCKDOWN','GETUP','DASH_FORWARD','BACKSTEP']:
    check(re.search(rf'\b{required_state},', state) is not None, f'M2 Complete includes {required_state} Fighter state/root')
move_runner=text('fighter/moves/move_runner.gd')
check('CROUCH_LOW' not in move_runner and 'crouch_low' not in move_runner, 'MoveRunner remains generic with no Crouch Low hard-code')
check('func finalize_tick(frozen_by_hitstop: bool)' in move_runner and 'or frozen_by_hitstop' in move_runner, 'MoveRunner still freezes timeline during gameplay hitstop')

# M2 Complete Gate A-E architecture/resource contracts.
air_move=text('data/moves/air_attack.tres')
throw_move=text('data/moves/ground_throw.tres')
movement=text('fighter/movement/movement_motor.gd')
direction_recognizer=text('fighter/input/direction_command_recognizer.gd')
throw_system=text('battle/combat/throw_system.gd')
frame_stepper=text('debug/frame_stepper.gd')
stress_test=text('tests/stress/test_simulation_stress.gd')
snapshot_codec=text('battle/simulation/fighter_snapshot_codec.gd')
battle_snapshot_codec=text('battle/simulation/battle_snapshot_codec.gd')
hasher=text('battle/simulation/battle_state_hasher.gd')

check(re.search(r'enum\s+RootState\s*\{[^}]*AIRBORNE', state, re.S) is not None, 'Airborne root exists')
check(all(re.search(rf'\b{name},', state) for name in ['JUMP','AIR_ATTACK']), 'Jump and Air Attack states exist')
check('var up_pressed: bool' in parser and 'previous_frame.direction_y <= 0' in parser, 'Up edge is derived from InputHistory frames')
check('delta' not in movement and 'Vector2i' in movement and 'sim_position.y += velocity_units.y' in movement, 'Air movement uses integer per-tick integration with no delta')
for key,value in {'startup_frames':6,'active_frames':4,'recovery_frames':12,'damage':70,'hitstun_frames':14,'blockstun_frames':10,'hitstop_attacker':4,'hitstop_defender':4,'knockback_x_units':700,'knockback_y_units':-350,'hit_level':0}.items():
    check(re.search(rf'^{key}\s*=\s*{value}\s*$', air_move, re.M) is not None, f'Air Attack {key}={value}')
check('air_move_id_for_intent' in action_map and action_map.count('MoveIds.AIR_ATTACK') >= 1 and 'InputFrame.InputButton.LIGHT' in action_map and 'InputFrame.InputButton.HEAVY' in action_map, 'Air Light/Heavy map to the same Air Attack')
check('knockback_velocity_y_units' in combatant and 'result.knockback_y_units' in resolver and 'combatant.knockback_velocity_y_units' in movement, 'Vertical knockback is connected through result/combatant/movement')
hitstop_branch=re.search(r'if combatant\.hitstop_remaining > 0:(.*?)(?=\n\s*if combatant\.is_ko)', movement, re.S)
check(hitstop_branch is not None and 'velocity_units = Vector2i.ZERO' not in hitstop_branch.group(1), 'Hitstop freezes integration without clearing vertical velocity')
check('if a.movement_motor.is_airborne() or b.movement_motor.is_airborne()' in collision, 'Pushbox separation is skipped when either fighter is airborne')
check('# 13. Facing + sparse diagnostics.' in battle and '_update_facings()' in battle and battle.find('_update_facings()', battle.find('# 13. Facing + sparse diagnostics.')) >= 0, 'Facing update remains deterministic after active/post-round settlement')

check((ROOT/'data/moves/ground_throw.tres').exists() and 'id = &"ground_throw"' in throw_move, 'Ground Throw resource exists with stable ID')
check('throw_box' in move_data and 'throw_box = SubResource' in throw_move and 'hitbox =' not in throw_move, 'Ground Throw uses separate throw_box and no strike hitbox')
check('intent.forward_held' in action_map and 'MoveIds.GROUND_THROW' in action_map, 'Forward+Heavy request-frame context maps Ground Throw')
check('air_move_id_for_intent' in action_map and 'MoveIds.GROUND_THROW' not in action_map.split('static func air_move_id_for_intent',1)[1], 'Air Heavy maps Air Attack and never Throw')
throw_system_code='\n'.join(line for line in throw_system.splitlines() if not line.lstrip().startswith('#'))
for forbidden in ['hp =','receive_hit','receive_throw','transition_to','AnimationPlayer']:
    check(forbidden not in throw_system_code, f'ThrowSystem stays geometry-only: no {forbidden}')
check('HitResult.ResultType.THROW' in resolver and 'resolve_throw_contact' in resolver and 'apply_throw_result' in resolver, 'HitResult.THROW is resolved/applied through CombatResolver')
check('State.GUARD' in re.search(r'func is_throwable\(\).*?func is_strike_target', state, re.S).group(0), 'Guard is throwable')
check('State.GROUND_ATTACK' not in re.search(r'func is_throwable\(\).*?func is_strike_target', state, re.S).group(0), 'Ground Attack is not throwable')

check('InputHistory' in direction_recognizer and 'TOTAL_WINDOW_FRAMES: int = 12' in direction_recognizer and 'MAX_NEUTRAL_GAP_FRAMES: int = 6' in direction_recognizer, 'Dash/Backstep recognition uses InputHistory with 12F/6F leniency')
check('DASH_FORWARD' in state and 'BACKSTEP' in state, 'Dash/Backstep states exist')
check('State.GETUP, State.THROWN, State.KNOCKDOWN, State.KO' in state and 'temporary greybox rule' in state, 'GetUp temporary strike protection is explicit')
check('State.GETUP' not in re.search(r'func is_throwable\(\).*?func is_strike_target', state, re.S).group(0), 'GetUp is not throwable')

check((ROOT/'debug/frame_stepper.gd').exists() and 'request_advance(1)' not in frame_stepper and 'func request_advance' in frame_stepper, 'FrameStepper exists as generic simulation-clock control')
check(all(token in scene for token in ['KEY_F3','KEY_F4','KEY_F5','request_advance(1, clock)','request_advance(5, clock)']), 'F3/F4/F5 debug pause and exact frame-advance bindings exist')
check((ROOT/'tests/stress/test_simulation_stress.gd').exists() and '10000' in stress_test, '10,000-frame deterministic stress test exists')

check('return BattleSnapshotCodec.capture(self)' in battle and 'BattleSnapshotCodec.restore(self, snapshot)' in battle, 'capture_state/restore_state are real snapshot codec calls, not placeholders')
check('input_history_slots' in snapshot_codec and 'restore_slots' in snapshot_codec and 'input_history_write_index' in snapshot_codec, 'InputHistory full circular state is captured/restored')
check('current_move_id' in snapshot_codec and 'move_registry' in snapshot_codec and 'restore_runtime' in snapshot_codec, 'MoveRunner snapshot restores by stable move ID through registry')
check('contacted_defender_ids' in snapshot_codec and 'restore_contact_registry' in snapshot_codec, 'AttackInstance contact registry is captured/restored')
check('ActionIntentSnapshot.from_intent' in snapshot_codec and 'to_intent()' in snapshot_codec, 'Buffered ActionIntent snapshot is deep value reconstruction')
check('clear_pending_presentation_events()' in battle_snapshot_codec and 'func clear_pending_presentation_events()' in battle and '_event_queue.clear()' in battle, 'Restore clears pending presentation events by documented policy')
hasher_code='\n'.join(line for line in hasher.splitlines() if not line.lstrip().startswith('#'))
check('sha256_text()' in hasher_code and 'get_instance_id' not in hasher_code and 'get_instance_id()' not in hasher_code and '_canonical_variant' in hasher_code and 'keys.sort' in hasher_code, 'BattleStateHasher canonicalizes Dictionary/Array values with explicit sorted keys and no instance IDs')

# This milestone explicitly does not add network/matchmaking gameplay code.
gameplay_gd='\n'.join('\n'.join(line for line in p.read_text(encoding='utf-8').splitlines() if not line.lstrip().startswith('#')) for p in list((ROOT/'fighter').rglob('*.gd')) + list((ROOT/'battle').rglob('*.gd')))
for forbidden in ['ENetMultiplayerPeer','MultiplayerSpawner','MultiplayerSynchronizer','matchmaking','WebSocketMultiplayerPeer']:
    check(forbidden not in gameplay_gd, f'No networking/matchmaking code introduced: {forbidden}')

# New gate suites are wired while all previous suites remain.
for token in ['MILESTONE_2_3_AIR_SUITE','MILESTONE_2_4_THROW_MOBILITY_SUITE','MILESTONE_2_4_KNOCKDOWN_SUITE','FRAME_STEPPER_SUITE','SNAPSHOT_SUITE','STRESS_SUITE']:
    check(token in run, f'Headless runner includes new suite: {token}')

# M2.2 regression suite coverage.
m22=text('tests/combat/test_milestone_2_2.gd')
for token in ['Down held from Idle enters CROUCH','Request-frame Down+Light maps to CROUCH_LOW','Crouch Low startup is 8F',
              'Buffered Down+Light remains CROUCH_LOW','Voluntary Guard has priority','Standing Guard blocks MID',
              'Crouching Guard blocks LOW','Supported Guard HitLevel still loses to attack from behind',
              'Standing Guard loses to real Crouch Low','Crouching Guard blocks real Crouch Low',
              'resolves BLOCK once per AttackInstanceID','Normal Light can buffer during Blockstun',
              'Buffered normal cannot bypass held Guard','block hitstop freezes MoveRunner timeline','CombatEvent.block creates BLOCK']:
    check(token in m22, f'M2.2 regression covers: {token}')

# Debug remains read-only and exposes defense state.
check('guard=%s' in fighter and 'bs=%d' in fighter and 'state_machine.guard_posture_name()' in fighter, 'Debug summary exposes GuardPosture and Blockstun')
debug_code='\n'.join(line for line in debug.splitlines() if not line.lstrip().startswith('#'))
for mutator in ['consume_intent','expire_if_needed','clear()','transition_to']:
    check(mutator not in debug_code, f'DebugOverlay remains read-only: no {mutator}')


# M3 Complete implementation contracts (source-level; runtime execution is external when Godot is unavailable).
meter_component=text('fighter/meter/meter_component.gd')
cancel_data=text('data/moves/cancel_window_data.gd')
special_move=text('data/moves/special_neutral.tres')
ultimate_move=text('data/moves/ultimate.tres')
m3_meter_tests=text('tests/combat/test_milestone_3_meter.gd')
m3_move_tests=text('tests/combat/test_milestone_3_moves.gd')
m3_cancel_tests=text('tests/combat/test_milestone_3_cancel.gd')
m3_snapshot_tests=text('tests/snapshot/test_milestone_3_snapshot.gd')

# Exact normalized InputButton contract and device/core boundary.
enum_names=re.findall(r'\b([A-Z_]+)\s*=\s*1\s*<<', enum_body)
check(enum_names == ['LIGHT','HEAVY','GUARD','SPECIAL','ULTIMATE'], 'InputButton remains exactly LIGHT/HEAVY/GUARD/SPECIAL/ULTIMATE')
combat_core_no_device=[p for p in core_files if p.name != 'keyboard_input_source.gd' and re.search(r'\bKEY_[A-Z0-9_]+\b|Input\.is_key_pressed', p.read_text(encoding='utf-8'))]
check(not combat_core_no_device, 'Combat core contains no KEY_K/KEY_L or direct keyboard polling')
check('KEY_K' in wiring_m8 and 'KEY_L' in wiring_m8 and 'KeyboardInputSource.new' in wiring_m8, 'Desktop K/L mapping remains isolated to input-source wiring')
check('func action_pressed_intent() -> ActionIntent' in parser and parser.find('if ultimate_pressed:') < parser.find('elif special_pressed:') < parser.find('elif heavy_pressed:') < parser.find('elif light_pressed:'), 'InputParser action priority is ULTIMATE > SPECIAL > HEAVY > LIGHT')

# Meter foundation.
check((ROOT/'fighter/meter/meter_component.gd').exists(), 'MeterComponent exists')
for token in ['MIN_VALUE: int = 0','MAX_VALUE: int = 100','func get_value() -> int','func gain(amount: int) -> void','func can_spend(amount: int) -> bool','func spend(amount: int) -> bool','func reset() -> void']:
    check(token in meter_component, f'MeterComponent contract exists: {token}')
check('delta' not in meter_component and 'Timer' not in meter_component and 'float' not in meter_component.lower(), 'MeterComponent is integer/fixed-tick independent with no delta/Timer/float state')
for field in ['meter_cost','meter_gain_on_hit','meter_gain_on_block','meter_gain_on_throw']:
    check(re.search(rf'@export[^\n]*var\s+{field}\s*:\s*int', move_data) is not None, f'MoveData exposes generic {field}')
check('var meter: MeterComponent' in fighter and 'meter = MeterComponent.new()' in fighter, 'Meter is Fighter runtime composition state, not CharacterData/UI state')
check('_award_attacker_meter(result, attacker)' in resolver and 'result.meter_gain_on_hit' in resolver and 'result.meter_gain_on_block' in resolver and 'result.meter_gain_on_throw' in resolver, 'CombatResolver awards meter generically from resolved HitResult payload')
check('meter.can_spend(move.meter_cost)' in state and 'meter.spend(move.meter_cost)' in state, 'Move start path gates/spends generic MoveData meter_cost')

# Cancel foundation and generic runner discipline.
check((ROOT/'data/moves/cancel_window_data.gd').exists(), 'CancelWindowData typed Resource exists')
for condition in ['ALWAYS','ON_HIT','ON_BLOCK','ON_HIT_OR_BLOCK']:
    check(re.search(rf'\b{condition}\b', cancel_data) is not None, f'CancelWindowData includes {condition}')
for field in ['start_frame','end_frame','condition','allowed_target_move_ids']:
    check(field in cancel_data, f'CancelWindowData field exists: {field}')
check(re.search(r'@export\s+var\s+cancel_windows\s*:\s*Array\[CancelWindowData\]', move_data) is not None, 'MoveData owns typed Array[CancelWindowData]')
check('connected_hit: bool' in move_runner and 'connected_block: bool' in move_runner, 'MoveRunner stores current AttackInstance HIT/BLOCK connection facts')
check('func can_cancel_to(target_move_id: StringName, resources: FighterResourceComponent = null) -> bool' in move_runner and 'current_move.cancel_windows' in move_runner and 'resource_condition_met(resources)' in move_runner, 'MoveRunner evaluates cancel legality and optional resource gates from MoveData windows generically')
runner_code='\n'.join(line for line in move_runner.splitlines() if not line.lstrip().startswith('#'))
for forbidden in ['MoveIds.STAND_LIGHT','MoveIds.STAND_HEAVY','MoveIds.SPECIAL_NEUTRAL','MoveIds.ULTIMATE','stand_light','stand_heavy','special_neutral']:
    check(forbidden not in runner_code, f'MoveRunner has no individual move hard-code: {forbidden}')
check('start_cancel(target_move)' in state and 'runner.can_cancel_to(target_move_id, resources)' in state, 'StateMachine uses generic cancel replacement path with optional resource context')

# Special/Ultimate resources and MoveSet integration.
check(re.search(r'const\s+SPECIAL_NEUTRAL\s*:\s*StringName\s*=\s*&"special_neutral"', move_ids) is not None, 'MoveIds.SPECIAL_NEUTRAL stable ID exists')
check(re.search(r'const\s+ULTIMATE\s*:\s*StringName\s*=\s*&"ultimate"', move_ids) is not None, 'MoveIds.ULTIMATE stable ID exists')
check((ROOT/'data/moves/special_neutral.tres').exists() and 'id = &"special_neutral"' in special_move, 'Special resource exists')
check((ROOT/'data/moves/ultimate.tres').exists() and 'id = &"ultimate"' in ultimate_move, 'Ultimate resource exists')
for body,name,expected in [
    (special_move,'Special',{'startup_frames':10,'active_frames':4,'recovery_frames':18,'damage':110,'hitstun_frames':20,'blockstun_frames':14,'hitstop_attacker':6,'hitstop_defender':6,'knockback_x_units':1100,'knockback_y_units':0,'meter_cost':0}),
    (ultimate_move,'Ultimate',{'startup_frames':14,'active_frames':5,'recovery_frames':32,'damage':260,'hitstun_frames':28,'blockstun_frames':18,'hitstop_attacker':10,'hitstop_defender':10,'knockback_x_units':1600,'knockback_y_units':-500,'meter_cost':100}),
]:
    for key,value in expected.items():
        check(re.search(rf'^{key}\s*=\s*{value}\s*$', body, re.M) is not None, f'{name} {key}={value}')
check('offset = Vector2(82, -76)' in special_move and 'size = Vector2(120, 88)' in special_move, 'Special static hitbox matches prototype')
check('offset = Vector2(94, -82)' in ultimate_move and 'size = Vector2(154, 108)' in ultimate_move, 'Ultimate static hitbox matches prototype')
check('MoveIds.SPECIAL_NEUTRAL' in action_map and 'MoveIds.ULTIMATE' in action_map, 'ActionMoveMap routes grounded Special/Ultimate')
air_map_body=action_map.split('static func air_move_id_for_intent',1)[1]
check('SPECIAL_NEUTRAL' not in air_map_body and 'MoveIds.ULTIMATE' not in air_map_body, 'ActionMoveMap does not add Air Special/Ultimate')
check('res://data/moves/special_neutral.tres' in generic and 'res://data/moves/ultimate.tres' in generic and 'ExtResource("10_special")' in generic and 'ExtResource("11_ultimate")' in generic, 'Generic Fighter MoveSet contains Special and Ultimate')

# Required prototype cancel routes are data, not code branches.
check('start_frame = 6' in light and 'end_frame = 12' in light and '&"stand_light"' in light and '&"stand_heavy"' in light and 'condition = 3' in light, 'Light cancel data = F6-12 ON_HIT_OR_BLOCK -> Light/Heavy')
check('start_frame = 12' in heavy and 'end_frame = 20' in heavy and '&"special_neutral"' in heavy and 'condition = 3' in heavy, 'Heavy cancel data = F12-20 ON_HIT_OR_BLOCK -> Special')
check('start_frame = 11' in special_move and 'end_frame = 18' in special_move and '&"ultimate"' in special_move and 'condition = 1' in special_move, 'Special cancel data = F11-18 ON_HIT -> Ultimate')
check('cancel_windows' not in ultimate_move, 'Ultimate has no configured cancel window')

# Snapshot / restore / hash coverage for every new mutable gameplay fact.
fighter_snapshot=text('battle/simulation/fighter_state_snapshot.gd')
check('meter_value: int' in fighter_snapshot and 'move_connected_hit: bool' in fighter_snapshot and 'move_connected_block: bool' in fighter_snapshot, 'M3 mutable meter/connection facts exist in FighterStateSnapshot')
check('s.meter_value = fighter.meter.get_value()' in snapshot_codec and 'fighter.meter.restore_value(s.meter_value)' in snapshot_codec, 'Meter capture/restore is wired')
check('s.move_connected_hit = fighter.move_runner.connected_hit' in snapshot_codec and 's.move_connected_block = fighter.move_runner.connected_block' in snapshot_codec, 'Cancel connection facts capture is wired')
check('s.move_connected_hit' in snapshot_codec and 's.move_connected_block' in snapshot_codec and 'restore_runtime' in snapshot_codec, 'Cancel connection facts restore through generic MoveRunner runtime restore')
check('s.meter_value' in hasher and 's.move_connected_hit' in hasher and 's.move_connected_block' in hasher, 'Meter and cancel connection facts participate in canonical hash')
# Snapshot DTOs must not own live gameplay/presentation object references.
snapshot_sources='\n'.join(text(rel) for rel in ['battle/simulation/fighter_state_snapshot.gd','battle/simulation/action_intent_snapshot.gd','battle/simulation/input_frame_snapshot.gd'])
for forbidden in ['MoveData','CharacterData','BoxData','Node','Sprite','AnimationPlayer','AudioStreamPlayer','Callable']:
    typed_ref=re.search(rf'var\s+\w+\s*:\s*{forbidden}\b', snapshot_sources)
    check(typed_ref is None, f'Snapshot value DTOs contain no live {forbidden} reference')

# No character-specific branching in generic combat core and no new timing mechanisms.
generic_core='\n'.join(p.read_text(encoding='utf-8') for p in [ROOT/'fighter/state_machine/fighter_state_machine.gd', ROOT/'fighter/moves/move_runner.gd', ROOT/'battle/combat/combat_resolver.gd', ROOT/'fighter/input/input_buffer.gd'])
check('character_id' not in generic_core and 'generic_fighter' not in generic_core, 'Generic M3 core has no character_id/generic_fighter branching')
check('Timer' not in generic_core and 'get_ticks' not in generic_core and 'Time.' not in generic_core, 'Meter/Cancel combat logic uses no Timer/wall clock')
check(re.search(r'\bdelta\b', generic_core) is None, 'Meter/Cancel combat logic uses no render delta')

# Debug/tooling + tests/runner/stress wiring.
check('meter=%d/100' in fighter and 'cancel=%s' in fighter and 'targets=%s' in fighter and 'conn=%s' in fighter, 'Debug summary exposes Meter, cancel state/targets, and connection outcome')
logger=text('debug/combat_logger.gd')
for token in ['log_meter_gain','log_meter_spend','log_cancel(','log_cancel_meter_denied']:
    check(token in logger, f'CombatLogger includes sparse M3 diagnostic: {token}')
for token in ['MILESTONE_3_METER_SUITE','MILESTONE_3_MOVES_SUITE','MILESTONE_3_CANCEL_SUITE','MILESTONE_3_SNAPSHOT_SUITE']:
    check(token in run and f'{token}.new().run_all()' in run, f'Headless runner wires M3 suite: {token}')
for body,label in [(m3_meter_tests,'Meter'),(m3_move_tests,'Special/Ultimate'),(m3_cancel_tests,'Cancel/Combo'),(m3_snapshot_tests,'M3 Snapshot')]:
    check('func run_all() -> int' in body and 't.failed' in body, f'{label} M3 suite is executable by common headless runner')
for token in ['InputFrame.InputButton.SPECIAL','InputFrame.InputButton.ULTIMATE','meter outside 0..100','Ultimate started below 100 meter','invalid current move ID','invalid AttackInstance serial']:
    check(token in stress_test, f'10,000F stress includes M3 input/invariant: {token}')


# M4 COMPLETE — second-character framework validation.
rush_character_path = ROOT/'data/characters/rush_grappler.tres'
rush_set_path = ROOT/'data/move_sets/rush_grappler_move_set.tres'
check(rush_character_path.exists(), 'M4 Rush Grappler CharacterData resource exists')
check(rush_set_path.exists(), 'M4 Rush Grappler MoveSetData resource exists')
rush_character = text('data/characters/rush_grappler.tres')
rush_set = text('data/move_sets/rush_grappler_move_set.tres')
check('id = &"generic_fighter"' in generic, 'Generic CharacterData stable ID remains generic_fighter')
check('id = &"rush_grappler"' in rush_character, 'Rush CharacterData stable ID is rush_grappler')
character_resource_bodies = [text('data/characters/generic_fighter.tres'), rush_character]
character_ids = []
for body in character_resource_bodies:
    match = re.search(r'^id\s*=\s*&"([^"]+)"\s*$', body, re.M)
    if match:
        character_ids.append(match.group(1))
check(len(character_ids) == 2 and all(character_ids), 'Both M4 character IDs are non-empty')
check(len(set(character_ids)) == 2, 'M4 character IDs are unique')
check(set(character_ids) == {'generic_fighter','rush_grappler'}, 'M4 required character IDs both exist')
check('# Canonical immutable character identity.' in character, 'CharacterData documents existing id field as canonical immutable character identity')
check(re.search(r'@export\s+var\s+character_id\b', character) is None, 'CharacterData does not duplicate stable identity with a parallel character_id field')

# Rush movement profile and unchanged generic movement.
for key, value in {
    'walk_forward_units_per_tick':345, 'walk_back_units_per_tick':252,
    'jump_velocity_y_units_per_tick':-1350, 'gravity_y_units_per_tick2':85,
    'max_fall_speed_y_units_per_tick':1850, 'air_forward_units_per_tick':270,
    'air_back_units_per_tick':225, 'landing_recovery_frames':2,
    'dash_move_frames':7, 'dash_speed_units_per_tick':1050, 'dash_recovery_frames':3,
    'backstep_move_frames':6, 'backstep_speed_units_per_tick':850, 'backstep_recovery_frames':5,
}.items():
    check(re.search(rf'^{key}\s*=\s*{value}\s*$', rush_character, re.M) is not None, f'Rush CharacterData {key}={value}')
for key, value in {
    'walk_forward_units_per_tick':300, 'walk_back_units_per_tick':240,
    'jump_velocity_y_units_per_tick':-1400, 'gravity_y_units_per_tick2':80,
    'max_fall_speed_y_units_per_tick':1800, 'air_forward_units_per_tick':240,
    'air_back_units_per_tick':210, 'landing_recovery_frames':3,
    'dash_move_frames':8, 'dash_speed_units_per_tick':900, 'dash_recovery_frames':4,
    'backstep_move_frames':7, 'backstep_speed_units_per_tick':800, 'backstep_recovery_frames':6,
}.items():
    check(re.search(rf'^{key}\s*=\s*{value}\s*$', generic, re.M) is not None, f'Generic movement regression {key}={value}')

# Rush MoveSet canonical IDs, resource distinction, exact M4 move data and boxes.
rush_move_paths = {
    'stand_light':'data/moves/rush_grappler/stand_light.tres',
    'stand_heavy':'data/moves/rush_grappler/stand_heavy.tres',
    'crouch_low':'data/moves/rush_grappler/crouch_low.tres',
    'air_attack':'data/moves/rush_grappler/air_attack.tres',
    'ground_throw':'data/moves/rush_grappler/ground_throw.tres',
    'special_neutral':'data/moves/rush_grappler/special_neutral.tres',
    'ultimate':'data/moves/rush_grappler/ultimate.tres',
}
for move_id, rel in rush_move_paths.items():
    check((ROOT/rel).exists(), f'Rush MoveData exists: {move_id}')
    body = text(rel)
    check(f'id = &"{move_id}"' in body, f'Rush MoveData canonical ID is {move_id}')
    check(f'res://{rel}' in rush_set, f'Rush MoveSet references distinct {move_id} resource')
check(len(set(rush_move_paths.values())) == 7, 'Rush MoveSet uses seven distinct MoveData resource files')
for canonical in ['stand_light','stand_heavy','crouch_low','air_attack','ground_throw','special_neutral','ultimate']:
    check(rush_set.count(f'/rush_grappler/{canonical}.tres') == 1, f'Rush MoveSet contains canonical {canonical} exactly once')

rush_expected = {
 'stand_light': {'startup_frames':4,'active_frames':3,'recovery_frames':9,'damage':45,'hitstun_frames':13,'blockstun_frames':9,'hitstop_attacker':3,'hitstop_defender':3,'hit_level':1,'knockback_x_units':520,'knockback_y_units':0,'meter_gain_on_hit':7,'meter_gain_on_block':3},
 'stand_heavy': {'startup_frames':9,'active_frames':4,'recovery_frames':18,'damage':90,'hitstun_frames':18,'blockstun_frames':12,'hitstop_attacker':5,'hitstop_defender':5,'hit_level':1,'knockback_x_units':900,'knockback_y_units':0,'meter_gain_on_hit':11,'meter_gain_on_block':5},
 'crouch_low': {'startup_frames':7,'active_frames':3,'recovery_frames':14,'damage':55,'hitstun_frames':14,'blockstun_frames':10,'hitstop_attacker':4,'hitstop_defender':4,'hit_level':2,'knockback_x_units':560,'knockback_y_units':0,'meter_gain_on_hit':9,'meter_gain_on_block':4},
 'air_attack': {'startup_frames':5,'active_frames':4,'recovery_frames':11,'damage':65,'hitstun_frames':13,'blockstun_frames':9,'hitstop_attacker':4,'hitstop_defender':4,'hit_level':0,'knockback_x_units':650,'knockback_y_units':-300,'meter_gain_on_hit':9,'meter_gain_on_block':4},
 'ground_throw': {'startup_frames':5,'active_frames':2,'recovery_frames':20,'damage':150,'hitstop_attacker':5,'hitstop_defender':5,'throw_hold_frames':12,'knockdown_frames':36,'meter_gain_on_throw':18},
 'special_neutral': {'startup_frames':8,'active_frames':4,'recovery_frames':15,'damage':100,'hitstun_frames':18,'blockstun_frames':11,'hitstop_attacker':5,'hitstop_defender':5,'hit_level':1,'knockback_x_units':900,'knockback_y_units':0,'meter_gain_on_hit':16,'meter_gain_on_block':7},
 'ultimate': {'startup_frames':12,'active_frames':5,'recovery_frames':28,'damage':240,'hitstun_frames':26,'blockstun_frames':16,'hitstop_attacker':9,'hitstop_defender':9,'hit_level':1,'knockback_x_units':1450,'knockback_y_units':-450,'meter_cost':100},
}
for move_id, expected_fields in rush_expected.items():
    body = text(rush_move_paths[move_id])
    for key, value in expected_fields.items():
        check(re.search(rf'^{key}\s*=\s*{value}\s*$', body, re.M) is not None, f'Rush {move_id} {key}={value}')
box_expected = {
 'stand_light':('Vector2(62, -70)','Vector2(92, 58)'),
 'stand_heavy':('Vector2(76, -74)','Vector2(112, 70)'),
 'crouch_low':('Vector2(66, -36)','Vector2(98, 34)'),
 'air_attack':('Vector2(64, -68)','Vector2(100, 66)'),
 'ground_throw':('Vector2(60, -80)','Vector2(96, 132)'),
 'special_neutral':('Vector2(88, -72)','Vector2(138, 84)'),
 'ultimate':('Vector2(90, -80)','Vector2(148, 104)'),
}
for move_id, (offset, size) in box_expected.items():
    body=text(rush_move_paths[move_id])
    check(f'offset = {offset}' in body and f'size = {size}' in body, f'Rush {move_id} static gameplay box matches M4 spec')
check('hitbox =' not in text(rush_move_paths['ground_throw']) and 'throw_box = SubResource' in text(rush_move_paths['ground_throw']), 'Rush Throw has throw box only and no strike hitbox')

# M4 cancel graph lives only in MoveData resources.
rush_light = text(rush_move_paths['stand_light']); rush_low = text(rush_move_paths['crouch_low']); rush_heavy = text(rush_move_paths['stand_heavy']); rush_special = text(rush_move_paths['special_neutral']); rush_ultimate = text(rush_move_paths['ultimate']); rush_throw = text(rush_move_paths['ground_throw'])
check('start_frame = 5' in rush_light and 'end_frame = 11' in rush_light and 'condition = 3' in rush_light and '&"stand_light"' in rush_light and '&"stand_heavy"' in rush_light, 'Rush Light cancel = F5-11 ON_HIT_OR_BLOCK -> Light/Heavy')
check('start_frame = 8' in rush_low and 'end_frame = 14' in rush_low and 'condition = 3' in rush_low and '&"special_neutral"' in rush_low, 'Rush Low cancel = F8-14 ON_HIT_OR_BLOCK -> Special')
check('start_frame = 10' in rush_heavy and 'end_frame = 17' in rush_heavy and 'condition = 3' in rush_heavy and '&"special_neutral"' in rush_heavy, 'Rush Heavy cancel = F10-17 ON_HIT_OR_BLOCK -> Special')
check('start_frame = 9' in rush_special and 'end_frame = 16' in rush_special and 'condition = 1' in rush_special and '&"ultimate"' in rush_special, 'Rush Special cancel = F9-16 ON_HIT -> Ultimate')
check('cancel_windows' not in rush_ultimate, 'Rush Ultimate has no cancel windows')
check('cancel_windows' not in rush_throw, 'Rush Throw has no cancel windows')
check('cancel_windows' not in low, 'Generic Crouch Low remains without new cancel window')

# Per-Fighter registry proof and asymmetric battle scene binding.
check('var move_registry: MoveRegistry = MoveRegistry.new()' in fighter and 'move_registry = MoveRegistry.new()' in fighter and 'move_registry.configure(data.move_set)' in fighter, 'Each Fighter constructs its own MoveRegistry from its CharacterData MoveSet')
scene_gd = text('battle/battle_scene.gd'); scene_tscn = text('battle/battle_scene.tscn')
check('@export var character_a_data: CharacterData' in scene_gd and '@export var character_b_data: CharacterData' in scene_gd, 'BattleScene owns explicit P1/P2 CharacterData configuration')
check('load("res://data/characters/generic_fighter.tres")' not in scene_gd and 'load("res://data/characters/rush_grappler.tres")' not in scene_gd, 'BattleScene script does not hardcode character resources')
check('res://data/characters/generic_fighter.tres' in scene_tscn and 'res://data/characters/zone_fighter.tres' in scene_tscn, 'Default M5 battle scene binds Zone and Generic resources')
check('character_a_data = ExtResource("6_generic")' in scene_tscn and 'character_b_data = ExtResource("7_zone")' in scene_tscn, 'Production default match is P1 Generic/Salad Cat and P2 Zone/Magic Orange Cat')

# Stable character identity is captured, guarded, and hashed; MoveData remains registry-rehydrated.
check('var character_id: StringName = &""' in fighter_snapshot, 'FighterStateSnapshot stores immutable character compatibility identity')
check('s.character_id = fighter.data.id' in snapshot_codec, 'Snapshot capture stores CharacterData stable ID')
check('fighter.data.id == s.character_id' in snapshot_codec and 'Snapshot character mismatch' in snapshot_codec, 'Snapshot restore validates character identity and fails loudly')
check('FighterSnapshotCodec.is_compatible(simulation.fighter_a' in text('battle/simulation/battle_snapshot_codec.gd') and 'FighterSnapshotCodec.is_compatible(simulation.fighter_b' in text('battle/simulation/battle_snapshot_codec.gd'), 'Battle restore preflights both fighter identities before mutation')
check('character=%s' in hasher and 'String(s.character_id)' in hasher, 'BattleStateHasher includes stable textual character identity')
check('const VERSION: int = 8' in text('battle/simulation/battle_state_snapshot.gd'), 'M8 Snapshot schema is v8 for authoritative Charge state while retaining prior state')
check('registry.get_move(move_id)' in move_runner and 'current_move = move' in move_runner, 'Snapshot MoveRunner rehydration continues through that Fighter registry')

# M4 no-character-branch core audit and hardcoded resource bans.
m4_generic_core_paths = [
 'fighter/moves/move_runner.gd','battle/combat/combat_resolver.gd','fighter/movement/movement_motor.gd',
 'fighter/input/input_parser.gd','fighter/input/input_buffer.gd','battle/combat/collision_system.gd',
 'battle/combat/throw_system.gd','battle/battle_simulation.gd'
]
for rel in m4_generic_core_paths:
    body=text(rel)
    code='\n'.join(line for line in body.splitlines() if not line.lstrip().startswith('#'))
    check('rush_grappler' not in code and 'generic_fighter' not in code, f'M4 generic core has no concrete character ID branch/reference: {rel}')
    check('data/characters/' not in code, f'M4 generic core does not hard-load character resources: {rel}')
check('RushGrapplerFighter' not in '\n'.join(str(p.relative_to(ROOT)) for p in ROOT.rglob('*')), 'No RushGrapplerFighter copy/class/file exists')
check(not any('charactermechanicruntime' in p.name.lower() for p in ROOT.rglob('*')), 'CharacterMechanicRuntime was not added')
check((ROOT/'battle/projectiles/projectile_system.gd').exists(), 'M5 adds generic battle-owned ProjectileSystem')

# M5 projectile + Zone architecture proof.
projectile_data = text('data/projectile_data.gd')
projectile_spawn_data = text('data/moves/projectile_spawn_data.gd')
projectile_runtime = text('battle/projectiles/projectile_runtime.gd')
projectile_system = text('battle/projectiles/projectile_system.gd')
projectile_contact = text('battle/projectiles/projectile_contact.gd')
projectile_snapshot = text('battle/simulation/projectile_snapshot.gd')
battle_snapshot = text('battle/simulation/battle_state_snapshot.gd')
zone_character = text('data/characters/zone_fighter.tres')
zone_set = text('data/move_sets/zone_fighter_move_set.tres')
zone_special = text('data/moves/zone_fighter/special_neutral.tres')
zone_ultimate = text('data/moves/zone_fighter/ultimate.tres')
shot_data = text('data/projectiles/zone_shot.tres')
super_shot_data = text('data/projectiles/zone_super_shot.tres')

check('class_name ProjectileData' in projectile_data and 'extends Resource' in projectile_data, 'ProjectileData is a typed immutable Resource contract')
for field in ['id: StringName','velocity_x_units_per_tick: int','lifetime_frames: int','hitbox_offset: Vector2','hitbox_size: Vector2','damage: int','hitstun_frames: int','blockstun_frames: int','meter_gain_on_hit: int','meter_gain_on_block: int']:
    check(field in projectile_data, f'ProjectileData field exists: {field}')
for forbidden in ['current_position','instance_id','owner_fighter_id','remaining_lifetime_frames']:
    check(forbidden not in projectile_data, f'ProjectileData contains no runtime field: {forbidden}')
check('class_name ProjectileSpawnData' in projectile_spawn_data and 'spawn_frame: int' in projectile_spawn_data and 'spawn_offset_units: Vector2i' in projectile_spawn_data and 'projectile_data: ProjectileData' in projectile_spawn_data, 'ProjectileSpawnData is typed and uses integer spawn offset')
check(re.search(r'@export\s+var\s+projectile_spawns\s*:\s*Array\[ProjectileSpawnData\]', move_data) is not None, 'MoveData exposes generic typed projectile_spawns descriptors')
check('current_move.projectile_spawns' in move_runner and 'consume_projectile_spawn_indices' in move_runner and '_spawned_projectile_indices' in move_runner, 'MoveRunner generically tracks data-defined spawn descriptors exactly once')
move_runner_code='\n'.join(line for line in move_runner.splitlines() if not line.lstrip().startswith('#'))
for forbidden in ['zone_fighter','zone_shot','fireball','zoner']:
    check(forbidden not in move_runner_code.lower(), f'MoveRunner projectile extension has no character/projectile hard-code: {forbidden}')

check('class_name ProjectileRuntime' in projectile_runtime and 'position_units: Vector2i' in projectile_runtime and 'remaining_lifetime_frames: int' in projectile_runtime, 'ProjectileRuntime owns small mutable integer simulation state')
check('var projectile_data: ProjectileData = null' in projectile_runtime and 'Execution cache only' in projectile_runtime, 'ProjectileRuntime Resource reference is documented execution cache, not snapshot truth')
for forbidden in ['extends Node','Area2D','PhysicsBody2D','CharacterBody2D','_process(','_physics_process(','Timer','Tween','delta']:
    check(forbidden not in '\n'.join(line for line in projectile_runtime.splitlines() if not line.lstrip().startswith('#')), f'ProjectileRuntime has no presentation/Node/timing authority: {forbidden}')
check('class_name ProjectileSystem' in projectile_system and 'extends RefCounted' in projectile_system, 'ProjectileSystem is a battle-owned non-Node subsystem')
check('next_projectile_instance_serial' in projectile_system and 'INITIAL_INSTANCE_SERIAL: int = 1' in projectile_system, 'ProjectileSystem owns deterministic runtime instance serial')
check('position_units.x += projectile.projectile_data.velocity_x_units_per_tick * projectile.facing' in projectile_system, 'Projectile movement is integer units-per-tick with captured facing')
check('remaining_lifetime_frames -= 1' in projectile_system and 'remaining_lifetime_frames <= 0' in projectile_system, 'Projectile lifetime is deterministic simulation frames')
check('projectile.position_units.x >= defender.movement_motor.sim_position.x' in projectile_system and 'owner current position' not in '\n'.join(line for line in projectile_system.splitlines() if not line.lstrip().startswith('#')).lower(), 'Projectile guard side is derived from projectile world origin')
for forbidden in ['Area2D','PhysicsServer','move_and_collide','move_and_slide','_process(','_physics_process(','Timer','Tween','delta']:
    check(forbidden not in '\n'.join(line for line in projectile_system.splitlines() if not line.lstrip().startswith('#')), f'ProjectileSystem avoids engine physics/time authority: {forbidden}')
check('class_name ProjectileContact' in projectile_contact and 'extends StrikeContact' in projectile_contact, 'ProjectileContact reuses generic strike provenance contract')
check('resolve_projectile_contact' in resolver and '_resolve_strike_payload' in resolver and 'HitResult.AttackSourceKind.PROJECTILE' in resolver, 'Projectile contacts route through shared CombatResolver strike logic')
check('mark_connected_hit' in resolver and 'if result.attack_source_kind == HitResult.AttackSourceKind.FIGHTER_BODY' in resolver, 'Detached projectile impact does not write current MoveRunner connection facts')
check('var projectile_system: ProjectileSystem = ProjectileSystem.new()' in battle and 'projectile_system.advance_existing' in battle and '_spawn_move_projectiles' in battle and 'projectile_system.build_contacts' in battle, 'BattleSimulation owns and ticks ProjectileSystem in explicit phases')
check('projectile_system.cleanup_end_of_tick' in battle and battle.find('projectile_system.cleanup_end_of_tick') > battle.find('apply_throw_result'), 'Projectile contact/KO/lifetime cleanup occurs after outcome apply phase')

check('id = &"zone_fighter"' in zone_character, 'Zone CharacterData stable ID exists')
for key,value in {'max_hp':1000,'walk_forward_units_per_tick':270,'walk_back_units_per_tick':250,'jump_velocity_y_units_per_tick':-1450,'gravity_y_units_per_tick2':75,'max_fall_speed_y_units_per_tick':1750,'air_forward_units_per_tick':220,'air_back_units_per_tick':230,'landing_recovery_frames':3,'dash_move_frames':8,'dash_speed_units_per_tick':820,'dash_recovery_frames':5,'backstep_move_frames':7,'backstep_speed_units_per_tick':900,'backstep_recovery_frames':5}.items():
    check(re.search(rf'^{key}\s*=\s*{value}\s*$', zone_character, re.M) is not None, f'Zone CharacterData {key}={value}')
for move_id in ['stand_light','stand_heavy','crouch_low','air_attack','ground_throw','special_neutral','ultimate']:
    path=f'data/moves/zone_fighter/{move_id}.tres'
    check((ROOT/path).exists(), f'Zone MoveData exists: {move_id}')
    check(f'res://{path}' in zone_set, f'Zone MoveSet references {move_id}')
zone_expected={
 'stand_light': {'startup_frames':6,'active_frames':3,'recovery_frames':11,'damage':48,'hitstun_frames':13,'blockstun_frames':9,'hitstop_attacker':3,'hitstop_defender':3,'hit_level':1,'knockback_x_units':560,'knockback_y_units':0,'meter_gain_on_hit':7,'meter_gain_on_block':3},
 'stand_heavy': {'startup_frames':13,'active_frames':4,'recovery_frames':22,'damage':100,'hitstun_frames':19,'blockstun_frames':13,'hitstop_attacker':6,'hitstop_defender':6,'hit_level':1,'knockback_x_units':1000,'knockback_y_units':0,'meter_gain_on_hit':12,'meter_gain_on_block':6},
 'crouch_low': {'startup_frames':9,'active_frames':3,'recovery_frames':17,'damage':58,'hitstun_frames':15,'blockstun_frames':11,'hitstop_attacker':4,'hitstop_defender':4,'hit_level':2,'knockback_x_units':620,'knockback_y_units':0,'meter_gain_on_hit':9,'meter_gain_on_block':4},
 'air_attack': {'startup_frames':7,'active_frames':4,'recovery_frames':13,'damage':68,'hitstun_frames':14,'blockstun_frames':10,'hitstop_attacker':4,'hitstop_defender':4,'hit_level':0,'knockback_x_units':680,'knockback_y_units':-320,'meter_gain_on_hit':9,'meter_gain_on_block':4},
 'ground_throw': {'startup_frames':6,'active_frames':2,'recovery_frames':20,'damage':110,'hitstop_attacker':4,'hitstop_defender':4,'throw_hold_frames':10,'knockdown_frames':28,'meter_gain_on_throw':12},
 'special_neutral': {'startup_frames':14,'active_frames':1,'recovery_frames':20,'damage':0,'meter_cost':0},
 'ultimate': {'startup_frames':18,'active_frames':1,'recovery_frames':30,'damage':0,'meter_cost':100},
}
zone_boxes={
 'stand_light':('Vector2(66, -70)','Vector2(96, 58)'),
 'stand_heavy':('Vector2(92, -74)','Vector2(148, 70)'),
 'crouch_low':('Vector2(72, -36)','Vector2(110, 34)'),
 'air_attack':('Vector2(70, -70)','Vector2(108, 68)'),
 'ground_throw':('Vector2(50, -80)','Vector2(78, 126)'),
}
for move_id,expected_fields in zone_expected.items():
    body=text(f'data/moves/zone_fighter/{move_id}.tres')
    check(f'id = &"{move_id}"' in body, f'Zone MoveData canonical ID: {move_id}')
    for key,value in expected_fields.items():
        check(re.search(rf'^{key}\s*=\s*{value}\s*$', body, re.M) is not None, f'Zone {move_id} {key}={value}')
for move_id,(offset,size) in zone_boxes.items():
    body=text(f'data/moves/zone_fighter/{move_id}.tres')
    check(f'offset = {offset}' in body and f'size = {size}' in body, f'Zone {move_id} static gameplay box matches M5 spec')
zone_light=text('data/moves/zone_fighter/stand_light.tres'); zone_heavy=text('data/moves/zone_fighter/stand_heavy.tres'); zone_low=text('data/moves/zone_fighter/crouch_low.tres'); zone_air=text('data/moves/zone_fighter/air_attack.tres'); zone_throw=text('data/moves/zone_fighter/ground_throw.tres')
check('start_frame = 7' in zone_light and 'end_frame = 13' in zone_light and 'condition = 3' in zone_light and '&"stand_heavy"' in zone_light and '&"special_neutral"' in zone_light, 'Zone Light cancel = F7-13 HIT/BLOCK -> Heavy/Special')
check('start_frame = 14' in zone_heavy and 'end_frame = 21' in zone_heavy and 'condition = 3' in zone_heavy and '&"special_neutral"' in zone_heavy, 'Zone Heavy cancel = F14-21 HIT/BLOCK -> Special')
check(all('CancelWindow_' not in body and ('cancel_windows' not in body or 'cancel_windows = []' in body) for body in [zone_low,zone_air,zone_throw,zone_special,zone_ultimate]), 'Zone Low/Air/Throw/Special/Ultimate have no cancel windows')
check('hitbox =' not in zone_throw and 'throw_box = SubResource' in zone_throw, 'Zone Throw has throw geometry only')
check('projectile_spawns' not in text('data/moves/special_neutral.tres') and 'projectile_spawns' not in text('data/moves/rush_grappler/special_neutral.tres'), 'Generic/Rush Special remain non-projectile body moves')
check('hitbox = null' in zone_special and 'spawn_frame = 15' in zone_special and 'Vector2i(100, -70)' in zone_special and 'zone_shot.tres' in zone_special, 'Zone Special is body-hitbox-free F15 zone_shot descriptor')
check('hitbox = null' in zone_ultimate and 'meter_cost = 100' in zone_ultimate and 'spawn_frame = 19' in zone_ultimate and 'Vector2i(110, -80)' in zone_ultimate and 'zone_super_shot.tres' in zone_ultimate, 'Zone Ultimate is cost-100 body-hitbox-free F19 super descriptor')
for body,pid,velocity,damage,lifetime in [(shot_data,'zone_shot',800,80,120),(super_shot_data,'zone_super_shot',1100,220,120)]:
    check(f'id = &"{pid}"' in body and f'velocity_x_units_per_tick = {velocity}' in body and f'damage = {damage}' in body and f'lifetime_frames = {lifetime}' in body, f'ProjectileData resource matches core values: {pid}')
check('id = &"zone_shot"' in shot_data and 'id = &"zone_super_shot"' in super_shot_data, 'Projectile IDs zone_shot/zone_super_shot are unique')

check('const VERSION: int = 8' in battle_snapshot and 'next_projectile_instance_serial' in battle_snapshot and 'Array[ProjectileSnapshot]' in battle_snapshot, 'Battle snapshot v8 retains M5 projectile serial and active entity snapshots')
for field in ['instance_id','owner_fighter_id','source_move_id','spawn_index','projectile_id','position_units','facing','remaining_lifetime_frames','contacted_defender_ids','pending_despawn']:
    check(field in projectile_snapshot, f'ProjectileSnapshot future-affecting field exists: {field}')
projectile_snapshot_code='\n'.join(line for line in projectile_snapshot.splitlines() if not line.lstrip().startswith('#'))
check('ProjectileData' not in projectile_snapshot_code and 'Resource' not in projectile_snapshot_code, 'ProjectileSnapshot stores no ProjectileData/Resource pointer')
check('_rehydrate_data' in projectile_system and 'owner.move_registry.get_move(source_move_id)' in projectile_system and 'source_move.projectile_spawns[spawn_index]' in projectile_system and 'data.id != s.projectile_id' in projectile_system, 'Projectile restore rehydrates owner -> MoveRegistry -> source move -> spawn index -> ProjectileData ID')
for token in ['next_projectile_instance_serial','s.instance_id','s.owner_fighter_id','s.source_move_id','s.spawn_index','s.projectile_id','s.position_units.x','s.position_units.y','s.facing','s.remaining_lifetime_frames','s.contacted_defender_ids','s.pending_despawn']:
    check(token in hasher, f'StateHasher includes projectile canonical state: {token}')

# M5 character ID uniqueness and per-MoveSet canonical ID uniqueness source audit.
character_ids=[]
for path in [ROOT/'data/characters/generic_fighter.tres', ROOT/'data/characters/rush_grappler.tres', ROOT/'data/characters/zone_fighter.tres']:
    m=re.search(r'^id\s*=\s*&"([^"]+)"', path.read_text(encoding='utf-8'), re.M)
    if m: character_ids.append(m.group(1))
check(character_ids == ['generic_fighter','rush_grappler','zone_fighter'] and len(set(character_ids)) == 3, f'Prototype roster has three unique stable Character IDs: {character_ids}')
projectile_ids=[]
for path in [ROOT/'data/projectiles/zone_shot.tres', ROOT/'data/projectiles/zone_super_shot.tres']:
    m=re.search(r'^id\s*=\s*&"([^"]+)"', path.read_text(encoding='utf-8'), re.M)
    if m: projectile_ids.append(m.group(1))
check(len(projectile_ids)==2 and len(set(projectile_ids))==2, f'Projectile IDs are globally unique in M5 resources: {projectile_ids}')

# M5 test runner/source coverage.
m5_suites={
 'MILESTONE_5_PROJECTILE_DATA_SUITE':'tests/projectiles/test_projectile_data.gd',
 'MILESTONE_5_PROJECTILE_SPAWN_SUITE':'tests/projectiles/test_projectile_spawn.gd',
 'MILESTONE_5_PROJECTILE_COMBAT_SUITE':'tests/projectiles/test_projectile_combat.gd',
 'MILESTONE_5_PROJECTILE_LIFECYCLE_SUITE':'tests/projectiles/test_projectile_lifecycle.gd',
 'MILESTONE_5_ZONE_FIGHTER_SUITE':'tests/characters/test_milestone_5_zone_fighter.gd',
 'MILESTONE_5_PROJECTILE_TRADE_SUITE':'tests/combat/test_milestone_5_projectile_trade.gd',
 'MILESTONE_5_PROJECTILE_SNAPSHOT_SUITE':'tests/snapshot/test_milestone_5_projectile_snapshot.gd',
}
for constant,rel in m5_suites.items():
    body=text(rel)
    check(f'preload("res://{rel}")' in run and f'{constant}.new().run_all()' in run, f'Headless runner wires M5 suite: {constant}')
    check('func run_all() -> int' in body and 'return t.failed' in body, f'M5 suite executable by common runner: {rel}')
m5_test_text='\n'.join(text(rel) for rel in m5_suites.values())
for token in ['No projectile before Special move F15','Zone projectile HIT applies ProjectileData damage 80','Projectile BLOCK awards owner +6 meter','Front projectile BLOCK uses projectile origin','two concurrent projectiles','same frame','Mid-flight projectile snapshot restores','Re-simulation spawns exactly one projectile','ProjectileData ID mismatch rejects restore loudly']:
    check(token.lower() in m5_test_text.lower(), f'M5 authored tests cover: {token}')
for token in ['zone_vs_generic_projectiles','projectile IDs/order','projectile source MoveRegistry rehydration','projectile registry/data cross-contamination']:
    check(token in stress_test, f'M5 10,000F stress source covers: {token}')

# M5 forbidden architecture scans.
m5_generic_core = [
 'fighter/fighter.gd','fighter/moves/move_runner.gd','fighter/movement/movement_motor.gd','fighter/input/input_parser.gd','fighter/input/input_buffer.gd',
 'battle/combat/collision_system.gd','battle/combat/throw_system.gd','battle/combat/combat_resolver.gd','battle/battle_simulation.gd','battle/projectiles/projectile_system.gd'
]
for rel in m5_generic_core:
    code='\n'.join(line for line in text(rel).splitlines() if not line.lstrip().startswith('#')).lower()
    check('zone_fighter' not in code and 'rush_grappler' not in code and 'generic_fighter' not in code, f'M5 generic gameplay code has no concrete character-ID branch/reference: {rel}')
check(not any(p.name.lower() in ['zonefighter.gd','zonerfighter.gd','projectilefighter.gd'] for p in ROOT.rglob('*.gd')), 'No ZoneFighter/ZonerFighter/ProjectileFighter subclass exists')
check(not any('charactermechanicruntime' in p.name.lower() for p in ROOT.rglob('*')), 'M5 does not add CharacterMechanicRuntime')

# Duplicate class_name audit.
class_names = {}
duplicate_classes=[]
for gd in ROOT.rglob('*.gd'):
    m=re.search(r'^class_name\s+(\w+)', gd.read_text(encoding='utf-8'), re.M)
    if m:
        name=m.group(1)
        if name in class_names:
            duplicate_classes.append((name, str(class_names[name]), str(gd.relative_to(ROOT))))
        else:
            class_names[name]=gd.relative_to(ROOT)
check(not duplicate_classes, f'No duplicate class_name declarations: {duplicate_classes}')

# M4 runtime test source and runner wiring.
m4_suites = {
 'MILESTONE_4_CHARACTER_DATA_SUITE':'tests/characters/test_milestone_4_character_data.gd',
 'MILESTONE_4_MOVE_REGISTRY_SUITE':'tests/characters/test_milestone_4_move_registry.gd',
 'MILESTONE_4_RUSH_GRAPPLER_SUITE':'tests/combat/test_milestone_4_rush_grappler.gd',
 'MILESTONE_4_ASYMMETRIC_MATCH_SUITE':'tests/combat/test_milestone_4_asymmetric_match.gd',
 'MILESTONE_4_CHARACTER_SNAPSHOT_SUITE':'tests/snapshot/test_milestone_4_character_snapshot.gd',
}
for constant, rel in m4_suites.items():
    body=text(rel)
    check(f'preload("res://{rel}")' in run and f'{constant}.new().run_all()' in run, f'Headless runner wires M4 suite: {constant}')
    check('func run_all() -> int' in body and 'return t.failed' in body, f'M4 suite executable by common runner: {rel}')
for token in ['Generic stable CharacterData.id is generic_fighter','Same canonical %s resolves to distinct MoveData resources','Rush Light actual simulation deals 45','Asymmetric trade applies Rush 45 damage','Generic fighter snapshot -> Rush fighter is rejected','Rush stand_light rehydrates through Rush registry']:
    check(token in '\n'.join(text(rel) for rel in m4_suites.values()), f'M4 tests cover: {token}')
for token in ['generic_vs_generic','rush_vs_rush','generic_vs_rush','character_id never empty','Fighter registry matches its CharacterData','no registry cross-contamination','snapshot identity stays stable']:
    check(token in stress_test, f'M4 stress source covers: {token}')


# M6 match lifecycle / replay / training architecture proof.
match_rules_data = text('data/match_rules_data.gd')
versus_rules = text('data/match_rules/versus_match_rules.tres')
training_rules = text('data/match_rules/training_match_rules.tres')
round_controller = text('battle/match/round_controller.gd')
round_snapshot = text('battle/simulation/round_state_snapshot.gd')
battle_snapshot_codec = text('battle/simulation/battle_snapshot_codec.gd')
battle_sim = text('battle/battle_simulation.gd')
replay_format = text('battle/replay/replay_format.gd')
replay_data = text('battle/replay/replay_data.gd')
replay_pair = text('battle/replay/replay_frame_pair.gd')
replay_recorder = text('battle/replay/replay_recorder.gd')
replay_source = text('battle/replay/replay_input_source.gd')
replay_codec = text('battle/replay/replay_codec.gd')
replay_validator = text('battle/replay/replay_validator.gd')
fighter_m6 = text('fighter/fighter.gd')
projectile_system_m6 = text('battle/projectiles/projectile_system.gd')
debug_overlay_m6 = text('debug/debug_overlay.gd')
logger_m6 = text('debug/combat_logger.gd')
hud_m6 = text('presentation/battle_hud.gd')
scene_gd_m6 = text('battle/battle_scene.gd')
scene_tscn_m6 = text('battle/battle_scene.tscn')

# MatchRules typed config + exact prototype resources.
check('class_name MatchRulesData' in match_rules_data and 'extends Resource' in match_rules_data, 'M6 MatchRulesData is typed immutable Resource configuration')
for field in ['id: StringName','mode: Mode','rounds_to_win: int','round_timer_frames: int','timer_enabled: bool','post_round_frames: int','match_can_end: bool','reset_meter_each_round: bool']:
    check(field in match_rules_data, f'M6 MatchRulesData field exists: {field}')
check('VERSUS' in match_rules_data and 'TRAINING' in match_rules_data and 'ONLINE' not in match_rules_data and 'RANKED' not in match_rules_data, 'M6 Battle mode enum contains only VERSUS/TRAINING foundation')
for token in ['id = &"versus"','mode = 0','rounds_to_win = 2','timer_enabled = true','round_timer_frames = 5940','post_round_frames = 90','match_can_end = true','reset_meter_each_round = true']:
    check(token in versus_rules, f'M6 versus_match_rules exact field: {token}')
for token in ['id = &"training"','mode = 1','rounds_to_win = 0','timer_enabled = false','round_timer_frames = 0','post_round_frames = 60','match_can_end = false','reset_meter_each_round = true']:
    check(token in training_rules, f'M6 training_match_rules exact field: {token}')
check('id = &"versus"' in versus_rules and 'id = &"training"' in training_rules, 'M6 MatchRules IDs are stable/non-empty/unique')

# Small battle-owned RoundController, no manager sprawl.
check('class_name RoundController' in round_controller and 'extends RefCounted' in round_controller, 'M6 RoundController is small deterministic RefCounted runtime component')
check('var round_controller: RoundController = RoundController.new()' in battle_sim, 'BattleSimulation owns RoundController')
for token in ['ROUND_ACTIVE','POST_ROUND','MATCH_OVER','P1_WIN','P2_WIN','DRAW','round_number','p1_round_wins','p2_round_wins','round_timer_remaining_frames','post_round_remaining_frames','round_result','pending_match_winner','match_winner']:
    check(token in round_controller, f'M6 RoundController state contract includes: {token}')
check('if p1_is_ko or p2_is_ko:' in round_controller and 'if rules.timer_enabled and not frozen_at_tick_start:' in round_controller, 'RoundController evaluates KO before timeout and freezes timer during gameplay hitstop')
check('round_timer_remaining_frames = maxi(0, round_timer_remaining_frames - 1)' in round_controller, 'Round timer is integer simulation-frame countdown')
check('p1_hp > p2_hp' in round_controller and 'p2_hp > p1_hp' in round_controller and '_enter_post_round(RoundResult.DRAW)' in round_controller, 'Timeout compares post-apply HP and supports draw')
check('post_round_remaining_frames = rules.post_round_frames' in round_controller and 'post_round_remaining_frames -= 1' in round_controller, 'POST_ROUND receives full configured duration then decrements on later ticks')
check('round_number += 1' in round_controller and 'round_number = 1' in round_controller, 'Versus advances rounds while Training keeps stable round number 1')
check('rules.mode == MatchRulesData.Mode.TRAINING' in round_controller and 'snapshot.state == State.MATCH_OVER' in round_controller, 'Training restore invariants prohibit scored MATCH_OVER state')
for forbidden_name in ['GameFlowManager','RoundManager','MatchManager','BattleManager','SessionManager','LifecycleService','TrainingBattleSimulation','TrainingFighter']:
    check(not any(forbidden_name.lower() in q.name.lower() for q in ROOT.rglob('*')), f'M6 does not add forbidden manager/specialized runtime: {forbidden_name}')

# Battle authority/tick/reset/cleanup contracts.
check('var next_frame := frame_number + 1' in battle_sim and 'frame_number = next_frame' in battle_sim, 'BattleSimulation remains global monotonic frame authority during normal match ticks')
check('func reset_full_match()' in battle_sim and 'frame_number = 0' in battle_sim.split('func reset_full_match()',1)[1], 'Only explicit full match reset resets global simulation frame')
check('func _reset_round_runtime()' in battle_sim and 'frame_number = 0' not in battle_sim.split('func _reset_round_runtime()',1)[1].split('func ',1)[0], 'Round reset does not reset global simulation frame')
check('func cleanup_temporary_combat_entities()' in battle_sim and 'projectile_system.clear_active()' in battle_sim.split('func cleanup_temporary_combat_entities()',1)[1].split('func ',1)[0], 'Central temporary entity cleanup hook clears active projectiles')
check('func clear_active()' in projectile_system_m6 and 'next_projectile_instance_serial' not in projectile_system_m6.split('func clear_active()',1)[1].split('func ',1)[0], 'Round projectile cleanup preserves deterministic projectile serial')
check('func reset_for_new_match()' in projectile_system_m6 and 'next_projectile_instance_serial = INITIAL_INSTANCE_SERIAL' in projectile_system_m6, 'Full match reset restores projectile serial initial value')
check('func reset_for_round(' in fighter_m6 and 'input_history.clear()' in fighter_m6 and 'input_buffer = InputBuffer.new()' in fighter_m6 and 'move_runner.reset_runtime' in fighter_m6 and 'hitbox_owner.reset_runtime()' in fighter_m6, 'Fighter round reset clears input/move/contact runtime through Fighter-owned API')
check('meter.reset()' in fighter_m6 and 'reset_meter_value' in fighter_m6, 'Fighter round reset obeys MatchRules reset_meter_each_round policy')
check('_start_a' in battle_sim and '_start_b' in battle_sim and '_start_facing_a' in battle_sim and '_start_facing_b' in battle_sim, 'BattleSimulation preserves canonical round starting positions/facings')
check('InputFrame.neutral(required_frame)' in battle_sim and 'if not round_controller.is_round_active()' in battle_sim, 'POST_ROUND/MATCH_OVER input is neutralized at simulation authority')
post_body = battle_sim.split('func _simulate_post_round_tick',1)[1].split('func _reset_round_runtime',1)[0]
check('build_strike_contact' not in post_body and 'build_contacts' not in post_body and 'build_throw_contact' not in post_body, 'POST_ROUND performs settlement without building new combat contacts')
check('fighter_a.movement_tick()' in post_body and 'fighter_a.status_tick()' in post_body, 'POST_ROUND still permits deterministic physics/reaction settlement')
active_body = battle_sim.split('func _simulate_round_active_tick',1)[1].split('func _simulate_post_round_tick',1)[0]
check(active_body.find('apply_strike_result') < active_body.find('evaluate_active_tick'), 'Round outcome evaluates only after authoritative combat apply')
check('cleanup_temporary_combat_entities()' in active_body and active_body.find('cleanup_temporary_combat_entities()') > active_body.find('evaluate_active_tick'), 'Round-ending tick cleans detached entities only after same-frame outcomes apply')

# Snapshot v6 + rules identity + round state hash.
check('const VERSION: int = 8' in battle_snapshot and 'round_state: RoundStateSnapshot' in battle_snapshot, 'M8 Battle snapshot schema v8 retains typed RoundStateSnapshot')
for field in ['rules_id','state','round_number','p1_round_wins','p2_round_wins','round_timer_remaining_frames','post_round_remaining_frames','round_result','pending_match_winner','match_winner']:
    check(re.search(rf'var\s+{field}\s*:', round_snapshot) is not None, f'M6 RoundStateSnapshot field exists: {field}')
check('MatchRulesData' not in '\n'.join(l for l in round_snapshot.splitlines() if not l.lstrip().startswith('#')) and 'Resource' not in '\n'.join(l for l in round_snapshot.splitlines() if not l.lstrip().startswith('#')), 'RoundStateSnapshot stores stable rules ID, not MatchRulesData Resource pointer')
check('snapshot.round_state = simulation.round_controller.capture_snapshot()' in battle_snapshot_codec, 'Battle snapshot capture includes RoundController state')
check('snapshot.rules_id != rules.id' in round_controller and 'Round snapshot restore rejected' in round_controller, 'Round snapshot restore rejects MatchRules identity mismatch loudly')
check('simulation.round_controller.validate_restore_snapshot' in battle_snapshot_codec and 'simulation.round_controller.restore_snapshot' in battle_snapshot_codec, 'Battle snapshot v8 preflights/restores RoundController state')
for token in ['String(s.rules_id)','s.state','s.round_number','s.p1_round_wins','s.p2_round_wins','s.round_timer_remaining_frames','s.post_round_remaining_frames','s.round_result','s.pending_match_winner','s.match_winner']:
    check(token in hasher, f'M6 BattleStateHasher includes round canonical field: {token}')
check('clear_pending_presentation_events()' in battle_snapshot_codec, 'M6 snapshot restore clears non-gameplay pending presentation events')

# Replay normalized-input-only architecture.
check('const SCHEMA_VERSION: int = 1' in replay_format and 'const COMBAT_RULES_VERSION: int = 4' in replay_format and '&"greybox_stage"' in replay_format and '.tbf_replay.json' in replay_format, 'Replay format centralizes unchanged schema and M8 combat-rules compatibility constants')
for field in ['replay_schema_version','combat_rules_version','match_rules_id','stage_id','p1_character_id','p2_character_id','random_seed','initial_simulation_frame','frames','expected_final_state_hash']:
    check(re.search(rf'var\s+{field}\s*:', replay_data) is not None, f'ReplayData metadata/input field exists: {field}')
replay_data_code='\n'.join(l for l in replay_data.splitlines() if not l.lstrip().startswith('#'))
for forbidden in ['BattleStateSnapshot','FighterStateSnapshot','ProjectileSnapshot','CharacterData','MoveData','Resource']:
    check(forbidden not in replay_data_code, f'ReplayData does not store derived gameplay/snapshot Resource field: {forbidden}')
for field in ['frame_number','p1_input','p2_input']:
    check(re.search(rf'var\s+{field}\s*:', replay_pair) is not None, f'ReplayFramePair stores canonical field: {field}')
for field in ['direction_x','direction_y','held_bits','pressed_bits','released_bits']:
    check(field in replay_pair or field in replay_codec, f'Replay persistence preserves normalized InputFrame scalar: {field}')
check('expected := _data.initial_simulation_frame + _data.frames.size() + 1' in replay_recorder and 'p1_input.frame_number != expected' in replay_recorder, 'ReplayRecorder rejects duplicate/gap/out-of-order frames')
check('record_frame(consumed_a, consumed_b)' in battle_sim and battle_sim.find('record_frame(consumed_a, consumed_b)') < battle_sim.find('_simulate_round_active_tick(next_frame'), 'ReplayRecorder observes authoritative normalized/gated InputFrames before gameplay consumption')
check('extends InputSource' in replay_source and 'replay.get_frame_pair(frame_number)' in replay_source and 'InputFrame.neutral(frame_number)' in replay_source, 'ReplayInputSource is random-access normalized InputSource with neutral EOF')
replay_source_code='\n'.join(l for l in replay_source.splitlines() if not l.lstrip().startswith('#'))
check('Input.' not in replay_source_code and 'KEY_' not in replay_source_code, 'ReplayInputSource never polls raw keyboard/device input')
check('fighter.attack' not in replay_source_code.lower() and 'move_runner' not in replay_source_code.lower(), 'ReplayInputSource knows no gameplay actions/MoveRunner')
check('replay.match_rules_id != simulation.round_controller.rules.id' in replay_validator and 'replay.p1_character_id != simulation.fighter_a.data.id' in replay_validator and 'replay.p2_character_id != simulation.fighter_b.data.id' in replay_validator, 'Replay playback validates rules and participant character identities without auto-config')
check('simulation.state_signature() == replay.expected_final_state_hash' in replay_validator, 'Replay final verification reuses BattleStateHasher signature')
check('JSON.stringify' in replay_codec and 'JSON.parse_string' in replay_codec and 'FileAccess.open' in replay_codec, 'ReplayCodec is explicit JSON/FileAccess persistence boundary')
for forbidden in ['var_to_bytes','bytes_to_var','store_var','get_var','get_instance_id','ResourceLoader','load("res://']:
    check(forbidden not in replay_codec, f'ReplayCodec avoids unsafe/arbitrary object persistence: {forbidden}')
check('frame_number != expected_frame' in replay_codec and 'replay.is_structurally_valid(true)' in replay_codec, 'ReplayCodec validates continuous strict frame ordering on decode')
check('frame.direction_x < -1' in replay_pair and '~ReplayFormat.VALID_INPUT_MASK' in replay_pair, 'Replay frame validation rejects invalid direction/button bits')
check('ActionIntent' not in replay_data_code and 'InputBuffer' not in replay_data_code, 'Replay stores normalized InputFrame only, never ActionIntent/InputBuffer')

# Training/debug/presentation boundary.
check('match_rules_data: MatchRulesData' in scene_gd_m6 and 'res://data/match_rules/versus_match_rules.tres' in scene_tscn_m6, 'BattleScene binds MatchRulesData as configuration only')
for token in ['Rules:','Round State:','Round Wins:','Timer Frames:','Post Round:','Match Winner:']:
    check(token in debug_overlay_m6, f'F2 debug overlay exposes M6 lifecycle field: {token}')
for token in ['log_round_start','log_round_end','log_round_reset','log_match_winner','log_replay']:
    check(token in logger_m6, f'CombatLogger exposes sparse M6 diagnostic: {token}')
check('round_controller' in hud_m6.lower() and 'timer' in hud_m6.lower(), 'Battle HUD reads RoundController state as presentation only')

# M6 suites actually wired into headless runner.
m6_suites = {
 'MILESTONE_6_ROUND_FLOW_SUITE':'tests/match/test_milestone_6_round_flow.gd',
 'MILESTONE_6_TIMEOUT_SUITE':'tests/match/test_milestone_6_timeout.gd',
 'MILESTONE_6_TRAINING_SUITE':'tests/match/test_milestone_6_training.gd',
 'MILESTONE_6_REPLAY_DATA_SUITE':'tests/replay/test_replay_data.gd',
 'MILESTONE_6_REPLAY_INPUT_SOURCE_SUITE':'tests/replay/test_replay_input_source.gd',
 'MILESTONE_6_REPLAY_CODEC_SUITE':'tests/replay/test_replay_codec.gd',
 'MILESTONE_6_REPLAY_DETERMINISM_SUITE':'tests/replay/test_replay_determinism.gd',
 'MILESTONE_6_MATCH_SNAPSHOT_SUITE':'tests/snapshot/test_milestone_6_match_snapshot.gd',
}
for constant,rel in m6_suites.items():
    body=text(rel)
    check(f'preload("res://{rel}")' in run and f'{constant}.new().run_all()' in run, f'Headless runner wires M6 suite: {constant}')
    check('func run_all() -> int' in body and 'return t.failed' in body, f'M6 suite executable by common runner: {rel}')
m6_test_text='\n'.join(text(rel) for rel in m6_suites.values())
for token in ['POST_ROUND','Double KO','Timeout','hitstop','Training','Replay preserves held bits exactly','random-access','Codec','Fresh Battle','restore into Training rules is rejected','snapshot schema','temporary-entity cleanup']:
    check(token.lower() in m6_test_text.lower(), f'M6 authored tests cover: {token}')
for token in ['10,000','MATCH_OVER -> explicit full match reset','zone_vs_generic_projectiles','snapshot identity hash','Replay deterministic stress','1,800']:
    check(token in stress_test, f'M6 stress source covers: {token}')

# M6 architecture bans: no device/wall-clock/timer authority, no character branches, no extra InputButtons, no Replay state in gameplay snapshot.
m6_generic_paths = ['battle/battle_simulation.gd','battle/match/round_controller.gd','battle/replay/replay_recorder.gd','battle/replay/replay_input_source.gd','battle/replay/replay_validator.gd']
for rel in m6_generic_paths:
    code='\n'.join(l for l in text(rel).splitlines() if not l.lstrip().startswith('#')).lower()
    check(all(cid not in code for cid in ['generic_fighter','rush_grappler','zone_fighter']), f'M6 generic lifecycle/replay code has no concrete character-ID gameplay branch: {rel}')
for rel in ['battle/battle_simulation.gd','battle/match/round_controller.gd']:
    code='\n'.join(l for l in text(rel).splitlines() if not l.lstrip().startswith('#'))
    for forbidden in ['Timer','Time.get','OS.get','delta','_process(','_physics_process(']:
        check(forbidden not in code, f'M6 round gameplay authority avoids wall-clock/SceneTree timing token {forbidden}: {rel}')
check('InputFrame.InputButton.' not in match_rules_data, 'MatchRulesData does not alter InputButton contract')
# Replay classes are tooling/input layer and must not be inserted into gameplay snapshot state.
battle_snapshot_code='\n'.join(l for l in battle_snapshot.splitlines() if not l.lstrip().startswith('#'))
check('ReplayRecorder' not in battle_snapshot_code and 'ReplayInputSource' not in battle_snapshot_code and 'ReplayData' not in battle_snapshot_code, 'BattleStateSnapshot excludes Replay tooling runtime state')

# Source-level structural sanity for newly authored M6 GDScript: no tabs and balanced delimiters outside strings/comments.
def _balanced_gd(body):
    stack=[]; pairs={')':'(',']':'[','}':'{'}; opens=set(pairs.values()); quote=None; esc=False
    for raw in body.splitlines():
        line=raw
        i=0
        while i < len(line):
            c=line[i]
            if quote:
                if esc: esc=False
                elif c=='\\': esc=True
                elif c==quote: quote=None
                i+=1; continue
            if c in ['"', "'"]:
                quote=c; i+=1; continue
            if c=='#': break
            if c in opens: stack.append(c)
            elif c in pairs:
                if not stack or stack.pop()!=pairs[c]: return False
            i+=1
    return not stack and quote is None
m6_source_paths = [
 'data/match_rules_data.gd','battle/match/round_controller.gd','battle/simulation/round_state_snapshot.gd',
 'battle/replay/replay_format.gd','battle/replay/replay_frame_pair.gd','battle/replay/replay_data.gd','battle/replay/replay_recorder.gd',
 'battle/replay/replay_input_source.gd','battle/replay/replay_validator.gd','battle/replay/replay_codec.gd',
 'tests/match/test_milestone_6_round_flow.gd','tests/match/test_milestone_6_timeout.gd','tests/match/test_milestone_6_training.gd',
 'tests/replay/test_replay_data.gd','tests/replay/test_replay_input_source.gd','tests/replay/test_replay_codec.gd','tests/replay/test_replay_determinism.gd',
 'tests/snapshot/test_milestone_6_match_snapshot.gd'
]
for rel in m6_source_paths:
    body=text(rel)
    check('\t' not in body, f'M6 GDScript uses spaces/no tabs: {rel}')
    check(_balanced_gd(body), f'M6 GDScript delimiters structurally balanced: {rel}')


# M7 Presentation Foundation architecture contracts.
m7_paths = [
 'presentation/data/character_presentation_data.gd','presentation/data/move_presentation_binding.gd','presentation/data/state_presentation_binding.gd',
 'presentation/data/projectile_presentation_binding.gd','presentation/simulation_render_converter.gd','presentation/fighter/fighter_visual.gd',
 'presentation/visuals/greybox_fighter_visual.gd','presentation/fighter/fighter_presentation_resolver.gd','presentation/fighter/fighter_presentation_controller.gd',
 'presentation/projectiles/projectile_visual_presenter.gd','presentation/events/presentation_event_id.gd','presentation/events/presentation_event_ledger.gd',
 'presentation/feedback/combat_vfx_presenter.gd','presentation/feedback/combat_audio_presenter.gd','presentation/camera/battle_camera_controller.gd',
 'presentation/round/round_presentation_overlay.gd','presentation/battle_hud_view_model.gd','presentation/battle_hud.gd','presentation/battle_presentation_controller.gd'
]
for rel in m7_paths:
    check((ROOT/rel).exists(), f'M7 presentation source exists: {rel}')

presentation_data = text('presentation/data/character_presentation_data.gd')
for field in ['character_id','display_name','fighter_visual_scene','visual_offset_pixels','visual_scale','state_bindings','move_bindings','projectile_bindings']:
    check(re.search(rf'@export\s+var\s+{field}\s*:', presentation_data) is not None, f'CharacterPresentationData field exists: {field}')
check('duplicate state binding' in presentation_data and 'duplicate move binding' in presentation_data and 'duplicate projectile binding' in presentation_data,
      'CharacterPresentationData rejects duplicate state/move/projectile bindings')

presentation_resources = {
 'generic_fighter':'presentation/characters/generic_fighter_presentation.tres',
 'rush_grappler':'presentation/characters/rush_grappler_presentation.tres',
 'zone_fighter':'presentation/characters/zone_fighter_presentation.tres',
}
seen_presentation_ids=[]
for cid,rel in presentation_resources.items():
    body=text(rel)
    m=re.search(r'^character_id\s*=\s*&"([^"]+)"', body, re.M)
    pid=m.group(1) if m else ''
    seen_presentation_ids.append(pid)
    check(pid == cid, f'CharacterPresentationData ID matches CharacterData identity: {cid}')
    check(re.search(r'^display_name\s*=\s*".+"', body, re.M) is not None, f'{cid} presentation display_name non-empty')
    if cid == 'generic_fighter':
        check('production/salad_cat_visual.tscn' in body, 'generic_fighter presentation binds Salad Cat production FighterVisual scene')
        check('display_name = "Salad Cat"' in body, 'generic_fighter presentation display name is Salad Cat')
    elif cid == 'zone_fighter':
        check('production/magic_orange_cat_visual.tscn' in body, 'zone_fighter presentation binds Magic Orange Cat production FighterVisual scene')
        check('display_name = "Magic Orange Cat"' in body, 'zone_fighter presentation display name is Magic Orange Cat')
    else:
        check('greybox_fighter_visual.tscn' in body, f'{cid} presentation keeps replaceable greybox FighterVisual scene')
    for move_id in ['stand_light','stand_heavy','crouch_low','air_attack','ground_throw','special_neutral','ultimate']:
        check(f'move_id = &"{move_id}"' in body, f'{cid} presentation binds canonical Move ID {move_id}')
check(len(set(seen_presentation_ids)) == 3 and set(seen_presentation_ids)==set(presentation_resources.keys()), 'Three CharacterPresentationData IDs are unique and match gameplay roster')
zone_present=text('presentation/characters/zone_fighter_presentation.tres')
check('projectile_id = &"zone_shot"' in zone_present and 'projectile_id = &"zone_super_shot"' in zone_present, 'Zone presentation binds both stable projectile IDs')
check('animation_key = &"special_neutral"' in text(presentation_resources['generic_fighter']) and 'animation_key = &"special_neutral"' in zone_present and 'animation_key = &"ultimate"' in zone_present and 'rush_breaker' in text(presentation_resources['rush_grappler']),
      'Salad and Magic production presentations use canonical special_neutral/ultimate keys while Rush keeps its existing presentation mapping')

converter=text('presentation/simulation_render_converter.gd')
check('SIMULATION_UNITS_PER_PIXEL: float = 100.0' in converter and '/ SIMULATION_UNITS_PER_PIXEL' in converter, 'Single presentation converter enforces 100 simulation units = 1 pixel')
visual=text('presentation/visuals/greybox_fighter_visual.gd')
check('Rect2(Vector2(-28, -150)' in visual, 'Greybox FighterVisual uses feet-center local origin convention')
resolver=text('presentation/fighter/fighter_presentation_resolver.gd')
check('fighter.state_machine.state' in resolver and 'fighter.move_runner.current_move_id()' in resolver, 'Fighter presentation resolver reads authoritative HFSM state/current Move ID')
for cid in ['generic_fighter','rush_grappler','zone_fighter']:
    check(cid not in resolver, f'Generic FighterPresentationResolver has no concrete character branch: {cid}')
controller=text('presentation/fighter/fighter_presentation_controller.gd')
for forbidden in ['start_move(', 'gain(', 'spend(', 'apply_damage', 'transition_to(', 'spawn_from_descriptor(', 'reset_for_round(']:
    check(forbidden not in controller, f'FighterPresentationController never mutates gameplay through {forbidden}')

projectile_presenter=text('presentation/projectiles/projectile_visual_presenter.gd')
check('projectile.instance_id' in projectile_presenter and '_visuals[projectile.instance_id]' in projectile_presenter, 'Projectile presentation cache is keyed by deterministic ProjectileInstanceID')
check('SimulationRenderConverter.to_pixels(projectile.position_units)' in projectile_presenter and 'projectile.facing' in projectile_presenter, 'Projectile visuals read runtime position/captured facing')
check('projectile_system.active_projectiles()' in projectile_presenter and 'spawn_from_descriptor' not in projectile_presenter, 'Projectile visual presenter mirrors active state and never spawns gameplay projectile')

combat_event_m7=text('battle/combat/combat_event.gd')
for field in ['attack_instance_id','projectile_instance_id','round_number','round_result']:
    check(re.search(rf'var\s+{field}\s*:', combat_event_m7) is not None, f'CombatEvent carries deterministic presentation provenance: {field}')
for token in ['ROUND_STARTED','ROUND_ENDED','TIME_UP','MATCH_ENDED']:
    check(token in combat_event_m7, f'CombatEvent exposes presentation round lifecycle event: {token}')
check('CombatEvent.round_ended' in battle_sim and 'CombatEvent.time_up' in battle_sim and 'CombatEvent.round_started' in battle_sim and 'CombatEvent.match_ended' in battle_sim,
      'BattleSimulation emits presentation round events only after authoritative RoundController decisions')

event_id=text('presentation/events/presentation_event_id.gd')
for token in ['event.frame_number','event.type','event.attacker_id','event.defender_id','event.move_id','event.attack_instance_id','event.projectile_instance_id','event.round_number','event.round_result']:
    check(token in event_id, f'PresentationEventId canonical facts include {token}')
for forbidden in ['UUID','Time.','rand','randi','get_instance_id','RID','String.hash']:
    check(forbidden not in event_id, f'PresentationEventId avoids nondeterministic identity source: {forbidden}')
ledger=text('presentation/events/presentation_event_ledger.gd')
check('consume_once' in ledger and 'PresentationEventId.canonical' in ledger and 'clear()' in ledger and 'forget_after_frame' in ledger, 'PresentationEventLedger supports stable-ID dedupe/full reset/future rollback rewind seam')

battle_present=text('presentation/battle_presentation_controller.gd')
check('ledger.consume_once(event)' in battle_present and 'vfx_presenter.present_event(event)' in battle_present and 'audio_presenter.present_event(event)' in battle_present and 'camera_controller.present_event(event)' in battle_present,
      'BattlePresentationController dedupes one-shot events before VFX/audio/camera dispatch')
check('resync_all()' in battle_present and 'on_snapshot_restored' in battle_present and 'on_full_match_reset' in battle_present, 'Stateful presentation exposes resync/reset seams')
for forbidden in ['combatant.hp =','meter.gain(','meter.spend(','move_runner.start_move(','state_machine.transition_to(','projectile_system.spawn_from_descriptor(','round_controller._enter']:
    check(forbidden not in battle_present, f'BattlePresentationController does not mutate gameplay: {forbidden}')

hud_m7=text('presentation/battle_hud.gd')
hud_vm=text('presentation/battle_hud_view_model.gd')
for token in ['p1_hp','p2_hp','p1_meter','p2_meter','p1_wins','p2_wins','timer_text','training']:
    check(token in hud_vm, f'BattleHudViewModel exposes read-only HUD field: {token}')
for forbidden in ['meter.gain','meter.spend','combatant.apply','reset_for_round','round_controller.reset']:
    check(forbidden not in hud_m7.lower(), f'BattleHUD never mutates gameplay via {forbidden}')
round_overlay=text('presentation/round/round_presentation_overlay.gd')
for token in ['ROUND_STARTED','KO','TIME_UP','ROUND_ENDED','MATCH_ENDED','FIGHT','DRAW','MATCH OVER']:
    check(token in round_overlay, f'RoundPresentationOverlay maps presentation cue: {token}')
check('_process(delta: float)' in round_overlay and all(token not in round_overlay for token in ['reset_for_new_match(', 'reset_for_new_round(', 'evaluate_active_tick(', 'round_controller.state =', 'round_controller.round_timer_remaining_frames =']), 'Round overlay visual timing is presentation-local and not gameplay authority')

# Dependency direction: gameplay core cannot load presentation types/assets.
gameplay_dependency_paths=['battle/battle_simulation.gd','battle/combat/combat_resolver.gd','battle/match/round_controller.gd','fighter/fighter.gd','fighter/state_machine/fighter_state_machine.gd','fighter/moves/move_runner.gd','battle/simulation/battle_state_snapshot.gd','battle/simulation/battle_state_hasher.gd']
for rel in gameplay_dependency_paths:
    code='\n'.join(l for l in text(rel).splitlines() if not l.lstrip().startswith('#'))
    for forbidden in ['CharacterPresentationData','FighterPresentationController','BattleHUD','CombatVfxPresenter','CombatAudioPresenter','BattleCameraController','PackedScene','Texture2D','AudioStream']:
        check(forbidden not in code, f'Gameplay -> Presentation dependency forbidden ({forbidden}): {rel}')

snapshot_m7=text('battle/simulation/battle_state_snapshot.gd')
hasher_m7=text('battle/simulation/battle_state_hasher.gd')
replay_data_m7=text('battle/replay/replay_data.gd')
for token in ['CharacterPresentationData','animation_key','event_ledger','Camera','VFX','AudioStream','Texture2D']:
    check(token not in snapshot_m7, f'Battle snapshot v8 excludes presentation field/pointer: {token}')
    check(token not in hasher_m7, f'BattleStateHasher excludes presentation field: {token}')
    check(token not in replay_data_m7, f'ReplayData remains normalized gameplay input-only, excludes: {token}')
check('const VERSION: int = 8' in text('battle/simulation/battle_state_snapshot.gd'), 'M8 bumps gameplay Snapshot schema to v7 only for new authoritative Charge state')
check('SCHEMA_VERSION: int = 1' in replay_format and 'COMBAT_RULES_VERSION: int = 4' in replay_format, 'M8 keeps Replay input schema at 1 and bumps combat-rules compatibility to 4 for Charge gameplay semantics')

scene_m7=text('battle/battle_scene.gd')
scene_tscn_m7=text('battle/battle_scene.tscn')
check('character_a_presentation: CharacterPresentationData' in scene_m7 and 'character_b_presentation: CharacterPresentationData' in scene_m7, 'BattleScene owns gameplay/presentation pair configuration')
check('presentation_controller.consume_events(simulation.drain_events())' in scene_m7 and 'presentation_controller.sync_from_simulation()' in scene_m7, 'BattleScene drains simulation events one-way into presentation and syncs latest state')
check('generic_fighter_presentation.tres' in scene_tscn_m7 and 'zone_fighter_presentation.tres' in scene_tscn_m7 and 'BattlePresentationController' in scene_tscn_m7, 'Default M7 scene binds production Generic/Zone presentation resources/controller')

m7_suites={
 'MILESTONE_7_CHARACTER_PRESENTATION_DATA_SUITE':'tests/presentation/test_character_presentation_data.gd',
 'MILESTONE_7_FIGHTER_PRESENTATION_RESOLVER_SUITE':'tests/presentation/test_fighter_presentation_resolver.gd',
 'MILESTONE_7_PRESENTATION_EVENT_IDENTITY_SUITE':'tests/presentation/test_presentation_event_identity.gd',
 'MILESTONE_7_PROJECTILE_PRESENTATION_SUITE':'tests/presentation/test_projectile_presentation.gd',
 'MILESTONE_7_BATTLE_HUD_SUITE':'tests/presentation/test_battle_hud.gd',
 'MILESTONE_7_FEEDBACK_PRESENTERS_SUITE':'tests/presentation/test_feedback_presenters.gd',
 'MILESTONE_7_GAMEPLAY_SEPARATION_SUITE':'tests/presentation/test_presentation_gameplay_separation.gd',
 'MILESTONE_7_REPLAY_RESIM_SUITE':'tests/presentation/test_presentation_replay_resim.gd',
}
m7_test_text='\n'.join(text(rel) for rel in m7_suites.values())
for constant,rel in m7_suites.items():
    check(f'preload("res://{rel}")' in run and f'{constant}.new().run_all()' in run, f'Headless runner wires M7 presentation suite: {constant}')
    check('func run_all() -> int' in text(rel) and 'return t.failed' in text(rel), f'M7 suite follows executable common runner contract: {rel}')
for token in ['duplicate move binding','walk_forward','guard_crouch','special_neutral','100 simulation units','ProjectileInstanceID','Training timer','TIME UP','MATCH OVER','different AttackInstanceID','Duplicate HIT event','identical BattleStateHash','Snapshot restore','Fresh replay playback']:
    check(token.lower() in m7_test_text.lower(), f'M7 authored presentation tests cover: {token}')

# Presentation production files may use render delta/Tween, but may never call known gameplay mutators.
for rel in m7_paths:
    body='\n'.join(l for l in text(rel).splitlines() if not l.lstrip().startswith('#'))
    for forbidden in ['Combatant.apply_damage','combatant.receive_hit','Meter.gain','meter.gain(','meter.spend(','MoveRunner.start_move','move_runner.start_move(','state_machine.transition_to(','ProjectileSystem.spawn','projectile_system.spawn_from_descriptor(','round_controller.reset_match(']:
        check(forbidden not in body, f'Presentation production source does not call gameplay mutator {forbidden}: {rel}')

# Source structural sanity for M7 GDScript.
for rel in m7_paths + list(m7_suites.values()):
    body=text(rel)
    check('\t' not in body, f'M7 GDScript uses spaces/no tabs: {rel}')
    check(_balanced_gd(body), f'M7 GDScript delimiters structurally balanced: {rel}')


# M7 prior-milestone defect regression + documentation handoff.
battle_sim_m7 = text('battle/battle_simulation.gd')
post_round_body = battle_sim_m7.split('func _simulate_post_round_tick', 1)[1].split('func _reset_round_runtime', 1)[0] if 'func _simulate_post_round_tick' in battle_sim_m7 else ''
check(post_round_body.count('fighter_a.movement_tick()') == 1 and post_round_body.count('fighter_b.movement_tick()') == 1, 'POST_ROUND settles each Fighter movement exactly once (M6 asymmetry regression fixed)')
check('_test_post_round_mirror_settlement_is_symmetric' in text('tests/match/test_milestone_6_round_flow.gd'), 'M7 wires source regression for symmetric POST_ROUND movement settlement')
check('M7 Presentation Boundary' in text('ARCHITECTURE.md'), 'ARCHITECTURE documents the M7 one-way Presentation boundary')
check('M7 Presentation Guardrails' in text('CONTRIBUTING_AI.md'), 'CONTRIBUTING_AI documents M7 Presentation authority guardrails')
check('M7 COMPLETE — Presentation Foundation' in text('README.md'), 'README documents M7 Presentation Foundation and headless boundary')
check('_event_queue.append(CombatEvent.round_started(frame_number, round_controller.round_number))' in battle_sim_m7, 'New BattleSimulation configuration/full reset exposes deterministic ROUND_STARTED presentation output')
check('presentation_controller.consume_events(simulation.drain_events())' in text('battle/battle_scene.gd'), 'BattleScene routes initial ROUND_STARTED through the shared presentation ledger/cue pipeline')



# M8 Solo Playtest + Charge architecture contracts.
for rel in [
    'frontend/mode_select_scene.gd', 'frontend/mode_select_scene.tscn',
    'battle/match/battle_mode.gd', 'battle/match/battle_input_wiring.gd',
    'fighter/input/cpu_input_source.gd', 'data/moves/charge_special_data.gd',
    'tests/m8/test_m8_cpu_input_source.gd', 'tests/m8/test_m8_charge_special.gd', 'tests/m8/test_m8_cpu_replay.gd',
]:
    check((ROOT/rel).exists(), f'M8 required file exists: {rel}')

mode_select=text('frontend/mode_select_scene.tscn')
battle_scene_m8=text('battle/battle_scene.gd')
wiring=text('battle/match/battle_input_wiring.gd')
cpu=text('fighter/input/cpu_input_source.gd')
charge_data=text('data/moves/charge_special_data.gd')
fsm_m8=text('fighter/state_machine/fighter_state_machine.gd')
move_data_m8=text('data/move_data.gd')
move_ids_m8=text('data/move_ids.gd')
snapshot_m8=text('battle/simulation/fighter_state_snapshot.gd')
snapshot_codec_m8=text('battle/simulation/fighter_snapshot_codec.gd')
hasher_m8=text('battle/simulation/battle_state_hasher.gd')
run_m8=text('tests/run_tests.gd')

check('1P VS CPU' in mode_select and '2P LOCAL' in mode_select, 'M8 Mode Select exposes VS_CPU and LOCAL_2P playtest choices')
check('BattleInputWiring.create_p1_source()' in battle_scene_m8 and 'BattleInputWiring.create_p2_source(battle_mode)' in battle_scene_m8, 'BattleScene delegates mode-only InputSource wiring without gameplay branching')
check('KEY_W, KEY_A, KEY_S, KEY_D, KEY_U, KEY_I, KEY_J, KEY_K, KEY_L' in wiring, 'P1 desktop mapping remains WASD/U/I/J/K/L')
check('KEY_UP, KEY_LEFT, KEY_DOWN, KEY_RIGHT, KEY_M, KEY_COMMA, KEY_PERIOD, KEY_SLASH, KEY_SEMICOLON' in wiring, 'P2 LOCAL desktop mapping remains Arrows/M/,/./slash/semicolon')
check('return CpuInputSource.new()' in wiring and 'mode == BattleMode.Mode.VS_CPU' in wiring, 'VS_CPU mode changes only P2 InputSource construction')
check('extends InputSource' in cpu and 'func sample(frame_number: int) -> InputFrame' in cpu, 'CPU implements canonical InputSource contract')
cpu_code='\n'.join(line for line in cpu.splitlines() if not line.lstrip().startswith('#'))
check('Input.is_key_pressed' not in cpu_code and 'RandomNumberGenerator' not in cpu_code and 'randf(' not in cpu_code and 'randi(' not in cpu_code and 'Time.' not in cpu_code and 'OS.get_ticks' not in cpu_code, 'CPU uses no keyboard polling, wall-clock time, or nondeterministic RNG')
for forbidden in ['.hp =', '.meter =', '.sim_position =', 'start_move(', 'transition_to(', 'receive_hit(', 'apply_damage', 'spawn_from_descriptor(']:
    check(forbidden not in cpu, f'CPU source cannot mutate gameplay via {forbidden}')
check('pressed := held & ~_previous_held_bits' in cpu and 'released := _previous_held_bits & ~held' in cpu, 'CPU computes canonical pressed/released edges from held bits')
check('REACTION_INTERVAL_FRAMES: int = 8' in cpu and 'CLOSE_DISTANCE_UNITS: int = 12000' in cpu and 'MID_DISTANCE_UNITS: int = 26000' in cpu, 'CPU v1 deterministic tuning uses 8F reaction and simulation-unit spacing bands')
check('&"throw"' in cpu and 'direction_x = facing' in cpu and 'InputFrame.InputButton.HEAVY' in cpu, 'CPU Throw is represented as facing-relative Forward + Heavy input')
check('_can_use_ultimate()' in cpu and 'meter.can_spend(move.meter_cost)' in cpu, 'CPU Ultimate decision respects authoritative MoveData meter cost')
check('_sample_charge' in cpu and '_charge_target_frames' in cpu and 'InputFrame.InputButton.SPECIAL' in cpu, 'CPU charge plan emits real Special press/hold/release edges through InputFrame')

check('class_name ChargeSpecialData' in charge_data and 'level_2_threshold_frames' in charge_data and 'level_3_threshold_frames' in charge_data, 'ChargeSpecialData is typed immutable configuration resource')
check('@export var charge_special_data: ChargeSpecialData' in move_data_m8, 'MoveData owns optional typed ChargeSpecialData entry configuration')
check('SPECIAL_NEUTRAL_L2' in move_ids_m8 and 'SPECIAL_NEUTRAL_L3' in move_ids_m8, 'M8 defines stable Lv2/Lv3 Special Move IDs')
check('CHARGE' in fsm_m8 and 'charge_frames' in fsm_m8 and 'charge_entry_move_id' in fsm_m8, 'FighterStateMachine owns generic authoritative CHARGE runtime state')
check('charge_frames += 1' in fsm_m8 and 'parser.special_released or not parser.special_held' in fsm_m8, 'Charge advances in simulation frames and releases only on Special release/not-held')
check('runner.interrupt()' in fsm_m8 and '_enter_charge(target_move_id' in fsm_m8, 'Heavy->Special data cancel can interrupt old AttackInstance and enter CHARGE')
check('State.CHARGE' in fsm_m8 and 'return true' in fsm_m8.split('func is_facing_locked',1)[1].split('func ',1)[0], 'Charge locks facing as committed grounded state')
check('State.CHARGE' in text('fighter/movement/movement_motor.gd') and '_ground_horizontal(0)' in text('fighter/movement/movement_motor.gd'), 'Charge movement is immobile while remaining grounded')

for rel in ['data/moves/special_neutral.tres','data/moves/rush_grappler/special_neutral.tres','data/moves/zone_fighter/special_neutral.tres']:
    body=text(rel)
    check('level_2_threshold_frames = 24' in body and 'level_3_threshold_frames = 54' in body, f'Charge thresholds 24F/54F are data-defined: {rel}')
    check('&"special_neutral_l2"' in body and '&"special_neutral_l3"' in body, f'Charge entry maps to stable L2/L3 IDs: {rel}')
for prefix in ['', 'rush_grappler/', 'zone_fighter/']:
    check((ROOT/f'data/moves/{prefix}special_neutral_l2.tres').exists() and (ROOT/f'data/moves/{prefix}special_neutral_l3.tres').exists(), f'Generic character move family has Lv2/Lv3 resources: {prefix or "generic"}')
check((ROOT/'data/projectiles/zone_shot_l2.tres').exists() and (ROOT/'data/projectiles/zone_shot_l3.tres').exists(), 'Zone charge levels reuse generic ProjectileData/ProjectileSystem path')

check('charge_frames' in snapshot_m8 and 'charge_entry_move_id' in snapshot_m8 and 'charge_locked_facing' in snapshot_m8, 'FighterStateSnapshot stores all future-affecting Charge primitives/IDs')
check('s.charge_frames = fighter.state_machine.charge_frames' in snapshot_codec_m8 and 'fighter.move_registry.get_move(fighter.state_machine.charge_entry_move_id)' in snapshot_codec_m8, 'Charge snapshot restores primitive state and re-resolves configuration through Fighter MoveRegistry')
check(':charge=' in hasher_m8 and 's.charge_frames' in hasher_m8 and 's.charge_entry_move_id' in hasher_m8, 'BattleStateHasher includes Charge state in canonical order')
check('charge' not in text('battle/replay/replay_data.gd').lower(), 'ReplayData does not store derived charge level/state; only canonical InputFrames')
check('CPU' not in text('battle/replay/replay_data.gd') and 'decision' not in text('battle/replay/replay_data.gd').lower(), 'ReplayData does not store CPU decision state')

m8_suites={
 'MILESTONE_8_CPU_INPUT_SUITE':'tests/m8/test_m8_cpu_input_source.gd',
 'MILESTONE_8_CHARGE_SPECIAL_SUITE':'tests/m8/test_m8_charge_special.gd',
 'MILESTONE_8_CPU_REPLAY_SUITE':'tests/m8/test_m8_cpu_replay.gd',
}
for constant,rel in m8_suites.items():
    check(f'preload("res://{rel}")' in run_m8 and f'{constant}.new().run_all()' in run_m8, f'Headless runner registers M8 suite: {constant}')
    check('func run_all() -> int' in text(rel) and 'return t.failed' in text(rel), f'M8 suite follows executable runner contract: {rel}')

for rel in ['battle/match/battle_mode.gd','battle/match/battle_input_wiring.gd','fighter/input/cpu_input_source.gd','data/moves/charge_special_data.gd','tests/m8/test_m8_cpu_input_source.gd','tests/m8/test_m8_charge_special.gd','tests/m8/test_m8_cpu_replay.gd']:
    body=text(rel)
    check('\t' not in body, f'M8 GDScript uses spaces/no tabs: {rel}')
    check(_balanced_gd(body), f'M8 GDScript delimiters structurally balanced: {rel}')

# Production character asset integration contracts.
production_paths = [
    'scripts/build_character_assets.py', 'scripts/validate_presentation_assets.py',
    'presentation/visuals/production/production_fighter_visual.gd',
    'presentation/visuals/production/salad_cat_visual.tscn',
    'presentation/visuals/production/magic_orange_cat_visual.tscn',
    'presentation/preview/character_preview.gd', 'presentation/preview/character_preview.tscn',
    'assets/characters/salad_cat/animations/manifest.json',
    'assets/characters/magic_orange_cat/animations/manifest.json'
]
for rel in production_paths:
    check((ROOT/rel).exists(), f'Production presentation asset exists: {rel}')
check(len(list((ROOT/'assets/characters/salad_cat/sprites').rglob('*.webp'))) == 250, 'Salad Cat has exactly 250 runtime WebP frames')
check(len(list((ROOT/'assets/characters/magic_orange_cat/sprites').rglob('*.webp'))) == 250, 'Magic Orange Cat has exactly 250 runtime WebP frames')
check('character_id = &"generic_fighter"' in text('presentation/characters/generic_fighter_presentation.tres'), 'Salad Cat keeps stable generic_fighter gameplay identity')
check('magic_orange_cat' not in text('battle/replay/replay_format.gd'), 'Magic Orange Cat does not create Replay gameplay identity')
for rel in ['presentation/visuals/production/production_fighter_visual.gd', 'presentation/preview/character_preview.gd']:
    body = text(rel)
    check('\t' not in body, f'Production presentation GDScript uses spaces/no tabs: {rel}')
    check(_balanced_gd(body), f'Production presentation GDScript delimiters structurally balanced: {rel}')
    for forbidden in ['apply_damage', 'receive_hit', 'meter.gain(', 'meter.spend(', 'move_runner.start_move(', 'state_machine.transition_to(', 'spawn_from_descriptor(']:
        check(forbidden not in body, f'Production presentation source excludes gameplay mutator {forbidden}: {rel}')


# M9P Multi-Pack Production Presentation architecture contracts.
m9p_required = [
    'presentation/data/presentation_asset_pack_type.gd',
    'presentation/data/mode_presentation_binding.gd',
    'presentation/data/effect_presentation_binding.gd',
    'presentation/data/ultimate_presentation_binding.gd',
    'presentation/data/attachment_presentation_binding.gd',
    'presentation/effects/world_effect_presenter.gd',
    'presentation/ultimates/ultimate_screen_presenter.gd',
    'presentation/ultimates/ultimate_screen_visual.gd',
    'presentation/attachments/attachment_presenter.gd',
    'presentation/visuals/production/production_world_effect_visual.gd',
    'presentation/visuals/production/production_projectile_visual.gd',
    'scripts/build_mode_character_assets.py',
    'scripts/build_effect_assets.py',
    'scripts/build_ultimate_screen_assets.py',
    'scripts/presentation_asset_pipeline/common.py',
    'docs/production_art_asset_contract.md',
    'docs/production_character_prompt_template.md',
    'docs/art_requirements/salad_cat.md',
    'docs/art_requirements/doge.md',
    'docs/art_requirements/magic_orange_cat.md',
    'docs/art_requirements/pink_star.md',
]
for rel in m9p_required:
    check((ROOT/rel).exists(), f'M9P required file exists: {rel}')

pack_type=text('presentation/data/presentation_asset_pack_type.gd')
for token in ['BASE_FIGHTER','MODE_FIGHTER','WORLD_EFFECT','PROJECTILE','HAZARD','ULTIMATE_SCREEN','ATTACHMENT']:
    check(token in pack_type, f'M9P PresentationAssetPackType exposes domain: {token}')

presentation_data_m9p=text('presentation/data/character_presentation_data.gd')
for field in ['mode_bindings','ultimate_bindings','effect_bindings','attachment_bindings','socket_offsets']:
    check(re.search(rf'@export\s+var\s+{field}\s*:', presentation_data_m9p) is not None, f'CharacterPresentationData M9P field exists: {field}')
for lookup in ['mode_binding(','ultimate_binding(','effect_binding(','attachment_binding(','effects_for_move(']:
    check(lookup in presentation_data_m9p, f'CharacterPresentationData exposes typed M9P lookup: {lookup}')

mode_binding=text('presentation/data/mode_presentation_binding.gd')
check('mode_id' in mode_binding and 'fighter_visual_scene' in mode_binding and 'visual_scale' in mode_binding and 'visual_offset_pixels' in mode_binding, 'ModePresentationBinding carries mode scene/scale/offset only')
attachment_binding=text('presentation/data/attachment_presentation_binding.gd')
check('socket_id' in attachment_binding and 'offset_pixels' in attachment_binding and 'rotation_degrees' in attachment_binding and 'mirror_with_facing' in attachment_binding, 'AttachmentPresentationBinding is socket-based')

a_base=json.loads(text('assets/characters/salad_cat/animations/manifest.json'))
a_magic=json.loads(text('assets/characters/magic_orange_cat/animations/manifest.json'))
for asset_key, manifest in [('salad_cat',a_base),('magic_orange_cat',a_magic)]:
    check(manifest.get('manifest_version') == 3 and manifest.get('asset_version') == 3, f'{asset_key} BASE_FIGHTER manifest upgraded to v3')
    check(manifest.get('pack_type') == 'BASE_FIGHTER' and manifest.get('mode_id') == '', f'{asset_key} remains backward-compatible BASE_FIGHTER pack')
    check(manifest.get('frame_count') == 250 and manifest.get('sheet_count') == 10, f'{asset_key} preserves 10-sheet/250-frame base contract')

base_builder=text('scripts/build_character_assets.py')
check('ASSET_VERSION = 3' in base_builder and '"pack_type": "BASE_FIGHTER"' in base_builder and '"mode_id": ""' in base_builder, 'Base builder emits M9P manifest v3 without changing 250-frame contract')
mode_builder=text('scripts/build_mode_character_assets.py')
check('PACK_TYPE = "MODE_FIGHTER"' in mode_builder and 'TIGHT_PIVOT' in mode_builder and 'square_canvas_required' in mode_builder and 'resize_body' in mode_builder, 'Mode builder uses manifest-driven tight-pivot non-square output')
check('TOTAL_FRAMES = 250' not in mode_builder and 'SHEETS_PER_CHARACTER = 10' not in mode_builder, 'MODE_FIGHTER builder has no 250-frame/10-sheet hard requirement')
effect_builder=text('scripts/build_effect_assets.py')
for token in ['PROJECTILE','WORLD_EFFECT','HAZARD','ATTACHMENT','horizontal_strip','vertical_strip','grid']:
    check(token in effect_builder, f'Effect builder supports {token}')
check('square_canvas_required' in effect_builder and 'aspect_ratio_restriction' in effect_builder and 'resize_effect' in effect_builder, 'Effect builder explicitly preserves arbitrary aspect ratio/source scale')
ultimate_builder=text('scripts/build_ultimate_screen_assets.py')
check('TARGET_SIZE = (1280, 720)' in ultimate_builder and 'TARGET_RATIO = 16.0 / 9.0' in ultimate_builder and 'Image.Resampling.LANCZOS' in ultimate_builder, 'ULTIMATE_SCREEN builder outputs canonical 1280x720 with aspect-preserving normalization')

fighter_controller_m9p=text('presentation/fighter/fighter_presentation_controller.gd')
check('apply_authoritative_mode_id' in fighter_controller_m9p and 'data.mode_binding(mode_id)' in fighter_controller_m9p and '_swap_visual' in fighter_controller_m9p, 'FighterPresentationController exposes one-way authoritative mode visual swap')
for forbidden in ['state_machine.transition_to(', 'move_runner.start_move(', 'combatant.hp =', 'meter.spend(', 'apply_damage']:
    check(forbidden not in fighter_controller_m9p, f'M9P mode visual swap never mutates gameplay via {forbidden}')
fighter_visual_m9p=text('presentation/fighter/fighter_visual.gd')
check('socket_world_position' in fighter_visual_m9p and 'set_visual_scale_multiplier' in fighter_visual_m9p, 'FighterVisual supports Presentation-only sockets and mode visual scale')

world_effect_presenter=text('presentation/effects/world_effect_presenter.gd')
check('EffectPresentationBinding' in world_effect_presenter and 'present_event(event: CombatEvent' in world_effect_presenter and 'present_effect(' in world_effect_presenter, 'WorldEffectPresenter supports event-driven and manual detached effects')
for forbidden in ['apply_damage','start_move(','transition_to(','spawn_from_descriptor(','projectile_system.']:
    check(forbidden not in world_effect_presenter, f'WorldEffectPresenter never mutates gameplay through {forbidden}')
ultimate_presenter=text('presentation/ultimates/ultimate_screen_presenter.gd')
check('extends CanvasLayer' in ultimate_presenter and 'CombatEvent.EventType.MOVE_STARTED' in ultimate_presenter and 'event.move_id != &"ultimate"' in ultimate_presenter, 'UltimateScreenPresenter is screen-space and follows existing MOVE_STARTED event facts')
for forbidden in ['hitstop','simulation_frame','start_move(','apply_damage','pause']:
    check(forbidden not in ultimate_presenter.lower(), f'UltimateScreenPresenter does not own gameplay timing/freeze through {forbidden}')

preview_m9p=text('presentation/preview/character_preview.gd')
for token in ['PackTypePicker','AssetPicker','MODE_FIGHTER','PROJECTILE','WORLD_EFFECT','HAZARD','ULTIMATE_SCREEN','ATTACHMENT']:
    check(token in preview_m9p or token in text('presentation/preview/character_preview.tscn'), f'M9P Preview exposes {token}')
check('BattleSimulation.new' not in preview_m9p and 'Input.' not in preview_m9p, 'M9P asset preview has no gameplay/input authority')

contract=text('docs/production_art_asset_contract.md')
check('PRODUCTION ART IS MULTI-PACK' in contract and 'Gameplay Entity and Presentation Asset are separate concepts' in contract, 'Production Art Contract states multi-pack/gameplay separation rule')
prompt_template=text('docs/production_character_prompt_template.md')
for phrase in ['full projectile travel','full-screen Ultimate background','complete transformed-mode moveset']:
    check(phrase in prompt_template, f'Production Character Prompt explicitly excludes {phrase} from body pack')

# Gameplay authority must not depend on M9P presentation types/textures.
m9p_gameplay_paths = [
    'battle/battle_simulation.gd', 'battle/combat/combat_resolver.gd',
    'fighter/fighter.gd', 'fighter/moves/move_runner.gd',
    'battle/projectiles/projectile_system.gd',
    'battle/simulation/battle_state_hasher.gd', 'battle/simulation/battle_state_snapshot.gd',
    'battle/replay/replay_data.gd'
]
for rel in m9p_gameplay_paths:
    code='\n'.join(line for line in text(rel).splitlines() if not line.lstrip().startswith('#'))
    for forbidden in ['PresentationAssetPackType','ModePresentationBinding','UltimatePresentationBinding','EffectPresentationBinding','AttachmentPresentationBinding','Texture2D','SpriteFrames']:
        check(forbidden not in code, f'M9P gameplay -> Presentation dependency forbidden ({forbidden}): {rel}')

m9p_tests = {
    'MILESTONE_9P_MODE_BINDING_SUITE':'tests/presentation/m9p/test_mode_presentation_binding.gd',
    'MILESTONE_9P_MODE_SWAP_SUITE':'tests/presentation/m9p/test_mode_visual_swap.gd',
    'MILESTONE_9P_RECT_MODE_SUITE':'tests/presentation/m9p/test_rectangular_mode_frames.gd',
    'MILESTONE_9P_EFFECT_PACK_SUITE':'tests/presentation/m9p/test_effect_pack.gd',
    'MILESTONE_9P_PROJECTILE_PACK_SUITE':'tests/presentation/m9p/test_projectile_visual_pack.gd',
    'MILESTONE_9P_HAZARD_PACK_SUITE':'tests/presentation/m9p/test_hazard_visual_pack.gd',
    'MILESTONE_9P_ULTIMATE_PACK_SUITE':'tests/presentation/m9p/test_ultimate_screen_pack.gd',
    'MILESTONE_9P_ULTIMATE_ASPECT_SUITE':'tests/presentation/m9p/test_ultimate_screen_aspect.gd',
    'MILESTONE_9P_BASE_REGRESSION_SUITE':'tests/presentation/m9p/test_base_pack_regression.gd',
    'MILESTONE_9P_SEPARATION_SUITE':'tests/presentation/m9p/test_presentation_gameplay_separation_m9p.gd',
}
for constant, rel in m9p_tests.items():
    check((ROOT/rel).exists(), f'M9P test file exists: {rel}')
    check(f'preload("res://{rel}")' in run_m8 and f'{constant}.new().run_all()' in run_m8, f'Headless runner registers M9P suite: {constant}')
    body=text(rel)
    check('func run_all() -> int' in body and 'return t.failed' in body, f'M9P suite follows executable runner contract: {rel}')
    check('\t' not in body and _balanced_gd(body), f'M9P test source is structurally clean: {rel}')

for msg in passes:
    print('[PASS]',msg)
if errors:
    for msg in errors:
        print('[FAIL]',msg,file=sys.stderr)
    print(f'\nStatic validation: {len(passes)} passed, {len(errors)} failed')
    sys.exit(1)
print(f'\nStatic validation: {len(passes)} passed, 0 failed')
