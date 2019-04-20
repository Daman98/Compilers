%{ 
	#include <bits/stdc++.h>
	#include "main.h"
	using namespace std;

	extern int yylex();
	extern int yyparse();
	extern int yylineno;
	void yyerror(string s);

	Node * root;
	int level = 0;
	SymbolTable symtab;

	vector <Variable *> patch;
	Function * active_func_ptr = NULL;
	vector <string> dimlist;
	int error_count = 0;
%}

%union{
	Node * node;
}

%token<node> SEMI EQUAL ADD SUB MUL DIV MOD GT LT GE LE EQ NE OR AND LP RP LB RB LS RS COMMA MAIN INT VOID FLOAT FOR WHILE IF ELSE SWITCH CASE DEFAULT BREAK CONTINU RETURN INTEGERS FLOATING_POINTS IDENTIFIER

%type<node> start statements statement d t l id_arr id_arr_asg dimlist assignment sim_exp un_exp dm_exp log_exp and_exp rel_exp op1 op2 op3 term unop

%start start


%define parse.error verbose;

%%

start			:	statements 
					{ $$ = new Node("start",""); $$->children.push_back($1); root = $$; }
					;

statements		:	statement
					{ $$ = new Node("statements","");$$->children.push_back($1);} 
					|
					statement statements
					{$$ = new Node("statements","");$$->children.push_back($1);$$->children.push_back($2);}
					;
statement		:	d SEMI
					{ $$ = new Node("statement","");$$->children.push_back($1);} 
					|
					assignment SEMI
					{ $$ = new Node("statement","");$$->children.push_back($1);$$->children.push_back($2);}
					;
d				:	t l 
					{
						$$ = new Node("d","");
						$$->children.push_back($1);
						$$->children.push_back($2);
						// $$->children.push_back($3);
						for(int i=0; i<patch.size(); i++){
							patch[i]->eletype = $1->data_type;
						}
						patch.clear();
					};
t				:	INT
					{
						$$ = new Node("t",$1->value);
						$$->children.push_back($1);
						$$->data_type = _integer;
					} 
					|
					FLOAT 
					{
						$$ = new Node("t",$1->value);
						$$->children.push_back($1);
						$$->data_type = _real;
					};
l				:	id_arr
					{
						$$ = new Node("l","");
						// $$->children.push_back($1);
					}
					|
					id_arr COMMA l
					{
						$$ = new Node("l","");
						$$->children.push_back($1);
						$$->children.push_back($2);
						$$->children.push_back($3);
					};
id_arr			: 	IDENTIFIER
					{
						$$ = new Node("id_arr",$1->value);
						$$->children.push_back($1);
						if(active_func_ptr==NULL){
							if(symtab.search_var($1->value)){
								yyerror("Variable \033[1;31m" + $1->value + "\033[0m already declared.");
								error_count++;
							}
							else{
								Variable * t = symtab.enter_var($1->value,_simple,_none);
								patch.push_back(t);
							}
						}						
					} 
					|
					IDENTIFIER LS dimlist RS
					{
						$$ = new Node("id_arr",$1->value);
						$$->children.push_back($1);
						$$->children.push_back($2);
						$$->children.push_back($3);
						$$->children.push_back($4);
						if(active_func_ptr==NULL){
							if(symtab.search_var($1->value)){
								yyerror("Variable \033[1;31m" + $1->value + "\033[0m already declared.");
								error_count++;
							}
							else{
								Variable * t = symtab.enter_var($1->value,_array,_none);
								t->dimlist = dimlist;
								dimlist.clear();
								patch.push_back(t);
							}
						}
					};
dimlist			:	INTEGERS
					{ 
						$$ = new Node("dimlist","");
						$$->children.push_back($1);
						dimlist.insert(dimlist.begin(),($1->value));
					} 
					| 
					INTEGERS COMMA dimlist
					{
						$$ = new Node("dimlist",""); 
						$$->children.push_back($1);
						$$->children.push_back($2);
						$$->children.push_back($3);
						dimlist.insert(dimlist.begin(),($1->value));
					};
