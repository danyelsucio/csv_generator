import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:shared_preferences/shared_preferences.dart';



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
      title: 'CSV',
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
  List<String> _fundamentos = []; // 👈 AHORA ES SOLO LISTA DE TEXTOS
  int? _selectedRow;
  int? _selectedCol;
  String _textoEscaneadoCompleto = ''; // 👈 GUARDA EL ÚLTIMO OCR
  

  @override
  void initState() {
    super.initState();
    _cargarFundamentos();
    // funcion nueva
    
    //termina funcion nueva
  }

  //nueva pegada
  
  //termina nueva pegada

  Future<void> _cargarFundamentos() async {
    final prefs = await SharedPreferences.getInstance();
    final String? fundString = prefs.getString('fundamentos');
    if (fundString!= null) {
      setState(() {
        _fundamentos = List<String>.from(json.decode(fundString)); // 👈 SOLO STRINGS
      });
    }
  }

  Future<void> _guardarFundamentos() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fundamentos', json.encode(_fundamentos));
  }

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
        _snack('El CSV no tiene datos');
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
      var status = await Permission.manageExternalStorage.request();
      if (!status.isGranted) {
        status = await Permission.storage.request();
        if (!status.isGranted) {
          _snack('Permiso denegado. Actívalo en Ajustes');
          openAppSettings();
          return;
        }
      }
    }

    String nombre = 'Pendientes_${DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now())}';
    final controller = TextEditingController(text: nombre);

    final nombreElegido = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Guardar como', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
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

    try {
      String csv = const ListToCsvConverter().convert(_data);
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar CSV',
        fileName: '$nombreElegido.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: utf8.encode(csv),
      );

      if (outputFile!= null) {
        _snack('Guardado: $nombreElegido.csv');
      }
    } catch (e) {
      _snack('Error: $e');
    }
  }

  void _pegarManual() async {
    if (_selectedRow == null || _selectedCol == null) {
      _snack('Selecciona una celda primero');
      return;
    }

    final controller = TextEditingController(text: _data[_selectedRow!][_selectedCol!].toString());
    final nuevoDato = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Dato manual', style: TextStyle(color: Colors.white)),
        content: TextField(controller: controller, style: const TextStyle(color: Colors.white), autofocus: true),
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

  void _pegarFecha() async {
    if (_selectedRow == null || _selectedCol == null) {
      _snack('Selecciona una celda primero');
      return;
    }

    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(data: ThemeData.dark(), child: child!),
    );
    if (picked!= null) {
      String fecha = DateFormat('dd/MM/yy').format(picked);
      setState(() {
        _data[_selectedRow!][_selectedCol!] = fecha;
      });
    }
  }

  void _gestionarFundamentos() async {
    if (_selectedRow == null || _selectedCol == null) {
      _snack('Selecciona una celda primero');
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => FundamentosDialog(
        fundamentos: _fundamentos,
        onGuardar: (nuevas) {
          setState(() {
            _fundamentos = nuevas;
          });
          _guardarFundamentos();
        },
        onPegar: (textos) {
          setState(() {
            _data[_selectedRow!][_selectedCol!] = textos.join('\n');
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  // 👈 CÁMARA AHORA REGRESA EL TEXTO SELECCIONADO + ACTUALIZA EL COMPLETO
  void _abrirCamaraOCR() async {
    if (_selectedRow == null || _selectedCol == null) {
      _snack('Selecciona una celda primero');
      return;
    }

    if (cameras.isEmpty) {
      _snack('No hay cámaras disponibles');
      return;
    }

    final resultado = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (context) => CameraScreen(textoAnterior: _textoEscaneadoCompleto),
      ),
    );

    if (resultado!= null) {
      setState(() {
        _textoEscaneadoCompleto = resultado['completo']!; // Guarda todo el OCR
        if (resultado['seleccion']!.isNotEmpty) {
          _data[_selectedRow!][_selectedCol!] = resultado['seleccion']!; // Pega la selección
        }
      });
      if (resultado['seleccion']!.isNotEmpty) {
        _snack('Texto pegado en celda');
      }
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
        title: const Text('CSV'),
        actions: [
          IconButton(icon: const Icon(Icons.upload_file), onPressed: _cargarCSV, tooltip: 'Subir'),
          const SizedBox(width: 8),
          IconButton(icon: const Icon(Icons.save), onPressed: _descargarCSV, tooltip: 'Guardar'),
          const SizedBox(width: 8),
          IconButton(icon: const Icon(Icons.edit), onPressed: _pegarManual, tooltip: 'Manual'),
          const SizedBox(width: 8),
          IconButton(icon: const Icon(Icons.calendar_month), onPressed: _pegarFecha, tooltip: 'Fecha'),
          const SizedBox(width: 8),
          IconButton(icon: const Icon(Icons.menu_book), onPressed: _gestionarFundamentos, tooltip: 'Fundamentos'),
          const SizedBox(width: 8),
          IconButton(icon: const Icon(Icons.camera_alt), onPressed: _abrirCamaraOCR, tooltip: 'Escanear y pegar'), // 👈 YA NO HAY BOTÓN +
          const SizedBox(width: 12),
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


class FundamentosDialog extends StatefulWidget {
  final List<String> fundamentos;
  final Function(List<String>) onGuardar;
  final Function(List<String>) onPegar;

  const FundamentosDialog({
    required this.fundamentos,
    required this.onGuardar,
    required this.onPegar,
    super.key,
  });

  @override
  State<FundamentosDialog> createState() => _FundamentosDialogState();
}

class _FundamentosDialogState extends State<FundamentosDialog> {
  late List<String> _funds;
  late List<bool> _seleccionados;
  final textoCtrl = TextEditingController(); // 👈 YA NO HAY TITULO

  @override
  void initState() {
    super.initState();
    _funds = List.from(widget.fundamentos);
    _seleccionados = List.generate(_funds.length, (index) => false);
  }

  void _agregarFund() {
    if (textoCtrl.text.isEmpty) return;
    setState(() {
      _funds.add(textoCtrl.text); // 👈 SOLO EL PÁRRAFO
      _seleccionados.add(false);
      textoCtrl.clear();
    });
    widget.onGuardar(_funds);
  }

  void _pegarSeleccionados() {
    List<String> textos = [];
    for (int i = 0; i < _funds.length; i++) {
      if (_seleccionados[i]) {
        textos.add(_funds[i]); // 👈 YA NO CONCATENA TÍTULO
      }
    }
    if (textos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos 1 párrafo')),
      );
      return;
    }
    widget.onPegar(textos);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text('Párrafos', style: TextStyle(color: Colors.white)), // 👈 CAMBIÓ TÍTULO
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: textoCtrl,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Párrafo', // 👈 SOLO PÁRRAFO
                labelStyle: TextStyle(color: Colors.white70),
                hintText: 'Escribe tu fundamento aquí...',
                hintStyle: TextStyle(color: Colors.white38),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[900]),
              onPressed: _agregarFund,
              child: const Text('AGREGAR PÁRRAFO'),
            ),
            const Divider(color: Colors.white24),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _funds.length,
                itemBuilder: (context, i) {
                  return CheckboxListTile(
                    title: Text(
                      _funds[i],
                      style: const TextStyle(color: Colors.white),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ), // 👈 SOLO EL TEXTO
                    value: _seleccionados[i],
                    activeColor: Colors.red[900],
                    onChanged: (bool? value) {
                      setState(() {
                        _seleccionados[i] = value!;
                      });
                    },
                    secondary: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _funds.removeAt(i);
                          _seleccionados.removeAt(i);
                        });
                        widget.onGuardar(_funds);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green[900]),
          onPressed: _pegarSeleccionados,
          child: const Text('PEGAR SELECCIONADOS'),
        ),
      ],
    );
  }
}

