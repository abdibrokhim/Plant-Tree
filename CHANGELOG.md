[v0.0.0] - 2025-03-30

## Backend Improvements
- Fixed YOLO detection results iterator exhaustion issue by storing results in a list
- Added `test_mode` parameter to allow immediate detection results without requiring frame history
- Created WebSocket endpoint for text messages at `/ws/text` for debugging and testing
- Enhanced `/ws/video` WebSocket endpoint to handle both text and binary messages
- Added `ConnectionManager` class to manage WebSocket connections 
- Implemented detailed logging for easier debugging and troubleshooting

## Test Client Features
- Created HTML test client (`backend/test_client.html`) for backend testing without mobile app
- Added HTTP image detection test section with image preview and results display
- Implemented WebSocket image detection testing with real-time results
- Added text messaging functionality with support for plain text and JSON formats
- Integrated live camera streaming feature to continuously send webcam frames to server
- Added adjustable frame rate controls (0.5-5 fps) for camera streaming
- Created server configuration section for easy server URL updates
- Added health check functionality to verify server status

## Mobile App Enhancements
- Added flexible server URL configuration with collapsible UI panel
- Enhanced error handling with descriptive messages and SnackBar notifications
- Improved request logging for easier debugging
- Added collapsible text messaging panel for WebSocket testing directly in the app
- Implemented real-time message exchange with color-coded display

## Documentation and Testing
- Created README file with usage instructions and troubleshooting tips
- Added Python script to serve test client page locally alongside FastAPI server
- Documented network configuration requirements for successful connectivity
- Added testing instructions for all feature sets

## General
- Flutter doesn't work on physical Android devices (issue with WebSockets WiFi IP address)
- Fixed server URL hardcoding for better flexibility across different devices
- Shipped very early version with core functionality