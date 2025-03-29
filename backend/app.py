# FASTAPI BACKEND CODE

from fastapi import FastAPI, WebSocket, File, UploadFile, BackgroundTasks, Query, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
import numpy as np
import cv2
from ultralytics import YOLO
import io
from PIL import Image
import json
import asyncio
from typing import List, Optional, Dict
import base64
import os

app = FastAPI()

# Add CORS middleware to allow requests from your Flutter app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allows all origins
    allow_credentials=True,
    allow_methods=["*"],  # Allows all methods
    allow_headers=["*"],  # Allows all headers
)

# Load YOLO model
model = YOLO("yolo-Weights/yolov8n.pt")

# Original YOLO class names
classNames = [
    "person", "bicycle", "car", "motorbike", "aeroplane", "bus", "train", "truck", "boat",
    "traffic light", "fire hydrant", "stop sign", "parking meter", "bench", "bird", "cat",
    "dog", "horse", "sheep", "cow", "elephant", "bear", "zebra", "giraffe", "backpack",
    "umbrella", "handbag", "tie", "suitcase", "frisbee", "skis", "snowboard", "sports ball",
    "kite", "baseball bat", "baseball glove", "skateboard", "surfboard", "tennis racket",
    "bottle", "wine glass", "cup", "fork", "knife", "spoon", "bowl", "banana", "apple",
    "sandwich", "orange", "broccoli", "carrot", "hot dog", "pizza", "donut", "cake", "chair",
    "sofa", "pottedplant", "bed", "diningtable", "toilet", "tvmonitor", "laptop", "mouse",
    "remote", "keyboard", "cell phone", "microwave", "oven", "toaster", "sink", "refrigerator",
    "book", "clock", "vase", "scissors", "teddy bear", "hair drier", "toothbrush"
]

# Challenge detection classes
challenge_classes = {
    "planting": ["pottedplant", "vase", "bowl", "person"],
    "watering": ["bottle", "cup", "person"],
    "waste_separation": ["bottle", "cup", "bowl", "banana", "apple", "orange", "person"]
}

# Track detection history
detection_history = {
    "planting": [],
    "watering": [],
    "waste_separation": []
}

