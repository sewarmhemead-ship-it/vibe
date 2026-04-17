import 'package:flutter/material.dart';
import 'package:vibe_orbit/pulse.dart';

class PulseCreationSheetBody extends StatefulWidget {
  const PulseCreationSheetBody({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  State<PulseCreationSheetBody> createState() => _PulseCreationSheetBodyState();
}

class _PulseCreationSheetBodyState extends State<PulseCreationSheetBody> {
  String? _selectedEmoji;
  String? _moodChip;
  final TextEditingController _secretController = TextEditingController();
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _moodController = TextEditingController();

  static const List<String> _moodPresetsAr = [
    'هادئ',
    'حماس',
    'حنين',
    'طاقة',
    'هدوء',
  ];

  @override
  void dispose() {
    _secretController.dispose();
    _captionController.dispose();
    _moodController.dispose();
    super.dispose();
  }

  String? _normalizeMoodWord() {
    final fromChip = _moodChip?.trim();
    if (fromChip != null && fromChip.isNotEmpty) return _clipOneWord(fromChip);
    final raw = _moodController.text.trim();
    if (raw.isEmpty) return null;
    return _clipOneWord(raw.split(RegExp(r'\s+')).first);
  }

  String _clipOneWord(String w) {
    if (w.length <= 24) return w;
    return w.substring(0, 24);
  }

  void _submit() {
    final emoji = _selectedEmoji;
    if (emoji == null || emoji.isEmpty) return;
    Navigator.of(context).pop((
      categoryEmoji: emoji,
      vaultSecret: _secretController.text.trim(),
      caption: _captionController.text.trim(),
      moodTag: _normalizeMoodWord(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: const Color(0xFF121212),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Text(
            'New pulse',
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pick a vibe, then drop it on the map.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Category',
            style: theme.textTheme.labelLarge?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.start,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final emoji in PulseCategoryCatalog.emojis)
                Material(
                  color: _selectedEmoji == emoji
                      ? const Color(0xFF2A3F5F)
                      : const Color(0xFF252525),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _selectedEmoji = emoji),
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: Center(
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 30),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _captionController,
            decoration: const InputDecoration(
              labelText: 'وصف (اختياري) · Optional caption',
              hintText: 'يظهر في بطاقة الفيد…',
              alignLabelWithHint: true,
            ),
            minLines: 1,
            maxLines: 3,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          Text(
            'وسم مزاج (كلمة واحدة، اختياري)',
            style: theme.textTheme.labelLarge?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in _moodPresetsAr)
                ChoiceChip(
                  label: Text(m),
                  selected: _moodChip == m,
                  onSelected: (sel) {
                    setState(() {
                      _moodChip = sel ? m : null;
                      if (sel) _moodController.clear();
                    });
                  },
                  selectedColor: const Color(0xFF2A3F5F),
                  backgroundColor: const Color(0xFF252525),
                  labelStyle: const TextStyle(color: Colors.white70),
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _moodController,
            decoration: const InputDecoration(
              labelText: 'أو اكتب كلمة واحدة',
              hintText: 'مثال: مركّز',
              alignLabelWithHint: true,
            ),
            maxLines: 1,
            textInputAction: TextInputAction.next,
            onChanged: (_) {
              if (_moodController.text.trim().isNotEmpty) {
                setState(() => _moodChip = null);
              }
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _secretController,
            decoration: const InputDecoration(
              labelText: 'Secret message',
              hintText: 'Stored encrypted in the vault at this location',
              alignLabelWithHint: true,
            ),
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _selectedEmoji == null ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF448AFF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Drop pulse'),
          ),
        ],
      ),
    );
  }
}
