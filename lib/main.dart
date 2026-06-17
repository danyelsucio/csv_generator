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
      title: 'Escuadrón de Michis Tableros',
      theme: ThemeData.dark(),
      home: const OficiosPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// MODELOS DE DATOS
class TablaMichi {
  final String id;
  final String nombre;
  final List<String> columnas;
  final List<List<String>> filas;
  
  TablaMichi({
    required this.id,
    required this.nombre,
    required this.columnas,
    required this.filas,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'columnas': columnas,
    'filas': filas,
  };

  factory TablaMichi.fromJson(Map<String, dynamic> json) => TablaMichi(
    id: json['id'],
    nombre: json['nombre'],
    columnas: List<String>.from(json['columnas']),
    filas: List<List<String>>.from(
      json['filas'].map((e) => List<String>.from(e))
    ),
  );
}

class CarpetaMichi {
  final String carpeta;
  final String volante;
  final String folio;
  final String direccion;
  final String fecha;
  final String? fechaRecibido;
  
  CarpetaMichi({
    required this.carpeta,
    required this.volante,
    required this.folio,
    required this.direccion,
    required this.fecha,
    this.fechaRecibido,
  });

  Map<String, dynamic> toJson() => {
    'carpeta': carpeta,
    'volante': volante,
    'folio': folio,
    'direccion': direccion,
    'fecha': fecha,
    'fechaRecibido': fechaRecibido,
  };

  factory CarpetaMichi.fromJson(Map<String, dynamic> json) => CarpetaMichi(
    carpeta: json['carpeta'],
    volante: json['volante'],
    folio: json['folio'],
    direccion: json['direccion'],
    fecha: json['fecha'],
    fechaRecibido: json['fechaRecibido'],
  );
}

class OficiosPage extends StatefulWidget {
  const OficiosPage({super.key});
  @override
  State<OficiosPage> createState() => _OficiosPageState();
}

//PARTE 1 ACA ARRIBA

class _OficiosPageState extends State<OficiosPage> {
  // BASE DE DATOS
  List<TablaMichi> _tablas = [];
  List<CarpetaMichi> _carpetasPedidas = [];
  List<CarpetaMichi> _carpetasRecibidas = [];
  List<CarpetaMichi> _carpetasPendientes = [];
  List<String> _datosEscaneados = [];
  List<String> _papelera = [];

  // BARRA SUPERIOR DINÁMICA
  String _labelActual = 'A sus órdenes Lic. Adrianayeli';
  final TextEditingController _inputController = TextEditingController();
  bool _mostrarEnter = false;
  int _columnaIndexActual = 0;
  int _filaIndexActual = 0;

  // ESTADO DE LA APP
  TablaMichi? _tablaEnTurno;
  CarpetaMichi? _carpetaEnTurno;
  String _tipoListaEnTurno = ''; // pedidas, recibidas, pendientes
  bool _modoCreacionTabla = false;
  List<String> _columnasTemp = [];

  // HISTORIAL PARA DESHACER - MICHI MAGO
  final List<Map<String, dynamic>> _historial = [];

  // KEYS SHARED PREFERENCES
  static const String _keyTablas = 'tablas_michi';
  static const String _keyPedidas = 'carpetas_pedidas';
  static const String _keyRecibidas = 'carpetas_recibidas';
  static const String _keyPendientes = 'carpetas_pendientes';
  static const String _keyEscaneados = 'datos_escaneados';
  static const String _keyPapelera = 'papelera_mago';

  @override
  void initState() {
    super.initState();
    _cargarTodo();
  }

  Future<void> _cargarTodo() async {
    final prefs = await SharedPreferences.getInstance();

    final String? tablasString = prefs.getString(_keyTablas);
    if (tablasString!= null) {
      _tablas = List<TablaMichi>.from(
        json.decode(tablasString).map((e) => TablaMichi.fromJson(e))
      );
    }

    final String? pedidasString = prefs.getString(_keyPedidas);
    if (pedidasString!= null) {
      _carpetasPedidas = List<CarpetaMichi>.from(
        json.decode(pedidasString).map((e) => CarpetaMichi.fromJson(e))
      );
    }

    final String? recibidasString = prefs.getString(_keyRecibidas);
    if (recibidasString!= null) {
      _carpetasRecibidas = List<CarpetaMichi>.from(
        json.decode(recibidasString).map((e) => CarpetaMichi.fromJson(e))
      );
    }

    final String? pendientesString = prefs.getString(_keyPendientes);
    if (pendientesString!= null) {
      _carpetasPendientes = List<CarpetaMichi>.from(
        json.decode(pendientesString).map((e) => CarpetaMichi.fromJson(e))
      );
    }

    final String? escaneadosString = prefs.getString(_keyEscaneados);
    if (escaneadosString!= null) {
      _datosEscaneados = List<String>.from(json.decode(escaneadosString));
    }

    final String? papeleraString = prefs.getString(_keyPapelera);
    if (papeleraString!= null) {
      _papelera = List<String>.from(json.decode(papeleraString));
    }

    setState(() {});
  }

