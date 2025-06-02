BISON = bison
FLEX = flex
CXX = c++
CXX_FLAGS = -Wall -Wextra

# Files
BISON_SRC = validacion.y
BISON_OUT = validacion_instrucciones.cpp

FLEX_SRC = encriptador_desencriptador.l
CXX_SRC = encriptador_desencriptador.cpp
CXX_OUT = encriptador_desencriptador

# Targets
all:
	$(BISON) -ldt -o $(BISON_OUT) $(BISON_SRC)
	$(FLEX) -L $(FLEX_SRC)
	$(CXX) validacion_instrucciones.cpp $(CXX_SRC) -o $(CXX_OUT) $(CXX_FLAGS)

decrypt: all
	./$(CXX_OUT) Instruction_to_decode.txt salida_encriptado.txt

encrypt: all
	./$(CXX_OUT) Original_document.txt

clean:
	rm -f $(BISON_OUT) a.out *.o
