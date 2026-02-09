import asyncio
import json
import logging
from aiohttp import web
import aiohttp

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Store active connections
# devices: { device_id: websocket }
# apps: { device_id: [websockets] }
# car_clients: { device_id: websocket_client_connection }
devices = {}
apps = {}
car_clients = {}

async def connect_to_car(device_id, car_ip):
    """Connect to the ESP32 car as a client"""
    url = f"ws://{car_ip}:80"
    try:
        async with aiohttp.ClientSession() as session:
            async with session.ws_connect(url) as ws:
                car_clients[device_id] = ws
                logger.info(f"Connected to car {device_id} at {car_ip}")
                
                # Forward messages from car to all apps
                async for msg in ws:
                    if msg.type == aiohttp.WSMsgType.TEXT:
                        if device_id in apps:
                            for app_ws in apps[device_id]:
                                if not app_ws.closed:
                                    await app_ws.send_str(msg.data)
                    elif msg.type == aiohttp.WSMsgType.CLOSED:
                        break
    except Exception as e:
        logger.error(f"Error connecting to car {device_id}: {e}")
    finally:
        if device_id in car_clients:
            del car_clients[device_id]
        logger.info(f"Disconnected from car {device_id}")

async def ws_handler(request):
    ws = web.WebSocketResponse()
    await ws.prepare(request)

    role = request.query.get('role') # 'device' (push) or 'app'
    device_id = request.query.get('deviceId')
    car_ip = request.query.get('carIp') # Only needed for 'app' role if car not connected

    if not role or not device_id:
        await ws.close(code=4000, message=b'Missing role or deviceId')
        return ws

    if role == 'device':
        # This is for when the device connects TO the relay server
        logger.info(f"Device {device_id} registered via push")
        devices[device_id] = ws
        try:
            async for msg in ws:
                if msg.type == aiohttp.WSMsgType.TEXT:
                    if device_id in apps:
                        for app_ws in apps[device_id]:
                            if not app_ws.closed:
                                await app_ws.send_str(msg.data)
        finally:
            del devices[device_id]
            logger.info(f"Device {device_id} disconnected")

    elif role == 'app':
        logger.info(f"App for device {device_id} connected")
        
        # If car_ip is provided and not connected, try connecting to it
        if car_ip and device_id not in car_clients and device_id not in devices:
            asyncio.create_task(connect_to_car(device_id, car_ip))
            # Wait a bit for connection
            await asyncio.sleep(1)

        if device_id not in apps:
            apps[device_id] = []
        apps[device_id].append(ws)
        
        try:
            async for msg in ws:
                if msg.type == aiohttp.WSMsgType.TEXT:
                    # Forward from app to device (either pushed device or pulled car)
                    target_ws = devices.get(device_id) or car_clients.get(device_id)
                    if target_ws and not target_ws.closed:
                        await target_ws.send_str(msg.data)
                    else:
                        await ws.send_json({"type": "error", "msg": "Device offline"})
        finally:
            apps[device_id].remove(ws)
            if not apps[device_id]:
                del apps[device_id]
            logger.info(f"App for device {device_id} disconnected")

    return ws

async def stream_handler(request):
    """Proxy MJPEG stream from device to app"""
    device_id = request.match_info.get('deviceId')
    
    # In a real remote scenario, the device would also need to 'push' its stream to the server
    # or the server must be able to reach the device.
    # For now, let's assume the server can reach the device via its local IP (if the server is in the same LAN)
    # OR we implement a reverse proxy if the device supports it.
    
    # For a true remote setup where device is behind NAT, the device needs to push.
    # But common ESP32-CAM examples are HTTP servers.
    # Let's provide a simple proxy if the device IP is known.
    
    device_ip = request.query.get('ip')
    if not device_ip:
        return web.Response(status=400, text="Missing device IP")

    url = f"http://{device_ip}:80/stream"
    
    try:
        async with aiohttp.ClientSession() as session:
            async with session.get(url) as resp:
                response = web.StreamResponse(
                    status=resp.status,
                    reason=resp.reason,
                    headers=resp.headers,
                )
                await response.prepare(request)
                async for chunk in resp.content.iter_any():
                    await response.write(chunk)
                return response
    except Exception as e:
        logger.error(f"Stream proxy error: {e}")
        return web.Response(status=500, text=str(e))

async def capture_handler(request):
    """Proxy image capture from device to app"""
    device_id = request.match_info.get('deviceId')
    device_ip = request.query.get('ip')
    if not device_ip:
        return web.Response(status=400, text="Missing device IP")

    url = f"http://{device_ip}:80/capture"
    
    try:
        async with aiohttp.ClientSession() as session:
            async with session.get(url) as resp:
                data = await resp.read()
                return web.Response(
                    body=data,
                    status=resp.status,
                    headers=resp.headers,
                )
    except Exception as e:
        logger.error(f"Capture proxy error: {e}")
        return web.Response(status=500, text=str(e))

async def init_app():
    app = web.Application()
    app.router.add_get('/ws', ws_handler)
    app.router.add_get('/stream/{deviceId}', stream_handler)
    app.router.add_get('/capture/{deviceId}', capture_handler)
    return app

if __name__ == '__main__':
    app = asyncio.run(init_app())
    web.run_app(app, host='0.0.0.0', port=8081)
