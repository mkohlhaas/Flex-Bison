%option nodefault

INDEX   ([1-9]+[0-9]*)
INTEGER (0|{INDEX})
EXP	    ([Ee][-+]?[0-9]+)
FLOAT   (([-+]?[0-9]+"."[0-9]*{EXP}?)|({INTEGER}))

%x VERTEX
%x FACE

%{
#include <stdbool.h>
#include <glib.h>

typedef struct {
  float x;
  float y;
  float z;
} vertex;

typedef struct {
  // list of indices
  GList *loi;
} face;

GArray *vertices;
GArray *indices;

%}

%%

<INITIAL>^v" "+                     { BEGIN(VERTEX); }
<INITIAL>^f" "+                     { BEGIN(FACE); }
<INITIAL>.
<INITIAL>\n                         { yylineno++; }

<VERTEX>{FLOAT}(" "+{FLOAT}" "*){2} { printf("%s\n", yytext); BEGIN(INITIAL); }
<VERTEX>.                           { printf("<VERTEX>Error in line %d: %s\n", yylineno, yytext); exit(EXIT_FAILURE); }

<FACE>(({INDEX}"/"*){1,3}" "*)+     { printf("%s\n", yytext);   BEGIN(INITIAL); }
<FACE>.                             { printf("<FACE>Error in line %d: %s\n", yylineno, yytext); exit(EXIT_FAILURE); }

%%

void addVertex() {}

void addIndex() {}

int main(void) {
  vertices = g_array_new(FALSE, FALSE, sizeof(vertex));
  indices  = g_array_new(FALSE, FALSE, sizeof(face));;
  yylex();
}

