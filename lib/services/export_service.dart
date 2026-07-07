// lib/services/export_service.dart — NOUVEAU
// Export liste clients en CSV (compatible Excel)

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/models.dart';

class ExportService {

  static Future<void> exporterClientsCSV(List<Client> clients) async {
    final buffer = StringBuffer();

    // En-têtes
    buffer.writeln(
      'Prénom,Nom,Téléphone,Email,Ville,Adresse,Type,Source,'
      'Date Création,Budget Moyen,Nb Événements,Segment'
    );

    // Lignes
    for (final c in clients) {
      buffer.writeln(
        '"${c.prenom}","${c.nom}","${c.telephone}","${c.email}",'
        '"${c.ville}","${c.adresse}","${c.typeClient}","${c.sourceAcquisition}",'
        '"${_formatDate(c.dateCreation)}","${c.budgetMoyen.toStringAsFixed(0)}",'
        '"${c.nombreEvenements}","${c.segmentAuto}"'
      );
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/clients_deco_pas_plus_${_dateNow()}.csv');
    // BOM UTF-8 pour Excel
    await file.writeAsBytes([0xEF, 0xBB, 0xBF, ...buffer.toString().codeUnits]);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Liste des clients DECO PAS PLUS',
    );
  }

  static Future<void> exporterEvenementsCSV(List<Evenement> evenements) async {
    final buffer = StringBuffer();
    buffer.writeln(
      'Client,Type,Date,Lieu,Budget,Pack,Thème,Statut'
    );
    for (final e in evenements) {
      buffer.writeln(
        '"${e.clientNom}","${e.typeEvenement}","${_formatDate(e.date)}",'
        '"${e.lieu}","${e.budget.toStringAsFixed(0)}","${e.packChoisi}",'
        '"${e.theme}","${e.statut}"'
      );
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/evenements_deco_pas_plus_${_dateNow()}.csv');
    await file.writeAsBytes([0xEF, 0xBB, 0xBF, ...buffer.toString().codeUnits]);
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Liste des événements DECO PAS PLUS',
    );
  }

  static String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static String _dateNow() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  }
}
