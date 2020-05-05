import 'dart:html';

import 'grid.dart';
import 'project.dart';

class Canvas {
  final CanvasElement e;
  final void Function(CanvasRenderingContext2D ctx, int width, int height)
      _draw;

  void redraw() {
    _draw(e.context2D, e.width, e.height);
  }

  void resize(int width, int height, {bool redraw = true}) {
    e.width = width;
    e.height = height;
    if (redraw) this.redraw();
  }

  Canvas(String canvasId, this._draw) : e = querySelector('canvas#$canvasId');
}

class Canvases {
  static String filter = 'none';
  static Project project;

  static final ImageElement img = querySelector('img#main');

  static final Canvas filteredImg = Canvas('img', (ctx, w, h) {
    ctx
      ..filter = filter
      ..drawImage(img, 0, 0);
  });

  static final Canvas inverted = Canvas('inverted', (ctx, w, h) {
    ctx
      ..filter = 'invert(1) grayscale(1) brightness(0.8) contrast(1000)'
      ..drawImage(filteredImg.e, 0, 0);
  });

  static Rectangle<int> dest;

  static void onResizeEditor() {
    var editor = project.editor;
    _gridified.resize(editor.clientWidth, editor.clientHeight, redraw: false);
    _main.resize(editor.clientWidth, editor.clientHeight, redraw: false);
  }

  static void redrawEditor() {
    var client = project.editor.client;
    var center = client.bottomRight * 0.5;

    dest = Rectangle.fromPoints(
        Grid.round(center +
            (project.size * -0.5 + project.offset) * (1 / project.zoom)),
        Grid.round(center +
            (project.size * 0.5 + project.offset) * (1 / project.zoom)));

    _gridified.redraw();
    _main.redraw();
  }

  static final Canvas _gridified = Canvas('gridified', (ctx, w, h) {
    ctx.globalCompositeOperation = 'source-over';
    ctx.imageSmoothingQuality = 'high';
    ctx.clearRect(0, 0, w, h);

    ctx.drawImageToRect(filteredImg.e, dest);
    project.grid.drawOn(ctx, dest, project.zoom);
  });

  static final Canvas _main = Canvas('main', (ctx, w, h) {
    ctx.clearRect(0, 0, w, h);
    ctx.drawImageToRect(inverted.e, dest);
    ctx.drawImage(_gridified.e, 0, 0);
  });
}
