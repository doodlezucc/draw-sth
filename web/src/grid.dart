import 'dart:html';
import 'dart:math';

import 'project.dart';

class Grid {
  final Project project;
  final DivElement el = querySelector('#grid');

  String _gridColor = '#fff9';
  String get gridColor => _gridColor;
  set gridColor(String gridColor) {
    _gridColor = gridColor;
    project.redraw();
  }

  String get subGridColor => '#ccc4';

  String _outsideColor = '#000a';
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

  Point<int> _position;
  Point<int> get position => _position;
  set position(Point<int> position) {
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

  Point<int> _size;
  Point<int> get size => _size;
  set size(Point<int> size) {
    _size = size;
    el.style.width = (_size.x / project.zoom).toString() + 'px';
    el.style.height = (_size.y / project.zoom).toString() + 'px';
  }

  static const dragSensitivity = 0; // minimum distance to enable dragging

  Grid(this.project) {
    _position = Point(200, 200);
    _size = Point(400, 400);

    el.onMouseDown.listen((e) {
      var pos1 = position;
      var size1 = size;

      var diffPosMin = pos1 * -1;
      var minSize = Point(50, 50);
      var diffPosMax = size1 - minSize;
      var diffSizeMin = minSize - size1;
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
            var v = min<int>(max(diff.y, diffPosMin.y), diffPosMax.y);
            y += v;
            height -= v;
          }
          if (classes.contains('right')) {
            width += min<int>(max(diff.x, diffSizeMin.x), diffSizeMax.x);
          }
          if (classes.contains('bottom')) {
            height += min<int>(max(diff.y, diffSizeMin.y), diffSizeMax.y);
          }
          if (classes.contains('left')) {
            var v = min<int>(max(diff.x, diffPosMin.x), diffPosMax.x);
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

    ctx.fillRect(0, 0, position.x, project.canvas.height);
    ctx.fillRect(position.x + size.x, 0,
        project.canvas.width - size.x - position.x, project.canvas.height);
    ctx.fillRect(position.x, 0, size.x, position.y);
    ctx.fillRect(position.x, position.y + size.y, size.x,
        project.canvas.height - size.y - position.y);

    ctx.strokeStyle = gridColor;
    ctx.lineWidth = 1;
    ctx.strokeRect(
        pos.x.round() - 0.5, pos.y.round() - 0.5, sizeMinus.x, sizeMinus.y);

    var lines = Point<int>((divisions.x + 1) * pow(2, subdivisions),
        (divisions.y + 1) * pow(2, subdivisions));

    void setStroke(int i) {
      ctx.strokeStyle =
          i % (pow(2, subdivisions)) == 0 ? gridColor : subGridColor;
    }

    for (var i = 1; i < lines.x; i++) {
      setStroke(i);

      var x = (pos.x + sizeMinus.x * (i / lines.x)).round() - 0.5;
      ctx.beginPath();
      ctx.moveTo(x, pos.y);
      ctx.lineTo(x, pos.y + sizeMinus.y - 1);
      ctx.stroke();
    }
    for (var i = 1; i < lines.y; i++) {
      setStroke(i);

      var y = (pos.y + sizeMinus.y * (i / lines.y)).round() - 0.5;
      ctx.beginPath();
      ctx.moveTo(pos.x, y);
      ctx.lineTo(pos.x + sizeMinus.x - 1, y);
      ctx.stroke();
    }
  }
}
