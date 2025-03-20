
.DATA
numberOfColors	    DWORD	0			    ;Liczba kolor�w
colorTablePtr	    QWORD	0			    ;Wska�nik na tablice kolor�w
sizeIn			    DWORD	0			    ;Rozmiar wej�ciowy
widthP			    DWORD	0			    ;Szeroko��
heightP			    DWORD	0			    ;Wysoko��
counterI            DWORD   0               ;Zmienna do iterowania w p�tli
counterJ            DWORD   0               ;Zmienna do iterowania w p�tli wewn�trznej
dataInPtr		    QWORD	0			    ;Wska�nik na dane wej�ciowe
sizeOut			    DWORD	0			    ;Rozmiar danych wyj�ciowych
dataOutPtr		    QWORD	0			    ;Wska�nnik na dane wyj�ciowe
parameter		    BYTE	0			    ;Parametr potrzebny do dzia�ania algorytmu
rowSizePaddingOut	DWORD	0			    ;Wiersz ��cznie z Paddingiem	
rowSizePaddingIn    DWORD	0			    ;Wiersz ��cznie z Paddingiem	
heapHandle		    QWORD	0               ;Uchwyt do sterty
errorBufferSize     QWORD   0               ;Rozmiar bufora b��d�w
errorBufferPtr	    QWORD	0               ;Wska�nik na bufor b��du
errorBufferDiag     REAL8   1.0             ;Bufor b��du po przek�tnej
errorBufferDiag1    REAL8   1.0             ;Bufor b��du po przek�tnej
errorBufferDiag2    REAL8   1.0             ;Bufor b��du po przek�tnej
currentPixelTrue    REAL8   0.0, 0.0, 0.0   ;Bufor prawdziej warto�ci pixela
currentPixel0       BYTE    0
currentPixel1       BYTE    0               ;Aktualnie przetwarzany pixel format BGR
currentPixel2       BYTE    0
minColorDiffrence   DWORD   16777215        ;Najmniejsza odleg�o�� pomi�dzy dwoma por�wnywanymi kolorami, specjalnie ustawiona pocz�tkowo na tak� warto�� 
nearestColorIndex   BYTE    0               ;Index koloru najmniejszej odleg�o�ci pomi�dzy kolorami
startTick           QWORD   0               ;Pocz�tkowa warto�� licznika takt�w

;Zewn�trzne procedury u�ywane w programie


.CODE
;-------------------------------------------------------------------------
; Procedura JohnSteinberg wykonuje dithering zdj�cia 
;-------------------------------------------------------------------------
;parametry funkcji: RCX RDX R8 R9 stos, 
;lub zmiennoproec.  XMM0 1 2 3

JohnSteinberg proc		

;------------------------------------------
; Pobranie argument�w z rejestr�w i stosu,
; zapisanie danych w zmiennych globalnych
;------------------------------------------

;Liczba kolor�w
mov eax, dword ptr [rcx]
mov numberOfColors, eax

;Wska�nik na tablic� kolor�w
mov colorTablePtr, rdx

;Liczba bajt�w danych (pixeli * 3)
mov eax, dword ptr[r8]
mov sizeIn, eax

;Szeroko�� zdj�cia
mov eax, dword ptr[r9]
mov widthP, eax
;mov widthCopy, eax

;Wysoko��, od 40 omini�cie shadow space
mov rax, [rsp + 40]
mov eax, dword ptr[rax]
mov heightP, eax
;mov heightCopy, eax

;Wska�nik na dane wej�ciowe
mov rax, [rsp + 48]
mov dataInPtr, rax

;Ilo�� bajt�w wyj�ciowych
mov rax, [rsp + 56] ;Ilo�� bajt�w Wyj�ciowych
mov eax, dword ptr[rax]
mov sizeOut, eax

;Wska�nik na dane wyj�ciowe
mov rax, [rsp + 64] 
mov dataOutPtr, rax

