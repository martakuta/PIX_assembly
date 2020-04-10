SYS_WRITE equ 1
STDOUT    equ 1
SYS_READ equ 0
STDIN    equ 0
SYS_EXIT  equ 60
MAX equ 8

global _start

section .bss
        ppi resb MAX*8
        pidx resb 8
        znak resb 1
        spin_lock resb 1 ; Blokada otwarta ma wartość 0. Blokada zamknięta ma wartość 1.

section .rodata
        new_line db `\n`

;-------------------------------------------------------------------------------;

section .text

zmniejsz_iterator:
        sub     r9, 1
        ret

aktualizuj_iterator:
        cmp     r9, 0
        jne     zmniejsz_iterator
        ret

aktualizuj_licznik_petla:
        mov     rax, 16                 ; mnożę licznik *16
        mul     r10                     ; wynik jest w rax

        div     r11                     ; licznik (aktualnie w rax) modulo mianownik
        mov     r10, rdx

        sub     r8, 1
        cmp     r8, r9
        jne     aktualizuj_licznik_petla
        ret


aktualizuj_licznik:
        mov     r8, rsi
        mov     r10, 1

        cmp     r8, r9
        jne     aktualizuj_licznik_petla
        ret

licz_male_S_petla:
        xor     rdx, rdx
        mov     rax, r10                ; licznik modulo mianownik
        div     r11
        mov     r10, rdx


        xor     rax, rax                ; dzielę rdx:rax (128 bitów) przez r11 (64bity)
        div     r11                     ; w rdx mam licznik, w r11 dół, rax = 0
        add     rcx, rax                ; wynik z div otrzymuję w rax

        call    aktualizuj_iterator     ; aktualizuję iterator (ale jeśli jest już 0 to go nie zmieniejszam, bo by się przekręcił)            
        sub     r11, 8                  ; aktualizuję mianownik
        call    aktualizuj_licznik      ; aktualizuję licznik

        cmp     r9, 0
        jne     licz_male_S_petla

        mov     rdx, r10
        xor     rax, rax                ; dzielę rdx:rax (128 bitów) przez r11 (64bity)
        div     r11                     ; w rdx mam licznik, w r11 dół, rax = 0
        add     rcx, rax                ; wynik z div otrzymuję w rax

        ret
        
licz_male_S:
        push    r8
        xor     rax, rax
        xor     rcx, rcx

        mov     r9, rsi                 ; ustawiam w r9 mój iterator k = n

        mov     rax, r9                 ; ustawiam w r11 dół ułamka, tj. 8k + j
        mov     r11, 8
        mul     r11
        mov     r11, rax
        add     r11, rdi  

        mov     r10, 1                  ; ustawiam w r10 górę ułamka, tj. aktualnie 16^0

        call    licz_male_S_petla

        mov     rax, rcx
        pop     r8
        ret

licz_duze_S_petla:
        xor     rdx, rdx                ; dzielę r10 przez r11, na 128 bitach (ale poniewaz r10 jest < 1 to znajduje sie ono na mniejszej polowce rax)
        mov     rax, r10
        div     r11
        add     rcx, rax                ; wynik otrzymany w rax dodaję do ogólnego

        mov     r9, rax

        shr     r10, 4                  ; aktualizuję licznik

        add     r11, 8                  ; aktualizuję mianownik

        cmp     rax, 0
        ja      licz_duze_S_petla
        ret
        

licz_duze_S:
        call    licz_male_S
        mov     rcx, rax

        mov     r9, rsi                 ; ustawiam w r9 mój iterator k = n + 1
        add     r9, 1

        mov     rdx, 1                  ; ustawiam w r10 górę ułamka, tj. 16^(-1)
        xor     rax, rax
        mov     r10, 16
        div     r10
        mov     r10, rax


        mov     rax, r9                 ; ustawiam w r11 dół ułamka, tj. 8k + j
        mov     r11, 8
        mul     r11
        mov     r11, rax
        add     r11, rdi

        call    licz_duze_S_petla

        mov     rax, rcx
        ret

licz_cala_sume:
        mov     rdi, 1
        call    licz_duze_S
        mov     r9, 4
        mul     r9
        mov     r8, rax
        
        mov     rdi, 4
        call    licz_duze_S
        mov     r9, 2
        mul     r9
        sub     r8, rax

        mov     rdi, 5
        call    licz_duze_S
        sub     r8, rax

        mov     rdi, 6
        call    licz_duze_S
        sub     r8, rax

        mov     rax, r8
        ret


