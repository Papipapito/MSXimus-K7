# Plan de migración — MSXimus → QMTECH XC7K325T Development Board

> Estado: **investigación cerrada, sin tocar RTL todavía.**
> Fecha: 2026-08-19 · Rama: `claude/msximus-fpga-migration-194h8o`
> Origen: core v3.0 de Tang Console 60K (Gowin GW5AT-60).

Este documento sustituye a las suposiciones del `PROJECT_CONTEXT.md` del pack de
contexto por **datos leídos del esquemático oficial** de la placa
(`QMTECH-XC7K325T-DEVELOPMENT-BOARD_SCHEMATIC_20231120_V01.pdf`, rev. V01 del
20-nov-2023, descargado del repo `ChinaQMTECH/QMTECH_Kintex-7_Development_Board`)
y del barrido del árbol RTL actual.

---

## 0. Resumen ejecutivo (la tesis del plan)

Tres hallazgos cambian la forma del plan respecto al borrador del pack:

1. **El serializador HDMI de Xilinx YA ESTÁ ESCRITO en el árbol.**
   `fpga/tn_vdp_v3_v9958/src/hdmi/serializer.sv` lleva una rama completa con
   `OSERDESE2` maestro+esclavo en cascada (líneas 20-110), desactivada
   únicamente por el `` `define GW_IDE `` de la línea 1. El HDMI no hay que
   escribirlo: hay que **elegir la rama que ya existe**. Esto saca el que
   parecía el mayor riesgo del camino crítico.

2. **La RAM principal del MSX vive hoy en SDR SDRAM externa
   (`fpga/src/memory.v`, `memory_ctrl`), y esa SDRAM NO EXISTE en la placa
   nueva.** Éste — y no el HDMI ni la DDR3 — es el verdadero trabajo de puerto.

3. **Pero el core mínimo no necesita memoria externa en absoluto.** El K325T
   tiene ~1,95 MB de BRAM (445 × 36 Kb = 16.020 Kb). Un MSX2+ básico
   (512 KB mapper + 128 KB VRAM + BIOS/SubROM) cabe holgadamente. **La DDR3
   se puede aplazar hasta después del primer arranque con vídeo.**

De ahí la estrategia: **BRAM primero, DDR3 después**. El primer MSX que
arranque en el K325T no llevará ni MIG ni UberDDR3 ni SDRAM. Eso convierte el
bring-up en una escalera corta y verificable en vez de un salto con tres
subsistemas analógicos sin validar a la vez.

Esto además concuerda con lo ya aprendido en la 60K
(`fpga/BASE_MINIMA_60K_PLAN.md` §A.2): *"DDR3 como RAM general del Z80:
DESCARTADA con evidencia definitiva"*. No repitamos esa batalla en el arranque.

---

## 1. Hardware verificado (leído del esquemático, no supuesto)

### 1.1 Núcleo

| Elemento | Dato verificado |
|---|---|
| FPGA | XC7K325T, footprint FBG676/FGG676 (símbolo compartido con XC7K70T/160T; muchos pines marcados *NO PAD ON XC7K70T*) |
| Oscilador | `SG-8002JC-50.0000M-PCB`, **50 MHz**, red `SYS_CLK_F22` → bola **F22** = `IO_L12P_T1_MRCC_14` (banco 14, **MRCC** ✔ apto para MMCM) |
| DDR3 | `MT41K128M16JT-125` — **x16, 256 MB**. Redes `DDR_A0..A13`, `DDR_BA0..2`, `DDR_D0..D15`, `DDR_DQM0/1`, `DDR_DQS0/1±`, `DDR_CLK±`, `CKE`, `CS`, `RAS`, `CAS`, `WE`, `ODT`, `RESETN`, `VREF` (un solo rank) |
| Flash config | QSPI: `FPGA_CCLK`, `FPGA_CSO_B`, `FPGA_DQ0..3` |
| Config | `M0/M1/M2`, `PROGRAM_B` (SW1), `INIT_B`, `DONE`, JTAG en **J1** |
| Transceptores | **GTX en bancos 115 y 116** (8 carriles, `MGTREFCLK0/1` en ambos). No lo mencionaba el pack |
| LEDs / botones | `D2/D3/D4` (LED2-4) y `SW2/SW3`, con pull-ups de 4,7 k a **VCCO_12** → banco 12 |

### 1.2 Tensiones de banco

| Bancos | VCCO | Tipo |
|---|---|---|
| 0 (config) | 3V3 | — |
| **13, 14, 15, 16** | **3V3** | **HR** (High Range) |
| 32, 33, 34 | 1V8 / 1V5 | HP (High Performance) — DDR3 |
| 12 | red propia `VCCO_12` | HR — **verificar en placa si es seleccionable por jumper** |

> Que los bancos 14/15 estén a **3,3 V y sean HR** es lo que habilita
> **`TMDS_33`** con `OBUFDS` directo. Es el requisito duro del HDMI y **está
> cumplido**.

### 1.3 Los tres PMOD — pinout completo y análisis de pares diferenciales

Hay **tres** cabeceras PMOD 2×6: **J11, J12, J13** (todas con VCC = 3V3).
Están cableadas con el convenio de *PMOD diferencial*: **el pin N y el pin N+6
forman par**. Extraído bola a bola del esquemático:

**J11** — VCC 3V3, bancos 15 y 14
| Pin | Bola | Nombre Xilinx | Par |
|---|---|---|---|
| 1 | C16 | `IO_L1P_T0_AD0P_15` | ↕ con 7 — **L1 bk15** ✔ |
| 7 | B16 | `IO_L1N_T0_AD0N_15` | |
| 2 | A17 | `IO_L3N_T0_DQS_AD1N_15` | ↕ con 8 — **L3 bk15** ✔ (polaridad invertida) |
| 8 | B17 | `IO_L3P_T0_DQS_AD1P_15` | |
| 3 | A18 | `IO_L2P_T0_AD8P_15` | ↕ con 9 — **L2 bk15** ✔ |
| 9 | A19 | `IO_L2N_T0_AD8N_15` | |
| 4 | A20 | `IO_L8N_T1_D12_14` | ↕ con 10 — **L8 bk14** ✔ (invertida) |
| 10 | B20 | `IO_L8P_T1_D11_14` | |

→ **4 pares válidos, pero repartidos entre banco 15 (3) y banco 14 (1)**
= dos regiones de reloj distintas.

**J12** — VCC 3V3, banco 14
| Pin | Bola | Nombre Xilinx | Par |
|---|---|---|---|
| 1 | E21 | `IO_L9P_T1_DQS_14` | ↕ con 7 — **L9** ✔ |
| 7 | E22 | `IO_L9N_T1_DQS_D13_14` | |
| 2 | D23 | `IO_L11P_T1_SRCC_14` | ↕ con 8 — **L11** ✔ (SRCC) |
| 8 | D24 | `IO_L11N_T1_SRCC_14` | |
| 3 | D25 | `IO_L15N_T2_DQS_DOUT_CSO_B_14` | ↕ con 9 — **L15** ✔ (invertida) |
| 9 | E25 | `IO_L15P_T2_DQS_RDWR_B_14` | |
| 4 | F23 | `IO_L13N_T2_MRCC_14` | ✖ **NO son par** (L13N vs L14N) |
| 10 | F24 | `IO_L14N_T2_SRCC_14` | |

→ **Sólo 3 pares válidos.** El cuarto "par" son dos mitades negativas de
parejas distintas. **J12 queda descartado para HDMI.**

**J13** — VCC 3V3, **todo banco 14**
| Pin | Bola | Nombre Xilinx | Par |
|---|---|---|---|
| 1 | A24 | `IO_L4N_T0_D05_14` | ↕ con 7 — **L4** ✔ (invertida) |
| 7 | A23 | `IO_L4P_T0_D04_14` | |
| 2 | B26 | `IO_L3N_T0_DQS_EMCCLK_14` | ↕ con 8 — **L3** ✔ (invertida) ⚠ |
| 8 | B25 | `IO_L3P_T0_DQS_PUDC_B_14` | |
| 3 | D26 | `IO_L5P_T0_D06_14` | ↕ con 9 — **L5** ✔ |
| 9 | C26 | `IO_L5N_T0_D07_14` | |
| 4 | F25 | `IO_L17P_T2_A14_D30_14` | ↕ con 10 — **L17** ✔ |
| 10 | E26 | `IO_L17N_T2_A13_D29_14` | |

→ **4 pares válidos, los cuatro en el banco 14** = una sola región de reloj.
**J13 es el mejor candidato para el HDMI.**

⚠ **Única pega de J13**: el par pin2/pin8 usa `EMCCLK` y **`PUDC_B`**, que son
pines de configuración. `PUDC_B` se muestrea durante la configuración (decide si
las E/S no usadas llevan pull-up). Un sumidero HDMI termina las líneas TMDS a
3,3 V con 50 Ω, así que `PUDC_B` quedaría **alto** con monitor conectado, y alto
por su pull-up interno sin monitor: comportamiento determinista en ambos casos.
Aceptable, pero **hay que confirmarlo en placa** — es el primer riesgo a cerrar.

### 1.4 Cabecera de expansión y CM4

- **JP5** = `HDR_25X2` (2×25, 50 pines): ~40 E/S del **banco 12** + 10 del
  **banco 33**, más `VCCO_12` y `5V0`. Es el "header de 50 pines" del pack.
- **Zócalo CM4**: `HDMI0_*` y `HDMI1_*` (TMDS + CEC + HPD + SCL/SDA),
  hub USB **`USB2514QFN36`** con "Dual USB A", **micro-SD**, Ethernet
  `HR911130A` con pares `MDI_*`/`TRD_*`, y `GPIO0..GPIO27`.
- Además, algunas E/S del FPGA llegan al conector del CM4:
  **4 del banco 15, 6 del banco 32, 10 del banco 33** → ése es el enlace
  FPGA↔CM4 del futuro Hito 9.

> **Queda confirmada la sospecha del pack**: los conectores HDMI, los USB-A y la
> micro-SD de la placa son **del CM4, no del FPGA**. Por eso los tres PMOD del
> usuario no son un apaño: son *la* vía de E/S del FPGA.

---

## 2. Correcciones al `PROJECT_CONTEXT.md`

| § del pack | Decía | Verificado |
|---|---|---|
| 15 | "Exact Kintex pins connected to each PMOD" (abierto) | **Resuelto** — tabla §1.3 |
| 15 | "Which free differential pairs are best for HDMI" | **Resuelto** — J13 (4 pares, banco 14 único) |
| 15 | "I/O bank voltages for candidate HDMI pins" | **Resuelto** — bancos 14/15 a 3V3, HR → `TMDS_33` OK |
| 15 | "Whether onboard USB-A / microSD are FPGA-accessible" | **Resuelto** — no, son del CM4 |
| 6 | "safest assumption: HDMI belongs to CM4" | **Confirmado** |
| 1 | "3 PMOD-compatible headers" | **Confirmado** — J11/J12/J13, pero **J12 sólo tiene 3 pares** |
| 8 | "no reproducir la SDRAM del Tang" | Correcto, **pero** hoy la RAM del MSX *es* esa SDRAM → §4 |
| — | (no lo mencionaba) | La placa tiene **8 carriles GTX** (bancos 115/116) |
| 6 | "pixel 74.25 / serializador 371.25" | Correcto, y alcanzable exacto desde 50 MHz → §3 |

---

## 3. Plan de relojes (cuentas cerradas, a confirmar en Clocking Wizard)

Entrada única: **50 MHz en F22** (MRCC banco 14).

**Restricción que decide la topología**: en 7-series el `MMCME2_ADV` tiene
`CLKFBOUT_MULT_F` ≤ **64** (pasos de 1/8) y VCO 600-1200 MHz (K7 **-1**).
Una búsqueda exhaustiva sobre ese espacio da un resultado tajante:

> **No existe ningún MMCM que saque 135/108/54/27 MHz exactos directamente
> desde 50 MHz.** Haría falta `M/D = 21,6` (VCO 1080), y 21,6 no cae en la
> rejilla de 1/8; y con `D=5, M=108` el multiplicador se sale del máximo de 64.

Por tanto **hay que cascadear pasando por 27 MHz** — que es, casualmente, la
misma topología que ya usa la 60K (`top.v:314-320`, cascada 50 → 27 → 74,25).
Cuatro MMCM, todos con salidas **exactas**:

| MMCM | Entrada | D | M | VCO | Salidas (divisor) |
|---|---|---|---|---|---|
| **REF** | 50 MHz | 1 | 13,500 | 675,00 | **27,000** (÷25) ✅ **implementado** |
| **SYS** | 27 MHz | 1 | 40,000 | 1080,00 | **135,00** (÷8) · **108,00** (÷10) · **54,00** (÷20) · **27,00** (÷40) |
| **VID** | 27 MHz | 1 | 27,500 | 742,50 | **74,250** (÷10) · **371,250** (÷2) |
| **WAVE** | 50 MHz | 1 | 12,000 | 600,00 | **37,500** (÷16) |

Las cuatro del dominio MSX salen del **mismo VCO** (1080 MHz) → **fases
conocidas entre sí por construcción**, que es justo la propiedad que en la 60K
costó sangre conseguir (ver los comentarios de `top.v:277-310` sobre el
`CLKDIV`/`PLLA` y el desalineado del gearbox del `OSER10`).

> `WAVE` (37,5 MHz, OPL4, Hito 8) lleva MMCM propio porque no sale del VCO de
> 1080 (1080/37,5 = 28,8, no entero). Igual que en Gowin tenía su propia salida.

> **Presupuesto de MMCM — comprobado el 2026-08-20.** El XC7K325T tiene
> **10 `MMCME2_ADV`** (más los `PLLE2_ADV`, que sirven para lo que no necesite
> fase fina). La cascada de arriba gasta **4 de 10**. Hay margen, pero no es
> infinito: conviene no repartir MMCM a capricho por los submódulos al portar
> los `pll_*.v` del §5.2 —`pll_86`, `pll_3375`, `pll_12`— sino ver cuáles
> pueden colgar de una salida ya existente. En la 60K esto no se planteaba
> porque los `rPLL` de Gowin son otro recurso y otra cuenta.

> **Escalón REF verificado en implementación** (Hito 0, 2026-08-20): el MMCM
> cayó en `MMCME2_ADV_X0Y2`, salida por `BUFGCTRL_X0Y0`, y el informe de
> relojes post-route da **37,037 ns = 27,000 MHz exactos**. La entrada de
> 50 MHz entra por `IOB_X0Y126` = pin **F22**, como decía §1.1. El resto de la
> cascada (SYS, VID, WAVE) sigue sin implementar.

> A 371,25 MHz el enlace TMDS son 742,5 Mb/s por carril, dentro de lo que da un
> `OSERDESE2` en banco HR de un K7 **-1**. Confirmar con el informe de timing
> real, no con esta nota.

---

## 4. La decisión de memoria (el corazón del puerto)

### 4.1 Situación actual

`fpga/src/memory.v` (`memory_ctrl`, 731 líneas) es un secuenciador SDR a pelo
sobre el módulo Winbond W9825G6KH de la Console. Arbitra CPU vs VDP por
`video_dhclk`/`video_dlclk`, hace el refresco a mano y garantiza el
"fix MG2" (el refresco nunca roba una escritura del VDP). El mapa es de 23 bits
(8 MB), con bancos:

| Banco | `ram_addr[22:21]` | Contenido | Tamaño |
|---|---|---|---|
| A/B | `00`/`01` | RAM del mapper MSX | hasta 4 MB |
| C | `10` | MegaRAM | 2 MB |
| D | `11` | BIOS, SubROM, MegaROM, Kanji, WiFi, logo | ~1 MB |

Más VRAM (128 KB V9958 / 256 KB V9968) por un puerto aparte.

### 4.2 Lo que cabe en BRAM del K325T

**Presupuesto: 1,95 MB de BRAM.**

| Config | Mapper | VRAM | ROMs | Total | ¿BRAM? |
|---|---|---|---|---|---|
| **Mínima (Hito 4)** | 256 KB | 128 KB (V9958) | ~64 KB | **~450 KB** | ✔ sobra |
| **Básica (Hito 5)** | 512 KB | 128 KB | ~64 KB | **~700 KB** | ✔ cómoda |
| **V9968 (Hito 6)** | 512 KB | 256 KB | ~64 KB | **~830 KB** | ✔ cabe |
| Completa | 4 MB | 256 KB | 1 MB + 2 MB OPL4 | ~7,3 MB | ✖ → DDR3 |

Conclusión: **hasta el Hito 6 inclusive no hace falta memoria externa.**
La DDR3 entra sólo cuando lleguen MegaRAM, mapper de 4 MB y la wavetable
YRW801 del OPL4.

### 4.3 Estrategia

Crear un `memory_bram.v` que **respete exactamente el contrato
`ram_*`/`vram_*` de `memory_ctrl`** (documentado ya en
`docs/MEMORY_CONTRACT.md`) y lo sirva desde BRAM inferida, con `ram_busy`
siempre a 0 (latencia fija). Es un módulo pequeño y simulable contra el mismo
banco de pruebas.

Después, en el Hito 7, un `memory_ddr3_mig.v` con el **mismo contrato**, detrás
de MIG. El core no se entera: se cambia el backend, no el MSX. Esto es
literalmente lo que el pack pedía en su §7 ("board-neutral memory interface"),
sólo que el interfaz neutro **ya existe** — es el de `memory_ctrl`.

---

## 5. Mapa de dependencias

### 5.1 Reutilizable tal cual (no tocar)

Todo el MSX propiamente dicho. El barrido de primitivas Gowin sobre el árbol
completo devuelve **sólo 30 ficheros contaminados**, y ninguno es lógica MSX:

- `fpga/G80A/` — Z80 + sistema MSX
- `fpga/v9968/` — VDP V9968 (salvo 2 line buffers, §5.2)
- `fpga/tn_vdp_v3_v9958/` — VDP V9958 (salvo `serializer.sv` y `clockdiv.v`)
- `fpga/jtopl/`, `fpga/jt10/` — OPLL / Y8950
- `fpga/opl3/` — OPL3 (salvo `mem_simple_dual_port_bram.sv`)
- `fpga/opl4wave/` — motor PCM OPL4 (salvo `YMF278B.sv`)
- `fpga/PSG_YM2149/`, `src/psg_filter.v`, `src/scc_*.v`, `src/megaram.v`
- `src/usb_direct/usb_hid_host.v` — **host USB soft, RTL puro**: sólo necesita
  `usb_dp`/`usb_dm` y 12 MHz. Portable sin cambios.
- `src/wondertang/sd_reader.sv` — lector SD
- `src/flash_rw.v` — SPI bit-bang (`SCLK/CS/MISO/MOSI`), portable ⚠ ver §5.2
- `src/msx_mouse.v`, `src/fan_ctrl.v`, `src/monostable/`, `src/denoise/`

### 5.2 Glue de plataforma a reescribir

| Fichero | Qué lleva de Gowin | Trabajo |
|---|---|---|
| `tn_vdp_v3_v9958/src/hdmi/serializer.sv` | `OSER10` + `` `define GW_IDE `` | **Quitar el define** — la rama `OSERDESE2` ya está escrita |
| `video720/msx2hdmi*.sv` | `ELVDS_OBUF tmds_bufds[3:0]` | → `OBUFDS` con `TMDS_33` |
| `video720/plla/pll_27.v`, `pll_74.v` | `PLLA` | → MMCM (§3) |
| `msx_console60k/src/gowin_pll/` | `Gowin_PLL` + `PLL_INIT`/mDRP | → MMCM (§3) |
| `src/pll_86.v`, `src/pll_3375.v`, `src/usb_direct/pll_12.v` | `rPLL`/`PLLA` | → MMCM/PLLE2 |
| `tn_vdp_v3_v9958/src/clockdiv.v` | `CLKDIV` | Innecesario: el MMCM da todas las salidas |
| `v9968/vdp_upscan_line_buffer.v`, `vdp_video_ram_line_buffer.v` | `SDPB`/`SP` | → BRAM inferida o XPM |
| `opl3/mem_simple_dual_port_bram.sv` | `SDPB` | → BRAM inferida |
| `opl4wave/YMF278B.sv` | primitivas Gowin | → BRAM inferida |
| `src/memory.v` | secuenciador SDR | → `memory_bram.v` (§4.3) |
| `src/memory_ddr3.v`, `wave_ddr3.v`, `v9968_ddr3_backend.v`, `adpcm_sdram.v` | `DDR3_Memory_Interface_Top` | → MIG (Hito 7+) |
| `constraints/*.cst`, `*.sdc` | formato Gowin | → `.xdc` |
| `fpga/build.tcl` | `gw_sh` | → script Vivado no-project |
| `top.v` | pinout, `GSR`, `ro_osc`, `ws2812` | Reescribir la envoltura de placa; el cuerpo se conserva |

