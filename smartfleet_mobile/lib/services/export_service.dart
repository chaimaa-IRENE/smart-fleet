import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart' as excel;
import '../database/dao/declaration_dao.dart';
import '../database/dao/checkup_dao.dart';
import '../database/dao/depart_dao.dart';

class ExportService {
  final DeclarationDao _declarationDao = DeclarationDao();
  final CheckupDao _checkupDao = CheckupDao();
  final DepartDao _departDao = DepartDao();

  // ── CSV exports ──
  Future<String> exportDeclarationsCSV() async {
    final declarations = await _declarationDao.getAll();
    final buffer = StringBuffer();
    buffer.writeln(
        'ID;Numero;TypePanne;Description;Statut;Priorite;Criticite;SLA;Qualification;DateCreation;DateCloture;Immatriculation;Chauffeur;CoutEstime;CoutReel;Lieu;Kilometrage;ElementVehicule;Solution;PieceNecessaires');
    for (var d in declarations) {
      buffer.writeln(
        '${d['id']};${d['numeroDemande'] ?? ''};${d['typePanne'] ?? ''};${d['description'] ?? ''};${d['statut'] ?? ''};${d['priorite'] ?? ''};${d['criticite'] ?? ''};${d['sla'] ?? ''};${d['qualification'] ?? ''};${d['dateCreation'] ?? ''};${d['dateCloture'] ?? ''};${d['immatriculation'] ?? ''};${d['chauffeurNom'] ?? ''};${d['coutEstime'] ?? 0};${d['coutReel'] ?? 0};${d['lieu'] ?? ''};${d['kilometrage'] ?? ''};${d['elementVehicule'] ?? ''};${d['solution'] ?? ''};${d['piecesNecessaires'] ?? ''}',
      );
    }
    return await _saveFile(buffer.toString(), 'declarations_export.csv');
  }

  Future<String> exportCheckupsCSV() async {
    final checkups = await _checkupDao.getAll();
    final buffer = StringBuffer();
    buffer
        .writeln('ID;Code;Vehicule;Chauffeur;Kilometrage;Conforme;Date;Notes');
    for (var c in checkups) {
      buffer.writeln(
        '${c['id']};${c['code'] ?? ''};${c['immatriculation'] ?? ''};${c['chauffeurNom'] ?? ''};${c['kilometrage'] ?? 0};${c['conforme'] == 1 ? 'OUI' : 'NON'};${c['dateCheckup'] ?? ''};${c['notes'] ?? ''}',
      );
    }
    return await _saveFile(buffer.toString(), 'checkups_export.csv');
  }

  Future<String> exportDepartsCSV() async {
    final departs = await _departDao.getAll();
    final buffer = StringBuffer();
    buffer.writeln('ID;Chauffeur;Vehicule;Tournee;DateDepart;Site;Branche;GPS');
    for (var d in departs) {
      buffer.writeln(
        '${d['id']};${d['chauffeurId'] ?? ''};${d['immatriculation'] ?? ''};${d['tourneeId'] ?? ''};${d['dateDepart'] ?? ''};${d['site'] ?? ''};${d['branche'] ?? ''};${d['gpsLatitude'] ?? ''},${d['gpsLongitude'] ?? ''}',
      );
    }
    return await _saveFile(buffer.toString(), 'departs_export.csv');
  }

  // ── Excel XLSX export ──
  Future<String> exportExcel() async {
    final workbook = excel.Excel.createExcel();
    await _addDeclarationSheet(workbook);
    await _addCheckupSheet(workbook);
    await _addDepartSheet(workbook);
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/smartfleet_export.xlsx';
    final fileBytes = workbook.save();
    await File(path).writeAsBytes(fileBytes!);
    await OpenFile.open(path);
    return path;
  }

