import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:convert';

// ========== NUEVO: MODELOS PA CONTROL DE CARPETAS ==========
class PedidoCarpeta {
  final String carpeta;
  final String folio;
  final String volante;
  final String destino; // "Noti" o "Mesa de Control"
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
      title: 'Adry CSV - Control Carpetas',
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

  // AQUÍ GUARDAMOS TODOS LOS CAMPOS DEL CSV ORIGINAL
  Map<String, String> _valoresCampos = {};

  // ========== NUEVO: LISTAS PA CONTROL DE CARPETAS ==========
  List<PedidoCarpeta> _pedidos = [];
  List<RecibidoCarpeta> _recibidos = [];

  // PA SABER QUÉ TAB ESTÁ ACTIVO: 0=CSV, 1=Pedidos, 2=Recibidos, 3=Pendientes
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    // Inicializar todos los campos vacíos del CSV
    for (var campo in CAMPOS_ORDEN) {
      _valoresCampos[campo] = '';
    }
    // Los booleanos inician en false
    for (var campo in CAMPOS_BOOL) {
      _valoresCampos[campo] = 'false';
    }
    _cargarDatosCarpetas(); // NUEVO: Cargar pedidos/recibidos guardados
  }

  // ========== NUEVO: PERSISTENCIA LOCAL ==========
  Future<void> _cargarDatosCarpetas() async {
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
      print('Error cargando datos: $e');
    }
  }

  Future<void> _guardarDatosCarpetas() async {
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

  // HELPERS PA FECHA CON LETRA
  String _numeroALetras(int numero) {
    const unidades = ['', 'uno', 'dos', 'tres', 'cuatro', 'cinco', 'seis', 'siete', 'ocho', 'nueve'];
    const diezVeinte = ['diez', 'once', 'doce', 'trece', 'catorce', 'quince', 'dieciséis', 'diecisiete', 'dieciocho', 'diecinueve'];
    const decenas = ['', '', 'veinte', 'treinta'];

    if (numero < 10) return unidades[numero];
    if (numero < 20) return diezVeinte[numero - 10];
    if (numero == 20) return 'veinte';
    if (numero < 30) return 'veinti${unidades[numero - 20]}';
    if (numero == 30) return 'treinta';
    if (numero == 31) return 'treinta y uno';
    return numero.toString();
  }

  String _mesALetras(int mes) {
    const meses = [
      '', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    return meses[mes];
  }

  Future<void> _abrirDatePicker(String campo, StateSetter setModalState) async {
    final ahora = DateTime.now();
    final fecha = await showDatePicker(
      context: context,
      initialDate: ahora,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.red,
              surface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (fecha!= null) {
      final diaNum = fecha.day.toString().padLeft(2, '0');
      final diaLetra = _numeroALetras(fecha.day);
      final mesLetra = _mesALetras(fecha.month);
      final fechaFormateada = '$diaNum $diaLetra de $mesLetra';

      setModalState(() {
        _valoresCampos[campo] = fechaFormateada;
      });
      setState(() {});
      Navigator.pop(context);
      _snack('Campo $campo = $fechaFormateada');
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

    // NUEVO: Si estamos en tab de Pedidos o Recibidos, abre flujo especial
    if (_tabIndex == 1) {
      _mostrarDialogoPedido(textoSeleccionado);
    } else if (_tabIndex == 2) {
      _procesarRecibido(textoSeleccionado);
    } else {
      _mostrarBottomSheetCampos(textoSeleccionado);
    }
  }

  // ========== NUEVO: FLUJO PEDIDOS ==========
  void _mostrarDialogoPedido(String carpetaPreseleccionada) {
    if (carpetaPreseleccionada.isEmpty) {
      _snack('Selecciona el número de carpeta primero');
      return;
    }

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
                Text('CARPETA: $carpetaPreseleccionada', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
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
                    carpeta: carpetaPreseleccionada,
                    folio: ctrlFolio.text.trim(),
                    volante: ctrlVolante.text.trim(),
                    destino: destinoSeleccionado,
                    fechaPedido: DateTime.now().toString().substring(0, 16),
                  ));
                });
                _guardarDatosCarpetas();
                Navigator.pop(context);
                _snack('Pedido guardado: $carpetaPreseleccionada');
              },
              child: const Text('GUARDAR', style: TextStyle(color: Colors.green)),
            ),
          ],
        ),
      ),
    );
  }



    // ========== NUEVO: FLUJO RECIBIDOS ==========
  void _procesarRecibido(String carpetaSeleccionada) {
    if (carpetaSeleccionada.isEmpty) {
      _snack('Selecciona el número de carpeta primero');
      return;
    }

    final pedido = _pedidos.firstWhere(
      (p) => p.carpeta.trim().toLowerCase() == carpetaSeleccionada.trim().toLowerCase(),
      orElse: () => PedidoCarpeta(carpeta: '', folio: '', volante: '', destino: '', fechaPedido: ''),
    );

    if (pedido.carpeta.isEmpty) {
      _snack('No esta no la pediste');
      return;
    }

    // Si ya está recibida, avisar
    final yaRecibida = _recibidos.any((r) => r.carpeta.trim().toLowerCase() == carpetaSeleccionada.trim().toLowerCase());
    if (yaRecibida) {
      _snack('Esta carpeta ya fue recibida');
      return;
    }

    // Prellenar y guardar en recibidos
    setState(() {
      _recibidos.add(RecibidoCarpeta(
        carpeta: pedido.carpeta,
        folio: pedido.folio,
        volante: pedido.volante,
        fechaRecibido: DateTime.now().toString().substring(0, 16),
      ));
    });
    _guardarDatosCarpetas();
    _snack('Recibida: ${pedido.carpeta} | Folio: ${pedido.folio}');
  }

  // ========== NUEVO: LISTA DE PENDIENTES ==========
  List<PedidoCarpeta> _getPendientes() {
    return _pedidos.where((p) =>
     !_recibidos.any((r) => r.carpeta.trim().toLowerCase() == p.carpeta.trim().toLowerCase())
    ).toList();
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
                    final esFecha = campo == 'FECHA' || campo == 'RECEPCION';

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
                          if (esFecha)
                            const Icon(Icons.calendar_month, color: Colors.red, size: 20),
                        ],
                      ),
                      onTap: esBool? null : () {
                        if (esFecha) {
                          _abrirDatePicker(campo, setModalState);
                          return;
                        }
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

  // ========== NUEVO: WIDGET PA CADA TAB ==========
  Widget _buildTabContent() {
    switch (_tabIndex) {
      case 1: // PEDIDOS
        return _buildListaPedidos();
      case 2: // RECIBIDOS
        return _buildListaRecibidos();
      case 3: // PENDIENTES
        return _buildListaPendientes();
      default: // CSV ORIGINAL
        return _buildTabCSV();
    }
  }

  Widget _buildTabCSV() {
    return Column(
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
        Text(
          'Campos llenos: ${_valoresCampos.values.where((v) => v.isNotEmpty && v!= 'false').length}/${CAMPOS_ORDEN.length}',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildListaPedidos() {
    return _pedidos.isEmpty
     ? const Center(child: Text('Sin pedidos aún\nEscanea y selecciona carpeta + botón PEDIDOS',
          style: TextStyle(color: Colors.white38), textAlign: TextAlign.center))
      : ListView.builder(
          itemCount: _pedidos.length,
          itemBuilder: (context, i) {
            final p = _pedidos[i];
            return Card(
              color: Colors.grey[900],
              child: ListTile(
                title: Text('CARPETA: ${p.carpeta}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                subtitle: Text('Folio: ${p.folio}\nVolante: ${p.volante}\nDestino: ${p.destino}\n${p.fechaPedido}',
                  style: const TextStyle(color: Colors.white70)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    setState(() => _pedidos.removeAt(i));
                    _guardarDatosCarpetas();
                  },
                ),
              ),
            );
          },
        );
  }

  Widget _buildListaRecibidos() {
    return _recibidos.isEmpty
     ? const Center(child: Text('Sin recibidos aún\nEscanea carpeta pedida + botón RECIBIDOS',
          style: TextStyle(color: Colors.white38), textAlign: TextAlign.center))
      : ListView.builder(
          itemCount: _recibidos.length,
          itemBuilder: (context, i) {
            final r = _recibidos[i];
            return Card(
              color: Colors.grey[900],
              child: ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: Text('CARPETA: ${r.carpeta}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text('Folio: ${r.folio}\nVolante: ${r.volante}\nRecibido: ${r.fechaRecibido}',
                  style: const TextStyle(color: Colors.white70)),
              ),
            );
          },
        );
  }

  Widget _buildListaPendientes() {
    final pendientes = _getPendientes();
    return pendientes.isEmpty
     ? const Center(child: Text('No hay pendientes\nTodo recibido 👍',
          style: TextStyle(color: Colors.green), textAlign: TextAlign.center))
      : ListView.builder(
          itemCount: pendientes.length,
          itemBuilder: (context, i) {
            final p = pendientes[i];
            return Card(
              color: Colors.grey[900],
              child: ListTile(
                leading: const Icon(Icons.pending, color: Colors.orange),
                title: Text('CARPETA: ${p.carpeta}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                subtitle: Text('Folio: ${p.folio}\nVolante: ${p.volante}\nDestino: ${p.destino}\nPedido: ${p.fechaPedido}',
                  style: const TextStyle(color: Colors.white70)),
              ),
            );
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.red[900],
        title: const Text(
          'Adry CSV',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          // SOLO EN TAB CSV MOSTRAMOS SHOW Y +
          if (_tabIndex == 0)...[
            TextButton(
              onPressed: _verCampos,
              child: const Text('SHOW', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white, size: 28),
              onPressed: _abrirMenuCampos,
              tooltip: 'Asignar a campo',
            ),
          ],
          IconButton(
            icon: const Icon(Icons.camera_alt, color: Colors.white, size: 28),
            onPressed: _abrirCamara,
          ),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ========== NUEVO: MENU DE TABS ==========
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  _buildTabButton('CSV', 0),
                  _buildTabButton('PEDIDOS', 1),
                  _buildTabButton('RECIBIDOS', 2),
                  _buildTabButton('PENDIENTES', 3),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // TEXTO DE AYUDA SEGÚN TAB
            if (_tabIndex == 1)
              const Text('Selecciona número de carpeta en el texto y pica +',
                style: TextStyle(color: Colors.yellow, fontSize: 12)),
            if (_tabIndex == 2)
              const Text('Selecciona número de carpeta pedida y pica +',
                style: TextStyle(color: Colors.yellow, fontSize: 12)),
            if (_tabIndex == 3)
              Text('Pendientes: ${_getPendientes().length}',
                style: const TextStyle(color: Colors.orange, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(child: _buildTabContent()),
          ],
        ),
      ),
      // ========== NUEVO: BOTÓN + FLOTANTE PA PEDIDOS/RECIBIDOS ==========
      floatingActionButton: _tabIndex == 1 || _tabIndex == 2
       ? FloatingActionButton(
            backgroundColor: Colors.red[900],
            onPressed: _abrirMenuCampos,
            child: const Icon(Icons.add, color: Colors.white),
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
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}


// PÁGINA SHOW - VER TODOS LOS CAMPOS + GUARDAR (SIN CAMBIOS)
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
    final ctrlNombre = TextEditingController();

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

    if (nombreArchivo == null || nombreArchivo.isEmpty) {
      _snack('Debes poner un nombre');
      return;
    }

    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.request().isDenied) {
        _snack('Ocupas dar permiso en Ajustes');
        await openAppSettings();
        return;
      }
    }

    final valoresOrdenados = CAMPOS_ORDEN.map((campo) {
      final valor = _valoresTemp[campo]?? '';
      return '"${valor.replaceAll('"', '""')}"';
    }).toList();

    final lineaExcel = valoresOrdenados.join(',');

    Directory? dir;
    if (Platform.isAndroid) {
      dir = Directory('/storage/emulated/0/Download');
    } else {
      dir = await getApplicationDocumentsDirectory();
    }

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

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
        title: const Text('CAMPOS ADRY CSV'),
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

// PANTALLA DE CÁMARA + OCR - SOLO EXTRAE TEXTO (SIN CAMBIOS)
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







