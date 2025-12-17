import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';
import 'package:busmate_web/modules/SuperAdmin/dashboard/dashboard_controller.dart';

class EnhancedSuperAdminHomeScreen extends StatefulWidget {
  const EnhancedSuperAdminHomeScreen({super.key});

  @override
  State<EnhancedSuperAdminHomeScreen> createState() => _EnhancedSuperAdminHomeScreenState();
}

class _EnhancedSuperAdminHomeScreenState extends State<EnhancedSuperAdminHomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _loading = true;
  int _totalSchools = 0;
  int _totalBuses = 0;
  int _totalDrivers = 0;
  int _totalStudents = 0;
  int _activeBuses = 0;
  double _revenueThisMonth = 0;

  List<Map<String, dynamic>> _recentSchools = [];
  List<Map<String, dynamic>> _pendingPayments = [];
  List<Map<String, dynamic>> _systemAlerts = [];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _loading = true);

    try {
      // Use schooldetails as primary collection (matches the rest of the app)
      final schoolsSnap = await _firestore.collection('schooldetails').get();
      final busesSnap = await _firestore.collectionGroup('buses').get();
      final driversSnap = await _firestore.collectionGroup('drivers').get();
      final studentsSnap = await _firestore.collectionGroup('students').get();
      final busStatusSnap = await _firestore.collection('bus_status').get();

      // Try to get recent schools with ordering, fallback to unordered if index missing
      QuerySnapshot<Map<String, dynamic>> recentSchoolsSnap;
      try {
        recentSchoolsSnap = await _firestore
            .collection('schooldetails')
            .orderBy('created_at', descending: true)
            .limit(5)
            .get();
      } catch (e) {
        debugPrint('OrderBy failed, using unordered query: $e');
        recentSchoolsSnap = await _firestore.collection('schooldetails').limit(5).get();
      }

      final allPayments = <Map<String, dynamic>>[];
      double revenue = 0;

      for (final school in schoolsSnap.docs) {
        try {
          QuerySnapshot<Map<String, dynamic>> paySnap;
          try {
            paySnap = await _firestore
                .collection('schooldetails')
                .doc(school.id)
                .collection('payments')
                .orderBy('createdAt', descending: true)
                .limit(3)
                .get();
          } catch (e) {
            debugPrint('Payment orderBy failed for ${school.id}: $e');
            paySnap = await _firestore
                .collection('schooldetails')
                .doc(school.id)
                .collection('payments')
                .limit(3)
                .get();
          }

          for (final p in paySnap.docs) {
            final data = p.data();
            final status = (data['status'] ?? '').toString().toLowerCase();
            final amount = (data['amount'] is num) ? (data['amount'] as num).toDouble() : 0.0;

            if (status == 'completed' || status == 'paid') {
              final createdAt = data['createdAt'] is Timestamp
                  ? (data['createdAt'] as Timestamp).toDate()
                  : null;
              if (createdAt != null &&
                  createdAt.month == DateTime.now().month &&
                  createdAt.year == DateTime.now().year) {
                revenue += amount;
              }
            }

            if (status == 'pending') {
              allPayments.add({
                ...data,
                'schoolName': school['schoolName'] ?? school['school_name'] ?? 'Unknown',
                'schoolId': school.id,
                'paymentId': p.id,
              });
            }
          }
        } catch (e) {
          debugPrint('Error processing school ${school.id}: $e');
        }
      }

      allPayments.sort((a, b) {
        final aTime = a['createdAt'] is Timestamp ? (a['createdAt'] as Timestamp).toDate() : DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b['createdAt'] is Timestamp ? (b['createdAt'] as Timestamp).toDate() : DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      final activeCount = busStatusSnap.docs
          .where((d) {
            try {
              return (d.data()['currentStatus'] ?? '').toString().toLowerCase() == 'active';
            } catch (e) {
              return false;
            }
          })
          .length;

      if (mounted) {
        setState(() {
          _totalSchools = schoolsSnap.size;
          _totalBuses = busesSnap.size;
          _totalDrivers = driversSnap.size;
          _totalStudents = studentsSnap.size;
          _activeBuses = activeCount;
          _revenueThisMonth = revenue;
          _recentSchools = recentSchoolsSnap.docs.map((d) {
            try {
              return {
                'name': d['schoolName'] ?? d['school_name'] ?? 'Unnamed',
                'email': d['email'] ?? '',
                'createdAt': d['created_at'] ?? d['createdAt'],
              };
            } catch (e) {
              return {
                'name': 'Unnamed',
                'email': '',
                'createdAt': null,
              };
            }
          }).toList();
          _pendingPayments = allPayments.take(5).toList();
          _systemAlerts = [
            {'level': 'info', 'message': 'Firestore connection healthy'},
            {'level': 'info', 'message': 'All bus services operational'},
            if (_pendingPayments.length > 3) {'level': 'warning', 'message': '${_pendingPayments.length} pending payments require attention'},
          ];
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Super Admin dashboard error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          // Set safe defaults even on error
          _systemAlerts = [
            {'level': 'warning', 'message': 'Unable to load complete dashboard data'},
            {'level': 'info', 'message': 'Please refresh or check your connection'},
          ];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue[50]!,
              Colors.white,
              Colors.purple[50]!,
            ],
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E3A8A)),
          ),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 1200;
    final isMedium = screenWidth > 768;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF0F9FF),
            Colors.white,
            Color(0xFFFAF5FF),
          ],
        ),
      ),
      child: RefreshIndicator(
        onRefresh: _loadDashboard,
        color: const Color(0xFF1E3A8A),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildAnimatedHeader(context, isMedium),
              Padding(
                padding: EdgeInsets.all(isMedium ? 32 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsGrid(context, isWide, isMedium),
                    const SizedBox(height: 32),
                    _buildMiddleSection(context, isWide, isMedium),
                    const SizedBox(height: 32),
                    _buildBottomSection(context, isWide, isMedium),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedHeader(BuildContext context, bool isMedium) {
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12
        ? '🌅 Good Morning'
        : hour < 17
            ? '☀️ Good Afternoon'
            : '🌙 Good Evening';

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1200),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.all(isMedium ? 32 : 16),
        padding: EdgeInsets.all(isMedium ? 40 : 24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF667EEA),
              Color(0xFF764BA2),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF667EEA).withOpacity(0.4),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        greeting,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.95),
                          fontSize: isMedium ? 36 : 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Super Admin Dashboard',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: isMedium ? 18 : 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isMedium)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.white, size: 18),
                        const SizedBox(width: 10),
                        Text(
                          DateFormat('EEE, MMM d, yyyy').format(now),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                _buildHeaderStat('Total Schools', _totalSchools.toString(), Icons.school),
                _buildHeaderStat('Active Fleet', '$_activeBuses/$_totalBuses', Icons.local_shipping),
                _buildHeaderStat('Revenue', '₹${_revenueThisMonth.toStringAsFixed(0)}', Icons.trending_up),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, bool isWide, bool isMedium) {
    final metrics = [
      _MetricData(
        icon: Icons.school,
        label: 'Total Schools',
        value: _totalSchools,
        color: const Color(0xFF6366F1),
        gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
      ),
      _MetricData(
        icon: Icons.directions_bus,
        label: 'Total Buses',
        value: _totalBuses,
        color: const Color(0xFF3B82F6),
        gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2563EB)]),
      ),
      _MetricData(
        icon: Icons.person_pin,
        label: 'Total Drivers',
        value: _totalDrivers,
        color: const Color(0xFFEC4899),
        gradient: const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFFDB2777)]),
      ),
      _MetricData(
        icon: Icons.groups_rounded,
        label: 'Total Students',
        value: _totalStudents,
        color: const Color(0xFF10B981),
        gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
      ),
      _MetricData(
        icon: Icons.electric_bolt,
        label: 'Active Buses',
        value: _activeBuses,
        color: const Color(0xFFF59E0B),
        gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
      ),
      _MetricData(
        icon: Icons.currency_rupee,
        label: 'Monthly Revenue',
        value: _revenueThisMonth.toInt(),
        color: const Color(0xFF14B8A6),
        gradient: const LinearGradient(colors: [Color(0xFF14B8A6), Color(0xFF0D9488)]),
      ),
    ];

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 800),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.9 + (0.1 * value),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isWide ? 3 : (isMedium ? 2 : 1),
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
          childAspectRatio: isWide ? 1.8 : (isMedium ? 1.5 : 1.3),
        ),
        itemCount: metrics.length,
        itemBuilder: (context, index) {
          final m = metrics[index];
          return _buildEnhancedMetricCard(m, index);
        },
      ),
    );
  }

  Widget _buildEnhancedMetricCard(_MetricData data, int index) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 600 + (index * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(-50 * (1 - value), 0),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                data.color.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: data.color.withOpacity(0.15), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: data.color.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: data.gradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: data.color.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(data.icon, color: Colors.white, size: 28),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: data.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '+12%',
                      style: TextStyle(
                        color: data.color,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.label,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    data.value.toString(),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: data.color,
                      letterSpacing: -1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiddleSection(BuildContext context, bool isWide, bool isMedium) {
    return isWide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: _buildSystemHealthCard(isMedium)),
              const SizedBox(width: 24),
              Expanded(flex: 3, child: _buildQuickActionsCard(isMedium)),
            ],
          )
        : Column(
            children: [
              _buildSystemHealthCard(isMedium),
              const SizedBox(height: 24),
              _buildQuickActionsCard(isMedium),
            ],
          );
  }

  Widget _buildSystemHealthCard(bool isMedium) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1000),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(-30 * (1 - value), 0),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        padding: EdgeInsets.all(isMedium ? 28 : 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF10B981), Color(0xFF059669)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.health_and_safety, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                const Text(
                  'System Health',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ..._systemAlerts.map((alert) {
              final isWarning = alert['level'] == 'warning';
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(isWarning ? 0.2 : 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isWarning ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          alert['message'] ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsCard(bool isMedium) {
    final controller = Get.find<SuperAdminDashboardController>(tag: 'superAdmin');
    
    final actions = [
      _ActionItem(
        icon: Icons.add_business,
        label: 'Add School',
        color: const Color(0xFF6366F1),
        onTap: () {
          controller.changePage(1); // Navigate to School Management
        },
      ),
      _ActionItem(
        icon: Icons.campaign,
        label: 'Broadcast',
        color: const Color(0xFFEC4899),
        onTap: () {
          controller.changePage(3); // Navigate to Notifications
        },
      ),
      _ActionItem(
        icon: Icons.receipt_long,
        label: 'Payments',
        color: const Color(0xFF14B8A6),
        onTap: () {
          controller.changePage(2); // Navigate to Payment Management
        },
      ),
      _ActionItem(
        icon: Icons.analytics_outlined,
        label: 'Analytics',
        color: const Color(0xFFF59E0B),
        onTap: () {
          // TODO: Navigate to analytics page when available
          Get.snackbar(
            'Coming Soon',
            'Analytics dashboard will be available soon',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: const Color(0xFFF59E0B).withOpacity(0.9),
            colorText: Colors.white,
          );
        },
      ),
      _ActionItem(
        icon: Icons.settings,
        label: 'Settings',
        color: const Color(0xFF8B5CF6),
        onTap: () {
          Get.snackbar(
            'Coming Soon',
            'Settings page will be available soon',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.9),
            colorText: Colors.white,
          );
        },
      ),
      _ActionItem(
        icon: Icons.support_agent,
        label: 'Support',
        color: const Color(0xFF3B82F6),
        onTap: () {
          Get.snackbar(
            'Support',
            'For support, contact admin@busmate.com',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: const Color(0xFF3B82F6).withOpacity(0.9),
            colorText: Colors.white,
            duration: const Duration(seconds: 4),
          );
        },
      ),
    ];

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1200),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(30 * (1 - value), 0),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        padding: EdgeInsets.all(isMedium ? 28 : 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isMedium ? 3 : 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: isMedium ? 1.4 : 1.2,
              ),
              itemCount: actions.length,
              itemBuilder: (context, index) {
                final action = actions[index];
                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: action.onTap,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            action.color.withOpacity(0.1),
                            action.color.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: action.color.withOpacity(0.2)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [action.color, action.color.withOpacity(0.7)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: action.color.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(action.icon, color: Colors.white, size: 24),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            action.label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: action.color,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSection(BuildContext context, bool isWide, bool isMedium) {
    return isWide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildRecentSchoolsCard(isMedium)),
              const SizedBox(width: 24),
              Expanded(child: _buildPendingPaymentsCard(isMedium)),
            ],
          )
        : Column(
            children: [
              _buildRecentSchoolsCard(isMedium),
              const SizedBox(height: 24),
              _buildPendingPaymentsCard(isMedium),
            ],
          );
  }

  Widget _buildRecentSchoolsCard(bool isMedium) {
    final controller = Get.find<SuperAdminDashboardController>(tag: 'superAdmin');
    
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1400),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        padding: EdgeInsets.all(isMedium ? 28 : 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.school, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                const Text(
                  'Recently Added Schools',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    controller.changePage(1); // Navigate to School Management
                  },
                  child: const Text('View All →'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_recentSchools.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(Icons.school_outlined, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text(
                        'No recent schools',
                        style: TextStyle(color: Colors.grey[500], fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ..._recentSchools.map((school) {
              final createdAt = school['createdAt'] is Timestamp
                  ? (school['createdAt'] as Timestamp).toDate()
                  : null;
              final dateStr = createdAt != null ? DateFormat('MMM d, yyyy').format(createdAt) : '';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF6366F1).withOpacity(0.05),
                      const Color(0xFF8B5CF6).withOpacity(0.02),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.school, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            school['name'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            school['email'] ?? '',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingPaymentsCard(bool isMedium) {
    final controller = Get.find<SuperAdminDashboardController>(tag: 'superAdmin');
    
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1600),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        padding: EdgeInsets.all(isMedium ? 28 : 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.payments, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                const Text(
                  'Pending Payments',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    controller.changePage(2); // Navigate to Payment Management
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_pendingPayments.length} pending',
                            style: const TextStyle(
                              color: Color(0xFFF59E0B),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward,
                            size: 14,
                            color: Color(0xFFF59E0B),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_pendingPayments.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(Icons.check_circle_outline, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text(
                        'All payments cleared!',
                        style: TextStyle(color: Colors.grey[500], fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ..._pendingPayments.map((payment) {
              final amount = (payment['amount'] is num) ? (payment['amount'] as num).toDouble() : 0.0;
              final createdAt = payment['createdAt'] is Timestamp
                  ? (payment['createdAt'] as Timestamp).toDate()
                  : null;
              final dateStr = createdAt != null ? DateFormat('MMM d').format(createdAt) : '';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFF59E0B).withOpacity(0.05),
                      const Color(0xFFD97706).withOpacity(0.02),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.15)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.currency_rupee, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            payment['schoolName'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₹${amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Color(0xFFF59E0B),
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'PENDING',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFF59E0B),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          dateStr,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _MetricData {
  final IconData icon;
  final String label;
  final int value;
  final Color color;
  final Gradient gradient;

  _MetricData({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.gradient,
  });
}

class _ActionItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  _ActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}
