// ignore_for_file: avoid_print
//
// PLANCHES DE COMPARAISON — outil du skill `ux-ui` (source : .claude/skills/ux-ui/scripts/).
// Assemble, côte à côte et légendées, des captures déjà rendues par
// ui_snapshot_test.dart (ou un prototype qui l'importe) : avant / après, ou les
// candidats d'une proposition sur la même scène. Rien n'est rendu ici, seulement
// composé : lancer d'abord les captures.
//
// 1. Adapter la section PLANCHES (chemins relatifs à build/ui_snapshots/, sans
//    « .png » : « <label>/<scène>/<variante> », ou « <label>/<scène> » pour la
//    planche clair | sombre | 200 % entière).
// 2. flutter test build/ui_snapshots/_src/compare_boards_test.dart
// 3. Lire build/ui_snapshots/boards/<planche>.png
//
// Chaque capture est ramenée à la même hauteur, proportions gardées : une
// variante compacte (360×640) se compare donc à une variante pleine.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// ═══ PLANCHES — la seule partie à adapter ═══════════════════════════════════

final List<Board> boards = [
  const Board(
    file: 'avant_apres',
    title: 'Accueil — avant / après',
    shots: [
      ('before/home/light', 'Avant'),
      ('after/home/light', 'Après'),
      ('after/home/dark', 'Après · sombre'),
      ('after/home/light-text200', 'Après · texte 200 %'),
    ],
  ),
];

// ═══ Moteur — inutile de modifier ═══════════════════════════════════════════

/// Une planche : son fichier (sans extension), son titre, et ses captures
/// (chemin sous build/ui_snapshots sans « .png », légende).
class Board {
  const Board({required this.file, required this.title, required this.shots});

  final String file;
  final String title;
  final List<(String, String)> shots;
}

const _root = 'build/ui_snapshots';

// Hauteur commune des captures sur la planche, en pixels de la planche.
const double _shotHeight = 915;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Sans police chargée, le texte de test s'affiche en carrés.
    final loader = FontLoader('Outfit')
      ..addFont(rootBundle.load('lib/assets/fonts/Outfit-Medium.ttf'));
    await loader.load();
  });

  testWidgets('planches de comparaison', (tester) async {
    await tester.runAsync(() async {
      for (final board in boards) {
        final missing = [
          for (final (shot, _) in board.shots)
            if (!File('$_root/$shot.png').existsSync()) '$_root/$shot.png',
        ];
        if (missing.isNotEmpty) {
          // Une planche périmée ne doit pas passer pour la nouvelle.
          final stale = File('$_root/boards/${board.file}.png');
          if (stale.existsSync()) stale.deleteSync();
          print(
            '── ${board.file} : captures absentes\n   ${missing.join('\n   ')}',
          );
          continue;
        }
        print('── ${board.file} → ${await _compose(board)}');
      }
    });
  });
}

Future<String> _compose(Board board) async {
  const gap = 24.0;
  const header = 56.0;
  const caption = 36.0;
  final images = [
    for (final (shot, _) in board.shots) await _load('$_root/$shot.png'),
  ];
  final widths = [
    for (final image in images) image.width * _shotHeight / image.height,
  ];
  final width = widths.fold<double>(gap, (w, x) => w + x + gap);
  const height = header + caption + _shotHeight + gap;

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)
    ..drawColor(const ui.Color(0xFF3C4043), ui.BlendMode.src);
  _text(canvas, board.title, const ui.Offset(gap, 16), width - 2 * gap, 20);
  var x = gap;
  for (var i = 0; i < images.length; i++) {
    final image = images[i];
    _text(canvas, board.shots[i].$2, ui.Offset(x, header + 6), widths[i], 16);
    canvas.drawImageRect(
      image,
      ui.Offset.zero & ui.Size(image.width.toDouble(), image.height.toDouble()),
      ui.Offset(x, header + caption) & ui.Size(widths[i], _shotHeight),
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );
    x += widths[i] + gap;
  }
  final image = await recorder.endRecording().toImage(
    width.ceil(),
    height.ceil(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final out = File('$_root/boards/${board.file}.png');
  await out.parent.create(recursive: true);
  await out.writeAsBytes(bytes!.buffer.asUint8List());
  return out.absolute.path;
}

Future<ui.Image> _load(String path) async {
  final codec = await ui.instantiateImageCodec(await File(path).readAsBytes());
  return (await codec.getNextFrame()).image;
}

void _text(
  ui.Canvas canvas,
  String text,
  ui.Offset at,
  double width,
  double size,
) {
  final paragraph =
      (ui.ParagraphBuilder(
              ui.ParagraphStyle(
                fontFamily: 'Outfit',
                fontSize: size,
                maxLines: 1,
                ellipsis: '…',
              ),
            )
            ..pushStyle(ui.TextStyle(color: const ui.Color(0xFFFFFFFF)))
            ..addText(text))
          .build()
        ..layout(ui.ParagraphConstraints(width: width));
  canvas.drawParagraph(paragraph, at);
}
