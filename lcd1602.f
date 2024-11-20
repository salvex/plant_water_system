\ Embedded Systems - Sistemi Embedded - 17873
\ configurazione LCD 1602   
\ Salvatore Lucio Auria 0737598 - Fabio Villa 0744495 - Ingegneria Informatica LM 
 

\lcd1602.f

3 CONSTANT MSB_NUM_ASCII \ bit più significativi nella codifica dei numeri esadecimali in ASCII


\ Il dispositivo LCD1602 16x2 consente di visualizzare numeri,caratteri e simboli tramite 
\ codifica ASCII. Esso è connesso all'exapnder I2C PCF8574 tramite la seguente configurazione: 
\ P0 (PCF8574) -> RS (LCD) -- P1 (PCF8574) -> R/W (LCD) -- P2 (PCF8574) -> ENABLE (LCD) -- P3 (PCF8574) -> BACKLIGHT (LCD)
\ P4 (PCF8574) -> D4 (LCD) -- P5 (PCF8574) -> D5 (LCD)-- P6 (PCF8574) -> D7 (LCD) -- P7 (PCF8574) -> D7 (LCD)
\ I dati da inviare dovranno seguire il seguente schema
\ D7 ---- D6 ----- D5 ----- D4 ---- Backlight --- Enable -- R/W -- R/S 
\ Per trasferire 1 byte, necessiteremo di 4 scritture sul bus i2c 
\ Esempio, se volessimo trasferire il carattere "C", in ASCII 0x43, si dovrebbero:
\ 1) scomporre in due parti-- > 0x43 --> 0x 0100 (MSB) 0011 (LSB) 
\ 2) attivare e disattivare "enable" per ogni trasferimento di bit 
\ 3) impostare il bit RS a 0 se si tratta di un comando, altrimenti 1 
\ CODIFICA PER INVIARE DATI: MSB+0D  MSB+09 LSB+0D  LSB+09
\ CODIFICA PER INVIARE COMANDI : MSB+0C  MSB+08 LSB+0C  LSB+08
\ In dettaglio (trasferimento dati)
\ D7 D6 D5 D4 BL EN R/W RS  (primo invio)
\ M   M  M M  1  1   0  1 
\ D7 D6 D5 D4 BL EN R/W RS  (secondo invio)
\ M  M  M   M  1  0   0  1
\ (M rappresentano i bit più significativi)
\ per il terzo e quarto invio è la medesima procedura, ma con gli LSB
\ Per il trasferimento comandi è sufficiente effettuare le medesime operazioni
\ impostando il bit RS a 0


: LCD-EN ( data mode dlen -- )
   1 1 >I2C ;

\La procedura inserisce in cima, in base alla modalità selezionata, i valori d'impostazione adeguati
: DATA-OR-CMD ( mode -- setting_2 setting_1)
    CASE 
        0 OF 08 0C ENDOF 
        1 OF 09 0D ENDOF 
        (  default case: )
     ." Invalid selection " CR 
    ENDCASE ;

\La procedura divide 1 byte in esadecimale in 1 coppia di 4bit lsb-msb 
: SPLIT-HEX-NUM ( hex -- lsb_hex msb_hex )
    DUP 0F AND 
    SWAP
    F0 AND 10 /
;

\La procedura unisce 4 bit da inviare ed i 4 bit d'impostazione 
: >4BIT-S-D ( 4bit_setting 4bit_hex  --  )
    4 LSHIFT \Riposizionamento dei bit            
    OR
    LCD-EN 1000 DELAY \invia i bit
;

\La procedura verifica se si vuole inviare un comando o un dato, inserendo
\un valore di selezione nello stack
: ?SETTINGS ( hex -- selection hex )
    DUP 100 AND \Verifica che il bit più significativo sia 1
    100 = IF \Se è un comando
        0 DUP
        ROT
        100 MOD \Rimuovo il bit più significativo
    ELSE \Se non è un comando
        1 DUP
        ROT
    THEN
;


\ Questa procedura prepara lo stack all'invio di una parte di dati o comandi (chiamata anche "nibble")
\ congiuntamente ad una parte relativa all'impostazione (altro "nibble")
: PREP-STACK ( mode lsb_hex msb_hex  -- lsb_hex setting_2 setting_1 msb_hex )
    ROT ( stack = [lsb_hex msb_hex mode ] )
    DATA-OR-CMD ( stack = [lsb_hex msb_hex setting_2 setting_1] )
    ROT ( stack = [ lsb_hex setting_2 setting_1 msb_hex] )
;

\Questa procedura invia il bit più significativo per le due impostazioni selezionate in precedenza
: >MSB ( mode mode lsb_hex msb_hex -- )
    DUP ( stack = [mode mode lsb_hex msb_hex msb_hex] return-stack = [])
    >R ( stack = [mode mode lsb_hex msb_hex ] return-stack = [msb_hex])
    PREP-STACK ( stack = [mode lsb_hex setting_2 setting_1 msb_hex] eturn-stack = [msb_hex] )
    >4BIT-S-D ( stack = [mode lsb_hex setting_2 ] return-stack = [msb_hex])
    R> ( stack = [mode lsb_hex setting_2 msb_hex] return-stack = [])
    >4BIT-S-D ( stack = [mode lsb_hex] return-stack = [])
