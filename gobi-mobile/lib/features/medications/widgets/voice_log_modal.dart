import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/voice_service.dart';
import 'review_schedule_bottom_sheet.dart';

class VoiceLogModal extends StatefulWidget {
  final ApiService apiService;
  final int? dependentId;
  final VoidCallback? onScheduleCreated;
  final Function(String message, {VoidCallback? onUndo})? onDoseLogged;

  const VoiceLogModal({
    super.key,
    required this.apiService,
    this.dependentId,
    this.onScheduleCreated,
    this.onDoseLogged,
  });

  static Future<void> show({
    required BuildContext context,
    required ApiService apiService,
    int? dependentId,
    VoidCallback? onScheduleCreated,
    Function(String message, {VoidCallback? onUndo})? onDoseLogged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: VoiceLogModal(
          apiService: apiService,
          dependentId: dependentId,
          onScheduleCreated: onScheduleCreated,
          onDoseLogged: onDoseLogged,
        ),
      ),
    );
  }

  @override
  State<VoiceLogModal> createState() => _VoiceLogModalState();
}

class _VoiceLogModalState extends State<VoiceLogModal> {
  final VoiceService _voiceService = VoiceService();
  final TextEditingController _textController = TextEditingController();
  bool _isListening = false;
  bool _isAnalyzing = false;
  String _statusMessage = 'Tap the microphone and speak your medication command.';

  @override
  void initState() {
    super.initState();
    _initVoice();
  }

  Future<void> _initVoice() async {
    final available = await _voiceService.initialize();
    if (!available && mounted) {
      setState(() {
        _statusMessage = 'Speech recognition not available. You can type your command below.';
      });
    }
  }

  @override
  void dispose() {
    _voiceService.stopListening();
    _textController.dispose();
    super.dispose();
  }

  void _toggleListening() async {
    if (_isListening) {
      await _voiceService.stopListening();
      setState(() {
        _isListening = false;
        _statusMessage = 'Voice input stopped. Review or tap Analyze.';
      });
    } else {
      setState(() {
        _isListening = true;
        _statusMessage = 'Listening... Speak naturally (e.g. "Take Metformin 500mg twice daily")';
      });

      await _voiceService.startListening(
        onResult: (words) {
          setState(() {
            _textController.text = words;
          });
        },
        onError: (err) {
          setState(() {
            _isListening = false;
            _statusMessage = 'Voice error: $err';
          });
        },
      );
    }
  }

  Future<void> _analyzeIntent() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please speak or type a command first.')),
      );
      return;
    }

    if (_isListening) {
      await _voiceService.stopListening();
      setState(() {
        _isListening = false;
      });
    }

    setState(() {
      _isAnalyzing = true;
      _statusMessage = 'Analyzing with OpenRouter AI...';
    });

    try {
      final res = await widget.apiService.parseVoiceIntent(
        text,
        dependentId: widget.dependentId,
      );

      if (!mounted) return;

      final action = res['action'] as String?;
      final params = res['parameters'] as Map<String, dynamic>? ?? {};

      if (action == 'set_schedule') {
        // Human-in-the-loop safeguard: Open ReviewScheduleBottomSheet
        final timesDynamic = params['times'] as List<dynamic>?;
        final times = timesDynamic?.map((e) => e.toString()).toList();

        Navigator.of(context).pop(); // Close voice modal
        
        ReviewScheduleBottomSheet.show(
          context: context,
          apiService: widget.apiService,
          initialName: params['name'] as String?,
          initialDosage: params['dosage'] as String?,
          initialFrequency: params['frequency'] as String?,
          initialTimes: times,
          initialDurationWeeks: params['duration_weeks'] as int?,
          initialInstructions: params['instructions'] as String?,
          dependentId: widget.dependentId,
          onSaved: widget.onScheduleCreated,
        );
      } else if (action == 'record_dose') {
        Navigator.of(context).pop();
        final medName = params['name'] ?? 'Medication';
        final status = params['status'] ?? 'taken';
        
        if (widget.onDoseLogged != null) {
          widget.onDoseLogged!(
            'Logged dose for $medName as $status',
            onUndo: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Undone dose for $medName'),
                  backgroundColor: AppColors.info,
                ),
              );
            },
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.success,
              content: Text('Logged dose for $medName ($status)'),
            ),
          );
        }
      } else {
        // get_schedule or general response
        final msg = res['message'] ?? 'Parsed command: $text';
        setState(() {
          _statusMessage = msg;
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _statusMessage = 'Error processing command: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Voice Medication Assistant',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              _statusMessage,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _isListening ? AppColors.primary : Colors.grey.shade600,
                    fontWeight: _isListening ? FontWeight.w600 : FontWeight.normal,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Pulsing Mic Button
            GestureDetector(
              onTap: _isAnalyzing ? null : _toggleListening,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: _isListening ? 88 : 72,
                height: _isListening ? 88 : 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isListening ? AppColors.error : AppColors.primary,
                  boxShadow: [
                    BoxShadow(
                      color: (_isListening ? AppColors.error : AppColors.primary).withOpacity(0.35),
                      blurRadius: _isListening ? 20 : 10,
                      spreadRadius: _isListening ? 6 : 2,
                    ),
                  ],
                ),
                child: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  color: Colors.white,
                  size: _isListening ? 40 : 32,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Text Input / Speech Preview Box
            TextField(
              controller: _textController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Or type a command, e.g.\n"Set Amoxicillin 500mg 3 times a day for 7 days"',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _isAnalyzing ? null : _analyzeIntent,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: _isAnalyzing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: Text(
                      _isAnalyzing ? 'Analyzing...' : 'Analyze with AI',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
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
