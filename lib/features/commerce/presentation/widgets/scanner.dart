import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../app/localization/l10n.dart';

/// La caméra peut-elle scanner sur cet appareil ? (Sur ordinateur, une
/// douchette se comporte comme un clavier : la saisie suffit.)
bool get scanDisponible =>
    kIsWeb || defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;

/// Ouvre la caméra et renvoie le premier code lu (ou `null`).
Future<String?> scannerCodeBarres(BuildContext context) =>
    Navigator.of(context).push<String>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const _ScannerPage()));

/// Bouton « Scanner » : n'apparaît que si la caméra est disponible.
class BoutonScanner extends StatelessWidget {
  const BoutonScanner({super.key, required this.onCode, this.boxed = false});
  final ValueChanged<String> onCode;
  final bool boxed;

  @override
  Widget build(BuildContext context) {
    if (!scanDisponible) return const SizedBox.shrink();
    Future<void> scanner() async {
      final code = await scannerCodeBarres(context);
      if (code != null && code.isNotEmpty) onCode(code);
    }

    final l10n = context.l10n;
    return boxed
        ? IconButton.filledTonal(
            key: const Key('scanner'),
            tooltip: l10n.comScan,
            onPressed: scanner,
            icon: const Icon(Icons.qr_code_scanner_rounded),
          )
        : IconButton(
            key: const Key('scanner'),
            tooltip: l10n.comScan,
            onPressed: scanner,
            icon: const Icon(Icons.qr_code_scanner_rounded),
          );
  }
}

class _ScannerPage extends StatefulWidget {
  const _ScannerPage();

  @override
  State<_ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<_ScannerPage> {
  final _controleur = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  bool _lu = false;

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  void _surDetection(BarcodeCapture capture) {
    if (_lu) return;
    final code = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
    if (code == null) return;
    _lu = true;
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(l10n.comScanTitle),
        actions: [
          IconButton(
            tooltip: l10n.comTorch,
            onPressed: _controleur.toggleTorch,
            icon: const Icon(Icons.flashlight_on_outlined),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controleur,
            onDetect: _surDetection,
            errorBuilder: (_, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.comScanUnavailable,
                    textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 260,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 48,
            child: Text(l10n.comScanHint,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
