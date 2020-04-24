import 'dart:html';
import 'dart:math';

import 'io.dart';
import 'project.dart';

class Grid {
  final Project project;
  final DivElement el = querySelector('#grid');

  String _outsideColor = '#000c';
  String get outsideColor => _outsideColor;
  set outsideColor(String outsideColor) {
    _outsideColor = outsideColor;
    project.redraw();
  }

  Point<int> _divisions = Point(3, 3);
  Point<int> get divisions => _divisions;
  set divisions(Point<int> divisions) {
    _divisions = divisions;
  }

  int _subdivisions = 2;
  int get subdivisions => _subdivisions;
  set subdivisions(int subdivisions) {
    _subdivisions = subdivisions;
  }

  Point _position;
  Point get position => _position;
  set position(Point position) {
    _position = position;
    el.style.left = (_position.x / project.zoom).toString() + 'px';
    el.style.top = (_position.y / project.zoom).toString() + 'px';
  }

  static Point<T> clamp<T extends num>(
      Point<T> point, Point<T> pMin, Point<T> pMax,
      [num inset = 0]) {
    return Point<T>(min(max(point.x, pMin.x), pMax.x + inset),
        min(max(point.y, pMin.y), pMax.y + inset));
  }

  Point _size;
  Point get size => _size;
  set size(Point size) {
    _size = size;
    el.style.width = (_size.x / project.zoom).toString() + 'px';
    el.style.height = (_size.y / project.zoom).toString() + 'px';
  }

  static const minSize = Point<int>(50, 50);

  void immediateClamp() {
    size = clamp(size, minSize, project.size);
    position = clamp(position, Point(0, 0), project.size - size);
  }

  static const dragSensitivity = 0; // minimum distance to enable dragging

  Grid(this.project) {
    _position = Point(200, 200);
    _size = Point(400, 400);

    el.onMouseDown.listen((e) {
      var pos1 = position;
      var size1 = size;

      var diffPosMin = pos1 * -1;
      var diffPosMax = size1 - minSize;
      var diffSizeMin = Point<num>(minSize.x, minSize.y) - size1;
      var diffSizeMax = project.size - (pos1 + size1);

      void Function(Point<int>) action;
      if (e.target != el) {
        var classes = (e.target as HtmlElement).classes;
        action = (diff) {
          var x = pos1.x;
          var y = pos1.y;
          var width = size1.x;
          var height = size1.y;

          if (classes.contains('top')) {
            var v = min(max(diff.y, diffPosMin.y), diffPosMax.y);
            y += v;
            height -= v;
          }
          if (classes.contains('right')) {
            width += min(max(diff.x, diffSizeMin.x), diffSizeMax.x);
          }
          if (classes.contains('bottom')) {
            height += min(max(diff.y, diffSizeMin.y), diffSizeMax.y);
          }
          if (classes.contains('left')) {
            var v = min(max(diff.x, diffPosMin.x), diffPosMax.x);
            x += v;
            width -= v;
          }

          size = Point(width, height);
          position = Point(x, y);
        };
      } else {
        action = (diff) {
          position = clamp(pos1 + diff, Point(0, 0), project.size - size1);
        };
      }

      var mouse1 = Point<int>(e.client.x, e.client.y);
      var drag = false;
      var subMove = document.onMouseMove.listen((e) {
        if (e.movement.magnitude == 0) return;
        var diff = (Point<int>(e.client.x, e.client.y) - mouse1) * project.zoom;
        if (!drag &&
            diff.x * diff.x + diff.y * diff.y >=
                dragSensitivity * dragSensitivity) {
          drag = true;
        }

        if (drag) {
          action(diff);
          project.redraw();
        }
      });

      var subUp;
      subUp = document.onMouseUp.listen((e) {
        subMove.cancel();
        subUp.cancel();
      });
    });
  }

  void drawOn(CanvasRenderingContext2D ctx) {
    var zoom = project.zoom;
    var position = Point<int>(this.position.x ~/ zoom, this.position.y ~/ zoom);
    var pos = Point<int>(position.x + 1, position.y + 1);
    var size = Point<int>(this.size.x ~/ zoom + 1, this.size.y ~/ zoom + 1);
    var sizeMinus = Point<int>(size.x - 1, size.y - 1);

    ctx.fillStyle = outsideColor;

    ctx.fillRect(0, 0, position.x, project.zoomedSize.y);
    ctx.fillRect(position.x + size.x, 0,
        project.zoomedSize.x - size.x - position.x, project.zoomedSize.y);
    ctx.fillRect(position.x, 0, size.x, position.y);
    ctx.fillRect(position.x, position.y + size.y, size.x,
        project.zoomedSize.y - size.y - position.y);

    void invert(Point<int> start, Point<int> size, bool solid) {
      var d = ctx.getImageData(start.x, start.y, size.x, size.y);
      for (var i = 0; i < d.data.length; i += 4) {
        var luminance = (0.2126 * d.data[i] +
                0.7152 * d.data[i + 1] +
                0.0722 * d.data[i + 2]) /
            255;
        var v = ((0.8 - 2 * luminance.round()) * (solid ? 120 : 30)).floor();
        d.data[i] += v;
        d.data[i + 1] += v;
        d.data[i + 2] += v;
      }
      ctx.putImageData(d, start.x, start.y);
    }

    ctx.strokeStyle = '#fff';
    ctx.strokeRect(
        pos.x.round() - 0.5, pos.y.round() - 0.5, sizeMinus.x, sizeMinus.y);

    var lines = Point<int>((divisions.x + 1) * pow(2, subdivisions),
        (divisions.y + 1) * pow(2, subdivisions));

    bool isSolid(int i) {
      return i % (pow(2, subdivisions)) == 0;
    }

    for (var i = 1; i < lines.x; i++) {
      var x = (pos.x + sizeMinus.x * (i / lines.x)).round();
      invert(Point(x, pos.y), Point(1, sizeMinus.y - 1), isSolid(i));
    }
    for (var i = 1; i < lines.y; i++) {
      var y = (pos.y + sizeMinus.y * (i / lines.y)).round();
      invert(Point(pos.x, y), Point(sizeMinus.x - 1, 1), isSolid(i));
    }
  }

  Map<String, dynamic> toJson() => {
        'divisions': pointToJson(divisions),
        'subdivisions': subdivisions,
        'position': pointToJson(position),
        'size': pointToJson(size)
      };
  void fromJson(Map<String, dynamic> json) {
    divisions = pointFromJson(json['divisions']);
    subdivisions = json['subdivisions'];
    position = pointFromJson(json['position']);
    size = pointFromJson(json['size']);
  }
}
