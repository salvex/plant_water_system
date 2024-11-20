\ Embedded Systems - Sistemi Embedded - 17873
\ configurazione base GPIO  
\ Salvatore Lucio Auria 0737598 - Fabio Villa 0744495 - Ingegneria Informatica LM 
 
\ Il GPIO utilizza uno spaziamento di indirizzi a 32 bit. 
\ L'indirizzo base del RPI (su RPI 4, secondo la documentazione bcm2711-peripherals.pdf) è 0x7e200000
\ ovvero 0xFE200000

\ config_gpio.f
HEX
\ --------------------------------------------------------------------- \
FE200000 CONSTANT GPIO_BASE

\ -- Il selettore di funzione per il banco 0 (GPFSEL0) corrisponde all'indirizzo base FE200000  \ 
\ -- per il protocollo i2c necessitiamo SDA1 ed SCL1, corrispondenti rispettivamente alla funzione alternativa 0 di GPIO2 e GPIO3 \
\ -- Per accedere al registro di attivazione (GPSET0) del GPIO, sommare 0x1c \
\ -- Per accedere al registro di reset (GPCLR0), sommare 0x28 \
\ -- Per leggere i bit da un GPIO (GPLEV0), sommare 0x34 \
\ --------------------------------------------------------------------- \

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


\ Funzioni del GPFSEL d'interesse
\ 1) 000 : imposta come input;
\ 2) 001 : inposta come output;
\ 3) 100 : impostazome funzione alternativa 0; -> necessaria per i2c

\La seguente word effettua la pulizia del valore di registro GPFSELN
\in preparazione alla successiva scrittura
: GPFSELN-PREP ( n_gpio -- n_gpio gpfnseln_reg reg_value_clean )
    DUP ( stack : n_gpio n_gpio )  
    DUP ( stack : n_gpio n_gpio n_gpio )
    GPFSELN-REG  ( stack : n_gpio n_gpio gpnseln_reg)
    REG-VALUE ( stack: n_gpio n_gpio gpfnsel_reg gpfnseln_reg_value)
    ROT ( stack : n_gpio gpfnseln_reg gpfnseln_reg_value gpio )
    CALC-MASK ( stacK: n_gpio gpfnseln_reg gpfnseln_reg_value mask_curr_pos  )
    CLEAR-REG  ( stack: n_gpio gpfnseln_reg reg_value_clean);

\La seguente word consente di scrivere, nel registro GPFSELN
\I bit in cima allo stack per l'attivazione della corrispettiva funzionalità GPIO
: !GPFNSELN-FUN ( gpfnsel cleaned_reg offset_pos bit -- )
    MOVE-WORD  \ Muove il bit in cima allo stack in base al valore di offset_pos
    OR \ Effettua l'OR logico tra il bit spostato nella posizione corretta e il registro "ripulito"
    SWAP ! ; \ Scambia "cleaned_reg e gpfnsel" e scrive "cleaned_reg" su gpfnsel


: !1-BIT ( gpsetclear_register offset_pos --  )
    1 MOVE-WORD 
    SWAP ! ;

: GET-1BIT ( gplev_register_val offset_pos -- and_res )
    1 MOVE-WORD 
    AND ;

: GPFSELN-CONF ( n_gpio -- n_gpio gpfnseln_reg reg_value_clean )
    CHECK-GPIO
    GPFSELN-PREP ;

: SET-INPUT ( n_gpio -- )  \ Scorciatoia per attivare la modalità di input
    GPFSELN-CONF SWAP ! DROP ;

: SET-OUTPUT ( n_gpio -- ) \ Scorciatoia per attivare la modalità di output
    GPFSELN-CONF ( stack :  n_gpio gpfnseln_reg reg_value_clean )
    ROT  ( stack : gpfnseln_reg reg_value_clean n_gpio )
    OFFSET-BANK 1  ( stack: gpfnseln_reg reg_value_clean offset_pos bit ;)
    !GPFNSELN-FUN  ;

: SET-ALTFN0 ( n_gpio -- ) \ Scorciatoia per attivare la funzione alternativa 0
    GPFSELN-CONF ROT OFFSET-BANK 4 !GPFNSELN-FUN ;

: GET-INPUT ( n_gpio -- res) \ Scorciatoia per prelevare l'input da GPIO
    3 GPIO0-REG @ SWAP GET-1BIT ;


: SET-ON-OFF ( n_gpio mode -- ) \ Rivedere  
    CASE
        0 OF 1 GPIO0-REG SWAP !1-BIT ENDOF 
        1 OF 2 GPIO0-REG SWAP !1-BIT ENDOF
        ( default case: )
        ." Invalid selection! Use 0 and 1 for set/clear operation " CR
    ENDCASE ;

\Questa word abilita all'accesso del controller BSC1
: EN-BSC ( -- ) 
    2 SET-ALTFN0
    3 SET-ALTFN0 ;

