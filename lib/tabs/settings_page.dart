import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../auth/auth_service.dart';
import '../theme_provider.dart';
import '../services/notifications_service.dart';
import 'preferences/preferences_service.dart';

// ── Companion data ─────────────────────────────────────────────────────────────

class _CompanionOption {
  final String emoji;
  final String defaultName;
  final String species;
  const _CompanionOption(this.emoji, this.defaultName, this.species);
}

const _kCompanions = [
  _CompanionOption('🦊', 'Ember', 'Fox'),
  _CompanionOption('🐱', 'Mochi', 'Cat'),
  _CompanionOption('🐶', 'Biscuit', 'Dog'),
  _CompanionOption('🐼', 'Panda', 'Panda'),
  _CompanionOption('🦋', 'Luna', 'Butterfly'),
  _CompanionOption('🐻', 'Cosmo', 'Bear'),
];

// ── Interests data ─────────────────────────────────────────────────────────────

const _kInterestOptions = {
  'food': [
    'Coffee',
    'Sushi',
    'Pizza',
    'Brunch',
    'Wine',
    'Ramen',
    'Tacos',
    'BBQ',
    'Desserts',
    'Cocktails',
  ],
  'outing': [
    'Hiking',
    'Concerts',
    'Museums',
    'Beach',
    'Camping',
    'Markets',
    'Galleries',
    'Parks',
    'Drives',
    'Picnics',
  ],
  'interests': [
    'Movies',
    'Gaming',
    'Books',
    'Fitness',
    'Cooking',
    'Travel',
    'Music',
    'Photography',
    'Yoga',
    'Gardening',
  ],
  'location': [
    'Indoors',
    'Outdoors',
    'Local',
    'Day trip',
    'Walkable',
    'City',
    'Nature',
    'Hidden gems',
  ],
};

