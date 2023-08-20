#!/bin/bash
# De la base de datos entregada, se extraen la columna de longitud, latitud, bright_ti4 (medida en kelvin) y las fechas.
#El archivo con los datos se llama "datos.txt"
#También se descargaron datos de 5 estaciones meteorológicas de vientos.
#
#Se extraen las columnas mencionadas anteriormente en la región entre latitudes -38.5 y -36.43 y longitudes -73.68 -71.13. (Región Bío-Bío aproximadamente)
more datos.txt | sed 's/,/ /g' | LC_NUMERIC="en_US.UTF-8" awk '{if (($1+0 >= -38.5) && ($1+0 <= -36.43) && ($2+0 >= -73.68) && ($2+0 <= -71.13)) print $1, $2, $3, $6, $7}' > biobio.txt
#--- Definición del rango de días en el cual se obtendrán los datos.
fecha_inicial="2023-01-21"
fecha_final="2023-03-22" #Este es el rango de fechas en donde hay datos de focos de temperatura.
#-- Estas fechas pueden ser representadas en segundos UNIX, por medio de `date -d "fecha" +%s`. Forma cómoda de trabajar fechas.
#-- Trabaja en segundos desde las 00:00 UTC de enero de 1970.
inicial_unix=`date -d "${fecha_inicial}" +%s`
final_unix=`date -d "${fecha_final}" +%s`

#-- Parámetros del mapa ----------------------------
paleta="wiki-france.cpt" #Paleta de colores para la topografía
paleta_bright="brillos.cpt" #Paleta de colores para la los brillos
region="-74.2/-71/-38.9/-36"
proye="M15"
ruta="/home/jotacesh/Universidad/GMT/Trabajo_final/images2/"
gmt grdcut ETOPO1_Ice_c_gmt4.grd -Gtopo.grd -R${region} #corta la grilla en la region de estudio. (menos peso)
grilla=topo.grd
rm ${ruta}* #borra todo dentro de la carpeta donde se generan las imágenes.

### GRADIENTE PARA SOMBREADO/ILUMINACION #--------------------------------------
gmt grdgradient topo.grd -Nt1 -A30 -Gbi.grd #crea un archivo llamado bi.grd con los gradientes de topografia, con 30° de azimut
gmt grdmath 0.25 bi.grd MUL = int.grd #el archivo int.grd contienen la topografía, ya iluminado/sombreado.

#-------- GROSOR CUADRADOS DE 2km metros -----------
equivalencia_grados=$(echo "2000 / 13000.17" | bc -l) #Cálculo al tanteo, y con ayuda de chatGPT, para ver escala de los puntos.
##--------------------COMIENZO CREACIÓN DEL MAPA------------------------------------------

let cont=1
while [[ ${inicial_unix} -le ${final_unix} ]]; do  #inicial_unix irá aumentando en 86400 segundos por cada iteración, hasta llegar a la fecha final_unix
    name="brillo`printf "%03d" ${cont}`" #define el nombre de los archivos generados, como brillo00x.
    fecha=`date -d @"${inicial_unix}" "+%Y-%m-%d"` #Transforma el tiempo en segundos unix al formato yyyy-mm-dd
    fecha_vientos=`date -d @"${inicial_unix}" "+%d-%m-%Y"` #Formato de hora distinto, para los datos de viento.
    more biobio.txt | grep "${fecha}" > biobio_aux.txt #En biobio_aux.txt se guardarán los datos del día solamente, y cambiará por cada iteración.
    more diarioscarriel.txt | grep "${fecha_vientos}" | awk '{print "-73.06", "-36.77", $3, $2/3.6}' > flechitas.txt #angulo magnitud de conce, se divide en 3.6 para pasar a m/s las velocidades.
    more diariosyungay.txt | grep "${fecha_vientos}" | awk '{print "-72.01", "-37.14", $3, $2/3.6}' >> flechitas.txt #angulo magnitud de yungay ## TEXTO PARA LOS VECTORES DE VIENTO
    more laspuentes.txt | grep "${fecha_vientos}" | awk '{print "-73.43", "-37.3", $3, $2/3.6}' >> flechitas.txt #angulo magnitud de navidad
    more losangeles.txt | grep "${fecha_vientos}" | awk '{print "-72.42", "-37.39", $3, $2/3.6}' >> flechitas.txt #angulo magnitud de colonia
    more termaschillan.txt | grep "${fecha_vientos}" | awk '{print "-71.41", "-36.90", $3, $2/3.6}' >> flechitas.txt #angulo magnitud de nueva aldea
    more biobio_aux.txt | awk '{print $2, $1, $3}' > coords.txt # Extrae las columnas longitud latitud bright_ti4. Archivo coords.txt contendrá los focos para cada día.
    #Creación del mapa para esa hora/dia
    gmt psbasemap -Ba1g1 -J${proye} -R${region} -Xc -Yc -K > ${ruta}${name}.ps #Creación de los bordes, con marco y grilla de 1° de separación.
    gmt grdimage ${grilla} -Iint.grd -Ba1g1 -J${proye} -R${region} -Xc -Yc -P -C${paleta} -O -K >> ${ruta}${name}.ps #Agrega la topografía iluminada, creada anteriormente
    gmt pscoast  -Ba1g1 -J${proye} -R${region} -I1 -W1/1 -Df -O -K >> ${ruta}${name}.ps #Esto genera la linea de costa, I1, solo es linea de costa. -Df significa con resolución full.
    gmt psscale -Dx6.8i/6.5i+w3i/0.3i+jTC+v -C${paleta} -Bx2000+l"Topografía [metros]" -O -K >> ${ruta}${name}.ps #Genera la barra de colores de la topografía.
    gmt psscale -Dx6.8i/3i+w3i/0.3i+jTC+v -C${paleta_bright} -Bx50+l"Brillos [K]" -O -K >> ${ruta}${name}.ps #genera la barra de colores de los brillos
    gmt pstext ciudades.txt -R${region} -J${proye} -Ba1g1 -W0/0/0 -F+f18p -Gwhite -P -O -K >> ${ruta}${name}.ps #Agrega el nombre de las ciudades al mapa (Los ángeles, Antuco y Concepción)
    gmt psxy posiciones.txt -J${proye} -R${region} -Sc0.5 -G0/0/245 -W0/0/0 -P -O -K >> ${ruta}${name}.ps #Agrega un circulo azul en la posición de las ciudades.
    gmt pstext -R${region} -J${proye} -Ba1g1 -W0/0/0 -F+f18p -Gwhite -P -O -K << EOF >> ${ruta}${name}.ps #Agrega un cuadro, en la parte superior, con la fecha de cada imagen.
    -72.5 -36.2 ${fecha}