mov rax, [rsp + 72]
mov errorBufferPtr, rax


    ;-------------------------------------------------
    ; Pobranie pocz�tkowej warto�ci licznika takt�w
    ;-------------------------------------------------
    xor rax, rax
    rdtscp
    shl rdx, 32       ; Przesu� g�rne 32 bity
    or rax, rdx       ; Po��cz w jeden 64-bitowy wynik
    mov startTick, rax



;--------------------------------------------------
; Ustawienie parametru ze wzgl�du na ilo�� kolor�w
;--------------------------------------------------

mov eax, [numberOfColors]

; Sprawd�, czy liczba kolor�w to 256
cmp eax, 256
je  setAlign1        ; Je�li r�wna 256, ustaw alignBytesParameter = 1

; Sprawd�, czy liczba kolor�w to 16
cmp eax, 16
je  setAlign2        ; Je�li r�wna 16, ustaw alignBytesParameter = 2

; Sprawd�, czy liczba kolor�w to 1
cmp eax, 2
je  setAlign8        ; Je�li r�wna 1, ustaw alignBytesParameter = 8
jmp endIf0

setAlign1:
mov byte ptr [parameter], 1
jmp endIf0

setAlign2:
mov byte ptr [parameter], 2
jmp endIf0

setAlign8:
mov byte ptr [parameter], 8
jmp endIf0

endIf0:

;--------------------------------------------------------------
; G��wna cz�� programu iterowanie po pixelach obliczanie 
; najbli�szego koloru, propagowanie b��du, zapisywanie wynik�w
;--------------------------------------------------------------

;Obliczenie rozmiaru wiersza z paddingiem
mov eax, sizeOut
xor rdx, rdx
mov ebx, heightP
div ebx
mov [rowSizePaddingOut], eax

mov eax, sizeIn
xor rdx, rdx
mov ebx, heightP
div ebx
mov [rowSizePaddingIn], eax

;Wyzerowanie index�w i i j przed p�tl�
xor eax, eax
mov [counterI], eax
mov [counterJ], eax

;Zewn�trzna p�tla, iterowanie po wysoko�ci zdj�cia
outerLoop:

;for(int i = 0; i<height; i++)
mov eax, [counterI]
cmp eax, [heightP]
jae endOuterLoop

;Wyzerowanie bufora b��d�w
xor rax,rax
mov REAL8 PTR [errorBufferDiag], rax       ;Pierwszy element ustawiamy na 0.0
mov REAL8 PTR [errorBufferDiag + 8], rax   ;Drugi element ustawiamy na 0.0
mov REAL8 PTR [errorBufferDiag + 16], rax  ;Trzeci element ustawiamy na 0.0

	innerLoop:
	mov eax, [counterJ]
	cmp eax, [widthP]
	jae endInnerLoop
    
    ;-------------------------------------------------------------------------------------------------------
    ; Pobranie pixela warto�ci pixela za pomoc� wzoru
    ; rowSizePadding * counterI + 3 * counterJ
    ;-------------------------------------------------------------------------------------------------------
    
    xor rax, rax
    mov eax, [counterI]
    mov ebx, [rowSizePaddingIn]
    imul eax, ebx
    mov ecx, eax
    xor rax, rax
    mov eax, [counterJ]
    imul eax, 3
    add eax, ecx

    mov rbx, [dataInPtr] 
    mov eax, [rbx + rax] ;Pobrana warto�� pixela w eax
    
    ;---------------------------------------------------
    ; Zapisanie obecnego pixela w buforze currentPixel0
    ;----------------------------------------------------

    mov [currentPixel0], al
    mov [currentPixel0 + 1], ah
    shr eax, 16
    mov [currentPixel0 + 2], al

    ;-------------------------------------------------------
    ; Obliczenie warto�ci nowego pixela na podstawie
    ; warto�ci starego pixela i warto�ci bufora b��du
    ; Pocz�tkowo pixel jest zapisywany w double
    ; pozwoli to na propagowanie tak�e ma�ej warto�ci b��du
    ;--------------------------------------------------------

	mov rbx, [errorBufferPtr]       ;rbx = wska�nik do errorTable
    mov eax, [counterJ]
    mov rsi, rax                    ;rsi = counterJ (indeks)

	;Obliczanie indeksu w errorTable (3 * counterJ)
	imul rsi, rsi, 3               ; rsi = 3 * counterJ
    imul rsi, rsi, 8

	;Pobierz warto�ci z errorTable[3 * j], errorTable[3 * j + 1], errorTable[3 * j + 2], kolejne sk�adowe pixela
	movsd xmm0, real8 ptr[rbx + rsi]        ; errorTable[3 * j] -> xmm0 
	movsd xmm1, real8 ptr[rbx + rsi + 8]    ; errorTable[3 * j + 1] -> xmm1 
	movsd xmm2, real8 ptr[rbx + rsi + 16]   ; errorTable[3 * j + 2] -> xmm2 

	;Pobranie warto�ci z currentPixel0 (B, G, R)
	mov al, [currentPixel0]       ; B - pierwszy bajt
	mov bl, [currentPixel0 + 1]   ; G - drugi bajt
	mov cl, [currentPixel0 + 2]   ; R - trzeci bajt

	;Dodanie warto�ci B (currentPixel0) do errorTable[3 * j]
	movzx rdx, al                  ; Zmienna B (currentPixel0) w rejestrze rdx
	cvtsi2sd xmm3, rdx             ; Konwertowanie B do typu double (xmm3)
	addsd xmm0, xmm3               ; errorTable[3 * j] += B

	;Dodanie warto�ci G (currentPixel0+1) do errorTable[3 * j + 1]
	movzx rdx, bl                  ; Zmienna G (currentPixel0+1) w rejestrze rdx
	cvtsi2sd xmm3, rdx             ; Konwertowanie G do typu double (xmm3)
	addsd xmm1, xmm3               ; errorTable[3 * j + 1] += G

	;Dodanie warto�ci R (currentPixel0+2) do errorTable[3 * j + 2]
	movzx rdx, cl                  ; Zmienna R (currentPixel0+2) w rejestrze rdx
	cvtsi2sd xmm3, rdx             ; Konwertowanie R do typu double (xmm3)
	addsd xmm2, xmm3               ; errorTable[3 * j + 2] += R

    ;-----------------------------------------------------------------------------------
    ; Ograniczenie maksymalnej aktywacji pixela w przypadku braku tej funkcji 
    ; w wynikowym obrazie mog� powsta� niedoskona�o�ci w postaci smug
    ;-----------------------------------------------------------------------------------

    ;Zrzutowanie warto�ci double do warto�ci -255, 255 dla ka�dego koloru
    mov rax, 06fe00000000000h     ;Sta�a -255 (dla ograniczenia od do�u)
	movq xmm3, rax                  ;Przenie� do xmm3
	mov rax, 406fe00000000000h      ;Sta�a 255.0 w postaci IEEE 754
	movq xmm4, rax                  ;Przenie� do xmm4

    ; Przetwarzanie xmm0
	maxsd xmm0, xmm3                ;Ogranicz dolny zakres: max(xmm0, -255.0)
	minsd xmm0, xmm4                ;Ogranicz g�rny zakres: min(xmm0, 255.0)

	; Przetwarzanie xmm1
	maxsd xmm1, xmm3                ; Ogranicz dolny zakres: max(xmm1, 0.0)
	minsd xmm1, xmm4                ; Ogranicz g�rny zakres: min(xmm1, 255.0)

	; Przetwarzanie xmm2
	maxsd xmm2, xmm3                ; Ogranicz dolny zakres: max(xmm2, 0.0)
	minsd xmm2, xmm4                ; Ogranicz g�rny zakres: min(xmm2, 255.0)

    ;Zapisanie warto�ci BGR w postaci double w buforze
    movsd real8 ptr [currentPixelTrue], xmm0
    movsd real8 ptr [currentPixelTrue + 8], xmm1
    movsd real8 ptr [currentPixelTrue + 16], xmm2

    ;Zrzutowanie warto�ci double do warto�ci 0, 255 dla ka�dego koloru
    xor rax, rax                    ;Sta�a 0.0 (dla ograniczenia od do�u)
	movq xmm3, rax                  ;Przenie� do xmm3
	mov rax, 406fe00000000000h     ;Sta�a 255.0 w postaci IEEE 754
	movq xmm4, rax                  ;Przenie� do xmm4

    ; Przetwarzanie xmm0
	maxsd xmm0, xmm3                ;Ogranicz dolny zakres: max(xmm0, 0.0)
	minsd xmm0, xmm4                ;Ogranicz g�rny zakres: min(xmm0, 255.0)
	cvttsd2si eax, xmm0             ;Konwersja do liczby ca�kowitej (zaokr�glenie w d�)
	mov [currentPixel0], al         ;Przenie� wynik do pami�ci, nadpisanie currentPixel, z uwzgl�dnionym b��dem 

	; Przetwarzanie xmm1
	maxsd xmm1, xmm3                ; Ogranicz dolny zakres: max(xmm1, 0.0)
	minsd xmm1, xmm4                ; Ogranicz g�rny zakres: min(xmm1, 255.0)
	cvttsd2si eax, xmm1             ; Konwersja do liczby ca�kowitej (zaokr�glenie w d�)
	mov [currentPixel0 + 1], al     ;Przenie� wynik do pami�ci, nadpisanie currentPixel, z uwzgl�dnionym b��dem

	; Przetwarzanie xmm2
	maxsd xmm2, xmm3                ; Ogranicz dolny zakres: max(xmm2, 0.0)
	minsd xmm2, xmm4                ; Ogranicz g�rny zakres: min(xmm2, 255.0)
	cvttsd2si eax, xmm2             ; Konwersja do liczby ca�kowitej (zaokr�glenie w d�)
	mov [currentPixel0 + 2], al     ;Przenie� wynik do pami�ci, nadpisanie currentPixel, z uwzgl�dnionym b��dem

    ;---------------------------------
    ; Obliczenie najbli�szego koloru
    ;---------------------------------

	mov [minColorDiffrence], 0FFFFFFFFh
    mov [nearestColorIndex], 0h

    movzx r9d, [currentPixel0]          ;B - Warto�� niebieski
    movzx r10d, [currentPixel0 + 1]      ;G - Warto�� zielony
    movzx r11d, [currentPixel0 + 2]     ;R - Warto�� czerwony

    xor rcx, rcx
    nearestColorLoop:
    mov eax, [numberOfColors]
    cmp rcx, rax
    jae endNearestColorLoop

    ;Pobranie koloru z tablicy
    mov rbx, [colorTablePtr]
    mov rax, rcx
    imul rax, 4
    mov eax, [rbx + rax]

    ;W eax BGRA
    movzx r12d, al      ;B -> r12
    shr eax, 8
    movzx r13d, al      ;G -> r13 
    shr eax, 8         ;R -> r14
    movzx r14d, al

    ;Obliczenie dystansu
   
    sub r12d, r9d
    imul r12d, r12d
    sub r13d, r10d
    imul r13d, r13d
    sub r14d, r11d
    imul r14d, r14d

    xor edi, edi
    add edi, r12d
    add edi, r13d
    add edi, r14d
    
    mov eax, [minColorDiffrence]
    cmp edi, eax
    jae skipIndexSaving
    mov [minColorDiffrence], edi
    mov [nearestColorIndex], cl
