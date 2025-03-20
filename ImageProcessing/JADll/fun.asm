
.DATA
numberOfColors	    DWORD	0			    ;Liczba kolorów
colorTablePtr	    QWORD	0			    ;WskaŸnik na tablice kolorów
sizeIn			    DWORD	0			    ;Rozmiar wejœciowy
widthP			    DWORD	0			    ;Szerokoœæ
heightP			    DWORD	0			    ;Wysokoœæ
counterI            DWORD   0               ;Zmienna do iterowania w pêtli
counterJ            DWORD   0               ;Zmienna do iterowania w pêtli wewnêtrznej
dataInPtr		    QWORD	0			    ;WskaŸnik na dane wejœciowe
sizeOut			    DWORD	0			    ;Rozmiar danych wyjœciowych
dataOutPtr		    QWORD	0			    ;WskaŸnnik na dane wyjœciowe
parameter		    BYTE	0			    ;Parametr potrzebny do dzia³ania algorytmu
rowSizePaddingOut	DWORD	0			    ;Wiersz £¹cznie z Paddingiem	
rowSizePaddingIn    DWORD	0			    ;Wiersz £¹cznie z Paddingiem	
heapHandle		    QWORD	0               ;Uchwyt do sterty
errorBufferSize     QWORD   0               ;Rozmiar bufora b³êdów
errorBufferPtr	    QWORD	0               ;WskaŸnik na bufor b³êdu
errorBufferDiag     REAL8   1.0             ;Bufor b³êdu po przek¹tnej
errorBufferDiag1    REAL8   1.0             ;Bufor b³êdu po przek¹tnej
errorBufferDiag2    REAL8   1.0             ;Bufor b³êdu po przek¹tnej
currentPixelTrue    REAL8   0.0, 0.0, 0.0   ;Bufor prawdziej wartoœci pixela
currentPixel0       BYTE    0
currentPixel1       BYTE    0               ;Aktualnie przetwarzany pixel format BGR
currentPixel2       BYTE    0
minColorDiffrence   DWORD   16777215        ;Najmniejsza odleg³oœæ pomiêdzy dwoma porównywanymi kolorami, specjalnie ustawiona pocz¹tkowo na tak¹ wartoœæ 
nearestColorIndex   BYTE    0               ;Index koloru najmniejszej odleg³oœci pomiêdzy kolorami
startTick           QWORD   0               ;Pocz¹tkowa wartoœæ licznika taktów

;Zewnêtrzne procedury u¿ywane w programie


.CODE
;-------------------------------------------------------------------------
; Procedura JohnSteinberg wykonuje dithering zdjêcia 
;-------------------------------------------------------------------------
;parametry funkcji: RCX RDX R8 R9 stos, 
;lub zmiennoproec.  XMM0 1 2 3

JohnSteinberg proc		

;------------------------------------------
; Pobranie argumentów z rejestrów i stosu,
; zapisanie danych w zmiennych globalnych
;------------------------------------------

;Liczba kolorów
mov eax, dword ptr [rcx]
mov numberOfColors, eax

;WskaŸnik na tablicê kolorów
mov colorTablePtr, rdx

;Liczba bajtów danych (pixeli * 3)
mov eax, dword ptr[r8]
mov sizeIn, eax

;Szerokoœæ zdjêcia
mov eax, dword ptr[r9]
mov widthP, eax
;mov widthCopy, eax

;Wysokoœæ, od 40 ominiêcie shadow space
mov rax, [rsp + 40]
mov eax, dword ptr[rax]
mov heightP, eax
;mov heightCopy, eax

;WskaŸnik na dane wejœciowe
mov rax, [rsp + 48]
mov dataInPtr, rax

;Iloœæ bajtów wyjœciowych
mov rax, [rsp + 56] ;Iloœæ bajtów Wyjœciowych
mov eax, dword ptr[rax]
mov sizeOut, eax

;WskaŸnik na dane wyjœciowe
mov rax, [rsp + 64] 
mov dataOutPtr, rax

mov rax, [rsp + 72]
mov errorBufferPtr, rax


    ;-------------------------------------------------
    ; Pobranie pocz¹tkowej wartoœci licznika taktów
    ;-------------------------------------------------
    xor rax, rax
    rdtscp
    shl rdx, 32       ; Przesuñ górne 32 bity
    or rax, rdx       ; Po³¹cz w jeden 64-bitowy wynik
    mov startTick, rax



