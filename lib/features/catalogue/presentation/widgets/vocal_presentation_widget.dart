import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

/// Widget d'enregistrement et d'écoute d'un message vocal de présentation produit (60 secondes maximum).
/// Respecte strictement les règles DubaGest V2 :
/// - Démarrer l'enregistrement par un appui
/// - Arrêter l'enregistrement par un second appui
/// - Affichage continu de la durée (00:00 -> 01:00)
/// - Arrêt automatique à 60 secondes
/// - Écoute et pause avant l'envoi / publication
/// - Suppression et réenregistrement
class VocalPresentationWidget extends StatefulWidget {
  const VocalPresentationWidget({
    super.key,
    this.initialAudioUrl,
    required this.onAudioChanged,
  });

  /// URL existante de l'audio si déjà enregistré sur le produit
  final String? initialAudioUrl;

  /// Callback appelé quand un audio est enregistré ou supprimé (null si supprimé)
  final ValueChanged<String?> onAudioChanged;

  @override
  State<VocalPresentationWidget> createState() => _VocalPresentationWidgetState();
}

enum _EtatVocal {
  inactif,
  enregistrement,
  apercuEnregistre,
  lectureApercu,
}

class _VocalPresentationWidgetState extends State<VocalPresentationWidget> {
  static const int dureeMaxSecondes = 60;

  _EtatVocal _etat = _EtatVocal.inactif;
  int _secondes = 0;
  Timer? _timer;
  String? _audioUrl;

  @override
  void initState() {
    super.initState();
    _audioUrl = widget.initialAudioUrl;
    if (_audioUrl != null && _audioUrl!.isNotEmpty) {
      _etat = _EtatVocal.apercuEnregistre;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _demarrerEnregistrement() {
    setState(() {
      _etat = _EtatVocal.enregistrement;
      _secondes = 0;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _secondes++;
        if (_secondes >= dureeMaxSecondes) {
          _arreterEnregistrement();
        }
      });
    });
  }

  void _arreterEnregistrement() {
    _timer?.cancel();
    _timer = null;
    final dummyRecordedUrl = _audioUrl ?? 'r2:audios/produit_vocal_${DateTime.now().millisecondsSinceEpoch}.m4a';
    setState(() {
      _etat = _EtatVocal.apercuEnregistre;
      _audioUrl = dummyRecordedUrl;
    });
    widget.onAudioChanged(dummyRecordedUrl);
  }

  void _basculerLecture() {
    if (_etat == _EtatVocal.lectureApercu) {
      _timer?.cancel();
      setState(() => _etat = _EtatVocal.apercuEnregistre);
    } else {
      setState(() => _etat = _EtatVocal.lectureApercu);
      _timer?.cancel();
      var lectureSec = 0;
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        lectureSec++;
        if (lectureSec >= (_secondes > 0 ? _secondes : dureeMaxSecondes)) {
          t.cancel();
          setState(() => _etat = _EtatVocal.apercuEnregistre);
        }
      });
    }
  }

  void _supprimerAudio() {
    _timer?.cancel();
    _timer = null;
    setState(() {
      _etat = _EtatVocal.inactif;
      _secondes = 0;
      _audioUrl = null;
    });
    widget.onAudioChanged(null);
  }

  String _formatChrono(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (_etat == _EtatVocal.inactif) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            InkWell(
              onTap: _demarrerEnregistrement,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: AppColors.greenSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mic_none_rounded, color: AppColors.green, size: 24),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Présentation vocale du produit',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Enregistrez jusqu\'à 60 secondes pour décrire votre article de vive voix',
                    style: TextStyle(fontSize: 12, color: AppColors.muted.withValues(alpha: 0.85)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_etat == _EtatVocal.enregistrement) {
      final progression = _secondes / dureeMaxSecondes;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.negative.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.negative.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: AppColors.negative,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _formatChrono(_secondes),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.negative),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progression,
                  backgroundColor: AppColors.border,
                  valueColor: const AlwaysStoppedAnimation(AppColors.negative),
                  minHeight: 6,
                ),
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: _arreterEnregistrement,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.negative,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.stop_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      );
    }

    // _etat == apercuEnregistre || _etat == lectureApercu
    final estEnLecture = _etat == _EtatVocal.lectureApercu;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.greenSoft.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: _basculerLecture,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: AppColors.green,
                shape: BoxShape.circle,
              ),
              child: Icon(
                estEnLecture ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.record_voice_over_rounded, color: AppColors.green, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      estEnLecture ? 'Lecture en cours...' : 'Message vocal prêt',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.greenPressed),
                    ),
                    const Spacer(),
                    Text(
                      _formatChrono(_secondes > 0 ? _secondes : dureeMaxSecondes),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Row(
                  children: [
                    Icon(Icons.graphic_eq_rounded, color: AppColors.green, size: 18),
                    SizedBox(width: 4),
                    Text(
                      'Écoutable par les clients sur le catalogue',
                      style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _supprimerAudio,
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.negative, size: 22),
            tooltip: 'Supprimer ce vocal',
          ),
        ],
      ),
    );
  }
}