//variable or an array element assigned an expression
//						
assignment		:	id_arr_asg EQUAL sim_exp
					{
						$$ = new Node("expression","=");
						$$->children.push_back($1);
						$$->children.push_back($2);
						$$->children.push_back($3);
						if($1->data_type==_error || $3->data_type==_error){
								$$->data_type = _error;
						}
						else if(active_func_ptr==NULL){
							if(symtab.search_var($1->value)){
								Variable * ptr = symtab.search_var($1->value);
								$$->data_type = ptr->eletype;
								if(get_type(ptr->eletype, $3->data_type)==_error){
									yyerror("Mismatching datatypes of LHS and RHS: " + _type[$1->data_type] + " and " + _type[$3->data_type]);
									$$->data_type = _error;
								}
							}
						}
					}					

// expression:			rel_exp
// 					{
// 						$$ = new Node("expression","");
// 						$$->data_type = $1->data_type;
// 						$$->children.push_back($1);						
// 					}
// 					|
// 					log_exp
// 					{ 
// 						$$ = new Node("expression","");
// 						$$->data_type = _boolean;
// 						$$->children.push_back($1);
// 					}
// 					;

id_arr_asg			: 	IDENTIFIER
					{
						$$ = new Node("id_arr",$1->value);
						$$->children.push_back($1);
						if(active_func_ptr==NULL){
							Variable * ptr = symtab.search_var($1->value);
							if(ptr==NULL){
								yyerror("Variable \033[1;31m" + $1->value + "\033[0m not declared.");
								error_count++;
							}
							else{
								$$->data_type = ptr->eletype;
							}
						}						
					} 
					|
					IDENTIFIER LS dimlist RS
					{
						$$ = new Node("id_arr",$1->value);
						$$->children.push_back($1);
						$$->children.push_back($2);
						$$->children.push_back($3);
						$$->children.push_back($4);
						if(active_func_ptr==NULL){
							Variable * ptr = symtab.search_var($1->value);
							if(ptr==NULL){
								yyerror("Variable \033[1;31m" + $1->value + "\033[0m not declared.");
								error_count++;
								$$->data_type = _error;
							}
							else{
								$$->data_type = ptr->eletype;
								if(ptr->dimlist.size()!=dimlist.size()){
									yyerror("Variable \033[1;31m" + $1->value + "\033[0m unmatching dimensions.");
									error_count++;
									$$->data_type = _error;
								}
								dimlist.clear();
							}
						}	
					};

log_exp 		:	log_exp OR and_exp
					{$$ = new Node("log_exp","or");$$->children.push_back($1);$$->children.push_back($2);$$->children.push_back($3);}
					| 
					and_exp
					{$$ = new Node("log_exp","");$$->children.push_back($1);};

and_exp 		:	and_exp AND rel_exp
					{
						$$ = new Node("and_exp","and");$$->children.push_back($1);$$->children.push_back($2);$$->children.push_back($3);
					}
					|
					rel_exp
					{
						$$ = new Node("and_exp","");$$->children.push_back($1);
					};

rel_exp 		:	rel_exp op3 sim_exp
					{
						$$ = new Node("rel_exp","op");$$->children.push_back($1);$$->children.push_back($2);$$->children.push_back($3);
						
					}
					|
					sim_exp
					{
						$$ = new Node("rel_exp","");$$->children.push_back($1);
						$$
					};

sim_exp 		:	sim_exp op1 dm_exp
					{
						$$ = new Node("sim_exp",$1->value + $2->value + $3->value);$$->children.push_back($1);$$->children.push_back($2);$$->children.push_back($3);
						Type tt = get_type($1->data_type, $3->data_type);
						if(tt == _integer || tt == _real) $$->data_type = tt;
						else $$->data_type = _error; 

					}
					|
					dm_exp
					{
						$$ = new Node("sim_exp",$1->value);$$->children.push_back($1);
						if($1->data_type == _integer || $1->data_type == _real) $$->data_type = $1->data_type;
						else $$->data_type = _error; 

					};

