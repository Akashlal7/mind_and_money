import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Interactive guided box breathing exercise modal (Inhale 4s, Hold 4s, Exhale 4s, Rest 4s)
class QuickBreathingSheet extends StatefulWidget {
  const QuickBreathingSheet({super.key});

  @override
  State<QuickBreathingSheet> createState() => _QuickBreathingSheetState();
}

enum BreathingPhase {
  inhale('Inhale slowly through your nose', 4),
  hold('Gently hold your breath', 4),
  exhale('Slowly release and exhale', 4),
  rest('Rest and pause quietly', 4);

  final String instruction;
  final int durationSeconds;

  const BreathingPhase(this.instruction, this.durationSeconds);
}

class _QuickBreathingSheetState extends State<QuickBreathingSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  Timer? _timer;
  static const int _totalDurationSeconds = 60; // 1 minute default
  int _remainingSeconds = 60;
  bool _isRunning = false;
  BreathingPhase _currentPhase = BreathingPhase.inhale;
  int _phaseSecondsLeft = 4;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.25).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  void _startOrResume() {
    setState(() {
      _isRunning = true;
    });

    if (_currentPhase == BreathingPhase.inhale) {
      _animController.forward(from: 0.0);
    } else if (_currentPhase == BreathingPhase.exhale) {
      _animController.reverse(from: 1.0);
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _stopSession();
          return;
        }

        _phaseSecondsLeft--;
        if (_phaseSecondsLeft <= 0) {
          _advancePhase();
        }
      });
    });
  }

  void _advancePhase() {
    switch (_currentPhase) {
      case BreathingPhase.inhale:
        _currentPhase = BreathingPhase.hold;
        _animController.stop();
        break;
      case BreathingPhase.hold:
        _currentPhase = BreathingPhase.exhale;
        _animController.reverse(from: 1.0);
        break;
      case BreathingPhase.exhale:
        _currentPhase = BreathingPhase.rest;
        _animController.stop();
        break;
      case BreathingPhase.rest:
        _currentPhase = BreathingPhase.inhale;
        _animController.forward(from: 0.0);
        break;
    }
    _phaseSecondsLeft = _currentPhase.durationSeconds;
  }

  void _pause() {
    _timer?.cancel();
    _animController.stop();
    setState(() {
      _isRunning = false;
    });
  }

  void _stopSession() {
    _timer?.cancel();
    _animController.reset();
    setState(() {
      _isRunning = false;
      _remainingSeconds = _totalDurationSeconds;
      _currentPhase = BreathingPhase.inhale;
      _phaseSecondsLeft = 4;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isComplete = _remainingSeconds == 0;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.air_rounded, color: AppColors.tealSecondary),
                  const SizedBox(width: 8),
                  Text(
                    'Guided Breathing',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isComplete
                ? 'Great job taking this mindful pause.'
                : _isRunning
                ? _currentPhase.instruction
                : 'Tap start to begin a 1-minute box breathing session to reset and center your thoughts.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),

          // Breathing Animation Circle
          AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              final scale = _isRunning ? _scaleAnimation.value : 1.0;
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.tealContainer,
                        AppColors.sageContainer.withValues(alpha: 0.6),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.tealSecondary.withValues(alpha: 0.15),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isRunning ? '$_phaseSecondsLeft' : '4-4-4-4',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.onTealContainer,
                          ),
                        ),
                        if (_isRunning)
                          Text(
                            _currentPhase.name.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: AppColors.onTealContainer,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Remaining time indicator
          Text(
            'Remaining: ${_remainingSeconds ~/ 60}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),

          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_isRunning)
                FilledButton.icon(
                  onPressed: _startOrResume,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    _remainingSeconds == _totalDurationSeconds
                        ? 'Start Session'
                        : 'Resume',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.tealSecondary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                )
              else ...[
                OutlinedButton.icon(
                  onPressed: _pause,
                  icon: const Icon(Icons.pause_rounded),
                  label: const Text('Pause'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _stopSession,
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('Stop'),
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'This exercise is for everyday calming and mindfulness. It is not intended as medical treatment.',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
