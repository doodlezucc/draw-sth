import 'dart:html';

import 'grid.dart';

class Project {
  final CanvasElement canvas = querySelector('canvas');
  final ImageElement img = querySelector('img');
  Grid _grid;

  Project() {
    _grid = Grid(this);

    ImageElement img = querySelector('img');
    img.onLoad.listen((e) => print('Loaded image!'));
  }

  void initDemo() {
    loadImage();
  }

  void loadImage() {
    canvas.width = img.width ~/ 4;
    canvas.height = img.height ~/ 4;
    redraw();
  }

  void redraw() {
    var ctx = canvas.context2D;
    ctx.drawImageScaled(img, 0, 0, canvas.width, canvas.height);
    _grid.drawOn(ctx);
  }
}
