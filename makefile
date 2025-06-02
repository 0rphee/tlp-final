BISON = bison
FLEX = flex
CXX = c++

# Files
BISON_SRC = validacion.y
BISON_OUT = validacion_instrucciones.cpp

FLEX_SRC = encriptador_desencriptador.l
FLEX_OUT = lex.yy.c

CXX_SRC = encriptador_desencriptador.cpp
CXX_OUT = encriptador_desencriptador

# Targets
all: $(CXX_SRC)

	$(BISON) -ldt -o $(BISON_OUT) $(BISON_SRC)
	$(FLEX) -L $(FLEX_SRC)
	$(CXX) validacion_instrucciones.cpp $(CXX_SRC) -o $(CXX_OUT)

decrypt: all
	cd odata/
	./$(CXX_OUT) Instruction_to_decode.txt Original_document.cod
	cd ..

encrypt: all
	cd odata/
	./$(CXX_OUT) Original_document.txt
	cd ..

clean:
	rm -f $(BISON_OUT) $(FLEX_OUT) a.out *.o
