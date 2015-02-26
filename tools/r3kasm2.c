/* =================================================================================
	Assembleur R3000
	================================================================================= */

#include <stdio.h>
#include <ctype.h>
#include <string.h>
#include "r3kasm2.h"

/* R3Kasm by FOX ******************************************************/

int verbose=0;

// One line read from file
void Lread(FILE *s, char *dest){
	int i=0;

	do
		dest[i++]= (char) fgetc(s);
	while( (!feof(s)) && (dest[i-1] != '\n') );
	dest[i]='\0';
	if (feof(s))
		dest[i-1]='\0';
}

// Nettoyage de la chaine de caractere lue
void Nettoyage(char *dest){
	char *p1,*p2;
	p1=dest;
	p2=p1;

	while ( *p2 != '\0' ){
		if ((*p2!=' ') && (*p2!='\n') && (*p2!='\t'))
			*p1++=*p2;
		p2++;
	}
	*p1='\0';
}

// Conversion d'un entier en un binaire de type char*
void intTOsbin(int n, char *result, int length){
	int tmp,i;
	strcpy(result,"");

	for(i=length-1;i>=0;i--){
		tmp= n & (1<<i);
		if (tmp==0)
			strcat(result, "0");
		else
			strcat(result, "1");
	}
//	fprintf(stderr,"Conversion n %d sur %dbits = %s\n",n,length,result);
}

// Mise en MAJUSCULE
void strUP(char *s){
	int i;

	for(i=0;i<strlen(s);i++)
		s[i]=toupper(s[i]);
}

// Ajoute un label dans la liste
void addLabel(const char *name, int CP, TLabels *l){
	strcpy( (*l).name[(*l).nb], name );
	(*l).cp[(*l).nb]=CP;
	(*l).nb++;
}

// Retourne le CP du label correspondant
int cpLabel(const char *name, TLabels *l){
	int i;

	for(i=0;i<(*l).nb;i++){
		if ( strcmp(name,(*l).name[i])==0 )
		return (*l).cp[i];
	}

	// si on est ici c'est que le label est inconnu !
	printf ("\tERROR label %s unknown !\n",name);
	exit (1);
}

// Ecriture de l'OPcode assemble
void opMake(FILE *f, int type, const char *op, int rs, int rt, int rd, int valdec,
					const char *fct, int imm, int adr){
	static char tmp[200];
	char retop[OPCODE+1];
	strcpy(retop,"");

	// Tests de conformite
	if ( (rs<0) || (rs>=MAX_REGS) ){
		printf ("\tERROR registre RS invalide: R%d\n",rs);
		exit(1); 
	}

	if ( (rt<0) || (rt>=MAX_REGS) ){
		printf ("\tERROR registre RT invalide: R%d\n",rt);
		exit(1);
	}

	if ( (rd<0) || (rd>=MAX_REGS) ){
		printf ("\tERROR registre RD invalide: R%d\n",rd);
		exit(1);
	}

	if ( (valdec<0) || (valdec>=MAX_VALDEC) ){
		printf ("\tERROR valdec incorrect: %d\n",valdec);
		exit(1);
	}

	switch(type){
		case TYPE_R:
		{
			strcat(retop,op); //code op
			intTOsbin(rs,tmp,5);
			strcat(retop,tmp); //rs
			intTOsbin(rt,tmp,5);
			strcat(retop,tmp); //rt
			intTOsbin(rd,tmp,5);
			strcat(retop,tmp); //rd
			intTOsbin(valdec,tmp,5); //valdec
			strcat(retop,tmp);
			strcat(retop,fct);
		}
		break;

		case TYPE_I:
		{
			strcat(retop,op); //code op
			intTOsbin(rs,tmp,5);
			strcat(retop,tmp); //rs
			intTOsbin(rt,tmp,5);
			strcat(retop,tmp); //rt
			intTOsbin(imm,tmp,16);
			strcat(retop,tmp); //imm
		}
		break;

		case TYPE_J:
		{
			strcat(retop,op); //code op
			intTOsbin(adr,tmp,26);
			strcat(retop,tmp); //adr
		}
		break;
	}
	fprintf(f,"%s\n",retop);
}

