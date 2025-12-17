import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../db/database.dart';
import '../../providers/app_providers.dart';

enum PomodoroState { idle, running, paused }

enum SessionType { work, shortBreak, longBreak }

class PomodoroScreen extends ConsumerStatefulWidget {
  const PomodoroScreen({super.key});

  @override
  ConsumerState<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends ConsumerState<PomodoroScreen>
    with TickerProviderStateMixin {
  PomodoroState _state = PomodoroState.idle;
  SessionType _sessionType = SessionType.work;
  int _completedPomodoros = 0;

  // Timer values
  int _workDuration = 25;
  int _shortBreakDuration = 5;
  int _longBreakDuration = 15;
  int _sessionsBeforeLongBreak = 4;
  bool _autoStartBreaks = false;
  bool _autoStartWork = false;

  // Current timer
  int _remainingSeconds = 25 * 60;
  Timer? _timer;

  // Task name
  final _taskController = TextEditingController();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _taskController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settings = await ref.read(pomodoroSettingsProvider.future);
    if (settings != null) {
      setState(() {
        _workDuration = settings.workDuration;
        _shortBreakDuration = settings.shortBreakDuration;
        _longBreakDuration = settings.longBreakDuration;
        _sessionsBeforeLongBreak = settings.sessionsBeforeLongBreak;
        _autoStartBreaks = settings.autoStartBreaks;
        _autoStartWork = settings.autoStartWork;
        _remainingSeconds = _workDuration * 60;
      });
    }

    final completed = await ref.read(completedPomodorosTodayProvider.future);
    setState(() => _completedPomodoros = completed);
  }

  int get _currentDuration {
    switch (_sessionType) {
      case SessionType.work:
        return _workDuration;
      case SessionType.shortBreak:
        return _shortBreakDuration;
      case SessionType.longBreak:
        return _longBreakDuration;
    }
  }

  void _startTimer() {
    setState(() => _state = PomodoroState.running);
    _pulseController.repeat(reverse: true);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _onTimerComplete();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    _pulseController.stop();
    setState(() => _state = PomodoroState.paused);
  }

  void _resetTimer() {
    _timer?.cancel();
    _pulseController.stop();
    _pulseController.reset();
    setState(() {
      _state = PomodoroState.idle;
      _remainingSeconds = _currentDuration * 60;
    });
  }

  Future<void> _onTimerComplete() async {
    _timer?.cancel();
    _pulseController.stop();
    _pulseController.reset();

    // Save session if it was a work session
    if (_sessionType == SessionType.work) {
      await _saveSession();
      setState(() => _completedPomodoros++);
    }

    // Determine next session type
    if (_sessionType == SessionType.work) {
      if (_completedPomodoros % _sessionsBeforeLongBreak == 0) {
        _switchToSession(SessionType.longBreak);
      } else {
        _switchToSession(SessionType.shortBreak);
      }
      if (_autoStartBreaks) {
        _startTimer();
      }
    } else {
      _switchToSession(SessionType.work);
      if (_autoStartWork) {
        _startTimer();
      }
    }

    // Show completion dialog
    if (mounted) {
      _showCompletionDialog();
    }
  }

  void _switchToSession(SessionType type) {
    setState(() {
      _sessionType = type;
      _state = PomodoroState.idle;
      _remainingSeconds = _currentDuration * 60;
    });
  }

  Future<void> _saveSession() async {
    final db = ref.read(databaseProvider);
    final user = await db.getUser();
    if (user == null) return;

    await db.insertPomodoroSession(
      PomodoroSessionsCompanion.insert(
        userId: user.id,
        durationMinutes: _workDuration,
        sessionType: 'work',
        taskName: drift.Value(
          _taskController.text.isNotEmpty ? _taskController.text : null,
        ),
        completed: const drift.Value(true),
        completedAt: drift.Value(DateTime.now()),
      ),
    );

    ref.invalidate(todayPomodoroSessionsProvider);
    ref.invalidate(completedPomodorosTodayProvider);
    ref.invalidate(totalFocusMinutesTodayProvider);
  }

