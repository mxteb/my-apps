import 'package:flutter/material.dart';

import '../l10n.dart';
import '../sorter.dart';
import '../theme.dart';

class DoneScreen extends StatelessWidget {
  const DoneScreen({super.key, required this.sorter});
  final Sorter sorter;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Transform.rotate(angle: -0.05, child: Text(tr('تم بنجاح!', 'Done!'), style: hand(44))),
            const SizedBox(height: 12),
            Text(
              tr(
                'حُذف ${sorter.totalDeleted} ملفًا، ووُفّرت مساحة قدرها ${formatBytes(sorter.totalFreedBytes)}.',
                '${sorter.totalDeleted} ${filesWord(sorter.totalDeleted)} deleted, ${formatBytes(sorter.totalFreedBytes)} freed.',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, height: 1.8),
            ),
            Text(
              tr('يمكنك استعادتها من سلة المحذوفات خلال ٣٠ يومًا.', 'You can restore them from the trash within 30 days.'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Palette.muted, height: 1.8),
            ),
            const SizedBox(height: 24),
            OutlineInkButton(tr('العودة إلى البداية', 'Back to start'), onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst)),
          ],
        ),
      ),
    ),
  );
}