// Remplacement des macros
void replaceMacro(char *s,TMacros *m){
	char *ptr1,*ptr2,*tmp1;
	char lgnLu[100],tmp2[100],name[100];

	strcpy(lgnLu,s);
	tmp1=lgnLu;
	strUP(lgnLu);
	strcpy(tmp2,"");
	ptr1=strchr(tmp1,'$');

	do
	{
		// fprintf(stderr,"tmp1 %s **** tmp2 %s \n",tmp1,tmp2);
		strncat(tmp2,tmp1,ptr1-tmp1);
		if (*(ptr1-1)=='(')
			ptr2=strchr(ptr1,')');
		else
			ptr2=strchr(ptr1,',');

		if (ptr2!=NULL){
			strncpy(name,ptr1,ptr2-ptr1);
			name[ptr2-ptr1]='\0';
			tmp1=ptr2;
		}
		else
		{
			strcpy(name,ptr1);
			name[strlen(name)-1] = '\0';
			tmp1=ptr1+strlen(name);
		}

		Nettoyage(name);
		strcat(tmp2,searchMacro(m,name));

		ptr1=strchr(tmp1,'$'); //repere le $ suivant
	} while (ptr1!=NULL);

	strcat(tmp2,tmp1);
	strcpy(s,tmp2);
}

// Extraction des labels etiquettes macros...
void prePARSE(FILE *source, FILE *dest, TLabels *l, TMacros *m){
	char tmp[255],tmp2[255],tmp3[255];
	char *ptr;
	int CP=0;
	m->nb=0;
	fprintf(stderr,"Preparsing...\n");
	
	//On repere les macros ainsi que les etiquettes
	rewind(source);
	l->nb=0;

	while ( !feof(source) ){
		//fscanf(source,"%s",tmp);
		Lread(source,tmp);
		strUP(tmp); // majuscules
		// Nettoyage(tmp);

		// Labels
		if (tmp[0]==':'){
			Nettoyage(tmp);
			addLabel(tmp,CP,l);
			fprintf(stderr,"\tLabel %s -> CP %d\n",l->name[l->nb-1],l->cp[l->nb-1]);
			continue;
		}

		// Macros
		if (tmp[0]=='$'){
			sscanf(tmp,"%s %s",tmp2,tmp3);
			Nettoyage(tmp2);
			addMacro(m,tmp2,tmp3);
			fprintf(stderr,"\tMacro %s -> %s\n",m->name[m->nb-1],m->replace[m->nb-1]);
			continue;
		}

		// Commentaires ou ligne vide
		Nettoyage(tmp);
		if ( ((tmp[0]=='/') && (tmp[1]=='/')) || (tmp[0]=='\n') || (tmp[0]=='\0') )
		continue;

		fprintf(stderr,"@CP %d, inst %s\n",CP,tmp);
		CP++;
	}

	//on remplace les macros en enlevant les commentaires et etiquettes
	rewind(source);
	rewind(dest);

	while( !feof(source) ){
		Lread(source,tmp);
		strcpy(tmp2,tmp);
		Nettoyage(tmp);
		if ( (tmp[0]=='/') || (tmp[0]==':') || (tmp[0]=='$') || (tmp[0]=='\n') || (tmp[0]=='\0') )
			continue;
		if ( (ptr=strchr(tmp2,'$'))!=NULL ){
			// fprintf(stderr,"avant: %s\n",tmp);
			replaceMacro(tmp2,m);
			// fprintf(stderr,"apres: %s\n",tmp);
		}
		fprintf(dest,"%s",tmp2);
	}
}

// Ajout d'une macro
void addMacro(TMacros *m, char *name, char *replace){
	strcpy(m->name[m->nb],name);
	strcpy(m->replace[m->nb],replace);
	m->nb++;
}

