%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int yylex();
void yyerror(const char *s);
int parsed_ok = 0;

// Nueva variable de estado para el modo encriptador
// Se inicializa a 0: desencriptador, 1: encriptador
int bison_encrypt_mode = 0;

char parsed_path[256];
unsigned int parsed_offset = 0, parsed_max_attempts = 0, parsed_n_lines = 0;
%}

%union {
    char *str;
    unsigned int num;
}

%token <str> FILENAME
%token <num> NUMBER

%%

instruction:
    FILENAME ',' NUMBER ',' NUMBER {
        // Esta es la nueva regla para el modo encriptador.
        // Aquí no necesitamos verificar 'encrypt_mode' porque esta regla solo se
        // puede alcanzar si el lexer ya envió ENCRYPT_KEYWORD, lo que implica
        // que 'encrypt_mode' ya fue establecido a 1 en Flex.
        strncpy(parsed_path, $1, sizeof(parsed_path));
        parsed_offset = $3;
        parsed_max_attempts = $5;
        parsed_ok = 1;
    }
    |
    FILENAME ',' NUMBER ',' NUMBER ',' NUMBER {
        // Esta es la regla original de desencriptación.
        // Si estamos en modo encriptador, esta gramática es inválida.
        if (bison_encrypt_mode == 1) {
            yyerror("Gramática de desencriptación no permitida en modo encriptación.");
            YYABORT; // Aborta el parseo
        }
        strncpy(parsed_path, $1, sizeof(parsed_path));
        parsed_offset = $3;
        parsed_max_attempts = $5;
        parsed_n_lines = $7;
        parsed_ok = 1;
    }
;

%%

void yyerror(const char *s) {
    fprintf(stderr, "Error de sintaxis (bison): %s\n", s);
}