;

\Questa procedura invia il bit meno significativo per le due impostazioni selezionate in precedenza
: >LSB ( mode lsb_hex -- )
    DUP ( stack = [mode lsb_hex lsb_hex] return-stack = [])
    PREP-STACK ( stack = [lsb_hex setting_2 setting_1 lsb_hex] )
    >4BIT-S-D ( stack = [lsb_hex setting_2 ])
    SWAP ( stack = [setting_2 lsb_hex])
    >4BIT-S-D ; ( stack = [])

\Word di alto livello che riunisce le due word precedenti
: >1BYTE ( mode mode lsb_hex msb_hex)
   >MSB 
   >LSB 
;

\Word di alto livello che consente la scrittura di caratteri in formato ASCII o comandi di utillità per lo schermo
: >LCD ( hex -- ) 
    ?SETTINGS SPLIT-HEX-NUM >1BYTE
;

DECIMAL 

\Divide MSB e LSB, dividendo per 10 affinché si possa ottenere i primi ed effettuando il modulo per 10 per ottenere i secondi
: SPLIT-DEC-NUM ( percentage -- lsb_value msb_value )
    DUP ( percentage percentage ) 
    10 / ( percentage msb_val)
    SWAP ( msb_val percentage)
    10 MOD ( msb_val lsb_val)
    SWAP ( lsb_val msb_val)
;

HEX 

\Aggiunge "3" come bit più significativo al valore presente in cima allo stack per consentire 
\la corretta codifica ascii 
: APPEND-ASCII ( hex_num -- ascii_num )  
    MSB_NUM_ASCII 
    4  
    LSHIFT 
    + ; 

\ Cancella il display
: CLEAR-LCD ( -- )
    101 >LCD ;

\ Inizializza il cursore, posizionandolo sul primo elemento della prima riga 
\ e disattiva blinking del cursore
: SETUP-LCD ( -- )
   102 >LCD 
   108 04 OR >LCD ;

\\\ da vedere 
\\-----------------------------------------------
\ Sposta il cursore a sinistra
: CURSOR-LSHIFT ( -- ) 
    110 >LCD ;
\ Sposta il cursore nella seconda riga a partire dal primo elemento
: LINE-2 ( -- )
    1C0 >LCD ;    
\\ ------------------------------------
\Imposta il cursore nella riga e colonna desiderata
: SET-CURSOR ( col row -- )
    CASE 
        0 OF 180 OR >LCD ENDOF
        1 OF 1C0 OR >LCD ENDOF 
        ( default case )
        ." Invalid selection, there are only 2 rows " CR
    ENDCASE ;


: POMPA ( -- )
    50 >LCD
    4F >LCD
    4D >LCD
    50 >LCD
    41 >LCD
    3A >LCD
    20 >LCD ;

: ON ( -- ) 
    4F >LCD
    4E >LCD ;

: OFF ( -- )
    4F >LCD
    46 >LCD
    46 >LCD ;


: OK ( -- ) 
    4F >LCD
    4B >LCD 
    21 >LCD ;


: UMIDITA ( -- )
    55 >LCD 
    4D >LCD
    49 >LCD
    44 >LCD
    49 >LCD
    54 >LCD
    41 >LCD
    60 >LCD
    3A >LCD
    20 >LCD ;

: PERCENTAGE-SYM ( -- )
    25 >LCD ;

: WET ( -- ) 
    57 >LCD \W
;

: DRY ( -- )
    44 >LCD \D 
;

: P-EXIT ( -- )
    CLEAR-LCD
    45 >LCD \E
    58 >LCD \X
    49 >LCD \I
    54 >LCD \T
    21 >LCD
;


: CALIB-TEXT ( -- ) 
    43 >LCD \C 
    41 >LCD \A
    4C >LCD \L
    49 >LCD \I
    42 >LCD \B
    52 >LCD \R
    41 >LCD \A
    5A >LCD \Z
    49 >LCD \I
    4F >LCD \O
    4E >LCD \N
    45 >LCD \E
    20 >LCD 
;

: UPDATE-S-PUMP ( mode -- ) \Aggiorna lo status della pompa, stampando a schermo "On" o "Off"
    CASE 
        0 OF 7 0 SET-CURSOR ON 20 >LCD ENDOF 
        1 OF 7 0 SET-CURSOR OFF ENDOF 
        ( default case )
        ." Not Valid "
    ENDCASE ;


\Stampa il valore percentuale su schermo, dividendo le cifre meno significative e più significative
: PRINT-PERCENTAGE ( percentage -- )
    DUP ( stack = [ percentage percentage ] )
    9 >= IF 
        A 1 SET-CURSOR SPLIT-DEC-NUM APPEND-ASCII >LCD APPEND-ASCII >LCD
    ELSE 
        DUP
        0 <= IF
            DROP A 1 SET-CURSOR 30 >LCD 30 >LCD
        ELSE 
            A 1 SET-CURSOR 30 >LCD APPEND-ASCII >LCD
        THEN
    THEN 
;