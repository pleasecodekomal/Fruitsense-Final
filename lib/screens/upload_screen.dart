import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

// Helper to capitalize dropdown text
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

  // ===== INPUTS =====
  String _selectedFruit = 'apple';
  String? _selectedMarket;
  String? _selectedVariety;
  final TextEditingController _arrivalsCtrl =
      TextEditingController(text: "10");

  final List<String> _fruits = ['apple', 'orange', 'banana'];
  final List<String> _markets = [
    'Chail Chowk',
    'Chamba',
    'Dehradoon',
    'Kanispora Baramulla (F&V)',
    'Narwal Jammu (F&V)',
    'Rishikesh',
  ];
  final List<String> _varieties = [
    'American',
    'Delicious',
    'Golden',
    'Maharaji',
    'Hajratbali',
    'Rizakwadi',
    'Kesri',
    'Royal Delicious',
    'Simla',
  ];

  // ================= IMAGE PICK =================
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

  // ================= QUALITY =================
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

  // ================= PRICE =================
  Future<void> _estimatePrice() async {
    if (_imageFile == null) {
      _showSnack("Select an image first");
      return;
    }

    // Only require market, variety, and arrivals if fruit is apple
    if (_selectedFruit == 'apple' &&
        (_selectedMarket == null || _selectedVariety == null || _arrivalsCtrl.text.isEmpty)) {
      _showSnack("Select market, variety, and arrivals");
      return;
    }

    setState(() => _loading = true);

    try {
      final res = await ApiService.predictPrice(
        file: _imageFile!,
        fruit: _selectedFruit,
        market: _selectedMarket ?? "",
        variety: _selectedVariety ?? "",
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

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    // Disable dropdowns and arrivals field for orange and banana
    bool disableInputs =
        _selectedFruit == 'orange' || _selectedFruit == 'banana';

    // Clear previous selections if disabled
    if (disableInputs) {
      _selectedMarket = null;
      _selectedVariety = null;
      _arrivalsCtrl.text = "";
    }

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
                // ===== IMAGE UPLOAD =====
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
                                  size: 56, color: Colors.grey[400]),
                              const SizedBox(height: 8),
                              const Text('Tap to pick image from gallery',
                                  style: TextStyle(color: Colors.grey)),
                              const SizedBox(height: 6),
                              const Text('PNG, JPG or JPEG',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 12)),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () => _pickImage(ImageSource.camera),
                                icon: const Icon(Icons.camera_alt),
                                label: const Text('Open Camera'),
                              ),
                            ],
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.file(File(_imageFile!.path),
                                fit: BoxFit.cover, width: double.infinity),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                // ===== FRUIT SELECTION =====
                DropdownButtonFormField<String>(
                  value: _selectedFruit,
                  decoration: const InputDecoration(
                      labelText: 'Select Fruit', border: OutlineInputBorder()),
                  items: _fruits
                      .map((f) => DropdownMenuItem(
                            value: f,
                            child: Text(f.capitalize()),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedFruit = v!),
                ),

                const SizedBox(height: 16),

                // ===== MARKET SELECTION =====
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _selectedMarket,
                  decoration: const InputDecoration(
                      labelText: "Market", border: OutlineInputBorder()),
                  items: _markets
                      .map((m) => DropdownMenuItem(
                            value: m,
                            child: Text(m, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged:
                      disableInputs ? null : (v) => setState(() => _selectedMarket = v),
                ),

                const SizedBox(height: 16),

                // ===== VARIETY SELECTION =====
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _selectedVariety,
                  decoration: const InputDecoration(
                      labelText: "Variety", border: OutlineInputBorder()),
                  items: _varieties
                      .map((v) => DropdownMenuItem(
                            value: v,
                            child: Text(v, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged:
                      disableInputs ? null : (v) => setState(() => _selectedVariety = v),
                ),

                const SizedBox(height: 16),

                // ===== ARRIVALS =====
                TextField(
                  controller: _arrivalsCtrl,
                  enabled: !disableInputs,
                  decoration: const InputDecoration(
                      labelText: "Arrivals (Tonnes)",
                      border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),

                const SizedBox(height: 20),

                // ===== BUTTONS =====
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