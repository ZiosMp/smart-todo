
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../auth/data/auth_repository.dart';
import '../data/boards_repository.dart';

class BoardsScreen extends StatefulWidget {
  const BoardsScreen({required this.user, required this.auth, super.key});

  final User user;
  final AuthRepository auth;

  @override
  State<BoardsScreen> createState() => _BoardsScreenState();
}

class _BoardsScreenState extends State<BoardsScreen> {
  late final BoardsRepository _repository;
  late final Stream<List<BoardSummary>> _boardsStream;
  bool _creatingBoard = false;
  bool _signingOut = false;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _repository = BoardsRepository();
    _boardsStream = _repository.watchMyActiveBoards(widget.user.uid);
  }

  Future<void> _createBoard() async {
    // Controllers belong to this State, so they stay alive until the screen is disposed.
    // Reset their values whenever the create dialog is opened.
    _nameController.clear();
    _descriptionController.clear();
    String? dialogError;

    final formData = await showDialog<({String name, String description})>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Tạo board mới'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameController,
                  autofocus: true,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    labelText: 'Tên board *',
                    hintText: 'Ví dụ: Đồ án môn học',
                  ),
                ),
                TextField(
                  controller: _descriptionController,
                  maxLength: 500,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Mô tả (không bắt buộc)',
                  ),
                ),
                if (dialogError != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      dialogError!,
                      style: TextStyle(
                        color: Theme.of(dialogContext).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                final name = _nameController.text.trim();
                final description = _descriptionController.text.trim();
                if (name.isEmpty) {
                  setDialogState(() => dialogError = 'Bạn cần nhập tên board.');
                  return;
                }
                if (name.length > 100) {
                  setDialogState(() => dialogError = 'Tên tối đa 100 ký tự.');
                  return;
                }
                if (description.length > 500) {
                  setDialogState(
                    () => dialogError = 'Mô tả tối đa 500 ký tự.',
                  );
                  return;
                }
                Navigator.of(dialogContext).pop((
                  name: name,
                  description: description,
                ));
              },
              child: const Text('Tạo board'),
            ),
          ],
        ),
      ),
    );

    // Do not dispose controllers here: the dialog's reverse transition may still
    // rebuild its TextFields after showDialog completes. They are disposed with this State.
    if (formData == null || !mounted) return;

    setState(() => _creatingBoard = true);
    try {
      await _repository.createBoard(
        name: formData.name,
        description: formData.description,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã tạo board và lưu vào Firestore.')),
        );
      }
    } on FirebaseException catch (error) {
      if (mounted) {
        final detail = error.code == 'permission-denied'
            ? 'Firestore từ chối thao tác. Hãy kiểm tra Security Rules và tài khoản đăng nhập.'
            : 'Không tạo được board: ${error.message ?? error.code}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(detail)),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không tạo được board: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _creatingBoard = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    try {
      await widget.auth.signOut();
    } on AuthFailure catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.user.displayName?.trim().isNotEmpty == true
        ? widget.user.displayName!.trim()
        : widget.user.email ?? 'bạn';

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF3157D5)),
            SizedBox(width: 8),
            Text('Smart Todo · Board'),
          ],
        ),
        actions: [
          if (_signingOut)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              tooltip: 'Đăng xuất',
              onPressed: _signOut,
              icon: const Icon(Icons.logout),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              child: Text(displayName.isEmpty ? '?' : displayName[0].toUpperCase()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<BoardSummary>>(
          stream: _boardsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _MessageState(
                icon: Icons.cloud_off_outlined,
                title: 'Không đọc được board từ Firestore',
                message: 'Kiểm tra Emulator, tài khoản đăng nhập và Security Rules.\n\n${snapshot.error}',
                actionLabel: 'Thử tải lại',
                onAction: () => setState(() {
                  _boardsStream = _repository.watchMyActiveBoards(widget.user.uid);
                }),
              );
            }

            final boards = snapshot.data ?? const <BoardSummary>[];
            if (boards.isEmpty) {
              return _MessageState(
                icon: Icons.dashboard_outlined,
                title: 'Chưa có board nào',
                message: 'Hãy tạo board đầu tiên. Board sẽ được lưu vào Firestore Emulator và cập nhật trực tiếp tại đây.',
                actionLabel: 'Tạo board đầu tiên',
                onAction: _creatingBoard ? null : _createBoard,
                loading: _creatingBoard,
              );
            }

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Xin chào $displayName 👋',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Board của tôi',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text('Dữ liệu đang được đọc trực tiếp từ Cloud Firestore.'),
                const SizedBox(height: 18),
                for (final board in boards)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.dashboard_outlined),
                      ),
                      title: Text(board.name),
                      subtitle: Text(
                        board.description.isEmpty
                            ? '${board.memberIds.length} thành viên'
                            : '${board.description}\n${board.memberIds.length} thành viên',
                      ),
                      isThreeLine: board.description.isNotEmpty,
                      trailing: const Icon(Icons.cloud_done_outlined),
                    ),
                  ),
                const SizedBox(height: 80),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _creatingBoard ? null : _createBoard,
        icon: _creatingBoard
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),
        label: Text(_creatingBoard ? 'Đang tạo...' : 'Tạo board'),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.loading = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback? onAction;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 58, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onAction,
                icon: loading
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: Text(loading ? 'Đang xử lý...' : actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
