import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

// Helper extension
extension StringCasing on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {

  final ImagePicker _picker = ImagePicker();

  XFile? _imageFile;
  bool _loading = false;

  String _selectedFruit = 'apple';
  String? _selectedMarket;
  String? _selectedVariety;

  final TextEditingController _arrivalsCtrl =
      TextEditingController(text: "10");

  final List<String> _fruits = ['apple', 'orange', 'banana'];

  // =========================
  // MARKET DATA MAP
  // =========================

  final Map<String, List<String>> marketMap = {
    'apple': [
      'Chail Chowk',
      'Chamba',
      'Dehradoon',
      'Kanispora Baramulla (F&V)',
      'Narwal Jammu (F&V)',
      'Rishikesh'
    ],
    'orange': [
      'Nasik APMC',
      'Hansi APMC',
      'Ladwa APMC',
      'Narnaul APMC',
      'PMY Kather Solan',
      'Rajpura APMC'
    ],
    'banana': [
      'Ernakulam APMC',
      'Ravulapelem APMC',
      'Bangalore APMC',
      'Thalasserry APMC',
      'Palakkad APMC'
    ],
  };

  // =========================
  // VARIETY DATA MAP
  // =========================

  final Map<String, List<String>> varietyMap = {
    'apple': [
      'American',
      'Delicious',
      'Golden',
      'Royal Delicious',
      'Simla'
    ],
    'orange': [
      'Kinnow',
      'Nagpur',
      'Mandarin',
      'Other'
    ],
    'banana': [
      'Banana - Ripe',
      'Robusta',
      'Poovan',
      'Nendra Bale',
      'Red Banana'
    ],
  };

  // =========================
  // IMAGE PICKER
  // =========================

  Future<void> _pickImage(ImageSource source) async {

    final XFile? picked = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );

    if (!mounted) return;

    if (picked != null) {
      setState(() {
        _imageFile = picked;
      });
    }
  }

  // =========================
  // QUALITY GRADING
  // =========================

  Future<void> _gradeQuality() async {

    if (_imageFile == null) {
      _showSnack("Select an image first");
      return;
    }

    setState(() => _loading = true);

    try {

      final res = await ApiService.summarizeQuality(
        file: _imageFile!,
        fruit: _selectedFruit,
      );

      if (!mounted) return;

      Navigator.pushNamed(context, '/results', arguments: {
        'latest': res,
        'sourceImagePath': _imageFile!.path,
        'inputs': {'fruit': _selectedFruit},
      });

    } catch (e) {

      _showSnack("Quality grading failed");

    } finally {

      if (mounted) setState(() => _loading = false);
    }
  }

  // =========================
  // PRICE ESTIMATION
  // =========================

  Future<void> _estimatePrice() async {

    if (_imageFile == null) {
      _showSnack("Select an image first");
      return;
    }

    if (_selectedMarket == null ||
        _selectedVariety == null ||
        _arrivalsCtrl.text.isEmpty) {

      _showSnack("Select market, variety and arrivals");
      return;
    }

    setState(() => _loading = true);

    try {

      final res = await ApiService.predictPrice(
        file: _imageFile!,
        fruit: _selectedFruit,
        market: _selectedMarket!,
        variety: _selectedVariety!,
        arrivals: _arrivalsCtrl.text,
      );

      if (!mounted) return;

      Navigator.pushNamed(context, '/results', arguments: {
        'priceResult': res,
        'sourceImagePath': _imageFile!.path,
        'inputs': {'fruit': _selectedFruit},
      });

    } catch (e) {

      _showSnack("Price estimation failed");

    } finally {

      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _arrivalsCtrl.dispose();
    super.dispose();
  }

  // =========================
  // UI
  // =========================

  @override
  Widget build(BuildContext context) {


    return Scaffold(
      appBar: AppBar(
        title: const Text("Grade & Predict Price"),
      ),
      body: Center(
        child: Container(
          width: 600,
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

                // ================= IMAGE =================

                GestureDetector(
                  onTap: () => _pickImage(ImageSource.gallery),
                  child: Container(
                    height: 220,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: _imageFile == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [

                              Icon(Icons.cloud_upload,
                                  size: 56,
                                  color: Colors.grey[400]),

                              const SizedBox(height: 8),

                              const Text(
                                'Tap to pick image from gallery',
                                style: TextStyle(color: Colors.grey),
                              ),

                              const SizedBox(height: 6),

                              const Text(
                                'PNG, JPG or JPEG',
                                style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12),
                              ),

                              const SizedBox(height: 12),

                              ElevatedButton.icon(
                                onPressed: () =>
                                    _pickImage(ImageSource.camera),
                                icon: const Icon(Icons.camera_alt),
                                label: const Text('Open Camera'),
                              ),
                            ],
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.file(
                              File(_imageFile!.path),
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                // ================= FRUIT =================

                DropdownButtonFormField<String>(
                  initialValue: _selectedFruit,
                  decoration: const InputDecoration(
                      labelText: 'Select Fruit',
                      border: OutlineInputBorder()),
                  items: _fruits
                      .map((f) => DropdownMenuItem(
                            value: f,
                            child: Text(f.capitalize()),
                          ))
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedFruit = val!;
                      _selectedMarket = null;
                      _selectedVariety = null;
                    });
                  },
                ),

                const SizedBox(height: 16),

                // ================= MARKET =================

                DropdownButtonFormField<String>(
                  hint: const Text("Select Market"),
                  initialValue: _selectedMarket,
                  decoration: const InputDecoration(
                      labelText: "Market",
                      border: OutlineInputBorder()),
                  items: (marketMap[_selectedFruit] ?? [])
                      .map((m) => DropdownMenuItem(
                            value: m,
                            child: Text(m),
                          ))
                      .toList(),
            onChanged: (val) => setState(() => _selectedMarket = val),),


                const SizedBox(height: 16),

                // ================= VARIETY =================

          DropdownButtonFormField<String>(
            hint: const Text("Select Variety"),
            initialValue: _selectedVariety,
            decoration: const InputDecoration(
              labelText: "Variety",
              border: OutlineInputBorder(),
            ),
            items: (varietyMap[_selectedFruit] ?? [])
                .map((v) => DropdownMenuItem(
                      value: v,
                      child: Text(v),
                    ))
                .toList(),
            onChanged: (val) => setState(() => _selectedVariety = val),
          ),

          const SizedBox(height: 16),
                // ================= ARRIVALS =================

                TextField(
                  controller: _arrivalsCtrl,
                  enabled: true,
                  decoration: const InputDecoration(
                      labelText: "Arrivals (Tonnes)",
                      border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),

                const SizedBox(height: 20),

                // ================= BUTTONS =================

                ElevatedButton(
                  onPressed: _loading ? null : _estimatePrice,
                  child: const Text("Estimate Price"),
                ),

                const SizedBox(height: 12),

                ElevatedButton(
                  onPressed: _loading ? null : _gradeQuality,
                  child: const Text("Quality Grading"),
                ),

                const SizedBox(height: 16),

                const Text(
                  "Tip: Use camera for live capture or gallery to pick an existing image.",
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
            ],
            ),
          ),
        ),
      ),
    );
  }
}
