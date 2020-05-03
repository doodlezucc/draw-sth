import 'dart:async';
import 'dart:convert';
import 'dart:html';
import 'dart:js';
import 'dart:math';

import 'grid.dart';
import 'io.dart';

class Project {
  static const zoomSpeed = 10;
  static const fileExtension = '.grid';

  final CanvasElement fg = querySelector('canvas#fg');
  final CanvasElement bg = querySelector('canvas#bg');
  final ImageElement img = querySelector('img');
  final DivElement offsetElement = querySelector('#offset');
  final DivElement editor = querySelector('.image');
  final InputElement ratioCheckbox = querySelector('#keepRatio');
  final InputElement cellX = querySelector('#cellX');
  final InputElement cellY = querySelector('#cellY');
  final InputElement lockCheckbox = querySelector('#lockGrid');
  final HtmlElement loader = querySelector('#loader');
  final DivElement _cursorTag = querySelector('#cursorTag');
  final ButtonElement saveButton = querySelector('#save');
  final ButtonElement exportButton = querySelector('#export');
  final SpanElement storageWarning = querySelector('.warning');
  Point _mousePos;
  Grid _grid;
  String _fileName = 'draw_sth$fileExtension';
  Storage _storage;
  bool _updateStorage = false;
  bool _blockStorage = false;

  String get filter => 'blur(5px)';

  bool get lockUser => loader.parent != null;
  bool get lockGrid => lockCheckbox.checked;
  bool get keepRatio => ratioCheckbox.checked;

  set loading(String s) {
    var blockParent = querySelector('.controls.section');
    saveButton.disabled = s.isNotEmpty;
    exportButton.disabled = s.isNotEmpty;
    if (s.isNotEmpty) {
      if (blockParent.querySelector('.block') == null) {
        blockParent.append(DivElement()..className = 'block');
      }
      editor.append(loader..innerHtml = s);
    } else {
      blockParent.querySelector('.block')?.remove();
      loader.remove();
      updateCursorTagString();
    }
  }

  int get minWidth {
    var rect = editor.client;
    var width = (img.width / img.height) * rect.height;
    return (width < rect.width ? width : rect.width).round() ~/ 2;
  }

  int _zoomWidth = 500;
  int get zoomWidth => _zoomWidth;
  set zoomWidth(int zoomWidth) {
    _zoomWidth = max(minWidth, zoomWidth);
    setSize();
  }

  double get zoom => img.width / zoomWidth;

  Point get zoomedSize => Point(_zoomWidth, img.height / zoom);
  Point get size => Point(img.width, img.height);

  Point _offset = Point(0, 0);
  Point get offset => _offset;
  set offset(Point offset) {
    _offset = offset;
    var point = (_offset * (1 / zoom)) - zoomedSize * 0.5;
    offsetElement.style.left = 'calc(50% + ${point.x}px)';
    offsetElement.style.top = 'calc(50% + ${point.y}px)';
  }

  void registerIntInput(
      InputElement e,
      void Function(double value, bool bonus) apply,
      String Function() applyBackwards,
      {void Function() onMouseUp}) {
    void parse(bool executeBonus) {
      var s = e.value;
      var v = double.tryParse(s);
      if (v != null && v >= 0) {
        apply(v, executeBonus);
        if (executeBonus) redraw();
      }
    }

    if (onMouseUp != null) {
      e.onMouseDown.listen((ev) {
        var sub;
        sub = window.onMouseUp.listen((ev) {
          onMouseUp();
          sub.cancel();
        });
      });
    }

    e.onInput.listen((ev) {
      parse(true);
    });
    parse(false);

    e.onBlur.listen((ev) {
      e.value = applyBackwards();
      if (onMouseUp != null) onMouseUp();
    });

    e.onKeyDown.listen((ev) {
      if (ev.keyCode == 13) {
        e.blur();
      }
    });
  }

