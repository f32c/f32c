  100 VIDMODE 1
  110 FOR i = 0 TO 255
  120   FOR j = 0 TO 255 
  130     INK j * 256 + i
  140     PLOT i + 16, j + 16
  150   NEXT j
  160 NEXT i
  170 INK "white"
  180 FOR i = 0 TO 15
  190   IF i < 10 THEN x$ = STR$(i) ELSE x$ = CHR$(i + 55)
  200   TEXT i * 16 + 18, 6, x$ + "0"
  210   TEXT i * 16 + 18, 272, x$ + "0"
  220   TEXT 3, i * 16 + 19, x$ + "0"
  230   TEXT 274, i * 16 + 19, x$ + "0"
  240 NEXT i
