import 'dart:html';

import 'project.dart';

class Grid {
  final Project project;
  final DivElement el = querySelector('#grid');

  String _gridColor = '#fff6';
  String get gridColor => _gridColor;
  set gridColor(String gridColor) {
    _gridColor = gridColor;
    project.redraw();
  }

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
    project.redraw();
  }

  int _subdivisions = 2;
  int get subdivisions => _subdivisions;
  set subdivisions(int subdivisions) {
    _subdivisions = subdivisions;
    project.redraw();
  }

  Point<int> _position;
  Point<int> get position => _position;
  set position(Point<int> position) {
    _position = position;
    el.style.left = (project.zoom * position.x).toString() + 'px';
    el.style.top = (project.zoom * position.y).toString() + 'px';
  }

  Point<int> _size;
  Point<int> get size => _size;
  set size(Point<int> size) {
    _size = size;
    el.style.width = (project.zoom * size.x).toString() + 'px';
    el.style.height = (project.zoom * size.y).toString() + 'px';
  }

  static const dragSensitivity = 5; // minimum distance to enable dragging

  Grid(this.project) {
    position = Point(200, 200);
    size = Point(400, 400);

    el.onMouseDown.listen((e) {
      void Function(Point<int>, Point<int>, Point<int>) action;
      if (e.target != el) {
        var classes = (e.target as HtmlElement).classes;
        action = (pos1, size1, diff) {
          var x = pos1.x;
          var y = pos1.y;
          var width = size1.x;
          var height = size1.y;

          if (classes.contains('top')) {
            y += diff.y;
            height -= diff.y;
          }
          if (classes.contains('right')) {
            width += diff.x;
          }
          if (classes.contains('bottom')) {
            height += diff.y;
          }
          if (classes.contains('left')) {
            x += diff.x;
            width -= diff.x;
          }

          position = Point(x, y);
          size = Point(width, height);
        };
      } else {
        action = (pos1, size1, diff) {
          position = pos1 + diff;
        };
      }

      var mouse1 = Point<int>(e.client.x, e.client.y);
      var pos1 = position;
      var size1 = size;
      var drag = false;
      var subMove = document.onMouseMove.listen((e) {
        if (e.movement.magnitude == 0) return;
        var diff =
            (Point<int>(e.client.x, e.client.y) - mouse1) * (1 / project.zoom);
        if (!drag &&
            diff.x * diff.x + diff.y * diff.y >=
                dragSensitivity * dragSensitivity) {
          drag = true;
        }

        if (drag) {
          action(pos1, size1, diff);
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
    var position = Point<num>(zoom * this.position.x, zoom * this.position.y);
    var pos = Point<num>(position.x + 1, position.y + 1);
    var size = Point<num>(zoom * this.size.x, zoom * this.size.y);
    var sizeMinus = Point<num>(size.x - 1, size.y - 1);

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

    var lines = Point<int>(divisions.x + 1, divisions.y + 1);

    ctx.beginPath();
    for (var i = 1; i < lines.x; i++) {
      var x = (pos.x + sizeMinus.x * (i / lines.x)).round() - 0.5;
      ctx.moveTo(x, pos.y);
      ctx.lineTo(x, pos.y + sizeMinus.y);
    }
    for (var i = 1; i < lines.y; i++) {
      var y = (pos.y + sizeMinus.y * (i / lines.y)).round() - 0.5;
      ctx.moveTo(pos.x, y);
      ctx.lineTo(pos.x + sizeMinus.x, y);
    }
    ctx.closePath();
    ctx.stroke();
  }
}
