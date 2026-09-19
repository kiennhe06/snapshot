import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:snapshot/core/design/tokens.dart';
import 'package:snapshot/core/i18n/i18n.dart';
import 'package:snapshot/widgets/components/components.dart';
import 'package:snapshot/widgets/loading_view.dart';
import '../../../../models/app_user.dart';
import '../../../profile/providers/profile_providers.dart';

/// Shows a bottom sheet to pick users (from the ones you follow) and returns
/// the selected uid set. Used for tagging people and adding collaborators.
Future<Set<String>?> showUserMultiPicker(
  BuildContext context, {
  required String title,
  Set<String> initial = const {},
}) {
  return showAppSheet<Set<String>>(
    context,
    builder: (_) => _UserMultiPicker(title: title, initial: initial),
  );
}

class _UserMultiPicker extends ConsumerStatefulWidget {
  const _UserMultiPicker({required this.title, required this.initial});
  final String title;
  final Set<String> initial;

  @override
  ConsumerState<_UserMultiPicker> createState() => _UserMultiPickerState();
}

class _UserMultiPickerState extends ConsumerState<_UserMultiPicker> {
  late final Set<String> _selected = {...widget.initial};
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(
      () => setState(() => _query = _searchController.text.toLowerCase()),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(followingUsersProvider);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: AppSheetSurface(
        title: widget.title,
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: AppTextField(
                  controller: _searchController,
                  label: tr('Tìm kiếm', 'Search'),
                  hint: tr('Tìm theo tên/username', 'Search by name/username'),
                  icon: Icons.search_rounded,
                ),
              ),
              Expanded(
                child: usersAsync.when(
                  loading: () => const LoadingView(),
                  error: (_, _) => Center(
                    child: Text(
                      tr(
                        'Không tải được danh sách.',
                        'Could not load the list.',
                      ),
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: AppType.subhead,
                      ),
                    ),
                  ),
                  data: (users) {
                    final filtered = users
                        .where(
                          (u) =>
                              u.username.toLowerCase().contains(_query) ||
                              u.displayName.toLowerCase().contains(_query),
                        )
                        .toList();
                    if (filtered.isEmpty) {
                      return Center(
                        child: Text(
                          tr(
                            'Bạn chưa theo dõi ai để chọn.',
                            'You are not following anyone to pick.',
                          ),
                          style: TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: AppType.subhead,
                          ),
                        ),
                      );
                    }
                    return ListView(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      children: filtered.map(_tile).toList(),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: AppButton(
                  label: tr(
                    'Xong (${_selected.length})',
                    'Done (${_selected.length})',
                  ),
                  height: 48,
                  onPressed: () => Navigator.pop(context, _selected),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(AppUser u) {
    final selected = _selected.contains(u.uid);
    return AppTile(
      leading: AppAvatar(
        imageProvider: u.photoUrl != null
            ? CachedNetworkImageProvider(u.photoUrl!)
            : null,
        radius: 22,
      ),
      title: u.displayName,
      subtitle: '@${u.username}',
      trailing: Icon(
        selected
            ? Icons.check_circle_rounded
            : Icons.radio_button_unchecked_rounded,
        color: selected ? AppColors.primary : AppColors.textTertiary,
        size: AppIconSize.lg,
      ),
      onTap: () => setState(() {
        if (selected) {
          _selected.remove(u.uid);
        } else {
          _selected.add(u.uid);
        }
      }),
    );
  }
}
