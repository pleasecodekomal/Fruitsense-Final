import 'package:flutter/material.dart';
import '../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? stats;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => loading = true);
    try {
      final res = await ApiService.getStats();
      setState(() => stats = res);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load stats: $e')));
    } finally {
      setState(() => loading = false);
    }
  }

  Widget _statCard(String title, String value) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(onPressed: () => Navigator.pushNamed(context, '/upload'), icon: const Icon(Icons.camera_alt)),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                children: [
                  const SizedBox(height: 6),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.3,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _statCard('Total Fruits Graded', stats?['totalGraded']?.toString() ?? '0'),
                      _statCard('Average Quality', stats?['avgQuality']?.toString() ?? '0%'),
                      _statCard('Today\'s Uploads', stats?['todayUploads']?.toString() ?? '0'),
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: InkWell(
                          onTap: () => Navigator.pushNamed(context, '/history'),
                          borderRadius: BorderRadius.circular(14),
                          child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: const [
                            Icon(Icons.history, size: 28, color: Colors.green),
                            SizedBox(height: 8),
                            Text('History', style: TextStyle(fontWeight: FontWeight.w600))
                          ])),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
