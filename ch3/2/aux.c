/* helper functions */

#include "aux.h"
#include <math.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int yyparse();

/* symbol table */
symbol symtab[NHASH];

/* hash a symbol */
static unsigned hashSym(char *sym) {
  unsigned int hash = 0;
  unsigned c;

  while ((c = *sym++)) {
    hash = hash * 9 ^ c;
  }

  return hash;
}

void *allocAst(size_t size) {
  void *ast = malloc(size);
  if (!ast) {
    yyerror("out of memory");
    exit(EXIT_FAILURE);
  }
  return ast;
}

/* lookup symbolName in symtab */
/* insert symbolName if not found */
symbol *lookup(char *symbolName) {
  symbol *symbol = &symtab[hashSym(symbolName) % NHASH];
  int scount = NHASH; /* how many have we looked at */

  while (--scount >= 0) {
    if (symbol->name && !strcmp(symbol->name, symbolName)) {
      return symbol; // we found the symbol
    }

    // insert new entry
    if (!symbol->name) {                 /* empty slot in symbol table ? */
      symbol->name = strdup(symbolName); // Make a copy of bison provided string!
      symbol->value = 0;
      symbol->func = NULL;
      symbol->syms = NULL;
      return symbol;
    }

    if (++symbol >= symtab + NHASH) {
      symbol = symtab; /* try the next entry */
    }
  }
  yyerror("symbol table overflow\n");
  exit(EXIT_FAILURE); /* tried them all, table is full */
}

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

ast *newast(int nodetype, ast *l, ast *r) {
  ast *a = allocAst(sizeof(ast));
  a->nodetype = nodetype;
  a->l = l;
  a->r = r;
  return a;
}

ast *newnum(double d) {
  numval *a = allocAst(sizeof(numval));
  a->nodetype = 'K';
  a->number = d;
  return (ast *)a;
}

ast *newcmp(int cmptype, ast *l, ast *r) {
  ast *a = allocAst(sizeof(ast));
  a->nodetype = '0' + cmptype;
  a->l = l;
  a->r = r;
  return a;
}

ast *newfunc(int func, ast *l) {
  fncall *a = allocAst(sizeof(fncall));
  a->nodetype = 'F';
  a->l = l;
  a->func = func;
  return (ast *)a;
}

ast *newcall(symbol *s, ast *l) {
  ufncall *a = allocAst(sizeof(ufncall));
  a->nodetype = 'C';
  a->l = l;
  a->s = s;
  return (ast *)a;
}

ast *newref(symbol *s) {
  symref *a = allocAst(sizeof(symref));
  a->nodetype = 'N';
  a->s = s;
  return (ast *)a;
}

ast *newasgn(symbol *s, ast *v) {
  symasgn *a = allocAst(sizeof(symasgn));
  a->nodetype = '=';
  a->s = s;
  a->v = v;
  return (ast *)a;
}

ast *newflow(int nodetype, ast *cond, ast *tl, ast *el) {
  flow *a = allocAst(sizeof(flow));
  a->nodetype = nodetype;
  a->cond = cond;
  a->tl = tl;
  a->el = el;
  return (ast *)a;
}

symlist *newsymlist(symbol *sym, symlist *next) {
  symlist *sl = allocAst(sizeof(symlist));
  sl->sym = sym;
  sl->next = next;
  return sl;
}

void symlistfree(symlist *sl) {
  while (sl) {
    symlist *nsl = sl->next;
    free(sl);
    sl = nsl;
  }
}

/* define a function */
/* A symbol pointer (symbol *) is always a pointer into the symbol table! */
/* Comes from the NAME token which call lookup(). */
void defFn(symbol *symbol, symlist *syms, ast *func) {
  if (symbol->syms) {
    // delete old symbol list
    symlistfree(symbol->syms);
  }
  if (symbol->func) {
    // delete old function
    treefree(symbol->func);
  }
  // insert new function and symbol list
  symbol->syms = syms;
  symbol->func = func;
}

double eval(ast *a) {
  if (!a) {
    yyerror("internal error, null eval");
    return 0.0;
  }

  flow *flowAst;
  double v;
  switch (a->nodetype) {
  case 'K': /* constant */
    v = ((numval *)a)->number;
    break;
  case 'N': /* name reference */
    v = ((symref *)a)->s->value;
    break;
  case '=': /* assignment */
    v = ((symasgn *)a)->s->value = eval(((symasgn *)a)->v);
    break;
  case '+': /* expressions */
    v = eval(a->l) + eval(a->r);
    break;
  case '-':
    v = eval(a->l) - eval(a->r);
    break;
  case '*':
    v = eval(a->l) * eval(a->r);
    break;
  case '/':
    v = eval(a->l) / eval(a->r);
    break;
  case '|':
    v = fabs(eval(a->l));
    break;
  case 'M':
    v = -eval(a->l);
    break;
  case '1': /* comparisons */
    v = (eval(a->l) > eval(a->r)) ? 1 : 0;
    break;
  case '2':
    v = (eval(a->l) < eval(a->r)) ? 1 : 0;
    break;
  case '3':
    v = (eval(a->l) != eval(a->r)) ? 1 : 0;
    break;
  case '4':
    v = (eval(a->l) == eval(a->r)) ? 1 : 0;
    break;
  case '5':
    v = (eval(a->l) >= eval(a->r)) ? 1 : 0;
    break;
  case '6':
    v = (eval(a->l) <= eval(a->r)) ? 1 : 0;
    break;
  case 'I': /* null if/else/do expressions allowed in the grammar, so check for them */
    flowAst = (flow *)a;
    if (!eval(flowAst->cond)) {
      if (flowAst->tl) {
        v = eval(flowAst->tl);
      } else {
        v = 0.0; /* a default value */
      }
    } else {
      if (flowAst->el) {
        v = eval(flowAst->el);
      } else {
        v = 0.0; /* a default value */
      }
    }
    break;
  case 'W':
    flowAst = (flow *)a;
    v = 0.0; /* a default value */
    if (flowAst->tl) {
      while (eval(flowAst->cond)) {
        v = eval(flowAst->tl);
      }
    }
    break; /* last value is value */
  case 'L':
    eval(a->l);
    v = eval(a->r);
    break;
  case 'F':
    v = callbuiltin((fncall *)a);
    break;
  case 'C':
    v = calluser((ufncall *)a);
    break;
  default:
    printf("internal error: bad node %c\n", a->nodetype);
  }
  return v;
}

