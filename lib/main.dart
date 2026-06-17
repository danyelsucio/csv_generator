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
  final List<Map<String, int>> camposVerdes;

  ResaltadorController({String? text, this.camposVerdes = const []}) : super(text: text);

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

    // 1. Marcamos qué rangos son verdes
    List<bool> esVerde = List.filled(text.length, false);
    for (var rango in camposVerdes) {
      int ini = rango['inicio']!;
      int fin = rango['fin']!;
      if (ini >= 0 && fin <= text.length && ini < fin) {
        for (int i = ini; i < fin; i++) esVerde[i] = true;
      }
    }

    // 2. Recorremos letra por letra: ROJO tiene prioridad sobre VERDE
    int i = 0;
    while (i < text.length) {
      // PRIORIDAD 1: {{}} SIEMPRE ROJO aunque esté en rango verde
      if (i + 1 < text.length && text[i] == '{' && text[i + 1] == '{') {
        int start = i;
        int end = text.indexOf('}}', i);
        if (end!= -1) {
          end += 2;
          spans.add(TextSpan(
            text: text.substring(start, end),
            style: baseStyle.copyWith(color: Colors.red, fontWeight: FontWeight.bold),
          ));
          i = end;
          continue;
        }
      }

      // PRIORIDAD 2: Si es verde y no es {{}}
      if (esVerde[i]) {
        int start = i;
        while (i < text.length && esVerde[i] &&!(i + 1 < text.length && text[i] == '{' && text[i + 1] == '{')) {
          i++;
        }
        spans.add(TextSpan(
          text: text.substring(start, i),
          style: baseStyle.copyWith(color: Colors.green, fontWeight: FontWeight.bold),
        ));
      } else {
        // Texto normal
        spans.add(TextSpan(text: text[i], style: baseStyle));
        i++;
      }
    }

    return TextSpan(children: spans);
  }
}

  

class _OficiosPageState extends State<OficiosPage> {
  List<Map<String, String>> _fundamentos = [];
  List<Map<String, String>> _pedidos = [];
  List<Map<String, String>> _recibidos = [];

  String _textoEscaneadoCompleto = '';
  late ResaltadorController _controller;
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, int>> _camposVerdes = [];
  OverlayEntry? _overlayEntry;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static const String _keyTextoPrincipal = 'texto_principal_oficio';
  static const String _keyTextoEscaneado = 'texto_escaneado_completo';
  static const String _keyPedidos = 'lista_pedidos';
  static const String _keyRecibidos = 'lista_recibidos';

  @override
  void initState() {
    super.initState();
    _controller = ResaltadorController(camposVerdes: _camposVerdes);
    _controller.addListener(_checarCampoEnCursor);
    _controller.addListener(_guardarTextoPrincipal);
    _cargarTodo();
    Future.delayed(Duration.zero, () => _focusNode.requestFocus());
  }

  Future<void> _cargarTodo() async {
    final prefs = await SharedPreferences.getInstance();

    final String? textoGuardado = prefs.getString(_keyTextoPrincipal);
    if (textoGuardado!= null && textoGuardado.isNotEmpty) {
      _actualizarController(textoGuardado, textoGuardado.length);
    }

    _textoEscaneadoCompleto = prefs.getString(_keyTextoEscaneado)?? '';

    final String? fundString = prefs.getString('fundamentos_v2');
    if (fundString!= null) {
      _fundamentos = List<Map<String, String>>.from(
        json.decode(fundString).map((e) => Map<String, String>.from(e))
      );
    }

    final String? pedidosString = prefs.getString(_keyPedidos);
    if (pedidosString!= null) {
      _pedidos = List<Map<String, String>>.from(
        json.decode(pedidosString).map((e) => Map<String, String>.from(e))
      );
    }

    final String? recibidosString = prefs.getString(_keyRecibidos);
    if (recibidosString!= null) {
      _recibidos = List<Map<String, String>>.from(
        json.decode(recibidosString).map((e) => Map<String, String>.from(e))
      );
    }

    setState(() {});
  }

