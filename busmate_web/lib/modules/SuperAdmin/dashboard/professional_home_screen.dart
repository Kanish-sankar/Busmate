import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';
import 'package:busmate_web/utils/responsive.dart';

class ProfessionalSuperAdminHomeScreen extends StatefulWidget {
  const ProfessionalSuperAdminHomeScreen({super.key});

  @override
  State<ProfessionalSuperAdminHomeScreen> createState() =>
      _ProfessionalSuperAdminHomeScreenState();
}

class _ProfessionalSuperAdminHomeScreenState
    extends State<ProfessionalSuperAdminHomeScreen> {
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
      // Load critical data in parallel for faster initial display
      final results = await Future.wait([
        _firestore.collection('schooldetails').limit(50).get(),
        _firestore.collectionGroup('buses').get(),
        _firestore.collectionGroup('drivers').get(),
        _firestore.collectionGroup('students').get(),
        _firestore.collection('bus_status').get(),
        _loadRecentSchools(),
      ]);

      final schoolsSnap = results[0] as QuerySnapshot<Map<String, dynamic>>;
      final busesSnap = results[1] as QuerySnapshot;
      final driversSnap = results[2] as QuerySnapshot;
      final studentsSnap = results[3] as QuerySnapshot;
      final busStatusSnap = results[4] as QuerySnapshot<Map<String, dynamic>>;
      final recentSchoolsSnap = results[5] as QuerySnapshot<Map<String, dynamic>>;

      final activeCount = busStatusSnap.docs
          .where((d) {
            try {
              return (d.data()['currentStatus'] ?? '')
                      .toString()
                      .toLowerCase() ==
                  'active';
            } catch (e) {
              return false;
            }
          })
          .length;

      // Set initial state quickly to show UI
      if (mounted) {
        setState(() {
          _totalSchools = schoolsSnap.size;
          _totalBuses = busesSnap.size;
          _totalDrivers = driversSnap.size;
          _totalStudents = studentsSnap.size;
          _activeBuses = activeCount;
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
          _systemAlerts = [
            {'level': 'success', 'message': 'All systems operational'},
          ];
          _loading = false;
        });
      }

      // Load payments in background (non-blocking)
      _loadPaymentsInBackground(schoolsSnap.docs);
    } catch (e) {
      debugPrint('Dashboard error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _systemAlerts = [
            {'level': 'error', 'message': 'Unable to load dashboard data'},
          ];
        });
      }
    }
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _loadRecentSchools() async {
    try {
      return await _firestore
          .collection('schooldetails')
          .orderBy('created_at', descending: true)
          .limit(5)
          .get();
    } catch (e) {
      return await _firestore.collection('schooldetails').limit(5).get();
    }
  }

  void _loadPaymentsInBackground(List<QueryDocumentSnapshot<Map<String, dynamic>>> schools) async {
    try {
      final allPayments = <Map<String, dynamic>>[];
      double revenue = 0;

      // Process only first 10 schools for faster loading
      final schoolsToProcess = schools.take(10);

      for (final school in schoolsToProcess) {
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
            final amount = (data['amount'] is num)
                ? (data['amount'] as num).toDouble()
                : 0.0;

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
                'schoolName': school['schoolName'] ??
                    school['school_name'] ??
                    'Unknown',
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
        final aTime = a['createdAt'] is Timestamp
            ? (a['createdAt'] as Timestamp).toDate()
            : DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b['createdAt'] is Timestamp
            ? (b['createdAt'] as Timestamp).toDate()
            : DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      if (mounted) {
        setState(() {
          _revenueThisMonth = revenue;
          _pendingPayments = allPayments.take(5).toList();
          if (_pendingPayments.length > 3) {
            _systemAlerts = [
              {'level': 'success', 'message': 'All systems operational'},
              {
                'level': 'warning',
                'message':
                    '${_pendingPayments.length} pending payments require attention'
              },
            ];
          }
        });
      }
    } catch (e) {
      debugPrint('Background payment load error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
            strokeWidth: 3,
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
        ),
      ),
      child: RefreshIndicator(
        onRefresh: _loadDashboard,
        color: const Color(0xFF2563EB),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(ResponsiveLayout.getHorizontalPadding(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              SizedBox(height: ResponsiveLayout.getVerticalSpacing(context)),
              _buildStatsGrid(context),
              SizedBox(height: ResponsiveLayout.getVerticalSpacing(context)),
              Responsive.isMobile(context)
                  ? Column(
                      children: [
                        _buildRecentSchools(context),
                        const SizedBox(height: 16),
                        _buildPendingPayments(context),
                        const SizedBox(height: 16),
                        _buildSystemAlerts(context),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            children: [
                              _buildRecentSchools(context),
                              const SizedBox(height: 24),
                              _buildPendingPayments(context),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 2,
                          child: _buildSystemAlerts(context),
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';
    
    final isMobile = Responsive.isMobile(context);

    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
        ),
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            greeting,
            style: TextStyle(
              fontSize: ResponsiveLayout.getFontSize(context, desktop: 32, tablet: 28, mobile: 24),
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: isMobile ? 4 : 8),
          Text(
            'Super Admin Dashboard',
            style: TextStyle(
              fontSize: ResponsiveLayout.getFontSize(context, desktop: 16, tablet: 14, mobile: 12),
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
          if (!isMobile) const SizedBox(height: 16),
          if (!isMobile)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today, size: 18, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(
                    DateFormat('MMM d, yyyy').format(now),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final stats = [
      _StatData('Total ScBuildContext context) {
    final stats = [
      _StatData('Total Schools', _totalSchools.toString(), Icons.school,
          const Color(0xFF1976D2)),
      _StatData('Total Buses', _totalBuses.toString(), Icons.directions_bus,
          const Color(0xFF0288D1)),
      _StatData('Total Drivers', _totalDrivers.toString(), Icons.person,
          const Color(0xFF0097A7)),
      _StatData('Total Students', _totalStudents.toString(), Icons.groups,
          const Color(0xFF00796B)),
      _StatData('Active Buses', '$_activeBuses / $_totalBuses',
          Icons.electric_bolt, const Color(0xFFF57C00)),
      _StatData('Monthly Revenue', '₹${_revenueThisMonth.toStringAsFixed(0)}',
          Icons.currency_rupee, const Color(0xFF388E3C)),
    ];

    final crossAxisCount = ResponsiveLayout.getGridCrossAxisCount(
      context,
      desktop: 3,
      tablet: 2,
      mobile: 1,
    );

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,, BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: data.color.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 10 : 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [data.color, data.color.withOpacity(0.8)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: data.color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(data.icon, color: Colors.white, size: isMobile ? 20 : 26),
          ),
          SizedBox(width: isMobile ? 12 : 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  data.label,
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: isMobile ? 4 : 6),
                Text(
                  data.value,
                  style: TextStyle(
                    fontSize: isMobile ? 18 ht: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  data.value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: data.color,
                    letterSpacing: -0.5,
                  ),
                ),BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSchools() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.school, size: 20, color: Color(0xFF2563EB)),
                Text(
                  'Recent Schools',
                  style: TextStyle(
                    fontSize: ResponsiveLayout.getFontSize(context, desktop: 18, mobile: 16),
                    fontWeight: FontWeight.w700,
                    color: constze: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          if (_recentSchools.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('No recent schools'),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentSchools.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, color: Color(0xFFF5F7FA)),
              itemBuilder: (context, index) {
                final school = _recentSchools[index];
                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF2563EB).withOpacity(0.1),
                    child: const Icon(Icons.school,
                        size: 20, color: Color(0xFF2563EB)),
                  ),
                  title: Text(
                    school['name'] ?? 'Unnamed',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF212121),
                    ),
                  ),
                  subtitle: Text(
                    school['email'] ?? '',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  trailing: Text(
                    _formatDate(school['createdAt']),
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPendingPayments(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9800).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.payment, size: 20, color: Color(0xFFFF9800)),
                    Text(
                      'Pending Payments',
                      style: TextStyle(
                        fontSize: ResponsiveLayout.getFontSize(context, desktop: 18, mobile: 16),
                        fontWeight: FontWeight.w700,
                        color: constze: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                if (_pendingPayments.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9800).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_pendingPayments.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFF9800),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          if (_pendingPayments.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('No pending payments'),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _pendingPayments.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, color: Color(0xFFF5F7FA)),
              itemBuilder: (context, index) {
                final payment = _pendingPayments[index];
                final amount = (payment['amount'] is num)
                    ? (payment['amount'] as num).toDouble()
                    : 0.0;
                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFFF9800).withOpacity(0.1),
                    child: const Icon(Icons.payment,
                        size: 20, color: Color(0xFFFF9800)),
                  ),
                  title: Text(
                    payment['schoolName'] ?? 'Unknown School',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF212121),
                    ),
                  ),
                  subtitle: Text(
                    _formatDate(payment['createdAt']),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  trailing: Text(
                    '₹${amount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFF9800),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSystemAlerts(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.info_outline, size: 20, color: Color(0xFF10B981)),
                Text(
                  'System Status',
                  style: TextStyle(
                    fontSize: ResponsiveLayout.getFontSize(context, desktop: 18, mobile: 16),
                    fontWeight: FontWeight.w700,
                    color: constze: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          if (_systemAlerts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('No alerts'),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _systemAlerts.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, color: Color(0xFFF5F7FA)),
              itemBuilder: (context, index) {
                final alert = _systemAlerts[index];
                final level = alert['level'] ?? 'info';
                final color = level == 'success'
                    ? const Color(0xFF4CAF50)
                    : level == 'warning'
                        ? const Color(0xFFFF9800)
                        : const Color(0xFFF44336);
                final icon = level == 'success'
                    ? Icons.check_circle
                    : level == 'warning'
                        ? Icons.warning
                        : Icons.error;

                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  leading: Icon(icon, color: color, size: 24),
                  title: Text(
                    alert['message'] ?? '',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF212121),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return DateFormat('MMM d, yyyy').format(date);
    } else if (timestamp is String) {
      try {
        final date = DateTime.parse(timestamp);
        return DateFormat('MMM d, yyyy').format(date);
      } catch (e) {
        return 'N/A';
      }
    }
    return 'N/A';
  }
}

class _StatData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  _StatData(this.label, this.value, this.icon, this.color);
}
