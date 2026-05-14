import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class OpenedPdfPage extends StatefulWidget {
  final String path;
  final String? title;

  const OpenedPdfPage({
    super.key,
    required this.path,
    this.title,
  });

  @override
  State<OpenedPdfPage> createState() => _OpenedPdfPageState();
}

class _OpenedPdfPageState extends State<OpenedPdfPage> {
  final PdfViewerController _controller = PdfViewerController();
  Uint8List? _bytes;
  bool _loading = true;
  String? _error;
  double _zoomLevel = 1.0;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      final file = File(widget.path);
      final exists = await file.exists();

      if (!exists) {
        setState(() {
          _error = "PDF file not found";
          _loading = false;
        });
        return;
      }

      final data = await file.readAsBytes();

      if (data.isEmpty) {
        setState(() {
          _error = "PDF file is empty";
          _loading = false;
        });
        return;
      }

      setState(() {
        _bytes = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Failed to open PDF: $e";
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.title ?? widget.path.split(Platform.pathSeparator).last;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          fileName,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: () {
              _zoomLevel += 0.25;
              _controller.zoomLevel = _zoomLevel;
              setState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: () {
              _zoomLevel -= 0.25;
              if (_zoomLevel < 1.0) _zoomLevel = 1.0;
              _controller.zoomLevel = _zoomLevel;
              setState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.first_page),
            onPressed: () => _controller.firstPage(),
          ),
          IconButton(
            icon: const Icon(Icons.last_page),
            onPressed: () => _controller.lastPage(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : SfPdfViewer.memory(
        _bytes!,
        controller: _controller,
        canShowPaginationDialog: true,
        canShowScrollHead: true,
        canShowScrollStatus: true,
        enableDoubleTapZooming: true,
      ),
    );
  }
}