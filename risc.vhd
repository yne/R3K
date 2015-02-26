------------------------------------
-- Processeur RISC
-- THIEBOLT Francois le 09/12/04
------------------------------------

---------------------------------------------------------
-- Lors de la phase RESET, permet la lecture d'un fichier
-- instruction et un fichier donnees passe en parametre
--	generique.
---------------------------------------------------------

-- Definition des librairies
library IEEE;

-- Definition des portee d'utilisation
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;
use WORK.cpu_package.all;

-- Definition de l'entite
entity risc is
	generic(
		IFILE : string := "";  -- cache instruction
		DFILE : string := ""   -- cache donnees
	);
	port(
		RST : in std_logic; -- actifs a l'etat bas
		CLK : in std_logic
	);
end risc;

-- Definition de l'architecture du banc de registres
architecture behavior of risc is
	-- Registres du pipeline
	signal reg_EI_DI     : EI_DI;     -- registre pipeline EI/DI
	signal reg_DI_EX     : DI_EX;     -- registre pipeline DI/EX
	signal reg_EX_ME     : EX_ME;     -- registre pipeline EX/MEM
	signal reg_ME_ER     : ME_ER;     -- registre pipeline MEM/ER
	signal reg_PC        : ADDR;      -- compteur programme format octet
	-- Ressources des etages
	signal ei_pc_mux     : MUX_PC_SRC;-- doit ont CP+4 ou CP=BRANCH ou CP=PC+IMM
	signal ei_pc_next    : PC;        -- pointeur sur prochaine instruction
	signal di_pc_branch  : PC;        -- IMM+PC
	signal ei_pc_jump    : PC;        -- JADDR
	signal ei_inst       : INST;      -- instruction en sortie du cache instruction
	signal di_ctrl_di    : ctrlDI;    -- signaux de controle de l'etage DI
	signal di_ctrl_ex    : ctrlEX;    -- signaux de controle de l'etage EX
	signal di_ctrl_me    : ctrlME;    -- signaux de controle de l'etage ME
	signal di_ctrl_er    : ctrlER;    -- signaux de controle de l'etage ER
	signal di_imm_ext    : DATA;      -- valeur immediate etendue
	signal di_qa         : DATA;      -- sortie QA du banc de registres
	signal di_qb         : DATA;      -- sortie QB du banc de registres
	signal ex_alu_a      : DATA;      -- ALU Entée A
	signal ex_alu_b      : DATA;      -- ALU Entée B
	signal me_data       : DATA;      -- sortie du banc memoire (dcache)
	signal er_regd       : DATA;      -- donnees a ecrire dans le banc de registre
	signal er_adrw       : REGS;      -- adresse du registre a ecrire dans le banc

begin

-- ===============================================================
-- === Etage EI ==================================================
-- ===============================================================

-- instanciation et mapping du composant cache instruction
icache : entity work.memory(behavior)
generic map (
	DBUS_WIDTH=>CPU_DATA_WIDTH,
	ABUS_WIDTH=>CPU_ADR_WIDTH,
	MEM_SIZE=>L1_ISIZE,
	ACTIVE_FRONT=>L1_FRONT,
	FILENAME=>IFILE )
port map (
	RST=>RST,
	CLK=>CLK,
	RW=>'0',
	DS=>MEM_32,
	SIGN=>'0',
	AS=>'1',
	Ready=>open,
	Berr=>open,
	ADR=>reg_PC,
	D=>(others => '0'),
	Q=>ei_inst
);

-- Affectations dans le domaine combinatoire de l'etage EI

