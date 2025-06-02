%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int yylex();
void yyerror(const char *s);
int parsed_ok = 0;

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
    FILENAME ',' NUMBER ',' NUMBER ',' NUMBER {
        strncpy(parsed_path, $1, sizeof(parsed_path));
        parsed_offset = $3;
        parsed_max_attempts = $5;
        parsed_n_lines = $7;
        parsed_ok = 1;
    }
;

%%

void yyerror(const char *s) {
    fprintf(stderr, "Error de sintaxis: %s\n", s);
}
