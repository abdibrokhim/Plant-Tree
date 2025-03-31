import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../utils/usage_stats_util.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<AppUsageInfo> _usageData = [];
  Duration _totalScreenTime = Duration.zero;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUsageData();
  }

  Future<void> _loadUsageData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Try to get real data
      final hasPermission = await UsageStatsUtil.requestUsageStatsPermission();
      
      if (hasPermission) {
        final usageData = await UsageStatsUtil.getAppUsageStats(7);
        final totalTime = await UsageStatsUtil.getTotalScreenTime(7);
        
        setState(() {
          _usageData.clear();
          _usageData.addAll(usageData);
          _totalScreenTime = totalTime;
          _isLoading = false;
        });
      } else {
        // Use mock data if permission not granted
        setState(() {
          _usageData.clear();
          _usageData.addAll(UsageStatsUtil.getMockData());
          _totalScreenTime = const Duration(hours: 6, minutes: 25);
          _isLoading = false;
        });
      }
    } catch (e) {
      // Fallback to mock data on error
      setState(() {
        _usageData.clear();
        _usageData.addAll(UsageStatsUtil.getMockData());
        _totalScreenTime = const Duration(hours: 6, minutes: 25);
        _isLoading = false;
      });
      debugPrint('Error loading usage data: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Welcome section
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome to Green Guardians!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              // User's stats card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your Eco-Stats',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildStatRow(Icons.eco, 'Plants Watered', '0'),
                    _buildStatRow(Icons.recycling, 'Items Recycled', '0'),
                    _buildStatRow(Icons.emoji_events, 'Eco-Points', '0'),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Tab bar
        Container(
          decoration: BoxDecoration(
            color: Colors.green.shade50,
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.green,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.green,
            tabs: const [
              Tab(
                text: 'Challenges',
                icon: Icon(Icons.task_alt),
              ),
              Tab(
                text: 'Analytics',
                icon: Icon(Icons.analytics),
              ),
            ],
          ),
        ),
        
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Challenges tab
              _buildChallengesTab(),
              
              // Analytics tab
              _buildAnalyticsTab(),
            ],
          ),
        ),
      ],
    );
  }

  // Challenges tab
  Widget _buildChallengesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Today\'s Challenges',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          _buildChallengeCard(
            'Plant a Tree',
            'Plant a new tree or flower and earn 50 points!',
            Icons.park,
            Colors.green.shade200,
          ),
          
          _buildChallengeCard(
            'Recycle Plastic',
            'Recycle plastic items and earn 30 points!',
            Icons.delete_outline,
            Colors.blue.shade200,
          ),
          
          _buildChallengeCard(
            'Water Your Plants',
            'Water your plants and earn 20 points!',
            Icons.water_drop,
            Colors.cyan.shade200,
          ),
        ],
      ),
    );
  }
  
  // Analytics tab
  Widget _buildAnalyticsTab() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator(color: Colors.green))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Total screen time card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.access_time, color: Colors.green),
                          SizedBox(width: 8),
                          Text(
                            'Total Screen Time (Last 7 Days)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          UsageStatsUtil.formatDuration(_totalScreenTime),
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Center(
                        child: Text(
                          'Complete eco-activities to reduce screen time!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // App usage chart
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'App Usage Breakdown',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: _buildPieChart(_usageData),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // App usage list
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Most Used Apps',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._usageData.take(5).map((app) => _buildAppUsageRow(app)),
                    ],
                  ),
                ),
              ],
            ),
          );
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.green.shade700),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(fontSize: 16),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeCard(
    String title, 
    String description, 
    IconData icon,
    Color color,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(title),
        subtitle: Text(description),
        trailing: const Icon(Icons.arrow_forward),
      ),
    );
  }
  
  Widget _buildAppUsageRow(AppUsageInfo app) {
    // Generate a deterministic color based on app name
    final int colorValue = app.appName.hashCode & 0xFFFFFF;
    final Color appColor = Color(colorValue).withOpacity(1.0);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: appColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                app.appName.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: appColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app.appName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Last used: ${_formatLastUsed(app.lastTimeUsed)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Text(
            UsageStatsUtil.formatDuration(app.usageTime),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPieChart(List<AppUsageInfo> apps) {
    if (apps.isEmpty) {
      return const Center(child: Text('No usage data available'));
    }
    
    // Only show top 5 apps for the chart
    final topApps = apps.take(5).toList();
    
    // Calculate total time for percentage
    final totalTime = topApps.fold<int>(
      0, 
      (sum, app) => sum + app.usageTime.inMinutes,
    );
    
    return PieChart(
      PieChartData(
        sections: topApps.asMap().entries.map((entry) {
          final int index = entry.key;
          final AppUsageInfo app = entry.value;
          
          // Generate a deterministic color based on app name
          final int colorValue = app.appName.hashCode & 0xFFFFFF;
          final Color appColor = Color(colorValue).withOpacity(1.0);
          
          // Calculate percentage
          final double percentage = totalTime > 0 
              ? (app.usageTime.inMinutes / totalTime) * 100 
              : 0;
          
          return PieChartSectionData(
            color: appColor,
            value: percentage,
            title: '${percentage.toStringAsFixed(1)}%',
            radius: 80,
            titleStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        }).toList(),
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        centerSpaceColor: Colors.white,
      ),
    );
  }
  
  String _formatLastUsed(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} h ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }
} 