import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';

class PedidoCarpeta {
  final String carpeta;
  final String folio;
  final String volante;
  final String destino;
  final String fechaPedido;

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
  final String fechaRecibido;

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
  List<PedidoCarpeta> _pedidos = [];
  List<RecibidoCarpeta> _recibidos = [];
  int _tabIndex = 0; // 0=Pedidos, 1=Recibidos, 2=Pendientes

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

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

  String _fechaHoy() {
    final ahora = DateTime.now();
    return '${ahora.day.toString().padLeft(2, '0')}/${ahora.month.toString().padLeft(2, '0')}/${ahora.year}';
  }

  List<PedidoCarpeta> _getPendientes() {
    return _pedidos.where((p) =>
    !_recibidos.any((r) => r.carpeta.trim().toLowerCase() == p.carpeta.trim().toLowerCase())
    ).toList();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

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
      _abrirPantallaTextoCompleto(resultado);
    }
  }

  void _abrirPantallaTextoCompleto(String textoEscaneado) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PantallaTextoCompleto(
          textoInicial: textoEscaneado,
          pedidos: _pedidos,
          recibidos: _recibidos,
          onAgregarPedido: (pedido) {
            setState(() => _pedidos.add(pedido));
            _guardarDatos();
          },
          onAgregarRecibido: (recibido) {
            setState(() => _recibidos.add(recibido));
            _guardarDatos();
          },
        ),
      ),
    );
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
            tooltip: 'Escanear Documento',
          ),
        ],
      ),
      body: Column(
        children: [
          // ========== TABS ==========
          Container(
            color: Colors.grey[900],
            child: Row(
              children: [
                _buildTabButton('PEDIDOS (${_pedidos.length})', 0),
                _buildTabButton('RECIBIDOS (${_recibidos.length})', 1),
                _buildTabButton('PENDIENTES (${_getPendientes().length})', 2),
              ],
            ),
          ),
          // ========== LISTA ==========
          Expanded(child: _buildTabContent()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.red[900],
        onPressed: _abrirCamara,
        icon: const Icon(Icons.camera_alt, color: Colors.white),
        label: const Text('ESCANEAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildTabButton(String texto, int index) {
    final activo = _tabIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: activo? Colors.red[900] : Colors.transparent,
            border: Border(bottom: BorderSide(color: activo? Colors.red : Colors.transparent, width: 3)),
          ),
          child: Text(
            texto,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: activo? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
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
 ? const Center(child: Text('Sin pedidos\nPica ESCANEAR pa empezar',
        style: TextStyle(color: Colors.white38), textAlign: TextAlign.center))
      : ListView.builder(
          itemCount: _pedidos.length,
          itemBuilder: (context, i) {
            final p = _pedidos[i];
            return Dismissible(
              key: Key(p.carpeta + p.fechaPedido),
              direction: DismissDirection.endToStart,
              background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
              onDismissed: (dir) {
                setState(() => _pedidos.removeAt(i));
                _guardarDatos();
                _snack('Pedido eliminado');
              },
              child: Card(
                color: Colors.grey[900],
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  title: Text('CARPETA: ${p.carpeta}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  subtitle: Text('Folio: ${p.folio}\nVolante: ${p.volante}\nDestino: ${p.destino}\nPedido: ${p.fechaPedido}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ),
              ),
            );
          },
        );
  }

  Widget _buildListaRecibidos() {
    return _recibidos.isEmpty
 ? const Center(child: Text('Sin recibidos\nEscanea una carpeta pedida',
        style: TextStyle(color: Colors.white38), textAlign: TextAlign.center))
      : ListView.builder(
          itemCount: _recibidos.length,
          itemBuilder: (context, i) {
            final r = _recibidos[i];
            return Card(
              color: Colors.grey[900],
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

// ========== PANTALLA NUEVA: TEXTO COMPLETO ==========
class PantallaTextoCompleto extends StatefulWidget {
  final String textoInicial;
  final List<PedidoCarpeta> pedidos;
  final List<RecibidoCarpeta> recibidos;
  final Function(PedidoCarpeta) onAgregarPedido;
  final Function(RecibidoCarpeta) onAgregarRecibido;

  const PantallaTextoCompleto({
    required this.textoInicial,
    required this.pedidos,
    required this.recibidos,
    required this.onAgregarPedido,
    required this.onAgregarRecibido,
    super.key,
  });

  @override
  State<PantallaTextoCompleto> createState() => _PantallaTextoCompletoState();
}

class _PantallaTextoCompletoState extends State<PantallaTextoCompleto> {
  late TextEditingController _textoController;

  @override
  void initState() {
    super.initState();
    _textoController = TextEditingController(text: widget.textoInicial);
  }

  String _fechaHoy() {
    final ahora = DateTime.now();
    return '${ahora.day.toString().padLeft(2, '0')}/${ahora.month.toString().padLeft(2, '0')}/${ahora.year}';
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

  void _procesarComoPedido() {
    final seleccion = _textoController.selection;
    if (!seleccion.isValid || seleccion.isCollapsed) {
      _snack('Selecciona el número de carpeta en el texto');
      return;
    }
    final carpeta = seleccion.textInside(_textoController.text).trim();
    if (carpeta.isEmpty) {
      _snack('Selecciona el número de carpeta');
      return;
    }
    _mostrarDialogoPedido(carpeta);
  }

  void _procesarComoRecibido() {
    final seleccion = _textoController.selection;
    if (!seleccion.isValid || seleccion.isCollapsed) {
      _snack('Selecciona el número de carpeta en el texto');
      return;
    }
    final carpeta = seleccion.textInside(_textoController.text).trim();
    if (carpeta.isEmpty) {
      _snack('Selecciona el número de carpeta');
      return;
    }

    final pedido = widget.pedidos.firstWhere(
      (p) => p.carpeta.trim().toLowerCase() == carpeta.trim().toLowerCase(),
      orElse: () => PedidoCarpeta(carpeta: '', folio: '', volante: '', destino: '', fechaPedido: ''),
    );

    if (pedido.carpeta.isEmpty) {
      _mostrarAlerta('esta no la pediste regrésala');
      return;
    }

    final yaRecibida = widget.recibidos.any((r) => r.carpeta.trim().toLowerCase() == carpeta.trim().toLowerCase());
    if (yaRecibida) {
      _snack('Esta carpeta ya fue recibida');
      return;
    }

    widget.onAgregarRecibido(RecibidoCarpeta(
      carpeta: pedido.carpeta,
      folio: pedido.folio,
      volante: pedido.volante,
      fechaRecibido: _fechaHoy(),
    ));
    Navigator.pop(context);
    _snack('Recibida: ${pedido.carpeta}');
  }

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
                widget.onAgregarPedido(PedidoCarpeta(
                  carpeta: carpeta,
                  folio: ctrlFolio.text.trim(),
                  volante: ctrlVolante.text.trim(),
                  destino: destinoSeleccionado,
                  fechaPedido: _fechaHoy(),
                ));
                Navigator.pop(context);
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




    @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.red[900],
        title: const Text('Selecciona Carpeta', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // ========== INSTRUCCIONES ==========
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.yellow[900],
            child: const Text(
              '1. Corrige el texto si tiene errores\n2. Selecciona el NÚMERO DE CARPETA\n3. Pica PEDIDO o RECIBIDO',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          // ========== TEXTO COMPLETO EDITABLE ==========
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                border: Border.all(color: Colors.red[900]!, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _textoController,
                style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Texto escaneado...',
                  hintStyle: TextStyle(color: Colors.white38),
                ),
              ),
            ),
          ),
          // ========== BOTONES ACCIÓN ==========
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey[900],
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _procesarComoPedido,
                    icon: const Icon(Icons.send, color: Colors.white),
                    label: const Text('PEDIDO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[800],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _procesarComoRecibido,
                    icon: const Icon(Icons.check_circle, color: Colors.white),
                    label: const Text('RECIBIDO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[800],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _textoController.dispose();
    super.dispose();
  }
}

// ========== PANTALLA CÁMARA ==========
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
        title: const Text('Escanear Documento'),
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
              child: FloatingActionButton.extended(
                backgroundColor: Colors.red[900],
                onPressed: _procesando? null : _escanearTexto,
                icon: _procesando
           ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.camera, size: 28, color: Colors.white),
                label: Text(_procesando? 'PROCESANDO...' : 'TOMAR FOTO', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}








  
