#!/usr/bin/env python3
from __future__ import annotations
import json,re,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
INV=ROOT/'assets/production_roster/combat_asset_inventory.json'
OUT=ROOT/'presentation/resources/production_asset_bindings'
EXPORT=ROOT/'GATE3_ASSET_BINDINGS.json'
CHARACTERS={
'Alien Meow':('alien_meow','Alien Meow','Alien Meow'),
'Doge':('doge','Doge','Doge'),
'YA鼠':('ya_mouse','YA鼠','YA鼠'),
'Oh fuxking 天婦羅尬哩涼':('tempura_penguin','Oh fuxking 天婦羅尬哩涼','Oh fuxking 天婦羅尬哩涼'),
'哥布林也想談戀愛':('goblin_love','哥布林也想談戀愛','哥布林也想談戀愛'),
'沙拉貓貓':('salad_cat','沙拉貓貓','沙拉貓貓'),
'魔法胖橘貓':('magic_orange_cat','魔法胖橘貓','魔法胖橘貓'),
'我的刀盾':('blade_shield','我的刀盾','我的刀盾'),
'粉藍星星':('pink_star','粉紅星星','粉藍星星'),
'蘸醬胡渣狗':('sauce_stubble_dog','蘸醬胡渣狗','蘸醬胡渣狗'),
'驚嚇小貓':('scared_cat','驚嚇小貓','驚嚇小貓'),
'OK喵老大':('ok_meow_boss','OK喵老大','OK喵老大'),
'牛來':('niu_lai','牛來','牛來'),
'豹拉':('bao_la','豹拉','豹拉'),
}
SPECIALS={
'alien_meow':['alien_scan_l1','alien_scan_l2','alien_scan_l3'], 'doge':['doge_rush_l1','doge_rush_l2','doge_rush_l3'],
'ya_mouse':['ya_wave_l1','ya_wave_l2','ya_wave_l3'], 'tempura_penguin':['penguin_rush_l1','penguin_rush_l2','penguin_rush_l3'],
'goblin_love':['goblin_grab_l1','goblin_grab_l2','goblin_grab_l3'], 'salad_cat':['salad_wave_l1','salad_wave_l2','salad_wave_l3'],
'magic_orange_cat':['magic_circle_l1','magic_circle_l2','magic_circle_l3'], 'blade_shield':['blade_slash_l1','blade_slash_l2','blade_slash_l3'],
'pink_star':['pink_sonic_l1','pink_sonic_l2','pink_sonic_l3'], 'sauce_stubble_dog':['sauce_shot_l1','sauce_shot_l2','sauce_shot_l3'],
'scared_cat':['scared_dash_l1','scared_dash_l2','scared_dash_l3'], 'ok_meow_boss':['ok_pressure_l1','ok_pressure_l2','ok_pressure_l3'],
'niu_lai':['niu_special_l1','niu_special_l2','niu_special_l3'], 'bao_la':['bao_counter_l1','bao_counter_l2','bao_counter_l3'],
}

def num(action):
 m=re.match(r'(\d+)_',action); return int(m.group(1)) if m else 999

def raw_id(rnd,action): return f"asset_{rnd.lower()}_a{num(action):02d}"

def mode_for(cid,rnd,action):
 n=num(action)
 if cid=='doge' and rnd=='ROUND_2' and (action.startswith(('06_','07_','08_','09_','10_','11_','12_','13_','14_','15_','16_','17_','18_','19_','20_','21_','22_','23_','24_'))): return 'super_doge'
 if cid=='goblin_love' and rnd=='ROUND_2' and n>=7: return 'love_awakened'
 if cid=='blade_shield' and rnd=='ROUND_2' and 8<=n<=19: return 'dual_blade'
 if cid=='pink_star' and rnd=='ROUND_2' and n>=2: return 'true_face'
 if cid=='bao_la' and rnd=='ROUND_2' and 19<=n<=34: return 'last_stand'
 return ''

