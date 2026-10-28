import 'package:flutter/material.dart';
import 'package:digilens/theme/app_theme.dart';
import 'package:digilens/services/voice_analysis_service.dart';
import 'package:digilens/services/scan_history_service.dart';
import 'package:digilens/screens/scan_result_screen.dart';
import 'package:digilens/screens/live_call_protection_screen.dart';

class VoiceAnalyzerScreen extends StatefulWidget {
  const VoiceAnalyzerScreen({super.key});

  @override
  State<VoiceAnalyzerScreen> createState() => _VoiceAnalyzerScreenState();
}

class _VoiceAnalyzerScreenState extends State<VoiceAnalyzerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _transcriptController = TextEditingController();
  bool _isLoading = false;
  final _voiceService = VoiceAnalysisService();

  @override
  void dispose() {
    _transcriptController.dispose();
    super.dispose();
  }

  Future<void> _analyzeTranscript() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final transcript = _transcriptController.text.trim();
      final result = await _voiceService.classifyTranscript(transcript);

      // Record to history
      ScanHistoryService.instance.recordScan(
        rawInput: transcript,
        result: result,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ScanResultScreen(result: result, scannedInput: transcript),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Voice analysis error: $e'),
          backgroundColor: AppTheme.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _loadSample(String sampleText) {
    setState(() {
      _transcriptController.text = sampleText;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.lavenderBackground,
      appBar: AppBar(
        title: const Text(
          'Voice Scam Analyzer',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Status Badge / Banner
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.record_voice_over_outlined,
                        color: Color(0xFFF59E0B),
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Transcript Scam Radar',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.navyText,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.amberLight,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: AppTheme.amber.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ),
                                child: const Text(
                                  'TEXT ANALYSIS',
                                  style: TextStyle(
                                    color: AppTheme.amber,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Analyze spoken or recorded call transcripts for digital arrest threats, coercion, and impersonation scripts.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.mutedText,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Live Call Protection Navigation Banner
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LiveCallProtectionScreen(),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.indigo.withValues(alpha: 0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.indigo.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.indigo.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.mic_external_on,
                          color: AppTheme.indigo,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Live Call Protection & Microphone Guard',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.navyText,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Request RECORD_AUDIO permission & run live audio guard',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.mutedText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: AppTheme.indigo,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Transcript Input Area
              Text(
                'Paste Call Conversation / Transcript',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              const Text(
                'Type or paste what the caller said to check for extortion patterns.',
                style: TextStyle(fontSize: 12, color: AppTheme.mutedText),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _transcriptController,
                maxLines: 5,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  hintText: 'e.g. "This is Officer Sharma from Cyber Crime. You are under digital arrest..."',
                  hintStyle: const TextStyle(
                    color: AppTheme.mutedText,
                    fontSize: 13,
                  ),
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
                    borderSide: const BorderSide(
                      color: AppTheme.indigo,
                      width: 1.5,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter or paste a call transcript';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Analyze Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _analyzeTranscript,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: AppTheme.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.security, size: 20),
                  label: Text(
                    _isLoading
                        ? 'Analyzing Call Script…'
                        : 'Analyze Transcript',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Sample Call Scenarios
              Text(
                'Try Sample Call Scenarios (DEMO)',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(
                      Icons.gavel,
                      size: 14,
                      color: Colors.red,
                    ),
                    label: const Text('Digital Arrest Extortion'),
                    onPressed: () => _loadSample(
                      'I am calling from CBI headquarters. An illegal parcel with drugs in your name was seized at customs. You are under digital arrest. Stay on video call, do not disconnect or inform your family, and transfer a security deposit to clear your name.',
                    ),
                  ),
                  ActionChip(
                    avatar: const Icon(
                      Icons.screen_share,
                      size: 14,
                      color: Colors.orange,
                    ),
                    label: const Text('AnyDesk Remote Support'),
                    onPressed: () => _loadSample(
                      'Hello sir, I am calling from bank technical support. Your account is compromised. Please install AnyDesk or QuickSupport immediately and share your 9-digit code so we can secure your funds.',
                    ),
                  ),
                  ActionChip(
                    avatar: const Icon(
                      Icons.check_circle,
                      size: 14,
                      color: Colors.green,
                    ),
                    label: const Text('Legitimate Bank Call'),
                    onPressed: () => _loadSample(
                      'Good afternoon, this is an automated courtesy reminder from your branch. Your monthly statement is now available on internet banking. We will never ask for your password or OTP.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Planned Future Capabilities (Honest Labelling)
              const Text(
                'Planned Capabilities (Under Research)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.navyText,
                ),
              ),
              const SizedBox(height: 10),

              _buildFeatureCard(
                context,
                icon: Icons.graphic_eq,
                title: 'Acoustic Deepfake & Voice Clone Detection',
                badge: 'PLANNED',
                description: 'Spectral waveform and jitter analysis to detect synthetic AI voices used in fake emergency family kidnapping scams.',
              ),
              const SizedBox(height: 10),

              _buildFeatureCard(
                context,
                icon: Icons.hub_outlined,
                title: 'On-Device Model Updates (Federated Learning)',
                badge: 'PLANNED',
                description: 'Decentralized model training that distributes fraud detection updates without transmitting your private call transcripts to any central server.',
              ),
              const SizedBox(height: 10),

              _buildFeatureCard(
                context,
                icon: Icons.mic_none,
                title: 'Real-time Live Call Audio Monitoring',
                badge: 'PLANNED',
                description: 'Direct cellular audio interception requires privileged Android telephony APIs and elevated OS permissions not enabled in this prototype.',
              ),
              const SizedBox(height: 24),

              // Awareness Note
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.grayBorder),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.security, size: 18, color: AppTheme.indigo),
                        SizedBox(width: 8),
                        Text(
                          'Indian Law Enforcement Fact',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.indigo,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      'No government agency or police department conducts "Digital Arrests" via WhatsApp video or phone calls. Legitimate officers never demand money transfers to verify your innocence. Dial 1930 immediately if targeted.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.navyLight,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String badge,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.grayBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.indigo.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: AppTheme.indigo),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.navyText,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.lavenderBackground,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.grayBorder),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.mutedText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.mutedText,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
