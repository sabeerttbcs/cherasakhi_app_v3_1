// ignore_for_file: prefer_const_constructors

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/quiz_report_repository.dart';
import '../domain/entities/quiz_report_models.dart';

class QuizReportPdf {
  QuizReportPdf._();

  static Future<void> download(
    QuizReport report, {
    QuizPrizeSelection? prize,
  }) async {
    final font = pw.Font.ttf(
        (await rootBundle.load('assets/fonts/NotoSansMalayalam.ttf')));
    final logo = pw.MemoryImage(
        (await rootBundle.load('assets/brand/logo.png')).buffer.asUint8List());
    final document = pw.Document(
      theme: pw.ThemeData.withFont(
        base: font,
        bold: font,
        italic: font,
        boldItalic: font,
      ),
    );
    final generated =
        DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    final filename =
        'cherasakhi-${report.period.kind.name}-${report.period.monthKey}.pdf';

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Image(logo, width: 42, height: 42),
            pw.SizedBox(width: 10),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('CheraSakhi',
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.Text('Quiz Leaderboard & Report',
                    style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
          ],
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Page ${context.pageNumber} / ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8)),
        ),
        build: (context) => [
          pw.SizedBox(height: 12),
          pw.Text(
              '${_kindLabel(report.period.kind)} · ${report.category.label}',
              style:
                  pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
          pw.Text('Period: ${report.period.label}',
              style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Generated: ${_dateTimeLabel(generated)} Asia/Kolkata',
              style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 14),
          pw.Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metric('Completed quizzes', '${report.completedQuizCount}'),
              _metric('Participants', '${report.participatingMembers}'),
              _metric('Answers', '${report.totalAnswers}'),
              _metric('Correct', '${report.totalCorrect}'),
              _metric('Wrong', '${report.totalIncorrect}'),
            ],
          ),
          if (report.warnings.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              color: PdfColors.amber100,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Incomplete or unavailable results',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  for (final warning in report.warnings)
                    pw.Text('• $warning',
                        style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
            ),
          ],
          pw.SizedBox(height: 16),
          pw.Text('Daily winners',
              style:
                  pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          if (report.dailyWinners.isEmpty)
            pw.Text('No daily winner recorded.',
                style: const pw.TextStyle(fontSize: 9))
          else
            pw.Table.fromTextArray(
              headers: const ['Date', 'Quiz', 'Winner', 'Category'],
              data: [
                for (final winner in report.dailyWinners)
                  [
                    _dateLabel(winner.date),
                    winner.title,
                    winner.name,
                    winner.category
                  ],
              ],
              headerStyle:
                  pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellPadding: const pw.EdgeInsets.all(4),
            ),
          pw.SizedBox(height: 16),
          pw.Text('Member leaderboard',
              style:
                  pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.Table.fromTextArray(
            headers: const [
              'Rank',
              'Member',
              'Played',
              'Correct',
              'Wrong',
              'Wins',
              'Accuracy'
            ],
            data: [
              for (final entry in report.leaderboard)
                [
                  '${entry.rank}',
                  entry.name,
                  '${entry.participated}/${entry.available}',
                  '${entry.correct}',
                  '${entry.incorrect}',
                  '${entry.dailyWins}',
                  '${entry.accuracyPercent.toStringAsFixed(1)}%',
                ],
            ],
            headerStyle:
                pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellPadding: const pw.EdgeInsets.all(4),
          ),
          pw.SizedBox(height: 16),
          pw.Text('Performance leaders',
              style:
                  pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          _leaderLine(
              'Most correct', report.candidatesFor(PrizeCriterion.mostCorrect)),
          _leaderLine('Most participation',
              report.candidatesFor(PrizeCriterion.mostParticipation)),
          _leaderLine('Most daily wins',
              report.candidatesFor(PrizeCriterion.mostDailyWins)),
          _leaderLine(
              'Best accuracy (minimum $minimumAccuracyParticipation played)',
              report.bestAccuracyCandidates),
          if (prize != null) ...[
            pw.SizedBox(height: 16),
            pw.Text('Monthly prize confirmation',
                style:
                    pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.Text('${prize.criterion.label}: ${prize.recipientName}',
                style: const pw.TextStyle(fontSize: 9)),
          ],
        ],
      ),
    );
    await Printing.sharePdf(bytes: await document.save(), filename: filename);
  }

  static pw.Widget _metric(String label, String value) => pw.Container(
        width: 92,
        padding: const pw.EdgeInsets.all(7),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(value,
                style:
                    pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Text(label, style: const pw.TextStyle(fontSize: 7)),
          ],
        ),
      );

  static pw.Widget _leaderLine(
      String label, List<QuizLeaderboardEntry> entries) {
    final names =
        entries.isEmpty ? '—' : entries.map((entry) => entry.name).join(', ');
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 3),
      child: pw.Text('$label: $names', style: const pw.TextStyle(fontSize: 9)),
    );
  }

  static String _kindLabel(QuizReportKind kind) => switch (kind) {
        QuizReportKind.daily => 'Daily Report',
        QuizReportKind.weekly => 'Weekly Report',
        QuizReportKind.monthly => 'Monthly Report',
        QuizReportKind.custom => 'Custom Report',
      };

  static String _dateLabel(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  static String _dateTimeLabel(DateTime value) =>
      '${_dateLabel(value)} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