  void displayLoadError() {
    var aText = ' URL response';

    loading = 'Oh, come on... failed to load.'
        '<br>:c'
        '<br><br>Your URL probably doesn\'t point to an image.'
        '<a title="${img.src}">Display $aText</a>'
        '<div class="wrap hidden"><iframe></iframe></div>'
        '<br>Try the following:'
        '<br>Copy the image (instead of its address) and press Ctrl V in this window.'
        '<br>or<br>Download the image and load it into the editor.';

    loader.querySelector('a').onClick.listen((e) {
      var hidden = loader.querySelector('div').classes.toggle('hidden');
      IFrameElement iframe = loader.querySelector('iframe');
      if (!hidden) iframe.src = img.src;

      loader.querySelector('a').text = (hidden ? 'Display' : 'Hide') + aText;
    });
  }

  void setSrc(String src) {
    var oldWidth = img.width;
    loading = 'Loading image...';
    var sub;
    sub = img.onLoad.listen((e) {
      sub.cancel();
      if (lockGrid) {
        lockCheckbox.click();
      }
      if (oldWidth > 0) {
        _grid.cellSize = _grid.cellSize * (img.width / oldWidth);
      }
      _grid.immediateClamp();
      offset = Point(0, 0);
      zoomWidth = minWidth * 2;
      loading = '';
      setSize();

      try {
        _storage['json'] = json.encode(this);
        _blockStorage = false;
      } catch (e) {
        _blockStorage = true;
      } finally {
        storageWarning.classes.toggle('hidden', !_blockStorage);
      }
    });
    print('set src to ' + (src.startsWith('data:') ? 'DATA' : src));
    img.src = src;
  }

  void applyCellSize(bool x, bool y) {
    if (x) cellX.value = _grid.cellSize.x.toStringAsFixed(1);
    if (y) cellY.value = _grid.cellSize.y.toStringAsFixed(1);
  }

  void moveCursorTag(MouseEvent e) {
    _mousePos = e.client;
    if (lockUser || e.movement.magnitude == 0) return;
    _cursorTag.style.left = '${e.client.x - editor.offsetLeft}px';
    _cursorTag.style.top = '${e.client.y - editor.offsetTop}px';

    if (e.buttons == 0) {
      updateCursorTagString();
    }
  }

  void updateCursorTagString() {
    if (_mousePos == null) return;
    var client = editor.client;
    var center = client.bottomRight * 0.5;
    var gridStart = Grid.round(
        center + (size * -0.5 + offset + _grid.position) * (1 / zoom));
    var cursor = Grid.round(_mousePos - editor.offset.topLeft);
    var cursorInGrid = cursor - gridStart;
    var s = '';
    if (cursorInGrid.x >= 0 &&
        cursorInGrid.y >= 0 &&
        cursorInGrid.x * zoom < _grid.size.x &&
        cursorInGrid.y * zoom < _grid.size.y) {
      var cells = Point(
          1 + ((cursorInGrid.x / _grid.cellSize.x) * zoom).floor(),
          _grid.array.y - ((cursorInGrid.y / _grid.cellSize.y) * zoom).floor());
      s = 'x: ${cells.x}, y: ${cells.y}';
    }

    setCursorTagString(s);
  }

  void setCursorTagString(String s) => _cursorTag.children.first.text = s;