// 👈 CÁMARA CON TEXTO SELECCIONABLE + BOTÓN + INTEGRADO
class CameraScreen extends StatefulWidget {
  final String textoAnterior;
  const CameraScreen({super.key, required this.textoAnterior});

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  bool _procesando = false;
  String _textoCompleto = '';
  final TextEditingController _textoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = CameraController(cameras[0], ResolutionPreset.high);
    _initializeControllerFuture = _controller.initialize();
    _textoController.text = widget.textoAnterior; // 👈 CARGA EL TEXTO ANTERIOR
    _textoCompleto = widget.textoAnterior;
  }

  Future<void> _escanearTexto() async {
    try {
      setState(() => _procesando = true);
      await _initializeControllerFuture;
      final image = await _controller.takePicture();
      final inputImage = InputImage.fromFilePath(image.path);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      setState(() {
        _textoCompleto = recognizedText.text;
        _textoController.text = recognizedText.text;
        _procesando = false;
      });
    } catch (e) {
      setState(() => _procesando = false);
    }
  }

  // 👈 ESTE ES EL BOTÓN + QUE PEGA LA SELECCIÓN
  void _pegarSeleccionYCerrar() {
    final seleccion = _textoController.selection;
    String textoAPegar = '';

    if (seleccion.isValid &&!seleccion.isCollapsed) {
      textoAPegar = seleccion.textInside(_textoController.text);
    }

    Navigator.pop(context, {
      'completo': _textoCompleto, // Siempre regresa el texto completo
      'seleccion': textoAPegar, // Solo pega si hay selección
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    textRecognizer.close();
    _textoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.red[900],
        title: const Text('Escanear y seleccionar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _pegarSeleccionYCerrar, // 👈 BOTÓN + EN LA CÁMARA
            tooltip: 'Pegar selección a celda',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return CameraPreview(_controller);
                } else {
                  return const Center(child: CircularProgressIndicator());
                }
              },
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.grey[900],
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  const Text(
                    'Selecciona texto con el dedo y pica +',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: TextField(
                      controller: _textoController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Toma foto para escanear texto...',
                        hintStyle: TextStyle(color: Colors.white38),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red[900],
        onPressed: _procesando? null : _escanearTexto,
        child: _procesando
       ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(Icons.camera),
      ),
    );
  }
}
