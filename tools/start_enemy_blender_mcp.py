import bpy
import sys
sys.path.insert(0, '/home/clau/.config/blender/5.2/scripts/addons')
import blender_mcp
try:
    if not hasattr(bpy.types.Scene, 'blendermcp_port'):
        blender_mcp.register()
except Exception as e:
    print('Registration notice:', e)
try:
    bpy.ops.blendermcp.start_server()
    print('ENEMY_ASSET_MCP_READY')
except Exception as e:
    print('Start server notice:', e)

