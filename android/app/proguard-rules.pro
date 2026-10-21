# google_mlkit_text_recognition: el plugin referencia los reconocedores de
# chino, japonés, coreano y devanagari, pero SafeLabel solo usa el latino
# (TextRecognitionScript.latin). Esas dependencias no están en el APK, así que
# R8 las reporta como "Missing class". Se le indica que no advierta por ellas.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Conservar las clases del OCR latino y de ML Kit que se usan vía reflexión.
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }
