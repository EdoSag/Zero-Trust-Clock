import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../time_log/time_log.dart';
import 'alarm_text.dart';
import 'duration_text.dart';

/// "Log to ZT Time": a finished stopwatch or timer run becomes a time
/// entry in ZT Time, ending now. Pops true once logged.
class LogTimeSheet extends ConsumerStatefulWidget {
  const LogTimeSheet({
    super.key,
    required this.length,
    required this.description,
  });

  final Duration length;
  final String description;

  static Future<void> show(
    BuildContext context, {
    required Duration length,
    required String description,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    final logged = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => LogTimeSheet(length: length, description: description),
    );
    if (logged == true) showSnack(messenger, l.loggedToTime);
  }

  @override
  ConsumerState<LogTimeSheet> createState() => _LogTimeSheetState();
}

class _LogTimeSheetState extends ConsumerState<LogTimeSheet> {
  late final _text = TextEditingController(text: widget.description);
  late final Future<List<TimeProject>> _projects = ref
      .read(timeLogProvider)
      .projects();
  String? _project;
  bool _saving = false;
  bool _failed = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _log() async {
    setState(() {
      _saving = true;
      _failed = false;
    });
    final end = DateTime.now();
    try {
      await ref
          .read(timeLogProvider)
          .log(
            start: end.subtract(widget.length),
            end: end,
            description: _text.text.trim(),
            projectId: _project,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final end = DateTime.now();
    final start = end.subtract(widget.length);
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.logToTime, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            l.logToTimeSpan(
              timeOfDayText(context, start.hour, start.minute),
              timeOfDayText(context, end.hour, end.minute),
              countdownText(widget.length),
            ),
            key: const ValueKey('logSpan'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _text,
            maxLength: 120,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l.whatWasIt),
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<TimeProject>>(
            future: _projects,
            builder: (context, snap) {
              final list = snap.data ?? const <TimeProject>[];
              return DropdownButtonFormField<String?>(
                key: const ValueKey('logProject'),
                initialValue: _project,
                decoration: InputDecoration(labelText: l.project),
                items: [
                  DropdownMenuItem<String?>(child: Text(l.noProject)),
                  for (final p in list)
                    DropdownMenuItem<String?>(
                      value: p.id,
                      child: Text(
                        p.client.isEmpty ? p.name : '${p.name} · ${p.client}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _project = v),
              );
            },
          ),
          if (_failed) ...[
            const SizedBox(height: 8),
            Text(
              l.couldNotLog,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(onPressed: _saving ? null : _log, child: Text(l.logIt)),
        ],
      ),
    );
  }
}