;--------------------------------------------------
; Ustawienie parametru ze wzglêdu na iloœæ kolorów
;--------------------------------------------------

mov eax, [numberOfColors]

; SprawdŸ, czy liczba kolorów to 256
cmp eax, 256
je  setAlign1        ; Jeœli równa 256, ustaw alignBytesParameter = 1

; SprawdŸ, czy liczba kolorów to 16
cmp eax, 16
je  setAlign2        ; Jeœli równa 16, ustaw alignBytesParameter = 2

; SprawdŸ, czy liczba kolorów to 1
cmp eax, 2
je  setAlign8        ; Jeœli równa 1, ustaw alignBytesParameter = 8
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
; G³ówna czêœæ programu iterowanie po pixelach obliczanie 
; najbli¿szego koloru, propagowanie b³êdu, zapisywanie wyników
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

;Wyzerowanie indexów i i j przed pêtl¹
xor eax, eax
mov [counterI], eax
mov [counterJ], eax

;Zewnêtrzna pêtla, iterowanie po wysokoœci zdjêcia
outerLoop:

;for(int i = 0; i<height; i++)
mov eax, [counterI]
cmp eax, [heightP]
jae endOuterLoop

;Wyzerowanie bufora b³êdów
xor rax,rax
mov REAL8 PTR [errorBufferDiag], rax       ;Pierwszy element ustawiamy na 0.0
mov REAL8 PTR [errorBufferDiag + 8], rax   ;Drugi element ustawiamy na 0.0
mov REAL8 PTR [errorBufferDiag + 16], rax  ;Trzeci element ustawiamy na 0.0

	innerLoop:
	mov eax, [counterJ]
	cmp eax, [widthP]
	jae endInnerLoop
    
    ;-------------------------------------------------------------------------------------------------------
    ; Pobranie pixela wartoœci pixela za pomoc¹ wzoru
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
    mov eax, [rbx + rax] ;Pobrana wartoœæ pixela w eax
    
    ;---------------------------------------------------
    ; Zapisanie obecnego pixela w buforze currentPixel0
    ;----------------------------------------------------

    mov [currentPixel0], al
    mov [currentPixel0 + 1], ah
    shr eax, 16
    mov [currentPixel0 + 2], al

    ;-------------------------------------------------------
    ; Obliczenie wartoœci nowego pixela na podstawie
    ; wartoœci starego pixela i wartoœci bufora b³êdu
    ; Pocz¹tkowo pixel jest zapisywany w double
    ; pozwoli to na propagowanie tak¿e ma³ej wartoœci b³êdu
    ;--------------------------------------------------------

	mov rbx, [errorBufferPtr]       ;rbx = wskaŸnik do errorTable
    mov eax, [counterJ]
    mov rsi, rax                    ;rsi = counterJ (indeks)

	;Obliczanie indeksu w errorTable (3 * counterJ)
	imul rsi, rsi, 3               ; rsi = 3 * counterJ
    imul rsi, rsi, 8

	;Pobierz wartoœci z errorTable[3 * j], errorTable[3 * j + 1], errorTable[3 * j + 2], kolejne sk³adowe pixela
	movsd xmm0, real8 ptr[rbx + rsi]        ; errorTable[3 * j] -> xmm0 
	movsd xmm1, real8 ptr[rbx + rsi + 8]    ; errorTable[3 * j + 1] -> xmm1 
	movsd xmm2, real8 ptr[rbx + rsi + 16]   ; errorTable[3 * j + 2] -> xmm2 

	;Pobranie wartoœci z currentPixel0 (B, G, R)
	mov al, [currentPixel0]       ; B - pierwszy bajt
	mov bl, [currentPixel0 + 1]   ; G - drugi bajt
	mov cl, [currentPixel0 + 2]   ; R - trzeci bajt

	;Dodanie wartoœci B (currentPixel0) do errorTable[3 * j]
	movzx rdx, al                  ; Zmienna B (currentPixel0) w rejestrze rdx
	cvtsi2sd xmm3, rdx             ; Konwertowanie B do typu double (xmm3)
	addsd xmm0, xmm3               ; errorTable[3 * j] += B

	;Dodanie wartoœci G (currentPixel0+1) do errorTable[3 * j + 1]
	movzx rdx, bl                  ; Zmienna G (currentPixel0+1) w rejestrze rdx
	cvtsi2sd xmm3, rdx             ; Konwertowanie G do typu double (xmm3)
	addsd xmm1, xmm3               ; errorTable[3 * j + 1] += G

	;Dodanie wartoœci R (currentPixel0+2) do errorTable[3 * j + 2]
	movzx rdx, cl                  ; Zmienna R (currentPixel0+2) w rejestrze rdx
	cvtsi2sd xmm3, rdx             ; Konwertowanie R do typu double (xmm3)
	addsd xmm2, xmm3               ; errorTable[3 * j + 2] += R

    ;-----------------------------------------------------------------------------------
    ; Ograniczenie maksymalnej aktywacji pixela w przypadku braku tej funkcji 
    ; w wynikowym obrazie mog¹ powstaæ niedoskona³oœci w postaci smug
    ;-----------------------------------------------------------------------------------

    ;Zrzutowanie wartoœci double do wartoœci -255, 255 dla ka¿dego koloru
    mov rax, 06fe00000000000h     ;Sta³a -255 (dla ograniczenia od do³u)
	movq xmm3, rax                  ;Przenieœ do xmm3
	mov rax, 406fe00000000000h      ;Sta³a 255.0 w postaci IEEE 754
	movq xmm4, rax                  ;Przenieœ do xmm4

    ; Przetwarzanie xmm0
	maxsd xmm0, xmm3                ;Ogranicz dolny zakres: max(xmm0, -255.0)
	minsd xmm0, xmm4                ;Ogranicz górny zakres: min(xmm0, 255.0)

	; Przetwarzanie xmm1
	maxsd xmm1, xmm3                ; Ogranicz dolny zakres: max(xmm1, 0.0)
	minsd xmm1, xmm4                ; Ogranicz górny zakres: min(xmm1, 255.0)

	; Przetwarzanie xmm2
	maxsd xmm2, xmm3                ; Ogranicz dolny zakres: max(xmm2, 0.0)
	minsd xmm2, xmm4                ; Ogranicz górny zakres: min(xmm2, 255.0)

    ;Zapisanie wartoœci BGR w postaci double w buforze
    movsd real8 ptr [currentPixelTrue], xmm0
    movsd real8 ptr [currentPixelTrue + 8], xmm1
    movsd real8 ptr [currentPixelTrue + 16], xmm2

    ;Zrzutowanie wartoœci double do wartoœci 0, 255 dla ka¿dego koloru
    xor rax, rax                    ;Sta³a 0.0 (dla ograniczenia od do³u)
	movq xmm3, rax                  ;Przenieœ do xmm3
	mov rax, 406fe00000000000h     ;Sta³a 255.0 w postaci IEEE 754
	movq xmm4, rax                  ;Przenieœ do xmm4

    ; Przetwarzanie xmm0
	maxsd xmm0, xmm3                ;Ogranicz dolny zakres: max(xmm0, 0.0)
	minsd xmm0, xmm4                ;Ogranicz górny zakres: min(xmm0, 255.0)
	cvttsd2si eax, xmm0             ;Konwersja do liczby ca³kowitej (zaokr¹glenie w dó³)
	mov [currentPixel0], al         ;Przenieœ wynik do pamiêci, nadpisanie currentPixel, z uwzglêdnionym b³êdem 

	; Przetwarzanie xmm1
	maxsd xmm1, xmm3                ; Ogranicz dolny zakres: max(xmm1, 0.0)
	minsd xmm1, xmm4                ; Ogranicz górny zakres: min(xmm1, 255.0)
	cvttsd2si eax, xmm1             ; Konwersja do liczby ca³kowitej (zaokr¹glenie w dó³)
	mov [currentPixel0 + 1], al     ;Przenieœ wynik do pamiêci, nadpisanie currentPixel, z uwzglêdnionym b³êdem

	; Przetwarzanie xmm2
	maxsd xmm2, xmm3                ; Ogranicz dolny zakres: max(xmm2, 0.0)
	minsd xmm2, xmm4                ; Ogranicz górny zakres: min(xmm2, 255.0)
	cvttsd2si eax, xmm2             ; Konwersja do liczby ca³kowitej (zaokr¹glenie w dó³)
	mov [currentPixel0 + 2], al     ;Przenieœ wynik do pamiêci, nadpisanie currentPixel, z uwzglêdnionym b³êdem

    ;---------------------------------
    ; Obliczenie najbli¿szego koloru
    ;---------------------------------

	mov [minColorDiffrence], 0FFFFFFFFh
    mov [nearestColorIndex], 0h

    movzx r9d, [currentPixel0]          ;B - Wartoœæ niebieski
    movzx r10d, [currentPixel0 + 1]      ;G - Wartoœæ zielony
    movzx r11d, [currentPixel0 + 2]     ;R - Wartoœæ czerwony

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
    ; Zapisanie indexu w danych wyjœciowych
    ;----------------------------------------

    mov rbx, [dataOutPtr]
	mov eax, [rowSizePaddingOut];eax = rowSizePadding
	mov ecx, [counterI]         ;ecx = iCounter
	imul eax, ecx               ;eax = rowSizePadding * iCounter
    mov r10d, eax               ;r10 = rowSizePadding * iCounter

	mov eax, [counterJ]             ;eax = jCounter
    xor edx, edx                    ;Wyczyszczenie górnych bajtów potrzebne aby upewniæ siê ¿e div bêdzie dzia³aæ prawid³owo
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
    ; Propagowanie b³êdu na kolejne komórki
    ; zgodnie z algorytmem Floyda-Steinberga
    ;-------------------------------------------

    ;Przeniesienie wartoœci pixela w formacie double z pamiêci do odpowiednich rejestrów
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

    ;Zapisanie kolorów uint32_t w rejestrach double  
	cvtsi2sd xmm3, r12d      ;Konwertuje r12d (uint32_t) na double i zapisuje w xmm3
	cvtsi2sd xmm4, r13d      ;Konwertuje r13d (uint32_t) na double i zapisuje w xmm4
	cvtsi2sd xmm5, r14d      ;Konwertuje r14d (uint32_t) na double i zapisuje w xmm5

    ;Obliczenie b³êdu absolutnego
	subsd xmm0, xmm3         ;xmm0 = xmm0 - xmm3 (TrueBlue - Blue z tablicy)
	subsd xmm1, xmm4         ;xmm0 = xmm1 - xmm4 (TrueGreen - Green z tablicy)
	subsd xmm2, xmm5         ;xmm0 = xmm2 - xmm5 (TrueRed - Red z tablicy)

    ;Zapisywanie propagowanego b³êdu zgodnie z wagami w zale¿noœci od pozycji aktualnego pixela zdjêcia, uwzglêdnienie skrajnych pixeli 
	mov rbx, [errorBufferPtr]       ;rbx = wskaŸnik do errorTable

    ;if j > 0
    cmp [counterJ], 0
    ja ditherLeftUp
    jmp endDitherLeftUp    
    
