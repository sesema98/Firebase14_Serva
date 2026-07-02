# DocenteHub

Proyecto iOS con SwiftUI que cumple la práctica **App de Docentes con horario por IA**:

- Google Sign-In con Firebase Authentication.
- Colección `teachers` en Cloud Firestore.
- Consultas `WHERE` por departamento y `ORDER BY + LIMIT` para docentes recientes.
- Consulta de horario por IA usando `POST /api/chat/completions` contra OpenWebUI/Gemma.
- Dos conclusiones visibles dentro de la app.

## Requisitos para ejecutar

- Colocar `GoogleService-Info.plist` dentro de `Lab14IntroFirebaseServa/`.
- Si cambias el bundle identifier al solicitado por el documento, descarga un `GoogleService-Info.plist` que coincida con ese nuevo bundle ID.
- En la app, abrir **Configurar IA** y registrar:
  - La IP o URL base del servidor OpenWebUI/Gemma.
  - La API key.
  - El modelo preferido solo si quieres forzarlo; por defecto la app arranca con `Tecsup/schedule`.

## Flujo cubierto

1. Iniciar sesión con Google.
2. Registrar docentes o cargar data demo.
3. Consultar docentes por departamento o ver los más recientes.
4. Abrir un docente y preguntar su horario en lenguaje natural.

## Seguridad

- La API key de la IA no está hardcodeada en el repositorio.
- La app guarda la API key en Keychain para evitar exponerla en código fuente o Git.

## Conclusiones

1. Al registrar y filtrar docentes en Firestore me di cuenta de que conviene guardar ahi la informacion estructurada, porque asi las consultas por carrera y los listados recientes responden rapido y sin depender de la IA.
2. Al conectar el chat con el modelo para preguntar por horarios note que la experiencia mejora bastante cuando la base de datos y la IA tienen roles separados: Firestore organiza los docentes y la IA resuelve preguntas en lenguaje natural de forma mas practica para el usuario.
