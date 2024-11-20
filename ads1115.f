\ Embedded Systems - Sistemi Embedded - 17873
\ configurazione ADS1115  
\ Salvatore Lucio Auria 0737598 - Fabio Villa 0744495 - Ingegneria Informatica LM 
 
\ads1115.f

\ per accedere ad un registro specifico dall'ads1115, il master deve prima scrivere 
\ un valore appropriato nel registro ADdress Pointer [struttura: 000000P1P0 ]
\ possibili valori: 
\ 00 -> conversion register 
\ 01 -> config register
\ 10 -> Lo_thresh register
\ 11 -> Hi_thresh register


\ Il config register avrà la seguente configurazione: 
\ 0x 0100 001 0 1000 0011 -> 0x4283
\ DA DESTRA VERSO SINISTRA
\ 11 bit[0:1] (disable comparator,ALERT/RDY high impedence mode)
\ 0 bit[2] (Nonlatching comparator)
\ 0 bit[3] (Comparator polarity: active low)
\ 0 bit[4] (Comparator mode: traditional comparator)
\ 100 bit[5:7] (Data rate: 128 SPS)
\ 0 bit[8] (Conversione continua)
\ 001 bit[9:11] (Gain amplifier FSR = +-4,096 V)
\ 100 bit[12:14] (AINp=AIN0 e AINn=GND)
\ 0 bit[15] (operational status= no effect)
\ Visto lo spazio di indirizzamento a 10-bit, si effettueranno due comunicazioni
\ (più una preliminare) in cui si trasmetteranno prima l'LSB (83) e poi l'MSB (44)
\Le variabili WET_VALUE E DRY_VALUE sono necessarie nella fase di calibrazione


42 CONSTANT MSB_CONFIG_R
83 CONSTANT LSB_CONFIG_R
VARIABLE DRY_VALUE
VARIABLE WET_VALUE


\La procedura ADC-CFG è necessaria alla configurazione dell'ADS1115
\ 01 Rappresenta l'indirizzo di accesso del config register da scrivere nella fifo
\ 2 Rappresenta la selezione dell'indirizzo slave ADS1115 (tramite SET_SLAVE_ADDRESS)
\ 3 Sono i bytes da inviare: il primo è 01 ovvero l'indirizzo già citato
\ il secondo è l'MSB del config register e il terzo è l'LSB in quanto l'indirizzamento
\del bsc2711 è di 10bit ed è necessario suddividere i bit in trasferimento

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
\ Per via dello spazio di indirizzamento a 10 bit, la dimensione dei dati in modalità di lettura dev'essere 2 byte
\ in quanto il Conversion Register rappresenta i valori in 16 bit
\ La lettura dovrà avvenire 2 volte: 1 per byte;
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


\Il sensore capacitivo necessita di una "calibrazione" effettuabile seguendo due fasi
\1) mantenendo "libero" il sensore in aria per estrarre il "DryValue" 
\2) posizionando il sensore in acqua per estrarre il "WetValue "
\. Dopo tale fase, verranno utilizzati i valori 
\ massimi (DryValue) e minimi (WetValue) 
\ Humidity_Percentage = 100 - [(MeanADCValue-WetValue/DryValue - WetValue) * 100]
\ La percentuale è calcolata in esadecimale 
\ HEX(100) = 64 

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

\Calcola effettivamente la percentuale di umidità richiamando le due word precedenti.
\Il risultato ottenuto viene gestito in base al  valore ottenuto:
\1) se il valore è inferiore a 0, inserisci 0 nello stack e rimuovi il valore negativo
\2) se il valore è uguale a 64 (in decimale, 100), allora inserisci 63 (ovvero 99) e rimuovi 64
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
