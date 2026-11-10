# ZXing local para lectura de QR

`index.min.js` es el bundle UMD de `@zxing/library` **0.23.0**:
https://unpkg.com/@zxing/library@0.23.0/umd/index.min.js

Se conserva sin modificaciones y con su licencia Apache-2.0 (`LICENSE`).
`CamaraQr` configura `mobile_scanner` para cargar este lector desde el mismo
origen que SafeLabel. No usa el CDN ni envía imágenes fuera del dispositivo.

El recurso debe desplegarse junto con el resto de `build/web`. Para abrir una
aplicación web sin conexión también es necesario disponer de sus recursos
localmente; esto no implementa una PWA ni una sincronización.