ditherLeftUp:
    mov edi, [counterJ]
    dec edi
    imul rdi, rdi, 3
    imul rdi, rdi, 8

    ;Przeniesienie b³êdu do innych rejestrów
    movsd xmm3, xmm0    ;xmm3 = (TrueBlue - Blue), b³¹d absolutny miêdzy rzeczywist¹, a wybran¹ wartoœci¹ pixela
    movsd xmm4, xmm1    ;xmm4 = (TrueGreen - Green), b³¹d absolutny miêdzy rzeczywist¹, a wybran¹ wartoœci¹ pixela
    movsd xmm5, xmm2    ;xmm5 = (TrueRed - Red), b³¹d absolutny miêdzy rzeczywist¹, a wybran¹ wartoœci¹ pixela

    ;Zastosowanie wagi 3/16
    mov rax, 4008000000000000h ;3.0 wartoœæ
    movq xmm6, rax

    mulsd xmm3, xmm6
    mulsd xmm4, xmm6
    mulsd xmm5, xmm6

    mov rax, 4030000000000000h ;16.0 wartoœæ
    movq xmm6, rax

    divsd xmm3, xmm6
    divsd xmm4, xmm6
    divsd xmm5, xmm6

    ;Propagowanie b³êdu Blue
    movsd xmm6, real8 ptr[rbx + rdi]     ;Za³adowanie b³êdu z pamiêci
    addsd xmm3, xmm6            ;Dodanie do nowego b³êdu
    movsd real8 ptr[rbx + rdi], xmm3     ;Zapisanie nowego b³êdu

    ;Propagowanie b³êdu Green
    movsd xmm6, real8 ptr[rbx + rdi + 8]
    addsd xmm4, xmm6
    movsd real8 ptr[rbx + rdi + 8], xmm4 

    ;Propagowanie b³êdu Red
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

    ;Przeniesienie b³êdu do innych rejestrów
    movsd xmm3, xmm0    ;xmm3 = (TrueBlue - Blue), b³¹d absolutny miêdzy rzeczywist¹, a wybran¹ wartoœci¹ pixela
    movsd xmm4, xmm1    ;xmm4 = (TrueGreen - Green), b³¹d absolutny miêdzy rzeczywist¹, a wybran¹ wartoœci¹ pixela
    movsd xmm5, xmm2    ;xmm5 = (TrueRed - Red), b³¹d absolutny miêdzy rzeczywist¹, a wybran¹ wartoœci¹ pixela

    ;Zastosowanie wagi 7/16
    mov rax, 401c000000000000h ;7.0 wartoœæ
    movq xmm6, rax

    mulsd xmm3, xmm6
    mulsd xmm4, xmm6
    mulsd xmm5, xmm6

    mov rax, 3fb0000000000000h ;16.0 wartoœæ
    movq xmm6, rax

    mulsd xmm3, xmm6
    mulsd xmm4, xmm6
    mulsd xmm5, xmm6

    ;Propagowanie b³êdu Blue
    movsd xmm6, real8 ptr[rbx + rdi]     ;Za³adowanie b³êdu z pamiêci
    addsd xmm3, xmm6            ;Dodanie do nowego b³êdu
    movsd real8 ptr[rbx + rdi], xmm3     ;Zapisanie nowego b³êdu

    ;Propagowanie b³êdu Green
    movsd xmm6, real8 ptr[rbx + rdi + 8]
    addsd xmm4, xmm6
    movsd real8 ptr[rbx + rdi + 8], xmm4 

    ;Propagowanie b³êdu Red
    movsd xmm6, real8 ptr[rbx + rdi + 16]
    addsd xmm5, xmm6
    movsd real8 ptr[rbx + rdi + 16], xmm5 
     
