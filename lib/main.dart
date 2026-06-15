import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const CSVEditor(),
    );
  }
}

// MODELO FUNDAMENTO
class Fundamento {
  String titulo;
  String texto;
  Fundamento({required this.titulo, required this.texto});

  Map<String, dynamic> toJson() => {'titulo': titulo, 'texto': texto};
  factory Fundamento.fromJson(Map<String, dynamic> json) =>
      Fundamento(titulo: json['titulo'], texto: json['texto']);
}

class CSVEditor extends StatefulWidget {
  const CSVEditor({super.key});
  @override
  State<CSVEditor> createState() => _CSVEditorState();
}

class _CSVEditorState extends State<CSVEditor> {
  List<List<String>> _data = [];
  int? _selectedRow;
  int? _selectedCol;
  String _ocrText = '';
  List<Fundamento> _fundamentos = [];

  @override
  void initState() {
    super.initState();
    _cargarFundamentos();
  }

  // CARGAR FUNDAMENTOS GUARDADOS
  Future<void> _cargarFundamentos() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString('fundamentos');
    if (jsonString!= null) {
      final List decoded = jsonDecode(jsonString);
      setState(() {
        _fundamentos = decoded.map((e) => Fundamento.fromJson(e)).toList();
      });
    }
  }

  // GUARDAR FUNDAMENTOS
  Future<void> _guardarFundamentos() async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonString = jsonEncode(_fundamentos.map((e) => e.toJson()).toList());
    await prefs.setString('fundamentos', jsonString);
  }

  // SUBIR CSV
  Future<void> _subirCSV() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result!= null) {
      final file = File(result.files.single.path!);
      final csvString = await file.readAsString();
      setState(() {
        _data = const CsvToListConverter().convert(csvString);
      });
    }
  }

  // DESCARGAR CSV
  // DESCARGAR CSV - CON NOMBRE Y CARPETA A ELEGIR