def domain_for(cid,rnd,action,mode):
 a=action.lower()
 if cid=='tempura_penguin' and rnd=='ROUND_2' and 26<=num(action)<=52: return 'SUMMON'
 if cid=='scared_cat' and rnd=='ROUND_2' and 32<=num(action)<=55: return 'SUMMON'
 if '16_9' in a: return 'ULTIMATE_SCREEN'
 if any(k in a for k in ['魔法陣','trap','tentacle','safe_zone','cthulhu','hazard','地面圈']): return 'HAZARD'
 if any(k in a for k in ['vfx','特效','warning','警告','impact','火花','脈衝','能量柱','爆炸','軌跡','smear','residue','aura','overlay','命中特效','光']): return 'WORLD_EFFECT'
 if any(k in a for k in ['projectile','飛射','判決波','掃描波','聲波','wave','地面波']) and not any(k in a for k in ['蓄力','釋放','後座']): return 'PROJECTILE'
 if any(k in a for k in ['本體素材','master','weapon','重機槍']): return 'ATTACHMENT'
 return 'MODE_FIGHTER' if mode else 'BASE_FIGHTER'

def canonical_id(cid,rnd,action,mode,domain):
 a=action.lower(); n=num(action)
 # Resource-conditioned Niu visual keys already used by active presentation data.
 if cid=='niu_lai':
  special={1:'idle',2:'idle_c3',3:'walk_forward',4:'walk_forward_c2',5:'walk_back',6:'crouch',7:'jump',8:'landing',9:'dash_forward',10:'dash_forward',11:'dash_forward_c2',12:'backstep',14:'stand_light',15:'stand_light_c3',16:'stand_heavy',17:'stand_heavy_c2',18:'crouch_low',19:'crouch_low_c2',20:'crouch_low_c3',23:'air_attack',24:'air_attack_c2',25:'air_attack_c3',26:'guard_stand',27:'guard_stand_c1',28:'guard_stand_c2',29:'guard_stand_c3',30:'guard_crouch',31:'guard_crouch_c1',32:'guard_crouch_c2',33:'guard_crouch_c3',35:'blockstun',36:'blockstun',37:'hitstun',38:'hitstun',39:'hitstun',40:'hitstun'} if rnd=='ROUND_1' else {1:'ground_throw',2:'thrown',4:'knockdown',5:'knockdown',6:'getup',7:'ko',8:'charge',9:'charge',25:'ultimate'}
  if n in special: return special[n]
 if mode:
  # transformed body keys
  if cid=='doge' and rnd=='ROUND_2':
   return {6:'idle',7:'walk_forward',8:'walk_back',9:'dash_forward',10:'backstep',11:'crouch',12:'jump',13:'landing',14:'hitstun',15:'stand_light',16:'stand_heavy',17:'crouch_low',18:'guard_stand',19:'guard_crouch',20:'air_attack',21:'ground_throw',22:'special_neutral'}.get(n,raw_id(rnd,action))
  if cid=='goblin_love' and rnd=='ROUND_2':
   return {7:'idle',8:'walk_forward',9:'walk_back',10:'crouch',11:'jump',12:'landing',13:'dash_forward',14:'backstep',15:'guard_stand',17:'blockstun',18:'guard_crouch',20:'blockstun',21:'hitstun',22:'hitstun',23:'hitstun',24:'stand_light',25:'crouch_low',26:'goblin_awakened_heavy',27:'air_attack',28:'goblin_awakened_throw',29:'charge',30:'charge',31:'goblin_aw_grab_l1',32:'goblin_aw_grab_l2',33:'goblin_aw_grab_l3',34:'goblin_awakened_special',38:'thrown',41:'knockdown',42:'getup',45:'ko'}.get(n,raw_id(rnd,action))
  if cid=='blade_shield' and rnd=='ROUND_2':
   return {8:'idle',9:'walk_forward',10:'walk_back',11:'crouch',12:'jump',13:'landing',14:'dash_forward',15:'backstep',16:'stand_light',17:'dual_blade_heavy',18:'dual_blade_low',19:'dual_blade_air'}.get(n,raw_id(rnd,action))
  if cid=='pink_star' and rnd=='ROUND_2':
   return {2:'idle',3:'walk_forward',4:'dash_forward',5:'pink_dash_cancel',6:'walk_back',7:'crouch',8:'jump',9:'guard_stand',10:'blockstun',11:'guard_crouch',12:'blockstun',13:'hitstun',14:'pink_true_light',15:'pink_true_heavy',16:'pink_true_low',17:'pink_true_air',18:'ground_throw',19:'charge',20:'pink_true_special',26:'pink_true_finisher',27:'true_face_exit',28:'true_face_exit',29:'idle'}.get(n,raw_id(rnd,action))
  if cid=='bao_la' and rnd=='ROUND_2':
   return {19:'ultimate',20:'ultimate',21:'hitstun',22:'bao_last_stand_1',23:'bao_last_stand_2',24:'bao_last_stand_0',32:'bao_last_stand_1',33:'bao_last_stand_2',34:'bao_last_stand_3'}.get(n,raw_id(rnd,action))
 # base/common semantic map, intentionally one exact action per key
 if any(k in a for k in ['待機','idle']) and not any(k in a for k in ['hold','knockdown']): return 'idle'
 if any(k in a for k in ['前走','walk_forward']): return 'walk_forward'
 if any(k in a for k in ['後走','walk_backward','walk_back']): return 'walk_back'
 if any(k in a for k in ['蹲下','crouch']) and 'guard' not in a and '防' not in a: return 'crouch'
 if ('跳躍' in a or re.search(r'(^|_)jump($|_)',a)) and '攻擊' not in a: return 'jump'
 if any(k in a for k in ['落地','landing']) and 'knockdown' not in a: return 'landing'
 if any(k in a for k in ['前衝','dash_forward']) and '強化' not in a: return 'dash_forward'
 if any(k in a for k in ['後撤','backstep']) and 'panic_exit' not in a: return 'backstep'
 if any(k in a for k in ['輕攻','light_paw','light「','light_']) and domain in ('BASE_FIGHTER','MODE_FIGHTER'): return 'stand_light'
 if any(k in a for k in ['重攻','heavy_serious','heavy「','heavy_']) and domain in ('BASE_FIGHTER','MODE_FIGHTER') and 'hit' not in a and 'armor' not in a: return 'stand_heavy'
 if any(k in a for k in ['下段','low_','low「']) and domain in ('BASE_FIGHTER','MODE_FIGHTER') and 'hit' not in a: return 'crouch_low'
 if any(k in a for k in ['空中攻擊','air_body','air_']) and domain in ('BASE_FIGHTER','MODE_FIGHTER') and 'hit' not in a: return 'air_attack'
 if ('站防' in a or 'guard_standing' in a) and '硬直' not in a and 'impact' not in a: return 'guard_stand'
 if ('蹲防' in a or 'guard_crouching' in a) and '硬直' not in a and 'impact' not in a: return 'guard_crouch'
 if any(k in a for k in ['blockstun','防硬直','防禦硬直']): return 'blockstun'
 if any(k in a for k in ['受擊','hitstun','stagger','reel']) and domain in ('BASE_FIGHTER','MODE_FIGHTER'): return 'hitstun'
 if ('投技' in a or a.startswith('01_throw') or 'ground_throw' in a) and domain in ('BASE_FIGHTER','MODE_FIGHTER'): return 'ground_throw'
 if any(k in a for k in ['被摔','thrown_start','throw_reaction','airborne_thrown']): return 'thrown'
 if any(k in a for k in ['knockdown','倒地']) and 'ultimate' not in a: return 'knockdown'
 if any(k in a for k in ['起身','getup']): return 'getup'
 if re.search(r'(^|_)ko($|_)',a) or 'ko_' in a: return 'ko'
 if cid=='doge' and rnd=='ROUND_2' and n==3: return 'special_neutral'
 if any(k in a for k in ['charge_start','charge_loop','charge_hold','開始蓄力','蓄力維持','持續蓄力','最大蓄力','maximum_charge','開始蓄力','蓄力「','蓄力']): return 'charge'
 # Explicit ultimate body starts whose source labels vary.
 if (cid=='doge' and rnd=='ROUND_2' and n==5) or (cid=='blade_shield' and rnd=='ROUND_2' and n==7) or (cid=='scared_cat' and rnd=='ROUND_2' and n==26): return 'ultimate'
 if cid=='ya_mouse' and rnd=='ROUND_2' and n==28: return 'ultimate'
 if cid=='magic_orange_cat' and rnd=='ROUND_2' and n==11: return 'charge'
 if cid=='magic_orange_cat' and rnd=='ROUND_2' and n in (13,15): return 'special_neutral'
 if cid=='scared_cat' and rnd=='ROUND_1' and 17<=n<=22: return 'hitstun'
 if 'ultimate' in a and any(k in a for k in ['啟動','startup','發動','變身','決意']): return 'ultimate'
 # special level IDs only for clearly level-labelled special presentation actions.
 if domain in ('BASE_FIGHTER','MODE_FIGHTER','PROJECTILE','WORLD_EFFECT','HAZARD'):
  for level in (1,2,3):
   if f'lv{level}' in a and cid in SPECIALS:
    return SPECIALS[cid][level-1]
 return raw_id(rnd,action)

