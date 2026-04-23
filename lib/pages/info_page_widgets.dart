part of 'info_page.dart';

Widget _buildInfoPageView(_InfoPageState state, BuildContext context) {
  final theme = FluentTheme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final refreshSnapshot = state._refreshService.snapshot;

  return ScaffoldPage(
    header: const PageHeader(title: Text('信息中心')),
    content: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          state._buildActionBar(theme),
          if (refreshSnapshot.isRefreshing) ...[
            const SizedBox(height: FluentSpacing.s),
            state._buildRefreshProgress(theme),
          ],
          const SizedBox(height: FluentSpacing.m),
          state._buildSearchBar(theme),
          const SizedBox(height: FluentSpacing.s),
          state
              ._buildFilterBar(theme, isDark)
              .animate()
              .fadeIn(
                duration: FluentDuration.slow,
                curve: FluentEasing.decelerate,
              ),
          const SizedBox(height: FluentSpacing.m),
          Expanded(
            child:
                refreshSnapshot.isRefreshing && state._filteredMessages.isEmpty
                ? const Center(child: ProgressRing())
                : state._filteredMessages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          FluentIcons.inbox,
                          size: 48,
                          color: theme.resources.textFillColorSecondary,
                        ),
                        const SizedBox(height: FluentSpacing.m),
                        Text(
                          '暂无消息',
                          style: theme.typography.body?.copyWith(
                            color: theme.resources.textFillColorSecondary,
                          ),
                        ),
                        const SizedBox(height: FluentSpacing.s),
                        Text(
                          '点击上方刷新按钮获取最新消息',
                          style: theme.typography.caption?.copyWith(
                            color: theme.resources.textFillColorSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : state._buildMessageList(theme, isDark),
          ),
          if (state._filteredMessages.isNotEmpty) ...[
            const SizedBox(height: FluentSpacing.s),
            state._buildPagination(theme),
            const SizedBox(height: FluentSpacing.m),
          ],
        ],
      ),
    ),
  );
}

Widget _buildInfoActionBar(_InfoPageState state, FluentThemeData theme) {
  final unreadCount = state._stateService.countUnread(
    state._filteredMessages.map((msg) => msg.id).toList(),
  );

  return Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      FilledButton(
        onPressed: state._filteredMessages.isEmpty ? null : state._markAllRead,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(FluentIcons.read, size: 14),
            const SizedBox(width: FluentSpacing.xs + FluentSpacing.xxs),
            Text('全部标为已读${unreadCount > 0 ? ' ($unreadCount)' : ''}'),
          ],
        ),
      ),
      Button(
        onPressed: state._refreshService.isRefreshing
            ? null
            : () => state._refreshSchoolWebsite(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state._refreshService.isRefreshingSchoolWebsite)
              const SizedBox(
                width: 14,
                height: 14,
                child: ProgressRing(strokeWidth: 2),
              )
            else
              const Icon(FluentIcons.refresh, size: 14),
            const SizedBox(width: FluentSpacing.xs + FluentSpacing.xxs),
            const Text('刷新官网消息'),
          ],
        ),
      ),
      Button(
        onPressed:
            state._refreshService.isRefreshing || !state._wechatSourceConfigured
            ? null
            : state._refreshWechatArticles,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state._refreshService.isRefreshingWechat)
              const SizedBox(
                width: 14,
                height: 14,
                child: ProgressRing(strokeWidth: 2),
              )
            else
              const Icon(FluentIcons.refresh, size: 14),
            const SizedBox(width: FluentSpacing.xs + FluentSpacing.xxs),
            const Text('刷新最新微信推文'),
          ],
        ),
      ),
    ],
  );
}

Widget _buildInfoRefreshProgress(_InfoPageState state, FluentThemeData theme) {
  final snapshot = state._refreshService.snapshot;
  final progressValue = snapshot.total <= 0
      ? null
      : (snapshot.completed / snapshot.total * 100).clamp(0.0, 100.0);

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(FluentSpacing.s),
    decoration: BoxDecoration(
      color: theme.inactiveColor.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProgressBar(value: progressValue),
        const SizedBox(height: FluentSpacing.xs),
        Text(
          snapshot.text.isEmpty ? '正在刷新...' : snapshot.text,
          style: theme.typography.caption,
        ),
      ],
    ),
  );
}

