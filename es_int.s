	ORG	$0
	DC.L	$8000	      * Valor inicial puntero Pila
	DC.L	INICIO		  * Valor inicial programa principal

	ORG     $400

MR1A    EQU     $effc01       * de modo A (escritura)
MR2A    EQU     $effc01       * de modo A (2º escritura)
SRA     EQU     $effc03       * de estado A (lectura)
CSRA    EQU     $effc03       * de seleccion de reloj A (escritura)
CRA     EQU     $effc05       * de control A (escritura)
TBA     EQU     $effc07       * buffer transmision A (escritura)
RBA     EQU     $effc07       * buffer recepcion A  (lectura)
ACR	EQU	$effc09	      * de control auxiliar
IMR     EQU     $effc0B       * de mascara de interrupcion A (escritura)
ISR     EQU     $effc0B       * de estado de interrupcion A (lectura)
MR1B    EQU     $effc11       * de modo B (escritura)
MR2B    EQU     $effc11       * de modo B (2º escritura)
CRB     EQU     $effc15	      * de control B (escritura)
TBB     EQU     $effc17       * buffer transmision B (escritura)
RBB	EQU	$effc17       * buffer recepcion B (lectura)
SRB     EQU     $effc13       * de estado B (lectura)
CSRB	EQU	$effc13       * de seleccion de reloj B (escritura)
IVR	EQU	$effc19		  * de vector interrupción

CR	EQU	$0D			* Carriage Return
LF	EQU	$0A			* Line Feed
FLAGT	EQU	2			* Flag de transmisión
FLAGR   EQU     0		    * Flag de recepción

IMRC	DC.B	0	* Copia IMR para acceder en modo lectura

**************************** INIT *************************************************************
INIT:		MOVE.B          #%00000000,ACR      * Velocidad = 38400 bps.
		MOVE.B          #%00100010,IMR		 * Se habilitan interrupciones en A y B siempre que haya un caracter
		MOVE.B		#%00100010,IMRC		* Se establece la copia del IMR al mismo valor que el IMR para accederlo como lectura
		MOVE.B		#%01000000,IVR	* Se inicializa el vecto de interrupciones a 40
		MOVE.L		#RTI,$100			* Inicializa RTI en la tabla de vectores de interrupción
		* Línea A
		MOVE.B          #%00010101,CRA      * Activa transmisión y recepción en A
		MOVE.B          #%00000011,MR1A     * 8 bits por caracter.
		MOVE.B          #%00000000,MR2A     * Eco desactivado.
		MOVE.B          #%11001100,CSRA     * Velocidad = 38400 bps.
		* Línea B
		MOVE.B          #%00010101,CRB      * Activa transmisión y recepción en B
		MOVE.B          #%00000011,MR1B     * 8 bits por caracter.
		MOVE.B          #%00000000,MR2B     * Eco desactivado.
		MOVE.B          #%11001100,CSRB     * Velocidad = 38400 bps.
		BSR		INI_BUFS	    * Llama la subrutina ini_bufs
		RTS
**************************** FIN INIT *********************************************************

**************************** PRINT ************************************************************
PRINT:		LINK		A6,#-14		* Crea marco de pila auxiliar
			MOVE.L		8(A6),A1	* Se guarda el buffer en A1
			MOVE.W		12(A6),D2	* Se guarda el descriptor en D2
			MOVE.W		14(A6),D3	* Se guarda el tamaño del bloque en D3
			CLR.L		D0			* Se inicializa D0 a 0
			CLR.L		D4			* Se inicializa el descriptor de ESCCAR a 0
			CLR.L		D5			* Se crea la variable D5 para almacenar el tamaño
			CMP.W		#0,D2		* Se comprueba si el descriptor es 0 (Línea A)
			BEQ		PRLIN_A
			CMP.W		#1,D2		* Se comprueba si el descriptor es 1 (Línea B)
			BEQ		PRLIN_B
			BRA		ERROR_P		* Si no es ni 0 ni 1 da ERROR

PRLIN_A:	MOVE.L		#2,D4		* Inicializa D4 a 2 (se usará para el descriptor en ESCCAR)
			BRA		BUC_PR

