import 'package:flutter/material.dart';
import 'package:rive/rive.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  bool _obscure = true;
  bool _isAnimating = false;

  StateMachineController? _controller;
  SMIBool? _isChecking;
  SMIBool? _isHandsUp;
  SMITrigger? _trigSuccess;
  SMITrigger? _trigFail;
  SMINumber? _numLook;
  Timer? _typingDebounce;

  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  String? emailError;
  String? passError;

  bool isValidEmail(String email) {
    final re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return re.hasMatch(email);
  }

  bool isValidPassword(String pass) {
    final re = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,}$');
    return re.hasMatch(pass);
  }

  void _onRiveStateChange(String stateMachineName, String stateName) {
    if (stateName.toLowerCase() == 'idle') {
      if (mounted && _isAnimating) {
        setState(() { _isAnimating = false; });
      }
    }
  }

  // LÓGICA DE REGISTRO EN FIREBASE
  Future<void> _onSignUp() async {
    if (_isAnimating) return;
    setState(() { _isAnimating = true; });

    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;

    final eError = isValidEmail(email) ? null : "Invalid email";
    final pError = isValidPassword(pass) ? null : "Invalid password";

    setState(() {
      emailError = eError;
      passError = pError;
    });

    FocusScope.of(context).unfocus(); 
    _typingDebounce?.cancel();
    _isChecking?.change(false);
    _isHandsUp?.change(false);
    _numLook?.value = 50.0;

    if (eError != null || pError != null) {
      _trigFail?.fire();
      _liberarUI(); 
      return;
    }

    try {
      // 1. CREAMOS EL USUARIO EN FIREBASE
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: pass,
      );
      
      // 2. Éxito: el osito celebra
      _trigSuccess?.fire();
      print("✅ Cuenta creada exitosamente");
      
      // 3. Navegar a la pantalla de Inicio después de 2 segundos
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      });
      
    } on FirebaseAuthException catch (e) {
      // Error: el osito llora
      _trigFail?.fire();
      setState(() {
        if (e.code == 'email-already-in-use') {
          emailError = "El correo ya está registrado";
        } else {
          passError = "Error al crear cuenta: ${e.message}";
        }
      });
    } finally {
      _liberarUI();
    }
  }

  void _liberarUI() {
    Timer(const Duration(milliseconds: 2500), () {
      if (mounted && _isAnimating) {
        setState(() { _isAnimating = false; });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener((){
      if (_emailFocus.hasFocus){
        if(_isHandsUp != null){
         _isHandsUp?.change(false);
         _numLook?.value = 50.0;
        }
      }
    });
    _passwordFocus.addListener((){
      _isHandsUp?.change(_passwordFocus.hasFocus);
    });
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    
    return Scaffold(
      // AppBar transparente con botón para regresar al Login
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: IgnorePointer(
        ignoring: _isAnimating,
        child: SingleChildScrollView(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const Text("Crear Cuenta Nueva", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  SizedBox(
                    width: size.width, height: 200,
                    child: RiveAnimation.asset(
                      'assets/login_bear.riv',
                      stateMachines: const ['Login Machine'],
                      onInit: (artboard) {
                        _controller = StateMachineController.fromArtboard(
                          artboard, 'Login Machine', onStateChange: _onRiveStateChange,
                        );
                        if (_controller == null) return;
                        artboard.addController(_controller!);
                        _isChecking = _controller!.findSMI('isChecking');
                        _isHandsUp = _controller!.findSMI('isHandsUp');
                        _trigSuccess = _controller!.findSMI('trigSuccess');
                        _trigFail = _controller!.findSMI('trigFail');
                        _numLook = _controller!.findSMI('numLook');
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _emailCtrl, focusNode: _emailFocus,
                    onChanged: (value) {
                      if (_isChecking == null) return;
                      _isChecking!.change(true);
                      _numLook?.value = (value.length / 80.0 * 100.0).clamp(0.0, 100.0);
                      _typingDebounce?.cancel();
                      _typingDebounce = Timer(const Duration(seconds: 3),(){
                        if (!mounted) return;
                        _isChecking?.change(false);
                      });
                    },
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      errorText: emailError, hintText: 'Email', prefixIcon: const Icon(Icons.email),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _passCtrl, focusNode: _passwordFocus,
                    onChanged: (value) {
                      if (_isHandsUp == null) return;
                      _isHandsUp!.change(true);
                    },
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      errorText: passError, hintText: 'Contraseña', prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                        onPressed: () { setState(() { _obscure = !_obscure; }); },
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 30),
                  MaterialButton(
                    minWidth: size.width, height: 50,
                    color: _isAnimating ? Colors.grey : Colors.pinkAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onPressed: _isAnimating ? null : _onSignUp,
                    child: _isAnimating
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Registrarse', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose(){
    _emailCtrl.dispose(); 
    _passCtrl.dispose(); 
    _emailFocus.dispose(); 
    _passwordFocus.dispose();
    _typingDebounce?.cancel(); 
    _controller?.dispose();
    super.dispose();
  }
}