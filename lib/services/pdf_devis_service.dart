// lib/services/pdf_devis_service.dart — NOUVEAU
// Génère un PDF professionnel pour un devis
// Utilise le package 'pdf' déjà dans pubspec.yaml

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';

class PdfDevisService {

  static Future<File> genererPDF(Devis devis) async {
    final pdf = pw.Document();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (context) => [
        // ─── HEADER ────────────────────────────────────────────────────────
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('DECO PAS PLUS',
                    style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('B5677A'))),
                pw.Text('Organisation & Décoration Événementielle',
                    style: pw.TextStyle(fontSize: 10,
                        color: PdfColor.fromHex('888888'))),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('DEVIS',
                    style: pw.TextStyle(fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('2D1B4E'))),
                pw.Text(devis.numeroDevis.isNotEmpty
                    ? devis.numeroDevis
                    : '#${devis.id.substring(0, 8).toUpperCase()}',
                    style: pw.TextStyle(fontSize: 12,
                        color: PdfColor.fromHex('B5677A'),
                        fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Divider(color: PdfColor.fromHex('B5677A'), thickness: 2),
        pw.SizedBox(height: 20),

        // ─── INFOS CLIENT & DEVIS ──────────────────────────────────────────
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('CLIENT',
                      style: pw.TextStyle(fontSize: 10,
                          color: PdfColor.fromHex('888888'),
                          fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text(devis.clientNom,
                      style: pw.TextStyle(fontSize: 14,
                          fontWeight: pw.FontWeight.bold)),
                  if (devis.typeEvenement.isNotEmpty)
                    pw.Text(devis.typeEvenement,
                        style: pw.TextStyle(fontSize: 11,
                            color: PdfColor.fromHex('555555'))),
                ],
              ),
            ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  _infoRow('Date de création',
                      _formatDate(devis.dateCreation)),
                  _infoRow('Date d\'expiration',
                      _formatDate(devis.dateExpiration)),
                  _infoRow('Statut', devis.statut),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 24),

        // ─── TABLEAU PRESTATIONS ──────────────────────────────────────────
        pw.Text('PRESTATIONS',
            style: pw.TextStyle(fontSize: 10,
                color: PdfColor.fromHex('888888'),
                fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(
              color: PdfColor.fromHex('EEEEEE'), width: 0.5),
          children: [
            // Header
            pw.TableRow(
              decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('2D1B4E')),
              children: [
                _cellHeader('Description'),
                _cellHeader('Qté'),
                _cellHeader('Prix unit.'),
                _cellHeader('Total'),
              ],
            ),
            // Lignes
            ...devis.lignes.map((l) => pw.TableRow(
              children: [
                _cell(l.description),
                _cell('${l.quantite} ${l.unite}'),
                _cell('${l.prixUnitaire.toStringAsFixed(0)} DT'),
                _cell('${l.total.toStringAsFixed(0)} DT', bold: true),
              ],
            )),
          ],
        ),
        pw.SizedBox(height: 16),

        // ─── TOTAUX ────────────────────────────────────────────────────────
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Container(
            width: 220,
            child: pw.Column(
              children: [
                _totalRow('Sous-total HT', devis.sousTotal),
                if (devis.remise > 0)
                  _totalRow('Remise (${devis.remise.toStringAsFixed(0)}%)',
                      -(devis.sousTotal * devis.remise / 100)),
                if (devis.tva > 0)
                  _totalRow('TVA ${devis.tva.toStringAsFixed(0)}%',
                      devis.total * devis.tva / 100),
                pw.Divider(color: PdfColor.fromHex('B5677A')),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('TOTAL',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold,
                            fontSize: 14)),
                    pw.Text('${devis.total.toStringAsFixed(0)} DT',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 16,
                            color: PdfColor.fromHex('B5677A'))),
                  ],
                ),
                if (devis.tva > 0)
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('TOTAL TTC',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 12)),
                      pw.Text('${devis.totalTTC.toStringAsFixed(0)} DT',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 14,
                              color: PdfColor.fromHex('2D1B4E'))),
                    ],
                  ),
              ],
            ),
          ),
        ),
        pw.SizedBox(height: 30),

        // ─── NOTES ────────────────────────────────────────────────────────
        if (devis.notes.isNotEmpty) ...[
          pw.Text('Notes :',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
          pw.SizedBox(height: 4),
          pw.Text(devis.notes,
              style: pw.TextStyle(fontSize: 10,
                  color: PdfColor.fromHex('555555'))),
          pw.SizedBox(height: 20),
        ],

        // ─── FOOTER ────────────────────────────────────────────────────────
        pw.Divider(color: PdfColor.fromHex('EEEEEE')),
        pw.SizedBox(height: 8),
        pw.Center(
          child: pw.Text(
            'Ce devis est valable jusqu\'au ${_formatDate(devis.dateExpiration)}. '
            'Pour toute question, contactez-nous sur WhatsApp.',
            style: pw.TextStyle(fontSize: 9,
                color: PdfColor.fromHex('888888'),
                fontStyle: pw.FontStyle.italic),
            textAlign: pw.TextAlign.center,
          ),
        ),
      ],
    ));

    // Sauvegarder le fichier
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/devis_${devis.numeroDevis.isNotEmpty ? devis.numeroDevis : devis.id.substring(0, 8)}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  // ─── PARTAGER LE PDF ─────────────────────────────────────────────────────

  static Future<void> partagerPDF(Devis devis) async {
    final file = await genererPDF(devis);
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Devis ${devis.numeroDevis} — DECO PAS PLUS',
    );
  }

  static Future<void> envoyerWhatsApp(Devis devis, String telephone) async {
    // D'abord générer le PDF
    final file = await genererPDF(devis);
    // Partager via le share sheet (l'utilisateur choisit WhatsApp)
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Bonjour ${devis.clientNom} ! Voici votre devis ${devis.numeroDevis} '
          'de ${devis.total.toStringAsFixed(0)} DT. '
          'Valable jusqu\'au ${_formatDate(devis.dateExpiration)}.',
    );
  }

  // ─── HELPERS ─────────────────────────────────────────────────────────────

  static pw.Widget _cellHeader(String text) => pw.Padding(
    padding: const pw.EdgeInsets.all(8),
    child: pw.Text(text, style: pw.TextStyle(
        color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
  );

  static pw.Widget _cell(String text, {bool bold = false}) => pw.Padding(
    padding: const pw.EdgeInsets.all(8),
    child: pw.Text(text, style: pw.TextStyle(
        fontSize: 10,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
  );

  static pw.Widget _infoRow(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Text('$label: ',
            style: pw.TextStyle(fontSize: 10,
                color: PdfColor.fromHex('888888'))),
        pw.Text(value,
            style: pw.TextStyle(fontSize: 10,
                fontWeight: pw.FontWeight.bold)),
      ],
    ),
  );

  static pw.Widget _totalRow(String label, double montant) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 11,
            color: PdfColor.fromHex('555555'))),
        pw.Text('${montant.toStringAsFixed(0)} DT',
            style: pw.TextStyle(fontSize: 11)),
      ],
    ),
  );

  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}
