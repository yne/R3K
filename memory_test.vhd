------------------------------------
-- Fichier de test pour Banc Memoire
-- THIEBOLT Francois le 08/12/04
------------------------------------

-- Definition des librairies
library IEEE;
library WORK;

-- Definition des portee d'utilisation
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;
-- use WORK.func_package.all;
use WORK.cpu_package.all;

-- Definition de l'entite
entity test_memory is
end test_memory;

-- Definition de l'architecture
architecture behavior of test_memory is

-- definition de constantes de test
	constant S_DATA	: positive := CPU_DATA_WIDTH; -- taille du bus de donnees
	constant S_ADR		: positive := CPU_ADR_WIDTH; -- taille du bus d'adresse
	constant S_L1		: positive := L1_SIZE; -- taille du cache L1 en nombre de mots
--	constant S_L1		: positive := 32; -- taille du cache L1 en nombre de mots
	constant WFRONT 	: std_logic := L1_FRONT; -- front actif pour ecriture
	constant FILENAME : string := ""; -- init a 0 par defaut
--	constant FILENAME : string := "rom_file.0.txt"; -- init par fichier
	constant TIMEOUT 	: time := 200 ns; -- timeout de la simulation

-- definition de constantes
constant clkpulse : Time := 5 ns; -- 1/2 periode horloge

-- definition de types

-- definition de ressources internes

-- definition de ressources externes
signal E_RST         : std_logic; -- actif a l'etat bas
signal E_CLK         : std_logic;
signal E_RW          : std_logic;
signal E_DS          : std_logic_vector(1 downto 0);
signal E_Signed      : std_logic;
signal E_AS          : std_logic;
signal E_Ready,E_Berr: std_logic;
signal E_ADR         : std_logic_vector(S_ADR-1 downto 0); -- bus adresse au format octet !
signal E_D,E_Q       : std_logic_vector(S_DATA-1 downto 0);

begin

--------------------------
-- definition de l'horloge
P_E_CLK: process
begin
	E_CLK <= '1';
	wait for clkpulse;
	E_CLK <= '0';
	wait for clkpulse;
end process P_E_CLK;

-----------------------------------------
-- definition du timeout de la simulation
P_TIMEOUT: process
begin
	wait for TIMEOUT;
	assert FALSE report "SIMULATION TIMEOUT!!!" severity FAILURE;
end process P_TIMEOUT;

-----------------------------------------
-- instanciation et mapping de composants
L1 : entity work.memory(behavior)
			generic map (S_DATA,S_ADR,S_L1,WFRONT,FILENAME)
			port map (RST => E_RST, CLK => E_CLK, RW => E_RW,
							DS => E_DS, SIGN => E_Signed, AS => E_AS,
							Ready => E_Ready, Berr => E_Berr,
							ADR => E_ADR, D => E_D, Q => E_Q );

