\ Embedded Systems - Sistemi Embedded - 17873
\ Salvatore Lucio Auria 0737598 - Fabio Villa 0744495 - Ingegneria Informatica LM 
 
\main.f 

\Word principale nel quale vengono eseguite le istruzioni di controllo e sensoristica
\ Il ciclo si interrompe qualora venga premuto il tasto presente nella breadboard
: WATER_SYSTEM ( -- )
    INIT
    CALIBRATION
    PREPARE
    BEGIN 
        HUMIDITY-PERCENTAGE
        DUP
        PRINT-PERCENTAGE
        ?THRESHOLD
        ?BUTTON-PRESSED
    0 = UNTIL
    P-EXIT ;

