# Decisiones de control y mundo — 0.2

## Control aprobado por el usuario

1. Mouse libre de Ctrl: orientar cámara y apuntar.
2. Mantener Ctrl: empezar un nuevo trazo y fijar yaw/pitch. WASD, carrera, salto y mundo siguen a tiempo real.
3. Soltar Ctrl: evaluar y preparar una única carga si la forma es válida; recuperar orientación del mouse sin salto acumulado.
4. Apuntar de nuevo y click izquierdo: disparar desde la posición y orientación actuales. Consumir carga y maná solo si el lanzamiento tiene éxito.
5. Click derecho o Q: cancelar el dibujo o descartar el hechizo preparado.

Preparación y lanzamiento son estados distintos. El jugador puede preparar mientras se recupera el cooldown, pero no eludirlo con el click. Si falta maná o sigue el cooldown, la carga se conserva. Cambiar hechizo, pausar, perder foco, volver al inicio o regenerar cancela la carga. Empezar otro gesto la reemplaza. No se acumulan cargas ni hay disparo automático al mantener el botón.

El mouse permanece capturado siempre durante juego; no se libera el cursor ni se lo transporta al volver. Se usa `screen_relative` para que el escalado de ventana no cambie la sensibilidad del input, y se desactiva la acumulación de eventos. [Referencia de Godot](https://docs.godotengine.org/en/4.4/classes/class_inputeventmousemotion.html).

El dibujo se muestra al costado para dejar visible la mira. Si el personaje se desplaza durante el gesto, la cámara también se desplaza con él: se conserva orientación, no un punto del mundo mediante autoapuntado.

## Precisión

Las plantillas iniciales son línea descendente y V de izquierda a derecha. Remuestreo uniforme de 32 puntos a lo largo del recorrido; normalización por origen y longitud, sin rotar la figura ni normalizar sus ejes por separado. Se compara el orden de puntos y el destino. Eso acepta diferentes tamaños y velocidades, manteniendo dirección y proporciones.

`q = clamp(1 - 4 * (0.8 * error_medio + 0.2 * error_final), 0, 1)`.

Se acepta `q >= 0.55`. La maestría utilizada para balance es `(q - 0.55) / 0.45`, limitada a [0,1]. Daño y costo se interpolan y redondean a centésimas para evitar vida residual por errores de coma flotante. Un gesto inválido no consume maná. La penalización inicial es perder el tiempo de ejecución; una penalización adicional de recursos queda para balance humano posterior.

| Hechizo | Gesto | Daño aceptado→perfecto | Maná aceptado→perfecto | Cooldown después del disparo |
|---|---|---|---|---|
| Aguja de Luz | ↓ | 18→36 | 16→10 | 0,28 s |
| Brasa Rúnica | V | 26→52 | 24→16 | 0,55 s |

El tiempo del trazo se registra para feedback, no se transforma en un bonus artificial. Practicar permite reducir tiempo real de preparación manteniendo calidad. El daño se fija en el proyectil al disparar y no cambia al seleccionar otra magia. Estos parámetros necesitan pruebas humanas de comodidad y dificultad; las capturas usan input automatizado.

Este evaluador es la primera matemática jugable del proyecto. No es todavía el evaluador de un problema de investigación distribuida, ni crea nuevas recetas de hechizos.

## Mundo natural, generación continua y destrucción

La preferencia confirmada es terreno con apariencia natural, sin construir con bloques, con posibilidad de destruir el entorno. Para incluir excavaciones, cuevas o perforaciones, propongo representar el terreno mediante un campo volumétrico de densidad y extraer una superficie suave.

Un mapa de alturas resulta útil para colinas, pero representa una sola altura por posición horizontal. La representación volumétrica permite huecos y voladizos. Sus celdas son datos internos: la superficie visible puede ser suave. Esta distinción está explicada en la [documentación de terrenos suaves de Voxel Tools](https://voxel-tools.readthedocs.io/en/latest/smooth_terrain/). No se instaló ni eligió esa extensión; se usa como referencia técnica. Antes de adoptarla habría que verificar compatibilidad con nuestro Godot y medir un prototipo.

### Sistemas necesarios

- **Generador espacial determinista:** seed, coordenadas del mundo y versión producen relieve, distribución de humedad/temperatura y materiales. El orden en que se visitan regiones no puede alterar el resultado.
- **Chunks:** sectores iniciales de 16–32 m, con una ventana acotada cargada alrededor del jugador. Priorizar superficie y colisión próximas antes de habilitar movimiento hacia un sector.
- **Superficie y colisión:** generar la malla visible y reconstruir la colisión solo donde cambia terreno. Los bordes necesitan muestras compartidas/margen y actualización de vecinos para evitar grietas.
- **Biomas y vegetación:** reglas por pendiente, altitud, humedad y suelo. Evitar árboles flotando, recursos inaccesibles y plantas sobre caminos. IDs estables para objetos independientemente de orden de carga.
- **Destrucción de objetos:** vida/material, retirada o fractura controlada, caída y escombros con límites. La versión actual solo retira árboles y rocas dañados; no simula fragmentación arbitraria.
- **Destrucción de terreno:** un impacto modifica densidad en un volumen acotado. Recalcular los chunks afectados, actualizar apoyos y tratar objetos que queden suspendidos. Eliminar material no equivale a simular derrumbe estructural; ese comportamiento requiere reglas adicionales.
- **Persistencia:** guardar seed y versión junto con cambios por sector: objetos destruidos y ediciones del terreno. Al cargar, reconstruir base y aplicar cambios; compactar el historial para evitar crecimiento ilimitado. Cambiar generador exige una estrategia para partidas anteriores.
- **Presupuesto de trabajo:** trabajos de generación de datos/mallas fuera del ciclo principal cuando sea viable, aplicación controlada al mundo, colisiones agrupadas y detalle reducido a distancia. Limitar tamaño/frecuencia de excavaciones para evitar pausas al lanzar magia.

### Secuencia recomendada

1. **Implementado ahora:** árboles y rocas destructibles en el bosque finito; registro en memoria.
2. **Próximo prototipo:** una región acotada, por ejemplo 3 × 3 sectores, con desniveles suaves. Un ataque produce un cráter; el jugador puede entrar y salir; destruir en una frontera no abre grietas.
3. **Persistencia de destrucción:** cerrar/abrir conserva el cráter y los árboles destruidos. Salir y volver a un sector también conserva sus cambios.
4. **Streaming:** cargar sectores al caminar con presupuesto de tiempo y memoria medido.
5. **Biomas, cuevas y destrucción más rica:** ampliar una vez que regeneración, física y guardado sean fiables.

El criterio de éxito de la siguiente etapa no será tamaño del mundo: será caminar sobre terreno con desnivel, romperlo, conservar el cambio y seguir con controles fluidos. El bosque actual continúa plano, limitado a 64 × 64 m. Suelo, santuario, límites y decoración todavía no se destruyen.

## Mejora visual de esta entrega

Biblioteca original de mallas compartidas para tres variantes de árboles ramificados, hojas, pasto y helechos; shaders procedurales de suelo/corteza/roca; vegetación por sectores con MultiMesh, viento y límites de distancia. El primer tramo tiene más sotobosque. Se conserva la distribución por seed del generador anterior.

Forward+ añade niebla volumétrica y SSAO. Compatibility conserva los assets y controles mediante Jugar-ligero.cmd. Ambas rutas se probaron en la GTX 1070. La referencia enviada por el usuario sigue siendo una dirección artística: faltan assets más trabajados, terreno irregular, animaciones y más iteraciones para acercarse a su acabado.