  Project() {
    _grid = Grid(this);

    registerIntInput(cellX, (v, bonus) {
      if (v < 10 || !bonus) return;
      _grid.cellSize =
          Point(v, _grid.cellSize.y * (keepRatio ? v / _grid.cellSize.x : 1));
      applyCellSize(false, true);
    }, () {
      applyCellSize(true, false);
      return _grid.cellSize.x.toStringAsFixed(1);
    }, onMouseUp: _grid.fit);
    registerIntInput(cellY, (v, bonus) {
      if (v < 10 || !bonus) return;
      _grid.cellSize =
          Point(_grid.cellSize.x * (keepRatio ? v / _grid.cellSize.y : 1), v);
      applyCellSize(true, false);
    }, () {
      applyCellSize(true, true);
      return _grid.cellSize.y.toStringAsFixed(1);
    }, onMouseUp: _grid.fit);
    ratioCheckbox.checked = true;
    applyCellSize(true, true);
    registerIntInput(
        querySelector('#subdivisions'),
        (v, bonus) => _grid.subdivisions = v.round(),
        () => _grid.subdivisions.toString());

    // urlInput.onKeyDown.listen((e) {
    //   if (e.keyCode == 13) {
    //     setSrc(urlInput.value);
    //   }
    // });

    lockCheckbox.onInput.listen((e) {
      var lock = lockGrid;
      _grid.el.style.display = lock ? 'none' : 'block';
      setCursorTagString('');
      cellX.disabled = lock;
      cellY.disabled = lock;
      ratioCheckbox.disabled = lock;
      _updateStorage = true;
    });

    window.onResize.listen((e) => resizeCanvas());
    resizeCanvas();

    window.onMouseMove.listen(moveCursorTag);

    window.onBeforeUnload.listen((e) {
      if (_blockStorage) {
        (e as BeforeUnloadEvent).returnValue =
            'You may want to download your grid before leaving the site.';
      }
    });

    storageWarning.onMouseEnter.listen((e) {
      if (storageWarning.classes.remove('new')) {
        _storage['readWarning'] = 'true';
      }
    });

    var previousLoading = '';

    editor.onDragEnter.listen((e) {
      previousLoading = loader.innerHtml;
      loading = 'Drop file here!';
    });
    window.onDragOver.listen((e) {
      e.preventDefault();
    });
    editor.onDragLeave.listen((e) {
      loading = previousLoading;
    });
    window.onDrop.listen((e) {
      e.preventDefault();

      var transfer = e.dataTransfer;

      for (var i = 0; i < transfer.files.length; i++) {
        var file = transfer.files[i];
        return uploadFile(file);
      }
      for (var type in transfer.types) {
        var data = transfer.getData(type);
        //print('$type: $data');
        if (type == 'text/html') {
          var src = data.substring(data.indexOf('src=\"') + 5);
          return setSrc(src.substring(0, src.indexOf('\"')));
        }
      }
      loading = previousLoading;
    });

    editor.onMouseDown.listen((e) {
      HtmlElement el = e.target;
      if (lockUser || el.matchesWithAncestors('#grid')) return;
      var pos1 = offset;

      var mouse1 = e.client;
      var subMove = document.onMouseMove.listen((e) {
        if (e.movement.magnitude == 0) return;
        var diff = e.client - mouse1;

        offset = pos1 + diff * zoom;
        redraw();
      });

      var subUp;
      subUp = document.onMouseUp.listen((e) {
        subMove.cancel();
        subUp.cancel();
      });
    });

    img.onError.listen((e) => displayLoadError());

    querySelector('#loadUrl').onClick.listen((e) {
      String url = context.callMethod('prompt', [
        'Enter the URL address of an image you found on the internet.\n'
            'WARNING: This will discard your current grid!',
        ''
      ]);
      if (url != null && url.isNotEmpty) {
        if (url.startsWith('<')) {
          url = url.substring(url.indexOf('src="') + 5);
          url = url.substring(0, url.indexOf('"'));
        }
        setSrc(url);
      }
    });
    saveButton.onClick.listen((e) => downloadGrid());
    exportButton.onClick.listen((e) => export());
    InputElement fileInput = querySelector('#upload');
    fileInput.onChange.listen((e) {
      var file = fileInput.files[0];
      if (file != null) {
        uploadFile(file);
      }
      fileInput.value = '';
    });

    document.onPaste.listen((e) {
      if (e.target is InputElement) return;

      if (e.clipboardData.files.isNotEmpty) {
        var file = e.clipboardData.files.first;
        return uploadFile(file);
      }

      var url = e.clipboardData.getData('text/plain');
      if (url != null && url.startsWith('http')) {
        setSrc(url);
      }
    });

    document.onKeyDown.listen((e) {
      if (e.target is! InputElement) {
        if (e.shiftKey) {
          switch (e.key) {
            case 'R':
              reloadStylesheet(); //TODO remove from final version
              return;
          }
        }
        if (lockUser) return;
        switch (e.key) {
          case '+':
            zoomWidth += zoomSpeed;
            return;
          case '-':
            zoomWidth -= zoomSpeed;
            return;
          case 'l':
            lockCheckbox.click();
            return;
          case 'o':
            e.preventDefault();
            if (e.ctrlKey) fileInput.click();
            return;
          case 's':
            e.preventDefault();
            if (e.ctrlKey) downloadGrid();
            return;
        }
        if (lockGrid) return;
        var speed = zoom;
        var diffX = 0.0;
        var diffY = 0.0;
        switch (e.keyCode) {
          case 37: //left
            diffX += -1;
            break;
          case 38: //up
            diffY += -1;
            break;
          case 39: //right
            diffX += 1;
            break;
          case 40: //down
            diffY += 1;
            break;
        }
        if (diffX != 0 || diffY != 0) {
          _grid.position = _grid.position + Point(diffX, diffY) * speed;
          redraw();
        }
      }
    });

    document.onMouseWheel.listen((e) {
      if (lockUser) return;
      zoomWidth -= (zoomSpeed * min(max(e.deltaY, -5), 5)).round();
    });

    try {
      _storage = window.localStorage;
      if (_storage['readWarning'] == 'true') {
        storageWarning.classes.remove('new');
      }
      Timer.periodic(Duration(seconds: 1), (timer) {
        if (_updateStorage) {
          _updateStorage = false;
          saveToStorage();
        }
      });

      loadFromStorage();
    } catch (e) {
      print('Saving in-browser not allowed... launching demo!');
      _blockStorage = true;
      storageWarning.classes.remove('new');
      var div = storageWarning.querySelector('div');
      var html = div.innerHtml;
      html = html.substring(html.indexOf('<br>'));
      html = html.substring(0, html.indexOf('<', 4));
      div.innerHtml = '<span>Not allowed to save in-browser!</span>' + html;
      initDemo();
    }
  }

