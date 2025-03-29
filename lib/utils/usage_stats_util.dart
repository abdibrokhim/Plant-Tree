import 'package:flutter/material.dart';

class UsageStatsUtil {
  // Method to request usage stats permission (mocked)
  static Future<bool> requestUsageStatsPermission() async {
    // Always return false to use mock data
    return false;
  }

  // Get app usage stats for the last N days (always returns mock data)
  static Future<List<AppUsageInfo>> getAppUsageStats(int days) async {
    // Always return mock data
    return getMockData();
  }

  // Get total screen time for the last N days
  static Future<Duration> getTotalScreenTime(int days) async {
    final appUsageList = await getAppUsageStats(days);
    
    int totalMilliseconds = 0;
    for (var appUsage in appUsageList) {
      totalMilliseconds += appUsage.usageTime.inMilliseconds;
    }
    
    return Duration(milliseconds: totalMilliseconds);
  }
  
  // Format duration to readable string (eg: 2h 15m)
  static String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${twoDigits(duration.inMinutes.remainder(60))}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${twoDigits(duration.inSeconds.remainder(60))}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  // Get mock data for testing
  static List<AppUsageInfo> getMockData() {
    final now = DateTime.now();
    return [
      AppUsageInfo(
        appName: 'Social Media',
        packageName: 'com.example.socialmedia',
        usageTime: const Duration(hours: 2, minutes: 15),
        lastTimeUsed: now.subtract(const Duration(minutes: 30)),
      ),
      AppUsageInfo(
        appName: 'Video Streaming',
        packageName: 'com.example.videostream',
        usageTime: const Duration(hours: 1, minutes: 45),
        lastTimeUsed: now.subtract(const Duration(hours: 1)),
      ),
      AppUsageInfo(
        appName: 'Games',
        packageName: 'com.example.games',
        usageTime: const Duration(hours: 1, minutes: 10),
        lastTimeUsed: now.subtract(const Duration(hours: 2)),
      ),
      AppUsageInfo(
        appName: 'Shopping',
        packageName: 'com.example.shopping',
        usageTime: const Duration(minutes: 45),
        lastTimeUsed: now.subtract(const Duration(hours: 3)),
      ),
      AppUsageInfo(
        appName: 'News',
        packageName: 'com.example.news',
        usageTime: const Duration(minutes: 30),
        lastTimeUsed: now.subtract(const Duration(hours: 5)),
      ),
    ];
  }
}

// Model class for app usage info
class AppUsageInfo {
  final String appName;
  final String packageName;
  final Duration usageTime;
  final DateTime lastTimeUsed;
  
  AppUsageInfo({
    required this.appName,
    required this.packageName,
    required this.usageTime,
    required this.lastTimeUsed,
  });
} 