// ─────────────────────────────────────────────────────────────────────────────

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // companion state
  String _companionEmoji = '🦊';
  String _companionName = 'Ember';
  bool _companionLoading = true;

  // partner state
  String _partnerEmail = '';
  DateTime? _anniversaryDate;

  final _prefsService = PreferencesService();

  @override
  void initState() {
    super.initState();
    _loadCompanion();
  }

  Future<void> _loadCompanion() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _companionLoading = false);
      return;
    }
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = doc.data() ?? {};
    setState(() {
      _companionEmoji = (data['companionEmoji'] as String?) ?? '🦊';
      _companionName = (data['companionName'] as String?) ?? 'Ember';
      _partnerEmail = (data['partnerEmail'] as String?) ?? '';
      final annivStr = data['anniversaryDate'] as String?;
      if (annivStr != null && annivStr.isNotEmpty) {
        _anniversaryDate = DateTime.tryParse(annivStr);
      }
      _companionLoading = false;
    });
  }

  Future<void> _showSupportDialog({
    required String title,
    required String message,
    String? actionLabel,
    Future<void> Function()? onAction,
  }) async {
    final cs = Theme.of(context).colorScheme;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          if (actionLabel != null && onAction != null)
            FilledButton(
              onPressed: () async {
                await onAction();
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
              },
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
              ),
              child: Text(actionLabel),
            ),
        ],
      ),
    );
  }

  Future<void> _showAboutSupport() async {
    await _showSupportDialog(
      title: 'About Closr',
      message:
          'Closr helps you and your partner keep track of suggestions, interests, and shared settings in one place.',
    );
  }

  Future<void> _showPrivacySupport() async {
    await _showSupportDialog(
      title: 'Privacy policy',
      message:
          'Closr stores your account, companion, and preference data in Firebase so your experience stays in sync across devices. Review the app settings before sharing anything sensitive.',
    );
  }

  Future<void> _showHelpSupport() async {
    await _showSupportDialog(
      title: 'Help & feedback',
      message:
          'If something feels off, copy a short note about what happened and share it with your team or support channel.',
      actionLabel: 'Copy note',
      onAction: () async {
        await Clipboard.setData(
          const ClipboardData(
            text:
                'Closr feedback: describe the issue, what you expected, and what happened instead.',
          ),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Feedback note copied to clipboard')),
        );
      },
    );
  }

  // ── Companion picker ──────────────────────────────────────────────────────────
  // ── Partner email dialog ───────────────────────────────────────────────────────

  Future<void> _showAddPartnerDialog() async {
    final cs = Theme.of(context).colorScheme;
    final controller = TextEditingController(text: _partnerEmail);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Partner'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your partner\'s email to link your accounts.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: 'partner@email.com'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final email = controller.text.trim().toLowerCase();
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .set({
                      'partnerEmail': email,
                      'partnerEmailLower': email,
                    }, SetOptions(merge: true));
                setState(() => _partnerEmail = email);
              }
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            style: FilledButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSetAnniversaryDialog() async {
    final cs = Theme.of(context).colorScheme;

    final selected = await showDatePicker(
      context: context,
      initialDate: _anniversaryDate ?? DateTime.now(),
      firstDate: DateTime(1980),
      lastDate: DateTime.now(),
    );

    if (selected != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'anniversaryDate': selected.toIso8601String(),
        }, SetOptions(merge: true));
        setState(() => _anniversaryDate = selected);
      }
    }
  }

  Future<void> _showCompanionPicker() async {
    final cs = Theme.of(context).colorScheme;
    int selectedIdx = _kCompanions.indexWhere(
      (c) => c.emoji == _companionEmoji,
    );
    if (selectedIdx < 0) selectedIdx = 0;
    final nameCtrl = TextEditingController(text: _companionName);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            MediaQuery.of(ctx).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Choose your companion',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Your companion grows with your relationship.',
                style: Theme.of(
                  ctx,
                ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1,
                children: List.generate(_kCompanions.length, (i) {
                  final c = _kCompanions[i];
                  final selected = i == selectedIdx;
                  return GestureDetector(
                    onTap: () {
                      setSheet(() => selectedIdx = i);
                      if (_kCompanions.any(
                        (x) => x.defaultName == nameCtrl.text,
                      )) {
                        nameCtrl.text = c.defaultName;
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: selected
                            ? cs.primaryContainer
                            : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selected ? cs.primary : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(c.emoji, style: const TextStyle(fontSize: 32)),
                          const SizedBox(height: 4),
                          Text(
                            c.species,
                            style: Theme.of(ctx).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),
              Text(
                'Name your companion',
                style: Theme.of(
                  ctx,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'Give them a name...',
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final chosen = _kCompanions[selectedIdx];
                    final newName = nameCtrl.text.trim().isEmpty
                        ? chosen.defaultName
                        : nameCtrl.text.trim();
                    setState(() {
                      _companionEmoji = chosen.emoji;
                      _companionName = newName;
                    });
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .set({
                            'companionEmoji': chosen.emoji,
                            'companionName': newName,
                          }, SetOptions(merge: true));
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Save companion'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Interests editor ──────────────────────────────────────────────────────────

  Future<void> _showInterestsEditor(
    String key,
    String label,
    List<String> current,
  ) async {
    final cs = Theme.of(context).colorScheme;
    final options = _kInterestOptions[key] ?? [];
    final selected = Set<String>.from(current);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            MediaQuery.of(ctx).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Edit $label',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap to select what fits you both.',
                style: Theme.of(
                  ctx,
                ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: options.map((opt) {
                  final isOn = selected.contains(opt);
                  return GestureDetector(
                    onTap: () => setSheet(() {
                      isOn ? selected.remove(opt) : selected.add(opt);
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: isOn ? cs.primary : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: isOn ? cs.primary : cs.outlineVariant,
                        ),
                      ),
                      child: Text(
                        opt,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isOn ? cs.onPrimary : cs.onSurface,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await _prefsService.updatePreference(
                      key,
                      selected.toList(),
                    );
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      setState(() {});
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName ?? 'Your Name';
    final email = user?.email ?? '';
    final initials = name.isNotEmpty
        ? name.trim().split(' ').map((p) => p[0]).take(2).join().toUpperCase()
        : '?';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('You', style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: 20),

          // ── Profile card (ORIGINAL — unchanged) ──────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF231519)
                  : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.primaryContainer,
                    border: Border.all(
                      color: cs.primary.withOpacity(0.3),
                      width: 2,
                    ),
                    image: user?.photoURL != null
                        ? DecorationImage(
                            image: NetworkImage(user!.photoURL!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: user?.photoURL == null
                      ? Center(
                          child: Text(
                            initials,
                            style: TextStyle(
                              fontFamily: 'DMSans',
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: cs.primary,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        email,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.edit_outlined, size: 18, color: cs.onSurfaceVariant),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Your Companion (NEW) ──────────────────────────────────────
          _GroupLabel(text: 'Your Companion', cs: cs),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF231519)
                  : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: InkWell(
              onTap: _companionLoading ? null : _showCompanionPicker,
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.pets_rounded,
                      size: 20,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 14),
                    Text(
                      _companionLoading ? 'Loading...' : _companionEmoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _companionLoading ? '' : _companionName,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    const _TrailingArrow(),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Relationship group (ORIGINAL — unchanged) ─────────────────
          _GroupLabel(text: 'Relationship', cs: cs),
          const SizedBox(height: 8),
          _SettingsGroup(
            cs: cs,
            rows: [
              _SettingsRowData(
                icon: Icons.favorite_outline_rounded,
                label: 'Partner',
                onTap: _showAddPartnerDialog,
                trailing: _partnerEmail.isEmpty
                    ? const _TrailingArrow()
                    : Text(
                        _partnerEmail,
                        style: TextStyle(fontSize: 13, color: cs.primary),
                      ),
              ),
              _SettingsRowData(
                icon: Icons.cake_outlined,
                label: 'Anniversary date',
                onTap: _showSetAnniversaryDialog,
                trailing: _anniversaryDate == null
                    ? const _TrailingArrow()
                    : Text(
                        '${_anniversaryDate!.month}/${_anniversaryDate!.day}/${_anniversaryDate!.year}',
                        style: TextStyle(fontSize: 13, color: cs.primary),
                      ),
              ),
              _SettingsRowData(
                icon: Icons.pets_rounded,
                label: 'Companion name',
                trailing: Text(
                  _companionName,
                  style: TextStyle(
                    fontFamily: 'DMSans',
                    fontSize: 14,
                    color: cs.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Preferences group (ORIGINAL — toggles now functional) ─────
          _GroupLabel(text: 'Preferences', cs: cs),
          const SizedBox(height: 8),
          _SettingsGroup(
            cs: cs,
            rows: [
              _SettingsRowData(
                icon: Icons.notifications_outlined,
                label: 'Daily reminder',
                trailing: Consumer<NotificationsService>(
                  builder: (_, ns, __) => _ToggleSwitch(
                    cs: cs,
                    value: ns.enabled,
                    onChanged: ns.setEnabled,
                  ),
                ),
              ),
              _SettingsRowData(
                icon: Icons.dark_mode_outlined,
                label: 'Dark mode',
                trailing: Consumer<ThemeProvider>(
                  builder: (_, tp, __) => _ToggleSwitch(
                    cs: cs,
                    value: tp.isDark,
                    onChanged: tp.setDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Interests (NEW) ───────────────────────────────────────────
          _GroupLabel(text: 'Interests', cs: cs),
          const SizedBox(height: 8),
          FutureBuilder<Map<String, dynamic>?>(
            future: _prefsService.getPreferences(),
            builder: (context, snapshot) {
              final prefs = snapshot.data ?? {};
              return _CollapsibleInterests(
                prefs: prefs,
                cs: cs,
                onEdit: _showInterestsEditor,
              );
            },
          ),
          const SizedBox(height: 20),

          // ── Support group (ORIGINAL — unchanged) ─────────────────────
          _GroupLabel(text: 'Support', cs: cs),
          const SizedBox(height: 8),
          _SettingsGroup(
            cs: cs,
            rows: [
              _SettingsRowData(
                icon: Icons.info_outline_rounded,
                label: 'About Closr',
                onTap: _showAboutSupport,
                trailing: const _TrailingArrow(),
              ),
              _SettingsRowData(
                icon: Icons.privacy_tip_outlined,
                label: 'Privacy policy',
                onTap: _showPrivacySupport,
                trailing: const _TrailingArrow(),
              ),
              _SettingsRowData(
                icon: Icons.help_outline_rounded,
                label: 'Help & feedback',
                onTap: _showHelpSupport,
                trailing: const _TrailingArrow(),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ── Sign out ──────────────────────────────────────────────────
          ElevatedButton(
            onPressed: () async {
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/welcome');
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: const Text('Sign out'),
          ),
          const SizedBox(height: 12),

          Center(
            child: Text(
              'Closr v1.0.0',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant.withOpacity(0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Interests collapsible widget (NEW) ────────────────────────────────────────

class _CollapsibleInterests extends StatefulWidget {
  final Map<String, dynamic> prefs;
  final ColorScheme cs;
  final Future<void> Function(String key, String label, List<String> current)
  onEdit;
  const _CollapsibleInterests({
    required this.prefs,
    required this.cs,
    required this.onEdit,
  });

  @override
  State<_CollapsibleInterests> createState() => _CollapsibleInterestsState();
}

class _CollapsibleInterestsState extends State<_CollapsibleInterests> {
  final Map<String, bool> _expanded = {
    'food': false,
    'outing': false,
    'interests': false,
    'location': false,
  };

  static const _labels = {
    'food': 'Food',
    'outing': 'Outing',
    'interests': 'Interests',
    'location': 'Location',
  };

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF231519)
            : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: _labels.entries.map((entry) {
          final key = entry.key;
          final label = entry.value;
          final isLast = key == 'location';
          final isExpanded = _expanded[key]!;
          final items = widget.prefs[key] is List
              ? List<String>.from(widget.prefs[key])
              : <String>[];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    // expand/collapse tap on label
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _expanded[key] = !isExpanded),
                        child: Row(
                          children: [
                            Icon(
                              const {
                                'food': Icons.restaurant_outlined,
                                'outing': Icons.explore_outlined,
                                'interests': Icons.auto_awesome_outlined,
                                'location': Icons.place_outlined,
                              }[key]!,
                              size: 20,
                              color: cs.onSurfaceVariant,
                            ),
                            const SizedBox(width: 14),
                            Text(
                              label,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              isExpanded
                                  ? Icons.keyboard_arrow_down
                                  : Icons.keyboard_arrow_right,
                              size: 18,
                              color: cs.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Edit button
                    TextButton(
                      onPressed: () => widget.onEdit(key, label, items),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 0,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: cs.primary,
                      ),
                      child: const Text('Edit', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),
              // chips when expanded
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                crossFadeState: isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox.shrink(),
                secondChild: items.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(50, 0, 16, 14),
                        child: Text(
                          'None set — tap Edit to add some.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(50, 0, 16, 14),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: items
                              .map(
                                (item) => Chip(
                                  label: Text(item),
                                  backgroundColor: cs.primaryContainer,
                                  side: BorderSide(color: cs.primary),
                                  labelStyle: TextStyle(
                                    color: cs.onPrimaryContainer,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                  padding: EdgeInsets.zero,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              )
                              .toList(),
                        ),
                      ),
              ),
              if (!isLast)
                Divider(height: 1, color: cs.outlineVariant, indent: 50),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ── Private widgets (ORIGINAL — unchanged) ────────────────────────────────────

class _GroupLabel extends StatelessWidget {
  final String text;
  final ColorScheme cs;
  const _GroupLabel({required this.text, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall,
    );
  }
}

class _SettingsRowData {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Widget trailing;
  const _SettingsRowData({
    required this.icon,
    required this.label,
    this.onTap,
    required this.trailing,
  });
}

class _SettingsGroup extends StatelessWidget {
  final ColorScheme cs;
  final List<_SettingsRowData> rows;
  const _SettingsGroup({required this.cs, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF231519)
            : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: List.generate(rows.length, (i) {
          final row = rows[i];
          final isLast = i == rows.length - 1;
          return Column(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: row.onTap,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(i == 0 ? 18 : 0),
                    bottom: Radius.circular(isLast ? 18 : 0),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Icon(row.icon, size: 20, color: cs.onSurfaceVariant),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            row.label,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                        row.trailing,
                      ],
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Divider(height: 1, color: cs.outlineVariant, indent: 50),
            ],
          );
        }),
      ),
    );
  }
}

class _TrailingArrow extends StatelessWidget {
  const _TrailingArrow();
  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.chevron_right_rounded,
      size: 20,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }
}

// Fixed: thumb is cs.surface (cream/dark bg) so it contrasts the rose track
class _ToggleSwitch extends StatelessWidget {
  final ColorScheme cs;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleSwitch({
    required this.cs,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: value,
      onChanged: onChanged,
      activeTrackColor: cs.primary,
      activeColor: cs.surface, // thumb = cream/dark bg when ON
      inactiveThumbColor: cs.onSurfaceVariant.withOpacity(0.4),
      inactiveTrackColor: cs.outlineVariant,
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    );
  }
}
