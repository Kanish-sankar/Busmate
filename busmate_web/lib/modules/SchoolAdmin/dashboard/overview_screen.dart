import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SchoolAdminOverviewScreen extends StatefulWidget {
  const SchoolAdminOverviewScreen({
    super.key,
    required this.schoolId,
    required this.schoolData,
    this.fromSuperAdmin = false,
  });

  final String schoolId;
  final Map<String, dynamic> schoolData;
  final bool fromSuperAdmin;

  @override
  State<SchoolAdminOverviewScreen> createState() => _SchoolAdminOverviewScreenState();
}

class _SchoolAdminOverviewScreenState extends State<SchoolAdminOverviewScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _loading = true;
  bool _error = false;

  int _busCount = 0;
  int _driverCount = 0;
  int _studentCount = 0;
  int _routeCount = 0;
  double _onTimeRate = 0;

  List<Map<String, dynamic>> _liveFleet = [];
  List<Map<String, dynamic>> _paymentAlerts = [];
  List<Map<String, dynamic>> _recentActivity = [];

  @override
  void initState() {
    super.initState();
    _primeFromCachedData();
    _loadDashboard();
  }

  void _primeFromCachedData() {
    setState(() {
      _busCount = (widget.schoolData['totalBuses'] as int?) ?? 0;
      _driverCount = (widget.schoolData['totalDrivers'] as int?) ?? 0;
      _studentCount = (widget.schoolData['totalStudents'] as int?) ?? 0;
      _routeCount = (widget.schoolData['totalRoutes'] as int?) ?? 0;
    });
  }

  Future<void> _loadDashboard() async {
    if (widget.schoolId.isEmpty) {
      setState(() {
        _loading = false;
        _error = true;
      });
      return;
    }

    try {
      setState(() {
        _loading = true;
        _error = false;
      });

      final docRef = _firestore.collection('schooldetails').doc(widget.schoolId);

      final busDocs = await _safeCollectionDocs(docRef.collection('buses'));
      final driverDocs = await _safeCollectionDocs(docRef.collection('drivers'));
      final studentDocs = await _safeCollectionDocs(docRef.collection('students'));
      final routeDocs = await _safeCollectionDocs(docRef.collection('routes'));

      final busStatusSnap = await _firestore
          .collection('bus_status')
          .where('schoolId', isEqualTo: widget.schoolId)
          .limit(10)
          .get();

      final paymentsDocs = await _safeCollectionDocs(
        docRef.collection('payments').orderBy('createdAt', descending: true).limit(5),
      );

      final notificationDocs = await _safeCollectionDocs(
        docRef.collection('notifications').orderBy('createdAt', descending: true).limit(5),
      );

      final onTimeDocs = busStatusSnap.docs.where((d) => (d['isDelayed'] != true)).length;
      final totalStatusDocs = busStatusSnap.docs.length;
      final onTimeRate = totalStatusDocs == 0
          ? 0
          : (onTimeDocs / totalStatusDocs * 100).clamp(0, 100);

      setState(() {
        _busCount = busDocs.length;
        _driverCount = driverDocs.length;
        _studentCount = studentDocs.length;
        _routeCount = routeDocs.length;
        _onTimeRate = double.parse(onTimeRate.toStringAsFixed(1));

        _liveFleet = busStatusSnap.docs.map((doc) {
          final data = doc.data();
          return {
            'busNo': data['busNo'] ?? doc.id,
            'status': data['currentStatus'] ?? 'Unknown',
            'lastPoint': data['lastKnownStop'] ?? data['currentStop'] ?? '--',
            'updatedAt': data['timestamp'],
            'isDelayed': data['isDelayed'] == true,
          };
        }).take(6).toList();

        _paymentAlerts = paymentsDocs.map((doc) {
          final data = doc.data();
          return {
            'amount': data['amount'] ?? 0,
            'status': data['status'] ?? 'pending',
            'createdAt': data['createdAt'],
            'reference': doc.id,
          };
        }).toList();

        _recentActivity = notificationDocs.map((doc) {
          final data = doc.data();
          return {
            'title': data['title'] ?? 'Notification',
            'body': data['body'] ?? '',
            'createdAt': data['createdAt'],
          };
        }).toList();
      });
    } catch (e) {
      debugPrint('School dashboard load error: $e');
      setState(() {
        _error = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _safeCollectionDocs(
    Query<Map<String, dynamic>> query,
  ) async {
    try {
      final snapshot = await query.get();
      return snapshot.docs;
    } catch (e) {
      debugPrint('Dashboard query fallback: $e');
      return <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return _buildErrorState();
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeroSection(context)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            sliver: SliverToBoxAdapter(child: _buildMetricsGrid(context)),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverToBoxAdapter(child: _buildLiveFleetAndAlerts(context)),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            sliver: SliverToBoxAdapter(child: _buildActivityFeeds(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    final schoolName = widget.schoolData['schoolName'] ?? 'Your School';
    final location = widget.schoolData['address'] ?? 'Campus';

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x332563EB),
              blurRadius: 32,
              offset: Offset(0, 18),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              schoolName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.white70, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    location,
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 20,
              runSpacing: 12,
              children: [
                _HeroChip(label: 'On-time performance', value: '${_onTimeRate.toStringAsFixed(1)}%'),
                _HeroChip(label: 'Total students', value: _studentCount.toString()),
                if (widget.fromSuperAdmin)
                  const _HeroChip(label: 'Access', value: 'Super Admin Preview'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(BuildContext context) {
    final metrics = [
      _MetricTile(icon: Icons.directions_bus, label: 'Buses', value: _busCount),
      _MetricTile(icon: Icons.badge, label: 'Drivers', value: _driverCount),
      _MetricTile(icon: Icons.route, label: 'Routes', value: _routeCount),
      _MetricTile(icon: Icons.groups, label: 'Students', value: _studentCount),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isWide ? 4 : 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
          ),
          itemCount: metrics.length,
          itemBuilder: (context, index) => metrics[index],
        );
      },
    );
  }

  Widget _buildLiveFleetAndAlerts(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 1200;
        final children = [
          Expanded(child: _FleetCard(data: _liveFleet)),
          const SizedBox(width: 20),
          Expanded(child: _PaymentAlertCard(data: _paymentAlerts)),
        ];

        return isWide
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: children)
            : Column(
                children: [
                  _FleetCard(data: _liveFleet),
                  const SizedBox(height: 20),
                  _PaymentAlertCard(data: _paymentAlerts),
                ],
              );
      },
    );
  }

  Widget _buildActivityFeeds(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Announcements',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            if (_recentActivity.isEmpty)
              const Text('No announcements published recently.', style: TextStyle(color: Colors.grey)),
            ..._recentActivity.map((item) {
              final date = item['createdAt'] is Timestamp
                  ? (item['createdAt'] as Timestamp).toDate()
                  : null;
              final formatted = date != null ? DateFormat('dd MMM, hh:mm a').format(date) : '';
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.notifications, color: Colors.indigo),
                ),
                title: Text(item['title'] ?? ''),
                subtitle: Text(item['body'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: Text(formatted, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
          const SizedBox(height: 12),
          const Text('Unable to load dashboard data'),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _loadDashboard,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        boxShadow: const [
          BoxShadow(color: Color(0x11000000), blurRadius: 12, offset: Offset(0, 10)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.indigo.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.indigo),
          ),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            value.toString(),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _FleetCard extends StatelessWidget {
  const _FleetCard({required this.data});

  final List<Map<String, dynamic>> data;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Live Fleet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${data.length} tracked'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (data.isEmpty)
              const Text('No buses are reporting live positions.', style: TextStyle(color: Colors.grey)),
            ...data.map((item) {
              final updatedAt = item['updatedAt'] is Timestamp
                  ? (item['updatedAt'] as Timestamp).toDate()
                  : null;
              final formatted = updatedAt == null
                  ? 'Unknown'
                  : DateFormat('hh:mm a').format(updatedAt);
              final delayed = item['isDelayed'] == true;

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: delayed ? const Color(0xFFFFF1F0) : const Color(0xFFF1F5FF),
                ),
                child: Row(
                  children: [
                    Icon(Icons.directions_bus, color: delayed ? Colors.red : Colors.indigo),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['busNo']?.toString() ?? '--',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            item['lastPoint']?.toString() ?? '--',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: delayed ? Colors.red.withOpacity(0.15) : Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            item['status']?.toString() ?? 'Unknown',
                            style: TextStyle(
                              color: delayed ? Colors.red : Colors.green[800],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          formatted,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
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

class _PaymentAlertCard extends StatelessWidget {
  const _PaymentAlertCard({required this.data});

  final List<Map<String, dynamic>> data;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Payment Alerts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            if (data.isEmpty)
              const Text('No recent payment activity.', style: TextStyle(color: Colors.grey)),
            ...data.map((item) {
              final createdAt = item['createdAt'] is Timestamp
                  ? (item['createdAt'] as Timestamp).toDate()
                  : null;
              final formatted = createdAt == null
                  ? '--'
                  : DateFormat('dd MMM').format(createdAt);
              final amount = item['amount'] ?? 0;
              final status = (item['status'] ?? 'pending').toString();
              final isPending = status.toLowerCase() == 'pending';

              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: isPending ? Colors.orange[50] : Colors.green[50],
                  child: Icon(
                    Icons.receipt_long,
                    color: isPending ? Colors.orange : Colors.green,
                  ),
                ),
                title: Text('₹${amount is num ? amount.toStringAsFixed(2) : amount.toString()}'),
                subtitle: Text('Ref: ${item['reference']}'),
                trailing: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPending ? Colors.orange.withOpacity(0.15) : Colors.green.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          color: isPending ? Colors.orange[900] : Colors.green[900],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(formatted, style: const TextStyle(fontSize: 12, color: Colors.grey)),
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

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}