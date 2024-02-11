/* Recognize tokens for the calculator. */

%option noyywrap nodefault yylineno

%{
# include "aux.h"
# include "parser.h"
%}

/* float exponent */
EXP	([Ee][-+]?[0-9]+)

%%

 /* operators, grouping */
"+" |
"-" |
"*" |
"/" |
"|" |
"(" |
")"                       { return yytext[0]; }

 /* (floating point) numbers */
[0-9]+"."[0-9]*{EXP}? |
"."?[0-9]+{EXP}?          { yylval.d = atof(yytext); return NUMBER; }
\n                        { return EOL; }
"//".*                    /* ignore comments */
[ \t]                     /* ignore white space */
.	                        { yyerror("Mystery character %c\n", *yytext); }

%%
