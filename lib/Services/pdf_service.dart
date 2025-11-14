import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pasada_driver_side/data/models/booking_receipt_model.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Service for generating PDF booking receipts
class PdfService {
  PdfService._();
  static final PdfService instance = PdfService._();

  /// Generate PDF receipt for bookings
  ///
  /// [driverName] - Full name of the driver
  /// [vehicleId] - Vehicle ID
  /// [plateNumber] - Vehicle plate number
  /// [routeName] - Route name
  /// [bookings] - List of booking receipts
  /// [reportType] - Type of report (daily, weekly, monthly)
  /// [dateRange] - Date range string for the report
  Future<File?> generateBookingReceiptPdf({
    required String driverName,
    required String vehicleId,
    required String plateNumber,
    required String routeName,
    required List<BookingReceipt> bookings,
    required String reportType,
    required String dateRange,
  }) async {
    try {
      final pdf = pw.Document();

      // Load Pasada logo
      final logoData = await rootBundle.load('assets/png/pasada_logo.png');
      final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());

      // Calculate summary metrics
      final totalBookings = bookings.length;
      final totalEarnings = bookings.fold(0, (sum, b) => sum + (b.fare ?? 0));

      // Count by passenger type
      final passengerTypeCounts = <String, int>{};
      for (final booking in bookings) {
        final type = booking.passengerType;
        if (type != null && type.isNotEmpty) {
          passengerTypeCounts[type] = (passengerTypeCounts[type] ?? 0) + 1;
        } else {
          passengerTypeCounts['Regular'] =
              (passengerTypeCounts['Regular'] ?? 0) + 1;
        }
      }

      // Build PDF with compact layout
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(25),
          maxPages: 200, // Increase page limit significantly
          header: (context) {
            // Only show header on first page
            if (context.pageNumber == 1) {
              return pw.Column(
                children: [
                  _buildCompactHeader(
                    logoImage,
                    reportType,
                    driverName,
                    vehicleId,
                    plateNumber,
                    routeName,
                    dateRange,
                  ),
                  pw.SizedBox(height: 12),
                  _buildSummary(
                    totalBookings,
                    totalEarnings,
                    passengerTypeCounts,
                  ),
                  pw.SizedBox(height: 12),
                ],
              );
            }
            return pw.SizedBox.shrink();
          },
          build: (context) => [
            _buildCompactBookingsTable(bookings),
          ],
          footer: (context) => _buildFooter(context),
        ),
      );

      // Save to file
      final output = await _getOutputFile(reportType);
      final file = File(output.path);
      await file.writeAsBytes(await pdf.save());

      return file;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error generating PDF: $e');
      }
      return null;
    }
  }

  /// Build compact PDF header section (for large reports)
  pw.Widget _buildCompactHeader(
    pw.MemoryImage logo,
    String reportType,
    String driverName,
    String vehicleId,
    String plateNumber,
    String routeName,
    String dateRange,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        // Smaller Logo
        pw.Image(logo, width: 60, height: 60),
        pw.SizedBox(height: 6),

        // Title
        pw.Text(
          'BOOKING RECEIPT - ${reportType.toUpperCase()}',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),

        // Compact Driver Information
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Driver: $driverName',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.Text(
                    'Vehicle: $vehicleId ($plateNumber)',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Route: $routeName',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.Text(
                    'Period: $dateRange',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build summary section
  pw.Widget _buildSummary(
    int totalBookings,
    int totalEarnings,
    Map<String, int> passengerTypeCounts,
  ) {
    final formatter = NumberFormat.currency(symbol: 'PHP ', decimalDigits: 2);

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        // color: PdfColors.grey200,
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'SUMMARY',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Divider(thickness: 0.5),
          pw.SizedBox(height: 6),

          // Total bookings and earnings in compact row
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Total Bookings: $totalBookings',
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.Text(
                'Total Earnings: ${formatter.format(totalEarnings.toDouble())}',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green700,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),

          // Passenger type breakdown - inline
          if (passengerTypeCounts.isNotEmpty) ...[
            pw.Row(
              children: [
                pw.Text(
                  'Passenger Types: ',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    passengerTypeCounts.entries
                        .where((e) => e.key.isNotEmpty)
                        .map((e) =>
                            '${_abbreviatePassengerType(e.key)}: ${e.value}')
                        .join('   |   '),
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Build compact bookings table for large number of bookings
  pw.Widget _buildCompactBookingsTable(List<BookingReceipt> bookings) {
    if (bookings.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(20),
        child: pw.Center(
          child: pw.Text(
            'No bookings found for this period',
            style: pw.TextStyle(
              fontSize: 12,
              color: PdfColors.grey600,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
        ),
      );
    }

    final formatter = NumberFormat.currency(symbol: 'PHP ', decimalDigits: 2);
    final dateFormatter = DateFormat('MMM dd hh:mm a');

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'BOOKING DETAILS',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Divider(thickness: 1.5),
        pw.SizedBox(height: 8),

        // Table with bookings
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FixedColumnWidth(25), // #
            1: const pw.FlexColumnWidth(2), // ID
            2: const pw.FlexColumnWidth(2), // Date
            3: const pw.FlexColumnWidth(3), // Pickup
            4: const pw.FlexColumnWidth(3), // Drop-off
            5: const pw.FlexColumnWidth(1), // Type
            6: const pw.FlexColumnWidth(1), // Fare
          },
          children: [
            // Header row
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
              ),
              children: [
                _buildTableHeader('#'),
                _buildTableHeader('ID'),
                _buildTableHeader('Date'),
                _buildTableHeader('Pickup'),
                _buildTableHeader('Drop-off'),
                _buildTableHeader('Type'),
                _buildTableHeader('Fare'),
              ],
            ),
            // Data rows
            ...bookings.asMap().entries.map((entry) {
              final index = entry.key;
              final booking = entry.value;
              final date = booking.completedAt ?? booking.createdAt;

              // Format date (database stores Philippines time as UTC)
              final dateStr = date != null ? dateFormatter.format(date) : 'N/A';

              return pw.TableRow(
                children: [
                  _buildTableCell('${index + 1}'),
                  _buildTableCell(booking.bookingId),
                  _buildTableCell(dateStr),
                  _buildTableCell(
                    _truncateText(booking.pickupAddress, 25),
                  ),
                  _buildTableCell(
                    _truncateText(booking.dropoffAddress, 25),
                  ),
                  _buildTableCell(
                    _abbreviatePassengerType(booking.passengerType),
                  ),
                  _buildTableCell(
                    formatter.format(booking.fare?.toDouble() ?? 0.0),
                    bold: true,
                  ),
                ],
              );
            }).toList(),
          ],
        ),
      ],
    );
  }

  /// Build table header cell
  pw.Widget _buildTableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(2),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 7,
          fontWeight: pw.FontWeight.bold,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  /// Build table data cell
  pw.Widget _buildTableCell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(2),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 6,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        maxLines: 2,
        overflow: pw.TextOverflow.clip,
      ),
    );
  }

  /// Truncate text to max length
  String _truncateText(String? text, int maxLength) {
    if (text == null || text.isEmpty) return 'N/A';
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3)}...';
  }

  /// Abbreviate passenger type
  String _abbreviatePassengerType(String? type) {
    if (type == null || type.isEmpty) return 'REG';

    switch (type.toLowerCase()) {
      case 'pwd':
        return 'PWD';
      case 'senior':
      case 'senior citizen':
        return 'SNR';
      case 'student':
        return 'STU';
      case 'regular':
        return 'REG';
      default:
        return type.length > 5
            ? type.substring(0, 5).toUpperCase()
            : type.toUpperCase();
    }
  }

  /// Build footer
  pw.Widget _buildFooter(pw.Context context) {
    final now = DateTime.now();
    final formatter = DateFormat('MMM dd, yyyy hh:mm a');

    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 10),
      child: pw.Column(
        children: [
          pw.Divider(thickness: 0.5),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Generated: ${formatter.format(now)}',
                style: pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey600,
                ),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Get output file path - saves to accessible location
  Future<File> _getOutputFile(String reportType) async {
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'Pasada_Receipt_${reportType}_$timestamp.pdf';

    if (Platform.isAndroid) {
      // For Android, use external storage (accessible via Files app)
      // This is more reliable than trying to access shared Downloads folder
      final directory = await getExternalStorageDirectory();

      if (directory != null) {
        // Create a Documents subfolder in external storage
        final documentsPath = '${directory.path}/Documents';
        final documentsDir = Directory(documentsPath);

        if (!await documentsDir.exists()) {
          await documentsDir.create(recursive: true);
        }

        return File('$documentsPath/$fileName');
      }

      // Fallback to app documents directory
      final appDir = await getApplicationDocumentsDirectory();
      return File('${appDir.path}/$fileName');
    } else {
      // For iOS and other platforms
      final directory = await getApplicationDocumentsDirectory();
      return File('${directory.path}/$fileName');
    }
  }

  /// Share or preview PDF
  Future<void> sharePdf(File pdfFile) async {
    try {
      await Printing.sharePdf(
        bytes: await pdfFile.readAsBytes(),
        filename: pdfFile.path.split('/').last,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error sharing PDF: $e');
      }
    }
  }

  /// Print PDF
  Future<void> printPdf(File pdfFile) async {
    try {
      await Printing.layoutPdf(
        onLayout: (format) async => await pdfFile.readAsBytes(),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error printing PDF: $e');
      }
    }
  }
}