  Future<void> _addDeclarationSheet(excel.Excel workbook) async {
    final sheet = workbook['Déclarations'];
    final headers = [
      'ID', 'Numéro', 'Type Panne', 'Description', 'Statut', 'Priorité',
      'Criticité', 'SLA', 'Qualification', 'Date Création', 'Date Clôture',
      'Immatriculation', 'Chauffeur', 'Prestataire', 'Coût Estimé', 'Coût Réel',
      'Lieu', 'Kilométrage', 'Élément', 'Solution', 'Pièces',
    ];
    for (var i = 0; i < headers.length; i++) {
      sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          ..value = excel.TextCellValue(headers[i])
          ..cellStyle = excel.CellStyle(
            bold: true, backgroundColorHex: excel.ExcelColor.fromHexString('#1A56DB'),
            fontColorHex: excel.ExcelColor.fromHexString('#FFFFFF'),
          );
    }
    final declarations = await _declarationDao.getAll();
    for (var r = 0; r < declarations.length; r++) {
      final d = declarations[r];
      final vals = [
        d['id'], d['numeroDemande'], d['typePanne'], d['description'],
        d['statut'], d['priorite'], d['criticite'], d['sla'],
        d['qualification'], d['dateCreation'], d['dateCloture'],
        d['immatriculation'], d['chauffeurNom'], d['prestataireNom'],
        d['coutEstime'], d['coutReel'], d['lieu'], d['kilometrage'],
        d['elementVehicule'], d['solution'], d['piecesNecessaires'],
      ];
      for (var c = 0; c < vals.length; c++) {
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1))
            ..value = excel.TextCellValue('${vals[c] ?? ''}');
      }
    }
  }

  Future<void> _addCheckupSheet(excel.Excel workbook) async {
    final sheet = workbook['Check-ups'];
    final headers = ['ID', 'Code', 'Véhicule', 'Chauffeur', 'Km', 'Conforme', 'Date', 'Notes'];
    for (var i = 0; i < headers.length; i++) {
      sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          ..value = excel.TextCellValue(headers[i])
          ..cellStyle = excel.CellStyle(
            bold: true, backgroundColorHex: excel.ExcelColor.fromHexString('#1A56DB'),
            fontColorHex: excel.ExcelColor.fromHexString('#FFFFFF'),
          );
    }
    final checkups = await _checkupDao.getAll();
    for (var r = 0; r < checkups.length; r++) {
      final c = checkups[r];
      final vals = [
        c['id'], c['code'], c['immatriculation'], c['chauffeurNom'],
        c['kilometrage'], c['conforme'] == 1 ? 'OUI' : 'NON',
        c['dateCheckup'], c['notes'],
      ];
      for (var ci = 0; ci < vals.length; ci++) {
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: ci, rowIndex: r + 1))
            ..value = excel.TextCellValue('${vals[ci] ?? ''}');
      }
    }
  }

  Future<void> _addDepartSheet(excel.Excel workbook) async {
    final sheet = workbook['Départs'];
    final headers = ['ID', 'Chauffeur', 'Véhicule', 'Tournée', 'Date', 'Site', 'Branche', 'GPS'];
    for (var i = 0; i < headers.length; i++) {
      sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          ..value = excel.TextCellValue(headers[i])
          ..cellStyle = excel.CellStyle(
            bold: true, backgroundColorHex: excel.ExcelColor.fromHexString('#1A56DB'),
            fontColorHex: excel.ExcelColor.fromHexString('#FFFFFF'),
          );
    }
    final departs = await _departDao.getAll();
    for (var r = 0; r < departs.length; r++) {
      final d = departs[r];
      final vals = [
        d['id'], d['chauffeurId'], d['immatriculation'], d['tourneeId'],
        d['dateDepart'], d['site'], d['branche'],
        '${d['gpsLatitude'] ?? ''},${d['gpsLongitude'] ?? ''}',
      ];
      for (var ci = 0; ci < vals.length; ci++) {
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: ci, rowIndex: r + 1))
            ..value = excel.TextCellValue('${vals[ci] ?? ''}');
      }
    }
  }

  // ── PDF Intervention Report ──
  Future<String> exportPdfIntervention(int declarationId) async {
    final decl = await _declarationDao.getById(declarationId);
    if (decl == null) throw Exception('Déclaration introuvable');

    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => [
        _header(ctx),
        pw.SizedBox(height: 8),
        pw.Divider(color: PdfColors.blue800, thickness: 1.5),
        pw.SizedBox(height: 16),
        _section('N° Déclaration', '${decl['numeroDemande'] ?? 'N/A'}'),
        pw.SizedBox(height: 8),
        _twoColumn(
          'Type de panne', '${decl['typePanne'] ?? ''}',
          'Statut', '${decl['statut'] ?? ''}',
        ),
        pw.SizedBox(height: 6),
        _twoColumn(
          'Priorité', '${decl['priorite'] ?? ''}',
          'Criticité', '${decl['criticite'] ?? ''}',
        ),
        pw.SizedBox(height: 6),
        _twoColumn(
          'SLA', '${decl['sla'] ?? ''}',
          'Qualification', '${decl['qualification'] ?? ''}',
        ),
        pw.SizedBox(height: 12),
        _sectionTitle('Véhicule'),
        pw.SizedBox(height: 4),
        pw.Table(border: pw.TableBorder.all(), children: [
          pw.TableRow(children: [
            _cell('Immatriculation'), _cell('${decl['immatriculation'] ?? ''}'),
            _cell('Marque'), _cell('${decl['vehiculeMarque'] ?? ''}'),
          ]),
          pw.TableRow(children: [
            _cell('Modèle'), _cell('${decl['vehiculeModele'] ?? ''}'),
            _cell('Type'), _cell('${decl['vehiculeType'] ?? ''}'),
          ]),
        ]),
        pw.SizedBox(height: 12),
        _sectionTitle('Détails'),
        pw.SizedBox(height: 4),
        _row('Description', '${decl['description'] ?? 'N/A'}'),
        pw.SizedBox(height: 4),
        _row('Élément véhicule', '${decl['elementVehicule'] ?? 'N/A'}'),
        pw.SizedBox(height: 4),
        _row('Solution', '${decl['solution'] ?? 'N/A'}'),
        pw.SizedBox(height: 12),
        _sectionTitle('Coûts'),
        pw.SizedBox(height: 4),
        _twoColumn(
          'Coût estimé', '${decl['coutEstime'] ?? 0} €',
          'Coût réel', '${decl['coutReel'] ?? 0} €',
        ),
        pw.SizedBox(height: 12),
        _sectionTitle('Intervention'),
        pw.SizedBox(height: 4),
        _twoColumn(
          'Lieu', '${decl['lieu'] ?? 'N/A'}',
          'Kilométrage', '${decl['kilometrage'] ?? 'N/A'}',
        ),
        pw.SizedBox(height: 4),
        _twoColumn(
          'Date création', '${_fmt(decl['dateCreation'])}',
          'Date clôture', '${_fmt(decl['dateCloture'])}',
        ),
        pw.SizedBox(height: 4),
        _row('Actions réalisées', '${decl['actionsRealisees'] ?? 'N/A'}'),
        pw.SizedBox(height: 4),
        _row('Pièces nécessaires', '${decl['piecesNecessaires'] ?? 'N/A'}'),
        pw.SizedBox(height: 4),
        _row('Contrat / Bon de commande', '${decl['contratBonCommande'] ?? 'N/A'}'),
        pw.SizedBox(height: 20),
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 8),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(children: [
            pw.Text('Chauffeur : ${decl['chauffeurNom'] ?? 'N/A'}',
                style: pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 4),
            pw.Container(width: 120, height: 1, color: PdfColors.grey400),
            pw.Text('Signature chauffeur', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ]),
          pw.Column(children: [
            pw.Text('Prestataire : ${decl['prestataireNom'] ?? 'N/A'}',
                style: pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 4),
            pw.Container(width: 120, height: 1, color: PdfColors.grey400),
            pw.Text('Signature prestataire', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ]),
        ]),
        pw.SizedBox(height: 16),
        pw.Text('SmartFleet - Danone Maroc  |  Généré le ${DateTime.now().toIso8601String().substring(0, 10)}',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
      ],
    ));

    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/intervention_${decl['numeroDemande'] ?? declarationId}.pdf';
    await File(path).writeAsBytes(await pdf.save());
    await OpenFile.open(path);
    return path;
  }

  // ── PDF helpers ──
  pw.Widget _header(pw.Context ctx) {
    return pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('SmartFleet', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
        pw.Text('Rapport d\'Intervention', style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
      ]),
      pw.Text('Danone Maroc', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
    ]);
  }

  pw.Widget _section(String label, String value) {
    return pw.Row(children: [
      pw.Text('$label : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
      pw.Text(value, style: pw.TextStyle(fontSize: 11)),
    ]);
  }

  pw.Widget _sectionTitle(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: pw.BoxDecoration(color: PdfColors.blue100),
      child: pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.blue800)),
    );
  }

  pw.Widget _twoColumn(String l1, String v1, String l2, String v2) {
    return pw.Row(children: [
      pw.Expanded(child: _row(l1, v1)),
      pw.SizedBox(width: 16),
      pw.Expanded(child: _row(l2, v2)),
    ]);
  }

  pw.Widget _row(String label, String value) {
    return pw.Row(children: [
      pw.Text('$label : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
      pw.Expanded(child: pw.Text(value, style: pw.TextStyle(fontSize: 10))),
    ]);
  }

  pw.Widget _cell(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 9)),
    );
  }

  String _fmt(String? iso) {
    if (iso == null || iso.length < 10) return 'N/A';
    return iso.substring(0, 10);
  }

  // ── File helpers ──
  Future<String> _saveFile(String content, String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(content);
    await OpenFile.open(file.path);
    return file.path;
  }
}
