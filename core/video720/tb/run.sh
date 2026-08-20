#!/usr/bin/env bash
# Testbench del puente msx2hdmi (solo lógica: captura + ring + lock + escalado)
#
# Uso desde WSL, con la cadena abierta en el PATH:
#   source ~/oss-cad-suite/environment
#   bash core/video720/tb/run.sh
#
# Uso desde Windows en una linea:
#   wsl -d Ubuntu-22.04 -- bash -lc 'source ~/oss-cad-suite/environment && bash /mnt/c/Users/alber/proyectosAI/msx/MSXimus-K7/core/video720/tb/run.sh'
#
# Ultima ejecucion verde: 2026-08-20, Icarus 14.0, 20.671.200 checks, 0 errores.
set -e
cd "$(dirname "$0")"

echo "== compilando (iverilog -g2012 -DSIM_NO_HDMI) =="
iverilog -g2012 -DSIM_NO_HDMI -o msx2hdmi_tb.vvp ../msx2hdmi.sv msx2hdmi_tb.v

echo "== simulando =="
vvp msx2hdmi_tb.vvp
