/// Términos y Condiciones de Uso de SafeLabel.
///
/// Si se modifica el texto, hay que subir [TerminosCondiciones.version]: cada
/// cuenta guarda la versión que aceptó.
class TerminosCondiciones {
  TerminosCondiciones._();

  static const String titulo = 'Términos y Condiciones de Uso';
  static const String version = '1.2';
  static const String vigenteDesde = '1 de noviembre de 2026';

  static const String emailLegales = 'legales@safelabel.com.ar';
  static const String emailPrivacidad = 'privacidad@safelabel.com.ar';

  static const List<SeccionTerminos> secciones = [
    SeccionTerminos(
      '1. Objeto y aceptación',
      'Los presentes Términos y Condiciones de Uso (en adelante, los '
          '"Términos") regulan el acceso y la utilización de la aplicación '
          'SafeLabel (en adelante, la "Aplicación") por parte de toda persona '
          'que se registre en ella (en adelante, el "Usuario").\n\n'
          'La creación de una cuenta y la marcación de la casilla de '
          'aceptación implican que el Usuario ha leído, comprendido y aceptado '
          'en forma plena e incondicional la totalidad de estos Términos. El '
          'Usuario que no esté de acuerdo con ellos deberá abstenerse de '
          'registrarse y de utilizar la Aplicación.',
    ),
    SeccionTerminos(
      '2. Descripción del servicio',
      'SafeLabel es una aplicación que, mediante el reconocimiento del texto '
          'impreso en la etiqueta de un alimento, identifica los ingredientes '
          'que podrían resultar incompatibles con las restricciones '
          'alimentarias declaradas por el Usuario en sus perfiles, e informa '
          'el motivo de cada señalamiento. Adicionalmente, y solo cuando el '
          'Usuario lo solicite, la Aplicación puede sugerir productos o '
          'ingredientes alternativos.',
    ),
    SeccionTerminos(
      '3. Carácter informativo. La Aplicación no reemplaza el consejo médico',
      'La información brindada por SafeLabel tiene carácter exclusivamente '
          'informativo y orientativo. SafeLabel no es un dispositivo médico, '
          'no formula diagnósticos, no indica tratamientos y no reemplaza en '
          'ningún caso el consejo, el diagnóstico ni las indicaciones de un '
          'médico, nutricionista u otro profesional de la salud '
          'debidamente matriculado.\n\n'
          'La Aplicación no califica a ningún alimento como "apto" o "seguro" '
          'para el Usuario. La información que brinda tampoco sustituye la '
          'lectura del rótulo oficial del producto, que el Usuario deberá '
          'consultar siempre antes de su consumo. Ante cualquier duda '
          'vinculada con su salud, y en particular ante alergias o '
          'intolerancias que puedan provocar reacciones graves, el Usuario '
          'deberá consultar a un profesional de la salud.',
    ),
    SeccionTerminos(
      '4. Registro y cuenta del Usuario',
      'Para utilizar la Aplicación es necesario crear una cuenta. Podrán '
          'registrarse las personas de trece (13) años de edad o más. Las '
          'personas menores de dieciocho (18) años deberán contar con la '
          'autorización de sus padres, tutores o representantes legales, '
          'quienes serán responsables del uso que aquellas hagan de la '
          'Aplicación.\n\n'
          'El Usuario se obliga a proporcionar información veraz, exacta y '
          'actualizada, y a mantenerla actualizada. La cuenta es personal e '
          'intransferible. El Usuario es el único responsable de la '
          'confidencialidad de su contraseña y de toda actividad que se '
          'realice con su cuenta, y deberá comunicar de inmediato a SafeLabel '
          'cualquier uso no autorizado del que tome conocimiento.',
    ),
    SeccionTerminos(
      '5. Obligaciones del Usuario',
      'El Usuario se compromete a utilizar la Aplicación de conformidad con '
          'la ley, estos Términos, la moral y las buenas costumbres. En '
          'particular, se obliga a no: (a) utilizar la Aplicación con fines '
          'ilícitos o que puedan perjudicar a SafeLabel o a terceros; '
          '(b) copiar, modificar, descompilar o realizar ingeniería inversa '
          'sobre la Aplicación; (c) intentar acceder sin autorización a '
          'cuentas de otros Usuarios; y (d) mantener desactualizadas las '
          'restricciones alimentarias de sus perfiles cuando estas hayan '
          'cambiado.',
    ),
    SeccionTerminos(
      '6. Protección de los datos personales',
      'Datos recabados. Al registrarse, el Usuario proporciona su nombre, '
          'apellido, dirección de correo electrónico, fecha de nacimiento y '
          'contraseña. Las contraseñas se almacenan cifradas y no '
          'resultan legibles para SafeLabel ni para terceros.\n\n'
          'Datos sensibles. Las restricciones alimentarias que el Usuario '
          'declara en sus perfiles pueden revelar información relativa a su '
          'salud, que la Ley N° 25.326 de Protección de los Datos Personales '
          'califica como dato sensible. El Usuario no está obligado a '
          'proporcionarla. Al cargarla, presta su consentimiento libre, '
          'expreso e informado para su tratamiento con la única finalidad de '
          'prestar el servicio descripto en la cláusula 2.\n\n'
          'Finalidad y cesión. Los datos se utilizan exclusivamente para '
          'identificar la cuenta del Usuario y personalizar el servicio. '
          'SafeLabel no vende, no alquila ni cede los datos personales del '
          'Usuario a terceros.\n\n'
          'Servicios de terceros. Cuando el Usuario solicita sugerencias de '
          'alternativas, la Aplicación envía al proveedor de inteligencia '
          'artificial Google Gemini únicamente la lista de ingredientes y los '
          'grupos de alérgenos involucrados, sin incluir datos personales del '
          'Usuario ni imágenes. Dicho proveedor trata esa información conforme '
          'a sus propias condiciones, que pueden incluir su utilización para '
          'mejorar sus servicios.\n\n'
          'Derechos del titular. El Usuario puede ejercer en cualquier momento '
          'sus derechos de acceso, rectificación, actualización y supresión de '
          'sus datos personales, conforme a la Ley N° 25.326, desde la sección '
          '"Mi cuenta" de la Aplicación o escribiendo a $emailPrivacidad. El '
          'titular de los datos personales tiene la facultad de ejercer el '
          'derecho de acceso a ellos en forma gratuita a intervalos no '
          'inferiores a seis meses, salvo que se acredite un interés legítimo '
          'al efecto, conforme a lo establecido en el artículo 14, inciso 3, '
          'de la Ley N° 25.326. La Agencia de Acceso a la Información Pública, '
          'en su carácter de Órgano de Control de la Ley N° 25.326, tiene la '
          'atribución de atender las denuncias y reclamos que interpongan '
          'quienes resulten afectados en sus derechos por incumplimiento de '
          'las normas vigentes en materia de protección de datos personales.',
    ),
    SeccionTerminos(
      '7. Propiedad intelectual',
      'La Aplicación, su código, diseño, marcas, logotipos y contenidos son '
          'propiedad de SafeLabel o de sus licenciantes y se encuentran '
          'protegidos por la legislación de propiedad intelectual vigente. '
          'Estos Términos no otorgan al Usuario derecho alguno sobre ellos, más '
          'allá de la licencia de uso personal, no exclusiva e intransferible '
          'necesaria para utilizar la Aplicación.\n\n'
          'La base de ingredientes de la Aplicación se elabora, entre otras '
          'fuentes, a partir del Código Alimentario Argentino y de la '
          'taxonomía de Open Food Facts, utilizada bajo la licencia Open '
          'Database License (ODbL), cuyos términos se respetan.',
    ),
    SeccionTerminos(
      '8. Responsabilidad',
      'En la máxima medida permitida por la legislación aplicable, SafeLabel '
          'no será responsable por los daños y perjuicios que pudieran derivar '
          'de decisiones adoptadas por el Usuario sobre la base exclusiva de '
          'la información brindada por la Aplicación, sin haber consultado el '
          'rótulo oficial del producto o a un profesional de la salud, ni de '
          'un uso de la Aplicación contrario a estos Términos.\n\n'
          'Nada de lo dispuesto en estos Términos limita ni restringe los '
          'derechos que la Ley N° 24.240 de Defensa del Consumidor y demás '
          'normas aplicables reconocen al Usuario.',
    ),
    SeccionTerminos(
      '9. Suspensión y baja',
      'SafeLabel podrá suspender o dar de baja la cuenta del Usuario que '
          'incumpla estos Términos. El Usuario podrá dejar de utilizar la '
          'Aplicación en cualquier momento y solicitar la baja de su cuenta y '
          'la supresión de sus datos escribiendo a $emailPrivacidad.',
    ),
    SeccionTerminos(
      '10. Modificaciones',
      'SafeLabel podrá modificar estos Términos en cualquier momento. Las '
          'modificaciones se informarán al Usuario a través de la Aplicación, '
          'con indicación de la nueva versión y su fecha de vigencia. La '
          'continuidad en el uso de la Aplicación quedará sujeta a la '
          'aceptación de la versión vigente.',
    ),
    SeccionTerminos(
      '11. Legislación aplicable y jurisdicción',
      'Estos Términos se rigen por las leyes de la República Argentina. '
          'Cualquier controversia derivada de su interpretación o cumplimiento '
          'será sometida a los tribunales competentes que correspondan '
          'conforme a la normativa de defensa del consumidor, incluido el '
          'domicilio del Usuario.',
    ),
    SeccionTerminos(
      '12. Contacto',
      'Las consultas relativas a estos Términos podrán dirigirse a '
          '$emailLegales. Las consultas y solicitudes vinculadas con datos '
          'personales podrán dirigirse a $emailPrivacidad.',
    ),
  ];
}

/// Una sección de los términos: título y texto.
class SeccionTerminos {
  const SeccionTerminos(this.titulo, this.texto);

  final String titulo;
  final String texto;
}
