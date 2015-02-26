-------------------------------------------------------------------------------
-- Banc de registres
-- THIEBOLT Francois le 05/04/04
-------------------------------------------------------------------------------

--------------------------------------------------------------
-- Par defaut 32 registres de 32 bits avec lecture double port
--------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;
use WORK.cpu_package.all;

entity registres is
	generic	(-- definition des parametres generiques
		DBUS_WIDTH   : integer   := 32; -- largeur du bus de donnees par defaut
		ABUS_WIDTH   : integer   := 5;  -- largeur du bus adr pour acces registre soit 32 (2**5) par defaut
		ACTIVE_FRONT : std_logic := '1' -- definition du front actif d'ecriture par defaut
	);
	port 	(-- definition des entrees/sorties
		CLK,RST,W         : in  std_logic;
		ADR_A,ADR_B,ADR_W : in  std_logic_vector(ABUS_WIDTH-1 downto 0);
		D                 : in  std_logic_vector(DBUS_WIDTH-1 downto 0);
		QA,QB             : out std_logic_vector(DBUS_WIDTH-1 downto 0)
	);
end registres;

-------------------------------------------------------------------------------
-- REGISTRES architecture
-------------------------------------------------------------------------------

architecture behavior of registres is
	type FILE_REGS is array (0 to (2**ABUS_WIDTH)-1) of std_logic_vector (DBUS_WIDTH-1 downto 0);
	signal REGS : FILE_REGS; -- le banc de registres
begin

QA <= 
	(others => 'X') when is_x(ADR_A) else -- X si adresse invalide
	(others => '0') when conv_integer(ADR_A)=0 else -- 0 si R0
	D               when (W='0' and ADR_A = ADR_W) else -- D si access simultané
	REGS(conv_integer(ADR_A));-- sinon registre

QB <= 
	(others => 'X') when is_x(ADR_B) else -- X si adresse invalide
	(others => '0') when conv_integer(ADR_B)=0 else -- 0 si R0
	D               when (W='0' and ADR_B = ADR_W) else -- D si access simultané
	REGS(conv_integer(ADR_B));-- sinon registre

P_WRITE: process(CLK)
begin
	if (CLK'event and CLK=ACTIVE_FRONT) then-- test du front actif d'horloge
		if RST='0' then -- test du reset (actif a l'etat bas)
			REGS <= (others => conv_std_logic_vector(0,DBUS_WIDTH));
		else-- test si ecriture dans le registre
			if ((W='0') and (conv_integer(ADR_W) /= 0)) then
				REGS(conv_integer(ADR_W)) <= D;
			end if;
		end if;
	end if;
end process P_WRITE;

end behavior;
