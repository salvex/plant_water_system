: '\n' 10 ;
: BL 32 ;
: ':' [ CHAR : ] LITERAL ;
: ';' [ CHAR ; ] LITERAL ;
: '(' [ CHAR ( ] LITERAL ;
: ')' [ CHAR ) ] LITERAL ;
: '"' [ CHAR " ] LITERAL ;
: 'A' [ CHAR A ] LITERAL ;
: '0' [ CHAR 0 ] LITERAL ;
: '-' [ CHAR - ] LITERAL ;
: '.' [ CHAR . ] LITERAL ;
: ( IMMEDIATE 1 BEGIN KEY DUP '(' = IF DROP 1+ ELSE ')' = IF 1- THEN THEN DUP 0= UNTIL DROP ;
: SPACES ( n -- ) BEGIN DUP 0> WHILE SPACE 1- REPEAT DROP ;
: WITHIN -ROT OVER <= IF > IF TRUE ELSE FALSE THEN ELSE 2DROP FALSE THEN ;
: ALIGNED ( c-addr -- a-addr ) 3 + 3 INVERT AND ;
: ALIGN HERE @ ALIGNED HERE ! ;
: C, HERE @ C! 1 HERE +! ;
: S" IMMEDIATE ( -- addr len )
	STATE @ IF
		' LITS , HERE @ 0 ,
		BEGIN KEY DUP '"'
                <> WHILE C, REPEAT
		DROP DUP HERE @ SWAP - 4- SWAP ! ALIGN
	ELSE
		HERE @
		BEGIN KEY DUP '"'
                <> WHILE OVER C! 1+ REPEAT
		DROP HERE @ - HERE @ SWAP
	THEN
;
: ." IMMEDIATE ( -- )
	STATE @ IF
		[COMPILE] S" ' TELL ,
	ELSE
		BEGIN KEY DUP '"' = IF DROP EXIT THEN EMIT AGAIN
	THEN
;

\ config_gpio.f
HEX
\ --------------------------------------------------------------------- \
FE200000 CONSTANT GPIO_BASE

: DELAY BEGIN 1 - DUP 0 = UNTIL DROP ;

: MOVE-WORD ( n_pos word    -- shifted_word ) \Sposta la word al TOS di "n" posizioni
    SWAP LSHIFT ; \ Si scambiano i primi due elementi dello stack ed effettua lo shift in base al valore individuato nello stack 

: OFFSET-BANK ( n_gpio  -- offset_pos ) \Calcola lo spiazzamento corretto del pin GPIO presente in cima allo stack
    A MOD 3 * ;  \ Effettua il modulo di n_gpio in base 10, in quanto ogni banco ha 10 pin e successivamente viene effettuata la moltiplicazione per 3, ovvero i bit da considerare nella selezione

: CALC-MASK ( n_gpio -- fsel_mask ) \ Imposta la maschera adeguatamente al numero del GPIO presentato in ingresso
    OFFSET-BANK 7 MOVE-WORD ; \ il valore 7 (ovvero 111) viene spostato correttamente di n posizioni calcolate in precedenza

: CLEAR-REG ( reg_val mask -- clear_reg ) \Ripulisce il valore del registro in ingresso con la maschera corrispondente
    INVERT AND ; \ inverte i bit della mascha ed effettua un and logico con gli altri bit affinché i bit interessati siano resettati e gli altri lasciati intatti

: REG-VALUE ( reg_address -- reg_address reg_value ) \Duplica l'indirizzo del registro e ne preleva il valore in TOS
    DUP ( stack: reg_address reg_address ) 
    @  ( stack: reg_address reg_addres_val );

: CHECK-GPIO ( n_gpio -- n_gpio )  \La procedura controlla la validità del numero GPIO presente in cima allo stack
    DUP DUP 0 <= SWAP 11 > OR 
    IF 
       ." Invalid GPIO Selection " CR
    THEN ;

: GPIO0-REG ( n_mode -- gpio_base_register )
    CASE 
        0 OF ENDOF \GPFSEL0
        1 OF 1C GPIO_BASE + ENDOF \GPSET0 
        2 OF 28 GPIO_BASE + ENDOF \GPCLR0
        3 OF 34 GPIO_BASE + ENDOF \GPLEV0
        ( default case: )
        ." Invalid GPIO Mode " CR
    ENDCASE ;

: GPFSELN-REG ( n_gpio -- gpfsel_reg )  
    A /  \ divisione del numero gpio per 10, ovvero il numero massimo di GPIO per banco
    02 LSHIFT  \shift di 4 posizioni
    GPIO_BASE + ; \somma rispetto all'indirizzo del gpio base

: GPFSELN-PREP ( n_gpio -- gpio_register gpio_mask )
    DUP ( stack : gpio gpio )  
    DUP ( stack : gpio gpio pio )
    GPFSELN-REG  ( stack : gpio gpio gpnseln_reg)
    REG-VALUE ( stack: gpio gpio gpfnsel_reg gpfnseln_reg_value)
    ROT ( stack : gpio gpfnseln_reg gpfnseln_reg_value gpio )
    CALC-MASK ( stacK: gpio gpfnseln_reg gpfnseln_reg_value mask_curr_pos  )
    CLEAR-REG  ( stack: gpio gpfnseln_reg reg_value_clean);

\La seguente word consente di scrivere, nel registro GPFSELN
\I bit in cima allo stack per l'attivazione della corrispettiva funzionalità GPIO
: !GPFNSELN-FUN ( bit gpfnsel cleaned_reg offset_pos -- )
    MOVE-WORD  \ Muove il bit in cima allo stack in base al valore di offset_pos
    OR \ Effettua l'OR logico tra il valore "1" spostato nella posizione corretta e il registro "ripulito"
    SWAP ! ; \ Scambia "cleaned_reg e gpfnsel" e scrive "cleaned_reg" su gpfnsel

: !1-BIT ( gpsetclear_register offset_pos --  )
    1 MOVE-WORD 
    SWAP ! ;

: GET-1BIT ( gplev_register_val offset_pos -- and_res )
    1 MOVE-WORD 
    AND ;

: GPFSELN-CONF ( n_gpio -- gpio_register gpio_mask )
    CHECK-GPIO
    GPFSELN-PREP ;

: SET-INPUT ( n_gpio -- )  \ Scorciatoia per attivare la modalità di input
    GPFSELN-CONF SWAP ! DROP ;

: SET-OUTPUT ( n_gpio -- ) \ Scorciatoia per attivare la modalità di output
    GPFSELN-CONF ROT OFFSET-BANK 1 !GPFNSELN-FUN  ;

: SET-ALTFN0 ( n_gpio -- ) \ Scorciatoia per attivare la funzione alternativa 0
    GPFSELN-CONF ROT OFFSET-BANK 4 !GPFNSELN-FUN ;

: GET-INPUT ( n_gpio -- res) \ Scorciatoia per prelevare l'input da GPIO
    3 GPIO0-REG @ SWAP GET-1BIT ;


: SET-ON-OFF ( n_gpio mode -- ) \ Rivedere  
    CASE
        0 OF  1 GPIO0-REG SWAP !1-BIT ENDOF 
        1 OF  2 GPIO0-REG SWAP !1-BIT ENDOF
        ( default case: )
        ." Invalid selection! Use 0 and 1 for set/clear operation " CR
    ENDCASE ;

\Questa word abilita all'accesso del controller BSC1
: EN-BSC ( -- ) 
    2 SET-ALTFN0
    3 SET-ALTFN0 ;

FE804000 CONSTANT BSC1_BASE  \Coincide a Registro C = Control

: BSC1-REGISTER ( n_mode -- bsc1_reg )
    CASE  
        1 OF 04 BSC1_BASE + ENDOF \ Registro S = Status
        2 OF 08 BSC1_BASE + ENDOF \ Registro DLEN = Data Length 
        3 OF 0C BSC1_BASE + ENDOF \ Registro A = Slave Address
        4 OF 10 BSC1_BASE + ENDOF \ Registro FIFO = Data FIFO
        5 OF 14 BSC1_BASE + ENDOF \ Registro DIV = Clock Divider
        6 OF 18 BSC1_BASE + ENDOF \ Registro DEL = Data Delay
        7 OF 1C BSC1_BASE + ENDOF \ Registro CLKT = Clock Stretch Timeout
        ( default case : )
        ." Invalid Selection " CR
    ENDCASE ; 

\ Abilita la scrittura i2c scrivendo "0" sul bit READ , "1" sul bit ST e "1" sul bit I2CEN del Control Register
: WRITE-MODE ( --  ) 
    8080 BSC1_BASE ! ;

: READ-MODE ( -- ) \abilita la lettura i2c scrivendo "1" sul bit READ, "1" sul bit ST e "1" sul bit I2CEN del Control Register
    8081 BSC1_BASE ! ;

\ Pulisce la coda FIFO scrivendo "1" sul quarto bit del Control Register
: CLEAR-FIFO ( -- ) 
    10 BSC1_BASE ! ; 

\ Ripristina lo status register srivendo "1" rispettivamente nella posiziome 1 (DONE),8 (ERR) e 9 (CLKT) dello Status Register
: CLEAR-S-REG ( -- )
    302 1 BSC1-REGISTER ! ;

\ Imposta il numero di byte (1 nel caso dell'LCD) da trasferire / ricevere sul bus i2c
: SET-DLEN ( d_len -- ) 
    2 BSC1-REGISTER ! ;


: !SLAVE-ADDR ( mode -- )
    CASE
        1 OF 3F 3 BSC1-REGISTER ! ENDOF \ imposta lo slave address dell'LCD 1602
        2 OF 48 3 BSC1-REGISTER ! ENDOF \ Imposta lo slave address dell'ADS 1115 
        ( default case : )
        ." Invalid slave selection "
    ENDCASE ;

: CLEAR-A-REG ( -- )
    0 3 BSC1-REGISTER ! ;

\ Scrive i dati sul registro Data FIFO
: !FIFO ( data -- ) 
    4 BSC1-REGISTER ! ; 

\ Preleva i dati dal registro Data FIFO
: @FIFO ( -- data )
    4 BSC1-REGISTER @ ;

: ?FIFO-EMPTY ( -- ) 
    BEGIN 
        1 BSC1-REGISTER @ 51 AND
        51 = 
    UNTIL
;

: ?COMPLETE ( -- )
    BEGIN
        1 BSC1-REGISTER @ 52 AND 
        52 =
    UNTIL
;

: CLEAR-I2C ( -- ) 
    CLEAR-A-REG 
    CLEAR-S-REG
    CLEAR-FIFO ;

\ Imposta la lunghezza dei dati di trasferimento 
: I2C-INIT ( mode dlen -- ) 
   CLEAR-I2C SET-DLEN !SLAVE-ADDR ;

\ Word di alto livello per abilitare la modalità di scrittura
: >I2C ( data mode dlen -- )
    I2C-INIT !FIFO WRITE-MODE ;

\ Word di alto livello per abilitare la modalità di lettura 
: I2C> ( mode dlen -- )
    I2C-INIT READ-MODE ;


\lcd1602.f

3 CONSTANT MSB_NUM_ASCII \ bit più significativi nella codifica dei numeri esadecimali in ASCII

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

\ads1115.f

42 CONSTANT MSB_CONFIG_R
83 CONSTANT LSB_CONFIG_R
VARIABLE DRY_VALUE
VARIABLE WET_VALUE

: ADC-CFG ( -- )
    01 
    2
    3 
    >I2C  
    ?FIFO-EMPTY MSB_CONFIG_R !FIFO 
    ?FIFO-EMPTY LSB_CONFIG_R !FIFO ;

\la procedura ADC-CNV scrive l'indirizzo del conversion register nella FIFO
\per abilitarne l'accesso , in quanto vi sarà contenuto il valore proveniente dall'Igrometro. 

: ADC-CNV ( -- )
    00 \ indirizzo conversion register
    2 \selezione dell'indirizzo slave ads1115
    1 >I2C ;


\La prcedura ADC> abilita alla lettura della coda FIFO. 

: ADC> ( -- )
    2 
    2 
    I2C> ;

\Word generale per l'inizializzazione del converitore Analogico-digitale
: ADS1115 ( -- )
    ADC-CFG ?COMPLETE 
    ADC-CNV ?COMPLETE ;

\La procedura consente, tramite due delay da 250, di leggere la coda 2 volte, ogni lettura raccoglierà 1 byte dalla coda FIFO
: SENSOR-VALUE ( -- fifo_value ) 
    ADC> 250 DELAY @FIFO 250 DELAY @FIFO  ( stack : value_1 value_2 )
    8 ( stack : value_1 value_2 8)
    ROT ( stack : value_2 8 value_1)
    MOVE-WORD ( stack : value_2 value_1_shifted)
    SWAP  ( stack : value_1_shifted value_2 ) 
    OR ( stack : value) ;


\Calcola la media delle misurazioni su 50 valori prelevati
: MEAN-MEASURES ( -- mean_value) 
    0
    32
    BEGIN  
        SWAP
        SENSOR-VALUE +
        SWAP
        1 - DUP
    0 = UNTIL 
    DROP
    32 /
;

: !DRY-VAL ( -- )
    MEAN-MEASURES DRY_VALUE ! ;

: !WET-VAL ( -- )
    MEAN-MEASURES WET_VALUE ! ;

\Calcola l'intervallo tra Dry e WetValue: diventerà il denominatore della formula "Humidity_Percentage";
: CALC-RANGE ( -- range ) 
    DRY_VALUE @ WET_VALUE @ - ;

\Calcola la differenza tra MeanADCValue e WetValue, moltiplicando infine per 100
: MEASURES-RESCALED ( -- adc_val_rescaled )
    MEAN-MEASURES 
    WET_VALUE @ - 64 * 
    DUP 0 <= IF
    0 SWAP DROP
    THEN     
;

: HUMIDITY-PERCENTAGE ( -- percentage )
    64 MEASURES-RESCALED CALC-RANGE / -
    DUP 
    0 <= IF 
        0 SWAP DROP
    ELSE 
        DUP 64 = IF 
            63 SWAP DROP
        THEN
    THEN
;

\setup.f 

: INIT ( -- ) 
    EN-BSC
    ADS1115
    D SET-INPUT
    SETUP-LCD ;

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

