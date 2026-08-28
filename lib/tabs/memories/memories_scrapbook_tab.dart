// lib/memories/memories_scrapbook_tab.dart
part of 'memories_screen.dart';

class MemoriesScrapbookTab extends StatelessWidget {
  const MemoriesScrapbookTab({super.key});

  @override
  Widget build(BuildContext context) => const _ScrapbookTab();
}

enum _ScrapbookViewMode { calendar, polaroids }

class _ScrapbookTab extends StatefulWidget {
  const _ScrapbookTab();

  @override
  State<_ScrapbookTab> createState() => _ScrapbookTabState();
}

class _ScrapbookTabState extends State<_ScrapbookTab>
    with SingleTickerProviderStateMixin {
  final ScrapbookService _service = ScrapbookService();
  final PageController _galleryController = PageController();

  _ScrapbookViewMode _viewMode = _ScrapbookViewMode.calendar;
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  int _galleryIndex = 0;
  late final AnimationController _dissolveController;
  late final Animation<double> _dissolveAnimation;

  @override
  void initState() {
    super.initState();
    _dissolveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _dissolveAnimation = CurvedAnimation(
      parent: _dissolveController,
      curve: Curves.easeInOut,
    );
    _dissolveController.forward();
  }

  @override
  void dispose() {
    _galleryController.dispose();
    _dissolveController.dispose();
    super.dispose();
  }

  void _switchViewMode(_ScrapbookViewMode newMode) {
    if (_viewMode == newMode) return;
    setState(() {
      _viewMode = newMode;
    });
    _dissolveController.forward(from: 0.0);
  }

  String _dateKey(DateTime date) => ScrapbookEntry.dateKeyFor(date);

  String _monthLabel(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _weekdayLabel(int weekday) {
    const labels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return labels[weekday % 7];
  }

  List<DateTime?> _buildMonthCells(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final leadingEmpty = firstDay.weekday % 7;
    final cells = <DateTime?>[];

    for (var i = 0; i < leadingEmpty; i++) {
      cells.add(null);
    }
    for (var day = 1; day <= daysInMonth; day++) {
      cells.add(DateTime(month.year, month.month, day));
    }
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return cells;
  }

  ScrapbookEntry? _entryForDate(List<ScrapbookEntry> entries, DateTime date) {
    final key = _dateKey(date);
    for (final entry in entries) {
      if (entry.id == key) return entry;
    }
    return null;
  }

  Future<void> _openEntryEditor({
    ScrapbookEntry? existingEntry,
    DateTime? presetDate,
  }) async {
    final picker = ImagePicker();
    final cs = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context);
    final today = DateTime.now();
    final latestAllowedDate = DateTime(today.year, today.month, today.day);
    DateTime selectedDate =
        existingEntry?.entryDate ?? presetDate ?? DateTime.now();
    String description = existingEntry?.description ?? '';
    final descriptionController = TextEditingController(text: description);
    String existingImageUrl = existingEntry?.imageUrl ?? '';
    String existingImagePath = existingEntry?.imagePath ?? '';
    XFile? pickedImage;
    Uint8List? previewBytes;
    bool isSaving = false;
    bool isDeleteOverlayVisible = false;
    bool isDeletingImage = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> pickImage(ImageSource source) async {
              final file = await picker.pickImage(
                source: source,
                imageQuality: 86,
              );
              if (file == null) return;
              final bytes = await file.readAsBytes();
              setSheetState(() {
                pickedImage = file;
                previewBytes = bytes;
                existingImageUrl = '';
                existingImagePath = '';
                isDeleteOverlayVisible = false;
              });
            }

            Future<void> deleteImage() async {
              if (isDeletingImage) return;

              if (pickedImage != null) {
                setSheetState(() {
                  pickedImage = null;
                  previewBytes = null;
                  isDeleteOverlayVisible = false;
                });
                return;
              }

              if (existingImageUrl.isEmpty) return;

              setSheetState(() => isDeletingImage = true);
              try {
                await _service.deleteImageFromEntry(
                  entryDate: selectedDate,
                  existingImagePath: existingImagePath,
                );
                setSheetState(() {
                  existingImageUrl = '';
                  existingImagePath = '';
                  isDeleteOverlayVisible = false;
                  isDeletingImage = false;
                });
                messenger.showSnackBar(
                  const SnackBar(content: Text('Photo deleted.')),
                );
              } catch (error) {
                setSheetState(() => isDeletingImage = false);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Could not delete scrapbook photo: $error'),
                  ),
                );
              }
            }

            Future<void> handleImageTap() async {
              final hasImage =
                  pickedImage != null || existingImageUrl.isNotEmpty;
              if (!hasImage) {
                await pickImage(ImageSource.gallery);
                return;
              }

              if (isDeleteOverlayVisible) {
                await deleteImage();
                return;
              }

              setSheetState(() => isDeleteOverlayVisible = true);
            }

            Future<void> handleImageDoubleTap() async {
              final hasImage =
                  pickedImage != null || existingImageUrl.isNotEmpty;
              if (!hasImage) {
                await pickImage(ImageSource.gallery);
                return;
              }

              await deleteImage();
            }

            Future<void> chooseDate() async {
              final initialDate = selectedDate.isAfter(latestAllowedDate)
                  ? latestAllowedDate
                  : selectedDate;
              final chosen = await showDatePicker(
                context: sheetContext,
                initialDate: initialDate,
                firstDate: DateTime(2010),
                lastDate: latestAllowedDate,
              );
              if (chosen == null) return;
              setSheetState(() {
                selectedDate = chosen;
              });
            }

            Future<void> saveEntry() async {
              if (isSaving) return;
              final messenger = ScaffoldMessenger.of(sheetContext);
              final navigator = Navigator.of(sheetContext);

              setSheetState(() => isSaving = true);
              try {
                await _service.upsertEntry(
                  entryDate: selectedDate,
                  description: description.trim(),
                  existingImageUrl: existingImageUrl,
                  existingImagePath: existingImagePath,
                  pickedImage: pickedImage,
                );
                if (!mounted) return;
                navigator.pop();
              } catch (error) {
                if (!mounted) return;
                setSheetState(() => isSaving = false);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Could not save scrapbook entry: $error'),
                  ),
                );
              }
            }

            final previewWidget = pickedImage != null && previewBytes != null
                ? Image.memory(previewBytes!, fit: BoxFit.cover)
                : existingImageUrl.isNotEmpty
                ? Image.network(
                    existingImageUrl,
                    fit: BoxFit.cover,
                    frameBuilder:
                        (context, child, frame, wasSynchronouslyLoaded) {
                          if (wasSynchronouslyLoaded || frame != null) {
                            return child;
                          }
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              Container(
                                color: cs.primaryContainer.withValues(
                                  alpha: 0.35,
                                ),
                              ),
                              Center(
                                child: SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: cs.primary,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                    errorBuilder: (context, error, stackTrace) =>
                        _PhotoFallback(cs: cs),
                  )
                : null;
            final hasImage = pickedImage != null || existingImageUrl.isNotEmpty;

            return Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 12,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: cs.outlineVariant,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        existingEntry == null
                            ? 'Add scrapbook moment'
                            : 'Update scrapbook moment',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Pick a date, add a photo, and write what made that day feel special.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 18),
                      GestureDetector(
                        onTap: chooseDate,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: cs.primary.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                color: cs.primary,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Date: ${MaterialLocalizations.of(context).formatFullDate(selectedDate)}',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              TextButton(
                                onPressed: chooseDate,
                                child: const Text('Change'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        height: 220,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: cs.outlineVariant),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: handleImageTap,
                            onDoubleTap: handleImageDoubleTap,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                previewWidget ??
                                    Container(
                                      decoration: BoxDecoration(
                                        color: cs.primaryContainer.withValues(
                                          alpha: 0.35,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Tap to add a photo',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: cs.onSurfaceVariant,
                                              ),
                                        ),
                                      ),
                                    ),
                                if (hasImage && isDeleteOverlayVisible)
                                  Positioned.fill(
                                    child: Container(
                                      color: Colors.black.withValues(
                                        alpha: 0.5,
                                      ),
                                      child: Center(
                                        child: Icon(
                                          Icons.delete_forever_rounded,
                                          color: Colors.white,
                                          size: 54,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => pickImage(ImageSource.gallery),
                              icon: const Icon(Icons.photo_library_outlined),
                              label: const Text('Gallery'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => pickImage(ImageSource.camera),
                              icon: const Icon(Icons.camera_alt_outlined),
                              label: const Text('Camera'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: descriptionController,
                        minLines: 4,
                        maxLines: 6,
                        onChanged: (value) => description = value,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          hintText:
                              'What did you do, how did it feel, or why was this day special?',
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: isSaving ? null : saveEntry,
                        child: isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Save scrapbook entry'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _jumpToNextImage(int total) async {
    if (total <= 1) return;
    final nextIndex = (_galleryIndex + 1) % total;
    await _galleryController.animateToPage(
      nextIndex,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _pickFocusedMonth() async {
    final today = DateTime.now();
    final latestAllowedDate = DateTime(today.year, today.month, today.day);
    final initialDate = _focusedMonth.isAfter(latestAllowedDate)
        ? latestAllowedDate
        : _focusedMonth;
    final chosen = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2010),
      lastDate: latestAllowedDate,
    );
    if (chosen == null) return;
    setState(() {
      _focusedMonth = DateTime(chosen.year, chosen.month);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = FirebaseAuth.instance.currentUser;
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);

    return StreamBuilder<List<ScrapbookEntry>>(
      stream: _service.streamForCurrentUser(),
      builder: (context, snapshot) {
        final entries = snapshot.data ?? const <ScrapbookEntry>[];
        final imageEntries = entries
            .where((entry) => entry.imageUrl.isNotEmpty)
            .toList();
        if (_galleryIndex >= imageEntries.length && imageEntries.isNotEmpty) {
          _galleryIndex = 0;
        }

        return Stack(
          children: [
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (entries.isEmpty)
                    _EmptyScrapbookState(
                      cs: cs,
                      hasUser: user != null,
                      onAdd: () => _openEntryEditor(presetDate: DateTime.now()),
                    )
                  else
                    const SizedBox.shrink(),
                  if (entries.isNotEmpty)
                    const SizedBox(height: 16)
                  else
                    const SizedBox(height: 24),
                  _ViewModeSwitch(
                    cs: cs,
                    viewMode: _viewMode,
                    onCalendar: () =>
                        _switchViewMode(_ScrapbookViewMode.calendar),
                    onGallery: () =>
                        _switchViewMode(_ScrapbookViewMode.polaroids),
                  ),
                  const SizedBox(height: 16),
                  if (_viewMode == _ScrapbookViewMode.polaroids)
                    FadeTransition(
                      opacity: _dissolveAnimation,
                      child: Text(
                        'Swipe left/right or tap to flip through polaroids. Long-press to edit.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (_viewMode == _ScrapbookViewMode.polaroids)
                    const SizedBox(height: 12),
                  FadeTransition(
                    opacity: _dissolveAnimation,
                    child: _viewMode == _ScrapbookViewMode.calendar
                        ? _CalendarScrapbookView(
                            cs: cs,
                            monthLabel: _monthLabel(_focusedMonth),
                            onMonthLabelTap: _pickFocusedMonth,
                            onPreviousMonth: () {
                              setState(() {
                                _focusedMonth = DateTime(
                                  _focusedMonth.year,
                                  _focusedMonth.month - 1,
                                );
                              });
                            },
                            onNextMonth: () {
                              setState(() {
                                _focusedMonth = DateTime(
                                  _focusedMonth.year,
                                  _focusedMonth.month + 1,
                                );
                              });
                            },
                            days: _buildMonthCells(_focusedMonth),
                            weekdayLabel: _weekdayLabel,
                            entryForDate: (date) =>
                                _entryForDate(entries, date),
                            onTapDate: (date) => _openEntryEditor(
                              existingEntry: _entryForDate(entries, date),
                              presetDate: date,
                            ),
                            isDateEnabled: (date) => !date.isAfter(todayKey),
                          )
                        : _GalleryScrapbookView(
                            cs: cs,
                            entries: imageEntries,
                            controller: _galleryController,
                            currentIndex: _galleryIndex,
                            onPageChanged: (index) =>
                                setState(() => _galleryIndex = index),
                            onTapCard: () =>
                                _jumpToNextImage(imageEntries.length),
                            onEditEntry: (entry) =>
                                _openEntryEditor(existingEntry: entry),
                          ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            Positioned(
              right: 20,
              bottom: 28,
              child: FloatingActionButton.extended(
                onPressed: () => _openEntryEditor(presetDate: DateTime.now()),
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ViewModeSwitch extends StatelessWidget {
  final ColorScheme cs;
  final _ScrapbookViewMode viewMode;
  final VoidCallback onCalendar;
  final VoidCallback onGallery;

  const _ViewModeSwitch({
    required this.cs,
    required this.viewMode,
    required this.onCalendar,
    required this.onGallery,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final pillWidth = (totalWidth - 8) / 2;
          final isCalendar = viewMode == _ScrapbookViewMode.calendar;

          return Stack(
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOutCubic,
                alignment: isCalendar
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: Container(
                  width: pillWidth,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _ModePill(
                      label: 'Calendar',
                      selected: isCalendar,
                      cs: cs,
                      icon: Icons.calendar_month_rounded,
                      onTap: onCalendar,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _ModePill(
                      label: 'Polaroids',
                      selected: !isCalendar,
                      cs: cs,
                      icon: Icons.photo_library_outlined,
                      onTap: onGallery,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ModePill extends StatelessWidget {
  final String label;
  final bool selected;
  final ColorScheme cs;
  final IconData icon;
  final VoidCallback onTap;

  const _ModePill({
    required this.label,
    required this.selected,
    required this.cs,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? cs.onPrimary : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: selected ? cs.onPrimary : cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarScrapbookView extends StatelessWidget {
  final ColorScheme cs;
  final String monthLabel;
  final VoidCallback onMonthLabelTap;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final List<DateTime?> days;
  final String Function(int weekday) weekdayLabel;
  final ScrapbookEntry? Function(DateTime date) entryForDate;
  final ValueChanged<DateTime> onTapDate;
  final bool Function(DateTime date) isDateEnabled;

  const _CalendarScrapbookView({
    required this.cs,
    required this.monthLabel,
    required this.onMonthLabelTap,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.days,
    required this.weekdayLabel,
    required this.entryForDate,
    required this.onTapDate,
    required this.isDateEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onPreviousMonth,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: InkWell(
                  onTap: onMonthLabelTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          monthLabel,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tap month or year to jump',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: onNextMonth,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(7, (index) {
              return Expanded(
                child: Center(
                  child: Text(
                    weekdayLabel(index),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: days.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              mainAxisExtent: 72,
            ),
            itemBuilder: (context, index) {
              final day = days[index];
              if (day == null) {
                return const SizedBox.shrink();
              }

              final entry = entryForDate(day);
              final hasImage = entry?.imageUrl.isNotEmpty == true;
              final dayKey = DateTime(day.year, day.month, day.day);
              final isToday = dayKey == todayKey;
              final isEnabled = isDateEnabled(dayKey);

              return InkWell(
                onTap: isEnabled ? () => onTapDate(day) : null,
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: hasImage
                        ? cs.primaryContainer.withValues(alpha: 0.92)
                        : (isToday
                              ? cs.secondaryContainer.withValues(alpha: 0.72)
                              : cs.surfaceContainerHighest.withValues(
                                  alpha: 0.45,
                                )),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: hasImage
                          ? cs.primary.withValues(alpha: 0.3)
                          : isToday
                          ? cs.primary.withValues(alpha: 0.18)
                          : cs.outlineVariant,
                    ),
                  ),
                  child: Opacity(
                    opacity: isEnabled ? 1 : 0.38,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${day.day}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface,
                              ),
                        ),
                        Expanded(
                          child: hasImage
                              ? Center(
                                  child: Icon(
                                    Icons.favorite_rounded,
                                    size: 18,
                                    color: cs.primary,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _GalleryScrapbookView extends StatelessWidget {
  final ColorScheme cs;
  final List<ScrapbookEntry> entries;
  final PageController controller;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onTapCard;
  final ValueChanged<ScrapbookEntry> onEditEntry;

  const _GalleryScrapbookView({
    required this.cs,
    required this.entries,
    required this.controller,
    required this.currentIndex,
    required this.onPageChanged,
    required this.onTapCard,
    required this.onEditEntry,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return _EmptyGalleryCard(cs: cs);
    }

    const brownTextColor = Color(0xFF6D4C41);

    return Column(
      children: [
        SizedBox(
          height: 480,
          child: PageView.builder(
            controller: controller,
            itemCount: entries.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, index) {
              final entry = entries[index];

              return AnimatedBuilder(
                animation: controller,
                builder: (context, child) {
                  double page = index.toDouble();
                  if (controller.hasClients &&
                      controller.position.haveDimensions) {
                    page = controller.page ?? controller.initialPage.toDouble();
                  }

                  final diff = page - index;
                  final isPast = diff > 0;
                  final absDiff = diff.abs();

                  final scale = isPast
                      ? (1.0 - (absDiff * 0.25)).clamp(0.65, 1.0)
                      : (1.0 - (absDiff * 0.1)).clamp(0.9, 1.0);

                  final translateY = isPast
                      ? (-absDiff * 120.0)
                      : (absDiff * 35.0);
                  final opacity = isPast
                      ? (1.0 - absDiff).clamp(0.0, 1.0)
                      : 1.0;

                  return Transform(
                    transform: Matrix4.identity()
                      ..translate(0.0, translateY)
                      ..scale(scale, scale),
                    alignment: Alignment.center,
                    child: Opacity(opacity: opacity, child: child),
                  );
                },
                child: Center(
                  child: GestureDetector(
                    onTap: onTapCard,
                    onLongPress: () => onEditEntry(entry),
                    child: Container(
                      width: 270,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBF4),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cs.primary, width: 2.0),
                        boxShadow: [
                          BoxShadow(
                            color: cs.primary.withValues(alpha: 0.15),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.network(
                                    entry.imageUrl,
                                    fit: BoxFit.cover,
                                    frameBuilder:
                                        (
                                          context,
                                          child,
                                          frame,
                                          wasSynchronouslyLoaded,
                                        ) {
                                          if (wasSynchronouslyLoaded ||
                                              frame != null) {
                                            return child;
                                          }
                                          return Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              Container(
                                                color: cs.primaryContainer
                                                    .withValues(alpha: 0.35),
                                              ),
                                              Center(
                                                child: SizedBox(
                                                  width: 28,
                                                  height: 28,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2.5,
                                                        color: cs.primary,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                    errorBuilder: (context, error, stackTrace) {
                                      return _PhotoFallback(cs: cs);
                                    },
                                  ),
                                  Positioned(
                                    top: 10,
                                    right: 10,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.85,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        'Swipe or tap',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: brownTextColor,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 10,
                                            ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDate(entry.entryDate),
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: brownTextColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                              ),
                              Icon(
                                Icons.favorite_rounded,
                                size: 14,
                                color: cs.primary.withValues(alpha: 0.8),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            entry.description.isEmpty ? '' : entry.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  height: 1.3,
                                  color: brownTextColor,
                                  fontStyle: FontStyle.italic,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.touch_app_rounded,
                                size: 12,
                                color: brownTextColor.withValues(alpha: 0.7),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Swipe cards, long-press to edit',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: brownTextColor.withValues(
                                        alpha: 0.7,
                                      ),
                                      fontSize: 10,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(entries.length, (index) {
            final isActive = index == currentIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 18 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: isActive ? cs.primary : cs.outlineVariant,
                borderRadius: BorderRadius.circular(99),
              ),
            );
          }),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _EmptyScrapbookState extends StatelessWidget {
  final ColorScheme cs;
  final bool hasUser;
  final VoidCallback onAdd;

  const _EmptyScrapbookState({
    required this.cs,
    required this.hasUser,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.primary.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: cs.surface.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.photo_camera_outlined, color: cs.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  hasUser
                      ? 'Start your scrapbook'
                      : 'Sign in to save scrapbook memories',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Tap Add to choose a date, upload a photo, and write a little note about the day.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add first memory'),
          ),
        ],
      ),
    );
  }
}

class _EmptyGalleryCard extends StatelessWidget {
  final ColorScheme cs;

  const _EmptyGalleryCard({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 360,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_outlined, color: cs.primary, size: 42),
            const SizedBox(height: 10),
            Text(
              'No scrapbook photos yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Add one from the plus button and it will show up here as a polaroid.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoFallback extends StatelessWidget {
  final ColorScheme cs;

  const _PhotoFallback({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: cs.primaryContainer.withValues(alpha: 0.35),
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: cs.primary,
          size: 36,
        ),
      ),
    );
  }
}
