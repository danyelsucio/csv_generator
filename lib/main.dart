import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

// ORDEN EXACTO PA EL TXT/EXCEL
const List<String> CAMPOS_ORDEN = [
  'VOLANTE', 'NOMBRE', 'CALIDAD', 'CARPETA', 'OFICIO', 'FECHA', 'RECEPCION',
  'PETICION', 'FOJAS', 'OTROS', 'FUNDAMENTOS', 'ORDEN_RESPUESTAS', 'ESTATUS',
  'EN_ESTUDIO', 'ACCESO', 'COPIAS_VICT', 'COPIAS_IMP', 'AUT_MEDIOS',
  'AUT_ABOGADOS', 'S_R', 'COPIAS_AUTENTICAS'
];

// CAMPOS QUE SON TRUE/FALSE
const Set<String> CAMPOS_BOOL = {
  'ESTATUS', 'EN_ESTUDIO', 'ACCESO', 'COPIAS_VICT', 'COPIAS_IMP', 
  'AUT_MEDIOS', 'AUT_ABOGADOS', 'S_R', 'COPIAS_AUTENTICAS'
};

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
      title: 'Adrianita csv',
      theme: ThemeData.dark(),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}


class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _textoEscaneado = '';
  final TextEditingController _textoController = TextEditingController();

  // AQUÍ GUARDAMOS TODOS LOS CAMPOS
  Map<String, String> _valoresCampos = {};

  @override
  void initState() {
    super.initState();
    // Inicializar todos los campos vacíos
    for (var campo in CAMPOS_ORDEN) {
      _valoresCampos[campo] = '';
    }
    // Los booleanos inician en false
    for (var campo in CAMPOS_BOOL) {
      _valoresCampos[campo] = 'false';
    }
  }

  void _abrirCamara() async {
    if (cameras.isEmpty) {
      _snack('No hay cámaras disponibles');
      return;
    }
    final resultado = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const CameraScreen(),
      ),
    );
    if (resultado!= null && resultado.isNotEmpty) {
      setState(() {
        _textoEscaneado = resultado;
        _textoController.text = resultado;
      });
      _snack('Texto extraído');
    }
  }

  void _abrirMenuCampos() {
    final seleccion = _textoController.selection;
    String textoSeleccionado = '';
    if (seleccion.isValid &&!seleccion.isCollapsed) {
      textoSeleccionado = seleccion.textInside(_textoController.text);
    }
    _mostrarBottomSheetCampos(textoSeleccionado);
  }

  void _mostrarBottomSheetCampos(String textoSeleccionado) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              Text(
                textoSeleccionado.isEmpty
                 ? 'SELECCIONA UN CAMPO'
                  : 'Texto: "${textoSeleccionado.length > 30? '${textoSeleccionado.substring(0, 30)}...' : textoSeleccionado}"',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: CAMPOS_ORDEN.length,
                  itemBuilder: (context, i) {
                    final campo = CAMPOS_ORDEN[i];
                    final valor = _valoresCampos[campo]?? '';
                    final tieneValor = valor.isNotEmpty && valor!= 'false';
                    final esBool = CAMPOS_BOOL.contains(campo);

                    return ListTile(
                      dense: true,
                      title: Text(
                        campo.replaceAll('_', ' '),
                        style: TextStyle(
                          color: tieneValor? Colors.green : Colors.white,
                          fontWeight: tieneValor? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: esBool
                       ? Text(valor == 'true'? 'TRUE' : 'FALSE',
                            style: TextStyle(color: valor == 'true'? Colors.green : Colors.white54))
                        : Text(valor.isEmpty? 'Vacío' : valor,
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (tieneValor &&!esBool)
                            IconButton(
                              icon: const Icon(Icons.clear, color: Colors.red, size: 20),
                              onPressed: () {
                                setModalState(() {
                                  _valoresCampos[campo] = '';
                                });
                                setState(() {});
                                _snack('Campo $campo borrado');
                              },
                            ),
                          if (esBool)
                            Switch(
                              value: valor == 'true',
                              activeColor: Colors.green,
                              onChanged: (v) {
                                setModalState(() {
                                  _valoresCampos[campo] = v.toString();
                                });
                                setState(() {});
                              },
                            ),
                        ],
                      ),
                      onTap: esBool? null : () {
                        if (textoSeleccionado.isEmpty) {
                          _snack('Selecciona texto primero');
                          return;
                        }
                        setModalState(() {
                          _valoresCampos[campo] = textoSeleccionado;
                        });
                        setState(() {});
                        Navigator.pop(context);
                        _snack('Campo $campo = $textoSeleccionado');
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _verCampos() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaginaCampos(
          valoresCampos: Map.from(_valoresCampos),
          onGuardar: (nuevosValores) {
            setState(() {
              _valoresCampos = nuevosValores;
            });
          },
        ),
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _textoController.dispose();
    super.dispose();
  }



    @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.red[900],
        title: const Text(
          'JARVIS Scanner',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          // BOTÓN SHOW
          TextButton(
            onPressed: _verCampos,
            child: const Text(
              'SHOW',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          // BOTÓN +
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white, size: 28),
            onPressed: _abrirMenuCampos,
            tooltip: 'Asignar a campo',
          ),
          // BOTÓN CÁMARA
          IconButton(
            icon: const Icon(Icons.camera_alt, color: Colors.white, size: 28),
            onPressed: _abrirCamara,
          ),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'TEXTO ESCANEADO - Selecciona y pica +',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  border: Border.all(color: Colors.red[900]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _textoEscaneado.isEmpty
                ? const Center(
                      child: Text(
                        'Pica el icono de la cámara pa escanear...',
                        style: TextStyle(color: Colors.white38, fontSize: 16),
                      ),
                    )
                    : TextField(
                      controller: _textoController,
                      readOnly: false,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Texto escaneado...',
                        hintStyle: TextStyle(color: Colors.white38),
                      ),
                      onChanged: (v) {
                        _textoEscaneado = v;
                      },
                    ),
              ),
            ),
            const SizedBox(height: 8),
            // CONTADOR DE CAMPOS LLENOS
            Text(
              'Campos llenos: ${_valoresCampos.values.where((v) => v.isNotEmpty && v!= 'false').length}/${CAMPOS_ORDEN.length}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}


// PÁGINA SHOW - VER TODOS LOS CAMPOS + GUARDAR
class PaginaCampos extends StatefulWidget {
  final Map<String, String> valoresCampos;
  final Function(Map<String, String>) onGuardar;

  const PaginaCampos({
    required this.valoresCampos,
    required this.onGuardar,
    super.key,
  });

  @override
  State<PaginaCampos> createState() => _PaginaCamposState();
}

class _PaginaCamposState extends State<PaginaCampos> {
  late Map<String, String> _valoresTemp;

  @override
  void initState() {
    super.initState();
    _valoresTemp = Map.from(widget.valoresCampos);
  }

  Future<void> _guardarTxt() async {
  try {
    // 1. PREGUNTAR NOMBRE DEL ARCHIVO
    final fecha = DateTime.now().toIso8601String().split('T')[0];
    final hora = DateTime.now().hour.toString().padLeft(2, '0') +
                 DateTime.now().minute.toString().padLeft(2, '0');
    
    final ctrlNombre = TextEditingController(text: 'JARVIS_${fecha}_$hora');
    
    final nombreArchivo = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('NOMBRE DEL ARCHIVO', 
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrlNombre,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Ej: Escritura_Daniel_Hernandez',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.red)),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.green)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrlNombre.text.trim()),
            child: const Text('GUARDAR', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );

    // Si canceló, nos salimos
    if (nombreArchivo == null || nombreArchivo.isEmpty) {
      _snack('Cancelado');
      return;
    }

    // 2. PEDIR PERMISOS
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.request().isDenied) {
        _snack('Ocupas dar permiso en Ajustes');
        await openAppSettings();
        return;
      }
    }

    // 3. GENERAR CSV CON COMILLAS
    final valoresOrdenados = CAMPOS_ORDEN.map((campo) {
      final valor = _valoresTemp[campo]?? '';
      return '"${valor.replaceAll('"', '""')}"';
    }).toList();

    final lineaExcel = valoresOrdenados.join(',');

    // 4. GUARDAR CON EL NOMBRE QUE PUSO
    Directory? dir;
    if (Platform.isAndroid) {
      dir = Directory('/storage/emulated/0/Download');
    } else {
      dir = await getApplicationDocumentsDirectory();
    }

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // Limpiar nombre: quita caracteres raros
    final nombreLimpio = nombreArchivo.replaceAll(RegExp(r'[^\w\s-]'), '');
    final file = File('${dir.path}/$nombreLimpio.csv');

    await file.writeAsString(lineaExcel, flush: true);
    _snack('Guardado: $nombreLimpio.csv');
    
  } catch (e) {
    _snack('Error al guardar: $e');
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
        title: const Text('CAMPOS JARVIS'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            widget.onGuardar(_valoresTemp);
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton.icon(
            onPressed: _guardarTxt,
            icon: const Icon(Icons.save, color: Colors.white),
            label: const Text('GUARDAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.all(12),
        child: ListView.builder(
          itemCount: CAMPOS_ORDEN.length,
          itemBuilder: (context, i) {
            final campo = CAMPOS_ORDEN[i];
            final valor = _valoresTemp[campo]?? '';
            final esBool = CAMPOS_BOOL.contains(campo);
            final tieneValor = valor.isNotEmpty && valor!= 'false';

            return Card(
              color: Colors.grey[900],
              child: ListTile(
                title: Text(
                  campo.replaceAll('_', ' '),
                  style: TextStyle(
                    color: tieneValor? Colors.green : Colors.white,
                    fontWeight: tieneValor? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: Text(
                  valor.isEmpty? 'VACÍO' : valor,
                  style: TextStyle(
                    color: tieneValor? Colors.greenAccent : Colors.white38,
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: esBool
               ? Switch(
                      value: valor == 'true',
                      activeColor: Colors.green,
                      onChanged: (v) {
                        setState(() {
                          _valoresTemp[campo] = v.toString();
                        });
                      },
                    )
                    : IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white54, size: 20),
                      onPressed: () async {
                        final ctrl = TextEditingController(text: valor);
                        final nuevo = await showDialog<String>(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: Colors.grey[900],
                            title: Text(campo.replaceAll('_', ' '),
                              style: const TextStyle(color: Colors.white)),
                            content: TextField(
                              controller: ctrl,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: Colors.red)),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('CANCELAR'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, ctrl.text),
                                child: const Text('OK', style: TextStyle(color: Colors.green)),
                              ),
                            ],
                          ),
                        );
                        if (nuevo!= null) {
                          setState(() {
                            _valoresTemp[campo] = nuevo;
                          });
                        }
                      },
                    ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// PANTALLA DE CÁMARA + OCR - SOLO EXTRAE TEXTO
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

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

      if (mounted) {
        Navigator.pop(context, recognizedText.text);
      }
    } catch (e) {
      setState(() => _procesando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al escanear: $e')),
        );
      }
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return CameraPreview(_controller);
                } else {
                  return const Center(child: CircularProgressIndicator(color: Colors.red));
                }
              },
            ),
          ),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton(
                backgroundColor: Colors.red[900],
                onPressed: _procesando? null : _escanearTexto,
                child: _procesando
              ? const CircularProgressIndicator(color: Colors.white)
                    : const Icon(Icons.camera, size: 32, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
