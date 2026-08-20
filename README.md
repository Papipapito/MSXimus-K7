<h1 align="center">MSXimus-K7</h1>
<p align="center"><b>Un MSX2+ en FPGA sobre QMTECH Kintex-7 XC7K325T</b></p>
<p align="center">
  <img alt="estado" src="https://img.shields.io/badge/estado-Hito%200%20superado-brightgreen">
  <img alt="fpga" src="https://img.shields.io/badge/FPGA-Xilinx%20XC7K325T-blue">
  <img alt="licencia" src="https://img.shields.io/badge/licencia-GPLv3-orange">
</p>

---

## Qué es esto

El puerto de [**MSXimus**](https://github.com/Papipapito/MSXimus) —MSX2+ completo
sobre Tang Console 60K (Gowin GW5AT-60)— a una **QMTECH Kintex-7 Development
Board** con XC7K325T.

**Repo aparte, y no por capricho:** cambia la toolchain entera (Vivado en vez
de Gowin IDE), el formato de constraints (`.xdc` vs `.cst`), el bitstream
(`.bit` vs `.fs`) y las instrucciones de flasheo. Y sobre todo: el core del 60K
está **publicado y validado en hardware**, y un puerto exploratorio de meses no
debe poder romperlo.

> **Esto no es un fork en plano.** El RTL del MSX vive en `core/` y es
> *idéntico* al del 60K; lo específico de placa vive en `platform/`. Solo ~30
> ficheros del árbol original eran específicos de Gowin, y ninguno era lógica
> MSX. Mantener esa separación es lo que permitirá converger más adelante —
> copiar en plano cerraría esa puerta.

## Estado

**Hito 0 — superado el 2026-08-20.** El criterio de salida era *«`write_bitstream`
termina sin errores»*, y termina:

```
Vivado 2026.1 BASIC · xc7k325tffg676-1
synth → opt → place → phys_opt → route → bitstream
0 errores · 0 critical warnings · DRC sin violaciones
WNS = 33,885 ns    WHS = 0,114 ns
7 LUTs · 28 FFs · 1 MMCM · 1 BUFG · 3 IOBs
MMCME2_ADV_X0Y2 → BUFGCTRL_X0Y0 → 37,037 ns = 27,000 MHz exactos
```

Ese último renglón es el primer escalón de la cascada de relojes del §3 del
plan, y ya no es un cálculo: es lo que implementó el P&R.

- [x] Estructura `core/` + `platform/` + `reference/`, ya poblada
- [x] `board.xdc` con reloj y los tres PMOD **verificados contra el esquemático**
- [x] Build no-project de Vivado, reproducible
- [x] `top.sv` del Hito 1 (parpadeo desde el MMCM)
- [x] **Toolchain resuelta y verificada de primera mano**: Vivado **2026.1 nivel
      BASIC** (gratuito) cubre todas las 7 Series; `xc7k325tffg676-1` presente
- [ ] Pines de LEDs y botones — **sin verificar**, ver `board.xdc`
- [ ] Cadena de simulación abierta (Icarus + GHDL + Verilator) — el core es
      mixto VHDL/Verilog y XSIM viene capado en BASIC
- [ ] Programador JTAG — J1 es cabecera; la placa casi seguro no lleva USB-JTAG

**Hito 1 — bloqueado por hardware.** El bitstream existe; falta la placa y un
programador JTAG para cargarlo y medir el parpadeo.

El plan completo, con los nueve hitos y sus criterios de salida:
[`docs/PORT_K325T_PLAN.md`](docs/PORT_K325T_PLAN.md).

## La idea en una línea

**BRAM primero, DDR3 después.** El K325T tiene ~1,95 MB de BRAM; un MSX2+
básico (512 KB de mapper + 128 KB de VRAM + BIOS) cabe holgadamente. Así el
primer MSX que arranque no necesita ni MIG, ni SDRAM, ni DDR3 — y el bring-up
es una escalera corta y verificable en vez de un salto con tres subsistemas
analógicos sin validar a la vez.

## Hardware

| | Qué | Notas |
|---|---|---|
| **Necesario** | QMTECH Kintex-7 Development Board | XC7K325T-1FFG676, 50 MHz, 256 MB DDR3 x16 |
| **Necesario** | PMOD HDMI | En **J13** — único con 4 pares diferenciales en un solo banco |
| Opcional | PMOD microSD | En **J12** |
| Opcional | PMOD USB | En **J11** |
| Opcional | Raspberry Pi CM4 | Hito 9. La máquina **debe** funcionar sin él |

Los conectores HDMI, los USB-A y la micro-SD **de la placa son del CM4, no del
FPGA** — verificado en el esquemático. Por eso las E/S van por PMOD.

### Reparto de PMOD, y por qué

Los tres están cableados como PMOD diferencial (**pin N hace par con pin N+6**),
pero no son intercambiables:

| PMOD | Pares válidos | Uso |
|---|---|---|
| **J13** | 4, **todos en el banco 14** | **HDMI** — una sola región de reloj |
| **J12** | **solo 3** — pin4/pin10 no son par | microSD (single-ended) |
| **J11** | 4, repartidos entre bancos 15 y 14 | USB (single-ended) |

⚠️ En J13 hay **dos pares con la polaridad invertida**, y el pin 8 es `PUDC_B`
(pin de configuración). Lee `board.xdc` antes de conectar nada.

## Compilar

```bash
vivado -mode batch -source platform/qmtech_k7/build/build.tcl
```

Salidas e informes en `platform/qmtech_k7/build/out/`. El script avisa si el
timing no cierra: **los informes de P&R mandan sobre cualquier estimación**.

Vale **Vivado 2026.1 en su nivel BASIC**, que es gratuito. Dos matices del
nivel gratuito que marcan el método del proyecto: XSIM viene limitado —por eso
la simulación va por Icarus/GHDL/Verilator, como ya venían los `tb/` heredados—
y solo hay una ILA con 5 sondas, por lo que la depuración en placa se apoya en
`dbg_uart.v` (Hito 3) antes que en ChipScope.

## Simular

La simulación **no** va por Vivado. Va por la cadena abierta en WSL2, por dos
razones: XSIM viene capado en BASIC, y buena parte del core es **VHDL** —G80A
(el Z80 entero), `PSG_YM2149`, el VDP V9958, `src/ocm/`— que Icarus no toca.

```bash
wsl -d Ubuntu-24.04 -- bash -lc 'source ~/oss-cad-suite/environment && bash /mnt/c/Users/alber/proyectosAI/msx/MSXimus-K7/core/video720/tb/run.sh'
```

Herramientas: **OSS CAD Suite** (`~/oss-cad-suite/`) — Icarus 14.0, GHDL 7.0-dev,
Verilator 5.051, GTKWave, Yosys, cocotb. Ojo: **la build de Windows de OSS CAD
Suite no incluye GHDL**; de ahí que la simulación viva en WSL y no nativa.

Dentro de WSL hay una función `ossenv` que activa la cadena **bajo demanda**:

```bash
ossenv          # activa iverilog, ghdl, verilator, yosys, gtkwave
```

No se hace `source` en el arranque **a propósito**: OSS CAD Suite mete su propio
Python, Tcl y binutils en el `PATH` y ensombrece los del sistema.

> GHDL necesita un compilador de C para enlazar; si no, falla con
> `installation problem: cc not found`. Ubuntu 24.04 ya trae `gcc`.

### Estado de la simulación por módulo

Verificado el 2026-08-20 contra el core heredado:

| Módulo | Herramienta | Estado |
|---|---|---|
| `core/video720/msx2hdmi.sv` | Icarus | ✅ **20.671.200 checks, 0 errores** (NTSC/PAL, 4:3 y 16:9) |
| `core/G80A/` — **el Z80 entero** | GHDL | ✅ los 6 ficheros analizan y `T80s` **elabora** |
| `core/v9968/vdp.v` | Verilator | ✅ elabora 22 módulos; solo avisos informativos |
| `core/denoise/`, `core/src/ocm/fifo.vhd` | GHDL | ✅ con `--std=93c` a secas |
| `core/PSG_YM2149/YM2149.vhdl` | GHDL | ⚠ pendiente |
| `core/monostable/` | GHDL | ⚠ pendiente |

**El core necesita flags de GHDL distintos según el módulo**, y conviene saberlo
antes de pelearse con ello. G80A los necesita así:

```bash
ghdl -a --std=93c --ieee=synopsys -frelaxed-rules core/G80A/*.vhd
```

`YM2149.vhdl` **exige** `--ieee=synopsys` (usa `std_logic_unsigned`, que sin esa
opción no existe), pero con ella su línea 155 se vuelve ambigua: el `=` queda
sobrecargado entre `std_logic_unsigned` y `std_logic_1164`. Es un choque clásico
de VHDL heredado, no un fallo del fichero.

## Estructura

```
core/                      RTL portable — idéntico al MSXimus del 60K
  G80A/ v9968/ tn_vdp_v3_v9958/ jtopl/ jt10/ opl3/ opl4wave/
  PSG_YM2149/ video720/ src/ denoise/ monostable/
platform/qmtech_k7/        todo lo específico de esta placa
  top.sv                   top del hito en curso
  board.xdc                pines (procedencia documentada dentro)
  build/build.tcl          build no-project
reference/tang60k/         el 60K validado, SÓLO para consultar al portar
  top.v                    la envoltura de placa Gowin que hay que reescribir
  constraints/             los .cst/.sdc de origen
  test_hdmi/ test_sdram/   bancos de pruebas reutilizables (plan Hito 2)
docs/PORT_K325T_PLAN.md    el plan: 9 hitos con criterios de salida
docs/BASE_MINIMA_60K_PLAN.md  lo aprendido en el 60K (por qué DDR3 ≠ RAM del Z80)
```

`reference/tang60k/` **no entra en ningún build**. Está para poder leer el core
que sí funciona mientras se porta, sin tener que saltar de repositorio. Las
salidas del Gowin IDE (`impl/`, `.fs`, `.vg`, IP de reloj generada) están
excluidas por `.gitignore`: eran ~150 MB y uno de sus ficheros superaba el
límite duro de 100 MB de GitHub.

## Licencia y procedencia

**GPLv3**, heredada de MSXimus. El core incluye trabajo de terceros con sus
propias licencias y condiciones —OPL3 (LGPL-3.0), el motor wavetable de srg320
(BSD-3/MAME, con permiso expreso), jtopl de Jotego, el V9968 de HRA!—.

`UPSTREAM.md` y `core/v9968/ORIGEN.txt` documentan cada procedencia y cada
parche local. **Se conservan íntegros**: no son burocracia, son las condiciones
bajo las que se puede usar este código.

Las ROMs del MSX y `yrw801.rom` pertenecen a sus dueños y **no se distribuyen
aquí** — el `.gitignore` está puesto para que no entren por accidente.
