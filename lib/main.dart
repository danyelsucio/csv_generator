import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

List<CameraDescription> cameras = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Editor CSV',
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
      List<List<dynamic>> csvTable = const CsvToListConverter(
        shouldParseNumbers: false,
        eol: '\n',
      ).convert(input);

      if (csvTable.length <= 1) {
        _snack('El CSV no tiene datos o está mal formado');
        return;
      }

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

  // MANITA ✋ = SOLO TEXTO MANUAL
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
        title: const Text('Pegar dato manual', style: TextStyle(color: Colors.white)),
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

  // CALENDARIO 📅 = REGRESÓ EL BOTÓN
  void _pegarFecha() async {
    if (_selectedRow == null || _selectedCol == null) {
      _snack('Primero selecciona una celda');
      return;
    }

    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(data: ThemeData.dark(), child: child!);
      },
    );
    if (picked!= null) {
      String fecha = DateFormat('dd/MM/yy, h:mm a').format(picked);
      setState(() {
        _data[_selectedRow!][_selectedCol!] = fecha;
      });
    }
  }

  void _agregarFilaVacia() {
    if (_data.isEmpty) {
      _snack('Primero carga un CSV');
      return;
    }
    setState(() {
      _data.add(List.generate(_data[0].length, (index) => ''));
    });
    _snack('Fila nueva agregada abajo');
  }

  // LIBRITO 📚 = REGRESÓ EL BOTÓN DE FUNDAMENTOS
  void _mostrarFundamentos() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Fundamentos Legales', style: TextStyle(color: Colors.white)),
        content: const SingleChildScrollView(
          child: Text(
            '1. CNPP Art. 211 - Carpeta de Investigación\n\n'
            '2. Acuerdo A/009/15 - Gestión de folios\n\n'
            '3. Ley Orgánica FGR Art. 5 - Control de volantes',
            style: TextStyle(color: Colors.white70),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CERRAR')),
        ],
      ),
    );
  }

  // CÁMARA OCR 📷 = AHORA SÍ JALA
  void _abrirCamaraOCR() async {
    if (_selectedRow == null || _selectedCol == null) {
      _snack('Primero selecciona una celda para pegar el texto');
      return;
    }

    if (cameras.isEmpty) {
      _snack('No hay cámaras disponibles');
      return;
    }

    final textoEscaneado = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => CameraScreen()),
    );

    if (textoEscaneado!= null && textoEscaneado.isNotEmpty) {
      setState(() {
        _data[_selectedRow!][_selectedCol!] = textoEscaneado;
      });
      _snack('Texto pegado desde cámara');
    }
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
        title: const Text('Editor CSV'), // 👈 SIN CORONA
        actions: [
          IconButton(icon: const Icon(Icons.upload), onPressed: _cargarCSV, tooltip: 'Subir'),
          IconButton(icon: const Icon(Icons.download), onPressed: _descargarCSV, tooltip: 'Descargar'),
          IconButton(icon: const Icon(Icons.back_hand), onPressed: _pegarEnCelda, tooltip: 'Pegar Manual'),
          IconButton(icon: const Icon(Icons.calendar_month), onPressed: _pegarFecha, tooltip: 'Fecha'), // 👈 REGRESÓ
          IconButton(icon: const Icon(Icons.add), onPressed: _agregarFilaVacia, tooltip: 'Agregar fila'),
          IconButton(icon: const Icon(Icons.menu_book), onPressed: _mostrarFundamentos, tooltip: 'Fundamentos'), // 👈 REGRESÓ
          IconButton(icon: const Icon(Icons.camera_alt), onPressed: _abrirCamaraOCR, tooltip: 'OCR'), // 👈 SÍ JALA
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
                  columns: List.generate(
                    _data[0].length,
                    (i) => DataColumn(
                      label: Text(_data[0][i].toString(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  rows: List.generate(
                    _data.length - 1,
                    (row) {
                      final realRow = row + 1;
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
                              if (realRow == 0) return;
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

// PANTALLA DE CÁMARA CON OCR QUE SÍ JALA
class CameraScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  bool _procesando = false;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(cameras[0], ResolutionPreset.high);
    _initializeControllerFuture = _controller.initialize();
  }

  Future<void> _escanearTexto() async {
    try {
      setState(() => _procesando = true);
      await _initializeControllerFuture;
      final image = await _controller.takePicture();
      final inputImage = InputImage.fromFilePath(image.path);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      Navigator.pop(context, recognizedText.text.replaceAll('\n', ' '));
    } catch (e) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.red[900],
        title: const Text('Escanear Texto'),
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: [
                CameraPreview(_controller),
                if (_procesando)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.red),
                    ),
                  ),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red[900],
        onPressed: _procesando? null : _escanearTexto,
        child: const Icon(Icons.camera),
      ),
    );
  }
}
