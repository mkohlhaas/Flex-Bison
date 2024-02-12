%{
#  include "aux.h"
#  include <stdio.h>
#  include <stdlib.h>
int yylex();
%}

%union {
  ast *a;
  double d;
  symbol *s;
  symlist *sl;
  int fn;
}

/* declare types/tokens */
%type  <a>  exp stmt list explist
%token <d>  NUMBER
%token <s>  NAME /* Whenever you see NAME it meams it will return a pointer into the symbol table (→ symbol *). The lexer calls lookup(). */
%type  <sl> symlist
%token <fn> FUNC
%token      EOL

%token IF THEN ELSE WHILE DO LET

/* associativity and precedence */
%nonassoc <fn> CMP
%right '='
%left  '+' '-'
%left  '*' '/'
%nonassoc '|' UMINUS

%start calclist

%%

stmt: IF exp THEN list                              { $$ = newflow('I', $2, $4, NULL); }
    | IF exp THEN list ELSE list                    { $$ = newflow('I', $2, $4, $6); }
    | WHILE exp DO list                             { $$ = newflow('W', $2, $4, NULL); }
    | exp
    ;

list: /* nothing - empty list */                    { $$ = NULL; }
    | stmt ';' list                                 {
                                                      if ($3 == NULL) {
	                                                      $$ = $1;
                                                      } else {
			                                                  $$ = newast('L', $1, $3);
                                                      }
                                                    }
    ;

exp: exp CMP exp                                    { $$ = newcmp($2, $1, $3); }
   | exp '+' exp                                    { $$ = newast('+', $1,$3); }
   | exp '-' exp                                    { $$ = newast('-', $1,$3);}
   | exp '*' exp                                    { $$ = newast('*', $1,$3); }
   | exp '/' exp                                    { $$ = newast('/', $1,$3); }
   | '|' exp                                        { $$ = newast('|', $2, NULL); }
   | '(' exp ')'                                    { $$ = $2; }
   | '-' exp %prec UMINUS                           { $$ = newast('M', $2, NULL); }
   | NUMBER                                         { $$ = newnum($1); }
   | FUNC '(' explist ')'                           { $$ = newfunc($1, $3); }
   | NAME                                           { $$ = newref($1); }
   | NAME '=' exp                                   { $$ = newasgn($1, $3); }
   | NAME '(' explist ')'                           { $$ = newcall($1, $3); }
   ;

explist: exp
       | exp ',' explist                            { $$ = newast('L', $1, $3); }
       ;

/* symbol list for function arguments; they shouldn't actually use the symbol table → bug */
/* suggestion: use PARAMNAME as token and separate lexer rule for it without using the global symbol table */
symlist: NAME                                       { $$ = newsymlist($1, NULL); }
       | NAME ',' symlist                           { $$ = newsymlist($1, $3); }
       ;

calclist: /* nothing - empty list */
  | calclist stmt EOL                               {
                                                      if(debug) dumpast($2, 0);
                                                      printf("⇒ %.4g\n» ", eval($2));
                                                      treefree($2);
                                                    }
  | calclist LET NAME '(' symlist ')' '=' list EOL  {
                                                      defFn($3, $5, $8);
                                                      printf("defined %s\n= ", $3->name);
                                                    }

  | calclist error EOL                              { yyerrok; printf("» "); }
  ;

%%
