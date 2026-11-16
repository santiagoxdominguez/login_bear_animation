import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart';
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // CONTROL PARA MOSTRAR/OCULTAR CONTRASEÑA
  bool _obscure = true;

  bool _rememberMe = false; // Estado del Checkbox
  bool _isAnimating = false; // Bandera Anti-Spam

  // CEREBRO DE LA ANIMACIÓN RIVE
  StateMachineController? _controller;
  SMIBool? _isChecking;
  SMIBool? _isHandsUp;
  SMITrigger? _trigSuccess;
  SMITrigger? _trigFail;
  SMINumber? _numLook;

  Timer? _typingDebounce;

  // FOCUS NODES
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  // CONTROLLERS
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  // ERRORES EN UI
  String? emailError;
  String? passError;

  // VALIDADORES
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
        setState(() {
          _isAnimating = false;
        });
      }
    }
  }

  // ACCIÓN DE LOGIN
  Future<void> _onLogin() async {
    if (_isAnimating) return;

    setState(() {
      _isAnimating = true;
    });

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
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: pass,
      );
      
      _trigSuccess?.fire();
      print("✅ Usuario logueado correctamente en Firebase");
      
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      });
      
    } on FirebaseAuthException catch (e) {
      _trigFail?.fire();
      print("❌ Error de autenticación: ${e.message}");
      
      setState(() {
        passError = "Credenciales incorrectas";
      });
    } finally {
      _liberarUI();
    }
  }

  void _liberarUI() {
    Timer(const Duration(milliseconds: 2500), () {
      if (mounted && _isAnimating) {
        setState(() {
          _isAnimating = false;
        });
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
      body: IgnorePointer(
        ignoring: _isAnimating,
        child: SingleChildScrollView(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  SizedBox(
                    width: size.width,
                    height: 200,
                    child: RiveAnimation.asset(
                      'assets/login_bear.riv',
                      stateMachines: const ['Login Machine'],
                      onInit: (artboard) {
                        _controller = StateMachineController.fromArtboard(
                          artboard,
                          'Login Machine',
                          onStateChange: _onRiveStateChange,
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
                  // CAMPO EMAIL
                  TextField(
                    controller: _emailCtrl,
                    focusNode: _emailFocus,
                    onChanged: (value) {
                      if (_isChecking == null) return;
                      _isChecking!.change(true);
                      final look = (value.length / 80.0 * 100.0).clamp(0.0, 100.0);
                      _numLook?.value = look;

                      _typingDebounce?.cancel();
                      _typingDebounce = Timer(const Duration(seconds: 3),(){
                        if (!mounted) return;
                        _isChecking?.change(false);
                      });
                    },
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      errorText: emailError,
                      hintText: 'Email',
                      prefixIcon: const Icon(Icons.email),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // CAMPO CONTRASEÑA
                  TextField(
                    controller: _passCtrl,
                    focusNode: _passwordFocus,
                    onChanged: (value) {
                      if (_isHandsUp == null) return;
                      _isHandsUp!.change(true);
                    },
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      errorText: passError,
                      hintText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscure = !_obscure;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // REMEMBER ME & FORGOT PASSWORD
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            activeColor: Colors.pinkAccent,
                            onChanged: (value) {
                              setState(() {
                                _rememberMe = value ?? false;
                              });
                            },
                          ),
                          const Text('Remember me'),
                        ],
                      ),
                      // FASE 4: Recuperación de contraseña funcional
                      TextButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              final resetCtrl = TextEditingController();
                              return AlertDialog(
                                title: const Text('Recuperar contraseña'),
                                content: TextField(
                                  controller: resetCtrl,
                                  decoration: const InputDecoration(hintText: 'Ingresa tu correo electrónico'),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancelar'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () async {
                                      try {
                                        await FirebaseAuth.instance.sendPasswordResetEmail(
                                          email: resetCtrl.text.trim(),
                                        );
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Correo de recuperación enviado. Revisa tu bandeja.')),
                                        );
                                      } catch (e) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Error: ${e.toString()}')),
                                        );
                                      }
                                    },
                                    child: const Text('Enviar'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        child: const Text(
                          'Forgot password?',
                          style: TextStyle(
                            color: Colors.black,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // BOTÓN LOGIN
                  MaterialButton(
                    minWidth: size.width,
                    height: 50,
                    color: _isAnimating ? Colors.grey : Colors.pinkAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onPressed: _isAnimating ? null : _onLogin,
                    child: _isAnimating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        )
                      : const Text('Login', style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(height: 10),
                  // BOTÓN SIGN UP
                  SizedBox(
                    width: size.width,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children:[
                        const Text("Don't have an account?"),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const SignUpScreen()),
                            );
                          },
                          child: const Text(
                            'Sign up',
                            style: TextStyle(
                              color: Colors.black,
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
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