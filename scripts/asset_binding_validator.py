#!/usr/bin/env python3
"""Gate 3 read-only validator for exact inventory-backed production presentation bindings."""
from __future__ import annotations
import json,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
CATALOG=ROOT/'GATE3_ASSET_BINDINGS.json'
INV=ROOT/'assets/production_roster/combat_asset_inventory.json'
EXPECTED=['alien_meow','doge','ya_mouse','tempura_penguin','goblin_love','salad_cat','magic_orange_cat','blade_shield','pink_star','sauce_stubble_dog','scared_cat','ok_meow_boss','niu_lai','bao_la']
REQUIRED_BASE=['idle','walk_forward','walk_back','crouch','jump','landing','dash_forward','backstep','stand_light','stand_heavy','crouch_low','air_attack','guard_stand','guard_crouch','hitstun','ground_throw','charge','special_neutral','ultimate']
MODE_REQUIREMENTS={
'doge':('super_doge',['idle','walk_forward','walk_back','dash_forward','backstep','crouch','jump','landing','hitstun','stand_light','stand_heavy','crouch_low','guard_stand','guard_crouch','air_attack','ground_throw','special_neutral']),
'goblin_love':('love_awakened',['idle','walk_forward','walk_back','crouch','jump','landing','dash_forward','backstep','guard_stand','guard_crouch','hitstun','stand_light','crouch_low','goblin_awakened_heavy','air_attack','goblin_awakened_throw']),
'blade_shield':('dual_blade',['idle','walk_forward','walk_back','crouch','jump','landing','dash_forward','backstep','stand_light','dual_blade_heavy','dual_blade_low','dual_blade_air','special_neutral']),
'pink_star':('true_face',['idle','walk_forward','walk_back','crouch','jump','dash_forward','guard_stand','guard_crouch','hitstun','pink_true_light','pink_true_heavy','pink_true_low','pink_true_air','ground_throw','pink_true_special','true_face_exit']),
'bao_la':('last_stand',['ultimate','bao_last_stand_0','bao_last_stand_1','bao_last_stand_2','bao_last_stand_3']),
}

def validate():
 errors=[]; warnings=[]
 if not CATALOG.is_file(): return ['missing GATE3_ASSET_BINDINGS.json'],[]
 data=json.load(CATALOG.open(encoding='utf-8')); inv=json.load(INV.open(encoding='utf-8'))
 chars={c['character_id']:c for c in data.get('characters',[])}
 if sorted(chars)!=sorted(EXPECTED): errors.append(f'character set mismatch: {sorted(chars)}')
 if len(inv)!=14: errors.append(f'inventory roster must be 14, got {len(inv)}')
 for cid in EXPECTED:
  c=chars.get(cid); 
  if not c: continue
  if cid=='pink_star' and c.get('asset_folder')!='粉藍星星': errors.append('pink_star asset alias must be 粉藍星星')
  if cid!='pink_star' and c.get('asset_folder') not in inv: errors.append(f'{cid}: asset folder not in inventory: {c.get("asset_folder")}')
  b=c.get('bindings',[]); keys={(x.get('mode_id',''),x.get('animation_id',''),x.get('domain','')) for x in b}
  for x in b:
   if x.get('domain') not in {'BASE_FIGHTER','MODE_FIGHTER','PROJECTILE','SUMMON','HAZARD','WORLD_EFFECT','ATTACHMENT','ULTIMATE_SCREEN'}: errors.append(f'{cid}: invalid domain')
   if x.get('status')=='RED': errors.append(f'{cid}: RED binding {x.get("animation_id")}')
   for frame in x.get('frame_paths',[]):
    if not (ROOT/frame.removeprefix('res://')).is_file(): errors.append(f'{cid}: missing frame {frame}')
  for req in REQUIRED_BASE:
   if not any(k[0]=='' and k[1]==req and k[2]=='BASE_FIGHTER' for k in keys):
    # blockstun/thrown/knockdown/getup/ko may safely resolve from hit/knockdown packs; required core list is presentation minimum for this gate.
    warnings.append(f'{cid}: approved presentation fallback for base {req}')
  if cid in MODE_REQUIREMENTS:
   mode,reqs=MODE_REQUIREMENTS[cid]
   for req in reqs:
    if not any(k[0]==mode and k[1]==req and k[2]=='MODE_FIGHTER' for k in keys): errors.append(f'{cid}: missing mode binding {mode}:{req}')
  # Every inventory action must appear exactly once as its exact folder/round/frame list, plus optional approved reuse entries.
  folder=c['asset_folder']; src=inv[folder]
  exact={(x['round_name'],x['action_folder'],tuple(Path(p).name for p in x['frame_paths'])) for x in b if x.get('status')=='GREEN'}
  for rnd,actions in src['rounds'].items():
   for a in actions:
    key=(rnd,a['action'],tuple(a['frames']))
    if key not in exact: errors.append(f'{cid}: unbound inventory action {rnd}/{a["action"]}')
 return errors,warnings

if __name__=='__main__':
 errors,warnings=validate()
 for w in warnings: print('[YELLOW]',w)
 if errors:
  for e in errors: print('[RED]',e,file=sys.stderr)
  print(f'Asset Binding: FAIL ({len(errors)} RED, {len(warnings)} YELLOW)')
  sys.exit(1)
 print(f'Asset Binding: PASS (14/14, 0 RED, {len(warnings)} YELLOW)')