PRLIN_B:	MOVE.L		#3,D4		* Inicializa D4 a 3 (se usará para el descriptor en ESCCAR)

BUC_PR:		CMP.W		#0,D3		* Comprueba si el tamaño del bloque ha llegado a 0
			BEQ		FIN_PR		* Si ha llegado a 0 termina el bucle
			MOVE.B		(A1)+,D1	* Guarda el caracter actual en D1
			MOVE.L		A1,-4(A6)	* Se guarda la variable del buffer
			MOVE.L		D4,-8(A6)	* Se guarda la variable del descriptor
			MOVE.W		D3,-10(A6)	* Se guarda la variable tamaño del bloque
			MOVE.L		D5,-14(A6)	* Se guarda la variable número de caracteres leídos
			MOVE.L		D4,D0		* Guarda el descriptor en en D0 para su uso futuro
			BSR		ESCCAR
			CMP.L		#-1,D0		* Comprueba está libre o no
			BEQ		FIN_PR		* Si no está libre se acaba
			MOVE.L		-4(A6),A1	* Se recupera la variable del buffer
			MOVE.L		-8(A6),D4	* Se recupera la variable del descriptor
			MOVE.W		-10(A6),D3	* Se recupera la variable tamaño del bloque
			MOVE.L		-14(A6),D5	* Se recupera la variable número de caracteres leídos
			ADD.L		#1,D5		* Incrementa D5 (resultado) por 1
			SUB.W		#1,D3		* Le resta 1 al tamaño del bloque
			BNE		BUC_PR 
			BRA		FIN_PR

ERROR_P:	MOVE.L		#$FFFFFFFF,D0	* Coloca el estado error en D0 al no haber caracteres
		BRA		NOINT

FIN_PR:	MOVE.L		D5,D0	* Se pasa el resultado a D0
			CMP.L		#0,D0		* Se comprueba la cantidad de caracteres para imprimir
			BEQ		NOINT		* Si no hay ninguno se acaba
			MOVE.B		IMRC,D6		* Se pone la copia del IMR en D6 para su posterior edición
			MOVE.W		SR,D7		* Se guarda el valor anterior del SR
			MOVE.W		#$2700,SR	* Se inhiben las interrupciones
			CMP.L		#3,D4		* Se comprueba el descriptor para editar el IMR
			BEQ		IMR_LB
			BSET		#0,D6		* Se pone el bit 0 a 1 para habilitar transmisiones en la línea A
			BRA		SETIMR
IMR_LB:			BSET		#4,D6		* Se pone el bit 4 a 1 para habilitar transmisiones en la línea B
SETIMR:			MOVE.B		D6,IMRC		* Se modifica copia IMR con el valor adecuado según la línea
			MOVE.B		D6,IMR		* Se modifica IMR para habilitar interrupciones de transmisión 
			MOVE.W		D7,SR		* Se recupera el valor anterior del SR

NOINT:		UNLK		A6		* Se recupera el valor de la pila
			RTS
**************************** FIN PRINT ********************************************************

**************************** SCAN ************************************************************
SCAN:		LINK		A6,#-14		* Crea marco de pila auxiliar
			MOVE.L		8(A6),A1	* Se guarda el buffer en A1
			MOVE.W		12(A6),D2	* Se guarda el descriptor en D2
			MOVE.W		14(A6),D3	* Se guarda el tamaño del bloque en D3
			CLR.L		D0			* Se inicializa D0 a 0
			SUB.L		#8,A7		* Reserva espacio en el marco de pila auxiliar
			CLR.L		D4			* Se inicializa D4 a 0 (se usará para el número de caracteres leídos)
			CMP.W		#0,D2		* Se comprueba si el descriptor es 0 (Línea A)
			BEQ		SCLIN_A
			CMP.W		#1,D2		* Se comprueba si el descriptor es 1 (Línea B)
			BEQ		SCLIN_B
			BRA		ERROR_S		* Si no es ni 0 ni 1 da ERROR

SCLIN_A: 	CLR.L 	 	D5			* Se inicializa D5 a 0 (se usará para el descriptor en LEECAR)
			BRA		BUC_SCAN

