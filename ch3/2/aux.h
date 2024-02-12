/* Declarations for a calculator */

/* Abstract Syntax Tree */
typedef struct ast {
  int nodetype;
  struct ast *l;
  struct ast *r;
} ast;

/* symbol (variable names for values and functions) */
typedef struct symbol { /* a variable name */
  char *name;
  double value;         /* if symbol is a value */
  ast *func;            /* if symbol is a function */
  struct symlist *syms; /* function args */
} symbol;

/* list of symbols, for an argument list */
typedef struct symlist {
  symbol *sym;
  struct symlist *next;
} symlist;

/* built-in functions */
typedef enum {
  B_sqrt = 1,
  B_exp,
  B_log,
  B_print,
} bifs;

/* nodes in the Abstract Syntax Tree */
/* all have common initial nodetype */
typedef struct fncall { /* built-in function */
  int nodetype;         /* F */
  ast *l;
  bifs func;
} fncall;

typedef struct ufncall { /* user function */
  int nodetype;          /* C */
  ast *l;                /* list of arguments */
  symbol *s;
} ufncall;

typedef struct flow {
  int nodetype; /* I or W */
  ast *cond;    /* condition */
  ast *tl;      /* then or do list */
  ast *el;      /* optional else list */
} flow;

typedef struct numval {
  int nodetype; /* K */
  double number;
} numval;

typedef struct symref {
  int nodetype; /* N */
  symbol *s;
} symref;

typedef struct symasgn {
  int nodetype; /* = */
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

/* simple symtab of fixed size */
#define NHASH 9997
extern symbol symtab[NHASH];

symbol *lookup(char *symbolName);
symlist *newsymlist(symbol *sym, symlist *next);
void symlistfree(symlist *sl);

/* define a function */
void defFn(symbol *name, symlist *syms, ast *stmts);

double callbuiltin(fncall *);
double calluser(ufncall *);

/* evaluate an AST */
double eval(ast *);

/* delete and free an AST */
void treefree(ast *);

/* interface to the lexer */
extern int yylineno; /* from lexer */
void yyerror(char *s, ...);

extern int debug;
void dumpast(ast *a, int level);
