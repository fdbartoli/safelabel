import 'package:sqflite/sqflite.dart';

/// Plataformas sin `dart:ffi` (web): no hay fábrica alternativa. Este archivo
/// existe para que el proyecto siga compilando ahí; ver `fabrica_bd.dart`.
DatabaseFactory? fabricaBdPlataforma() => null;
