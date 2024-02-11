/* Declarations for a calculator */

/* interface to the lexer */
extern int yylineno; /* from lexer */
extern int yylex(void);
void yyerror(char *s, ...);

/* nodes in the AST */
typedef struct ast {
  int nodetype;
  struct ast *l;
  struct ast *r;
} ast;

typedef struct {
  int nodetype;
  double number;
} numval;

/* build an AST */
ast *newast(int nodetype, ast *l, ast *r);
ast *newnum(double d);

/* evaluate an AST */
double eval(ast *);

/* delete and free an AST */
void treefree(ast *);
