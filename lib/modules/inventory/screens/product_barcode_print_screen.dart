import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/inventory_item.dart';

class ProductBarcodePrintScreen extends StatefulWidget {
  final List<InventoryItem> items;

  const ProductBarcodePrintScreen({super.key, required this.items});

  @override
  State<ProductBarcodePrintScreen> createState() =>
      _ProductBarcodePrintScreenState();
}

class _ProductBarcodePrintScreenState extends State<ProductBarcodePrintScreen> {
  int _copiesPerItem = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Print Barcodes'),
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.teal.shade600, Colors.teal.shade800],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Settings Card
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Text(
                    'Copies per item:',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  IconButton(
                    onPressed: _copiesPerItem > 1
                        ? () => setState(() => _copiesPerItem--)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                    iconSize: 20,
                  ),
                  Text(
                    '$_copiesPerItem',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _copiesPerItem++),
                    icon: const Icon(Icons.add_circle_outline),
                    iconSize: 20,
                  ),
                  const Spacer(),
                  Text(
                    '${widget.items.length * _copiesPerItem} barcodes',
                    style: TextStyle(
                      color: Colors.teal.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // A4 PDF Preview with Print and Share actions
          Expanded(
            child: PdfPreview(
              build: (format) => _generatePdf(),
              canChangePageFormat: false,
              canChangeOrientation: false,
              canDebug: false,
              pdfFileName: 'inventory_barcodes.pdf',
              allowPrinting: true,
              allowSharing: true,
              maxPageWidth: 700,
              actions: [
                PdfPreviewAction(
                  icon: const Icon(Icons.print),
                  onPressed: (context, build, pageFormat) async {
                    final pdfData = await _generatePdf();
                    await Printing.layoutPdf(
                      onLayout: (format) async => pdfData,
                      name: 'inventory_barcodes',
                    );
                  },
                ),
                PdfPreviewAction(
                  icon: const Icon(Icons.share),
                  onPressed: (context, build, pageFormat) async {
                    final pdfData = await _generatePdf();
                    await Printing.sharePdf(
                      bytes: pdfData,
                      filename: 'inventory_barcodes.pdf',
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<Uint8List> _generatePdf() async {
    final pdf = pw.Document();

    // A4 page dimensions: 595 x 842 points
    // With margins of 10 on each side: usable width = 575
    // 7 barcodes per row: each barcode width = 575 / 7 ≈ 82
    const double barcodeWidth = 75.0;
    const double barcodeHeight = 35.0;
    const double labelHeight = 65.0; // Total height including price
    const int barcodesPerRow = 7;
    const int rowsPerPage = 10;
    const int barcodesPerPage = barcodesPerRow * rowsPerPage; // 70 per page

    final barcodeData = <Map<String, dynamic>>[];
    for (final item in widget.items) {
      for (int i = 0; i < _copiesPerItem; i++) {
        barcodeData.add({'sku': item.sku, 'price': item.sellingPrice});
      }
    }

    // Create pages
    for (
      int pageStart = 0;
      pageStart < barcodeData.length;
      pageStart += barcodesPerPage
    ) {
      final pageItems = barcodeData
          .skip(pageStart)
          .take(barcodesPerPage)
          .toList();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(10),
          build: (context) {
            final rows = <pw.Widget>[];

            for (
              int rowStart = 0;
              rowStart < pageItems.length;
              rowStart += barcodesPerRow
            ) {
              final rowItems = pageItems
                  .skip(rowStart)
                  .take(barcodesPerRow)
                  .toList();

              rows.add(
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.start,
                  children: rowItems.map((data) {
                    return pw.Container(
                      width: barcodeWidth,
                      height: labelHeight,
                      margin: const pw.EdgeInsets.all(2),
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          pw.BarcodeWidget(
                            barcode: pw.Barcode.code128(),
                            data: data['sku'],
                            width: barcodeWidth - 4,
                            height: barcodeHeight,
                            drawText: false,
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Tk. ${(data['price'] as double).toStringAsFixed(0)}',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              );
            }

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: rows,
            );
          },
        ),
      );
    }

    return pdf.save();
  }
}