  void _guardarTextoPrincipal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTextoPrincipal, _controller.text);
  }

  Future<void> _guardarTextoEscaneado() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTextoEscaneado, _textoEscaneadoCompleto);
  }

  Future<void> _guardarFundamentos() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fundamentos_v2', json.encode(_fundamentos));
  }

  Future<void> _guardarPedidos() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPedidos, json.encode(_pedidos));
  }

  Future<void> _guardarRecibidos() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRecibidos, json.encode(_recibidos));
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

      bool yaExiste = _fundamentos.any((f) =>
        f['titulo']!.toUpperCase() == 'FECHA' && f['texto']!.trim() == fecha.trim()
      );

      if (!yaExiste) {
        setState(() {
          _fundamentos.add({
            'titulo': 'FECHA',
            'texto': fecha.trim(),
          });
        });
        _guardarFundamentos();
      }

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
    _cargarTodo();
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
        _textoEscaneadoCompleto = resultado['completo']!; // PERMANECE HASTA NUEVA FOTO
        if (resultado['seleccion']!.isNotEmpty) {
          _insertarTexto(resultado['seleccion']!);
        }
      });
      _guardarTextoEscaneado();
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
      final String nombreCampo = campo['contenido'].toUpperCase().trim();

      if ((nombreCampo == 'NOMBRE' || nombreCampo == 'FECHA') && texto.trim().isNotEmpty) {
        bool yaExiste = _fundamentos.any((f) =>
          f['titulo']!.toUpperCase() == nombreCampo && f['texto']!.trim() == texto.trim()
        );

        if (!yaExiste) {
          setState(() {
            _fundamentos.add({
              'titulo': nombreCampo,
              'texto': texto.trim(),
            });
          });
          _guardarFundamentos();
        }
      }

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
    _controller.removeListener(_guardarTextoPrincipal);
    _controller.dispose();
    _controller = ResaltadorController(
      text: texto,
      camposVerdes: _camposVerdes
    );
    _controller.addListener(_checarCampoEnCursor);
    _controller.addListener(_guardarTextoPrincipal);
    _controller.selection = seleccionActual;
    setState(() {});
  }

  void _copiarTodo() {
    Clipboard.setData(ClipboardData(text: _controller.text));
    _snack('Texto copiado');
  }

  void _limpiarTexto() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('¿Borrar todo?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Se va a borrar todo el texto del oficio. ¿Estás seguro?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('BORRAR', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      setState(() {
        _controller.clear();
        _camposVerdes.clear();
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyTextoPrincipal);
      _snack('Texto limpiado');
    }
  }

  void _mostrarListaEnPantalla(String tipo, List<Map<String, String>> lista) {
    if (_controller.text.trim().isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('Primero borra el texto', style: TextStyle(color: Colors.white)),
          content: const Text(
            'Para ver la lista debes borrar el texto con el botón de tachecito',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      return;
    }

    String textoLista = lista.map((e) {
      if (tipo == 'Pedidos') {
        return 'VOLANTE: ${e['volante']}\nCARPETA: ${e['carpeta']}\nFOLIO: ${e['folio']}\nDIRECCIÓN: ${e['direccion']}';
      } else {
        return 'FOLIO: ${e['folio']}\nVOLANTE: ${e['volante']}\nCARPETA: ${e['carpeta']}\nDIRECCIÓN: ${e['direccion']}';
      }
    }).join('\n\n─────────────────\n\n');

    setState(() {
      _actualizarController(textoLista, 0);
    });
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _agregarPedido() async {
  final volanteCtrl = TextEditingController();
  final carpetaCtrl = TextEditingController();
  final folioCtrl = TextEditingController();
  final direccionCtrl = TextEditingController();
  final fechaCtrl = TextEditingController(); // NUEVO CAMPO

  // FocusNodes para saber dónde está el cursor
  final volanteFocus = FocusNode();
  final carpetaFocus = FocusNode();
  final folioFocus = FocusNode();
  final direccionFocus = FocusNode();
  final fechaFocus = FocusNode();

  TextEditingController? _getActiveController() {
    if (volanteFocus.hasFocus) return volanteCtrl;
    if (carpetaFocus.hasFocus) return carpetaCtrl;
    if (folioFocus.hasFocus) return folioCtrl;
    if (direccionFocus.hasFocus) return direccionCtrl;
    if (fechaFocus.hasFocus) return fechaCtrl;
    return null;
  }

  void _insertarEnCampoActivo(String texto) {
    final ctrl = _getActiveController();
    if (ctrl!= null) {
      final int pos = ctrl.selection.baseOffset;
      final String nuevo = ctrl.text.replaceRange(pos >= 0? pos : ctrl.text.length, pos >= 0? pos : ctrl.text.length, texto);
      ctrl.text = nuevo;
      ctrl.selection = TextSelection.collapsed(offset: (pos >= 0? pos : ctrl.text.length) + texto.length);
    }
  }

  Future<void> _abrirLibritoDialog() async {
    final texto = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => FundamentosPage(fundamentos: _fundamentos),
      ),
    );
    if (texto!= null && texto.isNotEmpty) {
      _insertarEnCampoActivo(texto);
    }
  }

  Future<void> _abrirScannerDialog() async {
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
      });
      _guardarTextoEscaneado();
      if (resultado['seleccion']!.isNotEmpty) {
        _insertarEnCampoActivo(resultado['seleccion']!);
      }
    }
  }

  Future<void> _pegarFechaDialog() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(data: ThemeData.dark(), child: child!),
    );
    if (picked!= null) {
      String fecha = _formatearFechaLarga(picked);
      _insertarEnCampoActivo(fecha);
    }
  }

  final resultado = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.grey[900],
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Nuevo Pedido', style: TextStyle(color: Colors.white)),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.calendar_month, color: Colors.white70, size: 20),
                onPressed: _pegarFechaDialog,
                tooltip: 'Fecha',
              ),
              IconButton(
                icon: const Icon(Icons.menu_book, color: Colors.white70, size: 20),
                onPressed: _abrirLibritoDialog,
                tooltip: 'Librito',
              ),
              IconButton(
                icon: const Icon(Icons.camera_alt, color: Colors.white70, size: 20),
                onPressed: _abrirScannerDialog,
                tooltip: 'Escanear',
              ),
            ],
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _campoDialog(volanteCtrl, 'VOLANTE', volanteFocus),
            _campoDialog(carpetaCtrl, 'CARPETA', carpetaFocus),
            _campoDialog(folioCtrl, 'FOLIO', folioFocus),
            _campoDialog(direccionCtrl, 'DIRECCIÓN', direccionFocus),
            _campoDialog(fechaCtrl, 'FECHA', fechaFocus), // NUEVO
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Guardar', style: TextStyle(color: Colors.green)),
        ),
      ],
    ),
  );

  if (resultado == true) {
    setState(() {
      _pedidos.add({
        'volante': volanteCtrl.text.trim(),
        'carpeta': carpetaCtrl.text.trim(),
        'folio': folioCtrl.text.trim(),
        'direccion': direccionCtrl.text.trim(),
        'fecha': fechaCtrl.text.trim(), // NUEVO
      });
    });
    _guardarPedidos();
  }

  volanteCtrl.dispose();
  carpetaCtrl.dispose();
  folioCtrl.dispose();
  direccionCtrl.dispose();
  fechaCtrl.dispose();
  volanteFocus.dispose();
  carpetaFocus.dispose();
  folioFocus.dispose();
  direccionFocus.dispose();
  fechaFocus.dispose();
  }

  void _agregarRecibido() async {
    final folioCtrl = TextEditingController();

    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Nuevo Recibido', style: TextStyle(color: Colors.white)),
        content: _campoDialog(folioCtrl, 'FOLIO'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Buscar', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );

    if (resultado == true) {
      final folio = folioCtrl.text.trim();
      final pedido = _pedidos.firstWhere(
        (p) => p['folio'] == folio,
        orElse: () => {},
      );

      if (pedido.isEmpty) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text('Carpeta no pedida', style: TextStyle(color: Colors.red)),
            content: const Text(
              'Este folio no está en la lista de pedidos',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      } else {
        setState(() {
          _recibidos.add(pedido);
        });
        _guardarRecibidos();
        _snack('Recibido agregado');
      }
    }

    folioCtrl.dispose();
  }

  List<Map<String, String>> _obtenerPendientes() {
    return _pedidos.where((p) {
      return!_recibidos.any((r) => r['folio'] == p['folio']);
    }).toList();
  }

  Widget _campoDialog(TextEditingController ctrl, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.red)),
          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.green)),
        ),
      ),
    );
  }

  void _borrarItem(List<Map<String, String>> lista, int index, VoidCallback guardar) {
    setState(() {
      lista.removeAt(index);
    });
    guardar();
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _controller.removeListener(_checarCampoEnCursor);
    _controller.removeListener(_guardarTextoPrincipal);
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.red[900],
        title: const Text(''),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.calendar_month), onPressed: _pegarFecha, tooltip: 'Fecha'),
          IconButton(icon: const Icon(Icons.menu_book), onPressed: _abrirPaginaFundamentos, tooltip: 'Librito'),
          IconButton(icon: const Icon(Icons.camera_alt), onPressed: _abrirCamaraOCR, tooltip: 'Escanear'),
          IconButton(icon: const Icon(Icons.copy), onPressed: _copiarTodo, tooltip: 'Copiar'),
          IconButton(icon: const Icon(Icons.clear), onPressed: _limpiarTexto, tooltip: 'Limpiar'),
          const SizedBox(width: 8),
        ],
      ),
      drawer: Drawer(
        backgroundColor: Colors.grey[900],
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red[900]!, Colors.green[900]!],
                ),
              ),
              child: const Text(
                'OFICIOS - MENÚ',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.send, color: Colors.red),
              title: const Text('Pedidos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              trailing: IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.green),
                onPressed: () {
                  Navigator.pop(context);
                  _agregarPedido();
                },
              ),
              onTap: () {
                Navigator.pop(context);
                _mostrarListaEnPantalla('Pedidos', _pedidos);
              },
            ),
            if (_pedidos.isNotEmpty)
           ..._pedidos.asMap().entries.map((e) => ListTile(
                dense: true,
                contentPadding: const EdgeInsets.only(left: 72, right: 16),
                title: Text(
                  'FOLIO: ${e.value['folio']}',
                  style: const TextStyle(color: Colors.green, fontSize: 12),
                ),
                subtitle: Text(
                  'CARPETA: ${e.value['carpeta']}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                  onPressed: () => _borrarItem(_pedidos, e.key, _guardarPedidos),
                ),
              )),
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.inbox, color: Colors.green),
              title: const Text('Recibidos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              trailing: IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.red),
                onPressed: () {
                  Navigator.pop(context);
                  _agregarRecibido();
                },
              ),
              onTap: () {
                Navigator.pop(context);
                _mostrarListaEnPantalla('Recibidos', _recibidos);
              },
            ),
            if (_recibidos.isNotEmpty)
           ..._recibidos.asMap().entries.map((e) => ListTile(
                dense: true,
                contentPadding: const EdgeInsets.only(left: 72, right: 16),
                title: Text(
                  'FOLIO: ${e.value['folio']}',
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
                subtitle: Text(
                  'CARPETA: ${e.value['carpeta']}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.green, size: 18),
                  onPressed: () => _borrarItem(_recibidos, e.key, _guardarRecibidos),
                ),
              )),
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.pending_actions, color: Colors.yellow),
              title: const Text('Pendientes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                _mostrarListaEnPantalla('Pendientes', _obtenerPendientes());
              },
            ),
          ],
        ),
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

  void _editarFund(int index) async {
    final fund = _funds[index];
    final tituloCtrl = TextEditingController(text: fund['titulo']);
    final textoCtrl = TextEditingController(text: fund['texto']);

    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Editar', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: tituloCtrl,
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  labelText: 'TÍTULO',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.red)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textoCtrl,
                style: const TextStyle(color: Colors.white),
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Texto',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (resultado == true) {
      setState(() {
        _funds[index] = {
          'titulo': tituloCtrl.text.trim(),
          'texto': textoCtrl.text.trim(),
        };
      });
      _guardar();
    }

    tituloCtrl.dispose();
    textoCtrl.dispose();
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
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _editarFund(i),
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
  bool _fotoTomada = false;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(cameras[0], ResolutionPreset.high);
    _initializeControllerFuture = _controller.initialize();
    _textoController.text = widget.textoAnterior;
    _textoCompleto = widget.textoAnterior;
    // Si ya hay texto anterior, mostrarlo directo pa sacar más datos
    if (widget.textoAnterior.isNotEmpty) {
      _fotoTomada = true;
    }
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
        _fotoTomada = true;
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
          if (_fotoTomada)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _pegarSeleccionYCerrar,
              tooltip: 'Pegar selección',
            ),
        ],
      ),
      body: _fotoTomada
      ? Container(
              color: Colors.grey[900],
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Selecciona texto con el dedo y pica +',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.camera_alt, color: Colors.red),
                        onPressed: () => setState(() => _fotoTomada = false),
                        tooltip: 'Tomar otra foto',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: TextField(
                      controller: _textoController,
                      readOnly: true,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Texto escaneado...',
                        hintStyle: TextStyle(color: Colors.white38),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                Positioned.fill(
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
                          : const Icon(Icons.camera, size: 32),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