  void export() async {
    // Worst practice, duplicate code
    var canvas = CanvasElement(width: img.width, height: img.height);
    var mainCtx = canvas.context2D;
    mainCtx.filter = 'invert(1) grayscale(1) brightness(0.8) contrast(1000)';
    mainCtx.drawImage(img, 0, 0);

    var fg = CanvasElement(width: img.width, height: img.height);
    var fgCtx = fg.context2D;
    fgCtx.drawImage(img, 0, 0);
    _grid.drawOn(fgCtx, Rectangle(0, 0, img.width, img.height), 1);

    mainCtx.filter = 'none';
    mainCtx.drawImage(fg, 0, 0);

    var data = await canvas.toDataUrl();
    download('export.png', data);
  }

  void uploadImage(File file) {
    if (!_fileName.endsWith(fileExtension)) {
      _fileName = '$_fileName$fileExtension';
    }
    var reader = FileReader();
    reader.onLoad.listen((e) {
      String dataUrl = (e.target as dynamic).result;
      setSrc(dataUrl);
    });
    reader.readAsDataUrl(file);
  }

  void uploadSaveFile(File file) {
    var reader = FileReader();
    reader.onLoad.listen((e) {
      try {
        String jsonString = (e.target as dynamic).result;
        fromJson(json.decode(jsonString));
      } catch (err, trace) {
        print('$err\n--- Stacktrace ---\n$trace');
        loading = 'Loading your file as a savefile failed.'
            '<br>$err'
            '<br><br>Try loading an image or a valid $fileExtension file.';
      }
    });
    reader.readAsText(file);
  }

