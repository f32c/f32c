  100 VIDMODE 0
  110 FOR i = 0 TO 15
  120   FOR j = 0 TO 15
  130     INK i + j * 16
  140     RECTANGLE i * 16 + 16, j * 16 + 16, i * 16 + 31, j * 16 + 31, 1
  150   NEXT j
  160 NEXT i
  170 INK "white"
  180 FOR i = 0 TO 15
  190   IF i < 10 THEN x$ = STR$(i) ELSE x$ = CHR$(i + 55)
  200   TEXT i * 16 + 22, 6, x$
  210   TEXT i * 16 + 22, 272, x$
  220   TEXT 9, i * 16 + 19, x$
  230   TEXT 274, i * 16 + 19, x$
  240 NEXT i
