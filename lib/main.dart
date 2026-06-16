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
  bool _resaltarCampos = false;
  final ScrollController _scrollController = ScrollController();

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
      _resaltarCampos = false;
    });
    _snack('Texto limpiado');
  }

  bool _tieneCampos() {
    return RegExp(r'\{\{[^}]+\}\}').hasMatch(_controller.text);
  }

  void _aplicarResaltado() {
    setState(() {
      _resaltarCampos =!_resaltarCampos;
    });
    _snack(_resaltarCampos? 'Campos resaltados' : 'Resaltado quitado');
  }

  List<TextSpan> _buildTextSpans(String text) {
    final List<TextSpan> spans = [];

    if (!_resaltarCampos) {
      spans.add(TextSpan(
        text: text.isEmpty? 'Pega tu texto aquí...' : text,
        style: TextStyle(
            color: text.isEmpty? Colors.white38 : Colors.white,
            fontSize: 16,
            height: 1.5),
      ));
      return spans;
    }

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
        style: const Text
