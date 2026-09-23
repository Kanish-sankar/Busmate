import 'package:busmate/meta/utils/constant/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppAdoptionScreen extends StatefulWidget {
  const AppAdoptionScreen({super.key});

  @override
  State<AppAdoptionScreen> createState() => _AppAdoptionScreenState();
}

class _AppAdoptionScreenState extends State<AppAdoptionScreen> {
  late Future<_AdoptionViewData> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadAdoptionData();
  }

  Future<_AdoptionViewData> _loadAdoptionData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const _AdoptionViewData.unauthorized();
    }

    final firestore = FirebaseFirestore.instance;
    final adminDoc = await firestore.collection('adminusers').doc(user.uid).get();
    if (!adminDoc.exists || adminDoc.data() == null) {
      return const _AdoptionViewData.unauthorized();
    }

    final role = ((adminDoc.data()!['role'] ?? '') as String).toLowerCase().trim();
    const allowedRoles = {
      'admin',
      'super_admin',
      'superadmin',
      'regional_admin',
      'regionaladmin',
      'school_admin',
      'schooladmin',
      'owner',
    };
    if (!allowedRoles.contains(role)) {
      return const _AdoptionViewData.unauthorized();
    }

    final configDoc = await firestore.collection('app_config').doc('version_control').get();
    final configData = configDoc.data() ?? <String, dynamic>{};
    final latestVersion = (configData['latest_version'] as String?)?.trim() ?? '-';
    final graceDays = (configData['grace_days'] as num?)?.toInt() ?? 5;

    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);

    final snapshot = await firestore
        .collection('adminusers')
        .where('lastAppSeenAt', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
        .get();

    final Map<String, int> counts = <String, int>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final version = (data['appVersion'] as String?)?.trim();
      final key = (version == null || version.isEmpty) ? 'unknown' : version;
      counts[key] = (counts[key] ?? 0) + 1;
    }

    final totalActiveToday = snapshot.docs.length;
    final rows = counts.entries
        .map((entry) => _VersionCount(version: entry.key, count: entry.value))
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    final latestCount = counts[latestVersion] ?? 0;
    final latestAdoptionPercent = totalActiveToday == 0
        ? 0.0
        : (latestCount * 100.0) / totalActiveToday;

    return _AdoptionViewData(
      isAuthorized: true,
      totalActiveToday: totalActiveToday,
      latestVersion: latestVersion,
      latestAdoptionPercent: latestAdoptionPercent,
      graceDays: graceDays,
      versionRows: rows,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _loadAdoptionData();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.lightblue,
        title: const Text('App Adoption'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<_AdoptionViewData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(
              child: Text('Unable to load adoption data.'),
            );
          }

          final data = snapshot.data!;
          if (!data.isAuthorized) {
            return Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock, size: 44.sp),
                    SizedBox(height: 12.h),
                    Text(
                      'Admin access required',
                      style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: EdgeInsets.all(16.w),
              children: [
                _MetricCard(
                  title: 'Daily Active Users',
                  value: '${data.totalActiveToday}',
                  subtitle: 'Users seen since 12:00 AM',
                ),
                SizedBox(height: 10.h),
                _MetricCard(
                  title: 'Latest Version Adoption',
                  value: '${data.latestAdoptionPercent.toStringAsFixed(1)}%',
                  subtitle: 'Latest: ${data.latestVersion} • Grace: ${data.graceDays} days',
                ),
                SizedBox(height: 16.h),
                Text(
                  'Version Breakdown (Today)',
                  style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 10.h),
                if (data.versionRows.isEmpty)
                  Container(
                    padding: EdgeInsets.all(14.w),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10.r),
                      color: AppColors.white,
                      border: Border.all(color: AppColors.lightblue),
                    ),
                    child: const Text('No adoption events recorded yet today.'),
                  )
                else
                  ...data.versionRows.map((row) {
                    final percent = data.totalActiveToday == 0
                        ? 0.0
                        : (row.count * 100.0) / data.totalActiveToday;
                    return Container(
                      margin: EdgeInsets.only(bottom: 8.h),
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10.r),
                        color: AppColors.white,
                        border: Border.all(color: AppColors.lightblue),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              row.version,
                              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text(
                            '${row.count} users • ${percent.toStringAsFixed(1)}%',
                            style: TextStyle(fontSize: 13.sp),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.r),
        color: AppColors.white,
        border: Border.all(color: AppColors.lightblue),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500)),
          SizedBox(height: 6.h),
          Text(value, style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.w700)),
          SizedBox(height: 4.h),
          Text(subtitle, style: TextStyle(fontSize: 12.sp)),
        ],
      ),
    );
  }
}

class _VersionCount {
  final String version;
  final int count;

  const _VersionCount({required this.version, required this.count});
}

class _AdoptionViewData {
  final bool isAuthorized;
  final int totalActiveToday;
  final String latestVersion;
  final double latestAdoptionPercent;
  final int graceDays;
  final List<_VersionCount> versionRows;

  const _AdoptionViewData({
    required this.isAuthorized,
    required this.totalActiveToday,
    required this.latestVersion,
    required this.latestAdoptionPercent,
    required this.graceDays,
    required this.versionRows,
  });

  const _AdoptionViewData.unauthorized()
      : isAuthorized = false,
        totalActiveToday = 0,
        latestVersion = '-',
        latestAdoptionPercent = 0,
        graceDays = 5,
        versionRows = const [];
}
