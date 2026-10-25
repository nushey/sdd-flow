---
name: writing-agents
description: >
  Evalúa y corrige instrucciones para agentes en AGENTS.md, CLAUDE.md,
  SKILL.md, prompts y otros archivos Markdown. Usar al revisar, aclarar,
  simplificar, compactar o deduplicar estos textos, conservando su
  comportamiento. Evalúa primero y después aplica las correcciones.
  Para textos destinados a personas, usar writing-humans.
---

# Writing agents

Hacé que las instrucciones sean concisas, claras y ejecutables. Conservá lo
que el agente debe hacer, cuándo debe hacerlo y bajo qué restricciones.
Reducir palabras sirve solo si mantiene esa precisión.

## Evaluar

Leé la versión actual del texto completo y el contexto necesario para entender
sus referencias. Conservá el idioma de cada fragmento, incluidos los textos
mixtos; no traduzcas.

Inventariá cada directiva con su ubicación: acción, condición, alcance,
obligación o permiso, prohibición, excepción, valor predeterminado, secuencia
y formato de salida. Registrá la razón cuando el texto la dé. Si el pedido
abarca varios archivos, el inventario debe incluirlos a todos.

Identificá problemas concretos antes de editar:

| Problema | Qué comprobar |
|---|---|
| Repetición | Dos pasajes ordenan lo mismo con igual alcance y condiciones. |
| Fragmentación | Una regla, sus condiciones o sus excepciones están separadas. |
| Caso particular | Una regla general ya lo cubre; verificá si aporta un matiz antes de fusionarlo. |
| Ambigüedad | No queda claro quién actúa, sobre qué, cuándo o con qué resultado. |
| Terminología inconsistente | Varios nombres designan lo mismo o un nombre designa cosas diferentes. |
| Relleno | Hay preámbulos, énfasis o justificaciones que solo reformulan una directiva. |
| Contradicción | Dos instrucciones exigen comportamientos incompatibles bajo las mismas condiciones. |

La descripción del frontmatter, las plantillas que se copian literalmente y
los ejemplos que muestran cómo aplicar una regla pueden necesitar repetir
contenido. Evaluá su función antes de eliminarlos.

## Corregir

Aplicá las correcciones después de evaluar; el diagnóstico no reemplaza la
edición. Releé los archivos justo antes de modificarlos para trabajar sobre
su versión actual.

- Escribí instrucciones directas en imperativo. Conservá las prohibiciones
  cuando expresen el límite con más precisión.
- Reemplazá rodeos y referencias vagas por acciones y referentes explícitos
  cuando el propio texto permita establecerlos.
- Ubicá cada regla donde se necesita por primera vez; las reglas generales,
  en la sección común. Mantené condiciones y excepciones junto a su regla.
- Fusioná directivas equivalentes sin perder detalles. Agrupá instrucciones
  paralelas solo si comparten acción, alcance y condiciones.
- Definí los términos antes de usarlos y mantené sus nombres consistentes.
- Conservá una justificación si ayuda a aplicar una regla a casos no listados;
  eliminá las que solo la repiten.
- Usá títulos, listas, tablas o bloques de código según lo que deba consultar
  o copiar el agente. Conservá el frontmatter y la sintaxis de las plantillas.

Al deduplicar entre archivos, comprobá que el agente tenga acceso al lugar
donde queda la regla cuando la necesite. Moverla fuera de un archivo que se
carga de forma independiente puede cambiar el comportamiento.

No inventes directivas ni completes condiciones por intuición. Conservá los
pasajes ambiguos que no puedas aclarar con el texto y las instrucciones en
contradicción; pedí al usuario la decisión necesaria en el reporte.

## Verificar y entregar

Rehacé el inventario sobre el resultado y comparalo con el original. Cada
directiva debe seguir representada, sola o fusionada, con el mismo alcance,
condiciones, excepciones y fuerza. Comprobá también la secuencia, los formatos
de salida y las referencias. Restaurá cualquier detalle perdido y eliminá
directivas introducidas durante la edición.

Si recibiste archivos, dejá las correcciones en ellos y devolvé sus rutas.
Si recibiste texto en el chat, entregá la versión corregida.

Acompañá el resultado con un reporte breve: problemas encontrados y cambios
aplicados, resultado de la verificación y cantidad de palabras antes y después.
Si quedan ambigüedades o contradicciones, citá los pasajes y preguntá qué debe
regir. No vuelques el inventario completo en el reporte.
