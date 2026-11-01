# SafeLabel — Decisiones para la construcción de la base de conocimiento

## Objetivo

SafeLabel busca ayudar a interpretar listas de ingredientes según las restricciones alimentarias configuradas por el usuario.

Para hacerlo necesita una base de conocimiento que permita reconocer que distintas denominaciones pueden referirse a un mismo ingrediente o a uno de sus derivados. Por ejemplo, que el caseinato de sodio está relacionado con la leche.

Las siguientes decisiones establecen cómo se obtiene, controla y utiliza esa información.

## 1. Priorizar fuentes oficiales

La información debe obtenerse preferentemente de organismos gubernamentales, agencias regulatorias y organismos internacionales especializados en alimentos y salud.

Se utilizaron fuentes de ANMAT, normativa argentina, FDA y Health Canada.

**Justificación:** la información puede influir en decisiones sensibles. Las fuentes oficiales ofrecen mayor autoridad y estabilidad que contenidos comerciales o publicaciones informales.

Una fuente no oficial solo debería utilizarse cuando sea necesaria, pueda justificarse su confiabilidad y quede claramente identificada.

## 2. Mantener trazabilidad sobre la información

Cada relación incorporada debe conservar una referencia a la fuente y a la evidencia que la respalda.

Esto incluye el documento utilizado, su origen, una identificación de su contenido y el fragmento relevante.

**Justificación:** debe ser posible explicar por qué SafeLabel relaciona un término con una restricción, revisar la decisión y detectar cambios posteriores en la fuente.

## 3. Usar automatización para encontrar candidatos

La búsqueda manual sobre documentos extensos no resulta escalable. Por eso, el proceso utiliza herramientas que localizan términos conocidos y presentan el contexto en el que aparecen.

En el futuro también podría utilizarse IA para asistir la búsqueda, el crawling y el análisis inicial de nuevas fuentes.

**Justificación:** la automatización reduce el volumen de trabajo manual y permite procesar más fuentes, pero su resultado debe considerarse una propuesta y no una regla definitiva.

## 4. Exigir revisión humana antes de aceptar una relación

Ninguna coincidencia encontrada automáticamente debe incorporarse a la base consolidada sin revisión humana.

**Justificación:** la aparición de un término en un documento no demuestra por sí sola una relación. Puede tratarse de una excepción, una comparación o un contexto diferente del esperado.

La herramienta automatiza la búsqueda; la decisión sigue siendo responsabilidad de una persona.

## 5. Aplicar criterios comunes de aceptación

Una relación puede aceptarse cuando:

- La fuente vincula de manera explícita el ingrediente o compuesto con la restricción analizada.
- El contexto permite comprender la relación.
- La denominación corresponde al concepto identificado.
- No existe una excepción o condición que invalide la asociación.
- La fuente y la evidencia pueden rastrearse posteriormente.

La relación debe rechazarse si la evidencia contradice la asociación o corresponde a otro concepto. Debe dejarse pendiente cuando el contexto sea insuficiente o se necesite un análisis adicional.

**Justificación:** utilizar criterios compartidos hace que las decisiones sean consistentes y revisables, independientemente de quién realice la validación.

## 6. Separar conceptos de sus denominaciones

Un mismo ingrediente puede aparecer con distintos nombres y en diferentes idiomas. SafeLabel representa primero el concepto y luego asocia sus denominaciones.

Por ejemplo, `caseinato de sodio`, `sodium caseinate`, `caseinato de sódio` y `caséinate de sodium` representan el mismo concepto.

**Justificación:** la aplicación debe reconocer ingredientes aunque la etiqueta esté en otro idioma. No es necesario determinar previamente el idioma completo de la etiqueta; alcanza con poder relacionar cada denominación encontrada con un concepto conocido.

La equivalencia entre denominaciones también debe ser controlada y no incorporarse únicamente por una traducción automática.

## 7. Diferenciar el alimento de sus derivados

La base distingue entre una coincidencia directa con el alimento restringido y una coincidencia con un compuesto o derivado relacionado.

Por ejemplo:

- Leche: coincidencia directa.
- Caseína o lactosuero: conceptos relacionados con leche.

**Justificación:** esta distinción permite explicar qué se encontró sin presentar todos los términos como si fueran exactamente el mismo ingrediente.

## 8. Tomar la etiqueta física como referencia del producto

El análisis debe realizarse sobre la lista de ingredientes del envase que el usuario tiene en sus manos.

El código de barras puede utilizarse como atajo, pero no como fuente definitiva de la composición.

**Justificación:** un fabricante puede modificar la fórmula sin cambiar inmediatamente el código de barras. También pueden coexistir en el mercado unidades anteriores y nuevas del mismo producto.

## 9. Permitir el funcionamiento sin conectividad

El análisis principal debe poder realizarse sin depender de una conexión a internet.

**Justificación:** la aplicación puede utilizarse en comercios o lugares con conectividad limitada. Una falla de red no debería impedir consultar la información contenida en la etiqueta.

Esta decisión llevó a generar una base de conocimiento local para la aplicación.

## 10. Separar la construcción del conocimiento de su uso

El proceso completo tiene dos partes:

1. Obtener información, revisar evidencia y consolidar el conocimiento.
2. Distribuir a la aplicación solamente la información necesaria para analizar etiquetas.

**Justificación:** la aplicación no necesita incluir documentos originales ni herramientas de recolección y revisión. Solo necesita una versión reducida, controlada y preparada para consultas locales.

Por eso, la base SQLite es un producto generado por el proceso y no la fuente original del conocimiento.

## 11. Mantener fuera de la base los datos del usuario

La base distribuida contiene conocimiento común sobre ingredientes y restricciones. Los perfiles, preferencias e historial del usuario deben almacenarse de manera separada.

**Justificación:** permite actualizar o reemplazar la base de conocimiento sin afectar los datos personales y evita mezclar información común con información propia de cada instalación.

## 12. Avanzar de manera incremental

La primera iteración se limitó a leche y sus derivados. Una segunda iteración incorpora enfermedad celíaca para validar que el proceso pueda trabajar con varias restricciones sin mezclar sus conceptos ni sus revisiones.

Cada restricción declara explícitamente el subconjunto de conceptos y fuentes que debe analizarse. Luego, las relaciones aprobadas se consolidan en una única base para la aplicación.

**Justificación:** comenzar con un alcance reducido permitió comprobar la disponibilidad de fuentes, la calidad de la extracción y el esfuerzo de revisión. Separar los subconjuntos evita combinaciones sin sentido y permite ampliar la base de manera controlada.

## Flujo resultante

Las decisiones anteriores llevaron al siguiente proceso:

```text
Fuentes confiables
    → búsqueda automática de candidatos
    → revisión humana de la evidencia
    → consolidación de conceptos y denominaciones
    → generación de una base local
    → consulta sin conexión desde la aplicación
```

## Evolución posterior

Para el MVP, el proceso se implementó mediante scripts y archivos controlados. En una evolución posterior podrán incorporarse:

- Una base central para administrar el conocimiento.
- Un backend de revisión y versionado.
- Incorporación incremental de nuevas fuentes.
- Nuevas restricciones alimentarias.
- Asistencia mediante IA para búsqueda y extracción.
- Distribución versionada y verificación de integridad de la base local.

Estas capacidades fueron pospuestas para concentrar el trabajo inicial en validar la viabilidad y confiabilidad del proceso.
