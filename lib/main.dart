import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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
      title: 'Oficios',
      theme: ThemeData.dark(),
      home: const OficiosPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class OficiosPage extends StatefulWidget {
  const OficiosPage({super.key});
  @override
  State<OficiosPage> createState() => _OficiosPageState();
}

class ResaltadorController extends TextEditingController {
  final bool resaltar;
  final List<Map<String, int>> camposVerdes;

  ResaltadorController({String? text, this.resaltar = false, this.camposVerdes = const []}) : super(text: text);

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final List<TextSpan> spans = [];
    final String text = this.text;
    final baseStyle = style?? const TextStyle(color: Colors.white, fontSize: 16, height: 1.5);

    if (text.isEmpty) {
      return TextSpan(
        text: 'Pega tu texto aquí...',
        style: baseStyle.copyWith(color: Colors.white38),
      );
    }

    List<bool> pintado = List.filled(text.length, false);
    for (var rango in camposVerdes) {
      int ini = rango['inicio']!;
      int fin = rango['fin']!;
      if (ini >= 0 && fin <= text.length && ini < fin) {
        for (int i = ini; i < fin; i++) pintado[i] = true;
      }
    }

    int i = 0;
    while (i < text.length) {
      if (pintado[i]) {
        int start = i;
        while (i < text.length && pintado[i]) i++;
        spans.add(TextSpan(
          text: text.substring(start, i),
          style: baseStyle.copyWith(color: Colors.green, fontWeight: FontWeight.bold),
        ));
      } else if (resaltar && i + 1 < text.length && text[i] == '{' && text[i + 1] == '{') {
        int start = i;
        int end = text.indexOf('}}', i);
        if (end!= -1) {
          end += 2;
          spans.add(TextSpan(
            text: text.substring(start, end),
            style: baseStyle.copyWith(color: Colors.red, fontWeight: FontWeight.bold),
          ));
          i = end;
        } else {
          spans.add(TextSpan(text: text[i], style: baseStyle));
          i++;
        }
      } else {
        spans.add(TextSpan(text: text[i], style: baseStyle));
        i++;
      }
    }

    return TextSpan(children: spans);
  }
}

