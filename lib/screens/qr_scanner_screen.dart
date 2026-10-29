import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:digilens/services/url_analysis_service.dart';
import 'package:digilens/services/scan_history_service.dart';
import 'package:digilens/services/qr_payload_service.dart';
import 'package:digilens/screens/scan_result_screen.dart';
import 'package:digilens/theme/app_theme.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> with WidgetsBindingObserver {
  MobileScannerController? _controller;
  bool _hasPermission = false;
  bool _isLoadingPermission = true;
  bool _isProcessing = false;
  bool _torchEnabled = false;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAndRequestCameraPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null) return;
    if (state == AppLifecycleState.resumed) {
      if (_hasPermission) {
        _controller?.start();
      }
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _controller?.stop();
    }
  }

  Future<void> _checkAndRequestCameraPermission() async {
    setState(() {
      _isLoadingPermission = true;
    });

    var status = await Permission.camera.status;
    if (status.isGranted) {
      setState(() {
        _hasPermission = true;
        _isLoadingPermission = false;
      });
      _initScanner();
      return;
    }

    status = await Permission.camera.request();
    if (status.isGranted) {
      setState(() {
        _hasPermission = true;
        _isLoadingPermission = false;
      });
      _initScanner();
    } else {
      setState(() {
        _hasPermission = false;
        _isLoadingPermission = false;
      });
    }
  }

  void _initScanner() {
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final String? rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.isNotEmpty) {
        _isProcessing = true;
        _controller?.stop();
        _processPayload(rawValue);
        break;
      }
    }
  }

  void _processPayload(String rawContent) {
    final payload = QrPayloadClassifier.classify(rawContent);

    if (payload.isWebUrl) {
      _showUrlConfirmationDialog(payload);
    } else {
      _showPayloadDialog(payload);
    }
  }

  void _showUrlConfirmationDialog(QrPayload payload) {
    final url = payload.url!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.qr_code_scanner, color: AppTheme.primary, size: 24),
            SizedBox(width: 10),
            Text('QR URL Detected', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The scanned QR code contains the following web link. Review it before analysis:',
              style: TextStyle(fontSize: 13, color: AppTheme.mutedText, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.grayBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.grayBorder),
              ),
              child: SelectableText(
                url,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.navyText, fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'DigiLens will scan this link for phishing, malware, and typo-squatting risks.',
              style: TextStyle(fontSize: 12, color: AppTheme.mutedText),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isProcessing = false;
              });
              _controller?.start();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _analyzeAndNavigateUrl(url);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('Analyze URL'),
          ),
        ],
      ),
    );
  }

  void _showPayloadDialog(QrPayload payload) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Icon(
              payload.type == QrPayloadType.unsupportedScheme ? Icons.code_off : Icons.info_outline,
              color: payload.type == QrPayloadType.unsupportedScheme ? AppTheme.red : AppTheme.amber,
              size: 24,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                payload.label,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              payload.description,
              style: const TextStyle(fontSize: 13, color: AppTheme.mutedText, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.grayBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.grayBorder),
              ),
              child: SelectableText(
                payload.rawContent,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.navyText),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isProcessing = false;
              });
              _controller?.start();
            },
            child: const Text('Scan Another'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Return home
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _analyzeAndNavigateUrl(String url) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppTheme.primary),
                SizedBox(height: 16),
                Text('Analyzing QR URL...', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final result = await UrlAnalysisService.analyzeUrl(url);
      ScanHistoryService.instance.recordScan(rawInput: url, result: result, source: 'QR Scanner');

      if (!mounted) return;
      Navigator.pop(context); // Pop loading dialog

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ScanResultScreen(
            result: result,
            scannedInput: url,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      setState(() {
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error analyzing QR URL: $e'),
          backgroundColor: AppTheme.red,
        ),
      );
      _controller?.start();
    }
  }

  Future<void> _pickAndScanImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image == null) return; // Cancelled

      final BarcodeCapture? capture = await _controller?.analyzeImage(image.path);

      if (capture == null || capture.barcodes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No QR code found in the selected image. Please try another image.'),
            backgroundColor: AppTheme.amber,
          ),
        );
        return;
      }

      if (capture.barcodes.length == 1) {
        final val = capture.barcodes.first.rawValue;
        if (val != null && val.isNotEmpty) {
          _processPayload(val);
        } else {
          _showDecodingError();
        }
      } else {
        _showMultipleQrSelectionDialog(capture.barcodes);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to read QR from image: $e'),
          backgroundColor: AppTheme.red,
        ),
      );
    }
  }

  void _showDecodingError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not decode valid text from the QR code image.'),
        backgroundColor: AppTheme.red,
      ),
    );
  }

  void _showMultipleQrSelectionDialog(List<Barcode> barcodes) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Multiple QR Codes Found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: barcodes.length,
            itemBuilder: (context, index) {
              final bc = barcodes[index];
              final text = bc.rawValue ?? 'Unknown QR code';
              return ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppTheme.primaryLight,
                  child: Icon(Icons.qr_code, color: AppTheme.primary, size: 18),
                ),
                title: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                onTap: () {
                  Navigator.pop(context);
                  _processPayload(text);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navyText,
      appBar: AppBar(
        title: const Text('QR Code Scanner', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_hasPermission && _controller != null)
            IconButton(
              icon: Icon(_torchEnabled ? Icons.flash_on : Icons.flash_off, color: Colors.white),
              onPressed: () async {
                await _controller?.toggleTorch();
                setState(() {
                  _torchEnabled = !_torchEnabled;
                });
              },
              tooltip: 'Toggle Flashlight',
            ),
        ],
      ),
      body: _isLoadingPermission
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : !_hasPermission
              ? _buildPermissionDeniedView()
              : Stack(
                  children: [
                    MobileScanner(
                      controller: _controller!,
                      onDetect: _onDetect,
                    ),
                    _buildScannerOverlay(),
                    Positioned(
                      bottom: 30,
                      left: 20,
                      right: 20,
                      child: ElevatedButton.icon(
                        onPressed: _pickAndScanImage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.navyText,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.photo_library_outlined, color: AppTheme.primary),
                        label: const Text('Upload QR Image from Gallery', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildScannerOverlay() {
    return IgnorePointer(
      child: Stack(
        children: [
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.green, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            top: 60,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Align the QR code within the frame to scan automatically.\nPhishing URLs will be verified securely.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionDeniedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt_outlined, size: 64, color: Colors.white70),
            const SizedBox(height: 16),
            const Text(
              'Camera Permission Required',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'DigiLens needs camera access to scan QR codes on product labels, posters, or menus. You can also upload a QR image from your gallery if you prefer.',
              style: TextStyle(fontSize: 13, color: Colors.white70, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _checkAndRequestCameraPermission,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Grant Permission', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => openAppSettings(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.settings),
              label: const Text('Open App Settings'),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: _pickAndScanImage,
              icon: const Icon(Icons.photo_library, color: AppTheme.green),
              label: const Text('Upload QR Image Instead', style: TextStyle(color: AppTheme.green, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
