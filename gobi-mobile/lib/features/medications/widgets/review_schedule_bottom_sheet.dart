import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../data/repositories/medications_repository.dart';

class ReviewScheduleBottomSheet extends StatefulWidget {
  final ApiService? apiService;
  final MedicationsRepository? repository;
  final String? initialName;
  final String? initialDosage;
  final String? initialFrequency;
  final List<String>? initialTimes;
  final int? initialDurationWeeks;
  final String? initialInstructions;
  final int? dependentId;
  final VoidCallback? onSaved;

  const ReviewScheduleBottomSheet({
    super.key,
    this.apiService,
    this.repository,
    this.initialName,
    this.initialDosage,
    this.initialFrequency,
    this.initialTimes,
    this.initialDurationWeeks,
    this.initialInstructions,
    this.dependentId,
    this.onSaved,
  });

  static Future<void> show({
    required BuildContext context,
    ApiService? apiService,
    MedicationsRepository? repository,
    String? initialName,
    String? initialDosage,
    String? initialFrequency,
    List<String>? initialTimes,
    int? initialDurationWeeks,
    String? initialInstructions,
    int? dependentId,
    VoidCallback? onSaved,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ReviewScheduleBottomSheet(
          apiService: apiService,
          repository: repository,
          initialName: initialName,
          initialDosage: initialDosage,
          initialFrequency: initialFrequency,
          initialTimes: initialTimes,
          initialDurationWeeks: initialDurationWeeks,
          initialInstructions: initialInstructions,
          dependentId: dependentId,
          onSaved: onSaved,
        ),
      ),
    );
  }


  @override
  State<ReviewScheduleBottomSheet> createState() => _ReviewScheduleBottomSheetState();
}

class _ReviewScheduleBottomSheetState extends State<ReviewScheduleBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _dosageController;
  late final TextEditingController _frequencyController;
  late final TextEditingController _durationController;
  late final TextEditingController _instructionsController;
  late List<String> _times;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _dosageController = TextEditingController(text: widget.initialDosage ?? '1 dose');
    _frequencyController = TextEditingController(text: widget.initialFrequency ?? 'daily');
    _durationController = TextEditingController(
      text: (widget.initialDurationWeeks ?? 1).toString(),
    );
    _instructionsController = TextEditingController(text: widget.initialInstructions ?? '');
    _times = widget.initialTimes != null && widget.initialTimes!.isNotEmpty
        ? List.from(widget.initialTimes!)
        : ['08:00'];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _frequencyController.dispose();
    _durationController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  void _addTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );
    if (pickedTime != null) {
      final formatted =
          '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}';
      if (!_times.contains(formatted)) {
        setState(() {
          _times.add(formatted);
          _times.sort();
        });
      }
    }
  }

  void _removeTime(String time) {
    if (_times.length > 1) {
      setState(() {
        _times.remove(time);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one dose time is required.')),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final payload = {
        'name': _nameController.text.trim(),
        'dosage': _dosageController.text.trim(),
        'frequency': _frequencyController.text.trim(),
        'times': _times.join(', '),
        'duration_weeks': int.tryParse(_durationController.text.trim()) ?? 1,
        'instructions': _instructionsController.text.trim().isEmpty
            ? null
            : _instructionsController.text.trim(),
        if (widget.dependentId != null) 'dependent_id': widget.dependentId,
      };

      if (widget.repository != null) {
        await widget.repository!.addMedication(payload);
      } else if (widget.apiService != null) {
        await widget.apiService!.createMedication(payload);
      }


      if (mounted) {
        Navigator.of(context).pop();
        widget.onSaved?.call();
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Scheduled ${_nameController.text.trim()} successfully!'),
                ),
              ],
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
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            content: Text('Failed to save schedule: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
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
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Review Medication Schedule',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          'AI-extracted details. Edit anything before confirming.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Medication Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Medication Name *',
                  prefixIcon: Icon(Icons.medication),
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 14),

              // Dosage and Frequency in a Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _dosageController,
                      decoration: const InputDecoration(
                        labelText: 'Dosage (e.g. 500mg)',
                        prefixIcon: Icon(Icons.fitness_center),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _frequencyController,
                      decoration: const InputDecoration(
                        labelText: 'Frequency (e.g. daily)',
                        prefixIcon: Icon(Icons.repeat),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Duration Weeks
              TextFormField(
                controller: _durationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Duration (weeks)',
                  prefixIcon: Icon(Icons.calendar_month),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Scheduled Times Section
              Text(
                'Dose Times',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._times.map(
                    (t) => Chip(
                      avatar: const Icon(Icons.access_time, size: 16),
                      label: Text(t),
                      onDeleted: () => _removeTime(t),
                      backgroundColor: AppColors.primary.withOpacity(0.08),
                    ),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 16, color: AppColors.primary),
                    label: const Text('Add Time', style: TextStyle(color: AppColors.primary)),
                    onPressed: _addTime,
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Instructions
              TextFormField(
                controller: _instructionsController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Doctor Instructions / Notes',
                  prefixIcon: Icon(Icons.note_alt_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
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
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check),
                      label: Text(
                        _isSubmitting ? 'Saving...' : 'Confirm & Schedule',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