SCLIN_B: 	MOVE.L		#1,D5		* Inicializa D5 a 1 (se usará para el descriptor en LEECAR)

BUC_SCAN:	CMP.W		#0,D3			* Comprueba si el tamaño del bloque ha llegado a 0
			BEQ		FIN_SC			* Si ha llegado a 0 termina el bucle
			MOVE.L		A1,-4(A6)		* Se guarda la variable buffer
			MOVE.L		D5,-8(A6)		* Se guarda la variable descriptor
			MOVE.W		D3,-10(A6)		* Se guarda la variable tamaño bloque
			MOVE.L		D4,-14(A6)		* Se guarda la variable caracteres leídos
			MOVE.W		D5,D0			* Guarda el descriptor en D0 para su futuro uso
			BSR		LEECAR
			CMP.L		#-1,D0			* Comprueba si hay caracteres o no
			BEQ		FIN_SC			* Si no hay más caracteres para leer se acaba
			MOVE.L		-4(A6),A1		* Se recupera el buffer en A1
			MOVE.L		-8(A6),D5		* Recupera la variable descriptor
			MOVE.W		-10(A6),D3		* Se recupera el tamaño del bloque en D3
			MOVE.W		-12(A6),D4		* Se recuperan los caracteres leídos en D3
			MOVE.B		D0,(A1)+		* Si hay un caracter lo copia al buffer A1 y lo avanza
			ADD.L		#1,D4			* Incrementa los caracteres leídos por 1
			SUB.W		#1,D3			* Le resta 1 al tamaño	
			BNE		BUC_SCAN		* Salta al inicio del bucle
			BRA		FIN_SC

ERROR_S:	MOVE.L		#$FFFFFFFF,D4	* Coloca el estado error en D0 al no haber leído caracteres

FIN_SC:		MOVE.L		D4,D0		* Coloca la variable caracteres leídos en D0
			UNLK		A6		* Se recupera el valor de la pila
			RTS

************************** FIN SCAN *********************************************************

****************************** RTI **********************************************************

RTI: 		MOVEM.L		A1-A5/D0-D7,-(A7)	* Guarda todos los registros en la pila para evitar modificaciones a sus valores
			MOVE.B		ISR,D2		* Copia el ISR en D2
			AND.B		IMRC,D2		* Une la copia del IMR con el ISR para determinar la fuente de la interrupción y si está habilitada
			BTST		#0,D2				* Comprueba el estado del bit 0 de ISR
			BNE		TR_LINA					* Si es 1 entonces está habilitada la transmisión en la línea A y hay interrupción de transmisión
			BTST		#1,D2				* Comprueba el estado del bit 1 de ISR
			BNE		RC_LINA					* Si es 1 entonces está habilitada la recepción en la línea A y hay interrupción de recepción
			BTST		#4,D2				* Comprueba el estado del bit 4 de ISR
			BNE		TR_LINB					* Si es 1 entonces eshtá habilitada la transmisión en la línea B y hay interrupción de transmisión
			BTST		#5,D2				* Comprueba el estado del bit 5 de ISR
			BNE		RC_LINB					
			BRA		FIN_RTI				* Acaba la RTI
			
RC_LINA:	MOVE.B		RBA,D1				* Pone el caracter leído en D1 para su futuro uso en ESCCAR
			CLR.L		D0					* Inicializa D0 a todo ceros
			BSR			ESCCAR			* Ejecuta la subrutina ESCCAR para añadir el caracter leído a los búferes internos
			BRA		FIN_RTI				* Acaba la RTI tenga éxito o falle (ya que si falla no se añade el caracter de todas formas)
			
RC_LINB:	MOVE.B		RBB,D1				* Pone el caracter leído en D1 para su futuro uso en ESCCAR
			MOVE.L		#1,D0				* Pone D0 a 1 para su futuro uso como descriptor en ESSCAR
			BSR		ESCCAR				* Ejecuta la subrutina ESCCAR para añadir el caracter leído a los búferes internos
			BRA		FIN_RTI				* Acaba la RTI tenga éxito o falle (ya que si falla no se añade el caracter de todas formas)
			