-- Incrementation du PC (format mot)
with(ei_pc_mux) select ei_pc_next <= 
	reg_PC(PC'range)+1 when PC_NEXT, -- "+" surchargé par l'entity adder
	di_pc_branch       when PC_BRANCH,-- BEQ,BNE,BLEZ,BGTZ,BLTZ,BGEZ,BLTZAL,BGEZAL
	ei_pc_jump         when PC_JUMP,  -- J/JAL
	di_qa(PC'range)    when PC_JUMP_R;-- JR/JALR

-- Process Etage Extraction de l'instruction et mise a jour de l'etage EI/DI et du PC
EI: process(CLK,RST)
begin
	if (RST='0') then -- test du reset
		reg_PC <= PC_DEFL;-- reset du PC
	elsif (CLK'event and CLK=CPU_WR_FRONT) then -- test du front actif d'horloge
		reg_PC(PC'range)  <= ei_pc_next;-- Mise a jour PC. TODO : only if halt=0 or MEM_flush='1' or EX_flush='1'
		reg_EI_DI.pc_next <= ei_pc_next;-- Mise a jour du registre inter-etage EI/DI
		reg_EI_DI.inst    <= ei_inst;   -- TODO if ME or EX flush : ZERO
	end if;
end process EI;

-- ===============================================================
-- === Etage DI ==================================================
-- ===============================================================

-- instantiation et mapping du composant registres
r : entity work.registres(behavior)
	generic map ( 
		DBUS_WIDTH=>CPU_DATA_WIDTH,
		ABUS_WIDTH=>REG_WIDTH,
		ACTIVE_FRONT=>REG_FRONT
	)
	port map (
		CLK=>CLK,
		W=>reg_ME_ER.er_ctrl.REGS_WE,
		RST=>RST,
		D=>er_regd,
		ADR_A=>reg_EI_DI.inst(RS'range),
		ADR_B=>reg_EI_DI.inst(RT'range),
		ADR_W=>er_adrw,
		QA=>di_qa,
		QB=>di_qb
	);
------------------------------------------------------------------
-- Affectations dans le domaine combinatoire de l'etage DI
-- 

-- Calcul de l'extension de la valeur immediate
ei_pc_jump <= reg_EI_DI.inst(JADR'range);
di_imm_ext(IMM'range) <= reg_EI_DI.inst(IMM'range);
di_imm_ext(DATA'high downto IMM'high+1) <=
	(others => '0') when di_ctrl_di.signed_ext=IMM_UNSIGNED else
	(others => reg_EI_DI.inst(IMM'high));
di_pc_branch <= reg_DI_EX.pc_next + reg_DI_EX.imm_ext(PC_WIDTH-1 downto 0);
-- Appel de la procedure control
UC: control(
	reg_EI_DI.inst(OPCODE'range),
	reg_EI_DI.inst(FCODE'range),
	reg_EI_DI.inst(BCODE'range),
	di_ctrl_di,
	di_ctrl_ex,
	di_ctrl_me,
	di_ctrl_er
);

------------------------------------------------------------------
-- Process Etage Extraction de l'instruction et mise a jour de l'etage DI/EX
DI: process(CLK,RST)
begin
	-- test du reset
	if (RST='0') then
		-- reset des controle du pipeline
		reg_DI_EX.ex_ctrl  <= EX_DEFL;
		reg_DI_EX.me_ctrl  <= ME_DEFL;
		reg_DI_EX.er_ctrl  <= ER_DEFL;
	-- test du front actif d'horloge
	elsif (CLK'event and CLK=CPU_WR_FRONT) then
		-- Mise a jour du registre inter-etage DI/EX
		reg_DI_EX.pc_next  <= reg_EI_DI.pc_next;
		reg_DI_EX.rs       <= reg_EI_DI.inst(RS'range);
		reg_DI_EX.rt       <= reg_EI_DI.inst(RT'range);
		reg_DI_EX.rd       <= reg_EI_DI.inst(RD'range);
		reg_DI_EX.val_dec  <= reg_EI_DI.inst(VALDEC'range);
		reg_DI_EX.imm_ext  <= di_imm_ext;
		reg_DI_EX.jump_adr <= reg_EI_DI.inst(JADR'range);
		reg_DI_EX.rs_read  <= di_qa;
		reg_DI_EX.rt_read  <= di_qb;
		-- Mise a jour des signaux de controle
		reg_DI_EX.ex_ctrl  <= di_ctrl_ex;--TODO EX_DEFL when EI/ME/EX halt
		reg_DI_EX.me_ctrl  <= di_ctrl_me;--TODO ME_DEFL when EI/ME/EX halt
		reg_DI_EX.er_ctrl  <= di_ctrl_er;--TODO ER_DEFL when EI/ME/EX halt
	end if;
end process DI;

-- ===============================================================
-- === Etage EX ==================================================
-- ===============================================================
reg_DI_EX.val_ext <= conv_std_logic_vector(conv_integer(reg_DI_EX.val_dec),DATA'length);

with(reg_DI_EX.ex_ctrl.ALU_SRCA) select ex_alu_a <= 
	reg_DI_EX.rs_read when REGS_QA,
	reg_DI_EX.rt_read when REGS_QB, -- LSL/LSR
	reg_DI_EX.imm_ext when IMMD; -- LUI only

with(reg_DI_EX.ex_ctrl.ALU_SRCB) select ex_alu_b <= 
	reg_DI_EX.rt_read when REGS_QB,
	reg_DI_EX.imm_ext when IMMD,
	reg_DI_EX.val_ext when VAL_DEC,
	VAL16             when IMM_16,
	ZERO              when IMM_0;

alu(ex_alu_a, ex_alu_b,-- in
	reg_EX_ME.ual_S, -- out
	reg_EX_ME.ual_N, reg_EX_ME.ual_V,reg_EX_ME.ual_Z, reg_EX_ME.ual_C, -- out
	reg_DI_EX.ex_ctrl.ALU_SIGNED,reg_DI_EX.ex_ctrl.ALU_OP -- param
);

ei_pc_mux <= PC_BRANCH when
   ((reg_EX_ME.me_ctrl.BRANCH=B_NE) and (not(reg_EX_ME.ual_Z='1')                                                    ))
or ((reg_EX_ME.me_ctrl.BRANCH=B_EQ) and (   (reg_EX_ME.ual_Z='1')                                                    ))
or ((reg_EX_ME.me_ctrl.BRANCH=B_LE) and (   (reg_EX_ME.ual_Z='1') or     (reg_EX_ME.ual_V='1' xor reg_EX_ME.ual_N='1')))
or ((reg_EX_ME.me_ctrl.BRANCH=B_LT) and (not(reg_EX_ME.ual_Z='1') and    (reg_EX_ME.ual_V='1' xor reg_EX_ME.ual_N='1')))
or ((reg_EX_ME.me_ctrl.BRANCH=B_GT) and (not(reg_EX_ME.ual_Z='1') and not(reg_EX_ME.ual_V='1' xor reg_EX_ME.ual_N='1')))
or ((reg_EX_ME.me_ctrl.BRANCH=B_GE) and (   (reg_EX_ME.ual_Z='1') or  not(reg_EX_ME.ual_V='1' xor reg_EX_ME.ual_N='1')))
else PC_JUMP   when di_ctrl_di.JUMP_IMM
else PC_JUMP_R when di_ctrl_di.JUMP_REG
else PC_NEXT;

with(reg_DI_EX.ex_ctrl.REG_DST) select reg_EX_ME.reg_dst <= 
	reg_DI_EX.rd when REG_RD,
	reg_DI_EX.rt when REG_RT,
	"11111"      when REG_31;-- *AL conv_std_logic_vector(1,ABUS_WIDTH)

EX: process(CLK,RST)
begin
	if (RST='0') then-- test du reset
		reg_EX_ME.me_ctrl <= ME_DEFL;-- reset des controle du pipeline
		reg_EX_ME.er_ctrl <= ER_DEFL;
	elsif (CLK'event and CLK=CPU_WR_FRONT) then -- test du front actif d'horloge
    reg_EX_ME.pc_next  <= reg_DI_EX.pc_next;
    reg_EX_ME.rt_read  <= reg_DI_EX.rt_read;
    reg_EX_ME.me_ctrl  <= reg_DI_EX.me_ctrl;
    reg_EX_ME.er_ctrl  <= reg_DI_EX.er_ctrl;
	end if;
end process EX;



-- ===============================================================
-- === Etage ME ==================================================
-- ===============================================================

-- instanciation et mapping du composant cache de donnees
dcache : entity work.memory(behavior)
generic map (
	DBUS_WIDTH=>CPU_DATA_WIDTH,
	ABUS_WIDTH=>CPU_ADR_WIDTH,
	MEM_SIZE=>L1_DSIZE,
	ACTIVE_FRONT=>L1_FRONT,
	FILENAME=>DFILE
)
port map(
	RST=>RST,
	CLK=>CLK,
	SIGN=>reg_EX_ME.me_ctrl.DC_SIGNED,
	DS=>reg_EX_ME.me_ctrl.DC_DS,
	RW=>reg_EX_ME.me_ctrl.DC_RW,
	AS=>reg_EX_ME.me_ctrl.DC_AS,
	Ready=>open,
	Berr=>open,
	ADR=>reg_EX_ME.ual_S,
	D=>reg_EX_ME.rt_read,
	Q=>me_data
);

ME: process(CLK,RST)
begin
	if (RST='0') then -- test du reset
		reg_ME_ER.er_ctrl <= ER_DEFL;-- reset des controle du pipeline
	elsif (CLK'event and CLK=CPU_WR_FRONT) then -- test du front actif d'horloge
		reg_ME_ER.mem_Q     <= me_data;-- sortie memoire
		reg_ME_ER.er_ctrl   <= reg_EX_ME.er_ctrl;-- propa signaux de controle
		reg_ME_ER.pc_next   <= reg_EX_ME.pc_next;-- propa cp incremente
		reg_ME_ER.ual_S     <= reg_EX_ME.ual_S;  -- propa resultat ual
		reg_ME_ER.reg_dst   <= reg_EX_ME.reg_dst;-- propa registre destination
	end if;
end process ME;

-- ===============================================================
-- === Etage ER ==================================================
-- ===============================================================

ER: process(CLK,RST)
begin
end process ER;

er_adrw<=reg_ME_ER.reg_dst;
with(reg_ME_ER.er_ctrl.REGS_SRCD) select er_regd <= 
	reg_ME_ER.mem_Q        when MEM_Q,
	reg_ME_ER.ual_S        when ALU_S,
	conv_std_logic_vector(conv_integer(reg_ME_ER.pc_next), DATA'length)      when NextPC; --TODO find a better one (maybe using &"00" ?)
end behavior;