  Future<void> _guardarTablas() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTablas, json.encode(_tablas.map((e) => e.toJson()).toList()));
  }

  Future<void> _guardarCarpetas(String tipo) async {
    final prefs = await SharedPreferences.getInstance();
    if (tipo == 'pedidas') {
      await prefs.setString(_keyPedidas, json.encode(_carpetasPedidas.map((e) => e.toJson()).toList()));
    } else if (tipo == 'recibidas') {
      await prefs.setString(_keyRecibidas, json.encode(_carpetasRecibidas.map((e) => e.toJson()).toList()));
    } else if (tipo == 'pendientes') {
      await prefs.setString(_keyPendientes, json.encode(_carpetasPendientes.map((e) => e.toJson()).toList()));
    }
  }

  Future<void> _guardarEscaneados() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyEscaneados, json.encode(_datosEscaneados));
  }

  Future<void> _guardarPapelera() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPapelera, json.encode(_papelera));
  }

  void _resetearBarraSuperior() {
    setState(() {
      _labelActual = 'A sus órdenes Lic. Adrianayeli';
      _inputController.clear();
      _mostrarEnter = false;
      _tablaEnTurno = null;
      _carpetaEnTurno = null;
      _tipoListaEnTurno = '';
      _modoCreacionTabla = false;
      _columnasTemp.clear();
      _columnaIndexActual = 0;
      _filaIndexActual = 0;
    });
  }

  void _agregarAHistorial(String accion, dynamic valor) {
    _historial.add({
      'accion': accion,
      'valor': valor,
      'timestamp': DateTime.now().toIso8601String(),
    });
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

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }


  //PARTE 2 ACA ARRIBA

    // ========== MICHI CONSTRUCTOR ==========
  void _constructorTap() {
    _mostrarListaTablasYCarpetas();
  }

  void _constructorLongPress() {
    setState(() {
      _modoCreacionTabla = true;
      _columnasTemp.clear();
      _columnaIndexActual = 1;
      _labelActual = 'columna1';
      _inputController.clear();
      _mostrarEnter = true;
    });
    _agregarAHistorial('iniciar_tabla', null);
  }

  void _mostrarListaTablasYCarpetas() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text('TABLAS EXISTENTES', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
           ..._tablas.map((tabla) => ListTile(
              title: Text(tabla.nombre, style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _abrirTablaParaEditar(tabla);
              },
            )),
            const Divider(color: Colors.white24),
            const Text('CARPETAS PEDIDAS', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
           ..._carpetasPedidas.asMap().entries.map((e) => ListTile(
              title: Text('FOLIO: ${e.value.folio}', style: const TextStyle(color: Colors.white)),
              subtitle: Text('CARPETA: ${e.value.carpeta}', style: const TextStyle(color: Colors.white70)),
              onTap: () {
                Navigator.pop(context);
                _abrirCarpetaParaEditar(e.value, 'pedidas', e.key);
              },
            )),
            const Text('CARPETAS RECIBIDAS', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
           ..._carpetasRecibidas.asMap().entries.map((e) => ListTile(
              title: Text('FOLIO: ${e.value.folio}', style: const TextStyle(color: Colors.white)),
              subtitle: Text('CARPETA: ${e.value.carpeta}', style: const TextStyle(color: Colors.white70)),
              onTap: () {
                Navigator.pop(context);
                _abrirCarpetaParaEditar(e.value, 'recibidas', e.key);
              },
            )),
            const Text('CARPETAS PENDIENTES', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
           ..._carpetasPendientes.asMap().entries.map((e) => ListTile(
              title: Text('FOLIO: ${e.value.folio}', style: const TextStyle(color: Colors.white)),
              subtitle: Text('CARPETA: ${e.value.carpeta}', style: const TextStyle(color: Colors.white70)),
              onTap: () {
                Navigator.pop(context);
                _abrirCarpetaParaEditar(e.value, 'pendientes', e.key);
              },
            )),
          ],
        ),
      ),
    );
  }

  void _abrirTablaParaEditar(TablaMichi tabla) {
    setState(() {
      _tablaEnTurno = tabla;
      _filaIndexActual = 0;
      _columnaIndexActual = 0;
      if (tabla.columnas.isNotEmpty && tabla.filas.isNotEmpty) {
        _labelActual = tabla.columnas[0];
        _inputController.text = tabla.filas[0][0];
      }
      _mostrarEnter = true;
    });
    _agregarAHistorial('abrir_tabla', tabla.id);
  }

  void _abrirCarpetaParaEditar(CarpetaMichi carpeta, String tipo, int index) {
    setState(() {
      _carpetaEnTurno = carpeta;
      _tipoListaEnTurno = tipo;
      _columnaIndexActual = 0;
      _mostrarEnter = true;
      _actualizarBarraCarpeta();
    });
    _agregarAHistorial('abrir_carpeta', {'tipo': tipo, 'index': index});
  }

  void _actualizarBarraCarpeta() {
    if (_carpetaEnTurno == null) return;
    final campos = ['Carpeta', 'Volante', 'Folio', 'Dirección', 'Fecha'];
    final valores = [
      _carpetaEnTurno!.carpeta,
      _carpetaEnTurno!.volante,
      _carpetaEnTurno!.folio,
      _carpetaEnTurno!.direccion,
      _carpetaEnTurno!.fecha,
    ];
    if (_columnaIndexActual < campos.length) {
      setState(() {
        _labelActual = campos[_columnaIndexActual];
        _inputController.text = valores[_columnaIndexActual];
      });
    }
  }

  // ========== MICHI INSPECTOR ==========
  void _inspectorTap() async {
    if (cameras.isEmpty) {
      _snack('No hay cámaras disponibles');
      return;
    }
    final resultado = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (context) => CameraScreen(textoAnterior: ''),
      ),
    );
    if (resultado!= null && resultado['completo']!.isNotEmpty) {
      setState(() {
        _datosEscaneados.add(resultado['completo']!);
      });
      _guardarEscaneados();
      _snack('Texto escaneado guardado');
      if (_tablaEnTurno!= null || _carpetaEnTurno!= null) {
        _intentarRellenarCampos(resultado['completo']!);
      }
    }
  }

  void _inspectorLongPress() {
    _mostrarListaDatosEscaneados();
  }

  void _mostrarListaDatosEscaneados() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('DATOS ESCANEADOS', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            Expanded(
              child: ListView.builder(
                itemCount: _datosEscaneados.length,
                itemBuilder: (context, i) => ListTile(
                  title: Text(
                    _datosEscaneados[i].length > 50
                     ? '${_datosEscaneados[i].substring(0, 50)}...'
                      : _datosEscaneados[i],
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _inputController.text = _datosEscaneados[i];
                    _agregarAHistorial('pegar_escaneado', i);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _intentarRellenarCampos(String textoEscaneado) {
    // Lógica básica: si hay tabla activa, intenta mapear
    _snack('Datos encontrados: procesando...');
  }

  // ========== MICHI GODÍNEZ ==========
  void _godinezTap() {
    FocusScope.of(context).requestFocus(FocusNode());
    SystemChannels.textInput.invokeMethod('TextInput.show');
    _agregarAHistorial('teclado', null);
  }

  void _godinezLongPress() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(data: ThemeData.dark(), child: child!),
    );
    if (picked!= null) {
      String fecha = _formatearFechaLarga(picked);
      _inputController.text = fecha;
      _agregarAHistorial('fecha', fecha);
    }
  }

  // ========== BOTÓN ENTER DE LA BARRA ==========
  void _onEnterPressed() {
    if (_modoCreacionTabla) {
      _avanzarCreacionTabla();
    } else if (_tablaEnTurno!= null) {
      _avanzarEdicionTabla();
    } else if (_carpetaEnTurno!= null) {
      _avanzarEdicionCarpeta();
    }
  }

  void _avanzarCreacionTabla() {
    final nombreCol = _inputController.text.trim();
    if (nombreCol.isNotEmpty) {
      _columnasTemp.add(nombreCol);
    } else {
      _columnasTemp.add('columna${_columnaIndexActual}');
    }

    if (_columnaIndexActual >= 22) {
      _snack('Máximo 22 columnas');
      return;
    }

    setState(() {
      _columnaIndexActual++;
      _labelActual = 'columna$_columnaIndexActual';
      _inputController.clear();
    });
  }

  void _avanzarEdicionTabla() {
    if (_tablaEnTurno == null) return;

    // Guardar valor actual
    if (_filaIndexActual < _tablaEnTurno!.filas.length &&
        _columnaIndexActual < _tablaEnTurno!.columnas.length) {
      _tablaEnTurno!.filas[_filaIndexActual][_columnaIndexActual] = _inputController.text;
    }

    // Avanzar al siguiente
    _columnaIndexActual++;
    if (_columnaIndexActual >= _tablaEnTurno!.columnas.length) {
      _columnaIndexActual = 0;
      _filaIndexActual++;
      if (_filaIndexActual >= _tablaEnTurno!.filas.length) {
        _snack('Fin de tabla');
        _resetearBarraSuperior();
        return;
      }
    }

    setState(() {
      _labelActual = _tablaEnTurno!.columnas[_columnaIndexActual];
      _inputController.text = _tablaEnTurno!.filas[_filaIndexActual][_columnaIndexActual];
    });
    _guardarTablas();
  }

  void _avanzarEdicionCarpeta() {
    if (_carpetaEnTurno == null) return;

    // Guardar valor actual en carpeta
    final campos = ['carpeta', 'volante', 'folio', 'direccion', 'fecha'];
    if (_columnaIndexActual < campos.length) {
      // Actualizar carpeta en turno
      _actualizarCampoCarpeta(campos[_columnaIndexActual], _inputController.text);
    }

    _columnaIndexActual++;
    if (_columnaIndexActual >= 5) {
      _snack('Fin de carpeta');
      _guardarCarpetas(_tipoListaEnTurno);
      _resetearBarraSuperior();
      return;
    }

    _actualizarBarraCarpeta();
  }

  void _actualizarCampoCarpeta(String campo, String valor) {
    if (_carpetaEnTurno == null) return;
    CarpetaMichi actualizada;
    switch (campo) {
      case 'carpeta':
        actualizada = CarpetaMichi(
          carpeta: valor,
          volante: _carpetaEnTurno!.volante,
          folio: _carpetaEnTurno!.folio,
          direccion: _carpetaEnTurno!.direccion,
          fecha: _carpetaEnTurno!.fecha,
          fechaRecibido: _carpetaEnTurno!.fechaRecibido,
        );
        break;
      case 'volante':
        actualizada = CarpetaMichi(
          carpeta: _carpetaEnTurno!.carpeta,
          volante: valor,
          folio: _carpetaEnTurno!.folio,
          direccion: _carpetaEnTurno!.direccion,
          fecha: _carpetaEnTurno!.fecha,
          fechaRecibido: _carpetaEnTurno!.fechaRecibido,
        );
        break;
      case 'folio':
        actualizada = CarpetaMichi(
          carpeta: _carpetaEnTurno!.carpeta,
          volante: _carpetaEnTurno!.volante,
          folio: valor,
          direccion: _carpetaEnTurno!.direccion,
          fecha: _carpetaEnTurno!.fecha,
          fechaRecibido: _carpetaEnTurno!.fechaRecibido,
        );
        break;
      case 'direccion':
        actualizada = CarpetaMichi(
          carpeta: _carpetaEnTurno!.carpeta,
          volante: _carpetaEnTurno!.volante,
          folio: _carpetaEnTurno!.folio,
          direccion: valor,
          fecha: _carpetaEnTurno!.fecha,
          fechaRecibido: _carpetaEnTurno!.fechaRecibido,
        );
        break;
      case 'fecha':
        actualizada = CarpetaMichi(
          carpeta: _carpetaEnTurno!.carpeta,
          volante: _carpetaEnTurno!.volante,
          folio: _carpetaEnTurno!.folio,
          direccion: _carpetaEnTurno!.direccion,
          fecha: valor,
          fechaRecibido: _carpetaEnTurno!.fechaRecibido,
        );
        break;
      default:
        actualizada = _carpetaEnTurno!;
    }
    setState(() {
      _carpetaEnTurno = actualizada;
    });
  }


  //PARTE 3 ACA ARRIBA

    // ========== MICHI BANQUERO ==========
  void _banqueroTap() {
    _mostrarPaginaSecundariaDatos();
  }

  void _banqueroLongPress() {
    if (_modoCreacionTabla) {
      _guardarTablaNueva();
    } else if (_tablaEnTurno!= null) {
      _guardarTablas();
      _snack('Tabla guardada');
      _resetearBarraSuperior();
    } else if (_carpetaEnTurno!= null) {
      _guardarCarpetas(_tipoListaEnTurno);
      _snack('Carpeta guardada');
      _resetearBarraSuperior();
    } else {
      _snack('Nada que guardar');
    }
  }

  void _guardarTablaNueva() async {
    final nombreCtrl = TextEditingController();
    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Nombre de tabla', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: nombreCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Nombre',
            labelStyle: TextStyle(color: Colors.white70),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.red)),
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

    if (resultado == true && nombreCtrl.text.trim().isNotEmpty) {
      final nuevaTabla = TablaMichi(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        nombre: nombreCtrl.text.trim(),
        columnas: List.from(_columnasTemp),
        filas: [List.filled(_columnasTemp.length, '')],
      );
      setState(() {
        _tablas.add(nuevaTabla);
      });
      _guardarTablas();
      _snack('Tabla creada');
      _resetearBarraSuperior();
    }
    nombreCtrl.dispose();
  }

  void _mostrarPaginaSecundariaDatos() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaginaSecundariaDatos(
          tablas: _tablas,
          pedidas: _carpetasPedidas,
          recibidas: _carpetasRecibidas,
          pendientes: _carpetasPendientes,
        ),
      ),
    );
  }

  // ========== MICHI BARRENDERO ==========
  void _barrenderoTap() {
    if (_labelActual == 'A sus órdenes Lic. Adrianayeli') {
      _snack('Nada que borrar');
      return;
    }
    final valorBorrado = '${_labelActual}: ${_inputController.text}';
    setState(() {
      _papelera.add(valorBorrado);
      _inputController.clear();
    });
    _guardarPapelera();
    _agregarAHistorial('borrar_campo', valorBorrado);
    _snack('Campo borrado');
  }

  void _barrenderoLongPress() async {
    if (_tablaEnTurno!= null) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('¿Borrar tabla completa?', style: TextStyle(color: Colors.red)),
          content: Text('Se borrará: ${_tablaEnTurno!.nombre}', style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('BORRAR', style: TextStyle(color: Colors.red))),
          ],
        ),
      );
      if (confirmar == true) {
        setState(() {
          _tablas.removeWhere((t) => t.id == _tablaEnTurno!.id);
          _papelera.add('TABLA: ${_tablaEnTurno!.nombre}');
        });
        _guardarTablas();
        _guardarPapelera();
        _resetearBarraSuperior();
        _snack('Tabla borrada');
      }
    } else if (_carpetaEnTurno!= null) {
      _snack('Borrando carpeta...');
      // Lógica para borrar carpeta según tipo
      _resetearBarraSuperior();
    } else {
      _snack('Nada seleccionado');
    }
  }

  // ========== MICHI MAGO ==========
  void _magoTap() {
    if (_historial.isEmpty) {
      _snack('No hay acciones para deshacer');
      return;
    }
    final ultimaAccion = _historial.removeLast();
    _snack('Deshecho: ${ultimaAccion['accion']}');
    // Aquí iría lógica específica de deshacer según acción
  }

  void _magoLongPress() {
    _mostrarPapelera();
  }

  void _mostrarPapelera() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('PAPELERA', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18)),
            Expanded(
              child: ListView.builder(
                itemCount: _papelera.length,
                itemBuilder: (context, i) => ListTile(
                  title: Text(_papelera[i], style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.restore, color: Colors.green, size: 20),
                        onPressed: () {
                          setState(() {
                            _inputController.text = _papelera[i];
                            _papelera.removeAt(i);
                          });
                          _guardarPapelera();
                          Navigator.pop(context);
                          _snack('Restaurado');
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_forever, color: Colors.red, size: 20),
                        onPressed: () {
                          setState(() {
                            _papelera.removeAt(i);
                          });
                          _guardarPapelera();
                          _snack('Eliminado definitivamente');
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[900]),
              onPressed: () => Navigator.pop(context),
              child: const Text('CERRAR'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // BARRA SUPERIOR DINÁMICA
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.red[900],
              child: _labelActual == 'A sus órdenes Lic. Adrianayeli'
              ? Center(
                    child: Text(
                      _labelActual,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          _labelActual,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 5,
                        child: TextField(
                          controller: _inputController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.black26,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                      if (_mostrarEnter)...[
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green[900]),
                          onPressed: _onEnterPressed,
                          child: const Icon(Icons.keyboard_return, color: Colors.white),
                        ),
                      ],
                    ],
                  ),
            ),
            // ÁREA CENTRAL VACÍA
            Expanded(
              child: Container(
                color: const Color(0xFF0A0A0A),
                child: Center(
                  child: Text(
                    _tablaEnTurno!= null
                    ? 'Editando: ${_tablaEnTurno!.nombre}'
                      : _carpetaEnTurno!= null
                    ? 'Editando carpeta: ${_carpetaEnTurno!.folio}'
                          : '',
                    style: const TextStyle(color: Colors.white24, fontSize: 16),
                  ),
                ),
              ),
            ),
            // LOS 6 GATOS ABAJO
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              color: Colors.grey[900],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildGatoBoton('🕵️', 'Inspector', _inspectorTap, _inspectorLongPress),
                  _buildGatoBoton('👨‍💼', 'Godínez', _godinezTap, _godinezLongPress),
                  _buildGatoBoton('🏦', 'Banquero', _banqueroTap, _banqueroLongPress),
                  _buildGatoBoton('🧹', 'Barrendero', _barrenderoTap, _barrenderoLongPress),
                  _buildGatoBoton('🧙‍♂️', 'Mago', _magoTap, _magoLongPress),
                  _buildGatoBoton('👷‍♂️', 'Constructor', _constructorTap, _constructorLongPress),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGatoBoton(String emoji, String nombre, VoidCallback onTap, VoidCallback onLongPress) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 4),
          Text(nombre, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }
}

