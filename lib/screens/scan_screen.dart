import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:web_socket_channel/io.dart';
import 'package:http/http.dart' as http;

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  String _selectedActivity = 'Plant a Tree';
  final List<String> _activities = [
    'Plant a Tree',
    'Water Plants',
    'Recycle Waste',
  ];

  // Camera and detection related variables
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  String _detectionResults = "No detections yet";
  
  // Socket connection (initialized on demand)
  IOWebSocketChannel? _channel;
  Timer? _frameTimer;
  bool _isConnected = false;
  
  // Text messaging for testing
  IOWebSocketChannel? _textChannel;
  bool _isTextConnected = false;
  bool _showTextMessaging = false;
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, String>> _messages = [];
  final ScrollController _messagesScrollController = ScrollController();
  
  // Server endpoint configuration
  // For emulators: Android = 10.0.2.2:8000, iOS = localhost:8000
  // For physical devices: Use your computer's actual IP address on the same network
  String _serverUrl = Platform.isAndroid ? '10.0.2.2:8000' : 'localhost:8000';
  final TextEditingController _serverUrlController = TextEditingController();
  bool _showServerConfig = false;
  
  // Simulation mode variables
  bool _isSimulationMode = true; // Set to true for simulation
  bool _isSimulating = false;
  Timer? _simulationTimer;
  String _simulationStatus = "";
  bool _detectionComplete = false;
  
  // Animation controllers for simulation effects
  late AnimationController _scanLineController;
  late Animation<double> _scanLineAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _serverUrlController.text = _serverUrl;
    
    // Setup animation controllers for simulation
    _scanLineController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_scanLineController);
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0)
      .chain(CurveTween(curve: Curves.easeInOut))
      .animate(_pulseController);
  }
  
  @override
  void dispose() {
    // Cancel timers and animations first
    _simulationTimer?.cancel();
    _frameTimer?.cancel();
    _scanLineController.dispose();
    _pulseController.dispose();
    
    // Dispose other controllers
    _cameraController?.dispose();
    _serverUrlController.dispose();
    _messageController.dispose();
    _messagesScrollController.dispose();
    
    // Close connections
    if (_channel != null) {
      _channel!.sink.close();
      _channel = null;
    }
    _disconnectTextWebSocket();
    
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle changes to properly manage camera resources
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    
    if (state == AppLifecycleState.inactive) {
      _stopVideoProcessing();
      _cameraController?.dispose();
      _isCameraInitialized = false;
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  // Request camera permissions and initialize
  Future<void> _initializeCamera() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      try {
        // Get available cameras
        _cameras = await availableCameras();
        
        if (_cameras != null && _cameras!.isNotEmpty) {
          // Initialize controller with the first available camera
          _cameraController = CameraController(
            _cameras![0],
            ResolutionPreset.medium,
            enableAudio: false,
            imageFormatGroup: ImageFormatGroup.jpeg,
          );
          
          // Initialize the controller
          await _cameraController!.initialize();
          
          if (mounted) {
            setState(() {
              _isCameraInitialized = true;
            });
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No cameras available on this device')),
          );
        }
      } catch (e) {
        debugPrint('Error initializing camera: $e');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera permission is required to scan activities')),
      );
    }
  }
  
  // Simulation functions
  void _startSimulation() async {
    if (_isSimulating) return;
    
    // Initialize camera if not already initialized
    if (!_isCameraInitialized) {
      await _initializeCamera();
      // If camera initialization failed, show an error and return
      if (!_isCameraInitialized) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to initialize camera')),
        );
        return;
      }
    }
    
    setState(() {
      _isSimulating = true;
      _isProcessing = true;
      _detectionComplete = false;
      _simulationStatus = "";
      _detectionResults = "No detections yet";
    });
    
    // Schedule detection events
    _simulationTimer = Timer(const Duration(seconds: 3), () {
      setState(() {
        _simulationStatus = "Analyzing...";
      });
      
      _simulationTimer = Timer(const Duration(seconds: 2), () {
        setState(() {
          _detectionComplete = true;
          
          // Set detection results based on selected activity
          if (_selectedActivity == 'Water Plants') {
            _simulationStatus = "Watering activity detected! ✅";
            _detectionResults = '{"planting_detected": false, "watering_detected": true, "waste_separation_detected": false, "detected_objects": [{"class": "watering can", "confidence": 0.92}, {"class": "plant", "confidence": 0.87}]}';
          } else if (_selectedActivity == 'Plant a Tree') {
            _simulationStatus = "Planting activity detected! ✅";
            _detectionResults = '{"planting_detected": true, "watering_detected": false, "waste_separation_detected": false, "detected_objects": [{"class": "seedling", "confidence": 0.88}, {"class": "soil", "confidence": 0.91}]}';
          } else if (_selectedActivity == 'Recycle Waste') {
            _simulationStatus = "Waste separation activity detected! ✅";
            _detectionResults = '{"planting_detected": false, "watering_detected": false, "waste_separation_detected": true, "detected_objects": [{"class": "plastic bottle", "confidence": 0.94}, {"class": "recycle bin", "confidence": 0.89}]}';
          }
        });
        
        // Auto-stop simulation after a delay
        _simulationTimer = Timer(const Duration(seconds: 4), () {
          _stopSimulation();
        });
      });
    });
  }
  
  void _stopSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
    
    if (mounted) {
      setState(() {
        _isSimulating = false;
        _isProcessing = false;
      });
    }
    
    // Release camera resources when simulation is done
    if (_isSimulationMode && _isCameraInitialized) {
      _cameraController?.dispose();
      setState(() {
        _isCameraInitialized = false;
      });
    }
  }

  // Start video processing using WebSocket
  void _startVideoProcessing() {
    // For simulation mode, just start simulation instead
    if (_isSimulationMode) {
      _startSimulation();
      return;
    }
    
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera not initialized')),
      );
      return;
    }
    
    try {
      // Connect to WebSocket
      debugPrint('Connecting to WebSocket at ws://$_serverUrl/ws/video');
      _channel = IOWebSocketChannel.connect('ws://$_serverUrl/ws/video');
      _isConnected = true;
      
      // Listen for detection results from the server
      _channel!.stream.listen(
        (message) {
          setState(() {
            _detectionResults = message.toString();
          });
        },
        onError: (error) {
          debugPrint('WebSocket error: $error');
          
          String errorMessage = 'WebSocket error: $error';
          if (error.toString().contains('SocketException')) {
            errorMessage = 'Cannot connect to WebSocket at $_serverUrl. Make sure:\n'
                '1. Your server is running\n'
                '2. Your device and server are on the same network\n'
                '3. The IP address is correct';
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 8),
              action: SnackBarAction(
                label: 'SETTINGS',
                textColor: Colors.white,
                onPressed: () {
                  setState(() {
                    _showServerConfig = true;
                  });
                },
              ),
            ),
          );
          
          _stopVideoProcessing();
        },
        onDone: () {
          debugPrint('WebSocket connection closed');
          _stopVideoProcessing();
        }
      );
      
      setState(() {
        _isProcessing = true;
      });
      
      // Start sending frames periodically
      _frameTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
        _captureAndSendFrame();
      });
      
    } catch (e) {
      debugPrint('Error starting video processing: $e');
      
      String errorMessage = 'Error connecting to server: $e';
      if (e.toString().contains('SocketException')) {
        errorMessage = 'Cannot connect to server at $_serverUrl. Check your server configuration.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'SETTINGS',
            textColor: Colors.white,
            onPressed: () {
              setState(() {
                _showServerConfig = true;
              });
            },
          ),
        ),
      );
      
      _stopVideoProcessing();
    }
  }
  
  // Stop video processing and clean up resources
  void _stopVideoProcessing() {
    // For simulation mode, stop simulation instead
    if (_isSimulationMode) {
      _stopSimulation();
      return;
    }
    
    _frameTimer?.cancel();
    _frameTimer = null;
    
    if (_channel != null) {
      _channel!.sink.close();
      _channel = null;
    }
    
    if (mounted) {
      setState(() {
        _isProcessing = false;
        _isConnected = false;
      });
    }
  }
  
  // Capture a frame and send to the server
  Future<void> _captureAndSendFrame() async {
    if (_cameraController == null || 
        !_cameraController!.value.isInitialized ||
        !_isConnected) {
      return;
    }
    
    try {
      // Take a picture
      final XFile imageFile = await _cameraController!.takePicture();
      
      // Read image file as bytes
      final File file = File(imageFile.path);
      final List<int> imageBytes = await file.readAsBytes();
      
      // Send the image bytes via WebSocket
      if (_channel != null && _isConnected) {
        _channel!.sink.add(imageBytes);
      }
      
      // Clean up temporary file
      await file.delete();
      
    } catch (e) {
      debugPrint('Error capturing or sending frame: $e');
    }
  }
  
  // Alternative method to send a single image via HTTP
  Future<void> _captureAndSendSingleImage() async {
    // For simulation mode, just start simulation instead
    if (_isSimulationMode) {
      _startSimulation();
      return;
    }
    
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera not initialized')),
      );
      return;
    }
    
    setState(() {
      _isProcessing = true;
    });
    
    try {
      // Take a picture
      final XFile imageFile = await _cameraController!.takePicture();
      
      // Read image file as bytes
      final File file = File(imageFile.path);
      final List<int> imageBytes = await file.readAsBytes();
      
      // Send image to backend via HTTP POST
      debugPrint('Sending request to http://$_serverUrl/detect');
      
      try {
        final response = await http.post(
          Uri.parse('http://$_serverUrl/detect'),
          headers: {'Content-Type': 'application/octet-stream'},
          body: imageBytes,
        ).timeout(const Duration(seconds: 10));
        
        if (response.statusCode == 200) {
          setState(() {
            _detectionResults = response.body;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Activity detected: ${response.body}'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Server error: ${response.statusCode} - ${response.body}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (networkError) {
        String errorMessage = 'Network error: $networkError';
        if (networkError.toString().contains('SocketException')) {
          errorMessage = 'Cannot connect to server at $_serverUrl. Make sure:\n'
              '1. Your server is running\n'
              '2. Your device and server are on the same network\n'
              '3. The IP address is correct';
        } else if (networkError.toString().contains('TimeoutException')) {
          errorMessage = 'Connection timed out. Server may be too slow or unavailable.';
        }
        
        debugPrint(errorMessage);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: 'SETTINGS',
              textColor: Colors.white,
              onPressed: () {
                setState(() {
                  _showServerConfig = true;
                });
              },
            ),
          ),
        );
      }
      
      // Clean up temporary file
      await file.delete();
      
    } catch (e) {
      debugPrint('Error capturing or sending image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Camera error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  // Text WebSocket functions
  void _connectTextWebSocket() {
    if (_isTextConnected) {
      _addMessage('System', 'Already connected');
      return;
    }
    
    try {
      // Connect to WebSocket
      debugPrint('Connecting to Text WebSocket at ws://$_serverUrl/ws/text');
      _textChannel = IOWebSocketChannel.connect('ws://$_serverUrl/ws/text');
      _isTextConnected = true;
      
      // Add connected message
      _addMessage('System', 'Connected to server');
      
      // Listen for messages from the server
      _textChannel!.stream.listen(
        (message) {
          _addMessage('Server', message.toString());
        },
        onError: (error) {
          debugPrint('Text WebSocket error: $error');
          
          String errorMessage = 'WebSocket error: $error';
          if (error.toString().contains('SocketException')) {
            errorMessage = 'Cannot connect to WebSocket at $_serverUrl';
          }
          
          _addMessage('Error', errorMessage);
          _disconnectTextWebSocket();
        },
        onDone: () {
          debugPrint('Text WebSocket connection closed');
          _addMessage('System', 'Disconnected from server');
          _disconnectTextWebSocket();
        }
      );
      
      setState(() {});
      
    } catch (e) {
      debugPrint('Error connecting to text WebSocket: $e');
      _addMessage('Error', 'Failed to connect: $e');
      _disconnectTextWebSocket();
    }
  }
  
  void _disconnectTextWebSocket() {
    if (_textChannel != null) {
      _textChannel!.sink.close();
      _textChannel = null;
    }
    
    setState(() {
      _isTextConnected = false;
    });
  }
  
  void _sendTextMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      return;
    }
    
    if (!_isTextConnected || _textChannel == null) {
      _addMessage('Error', 'Not connected to server');
      return;
    }
    
    try {
      // Send message
      _textChannel!.sink.add(message);
      
      // Add to messages list
      _addMessage('You', message);
      
      // Clear input
      _messageController.clear();
    } catch (e) {
      _addMessage('Error', 'Failed to send message: $e');
    }
  }
  
  void _sendJsonMessage() {
    try {
      // Create a simple JSON message
      final jsonMessage = {
        'message': _messageController.text.trim().isEmpty ? 
                  'Hello from Flutter' : _messageController.text.trim()
      };
      
      // Convert to JSON string
      final jsonString = json.encode(jsonMessage);
      
      if (!_isTextConnected || _textChannel == null) {
        _addMessage('Error', 'Not connected to server');
        return;
      }
      
      // Send message
      _textChannel!.sink.add(jsonString);
      
      // Add to messages list
      _addMessage('You (JSON)', jsonString);
      
      // Clear input
      _messageController.clear();
    } catch (e) {
      _addMessage('Error', 'Failed to send JSON message: $e');
    }
  }
  
  void _addMessage(String sender, String message) {
    setState(() {
      _messages.add({
        'sender': sender,
        'message': message,
        'time': DateTime.now().toString().substring(11, 19) // HH:MM:SS
      });
    });
    
    // Scroll to bottom after a short delay
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_messagesScrollController.hasClients) {
        _messagesScrollController.animateTo(
          _messagesScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title and instructions
          const Text(
            'Scan Your Eco-Activity',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Take a photo of your environmental activity to earn points!',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          
          // Server configuration button and expandable form
          Row(
            children: [
              Expanded(
                child: Text(
                  'Server: $_serverUrl',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(
                  _showServerConfig ? Icons.expand_less : Icons.settings,
                  color: Colors.grey,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _showServerConfig = !_showServerConfig;
                    // Close text messaging if opening server config
                    if (_showServerConfig) {
                      _showTextMessaging = false;
                    }
                  });
                },
              ),
              // Text messaging toggle button
              IconButton(
                icon: Icon(
                  _showTextMessaging ? Icons.expand_less : Icons.message,
                  color: Colors.grey,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _showTextMessaging = !_showTextMessaging;
                    // Close server config if opening text messaging
                    if (_showTextMessaging) {
                      _showServerConfig = false;
                    }
                  });
                },
              ),
            ],
          ),
          
          // Collapsible server configuration
          if (_showServerConfig)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Server Configuration',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _serverUrlController,
                          decoration: const InputDecoration(
                            hintText: 'e.g., 192.168.1.5:8000',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _serverUrl = _serverUrlController.text;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Server URL updated to: $_serverUrl'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Update'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'For physical devices: Use your computer\'s IP address',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            
          // Text messaging panel
          if (_showTextMessaging)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Text Messaging (Testing)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: _isTextConnected ? _disconnectTextWebSocket : _connectTextWebSocket,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isTextConnected ? Colors.red : Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                            child: Text(_isTextConnected ? 'Disconnect' : 'Connect'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Messages container
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: _messages.isEmpty
                      ? const Center(
                          child: Text('No messages yet', style: TextStyle(color: Colors.grey)),
                        )
                      : ListView.builder(
                          controller: _messagesScrollController,
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(color: Colors.black, fontSize: 14),
                                  children: [
                                    TextSpan(
                                      text: '${message['sender']} [${message['time']}]: ',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _getSenderColor(message['sender']!),
                                      ),
                                    ),
                                    TextSpan(
                                      text: message['message'],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Message input
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: const InputDecoration(
                            hintText: 'Type a message',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          enabled: _isTextConnected,
                          onSubmitted: (_) => _sendTextMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Text button
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: _isTextConnected ? _sendTextMessage : null,
                        color: Colors.green,
                      ),
                      // JSON button
                      IconButton(
                        icon: const Icon(Icons.code),
                        onPressed: _isTextConnected ? _sendJsonMessage : null,
                        color: Colors.blue,
                        tooltip: 'Send as JSON',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          
          // Activity selection dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: DropdownButton<String>(
              value: _selectedActivity,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down),
              elevation: 16,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 16,
              ),
              underline: Container(
                height: 0,
                color: Colors.transparent,
              ),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedActivity = newValue;
                  });
                }
              },
              items: _activities.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
          
          // Camera preview or simulation
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _isSimulationMode 
                ? (_isCameraInitialized && _isSimulating
                  ? _buildSimulationWithCameraView()
                  : _buildInitialSimulationView())
                : (_isCameraInitialized
                  ? Stack(
                      children: [
                        // Camera preview
                        CameraPreview(_cameraController!),
                        
                        // Processing indicator
                        if (_isProcessing)
                          Container(
                            color: Colors.black.withOpacity(0.3),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Colors.green,
                              ),
                            ),
                          ),
                          
                        // Detection results overlay
                        if (_detectionResults != "No detections yet" && _isProcessing)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              color: Colors.black.withOpacity(0.5),
                              child: Text(
                                _detectionResults,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                      ],
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt,
                            size: 64,
                            color: Colors.green.shade200,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Camera Preview',
                            style: TextStyle(
                              color: Colors.green.shade200,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Camera permissions required',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )),
            ),
          ),
          const SizedBox(height: 24),
          
          // Capture button - updated for simulation mode
          ElevatedButton.icon(
            onPressed: _isSimulationMode 
                ? (_isProcessing ? _stopSimulation : _startSimulation)
                : (_isCameraInitialized 
                    ? (_isProcessing ? _stopVideoProcessing : _captureAndSendSingleImage) 
                    : () => _initializeCamera()),
            icon: Icon(_isProcessing ? Icons.stop : Icons.camera),
            label: Text(
              _isProcessing 
                  ? 'STOP SCANNING' 
                  : (_isSimulationMode ? 'START SCANNING' : (_isCameraInitialized ? 'CAPTURE ACTIVITY' : 'INITIALIZE CAMERA'))
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isProcessing ? Colors.red : Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // Add a button for continuous mode - updated for simulation mode
          if ((_isSimulationMode || _isCameraInitialized) && !_isProcessing)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton.icon(
                onPressed: _startVideoProcessing,
                icon: const Icon(Icons.videocam),
                label: const Text('START CONTINUOUS SCANNING'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green,
                  side: const BorderSide(color: Colors.green),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  // Build the simulation view with camera
  Widget _buildSimulationWithCameraView() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera background
        CameraPreview(_cameraController!),
        
        // Scanning overlay when processing
        if (_isProcessing)
          Stack(
            children: [
              // Semi-transparent overlay
              Container(
                color: Colors.black.withOpacity(0.3),
              ),
              
              // Scan line animation
              AnimatedBuilder(
                animation: _scanLineAnimation,
                builder: (context, child) {
                  return Positioned(
                    top: MediaQuery.of(context).size.height * _scanLineAnimation.value * 0.3,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 2,
                      color: Colors.green.withOpacity(0.8),
                    ),
                  );
                },
              ),
              
              // Grid lines
              CustomPaint(
                size: Size.infinite,
                painter: _GridPainter(),
              ),
              
              // Corner brackets
              Positioned(
                top: 20,
                left: 20,
                child: _buildCornerBracket(topLeft: true),
              ),
              Positioned(
                top: 20,
                right: 20,
                child: _buildCornerBracket(topRight: true),
              ),
              Positioned(
                bottom: 20,
                left: 20,
                child: _buildCornerBracket(bottomLeft: true),
              ),
              Positioned(
                bottom: 20,
                right: 20,
                child: _buildCornerBracket(bottomRight: true),
              ),
              
              // Status text
              if (_simulationStatus.isNotEmpty)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.black.withOpacity(0.6),
                    child: Text(
                      _simulationStatus,
                      style: TextStyle(
                        color: _detectionComplete ? Colors.green : Colors.white,
                        fontSize: 16,
                        fontWeight: _detectionComplete ? FontWeight.bold : FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                
              // Pulsing border when detection complete
              if (_detectionComplete)
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.green.withOpacity(_pulseAnimation.value),
                          width: 5,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    );
                  },
                ),
                
              // Activity indicators based on selected activity
              if (_detectionComplete)
                ..._buildActivityIndicators(),
            ],
          ),
      ],
    );
  }
  
  // Initial simulation view (before camera is started)
  Widget _buildInitialSimulationView() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.camera_alt,
            size: 64,
            color: Colors.green.shade200,
          ),
          const SizedBox(height: 16),
          Text(
            'Eco-Activity Scanner',
            style: TextStyle(
              color: Colors.green.shade200,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Press START SCANNING to begin',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
  
  // Build appropriate activity indicators based on selected activity
  List<Widget> _buildActivityIndicators() {
    if (_selectedActivity == 'Water Plants') {
      return [
        Positioned(
          top: MediaQuery.of(context).size.height * 0.15,
          left: MediaQuery.of(context).size.width * 0.1,
          child: _buildActivityIndicator(Icons.water_drop, Colors.blue),
        ),
        Positioned(
          top: MediaQuery.of(context).size.height * 0.1,
          right: MediaQuery.of(context).size.width * 0.15,
          child: _buildActivityIndicator(Icons.water_drop, Colors.blue),
        ),
      ];
    } else if (_selectedActivity == 'Plant a Tree') {
      return [
        Positioned(
          top: MediaQuery.of(context).size.height * 0.12,
          left: MediaQuery.of(context).size.width * 0.15,
          child: _buildActivityIndicator(Icons.nature, Colors.green),
        ),
        Positioned(
          bottom: MediaQuery.of(context).size.height * 0.2,
          right: MediaQuery.of(context).size.width * 0.1,
          child: _buildActivityIndicator(Icons.eco, Colors.green.shade300),
        ),
      ];
    } else if (_selectedActivity == 'Recycle Waste') {
      return [
        Positioned(
          top: MediaQuery.of(context).size.height * 0.1,
          left: MediaQuery.of(context).size.width * 0.2,
          child: _buildActivityIndicator(Icons.recycling, Colors.lightBlue),
        ),
        Positioned(
          bottom: MediaQuery.of(context).size.height * 0.15,
          right: MediaQuery.of(context).size.width * 0.2,
          child: _buildActivityIndicator(Icons.delete_outline, Colors.blueGrey),
        ),
      ];
    }
    return [];
  }
  
  Widget _buildActivityIndicator(IconData icon, Color color) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(seconds: 1),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 32,
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildCornerBracket({
    bool topLeft = false,
    bool topRight = false,
    bool bottomLeft = false,
    bool bottomRight = false,
  }) {
    return SizedBox(
      width: 30,
      height: 30,
      child: CustomPaint(
        painter: _CornerBracketPainter(
          topLeft: topLeft,
          topRight: topRight,
          bottomLeft: bottomLeft, 
          bottomRight: bottomRight,
          color: Colors.green,
          thickness: 3,
        ),
      ),
    );
  }
  
  Color _getSenderColor(String sender) {
    switch (sender) {
      case 'You':
      case 'You (JSON)':
        return Colors.blue;
      case 'Server':
        return Colors.green;
      case 'Error':
        return Colors.red;
      case 'System':
        return Colors.grey;
      default:
        return Colors.black;
    }
  }
}

// Grid painter for simulation effect
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green.withOpacity(0.2)
      ..strokeWidth = 1;
    
    // Horizontal lines
    for (var i = 0; i <= 10; i++) {
      final y = size.height * i / 10;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    
    // Vertical lines
    for (var i = 0; i <= 10; i++) {
      final x = size.width * i / 10;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Corner bracket painter for simulation effect
class _CornerBracketPainter extends CustomPainter {
  final bool topLeft;
  final bool topRight;
  final bool bottomLeft;
  final bool bottomRight;
  final Color color;
  final double thickness;
  
  _CornerBracketPainter({
    this.topLeft = false,
    this.topRight = false,
    this.bottomLeft = false,
    this.bottomRight = false,
    this.color = Colors.green,
    this.thickness = 2,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.square;
    
    final length = size.width * 0.8;
    
    if (topLeft) {
      canvas.drawLine(
        Offset(0, thickness / 2),
        Offset(length, thickness / 2),
        paint,
      );
      canvas.drawLine(
        Offset(thickness / 2, 0),
        Offset(thickness / 2, length),
        paint,
      );
    }
    
    if (topRight) {
      canvas.drawLine(
        Offset(size.width, thickness / 2),
        Offset(size.width - length, thickness / 2),
        paint,
      );
      canvas.drawLine(
        Offset(size.width - thickness / 2, 0),
        Offset(size.width - thickness / 2, length),
        paint,
      );
    }
    
    if (bottomLeft) {
      canvas.drawLine(
        Offset(0, size.height - thickness / 2),
        Offset(length, size.height - thickness / 2),
        paint,
      );
      canvas.drawLine(
        Offset(thickness / 2, size.height),
        Offset(thickness / 2, size.height - length),
        paint,
      );
    }
    
    if (bottomRight) {
      canvas.drawLine(
        Offset(size.width, size.height - thickness / 2),
        Offset(size.width - length, size.height - thickness / 2),
        paint,
      );
      canvas.drawLine(
        Offset(size.width - thickness / 2, size.height),
        Offset(size.width - thickness / 2, size.height - length),
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}