def process_image(image_bytes, test_mode=False):
    """Process image bytes with YOLO model and custom detection logic"""
    # Convert bytes to numpy array
    nparr = np.frombuffer(image_bytes, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    
    # Run YOLO detection
    results = model(img, stream=True)
    
    # Store results in a list to avoid iterator exhaustion
    detection_results = list(results)
    
    # Object detections for debugging
    detected_objects = []
    for r in detection_results:
        boxes = r.boxes
        for box in boxes:
            cls = int(box.cls[0])
            confidence = float(box.conf[0])
            if confidence > 0.5:  # Only include confident detections
                detected_objects.append({
                    "class": classNames[cls],
                    "confidence": round(confidence, 2)
                })
    
    # Initialize detection results after we have detected objects
    planting_detected = detect_planting(detection_results, img, test_mode)
    watering_detected = detect_watering(detection_results, img, test_mode)
    waste_separation_detected = detect_waste_separation(detection_results, img, test_mode)
    
    # Create response
    response = {
        "planting_detected": planting_detected,
        "watering_detected": watering_detected,
        "waste_separation_detected": waste_separation_detected,
        "detected_objects": detected_objects,
        "test_mode": test_mode
    }
    print('response', response)
    
    return response

def detect_planting(results, img, test_mode=False):
    detected_objects = []
    has_plant = False
    has_person = False
    
    for r in results:
        boxes = r.boxes
        for box in boxes:
            cls = int(box.cls[0])
            class_name = classNames[cls]
            detected_objects.append(class_name)
            
            if class_name == "pottedplant" or class_name == "vase":
                has_plant = True
            if class_name == "person":
                has_person = True
    
    print(f"Planting detection - Has plant: {has_plant}, Has person: {has_person}, Detected objects: {detected_objects}")
    
    # Test mode - return immediate result for a single frame
    if test_mode:
        if has_plant and has_person:
            # Check for soil detection (simplified as brown color)
            hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
            lower_brown = np.array([10, 100, 20])
            upper_brown = np.array([20, 255, 200])
            mask = cv2.inRange(hsv, lower_brown, upper_brown)
            brown_pixels = cv2.countNonZero(mask)
            print(f"[TEST MODE] Brown pixels detected: {brown_pixels}")
            return brown_pixels > 1000
        return False
    
    # Normal mode - use detection history
    # Check if both plant and person are detected
    if has_plant and has_person:
        # Check for soil detection (simplified as brown color)
        hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
        lower_brown = np.array([10, 100, 20])
        upper_brown = np.array([20, 255, 200])
        mask = cv2.inRange(hsv, lower_brown, upper_brown)
        brown_pixels = cv2.countNonZero(mask)
        
        print(f"Brown pixels detected: {brown_pixels}")
        
        # If enough brown pixels detected, consider it soil
        if brown_pixels > 1000:
            detection_history["planting"].append(1)
        else:
            detection_history["planting"].append(0)
    else:
        detection_history["planting"].append(0)
    
    # Keep only the last 10 detections
    if len(detection_history["planting"]) > 10:
        detection_history["planting"] = detection_history["planting"][-10:]
    
    # If 6 out of 10 frames detect planting, consider it a valid detection
    detected = sum(detection_history["planting"][-10:]) >= 6
    print(f"Planting history: {detection_history['planting']}, Detected: {detected}")
    return detected

def detect_watering(results, img, test_mode=False):
    detected_objects = []
    has_water_container = False
    has_person = False
    
    for r in results:
        boxes = r.boxes
        for box in boxes:
            cls = int(box.cls[0])
            class_name = classNames[cls]
            detected_objects.append(class_name)
            
            if class_name == "bottle" or class_name == "cup":
                has_water_container = True
            if class_name == "person":
                has_person = True
    
    print(f"Watering detection - Has water container: {has_water_container}, Has person: {has_person}, Detected objects: {detected_objects}")
    
    # Test mode - return immediate result for a single frame
    if test_mode:
        if has_water_container and has_person:
            # Check for water detection (simplified as blue color)
            hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
            lower_blue = np.array([90, 50, 50])
            upper_blue = np.array([130, 255, 255])
            mask = cv2.inRange(hsv, lower_blue, upper_blue)
            blue_pixels = cv2.countNonZero(mask)
            print(f"[TEST MODE] Blue pixels detected: {blue_pixels}")
            return blue_pixels > 500
        return False
    
    # Normal mode - use detection history
    # Check for water detection (simplified as blue color)
    if has_water_container and has_person:
        hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
        lower_blue = np.array([90, 50, 50])
        upper_blue = np.array([130, 255, 255])
        mask = cv2.inRange(hsv, lower_blue, upper_blue)
        blue_pixels = cv2.countNonZero(mask)
        
        print(f"Blue pixels detected: {blue_pixels}")
        
        # If water color detected, consider it watering
        if blue_pixels > 500:
            detection_history["watering"].append(1)
        else:
            detection_history["watering"].append(0)
    else:
        detection_history["watering"].append(0)
    
    # Keep only the last 10 detections
    if len(detection_history["watering"]) > 10:
        detection_history["watering"] = detection_history["watering"][-10:]
    
    # If 6 out of 10 frames detect watering, consider it a valid detection
    detected = sum(detection_history["watering"][-10:]) >= 6
    print(f"Watering history: {detection_history['watering']}, Detected: {detected}")
    return detected

def detect_waste_separation(results, img, test_mode=False):
    detected_objects = []
    has_waste_item = False
    has_person = False
    
    for r in results:
        boxes = r.boxes
        for box in boxes:
            cls = int(box.cls[0])
            class_name = classNames[cls]
            detected_objects.append(class_name)
            
            if class_name in ["bottle", "cup", "bowl", "banana", "apple", "orange"]:
                has_waste_item = True
            if class_name == "person":
                has_person = True
    
    print(f"Waste separation detection - Has waste item: {has_waste_item}, Has person: {has_person}, Detected objects: {detected_objects}")
    
    # Test mode - return immediate result for a single frame
    if test_mode:
        if has_waste_item and has_person:
            gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
            _, thresh = cv2.threshold(gray, 100, 255, cv2.THRESH_BINARY)
            contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
            
            for contour in contours:
                # Approximate the contour to a polygon
                epsilon = 0.02 * cv2.arcLength(contour, True)
                approx = cv2.approxPolyDP(contour, epsilon, True)
                
                # If the polygon has 4 vertices, it's a rectangle (simplified bin detection)
                if len(approx) == 4 and cv2.contourArea(contour) > 5000:
                    print(f"[TEST MODE] Rectangle detected with area {cv2.contourArea(contour)}")
                    return True
            return False
        return False
    
    # Normal mode - use detection history
    # Check for bin detection (simplified as rectangular shapes)
    if has_waste_item and has_person:
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        _, thresh = cv2.threshold(gray, 100, 255, cv2.THRESH_BINARY)
        contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        
        rectangles_found = 0
        for contour in contours:
            # Approximate the contour to a polygon
            epsilon = 0.02 * cv2.arcLength(contour, True)
            approx = cv2.approxPolyDP(contour, epsilon, True)
            
            # If the polygon has 4 vertices, it's a rectangle (simplified bin detection)
            if len(approx) == 4 and cv2.contourArea(contour) > 5000:
                rectangles_found += 1
                detection_history["waste_separation"].append(1)
                break
        else:
            detection_history["waste_separation"].append(0)
            
        print(f"Rectangles found: {rectangles_found}")
    else:
        detection_history["waste_separation"].append(0)
    
    # Keep only the last 10 detections
    if len(detection_history["waste_separation"]) > 10:
        detection_history["waste_separation"] = detection_history["waste_separation"][-10:]
    
    # If 6 out of 10 frames detect waste separation, consider it a valid detection
    detected = sum(detection_history["waste_separation"][-10:]) >= 6
    print(f"Waste separation history: {detection_history['waste_separation']}, Detected: {detected}")
    return detected

# Create a class to manage WebSocket connections
class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)

    async def send_text(self, message: str, websocket: WebSocket):
        await websocket.send_text(message)

    async def broadcast(self, message: str):
        for connection in self.active_connections:
            await connection.send_text(message)

