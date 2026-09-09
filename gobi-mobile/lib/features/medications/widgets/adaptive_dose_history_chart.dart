import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/local/app_database.dart';
import '../../../data/repositories/medications_repository.dart';

enum DayBucketStatus {
  full,
  partial,
  missed,
  pendingToday,
  future,
  empty,
}

class DayAdherenceBucket {
  final DateTime date;
  final int dayIndex; // 0-based day of course
  final int totalScheduled;
  final int takenDoses;
  final int missedDoses;
  final bool isToday;
  final bool isPast;
  final bool isFuture;
  final DayBucketStatus status;
  final List<DoseLogEntry> doses;

  DayAdherenceBucket({
    required this.date,
    required this.dayIndex,
    required this.totalScheduled,
    required this.takenDoses,
    required this.missedDoses,
    required this.isToday,
    required this.isPast,
    required this.isFuture,
    required this.status,
    required this.doses,
  });
}

class AdaptiveDoseHistoryChart extends StatefulWidget {
  final String medicationId;
  final MedicationsRepository repository;
  final List<DoseLogEntry>? initialDoses;

  const AdaptiveDoseHistoryChart({
    super.key,
    required this.medicationId,
    required this.repository,
    this.initialDoses,
  });

  @override
  State<AdaptiveDoseHistoryChart> createState() => _AdaptiveDoseHistoryChartState();
}

class _AdaptiveDoseHistoryChartState extends State<AdaptiveDoseHistoryChart> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToToday(int todayIndex, int totalDays) {
    if (!_scrollController.hasClients) return;
    // Each item is ~22px wide (14px bar + 8px margin)
    const itemWidth = 22.0;
    final targetOffset = (todayIndex * itemWidth) - 100.0;
    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  void _showDayTooltip(BuildContext context, DayAdherenceBucket bucket) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dateStr = '${months[bucket.date.month - 1]} ${bucket.date.day}';
    final dayTitle = bucket.isToday ? '$dateStr (Today - Day ${bucket.dayIndex + 1})' : '$dateStr (Day ${bucket.dayIndex + 1})';

