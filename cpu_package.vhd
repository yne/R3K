--------------------------------------------------------------------------------
-- RISC processor general definitions
-- THIEBOLT Francois le 08/03/14
--------------------------------------------------------------------------------

library IEEE;

use IEEE.math_real.log2;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;
use work.func_package.all;

package cpu_package is

-- ===============================================================
-- TYPES/CONSTANT DEFINITIONS
-- ===============================================================

------------------------------------------------------------------
-- HARDWARE definitions
------------------------------------------------------------------
-- define CPU core physical sizes
	constant CPU_DATA_WIDTH : positive := 32; -- data bus width
	constant CPU_INST_WIDTH : positive := CPU_DATA_WIDTH; -- instruction bus width
	constant CPU_ADR_WIDTH  : positive := 32; -- address bus width, byte format

-- define MISC CPU CORE specs
	constant CPU_WR_FRONT   : std_logic:= '1';-- pipes write active front
	constant PC_WIDTH       : positive := 26;-- bits pour le PC format mot memoire
	constant PCLOW          : positive := natural(log2(real(CPU_INST_WIDTH/8)));

-- define REGISTERS physical sizes
	constant REG_WIDTH      : positive := 5; -- registers address bus with
	constant REG_FRONT      : std_logic:= CPU_WR_FRONT;

-- define instruction & data CACHE physical sizes
	constant L1_SIZE        : positive := 32; -- taille des caches L1 en nombre de mots
	constant L1_ISIZE       : positive := L1_SIZE; -- taille du cache instruction L1 en nombre de mots
	constant L1_DSIZE       : positive := L1_SIZE; -- taille du cache donnees L1 en nombre de mots
	constant L1_FRONT       : std_logic:= CPU_WR_FRONT;

-- define types/subtypes according to hardware specs
	subtype PC          is std_logic_vector(PC_WIDTH-1+PCLOW downto PCLOW);
	subtype INST        is std_logic_vector(CPU_INST_WIDTH-1 downto 0);
	subtype ADDR        is std_logic_vector(CPU_ADR_WIDTH-1 downto 0);
	subtype DATA        is std_logic_vector(CPU_DATA_WIDTH-1 downto 0);
	subtype REGS        is std_logic_vector(REG_WIDTH-1 downto 0);

