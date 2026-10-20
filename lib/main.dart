import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/firebase_runtime_config.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/auth_screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? firebaseSetupMessage;
  if (FirebaseRuntimeConfig.isConfigured) {
    try {
      await Firebase.initializeApp(options: FirebaseRuntimeConfig.options);
    } catch (_) {
      firebaseSetupMessage =
          'Không khởi tạo được Firebase. Kiểm tra lại cấu hình Android trong docs/firebase-auth-setup.md.';
    }
  } else {
    firebaseSetupMessage =
        'Chế độ xem trước: chưa có Firebase project. Giao diện đăng nhập, đăng ký và đặt lại mật khẩu đã sẵn sàng; để xác thực thật, làm theo docs/firebase-auth-setup.md.';
  }
  runApp(
    ProviderScope(
      child: SmartTodoApp(firebaseSetupMessage: firebaseSetupMessage),
    ),
  );
}

class SmartTodoApp extends StatelessWidget {
  const SmartTodoApp({required this.firebaseSetupMessage, super.key});

  final String? firebaseSetupMessage;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Todo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3157D5)),
        useMaterial3: true,
      ),
      home: _AuthGate(firebaseSetupMessage: firebaseSetupMessage),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate({required this.firebaseSetupMessage});

  final String? firebaseSetupMessage;

  @override
  Widget build(BuildContext context) {
    final auth = AuthRepository();
    if (firebaseSetupMessage != null) {
      return SignInScreen(
        auth: auth,
        firebaseSetupMessage: firebaseSetupMessage,
      );
    }
    return StreamBuilder<User?>(
      stream: auth.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return SignInScreen(
            auth: auth,
            firebaseSetupMessage:
                'Không đọc được phiên đăng nhập. Kiểm tra kết nối rồi khởi động lại ứng dụng.',
          );
        }
        final user = snapshot.data;
        return user == null
            ? SignInScreen(auth: auth, firebaseSetupMessage: null)
            : SmartTodoHome(user: user, auth: auth);
      },
    );
  }
}

class SmartTodoHome extends StatefulWidget {
  const SmartTodoHome({required this.user, required this.auth, super.key});

  final User user;
  final AuthRepository auth;

  @override
  State<SmartTodoHome> createState() => _SmartTodoHomeState();
}

class _SmartTodoHomeState extends State<SmartTodoHome> {
  bool _signingOut = false;

  final List<_DemoTask> _tasks = [
    _DemoTask(
      title: 'Hoàn thành báo cáo môn học',
      board: 'Đồ án tốt nghiệp',
      due: 'Hôm nay, 17:00',
    ),
    _DemoTask(
      title: 'Ôn tập cấu trúc dữ liệu',
      board: 'Học kỳ 2',
      due: 'Ngày mai',
    ),
    _DemoTask(
      title: 'Họp nhóm thiết kế ứng dụng',
      board: 'Đồ án tốt nghiệp',
      due: 'Thứ Sáu',
    ),
  ];

  Future<void> _addTask() async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thêm công việc'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 200,
          decoration: const InputDecoration(hintText: 'Nhập tên công việc'),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (title == null || title.isEmpty || !mounted) return;
    setState(
      () => _tasks.insert(
        0,
        _DemoTask(title: title, board: 'Cá nhân', due: 'Chưa đặt hạn'),
      ),
    );
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đăng xuất?'),
        content: const Text('Bạn có thể đăng nhập lại bất cứ lúc nào.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ở lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _signingOut = true);
    try {
      await widget.auth.signOut();
    } on AuthFailure catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final completed = _tasks.where((task) => task.completed).length;
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF3157D5)),
            SizedBox(width: 8),
            Text('Smart Todo'),
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
              onPressed: _confirmSignOut,
              icon: const Icon(Icons.logout),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 16,
              child: Text(
                (widget.user.displayName?.isNotEmpty ?? false)
                    ? widget.user.displayName![0].toUpperCase()
                    : (widget.user.email?.isNotEmpty ?? false)
                    ? widget.user.email![0].toUpperCase()
                    : '?',
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
          children: [
            Text(
              'Xin chào ${widget.user.displayName?.isNotEmpty == true ? widget.user.displayName : widget.user.email} 👋',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.black54),
            ),
            const SizedBox(height: 4),
            Text(
              'Kế hoạch hôm nay',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Tiến độ công việc',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text('$completed/${_tasks.length} hoàn thành'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: _tasks.isEmpty ? 0 : completed / _tasks.length,
                    ),
                    const SizedBox(height: 8),
                    const Text('Từng bước nhỏ giúp bạn hoàn thành mục tiêu.'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Công việc của tôi',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _addTask,
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final task in _tasks)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: CheckboxListTile(
                  value: task.completed,
                  onChanged: (value) =>
                      setState(() => task.completed = value ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    task.title,
                    style: TextStyle(
                      decoration: task.completed
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Row(
                      children: [
                        const Icon(Icons.dashboard_outlined, size: 15),
                        const SizedBox(width: 5),
                        Text(task.board),
                        const SizedBox(width: 12),
                        const Icon(Icons.schedule, size: 15),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            task.due,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              'Board gần đây',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.secondaryContainer,
                  child: const Icon(Icons.groups_outlined),
                ),
                title: const Text('Đồ án tốt nghiệp'),
                subtitle: const Text('4 thành viên · cập nhật gần đây'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Board mẫu trong bản demo')),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Khu vực công việc sẽ được triển khai ở UC03–UC08.'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTask,
        icon: const Icon(Icons.add),
        label: const Text('Thêm việc'),
      ),
    );
  }
}

class _DemoTask {
  _DemoTask({required this.title, required this.board, required this.due});

  final String title;
  final String board;
  final String due;
  bool completed = false;
}
