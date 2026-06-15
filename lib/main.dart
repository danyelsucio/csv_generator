import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

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
      home: const PantallaNegra(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// PANTALLA 1: NEGRA CON FRANJA ROJA Y BOTÓN
class PantallaNegra extends StatefulWidget {
  const PantallaNegra({super.key});
  @override
  State<PantallaNegra> createState() => _PantallaNegraState();
}

class _PantallaNegraState extends State<PantallaNegra> {
  String textoEscaneado = "";

  void _abrirCamara() async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PantallaCamara()),
    );
    if (resultado!= null) {
      setState(() => textoEscaneado = resultado);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50), // Franja roja delgada
        child: AppBar(
          backgroundColor: const Color(0xFFB71C1C),
          automaticallyImplyLeading: false,
          title: const Text(''),
          actions: [
            IconButton(
              icon: const Icon(Icons.camera_alt, color: Colors.white, size: 28),
              onPressed: _abrirCamara,
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
      body: textoEscaneado.isEmpty
         ? Container(color: Colors.black) // Todo negro si no hay texto
          : Container(
              color: Colors.black,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TEXTO:', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => setState(() => textoEscaneado = ""),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.red),
                  Expanded(
                    child: SingleChildScrollView(
                      child: SelectableText(
                        textoEscaneado,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// PANTALLA 2: SOLO CÁMARA PA' SACAR FOTO
class PantallaCamara extends StatefulWidget {
  const PantallaCamara({super.key});
  @override
  State<PantallaCamara> createState() => _PantallaCamaraState();
}

class _PantallaCamaraState extends State<PantallaCamara> {
  CameraController? _controller;
  final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  bool isBusy = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    _controller = CameraController(cameras[0], ResolutionPreset.high);
    await _controller!.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _tomarFotoYRegresar() async {
    if (_controller == null || isBusy) return;
    setState(() => isBusy = true);
    try {
      final foto = await _controller!.takePicture();
      final inputImage = InputImage.fromFilePath(foto.path);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      String texto = recognizedText.text.isEmpty? "No se detectó texto" : recognizedText.text;
      if (mounted) Navigator.pop(context, texto); // Regresa el texto a la pantalla negra
    } catch (e) {
      if (mounted) Navigator.pop(context, "Error: $e");
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null ||!_controller!.value.isInitialized) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFFB71C1C),
        title: const Text('Sacar Foto', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: CameraPreview(_controller!),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red,
        onPressed: isBusy? null : _tomarFotoYRegresar,
        child: isBusy
           ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(Icons.camera, color: Colors.white),
      ),
    );
  }
}
