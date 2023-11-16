# Buffer-Overflow-from-32-bit-binary

***

  <h5>Enumeración</h5>

- (El binario customizado no es mio, pertenece a una practica del curso de S4vitar, [Hack4u/introducción al hacking](https://hack4u.io/))
 
- En este caso, trabajaremos y analizaremos de manera basica la enumeración y explotación de un [binario](https://github.com/JoseVazquez101/Buffer-Overflow-from-32-bit-binary/blob/main/Files/custom) que poseé permisos de sudores llamado `custom`. Podemos asignarselos desde la ruta /etc/sudoers
  ![image](https://github.com/JoseVazquez101/Buffer-Overflow-from-32-bit-binary/assets/111292579/a9da53bd-6e2a-4259-bd19-b31cbc53fc96)

- El binario nos solicita una cadena como argumento para ejecutarlo:
  ![image](https://github.com/JoseVazquez101/Buffer-Overflow-from-32-bit-binary/assets/111292579/f20f55bc-4618-4d34-aaf0-e19a9e3e22a7)

- Probamos meter una cadena mas grande, pero vemos algo curioso. Al parecer después de ciertos caracteres podemos causar un `segmentation fault` , es decir, la variable que almacena nuestra cadena se sobrepasa a lo que puede contener
	- Por ejemplo, si nuestra variable es de 30 bytes y le ingresamos mas, el programa explotará
- Con `gdb`, podemos ver y debuguear la ejecución del programa de la siguiente manera:
  ~~~ bash 
  gdb /usr/bin/custom -q
  ~~~
![image](https://github.com/JoseVazquez101/Buffer-Overflow-from-32-bit-binary/assets/111292579/28516134-af38-41b8-a473-140a2846269e)

- De igual forma, con una r podremos correr el programa de manera normal:
  ![image](https://github.com/JoseVazquez101/Buffer-Overflow-from-32-bit-binary/assets/111292579/eadf68b6-3d75-4d63-aa84-1d7e5eff504c)

  - Si lo ejecutamos con un montón de cadenas de texto, nos arrojará lo siguiente:
    ![image](https://github.com/JoseVazquez101/Buffer-Overflow-from-32-bit-binary/assets/111292579/451822d5-6caa-409c-88f4-aee81c90e59b)

    - La dirección de memoria `EIP (Instruction Pointer)` es la que nos  indica hacia donde se dirigía el programa después de ejecutar la instrucción actual
    - También podemos observar algo curioso, en esa línea podemos ver:
    ~~~ C
    EIP: 0x41414141 ('AAAA')
    ~~~
    - Y si ponemos atención, nos daremos cuenta que ese espacio de memoria está lleno de 'A' en código ASCII, ya que A=41. Por lo que podemos ver, nuestro input tiene la capacidad de sobrescribir registros del sistema.

- Si logramos alterar de alguna manera el flujo del sistema para que esa dirección apunte a la ejecución de algún comando en especial, al ser el binario SUID, ejecutará esto como root y ganaremos acceso.
- Primero que nada, debemos encontrar cual es el limite de padding con 'A' que podemos meter al input antes de que se acontezca el Segmentation Fault

- A través de fuerza bruta, pude ver que el limite de ejecución de caracteres es de 111, con 112 se acontecerá el Segmentation Fault
- De igual forma, gbd tiene un modulo llamado `patter_create` donde le indicarás el numero de bits aleatorios que generará
  ![image](https://github.com/JoseVazquez101/Buffer-Overflow-from-32-bit-binary/assets/111292579/b27c4264-8b3b-47d7-aaf3-15858bfd5081)


- Si ingresamos esta cadena al programa, podremos ver algo:
  ![image](https://github.com/JoseVazquez101/Buffer-Overflow-from-32-bit-binary/assets/111292579/ed0058c2-3503-4b7f-aa7d-0dca200ad979)

- Y si greppeamos por esos caracteres exactos, podremos ver hasta donde se ubicaban
  ![image](https://github.com/JoseVazquez101/Buffer-Overflow-from-32-bit-binary/assets/111292579/c183681c-1f4b-4a03-a43b-5d875e2103bc)

- Aunque también con `pattern offset` podremos ver el limite mas simplificado xd:
  ![image](https://github.com/JoseVazquez101/Buffer-Overflow-from-32-bit-binary/assets/111292579/d7e274fb-3b15-44fa-a009-3edba9448f76)

   - Conociendo esto, podemos ordenarle que nos ejecute una operatoria como si fuese un comando, en mi caso emplee lo siguiente para hacer padding con 'A' y me imprimiera en el EIP el código de 'B':
  ~~~ python
  r $(python3 -c 'print("A"*112 + "B"*4)')
  ~~~
  ![image](https://github.com/JoseVazquez101/Buffer-Overflow-from-32-bit-binary/assets/111292579/db84e123-f1d7-408a-ad04-56c1b7331e02)
  
- Como información extra, podemos ver las funciones con `info functions`:
![image](https://github.com/JoseVazquez101/Buffer-Overflow-from-32-bit-binary/assets/111292579/9fb96654-dbb2-45c2-b86e-a09b1de7d638)

- Y a su vez podemos poner un punto de detención en alguna función en especifico con `b *<function>`, de esta forma podríamos hacer varias consultas, pues lo detenemos justo cuando empieza el programa.
![image](https://github.com/JoseVazquez101/Buffer-Overflow-from-32-bit-binary/assets/111292579/8811ec15-f720-49e6-bc66-a35faaf47044)

  ***
  <h5>Explotación</h5>
  
  - Lo primero que deberíamos hacer identificado esto, seria revisar la seguridad del binario con `checksec`
  ![image](https://github.com/JoseVazquez101/Buffer-Overflow-from-32-bit-binary/assets/111292579/e0f23b1c-669a-42e6-8a6d-17d34c46275e)

  
  1. **CANARY (DEP):** (DEP, Data Execution Prevention) se refiere a la técnica de seguridad que evita que datos no ejecutables se ejecuten como código. Está deshabilitado
    
2. **FORTIFY:** Esta característica se refiere a las mejoras de seguridad en funciones estándar de la biblioteca C para proteger contra desbordamientos de búfer y otros errores comunes de programación. Está deshabilitado

3. **NX (No eXecute):** Está habilitado, lo que significa que la región de la memoria que almacena el código no puede ser utilizada para almacenar datos. Esto ayuda a prevenir ataques de ejecución de código en áreas de memoria que deberían contener solo datos.

5. **PIE (Position Independent Executable):** Está deshabilitado, lo que significa que el binario no se carga en una dirección de memoria aleatoria en cada ejecución. 
    
5. **RELRO (RELocation Read-Only):** Está parcialmente habilitado. RELRO es una técnica que protege la tabla de reubicación, haciendo que ciertas secciones de la memoria sean de solo lectura después de que el programa ha sido cargado.

- Aquí podriamos intentar aprovecharnos de `ret2libc`, es decir de una llamada del sistema a libc para intentar cargar codigo
- La sintaxis es algo parecida a esto:
~~~ bash
ret2libc = system + exit + bin_sh
~~~
- Para entenderlo mejor, es como la sintaxis de python para hacer llamadas al sistema:
  ~~~ python
  os.system("whoami") #bin_sh almacena mi cadena
  user #system
  0 #codigo de salida
  ~~~
- Un atacante normalmente intentaría llamar con bin_sh al mismo binario /bin/sh, que afortunadamente podemos encontrar en libc.
- Con `ldd` podemos ver las llamadas a memoria a librerias que hace un binario:
  ![image](https://github.com/JoseVazquez101/Buffer-Overflow-from-32-bit-binary/assets/111292579/934b5336-e2bd-4f29-b543-f42608aae1ae)

- Podemos obtener la dirección de memoria de libc en este binario de la siguiente manera:
  ~~~ bash
  ldd /usr/bin/custom | grep libc |awk 'NF{print($NF)}' | tr -d '()'
  ~~~
  ![image](https://github.com/JoseVazquez101/Buffer-Overflow-from-32-bit-binary/assets/111292579/26a862ba-0054-45ec-8c71-501afc60d913)

  - Y si lo ejecutamos 10 veces, podemos ver que esta cambiará, ya que la ejecución aleatoria está habilitada, esto nos lo pone un poco mas difícil ya que no sabremos a donde apuntará directamente la siguiente ejecución.
  ~~~ bash
  for x in $(seq 1 10); do ldd /usr/bin/custom | grep libc |awk 'NF{print($NF)}' | tr -d '()'; done
  ~~~
  
  ![image](https://github.com/JoseVazquez101/Buffer-Overflow-from-32-bit-binary/assets/111292579/4977be53-a993-4a8e-b509-7d51b8bc2440)

- Como nos encontramos en una maquina de 32 bits, las direcciones de memoria no son tan largas, y hay mayor probabilidad de que estas se repitan en rangos de ejecución muy largos, por ejemplo, si ejecutamos mil veces y greppeamos por una dirección `0xb7d2a000` la veremos varias veces:

![image](https://github.com/JoseVazquez101/Buffer-Overflow-from-32-bit-binary/assets/111292579/5f0f64b2-aaef-49d2-b7aa-6148e98b3b2e)

- Algo sumamente practico que podemos hacer, es ver cuanto vale system, exit y /bin/sh de la siguiente forma
~~~ bash
p system
p exit
find /bin/sh
~~~
![image](https://github.com/JoseVazquez101/Buffer-Overflow-from-32-bit-binary/assets/111292579/cbeeb9e6-5f31-47ed-aff4-ffaa1f8799d2)

- Lo que podemos hacer es ejecutar como overflow del buffer, en lugar de letras, estas direcciones de memoria.
- El problema es que, como la locación de la memoria es aleatoria, tendremos que aplicar fuerza bruta hasta que las direcciones coincidan. Como lo vimos anteriormente, es bastante probable que en 1000 ejecuciones el programa repita direcciones.

- Primero, seleccionamos una locación de memoria tras ejecutar el programa, seleccioné `0xb7de4000`.
- A base de esta, tengo que calcular la distancia a recorrer para llegar a las direcciones de `system, exit y /bin/sh`. 

- Utilizaremos `readelf` podremos obtener estas direcciones de memoria que nos interesan, para esto utilizaremos el archivo de librería que libc llama del programa, esto de la siguiente forma:
~~~ bash
ldd /usr/bin/custom
readelf -s /lib/i386-linux-gnu/libc.so.6 | grep -E " system| exit"
~~~
![image](https://github.com/JoseVazquez101/Buffer-Overflow-from-32-bit-binary/assets/111292579/a8ac11ef-eddc-4bac-aeac-c783befaf668)

- Estas no son las direcciones reales, solo son los upsets para llegar a la dirección real de memoria para libc, pero a lo que sé, estos son valores estáticos.
- Ahora, solo nos falta el upset de /bin/sh, que nos pudo haber valido el que encontramos con find, de no ser porque la memoria está aleatorizada.
- Podemos utilizar `strings` para que nos lea el archivo completo de libc y nos muestre la data en base hexadecimal de la siguiente manera:
~~~bash
strings -a -t x /lib/i386-linux-gnu/libc.so.6 | grep /bin/sh
~~~
![image](https://github.com/JoseVazquez101/Buffer-Overflow-from-32-bit-binary/assets/111292579/3040ce98-a187-4db9-9153-e76fb3979bf3)

- Me cree un [script](https://github.com/JoseVazquez101/Buffer-Overflow-from-32-bit-binary/blob/main/Files/buff-ov.sh) de Python/bash el cual automatiza un poco las ejecuciones y nos obtiene los valores de memoria necesarios para la explotación, pueden revisarlo y verám que sigue los mismos puntos tocados anteriormente


  