wypisz_bit_petla:
        mov     r9d, 0x80000000
        and     r9d, r8d
        shr     r9d, 31
        add     r9d, 48
        mov     [znak], r9

        mov     rsi, znak
        mov     rdx, 1
        mov     rax, SYS_WRITE
        mov     rdi, STDOUT
        syscall

        shl     r8d, 1
        add     r10, 1
        cmp     r10, 32
        jb      wypisz_bit_petla
        ret

wypisz_rejestr_ppi:
        mov     r8d, [ppi + rsi]
        mov     r10, 0
        
        call    wypisz_bit_petla

        mov     rsi, new_line
        mov     rdx, 1
        mov     rax, SYS_WRITE
        mov     rdi, STDOUT
        ;syscall

        ret   

przepisz_32_bity:
        shr     rax, 32
        mov     [ppi + rsi], eax 
        ret

licz_swoje_pix:
        push    rsi 
        push    rdx
        push    rax
        push    rdi

        mov     rax, 8                  
        mul     rsi                     ; w jednej komorce tablicy jest 8 znaków systemu 16-kowego, więc w komórce 'm' będą znaki od m*8+1 do m*8+8
        mov     rsi, rax                ; dlatego liczę formułę dla 8*m

        call    licz_cala_sume          ; licz wartość tablicy pod swoim indeksem
        call    przepisz_32_bity        ; przepisz policzoną wartość do tablicy

        call    wypisz_rejestr_ppi

        pop     rdi
        pop     rax
        pop     rdx
        pop     rsi
        ret

pix_loop:
        mov     r8, spin_lock           ; w rdx jest adres blokady
        mov     r9b, 1                  ; w edi jest wartość zamknietej blokady
        xor     al, al                  ; w eax jest wartość otwartej blokady
        lock \
        cmpxchg [r8], r9b               ; jeśli blokada otwarta (czyli [r8]==al), zamknij ją ([r8]=r9b)
        jne     pix_loop                     ; skocz, gdy blokada była zamknięta, aby czekać dalej na wolną
        
        mov     rsi, [pidx]             ; przepisz sobie który indeks liczysz
        inc     dword [pidx]            ; zwiększ numer indeksu do policzenia
        mov     [r8], al                ; otwórz blokadę

        cmp     rsi, rdx
        jge     pix_koniec
        call    licz_swoje_pix
        jmp     pix_loop
        ret

pix:
        push    rdi
        push    rdx
        rdtsc                           ; pobierz czas procesora - zapisany jako 64 bity, pierwsze 32 w edx, drugie w eax
        mov     edi, edx
        shr     edi, 32
        mov     edi, eax
        call    pixtime
        pop     rdx
        pop     rdi

        call    pix_loop

        rdtsc                           ; pobierz czas procesora - zapisany jako 64 bity, pierwsze 32 w edx, drugie w eax
        mov     edi, edx
        shr     edi, 32
        mov     edi, eax
        call    pixtime
        ret

pix_koniec:
        rdtsc                           ; pobierz czas procesora - zapisany jako 64 bity, pierwsze 32 w edx, drugie w eax
        mov     edi, edx
        shr     edi, 32
        mov     edi, eax
        call    pixtime
        jmp     exit

pixtime:
        mov     rsi, new_line
        mov     rdx, 1
        mov     rax, SYS_WRITE
        mov     rdi, STDOUT
        syscall
        mov     r8b, 50
        mov     [znak], r8b

        mov     rsi, znak
        mov     rdx, 1
        syscall

        mov     rsi, new_line
        mov     rdx, 1
        syscall
        ret

_start:
        mov     rdi, ppi                ; wywołaj funkcję pix z parametrem, aby liczyła od pierwszego miejsca po przecinku
        mov     rsi, 0
        mov     [pidx], rsi
        mov     rdx, MAX
        call    pix

        mov     rsi, new_line
        mov     rdx, 1
        mov     rax, SYS_WRITE
        mov     rdi, STDOUT
        syscall

exit:
        mov     rax, SYS_EXIT
        xor     rdi, rdi                ; kod powrotu 0
        syscall

