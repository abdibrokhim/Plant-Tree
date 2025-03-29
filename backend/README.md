# Backend Testing Tools

This directory contains the FastAPI backend for the Take Trash App's image recognition functionality, plus tools to test it.

## Files

- `app.py` - Main FastAPI application with YOLO image detection
- `test_client.html` - Web-based client for testing the backend
- `serve_test_page.py` - Simple HTTP server to serve the test page

## Setup and Testing Instructions

### 1. Start the Backend Server

Run the FastAPI backend:

```bash
# Make sure you're in the backend directory
cd backend

# Install dependencies if you haven't already
pip install fastapi uvicorn numpy opencv-python ultralytics pillow

# Start the server
python app.py
```

This will start the server on `localhost:8000` by default.

### 2. Start the Test Client

In a new terminal window, run:

```bash
# Make sure you're in the backend directory
cd backend

# Start the test page server
python serve_test_page.py
```

This will automatically open the test client in your browser at `http://localhost:8080/test_client.html`.

### 3. Use the Test Client

The test client provides three main functions:

1. **Health Check** - Test basic connectivity to the backend
2. **HTTP Image Detection** - Upload a single image for detection
3. **WebSocket Test** - Test the real-time WebSocket connection

#### Testing with a Physical Device

If you want to test from a mobile device or another computer:

1. Find your computer's IP address (e.g., 192.168.1.5)
2. Enter this IP address with the port in the Server URL field (e.g., 192.168.1.5:8000)
3. Click "Update"
4. Make sure both devices are on the same network

## Troubleshooting

- **Connection refused errors**: Ensure the backend server is running
- **No route to host errors**: Check firewall settings or try using your LAN IP address
- **CORS errors**: The backend has CORS enabled for all origins, but if you see CORS errors, check your network configuration

## Reference: API Endpoints

- `GET /` - Health check endpoint
- `POST /detect` - Send an image for detection
- `WebSocket /ws/video` - Connect for real-time image processing 