### 5.3 IP de fabricante a sustituir

| Gowin | Xilinx |
|---|---|
| `Gowin_PLL` / `PLLA` / `rPLL` | `MMCME2_ADV` (Clocking Wizard) |
| `OSER10` | `OSERDESE2` ×2 en cascada (**ya escrito**) |
| `ELVDS_OBUF` | `OBUFDS` + `TMDS_33` |
| `SP` / `SDPB` / `DPB` | BRAM inferida o XPM_MEMORY |
| `DDR3_Memory_Interface_Top` | MIG 7 Series |
| `CLKDIV`, `CLKDIV2` | salidas del MMCM |
| — | ⚠ **`STARTUPE2`**: en 7-series el `CCLK` de la flash QSPI **sólo** es accesible por esta primitiva tras la configuración. `flash_rw.v` es portable, pero su `SCLK` hay que sacarlo por `STARTUPE2`. **Detalle fácil de pasar por alto.** |

---

## 6. Asignación de los tres PMOD

| PMOD | Uso | Por qué |
|---|---|---|
| **J13** | **HDMI** | Único con 4 pares válidos **en un solo banco** (14) → una región de reloj para los 4 `OSERDESE2` |
| **J12** | **microSD** | Sus 3 pares válidos dan de sobra; SD es *single-ended* (CS/MOSI/MISO/SCK, o 4-bit) y el par roto pin4/pin10 da igual |
| **J11** | **USB** | 2 puertos × (D+/D−) = 4 señales *single-ended*; sobran pines |

