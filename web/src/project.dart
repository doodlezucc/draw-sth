import 'dart:html';

import 'grid.dart';

class Project {
  final CanvasElement canvas = querySelector('canvas');
  final ImageElement img = querySelector('img');
  Grid _grid;

  double _zoom = 0.25;
  double get zoom => _zoom;
  set zoom(double zoom) {
    _zoom = zoom;
    redraw();
  }

  Point<int> get zoomedSize =>
      Point((img.width * zoom).round(), (img.height * zoom).round());

  Project() {
    _grid = Grid(this);

    ImageElement img = querySelector('img');
    img.onLoad.listen((e) => print('Loaded image!'));
  }

  void initDemo() {
    loadImage();
  }

  void loadImage() {
    canvas.width = zoomedSize.x;
    canvas.height = zoomedSize.y;
    redraw();
  }

  void redraw() {
    var ctx = canvas.context2D;
    ctx.drawImageScaled(img, 0, 0, canvas.width, canvas.height);
    _grid.drawOn(ctx);
  }
}