EOF
    echo -73.7 -38.6 "3m/s" | gmt pstext -R${region} -J${proye} -Ba1g1 -W0/0/0 -F+f18p -Gwhite -P -O -K >> ${ruta}${name}.ps #Genera un texto en la parte inferior del mapa que dice "3m/s".
    echo -74 -38.7 90 3 | gmt psxy -R${region} -J${proye} -SV0.01/0.3/0.15 -G0/0/245 -W1,0/0/0 -O -K >> ${ruta}${name}.ps #Genera una flecha, que corresponde a 3m/s en el mapa. Sirve para tener
                                                                                                                         #una referencia de la magnitud de los vientos.
    gmt psxy coords.txt -R${region} -J${proye} -Ss${equivalencia_grados} -C${paleta_bright} -O -K >> ${ruta}${name}.ps #Agrega los cuadros de brillo, con la paleta mencionada creada de brillos.
    gmt psxy flechitas.txt -R${region} -J${proye} -SV0.01/0.3/0.15 -G0/0/245 -W1,0/0/0 -O -K >> ${ruta}${name}.ps #Agrega los vectores de viento de las 5 estaciones. La opción -SV de psxy genera vectores
    # donde se le entrega la dirección en ángulo azimut, y la magnitud del vector.
    ## -SVancholinea/largocabeza/anchocabeza

    # INSERTAR MAPA DE REFERENCIA ##
    #Esta parte genera un mapa en la esquina superior izquierda de la imagen, donde se muestra sudamerica, y un cuadro rojo en la región de estudio (BIO-BIO)
    jc="-73/-20/1.8i" #-Jclon0/lat0/scale 1.5i define tamaño del mapa.
    gmt pscoast -R-90/-50/-50/-10 -JC${jc} -Bg8 -Dh -X+0.2 -Y12 -W0.25p -G255/187/86 -O -K >> ${ruta}${name}.ps #se genera una nueva linea de costa, de tamaño mas pequeña, y posicionada arriba a la izquierda.
    gmt psxy -R-90/-50/-50/-10 -JC${jc} -W0.7p,red -O square.txt >> ${ruta}${name}.ps #Genera un cuadro de color rojo, en la región de estudio. "square.txt" tiene las coordenadas de la region del biobio
    #
    gmt psconvert ${ruta}${name}.ps -A -Tg #Transforma los archivos .ps a .png, y son recortados, para no tener espacio en blanco extra.
    let inicial_unix=${inicial_unix}+24*3600 # se le suma un día/hora en segundos, esto genera que se avance en los días, hasta llegar al límite.
    let cont=${cont}+1 #contador para el nombre de las imagenes.
    echo ${fecha} #Muestra en consola el día en el que va, para saber el progreso del programa.
done
cd ${ruta}
rm brillo*.ps #Borra todos los archivos .ps, ya que se ocupa los .png para realizar el gif.

convert -delay 10 -loop -1 brillo*.png -layers optimize brillos_diarios.gif #Realiza el gif, con 10 milisegundos entre cada imagen. Se repite indefinidamente.
