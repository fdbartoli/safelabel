# Integración del análisis con SQLite

Esta iteración cambia el origen del matching y del análisis de ingredientes a
`assets/knowledge/safelabel.sqlite`.

Se mantienen temporalmente `BaseConocimiento` y `ingredientes.json` para:

- catálogo y validación de perfiles todavía no migrados;
- lectura de la línea `CONTIENE / PUEDE CONTENER`;
- excepciones normativas aún ausentes de SQLite;
- sugerencias de reemplazos.

La equivalencia temporal de identificadores está centralizada en
`lib/conocimiento/ids_restricciones.dart`.

## Verificación

```bash
dart format .
flutter analyze
flutter test
flutter run -d linux
```

Pruebas manuales sugeridas:

- `caseinato de sodio` con un perfil que restrinja leche;
- `trigo` con el perfil celíaco;
- un término desconocido;
- verificar que el resultado muestre la versión `0.8.1` de la SQLite.
