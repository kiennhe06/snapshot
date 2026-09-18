import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/app_user.dart';
import '../../../profile/providers/profile_providers.dart';

/// Shows a bottom sheet to pick users (from the ones you follow) and returns
/// the selected uid set. Used for tagging people and adding collaborators.
Future<Set<String>?> showUserMultiPicker(
  BuildContext context, {
  required String title,
  Set<String> initial = const {},
}) {
  return showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
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
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(followingUsersProvider);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Tìm theo tên/username',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _query = v.toLowerCase()),
                ),
              ),
              Expanded(
                child: usersAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) =>
                      const Center(child: Text('Không tải được danh sách.')),
                  data: (users) {
                    final filtered = users
                        .where(
                          (u) =>
                              u.username.toLowerCase().contains(_query) ||
                              u.displayName.toLowerCase().contains(_query),
                        )
                        .toList();
                    if (filtered.isEmpty) {
                      return const Center(
                        child: Text('Bạn chưa theo dõi ai để chọn.'),
                      );
                    }
                    return ListView(children: filtered.map(_tile).toList());
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, _selected),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text('Xong (${_selected.length})'),
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
    return CheckboxListTile(
      value: selected,
      onChanged: (_) => setState(() {
        if (selected) {
          _selected.remove(u.uid);
        } else {
          _selected.add(u.uid);
        }
      }),
      secondary: CircleAvatar(
        backgroundImage: u.photoUrl != null
            ? CachedNetworkImageProvider(u.photoUrl!)
            : null,
        child: u.photoUrl == null ? const Icon(Icons.person) : null,
      ),
      title: Text(u.displayName),
      subtitle: Text('@${u.username}'),
    );
  }
}
