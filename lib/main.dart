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

class _OficiosPageState extends State<OficiosPage> {
  List<String> _fundamentos = [];
  String _textoEscaneadoCompleto = '';
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _cargarFundamentos();
    Future.delayed(Duration.zero, () => _focusNode.requestFocus());
  }

  Future<void> _cargarFundamentos() async {
    final prefs = await SharedPreferences.getInstance();
    final String? fundString = prefs.getString('fundamentos');
    if (fundString!= null) {
      setState(() {
        _fundamentos = List<String>.from(json.decode(fundString));
      });
    }
  }

  Future<void> _guardarFundamentos() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fundamentos', json.encode(_fundamentos));
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
      String fecha = DateFormat('dd/MM/yy').format(picked);
      _insertarTexto(fecha);
    }
  }

  void _gestionarFundamentos() async {
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
          _insertarTexto(textos.join('\n'));
          Navigator.pop(context);
        },
      ),
    );
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
        _snack('Texto pegado');
      }
    }
  }

  void _insertarTexto(String texto) {
    final int cursorPos = _controller.selection.baseOffset;
    final String nuevoTexto = cursorPos >= 0
       ? _controller.text.replaceRange(cursorPos, cursorPos, texto)
        : _controller.text + texto;
    _controller.value = TextEditingValue(
      text: nuevoTexto,
      selection: TextSelection.collapsed(offset: cursorPos + texto.length),
    );
  }

  void _copiarTodo() {
    Clipboard.setData(ClipboardData(text: _controller.text));
    _snack('Texto copiado');
  }

  void _limpiarTexto() {
    setState(() {
      _controller.clear();
    });
    _snack('Texto limpiado');
  }

  List<TextSpan> _buildTextSpans(String text) {
    final List<TextSpan> spans = [];
    final RegExp exp = RegExp(r'\{\{[^}]+\}\}');
    int lastMatchEnd = 0;

    for (final Match match in exp.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
        ));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: const TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold, height: 1.5),
      ));
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
      ));
    }

    if (spans.isEmpty) {
      spans.add(const TextSpan(
        text: 'Pega tu texto aquí...',
        style: TextStyle(color: Colors.white38, fontSize: 16, height: 1.5),
      ));
    }

    return spans;
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
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
          IconButton(icon: const Icon(Icons.calendar_month), onPressed: _pegarFecha, tooltip: 'Fecha'),
          IconButton(icon: const Icon(Icons.menu_book), onPressed: _gestionarFundamentos, tooltip: 'Fundamentos'),
          IconButton(icon: const Icon(Icons.camera_alt), onPressed: _abrirCamaraOCR, tooltip: 'Escanear'),
          IconButton(icon: const Icon(Icons.copy), onPressed: _copiarTodo, tooltip: 'Copiar'),
          IconButton(icon: const Icon(Icons.clear), onPressed: _limpiarTexto, tooltip: 'Limpiar'),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
  padding: const EdgeInsets.all(12),
  child: Container(
    decoration: BoxDecoration(
      border: Border.all(color: Colors.red[900]!),
      borderRadius: BorderRadius.circular(8),
      color: const Color(0xFF0A0A0A),
    ),
    child: Stack(
      children: [
        // 👇 1. CAPA DE ABAJO: Texto pintado que SÍ scrollea
        SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, child) {
              return SelectableText.rich(
                TextSpan(children: _buildTextSpans(value.text + '\n')), // 👈 \n extra pa que scrollee
              );
            },
          ),
        ),
        // 👇 2. CAPA DE ARRIBA: TextField invisible que TAMBIÉN scrollea
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          style: const TextStyle(color: Colors.transparent, fontSize: 16, height: 1.5),
          cursorColor: Colors.red,
          maxLines: null,
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.all(12),
          ),
        ),
      ],
    ),
  ),
),
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: const TextStyle(color: Colors.transparent, fontSize: 16, height: 1.5),
              cursorColor: Colors.red,
              maxLines: null,
              expands: true,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(12),
              ),
            ),
          ],
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
  final textoCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _funds = List.from(widget.fundamentos);
    _seleccionados = List.generate(_funds.length, (index) => false);
  }

  void _agregarFund() {
    if (textoCtrl.text.isEmpty) return;
    setState(() {
      _funds.add(textoCtrl.text);
      _seleccionados.add(false);
      textoCtrl.clear();
    });
    widget.onGuardar(_funds);

    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _pegarSeleccionados() {
    List<String> textos = [];
    for (int i = 0; i < _funds.length; i++) {
      if (_seleccionados[i]) {
        textos.add(_funds[i]);
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
  void dispose() {
    textoCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text('Párrafos', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textoCtrl,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Párrafo',
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
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _funds.length,
                itemBuilder: (context, i) {
                  return CheckboxListTile(
                    title: Text(
                      _funds[i],
                      style: const TextStyle(color: Colors.white),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
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
            ],
          ),
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
