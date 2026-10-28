import 'package:flutter/material.dart';
import 'package:digilens/theme/app_theme.dart';
import 'package:digilens/services/parental_control_service.dart';

/// Screen allowing parent to set up a new 6-digit PIN or change existing PIN.
class ParentalPinSetupScreen extends StatefulWidget {
  final bool isChangePin;

  const ParentalPinSetupScreen({
    super.key,
    this.isChangePin = false,
  });

  @override
  State<ParentalPinSetupScreen> createState() => _ParentalPinSetupScreenState();
}

class _ParentalPinSetupScreenState extends State<ParentalPinSetupScreen> {
  // Step 0: Enter current PIN (if isChangePin)
  // Step 1: Enter new PIN
  // Step 2: Confirm new PIN
  int _currentStep = 0;

  String _newPin = '';
  String _errorMessage = '';
  bool _isLoading = false;

  final List<TextEditingController> _controllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());

  @override
  void initState() {
    super.initState();
    _currentStep = widget.isChangePin ? 0 : 1;
  }

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

  void _clearInputs() {
    for (var c in _controllers) {
      c.clear();
    }
    if (mounted) {
      _focusNodes[0].requestFocus();
    }
  }

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        if (_enteredPin.length == 6) {
          _handleStepSubmit();
        }
      }
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _handleStepSubmit() async {
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

    if (_currentStep == 0) {
      // Step 0: Verify existing PIN
      final res = await ParentalControlService.instance.verifyPin(pin);
      if (!mounted) return;
      if (res == PinVerificationResult.success) {
        setState(() {
          _currentStep = 1;
          _isLoading = false;
        });
        _clearInputs();
      } else if (res == PinVerificationResult.lockedOut) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Too many attempts. Locked out for 30 seconds.';
        });
        _clearInputs();
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Current PIN is incorrect.';
        });
        _clearInputs();
      }
    } else if (_currentStep == 1) {
      // Step 1: Enter new PIN
      _newPin = pin;
      setState(() {
        _currentStep = 2;
        _isLoading = false;
      });
      _clearInputs();
    } else if (_currentStep == 2) {
      // Step 2: Confirm new PIN
      if (pin != _newPin) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'PINs do not match. Please try again.';
          _currentStep = 1; // restart setup
          _newPin = '';
        });
        _clearInputs();
        return;
      }

      // Save PIN
      final success = await ParentalControlService.instance.setPin(pin);
      if (!mounted) return;

      if (success) {
        await ParentalControlService.instance.recordActivity(
          eventType: 'pin_setup',
          details: widget.isChangePin ? 'Parental PIN updated' : 'Parental PIN created',
          status: 'approved',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isChangePin
                  ? 'PIN changed successfully.'
                  : 'PIN configured successfully.',
            ),
          ),
        );
        Navigator.pop(context, true);
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to securely store PIN. Please try again.';
        });
        _clearInputs();
      }
    }
  }

  String get _stepTitle {
    if (_currentStep == 0) return 'Verify Current PIN';
    if (_currentStep == 1) return widget.isChangePin ? 'Enter New PIN' : 'Create 6-Digit PIN';
    return 'Confirm New PIN';
  }

  String get _stepDescription {
    if (_currentStep == 0) return 'Enter your existing 6-digit parental PIN to continue.';
    if (_currentStep == 1) return 'Choose a 6-digit PIN that your child cannot easily guess.';
    return 'Re-enter the 6-digit PIN to confirm.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lavenderBackground,
      appBar: AppBar(
        title: Text(
          widget.isChangePin ? 'Change Parental PIN' : 'Setup Parental PIN',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.indigo.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield_outlined, color: AppTheme.indigo, size: 48),
              ),
              const SizedBox(height: 24),
              Text(
                _stepTitle,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.navyText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _stepDescription,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.mutedText,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 36),

              // PIN Input boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    width: 44,
                    height: 54,
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      obscureText: true,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.navyText,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: AppTheme.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.grayBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.grayBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.indigo, width: 2),
                        ),
                      ),
                      onChanged: (value) => _onDigitChanged(index, value),
                    ),
                  );
                }),
              ),

              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.redLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleStepSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.indigo,
                    foregroundColor: AppTheme.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _currentStep == 2 ? 'Save PIN' : 'Continue',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
