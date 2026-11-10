# CLD-tools

[English](README.md) | [Русский](README.ru.md) | [简体中文](README.zh.md) | [한국어](README.ko.md)

Una colección de herramientas en Perl para extraer, editar, reconstruir y comparar archivos CLD (Coffin Language Data) utilizados por *The Coffin of Andy and Leyley* (TCOAAL).

TCOAAL CLD Tools permite examinar y modificar los archivos de traducción de usuario del juego. Incluye herramientas para extraer diálogos, imágenes y fuentes, reconstruir archivos CLD y comparar los cambios entre archivos.

## Características

- **Extracción de CLD:** Extrae diálogos y recursos de archivos CLD.
- **Exportación CSV:** Exporta los datos de traducción a archivos CSV en UTF-8.
- **Compatibilidad con plantillas:** Utiliza el `dialogue.csv` original del juego como plantilla.
- **Extracción de imágenes:** Extrae las imágenes integradas.
- **Extracción de fuentes:** Extrae los archivos de fuentes integrados.
- **Reconstrucción de CLD:** Aplica cambios de traducción y recursos a los archivos CLD.
- **Comparación de CLD:** Compara dos archivos CLD y muestra sus diferencias.

## Requisitos

- Perl 5
- Text::CSV (necesario para `cld_extract.pl`)

Los demás módulos necesarios están incluidos en las distribuciones estándar de Perl.

## Uso del extractor

    perl cld_extract.pl [--template dialogue.csv] <input.cld> [output_folder]

Si no se especifica una carpeta de salida, se utiliza el directorio de trabajo actual.

### Uso de `--template`

Para utilizar la opción `--template`, primero debes generar manualmente el `dialogue.csv` original mediante el `translator.exe` del juego.

Después, pasa el CSV generado a `cld_extract.pl` mediante `--template`.

    perl cld_extract.pl --template dialogue.csv input.cld output_folder

Se conservan la estructura de la plantilla, el orden de las entradas, los nombres de los personajes y el texto en inglés. Los datos de traducción se rellenan según el ID.

### Resultado de la extracción

    output_folder/
    ├── dialogue.csv
    ├── img/
    └── font/

El contenido generado depende del archivo CLD de entrada.

Sin `--template`, el extractor genera un CSV básico con la columna de inglés vacía. Este formato también puede utilizarse con `cld_repack.pl`.

## Uso del repacker

    perl cld_repack.pl [options] <input.cld> <output.cld> [dialogue.csv] [image_folder] [font_file]

Las rutas de entrada y salida deben terminar en `.cld`. La ruta de salida debe ser distinta de la ruta de entrada.

### Argumentos

| Argumento | Descripción | Valor predeterminado |
|---|---|---|
| input.cld | Archivo CLD original | Obligatorio |
| output.cld | Archivo CLD de salida | Obligatorio |
| dialogue.csv | CSV con los datos de traducción | Sin cambios si se omite |
| image_folder | Carpeta con las imágenes PNG modificadas | `./img` |
| font_file | Archivo de fuente que se insertará | Sin cambios si se omite |

### Opciones

| Opción | Descripción |
|---|---|
| `--no-images` | Elimina todas las entradas de imágenes integradas. |
| `--no-font` | Elimina la fuente integrada y restablece el nombre de la fuente a `GameFont`. |
| `--font-face NAME` | Establece el nombre de la fuente. |

### Ejemplos

**Modificar los datos de traducción**

    perl cld_repack.pl original.cld modified.cld dialogue.csv

**Modificar imágenes**

    perl cld_repack.pl original.cld modified.cld dialogue.csv ./img

**Modificar fuentes**

    perl cld_repack.pl original.cld modified.cld dialogue.csv ./img ./font.ttf

**Eliminar imágenes integradas**

    perl cld_repack.pl --no-images original.cld modified.cld

**Eliminar la fuente integrada**

    perl cld_repack.pl --no-font original.cld modified.cld

### Notas sobre la reconstrucción

- Las celdas de traducción vacías conservan el texto original.
- Las entradas CSV se emparejan por ID.
- Las filas consecutivas con el mismo ID representan varias líneas.
- No se añaden ID nuevos al archivo CLD.
- Las entradas que faltan en el CSV conservan los datos originales.
- Solo se pueden reemplazar entradas de imágenes existentes.
- Las imágenes deben ser archivos PNG con una firma PNG válida.
- Si la carpeta `./img` no existe, se conservan las imágenes originales.
- Si no se especifica un archivo de fuente, se conserva la fuente original.
- Si se encuentra exactamente un archivo de fuente compatible en `./font`, se selecciona automáticamente.
- El archivo CLD original nunca se sobrescribe.

## Uso de la herramienta Diff

    perl cld_diff.pl <file_A.cld> <file_B.cld>

Compara dos archivos CLD y muestra:

- Entradas modificadas.
- Entradas que solo existen en el archivo A.
- Entradas que solo existen en el archivo B.

Se ignoran el orden de las claves de los objetos y los espacios en blanco del JSON. Se conserva el orden de los elementos de los arrays.

Los datos de imágenes y fuentes se resumen mediante su longitud codificada, sin mostrar su contenido completo.

Para realizar una comparación byte a byte, utiliza:

    cmp file_A.cld file_B.cld

En Windows:

    fc /b file_A.cld file_B.cld

## Contribuciones

¡Las contribuciones son bienvenidas!

1. Haz un Fork de este repositorio.
2. Crea una nueva rama.
3. Realiza los cambios y pruébalos.
4. Crea un Commit.
5. Envía un Pull Request.

Las respuestas a Issues y Pull Requests pueden demorarse debido a compromisos personales.

## Aviso legal

TCOAAL CLD Tools es un proyecto independiente y no está afiliado, respaldado ni apoyado oficialmente por los desarrolladores o distribuidores de *The Coffin of Andy and Leyley*.

Este software está destinado a la investigación personal y a los procesos de traducción de usuarios. Todos los recursos extraídos del juego y los datos de traducción siguen siendo propiedad intelectual de sus respectivos titulares.

Los usuarios son responsables de asegurarse de que su uso cumpla con las leyes y los acuerdos aplicables.

Utiliza estas herramientas de acuerdo con el acuerdo de usuario de la herramienta oficial de traducción.

## Licencia

Este proyecto está publicado bajo la licencia GNU General Public License v3.0 (GPL-3.0).

Consulta [LICENSE](LICENSE) para ver el texto completo de la licencia.

---

TCOAAL CLD Tools — Extraer, editar, reconstruir y comparar archivos CLD.
