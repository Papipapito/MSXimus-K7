# ============================================================================
#  board.xdc - QMTECH XC7K325T Development Board
#  Dispositivo: xc7k325tffg676-1
# ----------------------------------------------------------------------------
#  PROCEDENCIA DE LOS PINES
#  Extraidos del esquematico oficial de QMTECH:
#    QMTECH-XC7K325T-DEVELOPMENT-BOARD_SCHEMATIC_20231120_V01.pdf
#  emparejando bola y nombre de pin por coordenada exacta de dibujo
#  (400 correspondencias bola -> nombre Xilinx). Ver docs/PORT_K325T_PLAN.md.
#
#  [OK]   = verificado contra el esquematico
#  [TODO] = NO verificado - hay que leerlo en placa/manual antes de usarlo
#
#  Recordatorio del plan: el multimetro en la placa manda sobre el papel.
# ============================================================================

# ---------------------------------------------------------------- reloj ----
# [OK] SG-8002JC 50.000 MHz -> red SYS_CLK_F22 -> bola F22
#      F22 = IO_L12P_T1_MRCC_14  (banco 14, MRCC: apto para MMCM)
set_property -dict {PACKAGE_PIN F22 IOSTANDARD LVCMOS33} [get_ports clk_50m]
create_clock -period 20.000 -name sys_clk_50m [get_ports clk_50m]

# ------------------------------------------------------- LEDs y botones ----
# [TODO] Las redes LED2/LED3/LED4 y SW2/SW3 existen en el esquematico (con
#        pull-ups de 4k7 a VCCO_12), pero sus etiquetas NO estan junto a
#        ninguna bola en el PDF: no se pueden deducir con certeza. Parecen
#        caer en el banco 13. LEERLOS EN EL MANUAL O CON MULTIMETRO.
#
#        Mientras tanto, para el Hito 1 se puede parpadear sobre un pin de
#        PMOD (esos SI estan verificados) y comprobarlo con un LED o un
#        polimetro. Ver top.sv.
#
# set_property -dict {PACKAGE_PIN <??> IOSTANDARD LVCMOS33} [get_ports {led[0]}]
# set_property -dict {PACKAGE_PIN <??> IOSTANDARD LVCMOS33} [get_ports {led[1]}]
# set_property -dict {PACKAGE_PIN <??> IOSTANDARD LVCMOS33} [get_ports {led[2]}]
# set_property -dict {PACKAGE_PIN <??> IOSTANDARD LVCMOS33} [get_ports rst_n]

# ==========================================================================
#  PMOD  -  los tres cableados como PMOD DIFERENCIAL: pin N hace par con N+6
#  Todos con VCC = 3V3. Bancos 14 y 15 (HR) -> TMDS_33 disponible.
# ==========================================================================

# ------------------------------------------------------- J11 (PMOD 1) ------
# [OK] 4 pares validos, PERO repartidos entre banco 15 (3) y banco 14 (1)
#      -> dos regiones de reloj. Plan: USB (single-ended).
#  pin1  C16  IO_L1P_T0_AD0P_15      \ par L1  bk15
#  pin7  B16  IO_L1N_T0_AD0N_15      /
#  pin2  A17  IO_L3N_T0_DQS_AD1N_15  \ par L3  bk15   (POLARIDAD INVERTIDA)
#  pin8  B17  IO_L3P_T0_DQS_AD1P_15  /
#  pin3  A18  IO_L2P_T0_AD8P_15      \ par L2  bk15
#  pin9  A19  IO_L2N_T0_AD8N_15      /
#  pin4  A20  IO_L8N_T1_D12_14       \ par L8  bk14   (POLARIDAD INVERTIDA)
#  pin10 B20  IO_L8P_T1_D11_14       /
set_property -dict {PACKAGE_PIN C16 IOSTANDARD LVCMOS33} [get_ports {pmod1[0]}]
set_property -dict {PACKAGE_PIN A17 IOSTANDARD LVCMOS33} [get_ports {pmod1[1]}]
set_property -dict {PACKAGE_PIN A18 IOSTANDARD LVCMOS33} [get_ports {pmod1[2]}]
set_property -dict {PACKAGE_PIN A20 IOSTANDARD LVCMOS33} [get_ports {pmod1[3]}]
set_property -dict {PACKAGE_PIN B16 IOSTANDARD LVCMOS33} [get_ports {pmod1[4]}]
set_property -dict {PACKAGE_PIN B17 IOSTANDARD LVCMOS33} [get_ports {pmod1[5]}]
set_property -dict {PACKAGE_PIN A19 IOSTANDARD LVCMOS33} [get_ports {pmod1[6]}]
set_property -dict {PACKAGE_PIN B20 IOSTANDARD LVCMOS33} [get_ports {pmod1[7]}]