class _OficiosPageState extends State<OficiosPage> {
  List<Map<String, String>> _fundamentos = [];
  String _textoEscaneadoCompleto = '';
  late ResaltadorController _controller;
  final FocusNode _focusNode = FocusNode();
  bool _resaltarCampos = false;
  final ScrollController _scrollController = ScrollController();
  List<Map<String, int>> _camposVerdes = [];
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _controller = ResaltadorController(resaltar: _resaltarCampos, camposVerdes: _camposVerdes);
    _controller.addListener(_checarCampoEnCursor);
    _cargarFundamentos();
    Future.delayed(Duration.zero, () => _focusNode.requestFocus());
  }

  void _checarCampoEnCursor() {
    _overlayEntry?.remove();
    _overlayEntry = null;

    final int pos = _controller.selection.baseOffset;
    if (pos < 0 ||!_controller.selection.isCollapsed) return;

    final campo = _buscarCampoEnPosicion(pos);
    if (campo == null) return;

    final nombreCampo = campo['contenido'].toUpperCase();

    final opciones = _fundamentos
  .where((f) => f['titulo']!.toUpperCase() == nombreCampo)
  .toList();

    if (opciones.isNotEmpty) {
      _mostrarMenuFlotante(nombreCampo, opciones, campo);
    }
  }

  void _mostrarMenuFlotante(String nombreCampo, List<Map<String, String>> opciones, Map<String, dynamic> campo) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: offset.dy + 100,
        left: 20,
        right: 20,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[900],
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.red[900]!, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.red[900],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Opciones para $nombreCampo',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 20),
                        onPressed: () {
                          _overlayEntry?.remove();
                          _overlayEntry = null;
                        },
                      ),
                    ],
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: opciones.length,
                    itemBuilder: (context, i) {
                      return ListTile(
                        dense: true,
                        title: Text(
                          opciones[i]['texto']!,
                          style: const TextStyle(color: Colors.white),
                        ),
                        onTap: () {
                          _insertarTextoEnCampo(opciones[i]['texto']!, campo);
                          _overlayEntry?.remove();
                          _overlayEntry = null;
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _insertarTextoEnCampo(String texto, Map<String, dynamic> campo) {
    final int inicio = campo['inicio']!;
    final int fin = campo['fin']!;
    final String textoActual = _controller.text;
    final String nuevoTexto = textoActual.replaceRange(inicio, fin, texto);

    setState(() {
      _camposVerdes.removeWhere((r) => r['inicio']! >= inicio && r['fin']! <= fin);
      _camposVerdes.add({'inicio': inicio, 'fin': inicio + texto.length});
      _actualizarController(nuevoTexto, inicio + texto.length);
    });
    _focusNode.requestFocus();
  }

  Map<String, dynamic>? _buscarCampoEnPosicion(int pos) {
    final text = _controller.text;
    final RegExp exp = RegExp(r'\{\{([^}]+)\}\}');
    for (final match in exp.allMatches(text)) {
      if (pos >= match.start && pos <= match.end) {
        return {
          'inicio': match.start,
          'fin': match.end,
          'contenido': match.group(1)!.trim()
        };
      }
    }
    return null;
  }

  Future<void> _cargarFundamentos() async {
    final prefs = await SharedPreferences.getInstance();
    final String? fundString = prefs.getString('fundamentos_v2');
    if (fundString!= null) {
      setState(() {
        _fundamentos = List<Map<String, String>>.from(
          json.decode(fundString).map((e) => Map<String, String>.from(e))
        );
      });
    }
  }

  Future<void> _guardarFundamentos() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fundamentos_v2', json.encode(_fundamentos));
  }

  void _pegarFecha() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(data: ThemeData.dark(), child: child!),
    );
    if (picked!= null) {
      String fecha = _formatearFechaLarga(picked);
      _insertarTexto(fecha);
    }
  }

  String _formatearFechaLarga(DateTime fecha) {
    final dia = fecha.day;
    final mes = fecha.month;

    final diasEnLetra = [
      '', 'uno', 'dos', 'tres', 'cuatro', 'cinco', 'seis', 'siete', 'ocho', 'nueve', 'diez',
      'once', 'doce', 'trece', 'catorce', 'quince', 'dieciséis', 'diecisiete', 'dieciocho', 'diecinueve', 'veinte',
      'veintiuno', 'veintidós', 'veintitrés', 'veinticuatro', 'veinticinco', 'veintiséis', 'veintisiete', 'veintiocho', 'veintinueve', 'treinta',
      'treinta y uno'
    ];

    final mesesEnLetra = [
      '', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];

    final diaDosDigitos = dia.toString().padLeft(2, '0');
    final diaLetra = diasEnLetra[dia];
    final mesLetra = mesesEnLetra[mes];

    return '$diaDosDigitos $diaLetra de $mesLetra';
  }

  void _abrirPaginaFundamentos() async {
    _overlayEntry?.remove();
    _overlayEntry = null;

    final textoParaInsertar = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => FundamentosPage(fundamentos: _fundamentos),
      ),
    );

    if (textoParaInsertar!= null && textoParaInsertar.isNotEmpty) {
      _insertarTexto(textoParaInsertar);
      _snack('Texto agregado');
    }
    _cargarFundamentos();
  }

  void _abrirCamaraOCR() async {
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
        _textoEscaneadoCompleto = resultado['completo']!;
        if (resultado['seleccion']!.isNotEmpty) {
          _insertarTexto(resultado['seleccion']!);
        }
      });
      if (resultado['seleccion']!.isNotEmpty) {
        _snack('Campo reemplazado');
      }
    }
  }

  void _insertarTexto(String texto) {
    final int cursorPos = _controller.selection.baseOffset;
    final String textoActual = _controller.text;
    final campo = _buscarCampoEnPosicion(cursorPos);

    if (campo!= null) {
      final int inicio = campo['inicio']!;
      final int fin = campo['fin']!;
      final String nuevoTexto = textoActual.replaceRange(inicio, fin, texto);

      setState(() {
        _camposVerdes.removeWhere((r) => r['inicio']! >= inicio && r['fin']! <= fin);
        _camposVerdes.add({'inicio': inicio, 'fin': inicio + texto.length});
        _actualizarController(nuevoTexto, inicio + texto.length);
      });
    } else {
      final String nuevoTexto = cursorPos >= 0
? textoActual.replaceRange(cursorPos, cursorPos, texto)
        : textoActual + texto;
      final int nuevaPos = cursorPos >= 0? cursorPos + texto.length : nuevoTexto.length;

      if (cursorPos >= 0) {
        for (var rango in _camposVerdes) {
          if (rango['inicio']! >= cursorPos) {
            rango['inicio'] = rango['inicio']! + texto.length;
            rango['fin'] = rango['fin']! + texto.length;
          }
        }
      }
      _actualizarController(nuevoTexto, nuevaPos);
    }
  }

  void _actualizarController(String texto, int posCursor) {
    final seleccionActual = TextSelection.collapsed(offset: posCursor);
    _controller.removeListener(_checarCampoEnCursor);
    _controller.dispose();
    _controller = ResaltadorController(
      text: texto,
      resaltar: _resaltarCampos,
      camposVerdes: _camposVerdes
    );
    _controller.addListener(_checarCampoEnCursor);
    _controller.selection = seleccionActual;
    setState(() {});
  }

  void _copiarTodo() {
    Clipboard.setData(ClipboardData(text: _controller.text));
    _snack('Texto copiado');
  }

  void _limpiarTexto() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() {
      _controller.clear();
      _resaltarCampos = false;
      _camposVerdes.clear();
    });
    _snack('Texto limpiado');
  }

  bool _tieneCampos() {
    return RegExp(r'\{\{[^}]+\}\}').hasMatch(_controller.text);
  }

  void _aplicarResaltado() {
    setState(() {
      _resaltarCampos =!_resaltarCampos;
      _actualizarController(_controller.text, _controller.selection.baseOffset);
    });
    _snack(_resaltarCampos? 'Campos resaltados' : 'Resaltado quitado');
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _controller.removeListener(_checarCampoEnCursor);
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.red[900],
        title: const Text('OFICIOS'),
        actions: [
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, child) {
              if (!_tieneCampos()) return const SizedBox.shrink();
              return IconButton(
                icon: Icon(
                  _resaltarCampos? Icons.change_circle : Icons.change_circle_outlined,
                  color: _resaltarCampos? Colors.yellow : Colors.white,
                ),
                onPressed: _aplicarResaltado,
                tooltip: 'Resaltar campos',
              );
            },
          ),
          IconButton(icon: const Icon(Icons.calendar_month), onPressed: _pegarFecha, tooltip: 'Fecha'),
          IconButton(icon: const Icon(Icons.menu_book), onPressed: _abrirPaginaFundamentos, tooltip: 'Librito'),
          IconButton(icon: const Icon(Icons.camera_alt), onPressed: _abrirCamaraOCR, tooltip: 'Escanear'),
          IconButton(icon: const Icon(Icons.copy), onPressed: _copiarTodo, tooltip: 'Copiar'),
          IconButton(icon: const Icon(Icons.clear), onPressed: _limpiarTexto, tooltip: 'Limpiar'),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.red[900]!),
          borderRadius: BorderRadius.circular(8),
          color: const Color(0xFF0A0A0A),
        ),
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          scrollController: _scrollController,
          style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
          cursorColor: Colors.red,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.all(12),
            hintText: 'Pega tu texto aquí...',
            hintStyle: TextStyle(color: Colors.white38),
          ),
        ),
      ),
    );
  }
}

