# .env (a.k.a. take trash)

> Join Waitlist Now: https://www.yaps.gg/lab/take-trash

An app to gamify eco-friendly activities, incorporating user verification and community engagement. Key features include challenges related to planting, watering, and waste separation, a points system, and community leaderboards.

## Features

- **Splash Screen**: App logo, name, and loading indicator
- **Bottom Navigation**: Home, Scan, and Block List tabs
- **Home Screen**: Challenges and Analytics tabs
- **Scan Screen**: Take photos of eco-activities to earn points
- **Block List**: Apps that can be blocked until eco-activities are completed

## Setup Instructions

### Flutter App

1. **Install dependencies**:
   ```bash
   flutter pub get
   ```

2. **Build and run the app**:
   ```bash
   flutter run
   ```

3. **Permissions**: 
   - Make sure to grant camera permissions when prompted
   - For analytics, grant usage stats permissions

### Python Backend (for Scanning Feature)

1. **Set up a virtual environment**:
   ```bash
   cd backend
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

2. **Install dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

3. **Run the server**:
   ```bash
   python app.py
   ```
   The server will run on `http://localhost:8000`.

4. **Update the server URL in the app**:
   - In `lib/screens/scan_screen.dart`, update the `_serverUrl` variable with your server's IP address if you're testing on a physical device
   - When testing on an emulator, you can use:
     - Android emulator: `10.0.2.2:8000`
     - iOS simulator: `localhost:8000`

## Scan Feature

The scan feature allows users to:

1. **Take a photo** of their eco-friendly activity
2. Send it to the backend for processing via HTTP or WebSocket
3. Receive feedback on the detected eco-activity
4. Earn points for verified eco-activities

The backend uses a simple color-based detection system to identify plants (green colors) and recycling (blue colors).

# Take Trash App - Offline Mode

This Flutter application has been modified to work completely offline without requiring an internet connection or backend server. The app uses on-device machine learning with TensorFlow Lite to detect environmental activities.

## Features

- Camera-based detection of environmental activities
- Fully offline operation using on-device ML
- Demo mode when no ML model is available
- User-friendly interface for capturing images
- Continuous scanning mode

## Setup

1. Clone the repository
2. Run `flutter pub get` to install dependencies
3. Run the app with `flutter run`

## Using Your Own ML Model

The app is set up to use TensorFlow Lite models for detection. To use your own model:

1. Train a model or download a pre-trained one
2. Convert it to TensorFlow Lite format (.tflite)
3. Place the model in `/assets/models/model.tflite`
4. Update the labels file at `/assets/models/labels.txt` to match your model's output classes

## Demo Mode

If no valid TensorFlow Lite model is found, the app will run in "demo mode" which simulates detections. This is useful for testing the UI or when you don't have a trained model available.

## Dependencies

- TensorFlow Lite for Flutter
- Flutter Camera plugin
- Image processing libraries
- Permission handling

## Privacy

Since all processing happens on-device, no data is sent to any server, ensuring complete privacy for users.
