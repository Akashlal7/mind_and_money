import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../navigation/navigation_provider.dart';
import '../../models/breathing_session.dart';
import '../../providers/wellness_providers.dart';

enum BreathingTechnique {
  box('Box Breathing (4-4-4-4)', 'box', [
    ('Inhale slowly', 4, true),
    ('Hold gently', 4, false),
    ('Exhale smoothly', 4, false),
    ('Hold empty', 4, false),
  ]),
  relaxing478('4-7-8 Relaxing Breath', '478', [
    ('Inhale through nose', 4, true),
    ('Hold your breath', 7, false),
    ('Exhale completely', 8, false),
  ]),
  deepCalm('Deep Calm (4-6)', 'deep_calm', [
    ('Inhale deeply', 4, true),
    ('Exhale slowly', 6, false),
  ]);

  final String title;
  final String keyName;
  final List<(String instruction, int seconds, bool isInhale)> steps;

  const BreathingTechnique(this.title, this.keyName, this.steps);
}

class BreathingExerciseScreen extends ConsumerStatefulWidget {
  final bool showAppBar;

  const BreathingExerciseScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<BreathingExerciseScreen> createState() =>
      _BreathingExerciseScreenState();
}

class _BreathingExerciseScreenState
    extends ConsumerState<BreathingExerciseScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  BreathingTechnique _selectedTechnique = BreathingTechnique.box;
  int _sessionMinutes = 2; // Default 2 minutes
  late int _totalDurationSeconds;
  late int _remainingSeconds;

  bool _isActive = false;
  bool _isPaused = false;
  Timer? _timer;

  int _currentStepIndex = 0;
  int _stepSecondsLeft = 4;
  int _cyclesCompleted = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _totalDurationSeconds = _sessionMinutes * 60;
    _remainingSeconds = _totalDurationSeconds;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    // Bounded subtle scale: 0.90 to 1.15 (prevents circle from overflowing on small screens)
    _scaleAnimation = Tween<double>(begin: 0.90, end: 1.15).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_isActive && !_isPaused) {
        _pause();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _onTechniqueChanged(BreathingTechnique technique) {
    if (_isActive) return;
    setState(() {
      _selectedTechnique = technique;
      _currentStepIndex = 0;
      _stepSecondsLeft = technique.steps.first.$2;
    });
  }

  void _onDurationChanged(int minutes) {
    if (_isActive) return;
    setState(() {
      _sessionMinutes = minutes;
      _totalDurationSeconds = minutes * 60;
      _remainingSeconds = _totalDurationSeconds;
    });
  }

  void _start() {
    setState(() {
      _isActive = true;
      _isPaused = false;
      _remainingSeconds = _totalDurationSeconds;
      _currentStepIndex = 0;
      _stepSecondsLeft = _selectedTechnique.steps[0].$2;
      _cyclesCompleted = 0;
    });
    _animateStep();
    _startTimer();
  }

  void _resume() {
    setState(() => _isPaused = false);
    _animController.forward();
    _startTimer();
  }

  void _pause() {
    _timer?.cancel();
    _animController.stop();
    setState(() => _isPaused = true);
  }

  void _stop() {
    _timer?.cancel();
    _animController.reset();
    setState(() {
      _isActive = false;
      _isPaused = false;
      _remainingSeconds = _totalDurationSeconds;
      _currentStepIndex = 0;
      _stepSecondsLeft = _selectedTechnique.steps.first.$2;
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      if (_remainingSeconds <= 1) {
        _timer?.cancel();
        _onSessionComplete();
        return;
      }

      setState(() {
        _remainingSeconds--;
        _stepSecondsLeft--;

        if (_stepSecondsLeft <= 0) {
          _advanceStep();
        }
      });
    });
  }

  void _advanceStep() {
    final nextIndex = (_currentStepIndex + 1) % _selectedTechnique.steps.length;
    if (nextIndex == 0) {
      _cyclesCompleted++;
    }

    _currentStepIndex = nextIndex;
    _stepSecondsLeft = _selectedTechnique.steps[nextIndex].$2;
    _animateStep();
  }

  void _animateStep() {
    final step = _selectedTechnique.steps[_currentStepIndex];
    _animController.duration = Duration(seconds: step.$2);

    if (step.$3) {
      // Inhale: expand
      _animController.forward(from: 0.0);
    } else if (step.$1.toLowerCase().contains('exhale')) {
      // Exhale: contract
      _animController.reverse(from: 1.0);
    }
  }

  Future<void> _onSessionComplete() async {
    _animController.reset();
    final actualDuration = _totalDurationSeconds - _remainingSeconds;

    final session = BreathingSession(
      id: 'brth_${IdGenerator.generate()}',
      technique: _selectedTechnique.keyName,
      durationSeconds: actualDuration,
      completedAt: DateTime.now(),
      cyclesCompleted: _cyclesCompleted > 0 ? _cyclesCompleted : 1,
    );

    try {
      await ref.read(breathingRepositoryProvider).recordSession(session);
      ref.invalidate(breathingStatsProvider);
      ref.invalidate(recentBreathingSessionsProvider);
    } catch (_) {}

    setState(() {
      _isActive = false;
      _isPaused = false;
      _remainingSeconds = _totalDurationSeconds;
    });

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.spa_rounded,
          size: 36,
          color: AppColors.incomeGreen,
        ),
        title: const Text('Session Complete'),
        content: Text(
          'You completed $_sessionMinutes minute${_sessionMinutes > 1 ? 's' : ''} of ${_selectedTechnique.title}.\n\nTaking time to pause and breathe restores mental clarity.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(activeTabProvider.notifier).setTab(0); // Go to Home
            },
            child: const Text('Return to Home'),
          ),
        ],
      ),
    );
  }

  String _formatTimer(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isReducedMotion = MediaQuery.of(context).disableAnimations;
    final currentStep = _selectedTechnique.steps[_currentStepIndex];

    Widget bodyContent = LayoutBuilder(
      builder: (context, constraints) {
        // Compute responsive circle size that stays safely within boundaries across smartwatches and phones
        final availableWidth = constraints.maxWidth;
        final baseDiameter = (availableWidth * 0.42).clamp(70.0, 175.0);

        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight > 24
                  ? constraints.maxHeight - 24
                  : 0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Section: Configuration or Active Session Pill
                Column(
                  children: [
                    if (!widget.showAppBar) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Paced Breathing',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.info_outline_rounded,
                              size: 20,
                            ),
                            tooltip: 'About Breathing',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _showInfoDialog(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],

                    if (!_isActive) ...[
                      // Technique Selection Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.primarySurfaceDark
                              : AppColors.primarySurfaceLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? AppColors.borderDividerDark
                                : AppColors.borderDividerLight,
                            width: 1.0,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select Breathing Technique',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontFamily: 'NotoSansMono',
                                letterSpacing: 0.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...BreathingTechnique.values.map((tech) {
                              final isSelected = _selectedTechnique == tech;
                              return InkWell(
                                onTap: () => _onTechniqueChanged(tech),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 5,
                                    horizontal: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isSelected
                                            ? Icons.radio_button_checked_rounded
                                            : Icons.radio_button_off_rounded,
                                        color: isSelected
                                            ? (isDark
                                                  ? AppColors.nothingRedDark
                                                  : AppColors.nothingRed)
                                            : colorScheme.onSurfaceVariant,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              tech.title,
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                    fontWeight: isSelected
                                                        ? FontWeight.w700
                                                        : FontWeight.w500,
                                                  ),
                                            ),
                                            Text(
                                              tech.steps
                                                  .map(
                                                    (s) => '${s.$1} (${s.$2}s)',
                                                  )
                                                  .join(' • '),
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    fontSize: 10.5,
                                                    color: colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Duration Selector
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Session Duration:',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [1, 2, 3, 5].map((min) {
                              final isSelected = _sessionMinutes == min;
                              return ChoiceChip(
                                label: Text('${min}m'),
                                selected: isSelected,
                                visualDensity: VisualDensity.compact,
                                labelStyle: TextStyle(
                                  fontFamily: 'NotoSansMono',
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                                onSelected: (_) => _onDurationChanged(min),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ] else ...[
                      // Active session compact indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.secondarySurfaceDark
                              : AppColors.secondarySurfaceLight,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark
                                ? AppColors.borderDividerDark
                                : AppColors.borderDividerLight,
                            width: 1.0,
                          ),
                        ),
                        child: Text(
                          '${_selectedTechnique.title} • ${_sessionMinutes}m',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'NotoSansMono',
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 16),

                // Center Section: Bounded Breathing Circle & Step Instructions
                Center(
                  child: AnimatedBuilder(
                    animation: _animController,
                    builder: (context, child) {
                      final scale = isReducedMotion
                          ? 1.0
                          : (_isActive ? _scaleAnimation.value : 1.0);

                      final isExhale = currentStep.$1.toLowerCase().contains(
                        'exhale',
                      );
                      final circleBorderColor = _isActive
                          ? (isExhale
                                ? (isDark
                                      ? AppColors.incomeGreenDark
                                      : AppColors.incomeGreen)
                                : (isDark
                                      ? AppColors.primaryTextDark
                                      : AppColors.primaryTextLight))
                          : colorScheme.outlineVariant;

                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: baseDiameter,
                          height: baseDiameter,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark
                                ? AppColors.secondarySurfaceDark.withValues(
                                    alpha: _isActive ? 0.9 : 0.4,
                                  )
                                : AppColors.secondarySurfaceLight.withValues(
                                    alpha: _isActive ? 0.9 : 0.4,
                                  ),
                            border: Border.all(
                              color: circleBorderColor,
                              width: _isActive ? 2.5 : 1.5,
                            ),
                            boxShadow: _isActive
                                ? [
                                    BoxShadow(
                                      color: circleBorderColor.withValues(
                                        alpha: 0.2,
                                      ),
                                      blurRadius: 18,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      _isActive
                                          ? currentStep.$1
                                          : 'Ready to breathe',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: colorScheme.onSurface,
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  if (_isActive) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_stepSecondsLeft}s',
                                      style: theme.textTheme.headlineMedium
                                          ?.copyWith(
                                            fontFamily: 'NotoSansMono',
                                            fontWeight: FontWeight.w800,
                                            color: circleBorderColor,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // Bottom Section: Remaining Timer, Controls, and Note
                Column(
                  children: [
                    // Countdown Session Timer
                    Text(
                      _formatTimer(_remainingSeconds),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontFamily: 'NotoSansMono',
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.0,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Controls Bar
                    if (!_isActive) ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _start,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.play_arrow_rounded),
                              SizedBox(width: 8),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text('Start Breathing Session'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isPaused) ...[
                            Flexible(
                              child: FilledButton.icon(
                                onPressed: _resume,
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: const Text('Resume'),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                          ] else ...[
                            Flexible(
                              child: OutlinedButton.icon(
                                onPressed: _pause,
                                icon: const Icon(Icons.pause_rounded),
                                label: const Text('Pause'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 10),
                          Flexible(
                            child: TextButton.icon(
                              onPressed: _stop,
                              icon: Icon(
                                Icons.stop_rounded,
                                color: isDark
                                    ? AppColors.nothingRedDark
                                    : AppColors.nothingRed,
                              ),
                              label: Text(
                                'Stop',
                                style: TextStyle(
                                  color: isDark
                                      ? AppColors.nothingRedDark
                                      : AppColors.nothingRed,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),

                    // Non-medical Disclaimer (compact)
                    Text(
                      'For mindful relaxation. Not a substitute for medical therapy.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.65,
                        ),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!widget.showAppBar) {
      return bodyContent;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Guided Breathing'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'About Breathing',
            onPressed: () => _showInfoDialog(context),
          ),
        ],
      ),
      body: bodyContent,
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('About Guided Breathing'),
        content: const Text(
          'Deep, paced breathing helps activate the parasympathetic nervous system, easing acute stress and restoring calm.\n\n'
          '• Box Breathing: Balances the nervous system using equal 4-second counts.\n'
          '• 4-7-8 Breathing: Promotes deep relaxation and restfulness.\n'
          '• Deep Calm: Gentle prolonged exhales to reduce heart rate.\n\n'
          'Practice freely at any time. Stop immediately if you feel dizzy or uncomfortable.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
