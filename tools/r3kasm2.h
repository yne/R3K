/* =============================================================================
	Fichier de definition de l'assembleur R3000
	============================================================================= */
#ifndef _R3KASM2_H
#define _R3KASM2_H

// Definitions generales
#define MAX_LABELS	50
#define SIZE_LABELS	100
#define MAX_MACRO		50
#define SIZE_MACRO	100

#define OPCODE			32		// taille en bit d'une instruction
#define MAX_REGS		32
#define MAX_VALDEC	32
#define TYPE_R			0
#define TYPE_I			1
#define TYPE_J			2

//Structures des labels
typedef struct {
	char name[MAX_LABELS] [SIZE_LABELS];
	int cp[MAX_LABELS];
	int nb;
} TLabels;

//Strutures des macros
typedef struct {
	char name[SIZE_MACRO] [MAX_MACRO];
	char replace[SIZE_MACRO] [MAX_MACRO];
	int nb;
} TMacros;

// Declaration des fonctions
void Lread(FILE *s, char *dest);

void Nettoyage(char *dest);

void intTOsbin(int n, char *result, int length);

void strUP(char *s);

void addLabel(const char *name, int CP, TLabels *l);

int cpLabel(const char *name, TLabels *l);

void opMake(FILE *f, int type, const char *op, int rs, int rt, int rd, int valdec, const char *fct, int imm, int adr);

void replaceMacro(char *s,TMacros *m);

void prePARSE(FILE *source, FILE *dest, TLabels *l, TMacros *m);

void addMacro(TMacros *m, char *name, char *replace);

char *searchMacro(TMacros *m, const char *name);

// Definition OPCODES
#define OP_LSL		"000000"
#define OP_LSR		"000000"
#define OP_JR		"000000"
#define OP_ADD		"000000"
#define OP_ADDU	"000000"
#define OP_SUB		"000000"
#define OP_SUBU	"000000"
#define OP_AND		"000000"
#define OP_OR		"000000"
#define OP_XOR		"000000"
#define OP_NOR		"000000"
#define OP_SLT		"000000"
#define OP_SLTU	"000000"
#define OP_JALR	"000000"
#define OP_BLTZ	"000001"
#define OP_BGEZ	"000001"
#define OP_BLTZAL	"000001"
#define OP_BGEZAL	"000001"
#define OP_J		"000010"
#define OP_JAL		"000011"
#define OP_BEQ		"000100"
#define OP_BNE		"000101"
#define OP_BLEZ	"000110"
#define OP_BGTZ	"000111" 
#define OP_ADDI	"001000" 
#define OP_ADDIU	"001001" 
#define OP_SLTI	"001010" 
#define OP_SLTIU	"001011" 
#define OP_ANDI	"001100" 
#define OP_ORI		"001101" 
#define OP_XORI	"001110" 
#define OP_LUI		"001111" 
#define OP_LB		"100000" 
#define OP_LH		"100001" 
#define OP_LW		"100011" 
#define OP_LBU		"100100" 
#define OP_LHU		"100101" 
#define OP_SB		"101000" 
#define OP_SH		"101001" 
#define OP_SW		"101011"

// Definition FONCTIONS 
#define F_LSL		"000000" 
#define F_LSR		"000010" 
#define F_JR		"001000" 
#define F_ADD		"100000" 
#define F_ADDU		"100001" 
#define F_SUB		"100010" 
#define F_SUBU		"100011" 
#define F_AND		"100100" 
#define F_OR		"100101" 
#define F_XOR		"100110" 
#define F_NOR		"100111" 
#define F_SLT		"101010" 
#define F_SLTU		"101011" 
#define F_JALR		"001001"

// definition des BCOND 
#define B_BLTZ		"00000" 
#define B_BGEZ		"00001" 
#define B_BLTZAL	"10000" 
#define B_BGEZAL	"10001"

#endif
