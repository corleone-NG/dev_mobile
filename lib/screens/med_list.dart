import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../models.dart';
import '../storage.dart';
import '../notifications.dart';

class MedListScreen extends StatefulWidget {
  const MedListScreen({super.key});

  @override
  State<MedListScreen> createState() => _MedListScreenState();
}

class _MedListScreenState extends State<MedListScreen> with WidgetsBindingObserver {
  final StorageService _storage = StorageService();
  List<Medication> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load();
    }
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }
    
    try {
      final items = await _storage.loadMedications();
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
        // Debug: afficher le nombre d'éléments chargés
        debugPrint('Liste chargée: ${items.length} médicament(s)');
      }
    } catch (e, stackTrace) {
      debugPrint('Erreur lors du chargement de la liste: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _loading = false;
          _items = []; // S'assurer que la liste est vide en cas d'erreur
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _delete(Medication med) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le médicament'),
        content: Text('Êtes-vous sûr de vouloir supprimer "${med.name}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      HapticFeedback.lightImpact();
      try {
        // Charger la liste actuelle depuis le stockage
        final currentItems = await _storage.loadMedications();
        final updated = currentItems.where((m) => m.id != med.id).toList();
        
        // Sauvegarder la liste mise à jour
        await _storage.saveMedications(updated);
        
        // Annuler les notifications (ne pas faire échouer la suppression si ça échoue)
        try {
          await NotificationsService.instance.cancelForMedication(med);
        } catch (e) {
          debugPrint('Erreur lors de l\'annulation des notifications (non bloquante): $e');
        }
        
        // Mettre à jour l'état local
        if (mounted) {
          setState(() {
            _items = updated;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${med.name} a été supprimé'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } catch (e) {
        debugPrint('Erreur lors de la suppression: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de la suppression: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
          // Recharger la liste en cas d'erreur
          _load();
        }
      }
    }
  }

  Future<void> _add() async {
    final result = await Navigator.of(context).pushNamed('/add');
    // Recharger la liste après retour de l'écran d'ajout
    // Utiliser un délai pour s'assurer que la navigation est terminée
    if (mounted) {
      await Future.delayed(const Duration(milliseconds: 300));
      await _load();
    }
  }

  Future<void> _openHistory() async {
    await Navigator.of(context).pushNamed('/history');
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.medication_outlined,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 24),
            Text(
              'Aucun médicament',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Appuyez sur le bouton + pour ajouter\nvotre premier médicament',
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

  Widget _buildMedicationCard(Medication med, int index) {
    final time = DateTime(0, 1, 1, med.time.hour, med.time.minute);
    final timeStr = DateFormat.Hm().format(time);
    final isMorning = med.time.hour < 12;
    final isAfternoon = med.time.hour >= 12 && med.time.hour < 18;

    Color badgeColor;
    IconData badgeIcon;
    if (isMorning) {
      badgeColor = Colors.orange.shade100;
      badgeIcon = Icons.wb_sunny_outlined;
    } else if (isAfternoon) {
      badgeColor = Colors.blue.shade100;
      badgeIcon = Icons.wb_twilight_outlined;
    } else {
      badgeColor = Colors.indigo.shade100;
      badgeIcon = Icons.nightlight_outlined;
    }

    return Card(
      elevation: 3,
      shadowColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: () {
          // Pourrait ouvrir les détails ou éditer
        },
        borderRadius: BorderRadius.circular(20),
        splashColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
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
                        badgeColor,
                        badgeColor.withValues(alpha: 0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: badgeColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.medication,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        med.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  badgeColor,
                                  badgeColor.withValues(alpha: 0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: badgeColor.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(badgeIcon, size: 16, color: Colors.white),
                                const SizedBox(width: 6),
                                Text(
                                  timeStr,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(context).colorScheme.secondary,
                                  Theme.of(context).colorScheme.secondary.withValues(alpha: 0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              med.dose,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                  onPressed: () => _delete(med),
                  tooltip: 'Supprimer',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }



  Widget _buildHeader() {
    if (_items.isEmpty) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Icon(
                Icons.medication_liquid,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                '${_items.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _items.length == 1 ? 'Médicament' : 'Médicaments',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Container(
            width: 1,
            height: 50,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          Column(
            children: [
              Icon(
                Icons.notifications_active,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                '${_items.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Rappels actifs',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'MediAlert',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primary.withValues(alpha: 0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              onPressed: _openHistory,
              icon: Stack(
                children: [
                  const Icon(Icons.history),
                  if (_items.isNotEmpty)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: const SizedBox(),
                      ),
                    ),
                ],
              ),
              tooltip: 'Historique',
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _buildHeader()),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: Duration(milliseconds: 300 + (index * 50)),
                            curve: Curves.easeOut,
                            builder: (context, value, child) {
                              return Transform.translate(
                                offset: Offset(0, 20 * (1 - value)),
                                child: Opacity(
                                  opacity: value,
                                  child: child,
                                ),
                              );
                            },
                            child: _buildMedicationCard(_items[index], index),
                          ),
                          childCount: _items.length,
                        ),
                      ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 80),
                      ),
                    ],
                  ),
                ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.tertiary,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: _add,
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.add_circle_outline, color: Colors.white),
          label: const Text(
            'Ajouter',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          tooltip: 'Ajouter un médicament',
        ),
      ),
    );
  }
}


