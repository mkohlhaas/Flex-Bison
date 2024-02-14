%{
#include <glib.h>
GPtrArray  *a;
GHashTable *h;
gboolean cmp0 (gconstpointer a, gconstpointer b);
gint     cmp1 (gconstpointer a, gconstpointer b);

typedef struct {
  char* word;
  int count;
} wf;

%}

%%

[a-zA-Z]+ {
             GString *word = g_string_new(yytext);
             g_string_ascii_down(word);
             if (word->len > 3) {
               int count = GPOINTER_TO_INT(g_hash_table_lookup(h, word->str));
               count++;
               g_hash_table_insert(h, word->str, GINT_TO_POINTER(count));
             }
          }
.
\n

%%

void printWordFreq(gpointer elem) {
  wf* wordFreq = (wf*)elem;
  printf("%s: %d\n", wordFreq->word, wordFreq->count);
}

void printHashtable(gpointer key, gpointer value, gpointer user_data) {
  printf("%s: %d\n", key, GPOINTER_TO_INT(value));
}

gboolean cmp0 (gconstpointer a, gconstpointer b){
  GString *x = (GString*) a;
  GString *y = (GString*) b;
  return g_strcmp0(x->str, y->str) ? FALSE : TRUE;
}

gint cmp1 (gconstpointer a, gconstpointer b){
  wf *x = *(wf**) a;
  wf *y = *(wf**) b;
  return y->count - x->count;
}

void insertArrayElement(gpointer key, gpointer value, gpointer user_data) {
  wf* wf = malloc(sizeof(wf));
  wf->word = key;
  wf->count = GPOINTER_TO_INT(value);
  g_ptr_array_add(a, wf);
}

int main(void) {
  h = g_hash_table_new(g_str_hash, g_str_equal);
  yylex();
  a = g_ptr_array_new();
  // g_hash_table_foreach (h, printHashtable, NULL);
  g_hash_table_foreach (h, insertArrayElement, NULL);
  g_ptr_array_sort(a, (GCompareFunc)cmp1);
  g_ptr_array_foreach(a, (GFunc)printWordFreq, NULL);
}
