import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../storage.dart';
import '../models.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final StorageService _storage = StorageService();
  List<ReminderLogEntry> _entries = [];
  Map<String, Medication> _medications = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _storage.loadHistory();
    final medications = await _storage.loadMedications();
    final medMap = {for (var m in medications) m.id: m};
    
    if (mounted) {
      setState(() {
        _entries = list.reversed.toList();
        _medications = medMap;
        _loading = false;
      });
    }
  }

  String _getMedicationName(String medicationId) {
    return _medications[medicationId]?.name ?? 'Médicament inconnu';
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_outlined,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 24),
            Text(
              'Aucun rappel',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'L\'historique de vos rappels\napparaîtra ici',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade500,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(ReminderLogEntry entry, int index) {
    final med = _medications[entry.medicationId];
    final firedDate = entry.firedAt;
    final isToday = DateFormat('yyyy-MM-dd').format(firedDate) == DateFormat('yyyy-MM-dd').format(DateTime.now());
    final isYesterday = DateFormat('yyyy-MM-dd').format(firedDate) == 
        DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 1)));

    String dateLabel;
    if (isToday) {
      dateLabel = 'Aujourd\'hui';
    } else if (isYesterday) {
      dateLabel = 'Hier';
    } else {
      dateLabel = DateFormat('dd MMM yyyy').format(firedDate);
    }

    final timeStr = DateFormat('HH:mm').format(firedDate);
    final scheduledTime = DateFormat('HH:mm').format(entry.scheduledAt);

    final statusColor = entry.acknowledged ? Colors.green : Colors.orange;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: statusColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      statusColor.withValues(alpha: 0.2),
                      statusColor.withValues(alpha: 0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  entry.acknowledged ? Icons.check_circle : Icons.notifications_active,
                  color: statusColor,
                  size: 28,
                ),
              ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getMedicationName(entry.medicationId),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (med != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Dose: ${med.dose}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        '$dateLabel à $timeStr',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                      ),
                      if (scheduledTime != timeStr) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Prévu: $scheduledTime',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey.shade700,
                                  fontSize: 10,
                                ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (!entry.acknowledged)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'En attente',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                      ),
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
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Historique'),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _entries.length,
                    itemBuilder: (context, index) => _buildHistoryCard(_entries[index], index),
                  ),
                ),
    );
  }
}


