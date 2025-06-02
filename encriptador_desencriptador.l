%{
#include <stdio.h>
#include <stdlib.h> 
#include <string.h> 

#include "validacion_instrucciones.hpp" 
extern int yyparse(void);
extern int parsed_ok;
extern void yy_switch_to_buffer(YY_BUFFER_STATE);
extern YY_BUFFER_STATE yy_scan_string(const char *str);
extern void yy_delete_buffer(YY_BUFFER_STATE buffer);

#define MAX_INSTR 100
#define ALPHA_SIZE 26
#define MAX_STACK_SIZE 64

typedef struct {
    char key_path[256];
    unsigned int first_offset;
    unsigned int max_attempts;
    unsigned int n_lines;
} InstructionData;

typedef struct {
    YY_BUFFER_STATE buffer;
    long position;  
} FileState;

InstructionData instrucciones[MAX_INSTR];
InstructionData *current_instr = NULL;
int instr_count = 0;

unsigned int first_offset = 0;
unsigned int second_offset = 0;
unsigned int curr_second_offset = 0;
unsigned int next_index = 0;
int offset_encontrado = 0;
unsigned int lines_decrypted = 0;

const unsigned char DEFAULT_ALPHA_ARR[ALPHA_SIZE] = {
    0, 'Z', 0, 0, 0, 0, 0, 0, 0, 'X', 0, 0, 0, 0, 'U', 0, 0, 0, 0, 0, 'O', 0, 0, 'J', 0, 'B'
};
unsigned char alpha_arr[ALPHA_SIZE] = {0};
unsigned char reverse_alpha_arr[ALPHA_SIZE] = {0};

FileState file_stack[MAX_STACK_SIZE];
int stack_ptr = 0;
FILE *cifrado = NULL;
FILE *salida_desencriptado = NULL;
char instruccion_path[512];
char base_path[512] = {0};

void add_instruction(const char *line);
int fill_alpha_arr(const char *fasta_path, unsigned int first_offset_param, unsigned int max_attempts);
int letra_en_arreglo(unsigned char letra, const unsigned char arr[ALPHA_SIZE]);
void agregar_si_no_existe(unsigned char letra, unsigned char *arr, unsigned int *count, int offset);
void build_reverse_dict(const unsigned char alpha_arr[ALPHA_SIZE], unsigned char reverse_alpha_arr[ALPHA_SIZE]);

void set_base_path_from(const char *full_path);
void modo_encriptador(const char *path);
void modo_desencriptador(const char *instrucciones_path, const char *cifrado_path);

%}

%option noyywrap
%option outfile="encriptador_desencriptador.cpp"
%s ENCRIPTADOR
%s DESENCRIPTADOR 
%x FASTA
%x ENCABEZADO
%x INSTRUCCION

%%

#[^\n]* {
    // instrucciones para encriptar
}

<INSTRUCCION>#[^\n]* {
    char clean_line[512];
        strncpy(clean_line, yytext + 1, sizeof(clean_line));
        clean_line[sizeof(clean_line) - 1] = '\0';
    
        char *p = clean_line;
        while (*p) {
            if (*p == '\n' || *p == '\r' || *p == '%') *p = '\0';
            ++p;
        }
    
        // Ejecuta el parser con Bison
        YY_BUFFER_STATE old_buf = YY_CURRENT_BUFFER;
        YY_BUFFER_STATE new_buf = yy_scan_string(clean_line);
        parsed_ok = 0;
        yyparse();
        yy_delete_buffer(new_buf);
        yy_switch_to_buffer(old_buf);
    
        if (parsed_ok) {
            add_instruction(clean_line);
            printf("Instruccion valida: %s\n", clean_line);
        } else {
            fprintf(stderr, "Error, instruccion invalida: %s\n", clean_line);
            exit(1);
    }
}

<INSTRUCCION>, {
    return ',';
}

<INSTRUCCION>[0-9]+ {
    yylval.num = atoi(yytext);
    return NUMBER;
}

<INSTRUCCION>[^,\n]+\.fasta {
    yylval.str = strdup(yytext);
    return FILENAME;
}

> {
	memcpy(alpha_arr, DEFAULT_ALPHA_ARR, ALPHA_SIZE);
	BEGIN(ENCABEZADO);
}

<ENCABEZADO>\n {
	BEGIN(FASTA);
}

<ENCABEZADO>[^\n] {
	unsigned char c = yytext[0];
	if (++first_offset == current_instr->first_offset) {
	        offset_encontrado = 1; 
	        second_offset = c;  
    	}
}


