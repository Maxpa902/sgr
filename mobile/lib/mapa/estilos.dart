import 'package:flutter/material.dart';

/// Estados que el vecino puede ver en el mapa. Los rechazados no se muestran.
const estadosDelMapa = ['pendiente', 'en_proceso', 'resuelto'];

/// Estados que se muestran al abrir el mapa: los reclamos todavía abiertos.
const estadosPorDefecto = {'pendiente', 'en_proceso'};

Color colorDelEstado(String estado) => switch (estado) {
  'pendiente' => const Color(0xFFB45309),
  'en_proceso' => const Color(0xFF1D4ED8),
  'resuelto' => const Color(0xFF15803D),
  'rechazado' => const Color(0xFFB91C1C),
  _ => const Color(0xFF757575),
};

String nombreDelEstado(String estado) => switch (estado) {
  'pendiente' => 'Pendiente',
  'en_proceso' => 'En proceso',
  'resuelto' => 'Resuelto',
  'rechazado' => 'Rechazado',
  _ => estado,
};

/// Nombre del estado para los filtros, que hablan de varios reclamos.
String nombreDelFiltro(String estado) => switch (estado) {
  'pendiente' => 'Pendientes',
  'en_proceso' => 'En proceso',
  'resuelto' => 'Resueltos',
  _ => nombreDelEstado(estado),
};

/// El ícono de cada categoría, según la clave que manda el server.
IconData iconoDeCategoria(String? icono) => switch (icono) {
  'electricidad' => Icons.bolt,
  'alumbrado' => Icons.lightbulb,
  'agua' => Icons.water_drop,
  'cloacas' => Icons.plumbing,
  'telefonia' => Icons.wifi,
  'baches' => Icons.construction,
  'veredas' => Icons.directions_walk,
  'arbolado' => Icons.park,
  'residuos' => Icons.delete_outline,
  'transito' => Icons.traffic,
  'pluviales' => Icons.waves,
  'seguridad' => Icons.warning_amber_rounded,
  'espacios_verdes' => Icons.yard,
  'mobiliario' => Icons.chair_alt,
  _ => Icons.report_problem,
};
