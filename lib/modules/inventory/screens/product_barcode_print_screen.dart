import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart';
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
  bool _showPrice = true;
  bool _showName = true;
  String _barcodeType = 'Code128';

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
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Print',
            onPressed: _printBarcodes,
          ),
        ],
      ),
      body: Column(
        children: [
          // Settings Card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Print Settings',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Copies per item'),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: _copiesPerItem > 1
                                      ? () => setState(() => _copiesPerItem--)
                                      : null,
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                                Text(
                                  '$_copiesPerItem',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      setState(() => _copiesPerItem++),
                                  icon: const Icon(Icons.add_circle_outline),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Barcode Type'),
                            const SizedBox(height: 8),
                            DropdownButton<String>(
                              value: _barcodeType,
                              items: const [
                                DropdownMenuItem(
                                  value: 'Code128',
                                  child: Text('Code 128'),
                                ),
                                DropdownMenuItem(
                                  value: 'Code39',
                                  child: Text('Code 39'),
                                ),
                                DropdownMenuItem(
                                  value: 'EAN13',
                                  child: Text('EAN-13'),
                                ),
                                DropdownMenuItem(
                                  value: 'QRCode',
                                  child: Text('QR Code'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _barcodeType = value);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: CheckboxListTile(
                          title: const Text('Show Name'),
                          value: _showName,
                          onChanged: (value) =>
                              setState(() => _showName = value ?? true),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      Expanded(
                        child: CheckboxListTile(
                          title: const Text('Show Price'),
                          value: _showPrice,
                          onChanged: (value) =>
                              setState(() => _showPrice = value ?? true),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Preview Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.preview, color: Colors.teal.shade600),
                const SizedBox(width: 8),
                Text(
                  'Preview (${widget.items.length} items × $_copiesPerItem copies)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Barcode Preview Grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: widget.items.length,
              itemBuilder: (context, index) {
                final item = widget.items[index];
                return _BarcodePreviewCard(
                  item: item,
                  barcodeType: _barcodeType,
                  showName: _showName,
                  showPrice: _showPrice,
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _printBarcodes,
            icon: const Icon(Icons.print),
            label: Text(
              'Print ${widget.items.length * _copiesPerItem} Barcodes',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.teal.shade600,
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ),
      ),
    );
  }

  Barcode _getBarcodeType() {
    switch (_barcodeType) {
      case 'Code39':
        return Barcode.code39();
      case 'EAN13':
        return Barcode.ean13();
      case 'QRCode':
        return Barcode.qrCode();
      default:
        return Barcode.code128();
    }
  }

  pw.Barcode _getPdfBarcodeType() {
    switch (_barcodeType) {
      case 'Code39':
        return pw.Barcode.code39();
      case 'EAN13':
        return pw.Barcode.ean13();
      case 'QRCode':
        return pw.Barcode.qrCode();
      default:
        return pw.Barcode.code128();
    }
  }

  Future<void> _printBarcodes() async {
    final pdf = pw.Document();

    final barcodes = <pw.Widget>[];
    for (final item in widget.items) {
      for (int i = 0; i < _copiesPerItem; i++) {
        barcodes.add(
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                if (_showName)
                  pw.Text(
                    item.name,
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    maxLines: 1,
                  ),
                pw.SizedBox(height: 4),
                pw.BarcodeWidget(
                  barcode: _getPdfBarcodeType(),
                  data: item.sku,
                  width: 120,
                  height: 40,
                ),
                pw.SizedBox(height: 4),
                pw.Text(item.sku, style: const pw.TextStyle(fontSize: 8)),
                if (_showPrice)
                  pw.Text(
                    '৳${item.sellingPrice.toStringAsFixed(0)}',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        );
      }
    }

    // Create pages with grid layout
    const itemsPerPage = 10; // 2 columns × 5 rows
    for (int i = 0; i < barcodes.length; i += itemsPerPage) {
      final pageItems = barcodes.skip(i).take(itemsPerPage).toList();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (context) {
            return pw.Wrap(spacing: 10, runSpacing: 10, children: pageItems);
          },
        ),
      );
    }

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'inventory_barcodes',
    );
  }
}

class _BarcodePreviewCard extends StatelessWidget {
  final InventoryItem item;
  final String barcodeType;
  final bool showName;
  final bool showPrice;

  const _BarcodePreviewCard({
    required this.item,
    required this.barcodeType,
    required this.showName,
    required this.showPrice,
  });

  Barcode _getBarcodeType() {
    switch (barcodeType) {
      case 'Code39':
        return Barcode.code39();
      case 'EAN13':
        return Barcode.ean13();
      case 'QRCode':
        return Barcode.qrCode();
      default:
        return Barcode.code128();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showName)
              Text(
                item.name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 4),
            Expanded(
              child: BarcodeWidget(
                barcode: _getBarcodeType(),
                data: item.sku,
                drawText: true,
                style: const TextStyle(fontSize: 10),
              ),
            ),
            if (showPrice)
              Text(
                '৳${item.sellingPrice.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal.shade700,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