<FASTA>[^>\n ] {
	if (++curr_second_offset == second_offset) {
	        if (!letra_en_arreglo(yytext[0], alpha_arr)) {
	            agregar_si_no_existe(yytext[0], alpha_arr, &next_index, ALPHA_SIZE);
	        }
	        curr_second_offset = 0;  
    	}
    	if(next_index == ALPHA_SIZE - 1) {
        	return 0; 
    	}

}

<FASTA>>.+\n {     }

<FASTA>[ \t\r] 

<FASTA>.|\n 

<ENCRIPTADOR>[A-Za-z] {
    unsigned char c = yytext[0];
    int idx = letra_en_arreglo(c, alpha_arr);
    if (idx >= 0) {
        fputc('A' + idx, stdout); 
    } else {
        fputc(c, stdout); 
    }
}

<ENCRIPTADOR>[ \t\r] { fputc(yytext[0], stdout); }

<ENCRIPTADOR>\n {
    fputc('\n', stdout);
    lines_decrypted++; 
}

<DESENCRIPTADOR>[A-Z]   {
    int index = yytext[0] - 'A';
    if(index >= 0 && index < ALPHA_SIZE && reverse_alpha_arr[index] != 0) {
        fputc(reverse_alpha_arr[index], yyout);
    } else {
        fputc(yytext[0], yyout);
    }
}

<DESENCRIPTADOR>[ ]   {fputs(yytext, yyout);}
<DESENCRIPTADOR>\n   {
	fputs(yytext, yyout);
	if(++lines_decrypted == current_instr->n_lines){
		return 1;
	}
}

%%

int letra_en_arreglo(unsigned char letra, const unsigned char arr[ALPHA_SIZE]) {
    for (int i = 0; i < ALPHA_SIZE; i++) {
        if (arr[i] == letra) return 1; 
    }
    return 0;
}

void agregar_si_no_existe(unsigned char letra, unsigned char *arr, unsigned int *count, int offset) {
    if (!letra_en_arreglo(letra, arr)) {
        while (*count < ALPHA_SIZE &&
	               (arr[*count] != 0 || *count == 1 || *count == 9 || *count == 14 || *count == 20 || *count == 23)) {
	            (*count)++;
        }
        if (*count >= ALPHA_SIZE) {
	            fprintf(stderr, "Error: Arreglo de sustitución lleno o sin posiciones válidas.\n");
	            exit(1);
        }
        arr[*count] = letra;
	(*count)++;
        first_offset = 1;
    }
}



void add_instruction(const char *line) {
    if (instr_count >= MAX_INSTR) {
        fprintf(stderr, "Maximo de instrucciones alcanzado\n");
        exit(1);
    }

    char buffer[512];
    strncpy(buffer, line, sizeof(buffer));
    buffer[sizeof(buffer)-1] = '\0';

    char *p = buffer;

    char filename[256];
    unsigned first_offset = 0, max_attempts = 0, n_lines = 0;

    if (sscanf(p, "%255[^,],%u,%u,%u", filename, &first_offset, &max_attempts, &n_lines) != 4) {
        fprintf(stderr, "Error al analizar la lÌnea: %s\n", line);
        return;
    }

    char abs_path[512];
    snprintf(abs_path, sizeof(abs_path), "%s%s", base_path, filename);

    InstructionData *instr = &instrucciones[instr_count];
    strncpy(instr->key_path, abs_path, sizeof(instr->key_path));
    instr->key_path[sizeof(instr->key_path) - 1] = '\0';
    instr->first_offset = first_offset;
    instr->max_attempts = max_attempts;
    instr->n_lines = n_lines;
    
    instr_count++;
}

int fill_alpha_arr(const char *fasta_path, unsigned int first_offset_param, unsigned int max_attempts) {
    memcpy(alpha_arr, DEFAULT_ALPHA_ARR, ALPHA_SIZE);
    FILE *fasta = fopen(fasta_path, "r");
    if (!fasta) {
        perror("No se pudo abrir archivo FASTA");
        return 0;
    }
    
    first_offset = 0;
    second_offset = 0;
    curr_second_offset = 0;
    next_index = 0;
    offset_encontrado = 0;

    if (stack_ptr >= MAX_STACK_SIZE) {
        fprintf(stderr, "Error: Stack de buffers lleno.\n");
        fclose(fasta);
        return 0;
    }

    file_stack[stack_ptr].buffer = YY_CURRENT_BUFFER;
    file_stack[stack_ptr].position = ftell(yyin);  
    stack_ptr++;

    yyin = fasta;
    YY_BUFFER_STATE fasta_buf = yy_create_buffer(yyin, YY_BUF_SIZE);
    yy_switch_to_buffer(fasta_buf);
    BEGIN(INITIAL);

    yylex();

    fclose(fasta);

    if (--stack_ptr < 0) {
        fprintf(stderr, "Error: stack vacío al volver del archivo FASTA\n");
        yyterminate();
    } else {
        yy_delete_buffer(YY_CURRENT_BUFFER);
        yy_switch_to_buffer(file_stack[stack_ptr].buffer);
        fseek(yyin, file_stack[stack_ptr].position, SEEK_SET);
    }
    return 1;
}

