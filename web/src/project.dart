import 'dart:html';

import 'grid.dart';

class Project {
  final CanvasElement canvas = querySelector('canvas');
  final ImageElement img = querySelector('img');
  final InputElement urlInput = querySelector('#imgUrl');
  Grid _grid;

  double _zoom = 0.25;
  double get zoom => _zoom;
  set zoom(double zoom) {
    _zoom = zoom;
    redraw();
  }

  Point<int> get zoomedSize =>
      Point((img.width * zoom).round(), (img.height * zoom).round());

  void registerIntInput(InputElement e, void Function(int value) apply,
      int Function() applyBackwards) {
    void parse() {
      var s = e.value;
      var v = int.tryParse(s);
      if (v != null && v >= 0) {
        apply(v);
      }
    }

    e.onInput.listen((ev) {
      parse();
    });
    parse();

    e.onBlur.listen((ev) {
      e.value = applyBackwards().toString();
    });
  }

  void loadUrl(String url) {
    img.src = url;
  }

  Project() {
    _grid = Grid(this);

    registerIntInput(
        querySelector('#divX'),
        (v) => _grid.divisions = Point(v, _grid.divisions.y),
        () => _grid.divisions.x);
    registerIntInput(
        querySelector('#divY'),
        (v) => _grid.divisions = Point(_grid.divisions.x, v),
        () => _grid.divisions.y);
    registerIntInput(querySelector('#subdivisions'),
        (v) => _grid.subdivisions = v, () => _grid.subdivisions);

    urlInput.onKeyDown.listen((e) {
      if (e.keyCode == 13) {
        loadUrl(urlInput.value);
      }
    });

    img.onLoad.listen((e) {
      print('Loaded image!');
      onNewImage();
    });
  }

  void initDemo() {
    onNewImage();
  }

  void onNewImage() {
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