-- define default values
	constant PC_DEFL : ADDR := conv_std_logic_vector( 0,ADDR'length);
	constant ZERO    : DATA := conv_std_logic_vector( 0,DATA'length);
	constant VAL16   : DATA := conv_std_logic_vector(16,DATA'length);

------------------------------------------------------------------
-- SOFTWARE definitions
------------------------------------------------------------------
-- [_OP_][________________________]
-- 000000[RS_][RT_][RD_][VAL][FCOD] TYPE_R
-- 000001[RS_][BCO][_____IMM______] TYPE_B
-- 00001X[__________JADR__________] TYPE_J
-- 001XXX[RS_][RT_][_____IMM______] TYPE_I
-- 10WUSS[RS_][RT_][_____IMM______] TYPE_M Write/Unsigned/Size
-- definition des champs d'instructions
	subtype OPCODE    is std_logic_vector(31 downto 26);
	subtype RS        is std_logic_vector(25 downto 21);
	subtype RT        is std_logic_vector(20 downto 16);
	subtype RD        is std_logic_vector(15 downto 11);
	subtype VALDEC    is std_logic_vector(10 downto  6);
	subtype FCODE     is std_logic_vector( 5 downto  0);
	
	subtype BCODE     is std_logic_vector(20 downto 16);
	subtype IMM       is std_logic_vector(15 downto  0);
	subtype JADR      is std_logic_vector(25 downto  0);

-- ===== INSTRUCTIONS =====
	constant TYPE_R     : std_logic_vector := "000000" ;
	    constant LSL    : std_logic_vector := "000000" ;--r[rd]=  r[rt]<< re;
	    constant LSR    : std_logic_vector := "000010" ;--r[rd]=  u[rt]>> re;
	    constant JR     : std_logic_vector := "001000" ;--                  s->pc_next=r[rs];
	    constant JALR   : std_logic_vector := "001001" ;--r[rd]=s->pc_next; s->pc_next=r[rs];
	    constant ADD    : std_logic_vector := "100000" ;--r[rd]=  r[rs] + r[rt];
	    constant ADDU   : std_logic_vector := "100001" ;--r[rd]=  r[rs] + r[rt];
	    constant SUB    : std_logic_vector := "100010" ;--r[rd]=  r[rs] - r[rt];
	    constant SUBU   : std_logic_vector := "100011" ;--r[rd]=  r[rs] - r[rt];
	    constant iAND   : std_logic_vector := "100100" ;--r[rd]=  r[rs] & r[rt];
	    constant iOR    : std_logic_vector := "100101" ;--r[rd]=  r[rs] | r[rt];
	    constant iXOR   : std_logic_vector := "100110" ;--r[rd]=  r[rs] ^ r[rt];
	    constant iNOR   : std_logic_vector := "100111" ;--r[rd]=~(r[rs] | r[rt]);
	    constant SLT    : std_logic_vector := "101010" ;--r[rd]=  r[rs] < r[rt];
	    constant SLTU   : std_logic_vector := "101011" ;--r[rd]=  u[rs] < u[rt];
	    constant SYNC   : std_logic_vector := "001111" ;--ALLOW US TO BREAK
	
	constant TYPE_B     : std_logic_vector := "000001" ;
	    constant BLTZ   : std_logic_vector :=  "00000" ;--branch=r[rs]<0;
	    constant BGEZ   : std_logic_vector :=  "00001" ;--branch=r[rs]>=0;
	    constant BLTZAL : std_logic_vector :=  "10000" ;--r[31]=s->pc_next; branch=r[rs]<0;
	    constant BGEZAL : std_logic_vector :=  "10001" ;--r[31]=s->pc_next; branch=r[rs]>=0;
	
	constant J          : std_logic_vector := "000010" ;--                  s->pc_next=(s->pc&0xf0000000)|target;
	constant JAL        : std_logic_vector := "000011" ;--r[31]=s->pc_next; s->pc_next=(s->pc&0xf0000000)|target;
	
	constant BEQ        : std_logic_vector := "000100" ;--branch=r[rs]==r[rt];
	constant BNE        : std_logic_vector := "000101" ;--branch=r[rs]!=r[rt];
	constant BLEZ       : std_logic_vector := "000110" ;--branch=r[rs]<=0;
	constant BGTZ       : std_logic_vector := "000111" ;--branch=r[rs]>0;
	
	constant ADDI       : std_logic_vector := "001000" ;--r[rt]=r[rs]+(short)imm;
	constant ADDIU      : std_logic_vector := "001001" ;--u[rt]=u[rs]+(short)imm;
	constant SLTI       : std_logic_vector := "001010" ;--r[rt]=r[rs]<(short)imm;
	constant SLTIU      : std_logic_vector := "001011" ;--u[rt]=u[rs]<(unsigned long)(short)imm;
	constant ANDI       : std_logic_vector := "001100" ;--r[rt]=r[rs]&imm;
	constant ORI        : std_logic_vector := "001101" ;--r[rt]=r[rs]|imm;
	constant XORI       : std_logic_vector := "001110" ;--r[rt]=r[rs]^imm;
	constant LUI        : std_logic_vector := "001111" ;--r[rt]=(imm<<16);
	
	constant LB         : std_logic_vector := "100000" ;--r[rt]=*(signed char*)ptr;
	constant LH         : std_logic_vector := "100001" ;--r[rt]=*(signed short*)ptr;
	constant LW         : std_logic_vector := "100011" ;--r[rt]=*(long*)ptr;
	constant LBU        : std_logic_vector := "100100" ;--r[rt]=*(unsigned char*)ptr;
	constant LHU        : std_logic_vector := "100101" ;--r[rt]=*(unsigned short*)ptr;
	
	constant SB         : std_logic_vector := "101000" ;--*(char*)ptr=(char)r[rt];
	constant SH         : std_logic_vector := "101001" ;--*(short*)ptr=(short)r[rt];
	constant SW         : std_logic_vector := "101011" ;--*(long*)ptr=r[rt];
	
	type     B_OPS is (B_NULL  ,  B_EQ,B_NE,B_LE,B_GT  ,  B_LT,B_GE);
	--type     ALU_OPS is (ALU_UNK,ALU_ADD,ALU_SUB,ALU_AND,ALU_OR,ALU_NOR,ALU_XOR,ALU_SLT,ALU_LSL,ALU_LSR);
	constant ALU_SIGNED  : std_logic := '0';
	constant ALU_UNSIGNED: std_logic := '1';
	constant IMM_UNSIGNED: std_logic := '0';
	constant IMM_SIGNED  : std_logic := '1';

	constant MEM_8  : std_logic_vector := "00" ;
	constant MEM_16 : std_logic_vector := "01" ;
	constant MEM_32 : std_logic_vector := "11" ;
	constant MEM_READ      : std_logic := '0' ;
	constant MEM_WRITE     : std_logic := '1' ;
	constant MEM_SIGNED    : std_logic := '0' ;
	constant MEM_UNSIGNED  : std_logic := '1' ;
	
	constant REG_WRITE     : std_logic := '0' ;
	constant REG_RDONLY    : std_logic := '1' ;

------------------------------------------------------------------
-- HARDWARE Multiplexer and Pipelines registers definitions
------------------------------------------------------------------

---------------------------------------------------------------
-- Definition des multiplexeurs dans les etages
	type MUX_ALU_A   is (REGS_QA,IMMD,REGS_QB);
	type MUX_ALU_B   is (REGS_QB,IMMD,VAL_DEC,IMM_0,IMM_16);
	type MUX_REG_DST is (REG_RT,REG_RD,REG_31);
	type MUX_REGS_D  is (ALU_S,MEM_Q,NextPC);
	type MUX_PC_SRC  is (PC_NEXT,PC_BRANCH,PC_JUMP,PC_JUMP_R);

-- STRUCTURES DE CONTROLES DES ETAGES

	type ctrlDI is record
		SIGNED_EXT     : std_logic;-- extension signee ou non donnee immediate
		JUMP_IMM       : std_logic;
		JUMP_REG       : std_logic;
	end record;

	type ctrlEX is record
		ALU_OP      : FCODE;    -- ALU_ADD,ALU_SUB,ALU_AND,ALU_OR,ALU_NOR,ALU_XOR,ALU_SLT,ALU_LSL,ALU_LSR
		ALU_SIGNED  : std_logic;   -- operation ALU signee ou non
		ALU_SRCA    : MUX_ALU_A;  -- REGS_QA,REGS_QB,IMMD
		ALU_SRCB    : MUX_ALU_B;  -- REGS_QB,IMMD,VAL_DEC
		REG_DST     : MUX_REG_DST;-- REG_RD,REG_RT,REG_31
	end record;

	type ctrlME is record
		DC_DS       : std_logic_vector (1 downto 0);   -- DataCache taille d'acces 8/16/32/64/...
		BRANCH      : B_OPS ;     -- BRANCHE TYPE
		DC_RW       : std_logic;  -- DataCache signal R/W*
		DC_AS       : std_logic;  -- DataCache signal Address Strobe
		DC_SIGNED   : std_logic;  -- DataCache operation signee ou non (lecture)
	end record;
	
	type ctrlER is record
		REGS_WE     : std_logic; -- REG_RDONLY/ REG_WRITE
		REGS_SRCD   : MUX_REGS_D;-- ALU_S,MEM_Q,NextPC
	end record;
	
	constant DI_DEFL : ctrlDI := ( IMM_UNSIGNED,'0','0');
	constant EX_DEFL : ctrlEX := ( SUB,ALU_SIGNED,REGS_QA,REGS_QB,REG_RT);
	constant ME_DEFL : ctrlME := ( MEM_32,B_NULL,MEM_READ,MEM_UNSIGNED,'0');
	constant ER_DEFL : ctrlER := ( REG_WRITE,ALU_S);

-- STRUCURES DES REGISTRES PIPELINE
	type EI_DI is record
-- === Data ===
		pc_next     : std_logic_vector (PC  'range);-- cp incremente
		inst        : std_logic_vector (INST'range);-- instruction extraite
-- === Control ===
	end record;
	type DI_EX is record
-- === Data ===
		pc_next     : std_logic_vector (PC'range);-- cp incremente propage
		rs          : std_logic_vector (REGS'range);-- champ rs
		rt          : std_logic_vector (REGS'range);-- champ rt
		rd          : std_logic_vector (REGS'range);-- champ rd
		val_dec     : std_logic_vector (VALDEC'range);-- valeur de decalage
		imm_ext     : std_logic_vector (DATA'range);-- valeur immediate etendue
		jump_adr    : std_logic_vector (JADR'RANGE);-- champ adresse de JUMP_IMMs
		rs_read     : std_logic_vector (DATA'range);-- donnee du registre lu rs
		rt_read     : std_logic_vector (DATA'range);-- donnee du registre lu rt
		val_ext     : std_logic_vector (DATA'range);-- valdec etendu
-- === Control ===
		ex_ctrl     : ctrlEX;-- signaux de control de l'etage EX
		me_ctrl     : ctrlME;-- signaux de control de l'etage MEM
		er_ctrl     : ctrlER;-- signaux de control de l'etage ER
	end record;

-- Structure du registre EX/MEM
	type EX_ME is record
-- === Data ===
		pc_next     : std_logic_vector (PC'range);-- cp incremente propage
		ual_S       : std_logic_vector (DATA'range);-- resultat ual
		ual_N       : std_logic;-- resultat ual
		ual_V       : std_logic;-- resultat ual
		ual_Z       : std_logic;-- resultat ual
		ual_C       : std_logic;-- resultat ual
		rt_read     : std_logic_vector (DATA'range);-- registre rt propage
		reg_dst     : std_logic_vector (REGS'range);-- registre destination (MUX_REG_DST)
-- === Control ===
		me_ctrl     : ctrlME;-- signaux de control de l'etage MEM
		er_ctrl     : ctrlER;-- signaux de control de l'etage ER
	end record;

-- Structure du registre MEM/ER
	type ME_ER is record
-- Signaux
		pc_next     : std_logic_vector (PC'range);-- cp incremente propage
		mem_Q       : std_logic_vector (DATA'range);-- sortie memoire
		ual_S       : std_logic_vector (DATA'range);-- resultat ual propage
		reg_dst     : std_logic_vector (REGS'range);-- registre destination propage
-- === Control ===
		er_ctrl			: ctrlER;-- signaux de control de l'etage ER propage
	end record;

-- ===============================================================
-- DEFINITION DE FONCTIONS/PROCEDURES
-- ===============================================================

-- Si on ne specifie rien devant les parametres...il considere que c'est une variable
-- exemple : procedure adder_cla (A,B: in std_logic_vector;...)
-- ici A et B sont consideres comme etant des variables...
-- Sinon il faut : procedure adder_cla (signal A,B: in std_logic_vector;...)

-- Fonction "+" --> procedure adder_cla
	function "+" (A,B: in std_logic_vector) return std_logic_vector;

-- Procedure adder_cla
	procedure adder_cla (A,B: in std_logic_vector; C_IN : in std_logic;
								S : out std_logic_vector; C_OUT : out std_logic;
								V : out std_logic);

-- Procedure alu
-- 	on notera l'utilisation d'un signal comme parametres formels de type OUT
	procedure alu (A,B: in std_logic_vector; signal S: out std_logic_vector;
						signal N,V,Z,C: out std_logic; SIGNED_OP: in std_logic;
						CTRL_ALU: in FCODE);

-- Procedure control
--		permet de positionner les signaux de control pour chaque etage (EX MEM ER)
--		en fonction de l'instruction identifiee soit par son code op, soit par
--		son code fonction, soit par son code branchement.
	procedure control ( OP : in std_logic_vector(OPCODE'length-1 downto 0);
	                    F  : in std_logic_vector(FCODE'length-1 downto 0);
	                    B  : in std_logic_vector(BCODE'length-1 downto 0);
	                    signal di_ctrl_di : out ctrlDI;-- signaux de controle de l'etage DI
	                    signal di_ctrl_ex : out ctrlEX;-- signaux de controle de l'etage EX
	                    signal di_ctrl_me : out ctrlME;-- signaux de controle de l'etage MEM
	                    signal di_ctrl_er : out ctrlER );-- signaux de controle de l'etage ER

end cpu_package;

-- -----------------------------------------------------------------------------
-- the package contains types, constants, and function prototypes
-- -----------------------------------------------------------------------------
package body cpu_package is

-- ===============================================================
-- DEFINITION DE FONCTIONS/PROCEDURES
-- ===============================================================

-- fonction "+" --> procedure adder_cla
function "+" (A,B: in std_logic_vector) return std_logic_vector is
	variable tmp_S : std_logic_vector(A'range);
	variable tmp_COUT,tmp_V : std_logic;
begin
	adder_cla(A,B,'0',tmp_S,tmp_COUT,tmp_V);
	return tmp_S;
end "+";

-- Le drapeau overflow V ne sert que lors d'operations signees !!!
-- Overflow V=1 si operation signee et :
--		addition de deux grands nombres positifs dont le resultat < 0
--		addition de deux grands nombres negatifs dont le resultat >= 0
--		soustraction d'un grand nombre positif et d'un grand nombre negatif dont le resultat < 0
--		soustraction d'un grand nombre negatif et d'un grand nombre positif dont le resultat >= 0
--	Reviens a faire V = C_OUT xor <carry entrante du dernier bit>
-- procedure adder_cla
procedure adder_cla (
	A,B: in std_logic_vector;C_IN : in std_logic;
	S : out std_logic_vector;C_OUT : out std_logic;
	V : out std_logic
) is
	variable G_CLA,P_CLA  : std_logic_vector(A'length-1 downto 0);
	variable C_CLA        : std_logic_vector(A'length downto 0);
begin
-- calcul de P et G
	G_CLA:= A and B;
	P_CLA:= A or B;
	C_CLA(0):=C_IN;
	for I in 0 to (A'length-1) loop
		C_CLA(I+1):= G_CLA(I) or (P_CLA(I) and C_CLA(I));
	end loop;
-- mise a jour des sorties
	S:=(A Xor B) xor C_CLA(A'length-1 downto 0);
	C_OUT:=C_CLA(A'length);
	V:= C_CLA(A'length) xor C_CLA(A'length - 1);
end adder_cla;

-- procedure alu
procedure alu (A,B: in std_logic_vector;signal S: out std_logic_vector;
					signal N,V,Z,C: out std_logic;SIGNED_OP: in std_logic;
					CTRL_ALU: in FCODE) is
	variable DATA_WIDTH : positive := A'length;
	variable b_in       : std_logic_vector(DATA_WIDTH-1 downto 0);
	variable c_in       : std_logic;
	variable tmp_S      : std_logic_vector(DATA_WIDTH-1 downto 0);
	variable tmp_V      : std_logic;
	variable tmp_N      : std_logic;
	variable tmp_C      : std_logic;
	variable tmp_CLA_C  : std_logic;
	variable tmp_CLA_V  : std_logic;
begin
-- raz signaux
	tmp_V := '0';
	tmp_N := '0';
	tmp_C := '0';
-- case sur le type d'operation
	case CTRL_ALU is
		when ADD|ADDU|ADDI|ADDIU | SUB|SUBU | SLT|SLTU|SLTI|SLTIU => -- ALU_ADD | ALU_SUB | ALU_SLT
			b_in := B;
			c_in := '0';
			if ((CTRL_ALU/=ADD)and(CTRL_ALU/=ADDU)and(CTRL_ALU/=ADDI)and(CTRL_ALU/=ADDIU)) then
				b_in := not(B);
				c_in := '1';
			end if;
			adder_cla(A,b_in,c_in,tmp_S,tmp_C,tmp_V);
			if (CTRL_ALU=SLT or CTRL_ALU=SLTU) then
				tmp_S := conv_std_logic_vector( (SIGNED_OP and (tmp_V xor tmp_S(DATA_WIDTH-1))) or (not(SIGNED_OP) and not(tmp_C)) , S'length );
-- remize ? 0 des flags selon definition
				tmp_C := '0';
				tmp_V := '0';
			else
				tmp_C := not(SIGNED_OP) and tmp_C;
				tmp_N := SIGNED_OP and tmp_S(DATA_WIDTH-1);
				tmp_V := SIGNED_OP and tmp_V;
			end if;
		when iAND|ANDI => tmp_S := A and B;
		when iOR |ORI  => tmp_S := A  or B;
		when iNOR      => tmp_S := A nor B;
		when iXOR|XORI => tmp_S := A xor B;
		when LSL |LUI  => tmp_S := shl(A,B);
		when LSR       => tmp_S := shr(A,B);
		when others =>
	end case;
-- affectation de la sortie
	S <= tmp_S;
-- affectation du drapeau Z (valable dans tous les cas)
	if (tmp_S=conv_std_logic_vector(0,DATA_WIDTH))
	then Z <= '1';
	else Z <= '0';
	end if;
-- affectation des autres drapeaux N,V,C
	C <= tmp_C;
	N <= tmp_N;
	V <= tmp_V;
end alu;

-- === Procedure control =========================================
-- Permet de positionner les signaux de control pour chaque etage (EX MEM ER)
-- en fonction de l'instruction identifiee soit par :
-- -> son code op
-- -> son code fonction
-- -> code branchement.
procedure control ( OP : in std_logic_vector(OPCODE'length-1 downto 0);
							F : in std_logic_vector(FCODE'length-1 downto 0);
							B : in std_logic_vector(BCODE'length-1 downto 0);
							signal di_ctrl_di	: out ctrlDI;
							signal di_ctrl_ex	: out ctrlEX;
							signal di_ctrl_me	: out ctrlME;
							signal di_ctrl_er	: out ctrlER ) is
begin
-- Initialisation
	di_ctrl_di <= DI_DEFL; -- IMM_UNSIGNED,'0','0'
	di_ctrl_ex <= EX_DEFL; -- SUB,ALU_SIGNED,REGS_QA,REGS_QB,REG_RT
	di_ctrl_me <= ME_DEFL; -- MEM_32,B_NULL,MEM_READ,MEM_UNSIGNED,'0'
	di_ctrl_er <= ER_DEFL; -- REG_WRITE,ALU_S

	if(OP=TYPE_R)then                  -- REG ARITHMETIC
		di_ctrl_di.JUMP_REG  <= '1'        when F=JR  or F=JALR;
		di_ctrl_ex.REG_DST   <= REG_RD;-- 
		di_ctrl_ex.ALU_SIGNED<= F(0);-- 1=unsigned
		di_ctrl_ex.ALU_SRCA  <= REGS_QB    when F=LSL or F=LSR;
		di_ctrl_ex.ALU_SRCB  <= VAL_DEC    when F=LSL or F=LSR;
		di_ctrl_er.REGS_SRCD <= NextPC     when F=JR  or F=JALR;
		di_ctrl_er.REGS_WE   <= REG_RDONLY when F=JR;
		di_ctrl_ex.ALU_OP    <= LSR        when F=JR  or F=JALR else F;-- JR=ADDI, JALR=ADDIU
		if(f=SYNC)then report "BREAK INSTR" severity FAILURE;end if;
	elsif(OP=TYPE_B)then               -- REG BRANCH
		di_ctrl_ex.ALU_SRCB   <= IMM_0;
		with(B) select di_ctrl_me.branch <= 
			B_LT when BLTZ|BLTZAL,B_GE when BGEZ|BGEZAL,B_NULL when others;
	elsif OP(5 downto 4) = "10" then   -- MEMOIRE L*/S*
		di_ctrl_ex.REG_DST    <= REG_RD when OP(3)='1' else REG_RT;
		di_ctrl_me.DC_RW      <= OP(3);
		di_ctrl_me.DC_DS      <= OP(1 downto 0);
		di_ctrl_me.DC_SIGNED  <= OP(2);
		di_ctrl_er.REGS_WE    <= OP(3);
	elsif OP(5 downto 3) = "001"  then -- IMM ARITHMETIC (REG_RT=REGS_QA <?> IMMD)
		di_ctrl_er.REGS_SRCD  <= ALU_S;
		di_ctrl_ex.ALU_SRCA   <= IMMD   when OP=LUI;
		di_ctrl_ex.ALU_SRCB   <= IMM_16 when OP=LUI else IMMD;
		di_ctrl_ex.ALU_SIGNED <= OP(0);-- 1=unsigned
		di_ctrl_di.SIGNED_EXT <= IMM_SIGNED when OP=ADDI or OP=ADDIU or OP=SLTI;
		di_ctrl_ex.ALU_OP <= OP;
	elsif OP(5 downto 2) = "0001" then -- IMM BRANCH (JUMP_BRA = r[rs]<?>r[rt/0])
		with(OP) select di_ctrl_me.branch <=
			B_EQ when BEQ,B_NE when BNE,B_LE when BLEZ,	B_GT when BGTZ,B_NULL when others;
	elsif OP(5 downto 1) = "00001" then -- JUMP (J/JAL)
		di_ctrl_di.JUMP_IMM <= '1';
		di_ctrl_er.REGS_WE <= REG_WRITE when OP = JAL else REG_RDONLY;
		di_ctrl_ex.REG_DST <= REG_31    when OP = JAL else REG_RD;
	end if;
end control;
end cpu_package;
