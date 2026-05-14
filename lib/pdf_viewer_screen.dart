import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PdfViewerScreen extends StatefulWidget {
  final String title;
  final Uint8List? bytes;
  final String? url;

  const PdfViewerScreen({
    super.key,
    required this.title,
    this.bytes,
    this.url,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final PdfViewerController _controller = PdfViewerController();
  double zoomLevel = 1.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: () {
              setState(() {
                zoomLevel += 0.25;
                _controller.zoomLevel = zoomLevel;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: () {
              setState(() {
                zoomLevel -= 0.25;
                if (zoomLevel < 1.0) {
                  zoomLevel = 1.0;
                }
                _controller.zoomLevel = zoomLevel;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.first_page),
            onPressed: () {
              _controller.firstPage();
            },
          ),
          IconButton(
            icon: const Icon(Icons.last_page),
            onPressed: () {
              _controller.lastPage();
            },
          ),
        ],
      ),
      body: _buildViewer(),
    );
  }

  Widget _buildViewer() {
    if (widget.bytes != null && widget.bytes!.isNotEmpty) {
      return SfPdfViewer.memory(
        widget.bytes!,
        controller: _controller,
        canShowPaginationDialog: true,
        canShowScrollHead: true,
        canShowScrollStatus: true,
        enableDoubleTapZooming: true,
      );
    }

    if (widget.url != null && widget.url!.trim().isNotEmpty) {
      // ✅ FIX
      final cleanUrl = widget.url!.trim();

      return SfPdfViewer.network(
        cleanUrl,
        controller: _controller,
        canShowPaginationDialog: true,
        canShowScrollHead: true,
        canShowScrollStatus: true,
        enableDoubleTapZooming: true,
      );
    }

    return const Center(
      child: Text(
        "No PDF available",
        style: TextStyle(fontSize: 16),
      ),
    );
  }
}