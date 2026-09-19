import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/i18n/i18n.dart';
import '../../../models/app_user.dart';
import '../../../widgets/components/components.dart';
import '../../../widgets/empty_view.dart';
import '../../../widgets/loading_view.dart';
import '../../auth/providers/auth_providers.dart';
import '../../profile/providers/profile_providers.dart';
import '../providers/message_providers.dart';
import 'chat_screen.dart';

/// Starts a new conversation: a direct message, a group, or a broadcast
/// channel. Candidates are people the current user follows.
class NewChatScreen extends ConsumerStatefulWidget {
  const NewChatScreen({super.key});

  @override
  ConsumerState<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends ConsumerState<NewChatScreen> {
  int _tab = 0; // 0 = DM, 1 = group, 2 = broadcast
  final _selected = <String>{};
  final _name = TextEditingController();
  bool _busy = false;

  bool get _multi => _tab != 0;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _startDm(String uid) async {
    final me = ref.read(authStateProvider).valueOrNull?.uid;
    if (me == null) return;
    final chatId = await ref.read(chatRepositoryProvider).openDm(me, uid);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ChatScreen(chatId: chatId)),
    );
  }

  Future<void> _create() async {
    final me = ref.read(authStateProvider).valueOrNull?.uid;
    if (me == null || _selected.isEmpty || _name.text.trim().isEmpty) return;
    setState(() => _busy = true);
    final repo = ref.read(chatRepositoryProvider);
    final chatId = _tab == 1
        ? await repo.createGroup(
            me: me,
            memberIds: _selected.toList(),
            name: _name.text.trim(),
          )
        : await repo.createBroadcast(
            me: me,
            memberIds: _selected.toList(),
            name: _name.text.trim(),
          );
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ChatScreen(chatId: chatId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final following = ref.watch(followingUsersProvider);

    return AppScaffold(
      topBar: AppTopBar(
        title: tr('Tin nhắn mới', 'New message'),
        showBack: true,
        bottom: AppSegmentedTabs(
          index: _tab,
          labels: [
            tr('Trực tiếp', 'Direct'),
            tr('Nhóm', 'Group'),
            tr('Kênh', 'Channel'),
          ],
          onChanged: (i) => setState(() {
            _tab = i;
            _selected.clear();
          }),
        ),
      ),
      body: Column(
        children: [
          if (_multi)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: AppTextField(
                controller: _name,
                label: _tab == 1 ? tr('Tên nhóm', 'Group name') : tr('Tên kênh', 'Channel name'),
                hint: tr('Nhập tên...', 'Enter a name...'),
                icon: _tab == 1 ? Icons.group_rounded : Icons.campaign_rounded,
              ),
            ),
          Expanded(
            child: following.when(
              loading: () => const LoadingView(),
              error: (e, _) => Center(child: Text(tr('Có lỗi xảy ra', 'Something went wrong'))),
              data: (users) {
                if (users.isEmpty) {
                  return EmptyView(
                    message: tr(
                      'Hãy theo dõi ai đó để bắt đầu trò chuyện.',
                      'Follow someone to start chatting.',
                    ),
                    icon: Icons.people_outline_rounded,
                  );
                }
                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (_, i) => _UserRow(
                    user: users[i],
                    multi: _multi,
                    selected: _selected.contains(users[i].uid),
                    onTap: () {
                      if (_multi) {
                        setState(() {
                          _selected.contains(users[i].uid)
                              ? _selected.remove(users[i].uid)
                              : _selected.add(users[i].uid);
                        });
                      } else {
                        _startDm(users[i].uid);
                      }
                    },
                  ),
                );
              },
            ),
          ),
          if (_multi)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: SafeArea(
                top: false,
                child: AppButton(
                  label: _tab == 1
                      ? tr('Tạo nhóm (${_selected.length})', 'Create group (${_selected.length})')
                      : tr('Tạo kênh (${_selected.length})', 'Create channel (${_selected.length})'),
                  isLoading: _busy,
                  onPressed: _selected.isEmpty || _name.text.trim().isEmpty ? null : _create,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({
    required this.user,
    required this.multi,
    required this.selected,
    required this.onTap,
  });

  final AppUser user;
  final bool multi;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppTile(
      onTap: onTap,
      leading: AppAvatar(
        radius: 24,
        imageProvider: user.photoUrl != null
            ? CachedNetworkImageProvider(user.photoUrl!)
            : null,
      ),
      title: user.username.isNotEmpty ? user.username : user.displayName,
      subtitle: user.displayName,
      trailing: multi
          ? Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? AppColors.primary : AppColors.textTertiary,
            )
          : const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
    );
  }
}
