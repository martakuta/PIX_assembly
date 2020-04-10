nasm -f elf64 -w+all -w+error -o pix.o pix.asm
ld --fatal-warnings -o pix pix.o
./pix
cat odpowiedz