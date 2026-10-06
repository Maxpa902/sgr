import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const serverUrl = String.fromEnvironment(
  'SERVER_URL',
  defaultValue: 'http://10.0.2.2:8081',
);

void main() {
  runApp(const SgrApp());
}

class SgrApp extends StatelessWidget {
  const SgrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SGR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF176B5B)),
        useMaterial3: true,
      ),
      home: const WelcomePage(),
    );
  }
}

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  String _status = 'Todavía no se consultó el servidor.';
  bool _loading = false;
  bool? _serverOnline;

  Future<void> _checkServer() async {
    setState(() {
      _loading = true;
      _status = 'Consultando $serverUrl/api/status…';
      _serverOnline = null;
    });

    try {
      final response = await http
          .get(Uri.parse('$serverUrl/api/status'))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        throw Exception('El servidor respondió con HTTP ${response.statusCode}.');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      setState(() {
        _serverOnline = true;
        _status = body['message'] as String? ?? 'Servidor disponible.';
      });
    } catch (error) {
      setState(() {
        _serverOnline = false;
        _status = 'No se pudo conectar. Revisá que Laravel esté iniciado y la URL sea correcta.\n$error';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = switch (_serverOnline) {
      true => Colors.green.shade700,
      false => Colors.red.shade700,
      null => Theme.of(context).colorScheme.onSurfaceVariant,
    };

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.location_city, size: 64),
                  const SizedBox(height: 20),
                  Text(
                    'Bienvenido a SGR',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sistema de gestión de reclamos',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: _loading ? null : _checkServer,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_tethering),
                    label: Text(_loading ? 'Consultando…' : 'Leer estado del servidor'),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _serverOnline == true
                                ? Icons.check_circle
                                : _serverOnline == false
                                    ? Icons.error
                                    : Icons.info_outline,
                            color: color,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _status,
                              style: TextStyle(color: color),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
