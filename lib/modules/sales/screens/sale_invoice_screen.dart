import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/sale.dart';

class SaleInvoiceScreen extends StatelessWidget {
  final Sale sale;
  final String shopName;
  final String? shopAddress;
  final String? shopPhone;
  final String? shopEmail;

  const SaleInvoiceScreen({
    super.key,
    required this.sale,
    required this.shopName,
    this.shopAddress,
    this.shopPhone,
    this.shopEmail,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Invoice #${sale.saleNumber}'),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade600, Colors.blue.shade800],
            ),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => _printInvoice(context),
            icon: const Icon(Icons.print),
            tooltip: 'Print Invoice',
          ),
          IconButton(
            onPressed: () => _shareInvoice(context),
            icon: const Icon(Icons.share),
            tooltip: 'Share Invoice',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Preview Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                shopName,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                              if (shopAddress != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  shopAddress!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                              if (shopPhone != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Tel: $shopPhone',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // QR Code
                        Column(
                          children: [
                            QrImageView(
                              data: 'INVOICE:${sale.id}:${sale.saleNumber}',
                              version: QrVersions.auto,
                              size: 80,
                              backgroundColor: Colors.white,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Scan to verify',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(thickness: 2),
                    const SizedBox(height: 16),

                    // Invoice Info
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'INVOICE',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '#${sale.saleNumber}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Date',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            Text(
                              DateFormat('MMM dd, yyyy').format(sale.saleDate),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              DateFormat('hh:mm a').format(sale.saleDate),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Customer Info
                    if (sale.customerName != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.person, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bill To:',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                                Text(
                                  sale.customerName!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Items Table Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade600,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              'Item',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Qty',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Price',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Total',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Items List
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                      ),
                      child: Column(
                        children: sale.items.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          final isLast = index == sale.items.length - 1;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: index.isEven
                                  ? Colors.grey.shade50
                                  : Colors.white,
                              border: isLast
                                  ? null
                                  : Border(
                                      bottom: BorderSide(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    item.itemName,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '${item.quantity}',
                                    style: const TextStyle(fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '৳${item.sellingPrice.toStringAsFixed(0)}',
                                    style: const TextStyle(fontSize: 12),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '৳${item.totalSelling.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Totals
                    Row(
                      children: [
                        const Spacer(),
                        SizedBox(
                          width: 200,
                          child: Column(
                            children: [
                              _buildTotalRow(
                                'Subtotal',
                                '৳${sale.totalSelling.toStringAsFixed(2)}',
                              ),
                              if (sale.discountAmount > 0)
                                _buildTotalRow(
                                  'Discount',
                                  '-৳${sale.discountAmount.toStringAsFixed(2)}',
                                  isDiscount: true,
                                ),
                              const Divider(),
                              _buildTotalRow(
                                'Total',
                                '৳${sale.finalAmount.toStringAsFixed(2)}',
                                isTotal: true,
                              ),
                              if (sale.paidAmount > 0)
                                _buildTotalRow(
                                  'Paid',
                                  '৳${sale.paidAmount.toStringAsFixed(2)}',
                                ),
                              if (sale.dueAmount > 0)
                                _buildTotalRow(
                                  'Due',
                                  '৳${sale.dueAmount.toStringAsFixed(2)}',
                                  isDue: true,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Payment Method
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _getPaymentIcon(sale.paymentMethod),
                            color: Colors.green.shade700,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Payment: ${_getPaymentLabel(sale.paymentMethod)}',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Footer
                    Center(
                      child: Column(
                        children: [
                          Text(
                            'Thank you for your business!',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Generated by MCS Management',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _printInvoice(context),
                    icon: const Icon(Icons.print),
                    label: const Text('Print'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _shareInvoice(context),
                    icon: const Icon(Icons.share),
                    label: const Text('Share PDF'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blue.shade600,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalRow(
    String label,
    String value, {
    bool isTotal = false,
    bool isDiscount = false,
    bool isDue = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
              color: isDue
                  ? Colors.red.shade600
                  : isDiscount
                      ? Colors.green.shade600
                      : null,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              fontSize: isTotal ? 16 : 14,
              color: isDue
                  ? Colors.red.shade600
                  : isDiscount
                      ? Colors.green.shade600
                      : null,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getPaymentIcon(String method) {
    switch (method) {
      case 'cash':
        return Icons.money;
      case 'card':
        return Icons.credit_card;
      case 'mobile_banking':
        return Icons.phone_android;
      case 'credit':
        return Icons.account_balance;
      default:
        return Icons.payment;
    }
  }

  String _getPaymentLabel(String method) {
    switch (method) {
      case 'cash':
        return 'Cash';
      case 'card':
        return 'Card';
      case 'mobile_banking':
        return 'Mobile Banking';
      case 'credit':
        return 'Credit/Due';
      default:
        return method;
    }
  }

  Future<void> _printInvoice(BuildContext context) async {
    final pdf = await _generatePdf();
    await Printing.layoutPdf(
      onLayout: (format) => pdf.save(),
      name: 'Invoice_${sale.saleNumber}',
    );
  }

  Future<void> _shareInvoice(BuildContext context) async {
    final pdf = await _generatePdf();
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Invoice_${sale.saleNumber}.pdf',
    );
  }

  Future<pw.Document> _generatePdf() async {
    final pdf = pw.Document();

    // Generate QR code data
    final qrData = 'INVOICE:${sale.id}:${sale.saleNumber}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        shopName,
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800,
                        ),
                      ),
                      if (shopAddress != null)
                        pw.Text(
                          shopAddress!,
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey600,
                          ),
                        ),
                      if (shopPhone != null)
                        pw.Text(
                          'Tel: $shopPhone',
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey600,
                          ),
                        ),
                    ],
                  ),
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: qrData,
                    width: 80,
                    height: 80,
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Divider(thickness: 2),
              pw.SizedBox(height: 20),

              // Invoice Info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'INVOICE',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.Text(
                        '#${sale.saleNumber}',
                        style: const pw.TextStyle(color: PdfColors.grey600),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Date: ${DateFormat('MMM dd, yyyy').format(sale.saleDate)}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        'Time: ${DateFormat('hh:mm a').format(sale.saleDate)}',
                        style: const pw.TextStyle(color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Customer
              if (sale.customerName != null) ...[
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Text('Bill To: '),
                      pw.Text(
                        sale.customerName!,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
              ],

              // Items Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(1.2),
                  3: const pw.FlexColumnWidth(1.2),
                },
                children: [
                  // Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.blue600),
                    children: [
                      _buildPdfTableCell('Item', isHeader: true),
                      _buildPdfTableCell('Qty', isHeader: true, align: pw.TextAlign.center),
                      _buildPdfTableCell('Price', isHeader: true, align: pw.TextAlign.right),
                      _buildPdfTableCell('Total', isHeader: true, align: pw.TextAlign.right),
                    ],
                  ),
                  // Items
                  ...sale.items.map(
                    (item) => pw.TableRow(
                      children: [
                        _buildPdfTableCell(item.itemName),
                        _buildPdfTableCell('${item.quantity}', align: pw.TextAlign.center),
                        _buildPdfTableCell('৳${item.sellingPrice.toStringAsFixed(0)}', align: pw.TextAlign.right),
                        _buildPdfTableCell('৳${item.totalSelling.toStringAsFixed(0)}', align: pw.TextAlign.right),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Totals
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  width: 200,
                  child: pw.Column(
                    children: [
                      _buildPdfTotalRow('Subtotal', '৳${sale.totalSelling.toStringAsFixed(2)}'),
                      if (sale.discountAmount > 0)
                        _buildPdfTotalRow('Discount', '-৳${sale.discountAmount.toStringAsFixed(2)}'),
                      pw.Divider(),
                      _buildPdfTotalRow('Total', '৳${sale.finalAmount.toStringAsFixed(2)}', isTotal: true),
                      if (sale.paidAmount > 0)
                        _buildPdfTotalRow('Paid', '৳${sale.paidAmount.toStringAsFixed(2)}'),
                      if (sale.dueAmount > 0)
                        _buildPdfTotalRow('Due', '৳${sale.dueAmount.toStringAsFixed(2)}'),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(height: 30),

              // Payment Method
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green50,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColors.green200),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'Payment Method: ${_getPaymentLabel(sale.paymentMethod)}',
                    style: pw.TextStyle(
                      color: PdfColors.green800,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ),
              pw.Spacer(),

              // Footer
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Thank you for your business!',
                      style: pw.TextStyle(
                        fontStyle: pw.FontStyle.italic,
                        color: PdfColors.grey600,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Generated by MCS Management',
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  pw.Widget _buildPdfTableCell(
    String text, {
    bool isHeader = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: isHeader ? pw.FontWeight.bold : null,
          color: isHeader ? PdfColors.white : PdfColors.black,
          fontSize: isHeader ? 11 : 10,
        ),
        textAlign: align,
      ),
    );
  }

  pw.Widget _buildPdfTotalRow(String label, String value, {bool isTotal = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: isTotal ? pw.FontWeight.bold : null,
              fontSize: isTotal ? 14 : 12,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontWeight: isTotal ? pw.FontWeight.bold : null,
              fontSize: isTotal ? 14 : 12,
            ),
          ),
        ],
      ),
    );
  }
}