void build_reverse_dict(const unsigned char alpha_arr[ALPHA_SIZE], unsigned char reverse_alpha_arr[ALPHA_SIZE]) {
    memset(reverse_alpha_arr, 0, ALPHA_SIZE);

    for (int i = 0; i < ALPHA_SIZE; i++) {
        unsigned char letter = alpha_arr[i];
        if (letter != 0) {
            int original_index = letter - 'A';
            if (original_index >= 0 && original_index < ALPHA_SIZE) {
                reverse_alpha_arr[original_index] = i + 'A';
            }
        }
    }
}

void set_base_path_from(const char *full_path) {
    strncpy(base_path, full_path, sizeof(base_path));
    base_path[sizeof(base_path) - 1] = '\0';

    char *last_slash = strrchr(base_path, '\\');

    if (last_slash) *(last_slash + 1) = '\0';  
    else base_path[0] = '\0';  
}

void modo_encriptador(const char *path) {
    yyin = fopen(path, "r");
    if (!yyin) {
        perror("No se pudo abrir el archivo");
        exit(1);
    }
    strncpy(instruccion_path, path, sizeof(instruccion_path));
    instruccion_path[sizeof(instruccion_path) - 1] = '\0';
    set_base_path_from(instruccion_path);

    printf("Modo ENCRIPTADOR:\n");
    BEGIN(ENCRIPTADOR);
    yylex();
    fclose(yyin);
}

void modo_desencriptador(const char *instrucciones_path, const char *cifrado_path) {
    // Leer instrucciones
    yyin = fopen(instrucciones_path, "r");
    if (!yyin) {
        perror("No se pudo abrir el archivo de instrucciones");
        exit(1);
    }

    strncpy(instruccion_path, instrucciones_path, sizeof(instruccion_path));
    instruccion_path[sizeof(instruccion_path) - 1] = '\0';
    set_base_path_from(instruccion_path);

    printf("Modo DESENCRIPTADOR:\n");
    BEGIN(INSTRUCCION);
    yylex();
    fclose(yyin);

    // Abrir archivo cifrado y salida
    cifrado = fopen(cifrado_path, "r");
    if (!cifrado) {
        perror("No se pudo abrir el archivo cifrado");
        exit(1);
    }

    char salida_path[512];
    snprintf(salida_path, sizeof(salida_path), "%ssalida_desencriptado.txt", base_path);
    salida_desencriptado = fopen(salida_path, "w");
    if (!salida_desencriptado) {
        perror("No se pudo crear archivo de salida");
        fclose(cifrado);
        exit(1);
    }

    yyout = salida_desencriptado;
    yyin = cifrado;

    // Procesar instrucciones
    for (int i = 0; i < instr_count; i++) {
        current_instr = &instrucciones[i];
        printf("\n>> Procesando instruccion %d/%d\n", i + 1, instr_count);

        if (!fill_alpha_arr(current_instr->key_path, current_instr->first_offset, current_instr->max_attempts)) {
            fprintf(stderr, "Error creando diccionario para %s\n", current_instr->key_path);
            fclose(cifrado);
            fclose(salida_desencriptado);
            exit(1);
        }
        build_reverse_dict(alpha_arr, reverse_alpha_arr);

        BEGIN(DESENCRIPTADOR);
        yylex();
    }

    fclose(cifrado);
    fclose(salida_desencriptado);
    printf("\nArchivo desencriptado: %s\n", salida_path);
}

int main(int argc, char *argv[]) {
    if (argc == 2) {
        modo_encriptador(argv[1]);
    } else if (argc == 3) {
        modo_desencriptador(argv[1], argv[2]);
    } else {
        printf("Uso:\n");
        printf("  %s archivo1           -> Encriptar\n", argv[0]);
        printf("  %s instrucciones.txt cifrado.txt  -> Desencriptar\n", argv[0]);
        return 1;
    }
    return 0;
}