# Initialize the connection manager
manager = ConnectionManager()

# WebSocket endpoint for text messages
@app.websocket("/ws/text")
async def websocket_text(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        while True:
            # Receive the text message
            message = await websocket.receive_text()
            
            # Log the message
            print(f"Received message: {message}")
            
            try:
                # Try to parse as JSON
                data = json.loads(message)
                if isinstance(data, dict) and "message" in data:
                    # Echo back with server prefix
                    response = {
                        "server_response": f"Server received: {data['message']}",
                        "original": data["message"]
                    }
                    await manager.send_text(json.dumps(response), websocket)
                else:
                    # Echo back the raw data
                    await manager.send_text(f"Server received: {message}", websocket)
            except json.JSONDecodeError:
                # Not JSON, treat as plain text
                await manager.send_text(f"Server received: {message}", websocket)
                
    except WebSocketDisconnect:
        manager.disconnect(websocket)
        print("Text WebSocket client disconnected")
    except Exception as e:
        print(f"Text WebSocket error: {e}")
    finally:
        manager.disconnect(websocket)
        print("Text WebSocket connection closed")

# Modified video WebSocket to handle different message types
@app.websocket("/ws/video")
async def websocket_video(websocket: WebSocket):
    await websocket.accept()
    try:
        while True:
            # Check message type
            message_type = None
            try:
                # Try to receive a text message (could be a command)
                text_message = await websocket.receive_text()
                message_type = "text"
                data = text_message
            except Exception:
                try:
                    # If not text, try to receive bytes (image)
                    image_bytes = await websocket.receive_bytes()
                    message_type = "bytes"
                    data = image_bytes
                except Exception as e:
                    print(f"Error receiving message: {e}")
                    continue
            
            if message_type == "text":
                try:
                    # Try to parse as JSON
                    json_data = json.loads(data)
                    if isinstance(json_data, dict) and "command" in json_data:
                        # Handle command
                        command = json_data["command"]
                        if command == "ping":
                            await websocket.send_text(json.dumps({"status": "pong"}))
                        else:
                            await websocket.send_text(json.dumps({"status": "unknown_command"}))
                    else:
                        # Echo back
                        await websocket.send_text(f"Echo: {data}")
                except json.JSONDecodeError:
                    # Not JSON, treat as plain text
                    await websocket.send_text(f"Echo: {data}")
            
            elif message_type == "bytes":
                # Process image with YOLO
                results = process_image(data)
                
                # Send results back
                await websocket.send_text(json.dumps(results))
                
    except Exception as e:
        print(f"Video WebSocket error: {e}")
    finally:
        print("Video WebSocket connection closed")

# Option 2: HTTP endpoint (alternative to WebSocket)
@app.post("/detect")
async def detect_image(
    file: UploadFile = File(...),
    test_mode: Optional[bool] = Query(False, description="Test mode skips detection history requirement")
):
    # Read image
    image_bytes = await file.read()
    
    # Process image with YOLO
    results = process_image(image_bytes, test_mode)
    
    return results

# Health check endpoint
@app.get("/")
def read_root():
    return {"status": "YOLO detection server is up and running"}

if __name__ == "__main__":
    uvicorn.run("app:app", host="0.0.0.0", port=8000, reload=True)