**Antes de conectar nada**: hay que leer la serigrafía del PMOD HDMI concreto
para saber qué par lleva CLK y cuáles D0/D1/D2, y **cotejar la polaridad** —
recuérdese que en J13 los pares pin1/7 y pin2/8 están **invertidos** (el pin
bajo es la mitad *N*). Si el PMOD no permite recolocar, se corrige en RTL
intercambiando las mitades del `OBUFDS` o invirtiendo el dato TMDS.

---

## 7. Fases

Cada hito tiene un **criterio de salida binario**. No se pasa al siguiente sin
cumplirlo. Nada de integrar dos subsistemas sin validar a la vez.

### Hito 0 — Andamiaje (sin hardware) ✅ **SUPERADO 2026-08-20**
- Estructura `platform/qmtech_k7/` separada de `core/`.
- Script de build Vivado no-project reproducible.
- `board.xdc` con: reloj 50 MHz en F22, 3 LEDs, 2 botones, los 3 PMOD.
- **Salida**: `write_bitstream` termina sin errores. ✅

> Resultado: 0 errores, 0 critical warnings, DRC sin violaciones.
> **WNS = 33,885 ns · WHS = 0,114 ns.** Utilización de referencia (que es
> el "cero" contra el que se medirá todo lo que venga): 7 LUTs, 28 FFs,
> 1 MMCM, 1 BUFG, 3 IOBs. Los LEDs y botones siguen sin constreñir: el
> parpadeo sale por `pmod1[0]`, ver `board.xdc`.

