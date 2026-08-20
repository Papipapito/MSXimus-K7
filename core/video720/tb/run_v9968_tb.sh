#!/bin/bash
# run_v9968_tb.sh — TB del puente V9968 -> HDMI 720p (geometria 800/x3/ce)
#
# La ruta absoluta al repo viejo (MSX_up) se cambio por dirname: este script
# venia del arbol del 60K y aqui vive en core/video720/tb/.
set -e
cd "$(dirname "$0")"
iverilog -g2012 -DSIM_NO_HDMI -o /tmp/v9968_hdmi_tb.out -s msx2hdmi_v9968_tb \
  msx2hdmi_v9968_tb.v ../msx2hdmi_v9968.sv
vvp /tmp/v9968_hdmi_tb.out