class FundamentosPage extends StatefulWidget {
  final List<Map<String, String>> fundamentos;
  const FundamentosPage({required this.fundamentos, super.key});

  @override
  State<FundamentosPage> createState() => _FundamentosPageState();
}

class _FundamentosPageState extends State<FundamentosPage> {
  final TextEditingController _inputCtrl = TextEditingController();
  late List<Map<String, String>> _funds;
  Set<int> _seleccionados = {};

  @override
  void initState() {
    super.initState();
    _funds = List.from(widget.fundamentos);
  }

  Future<void> _guardar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fundamentos_v2', json.encode(_funds));
  }

  void _procesarTextoPegado() {
    if (_inputCtrl.text.trim().isEmpty) return;

    final bloques = _inputCtrl.text.split(RegExp(r'\n\s*\n'));

    setState(() {
      for (var bloque in bloques) {
        final lineas = bloque.trim().split('\n');
        if (lineas.isNotEmpty) {
          final titulo = lineas[0].trim();
          final texto = lineas.length > 1? lineas.sublist(1).join('\n').trim() : '';
          if (titulo.isNotEmpty) {
            _funds.add({'titulo': titulo, 'texto': texto});
          }
        }
      }
      _inputCtrl.clear();
    });
    _guardar();
  }

  void _toggleSeleccion(int index) {
    setState(() {
      if (_seleccionados.contains(index)) {
        _seleccionados.remove(index);
      } else {
        _seleccionados.add(index);
      }
    });
  }

  void _limpiarSeleccion() {
    setState(() {
      _seleccionados.clear();
    });
  }

  void _insertarSeleccionados() {
    if (_seleccionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos 1 párrafo')),
      );
      return;
    }

    final textos = _seleccionados.map((i) {
      final f = _funds[i];
      return f['texto']!;
    }).join('\n\n');

    Navigator.pop(context, textos);
  }

  void _eliminarFund(int index) {
    setState(() {
      _funds.removeAt(index);
      _seleccionados.remove(index);
      _seleccionados = _seleccionados.map((i) => i > index? i - 1 : i).toSet();
    });
    _guardar();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.red[900],
        title: const Text('LIBRITO'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services),
            onPressed: _limpiarSeleccion,
            tooltip: 'Quitar selección',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _insertarSeleccionados,
            tooltip: 'Insertar seleccionados',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.red[900]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _inputCtrl,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 6,
                  decoration: const InputDecoration(
                    hintText: 'CALIDAD\nimputado\n\nCALIDAD\ndetenido\n\nRECEPCIÓN\nSe recibió...',
                    hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                    border: InputBorder.none,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red[900]),
                  onPressed: _procesarTextoPegado,
                  child: const Text('GUARDAR EN LIBRITO'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _funds.length,
              itemBuilder: (context, i) {
                final fund = _funds[i];
                final estaSeleccionado = _seleccionados.contains(i);
                return GestureDetector(
                  onTap: () => _toggleSeleccion(i),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: estaSeleccionado? Colors.blue[900]!.withOpacity(0.3) : Colors.grey[900],
                      border: Border.all(
                        color: estaSeleccionado? Colors.blue : Colors.transparent,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      title: Text(
                        fund['titulo']!,
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        fund['texto']!,
                        style: TextStyle(
                          color: estaSeleccionado? Colors.blue[200] : Colors.white70,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _eliminarFund(i),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

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
    _textoController.text = widget.textoAnterior;
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

  void _pegarSeleccionYCerrar() {
    final seleccion = _textoController.selection;
    String textoAPegar = '';

    if (seleccion.isValid &&!seleccion.isCollapsed) {
      textoAPegar = seleccion.textInside(_textoController.text);
    }

    Navigator.pop(context, {
      'completo': _textoCompleto,
      'seleccion': textoAPegar,
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
            onPressed: _pegarSeleccionYCerrar,
            tooltip: 'Pegar selección',
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