skipIndexSaving:
    inc rcx
    jmp nearestColorLoop
    endNearestColorLoop:

    ;----------------------------------------
    ; Zapisanie indexu w danych wyj�ciowych
    ;----------------------------------------

    mov rbx, [dataOutPtr]
	mov eax, [rowSizePaddingOut];eax = rowSizePadding
	mov ecx, [counterI]         ;ecx = iCounter
	imul eax, ecx               ;eax = rowSizePadding * iCounter
    mov r10d, eax               ;r10 = rowSizePadding * iCounter

	mov eax, [counterJ]             ;eax = jCounter
    xor edx, edx                    ;Wyczyszczenie g�rnych bajt�w potrzebne aby upewni� si� �e div b�dzie dzia�a� prawid�owo
	movzx ecx, [parameter]            ;ecx = alignBytesParameter
	div ecx                         ;edx:eax / ecx -> eax = jCounter / alignBytesParameter

	add eax, r10d                ;eax = (rowSizePadding * iCounter) + (jCounter / alignBytesParameter), index pixela
    mov rsi, rax
    
    cmp byte ptr[parameter], 1
    je save8bitColor 
        
    cmp byte ptr[parameter], 2
    je save4bitColor 

    cmp byte ptr[parameter], 8
    je save1bitColor 

