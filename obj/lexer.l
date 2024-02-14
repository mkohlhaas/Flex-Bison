/* float exponent */
EXP	([Ee][-+]?[0-9]+)

%s VERTEX
%x FACE
%x COMMENT

%{
#include <stdbool.h>
#include <glib.h>
bool newVertex = false;
bool newFace   = false;
%}

%%

v                               { printf("vertex: \n"); newVertex =true; BEGIN VERTEX; }
f                               { printf("face: \n");   newFace   =true; BEGIN FACE; }
 /* floating point numbers */
<VERTEX>{
[0-9]+"."[0-9]*{EXP}? |
"."?[0-9]+{EXP}?                { /* create new vertex list */ newVertex = false; printf("%s ", yytext); }
.
}

<FACE>{
[1-9]+[0-9]*                    { /* create new face list */   newFace   = false; printf("%s ", yytext); }
.
}

\n                              ECHO;
.

%%