-----------------------------
-- debut sequence de test
P_TEST: process
begin

	-- initialisations
	E_RST <= '0';
	E_RW <= MEM_READ;
	E_DS <= MEM_8;
	E_Signed <= MEM_UNSIGNED;
	E_AS <= '0';
	E_ADR <= (others => 'X');
	E_D <= (others => 'X');

	-- sequence RESET
	E_RST <= '0';
	wait for clkpulse*3;
	E_RST <= '1';
	wait for clkpulse;

	-- ecriture octet a l'octet 1
	wait until (E_CLK=(WFRONT)); wait for clkpulse/2;
	E_ADR <= conv_std_logic_vector(1,S_ADR);
	E_DS <= MEM_8;
	E_D <= to_stdlogicvector(BIT_VECTOR'(X"FFFFFFAA"));
	E_RW <= MEM_WRITE;
	E_AS <= '1';
	E_Signed <= MEM_UNSIGNED;

	-- ecriture demi-mot a l'octet 2
	wait until (E_CLK=(WFRONT)); wait for clkpulse/2;
	E_ADR <= conv_std_logic_vector(2,S_ADR);
	E_DS <= MEM_16;
	E_D <= to_stdlogicvector(BIT_VECTOR'(X"FFFFBBBB"));
	E_RW <= MEM_WRITE;
	E_AS <= '1';
	E_Signed <= MEM_UNSIGNED;

	-- ecriture mot a l'octet 4
	wait until (E_CLK=(WFRONT)); wait for clkpulse/2;
	E_ADR <= conv_std_logic_vector(4,S_ADR);
	E_DS <= MEM_32;
	E_D <= to_stdlogicvector(BIT_VECTOR'(X"CCCCCCCC"));
	E_RW <= MEM_WRITE;
	E_AS <= '1';
	E_Signed <= MEM_UNSIGNED;

	-- ecriture octet a l'octet 6
	wait until (E_CLK=(WFRONT)); wait for clkpulse/2;
	E_ADR <= conv_std_logic_vector(6,S_ADR);
	E_DS <= MEM_8;
	E_D <= to_stdlogicvector(BIT_VECTOR'(X"FFFFFFDD"));
	E_RW <= MEM_WRITE;
	E_AS <= '1';
	E_Signed <= MEM_UNSIGNED;

	-- lecture octet a l'octet 2
	wait until (E_CLK=(WFRONT)); wait for clkpulse/2;
	E_D <= (others => 'X'); -- disable Datas on DataBus
	E_RW <= MEM_READ;
	E_ADR <= conv_std_logic_vector(2,S_ADR);
	E_DS <= MEM_8;
	E_AS <= '1';
	E_Signed <= MEM_UNSIGNED;

	-- tests & lecture demi-mot a l'octet 6
	wait until (E_CLK=(WFRONT)); wait for clkpulse/2;
	assert E_Q = to_stdlogicvector(BIT_VECTOR'(X"000000BB"))
		report "Memory 2 BAD VALUE"
		severity ERROR;
	E_RW <= MEM_READ;
	E_AS <= '1';
	E_Signed <= MEM_UNSIGNED;
	E_ADR <= conv_std_logic_vector(6,S_ADR);
	E_DS <= MEM_16;

	-- tests & lecture mot a l'octet 0
	wait until (E_CLK=(WFRONT)); wait for clkpulse/2;
	assert E_Q = to_stdlogicvector(BIT_VECTOR'(X"0000CCDD"))
		report "Memory 6 BAD VALUE"
		severity ERROR;
	E_RW <= MEM_READ;
	E_AS <= '1';
	E_Signed <= MEM_UNSIGNED;
	E_ADR <= conv_std_logic_vector(0,S_ADR);
	E_DS <= MEM_32;

	-- tests & lecture octet signe a l'adresse 6
	wait until (E_CLK=(WFRONT)); wait for clkpulse/2;
	assert E_Q = to_stdlogicvector(BIT_VECTOR'(X"BBBBAA00"))
		report "Memory 0 BAD VALUE"
		severity ERROR;
	E_RW <= MEM_READ;
	E_AS <= '1';
	E_Signed <= MEM_SIGNED;
	E_ADR <= conv_std_logic_vector(6,S_ADR);
	E_DS <= MEM_8;

	-- tests
	wait until (E_CLK=(WFRONT)); wait for clkpulse/2;
	E_RW <= MEM_READ;
	E_AS <= '0';
	E_Signed <= MEM_UNSIGNED;
	assert E_Q = to_stdlogicvector(BIT_VECTOR'(X"FFFFFFDD"))
		report "Memory 6 BAD VALUE"
		severity ERROR;

	-- erreur de lecture demi-mot a l'adresse 1
	wait until (E_CLK=(WFRONT)); wait for clkpulse/2;
	E_RW <= MEM_READ;
	E_AS <= '1';
	E_Signed <= MEM_UNSIGNED;
	E_ADR <= conv_std_logic_vector(3,S_ADR);
	E_DS <= MEM_16;

	-- tests
	wait until (E_CLK=(WFRONT)); wait for clkpulse/2;
	E_RW <= MEM_READ;
	E_AS <= '0';
	E_Signed <= MEM_UNSIGNED;
	assert E_Berr = '0'
		report "Berr not reporting error !"
		severity ERROR;

	-- ADD NEW SEQUENCE HERE

	-- LATEST COMMAND (NE PAS ENLEVER !!!)
	wait until (E_CLK=(WFRONT)); wait for clkpulse/2;
	assert FALSE report "FIN DE SIMULATION" severity FAILURE;
	-- assert (NOW < TIMEOUT) report "FIN DE SIMULATION" severity FAILURE;

end process P_TEST;

end behavior;
