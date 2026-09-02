import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/app_providers.dart';
import '../../../data/local/app_database.dart';

class MedicationsScreen extends ConsumerStatefulWidget {
  const MedicationsScreen({super.key});

  @override
  ConsumerState<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends ConsumerState<MedicationsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddScheduleDialog(BuildContext context) {
    final nameController = TextEditingController(text: 'Vitamin D');
    final dosageController = TextEditingController(text: '1');
    final weeksController = TextEditingController(text: '6');
    String frequency = 'weekly';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Set Medication Schedule',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Medication Name',
                  hintText: 'e.g. Vitamin D',
                  prefixIcon: Icon(Icons.medication),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: dosageController,
                      decoration: const InputDecoration(
                        labelText: 'Dosage',
                        hintText: 'e.g. 1 dose or 60k IU',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: frequency,
                      decoration: const InputDecoration(labelText: 'Frequency'),
                      items: const [
                        DropdownMenuItem(value: 'weekly', child: Text('Once Weekly')),
                        DropdownMenuItem(value: 'daily', child: Text('Daily')),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => frequency = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: weeksController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Duration (Weeks)',
                  hintText: 'e.g. 6',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Save Schedule'),
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;
                    final weeks = int.tryParse(weeksController.text) ?? 6;
                    final dosage = dosageController.text.trim().isEmpty ? '1' : dosageController.text.trim();

                    final repo = ref.read(medicationRepositoryProvider);
                    final result = await repo.setSchedule(
                      name: name,
                      frequencyType: frequency,
                      durationWeeks: weeks,
                      dosage: dosage,
                    );

                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(result.summaryMessage),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final medicationsAsync = ref.watch(activeMedicationsProvider);
    final todayDosesAsync = ref.watch(todayDosesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medications & Routines'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.today), text: 'Today / Due'),
            Tab(icon: Icon(Icons.medication_liquid), text: 'All Schedules'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: Today / Due Doses
          todayDosesAsync.when(
            data: (doses) {
              if (doses.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 80, color: AppColors.primary.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text(
                          'No doses pending today!',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You can schedule a new medication with Gemini voice or the button below.',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: doses.length,
                itemBuilder: (context, index) {
                  final dose = doses[index];
                  final isTaken = dose.status == 'taken';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isTaken ? AppColors.success.withOpacity(0.2) : AppColors.primary.withOpacity(0.2),
                        child: Icon(
                          isTaken ? Icons.check : Icons.access_time,
                          color: isTaken ? AppColors.success : AppColors.primary,
                        ),
                      ),
                      title: Text(
                        'Dose #${index + 1}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Scheduled: ${DateFormat('EEE, MMM d, yyyy').format(dose.scheduledTime.toLocal())}\nStatus: ${dose.status.toUpperCase()}',
                      ),
                      trailing: isTaken
                          ? const Chip(
                              label: Text('Taken', style: TextStyle(color: Colors.white, fontSize: 12)),
                              backgroundColor: AppColors.success,
                            )
                          : ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              onPressed: () async {
                                final repo = ref.read(medicationRepositoryProvider);
                                await repo.recordDose(
                                  name: 'Vitamin D', // will match medication
                                  status: 'taken',
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Dose recorded as TAKEN!')),
                                  );
                                }
                              },
                              child: const Text('Take Dose', style: TextStyle(color: Colors.white)),
                            ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err')),
          ),

          // TAB 2: All Active Schedules
          medicationsAsync.when(
            data: (meds) {
              if (meds.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.medication, size: 80, color: AppColors.primary.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text(
                          'No Active Medications',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Try: "Hey Gemini, I need to take Vitamin D once every week for the next 6 weeks"',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: meds.length,
                itemBuilder: (context, index) {
                  final med = meds[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                med.name,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Chip(
                                label: Text('${med.inventoryCount} ${med.unit}s left'),
                                backgroundColor: med.inventoryCount <= med.refillThreshold
                                    ? AppColors.warning.withOpacity(0.2)
                                    : AppColors.primary.withOpacity(0.1),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('Frequency: ${med.frequencyType.toUpperCase()} (${med.dosage} ${med.unit})'),
                          if (med.instructions != null && med.instructions!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Note: ${med.instructions}',
                                style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
                              ),
                            ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                icon: const Icon(Icons.info_outline, size: 18),
                                label: const Text('Check Schedule'),
                                onPressed: () async {
                                  final repo = ref.read(medicationRepositoryProvider);
                                  final status = await repo.getScheduleStatus(name: med.name);
                                  if (context.mounted) {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: Text('${med.name} Status'),
                                        content: Text(status['message'] as String),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx),
                                            child: const Text('OK'),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err')),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Set Schedule'),
        onPressed: () => _showAddScheduleDialog(context),
      ),
    );
  }
}
