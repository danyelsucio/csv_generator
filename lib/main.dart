import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';

// ========== MODELOS SIMPLIFICADOS ==========
class PedidoCarpeta {
  final String carpeta;
  final String folio;
  final String volante;
  final String destino; // "Noti" o "Mesa de Control"
  final String fechaPedido; // DD/MM/YYYY

  PedidoCarpeta({
    required this.carpeta,
    required this.folio,
    required this.volante,
    required this.destino,
    required this.fechaPedido,
  });

  Map<String, dynamic> toJson() => {
    'carpeta': carpeta,
    'folio': folio,
    'volante': volante,
    'destino': destino,
    'fechaPedido': fechaPedido,
  };

  factory PedidoCarpeta.fromJson(Map<String, dynamic> json) => PedidoCarpeta(
    carpeta: json['carpeta'],
    folio: json['folio'],
    volante: json['volante'],
    destino: json['destino'],
    fechaPedido: json['fechaPedido'],
  );
}

class RecibidoCarpeta {
  final String carpeta;
  final String folio;
  final String volante;
  final String fechaRecibido; // DD/MM/YYYY

  RecibidoCarpeta({
    required this.carpeta,
    required this.folio,
    required this.volante,
    required this.fechaRecibido,
  });

  Map<String, dynamic> toJson() => {
    'carpeta': carpeta,
    'folio': folio,
    'volante': volante,
    'fechaRecibido': fechaRecibido,
  };