double callbuiltin(fncall *f) {
  bifs functype = f->func;
  double v = eval(f->l);

  switch (functype) {
  case B_sqrt:
    return sqrt(v);
  case B_exp:
    return exp(v);
  case B_log:
    return log(v);
  case B_print:
    printf("= %.4g\n", v);
    return v;
  default:
    yyerror("Unknown built-in function %d. Yielding default value (0.0)!", functype);
    return 0.0;
  }
}

double calluser(ufncall *f) {
  double v;

  symbol *fn = f->s; /* function name */
  if (!fn->func) {
    yyerror("call to undefined function", fn->name);
    return 0.0;
  }

  /* count the arguments */
  int nargs;
  symlist *sl = fn->syms;
  for (nargs = 0; sl; sl = sl->next) {
    nargs++;
  }

  /* prepare to save them */
  double *oldval = (double *)malloc(nargs * sizeof(double));
  double *newval = (double *)malloc(nargs * sizeof(double));
  if (!oldval || !newval) {
    yyerror("out of memory in %s", fn->name);
    return 0.0;
  }

  ast *args = f->l;                 /* actual arguments */
  for (int i = 0; i < nargs; i++) { /* evaluate the arguments */
    if (!args) {
      yyerror("too few args in call to %s", fn->name);
      free(oldval);
      free(newval);
      return 0.0;
    }

    if (args->nodetype == 'L') { /* if this is a list node */
      newval[i] = eval(args->l);
      args = args->r;
    } else { /* if it's the end of the list */
      newval[i] = eval(args);
      args = NULL;
    }
  }

  sl = fn->syms; /* save old values of dummies, assign new ones */
  for (int i = 0; i < nargs; i++) {
    symbol *s = sl->sym;

    oldval[i] = s->value;
    s->value = newval[i];
    sl = sl->next;
  }
  free(newval);

  v = eval(fn->func); /* evaluate the function */

  sl = fn->syms; /* put the dummies back */
  for (int i = 0; i < nargs; i++) {
    symbol *s = sl->sym;

    s->value = oldval[i];
    sl = sl->next;
  }

  free(oldval);
  return v;
}

void treefree(ast *a) {
  switch (a->nodetype) {
  case '+': /* two subtrees */
  case '-':
  case '*':
  case '/':
  case '1':
  case '2':
  case '3':
  case '4':
  case '5':
  case '6':
  case 'L':
    treefree(a->r);
  case '|': /* one subtree */
  case 'M':
  case 'C':
  case 'F':
    treefree(a->l);
  case 'K': /* no subtree */
  case 'N':
    break;
  case '=':
    free(((symasgn *)a)->v);
    break;
  case 'I':
  case 'W':
    free(((flow *)a)->cond);
    if (((flow *)a)->tl)
      free(((flow *)a)->tl);
    if (((flow *)a)->el)
      free(((flow *)a)->el);
    break;
  default:
    printf("internal error: free bad node %c\n", a->nodetype);
  }
  free(a); /* always free the node itself */
}

void yyerror(char *s, ...) {
  va_list ap;
  va_start(ap, s);

  fprintf(stderr, "%d: error: ", yylineno);
  vfprintf(stderr, s, ap);
  fprintf(stderr, "\n");
}

int main(void) {
  printf("» ");
  return yyparse();
}

// debug flag
int debug = 0;

/* debugging: dump out an AST */
void dumpast(ast *a, int level) {
  printf("%*s", 2 * level, ""); /* indent to this level */
  level++;

  if (!a) {
    printf("NULL\n");
    return;
  }

  switch (a->nodetype) {
  case 'K': /* constant */
    printf("number %4.4g\n", ((numval *)a)->number);
    break;
  case 'N': /* name reference */
    printf("ref %s\n", ((symref *)a)->s->name);
    break;
  case '=': /* assignment */
    printf("= %s\n", ((symref *)a)->s->name);
    dumpast(((symasgn *)a)->v, level);
    return;
  case '+': /* expressions */
  case '-':
  case '*':
  case '/':
  case 'L':
  case '1':
  case '2':
  case '3':
  case '4':
  case '5':
  case '6':
    printf("binop %c\n", a->nodetype);
    dumpast(a->l, level);
    dumpast(a->r, level);
    return;
  case '|':
  case 'M':
    printf("unop %c\n", a->nodetype);
    dumpast(a->l, level);
    return;
  case 'I':
  case 'W':
    printf("flow %c\n", a->nodetype);
    dumpast(((flow *)a)->cond, level);
    if (((flow *)a)->tl)
      dumpast(((flow *)a)->tl, level);
    if (((flow *)a)->el)
      dumpast(((flow *)a)->el, level);
    return;
  case 'F':
    printf("builtin %d\n", ((fncall *)a)->func);
    dumpast(a->l, level);
    return;
  case 'C':
    printf("call %s\n", ((ufncall *)a)->s->name);
    dumpast(a->l, level);
    return;
  default:
    printf("bad %c\n", a->nodetype);
    return;
  }
}