save8bitColor:
    mov al, byte ptr[nearestColorIndex]
    mov rbx, [dataOutPtr]
    mov byte ptr[rbx + rsi], al
	jmp endSavingColor

save4bitColor:
    mov rbx, [dataOutPtr]
    xor rdx, rdx
    movzx rcx, [parameter]
    mov eax, [counterJ]
    div rcx             ;Pixelnumber % alignbytes parameter
    imul rdx, rdx, 4    ;(Pixelnumber % alignbytes parameter) * 4
    mov ecx, 4
    sub ecx, edx        ;ecx = 4 - (pixelNumber % alignBytesParameter) * 4, offset danych w bajcie
    mov al, byte ptr[nearestColorIndex]
    shl al, cl
    or byte ptr[rbx + rsi], al
	jmp endSavingColor

save1bitColor:
	mov rbx, [dataOutPtr]
    xor rdx, rdx
    movzx rcx, [parameter]
    mov eax, [counterJ]
    div rcx             ;Pixelnumber % alignbytes parameter
    mov ecx, 7          
    sub ecx, edx        ;7 - (Pixelnumber % alignbytes parameter) 
	mov al, byte ptr[nearestColorIndex]
    shl al, cl
    or byte ptr[rbx + rsi], al
	jmp endSavingColor

    endSavingColor:


    ;-------------------------------------------
    ; Propagowanie b��du na kolejne kom�rki
    ; zgodnie z algorytmem Floyda-Steinberga
    ;-------------------------------------------

    ;Przeniesienie warto�ci pixela w formacie double z pami�ci do odpowiednich rejestr�w
	movsd xmm0, real8 ptr [currentPixelTrue]        ;xmm0 <- True Blue
	movsd xmm1, real8 ptr [currentPixelTrue + 8]    ;xmm1 <- True Green
    movsd xmm2, real8 ptr [currentPixelTrue + 16]   ;xmm2 <- True Red

    ;Pobranie koloru z tablicy
    mov rbx, [colorTablePtr]
    movzx eax, byte ptr[nearestColorIndex]
    imul eax, eax, 4
	mov eax, [rbx + rax]

    ;W eax BGRA
    movzx r12d, al      ;B -> r12
    shr eax, 8
    movzx r13d, al      ;G -> r13 
    shr eax, 8          
    movzx r14d, al      ;R -> r14

    ;Zapisanie kolor�w uint32_t w rejestrach double  
	cvtsi2sd xmm3, r12d      ;Konwertuje r12d (uint32_t) na double i zapisuje w xmm3
	cvtsi2sd xmm4, r13d      ;Konwertuje r13d (uint32_t) na double i zapisuje w xmm4
	cvtsi2sd xmm5, r14d      ;Konwertuje r14d (uint32_t) na double i zapisuje w xmm5

    ;Obliczenie b��du absolutnego
	subsd xmm0, xmm3         ;xmm0 = xmm0 - xmm3 (TrueBlue - Blue z tablicy)
	subsd xmm1, xmm4         ;xmm0 = xmm1 - xmm4 (TrueGreen - Green z tablicy)
	subsd xmm2, xmm5         ;xmm0 = xmm2 - xmm5 (TrueRed - Red z tablicy)

    ;Zapisywanie propagowanego b��du zgodnie z wagami w zale�no�ci od pozycji aktualnego pixela zdj�cia, uwzgl�dnienie skrajnych pixeli 
	mov rbx, [errorBufferPtr]       ;rbx = wska�nik do errorTable

    ;if j > 0
    cmp [counterJ], 0
    ja ditherLeftUp
    jmp endDitherLeftUp    
    
