import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../widgets/review_schedule_bottom_sheet.dart';
import '../widgets/voice_log_modal.dart';

class MedicationsScreen extends StatefulWidget {
  final ApiService? apiService;
  final int? dependentId;

  const MedicationsScreen({
    super.key,
    this.apiService,
    this.dependentId,
  });

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  late final ApiService _apiService;
  final ImagePicker _imagePicker = ImagePicker();

  List<dynamic> _todayDoses = [];
  List<dynamic> _medications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _apiService.getTodayDoses(dependentId: widget.dependentId),
        _apiService.getMedications(dependentId: widget.dependentId),
      ]);

      if (mounted) {
        setState(() {
          _todayDoses = results[0];
          _medications = results[1];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _takeDose(Map<String, dynamic> dose) async {
    final doseId = dose['id'] as int;
    final medName = dose['medication_name'] ?? 'Medication';

    // Optimistic UI update
    setState(() {
      final idx = _todayDoses.indexWhere((d) => d['id'] == doseId);
      if (idx != -1) {
        _todayDoses[idx] = Map<String, dynamic>.from(_todayDoses[idx])..['status'] = 'taken';
      }
    });

    try {
      await _apiService.takeDose(doseId);

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Marked $medName as taken'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'UNDO',
              textColor: AppColors.warning,
              onPressed: () => _undoDose(doseId, medName),
            ),
          ),
        );
      }
    } catch (e) {
      _loadData(); // Revert on error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Failed to update dose: $e'),
          ),
        );
      }
    }
  }

  Future<void> _undoDose(int doseId, String medName) async {
    // Optimistic UI update
    setState(() {
      final idx = _todayDoses.indexWhere((d) => d['id'] == doseId);
      if (idx != -1) {
        _todayDoses[idx] = Map<String, dynamic>.from(_todayDoses[idx])..['status'] = 'pending';
      }
    });

    try {
      await _apiService.undoDose(doseId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.info,
            content: Text('Undone dose for $medName'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Failed to undo dose: $e'),
          ),
        );
      }
    }
  }

  Future<void> _scanPrescription() async {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Prescription Photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndProcessImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndProcessImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndProcessImage(ImageSource source) async {
    final picked = await _imagePicker.pickImage(source: source);
    if (picked == null) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Scanning prescription with OpenRouter Multimodal Vision...'),
          ],
        ),
        duration: Duration(seconds: 8),
      ),
    );

    try {
      final ocrResult = await _apiService.scanPrescription(
        picked.path,
        dependentId: widget.dependentId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();

      final meds = (ocrResult['medications'] as List<dynamic>?) ?? [];
      if (meds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No medications detected in prescription image.')),
        );
        return;
      }

      // Open review bottom sheet for first/each medication found
      final first = meds.first as Map<String, dynamic>;
      final timesDynamic = first['times'] as List<dynamic>?;
      final times = timesDynamic?.map((e) => e.toString()).toList();

      ReviewScheduleBottomSheet.show(
        context: context,
        apiService: _apiService,
        initialName: first['name'] as String?,
        initialDosage: first['dosage'] as String?,
        initialFrequency: first['frequency'] as String?,
        initialTimes: times,
        initialDurationWeeks: first['duration_weeks'] as int?,
        initialInstructions: first['instructions'] as String?,
        dependentId: widget.dependentId,
        onSaved: _loadData,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Prescription scan failed: $e'),
          ),
        );
      }
    }
  }

  void _openVoiceModal() {
    VoiceLogModal.show(
      context: context,
      apiService: _apiService,
      dependentId: widget.dependentId,
      onScheduleCreated: _loadData,
      onDoseLogged: (msg, {onUndo}) {
        if (!mounted) return;
        _loadData();
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            duration: const Duration(seconds: 5),
            action: onUndo != null
                ? SnackBarAction(
                    label: 'UNDO',
                    textColor: AppColors.warning,
                    onPressed: () {
                      onUndo();
                      if (mounted) _loadData();
                    },
                  )
                : null,
          ),
        );
      },
    );
  }

  void _openAddSchedule() {
    ReviewScheduleBottomSheet.show(
      context: context,
      apiService: _apiService,
      dependentId: widget.dependentId,
      onSaved: _loadData,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medications & Adherence'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // AI Quick Actions Bar
              _buildAiActionsBar(),
              const SizedBox(height: 24),

              // Today's Doses Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Today's Schedule",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    '${_todayDoses.where((d) => d['status'] == 'taken').length}/${_todayDoses.length} Taken',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildTodayDosesList(),

              const SizedBox(height: 28),

              // All Medications Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Active Medications',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  TextButton.icon(
                    onPressed: _openAddSchedule,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildMedicationsList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiActionsBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.08),
            AppColors.accent.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'AI Smart Entry',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _openVoiceModal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.mic, size: 20),
                  label: const Text('Voice Log', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _scanPrescription,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: const BorderSide(color: AppColors.primary),
                  ),
                  icon: const Icon(Icons.document_scanner, size: 20, color: AppColors.primary),
                  label: const Text(
                    'Scan Rx',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodayDosesList() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null && _todayDoses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Error: $_error', style: const TextStyle(color: AppColors.error)),
        ),
      );
    }

    if (_todayDoses.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.check_circle_outline, size: 48, color: Colors.grey),
                SizedBox(height: 8),
                Text('No doses scheduled for today!'),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: _todayDoses.map((dose) {
        final isTaken = dose['status'] == 'taken';
        final medName = dose['medication_name'] ?? 'Medication';
        final dosage = dose['dosage'] ?? '';
        final schedTimeStr = dose['scheduled_time'] as String?;
        String timeDisplay = 'Today';
        if (schedTimeStr != null) {
          try {
            final dt = DateTime.parse(schedTimeStr).toLocal();
            timeDisplay =
                '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
          } catch (_) {}
        }

        return Card(
          elevation: isTaken ? 0 : 2,
          color: isTaken ? Colors.grey.shade50 : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isTaken ? Colors.grey.shade200 : AppColors.primary.withOpacity(0.2),
            ),
          ),
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isTaken
                  ? AppColors.success.withOpacity(0.15)
                  : AppColors.primary.withOpacity(0.12),
              child: Icon(
                isTaken ? Icons.check : Icons.medication,
                color: isTaken ? AppColors.success : AppColors.primary,
              ),
            ),
            title: Text(
              medName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                decoration: isTaken ? TextDecoration.lineThrough : null,
                color: isTaken ? Colors.grey : Colors.black87,
              ),
            ),
            subtitle: Text('$dosage • $timeDisplay'),
            trailing: isTaken
                ? OutlinedButton(
                    onPressed: () => _undoDose(dose['id'], medName),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Undo', style: TextStyle(fontSize: 12)),
                  )
                : ElevatedButton(
                    onPressed: () => _takeDose(dose),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Take', style: TextStyle(fontSize: 12)),
                  ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMedicationsList() {
    if (_medications.isEmpty && !_isLoading) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Column(
              children: [
                const Icon(Icons.medical_services_outlined, size: 40, color: Colors.grey),
                const SizedBox(height: 8),
                const Text('No medications configured yet.'),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _openAddSchedule,
                  child: const Text('Add Your First Medication'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: _medications.map((med) {
        final name = med['name'] ?? '';
        final dosage = med['dosage'] ?? '';
        final freq = med['frequency'] ?? '';
        final times = med['times'] ?? '';
        final instructions = med['instructions'] as String?;

        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Chip(
                      label: Text(
                        freq,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      backgroundColor: AppColors.primary.withOpacity(0.08),
                      side: BorderSide.none,
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Dosage: $dosage   •   Times: $times', style: TextStyle(color: Colors.grey.shade700)),
                if (instructions != null && instructions.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.info_outline, size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          instructions,
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
