import 'package:flutter/material.dart';

import '../downloads.dart';
import '../format.dart';
import '../native.dart';
import '../player.dart';
import '../store.dart';
import '../widgets.dart';
import 'video.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التنزيلات')),
      body: ListenableBuilder(
        listenable: Listenable.merge([Store.i, Downloads.i]),
        builder: (context, _) {
          final tasks = Downloads.i.tasks;
          final done = Store.i.downloads;
          if (tasks.isEmpty && done.isEmpty) {
            return const EmptyState(
              icon: Icons.download_for_offline_outlined,
              title: 'لا توجد تنزيلات',
              body: 'نزّل مقطعًا أو صوتًا من صفحة المقطع لتشاهده بلا إنترنت.\nتُحفَظ الملفات في مجلّد Movies/Shoof أو Music/Shoof.',
            );
          }
          return ListView(children: [
            for (final t in tasks)
              ListTile(
                leading: const Icon(Icons.downloading_rounded),
                title: Text(t.video.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: 6),
                  LinearProgressIndicator(value: t.error != null ? 0 : (t.progress > 0 ? t.progress : null)),
                  const SizedBox(height: 4),
                  Text('${t.option.label} · ${t.error ?? t.stage}'
                      '${t.progress > 0 && t.error == null ? ' ${(t.progress * 100).round()}٪' : ''}'),
                ]),
                trailing: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Downloads.i.cancel(t)),
              ),
            for (final d in done)
              VideoRow(
                d.video,
                extra: '${d.label} · ${fmtBytes(d.bytes)}',
                onTap: () {
                  PlayerCtl.i.loadLocal(d);
                  VideoScreen.open(context);
                },
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('حذف الملف؟'),
                        content: Text(d.video.title),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
                          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('حذف')),
                        ],
                      ),
                    );
                    if (ok != true) return;
                    try {
                      await Native.delete(d.uri);
                    } catch (_) {}
                    Store.i.removeDownload(d.id);
                  },
                ),
              ),
          ]);
        },
      ),
    );
  }
}