ditherLeftUp:
    mov edi, [counterJ]
    dec edi
    imul rdi, rdi, 3
    imul rdi, rdi, 8

    ;Przeniesienie b��du do innych rejestr�w
    movsd xmm3, xmm0    ;xmm3 = (TrueBlue - Blue), b��d absolutny mi�dzy rzeczywist�, a wybran� warto�ci� pixela
    movsd xmm4, xmm1    ;xmm4 = (TrueGreen - Green), b��d absolutny mi�dzy rzeczywist�, a wybran� warto�ci� pixela
    movsd xmm5, xmm2    ;xmm5 = (TrueRed - Red), b��d absolutny mi�dzy rzeczywist�, a wybran� warto�ci� pixela

    ;Zastosowanie wagi 3/16
    mov rax, 4008000000000000h ;3.0 warto��
    movq xmm6, rax

    mulsd xmm3, xmm6
    mulsd xmm4, xmm6
    mulsd xmm5, xmm6

    mov rax, 4030000000000000h ;16.0 warto��
    movq xmm6, rax

    divsd xmm3, xmm6
    divsd xmm4, xmm6
    divsd xmm5, xmm6

    ;Propagowanie b��du Blue
    movsd xmm6, real8 ptr[rbx + rdi]     ;Za�adowanie b��du z pami�ci
    addsd xmm3, xmm6            ;Dodanie do nowego b��du
    movsd real8 ptr[rbx + rdi], xmm3     ;Zapisanie nowego b��du

    ;Propagowanie b��du Green
    movsd xmm6, real8 ptr[rbx + rdi + 8]
    addsd xmm4, xmm6
    movsd real8 ptr[rbx + rdi + 8], xmm4 

    ;Propagowanie b��du Red
    movsd xmm6, real8 ptr[rbx + rdi + 16]
    addsd xmm5, xmm6
    movsd real8 ptr[rbx + rdi + 16], xmm5 

endDitherLeftUp:
    
    mov eax, [counterJ]
    inc eax
    cmp eax, [widthP]
    jl ditherRight
    jmp endDitherRight

ditherRight:

    mov edi, [counterJ]
    inc edi
    imul rdi, rdi, 3
    imul rdi, rdi, 8

    ;Przeniesienie b��du do innych rejestr�w
    movsd xmm3, xmm0    ;xmm3 = (TrueBlue - Blue), b��d absolutny mi�dzy rzeczywist�, a wybran� warto�ci� pixela
    movsd xmm4, xmm1    ;xmm4 = (TrueGreen - Green), b��d absolutny mi�dzy rzeczywist�, a wybran� warto�ci� pixela
    movsd xmm5, xmm2    ;xmm5 = (TrueRed - Red), b��d absolutny mi�dzy rzeczywist�, a wybran� warto�ci� pixela

    ;Zastosowanie wagi 7/16
    mov rax, 401c000000000000h ;7.0 warto��
    movq xmm6, rax

    mulsd xmm3, xmm6
    mulsd xmm4, xmm6
    mulsd xmm5, xmm6

    mov rax, 3fb0000000000000h ;16.0 warto��
    movq xmm6, rax

    mulsd xmm3, xmm6
    mulsd xmm4, xmm6
    mulsd xmm5, xmm6

    ;Propagowanie b��du Blue
    movsd xmm6, real8 ptr[rbx + rdi]     ;Za�adowanie b��du z pami�ci
    addsd xmm3, xmm6            ;Dodanie do nowego b��du
    movsd real8 ptr[rbx + rdi], xmm3     ;Zapisanie nowego b��du

    ;Propagowanie b��du Green
    movsd xmm6, real8 ptr[rbx + rdi + 8]
    addsd xmm4, xmm6
    movsd real8 ptr[rbx + rdi + 8], xmm4 

    ;Propagowanie b��du Red
    movsd xmm6, real8 ptr[rbx + rdi + 16]
    addsd xmm5, xmm6
    movsd real8 ptr[rbx + rdi + 16], xmm5 
     
