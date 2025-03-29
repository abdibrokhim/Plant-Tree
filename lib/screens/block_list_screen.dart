import 'package:flutter/material.dart';

class BlockListScreen extends StatefulWidget {
  const BlockListScreen({super.key});

  @override
  State<BlockListScreen> createState() => _BlockListScreenState();
}

class _BlockListScreenState extends State<BlockListScreen> {
  // Placeholder list of blocked apps
  final List<Map<String, dynamic>> _blockedApps = [
    {
      'name': 'Social Media App',
      'icon': Icons.public,
      'color': Colors.blue,
      'isBlocked': true,
    },
    {
      'name': 'Video Streaming',
      'icon': Icons.video_library,
      'color': Colors.red,
      'isBlocked': true,
    },
    {
      'name': 'Games',
      'icon': Icons.sports_esports,
      'color': Colors.purple,
      'isBlocked': true,
    },
    {
      'name': 'Shopping App',
      'icon': Icons.shopping_cart,
      'color': Colors.orange,
      'isBlocked': false,
    },
    {
      'name': 'News App',
      'icon': Icons.article,
      'color': Colors.teal,
      'isBlocked': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title section
          const Text(
            'App Block List',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Manage apps that will be blocked until you complete eco-activities',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          
          // Environmental impact section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade100),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.eco,
                    color: Colors.green,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Environmental Impact',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'By limiting screen time, you\'ve helped plant 0 trees!',
                        style: TextStyle(
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Apps list title
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Apps',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Add App +',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Apps list
          Expanded(
            child: ListView.builder(
              itemCount: _blockedApps.length,
              itemBuilder: (context, index) {
                final app = _blockedApps[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: app['color'].withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        app['icon'],
                        color: app['color'],
                      ),
                    ),
                    title: Text(app['name']),
                    subtitle: Text(
                      app['isBlocked'] 
                          ? 'Blocked until eco-activity' 
                          : 'Not blocked',
                      style: TextStyle(
                        color: app['isBlocked'] ? Colors.red : Colors.green,
                      ),
                    ),
                    trailing: Switch(
                      value: app['isBlocked'],
                      activeColor: Colors.green,
                      onChanged: (value) {
                        setState(() {
                          _blockedApps[index]['isBlocked'] = value;
                        });
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