### Hito 1 — Vida
- Parpadeo de LED desde el MMCM_SYS (§3), no desde el pad.
- **Salida**: LED parpadea a ritmo medido; JTAG programa; DONE sube.

### Hito 2 — HDMI en solitario ⚠ *el riesgo que hay que matar primero*
- Barras de color 720p60 por J13, con `serializer.sv` **sin** `` `define GW_IDE ``
  + `OBUFDS`/`TMDS_33` + MMCM_VID.
- Reutilizar `fpga/test_hdmi/` como banco de pruebas.
- **Salida**: un monitor real engancha 1280×720@60 y muestra barras estables
  ≥10 min, en 10 de 10 arranques en frío. Y **queda cerrada la duda de
  `PUDC_B`** (§1.3).

> Se pone antes que el MSX **a propósito**: es lo único con incertidumbre
> física real (pares invertidos, `PUDC_B`, calidad del PMOD, el propio cable).
> Si algo obliga a mover el HDMI a J11, mejor saberlo aquí que con el MSX
> encima.

### Hito 3 — Flash y consola de depuración
- `flash_rw.v` sobre la QSPI **vía `STARTUPE2`**; leer el JEDEC ID.
- `dbg_uart.v` por JP5 o un PMOD libre.
- **Salida**: se lee el ID correcto de la flash y sale texto por el UART.

### Hito 4 — MSX mínimo, **todo en BRAM**
- G80A + `memory_bram.v` + V9958 + 256 KB de mapper.
- BIOS desde la flash (mismo esquema de *pack* que hoy, §4 del README).
- **Salida**: arranca C-BIOS o el BIOS propio y se ve el prompt de MSX BASIC
  por el HDMI del Hito 2.

> **Éste es el "core MX básico" que pedías.** Sin DDR3, sin SDRAM, sin SD, sin
> USB, sin audio. Un MSX que enciende y muestra el BASIC.

### Hito 5 — Teclado y PSG
- `usb_hid_host` ×1 en J11 + `usb_kbd_decode`; PSG + `psg_filter`.
- Salida de audio: decidir vía (I²S por PMOD, o PWM/sigma-delta por JP5).
- **Salida**: se teclea `PRINT "HOLA"` y suena el `BEEP`.

### Hito 6 — Almacenamiento
- `sd_reader` en J12 + Nextor + mapper a 512 KB.
- **Salida**: arranca Nextor desde microSD y lista un directorio.

> Al final del Hito 6 hay un **MSX2+ usable** que nunca ha tocado la DDR3.

### Hito 7 — DDR3 (MIG) y expansión de memoria
- MIG 7 Series contra `MT41K128M16JT-125`; test de memoria **aislado** primero.
- `memory_ddr3_mig.v` con el contrato de §4.3.
- Desbloquea: mapper 4 MB, MegaRAM, Kanji.
- **Salida**: test de memoria limpio sobre los 256 MB, y luego el MSX arrancando
  con MegaRAM sobre DDR3.

### Hito 8 — Audio completo y V9968
- SCC/SCC+, OPLL, Y8950 + ADPCM, OPL3, OPL4 + wavetable YRW801 en DDR3.
- Migrar del V9958 al V9968 (VRAM 256 KB; ya existe `v9968_ddr3_backend.v`).
- Gamepads USB, ratón, menú de arranque, turbo.
- **Salida**: paridad de funciones con el core v3.0 de la 60K.

### Hito 9 — CM4 (opcional, sólo si todo lo anterior es estable)
- Enlace por las E/S de bancos 15/32/33 que llegan al zócalo (§1.4).
- Servicios: OSD, red, Wi-Fi/BT, USB avanzado, actualizaciones.
- **Invariante**: la máquina debe seguir funcionando **sin CM4 puesto**.

### Fuera de plan (por ahora)
- **OpenXC7 / UberDDR3**: interesante, pero es una segunda cadena de
  herramientas sobre un puerto aún no validado. Vivado primero como referencia
  de timing; el flujo abierto cuando haya una base estable con la que comparar.
  *(Reconfirmado el 2026-08-20 al cerrar el riesgo 6: con BASIC gratis, Vivado
  sigue siendo la referencia. OpenXC7 queda como plan B real y documentado si
  el nivel gratuito estorbase más adelante.)*
- **1080p**, R800/Turbo-R, V9990: para cuando haya utilización real medida.

---

## 8. Riesgos, ordenados por lo que de verdad puede doler

1. **`PUDC_B` en J13 pin8** (§1.3). Mitigación: es el criterio de salida del
   Hito 2. Plan B: mover el HDMI a J11 asumiendo el cruce de bancos 15/14.
2. **Polaridad invertida en 2 de los 4 pares de J13.** Mitigación: se corrige en
   RTL; hay que detectarlo, no sufrirlo.
3. **BUFG a 371,25 MHz.** Los `OSERDESE2` querrían `BUFIO`/`BUFR` (locales de
   región). Con J13 todo en el banco 14 = una región, así que `BUFIO` es
   viable. Con J11 (dos bancos) haría falta `BUFG` global, que en K7-1 debería
   aguantar pero hay que comprobarlo con el informe de timing real.
4. **Estimaciones de BRAM** (§4.2). Son cálculos, no síntesis. El primer
   `report_utilization` manda. Si no cupiera, bajar el mapper a 256 KB.
5. **Utilización LUT.** El pack ya avisa: **LUT4 de Gowin ≠ LUT6 de Xilinx**.
   No hay ratio fijo. El K325T tiene ~203,8 K LUT6 frente a ~59,9 K LUT4 del
   GW5AT-60; sobra margen, pero la cifra real sale de P&R, no de una regla de
   tres.
6. ~~**Licencia de Vivado para el XC7K325T.**~~ **CERRADO — 2026-08-20, y sale
   bien.** El aviso del plan («no fiarse de hilos de foro antiguos») era
   correcto, y se aplica también a la documentación antigua: la tabla de
   UG973 2024.1 dice que Vivado ML Standard sólo cubre `XC7K70T` y `XC7K160T`,
   y **ese dato ya no vale**. En **Vivado 2026.1** (junio de 2026) AMD sustituyó
   Standard/Enterprise por niveles —BASIC, CORE, PRO, ENTERPRISE, GOLD— y
   **BASIC es gratuito y cubre todas las 7 Series, Kintex-7 incluido**. El
   `XC7K325T` entra. AMD además rectificó públicamente el plan inicial de dejar
   BASIC sólo para Windows: Linux sigue en todos los niveles.

   **El plan sigue en pie tal como está escrito**: MIG, Clocking Wizard y
   `OSERDESE2` están disponibles. Lo que BASIC sí recorta, y afecta al método:

   | Recorte de BASIC | Dónde duele | Mitigación |
   |---|---|---|
   | **XSIM limitado** | Simular el core MSX entero | Icarus + GHDL + Verilator, que es como ya están montados los `tb/` heredados |
   | **1 sola ILA, 5 sondas (1024 bits)** | Depurar en placa los Hitos 2 y 4 | `dbg_uart.v` (Hito 3), que además es más barato en recursos |
   | **Renovación anual** | Se suspende la herramienta si caduca | Apuntarlo en el calendario |

   > Verificación definitiva pendiente y trivial: instalar y comprobar que
   > `xc7k325tffg676-1` aparece en la lista de dispositivos. Hasta entonces
   > esto son fuentes secundarias, no la tabla del fabricante leída de primera
   > mano.
7. **Alimentación.** El pack cita 6 V/2 A. Con K325T + DDR3 + 3 PMOD + (quizá)
   CM4, medir consumo antes de dar por buena la fuente.

---

## 9. Lo primero que hay que hacer

### 9.0 Toolchain — decidido: Vivado 2026.1 BASIC

Riesgo 6 cerrado a favor. **Vivado 2026.1, nivel BASIC (gratuito), cubre el
XC7K325T.** No hay que elegir cadena de herramientas ni cambiar de placa: el
plan de §3 (MMCM), §5.3 (`OSERDESE2`, `OBUFDS`, MIG) y §7 (los nueve hitos) va
tal cual.

Lo único que el nivel gratuito cambia es **cómo se verifica**, no qué se
construye — y empuja hacia donde este proyecto ya estaba:

- **Simulación fuera de Vivado.** XSIM en BASIC es "limitado". Da igual: los
  bancos de pruebas heredados del 60K (`core/video720/tb/run.sh`) ya son de
  **Icarus**, y el core es mixto VHDL+Verilog, que Icarus solo no cubre →
  **Icarus + GHDL + Verilator**.
- **Depuración por UART antes que por ILA.** BASIC da **una sola ILA con 5
  sondas**. El Hito 3 ya pone `dbg_uart.v` justo por delante del MSX: esa
  decisión, que era de orden lógico, ahora también es de licencia.
- **Renovación anual** del fichero de licencia.

### 9.1 En este orden

1. **Instalar Vivado 2026.1 BASIC y confirmar que `xc7k325tffg676-1` sale en la
   lista de dispositivos.** Es la verificación de primera mano del riesgo 6;
   todo lo anterior son fuentes secundarias.
2. Montar la cadena de simulación abierta (Icarus, GHDL, Verilator, GTKWave) y
   revalidar un `tb/` heredado del 60K como prueba de que funciona.
3. **Hito 0 completo**: `write_bitstream` sin errores. No hace falta la placa.
4. Cuando llegue la placa: serigrafía de J11/J12/J13 contra el esquemático,
   serigrafía del PMOD HDMI (qué par es CLK y cuáles D0/D1/D2), y si `VCCO_12`
   es seleccionable por jumper.
5. Conseguir un programador JTAG: J1 es una cabecera, y la placa —a diferencia
   de las Tang— casi seguro **no lleva USB-JTAG integrado**. Confirmar al
   recibirla.

---

## Anexo — Procedencia de los datos

Los pinouts de §1 no vienen del manual ni de suposiciones: se extrajeron
programáticamente del PDF del esquemático. El PDF usa una fuente subconjunto con
codificación CID de 2 bytes desplazada `+0x1D`; se reconstruyó el `CMap`
(`beginbfrange`) y se emparejaron bola y nombre de pin por coordenada exacta de
dibujo, obteniendo **400 correspondencias bola → nombre Xilinx**. Los nets de
los PMOD se leyeron por posición relativa a los símbolos de J11/J12/J13.

Cualquier dato de §1 es, por tanto, **verificable contra el PDF oficial** — pero
sigue siendo lectura de un esquemático rev. V01: **el multímetro en la placa
manda sobre el papel**, como enseñó el episodio de los USB-A de la Console 60K
(`BASE_MINIMA_60K_PLAN.md` §A.1: *"el esquemático de Sipeed está MAL, la verdad
es el .cst"*).