  factory RecibidoCarpeta.fromJson(Map<String, dynamic> json) => RecibidoCarpeta(
    carpeta: json['carpeta'],
    folio: json['folio'],
    volante: json['volante'],
    fechaRecibido: json['fechaRecibido'],
  );
}

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
      title: 'Control Carpetas MP',
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

  List<PedidoCarpeta> _pedidos = [];
  List<RecibidoCarpeta> _recibidos = [];

  // 0=Pedidos, 1=Recibidos, 2=Pendientes
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  // ========== PERSISTENCIA ==========
  Future<void> _cargarDatos() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final filePedidos = File('${dir.path}/pedidos.json');
      final fileRecibidos = File('${dir.path}/recibidos.json');

      if (await filePedidos.exists()) {
        final data = await filePedidos.readAsString();
        final List<dynamic> jsonList = jsonDecode(data);
        setState(() {
          _pedidos = jsonList.map((e) => PedidoCarpeta.fromJson(e)).toList();
        });
      }

      if (await fileRecibidos.exists()) {
        final data = await fileRecibidos.readAsString();
        final List<dynamic> jsonList = jsonDecode(data);
        setState(() {
          _recibidos = jsonList.map((e) => RecibidoCarpeta.fromJson(e)).toList();
        });
      }
    } catch (e) {
      print('Error cargando: $e');
    }
  }

  Future<void> _guardarDatos() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final filePedidos = File('${dir.path}/pedidos.json');
      final fileRecibidos = File('${dir.path}/recibidos.json');

      await filePedidos.writeAsString(jsonEncode(_pedidos.map((e) => e.toJson()).toList()));
      await fileRecibidos.writeAsString(jsonEncode(_recibidos.map((e) => e.toJson()).toList()));
    } catch (e) {
      _snack('Error guardando: $e');
    }
  }

  // ========== HELPER FECHA ==========
  String _fechaHoy() {
    final ahora = DateTime.now();
    return '${ahora.day.toString().padLeft(2, '0')}/${ahora.month.toString().padLeft(2, '0')}/${ahora.year}';
  }

  // ========== OCR ==========
  void _abrirCamara() async {
    if (cameras.isEmpty) {
      _snack('No hay cámaras disponibles');
      return;
    }
    final resultado = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const CameraScreen()),
    );
    if (resultado!= null && resultado.isNotEmpty) {
      setState(() {
        _textoEscaneado = resultado;
        _textoController.text = resultado;
      });
      _snack('Texto extraído. Selecciona la carpeta');
    }
  }

  void _procesarBotonMas() {
    final seleccion = _textoController.selection;
    if (!seleccion.isValid || seleccion.isCollapsed) {
      _snack('Selecciona el número de carpeta primero');
      return;
    }
    final carpetaSeleccionada = seleccion.textInside(_textoController.text).trim();
    if (carpetaSeleccionada.isEmpty) {
      _snack('Selecciona el número de carpeta primero');
      return;
    }

    if (_tabIndex == 0) {
      _mostrarDialogoPedido(carpetaSeleccionada);
    } else if (_tabIndex == 1) {
      _procesarRecibido(carpetaSeleccionada);
    }
  }

  // ========== FLUJO PEDIDOS ==========
  void _mostrarDialogoPedido(String carpeta) {
    final ctrlFolio = TextEditingController();
    final ctrlVolante = TextEditingController();
    String destinoSeleccionado = 'Noti';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('NUEVO PEDIDO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CARPETA: $carpeta', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                Text('FECHA: ${_fechaHoy()}', style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrlFolio,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'FOLIO',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.red)),
                  ),
                ),
                TextField(
                  controller: ctrlVolante,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'VOLANTE',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.red)),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('¿SE ENVIÓ A?', style: TextStyle(color: Colors.white70)),
                DropdownButton<String>(
                  value: destinoSeleccionado,
                  dropdownColor: Colors.grey[900],
                  style: const TextStyle(color: Colors.white),
                  items: ['Noti', 'Mesa de Control'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setDialogState(() => destinoSeleccionado = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR', style: TextStyle(color: Colors.red))),
            TextButton(
              onPressed: () {
                if (ctrlFolio.text.isEmpty || ctrlVolante.text.isEmpty) {
                  _snack('Llena folio y volante');
                  return;
                }
                setState(() {
                  _pedidos.add(PedidoCarpeta(
                    carpeta: carpeta,
                    folio: ctrlFolio.text.trim(),
                    volante: ctrlVolante.text.trim(),
                    destino: destinoSeleccionado,
                    fechaPedido: _fechaHoy(),
                  ));
                });
                _guardarDatos();
                Navigator.pop(context);
                _snack('Pedido guardado');
              },
              child: const Text('GUARDAR', style: TextStyle(color: Colors.green)),
            ),
          ],
        ),
      ),
    );
  }

  // ========== FLUJO RECIBIDOS ==========
  void _procesarRecibido(String carpeta) {
    final pedido = _pedidos.firstWhere(
      (p) => p.carpeta.trim().toLowerCase() == carpeta.trim().toLowerCase(),
      orElse: () => PedidoCarpeta(carpeta: '', folio: '', volante: '', destino: '', fechaPedido: ''),
    );

    if (pedido.carpeta.isEmpty) {
      _mostrarAlerta('esta no la pediste regrésala');
      return;
    }

    final yaRecibida = _recibidos.any((r) => r.carpeta.trim().toLowerCase() == carpeta.trim().toLowerCase());
    if (yaRecibida) {
      _snack('Esta carpeta ya fue recibida');
      return;
    }

    setState(() {
      _recibidos.add(RecibidoCarpeta(
        carpeta: pedido.carpeta,
        folio: pedido.folio,
        volante: pedido.volante,
        fechaRecibido: _fechaHoy(),
      ));
    });
    _guardarDatos();
    _snack('Recibida: ${pedido.carpeta}');
  }

  List<PedidoCarpeta> _getPendientes() {
    return _pedidos.where((p) =>
    !_recibidos.any((r) => r.carpeta.trim().toLowerCase() == p.carpeta.trim().toLowerCase())
    ).toList();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _mostrarAlerta(String msg) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.red[900],
        title: const Text('AVISO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 18)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
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
          'Control Carpetas MP',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt, color: Colors.white, size: 28),
            onPressed: _abrirCamara,
            tooltip: 'Escanear',
          ),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ========== TABS ==========
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  _buildTabButton('PEDIDOS', 0),
                  _buildTabButton('RECIBIDOS', 1),
                  _buildTabButton('PENDIENTES', 2),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // ========== AYUDA SEGÚN TAB ==========
            if (_tabIndex == 0)
              const Text('1. Escanea → 2. Selecciona carpeta → 3. Pica +',
                style: TextStyle(color: Colors.yellow, fontSize: 12)),
            if (_tabIndex == 1)
              const Text('1. Escanea carpeta pedida → 2. Selecciona → 3. Pica +',
                style: TextStyle(color: Colors.yellow, fontSize: 12)),
            if (_tabIndex == 2)
              Text('Pendientes: ${_getPendientes().length}',
                style: const TextStyle(color: Colors.orange, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            // ========== TEXTO ESCANEADO ==========
            Container(
              width: double.infinity,
              height: 120,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                border: Border.all(color: Colors.red[900]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _textoEscaneado.isEmpty
           ? const Center(
                  child: Text(
                    'Pica la cámara pa escanear carpeta...',
                    style: TextStyle(color: Colors.white38, fontSize: 14),
                  ),
                )
                : TextField(
                  controller: _textoController,
                  readOnly: false,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Texto escaneado...',
                    hintStyle: TextStyle(color: Colors.white38),
                  ),
                  onChanged: (v) => _textoEscaneado = v,
                ),
            ),
            const SizedBox(height: 12),
            // ========== CONTENIDO TAB ==========
            Expanded(child: _buildTabContent()),
          ],
        ),
      ),
      // ========== BOTÓN + SOLO PA PEDIDOS Y RECIBIDOS ==========
      floatingActionButton: _tabIndex == 0 || _tabIndex == 1
    ? FloatingActionButton(
          backgroundColor: Colors.red[900],
          onPressed: _procesarBotonMas,
          child: const Icon(Icons.add, color: Colors.white, size: 32),
        )
      : null,
    );
  }

  Widget _buildTabButton(String texto, int index) {
    final activo = _tabIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: activo? Colors.red[900] : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            texto,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: activo? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_tabIndex) {
      case 1:
        return _buildListaRecibidos();
      case 2:
        return _buildListaPendientes();
      default:
        return _buildListaPedidos();
    }
  }

  Widget _buildListaPedidos() {
    return _pedidos.isEmpty
  ? const Center(child: Text('Sin pedidos\nEscanea y selecciona carpeta + botón +',
        style: TextStyle(color: Colors.white38), textAlign: TextAlign.center))
      : ListView.builder(
          itemCount: _pedidos.length,
          itemBuilder: (context, i) {
            final p = _pedidos[i];
            return Card(
              color: Colors.grey[900],
              child: ListTile(
                title: Text('CARPETA: ${p.carpeta}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                subtitle: Text('Folio: ${p.folio}\nVolante: ${p.volante}\nDestino: ${p.destino}\nPedido: ${p.fechaPedido}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    setState(() => _pedidos.removeAt(i));
                    _guardarDatos();
                  },
                ),
              ),
            );
          },
        );
  }

  Widget _buildListaRecibidos() {
    return _recibidos.isEmpty
  ? const Center(child: Text('Sin recibidos\nEscanea carpeta pedida + botón +',
        style: TextStyle(color: Colors.white38), textAlign: TextAlign.center))
      : ListView.builder(
          itemCount: _recibidos.length,
          itemBuilder: (context, i) {
            final r = _recibidos[i];
            return Card(
              color: Colors.grey[900],
              child: ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green, size: 32),
                title: Text('CARPETA: ${r.carpeta}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text('Folio: ${r.folio}\nVolante: ${r.volante}\nRecibido: ${r.fechaRecibido}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ),
            );
          },
        );
  }

  Widget _buildListaPendientes() {
    final pendientes = _getPendientes();
    return pendientes.isEmpty
  ? const Center(child: Text('No hay pendientes 👍\nTodo recibido',
        style: TextStyle(color: Colors.green, fontSize: 16), textAlign: TextAlign.center))
      : ListView.builder(
          itemCount: pendientes.length,
          itemBuilder: (context, i) {
            final p = pendientes[i];
            return Card(
              color: Colors.grey[900],
              child: ListTile(
                leading: const Icon(Icons.pending, color: Colors.orange, size: 32),
                title: Text('CARPETA: ${p.carpeta}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                subtitle: Text('Folio: ${p.folio}\nVolante: ${p.volante}\nDestino: ${p.destino}\nPedido: ${p.fechaPedido}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ),
            );
          },
        );
  }
}




// ========== PANTALLA DE CÁMARA + OCR ==========
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
        title: const Text('Escanear Carpeta'),
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






