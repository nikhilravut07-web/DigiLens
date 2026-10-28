import 'package:flutter/material.dart';
import 'package:digilens/theme/app_theme.dart';
import 'package:digilens/services/parental_control_service.dart';

/// Modal dialog prompting the parent for their 6-digit PIN.
class ParentalPinModal extends StatefulWidget {
  final String title;
  final String subtitle;
  final bool isConfirmMode;

  const ParentalPinModal({
    super.key,
    this.title = 'Parental PIN Verification',
    this.subtitle = 'Enter your 6-digit parental control PIN to proceed.',
    this.isConfirmMode = false,
  });

  /// Show the PIN entry modal and return true if verified successfully.
  static Future<bool> show(
    BuildContext context, {
    String title = 'Parental PIN Verification',
    String subtitle = 'Enter your 6-digit parental control PIN to proceed.',
    bool isConfirmMode = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ParentalPinModal(
        title: title,
        subtitle: subtitle,
        isConfirmMode: isConfirmMode,
      ),
    );
    return result ?? false;
  }

  @override
  State<ParentalPinModal> createState() => _ParentalPinModalState();
}

class _ParentalPinModalState extends State<ParentalPinModal> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());

  String _errorMessage = '';
  bool _isLoading = false;

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _enteredPin => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        if (_enteredPin.length == 6) {
          _submitPin();
        }
      }
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _submitPin() async {
    final pin = _enteredPin;
    if (pin.length != 6) {
      setState(() {
        _errorMessage = 'Please enter all 6 digits.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      if (widget.isConfirmMode) {
        // In confirm mode, we just return the 6-digit PIN entered
        Navigator.pop(context, true);
        return;
      }

      final verification = await ParentalControlService.instance.verifyPin(pin);
      if (!mounted) return;

      switch (verification) {
        case PinVerificationResult.success:
          Navigator.pop(context, true);
          break;
        case PinVerificationResult.incorrect:
          setState(() {
            _isLoading = false;
            _errorMessage = 'Incorrect PIN. Please try again.';
            for (var c in _controllers) {
              c.clear();
            }
          });
          _focusNodes[0].requestFocus();
          break;
        case PinVerificationResult.lockedOut:
          setState(() {
            _isLoading = false;
            _errorMessage = 'Too many failed attempts. Locked out for 30 seconds.';
            for (var c in _controllers) {
              c.clear();
            }
          });
          break;
        case PinVerificationResult.noPinSet:
          setState(() {
            _isLoading = false;
            _errorMessage = 'No PIN configured. Please set up a PIN first.';
          });
          break;
      }
    } catch (_) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Verification error. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.indigo.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.lock_outline, color: AppTheme.indigo, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.subtitle,
              style: const TextStyle(fontSize: 13, color: AppTheme.mutedText, height: 1.4),
            ),
            const SizedBox(height: 24),
            // 6-digit PIN input boxes
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (index) {
                return SizedBox(
                  width: 42,
                  height: 50,
                  child: TextField(
                    controller: _controllers[index],
                    focusNode: _focusNodes[index],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    obscureText: true,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.navyText,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: AppTheme.lavenderBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.grayBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.grayBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.indigo, width: 2),
                      ),
                    ),
                    onChanged: (value) => _onDigitChanged(index, value),
                  ),
                );
              }),
            ),
            if (_errorMessage.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.redLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(fontSize: 12, color: AppTheme.red, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_isLoading) ...[
              const SizedBox(height: 20),
              const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.indigo),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel', style: TextStyle(color: AppTheme.mutedText)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitPin,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.indigo,
            foregroundColor: AppTheme.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Verify'),
        ),
      ],
    );
  }
}
