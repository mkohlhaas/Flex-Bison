/* Declarations for a calculator */

/* symbol table */
typedef struct symbol { /* a variable name */
  char *name;
  double value;
  struct ast *func;     /* stmt for the function */
  struct symlist *syms; /* list of dummy args */
} symbol;

/* simple symtab of fixed size */
#define NHASH 9997
extern symbol symtab[NHASH];

symbol *lookup(char *);

/* list of symbols, for an argument list */
typedef struct symlist {
  symbol *sym;
  struct symlist *next;
} symlist;

struct symlist *newsymlist(symbol *sym, struct symlist *next);
void symlistfree(struct symlist *sl);

/* node types
 *  + - * / |
 *  0-7 comparison ops, bit coded 04 equal, 02 less, 01 greater
 *  M unary minus
 *  L statement list
 *  I IF statement
 *  W WHILE statement
 *  N symbol ref
 *  = assignment
 *  S list of symbols
 *  F built in function call
 *  C user function call
 */

/* built-in functions */
enum bifs {
  B_sqrt = 1,
  B_exp,
  B_log,
  B_print,
};

/* nodes in the Abstract Syntax Tree */
/* all have common initial nodetype */

typedef struct ast {
  int nodetype;
  struct ast *l;
  struct ast *r;
} ast;

typedef struct fncall { /* built-in function */
  int nodetype;         /* type F */
  ast *l;
  enum bifs functype;
} fncall;

typedef struct ufncall { /* user function */
  int nodetype;          /* type C */
  ast *l;                /* list of arguments */
  symbol *s;
} ufncall;

typedef struct flow {
  int nodetype; /* type I or W */
  ast *cond;    /* condition */
  ast *tl;      /* then or do list */
  ast *el;      /* optional else list */
} flow;

typedef struct numval {
  int nodetype; /* type K */
  double number;
} numval;

typedef struct symref {
  int nodetype; /* type N */
  symbol *s;
} symref;

typedef struct symasgn {
  int nodetype; /* type = */
  symbol *s;
  ast *v; /* value */
} symasgn;

/* build an AST */
ast *newast(int nodetype, ast *l, ast *r);
ast *newcmp(int cmptype, ast *l, ast *r);
ast *newfunc(int functype, ast *l);
ast *newcall(symbol *s, ast *l);
ast *newref(symbol *s);
ast *newasgn(symbol *s, ast *v);
ast *newnum(double d);
ast *newflow(int nodetype, ast *cond, ast *tl, ast *tr);

/* define a function */
void dodef(symbol *name, struct symlist *syms, ast *stmts);

/* evaluate an AST */
double eval(ast *);

/* delete and free an AST */
void treefree(ast *);

/* interface to the lexer */
extern int yylineno; /* from lexer */
void yyerror(char *s, ...);

extern int debug;
void dumpast(ast *a, int level);
