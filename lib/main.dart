import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CSV Editor Lic',
      theme: ThemeData.dark(),
      home: const CsvPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class CsvPage extends StatefulWidget {
  const CsvPage({super.key});
  @override
  State<CsvPage> createState() => _CsvPageState();
}

class _CsvPageState extends State<CsvPage> {
  List<List<dynamic>> _data = [];
  int? _selectedRow;
  int? _selectedCol;

  Future<void> _cargarCSV() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result!= null) {
      final file = File(result.files.single.path!);
      final input = await file.readAsString();
      List<List<dynamic>> csvTable = const CsvToListConverter().convert(input);
      setState(() {
        _data = csvTable;
        _selectedRow = null;
        _selectedCol = null;
      });
    }
  }

  Future<void> _descargarCSV() async {
    if (_data.isEmpty) {
      _snack('No hay datos para guardar');
      return;
    }

    // Permiso Android 13+
    if (Platform.isAndroid) {
      var status = await Permission.storage.request();
      if (!status.isGranted) {
        _snack('Permiso denegado. Actívalo en Ajustes');
        return;
      }
    }

    String nombre = 'Pendientes_${DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now())}';
    final controller = TextEditingController(text: nombre);

    final nombreElegido = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Guardar CSV como...', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Nombre del archivo',
            suffixText: '.csv',
            labelStyle: TextStyle(color: Colors.white70),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('GUARDAR')),
        ],
      ),
    );

    if (nombreElegido == null || nombreElegido.isEmpty) return;

    String csv = const ListToCsvConverter().convert(_data);
    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Selecciona dónde guardar:',
      fileName: '$nombreElegido.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (outputFile!= null) {
      await File(outputFile).writeAsString(csv);
      _snack('Guardado: $nombreElegido.csv');
    }
  }

  void _pegarEnCelda() async {
    if (_selectedRow == null || _selectedCol == null) {
      _snack('Primero selecciona una celda');
      return;
    }
    final controller = TextEditingController(text: _data[_selectedRow!][_selectedCol!].toString());
    final nuevoDato = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Pegar dato', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('PEGAR')),
        ],
      ),
    );
    if (nuevoDato!= null) {
      setState(() {
        _data[_selectedRow!][_selectedCol!] = nuevoDato;
      });
    }
  }

  // NUEVO: AGREGAR FILA VACÍA ABAJO
  void _agregarFilaVacia() {
    if (_data.isEmpty) {
      _snack('Primero carga un CSV');
      return;
    }
    setState(() {
      // Crea una fila con la misma cantidad de columnas pero vacías
      _data.add(List.generate(_data[0].length, (index) => ''));
    });
    _snack('Fila nueva agregada abajo');
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.red[900],
        title: const Text('Editor CSV Lic 👑'),
        actions: [
          IconButton(icon: const Icon(Icons.upload), onPressed: _cargarCSV, tooltip: 'Subir'),
          IconButton(icon: const Icon(Icons.download), onPressed: _descargarCSV, tooltip: 'Descargar'),
          // NUEVO BOTÓN MANITA ✋
          IconButton(icon: const Icon(Icons.back_hand), onPressed: _pegarEnCelda, tooltip: 'Pegar manual'),
          IconButton(icon: const Icon(Icons.add), onPressed: _agregarFilaVacia, tooltip: 'Agregar fila'),
          IconButton(icon: const Icon(Icons.camera_alt), onPressed: () => _snack('Próximamente OCR'), tooltip: 'Cámara'),
        ],
      ),
      body: _data.isEmpty
         ? const Center(child: Text('Sube un CSV para empezar', style: TextStyle(color: Colors.white)))
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(Colors.grey[900]),
                  dataRowColor: MaterialStateProperty.all(Colors.grey[850]),
                  // FIX 1: HEADERS CORRECTOS
                  columns: List.generate(
                    _data[0].length,
                    (i) => DataColumn(
                      label: Text(_data[0][i].toString(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  // FIX 2: NO DUPLICAR HEADER + MOSTRAR DATOS
                  rows: List.generate(
                    _data.length - 1, // <-- QUITA EL -1 PARA NO CONTAR HEADER
                    (row) {
                      final realRow = row + 1; // <-- EMPIEZA EN FILA 1
                      return DataRow(
                        cells: List.generate(_data[realRow].length, (col) {
                          bool selected = _selectedRow == realRow && _selectedCol == col;
                          return DataCell(
                            Container(
                              color: selected? Colors.red[900] : null,
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                _data[realRow][col].toString(),
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                            onTap: () {
                              if (realRow == 0) return; // NO EDITAR HEADERS
                              setState(() {
                                _selectedRow = realRow;
                                _selectedCol = col;
                              });
                            },
                          );
                        }),
                      );
                    },
                  ),
                ),
              ),
            ),
    );
  }
}
