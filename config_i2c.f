\ Embedded Systems - Sistemi Embedded - 17873
\ configurazione I2C (BCM2711)  
\ Salvatore Lucio Auria 0737598 - Fabio Villa 0744495 - Ingegneria Informatica LM 
\ config_i2c.f 

\ Il controller BSC possiede 8 registri in memoria. Ogni accesso sfrutta word da 32 bit.
\ I Controller master BSC2 e BSC7 vengono utilizzati dall'interfaccia HDMI e di conseguenza rimangono "riservati"
\ Gli indirizzi dei registri i2c vengono calcolati su base dell'indirizzo BSC, dove 
\ viene sommato uno spiazzamento di 4 

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

\\ Scrittura i2c
\ 1) scrivere il numero di byte nel registro i2clen
\ 2) scrivere gli 8 LSB nella FIFO (8 bit LSB slave address)
\ 3) scrivere altir dati da trasmettere nella fifo
\ 4) scrivere "11110XX" nell'indiirzzo slave dove "xx" sono i due MSB dell'indirizzo a 10 bit

\\ Lettura i2c
\ 1) scrivere 1 nel registro I2CDLEN
\ 2) impostare read = 0 e st = 1
\ 3) prelevare il bit TA, entrando in fase di attesa
\ 4) appena il bit TA = 1, scrivere il numero di byte nel registro I2CDLEN
\ 5) imposta READ = 1 e ST = 1 


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

\ Scrive gli eventuali indirizzi slave nel registro A del BSC2711;
 
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

\\ ?FIFO-EMPTY Esegue un ciclo e controlla lo status register finchè i bit TA (bit 0), TXD (bit 4) e TXE (bit 6) siano a 1
\\ovvero 0x[31:10 RESERVED]00 0101 0001
\\ se queste condizioni sono rispettate, allora la coda sarà vuota
: ?FIFO-EMPTY ( -- ) 
    BEGIN 
        1 BSC1-REGISTER @ 51 AND
        51 = 
    UNTIL
;

\ ?COMPLETE Esegue un controllo simile alla procedura precedente, ma in questo caso 
\ si controlla, dal registro S,  se il bit 1, ovvero DONE, sia impostato a 1, ovvero se il trasferimento è stato completato
\\ovvero 0x[31:10 RESERVED]00 0101 0010
: ?COMPLETE ( -- )
    BEGIN
        1 BSC1-REGISTER @ 52 AND 
        52 =
    UNTIL
;

\ Word di alto livello dove vengono "ripuliti" : 
\ 1) Address Register
\ 2) Status Register
\ 3) Coda ;

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

