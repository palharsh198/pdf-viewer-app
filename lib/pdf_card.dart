import 'package:flutter/material.dart';
import 'pdf_model.dart';

class PdfCard extends StatelessWidget {
  final PdfModel pdf;
  final bool isBookmarked;
  final VoidCallback onOpen;
  final VoidCallback onBookmark;
  final VoidCallback onDownload;
  final bool compact;

  const PdfCard({
    super.key,
    required this.pdf,
    required this.isBookmarked,
    required this.onOpen,
    required this.onBookmark,
    required this.onDownload,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(18),
        child: Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.picture_as_pdf,
                    color: Colors.red.shade400,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        pdf.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        pdf.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onBookmark,
                  icon: Icon(
                    isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  ),
                ),
                IconButton(
                  onPressed: onDownload,
                  icon: const Icon(Icons.download),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 68,
              width: 68,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.picture_as_pdf,
                color: Colors.red.shade400,
                size: 36,
              ),
            ),
            const Spacer(),
            Text(
              pdf.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              pdf.category,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            Text(
              pdf.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  onPressed: onBookmark,
                  icon: Icon(
                    isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  ),
                ),
                IconButton(
                  onPressed: onDownload,
                  icon: const Icon(Icons.download),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.visibility),
                  label: const Text("Open"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}