Widget _buildInfoSearchBar(_InfoPageState state, FluentThemeData theme) {
  return TextBox(
    controller: state._searchController,
    placeholder: '搜索消息标题…',
    prefix: const Padding(
      padding: EdgeInsets.only(left: 8.0),
      child: Icon(FluentIcons.search, size: 14),
    ),
    suffix: state._searchQuery.isNotEmpty
        ? IconButton(
            icon: const Icon(FluentIcons.clear, size: 12),
            onPressed: () {
              state._searchController.clear();
              state._searchQuery = '';
              state._applyFilters();
            },
          )
        : null,
    onChanged: (value) {
      state._searchQuery = value;
      state._applyFilters();
    },
  );
}

Widget _buildInfoFilterBar(
  _InfoPageState state,
  FluentThemeData theme,
  bool isDark,
) {
  final availableSourceNames = state._getAvailableSourceNames();
  final availableCategories = state._getAvailableCategories();

  return Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      state._buildFilterCombo<MessageSourceType>(
        label: '来源类型',
        value: state._filterSourceType,
        items: const [
          MessageSourceType.schoolWebsite,
          MessageSourceType.wechatPublic,
        ],
        itemLabel: (item) => item.label,
        onChanged: (value) {
          state._filterSourceType = value;
          state._filterSourceName = null;
          state._filterCategory = null;
          state._applyFilters();
        },
      ),
      state._buildFilterCombo<MessageSourceName>(
        label: '来源名称',
        value: state._filterSourceName,
        items: availableSourceNames,
        itemLabel: (item) => item.label,
        enabled: state._filterSourceType != null,
        onChanged: (value) {
          state._filterSourceName = value;
          state._filterCategory = null;
          state._applyFilters();
        },
      ),
      state._buildFilterCombo<MessageCategory>(
        label: '内容分类',
        value: state._filterCategory,
        items: availableCategories,
        itemLabel: (item) => item.label,
        enabled: state._filterSourceName != null,
        onChanged: (value) {
          state._filterCategory = value;
          state._applyFilters();
        },
      ),
      ToggleSwitch(
        checked: state._filterUnreadOnly,
        content: const Text('仅未读'),
        onChanged: (value) {
          state._filterUnreadOnly = value;
          state._applyFilters();
        },
      ),
    ],
  );
}

Widget _buildInfoFilterCombo<T>({
  required String label,
  required T? value,
  required List<T> items,
  required String Function(T) itemLabel,
  required void Function(T?) onChanged,
  bool enabled = true,
}) {
  return ComboBox<T?>(
    value: value,
    placeholder: Text(label),
    items: [
      ComboBoxItem<T?>(value: null, child: Text('全部$label')),
      ...items.map(
        (item) => ComboBoxItem<T?>(value: item, child: Text(itemLabel(item))),
      ),
    ],
    onChanged: enabled ? (selectedValue) => onChanged(selectedValue) : null,
  );
}

Widget _buildInfoMessageList(
  _InfoPageState state,
  FluentThemeData theme,
  bool isDark,
) {
  final messages = state._pagedMessages;

  return ListView.separated(
    itemCount: messages.length,
    separatorBuilder: (_, _) => const Divider(),
    itemBuilder: (context, index) {
      final message = messages[index];
      final isRead = state._stateService.isRead(message.id);

      return MessageTile(
        message: message,
        isRead: isRead,
        isDark: isDark,
        theme: theme,
        onTap: () => state._openMessage(message),
        onMarkRead: () async {
          await state._stateService.markAsRead(message.id);
          state._refreshView();
        },
      );
    },
  );
}

Widget _buildInfoPagination(_InfoPageState state, FluentThemeData theme) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      IconButton(
        icon: const Icon(FluentIcons.chevron_left, size: 12),
        onPressed: state._currentPage > 0
            ? () => state._setCurrentPage(state._currentPage - 1)
            : null,
      ),
      const SizedBox(width: FluentSpacing.s),
      Tooltip(
        message: '点击跳转到指定页',
        child: HoverButton(
          onPressed: () => state._showPageJumpDialog(),
          builder: (context, states) {
            return Text(
              '第 ${state._currentPage + 1} / ${state._totalPages} 页  '
              '(共 ${state._filteredMessages.length} 条)',
              style: theme.typography.caption?.copyWith(
                decoration: states.isHovered
                    ? TextDecoration.underline
                    : TextDecoration.none,
              ),
            );
          },
        ),
      ),
      const SizedBox(width: FluentSpacing.s),
      IconButton(
        icon: const Icon(FluentIcons.chevron_right, size: 12),
        onPressed: state._currentPage < state._totalPages - 1
            ? () => state._setCurrentPage(state._currentPage + 1)
            : null,
      ),
    ],
  );
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
