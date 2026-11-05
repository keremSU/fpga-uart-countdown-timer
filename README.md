# FPGA UART Countdown Timer

> Individual project, developed earlier and added to GitHub later.

A Verilog countdown timer for a Gowin GW1NR-9 FPGA board (27 MHz clock). The start time is typed over a serial (UART) connection, shown on a 4-digit 7-segment display as `MM:SS`, and counted down to zero after a button press.

## How it works

- **UART receiver** (`uart_rx.v`): 115200 baud, built as a state machine. Digits `0–9` sent from a serial terminal shift into the display from the right.
- **1 Hz tick**: a clock divider generates one tick per second from the 27 MHz system clock.
- **Start button**: passed through a two-stage synchronizer and a falling-edge detector so one press registers once.
- **Countdown logic**: BCD minutes and seconds with correct rollover (for example `10:00` → `09:59`). The timer stops at `00:00`.
- **Display**: multiplexed 7-segment output, with the decimal point used as the `:` separator.
- The last received byte is also shown on the LEDs for debugging.

## Files

```
src/serial_template.v   top module: tick, button, countdown FSM, display mux
src/uart_rx.v           UART receiver
src/constraints.cst     pin constraints
countdown_timer.gprj    Gowin IDE project file
```

## Build

Open `countdown_timer.gprj` in Gowin EDA, run synthesis and place & route, then program the board. Send digits from any serial terminal at 115200 baud.