// PÁGINA SECUNDARIA PARA MOSTRAR/COPIAR DATOS
class PaginaSecundariaDatos extends StatefulWidget {
  final List<TablaMichi> tablas;
  final List<CarpetaMichi> pedidas;
  final List<CarpetaMichi> recibidas;
  final List<CarpetaMichi> pendientes;

  const PaginaSecundariaDatos({
    required this.tablas,
    required this.pedidas,
    required this.recibidas,
    required this.pendientes,
    super.key,
  });

  @override
  State<PaginaSecundariaDatos> createState() => _PaginaSecundariaDatosState();
}

class _PaginaSecundariaDatosState extends State<PaginaSecundariaDatos> {
  String _textoCompleto = '';

  @override
  void initState() {
    super.initState();
    _generarTexto();
  }

  void _generarTexto() {
    final buffer = StringBuffer();
    for (var tabla in widget.tablas) {
      buffer.writeln('TABLA: ${tabla.nombre}');
      buffer.writeln(tabla.columnas.join('\t'));
      for (var fila in tabla.filas) {
        buffer.writeln(fila.join('\t'));
      }
      buffer.writeln('');
    }
    setState(() {
      _textoCompleto = buffer.toString();
    });
  }

  void _copiarTexto() {
    Clipboard.setData(ClipboardData(text: _textoCompleto));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copiado')));
  }

  void _limpiarPagina() {
    setState(() {
      _textoCompleto = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.red[900],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.clear), onPressed: _limpiarPagina),
          IconButton(icon: const Icon(Icons.table_chart), onPressed: () {}),
          IconButton(icon: const Icon(Icons.copy), onPressed: _copiarTexto),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.all(12),
        child: SelectableText(
          _textoCompleto,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ),
    );
  }
}

// CÁMARA SCREEN - REUTILIZADA
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
        title: const Text('Escanear'),
        actions: [
          if (_fotoTomada)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _pegarSeleccionYCerrar,
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
                          'Selecciona texto y pica +',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.camera_alt, color: Colors.red),
                        onPressed: () => setState(() => _fotoTomada = false),
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

