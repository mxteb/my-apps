import 'package:flutter/material.dart';

import '../main.dart';
import '../store.dart';
import '../widgets.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('مكتبتي'),
          bottom: const TabBar(tabs: [Tab(text: 'المفضلة'), Tab(text: 'السجل')]),
        ),
        body: ListenableBuilder(
          listenable: Store.i,
          builder: (context, _) {
            final s = Store.i;
            return TabBarView(children: [
              s.favorites.isEmpty
                  ? const EmptyState(
                      icon: Icons.favorite_border_rounded,
                      title: 'لا توجد مقاطع مفضلة',
                      body: 'اضغط على «المفضلة» في صفحة أي مقطع لحفظه هنا.')
                  : ListView(children: [
                      for (final v in s.favorites)
                        VideoRow(v,
                            onTap: () => openVideo(context, v),
                            trailing: IconButton(
                              icon: const Icon(Icons.favorite_rounded),
                              color: Theme.of(context).colorScheme.primary,
                              onPressed: () => s.toggleFavorite(v),
                            )),
                    ]),
              s.history.isEmpty
                  ? const EmptyState(icon: Icons.history_rounded, title: 'السجل فارغ')
                  : ListView(children: [
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton.icon(
                          icon: const Icon(Icons.delete_sweep_outlined),
                          label: const Text('مسح السجل'),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: const Text('مسح السجل؟'),
                                content: const Text('سيُحذف سجل المشاهدة ومواضع التوقف.'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
                                  FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('مسح')),
                                ],
                              ),
                            );
                            if (ok == true) s.clearHistory();
                          },
                        ),
                      ),
                      for (final v in s.history)
                        Dismissible(
                          key: ValueKey('h${v.id}'),
                          onDismissed: (_) => s.removeHistory(v.id),
                          child: VideoRow(v, onTap: () => openVideo(context, v)),
                        ),
                    ]),
            ]);
          },
        ),
      ),
    );
  }
}
