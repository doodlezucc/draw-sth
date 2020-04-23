import 'dart:html';

import 'project.dart';

class Grid {
  final Project project;
  final DivElement el = querySelector('#grid');

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

  Point<num> _position;
  Point<num> get position => _position;
  set position(Point<num> position) {
    _position = position;
    el.style.left = (project.zoom * position.x).toString() + 'px';
    el.style.top = (project.zoom * position.y).toString() + 'px';
  }

  Point<num> _size;
  Point<num> get size => _size;
  set size(Point<num> size) {
    _size = size;
    el.style.width = (project.zoom * size.x).toString() + 'px';
    el.style.height = (project.zoom * size.y).toString() + 'px';
  }

  static const dragSensitivity = 5; // minimum distance to enable dragging

  Grid(this.project) {
    position = Point(200, 200);
    size = Point(400, 400);

    el.onMouseDown.listen((e) {
      var mouse1 = e.client;
      var pos1 = position;
      var drag = false;
      var subMove = document.onMouseMove.listen((e) {
        if (e.movement.magnitude == 0) return;

        var newPos = pos1 + (e.client - mouse1) * (1 / project.zoom);
        if (!drag &&
            position.squaredDistanceTo(newPos) >=
                dragSensitivity * dragSensitivity) {
          drag = true;
        }

        if (drag) {
          position = newPos;
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

    ctx.fillStyle = '#000a';

    ctx.fillRect(0, 0, position.x, project.canvas.height);
    ctx.fillRect(position.x + size.x, 0,
        project.canvas.width - size.x - position.x, project.canvas.height);
    ctx.fillRect(position.x, 0, size.x, position.y);
    ctx.fillRect(position.x, position.y + size.y, size.x,
        project.canvas.height - size.y - position.y);

    ctx.strokeStyle = '#fff';
    ctx.lineWidth = 1;
    var lines = Point<int>(divisions.x + 1, divisions.y + 1);

    ctx.beginPath();
    for (var i = 0; i <= lines.x; i++) {
      var x = (pos.x + sizeMinus.x * (i / lines.x)).round() - 0.5;
      ctx.moveTo(x, pos.y);
      ctx.lineTo(x, pos.y + sizeMinus.y);
    }
    for (var i = 0; i <= lines.y; i++) {
      var y = (pos.y + sizeMinus.y * (i / lines.y)).round() - 0.5;
      ctx.moveTo(pos.x, y);
      ctx.lineTo(pos.x + sizeMinus.x, y);
    }
    ctx.closePath();
    ctx.stroke();
  }
}
