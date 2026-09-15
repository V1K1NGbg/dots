#!/usr/bin/env python3
"""Live renderer check; requires a running Miku and room for one test clone."""
import runpy,os,time,signal
signal.alarm(15)
# Pinned shimejictl misreads the server's one-byte variable count as uint16.
os.environ['XDG_RUNTIME_DIR']='/run/user/1000'
e=runpy.run_path('/usr/bin/shimejictl',run_name='test')
original=e['MascotInfo'].read_values
e['MascotInfo'].read_values=lambda self,fmt:original(self,'B' if fmt=='H' else fmt)
c=e['Client']('/run/user/1000/dots-miku.sock',{'start':False})
infos=[];ids=[]
c.register_callback(e['MascotInfo'],lambda c,p:infos.append(p))
def info(mid):
 infos.clear();c.queue_packet(e['MascotGetInfo'](mid));c.dispatch_events(until=lambda:bool(infos));return infos[0]
try:
 envs=sorted(e['environments'].values(),key=lambda x:x.x)
 for env,x,want in [(envs[0],12,0),(envs[-1],envs[-1].width-12,envs[-1].width),(envs[0],100,100)]:
  before=set(e['mascots'])
  c.queue_packet(e['Spawn'](next(iter(e['prototypes'])),env.id,x,600,'Thrown'))
  c.dispatch_events(until=lambda:bool(set(e['mascots'])-before))
  mid=(set(e['mascots'])-before).pop();ids.append(mid)
  c.queue_packet(e["ApplyBehavior"](mid,"Thrown"))
  info(mid)
  time.sleep(.25)
  p=info(mid);pos=[v.value for v in p.variables[:2]]
  print('position/action',pos,p.current_action_name,flush=True)
  if want!=100:
   assert pos[0]==want,(pos,want)
   assert p.current_action_name==b'GrabWall','Wall did not attach'
  else:
   assert p.current_action_name!=b'GrabWall','Ordinary drop incorrectly attached'
  c.queue_packet(e['ApplyBehavior'](mid,'RemoveMiku'))
 print('PASS: left/right screen-wall snap and ordinary drop away from walls',flush=True)
finally:
 for mid in ids:c.queue_packet(e['ApplyBehavior'](mid,'RemoveMiku'))