# ------------------------------------------------------- J12 (PMOD 2) ------
# [OK] SOLO 3 pares validos. pin4/pin10 NO son par (L13N vs L14N: dos
#      mitades negativas de parejas distintas). Plan: microSD (single-ended).
#  pin1  E21  IO_L9P_T1_DQS_14              \ par L9
#  pin7  E22  IO_L9N_T1_DQS_D13_14          /
#  pin2  D23  IO_L11P_T1_SRCC_14            \ par L11 (SRCC)
#  pin8  D24  IO_L11N_T1_SRCC_14            /
#  pin3  D25  IO_L15N_T2_DQS_DOUT_CSO_B_14  \ par L15  (INVERTIDA)
#  pin9  E25  IO_L15P_T2_DQS_RDWR_B_14      /
#  pin4  F23  IO_L13N_T2_MRCC_14            x NO SON PAR
#  pin10 F24  IO_L14N_T2_SRCC_14            x
set_property -dict {PACKAGE_PIN E21 IOSTANDARD LVCMOS33} [get_ports {pmod2[0]}]
set_property -dict {PACKAGE_PIN D23 IOSTANDARD LVCMOS33} [get_ports {pmod2[1]}]
set_property -dict {PACKAGE_PIN D25 IOSTANDARD LVCMOS33} [get_ports {pmod2[2]}]
set_property -dict {PACKAGE_PIN F23 IOSTANDARD LVCMOS33} [get_ports {pmod2[3]}]
set_property -dict {PACKAGE_PIN E22 IOSTANDARD LVCMOS33} [get_ports {pmod2[4]}]
set_property -dict {PACKAGE_PIN D24 IOSTANDARD LVCMOS33} [get_ports {pmod2[5]}]
set_property -dict {PACKAGE_PIN E25 IOSTANDARD LVCMOS33} [get_ports {pmod2[6]}]
set_property -dict {PACKAGE_PIN F24 IOSTANDARD LVCMOS33} [get_ports {pmod2[7]}]

# ------------------------------------------------------- J13 (PMOD 3) ------
# [OK] 4 pares validos, LOS CUATRO EN EL BANCO 14 = una sola region de reloj.
#      -> EL SITIO DEL HDMI (Hito 2).
#  pin1  A24  IO_L4N_T0_D05_14         \ par L4   (POLARIDAD INVERTIDA)
#  pin7  A23  IO_L4P_T0_D04_14         /
#  pin2  B26  IO_L3N_T0_DQS_EMCCLK_14  \ par L3   (INVERTIDA) *** ver aviso
#  pin8  B25  IO_L3P_T0_DQS_PUDC_B_14  /
#  pin3  D26  IO_L5P_T0_D06_14         \ par L5
#  pin9  C26  IO_L5N_T0_D07_14         /
#  pin4  F25  IO_L17P_T2_A14_D30_14    \ par L17
#  pin10 E26  IO_L17N_T2_A13_D29_14    /
#
#  *** AVISO: pin8 (B25) es PUDC_B, pin de configuracion que se muestrea al
#      configurar. Un sumidero HDMI termina TMDS a 3V3 con 50 ohm -> quedaria
#      ALTO con monitor, y ALTO por pull-up interno sin monitor: determinista
#      en ambos casos. PERO hay que confirmarlo en placa: es el criterio de
#      salida del Hito 2.
set_property -dict {PACKAGE_PIN A24 IOSTANDARD LVCMOS33} [get_ports {pmod3[0]}]
set_property -dict {PACKAGE_PIN B26 IOSTANDARD LVCMOS33} [get_ports {pmod3[1]}]
set_property -dict {PACKAGE_PIN D26 IOSTANDARD LVCMOS33} [get_ports {pmod3[2]}]
set_property -dict {PACKAGE_PIN F25 IOSTANDARD LVCMOS33} [get_ports {pmod3[3]}]
set_property -dict {PACKAGE_PIN A23 IOSTANDARD LVCMOS33} [get_ports {pmod3[4]}]
set_property -dict {PACKAGE_PIN B25 IOSTANDARD LVCMOS33} [get_ports {pmod3[5]}]
set_property -dict {PACKAGE_PIN C26 IOSTANDARD LVCMOS33} [get_ports {pmod3[6]}]
set_property -dict {PACKAGE_PIN E26 IOSTANDARD LVCMOS33} [get_ports {pmod3[7]}]

# ==========================================================================
#  HDMI sobre J13 - HITO 2. Comentado hasta entonces.
#  Sustituye al bloque pmod3 de arriba (no pueden coexistir: mismos pines).
#
#  Antes de descomentar: LEER LA SERIGRAFIA DEL PMOD HDMI para saber que par
#  lleva CLK y cuales D0/D1/D2. Y OJO CON LA POLARIDAD: en los pares L4 y L3
#  el pin bajo es la mitad N, asi que el "P" del OBUFDS va al pin ALTO.
# ==========================================================================
# set_property -dict {PACKAGE_PIN A23 IOSTANDARD TMDS_33} [get_ports hdmi_d0_p]
# set_property -dict {PACKAGE_PIN A24 IOSTANDARD TMDS_33} [get_ports hdmi_d0_n]
# set_property -dict {PACKAGE_PIN B25 IOSTANDARD TMDS_33} [get_ports hdmi_d1_p]
# set_property -dict {PACKAGE_PIN B26 IOSTANDARD TMDS_33} [get_ports hdmi_d1_n]
# set_property -dict {PACKAGE_PIN D26 IOSTANDARD TMDS_33} [get_ports hdmi_d2_p]
# set_property -dict {PACKAGE_PIN C26 IOSTANDARD TMDS_33} [get_ports hdmi_d2_n]
# set_property -dict {PACKAGE_PIN F25 IOSTANDARD TMDS_33} [get_ports hdmi_clk_p]
# set_property -dict {PACKAGE_PIN E26 IOSTANDARD TMDS_33} [get_ports hdmi_clk_n]

# ---------------------------------------------------------- bitstream ------
set_property CONFIG_VOLTAGE 3.3          [current_design]
set_property CFGBVS VCCO                 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
# QSPI x4 para la flash de configuracion de la placa
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4       [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33        [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE YES    [current_design]
