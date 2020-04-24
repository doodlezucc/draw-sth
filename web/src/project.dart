import 'dart:convert';
import 'dart:html';
import 'dart:math';

import 'grid.dart';
import 'io.dart';

class Project {
  static const zoomSpeed = 50;

  final CanvasElement canvas = querySelector('canvas');
  final ImageElement img = querySelector('img');
  final InputElement urlInput = querySelector('#imgUrl');
  final DivElement offsetElement = querySelector('#offset');
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

  Point _offset = Point(0, 0);
  Point get offset => _offset;
  set offset(Point offset) {
    _offset = offset;
    var point = (_offset * (1 / zoom)) - zoomedSize * 0.5;
    offsetElement.style.left = 'calc(50% + ${point.x}px)';
    offsetElement.style.top = 'calc(50% + ${point.y}px)';
  }

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

  void setSrc(String src) {
    img.src = src;
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
        setSrc(urlInput.value);
      }
    });

    querySelector('.image').onMouseDown.listen((e) {
      HtmlElement el = e.target;
      if (el.matchesWithAncestors('#grid')) return;
      var pos1 = offset;

      var mouse1 = Point<int>(e.client.x, e.client.y);
      var subMove = document.onMouseMove.listen((e) {
        if (e.movement.magnitude == 0) return;
        var diff = (Point<int>(e.client.x, e.client.y) - mouse1);

        offset = pos1 + diff * zoom;
      });

      var subUp;
      subUp = document.onMouseUp.listen((e) {
        subMove.cancel();
        subUp.cancel();
      });
    });

    querySelector('#save').onClick.listen((e) => download());
    InputElement fileInput = querySelector('#upload');
    fileInput.onChange.listen((e) {
      var file = fileInput.files[0];
      if (file != null) {
        var reader = FileReader();
        reader.onLoad.listen((e) {
          String jsonString = (e.target as dynamic).result;
          fromJson(json.decode(jsonString));
        });
        reader.readAsText(file);
      }
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

  Map<String, dynamic> toJson() => {
        'src': img.src,
        'offset': pointToJson(offset),
        'zoomWidth': zoomWidth,
        'grid': _grid.toJson()
      };
  void fromJson(Map<String, dynamic> json) {
    img.src = json['src'];
    var sub;
    sub = img.onLoad.listen((e) {
      sub.cancel();
      _offset = pointFromJson(json['offset']);
      _zoomWidth = json['zoomWidth'];
      _grid.fromJson(json['grid']);
      setSize();
    });
  }

  void download() {
    var jsonString = toJsonString(this);
    var aElement = AnchorElement(
        href:
            'data:text/json;charset=utf-8,' + Uri.encodeComponent(jsonString));
    aElement.download = 'draw_sth.json';
    document.body.append(aElement);
    aElement.click();
    aElement.remove();
  }

  void reloadStylesheet() {
    LinkElement cssLink = querySelector('link');
    cssLink.href = cssLink.href;
  }

  void initDemo() {
    img.src = 'jon.png';
    var sub;
    sub = img.onLoad.listen((e) {
      sub.cancel();
      setSize();
    });
  }

  void setSize() {
    canvas.width = zoomedSize.x;
    canvas.height = zoomedSize.y;
    _grid.position = _grid.position;
    _grid.size = _grid.size;
    offset = offset;
    redraw();
  }

  void redraw() {
    var ctx = canvas.context2D;
    ctx.drawImageScaled(img, 0, 0, canvas.width, canvas.height);
    _grid.drawOn(ctx);
  }
}
