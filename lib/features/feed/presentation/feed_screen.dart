import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/constants.dart';
import '../../../core/design/tokens.dart';
import '../../../widgets/components/app_scaffold.dart';
import '../../../widgets/components/app_top_bar.dart';
import '../../../widgets/components/press_scale.dart';
import '../../../widgets/empty_view.dart';
import '../../../widgets/loading_view.dart';
import '../providers/feed_providers.dart';
import 'widgets/post_card.dart';

/// Home feed with two custom segments: chronological "Đang theo dõi" and
/// "Yêu thích".
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      topBar: AppTopBar(
        titleWidget: Text('Snapshot', style: brandWordmark(context, size: 26)),
        actions: [
          AppIconButton(
            icon: Icons.add_box_outlined,
            tooltip: 'Đăng bài',
            onTap: () => context.push(Routes.createPost),
          ),
        ],
        bottom: _SegmentedTabs(
          index: _tab,
          labels: const ['Đang theo dõi', 'Yêu thích'],
          onChanged: (i) => setState(() => _tab = i),
        ),
      ),
      body: IndexedStack(
        index: _tab,
        children: const [
          _FeedList(kind: FeedKind.following),
          _FeedList(kind: FeedKind.favorites),
        ],
      ),
    );
  }
}

/// Custom pill segmented control (replaces Material TabBar).
class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({
    required this.index,
    required this.labels,
    required this.onChanged,
  });

  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.md,
      ),
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.layer1,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final active = i == index;
          return Expanded(
            child: PressScale(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: AppMotion.base,
                curve: AppMotion.standard,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  gradient: active ? AppGradients.elevated : null,
                  borderRadius: AppRadius.brMd,
                  boxShadow: active ? AppShadows.soft : null,
                ),
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: active
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontSize: AppType.body,
                    fontWeight: active ? AppType.bold : AppType.medium,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _FeedList extends ConsumerStatefulWidget {
  const _FeedList({required this.kind});
  final FeedKind kind;

  @override
  ConsumerState<_FeedList> createState() => _FeedListState();
}

class _FeedListState extends ConsumerState<_FeedList>
    with AutomaticKeepAliveClientMixin {
  final _scroll = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      ref.read(feedControllerProvider(widget.kind).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = ref.watch(feedControllerProvider(widget.kind));

    if (!state.initialized && state.isLoading) {
      return const LoadingView();
    }
    if (state.posts.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.layer2,
        onRefresh: () =>
            ref.read(feedControllerProvider(widget.kind).notifier).refresh(),
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.55,
              child: EmptyView(
                message: widget.kind == FeedKind.favorites
                    ? 'Chưa có bài viết từ danh sách Yêu thích.\nThêm người vào Yêu thích từ menu bài viết.'
                    : 'Chưa có bài viết.\nHãy theo dõi thêm người hoặc đăng bài.',
                icon: widget.kind == FeedKind.favorites
                    ? Icons.star_rounded
                    : Icons.dynamic_feed_rounded,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.layer2,
      onRefresh: () =>
          ref.read(feedControllerProvider(widget.kind).notifier).refresh(),
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.only(
          top: AppSpacing.xs,
          bottom: AppSpacing.xl,
        ),
        itemCount: state.posts.length + 1,
        itemBuilder: (_, i) {
          if (i == state.posts.length) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: state.hasMore
                    ? const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.primary,
                        ),
                      )
                    : Text(
                        'Đã hết bài viết',
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: AppType.label,
                        ),
                      ),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: PostCard(post: state.posts[i]),
          );
        },
      ),
    );
  }
}
