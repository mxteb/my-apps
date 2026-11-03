import 'package:flutter/material.dart';

import '../l10n.dart';
import '../sorter.dart';
import '../theme.dart';
import '../widgets/thumb.dart';
import 'done.dart';
import 'sort.dart';
import 'viewer.dart';

/// مراجعة الملفات المحددة للحذف، مع إمكانية استعادة أي ملف ثم تأكيد الحذف.
class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key, required this.sorter});
  final Sorter sorter;

  static const _tilts = [-0.05, 0.035, -0.017, 0.05, -0.035, 0.017];

  void _backToSort(BuildContext context) => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => SortScreen(sorter: sorter)));

  Future<void> _confirm(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0x8C2A241D),
      builder: (c) => _ConfirmDialog(count: sorter.deleteCount, bytes: sorter.deleteBytes),
    );
    if (ok != true || !context.mounted) return;
    await sorter.deleteMarked();
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => DoneScreen(sorter: sorter)));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: sorter,
      builder: (context, _) {
        final list = sorter.toDelete;
        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton.outlined(
                        tooltip: tr('رجوع للفرز', 'Back to sorting'),
                        onPressed: () => _backToSort(context),
                        icon: const Icon(Icons.arrow_back_rounded),
                        style: IconButton.styleFrom(
                          foregroundColor: Palette.ink,
                          backgroundColor: Palette.card,
                          side: const BorderSide(color: Palette.ink, width: 1.5),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr('قائمة الحذف', 'To delete'), style: hand(32)),
                            Text(
                              tr(
                                '${list.length} ملفًا بحجم ${formatBytes(sorter.deleteBytes)}. اضغط على أي ملف لمشاهدته أو استعادته.',
                                '${list.length} ${filesWord(list.length)}, ${formatBytes(sorter.deleteBytes)}. Tap any file to view or restore it.',
                              ),
                              style: const TextStyle(fontSize: 13, color: Palette.body),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: list.isEmpty
                        ? Center(
                            child: Text(tr('لا توجد ملفات محددة للحذف بعد', 'Nothing marked for deletion yet'), style: hand(22, color: Palette.body)),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(6),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.82,
                            ),
                            itemCount: list.length,
                            itemBuilder: (context, i) {
                              final a = list[i];
                              return Transform.rotate(
                                angle: _tilts[i % _tilts.length],
                                child: Semantics(
                                  button: true,
                                  label: tr('عرض الملف', 'View file'),
                                  child: GestureDetector(
                                    onTap: () => MediaViewer.open(context, assets: list, sorter: sorter, mode: ViewerMode.review, index: i),
                                    child: Container(
                                      padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
                                      decoration: BoxDecoration(color: Palette.card, boxShadow: paperShadow(0.6)),
                                      child: Column(
                                        children: [
                                          Expanded(
                                            child: Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                AssetThumb(a, size: 250),
                                                if (sorter.isVideo(a))
                                                  const Center(child: Icon(Icons.play_circle_outline_rounded, color: Palette.card, size: 30)),
                                                Positioned(
                                                  top: 0,
                                                  left: 0,
                                                  child: Semantics(
                                                    button: true,
                                                    label: tr('استعادة الملف', 'Restore file'),
                                                    child: GestureDetector(
                                                      onTap: () => sorter.restore(a),
                                                      child: Container(
                                                        margin: const EdgeInsets.all(3),
                                                        padding: const EdgeInsets.all(4),
                                                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xCCFFFFFF)),
                                                        child: const Icon(Icons.undo_rounded, color: Palette.blue, size: 16),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          SizedBox(
                                            height: 22,
                                            child: Center(child: Text(formatDate(sorter.dateOf(a)), style: hand(12), maxLines: 1)),
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
                  const SizedBox(height: 12),
                  SolidButton(
                    tr('حذف جميع الملفات المحددة', 'Delete all marked files'),
                    color: Palette.red,
                    onPressed: list.isEmpty ? null : () => _confirm(context),
                  ),
                  const SizedBox(height: 10),
                  OutlineInkButton(tr('متابعة الفرز لاحقًا', 'Continue sorting later'), onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({required this.count, required this.bytes});
  final int count;
  final int bytes;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.all(24),
    child: Transform.rotate(
      angle: -0.017,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 18),
            decoration: BoxDecoration(color: Palette.card, boxShadow: paperShadow(2.5)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(tr('هل أنت متأكد؟', 'Are you sure?'), style: hand(28)),
                const SizedBox(height: 8),
                Text(
                  tr(
                    'سيُحذف $count ملفًا لتوفير ${formatBytes(bytes)}. ستنتقل الملفات إلى سلة المحذوفات أولًا، ويمكنك استعادتها عند الحاجة.',
                    '$count ${filesWord(count)} will be deleted to free ${formatBytes(bytes)}. They go to the trash first, so you can restore them if needed.',
                  ),
                  style: const TextStyle(fontSize: 15, color: Palette.body, height: 1.8),
                ),
                const SizedBox(height: 16),
                SolidButton(tr('نعم، احذف', 'Yes, delete'), color: Palette.red, height: 54, onPressed: () => Navigator.pop(context, true)),
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    tr('لا، أريد المراجعة مرة أخرى', 'No, let me review again'),
                    style: const TextStyle(color: Palette.ink, decoration: TextDecoration.underline),
                  ),
                ),
              ],
            ),
          ),
          const Positioned(top: -10, child: Tape(width: 60, angle: 0)),
        ],
      ),
    ),
  );
}