endDitherRight:

ditherUp:
	mov edi, [counterJ]
	imul rdi, rdi, 3
	imul rdi, rdi, 8

	;Przeniesienie b³êdu do innych rejestrów
	movsd xmm3, xmm0    ;xmm3 = (TrueBlue - Blue), b³¹d absolutny miêdzy rzeczywist¹, a wybran¹ wartoœci¹ pixela
	movsd xmm4, xmm1    ;xmm4 = (TrueGreen - Green), b³¹d absolutny miêdzy rzeczywist¹, a wybran¹ wartoœci¹ pixela
	movsd xmm5, xmm2    ;xmm5 = (TrueRed - Red), b³¹d absolutny miêdzy rzeczywist¹, a wybran¹ wartoœci¹ pixela

	;Zastosowanie wagi 5/16, oraz zaporzyczenie z diagErrorBuffer
	mov rax, 4014000000000000h   ;5.0 wartoœæ
	movq xmm6, rax

	mulsd xmm3, xmm6
	mulsd xmm4, xmm6
	mulsd xmm5, xmm6

	mov rax, 3fb0000000000000h ;16.0 wartoœæ
	movq xmm6, rax

	mulsd xmm3, xmm6
	mulsd xmm4, xmm6
	mulsd xmm5, xmm6

	;Propagowanie b³êdu Blue
	movsd xmm6, [errorBufferDiag]     ;Za³adowanie b³êdu z pamiêci
	addsd xmm3, xmm6                           ;Dodanie do nowego b³êdu
	movsd real8 ptr[rbx + rdi], xmm3           ;Zapisanie nowego b³êdu

	;Propagowanie b³êdu Green
	movsd xmm6, real8 ptr[errorBufferDiag + 8]
	addsd xmm4, xmm6
	movsd real8 ptr[rbx + rdi + 8], xmm4 

	;Propagowanie b³êdu Red
	movsd xmm6, real8 ptr[errorBufferDiag + 16]
	addsd xmm5, xmm6
	movsd real8 ptr[rbx + rdi + 16], xmm5 

   
    ;Zbuforowanie b³edu propagowanego po przek¹tnej
    mov rax, 3fb0000000000000h ;1/16.0 wartoœæ
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
; Pobranie koñcowej wartoœci licznika cykli zegara
;---------------------------------------------------
rdtscp
shl rdx, 32       ; Przesuñ górne 32 bity
or rax, rdx       ; Po³¹cz w jeden 64-bitowy wynik
sub rax, [startTick]
ret							;Zakoñcz procedurê
JohnSteinberg endp
END 			;no entry point
;-------------------------------------------------------------------------
