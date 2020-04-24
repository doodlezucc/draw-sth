import 'dart:html';
import 'dart:math';

import 'grid.dart';

class Project {
  static const zoomSpeed = 50;

  final CanvasElement canvas = querySelector('canvas');
  final ImageElement img = querySelector('img');
  final InputElement urlInput = querySelector('#imgUrl');
  Grid _grid;

  int _zoomWidth = 500;
  int get zoomWidth => _zoomWidth;
  set zoomWidth(int zoomWidth) {
    _zoomWidth = zoomWidth;
    setSize();
  }

  double get zoom => img.width / zoomWidth;

  Point<int> get zoomedSize => Point(_zoomWidth, img.height ~/ zoom);
  Point<int> get size => Point(img.width, img.height);

  void registerIntInput(InputElement e, void Function(int value) apply,
      void Function(int value) bonus, int Function() applyBackwards) {
    void parse(bool executeBonus) {
      var s = e.value;
      var v = int.tryParse(s);
      if (v != null && v >= 0) {
        apply(v);
        if (executeBonus) bonus(v);
      }
    }

    e.onInput.listen((ev) {
      parse(true);
    });
    parse(false);

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
        (v) => redraw(),
        () => _grid.divisions.x);
    registerIntInput(
        querySelector('#divY'),
        (v) => _grid.divisions = Point(_grid.divisions.x, v),
        (v) => redraw(),
        () => _grid.divisions.y);
    registerIntInput(
        querySelector('#subdivisions'),
        (v) => _grid.subdivisions = v,
        (v) => redraw(),
        () => _grid.subdivisions);

    urlInput.onKeyDown.listen((e) {
      if (e.keyCode == 13) {
        loadUrl(urlInput.value);
      }
    });

    img.onLoad.listen((e) {
      print('Loaded image!');
      setSize();
    });

    document.onKeyDown.listen((e) {
      if (e.target is! InputElement) {
        if (e.shiftKey) {
          switch (e.key) {
            case 'R':
              reloadStylesheet();
              return;
          }
        }
        switch (e.key) {
          case '+':
            zoomWidth += zoomSpeed;
            return;
          case '-':
            zoomWidth -= zoomSpeed;
            return;
        }
      }
    });
  }

  void reloadStylesheet() {
    LinkElement cssLink = querySelector('link');
    cssLink.href = cssLink.href;
  }

  void initDemo() {
    setSize();
  }

  void setSize() {
    canvas.width = zoomedSize.x;
    canvas.height = zoomedSize.y;
    _grid.position = _grid.position;
    _grid.size = _grid.size;
    redraw();
  }

  void redraw() {
    var ctx = canvas.context2D;
    ctx.drawImageScaled(img, 0, 0, canvas.width, canvas.height);
    _grid.drawOn(ctx);
  }
}