def entity_for(cid,rnd,action,domain):
 n=num(action)
 if cid=='tempura_penguin' and domain=='SUMMON': return 'penguin_swarm'
 if cid=='scared_cat' and domain=='SUMMON': return 'husky_guardian'
 if cid=='magic_orange_cat' and rnd=='ROUND_2' and 17<=n<=25: return 'jpeg_circle'
 if cid=='magic_orange_cat' and rnd=='ROUND_2' and 32<=n<=44: return 'cthulhu_sequence'
 return ''

def sequence_move_for(cid,rnd,action,move_id):
 if move_id: return move_id
 n=num(action)
 if cid=='alien_meow' and rnd=='ROUND_2' and 27<=n<=51: return 'ultimate'
 if cid=='ya_mouse' and rnd=='ROUND_2' and 28<=n<=51: return 'ultimate'
 if cid=='tempura_penguin' and rnd=='ROUND_2' and 20<=n<=52: return 'ultimate'
 if cid=='goblin_love' and rnd=='ROUND_2' and 1<=n<=6: return 'ultimate'
 if cid=='salad_cat' and rnd=='ROUND_2' and 26<=n<=46: return 'ultimate'
 if cid=='magic_orange_cat' and rnd=='ROUND_2' and 26<=n<=44: return 'ultimate'
 if cid=='blade_shield' and rnd=='ROUND_2' and n==7: return 'ultimate'
 if cid=='pink_star' and rnd=='ROUND_2' and n in (1,21): return 'ultimate'
 if cid=='sauce_stubble_dog' and rnd=='ROUND_2' and 22<=n<=48: return 'ultimate'
 if cid=='scared_cat' and rnd=='ROUND_2' and 26<=n<=55: return 'ultimate'
 if cid=='ok_meow_boss' and rnd=='ROUND_2' and 23<=n<=52: return 'ultimate'
 if cid=='niu_lai' and rnd=='ROUND_2' and 25<=n<=43: return 'ultimate'
 if cid=='bao_la' and rnd=='ROUND_2' and 17<=n<=34: return 'ultimate'
 return ''

