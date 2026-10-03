#!/usr/bin/env python3
"""Run the deterministic refit through the installed Blender MCP bridge."""
import argparse,asyncio,json,os
from pathlib import Path
from mcp import ClientSession,StdioServerParameters
from mcp.client.stdio import stdio_client
ASSETS=['enforcer','scout','scout_jetpack','scout_flame','crawler','turret','gunship','hound','wasp','apex','warden','seraph','leviathan','sovereign','blaster','scattergun','railgun','launcher','enemy_rifle']
async def run(port,prompt):
 params=StdioServerParameters(command='/home/clau/miniconda3/bin/blender-mcp',env={**os.environ,'BLENDER_HOST':'127.0.0.1','BLENDER_PORT':str(port)})
 script=Path(__file__).resolve().with_name('build_arsenal_refit.py')
 async with stdio_client(params) as (read,write):
  async with ClientSession(read,write) as session:
   await session.initialize()
   for name in ASSETS:
    selected=script.with_name("build_rift_hound.py") if name=="hound" else script
    code=f"REFIT_ASSET={name!r}\nexec(compile(open({str(selected)!r}).read(),'build_arsenal_refit.py','exec'))"
    result=await session.call_tool('execute_blender_code',{'code':code,'user_prompt':prompt})
    output='\n'.join(block.text for block in result.content if hasattr(block,'text'))
    if result.isError or 'Error executing code' in output or ('RIFT HOUND EXPORTED' if name=='hound' else 'ARSENAL REFIT EXPORTED '+name) not in output:
     raise RuntimeError(name+': '+output)
    print('REFIT COMPLETE '+name,flush=True)
   code="import bpy\nbpy.data.libraries.write('/home/clau/dev/space-ranger/assets/models/arsenal_refit/arsenal_atelier.blend',{bpy.data.scenes['Arsenal Refit Atelier']},fake_user=True,compress=True)\nprint('ARSENAL SOURCE SAVED')"
   result=await session.call_tool('execute_blender_code',{'code':code,'user_prompt':prompt})
   output='\n'.join(block.text for block in result.content if hasattr(block,'text'))
   if 'ARSENAL SOURCE SAVED' not in output:raise RuntimeError(output)
   print('ALL 19 REFITS AND BLENDER SOURCE SAVED',flush=True)
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--port',type=int,default=9876);parser.add_argument('--prompt',required=True);args=parser.parse_args()
 asyncio.run(run(args.port,args.prompt))