    String detail;
    if (bucket.totalScheduled == 0) {
      detail = 'No doses scheduled for this day';
    } else if (bucket.status == DayBucketStatus.full) {
      detail = '✓ ${bucket.takenDoses}/${bucket.totalScheduled} doses taken on time';
    } else if (bucket.status == DayBucketStatus.partial) {
      detail = '⚠ ${bucket.takenDoses}/${bucket.totalScheduled} doses taken (${bucket.totalScheduled - bucket.takenDoses} missed)';
    } else if (bucket.status == DayBucketStatus.missed) {
      detail = '✕ ${bucket.totalScheduled} doses missed';
    } else if (bucket.status == DayBucketStatus.pendingToday) {
      detail = '○ ${bucket.takenDoses}/${bucket.totalScheduled} taken (${bucket.totalScheduled - bucket.takenDoses} remaining today)';
    } else {
      detail = '${bucket.totalScheduled} upcoming doses scheduled';
    }

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$dayTitle: $detail'),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DoseLogEntry>>(
      stream: widget.repository.watchAllDosesForMedication(widget.medicationId),
      initialData: widget.initialDoses,
      builder: (context, snapshot) {
        final doses = snapshot.data ?? [];
        if (doses.isEmpty) {
          return const SizedBox.shrink();
        }

        final now = DateTime.now();
        final todayMidnight = DateTime(now.year, now.month, now.day);

        // Group doses by date
        final Map<DateTime, List<DoseLogEntry>> grouped = {};
        DateTime minDate = DateTime(doses.first.scheduledTime.year, doses.first.scheduledTime.month, doses.first.scheduledTime.day);
        DateTime maxDate = minDate;

        for (final dose in doses) {
          final d = DateTime(dose.scheduledTime.year, dose.scheduledTime.month, dose.scheduledTime.day);
          grouped.putIfAbsent(d, () => []).add(dose);
          if (d.isBefore(minDate)) minDate = d;
          if (d.isAfter(maxDate)) maxDate = d;
        }

        final totalDays = maxDate.difference(minDate).inDays + 1;
        int todayIndex = todayMidnight.difference(minDate).inDays;
        todayIndex = todayIndex.clamp(0, totalDays - 1);

        final List<DayAdherenceBucket> buckets = [];
        int totalExpectedDoses = 0;
        int totalTakenDoses = 0;

        for (int i = 0; i < totalDays; i++) {
          final dayDate = minDate.add(Duration(days: i));
          final dayDoses = grouped[dayDate] ?? [];
          final isToday = dayDate == todayMidnight;
          final isPast = dayDate.isBefore(todayMidnight);
          final isFuture = dayDate.isAfter(todayMidnight);

          final takenCount = dayDoses.where((d) => d.status == 'taken').length;
          final totalCount = dayDoses.length;
          final missedCount = isPast ? (totalCount - takenCount) : 0;

          if (isPast || isToday) {
            totalExpectedDoses += totalCount;
            totalTakenDoses += takenCount;
          }

          DayBucketStatus status;
          if (totalCount == 0) {
            status = DayBucketStatus.empty;
          } else if (isToday) {
            if (takenCount == totalCount) {
              status = DayBucketStatus.full;
            } else if (takenCount > 0) {
              status = DayBucketStatus.partial;
            } else {
              status = DayBucketStatus.pendingToday;
            }
          } else if (isPast) {
            if (takenCount == totalCount) {
              status = DayBucketStatus.full;
            } else if (takenCount > 0) {
              status = DayBucketStatus.partial;
            } else {
              status = DayBucketStatus.missed;
            }
          } else {
            status = DayBucketStatus.future;
          }

          buckets.add(DayAdherenceBucket(
            date: dayDate,
            dayIndex: i,
            totalScheduled: totalCount,
            takenDoses: takenCount,
            missedDoses: missedCount,
            isToday: isToday,
            isPast: isPast,
            isFuture: isFuture,
            status: status,
            doses: dayDoses,
          ));
        }

        final adherencePct = totalExpectedDoses > 0 ? ((totalTakenDoses / totalExpectedDoses) * 100).round() : 100;
        final currentDayNumber = (todayMidnight.difference(minDate).inDays + 1).clamp(1, totalDays);

        // Schedule auto scroll for Tier 2
        if (totalDays > 14 && totalDays <= 60) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToToday(todayIndex, totalDays);
          });
        }

        return Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Metric Strip ─────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    totalDays <= 14
                        ? 'Day $currentDayNumber of $totalDays • $totalTakenDoses/$totalExpectedDoses Taken'
                        : totalDays <= 60
                            ? 'Week ${(currentDayNumber / 7).ceil()} of ${(totalDays / 7).ceil()} (Day $currentDayNumber/$totalDays)'
                            : 'Month ${(currentDayNumber / 30).ceil()} of ${(totalDays / 30).ceil()} • Day $currentDayNumber/$totalDays',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: adherencePct >= 85
                          ? AppColors.primary.withOpacity(0.12)
                          : adherencePct >= 70
                              ? AppColors.warning.withOpacity(0.15)
                              : AppColors.error.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$adherencePct% Adherence',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: adherencePct >= 85
                            ? AppColors.primaryDark
                            : adherencePct >= 70
                                ? const Color(0xFFE65100)
                                : AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // ── Adaptive Chart Canvas (3 Tiers) ─────────────────────
              if (totalDays <= 14)
                _buildTier1AcutePills(context, buckets)
              else if (totalDays <= 60)
                _buildTier2ScrollableRibbon(context, buckets)
              else
                _buildTier3DualTrack(context, buckets, totalDays, currentDayNumber),
            ],
          ),
        );
      },
    );
  }

  // ── Tier 1: Acute Short Courses (≤ 14 Days) ──────────────────────────
  Widget _buildTier1AcutePills(BuildContext context, List<DayAdherenceBucket> buckets) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: buckets.map((bucket) {
        return Expanded(
          child: InkWell(
            onTap: () => _showDayTooltip(context, bucket),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: Column(
                children: [
                  Container(
                    height: 32,
                    decoration: BoxDecoration(
                      color: _getBucketFillColor(bucket.status),
                      borderRadius: BorderRadius.circular(8),
                      border: bucket.isToday
                          ? Border.all(color: AppColors.primary, width: 2)
                          : Border.all(color: _getBucketBorderColor(bucket.status)),
                    ),
                    alignment: Alignment.center,
                    child: _getBucketIcon(bucket.status),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    bucket.isToday ? 'Today' : 'D${bucket.dayIndex + 1}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: bucket.isToday ? FontWeight.bold : FontWeight.w500,
                      color: bucket.isToday ? AppColors.primary : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Tier 2: Medium Courses (15–60 Days / 3–8 Weeks) ───────────────────
  Widget _buildTier2ScrollableRibbon(BuildContext context, List<DayAdherenceBucket> buckets) {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: buckets.length,
        itemBuilder: (context, index) {
          final bucket = buckets[index];
          final isWeekStart = index % 7 == 0;
          final weekNum = (index ~/ 7) + 1;

          return InkWell(
            onTap: () => _showDayTooltip(context, bucket),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3.5),
              child: Column(
                children: [
                  if (isWeekStart)
                    Text(
                      'W$weekNum',
                      style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                    )
                  else
                    const SizedBox(height: 11),
                  const SizedBox(height: 2),
                  Container(
                    width: 14,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _getBucketFillColor(bucket.status),
                      borderRadius: BorderRadius.circular(4),
                      border: bucket.isToday
                          ? Border.all(color: AppColors.primary, width: 2)
                          : Border.all(color: _getBucketBorderColor(bucket.status)),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    bucket.isToday ? '●' : '${bucket.dayIndex + 1}',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: bucket.isToday ? FontWeight.bold : FontWeight.normal,
                      color: bucket.isToday ? AppColors.primary : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Tier 3: Long & Chronic Courses (60–365 Days) ──────────────────────
  Widget _buildTier3DualTrack(
    BuildContext context,
    List<DayAdherenceBucket> buckets,
    int totalDays,
    int currentDay,
  ) {
    // Focus window: last 14 days up to today
    final recentBuckets = buckets.where((b) => b.isPast || b.isToday).toList();
    final focusList = recentBuckets.length > 14
        ? recentBuckets.sublist(recentBuckets.length - 14)
        : recentBuckets;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Track: 14-Day Recent Focus Strip
        Row(
          children: [
            Text(
              'Recent 14 Days:',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
            ),
            const Spacer(),
            Text(
              'Tap bar for details',
              style: TextStyle(fontSize: 9.5, color: Colors.grey.shade400),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: focusList.map((bucket) {
            return Expanded(
              child: InkWell(
                onTap: () => _showDayTooltip(context, bucket),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: Container(
                    height: 18,
                    decoration: BoxDecoration(
                      color: _getBucketFillColor(bucket.status),
                      borderRadius: BorderRadius.circular(3),
                      border: bucket.isToday
                          ? Border.all(color: AppColors.primary, width: 1.5)
                          : Border.all(color: _getBucketBorderColor(bucket.status)),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),

        // Bottom Track: Full Course Progress Ribbon
        Row(
          children: [
            Text(
              'Full Course Progress ($currentDay / $totalDays days):',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Row(
            children: buckets.map((bucket) {
              return Expanded(
                child: Container(
                  height: 6,
                  color: bucket.status == DayBucketStatus.full
                      ? AppColors.primary
                      : bucket.status == DayBucketStatus.partial
                          ? AppColors.warning
                          : bucket.status == DayBucketStatus.missed
                              ? AppColors.error.withOpacity(0.7)
                              : bucket.status == DayBucketStatus.pendingToday
                                  ? AppColors.primary.withOpacity(0.3)
                                  : Colors.grey.shade300,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Color _getBucketFillColor(DayBucketStatus status) {
    switch (status) {
      case DayBucketStatus.full:
        return AppColors.primary;
      case DayBucketStatus.partial:
        return AppColors.warning;
      case DayBucketStatus.missed:
        return AppColors.error.withOpacity(0.8);
      case DayBucketStatus.pendingToday:
        return AppColors.primary.withOpacity(0.12);
      case DayBucketStatus.future:
        return Colors.grey.shade200;
      case DayBucketStatus.empty:
        return Colors.grey.shade100;
    }
  }

  Color _getBucketBorderColor(DayBucketStatus status) {
    switch (status) {
      case DayBucketStatus.full:
        return AppColors.primaryDark;
      case DayBucketStatus.partial:
        return const Color(0xFFE65100);
      case DayBucketStatus.missed:
        return AppColors.error;
      case DayBucketStatus.pendingToday:
        return AppColors.primary;
      case DayBucketStatus.future:
        return Colors.grey.shade300;
      case DayBucketStatus.empty:
        return Colors.grey.shade200;
    }
  }

  Widget _getBucketIcon(DayBucketStatus status) {
    switch (status) {
      case DayBucketStatus.full:
        return const Icon(Icons.check, size: 14, color: Colors.white);
      case DayBucketStatus.partial:
        return const Icon(Icons.priority_high, size: 13, color: Colors.white);
      case DayBucketStatus.missed:
        return const Icon(Icons.close, size: 13, color: Colors.white);
      case DayBucketStatus.pendingToday:
        return const Icon(Icons.circle_outlined, size: 12, color: AppColors.primary);
      case DayBucketStatus.future:
        return Text('·', style: TextStyle(fontSize: 16, color: Colors.grey.shade400));
      case DayBucketStatus.empty:
        return const SizedBox.shrink();
    }
  }
}