TR_LINA:	MOVE.L		#2,D0				* Inicializa D0 a el buffer de transmisión de la linea A
			BSR		LEECAR
			CMP.L		#-1,D0				* Comprueba si LEECAR  ha fallado
			BEQ		FIN_TRA					* Acaba la transmisión en línea A ya que no hay caracteres para leer
			MOVE.B		D0,TBA				* Pone el caracter leído en la línea de transmisión
			BNE		FIN_RTI				* Acaba la RTI

FIN_TRA:		MOVE.B		IMRC,D6				* Pone la copia de IMR en D6 (ya que el IMR no puede leerse)
			BCLR		#0,D6				* Pone el bit 0 de D6 a 0
			MOVE.B		D6,IMRC				* Actualiza copia IMR para  indicar que las interrupciones de transmisión están desactivadas
			MOVE.B		D6,IMR				* Actualiza IMR para desactivar interrupciones de transmisión
			BRA		FIN_RTI				* Acaba la RTI

TR_LINB:	MOVE.L		#3,D0				* Inicializa D0 a el buffer de transmisión de la liena B en la pila
			BSR		LEECAR
			CMP.L		#-1,D0				* Comprueba si LEECAR  ha fallado
			BEQ		FIN_TRB				* Acaba la transmisión en línea B
			MOVE.B		D0,TBB				* Pone el caracter leído en la línea de transmisión
			BRA		FIN_RTI				* Acaba la RTI

FIN_TRB:		MOVE.B		IMRC,D6				* Pone la copia IMR en D6 (ya que el IMR no puede leerse)
			BCLR		#4,D6				* Pone el bit 4 de D6 a 0
			MOVE.B		D6,IMRC				* Actualiza copia IMR para indicar que las interrupciones de transmisión están desactivadas
			MOVE.B		D6,IMR				* Actualiza IMR para desactivar interrupciones de transmisión
			BRA		FIN_RTI				* Acaba la RTI

	
FIN_RTI:	MOVEM.L (A7)+,A0-A6/D0-D7	* Recupera todos los registros
			RTE



**************************** FIN RTI ********************************************************

**************************** FIN PROGRAMA PRINCIPAL ******************************************

**************************** PROGRAMA PRINCIPAL **********************************************
TAMANO EQU 5

BUFFER:		DS.B 2100 * Buffer para lectura y escritura de caracteres
PARDIR:		DC.L 0 * Direcci´on que se pasa como par´ametro
PARTAM:		DC.W 0 * Tama~no que se pasa como par´ametro
CONTC:		DC.W 0 * Contador de caracteres a imprimir
DESA:		EQU 0 * Descriptor l´ınea A
DESB:		EQU 1 * Descriptor l´ınea B
TAMBS:		EQU 10 * Tama~no de bloque para SCAN
TAMBP:		EQU 10 * Tama~no de bloque para PRINT

* Manejadores de excepciones
INICIO:		BSR INIT
		MOVE.W		#$2000,SR
		MOVE.W		#TAMBS,PARTAM
		MOVE.L		#BUFFER,PARDIR
TEST_SC:	MOVE.W		PARTAM,-(A7)
		MOVE.W		#DESA,-(A7)
		MOVE.L		PARDIR,-(A7)
		BSR		SCAN
		ADD.L		#8,A7
		ADD.L		D0,PARDIR
		SUB.W		D0,PARTAM
		BNE		TEST_SC

		MOVE.W		#TAMBS,CONTC
		MOVE.L		#BUFFER,PARDIR

OTRAE:		MOVE.W		#TAMBP,PARTAM

ESPE:		MOVE.W		PARTAM,-(A7)
		MOVE.W		#DESB,-(A7)
		MOVE.L		PARDIR,-(A7)
		BSR		PRINT
		ADD.L		#8,A7
		ADD.L		D0,PARDIR
		SUB.W		D0,CONTC
		BEQ		SALIR
		SUB.W		D0,PARTAM
		BNE		ESPE
		CMP.W		#TAMBP,CONTC
		BHI		OTRAE
		MOVE.W		CONTC,PARTAM
		BRA		ESPE

SALIR:		BREAK
**************************** FIN PROGRAMA PRINCIPAL ******************************************

INCLUDE bib_aux.s

