# VPN Control API

Fluxzy Connect exposes an HTTP API for controlling the VPN connection programmatically. The server listens on all network interfaces (`0.0.0.0`) on port `18080`.

## Base URL

```
http://<device-ip>:18080
```

Replace `<device-ip>` with your Android device's IP address on the local network.

## Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check |
| `/status` | GET | Get VPN connection status |
| `/connect` | POST | Connect to a SOCKS5 proxy |
| `/disconnect` | POST | Disconnect from VPN |

---

## GET /health

Health check endpoint to verify the API server is running.

### Request

```bash
curl http://192.168.1.50:18080/health
```

### Response

```json
{
  "status": "ok",
  "service": "fluxzy-vpn-control"
}
```

---

## GET /status

Returns the current VPN connection status.

### Request

```bash
curl http://192.168.1.50:18080/status
```

### Response (Disconnected)

```json
{
  "connected": false,
  "state": "disconnected"
}
```

### Response (Connected)

```json
{
  "connected": true,
  "state": "connected",
  "host": "192.168.1.100",
  "port": 9852
}
```

### Possible States

| State | Description |
|-------|-------------|
| `disconnected` | VPN is not connected |
| `connecting` | Connection in progress |
| `connected` | VPN is connected |
| `disconnecting` | Disconnection in progress |
| `error` | Connection error occurred |

---

## POST /connect

Connects to a SOCKS5 proxy through the VPN tunnel.

### Request Body

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `host` | string | Yes | Proxy server hostname or IP address |
| `port` | integer | Yes | Proxy server port (1-65535) |
| `username` | string | No | SOCKS5 authentication username |
| `password` | string | No | SOCKS5 authentication password |

### Examples

#### Basic Connection (No Authentication)

```bash
curl -X POST http://192.168.1.50:18080/connect \
  -H "Content-Type: application/json" \
  -d '{
    "host": "192.168.1.100",
    "port": 9852
  }'
```

#### Connection with Authentication

```bash
curl -X POST http://192.168.1.50:18080/connect \
  -H "Content-Type: application/json" \
  -d '{
    "host": "192.168.1.100",
    "port": 9852,
    "username": "myuser",
    "password": "mypassword"
  }'
```

#### One-liner (Windows CMD)

```cmd
curl -X POST http://192.168.1.50:18080/connect -H "Content-Type: application/json" -d "{\"host\":\"192.168.1.100\",\"port\":9852}"
```

#### One-liner (PowerShell)

```powershell
Invoke-RestMethod -Uri "http://192.168.1.50:18080/connect" -Method POST -ContentType "application/json" -Body '{"host":"192.168.1.100","port":9852}'
```

### Response (Success)

```json
{
  "success": true,
  "message": "Connected"
}
```

### Response (Already Connected - Same Host)

The endpoint is idempotent. Calling connect when already connected to the same host returns success:

```json
{
  "success": true,
  "message": "Already connected"
}
```

### Response (Already Connected - Different Host)

```json
{
  "success": false,
  "message": "Already connected to 192.168.1.100:9852. Disconnect first."
}
```

### Response (Invalid Request)

```json
{
  "success": false,
  "message": "Invalid request: Missing or invalid \"host\" field"
}
```

```json
{
  "success": false,
  "message": "Invalid request: Missing or invalid \"port\" field (must be 1-65535)"
}
```

---

## POST /disconnect

Disconnects from the VPN.

### Request

```bash
curl -X POST http://192.168.1.50:18080/disconnect
```

#### One-liner (Windows CMD)

```cmd
curl -X POST http://192.168.1.50:18080/disconnect
```

#### One-liner (PowerShell)

```powershell
Invoke-RestMethod -Uri "http://192.168.1.50:18080/disconnect" -Method POST
```

### Response (Success)

```json
{
  "success": true,
  "message": "Disconnected"
}
```

### Response (Already Disconnected)

The endpoint is idempotent. Calling disconnect when already disconnected returns success:

```json
{
  "success": true,
  "message": "Already disconnected"
}
```

---

## Error Responses

All endpoints return JSON error responses with the following format:

```json
{
  "success": false,
  "message": "Error description"
}
```

### HTTP Status Codes

| Code | Description |
|------|-------------|
| 200 | Success |
| 400 | Bad request (invalid parameters) |
| 404 | Endpoint not found |
| 500 | Server error |

---

## Complete Workflow Example

Here's a complete example workflow using curl:

```bash
# 1. Check if server is running
curl http://192.168.1.50:18080/health

# 2. Check current status
curl http://192.168.1.50:18080/status

# 3. Connect to proxy
curl -X POST http://192.168.1.50:18080/connect \
  -H "Content-Type: application/json" \
  -d '{"host": "192.168.1.100", "port": 9852}'

# 4. Verify connection
curl http://192.168.1.50:18080/status

# 5. Disconnect when done
curl -X POST http://192.168.1.50:18080/disconnect

# 6. Verify disconnection
curl http://192.168.1.50:18080/status
```

---

## Shell Script Example

```bash
#!/bin/bash

DEVICE_IP="192.168.1.50"
PROXY_HOST="192.168.1.100"
PROXY_PORT="9852"
API_BASE="http://${DEVICE_IP}:18080"

# Function to connect
connect_vpn() {
    echo "Connecting to ${PROXY_HOST}:${PROXY_PORT}..."
    curl -s -X POST "${API_BASE}/connect" \
        -H "Content-Type: application/json" \
        -d "{\"host\":\"${PROXY_HOST}\",\"port\":${PROXY_PORT}}"
    echo
}

# Function to disconnect
disconnect_vpn() {
    echo "Disconnecting..."
    curl -s -X POST "${API_BASE}/disconnect"
    echo
}

# Function to check status
check_status() {
    echo "Current status:"
    curl -s "${API_BASE}/status" | jq .
}

# Main
case "$1" in
    connect)
        connect_vpn
        ;;
    disconnect)
        disconnect_vpn
        ;;
    status)
        check_status
        ;;
    *)
        echo "Usage: $0 {connect|disconnect|status}"
        exit 1
        ;;
esac
```

Usage:
```bash
./vpn-control.sh connect
./vpn-control.sh status
./vpn-control.sh disconnect
```

---

## CORS Support

The API supports Cross-Origin Resource Sharing (CORS), allowing requests from web browsers on different origins. All responses include:

```
Access-Control-Allow-Origin: *
```

Preflight requests (OPTIONS) are handled automatically.

---

## Notes

- The server starts automatically when the Fluxzy Connect app launches
- The server listens on port `18080` by default
- All network interfaces are bound (`0.0.0.0`), so the API is accessible from any device on the same network
- Connection and disconnection operations are idempotent - calling them multiple times is safe
- The VPN connection requires the Android VPN permission to be granted first (handled by the app UI)
