# Terreno por mapa de alturas — plan (generador v2)

Alcance de este incremento: colinas suaves con una altura por posición. Cráteres, guardado, streaming, biomas, cuevas y salientes quedan fuera.

## Implementación

- **Región:** 3 × 3 sectores de 22 m (−33 a 33 m), que cubre el bosque de 64 m y queda debajo de los límites. Una grilla global de 133 × 133 muestras cada 0,5 m; cada sector usa 45 × 45 (44 celdas).
- **Datos** (`world_generator.gd`, sin nodos): `description.terrain` guarda tamaño, origen y alturas en milímetros enteros (`heights_mm`). Enteros: comparación exacta y huella estable al serializar.
- **Relieve:** ruido de valor propio con hash entero (3 octavas de 30/14/7 m y 2,2/0,5/0,12 m de amplitud) y una subida suave de 1,5 m hacia los bordes. Flujo aleatorio propio (`seed ^ 0x7E44A1`); no consume los RNG de sendero, árboles, rocas ni sotobosque: la distribución x/z de todo lo existente queda idéntica. Se comprueba con huellas de la versión 1.
- **Zonas planas:** claro de práctica, claro del santuario y punto de aparición se nivelan a la altura de su centro, con transición suave de 10 m (6 m en el spawn). El claro de práctica es el nivel 0: blancos y pruebas de combate conservan sus alturas.
- **Materialización** (nuevo `scripts/terrain.gd`): por sector, una `ArrayMesh` y un `StaticBody3D` con `HeightMapShape3D` escalado uniformemente × 0,5 (alturas ÷ 0,5). Los sectores leen la misma grilla y calculan normales sobre ella: los bordes comparten vértices, alturas y normales exactas, sin grietas ni escalones.
- **Consulta** `Generator.height_at(desc, x, z)`: interpolación por triángulo con la misma diagonal que malla y colisión. Árboles, rocas y marcadores se apoyan en el punto más bajo de su huella (nunca flotan del lado de abajo); santuario, blancos y spawn usan la altura nivelada; el sotobosque, la altura exacta.
- **Límites:** muros por tramos de 6,5 m que cubren desde debajo del suelo hasta 4 m sobre el punto más alto del tramo.
- **Versión:** `generator_version` 1 → 2. Misma semilla y versión reproducen alturas; el layout x/z no cambia.

## Riesgos y mitigación

1. **Escala de la colisión:** si la física no respetara el escalado del `HeightMapShape3D`, la colisión no coincidiría con la malla. Test: raycasts contra `height_at` en toda la región y sobre los bordes. Alternativa: celdas de 1 m sin escala.
2. **Diagonal de los triángulos:** si difiere entre malla y física aparecen diferencias de milímetros a centímetros. El mismo test lo detecta.
3. **Pendientes:** el jugador sube hasta 45°. Objetivo: < 30° en el interior y < 25° sobre el sendero, medido por test. Las transiciones de los claros empinan su borde: con octavas de 26 m y transiciones de 8 m el sendero llegaba a 37° en algunas semillas.
4. **Objetos en pendiente:** el tronco se hunde del lado alto (hasta ~0,4 m); raíces y rocas pueden verse algo enterradas. Revisar a ojo.
5. **Determinismo entre plataformas:** hash entero y operaciones básicas en doble precisión; debería coincidir en Windows y Linux, pero solo se prueba en la nube. Verificar la huella en la PC.
6. **Costo:** unas 17.700 muestras en GDScript y 9 mallas/colisiones por generación. Se mide; si pasa de ~200 ms, optimizar antes de agregar streaming.
7. **Pruebas con alturas fijas:** las que usan spawn, bordes o troncos se adaptan a la altura real; las de combate siguen iguales gracias al nivel 0 del claro.
8. **Futuro:** alturas por sector permiten editar cráteres y reconstruir solo sectores afectados; no permiten cuevas ni salientes (requieren volumétrico).
