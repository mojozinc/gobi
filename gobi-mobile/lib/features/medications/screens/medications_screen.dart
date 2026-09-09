import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/api_service.dart';
import '../../../data/repositories/medications_repository.dart';
import '../widgets/review_schedule_bottom_sheet.dart';
import '../widgets/voice_log_modal.dart';

class MedicationsScreen extends ConsumerStatefulWidget {
  final ApiService? apiService;
  final MedicationsRepository? repository;
  final int? dependentId;

  const MedicationsScreen({
    super.key,
    this.apiService,
    this.repository,
    this.dependentId,
  });

  @override
  ConsumerState<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends ConsumerState<MedicationsScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  SyncStatus _syncStatus = SyncStatus.idle;
  Stream<List<Map<String, dynamic>>>? _todayDosesStream;
  Stream<List<Map<String, dynamic>>>? _medicationsStream;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncCloudData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initStreams();
  }

  @override
  void didUpdateWidget(MedicationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dependentId != widget.dependentId || oldWidget.repository != widget.repository) {
      _initStreams();
    }
  }

  void _initStreams() {
    final repo = _getRepository();
    final depIdStr = widget.dependentId?.toString();
    _todayDosesStream = repo.watchTodayDoses(dependentId: depIdStr);
    _medicationsStream = repo.watchMedications(dependentId: depIdStr);
  }

  MedicationsRepository _getRepository() {
    return widget.repository ?? ref.read(medicationsRepositoryProvider);
  }

  ApiService _getApiService() {
    return widget.apiService ?? _getRepository().apiService;
  }

  Future<void> _syncCloudData() async {
    if (!mounted) return;
    setState(() {
      _syncStatus = SyncStatus.syncing;
    });

    final repo = _getRepository();
    final success = await repo.syncWithCloud(
      dependentId: widget.dependentId?.toString(),
    );

    if (mounted) {
      setState(() {
        _syncStatus = success ? SyncStatus.synced : SyncStatus.offline;
      });
    }
  }

  Future<void> _takeDose(Map<String, dynamic> dose) async {
    final doseId = dose['id'];
    final medName = dose['medication_name'] ?? 'Medication';
    final repo = _getRepository();

    try {
      await repo.takeDose(doseId);

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Marked $medName as taken'),
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'UNDO',
              textColor: AppColors.warning,
              onPressed: () => _undoDose(doseId, medName),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            content: Text('Failed to update dose: $e'),
          ),
        );
      }
    }
  }

  Future<void> _undoDose(dynamic doseId, String medName) async {
    final repo = _getRepository();

    try {
      await repo.undoDose(doseId);
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.info,
            content: Text('Undone dose for $medName'),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
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
      final apiService = _getApiService();
      final ocrResult = await apiService.scanPrescription(
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

      final first = meds.first as Map<String, dynamic>;
      final timesDynamic = first['times'] as List<dynamic>?;
      final times = timesDynamic?.map((e) => e.toString()).toList();

      ReviewScheduleBottomSheet.show(
        context: context,
        apiService: apiService,
        repository: _getRepository(),
        initialName: first['name'] as String?,
        initialDosage: first['dosage'] as String?,
        initialFrequency: first['frequency'] as String?,
        initialTimes: times,
        initialDurationWeeks: first['duration_weeks'] as int?,
        initialInstructions: first['instructions'] as String?,
        dependentId: widget.dependentId,
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
      apiService: _getApiService(),
      repository: _getRepository(),
      dependentId: widget.dependentId,
      onDoseLogged: (msg, {onUndo}) {
        if (!mounted) return;
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
      apiService: _getApiService(),
      repository: _getRepository(),
      dependentId: widget.dependentId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = _getRepository();
    final depIdStr = widget.dependentId?.toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medications & Adherence'),
        actions: [
          // Cloud Sync Status Badge
          IconButton(
            tooltip: _syncStatus == SyncStatus.synced
                ? 'Cloud Synced'
                : _syncStatus == SyncStatus.syncing
                    ? 'Syncing with Cloud...'
                    : 'Offline Mode (Local Storage)',
            icon: _syncStatus == SyncStatus.syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(
                    _syncStatus == SyncStatus.synced
                        ? Icons.cloud_done
                        : Icons.cloud_off_outlined,
                    color: _syncStatus == SyncStatus.synced
                        ? AppColors.success
                        : Colors.white70,
                    size: 22,
                  ),
            onPressed: _syncCloudData,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _syncCloudData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _syncCloudData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // AI Quick Actions Bar
              _buildAiActionsBar(),
              const SizedBox(height: 24),

              // Today's Doses Section (Reactive Stream from Local SQLite)
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: _todayDosesStream ?? repo.watchTodayDoses(dependentId: depIdStr),
                builder: (context, snapshot) {
                  final todayDoses = snapshot.data ?? [];
                  final takenCount = todayDoses.where((d) => d['status'] == 'taken').length;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                            '$takenCount/${todayDoses.length} Taken',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTodayDosesList(todayDoses, snapshot.connectionState == ConnectionState.waiting),
                    ],
                  );
                },
              ),

              const SizedBox(height: 28),

              // All Medications Section (Reactive Stream from Local SQLite)
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: _medicationsStream ?? repo.watchMedications(dependentId: depIdStr),
                builder: (context, snapshot) {
                  final medications = snapshot.data ?? [];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      _buildMedicationsList(medications, snapshot.connectionState == ConnectionState.waiting),
                    ],
                  );
                },
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 64),
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

  Widget _buildTodayDosesList(List<Map<String, dynamic>> todayDoses, bool isInitialLoading) {
    if (isInitialLoading && todayDoses.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (todayDoses.isEmpty) {
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
      children: todayDoses.map((dose) {
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

  void _editMedication(Map<String, dynamic> med) {
    List<String>? timesList;
    final rawTimes = med['times_list'] ?? med['times'];
    if (rawTimes is List) {
      timesList = rawTimes.map((e) => e.toString()).toList();
    } else if (rawTimes is String && rawTimes.isNotEmpty) {
      timesList = rawTimes.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }

    ReviewScheduleBottomSheet.show(
      context: context,
      apiService: _getApiService(),
      repository: _getRepository(),
      medicationId: med['id']?.toString(),
      initialName: med['name'] as String?,
      initialDosage: med['dosage'] as String?,
      initialFrequency: med['frequency'] as String?,
      initialTimes: timesList,
      initialDurationWeeks: med['duration_weeks'] as int? ?? 1,
      initialInstructions: med['instructions'] as String?,
      dependentId: widget.dependentId,
    );
  }

  Future<void> _toggleMedicationPause(Map<String, dynamic> med) async {
    final medId = med['id']?.toString();
    final medName = med['name'] ?? 'Medication';
    if (medId == null) return;

    try {
      final repo = _getRepository();
      final isPaused = await repo.toggleMedicationPause(medId);
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: isPaused ? AppColors.warning : AppColors.success,
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                Icon(isPaused ? Icons.pause_circle_outline : Icons.play_circle_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isPaused
                        ? 'Paused schedule for $medName'
                        : 'Resumed schedule for $medName',
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Failed to update schedule status: $e'),
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteMedication(Map<String, dynamic> med) async {
    final medId = med['id']?.toString();
    final medName = med['name'] ?? 'Medication';
    if (medId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Medication Schedule'),
        content: Text('Are you sure you want to delete "$medName"? All future pending doses will also be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final repo = _getRepository();
        await repo.deleteMedication(medId);

        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.info,
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              content: Text('Deleted $medName schedule'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.error,
              content: Text('Failed to delete medication: $e'),
            ),
          );
        }
      }
    }
  }

  void _showMedicationActionSheet(Map<String, dynamic> med) {
    final medName = med['name'] ?? 'Medication';
    final dosage = med['dosage'] ?? '';
    final freq = med['frequency'] ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.12),
                  child: const Icon(Icons.medication, color: AppColors.primary),
                ),
                title: Text(
                  medName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
                subtitle: Text('$dosage • $freq'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: AppColors.primary),
                title: const Text('Edit Schedule', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Change dosage, times, or notes'),
                onTap: () {
                  Navigator.pop(ctx);
                  _editMedication(med);
                },
              ),
              ListTile(
                leading: const Icon(Icons.pause_circle_outline, color: AppColors.warning),
                title: const Text('Pause / Resume Schedule', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Temporarily hold or restore upcoming doses'),
                onTap: () {
                  Navigator.pop(ctx);
                  _toggleMedicationPause(med);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.error),
                title: const Text('Delete Schedule', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.error)),
                subtitle: const Text('Remove medication and future doses'),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteMedication(med);
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildMedicationsList(List<Map<String, dynamic>> medications, bool isInitialLoading) {
    if (medications.isEmpty && !isInitialLoading) {
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
      children: medications.map((med) {
        final name = med['name'] ?? '';
        final dosage = med['dosage'] ?? '';
        final freq = med['frequency'] ?? '';
        final times = med['times'] ?? '';
        final instructions = med['instructions'] as String?;

        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _showMedicationActionSheet(med),
            onLongPress: () => _showMedicationActionSheet(med),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
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
                      IconButton(
                        icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                        onPressed: () => _showMedicationActionSheet(med),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
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
          ),
        );
      }).toList(),
    );
  }
}
