# CLD-tools

Una herramienta basada en Perl para extraer, inspeccionar y modificar archivos CLD (Coffin Language Data) utilizados por *The Coffin of Andy and Leyley (TCOAAL)*.

CLD-tools permite a los usuarios desempaquetar y examinar los archivos de traducción de usuario oficialmente compatibles con el juego. Puede extraer imágenes, fuentes y datos de traducción integrados, e incluye una herramienta de reempaquetado para aplicar modificaciones a los archivos CLD.

## Características

- **Extracción de CLD:** Lee archivos CLD y extrae los datos que contienen.
- **Extracción de imágenes:** Decodifica y extrae datos de imágenes codificados en Base64.
- **Extracción de fuentes:** Extrae las fuentes integradas y utiliza el nombre de la fuente especificado como nombre del archivo de salida.
- **Exportación CSV:** Exporta datos de traducción y otros datos a archivos CSV con codificación UTF-8, conservando las claves jerárquicas.
- **Reempaquetado de CLD:** Aplica modificaciones a los datos de traducción, imágenes y fuentes.

## Acerca del reempaquetador

CLD-tools incluye una herramienta de reempaquetado independiente que permite a los usuarios modificar los datos CLD extraídos y reconstruirlos en un archivo CLD.

El reempaquetador se desarrolló para permitir reconstruir datos de traducción y recursos modificados sin depender de la herramienta de compilación oficial.

El reempaquetador está pensado como una solución temporal mientras se trabaja para conseguir la compatibilidad con la herramienta de compilación oficial.

Una vez establecida la compatibilidad con la herramienta oficial, el reempaquetador independiente dejará de mantenerse y se eliminará del proyecto.

## Requisitos

- Perl 5
- JSON::PP
- MIME::Base64
- Encode
- Text::CSV
- File::Path
- File::Basename
- File::Find

## Uso del extractor

    perl extract_cld.pl input.cld [output_folder]

Si no se especifica un directorio de salida, se utilizará el directorio de trabajo actual.

### Resultado de la extracción

    output_folder/
    ├── output.csv
    ├── font.ttf
    └── imgFiles/
        └── directory
            └──extracted images...

La estructura de salida real depende del contenido del archivo CLD de entrada.

## Uso del reempaquetador

    perl cld_repack.pl input.cld output.cld [output.csv] [image_folder] [font_file]

### Argumentos

| Argumento | Descripción | Valor predeterminado |
|---|---|---|
| input.cld | Archivo CLD original | Obligatorio |
| output.cld | Archivo CLD de salida | Obligatorio |
| output.csv | Archivo CSV modificado | output.csv |
| image_folder | Directorio que contiene las imágenes modificadas | ./img |
| font_file | Archivo de fuente que se aplicará | Sin cambios si se omite |

### Ejemplos

**Modificar los datos de traducción**

    perl cld_repack.pl original.cld modified.cld output.csv

**Modificar imágenes**

    perl cld_repack.pl original.cld modified.cld output.csv ./img

**Modificar fuentes**

    perl cld_repack.pl original.cld modified.cld output.csv ./img ./font.ttf

## Proceso de reempaquetado

- Los valores CSV se comparan utilizando las columnas section, key y value.
- Los archivos de imagen se codifican en Base64 y se aplican a sus entradas existentes correspondientes.
- Si no se especifica el directorio de imágenes, se utiliza ./img de forma predeterminada.
- Si el directorio de imágenes no existe, se omiten las modificaciones de imágenes y se conservan los datos originales.
- Si falta un archivo de imagen individual o no se encuentra su entrada correspondiente, se omite esa entrada y se conservan sus datos originales.
- Los archivos de fuentes se codifican en Base64 y se actualizan tanto fontFile como fontFace.
- Si no se especifica un archivo de fuente, se conservan los datos originales de la fuente.
- Las entradas CSV que falten o no puedan coincidir se omiten, conservando los datos originales.
- El archivo CLD original nunca se sobrescribe. Todos los cambios se guardan en el archivo de salida especificado.

**Nota:** El reempaquetador es experimental. Guarda siempre copias de seguridad de tus archivos originales.

## TODO

- [ ] Establecer compatibilidad con la herramienta de compilación oficial.
- [ ] Mejorar la estabilidad y compatibilidad del reempaquetador.
- [ ] Mejorar la gestión de errores y los mensajes de diagnóstico.
- [ ] Añadir compatibilidad con estructuras de datos CLD adicionales.
- [ ] Mejorar la facilidad de uso general.

## Contribuciones

¡Las contribuciones son bienvenidas!

Se agradecen las correcciones de errores, las mejoras de funcionalidades y cualquier otro tipo de contribución.

1. Haz un Fork de este repositorio.
2. Crea una nueva rama.
3. Realiza tus cambios y pruébalos.
4. Crea un Commit.
5. Envía un Pull Request.

Todos los Pull Requests se revisarán antes de ser integrados.

**Nota: Debido a compromisos personales y a una agenda bastante ocupada, es posible que no pueda revisar regularmente los Issues y Pull Requests. Por lo tanto, las respuestas y revisiones pueden tardar más de lo habitual. ¡Gracias por tu comprensión y paciencia!**

## Aviso legal

CLD-tools es un proyecto independiente y no está afiliado, respaldado ni cuenta con el apoyo oficial de los desarrolladores o distribuidores de TCOAAL.

Este software está destinado a la investigación personal y a los procesos legítimos de traducción por parte de los usuarios.

No utilices este software para plagiar, copiar o redistribuir contenido sin autorización, ni para infringir derechos de autor.

Todos los recursos del juego y los datos de traducción extraídos siguen siendo propiedad intelectual de sus respectivos titulares.

Los usuarios son los únicos responsables de garantizar que su uso cumpla con las leyes, licencias y condiciones de servicio aplicables en su jurisdicción.

En la medida permitida por la legislación aplicable, el autor no asume ninguna responsabilidad por daños, pérdida de datos o consecuencias legales derivadas del uso indebido del software.

Utiliza este software de manera responsable y bajo tu propia responsabilidad. Respeta siempre las leyes aplicables.

## Licencia

Este proyecto está publicado bajo la licencia GNU General Public License v3.0 (GPL-3.0).

Consulta el archivo LICENSE para ver el texto completo de la licencia.

---

CLD-tools — Inspeccionar, extraer y modificar Coffin Language Data.