  void uploadFile(File file) {
    loading = 'Uploading...';
    _fileName = file.name;
    if (file.type.startsWith('image/')) {
      uploadImage(file);
    } else {
      uploadSaveFile(file);
    }
  }

  Map<String, dynamic> toJson() => {
        'src': img.src,
        'offset': pointToJson(offset),
        'zoomWidth': zoomWidth,
        'lock': lockGrid,
        'grid': _grid.toJson()
      };
  void fromJson(Map<String, dynamic> json) {
    _offset = pointFromJson(json['offset']);
    _zoomWidth = json['zoomWidth'];
    _grid.fromJson(json['grid']);
    (querySelector('#subdivisions') as InputElement).value =
        _grid.subdivisions.toString();
    applyCellSize(true, true);

    var sub;
    sub = img.onLoad.listen((e) {
      sub.cancel();
      loading = '';
      setSize();
      bool shouldLock = json['lock'] ?? true;
      if ((shouldLock && !lockGrid) || (!shouldLock && lockGrid)) {
        lockCheckbox.click();
      }
    });
    loading = 'Loading image...';
    img.src = json['src'];
  }

  void download(String fileName, String href) {
    var aElement = AnchorElement(href: href);
    aElement.download = fileName;
    document.body.append(aElement);
    aElement.click();
    aElement.remove();
  }

  void downloadGrid() {
    download(
        _fileName,
        'data:text/json;charset=utf-8,' +
            Uri.encodeComponent(toJsonString(this)));
  }

  void saveToStorage() {
    if (!_blockStorage) {
      try {
        _storage['json'] = json.encode(this);
        _blockStorage = false;
      } catch (e) {
        _blockStorage = true;
      } finally {
        storageWarning.classes.toggle('hidden', !_blockStorage);
      }
    }
  }

  void loadFromStorage() {
    _updateStorage = false;
    if (_storage.isNotEmpty) {
      fromJson(json.decode(_storage['json']));
    } else {
      initDemo();
    }
  }

  void clearStorage() {
    _storage.clear();
  }

  void reloadStylesheet() {
    LinkElement cssLink = querySelector('link');
    cssLink.href = cssLink.href;
  }

  void initDemo() {
    //setSrc('jon.png');
    loading = 'Start out by dragging an image into this window,'
        '<br>or by clicking on one of the buttons at the top right!';
  }

  void setSize() {
    _grid.position = _grid.position;
    _grid.size = _grid.size;
    offset = offset;
    updateCursorTagString();
    if (!lockUser) redraw();
  }

  void resizeCanvas() {
    fg.width = editor.clientWidth;
    fg.height = editor.clientHeight;
    bg.width = editor.clientWidth;
    bg.height = editor.clientHeight;
    if (!lockUser) redraw();
  }

  void redraw() {
    _updateStorage = true;

    CanvasRenderingContext2D bgCtx = bg.getContext('2d', {'alpha': false});

    bgCtx.clearRect(0, 0, bg.width, bg.height);

    var client = editor.client;
    var center = client.bottomRight * 0.5;

    var dest = Rectangle.fromPoints(
        Grid.round(center + (size * -0.5 + offset) * (1 / zoom)),
        Grid.round(center + (size * 0.5 + offset) * (1 / zoom)));

    bgCtx.filter = 'invert(1) grayscale(1) brightness(0.8) contrast(1000)';
    bgCtx.drawImageToRect(img, dest);

    var fgCtx = fg.context2D;
    fgCtx.globalCompositeOperation = 'source-over';
    fgCtx.imageSmoothingQuality = 'high';
    fgCtx.clearRect(0, 0, fg.width, fg.height);

    fgCtx.drawImageToRect(img, dest);
    _grid.drawOn(fgCtx, dest, zoom);
  }
}
