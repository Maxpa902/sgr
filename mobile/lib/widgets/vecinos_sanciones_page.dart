import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import '../modelos/usuario.dart';
import '../sesion/sesion.dart';

class VecinosSancionesPage extends StatefulWidget {
  const VecinosSancionesPage({super.key, required this.sesion});

  final Sesion sesion;

  @override
  State<VecinosSancionesPage> createState() => _VecinosSancionesPageState();
}

class _VecinosSancionesPageState extends State<VecinosSancionesPage> {
  late Future<List<Usuario>> _futuroUsuarios;

  @override
  void initState() {
    super.initState();
    _cargarUsuarios();
  }

  void _cargarUsuarios() {
    // Asegúrate de tener este método en tu clase Sesion/Api
    _futuroUsuarios = widget.sesion.obtenerUsuariosConSancionesOrdenados();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Monitoreo de Sanciones')),
      body: FutureBuilder<List<Usuario>>(
        future: _futuroUsuarios,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: FCircularProgress());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error al cargar datos: ${snapshot.error}'),
              ),
            );
          }

          final usuarios = snapshot.data ?? [];
          // Filtramos solo los que tengan al menos 1 sanción activa o estén suspendidos
          final enRiesgo = usuarios
              .where((u) => u.sancionesActivas > 0 || u.estaSuspendido)
              .toList();

          if (enRiesgo.isEmpty) {
            return const Center(
              child: Text('No hay vecinos con reportes falsos o suspensiones.'),
            );
          }

          // Ordenar de mayor a menor cantidad de sanciones
          enRiesgo.sort((a, b) => b.sancionesActivas.compareTo(a.sancionesActivas));

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: enRiesgo.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final usuario = enRiesgo[index];
              final leFaltan = 3 - usuario.sancionesActivas;

              return FCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: usuario.estaSuspendido || usuario.sancionesActivas >= 3
                            ? Colors.red.shade100
                            : Colors.orange.shade100,
                        child: Text(
                          '${usuario.sancionesActivas}/3',
                          style: TextStyle(
                            color: usuario.sancionesActivas >= 3
                                ? Colors.red.shade900
                                : Colors.orange.shade900,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${usuario.nombre} ${usuario.apellido}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              usuario.email,
                              style: TextStyle(
                                color: context.theme.colors.mutedForeground,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              usuario.estaSuspendido
                                  ? 'Cuenta suspendida temporalmente'
                                  : 'Le faltan $leFaltan rechazos falsos para la suspensión',
                              style: TextStyle(
                                color: usuario.estaSuspendido
                                    ? Colors.red
                                    : Colors.orange.shade800,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
