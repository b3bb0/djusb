# HARDWARE INSTABLE EXPERIMENTAL

<img width="1206" height="779" alt="image" src="https://github.com/user-attachments/assets/65079edf-0de6-4389-b194-14672d4979f4" />
PS: missing kill switchs + motors not routed yet

## PIN MAPPING
*Left corner (C)*
- HX711 S1L: PB0=DT, PB1=SCK
- HX711 S2L: PB2=DT, PB3=SCK
- Motor-L: PD6=DIR_L, PD5=PWM_L (OC0B)
- Limits-L (active-low): PC0=TOP_L, PC1=BOT_L

*Right corner (D)*
- HX711 S1R: PD2=DT, PD7=SCK
- HX711 S2R: PB4=DT, PB5=SCK
- Motor-R: PD4=DIR_R, PD3=PWM_R (OC2B)
- Limits-R (active-low): PC2=TOP_R, PC3=BOT_R

## Registering abd regularions
- .equ THRESH    = 6000     ; deadband in counts for |diff|
- .equ KP_SHIFT  = 11       ; PWM ~ |diff| >> KP_SHIFT
- .equ PWM_MIN   = 60
- .equ PWM_MAX   = 200
- .equ AVG_NLOG2 = 2        ; 2 -> average 4 samples (2^2)

## Build
```
avr-gcc -mmcu=atmega328p -x assembler-with-cpp -o canopy_avg.elf canopy_avg.S

avr-objcopy -O ihex -R .eeprom canopy_avg.elf canopy_avg.hex

avrdude -c usbasp -p m328p -U flash:w:canopy_avg.hex
```
