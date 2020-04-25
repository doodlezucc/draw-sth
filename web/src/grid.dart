import 'dart:html';
import 'dart:math';

import 'io.dart';
import 'project.dart';

class Grid {
  final Project project;
  final DivElement el = querySelector('#grid');

  String _gridColor = '#fff';
  String get gridColor => _gridColor + '6';
  set gridColor(String gridColor) {
    _gridColor = gridColor;
  }

  String get subGridColor => _gridColor + '2';

  String _outsideColor = '#000c';
  String get outsideColor => _outsideColor;
  set outsideColor(String outsideColor) {
    _outsideColor = outsideColor;
    project.redraw();
  }

  int _subdivisions = 2;
  int get subdivisions => _subdivisions;
  set subdivisions(int subdivisions) {
    _subdivisions = subdivisions;
  }

  Point<double> _position = Point(50, 50);
  Point<double> get position => _position;
  set position(Point<double> position) {
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

  static Point<T> clampMin<T extends num>(Point<T> point, Point<T> pMin) {
    return Point<T>(max(point.x, pMin.x), max(point.y, pMin.y));
  }

  Point<double> _size = Point(400, 400);
  Point<double> get size => _size;
  set size(Point<double> size) {
    _size = size;
    _recalculateElementSize();
  }

  void _recalculateElementSize() {
    el.style.width = (_size.x / project.zoom).toString() + 'px';
    el.style.height = (_size.y / project.zoom).toString() + 'px';
  }

  Point<double> _cellSize = Point<double>(50, 100);
  Point<double> get cellSize => _cellSize;
  set cellSize(Point<double> size) {
    _cellSize = clampMin(size, Point(10, 10));
  }

  void fit() {
    size = Point((size.x / cellSize.x).round() * cellSize.x,
        (size.y / cellSize.y).round() * cellSize.y);
  }

  Point get minSize => cellSize;

  void immediateClamp() {
    size = clamp(size, minSize, Point<double>(project.size.x, project.size.y));
    position = clamp(position, Point(0, 0),
        Point<double>(project.size.x, project.size.y) - size);
  }

  static const dragSensitivity = 0; // minimum distance to enable dragging

  Grid(this.project) {
    el.onMouseDown.listen((e) {
      var pos1 = position;
      var size1 = size;

      void Function(Point<double>) action;
      if (e.target != el) {
        var classes = (e.target as HtmlElement).classes;

        var diffPosMin = pos1 * -1;
        var diffPosMax = size1 - minSize;
        var diffSizeMin = minSize - size1;
        var diffSizeMax = project.size - size1 - pos1;

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
        var diffMax = Point<double>(project.size.x, project.size.y) - size1;

        action = (diff) {
          position = clamp<double>(pos1 + diff, Point(0, 0), diffMax);
        };
      }

      var mouse1 = Point<double>(e.client.x, e.client.y);
      var drag = false;
      var subMove = document.onMouseMove.listen((e) {
        if (e.movement.magnitude == 0) return;
        var diff =
            (Point<double>(e.client.x, e.client.y) - mouse1) * project.zoom;
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
        fit();
        project.redraw();
      });
    });
  }

  Point<int> round(Point<num> p) {
    return Point<int>(p.x.round(), p.y.round());
  }

  void drawOn(CanvasRenderingContext2D ctx, Rectangle rect) {
    var zoom = project.zoom;
    var position = round(
        rect.topLeft + Point(this.position.x / zoom, this.position.y / zoom));
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
    ctx.strokeRect(
        pos.x.round() - 0.5, pos.y.round() - 0.5, size.x - 1, size.y - 1);

    void stroke(num x1, num y1, num x2, num y2) {
      ctx.beginPath();
      ctx.moveTo(x1, y1);
      ctx.lineTo(x2, y2);
      ctx.stroke();
    }

    var subdiv = pow(2, subdivisions) - 1;

    for (var i = 1; i <= this.size.x / cellSize.x; i++) {
      var x = (pos.x + cellSize.x * i / zoom).round() - 0.5;
      if (i < this.size.x / cellSize.x) {
        ctx.strokeStyle = gridColor;
        stroke(x, pos.y, x, pos.y + sizeMinus.y);
      }
      ctx.strokeStyle = subGridColor;
      for (var sub = 0; sub < subdiv; sub++) {
        var x1 =
            (x - (cellSize.x * (sub + 1) / (subdiv + 1)) / zoom).round() - 0.5;
        stroke(x1, pos.y, x1, pos.y + sizeMinus.y);
      }
    }
    for (var i = 1; i <= this.size.y / cellSize.y; i++) {
      var y = (pos.y + cellSize.y * i / zoom).round() - 0.5;
      if (i < this.size.y / cellSize.y) {
        ctx.strokeStyle = gridColor;
        stroke(pos.x, y, pos.x + sizeMinus.x, y);
      }
      ctx.strokeStyle = subGridColor;
      for (var sub = 0; sub < subdiv; sub++) {
        var y1 =
            (y - (cellSize.y * (sub + 1) / (subdiv + 1)) / zoom).round() - 0.5;
        stroke(pos.x, y1, pos.x + sizeMinus.x, y1);
      }
    }
  }

  Map<String, dynamic> toJson() => {
        'cellSize': pointToJson(cellSize),
        'subdivisions': subdivisions,
        'position': pointToJson(position),
        'size': pointToJson(size)
      };
  void fromJson(Map<String, dynamic> json) {
    cellSize = pointFromJson(json['cellSize']);
    subdivisions = json['subdivisions'];
    position = pointFromJson(json['position']);
    size = pointFromJson(json['size']);
  }
}