// Recherche d'une macro
char *searchMacro(TMacros *m, const char *name){
	int i,j;

	//fprintf(stderr,"Search macro name %s\n",name);
	for(i=0;i<m->nb;i++){
		j=strcmp( (*m).name[i],name);
		if (j==0){
			printf ( "\tFound macro name %s replaced by %s\n",name,(*m).replace[i]);
			return (*m).replace[i];
		}
	}

	// si on est ici c'est que la macro est inconnue !
	fprintf(stderr,"ERROR macro %s unknown !\n",name);
	exit(1);
}

/* -----------------------------------------------
	Programme Principal
	----------------------------------------------- */
int main (int argc, char *argv[]){
	FILE *source=stdin;
	FILE *dest=stdout;
	char name_ftmp[100], *tmp;
	TLabels l;
	TMacros m;
	int CP=0;
	int i;
	// Parsing des arguments
	for(i=1;i<argc;i++){
		if(argv[i][0]=='-'){
			switch(argv[i][1]){
			case 'v':verbose=1;break;
			case 'i':source=fopen(argv[i+1],"r");break;
			case 'o':dest  =fopen(argv[i+1],"w");break;
			default :printf("unknow arguments '%c'",argv[i][1]);
			}
		}else{//direct file input (may be from drag n drop)
			source=fopen(argv[i],"r");
			memcpy(name_ftmp,argv[i],sizeof(name_ftmp));
			strcat(name_ftmp,".txt");
			dest  =fopen(name_ftmp,"w");
		}
	}
	
	char *tmp_path=".tmp.asm";
	FILE *ftmp=fopen(tmp_path,"w");
	
	// ouverture du fichier source
	if (!source || !dest || !ftmp) {
		perror("File Open Error");
		exit(1);
	}
	prePARSE(source,ftmp,&l,&m);
//	return 0;

	//fermeture des fichiers
	fclose(source);
	fclose(ftmp);

	//ouverture du fichier preparse
	source=fopen(tmp_path,"rt");
	if ( source==NULL ){
		fprintf(stderr,"Impossible d'ouvrir %s\n",tmp_path);
		exit(1);
	}
	// Assemblage
	fprintf(stderr,"ASM in progress... \n");
	rewind(source);
	CP=0;
	
	while ( !feof(source) ){
		static char op[30],reste[128],tmp2[SIZE_LABELS];
		static int rs, rt, rd, imm, valdec, adr;
		static char str_imm[30];

		fscanf(source,"%s",op);
		strUP(op); //majuscules
		fprintf(stderr,"Instruction %s\n",op);
		CP++;
		fscanf(source,"%[^\n]",reste);
		strUP(reste);
		
		if(op[0]==';'){
			continue;//skip comments
		}

		if ( strcmp(op,"LSL")==0 ){
			sscanf(reste,"R%d,R%d,%d\n",&rd,&rt,&valdec);  
			opMake(dest,TYPE_R,OP_LSL,0,rt,rd,valdec,F_LSL,0,0);  
			continue;
		}

		if ( strcmp(op,"LSR")==0 ){
			sscanf(reste,"R%d,R%d,%d\n",&rd,&rt,&valdec);  
			opMake(dest,TYPE_R,OP_LSR,0,rt,rd,valdec,F_LSR,0,0);  
			continue;
		}

		if ( strcmp(op,"ADD")==0 ){
			sscanf(reste,"R%d,R%d,R%d\n",&rd,&rs,&rt);  
			opMake(dest,TYPE_R,OP_ADD,rs,rt,rd,0,F_ADD,0,0);  
			continue;
		}

		if ( strcmp(op,"ADDU")==0 ){
			sscanf(reste,"R%d,R%d,R%d\n",&rd,&rs,&rt);  
			opMake(dest,TYPE_R,OP_ADDU,rs,rt,rd,0,F_ADDU,0,0);  
			continue;
		}

		if ( strcmp(op,"SUB")==0 ){
			sscanf(reste,"R%d,R%d,R%d\n",&rd,&rs,&rt);  
			opMake(dest,TYPE_R,OP_SUB,rs,rt,rd,0,F_SUB,0,0);  
			continue;
		}

		if ( strcmp(op,"SUBU")==0 ){
			sscanf(reste,"R%d,R%d,R%d\n",&rd,&rs,&rt);  
			opMake(dest,TYPE_R,OP_SUBU,rs,rt,rd,0,F_SUBU,0,0);  
			continue;
		}

		if ( strcmp(op,"AND")==0 ){
			sscanf(reste,"R%d,R%d,R%d\n",&rd,&rs,&rt);  
			opMake(dest,TYPE_R,OP_AND,rs,rt,rd,0,F_AND,0,0);  
			continue;
		}

		if ( strcmp(op,"OR")==0 ){
			sscanf(reste,"R%d,R%d,R%d\n",&rd,&rs,&rt);  
			opMake(dest,TYPE_R,OP_OR,rs,rt,rd,0,F_OR,0,0);  
			continue;
		}

		if ( strcmp(op,"XOR")==0 ){
			sscanf(reste,"R%d,R%d,R%d\n",&rd,&rs,&rt);
			opMake(dest,TYPE_R,OP_XOR,rs,rt,rd,0,F_XOR,0,0);  
			continue;
		}

		if ( strcmp(op,"NOR")==0 ){
			sscanf(reste,"R%d,R%d,R%d\n",&rd,&rs,&rt);
			opMake(dest,TYPE_R,OP_NOR,rs,rt,rd,0,F_NOR,0,0);  
			continue;
		}

		if ( strcmp(op,"SLT")==0 ){
			sscanf(reste,"R%d,R%d,R%d\n",&rd,&rs,&rt);  
			opMake(dest,TYPE_R,OP_SLT,rs,rt,rd,0,F_SLT,0,0);  
			continue;
		}

		if ( strcmp(op,"SLTU")==0 ){
			sscanf(reste,"R%d,R%d,R%d\n",&rd,&rs,&rt);  
			opMake(dest,TYPE_R,OP_SLTU,rs,rt,rd,0,F_SLTU,0,0);  
			continue;
		}

		if ( strcmp(op,"JR")==0 ){
			sscanf(reste,"R%d\n",&rs);  
			opMake(dest,TYPE_R,OP_JR,rs,0,0,0,F_JR,0,0);  
			continue;
		}

		if ( strcmp(op,"JALR")==0 ){
			sscanf(reste,"R%d,R%d\n",&rs,&rd);  
			opMake(dest,TYPE_R,OP_JALR,rs,0,rd,0,F_JALR,0,0);  
			continue;
		}

		if ( strcmp(op,"BLTZ")==0 ){
			sscanf(reste,"R%d,%s\n",&rs,tmp2);
			if (tmp2[0]==':'){
				fprintf(stderr,"\tlabel %s\n",tmp2);  
				imm=(cpLabel(tmp2,&l)-CP);
			}
			else
				sscanf(tmp2,"%d",&imm);
			opMake(dest,TYPE_I,OP_BLTZ,rs,0,0,0,NULL,imm,0);  
			continue;
		}

		if ( strcmp(op,"BGEZ")==0 ){
			sscanf(reste,"R%d,%s\n",&rs,tmp2);
			if (tmp2[0]==':'){
				fprintf(stderr,"\tlabel %s\n",tmp2);  
				imm=(cpLabel(tmp2,&l)-CP);
			}
			else
				sscanf(tmp2,"%d",&imm);  
			opMake(dest,TYPE_I,OP_BGEZ,rs,1,0,0,NULL,imm,0);  
			continue;
		}

		if ( strcmp(op,"BLTZAL")==0 ){
			sscanf(reste,"R%d,%s\n",&rs,tmp2);
			if (tmp2[0]==':'){
				fprintf(stderr,"\tlabel %s\n",tmp2);  
				imm=(cpLabel(tmp2,&l)-CP);
			}
			else
				sscanf(tmp2,"%d",&imm);  
			opMake(dest,TYPE_I,OP_BLTZAL,rs,16,0,0,NULL,imm,0);  
			continue;
		}

		if (strcmp(op,"BGEZAL")==0 ){
			sscanf (reste,"R%d,%s\n",&rs,tmp2);
			if (tmp2[0]==':'){
				fprintf(stderr,"\tlabel %s\n",tmp2);  
				imm=(cpLabel(tmp2,&l)-CP);
			}
			else
				sscanf(tmp2,"%d",&imm);  
			opMake(dest,TYPE_I,OP_BGEZAL,rs,17,0,0,NULL,imm,0);  
			continue;
		}

		if ( strcmp(op,"J")==0 ){
			if (reste[0]==':'){
				adr=cpLabel(reste,&l);
				fprintf(stderr,"\tlabel %s\n",reste);
			}
			else
				sscanf(reste,"%d\n",&adr);
			opMake(dest,TYPE_J,OP_J,0,0,0,0,NULL,0,adr);
			continue;
		}

		if ( strcmp(op,"JAL")==0 ){
			if (reste[0]==':'){
				adr=cpLabel(reste,&l);
				fprintf(stderr,"\tlabel %s\n",reste);
			}
			else
				sscanf (reste,"%d\n",&adr);  
			opMake(dest,TYPE_J,OP_JAL,0,0,0,0,NULL,0,adr);  
			continue;
		}

		if ( strcmp(op,"BEQ")==0 ){
			sscanf (reste,"R%d,R%d,%s\n",&rs,&rt,tmp2);
			if (tmp2[0]==':'){
				fprintf(stderr,"\tlabel %s\n",tmp2);
				imm=(cpLabel(tmp2,&l)-CP);
			}
			else
				sscanf(tmp2,"%d",&imm);  
			opMake(dest,TYPE_I,OP_BEQ,rs,rt,0,0,NULL,imm,0);  
			continue;
		}

		if ( strcmp(op,"BNE")==0 ){
			sscanf(reste,"R%d,R%d,%s\n",&rs,&rt,tmp2);
			if (tmp2[0]==':'){
				fprintf(stderr,"\tlabel %s\n",tmp2);
				imm=(cpLabel(tmp2,&l)-CP);
			}
			else
				sscanf(tmp2,"%d",&imm);
			opMake(dest,TYPE_I,OP_BNE,rs,rt,0,0,NULL,imm,0);
			continue;
		}

		if ( strcmp(op,"BLEZ")==0 ){
			sscanf(reste,"R%d,%s\n",&rs,tmp2);
			if (tmp2[0]==':'){
				fprintf(stderr,"\tlabel %s\n",tmp2);  
				imm=(cpLabel(tmp2,&l)-CP);
			}
			else
				sscanf(tmp2,"%d",&imm);  
			opMake(dest,TYPE_I,OP_BLEZ,rs,0,0,0,NULL,imm,0);  
			continue;
		}

		if ( strcmp(op,"BGTZ")==0 ){
			sscanf(reste,"R%d,%s\n",&rs,tmp2);
			if (tmp2[0]==':'){
				fprintf(stderr,"\tlabel %s\n",tmp2);  
				imm=(cpLabel(tmp2,&l)-CP);
			}
			else
				sscanf(tmp2,"%d",&imm);
			opMake(dest,TYPE_I,OP_BGTZ,rs,0,0,0,NULL,imm,0);  
			continue;
		}

		if ( strcmp(op,"ADDI")==0 ){
			sscanf(reste,"R%d,R%d,%d\n",&rt,&rs,&imm);
			opMake(dest,TYPE_I,OP_ADDI,rs,rt,0,0,0,imm,0);  
			continue;
		}

		if ( strcmp(op,"ADDIU")==0 ){
			sscanf(reste,"R%d,R%d,%d\n",&rt,&rs,&imm);  
			opMake(dest,TYPE_I,OP_ADDIU,rs,rt,0,0,0,imm,0);  
			continue;
		}

		if ( strcmp(op,"SLTI")==0 ){
			sscanf(reste,"R%d,R%d,%d\n",&rt,&rs,&imm);  
			opMake(dest,TYPE_I,OP_SLTI,rs,rt,0,0,0,imm,0);  
			continue;
		}

		if ( strcmp(op,"SLTIU")==0 ){
			sscanf(reste,"R%d,R%d,%d\n",&rt,&rs,&imm);  
			opMake(dest,TYPE_I,OP_SLTIU,rs,rt,0,0,0,imm,0);  
			continue;
		}

		if ( strcmp(op,"ANDI")==0 ){
			sscanf(reste,"R%d,R%d,%d\n",&rt,&rs,&imm);  
			opMake(dest,TYPE_I,OP_ANDI,rs,rt,0,0,0,imm,0);  
			continue;
		}

		if ( strcmp(op,"ORI")==0 ){
			sscanf(reste,"R%d,R%d,%d\n",&rt,&rs,&imm);  
			opMake(dest,TYPE_I,OP_ORI,rs,rt,0,0,0,imm,0);  
			continue;
		}

		if ( strcmp(op,"XORI")==0 ){
			sscanf(reste,"R%d,R%d,%d\n",&rt,&rs,&imm);  
			opMake(dest,TYPE_I,OP_XORI,rs,rt,0,0,0,imm,0);  
			continue;
		}

		if ( strcmp(op,"LUI")==0 ){
			sscanf(reste,"%d(R%d)\n",&imm,&rt);  
			opMake(dest,TYPE_I,OP_LUI,0,rt,0,0,0,imm,0);  
			continue;
		}

		if ( strcmp(op,"LB")==0 ){
			sscanf(reste,"R%d,%d(R%d)\n",&rt,&imm,&rs);  
			opMake(dest,TYPE_I,OP_LB,rs,rt,0,0,0,imm,0);  
			continue;
		}

		if ( strcmp(op,"LH")==0 ){
			sscanf(reste,"R%d,%d(R%d)\n",&rt,&imm,&rs);  
			opMake(dest,TYPE_I,OP_LH,rs,rt,0,0,0,imm,0);  
			continue;
		}

		if ( strcmp(op,"LW")==0 ){
			sscanf(reste,"R%d,%d(R%d)\n",&rt,&imm,&rs);  
			opMake(dest,TYPE_I,OP_LW,rs,rt,0,0,0,imm,0);
			continue;
		}

		if ( strcmp(op,"LBU")==0 ){
			sscanf(reste,"R%d,%d(R%d)\n",&rt,&imm,&rs);  
			opMake(dest,TYPE_I,OP_LBU,rs,rt,0,0,0,imm,0);
			continue;
		}

		if ( strcmp(op,"LHU")==0 ){
			sscanf(reste,"R%d,%d(R%d)\n",&rt,&imm,&rs);  
			opMake(dest,TYPE_I,OP_LHU,rs,rt,0,0,0,imm,0);
			continue;
		}

		if ( strcmp(op,"SB")==0 ){
			sscanf(reste,"R%d,%d(R%d)\n",&rt,&imm,&rs);
			opMake(dest,TYPE_I,OP_SB,rs,rt,0,0,0,imm,0);
			continue;
		}

		if ( strcmp(op,"SH")==0 ){
			sscanf(reste,"R%d,%d(R%d)\n",&rt,&imm,&rs);  
			opMake(dest,TYPE_I,OP_SH,rs,rt,0,0,0,imm,0);
			continue;
		}

		if ( strcmp(op,"SW")==0 ){
			sscanf(reste,"R%d,%d(R%d)\n",&rt,&imm,&rs);  
			opMake(dest,TYPE_I,OP_SW,rs,rt,0,0,0,imm,0);
			continue;
		}

		// Mnemonique inconnu
		fprintf(stderr,"\tERROR UNKNOWN INSTRUCTION\n");
		exit(1);
	}
	// fermeture des fichiers
	fclose(source);
	remove(tmp_path);
	fclose(dest);
}
