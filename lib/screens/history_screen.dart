import 'package:flutter/material.dart';
import '../services/api_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<HistoryScreen> {
  List<dynamic> pastResults = [];
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _loadPastResults();
  }

  Future<void> _loadPastResults() async {
    setState(() => loading = true);
    try {
      final res = await ApiService.getPastResults();
      setState(() {
        pastResults = res.reversed.toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load history: $e')),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _deleteRecord(String filename, String timestamp) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete record'),
        content: const Text('Are you sure you want to delete this record?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ApiService.deleteResult(filename, timestamp);
      _loadPastResults();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadPastResults,
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : pastResults.isEmpty
                ? const Center(child: Text('No past results found'))
                : ListView.separated(
                    itemCount: pastResults.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final r = pastResults[index];
                      return ListTile(
                        title: Text(r['filename'] ?? 'Image'),
                        subtitle: Text(
                          'Grade: ${r['grade']} • ${r['prediction']}\n${r['timestamp']}',
                        ),
                        trailing: IconButton(
                          icon:
                              const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteRecord(
                            r['filename'],
                            r['timestamp'],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}