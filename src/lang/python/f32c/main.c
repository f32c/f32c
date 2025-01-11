#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "mpconfig.h"
#include "nlr.h"
#include "misc.h"
#include "qstr.h"
#include "lexer.h"
#include "parse.h"
#include "obj.h"
#include "parsehelper.h"
#include "compile.h"
#include "runtime0.h"
#include "runtime.h"
#include "repl.h"

void do_str(const char *src) {
    mp_lexer_t *lex = mp_lexer_new_from_str_len(MP_QSTR__lt_stdin_gt_, src, strlen(src), 0);
    if (lex == NULL) {
        return;
    }

    mp_parse_error_kind_t parse_error_kind;
    mp_parse_node_t pn = mp_parse(lex, MP_PARSE_SINGLE_INPUT, &parse_error_kind);
	
    if (pn == MP_PARSE_NODE_NULL) {
        // parse error
        mp_parse_show_exception(lex, parse_error_kind);
        mp_lexer_free(lex);
        return;
    }

    // parse okay
    qstr source_name = mp_lexer_source_name(lex);
    mp_lexer_free(lex);
    mp_obj_t module_fun = mp_compile(pn, source_name, MP_EMIT_OPT_NONE, true);

    if (mp_obj_is_exception_instance(module_fun)) {
        // compile error
        mp_obj_print_exception(module_fun);
        return;
    }

    nlr_buf_t nlr;
    if (nlr_push(&nlr) == 0) {
        mp_call_function_0(module_fun);
        nlr_pop();
    } else {
        // uncaught exception
        mp_obj_print_exception((mp_obj_t)nlr.ret_val);
    }
}

char *linebuf;
int trapped;

int edit(int promptlen, int fi, int maxlin);


int main(int argc, char **argv) {
    char line[1024];
    int pos;

    mp_init();

    for (;;) {
	trapped = 0;
	linebuf = line;
	sprintf(line, ">>> ");
	edit(4, 4, 256);
	strcpy(linebuf, &linebuf[4]);
	if (trapped)
		continue;
	pos = strlen(line);
        while (mp_repl_continue_with_input(line)) {
	    linebuf = &line[pos];
	    sprintf(linebuf, "... ");
	    edit(4, 4, 256);
	    strcpy(linebuf, &linebuf[4]);
	    if (trapped || line[pos] == 0)
		break;
	    pos = strlen(line);
	    if (*linebuf == ' ')
		line[pos++] = ';';
        }
	if (trapped)
		continue;
    	do_str(line);
    }
}

void gc_collect(void) {
	printf("\r\n%s %d\n", __FUNCTION__, __LINE__);
}

mp_lexer_t *mp_lexer_new_from_file(const char *filename) {
	printf("\r\n%s %d\n", __FUNCTION__, __LINE__);
    return NULL;
}

mp_import_stat_t mp_import_stat(const char *path) {
	printf("\r\n%s %d\n", __FUNCTION__, __LINE__);
    return MP_IMPORT_STAT_NO_EXIST;
}

void nlr_jump_fail(void *val) {
	printf("\r\n%s %d\n", __FUNCTION__, __LINE__);
}

char *strcat(char *dest, const char *src) {
	printf("\r\n%s %d\n", __FUNCTION__, __LINE__);
	return dest;
}

#include <stdarg.h>

extern int _xvprintf(char const *, void(*)(int, void *), void *, va_list);

static void
pchar(int c, void *arg __unused)
{

        putchar(c);
}

int vprintf(const char *format, va_list ap)
{
        int retval;
        
        retval = _xvprintf(format, pchar, NULL, ap);
        return (retval);
}