endDitherRight:

ditherUp:
	mov edi, [counterJ]
	imul rdi, rdi, 3
	imul rdi, rdi, 8

	;Przeniesienie b��du do innych rejestr�w
	movsd xmm3, xmm0    ;xmm3 = (TrueBlue - Blue), b��d absolutny mi�dzy rzeczywist�, a wybran� warto�ci� pixela
	movsd xmm4, xmm1    ;xmm4 = (TrueGreen - Green), b��d absolutny mi�dzy rzeczywist�, a wybran� warto�ci� pixela
	movsd xmm5, xmm2    ;xmm5 = (TrueRed - Red), b��d absolutny mi�dzy rzeczywist�, a wybran� warto�ci� pixela

	;Zastosowanie wagi 5/16, oraz zaporzyczenie z diagErrorBuffer
	mov rax, 4014000000000000h   ;5.0 warto��
	movq xmm6, rax

	mulsd xmm3, xmm6
	mulsd xmm4, xmm6
	mulsd xmm5, xmm6

	mov rax, 3fb0000000000000h ;16.0 warto��
	movq xmm6, rax

	mulsd xmm3, xmm6
	mulsd xmm4, xmm6
	mulsd xmm5, xmm6

	;Propagowanie b��du Blue
	movsd xmm6, [errorBufferDiag]     ;Za�adowanie b��du z pami�ci
	addsd xmm3, xmm6                           ;Dodanie do nowego b��du
	movsd real8 ptr[rbx + rdi], xmm3           ;Zapisanie nowego b��du

	;Propagowanie b��du Green
	movsd xmm6, real8 ptr[errorBufferDiag + 8]
	addsd xmm4, xmm6
	movsd real8 ptr[rbx + rdi + 8], xmm4 

	;Propagowanie b��du Red
	movsd xmm6, real8 ptr[errorBufferDiag + 16]
	addsd xmm5, xmm6
	movsd real8 ptr[rbx + rdi + 16], xmm5 

   
    ;Zbuforowanie b�edu propagowanego po przek�tnej
    mov rax, 3fb0000000000000h ;1/16.0 warto��
	movq xmm6, rax

	mulsd xmm0, xmm6
	mulsd xmm1, xmm6
	mulsd xmm2, xmm6

     movsd real8 ptr[errorBufferDiag], xmm0
     movsd real8 ptr[errorBufferDiag + 8], xmm1
     movsd real8 ptr[errorBufferDiag + 16], xmm2

    inc [counterJ]
	jmp innerLoop

endInnerLoop:
mov [counterJ], 0
inc [counterI]
jmp outerLoop
endOuterLoop:

;---------------------------------------------------
; Pobranie ko�cowej warto�ci licznika cykli zegara
;---------------------------------------------------
rdtscp
shl rdx, 32       ; Przesu� g�rne 32 bity
or rax, rdx       ; Po��cz w jeden 64-bitowy wynik
sub rax, [startTick]
ret							;Zako�cz procedur�
JohnSteinberg endp
END 			;no entry point
;-------------------------------------------------------------------------
