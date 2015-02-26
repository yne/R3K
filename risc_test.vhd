------------------------------------------------------------------
-- Fichier de test du processeur RISC
-- THIEBOLT Francois le 16/12/02
------------------------------------------------------------------

-- Definition des librairies
library IEEE;
library WORK;

-- Definition des portee d'utilisation
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;
use WORK.cpu_package.all;

-- Definition de l'entite
entity test_risc is
end test_risc;

-- Definition de l'architecture
architecture behavior of test_risc is

-- definition des constantes de test
	constant FILE_I	: string 	:= "icache.txt";
	constant FILE_D	: string 	:= "";
	constant WFRONT 	: std_logic	:= CPU_WR_FRONT;
	constant TIMEOUT 	: time 		:= 2000 ns; -- timeout de la simulation

-- definition de constantes
constant clkpulse : Time := 5 ns; -- 1/2 periode horloge

-- definition de types

-- definition de ressources internes

-- definition de ressources externes
signal E_CLK							: std_logic;
signal E_RST		 					: std_logic; -- actifs a l'etat bas

begin

------------------------------------------------------------------
-- definition de l'horloge
P_E_CLK: process
begin
	E_CLK <= '1';
	wait for clkpulse;
	E_CLK <= '0';
	wait for clkpulse;
end process P_E_CLK;

------------------------------------------------------------------
-- definition du timeout de la simulation
P_TIMEOUT: process
begin
	wait for TIMEOUT;
	assert FALSE report "SIMULATION TIMEOUT!!!" severity FAILURE;
end process P_TIMEOUT;

------------------------------------------------------------------
-- instantiation et mapping du composant processeur
r3k : entity work.risc(behavior)
			generic map ( IFILE=>FILE_I, DFILE=>FILE_D )
			port map ( CLK=>E_CLK, RST=>E_RST);

------------------------------------------------------------------
-- debut sequence de test
P_TEST: process
begin

	-- initialisations
	E_RST <= '0';

	-- sequence RESET
	E_RST <= '0';
	wait for clkpulse*3;
	E_RST <= '1';
	wait for clkpulse;

	-- ADD NEW SEQUENCE HERE

	-- LATEST COMMAND (NE PAS ENLEVER !!!)
	wait until (E_CLK=(WFRONT)); wait for clkpulse/2;
	--assert FALSE report "FIN DE SIMULATION" severity FAILURE;
	wait; -- le processeur ne s'arrete pas, on attend le timeout

end process P_TEST;

end behavior;