def move_for(cid,anim,action):
 if anim in {'stand_light','stand_heavy','crouch_low','air_attack','ground_throw','special_neutral','ultimate'}: return anim
 all_moves=sum(SPECIALS.values(),[])
 if anim in all_moves or anim.startswith(('pink_true_','goblin_aw','dual_blade_','bao_')): return anim
 return ''

def hold_for(anim,domain):
 if domain in ('BASE_FIGHTER','MODE_FIGHTER') and anim in {'idle','walk_forward','walk_back','guard_stand','guard_crouch','charge'}: return ('LOOP',True)
 if domain in ('BASE_FIGHTER','MODE_FIGHTER') and (anim.startswith(('stand_','crouch_low','air_attack','ground_throw','special','ultimate','pink_','goblin_','dual_','bao_'))): return ('MOVE_TIMELINE',False)
 return ('ONE_SHOT',False)

def godot_string(s): return json.dumps(s,ensure_ascii=False)

def generate():
 inv=json.load(INV.open(encoding='utf-8')); OUT.mkdir(parents=True,exist_ok=True)
 export={'schema_version':1,'inventory':'res://assets/production_roster/combat_asset_inventory.json','characters':[]}
 for folder,data in inv.items():
  cid,display,asset_folder=CHARACTERS[folder]
  bindings=[]; used=set()
  for rnd,actions in data['rounds'].items():
   for item in actions:
    action=item['action']; mode=mode_for(cid,rnd,action); domain=domain_for(cid,rnd,action,mode)
    anim=canonical_id(cid,rnd,action,mode,domain)
    # Avoid illegal duplicate exact animation/mode/domain by keeping first canonical and exposing later action under exact raw ID.
    key=(mode,anim,domain)
    if key in used: anim=raw_id(rnd,action)
    used.add((mode,anim,domain))
    frames=[f"res://assets/production_roster/source/{asset_folder}/{rnd}/{action}/{f}" for f in item['frames']]
    hold,loop=hold_for(anim,domain)
    status='GREEN'; notes='Exact production inventory binding.'
    move_id=sequence_move_for(cid,rnd,action,move_for(cid,anim,action))
    entity_id=entity_for(cid,rnd,action,domain)
    trigger=''
    if domain in ('WORLD_EFFECT','HAZARD','ATTACHMENT','ULTIMATE_SCREEN') and move_id:
     trigger='HIT' if any(k in action.lower() for k in ['hit','命中','impact']) else 'MOVE_STARTED'
    bindings.append(dict(animation_id=anim,domain=domain,asset_folder=asset_folder,round_name=rnd,action_folder=action,frame_paths=frames,mode_id=mode,move_id=move_id,entity_id=entity_id,trigger_event=trigger,hold_policy=hold,loop=loop,anchor='FEET_CENTER' if domain in ('BASE_FIGHTER','MODE_FIGHTER') else 'CENTER',facing_policy='CANONICAL_RIGHT_MIRROR',status=status,notes=notes))
  # Known Blade dual special safe art reuse is an approved YELLOW runtime fallback.
  if cid=='blade_shield':
   heavy=next((b for b in bindings if b['mode_id']=='dual_blade' and b['animation_id']=='dual_blade_heavy'),None)
   if heavy:
    b=heavy.copy(); b.update(animation_id='special_neutral',move_id='special_neutral',status='YELLOW',notes='Approved fallback: Dual Heavy key poses + detached 鈍刀蓄斬 VFX; no gameplay impact.',hold_policy='MOVE_TIMELINE',loop=False)
    bindings.append(b)
  # Doge production source has Rush body but no separate charge body; hold its anticipation key pose while charging.
  if cid=='doge' and not any(b['animation_id']=='charge' and b['mode_id']=='' for b in bindings):
   rush=next((b for b in bindings if b['animation_id']=='special_neutral' and b['mode_id']=='' and b['domain']=='BASE_FIGHTER'),None)
   if rush:
    b=rush.copy(); b.update(animation_id='charge',move_id='special_neutral',status='YELLOW',notes='Approved fallback: hold Muscle Rush anticipation key pose during charge; gameplay charge timing remains MoveData-driven.',hold_policy='HOLD_LAST',loop=False)
    bindings.append(b)
  # Base special_neutral fallback if exact body charge exists but no explicit special key.
  if not any(b['animation_id']=='special_neutral' and b['mode_id']=='' and b['domain']=='BASE_FIGHTER' for b in bindings):
   charge=next((b for b in bindings if b['animation_id']=='charge' and b['mode_id']=='' and b['domain']=='BASE_FIGHTER'),None)
   if charge:
    b=charge.copy(); b.update(animation_id='special_neutral',move_id='special_neutral',status='GREEN',notes='Runtime special body fallback from exact authored charge/release body pose; detached effect remains separately bound.',hold_policy='MOVE_TIMELINE',loop=False)
    bindings.append(b)
  # Root .tres
  lines=['[gd_resource type="Resource" load_steps=%d format=3]'%(len(bindings)+3),'',
         '[ext_resource type="Script" path="res://presentation/data/production_animation_binding.gd" id="anim"]',
         '[ext_resource type="Script" path="res://presentation/data/production_character_asset_binding.gd" id="catalog"]','']
  domain_idx={'BASE_FIGHTER':0,'MODE_FIGHTER':1,'PROJECTILE':2,'SUMMON':3,'HAZARD':4,'WORLD_EFFECT':5,'ATTACHMENT':6,'ULTIMATE_SCREEN':7}
  hold_idx={'HOLD_LAST':0,'LOOP':1,'MOVE_TIMELINE':2,'ONE_SHOT':3}
  subids=[]
  for i,b in enumerate(bindings):
   sid=f'b{i:03d}';subids.append(f'SubResource("{sid}")')
   lines += [f'[sub_resource type="Resource" id="{sid}"]','script = ExtResource("anim")',f'animation_id = &{godot_string(b["animation_id"])}',f'domain = {domain_idx[b["domain"]]}',f'asset_folder = {godot_string(b["asset_folder"])}',f'round_name = &{godot_string(b["round_name"])}',f'action_folder = {godot_string(b["action_folder"])}',f'frame_paths = PackedStringArray({godot_string(b["frame_paths"])[1:-1]})' if b['frame_paths'] else 'frame_paths = PackedStringArray()',f'mode_id = &{godot_string(b["mode_id"])}',f'move_id = &{godot_string(b["move_id"])}',f'entity_id = &{godot_string(b["entity_id"])}',f'trigger_event = &{godot_string(b["trigger_event"])}',f'hold_policy = {hold_idx[b["hold_policy"]]}',f'loop = {str(b["loop"]).lower()}',f'anchor = &{godot_string(b["anchor"])}',f'facing_policy = &{godot_string(b["facing_policy"])}',f'status = &{godot_string(b["status"])}',f'notes = {godot_string(b["notes"])}','']
  lines += ['[resource]','script = ExtResource("catalog")',f'character_id = &{godot_string(cid)}',f'display_name = {godot_string(display)}',f'asset_folder = {godot_string(asset_folder)}','source_inventory_path = "res://assets/production_roster/combat_asset_inventory.json"',f'bindings = Array[ExtResource("anim")]([{", ".join(subids)}])']
  (OUT/f'{cid}.tres').write_text('\n'.join(lines)+'\n',encoding='utf-8')
  export['characters'].append({'character_id':cid,'display_name':display,'asset_folder':asset_folder,'binding_resource':f'res://presentation/resources/production_asset_bindings/{cid}.tres','bindings':bindings})
 EXPORT.write_text(json.dumps(export,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 print('generated',len(export['characters']),'characters',sum(len(c['bindings']) for c in export['characters']),'bindings')
if __name__=='__main__': generate()
