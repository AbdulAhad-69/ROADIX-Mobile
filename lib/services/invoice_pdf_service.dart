import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

/// Normalized receipt payload rendered into a downloadable ROADIX PDF invoice.
class InvoiceData {
  final String serviceId;
  final String title;
  final String date;
  final String techName;
  final String vehicle;
  final String location;
  final String diagFee;
  final String laborFee;
  final String partsTotal;
  final String totalAmount;
  final String paymentMethod;
  final String paymentStatus;

  const InvoiceData({
    required this.serviceId,
    required this.title,
    required this.date,
    required this.techName,
    required this.vehicle,
    required this.location,
    required this.diagFee,
    required this.laborFee,
    required this.partsTotal,
    required this.totalAmount,
    required this.paymentMethod,
    required this.paymentStatus,
  });

  factory InvoiceData.fromItem(Map<String, dynamic> item) {
    return InvoiceData(
      serviceId: (item['serviceId'] ?? 'RDX-INV').toString(),
      title: (item['title'] ?? 'Roadside Assistance').toString(),
      date: (item['date'] ?? '').toString(),
      techName: (item['techName'] ?? 'Assigned Technician').toString(),
      vehicle: (item['vehicle'] ?? 'Vehicle').toString(),
      location: (item['location'] ?? 'Roadside Location').toString(),
      diagFee: (item['diagFee'] ?? 'BDT 0').toString(),
      laborFee: (item['laborFee'] ?? 'BDT 0').toString(),
      partsTotal: (item['partsTotal'] ?? 'BDT 0').toString(),
      totalAmount: (item['amount'] ?? 'BDT 0').toString(),
      paymentMethod: (item['paymentMethod'] ?? 'Pending').toString(),
      paymentStatus: (item['paymentStatus'] ?? item['status'] ?? 'Completed').toString(),
    );
  }
}

typedef SharePdfCallback = Future<void> Function(File pdfFile, InvoiceData data);

/// Generates real PDF rescue invoices, writes them to app storage, and invokes
/// the native OS share/save sheet.
class InvoicePdfService {
  const InvoicePdfService._();

  static String _asciiSafe(String raw) {
    return raw
        .replaceAll('৳', 'BDT ')
        .replaceAll('•', '-')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Renders a valid A4 PDF byte buffer containing itemized rescue billing details.
  static Future<Uint8List> buildInvoicePdfBytes(InvoiceData data) async {
    final doc = pw.Document(
      title: 'ROADIX Invoice ${data.serviceId}',
      author: 'ROADIX Roadside Assistance',
    );

    const crimson = PdfColor.fromInt(0xFFDC2626);
    const chassis = PdfColor.fromInt(0xFF0F172A);
    const muted = PdfColor.fromInt(0xFF475569);
    const border = PdfColor.fromInt(0xFFE2E8F0);
    const porcelain = PdfColor.fromInt(0xFFF8FAFC);

    pw.Widget lineRow(String label, String value, {bool bold = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 5),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              child: pw.Text(
                label,
                style: pw.TextStyle(
                  color: bold ? chassis : muted,
                  fontSize: bold ? 12 : 10.5,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                ),
              ),
            ),
            pw.Text(
              value,
              style: pw.TextStyle(
                color: bold ? crimson : chassis,
                fontSize: bold ? 13 : 10.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'ROADIX',
                      style: pw.TextStyle(
                        color: crimson,
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Roadside Rescue & Dispatch Invoice',
                      style: const pw.TextStyle(color: muted, fontSize: 10),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: pw.BoxDecoration(
                    color: porcelain,
                    border: pw.Border.all(color: border),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Text(
                    data.paymentStatus.toUpperCase(),
                    style: pw.TextStyle(
                      color: chassis,
                      fontSize: 9.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 18),
            pw.Divider(color: border),
            pw.SizedBox(height: 14),
            pw.Text(
              data.title,
              style: pw.TextStyle(
                color: chassis,
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Invoice ID: ${data.serviceId}',
              style: const pw.TextStyle(color: muted, fontSize: 10.5),
            ),
            if (data.date.isNotEmpty)
              pw.Text(
                'Date: ${data.date}',
                style: const pw.TextStyle(color: muted, fontSize: 10.5),
              ),
            pw.SizedBox(height: 16),
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: porcelain,
                border: pw.Border.all(color: border),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                children: [
                  lineRow('Technician', _asciiSafe(data.techName)),
                  lineRow('Vehicle', _asciiSafe(data.vehicle)),
                  lineRow('Location', _asciiSafe(data.location)),
                  lineRow('Payment Method', _asciiSafe(data.paymentMethod)),
                ],
              ),
            ),
            pw.SizedBox(height: 18),
            pw.Text(
              'Itemized Charges',
              style: pw.TextStyle(
                color: chassis,
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: border),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                children: [
                  lineRow('Diagnostic Fee', _asciiSafe(data.diagFee)),
                  lineRow('Labor & Service', _asciiSafe(data.laborFee)),
                  lineRow('Replacement Parts', _asciiSafe(data.partsTotal)),
                  pw.Divider(color: border),
                  lineRow(
                    'Total Amount',
                    _asciiSafe(data.totalAmount),
                    bold: true,
                  ),
                ],
              ),
            ),
            pw.Spacer(),
            pw.Divider(color: border),
            pw.SizedBox(height: 6),
            pw.Text(
              'Generated by ROADIX Mobile - Thank you for riding safely.',
              style: const pw.TextStyle(color: muted, fontSize: 9),
            ),
          ],
        ),
      ),
    );

    return Uint8List.fromList(await doc.save());
  }

  /// Writes the PDF invoice to [outputDir] (or app documents directory) and returns the created [File].
  static Future<File> saveInvoicePdf(
    InvoiceData data, {
    Directory? outputDir,
  }) async {
    final bytes = await buildInvoicePdfBytes(data);
    final dir = outputDir ?? await getApplicationDocumentsDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final sanitizedId =
        data.serviceId.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final file = File('${dir.path}${Platform.pathSeparator}${sanitizedId}_invoice.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Generates, persists, and opens the native OS share/save sheet for the PDF invoice.
  static Future<File> saveAndShareInvoice(
    InvoiceData data, {
    Directory? outputDir,
    SharePdfCallback? onShare,
  }) async {
    final file = await saveInvoicePdf(data, outputDir: outputDir);
    if (onShare != null) {
      await onShare(file, data);
    } else {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf')],
          subject: 'ROADIX Invoice ${data.serviceId}',
          text: 'ROADIX digital rescue invoice ${data.serviceId}',
        ),
      );
    }
    return file;
  }
}
