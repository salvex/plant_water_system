\ Embedded Systems - Sistemi Embedded - 17873
\ set-up del sistema 
\ Salvatore Lucio Auria 0737598 - Fabio Villa 0744495 - Ingegneria Informatica LM 
 
\setup.f 

\ Word di alto livello atta ad inizializzare 
\ i2c,ADC,tasto di uscita ed LCD
: INIT ( -- ) 
    EN-BSC
    ADS1115
    D SET-INPUT
    SETUP-LCD ;

\Word di alto livello necessaria alla calibrazione di sistema.
\Il sensore capacitivo dovrà prelevare valore minimo "Dry" e valore massimo "Wet"
\affinchè le misurazioni possano essere effettuate correttamente.
\Intercorreranno 10 secondi per ogni fase di calibrazione
: CALIBRATION ( -- ) 
    CLEAR-LCD
    CALIB-TEXT
    DRY
    250000 DELAY
    !DRY-VAL
    CURSOR-LSHIFT
    WET
    250000 DELAY
    !WET-VAL
    CURSOR-LSHIFT
    OK
;

: PREPARE ( -- ) \Word di alto livello dove vengono stampati i caratteri "Umidità" e "Pompa"
    CLEAR-LCD
    POMPA 
    OFF 
    LINE-2
    UMIDITA
    C 1 SET-CURSOR 
    PERCENTAGE-SYM ;

: PUMP-ON ( -- ) \Word in grado di attivare la pompa, connessa tramite Relay
   6 SET-OUTPUT ;

: PUMP-OFF ( -- ) \Word in grado di disattivare la pompa, connessa tramite Relay
   6 SET-INPUT ;

: ?BUTTON-PRESSED ( -- status ) \Preleva lo status del GPIO 13 dove vi è connesso il tasto
   D GET-INPUT ;

: ?THRESHOLD ( percentage -- ) \ Controlla se la soglia del 30% di umidità è stata superata
    1E < 
    IF
        PUMP-ON
        1000 DELAY
        0 UPDATE-S-PUMP  
    ELSE 
        PUMP-OFF
        1000 DELAY
        1 UPDATE-S-PUMP 
    THEN ;
