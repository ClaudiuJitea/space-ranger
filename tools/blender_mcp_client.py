#!/usr/bin/env python3
"""Small project-local client for the configured Blender MCP stdio bridge."""

import argparse
import asyncio
import base64
import json
import os
from pathlib import Path

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client


async def run(action: str, tool: str | None, arguments_file: str | None, output_dir: str | None) -> None:
    params = StdioServerParameters(
        command="/home/clau/miniconda3/bin/blender-mcp",
        env={**os.environ, "BLENDER_HOST": "127.0.0.1", "BLENDER_PORT": "9876"},
    )
    async with stdio_client(params) as (read_stream, write_stream):
        async with ClientSession(read_stream, write_stream) as session:
            await session.initialize()
            if action == "list":
                result = await session.list_tools()
                print(json.dumps([tool.model_dump() for tool in result.tools], indent=2))
                return
            arguments = {}
            if arguments_file:
                arguments = json.loads(Path(arguments_file).read_text())
            result = await session.call_tool(tool, arguments)
            if output_dir:
                destination = Path(output_dir)
                destination.mkdir(parents=True, exist_ok=True)
                for index, block in enumerate(result.content):
                    if getattr(block, "type", None) == "image":
                        suffix = ".png" if getattr(block, "mimeType", "") == "image/png" else ".jpg"
                        path = destination / f"{tool}_{index}{suffix}"
                        path.write_bytes(base64.b64decode(block.data))
                        print(f"SAVED_IMAGE={path}")
            print(json.dumps(result.model_dump(), indent=2, default=str))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=["list", "call"])
    parser.add_argument("tool", nargs="?")
    parser.add_argument("--arguments-file")
    parser.add_argument("--output-dir")
    args = parser.parse_args()
    if args.action == "call" and not args.tool:
        parser.error("call requires a tool name")
    asyncio.run(run(args.action, args.tool, args.arguments_file, args.output_dir))


if __name__ == "__main__":
    main()
