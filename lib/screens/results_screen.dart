import 'dart:io';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  Map<String, dynamic>? latest;
  Map<String, dynamic>? priceResult;
  String? imagePath;
  Map<String, dynamic>? inputs;

  String? selectedLocation;

  Map<String, dynamic>? marketAdvice;
  bool loadingMarket = false;

  final List<String> locations = [
    "Nashik",
    "Mumbai",
    "Pune",
    "Aurangabad",
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;

    if (args != null) {
      latest = args['latest'];
      priceResult = args['priceResult'];
      imagePath = args['sourceImagePath'];
      inputs = args['inputs'];
    }
  }

  Future<void> _loadMarketRecommendation() async {
    if (selectedLocation == null || latest == null) return;

    setState(() {
      loadingMarket = true;
      marketAdvice = null;
    });

    try {
      final res = await ApiService.getMarketRecommendation(
        location: selectedLocation!,
        quality: latest!['grade'],
        fruit: inputs?['fruit'] ?? 'fruit',
      );

      setState(() => marketAdvice = res);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Market recommendation failed: $e')),
      );
    } finally {
      setState(() => loadingMarket = false);
    }
  }

  Widget _buildLatestCard() {
    final themeGreen = const Color(0xFF1F7A36);

    if (latest == null && priceResult == null) {
      return const SizedBox.shrink();
    }

    double? rawConfidence =
        latest?['confidence'] is num ? latest!['confidence'].toDouble() : null;

    double confidencePercent =
        rawConfidence == null ? 0 : (rawConfidence <= 1 ? rawConfidence * 100 : rawConfidence);

    String formattedConfidence =
        confidencePercent.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (imagePath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  File(imagePath!),
                  height: 150,
                  fit: BoxFit.cover,
                ),
              ),

            const SizedBox(height: 16),

            if (latest != null) ...[
              Text(
                'Quality Grading',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: themeGreen,
                ),
              ),
              const SizedBox(height: 12),
              _infoTile("Grade", latest!['grade'], themeGreen),
              _infoTile("Confidence", "$formattedConfidence%", themeGreen),
              if (latest!['summary'] != null)
                _summaryBox(latest!['summary']),
            ],

            const SizedBox(height: 16),

            Text(
              'Your Location',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: themeGreen,
              ),
            ),
            const SizedBox(height: 8),

            _locationDropdown(themeGreen),

            const SizedBox(height: 16),
ElevatedButton(
  onPressed: loadingMarket ? null : _loadMarketRecommendation,
  style: ElevatedButton.styleFrom(
    backgroundColor: themeGreen,
    padding: const EdgeInsets.symmetric(vertical: 14),
  ),
  child: loadingMarket
      ? const CircularProgressIndicator(color: Colors.white)
      : const Text(
          'Get Market Recommendation',
          style: TextStyle(
            color: Colors.white, // text color
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
),

            if (marketAdvice != null) ...[
              const SizedBox(height: 20),
              Text(
                'Recommended Market',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: themeGreen,
                ),
              ),
              const SizedBox(height: 6),

              Text(
                marketAdvice!['recommended_market'] ?? '-',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),

              const SizedBox(height: 10),
              Text(
                marketAdvice!['reason'] ?? '',
                style: const TextStyle(fontSize: 15, height: 1.4),
              ),

              if ((marketAdvice!['eligible_markets'] as List).length > 1) ...[
                const SizedBox(height: 14),
                const Text(
                  'Other suitable markets',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                ...marketAdvice!['eligible_markets']
                    .where((m) => m != marketAdvice!['recommended_market'])
                    .map<Widget>((m) => _marketChip(m))
                    .toList(),
              ],
            ],

            if (priceResult != null) ...[
              const SizedBox(height: 20),
              Text(
                'Price Estimation',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: themeGreen,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '₹${priceResult!['estimated_price_per_quintal']} / Quintal',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _locationDropdown(Color themeGreen) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: themeGreen.withOpacity(0.5)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedLocation,
          hint: const Text('Select location'),
          isExpanded: true,
          items: locations
              .map((l) => DropdownMenuItem(value: l, child: Text(l)))
              .toList(),
          onChanged: (val) => setState(() => selectedLocation = val),
        ),
      ),
    );
  }

  Widget _marketChip(String market) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        market,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _infoTile(String label, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 18)),
          Text(
            value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _summaryBox(String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: const TextStyle(fontSize: 16, height: 1.4)),
    );
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Results'),
      actions: [
        IconButton(
          icon: const Icon(Icons.bar_chart),
          onPressed: () => Navigator.pushNamed(context, '/dashboard'),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _buildLatestCard(),
      ],
    ),
  );
}
}