  void _showCompletionDialog() {
    final isBreak = _sessionType != SessionType.work;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isBreak ? Icons.coffee : Icons.celebration,
              color: isBreak ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 8),
            Text(isBreak ? 'Break Time!' : 'Session Complete!'),
          ],
        ),
        content: Text(
          isBreak
              ? 'Great work! Take a ${_sessionType == SessionType.longBreak ? "long" : "short"} break.'
              : 'You completed a focus session! Ready to work again?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    int tempWork = _workDuration;
    int tempShort = _shortBreakDuration;
    int tempLong = _longBreakDuration;
    int tempSessions = _sessionsBeforeLongBreak;
    bool tempAutoBreaks = _autoStartBreaks;
    bool tempAutoWork = _autoStartWork;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Pomodoro Settings'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSlider(
                  'Work Duration',
                  tempWork,
                  5,
                  60,
                  (val) => setDialogState(() => tempWork = val),
                  suffix: 'min',
                ),
                _buildSlider(
                  'Short Break',
                  tempShort,
                  1,
                  15,
                  (val) => setDialogState(() => tempShort = val),
                  suffix: 'min',
                ),
                _buildSlider(
                  'Long Break',
                  tempLong,
                  5,
                  30,
                  (val) => setDialogState(() => tempLong = val),
                  suffix: 'min',
                ),
                _buildSlider(
                  'Sessions before long break',
                  tempSessions,
                  2,
                  8,
                  (val) => setDialogState(() => tempSessions = val),
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('Auto-start breaks'),
                  value: tempAutoBreaks,
                  onChanged: (val) =>
                      setDialogState(() => tempAutoBreaks = val),
                ),
                SwitchListTile(
                  title: const Text('Auto-start work'),
                  value: tempAutoWork,
                  onChanged: (val) => setDialogState(() => tempAutoWork = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _saveSettings(
                  tempWork,
                  tempShort,
                  tempLong,
                  tempSessions,
                  tempAutoBreaks,
                  tempAutoWork,
                );
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider(
    String label,
    int value,
    int min,
    int max,
    Function(int) onChanged, {
    String? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label),
              Text(
                '$value${suffix != null ? ' $suffix' : ''}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            onChanged: (val) => onChanged(val.round()),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSettings(
    int work,
    int shortBreak,
    int longBreak,
    int sessions,
    bool autoBreaks,
    bool autoWork,
  ) async {
    final db = ref.read(databaseProvider);
    final user = await db.getUser();
    if (user == null) return;

    final existing = await db.getPomodoroSettings(user.id);
    if (existing != null) {
      await db.updatePomodoroSettings(
        PomodoroSetting(
          id: existing.id,
          userId: user.id,
          workDuration: work,
          shortBreakDuration: shortBreak,
          longBreakDuration: longBreak,
          sessionsBeforeLongBreak: sessions,
          autoStartBreaks: autoBreaks,
          autoStartWork: autoWork,
          updatedAt: DateTime.now(),
        ),
      );
    } else {
      await db.insertPomodoroSettings(
        PomodoroSettingsCompanion.insert(
          userId: user.id,
          workDuration: drift.Value(work),
          shortBreakDuration: drift.Value(shortBreak),
          longBreakDuration: drift.Value(longBreak),
          sessionsBeforeLongBreak: drift.Value(sessions),
          autoStartBreaks: drift.Value(autoBreaks),
          autoStartWork: drift.Value(autoWork),
        ),
      );
    }

    setState(() {
      _workDuration = work;
      _shortBreakDuration = shortBreak;
      _longBreakDuration = longBreak;
      _sessionsBeforeLongBreak = sessions;
      _autoStartBreaks = autoBreaks;
      _autoStartWork = autoWork;
      if (_state == PomodoroState.idle) {
        _remainingSeconds = _currentDuration * 60;
      }
    });

    ref.invalidate(pomodoroSettingsProvider);
  }

  void _showHistorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          final sessionsAsync = ref.watch(todayPomodoroSessionsProvider);
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade600,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Today\'s Sessions',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: sessionsAsync.when(
                    data: (sessions) {
                      if (sessions.isEmpty) {
                        return const Center(
                          child: Text('No sessions today. Start focusing!'),
                        );
                      }
                      return ListView.builder(
                        controller: scrollController,
                        itemCount: sessions.length,
                        itemBuilder: (context, index) {
                          final session = sessions[index];
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: session.completed
                                    ? Colors.green.shade100
                                    : Colors.orange.shade100,
                                child: Icon(
                                  session.completed
                                      ? Icons.check
                                      : Icons.timer_off,
                                  color: session.completed
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                              ),
                              title: Text(
                                session.taskName ?? 'Focus Session',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '${session.durationMinutes} min • ${_formatTime(session.startedAt)}',
                              ),
                              trailing: session.completed
                                  ? const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                    )
                                  : null,
                            ),
                          );
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Color get _sessionColor {
    switch (_sessionType) {
      case SessionType.work:
        return Colors.red;
      case SessionType.shortBreak:
        return Colors.green;
      case SessionType.longBreak:
        return Colors.blue;
    }
  }

  String get _sessionLabel {
    switch (_sessionType) {
      case SessionType.work:
        return 'Focus Time';
      case SessionType.shortBreak:
        return 'Short Break';
      case SessionType.longBreak:
        return 'Long Break';
    }
  }

  IconData get _sessionIcon {
    switch (_sessionType) {
      case SessionType.work:
        return Icons.work;
      case SessionType.shortBreak:
        return Icons.coffee;
      case SessionType.longBreak:
        return Icons.self_improvement;
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = 1 - (_remainingSeconds / (_currentDuration * 60));
    final totalMinutesAsync = ref.watch(totalFocusMinutesTodayProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pomodoro Timer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: _showHistorySheet,
            tooltip: 'Session History',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_sessionColor.withOpacity(0.1), Colors.transparent],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Stats bar
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade800.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatItem(
                      icon: Icons.local_fire_department,
                      label: 'Pomodoros',
                      value: '$_completedPomodoros',
                      color: Colors.orange,
                    ),
                    totalMinutesAsync.when(
                      data: (minutes) => _StatItem(
                        icon: Icons.timer,
                        label: 'Focus Time',
                        value: '${minutes}m',
                        color: Colors.blue,
                      ),
                      loading: () => const _StatItem(
                        icon: Icons.timer,
                        label: 'Focus Time',
                        value: '...',
                        color: Colors.blue,
                      ),
                      error: (_, __) => const _StatItem(
                        icon: Icons.timer,
                        label: 'Focus Time',
                        value: '0m',
                        color: Colors.blue,
                      ),
                    ),
                    _StatItem(
                      icon: Icons.flag,
                      label: 'Goal',
                      value: '$_sessionsBeforeLongBreak',
                      color: Colors.green,
                    ),
                  ],
                ),
              ),

              // Session type indicator
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _sessionColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_sessionIcon, color: _sessionColor),
                    const SizedBox(width: 8),
                    Text(
                      _sessionLabel,
                      style: TextStyle(
                        color: _sessionColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Timer circle
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _state == PomodoroState.running
                        ? _pulseAnimation.value
                        : 1.0,
                    child: child,
                  );
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 280,
                      height: 280,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 12,
                        backgroundColor: Colors.grey.shade800,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _sessionColor,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatDuration(_remainingSeconds),
                          style: const TextStyle(
                            fontSize: 64,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                        Text(
                          _state == PomodoroState.running
                              ? 'In Progress'
                              : _state == PomodoroState.paused
                              ? 'Paused'
                              : 'Ready',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Task input
              if (_sessionType == SessionType.work)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: TextField(
                    controller: _taskController,
                    decoration: InputDecoration(
                      hintText: 'What are you working on?',
                      prefixIcon: const Icon(Icons.edit_note),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade800.withOpacity(0.5),
                    ),
                    textAlign: TextAlign.center,
                    enabled: _state == PomodoroState.idle,
                  ),
                ),

              const SizedBox(height: 24),

              // Control buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_state != PomodoroState.idle)
                    FloatingActionButton(
                      heroTag: 'reset',
                      onPressed: _resetTimer,
                      backgroundColor: Colors.grey.shade700,
                      child: const Icon(Icons.refresh),
                    ),
                  const SizedBox(width: 16),
                  FloatingActionButton.large(
                    heroTag: 'main',
                    onPressed: _state == PomodoroState.running
                        ? _pauseTimer
                        : _startTimer,
                    backgroundColor: _sessionColor,
                    child: Icon(
                      _state == PomodoroState.running
                          ? Icons.pause
                          : Icons.play_arrow,
                      size: 36,
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (_state == PomodoroState.idle)
                    FloatingActionButton(
                      heroTag: 'skip',
                      onPressed: () {
                        if (_sessionType == SessionType.work) {
                          _switchToSession(
                            _completedPomodoros % _sessionsBeforeLongBreak == 0
                                ? SessionType.longBreak
                                : SessionType.shortBreak,
                          );
                        } else {
                          _switchToSession(SessionType.work);
                        }
                      },
                      backgroundColor: Colors.grey.shade700,
                      child: const Icon(Icons.skip_next),
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // Session type buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Row(
                  children: [
                    Expanded(
                      child: _SessionTypeButton(
                        label: 'Focus',
                        isSelected: _sessionType == SessionType.work,
                        color: Colors.red,
                        onTap: _state == PomodoroState.idle
                            ? () => _switchToSession(SessionType.work)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SessionTypeButton(
                        label: 'Short',
                        isSelected: _sessionType == SessionType.shortBreak,
                        color: Colors.green,
                        onTap: _state == PomodoroState.idle
                            ? () => _switchToSession(SessionType.shortBreak)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SessionTypeButton(
                        label: 'Long',
                        isSelected: _sessionType == SessionType.longBreak,
                        color: Colors.blue,
                        onTap: _state == PomodoroState.idle
                            ? () => _switchToSession(SessionType.longBreak)
                            : null,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
        ),
      ],
    );
  }
}

class _SessionTypeButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback? onTap;

  const _SessionTypeButton({
    required this.label,
    required this.isSelected,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : Colors.grey.shade600),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? color : Colors.grey.shade400,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
