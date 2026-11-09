import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Plataformas sin `dart:ffi` (web, al correr en Chrome): sqflite no tiene
/// implementación propia ahí, así que se usa `sqflite_common_ffi_web`, que
/// corre SQLite compilado a WebAssembly y guarda en IndexedDB del navegador.
/// Necesita `web/sqlite3.wasm` y `web/sqflite_sw.js`, generados con
/// `dart run sqflite_common_ffi_web:setup`. Ver `fabrica_bd.dart`.
///
/// Sin web worker: más simple y suficiente para probar la app en el navegador.
DatabaseFactory? fabricaBdPlataforma() => databaseFactoryFfiWebNoWebWorker;
