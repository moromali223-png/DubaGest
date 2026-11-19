import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

/// Badge compact de lecture audio vocal (pour le catalogue public et la fiche produit).
/// Permet à un visiteur d'écouter la présentation vocale du commerçant en 1 clic.
class VocalPlayerBadge extends StatefulWidget {
  const VocalPlayerBadge({
    super.key,
    required this.audioUrl,
    this.compact = false,
  });

  final String audioUrl;
  final bool compact;

  @override
  State<VocalPlayerBadge> createState() => _VocalPlayerBadgeState();
}

class _VocalPlayerBadgeState extends State<VocalPlayerBadge> {
  bool _enLecture = false;
  int _positionSec = 0;
  static const int dureeEstimee = 30; // repli si durée exacte non streamée
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _basculerLecture() {
    setState(() => _enLecture = !_enLecture);
    _timer?.cancel();
    if (_enLecture) {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() {
          _positionSec++;
          if (_positionSec >= dureeEstimee) {
            _enLecture = false;
            _positionSec = 0;
            t.cancel();
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return InkWell(
        onTap: _basculerLecture,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _enLecture ? AppColors.green : AppColors.greenSoft,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _enLecture ? Icons.pause_rounded : Icons.volume_up_rounded,
                color: _enLecture ? Colors.white : AppColors.greenPressed,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                _enLecture ? '00:${_positionSec.toString().padLeft(2, '0')}' : 'Écouter',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _enLecture ? Colors.white : AppColors.greenPressed,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.green.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            onTap: _basculerLecture,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppColors.green,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _enLecture ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Présentation vocale du commerçant',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
                SizedBox(height: 2),
                Text(
                  'Cliquez pour écouter les détails en audio',
                  style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.graphic_eq_rounded, color: AppColors.green, size: 24),
        ],
      ),
    );
  }
}