dm_exp 			: 	dm_exp op2 un_exp
					{
						$$ = new Node("dm_exp",$1->value + $2->value + $3->value);$$->children.push_back($1);$$->children.push_back($2);$$->children.push_back($3);
						Type tt = get_type($1->data_type, $3->data_type);
						if(tt == _integer || tt == _real) $$->data_type = tt;
						else $$->data_type = _error; 

					}
					|
				 	un_exp
					{
						$$ = new Node("dm_exp",$1->value);$$->children.push_back($1);
						if($1->data_type == _integer || $1->data_type == _real) $$->data_type = $1->data_type;
						else $$->data_type = _error; 

					};

un_exp 			: 	unop term
					{
						$$ = new Node("un_exp",$1->value + $2->value);$$->children.push_back($1);$$->children.push_back($2);
						if($1->data_type == _integer || $1->data_type == _real) $$->data_type = $1->data_type;
						else $$->data_type = _error; 

					}
					|
					term
					{
						$$ = new Node("un_exp",$1->value);$$->children.push_back($1);
						if($1->data_type == _integer || $1->data_type == _real) $$->data_type = $1->data_type;
						else $$->data_type = _error; 
					};

op1 			: 	ADD
					{
						$$ = new Node("op1", "+");$$->children.push_back($1);
					}
					| 
					SUB
					{
						$$ = new Node("op1", "-");$$->children.push_back($1);
					};

op2 			: 	MUL
						{$$ = new Node("op2", "*");$$->children.push_back($1);}
					|
					DIV
					{
						$$ = new Node("op2", "/");$$->children.push_back($1);
					}
					|
					MOD
					{
						$$ = new Node("op2", "%");$$->children.push_back($1);
					};

op3 			: 	GT
					{
						$$ = new Node("op3", ">");$$->children.push_back($1);
					}
					|
					LT
					{
						$$ = new Node("op3", "<");$$->children.push_back($1);
					}
					|
					GE
					{
						$$ = new Node("op3", ">=");$$->children.push_back($1);
					}
					|
					LE
					{
						$$ = new Node("op3", "<=");$$->children.push_back($1);
					}
					|
					EQ
					{
						$$ = new Node("op3", "==");$$->children.push_back($1);
					}
					|
					NE
					{
						$$ = new Node("op3", "!=");$$->children.push_back($1);
					};

unop 			:	SUB
					{
						$$ = new Node("unop", "-");$$->children.push_back($1);
					}
					|
					ADD
					{
						$$ = new Node("unop", "+");$$->children.push_back($1);
					};

term 			:	LP log_exp RP
					{
						$$ = new Node("term","");$$->children.push_back($1);$$->children.push_back($2);$$->children.push_back($3);
						$$->data_type = $2->data_type;
					}
					|
					INTEGERS
					{	
						$$ = new Node("term",$1->value);$$->children.push_back($1);
						$$->data_type = _integer;
					}
					|
					id_arr_asg
					{
						$$ = new Node("term",$1->value);$$->children.push_back($1);
						if(active_func_ptr==NULL){
							if(symtab.search_var($1->value)){
								Variable * ptr = symtab.search_var($1->value);
								$$->data_type = ptr->eletype;
							}
							else{
								$$->data_type = _error;
							}
						}

					};
%%

bool syntax_success = true;

void yyerror(string s){
	cerr<<"Line Number \033[1;31m" << yylineno <<"\033[0m : "<<s<<endl;
	syntax_success = false;
}


int yywrap(){}

int main(){
	yyparse();
	// cout<<"Total Errors: "<<error_count<<endl;
	if(syntax_success) symtab.print();
	return 0;
}
