part of 'info_page.dart';

Future<int?> _showInfoFetchCountDialog(_InfoPageState state) async {
  final controller = TextEditingController();
  final result = await showDialog<int?>(
    context: state.context,
    builder: (dialogContext) {
      return ContentDialog(
        title: const Text('获取消息条数'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('输入每个栏目要获取的消息条数，留空默认 20 条。'),
            const SizedBox(height: FluentSpacing.m),
            TextBox(
              controller: controller,
              placeholder: '20',
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          Button(
            child: const Text('取消'),
            onPressed: () => Navigator.pop(dialogContext, null),
          ),
          FilledButton(
            child: const Text('确认'),
            onPressed: () {
              final text = controller.text.trim();
              final count = text.isEmpty ? 20 : (int.tryParse(text) ?? 20);
              Navigator.pop(dialogContext, count.clamp(1, 200));
            },
          ),
        ],
      );
    },
  );
  controller.dispose();
  return result;
}

Future<void> _showInfoPageJumpDialog(_InfoPageState state) async {
  final controller = TextEditingController();
  final result = await showDialog<int>(
    context: state.context,
    builder: (ctx) => ContentDialog(
      title: const Text('跳转到指定页'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('当前第 ${state._currentPage + 1} 页，共 ${state._totalPages} 页'),
          const SizedBox(height: FluentSpacing.s),
          TextBox(
            controller: controller,
            placeholder: '输入页码 (1-${state._totalPages})',
            keyboardType: TextInputType.number,
            autofocus: true,
            onSubmitted: (_) {
              final page = int.tryParse(controller.text);
              if (page != null && page >= 1 && page <= state._totalPages) {
                Navigator.of(ctx).pop(page - 1);
              }
            },
          ),
        ],
      ),
      actions: [
        Button(
          child: const Text('取消'),
          onPressed: () => Navigator.of(ctx).pop(),
        ),
        FilledButton(
          child: const Text('跳转'),
          onPressed: () {
            final page = int.tryParse(controller.text);
            if (page != null && page >= 1 && page <= state._totalPages) {
              Navigator.of(ctx).pop(page - 1);
            }
          },
        ),
      ],
    ),
  );
  controller.dispose();

  if (result != null && state.mounted) {
    state._setCurrentPage(result);
  }
}