Future<void> _descargarCSV() async {
  if (_data.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No hay datos para guardar')),
    );
    return;
  }

  // Pedir nombre del archivo
  String nombreArchivo = 'Pendientes_${DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now())}';
  final nombreController = TextEditingController(text: nombreArchivo);
  
  final nombreElegido = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Guardar CSV como...'),
      content: TextField(
        controller: nombreController,
        decoration: const InputDecoration(
          labelText: 'Nombre del archivo',
          suffixText: '.csv',
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCELAR'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, nombreController.text),
          child: const Text('SIGUIENTE'),
        ),
      ],
    ),
  );

  if (nombreElegido == null || nombreElegido.isEmpty) return;

  // Convertir a CSV
  String csv = const ListToCsvConverter().convert(_data);
  
  // Abrir selector de carpeta para guardar
  String? outputFile = await FilePicker.platform.saveFile(
    dialogTitle: 'Selecciona dónde guardar:',
    fileName: '$nombreElegido.csv',
    type: FileType.custom,
    allowedExtensions: ['csv'],
  );

  if (outputFile!= null) {
    final file = File(outputFile);
    await file.writeAsString(csv);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Guardado en: $outputFile'),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

  // CALENDARIO
  Future<void> _mostrarCalendario() async {
    if (_selectedRow == null) return;
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked!= null) {
      setState(() {
        _data[_selectedRow!][_selectedCol!] = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  // GESTOR DE FUNDAMENTOS - AGREGAR/BORRAR/SELECCIONAR
  void _mostrarFundamentos() {
    if (_selectedRow == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una celda primero')),
      );
      return;
    }
    List<Fundamento> seleccionados = [];
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Fundamentos'),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _agregarFundamento(setDialogState),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: _fundamentos.isEmpty
                  ? const Text('No hay fundamentos. Agrega uno con +')
                    : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _fundamentos.length,
                          itemBuilder: (context, index) {
                            final f = _fundamentos[index];
                            return CheckboxListTile(
                              title: Text(f.titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: Text(f.texto, style: const TextStyle(fontSize: 11)),
                              value: seleccionados.contains(f),
                              secondary: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                onPressed: () {
                                  setDialogState(() {
                                    _fundamentos.removeAt(index);
                                    seleccionados.remove(f);
                                  });
                                  _guardarFundamentos();
                                },
                              ),
                              onChanged: (val) {
                                setDialogState(() {
                                  if (val!) seleccionados.add(f);
                                  else seleccionados.remove(f);
                                });
                              },
                            );
                          },
                        ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCELAR'),
                ),
                TextButton(
                  onPressed: () {
                    if (seleccionados.isNotEmpty) {
                      setState(() {
                        _data[_selectedRow!][_selectedCol!] =
                          seleccionados.map((e) => '${e.titulo}: ${e.texto}').join('; ');
                      });
                    }
                    Navigator.pop(context);
                  },
                  child: const Text('PEGAR SELECCIÓN'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // DIALOGO PARA AGREGAR FUNDAMENTO
  void _agregarFundamento(StateSetter setDialogState) {
    String titulo = '';
    String texto = '';
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nuevo Fundamento'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Título', hintText: 'Ej: Art. 14'),
                onChanged: (v) => titulo = v,
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Fundamento', hintText: 'Ej: Nadie podrá ser privado...'),
                maxLines: 3,
                onChanged: (v) => texto = v,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR'),
            ),
            TextButton(
              onPressed: () {
                if (titulo.isNotEmpty && texto.isNotEmpty) {
                  setDialogState(() {
                    _fundamentos.add(Fundamento(titulo: titulo, texto: texto));
                  });
                  _guardarFundamentos();
                  Navigator.pop(context);
                }
              },
              child: const Text('GUARDAR'),
            ),
          ],
        );
      },
    );
  }

  // CÁMARA
  void _abrirCamara() async {
    if (_selectedRow == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una celda primero')),
      );
      return;
    }
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraScreen(textoAnterior: _ocrText),
      ),
    );
    if (resultado!= null) {
      setState(() {
        _ocrText = resultado['texto'];
        if (resultado['pegar']) {
          _data[_selectedRow!][_selectedCol!] = resultado['seleccion'];
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.red[900],
        toolbarHeight: 40,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.upload, color: Colors.white, size: 20),
              onPressed: _subirCSV,
              tooltip: 'Subir CSV',
            ),
            IconButton(
              icon: const Icon(Icons.download, color: Colors.white, size: 20),
              onPressed: _descargarCSV,
              tooltip: 'Descargar CSV',
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month, color: Colors.white),
            onPressed: _mostrarCalendario,
            tooltip: 'Fecha',
          ),
          IconButton(
            icon: const Icon(Icons.menu_book, color: Colors.white),
            onPressed: _mostrarFundamentos,
            tooltip: 'Fundamentos',
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt, color: Colors.white),
            onPressed: _abrirCamara,
            tooltip: 'Escanear',
          ),
        ],
      ),
      body: _data.isEmpty
       ? const Center(
              child: Text('Sube un CSV para empezar',
                style: TextStyle(color: Colors.white)))
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(Colors.grey[900]),
                  dataRowColor: MaterialStateProperty.all(Colors.grey[850]),
                  columns: List.generate(
                    _data[0].length,
                    (i) => DataColumn(
                       label: Text(_data[0][i], // ✅ BIEN - Usa tu encabezado real
                        style: const TextStyle(color: Colors.white)),
                    ),
                  ),
                  rows: List.generate(_data.length, (row) {
                    return DataRow(
                      cells: List.generate(_data[row].length, (col) {
                        bool selected = _selectedRow == row && _selectedCol == col;
                        return DataCell(
                          Container(
                            color: selected? Colors.red[900] : null,
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              _data[row][col],
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                          onTap: () {
                            setState(() {
                              _selectedRow = row;
                              _selectedCol = col;
                            });
                          },
                        );
                      }),
                    );
                  }),
                ),
              ),
            ),
    );
  }
}

// PANTALLA DE CÁMARA - IGUAL QUE ANTES
class CameraScreen extends StatefulWidget {
  final String textoAnterior;
  const CameraScreen({super.key, required this.textoAnterior});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  bool _isBusy = false;
  String _text = '';
  String _selectedText = '';

  @override
  void initState() {
    super.initState();
    _text = widget.textoAnterior;
    _controller = CameraController(cameras[0], ResolutionPreset.high);
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  Future<void> _scanImage() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    final image = await _controller.takePicture();
    final inputImage = InputImage.fromFilePath(image.path);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final recognizedText = await textRecognizer.processImage(inputImage);
    setState(() {
      _text = recognizedText.text;
      _isBusy = false;
    });
    textRecognizer.close();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return const Scaffold(backgroundColor: Colors.black);
    }
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.red[900],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context, {'texto': _text, 'pegar': false}),
        ),
        title: const Text('Escanear', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () {
              Navigator.pop(context, {
                'texto': _text,
                'pegar': true,
                'seleccion': _selectedText.isEmpty? _text : _selectedText
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: CameraPreview(_controller)),
          Container(
            height: 200,
            color: Colors.grey[900],
            padding: const EdgeInsets.all(8),
            child: SingleChildScrollView(
              child: SelectableText(
                _text,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                onSelectionChanged: (selection, cause) {
                  setState(() {
                    _selectedText = selection.textInside(_text);
                  });
                },
              ),
            ),
          ),
          Container(
            color: Colors.black,
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[900],
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: _isBusy? null : _scanImage,
              child: _isBusy
               ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('ESCANEAR', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
