/* parser.lex

   Routines for compiling Flash2 AVM2 ABC Actionscript

   Extension module for the rfxswf library.
   Part of the swftools package.

   Copyright (c) 2008 Matthias Kramm <kramm@quiss.org>
 
   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA */
%{
#include <stdlib.h>
#include <stdio.h>
#include <memory.h>
#include "abc.h"
#include "pool.h"
#include "files.h"
#include "common.h"
#include "tokenizer.h"
#include "registry.h"
#include "code.h"
#include "opcodes.h"
#include "compiler.h"
#include "expr.h"
#include "initcode.h"

extern int a3_lex();

%}

//%glr-parser
//%expect-rr 1
%error-verbose

%union tokenunion {
    enum yytokentype token;

    classinfo_t*classinfo;
    classinfo_list_t*classinfo_list;
    slotinfo_t*slotinfo;
    slotinfo_list_t*slotinfo_list;

    int number_int;
    unsigned int number_uint;
    double number_float;
    code_t*code;
    typedcode_t value;
    //typedcode_list_t*value_list;
    codeandnumber_t value_list;
    param_t* param;
    params_t params;
    string_t str;
    char*id;
    constant_t*constant;
    for_start_t for_start;
    abc_exception_t *exception;
    regexp_t regexp;
    modifiers_t flags;
    namespace_decl_t* namespace_decl;
    node_t*node;
    struct {
        abc_exception_list_t *l;
        code_t*finally;
    } catch_list;
}


%token<id> T_IDENTIFIER T_NAMESPACE
%token<str> T_STRING
%token<regexp> T_REGEXP
%token<token> T_EMPTY
%token<number_int> T_INT
%token<number_uint> T_UINT
%token<number_float> T_FLOAT

%token<id> T_FOR "for"
%token<id> T_WHILE "while"
%token<id> T_DO "do"
%token<id> T_SWITCH "switch"

%token<token> KW_IMPLEMENTS "implements"
%token<token> KW_NAMESPACE "namespace"
%token<token> KW_PACKAGE "package"
%token<token> KW_PROTECTED "protected"
%token<token> KW_ARGUMENTS "arguments"
%token<token> KW_PUBLIC "public"
%token<token> KW_PRIVATE "private"
%token<token> KW_USE "use"
%token<token> KW_INTERNAL "internal"
%token<token> KW_NEW "new"
%token<token> KW_NATIVE "native"
%token<token> KW_FUNCTION "function"
%token<token> KW_FINALLY "finally"
%token<token> KW_UNDEFINED "undefined"
%token<token> KW_NAN "NaN"
%token<token> KW_CONTINUE "continue"
%token<token> KW_CLASS "class"
%token<token> KW_CONST "const"
%token<token> KW_CATCH "catch"
%token<token> KW_CASE "case"
%token<token> KW_SET "set"
%token<token> KW_VOID "void"
%token<token> KW_THROW "throw"
%token<token> KW_STATIC "static"
%token<token> KW_WITH "with"
%token<token> KW_INSTANCEOF "instanceof"
%token<token> KW_IMPORT "import"
%token<token> KW_RETURN "return"
%token<token> KW_TYPEOF "typeof"
%token<token> KW_INTERFACE "interface"
%token<token> KW_NULL "null"
%token<token> KW_VAR "var"
%token<token> KW_DYNAMIC "dynamic"
%token<token> KW_OVERRIDE "override"
%token<token> KW_FINAL "final"
%token<token> KW_EACH "each"
%token<token> KW_GET "get"
%token<token> KW_TRY "try"
%token<token> KW_SUPER "super"
%token<token> KW_EXTENDS "extends"
%token<token> KW_FALSE "false"
%token<token> KW_TRUE "true"
%token<token> KW_BOOLEAN "Boolean"
%token<token> KW_UINT "uint"
%token<token> KW_INT "int"
%token<token> KW_NUMBER "Number"
%token<token> KW_STRING "String"
%token<token> KW_DEFAULT "default"
%token<token> KW_DEFAULT_XML "default xml"
%token<token> KW_DELETE "delete"
%token<token> KW_IF "if"
%token<token> KW_ELSE  "else"
%token<token> KW_BREAK   "break"
%token<token> KW_IS "is"
%token<token> KW_IN "in"
%token<token> KW_AS "as"

%token<token> T_DICTSTART "{ (dictionary)"
%token<token> T_EQEQ "=="
%token<token> T_EQEQEQ "==="
%token<token> T_NE "!="
%token<token> T_NEE "!=="
%token<token> T_LE "<="
%token<token> T_GE ">="
%token<token> T_ORBY "|=" 
%token<token> T_DIVBY "/=" 
%token<token> T_MODBY "%="
%token<token> T_MULBY "*="
%token<token> T_ANDBY "&="
%token<token> T_PLUSBY "+=" 
%token<token> T_MINUSBY "-="
%token<token> T_XORBY "^="
%token<token> T_SHRBY ">>="
%token<token> T_SHLBY "<<="
%token<token> T_USHRBY ">>>="
%token<token> T_OROR "||"
%token<token> T_ANDAND "&&"
%token<token> T_COLONCOLON "::"
%token<token> T_MINUSMINUS "--"
%token<token> T_PLUSPLUS "++"
%token<token> T_DOTDOT ".."
%token<token> T_DOTDOTDOT "..."
%token<token> T_SHL "<<"
%token<token> T_USHR ">>>"
%token<token> T_SHR ">>"

%type <number_int> CONDITIONAL_COMPILATION EMBED_START
%type <for_start> FOR_START
%type <id> X_IDENTIFIER PACKAGE FOR_IN_INIT MAYBE_IDENTIFIER ID_OR_NS SUBNODE
%type <namespace_decl>  NAMESPACE_ID
%type <token> VARCONST
%type <code> CODE
%type <code> CODEPIECE CODE_STATEMENT
%type <code> CODEBLOCK IF_CODEBLOCK MAYBECODE MAYBE_CASE_LIST CASE_LIST DEFAULT CASE SWITCH WITH
%type <code> PACKAGE_DECLARATION SLOT_DECLARATION SLOT_LIST ONE_SLOT
%type <code> FUNCTION_DECLARATION PACKAGE_INITCODE
%type <code> VARIABLE_DECLARATION ONE_VARIABLE VARIABLE_LIST THROW
%type <exception> CATCH FINALLY
%type <catch_list> CATCH_LIST CATCH_FINALLY_LIST
%type <code> CLASS_DECLARATION
%type <code> NAMESPACE_DECLARATION
%type <code> INTERFACE_DECLARATION
%type <code> VOIDEXPRESSION
%type <value> EXPRESSION NONCOMMAEXPRESSION
%type <node> MAYBEEXPRESSION
%type <value> DELETE
%type <node> E COMMA_EXPRESSION
%type <node> VAR_READ
%type <code> FOR FOR_IN IF WHILE DO_WHILE MAYBEELSE BREAK RETURN CONTINUE TRY 
%type <value> INNERFUNCTION
%type <code> USE_NAMESPACE DEFAULT_NAMESPACE
%type <code> FOR_INIT
%type <code> IMPORT
%type <classinfo> MAYBETYPE
%type <token> GETSET
%type <param> PARAM
%type <params> PARAM_LIST
%type <params> MAYBE_PARAM_LIST
%type <flags> MAYBE_MODIFIERS
%type <flags> MODIFIER_LIST
%type <flags> MODIFIER
%type <constant> CONSTANT MAYBECONSTANT
%type <classinfo_list> IMPLEMENTS_LIST
%type <classinfo> EXTENDS CLASS_SPEC
%type <classinfo_list> EXTENDS_LIST
%type <classinfo> CLASS PACKAGEANDCLASS
%type <classinfo_list> CLASS_SPEC_LIST
%type <node>  XMLEXPR1 XMLEXPR2 XML2 XMLNODE XMLATTRIBUTE XMLATTRIBUTES MAYBE_XMLATTRIBUTES XMLTEXT XML_ID_OR_EXPR XML
%type <classinfo> TYPE
//%type <token> VARIABLE
%type <value> MEMBER
%type <value> NEW
//%type <token> T_IDENTIFIER
%type <value> FUNCTIONCALL
%type <value_list> MAYBE_EXPRESSION_LIST EXPRESSION_LIST EXPRESSION_LIST_AND_COMMA MAYBE_PARAM_VALUES 
%type <value_list> MAYBE_DICT_EXPRPAIR_LIST DICT_EXPRPAIR_LIST WITH_HEAD
%type <code> DICTLH

// precedence: from low to high

%left prec_none

%left below_semicolon
%left ';'
%left ','
%nonassoc below_assignment // for ?:, contrary to spec
%right '=' "*=" "/=" "%=" "+=" "-=" "<<=" ">>=" ">>>=" "&=" "^=" "|="
%right '?' ':'
%left "||"
%left "&&"
%left '|'
%left '^'
%nonassoc '&'
%nonassoc "==" "!=" "===" "!=="
%nonassoc "is" "as" "in"
%left below_lt
%nonassoc "<=" '<' ">=" '>' "instanceof" // TODO: support "a < b < c" syntax?
%left "<<" ">>" ">>>" 
%left below_minus
%left '-' '+'
%left '/' '*' '%'
%left plusplus_prefix minusminus_prefix '~' '!' "void" "delete" "typeof" //FIXME: *unary* + - should be here, too
%left "--" "++" 
%nonassoc below_curly

%left '('
%left new2
%left '[' ']' "new" '{' "{ (dictionary)" '.' ".." "::" '@'

%left T_IDENTIFIER "arguments"
%left above_identifier
%left below_else
%nonassoc "else"

// needed for "return" precedence:
%nonassoc T_STRING T_REGEXP
%nonassoc T_INT T_UINT T_FLOAT KW_NAN 
%left T_NAMESPACE
%nonassoc "false" "true" "null" "undefined" "super" "function"
%left above_function


     
%{

static int a3_error(char*s)
{
   syntaxerror("%s", s); 
   return 0; //make gcc happy
}

static void parsererror(const char*file, int line, const char*f)
{
    syntaxerror("internal error in %s, %s:%d", f, file, line);
}

#define parserassert(b) {if(!(b)) parsererror(__FILE__, __LINE__,__func__);}


static char* concat2(const char* t1, const char* t2)
{
    int l1 = strlen(t1);
    int l2 = strlen(t2);
    char*text = malloc(l1+l2+1);
    memcpy(text   , t1, l1);
    memcpy(text+l1, t2, l2);
    text[l1+l2] = 0;
    return text;
}
static char* concat3(const char* t1, const char* t2, const char* t3)
{
    int l1 = strlen(t1);
    int l2 = strlen(t2);
    int l3 = strlen(t3);
    char*text = malloc(l1+l2+l3+1);
    memcpy(text   , t1, l1);
    memcpy(text+l1, t2, l2);
    memcpy(text+l1+l2, t3, l3);
    text[l1+l2+l3] = 0;
    return text;
}

typedef struct _import {
    char*package;
} import_t;
DECLARE_LIST(import);

DECLARE(methodstate);
DECLARE_LIST(methodstate);

typedef struct _classstate {
    /* class data */
    classinfo_t*info;
    abc_class_t*abc;

    methodstate_t*init;
    methodstate_t*static_init;
    //code_t*init;
    //code_t*static_init;
    parsedclass_t*dependencies;

    char has_constructor;
} classstate_t;

struct _methodstate {
    /* method data */
    methodinfo_t*info;
    char has_exceptions;
    char late_binding;
    char is_constructor;
    char has_super;
    char is_global;
    char is_static;
    int variable_count;

    dict_t*unresolved_variables;

    char inner;
    char uses_parent_function;
    char no_variable_scoping;
    int uses_slots;
    dict_t*slots;
    int activation_var;

    int need_arguments;

    abc_method_t*abc;
    int var_index; // for inner methods
    int slot_index; // for inner methods
    char is_a_slot; // for inner methods

    code_t*header;

    code_t*scope_code;
    abc_exception_list_t*exceptions;
    
    methodstate_list_t*innerfunctions;
};

void methodstate_destroy(methodstate_t*m) 
{
    dict_destroy(m->unresolved_variables);
    m->unresolved_variables = 0;
    list_free(m->innerfunctions);m->innerfunctions=0;
}

typedef struct _state {
    struct _state*old;
    int level;
    
    char*package;     
    import_list_t*wildcard_imports;
    dict_t*import_toplevel_packages;
    dict_t*imports;

    namespace_list_t*active_namespace_urls;
    
    char has_own_imports;
    char new_vars; // e.g. transition between two functions
    char xmlfilter; // are we inside a xmlobj..() filter?
  
    classstate_t*cls;   
    methodstate_t*method;

    char*exception_name;

    int switch_var;
    
    dict_t*vars;
    dict_t*allvars; // also contains variables from sublevels
} state_t;

typedef struct _global {
    abc_file_t*file;

    parsedclass_list_t*classes;
    abc_script_t*classinit;

    abc_script_t*init; //package-level code

    dict_t*token2info;
    dict_t*file2token2info;
} global_t;

static global_t*global = 0;
static state_t* state = 0;

DECLARE_LIST(state);

/* protected handling here is a big hack: we just assume the protectedns
   is package:class. the correct approach would be to add the proper
   namespace to all protected members in the registry, even though that
   would slow down searching */
#define MEMBER_MULTINAME(m,f,n) \
    multiname_t m;\
    namespace_t m##_ns;\
    if(f) { \
        m##_ns.access = ((slotinfo_t*)(f))->access; \
        if(m##_ns.access == ACCESS_NAMESPACE) \
            m##_ns.name = ((slotinfo_t*)(f))->package; \
        else if(m##_ns.access == ACCESS_PROTECTED && (f)->parent) \
            m##_ns.name = concat3((f)->parent->package,":",(f)->parent->name); \
        else \
            m##_ns.name = ""; \
        m.type = QNAME; \
        m.ns = &m##_ns; \
        m.namespace_set = 0; \
        m.name = ((slotinfo_t*)(f))->name; \
    } else { \
        m.type = MULTINAME; \
        m.ns =0; \
        m.namespace_set = &nopackage_namespace_set; \
        m.name = n; \
    }

/* warning: list length of namespace set is undefined */
#define MULTINAME_LATE(m, access, package) \
    namespace_t m##_ns = {access, package}; \
    namespace_set_t m##_nsset; \
    namespace_list_t m##_l;m##_l.next = 0; \
    m##_nsset.namespaces = &m##_l; \
    m##_nsset = m##_nsset; \
    m##_l.namespace = &m##_ns; \
    multiname_t m = {MULTINAMEL, 0, &m##_nsset, 0};

static namespace_t ns1 = {ACCESS_PRIVATE, ""};
static namespace_t ns2 = {ACCESS_PROTECTED, ""};
static namespace_t ns3 = {ACCESS_PACKAGEINTERNAL, ""};
static namespace_t stdns = {ACCESS_PACKAGE, ""};
static namespace_list_t nl4 = {&stdns,0};
static namespace_list_t nl3 = {&ns3,&nl4};
static namespace_list_t nl2 = {&ns2,&nl3};
static namespace_list_t nl1 = {&ns1,&nl2};
static namespace_set_t nopackage_namespace_set = {&nl1};

static dict_t*definitions=0;
void as3_set_define(const char*c)
{
    if(!definitions) 
        definitions = dict_new();
    if(!dict_contains(definitions,c))
        dict_put(definitions,c,0);
}

static void new_state()
{
    NEW(state_t, s);
    state_t*oldstate = state;
    if(state)
        memcpy(s, state, sizeof(state_t)); //shallow copy
    if(!s->imports) {
        s->imports = dict_new();
    }
    if(!s->import_toplevel_packages) {
        s->import_toplevel_packages = dict_new(); 
    }
    state = s;
    state->level++;
    state->has_own_imports = 0;    
    state->vars = dict_new(); 
    state->old = oldstate;
    state->new_vars = 0;

    trie_remember(active_namespaces);
   
    if(oldstate)
        state->active_namespace_urls = list_clone(oldstate->active_namespace_urls);
}

static void state_destroy(state_t*state)
{
    if(state->has_own_imports) {
        list_free(state->wildcard_imports);
        dict_destroy(state->imports);state->imports=0;
    }
    if(state->imports && (!state->old || state->old->imports!=state->imports)) {
        dict_destroy(state->imports);state->imports=0;
    }
    if(state->vars) {
        dict_destroy(state->vars);state->vars=0;
    }
    if(state->new_vars && state->allvars) {
        parserassert(!state->old || state->old->allvars != state->allvars);
        DICT_ITERATE_DATA(state->allvars, void*, data) {
            free(data);
        }
        dict_destroy(state->allvars);
    }
    
    list_free(state->active_namespace_urls)
    state->active_namespace_urls = 0;
    
    free(state);
}

static void old_state()
{
    trie_rollback(active_namespaces);

    if(!state || !state->old)
        syntaxerror("invalid nesting");
    state_t*leaving = state;
    
    state = state->old;

    if(as3_pass>1 && leaving->method && leaving->method != state->method && !leaving->method->inner) {
        methodstate_destroy(leaving->method);leaving->method=0;
    }
    if(as3_pass>1 && leaving->cls && leaving->cls != state->cls) {
        free(leaving->cls);
        leaving->cls=0;
    }

    state_destroy(leaving);
}

static code_t* method_header(methodstate_t*m);
static code_t* wrap_function(code_t*c,code_t*header, code_t*body);
static void function_initvars(methodstate_t*m, char has_params, params_t*params, int flags, char var0);


static char* internal_filename_package = 0;
void initialize_file(char*filename)
{
    if(state) {
        syntaxerror("invalid call to initialize_file during parsing of another file");
    }
    
    active_namespaces = trie_new();

    new_state();
    state->package = internal_filename_package = strdup(filename);
    state->allvars = dict_new();
    
    global->token2info = dict_lookup(global->file2token2info, 
                                     current_filename // use long version
                                    );
    if(!global->token2info) {
        global->token2info = dict_new2(&ptr_type);
        dict_put(global->file2token2info, current_filename, global->token2info);
    }
  
    if(as3_pass==1) {
        state->method = rfx_calloc(sizeof(methodstate_t));
        dict_put(global->token2info, (void*)(ptroff_t)as3_tokencount, state->method);
        state->method->late_binding = 1; // init scripts use getglobalscope, so we need a getlocal0/pushscope
    } else {
        state->method = dict_lookup(global->token2info, (void*)(ptroff_t)as3_tokencount);
        state->method->variable_count = 0;
        if(!state->method)
            syntaxerror("internal error: skewed tokencount");
        function_initvars(state->method, 0, 0, 0, 1);
        global->init = 0;
    }
}

void finish_file()
{
    if(!state || state->level!=1) {
        syntaxerror("unexpected end of file in pass %d", as3_pass);
    }
    
    if(as3_pass==2) {
        dict_del(global->file2token2info, current_filename);
        code_t*header = method_header(state->method);
        //if(global->init->method->body->code || global->init->traits) {
        if(global->init) {
            code_t*c = wrap_function(header, 0, global->init->method->body->code);
            global->init->method->body->code = abc_returnvoid(c);
            free(state->method);state->method=0;
        }
    }

    //free(state->package);state->package=0; // used in registry
    state_destroy(state);state=0;
}

void initialize_parser()
{
    global = rfx_calloc(sizeof(global_t));
    global->file = abc_file_new();
    global->file->flags &= ~ABCFILE_LAZY;
    global->file2token2info = dict_new();
    global->token2info = 0;
    global->classinit = abc_initscript(global->file);
}

void* finish_parser()
{
    dict_free_all(global->file2token2info, 1, (void*)dict_destroy);
    global->token2info=0;
    
    initcode_add_classlist(global->classinit, global->classes);

    return global->file;
}

typedef struct _variable {
    int index;
    classinfo_t*type;
    char init;
    char kill;
    char is_parameter;
    methodstate_t*is_inner_method;
} variable_t;

static variable_t* find_variable(state_t*s, char*name)
{
    if(s->method->no_variable_scoping) {
        return dict_lookup(s->allvars, name);
    } else {
        state_t*top = s;
        while(s) {
            variable_t*v = 0;
            v = dict_lookup(s->vars, name);
            if(v) return v;
            if(s->new_vars) break;
            s = s->old;
        }
        return 0;
    }
}
static variable_t* find_slot(methodstate_t*m, const char*name)
{
    if(m && m->slots)
        return dict_lookup(m->slots, name);
    return 0;
}

static variable_t* find_variable_safe(state_t*s, char*name)
{
    variable_t* v = find_variable(s, name);
    if(!v)
        syntaxerror("undefined variable: %s", name);
    return v;
}

static char variable_exists(char*name) 
{
    return dict_contains(state->vars, name);
}

static code_t*defaultvalue(code_t*c, classinfo_t*type)
{
    if(TYPE_IS_INT(type)) {
       c = abc_pushbyte(c, 0);
    } else if(TYPE_IS_UINT(type)) {
       c = abc_pushuint(c, 0);
    } else if(TYPE_IS_FLOAT(type)) {
       c = abc_pushnan(c);
    } else if(TYPE_IS_BOOLEAN(type)) {
       c = abc_pushfalse(c);
    } else if(TYPE_IS_STRING(type)) {
       c = abc_pushnull(c);
       c = abc_coerce_s(c);
    } else if(!type) {
       //c = abc_pushundefined(c);
        syntaxerror("internal error: can't generate default value for * type");
    } else {
       c = abc_pushnull(c);
       MULTINAME(m, type);
       c = abc_coerce2(c, &m);
    }
    return c;
}

static int alloc_local()
{
    return state->method->variable_count++;
}

static variable_t* new_variable2(methodstate_t*method, const char*name, classinfo_t*type, char init, char maybeslot)
{
    if(maybeslot) {
        variable_t*v = find_slot(method, name);
        if(v) {
            alloc_local(); 
            return v;
        }
    }

    NEW(variable_t, v);
    v->index = alloc_local();
    v->type = type;
    v->init = v->kill = init;
 
    if(name) {
        if(!method->no_variable_scoping) 
        {
            if(dict_contains(state->vars, name)) {
                *(int*)0=0;
                syntaxerror("variable %s already defined", name);
            }
            dict_put(state->vars, name, v);
        }
        if(method->no_variable_scoping && 
           as3_pass==2 && 
           dict_contains(state->allvars, name)) 
        {
            variable_t*v = dict_lookup(state->allvars, name);
            if(v->type != type)
                syntaxerror("variable %s already defined.", name);
            return v;
        }
        dict_put(state->allvars, name, v);
    }

    return v;
}
static int new_variable(methodstate_t*method, const char*name, classinfo_t*type, char init, char maybeslot)
{
    return new_variable2(method, name, type, init, maybeslot)->index;
}

#define TEMPVARNAME "__as3_temp__"
int gettempvar()
{
    variable_t*v = find_variable(state, TEMPVARNAME);
    int i;
    if(v) 
        i = v->index;
    else
        i = new_variable(state->method, TEMPVARNAME, 0, 0, 0);
    parserassert(i);
    return i;
}

static code_t* var_block(code_t*body, dict_t*vars) 
{
    code_t*c = 0;
    code_t*k = 0;
    int t;
    DICT_ITERATE_DATA(vars, variable_t*, v) {
        if(v->type && v->init) {
            c = defaultvalue(c, v->type);
            c = abc_setlocal(c, v->index);
        }
        if(v->type && v->kill) {
            k = abc_kill(k, v->index); 
        }
    }

    if(k) {
        code_t*x = body;
        while(x) {
            if(x->opcode== OPCODE___BREAK__ ||
               x->opcode== OPCODE___CONTINUE__) {
               /* link kill code before break/continue */
                code_t*e = code_dup(k);
                code_t*s = code_start(e);
                s->prev = x->prev;
                if(x->prev) {
                    x->prev->next = s;
                }
                e->next = x;
                x->prev = e;
            }
            x = x->prev;
        }
    }
    
    c = code_append(c, body);
    c = code_append(c, k);
    return c;
}

static void unknown_variable(char*name) 
{
    if(!state->method->unresolved_variables)
        state->method->unresolved_variables = dict_new();
    if(!dict_contains(state->method->unresolved_variables, name))
        dict_put(state->method->unresolved_variables, name, 0);
}

static code_t* add_scope_code(code_t*c, methodstate_t*m, char init)
{
    if(m->uses_slots || m->innerfunctions || (m->late_binding && !m->inner)) {
        c = abc_getlocal_0(c);
        c = abc_pushscope(c);
    }
    if(m->uses_slots) {
        /* FIXME: this alloc_local() causes variable indexes to be
           different in pass2 than in pass1 */
        if(!m->activation_var) {
            m->activation_var = alloc_local();
        }
        if(init) {
            c = abc_newactivation(c);
            c = abc_dup(c);
            c = abc_pushscope(c);
            c = abc_setlocal(c, m->activation_var);
        } else {
            c = abc_getlocal(c, m->activation_var);
            c = abc_pushscope(c);
        }
    }
    return c;
}

static code_t* method_header(methodstate_t*m)
{
    code_t*c = 0;

    c = add_scope_code(c, m, 1);

    methodstate_list_t*l = m->innerfunctions;
    while(l) {
        parserassert(l->methodstate->abc);
        if(m->uses_slots && l->methodstate->is_a_slot) {
            c = abc_getscopeobject(c, 1);
            c = abc_newfunction(c, l->methodstate->abc);
            c = abc_dup(c);
            c = abc_setlocal(c, l->methodstate->var_index);
            c = abc_setslot(c, l->methodstate->slot_index);
        } else {
            c = abc_newfunction(c, l->methodstate->abc);
            c = abc_setlocal(c, l->methodstate->var_index);
        }
        free(l->methodstate);l->methodstate=0;
        l = l->next;
    }
    if(m->header) {
        c = code_append(c, m->header);
        m->header = 0;
    }
    if(m->is_constructor && !m->has_super) {
        // call default constructor
        c = abc_getlocal_0(c);
        c = abc_constructsuper(c, 0);
    }

    if(m->slots) {
        /* all parameters that are used by inner functions
           need to be copied from local to slot */
        parserassert(m->activation_var);
        DICT_ITERATE_ITEMS(m->slots,char*,name,variable_t*,v) {
            if(v->is_parameter) {
                c = abc_getlocal(c, m->activation_var); 
                c = abc_getlocal(c, v->index); 
                c = abc_setslot(c, v->index); 
            }
        }
    }
    list_free(m->innerfunctions);
    m->innerfunctions = 0;
    return c;
}
    

static code_t* wrap_function(code_t*c,code_t*header, code_t*body)
{
    c = code_append(c, header);
    c = code_append(c, var_block(body, state->method->no_variable_scoping?state->allvars:state->vars));
    /* append return if necessary */
    if(!c || (c->opcode != OPCODE_RETURNVOID && 
              c->opcode != OPCODE_RETURNVALUE)) {
        c = abc_returnvoid(c);
    }
    return c;
}

static void startpackage(char*name)
{
    new_state();
    state->package = strdup(name);
}
static void endpackage()
{
    //used e.g. in classinfo_register:
    //free(state->package);state->package=0;
    old_state();
}

#define FLAG_PUBLIC 256
#define FLAG_PROTECTED 512
#define FLAG_PRIVATE 1024
#define FLAG_PACKAGEINTERNAL 2048
#define FLAG_NAMESPACE 4096

static namespace_t modifiers2access(modifiers_t*mod)
{
    namespace_t ns;
    ns.access = 0;
    ns.name = "";
    if(mod->flags&FLAG_NAMESPACE)  {
        if(mod->flags&(FLAG_PRIVATE|FLAG_PROTECTED|FLAG_PACKAGEINTERNAL)) 
            syntaxerror("invalid combination of access levels and namespaces");
        ns.access = ACCESS_NAMESPACE;
        state_t*s = state;
        const char*url = (const char*)trie_lookup(active_namespaces, mod->ns);
        if(!url) {
            /* shouldn't happen- the tokenizer only reports something as a namespace
               if it was already registered */
            trie_dump(active_namespaces);
            syntaxerror("unknown namespace: %s", mod->ns);
        }
        ns.name = url;
    } else if(mod->flags&FLAG_PUBLIC)  {
        if(mod->flags&(FLAG_PRIVATE|FLAG_PROTECTED|FLAG_PACKAGEINTERNAL)) 
            syntaxerror("invalid combination of access levels");
        ns.access = ACCESS_PACKAGE;
    } else if(mod->flags&FLAG_PRIVATE) {
        if(mod->flags&(FLAG_PUBLIC|FLAG_PROTECTED|FLAG_PACKAGEINTERNAL)) 
            syntaxerror("invalid combination of access levels");
        ns.access = ACCESS_PRIVATE;
    } else if(mod->flags&FLAG_PROTECTED) {
        if(mod->flags&(FLAG_PUBLIC|FLAG_PRIVATE|FLAG_PACKAGEINTERNAL)) 
            syntaxerror("invalid combination of access levels");
        ns.access = ACCESS_PROTECTED;
    } else {
        ns.access = ACCESS_PACKAGEINTERNAL;
    }
    return ns;
}
static slotinfo_t* find_class(const char*name);

static memberinfo_t* findmember_nsset(classinfo_t*cls, const char*name, char recurse)
{
    return registry_findmember_nsset(cls, state->active_namespace_urls, name, recurse);
}

static void innerfunctions2vars(methodstate_t*m)
{
    methodstate_list_t*l = m->innerfunctions;
    while(l) {
        methodstate_t*m = l->methodstate;
        
        variable_t* v = new_variable2(state->method, m->info->name, TYPE_FUNCTION(m->info), 0, 0);
        m->var_index = v->index;
        if(m->is_a_slot)
            m->slot_index = m->is_a_slot;
        v->is_inner_method = m;
        l = l->next;
    }
}

static void function_initvars(methodstate_t*m, char has_params, params_t*params, int flags, char var0)
{
    if(var0) {
        int index = -1;
        if(m->inner)
            index = new_variable(m, "this", 0, 0, 0);
        else if(!m->is_global)
            index = new_variable(m, (flags&FLAG_STATIC)?"class":"this", state->cls?state->cls->info:0, 0, 0);
        else
            index = new_variable(m, "globalscope", 0, 0, 0);
        if(index) {
            DICT_ITERATE_ITEMS(state->vars, char*, name, variable_t*, v) {
                printf("%s %d\n", name, v->index);
            }
        }
        parserassert(!index);
    }

    if(has_params) {
        param_list_t*p=0;
        for(p=params->list;p;p=p->next) {
            variable_t*v = new_variable2(m, p->param->name, p->param->type, 0, 1);
            v->is_parameter = 1;
        }
        if(as3_pass==2 && m->need_arguments) {
            /* arguments can never be used by an innerfunction (the inner functions
               have their own arguments var), so it's ok to  not initialize this until
               pass 2. (We don't know whether we need it before, anyway) */
            variable_t*v = new_variable2(m, "arguments", TYPE_ARRAY, 0, 0);
            m->need_arguments = v->index;
        }
    }
    
    innerfunctions2vars(m);
    
    if(as3_pass==2) {
        m->scope_code = add_scope_code(m->scope_code, m, 0);
        if(m->slots) {
            /* exchange unresolved identifiers with the actual objects */
            DICT_ITERATE_ITEMS(m->slots, char*, name, variable_t*, v) {
                if(v->type && v->type->kind == INFOTYPE_UNRESOLVED) {
                    classinfo_t*type = (classinfo_t*)registry_resolve((slotinfo_t*)v->type);
                    if(!type || type->kind != INFOTYPE_CLASS) {
                        syntaxerror("Couldn't find class %s::%s (%s)", v->type->package, v->type->name, name);
                    }
                    v->type = type;
                }
            }
        }
    }
}


char*as3_globalclass=0;
static void startclass(modifiers_t* mod, char*classname, classinfo_t*extends, classinfo_list_t*implements)
{
    if(state->cls) {
        syntaxerror("inner classes now allowed"); 
    }

    new_state();
    token_list_t*t=0;
    classinfo_list_t*mlist=0;

    if(mod->flags&~(FLAG_PACKAGEINTERNAL|FLAG_PUBLIC|FLAG_FINAL|FLAG_DYNAMIC|FLAG_INTERFACE))
        syntaxerror("invalid modifier(s)");

    if((mod->flags&(FLAG_PUBLIC|FLAG_PACKAGEINTERNAL)) == (FLAG_PUBLIC|FLAG_PACKAGEINTERNAL))
        syntaxerror("public and internal not supported at the same time.");
    
    if((mod->flags&(FLAG_PROTECTED|FLAG_STATIC)) == (FLAG_PROTECTED|FLAG_STATIC))
        syntaxerror("protected and static not supported at the same time.");
    
    //if(!(mod->flags&FLAG_INTERFACE) && !extends) {
    if(!(mod->flags&FLAG_INTERFACE) && !extends) {
        // all classes extend object
        extends = registry_getobjectclass();
    }

    /* create the class name, together with the proper attributes */
    int access=0;
    char*package=0;

    if(!(mod->flags&FLAG_PUBLIC) && state->package==internal_filename_package) {
        access = ACCESS_PRIVATE; package = internal_filename_package;
    } else if(!(mod->flags&FLAG_PUBLIC) && state->package!=internal_filename_package) {
        access = ACCESS_PACKAGEINTERNAL; package = state->package;
    } else if(state->package!=internal_filename_package) {
        access = ACCESS_PACKAGE; package = state->package;
    } else {
        syntaxerror("public classes only allowed inside a package");
    }

    if(as3_pass==1) {
        state->cls = rfx_calloc(sizeof(classstate_t));
        state->cls->init = rfx_calloc(sizeof(methodstate_t));
        state->cls->static_init = rfx_calloc(sizeof(methodstate_t));
        state->cls->static_init->is_static=FLAG_STATIC;
        /* notice: we make no effort to initialize the top variable (local0) here,
           even though it has special meaning. We just rely on the fact
           that pass 1 won't do anything with variables */
        
        dict_put(global->token2info, (void*)(ptroff_t)as3_tokencount, state->cls);

        /* set current method to constructor- all code within the class-level (except
           static variable initializations) will be executed during construction time */
        state->method = state->cls->init;

        if(registry_find(package, classname)) {
            syntaxerror("Package \"%s\" already contains a class called \"%s\"", package, classname);
        }
        /* build info struct */
        int num_interfaces = (list_length(implements));
        state->cls->info = classinfo_register(access, package, classname, num_interfaces);
        state->cls->info->flags |= mod->flags & (FLAG_DYNAMIC|FLAG_INTERFACE|FLAG_FINAL);
        state->cls->info->superclass = extends;
        
        int pos = 0;
        classinfo_list_t*l = implements;
        for(l=implements;l;l=l->next) {
            state->cls->info->interfaces[pos++] = l->classinfo;
        }
    }
    
    if(as3_pass == 2) {
        state->cls = dict_lookup(global->token2info, (void*)(ptroff_t)as3_tokencount);
    
        parserassert(state->cls && state->cls->info);
       
        state->method = state->cls->static_init;

        function_initvars(state->cls->init, 0, 0, 0, 1);
        state->cls->static_init->variable_count=1;
        function_initvars(state->cls->static_init, 0, 0, 0, 0);

        if(extends && (extends->flags & FLAG_FINAL))
            syntaxerror("Can't extend final class '%s'", extends->name);
        
        int pos = 0;
        while(state->cls->info->interfaces[pos]) {
            if(!(state->cls->info->interfaces[pos]->flags & FLAG_INTERFACE))
                syntaxerror("'%s' is not an interface", 
                    state->cls->info->interfaces[pos]->name);
            pos++;
        }

        /* generate the abc code for this class */
        MULTINAME(classname2,state->cls->info);
        multiname_t*extends2 = sig2mname(extends);

        /* don't add the class to the class index just yet- that will be done later
           by initscript */
        state->cls->abc = abc_class_new(0, &classname2, extends2);
        state->cls->abc->file = global->file;

        multiname_destroy(extends2);
        if(state->cls->info->flags&FLAG_FINAL) abc_class_final(state->cls->abc);
        if(!(state->cls->info->flags&FLAG_DYNAMIC)) abc_class_sealed(state->cls->abc);
        if(state->cls->info->flags&FLAG_INTERFACE) {
            abc_class_interface(state->cls->abc);
        }

        for(mlist=implements;mlist;mlist=mlist->next) {
            MULTINAME(m, mlist->classinfo);
            abc_class_add_interface(state->cls->abc, &m);
        }

        state->cls->dependencies = parsedclass_new(state->cls->info, state->cls->abc);
        list_append(global->classes, state->cls->dependencies);

        /* flash.display.MovieClip handling */
        if(!as3_globalclass && (mod->flags&FLAG_PUBLIC) && slotinfo_equals((slotinfo_t*)registry_getMovieClip(),(slotinfo_t*)extends)) {
            if(state->package && state->package[0]) {
                as3_globalclass = concat3(state->package, ".", classname);
            } else {
                as3_globalclass = strdup(classname);
            }
        }
    }
}

static void endclass()
{
    if(as3_pass == 2) {
        if(!state->cls->has_constructor && !(state->cls->info->flags&FLAG_INTERFACE)) {
            code_t*c = 0;
            c = abc_getlocal_0(c);
            c = abc_constructsuper(c, 0);
            state->cls->init->header = code_append(state->cls->init->header, c);
            state->cls->has_constructor=1;
        }
        if(state->cls->init) {
            if(state->cls->info->flags&FLAG_INTERFACE) {
                if(state->cls->init->header) 
                    syntaxerror("interface can not have class-level code");
            } else {
                abc_method_t*m = abc_class_getconstructor(state->cls->abc, 0);
                code_t*c = method_header(state->cls->init);
                m->body->code = wrap_function(c, 0, m->body->code);
            }
        }
        if(state->cls->static_init) {
            abc_method_t*m = abc_class_getstaticconstructor(state->cls->abc, 0);
            code_t*c = method_header(state->cls->static_init);
            m->body->code = wrap_function(c, 0, m->body->code);
        }
      
        trait_list_t*trait = state->cls->abc->traits;
        /* switch all protected members to the protected ns of this class */
        while(trait) {
            trait_t*t = trait->trait;
            if(t->name->ns->access == ACCESS_PROTECTED) {
                if(!state->cls->abc->protectedNS) {
                    char*n = concat3(state->cls->info->package, ":", state->cls->info->name);
                    state->cls->abc->protectedNS = namespace_new_protected(n);
                    state->cls->abc->flags |= CLASS_PROTECTED_NS;
                }
                t->name->ns->name = strdup(state->cls->abc->protectedNS->name);
            }
            trait = trait->next;
        }
    }

    old_state();
}

void check_code_for_break(code_t*c)
{
    while(c) {
        if(c->opcode == OPCODE___BREAK__) {
            char*name = string_cstr(c->data[0]);
            syntaxerror("Unresolved \"break %s\"", name);
        }
        if(c->opcode == OPCODE___CONTINUE__) {
            char*name = string_cstr(c->data[0]);
            syntaxerror("Unresolved \"continue %s\"", name);
        }
        if(c->opcode == OPCODE___RETHROW__) {
            syntaxerror("Unresolved \"rethrow\"");
        }
        if(c->opcode == OPCODE___FALLTHROUGH__) {
            syntaxerror("Unresolved \"fallthrough\"");
        }
        if(c->opcode == OPCODE___PUSHPACKAGE__) {
            char*name = string_cstr(c->data[0]);
            syntaxerror("Can't reference a package (%s) as such", name);
        }
        c=c->prev;
    }
}

static void check_constant_against_type(classinfo_t*t, constant_t*c)
{
#define xassert(b) if(!(b)) syntaxerror("Invalid default value %s for type '%s'", constant_tostring(c), t->name)
   if(TYPE_IS_NUMBER(t)) {
        xassert(c->type == CONSTANT_FLOAT
             || c->type == CONSTANT_INT
             || c->type == CONSTANT_UINT);
   } else if(TYPE_IS_UINT(t)) {
        xassert(c->type == CONSTANT_UINT ||
               (c->type == CONSTANT_INT && c->i>=0));
   } else if(TYPE_IS_INT(t)) {
        xassert(c->type == CONSTANT_INT);
   } else if(TYPE_IS_BOOLEAN(t)) {
        xassert(c->type == CONSTANT_TRUE
             || c->type == CONSTANT_FALSE);
   }
}

static void check_override(memberinfo_t*m, int flags)
{
    if(!m)
        return;
    if(m->parent == state->cls->info)
        syntaxerror("class '%s' already contains a method/slot '%s'", m->parent->name, m->name);
    if(!m->parent)
        syntaxerror("internal error: overriding method %s, which doesn't have parent", m->name);
    if(m->access==ACCESS_PRIVATE)
        return;
    if(m->flags & FLAG_FINAL)
        syntaxerror("can't override final member %s", m->name);
    
    /* allow this. it's no issue.
    if((m->flags & FLAG_STATIC) && !(flags&FLAG_STATIC))
        syntaxerror("can't override static member %s", m->name);*/

    if(!(m->flags & FLAG_STATIC) && (flags&FLAG_STATIC))
        syntaxerror("can't override non-static member %s with static declaration", m->name);

    if(!(flags&FLAG_OVERRIDE) && !(flags&FLAG_STATIC) && !(m->flags&FLAG_STATIC)) {
        if(m->parent && !(m->parent->flags&FLAG_INTERFACE)) {
            if(m->kind == INFOTYPE_METHOD)
                syntaxerror("can't override without explicit 'override' declaration");
            else
                syntaxerror("can't override '%s'", m->name);
        }
    }
}

static methodinfo_t*registerfunction(enum yytokentype getset, modifiers_t*mod, char*name, params_t*params, classinfo_t*return_type, int slot)
{
    methodinfo_t*minfo = 0;
    namespace_t ns = modifiers2access(mod);
    if(!state->cls) {
        //package method
        minfo = methodinfo_register_global(ns.access, state->package, name);
        minfo->return_type = return_type;
    } else if(getset != KW_GET && getset != KW_SET) {
        //class method
        memberinfo_t* m = registry_findmember(state->cls->info, ns.name, name, 0);
        if(m) {
            syntaxerror("class already contains a %s '%s'", infotypename((slotinfo_t*)m), m->name);
        }
        minfo = methodinfo_register_onclass(state->cls->info, ns.access, ns.name, name);
        minfo->return_type = return_type;
        // getslot on a member slot only returns "undefined", so no need
        // to actually store these
        //state->minfo->slot = state->method->abc->method->trait->slot_id;
    } else {
        //class getter/setter
        int gs = getset==KW_GET?SUBTYPE_GET:SUBTYPE_SET;
        classinfo_t*type=0;
        if(getset == KW_GET) {
            type = return_type;
        } else if(params->list && params->list->param && !params->list->next) {
            type = params->list->param->type;
        } else
            syntaxerror("setter function needs to take exactly one argument");
        // not sure wether to look into superclasses here, too
        minfo = (methodinfo_t*)registry_findmember(state->cls->info, ns.name, name, 1);
        if(minfo) {
            if(minfo->kind!=INFOTYPE_VAR)
                syntaxerror("class already contains a method called '%s'", name);
            if(!(minfo->subtype & (SUBTYPE_GETSET)))
                syntaxerror("class already contains a field called '%s'", name);
            if(minfo->subtype & gs)
                syntaxerror("getter/setter for '%s' already defined", name);
            /* make a setter or getter into a getset */
            minfo->subtype |= gs;
            
            /*
            FIXME: this check needs to be done in pass 2
            
            if((!minfo->return_type != !type) ||
                (minfo->return_type && type && 
                 !strcmp(minfo->return_type->name, type->name))) {
                syntaxerror("different type in getter and setter: %s and %s", 
                    minfo->return_type?minfo->return_type->name:"*", 
                    type?type->name:"*");
            }*/
        } else {
            minfo = methodinfo_register_onclass(state->cls->info, ns.access, ns.name, name);
            minfo->kind = INFOTYPE_VAR; //hack
            minfo->subtype = gs;
            minfo->return_type = type;
        }

        /* can't assign a slot as getter and setter might have different slots */
        //minfo->slot = slot;
    }
    if(mod->flags&FLAG_FINAL) minfo->flags |= FLAG_FINAL;
    if(mod->flags&FLAG_STATIC) minfo->flags |= FLAG_STATIC;
    if(mod->flags&FLAG_OVERRIDE) minfo->flags |= FLAG_OVERRIDE;

    return minfo;
}

static void innerfunction(char*name, params_t*params, classinfo_t*return_type)
{
    //parserassert(state->method && state->method->info);

    methodstate_t*parent_method = state->method;
    variable_t*v = 0;

    if(as3_pass==1) {
        return_type = 0; // not valid in pass 1
        if(name) {
            v = new_variable2(parent_method, name, 0, 0, 0);
        }
    }

    new_state();
    state->new_vars = 1;
    state->allvars = dict_new();
   
    if(as3_pass == 1) {
        state->method = rfx_calloc(sizeof(methodstate_t));
        state->method->inner = 1;
        state->method->is_static = parent_method->is_static;
        state->method->variable_count = 0;
        state->method->abc = rfx_calloc(sizeof(abc_method_t));
        if(v) {
            v->is_inner_method = state->method;
        }

        NEW(methodinfo_t,minfo);
        minfo->kind = INFOTYPE_METHOD;
        minfo->access = ACCESS_PACKAGEINTERNAL;
        minfo->name = name;
        state->method->info = minfo;

        if(parent_method)
            list_append(parent_method->innerfunctions, state->method);

        dict_put(global->token2info, (void*)(ptroff_t)as3_tokencount, state->method);
    
        function_initvars(state->method, 1, params, 0, 1);
    }

    if(as3_pass == 2) {
        state->method = dict_lookup(global->token2info, (void*)(ptroff_t)as3_tokencount);
        state->method->variable_count = 0;
        parserassert(state->method);

        state->method->info->return_type = return_type;
        function_initvars(state->method, 1, params, 0, 1);
    }
}

static void startfunction(modifiers_t*mod, enum yytokentype getset, char*name,
                          params_t*params, classinfo_t*return_type)
{
    if(state->method && state->method->info) {
        syntaxerror("not able to start another method scope");
    }
    new_state();
    state->new_vars = 1;
    state->allvars = dict_new();

    if(as3_pass == 1) {
        state->method = rfx_calloc(sizeof(methodstate_t));
        state->method->has_super = 0;
        state->method->is_static = mod->flags&FLAG_STATIC;

        if(state->cls) {
            state->method->is_constructor = !strcmp(state->cls->info->name,name);
        } else {
            state->method->is_global = 1;
            state->method->late_binding = 1; // for global methods, always push local_0 on the scope stack
        }
        if(state->method->is_constructor)
            name = "__as3_constructor__";

        state->method->info = registerfunction(getset, mod, name, params, return_type, 0);
       
        function_initvars(state->method, 1, params, mod->flags, 1);
        
        dict_put(global->token2info, (void*)(ptroff_t)as3_tokencount, state->method);
    }

    if(as3_pass == 2) {
        state->method = dict_lookup(global->token2info, (void*)(ptroff_t)as3_tokencount);
        state->method->variable_count = 0;
        parserassert(state->method);
                
        if(state->cls) {
            memberinfo_t*m = registry_findmember(state->cls->info, mod->ns, name, 2);
            check_override(m, mod->flags);
        }
            
        if(state->cls) { 
            state->cls->has_constructor |= state->method->is_constructor;
        }
        
        function_initvars(state->method, 1, params, mod->flags, 1);
    } 
}

static void insert_unresolved(methodstate_t*m, dict_t*xvars, dict_t*allvars)
{
    parserassert(m->inner);
    if(m->unresolved_variables) {
        dict_t*d = m->unresolved_variables;
        int t;
        DICT_ITERATE_KEY(d, char*, id) {
            /* check parent method's variables */
            variable_t*v;
            if(dict_contains(allvars, id)) {
                m->uses_parent_function = 1;
                state->method->uses_slots = 1;
                dict_put(xvars, id, 0);
            }
        }
    }
    methodstate_list_t*ml = m->innerfunctions;
    while(ml) {
        insert_unresolved(ml->methodstate, xvars, allvars);
        ml = ml->next;
    }
}

static abc_method_t* endfunction(modifiers_t*mod, enum yytokentype getset, char*name,
                          params_t*params, classinfo_t*return_type, code_t*body)
{
    if(as3_pass==1) {
        dict_t*xvars = dict_new();
        
        if(state->method->unresolved_variables) {
            DICT_ITERATE_KEY(state->method->unresolved_variables, char*, vname) {
                if(!state->method->no_variable_scoping && dict_contains(state->allvars, vname)) {
                    variable_t*v = dict_lookup(state->allvars, vname);
                    if(!v->is_inner_method) {
                        state->method->no_variable_scoping = 1;
                        as3_warning("function %s uses forward or outer block variable references (%s): switching into compatiblity mode", name, vname);
                    }
                }
            }
        }

        methodstate_list_t*ml = state->method->innerfunctions;
        while(ml) {
            insert_unresolved(ml->methodstate, xvars, state->allvars);
            ml = ml->next;
        }
        
        if(state->method->uses_slots) {
            state->method->slots = dict_new();
            int i = 1;
            DICT_ITERATE_ITEMS(state->allvars, char*, name, variable_t*, v) {
                if(!name) syntaxerror("internal error");
                if(v->index && dict_contains(xvars, name)) {
                    v->init = v->kill = 0;
                    v->index = i;
                    if(v->is_inner_method) {
                        v->is_inner_method->is_a_slot = i;
                    }
                    i++;
                    dict_put(state->method->slots, name, v);
                }
            }
            state->method->uses_slots = i;
            dict_destroy(state->vars);state->vars = 0;
            parserassert(state->new_vars);
            dict_destroy(state->allvars);state->allvars = 0;
        }
        old_state();
        return 0;
    }

    if(as3_pass==2) {
        /*if(state->method->uses_parent_function){
            syntaxerror("accessing variables of parent function from inner functions not supported yet");
        }*/

        abc_method_t*f = 0;

        multiname_t*type2 = sig2mname(return_type);
        int slot = 0;
        if(state->method->inner) {
            f = state->method->abc;
            abc_method_init(f, global->file, type2, 1);
        } else if(state->method->is_constructor) {
            f = abc_class_getconstructor(state->cls->abc, type2);
        } else if(!state->method->is_global) {
            namespace_t ns = modifiers2access(mod);
            multiname_t mname = {QNAME, &ns, 0, name};
            if(mod->flags&FLAG_STATIC)
                f = abc_class_staticmethod(state->cls->abc, type2, &mname);
            else
                f = abc_class_method(state->cls->abc, type2, &mname);
            slot = f->trait->slot_id;
        } else {
            namespace_t mname_ns = {state->method->info->access, state->package};
            multiname_t mname = {QNAME, &mname_ns, 0, name};

            f = abc_method_new(global->file, type2, 1);
            if(!global->init) global->init = abc_initscript(global->file);
            trait_t*t = trait_new_method(&global->init->traits, multiname_clone(&mname), f);
            //abc_code_t*c = global->init->method->body->code;
        }
        //flash doesn't seem to allow us to access function slots
        //state->method->info->slot = slot;

        if(mod && mod->flags&FLAG_OVERRIDE) f->trait->attributes |= TRAIT_ATTR_OVERRIDE;
        if(getset == KW_GET) f->trait->kind = TRAIT_GETTER;
        if(getset == KW_SET) f->trait->kind = TRAIT_SETTER;
        if(params->varargs) f->flags |= METHOD_NEED_REST;
        if(state->method->need_arguments) f->flags |= METHOD_NEED_ARGUMENTS;

        char opt=0;
        param_list_t*p=0;
        for(p=params->list;p;p=p->next) {
            if(params->varargs && !p->next) {
                break; //varargs: omit last parameter in function signature
            }
            multiname_t*m = sig2mname(p->param->type);
            list_append(f->parameters, m);
            if(p->param->value) {
                check_constant_against_type(p->param->type, p->param->value);
                opt=1;list_append(f->optional_parameters, p->param->value);
            } else if(opt) {
                syntaxerror("function %s: non-optional parameter not allowed after optional parameters", name);
            }
        }
        if(state->method->slots) {
            DICT_ITERATE_ITEMS(state->method->slots, char*, name, variable_t*, v) {
                if(v->index) {
                    multiname_t*mname = multiname_new(namespace_new(ACCESS_PACKAGE, ""), name);
                    multiname_t*type = sig2mname(v->type);
                    trait_t*t = trait_new_member(&f->body->traits, type, mname, 0);
                    t->slot_id = v->index;
                }
            }
        }

        check_code_for_break(body);

        /* Seems this works now.
        if(state->method->exceptions && state->method->uses_slots) {
           as3_warning("try/catch and activation not supported yet within the same method");
        }*/

        if(f->body) {
            f->body->code = body;
            f->body->exceptions = state->method->exceptions;
        } else { //interface
            if(body)
                syntaxerror("interface methods can't have a method body");
        }

        old_state();
        return f;
    }
        
    return 0;
}

void breakjumpsto(code_t*c, char*name, code_t*jump) 
{
    while(c) {
        if(c->opcode == OPCODE___BREAK__) {
            string_t*name2 = c->data[0];
            if(!name2->len || !strncmp(name2->str, name, name2->len)) {
                c->opcode = OPCODE_JUMP;
                c->branch = jump;
            }
        }
        c=c->prev;
    }
}
void continuejumpsto(code_t*c, char*name, code_t*jump) 
{
    while(c) {
        if(c->opcode == OPCODE___CONTINUE__) {
            string_t*name2 = c->data[0];
            if(!name2->len || !strncmp(name2->str, name, name2->len)) {
                c->opcode = OPCODE_JUMP;
                c->branch = jump;
            }
        }
        c = c->prev;
    }
}

code_t*converttype(code_t*c, classinfo_t*from, classinfo_t*to)
{
    if(from==to)
        return c;
    if(!to) {
        return abc_coerce_a(c);
    }
    MULTINAME(m, to);
    if(!from) {
        // cast an "any" type to a specific type. subject to
        // runtime exceptions
        return abc_coerce2(c, &m);
    }
    
    if((TYPE_IS_NUMBER(from) || TYPE_IS_UINT(from) || TYPE_IS_INT(from)) &&
       (TYPE_IS_NUMBER(to) || TYPE_IS_UINT(to) || TYPE_IS_INT(to))) {
        // allow conversion between number types
        if(TYPE_IS_UINT(to))
            return abc_convert_u(c);
        else if(TYPE_IS_INT(to))
            return abc_convert_i(c);
        else if(TYPE_IS_NUMBER(to))
            return abc_convert_d(c);
        return abc_coerce2(c, &m);
    }

    if(TYPE_IS_XMLLIST(to) && TYPE_IS_XML(from))
        return c;

    if(TYPE_IS_BOOLEAN(to))
        return abc_convert_b(c);
    if(TYPE_IS_STRING(to))
        return abc_convert_s(c);
    if(TYPE_IS_OBJECT(to))
        return abc_coerce2(c, &m);
    if(TYPE_IS_OBJECT(from) && TYPE_IS_XMLLIST(to))
        return abc_coerce2(c, &m);
    if(TYPE_IS_OBJECT(from) && TYPE_IS_ARRAY(to))
        return abc_coerce2(c, &m);

    classinfo_t*supertype = from;
    while(supertype) {
        if(supertype == to) {
             /* target type is one of from's superclasses.
                (not sure we need this coerce - as far as the verifier
                 is concerned, object==object (i think) */
             return abc_coerce2(c, &m);
        }
        int t=0;
        while(supertype->interfaces[t]) {
            if(supertype->interfaces[t]==to) {
                // target type is one of from's interfaces
                return abc_coerce2(c, &m);
            }
            t++;
        }
        supertype = supertype->superclass;
    }
    if(TYPE_IS_FUNCTION(from) && TYPE_IS_FUNCTION(to))
        return c;
    if(TYPE_IS_CLASS(from) && TYPE_IS_CLASS(to))
        return c;
    if(TYPE_IS_NULL(from) && !IS_NUMBER_OR_INT(to))
        return c;

    as3_error("can't convert type %s%s%s to %s%s%s", 
        from->package, from->package[0]?".":"", from->name, 
        to->package, to->package[0]?".":"", to->name);

    return c;
}
code_t* coerce_to_type(code_t*c, classinfo_t*t)
{
    if(!t) {
        return abc_coerce_a(c);
    } else if(TYPE_IS_STRING(t)) {
        return abc_coerce_s(c);
    } else {
        MULTINAME(m, t);
        return abc_coerce2(c, &m);
    }
}

char is_pushundefined(code_t*c)
{
    return (c && !c->prev && !c->next && c->opcode == OPCODE_PUSHUNDEFINED);
}

static const char* get_package_from_name(const char*name)
{
    /* try explicit imports */
    dictentry_t* e = dict_get_slot(state->imports, name);
    while(e) {
        if(!strcmp(e->key, name)) {
            slotinfo_t*c = (slotinfo_t*)e->data;
            if(c) return c->package;
        }
        e = e->next;
    }
    return 0;
}
static namespace_list_t*get_current_imports()
{
    namespace_list_t*searchlist = 0;
    
    list_append(searchlist, namespace_new_package(state->package));

    import_list_t*l = state->wildcard_imports;
    while(l) {
        namespace_t*ns = namespace_new_package(l->import->package);
        list_append(searchlist, ns);
        l = l->next;
    }
    list_append(searchlist, namespace_new_package(""));
    list_append(searchlist, namespace_new_package(internal_filename_package));
    return searchlist;
}

static slotinfo_t* find_class(const char*name)
{
    slotinfo_t*c=0;

    c = registry_find(state->package, name);
    if(c) return c;

    /* try explicit imports */
    dictentry_t* e = dict_get_slot(state->imports, name);
    if(c) return c;
    while(e) {
        if(!strcmp(e->key, name)) {
            c = (slotinfo_t*)e->data;
            if(c) return c;
        }
        e = e->next;
    }

    /* try package.* imports */
    import_list_t*l = state->wildcard_imports;
    while(l) {
        //printf("does package %s contain a class %s?\n", l->import->package, name);
        c = registry_find(l->import->package, name);
        if(c) return c;
        l = l->next;
    }

    /* try global package */
    c = registry_find("", name);
    if(c) return c;
  
    /* try local "filename" package */
    c = registry_find(internal_filename_package, name);
    if(c) return c;

    return 0;
}
typedcode_t push_class(slotinfo_t*a)
{
    typedcode_t x;
    x.c = 0;
    x.t = 0;
    if(a->access == ACCESS_PACKAGEINTERNAL &&
       strcmp(a->package, state->package) &&
       strcmp(a->package, internal_filename_package)
       ) {
       syntaxerror("Can't access internal %s %s in package '%s' from package '%s'",
            infotypename(a), a->name, a->package, state->package);
    }


    if(a->kind != INFOTYPE_CLASS) {
        MULTINAME(m, a);
        x.c = abc_findpropstrict2(x.c, &m);
        x.c = abc_getproperty2(x.c, &m);
        if(a->kind == INFOTYPE_METHOD) {
            methodinfo_t*f = (methodinfo_t*)a;
            x.t = TYPE_FUNCTION(f);
        } else {
            varinfo_t*v = (varinfo_t*)a;
            x.t = v->type;
        }
        return x;
    } else {
        if(state->cls && state->method == state->cls->static_init) {
            /* we're in the static initializer. 
               record the fact that we're using this class here */
            parsedclass_add_dependency(state->cls->dependencies, (classinfo_t*)a);
        }
        classinfo_t*c = (classinfo_t*)a;
        //if(c->slot) {
        if(0) { //Error #1026: Slot 1 exceeds slotCount=0 of global
            x.c = abc_getglobalscope(x.c);
            x.c = abc_getslot(x.c, c->slot);
        } else {
            MULTINAME(m, c);
            x.c = abc_getlex2(x.c, &m);
        }
        x.t = TYPE_CLASS(c);
    }
    return x;
}


char is_break_or_jump(code_t*c)
{
    if(!c)
        return 0;
    if(c->opcode == OPCODE_JUMP ||
       c->opcode == OPCODE___BREAK__ ||
       c->opcode == OPCODE___CONTINUE__ ||
       c->opcode == OPCODE_THROW ||
       c->opcode == OPCODE_RETURNVOID ||
       c->opcode == OPCODE_RETURNVALUE) {
       return 1;
    }
    return 0;
}

#define IS_FINALLY_TARGET(op) \
        ((op) == OPCODE___CONTINUE__ || \
         (op) == OPCODE___BREAK__ || \
         (op) == OPCODE_RETURNVOID || \
         (op) == OPCODE_RETURNVALUE || \
         (op) == OPCODE___RETHROW__)

static code_t* insert_finally_lookup(code_t*c, code_t*finally, int tempvar)
{
#define NEED_EXTRA_STACK_ARG
    code_t*finally_label = abc_nop(0);
    NEW(lookupswitch_t, l);
    //_lookupswitch

    code_t*i = c;
    int count=0;
    while(i) {
        code_t*prev = i->prev;
        if(IS_FINALLY_TARGET(i->opcode)) {
           code_t*p = prev;
           char needvalue=0;
           if(i->opcode == OPCODE___RETHROW__ ||
              i->opcode == OPCODE_RETURNVALUE) {
               if(i->opcode == OPCODE___RETHROW__)
                 i->opcode = OPCODE_THROW;
               needvalue=1;
               p = abc_coerce_a(p);
               p = abc_setlocal(p, tempvar);
           }
           p = abc_pushbyte(p, count++);
           p = abc_jump(p, finally_label);
           code_t*target = p = abc_label(p);
#ifdef NEED_EXTRA_STACK_ARG
           p = abc_pop(p);
#endif
           if(needvalue) {
               p = abc_getlocal(p, tempvar);
           }

           p->next = i;i->prev = p;
           list_append(l->targets, target);
        }
        i = prev;
    }

    code_t*j,*f;
    c = abc_pushbyte(c, -1);
    c = code_append(c, finally_label);
    c = code_append(c, finally);

#ifdef NEED_EXTRA_STACK_ARG
    c = abc_dup(c);
#endif
    c = abc_lookupswitch(c, l);
    c = l->def = abc_label(c);
#ifdef NEED_EXTRA_STACK_ARG
    c = abc_pop(c);
#endif

    return c;
}

static code_t* insert_finally_simple(code_t*c, code_t*finally, int tempvar)
{
    code_t*i = c;
    while(i) {
        code_t*prev = i->prev;
        if(IS_FINALLY_TARGET(i->opcode)) {
           if(i->opcode == OPCODE___RETHROW__)
                i->opcode = OPCODE_THROW;
           code_t*end = code_dup(finally);
           code_t*start = code_start(end);
           if(prev) prev->next = start;
           start->prev = prev;
           i->prev = end;
           end->next = i;
        }
        i = prev;
    }
    return code_append(c, finally);
}

code_t* insert_finally(code_t*c, code_t*finally, int tempvar)
{
    if(!finally)
        return c;
    code_t*i = c;
    char cantdup=0;
    int num_insertion_points=0;
    while(i) {
        if(IS_FINALLY_TARGET(i->opcode))
            num_insertion_points++;
        i = i->prev;
    }
    i = finally;
    int code_size=0;
    while(i) {
        code_size++;
        if(i->branch || i->opcode == OPCODE_LOOKUPSWITCH) {
            cantdup=1;
        }
        i = i->prev;
    }
    int simple_version_cost = (1+num_insertion_points)*code_size;
    int lookup_version_cost = 4*num_insertion_points + 5;

    if(cantdup || simple_version_cost > lookup_version_cost) {
        //printf("(use lookup) simple=%d > lookup=%d\n", simple_version_cost, lookup_version_cost);
        return insert_finally_lookup(c, finally, tempvar);
    } else {
        //printf("(use simple) simple=%d < lookup=%d\n", simple_version_cost, lookup_version_cost);
        return insert_finally_simple(c, finally, tempvar);
    }
}

#define PASS1 }} if(as3_pass == 1) {{
#define PASS1END }} if(as3_pass == 2) {{
#define PASS2 }} if(as3_pass == 2) {{
#define PASS12 }} if(as3_pass == 1 || as3_pass == 2) {{
#define PASS12END }} if(as3_pass == 2) {{
#define PASS_ALWAYS }} {{

%}

%%

/* ------------ code blocks / statements ---------------- */

PROGRAM: MAYBE_PROGRAM_CODE_LIST

MAYBE_PROGRAM_CODE_LIST: | PROGRAM_CODE_LIST 
PROGRAM_CODE_LIST: PROGRAM_CODE 
                 | PROGRAM_CODE_LIST PROGRAM_CODE

PROGRAM_CODE: PACKAGE_DECLARATION 
            | INTERFACE_DECLARATION 
            | CLASS_DECLARATION
            | FUNCTION_DECLARATION
            | SLOT_DECLARATION
            | PACKAGE_INITCODE
            | CONDITIONAL_COMPILATION '{' MAYBE_PROGRAM_CODE_LIST '}' {PASS_ALWAYS as3_pass=$1;}
            | ';'

MAYBE_INPACKAGE_CODE_LIST: | INPACKAGE_CODE_LIST
INPACKAGE_CODE_LIST: INPACKAGE_CODE 
                   | INPACKAGE_CODE_LIST INPACKAGE_CODE

INPACKAGE_CODE: INTERFACE_DECLARATION 
              | CLASS_DECLARATION
              | FUNCTION_DECLARATION
              | SLOT_DECLARATION
              | PACKAGE_INITCODE
              | CONDITIONAL_COMPILATION '{' MAYBE_INPACKAGE_CODE_LIST '}' {PASS_ALWAYS as3_pass=$1;}
              | '[' EMBED_START E ']' {PASS_ALWAYS as3_pass=$2;PASS1 as3_warning("embed command ignored");}
              | ';'

MAYBECODE: CODE {$$=$1;}
MAYBECODE: {$$=code_new();}

CODE: CODE CODEPIECE {
    $$=code_append($1,$2);
}
CODE: CODEPIECE {$$=$1;}

// code which may appear outside of methods
CODE_STATEMENT: DEFAULT_NAMESPACE 
CODE_STATEMENT: IMPORT 
CODE_STATEMENT: FOR 
CODE_STATEMENT: FOR_IN 
CODE_STATEMENT: WHILE 
CODE_STATEMENT: DO_WHILE 
CODE_STATEMENT: SWITCH 
CODE_STATEMENT: IF
CODE_STATEMENT: WITH
CODE_STATEMENT: TRY
CODE_STATEMENT: VOIDEXPRESSION 
CODE_STATEMENT: USE_NAMESPACE
CODE_STATEMENT: NAMESPACE_DECLARATION
CODE_STATEMENT: '{' CODE '}' {$$=$2;}
CODE_STATEMENT: '{' '}' {$$=0;}

// code which may appear in methods (includes the above)
CODEPIECE: ';' {$$=0;}
CODEPIECE: CODE_STATEMENT
CODEPIECE: VARIABLE_DECLARATION
CODEPIECE: BREAK
CODEPIECE: CONTINUE
CODEPIECE: RETURN
CODEPIECE: THROW
CODEPIECE: CONDITIONAL_COMPILATION '{' CODE '}' {
    PASS_ALWAYS 
    if(as3_pass) {
        $$ = $3;
    } else {
        $$ = 0;
    }
    as3_pass=$1;
}

//CODEBLOCK :  '{' CODE '}' {$$=$2;}
//CODEBLOCK :  '{' '}'      {$$=0;}
CODEBLOCK :  CODEPIECE ';'             {$$=$1;}
CODEBLOCK :  CODEPIECE %prec below_semicolon {$$=$1;}

/* ------------ package init code ------------------- */

PACKAGE_INITCODE: CODE_STATEMENT {
    if($1) {
        if(!global->init) 
            global->init = abc_initscript(global->file);
        code_t**cc = &global->init->method->body->code;
        *cc = code_append(*cc, $1);
    }
}

/* ------------ embed code ------------- */

EMBED_START: %prec above_function {
    PASS_ALWAYS
    $$ = as3_pass;
    as3_pass=0;
}

/* ------------ conditional compilation ------------- */

CONDITIONAL_COMPILATION: T_IDENTIFIER "::" T_IDENTIFIER {
    PASS12
    $$=as3_pass;
    char*key = concat3($1,"::",$3);
    if(!definitions || !dict_contains(definitions, key)) {
        as3_pass=0;
    }
    free(key);
}

/* ------------ variables --------------------------- */

%code {
    char is_subtype_of(classinfo_t*type, classinfo_t*supertype)
    {
        return 1; // FIXME
    }
    char do_init_variable(char*name)
    {
        if(!state->method->no_variable_scoping)
            return 0;
        if(!state->new_vars)
            return 1;
        return 1;
    }
};

MAYBEEXPRESSION : '=' E {$$=$2;}
                |       {$$=mkdummynode();}

VARIABLE_DECLARATION : "var" VARIABLE_LIST {$$=$2;}
VARIABLE_DECLARATION : "const" VARIABLE_LIST {$$=$2;}

VARIABLE_LIST: ONE_VARIABLE                   {$$ = $1;}
VARIABLE_LIST: VARIABLE_LIST ',' ONE_VARIABLE {$$ = code_append($1, $3);}

ONE_VARIABLE: T_IDENTIFIER MAYBETYPE MAYBEEXPRESSION
{
PASS12
    if(variable_exists($1)) 
        syntaxerror("Variable %s already defined", $1);
PASS1
    new_variable(state->method, $1, 0, 1, 0);
PASS2
   
    char slot = 0;
    int index = 0;
    variable_t*v = 0;
    if(state->method->uses_slots) {
        v = find_slot(state->method, $1);
        if(v && !v->init) {
            // this variable is stored in a slot
            v->init = 1;
            v->type = $2;
            slot = 1;
        }
    }
    if(!v) {
        v = new_variable2(state->method, $1, $2, 1, 0);
    }

    $$ = slot?abc_getscopeobject(0, 1):0;
    
    typedcode_t val = node_read($3);
    if(!is_subtype_of(val.t, $2)) {
        syntaxerror("Can't convert %s to %s", val.t->name, $2->name);
    }
    if($2) {
        if(val.c->prev || val.c->opcode != OPCODE_PUSHUNDEFINED) {
            $$ = code_append($$, val.c);
            $$ = converttype($$, val.t, $2);
        } else {
            code_free(val.c);
            $$ = defaultvalue($$, $2);
        }
    } else {
        if(val.c->prev || val.c->opcode != OPCODE_PUSHUNDEFINED) {
            $$ = code_append($$, val.c);
            $$ = abc_coerce_a($$);
        } else {
            // don't do anything
            code_free(val.c);
            code_free($$);
            $$ = 0;
            break;
        }
    }
    if(slot) {
        $$ = abc_setslot($$, v->index);
    } else {
        $$ = abc_setlocal($$, v->index);
        v->init = do_init_variable($1);
    }
}

/* ------------ control flow ------------------------- */

IF_CODEBLOCK: {PASS12 new_state();} CODEBLOCK {
    $$ = var_block($2, state->vars);
    PASS12 old_state();
}
MAYBEELSE:  %prec below_else {$$ = code_new();}
MAYBEELSE: "else" IF_CODEBLOCK {$$=$2;}
//MAYBEELSE: ';' "else" CODEBLOCK {$$=$3;}

IF : "if" '(' EXPRESSION ')' IF_CODEBLOCK MAYBEELSE {
    $$ = code_new();
    $$ = code_append($$, $3.c);
    code_t*myjmp,*myif = $$ = abc_iffalse($$, 0);
   
    $$ = code_append($$, $5);
    if($6) {
        myjmp = $$ = abc_jump($$, 0);
    }
    myif->branch = $$ = abc_nop($$);
    if($6) {
        $$ = code_append($$, $6);
        myjmp->branch = $$ = abc_nop($$);
    }
}

FOR_INIT : {$$=code_new();}
FOR_INIT : VARIABLE_DECLARATION
FOR_INIT : VOIDEXPRESSION

// TODO: why doesn't an %prec above_identifier resolve the r-r conflict here?
//       (I don't see any easy way to revolve this conflict otherwise, as we
//        can't touch VAR_READ without upsetting the precedence about "return")
FOR_IN_INIT : "var" T_IDENTIFIER MAYBETYPE {
    PASS1 $$=$2;new_variable(state->method, $2,0,1,0);
    PASS2 $$=$2;new_variable(state->method, $2,$3,1,0);
}
FOR_IN_INIT : T_IDENTIFIER {
    PASS12
    $$=$1;
}

FOR_START : T_FOR '(' {PASS12 new_state();$$.name=$1;$$.each=0;}
FOR_START : T_FOR "each" '(' {PASS12 new_state();$$.name=$1;$$.each=1;}

FOR : FOR_START FOR_INIT ';' EXPRESSION ';' VOIDEXPRESSION ')' IF_CODEBLOCK {
    if($1.each) syntaxerror("invalid syntax: ; not allowed in for each statement");
    $$ = code_new();
    $$ = code_append($$, $2);
    code_t*loopstart = $$ = abc_label($$);
    $$ = code_append($$, $4.c);
    code_t*myif = $$ = abc_iffalse($$, 0);
    $$ = code_append($$, $8);
    code_t*cont = $$ = abc_nop($$);
    $$ = code_append($$, $6);
    $$ = abc_jump($$, loopstart);
    code_t*out = $$ = abc_nop($$);
    breakjumpsto($$, $1.name, out);
    continuejumpsto($$, $1.name, cont);
    myif->branch = out;

    $$ = var_block($$, state->vars);
    PASS12 old_state();
}

FOR_IN : FOR_START FOR_IN_INIT "in" EXPRESSION ')' IF_CODEBLOCK {
    variable_t*var = find_variable(state, $2);
    if(!var) {
        syntaxerror("variable %s not known in this scope", $2);
    }
    int it = alloc_local();
    int array = alloc_local();

    $$ = code_new();
    $$ = code_append($$, $4.c);
    $$ = abc_coerce_a($$);
    $$ = abc_setlocal($$, array);
    $$ = abc_pushbyte($$, 0);
    $$ = abc_setlocal($$, it);

    code_t*loopstart = $$ = abc_label($$);
    
    $$ = abc_hasnext2($$, array, it);
    code_t*myif = $$ = abc_iffalse($$, 0);
    $$ = abc_getlocal($$, array);
    $$ = abc_getlocal($$, it);
    if(!$1.each)
        $$ = abc_nextname($$);
    else
        $$ = abc_nextvalue($$);
    $$ = converttype($$, 0, var->type);
    $$ = abc_setlocal($$, var->index);

    $$ = code_append($$, $6);
    $$ = abc_jump($$, loopstart);
    
    code_t*out = $$ = abc_nop($$);
    breakjumpsto($$, $1.name, out);
    continuejumpsto($$, $1.name, loopstart);
    
    myif->branch = out;

    $$ = abc_kill($$, it);
    $$ = abc_kill($$, array);

    $$ = var_block($$, state->vars);
    PASS12 old_state();
}

WHILE : T_WHILE '(' EXPRESSION ')' IF_CODEBLOCK {

    $$ = code_new();

    code_t*myjmp = $$ = abc_jump($$, 0);
    code_t*loopstart = $$ = abc_label($$);
    $$ = code_append($$, $5);
    code_t*cont = $$ = abc_nop($$);
    myjmp->branch = cont;
    $$ = code_append($$, $3.c);
    $$ = abc_iftrue($$, loopstart);
    code_t*out = $$ = abc_nop($$);
    breakjumpsto($$, $1, out);
    continuejumpsto($$, $1, cont);
}

DO_WHILE : T_DO IF_CODEBLOCK "while" '(' EXPRESSION ')' {
    $$ = code_new();
    code_t*loopstart = $$ = abc_label($$);
    $$ = code_append($$, $2);
    code_t*cont = $$ = abc_nop($$);
    $$ = code_append($$, $5.c);
    $$ = abc_iftrue($$, loopstart);
    code_t*out = $$ = abc_nop($$);
    breakjumpsto($$, $1, out);
    continuejumpsto($$, $1, cont);
}

BREAK : "break" %prec prec_none {
    $$ = abc___break__(0, "");
}
BREAK : "break" T_IDENTIFIER {
    $$ = abc___break__(0, $2);
}
CONTINUE : "continue" %prec prec_none {
    $$ = abc___continue__(0, "");
}
CONTINUE : "continue" T_IDENTIFIER {
    $$ = abc___continue__(0, $2);
}

MAYBE_CASE_LIST :           {$$=0;}
MAYBE_CASE_LIST : CASE_LIST {$$=$1;}
MAYBE_CASE_LIST : DEFAULT   {$$=$1;}
MAYBE_CASE_LIST : CASE_LIST DEFAULT {$$=code_append($1,$2);}
CASE_LIST: CASE             {$$=$1;}
CASE_LIST: CASE_LIST CASE   {$$=code_append($$,$2);}

CASE: "case" E ':' MAYBECODE {
    $$ = abc_getlocal(0, state->switch_var);
    $$ = code_append($$, node_read($2).c);
    code_t*j = $$ = abc_ifne($$, 0);
    $$ = code_append($$, $4);
    if($$->opcode != OPCODE___BREAK__) {
        $$ = abc___fallthrough__($$, "");
    }
    code_t*e = $$ = abc_nop($$);
    j->branch = e;
}
DEFAULT: "default" ':' MAYBECODE {
    $$ = $3;
}
SWITCH : T_SWITCH '(' {PASS12 new_state();state->switch_var=alloc_local();} E ')' '{' MAYBE_CASE_LIST '}' {
    $$ = node_read($4).c;
    $$ = abc_setlocal($$, state->switch_var);
    $$ = code_append($$, $7);

    code_t*out = $$ = abc_kill($$, state->switch_var);
    breakjumpsto($$, $1, out);
    
    code_t*c = $$,*lastblock=0;
    while(c) {
        if(c->opcode == OPCODE_IFNE) {
            if(!c->next) syntaxerror("internal error in fallthrough handling");
            lastblock=c->next;
        } else if(c->opcode == OPCODE___FALLTHROUGH__) {
            if(lastblock) {
                c->opcode = OPCODE_JUMP;
                c->branch = lastblock;
            } else {
                /* fall through end of switch */
                c->opcode = OPCODE_NOP;
            }
        }
        c=c->prev;
    }
   
    $$ = var_block($$, state->vars);
    PASS12 old_state();
}

/* ------------ try / catch /finally ---------------- */

CATCH: "catch" '(' T_IDENTIFIER MAYBETYPE ')' {PASS12 new_state();
                                                      state->exception_name=$3;
                                               PASS1 new_variable(state->method, $3, 0, 0, 0);
                                               PASS2 new_variable(state->method, $3, $4, 0, 0);
                                              } 
        '{' MAYBECODE '}' {
    namespace_t name_ns = {ACCESS_PACKAGE, ""};
    multiname_t name = {QNAME, &name_ns, 0, $3};
    
    NEW(abc_exception_t, e)
    e->exc_type = sig2mname($4);
    e->var_name = multiname_clone(&name);
    $$ = e;

    code_t*c = 0;
    int i = find_variable_safe(state, $3)->index;
    e->target = c = abc_nop(0);
    c = abc_setlocal(c, i);
    c = code_append(c, code_dup(state->method->scope_code));
    c = code_append(c, $8);
    c = abc_kill(c, i);

    c = var_block(c, state->vars);
    PASS12 old_state();
}
FINALLY: "finally" '{' {PASS12 new_state();state->exception_name=0;} MAYBECODE '}' {
    $4 = var_block($4, state->vars);
    if(!$4) {
        $$=0;
    } else {
        NEW(abc_exception_t, e)
        e->exc_type = 0; //all exceptions
        e->var_name = 0; //no name
        e->target = 0;
        e->to = abc_nop(0);
        e->to = code_append(e->to, $4);
        $$ = e;
    }
    PASS12 old_state();
}

CATCH_LIST: CATCH {$$.l=list_new();$$.finally=0;list_append($$.l,$1);}
CATCH_LIST: CATCH_LIST CATCH {$$=$1;list_append($$.l,$2);}
CATCH_FINALLY_LIST: CATCH_LIST {$$=$1;}
CATCH_FINALLY_LIST: CATCH_LIST FINALLY {
    $$ = $1;
    $$.finally = 0;
    if($2) {
        list_append($$.l,$2);
        $$.finally = $2->to;$2->to=0;
    }
}
CATCH_FINALLY_LIST: FINALLY {
    $$.l=list_new();
    $$.finally = 0;
    if($1) {
        list_append($$.l,$1);
        $$.finally = $1->to;$1->to=0;
    }
}

TRY : "try" '{' {PASS12 new_state();
                 state->method->has_exceptions=1;
                 state->method->late_binding=1;//for invariant scope_code
                } MAYBECODE '}' CATCH_FINALLY_LIST {
    code_t*out = abc_nop(0);

    code_t*start = abc_nop(0);
    $$ = code_append(start, $4);
    if(!is_break_or_jump($4)) {
        $$ = abc_jump($$, out);
    }
    code_t*end = $$ = abc_nop($$);
  
    int tmp;
    if($6.finally)
        tmp = alloc_local();
    
    abc_exception_list_t*l = $6.l;
    int count=0;
    while(l) {
        abc_exception_t*e = l->abc_exception;
        if(e->var_name) {
            $$ = code_append($$, e->target);
            $$ = abc_jump($$, out);
        } else {
            parserassert((ptroff_t)$6.finally);
            // finally block
            e->target = $$ = abc_nop($$);
            $$ = code_append($$, code_dup(state->method->scope_code));
            $$ = abc___rethrow__($$);
        }
        
        e->from = start;
        e->to = end;

        l = l->next;
    }
    $$ = code_append($$, out);

    $$ = insert_finally($$, $6.finally, tmp);
        
    list_concat(state->method->exceptions, $6.l);
   
    $$ = var_block($$, state->vars);
    PASS12 old_state();
}

/* ------------ throw ------------------------------- */

THROW : "throw" EXPRESSION {
    $$=$2.c;
    $$=abc_throw($$);
}
THROW : "throw" %prec prec_none {
    if(!state->exception_name)
        syntaxerror("re-throw only possible within a catch block");
    variable_t*v = find_variable(state, state->exception_name);
    $$=code_new();
    $$=abc_getlocal($$, v->index);
    $$=abc_throw($$);
}

/* ------------ with -------------------------------- */

WITH_HEAD : "with" '(' EXPRESSION ')' {
     new_state();
     if(state->method->has_exceptions) {
         int v = alloc_local();
         state->method->scope_code = abc_getlocal(state->method->scope_code, v);
         state->method->scope_code = abc_pushwith(state->method->scope_code);
         $$.number = v;
     }
     $$.cc = $3.c;
} 
WITH : WITH_HEAD CODEBLOCK {
     /* remove getlocal;pushwith from scope code again */
     state->method->scope_code = code_cutlast(code_cutlast(state->method->scope_code));

     $$ = $1.cc;
     if(state->method->has_exceptions) {
         $$ = abc_dup($$);
         $$ = abc_setlocal($$, $1.number);
     }
     $$ = abc_pushwith($$);
     $$ = code_append($$, $2);
     $$ = abc_popscope($$);
     old_state();
}

/* ------------ packages and imports ---------------- */

X_IDENTIFIER: T_IDENTIFIER
            | "package" {PASS12 $$="package";}
            | "namespace" {PASS12 $$="namespace";}
            | "NaN" {PASS12 $$="NaN";}
            | T_NAMESPACE {PASS12 $$=$1;}

PACKAGE: PACKAGE '.' X_IDENTIFIER {PASS12 $$ = concat3($1,".",$3);free($1);$1=0;}
PACKAGE: X_IDENTIFIER             {PASS12 $$=strdup($1);}

PACKAGE_DECLARATION : "package" PACKAGE '{' {PASS12 startpackage($2);free($2);$2=0;}
                                MAYBE_INPACKAGE_CODE_LIST '}' {PASS12 endpackage();$$=0;}
PACKAGE_DECLARATION : "package" '{' {PASS12 startpackage("");} 
                                MAYBE_INPACKAGE_CODE_LIST '}' {PASS12 endpackage();$$=0;}

%code {
    static void state_has_imports()
    {
        state->wildcard_imports = list_clone(state->wildcard_imports);
        state->imports = dict_clone(state->imports);
        state->has_own_imports = 1;
    }
    static void import_toplevel(const char*package)
    {
        char* s = strdup(package);
        while(1) {
            dict_put(state->import_toplevel_packages, s, 0);
            char*x = strrchr(s, '.');
            if(!x)
                break;
            *x = 0;
        }
        free(s);
    }
};

IMPORT : "import" T_IDENTIFIER {
       PASS12
       slotinfo_t*s = registry_find(state->package, $2);
       if(!s && as3_pass==1) {as3_schedule_class(state->package, $2);}
       state_has_imports();
       dict_put(state->imports, state->package, $2);
       $$=0;
}
IMPORT : "import" PACKAGEANDCLASS {
       PASS12
       slotinfo_t*s = registry_find($2->package, $2->name);
       if(!s && as3_pass==1) {// || !(s->flags&FLAG_BUILTIN)) {
           as3_schedule_class($2->package, $2->name);
       }
       state_has_imports();
       dict_put(state->imports, $2->name, $2);
       import_toplevel($2->package);
       $$=0;
}
IMPORT : "import" PACKAGE '.' '*' {
       PASS12
       if(strncmp("flash.", $2, 6) && as3_pass==1) {
           as3_schedule_package($2);
       }

       NEW(import_t,i);
       i->package = $2;
       state_has_imports();
       list_append(state->wildcard_imports, i);
       import_toplevel(i->package);
       $$=0;
}

/* ------------ classes and interfaces (header) -------------- */

MAYBE_MODIFIERS : %prec above_function {PASS12 $$.flags=0;$$.ns=0;}
MAYBE_MODIFIERS : MODIFIER_LIST        {PASS12 $$=$1;}
MODIFIER_LIST : MODIFIER               {PASS12 $$=$1;}
MODIFIER_LIST : MODIFIER_LIST MODIFIER {
    PASS12 
    $$.flags=$1.flags|$2.flags;
    if($1.ns && $2.ns) syntaxerror("only one namespace allowed in one declaration");
    $$.ns=$1.ns?$1.ns:$2.ns;

}
MODIFIER : KW_PUBLIC {PASS12 $$.flags=FLAG_PUBLIC;$$.ns=0;}
         | KW_PRIVATE {PASS12 $$.flags=FLAG_PRIVATE;$$.ns=0;}
         | KW_PROTECTED {PASS12 $$.flags=FLAG_PROTECTED;$$.ns=0;}
         | KW_STATIC {PASS12 $$.flags=FLAG_STATIC;$$.ns=0;}
         | KW_DYNAMIC {PASS12 $$.flags=FLAG_DYNAMIC;$$.ns=0;}
         | KW_FINAL {PASS12 $$.flags=FLAG_FINAL;$$.ns=0;}
         | KW_OVERRIDE {PASS12 $$.flags=FLAG_OVERRIDE;$$.ns=0;}
         | KW_NATIVE {PASS12 $$.flags=FLAG_NATIVE;$$.ns=0;}
         | KW_INTERNAL {PASS12 $$.flags=FLAG_PACKAGEINTERNAL;$$.ns=0;}
         | T_NAMESPACE {PASS12 $$.flags=FLAG_NAMESPACE;
                               $$.ns=$1;
                       }

EXTENDS : {PASS12 $$=0;}
EXTENDS : KW_EXTENDS CLASS_SPEC {PASS12 $$=$2;}

EXTENDS_LIST : {PASS12 $$=list_new();}
EXTENDS_LIST : KW_EXTENDS CLASS_SPEC_LIST {PASS12 $$=$2;}

IMPLEMENTS_LIST : {PASS12 $$=list_new();}
IMPLEMENTS_LIST : KW_IMPLEMENTS CLASS_SPEC_LIST {PASS12 $$=$2;}

CLASS_DECLARATION : MAYBE_MODIFIERS "class" T_IDENTIFIER 
                              EXTENDS IMPLEMENTS_LIST 
                              '{' {PASS12 startclass(&$1,$3,$4,$5);} 
                              MAYBE_CLASS_BODY 
                              '}' {PASS12 endclass();$$=0;}

INTERFACE_DECLARATION : MAYBE_MODIFIERS "interface" T_IDENTIFIER 
                              EXTENDS_LIST 
                              '{' {PASS12 $1.flags|=FLAG_INTERFACE;
                                          startclass(&$1,$3,0,$4);}
                              MAYBE_INTERFACE_BODY 
                              '}' {PASS12 endclass();$$=0;}

/* ------------ classes and interfaces (body) -------------- */

MAYBE_CLASS_BODY : 
MAYBE_CLASS_BODY : CLASS_BODY
CLASS_BODY : CLASS_BODY_ITEM
CLASS_BODY : CLASS_BODY CLASS_BODY_ITEM
CLASS_BODY_ITEM : ';'
CLASS_BODY_ITEM : CONDITIONAL_COMPILATION '{' MAYBE_CLASS_BODY '}' {PASS_ALWAYS as3_pass=$1;}
CLASS_BODY_ITEM : SLOT_DECLARATION
CLASS_BODY_ITEM : FUNCTION_DECLARATION

CLASS_BODY_ITEM : CODE_STATEMENT {
    code_t*c = state->cls->static_init->header;
    c = code_append(c, $1);  
    state->cls->static_init->header = c;
}

MAYBE_INTERFACE_BODY : 
MAYBE_INTERFACE_BODY : INTERFACE_BODY
INTERFACE_BODY : IDECLARATION
INTERFACE_BODY : INTERFACE_BODY IDECLARATION
IDECLARATION : ';'
IDECLARATION : "var" T_IDENTIFIER {
    syntaxerror("variable declarations not allowed in interfaces");
}
IDECLARATION : MAYBE_MODIFIERS "function" GETSET T_IDENTIFIER '(' MAYBE_PARAM_LIST ')' MAYBETYPE {
    PASS12
    $1.flags |= FLAG_PUBLIC;
    if($1.flags&(FLAG_PRIVATE|FLAG_PACKAGEINTERNAL|FLAG_PROTECTED)) {
        syntaxerror("invalid method modifiers: interface methods always need to be public");
    }
    startfunction(&$1,$3,$4,&$6,$8);
    endfunction(&$1,$3,$4,&$6,$8, 0);
    list_deep_free($6.list);
}

/* ------------ classes and interfaces (body, slots ) ------- */

%code {
    static int slotstate_varconst = 0;
    static modifiers_t*slotstate_flags = 0;
    static void setslotstate(modifiers_t* flags, int varconst)
    {
        slotstate_varconst = varconst;
        slotstate_flags = flags;
        if(state->cls) {
            if(flags) {
                if(flags->flags&FLAG_STATIC) {
                    state->method = state->cls->static_init;
                } else {
                    state->method = state->cls->init;
                }
            } else {
                // reset to "default" state (all in class code is static by default) */
                state->method = state->cls->static_init;
            }
        } else {
            parserassert(state->method);
        }
    }
    static trait_t* add_abc_slot(modifiers_t* modifiers, const char*name, multiname_t*m, code_t***c)
    {
        int flags = modifiers->flags;
        namespace_t ns = modifiers2access(modifiers);

        /* slot name */
        multiname_t mname = {QNAME, &ns, 0, name};
      
        trait_list_t**traits;
        code_t**code=0;
        if(!state->cls) {
            // global variable
            if(!global->init) global->init = abc_initscript(global->file);
            ns.name = state->package;
            traits = &global->init->traits;
            code = &global->init->method->body->code;
        } else if(flags&FLAG_STATIC) {
            // static variable
            traits = &state->cls->abc->static_traits;
            code = &state->cls->static_init->header;
        } else {
            // instance variable
            traits = &state->cls->abc->traits;
            code = &state->cls->init->header;
            
            if(ns.access == ACCESS_PROTECTED) {
                ns.name = concat3(state->cls->info->package,":",state->cls->info->name);
            }
        }
        if(c)
            *c = code;
        if(m) 
            *m = *multiname_clone(&mname);
            
        return trait_new_member(traits, 0, multiname_clone(&mname), 0);
    }
};

VARCONST: "var" | "const"

SLOT_DECLARATION: MAYBE_MODIFIERS VARCONST {PASS12 setslotstate(&$1,$2);} SLOT_LIST {PASS12 $$=$4;setslotstate(0, 0);}

SLOT_LIST: ONE_SLOT               {PASS12 $$=0;}
SLOT_LIST: SLOT_LIST ',' ONE_SLOT {PASS12 $$=0;}

ONE_SLOT: T_IDENTIFIER MAYBETYPE MAYBEEXPRESSION
{
PASS12
    int flags = slotstate_flags->flags;
    namespace_t ns = modifiers2access(slotstate_flags);

    if(as3_pass == 1) {

        varinfo_t* info = 0;
        if(state->cls) {
            memberinfo_t*i = registry_findmember(state->cls->info, ns.name, $1, 1);
            if(i) {
                check_override(i, flags);
            }
            info = varinfo_register_onclass(state->cls->info, ns.access, ns.name, $1);
        } else {
            slotinfo_t*i = registry_find(state->package, $1);
            if(i) {
                syntaxerror("package %s already contains '%s'", state->package, $1);
            }
            if(ns.name && ns.name[0]) {
                syntaxerror("namespaces not allowed on package-level variables");
            }
            info = varinfo_register_global(ns.access, state->package, $1);
        }

        info->type = $2;
        info->flags = flags;
        
        dict_put(global->token2info, (void*)(ptroff_t)as3_tokencount, info);
    }

    if(as3_pass == 2) {
        varinfo_t*info = dict_lookup(global->token2info, (void*)(ptroff_t)as3_tokencount);

        multiname_t mname;
        code_t**code;
        trait_t*t = add_abc_slot(slotstate_flags, $1, &mname, &code);

        if($2) {
            MULTINAME(m, $2);
            t->type_name = multiname_clone(&m);
        }
        info->slot = t->slot_id;
        
        /* workaround for "VerifyError: Error #1053: Illegal override of ::test2 in C1" 
           FIXME: is there a way to use slots and still don't have conflicting overrides?
        */
        info->slot = t->slot_id = 0;
       
        constant_t cval = $3->type->eval($3);
        if(cval.type!=CONSTANT_UNKNOWN) {
            /* compile time constant */
            t->value = malloc(sizeof(constant_t));
            memcpy(t->value, &cval, sizeof(constant_t));
            info->value = constant_clone(t->value);
        } else {
            typedcode_t v = node_read($3);
            /* initalization code (if needed) */
            code_t*c = 0;
            if(v.c && !is_pushundefined(v.c)) {
                c = abc_getlocal_0(c);
                c = code_append(c, v.c);
                c = converttype(c, v.t, $2);
                if(!t->slot_id) {
                    c = abc_initproperty2(c, &mname);
                } else {
                    c = abc_setslot(c, t->slot_id);
                }
            }
            *code = code_append(*code, c);
        }

        if(slotstate_varconst==KW_CONST) {
            t->kind= TRAIT_CONST;
            info->flags |= FLAG_CONST;
        }
    }

    $$=0;
}

/* ------------ constants -------------------------------------- */

MAYBECONSTANT: {$$=0;}
MAYBECONSTANT: '=' E {
  $$ = malloc(sizeof(constant_t));
  *$$ = node_eval($2);
  if($$->type == CONSTANT_UNKNOWN) {
    syntaxerror("can't evaluate default parameter value (needs to be a compile-time constant)");
  }
}

//CONSTANT : T_NAMESPACE {$$ = constant_new_namespace($1);}
CONSTANT : T_INT {$$ = constant_new_int($1);}
CONSTANT : T_UINT {
    $$ = constant_new_uint($1);
}
CONSTANT : T_FLOAT {$$ = constant_new_float($1);}
CONSTANT : T_STRING {$$ = constant_new_string2($1.str,$1.len);free((char*)$1.str);}
CONSTANT : "true" {$$ = constant_new_true($1);}
CONSTANT : "false" {$$ = constant_new_false($1);}
CONSTANT : "null" {$$ = constant_new_null($1);}
CONSTANT : "undefined" {$$ = constant_new_undefined($1);}
CONSTANT : KW_NAN {$$ = constant_new_float(__builtin_nan(""));}

/*CONSTANT : T_NAMESPACE {
    // TODO
    $$ = constant_new_namespace(namespace_new_namespace($1.url));
}*/

/* ---------------------------xml ------------------------------ */

%code {
    static int xml_level = 0;
};

XML: XMLNODE {
   multiname_t m = {QNAME, &stdns, 0, "XML"};
   typedcode_t v;
   v.c = 0;
   v.c = abc_getlex2(v.c, &m);
   v.c = code_append(v.c, node_read($1).c);
   v.c = abc_construct(v.c, 1);
   v.t = TYPE_XML;
   $$ = mkcodenode(v);
}

OPEN : '<' {PASS_ALWAYS if(!xml_level++) tokenizer_begin_xml();}
CLOSE : '>' {PASS_ALWAYS tokenizer_begin_xmltext();}
CLOSE2 : {PASS_ALWAYS if(!--xml_level) tokenizer_end_xml(); else tokenizer_begin_xmltext();}

XMLEXPR1 : '{' E {PASS_ALWAYS tokenizer_begin_xmltext();} '}' {
    $$ = $2;
}
XMLEXPR2 : '{' E {PASS_ALWAYS tokenizer_begin_xml();} '}' {
    $$ = $2;
}
XMLTEXT : {$$=mkstringnode("");}
XMLTEXT : XMLTEXT XMLEXPR1 {
    $$ = mkaddnode($1,$2);
}
XMLTEXT : XMLTEXT T_STRING {
    char* str = string_cstr(&$2);
    $$ = mkaddnode($1,mkstringnode(str));
    free(str);
}
XMLTEXT : XMLTEXT '>' {
    $$ = mkaddnode($1, mkstringnode(">"));
}
XML2 : XMLNODE XMLTEXT {
    $$ = mkaddnode($1,$2);
}
XML2 : XML2 XMLNODE XMLTEXT {
    $$ = mkaddnode($1, mkaddnode($2,$3));
}
XML_ID_OR_EXPR: T_IDENTIFIER {
    $$ = mkstringnode($1);
}
XML_ID_OR_EXPR: XMLEXPR2 {
    $$ = $1;
}

MAYBE_XMLATTRIBUTES: {
    $$ = mkstringnode("");
}
MAYBE_XMLATTRIBUTES: XMLATTRIBUTES {
    $$ = mkaddnode(mkstringnode(" "),$1);
}

XMLNODE : OPEN XML_ID_OR_EXPR MAYBE_XMLATTRIBUTES '/' CLOSE2 '>' {
    //$$ = allocprintf("<%s%s/>", $2, $3, $5, $8);
    $$ = mkaddnode(mkaddnode(mkaddnode(mkstringnode("<"),$2),$3),mkstringnode("/>"));
}
XMLNODE : OPEN XML_ID_OR_EXPR MAYBE_XMLATTRIBUTES CLOSE XMLTEXT '<' '/' XML_ID_OR_EXPR CLOSE2 '>' {
    //$$ = allocprintf("<%s%s>%s</%s>", $2, $3, $5, $8);
    $$ = mkaddnode(mkaddnode(mkaddnode(mkaddnode(mkaddnode(mkaddnode(mkaddnode(
         mkstringnode("<"),$2),$3),mkstringnode(">")),$5),mkstringnode("</")),$8),mkstringnode(">"));
}
XMLNODE : OPEN XML_ID_OR_EXPR MAYBE_XMLATTRIBUTES CLOSE XMLTEXT XML2 '<' '/' XML_ID_OR_EXPR CLOSE2 '>' {
    //$$ = allocprintf("<%s%s>%s%s</%s>", $2, $3, $5, $6, $9);
    $$ = mkaddnode(mkaddnode(mkaddnode(mkaddnode(mkaddnode(mkaddnode(mkaddnode(mkaddnode(
         mkstringnode("<"),$2),$3),mkstringnode(">")),$5),$6),mkstringnode("</")),$9),mkstringnode(">"));
}

XMLATTRIBUTES: XMLATTRIBUTE {
    $$ = $1;
}
XMLATTRIBUTES: XMLATTRIBUTES XMLATTRIBUTE {
    $$ = mkaddnode($1, mkaddnode(mkstringnode(" "),$2));
}
XMLATTRIBUTE: XMLEXPR2 {
    $$ = $1;
}
XMLATTRIBUTE: XMLEXPR2 '=' T_STRING {
    char* str = string_cstr(&$3);
    $$ = mkaddnode($1, mkstringnode(concat2("=",str)));
    free(str);
}
XMLATTRIBUTE: XMLEXPR2 '=' XMLEXPR2 {
    $$ = mkaddnode($1, mkaddnode(mkstringnode("=\""), mkaddnode($3, mkstringnode("\""))));
}
XMLATTRIBUTE: T_IDENTIFIER '=' XMLEXPR2 {
    $$ = mkaddnode(mkaddnode(mkstringnode(concat2($1,"=\"")), $3), mkstringnode("\""));
}
XMLATTRIBUTE: T_IDENTIFIER '=' T_STRING {
    char* str = string_cstr(&$3);
    $$=mkstringnode(allocprintf("%s=%s", $1,str));
    free(str);
    free($1);free((char*)$3.str);
}

/* ------------ classes and interfaces (body, functions) ------- */

// non-vararg version
MAYBE_PARAM_LIST: {
    PASS12
    memset(&$$,0,sizeof($$));
}
MAYBE_PARAM_LIST: PARAM_LIST {
    PASS12
    $$=$1;
}

// vararg version
MAYBE_PARAM_LIST: "..." PARAM {
    PASS12
    memset(&$$,0,sizeof($$));
    $$.varargs=1;
    list_append($$.list, $2);
}
MAYBE_PARAM_LIST: PARAM_LIST ',' "..." PARAM {
    PASS12
    $$ =$1;
    $$.varargs=1;
    list_append($$.list, $4);
}

// non empty
PARAM_LIST: PARAM_LIST ',' PARAM {
    PASS12
    $$ = $1;
    list_append($$.list, $3);
}
PARAM_LIST: PARAM {
    PASS12
    memset(&$$,0,sizeof($$));
    list_append($$.list, $1);
}

PARAM:  T_IDENTIFIER ':' TYPE MAYBECONSTANT {
     PASS12
     $$ = rfx_calloc(sizeof(param_t));
     $$->name=$1;
     $$->type = $3;
     PASS2
     $$->value = $4;
}
PARAM:  T_IDENTIFIER MAYBECONSTANT {
     PASS12
     $$ = rfx_calloc(sizeof(param_t));
     $$->name=$1;
     $$->type = TYPE_ANY;
     PASS2
     $$->value = $2;
}
GETSET : "get"
       | "set"
       | {PASS12 $$=0;}

FUNCTION_DECLARATION: MAYBE_MODIFIERS "function" GETSET T_IDENTIFIER '(' MAYBE_PARAM_LIST ')' 
                      MAYBETYPE '{' {PASS12 startfunction(&$1,$3,$4,&$6,$8);} MAYBECODE '}' 
{
    PASS1 
    endfunction(&$1,$3,$4,&$6,0,0);
    PASS2
    if(!state->method->info) syntaxerror("internal error");
    
    code_t*c = method_header(state->method);
    c = wrap_function(c, 0, $11);

    endfunction(&$1,$3,$4,&$6,$8,c);
    PASS12
    list_deep_free($6.list);
    $$=0;
}

MAYBE_IDENTIFIER: T_IDENTIFIER
MAYBE_IDENTIFIER: {PASS12 $$=0;}
INNERFUNCTION: "function" MAYBE_IDENTIFIER '(' MAYBE_PARAM_LIST ')' MAYBETYPE 
               '{' {PASS12 innerfunction($2,&$4,$6);} MAYBECODE '}'
{
    PASS1
    endfunction(0,0,$2,&$4,0,0);
    PASS2
    methodinfo_t*f = state->method->info;
    if(!f || !f->kind) syntaxerror("internal error");
    
    code_t*c = method_header(state->method);
    c = wrap_function(c, 0, $9);

    int index = state->method->var_index;
    endfunction(0,0,$2,&$4,$6,c);
    
    $$.c = abc_getlocal(0, index);
    $$.t = TYPE_FUNCTION(f);

    PASS12 list_deep_free($4.list);
}


/* ------------- package + class ids --------------- */

CLASS: X_IDENTIFIER {
    PASS1 NEW(unresolvedinfo_t,c);
          memset(c, 0, sizeof(*c));
          c->kind = INFOTYPE_UNRESOLVED;
          c->name = $1;
          c->package = get_package_from_name($1);
          if(!c->package) {
              c->nsset = get_current_imports();
              /* make the compiler look for this class in the current directory,
                 just in case: */
              as3_schedule_class_noerror(state->package, $1);
          }
          $$ = (classinfo_t*)c;
    PASS2
    slotinfo_t*s = find_class($1);
    if(!s) syntaxerror("Could not find class/method %s (current package: %s)\n", $1, state->package);
    $$ = (classinfo_t*)s;
}

PACKAGEANDCLASS : PACKAGE '.' X_IDENTIFIER {
    PASS1 NEW(unresolvedinfo_t,c);
          memset(c, 0, sizeof(*c));
          c->kind = INFOTYPE_UNRESOLVED;
          c->package = $1;
          c->name = $3;
          $$ = (classinfo_t*)c;
    PASS2
    slotinfo_t*s = registry_find($1, $3);
    if(!s) syntaxerror("Couldn't find class/method %s.%s\n", $1, $3);
    free($1);$1=0;
    $$ = (classinfo_t*)s;
}

CLASS_SPEC: PACKAGEANDCLASS
          | CLASS

CLASS_SPEC_LIST : CLASS_SPEC {PASS12 $$=list_new();list_append($$, $1);}
CLASS_SPEC_LIST : CLASS_SPEC_LIST ',' CLASS_SPEC {PASS12 $$=$1;list_append($$,$3);}

TYPE : CLASS_SPEC {PASS12 $$=$1;}
     | '*'        {PASS12 $$=TYPE_ANY;}
     | "void"     {PASS12 $$=TYPE_VOID;}
    /*
     |  "String"  {$$=registry_getstringclass();}
     |  "int"     {$$=registry_getintclass();}
     |  "uint"    {$$=registry_getuintclass();}
     |  "Boolean" {$$=registry_getbooleanclass();}
     |  "Number"  {$$=registry_getnumberclass();}
    */

MAYBETYPE: ':' TYPE {PASS12 $$=$2;}
MAYBETYPE:          {PASS12 $$=0;}

/* ----------function calls, delete, constructor calls ------ */

MAYBE_PARAM_VALUES :  %prec prec_none {$$.cc=0;$$.number=0;}
MAYBE_PARAM_VALUES : '(' MAYBE_EXPRESSION_LIST ')' {$$=$2;}

MAYBE_EXPRESSION_LIST : {$$.cc=0;$$.number=0;}
MAYBE_EXPRESSION_LIST : EXPRESSION_LIST
MAYBE_EXPRESSION_LIST : EXPRESSION_LIST_AND_COMMA

EXPRESSION_LIST : NONCOMMAEXPRESSION             {$$.number=1;
                                                  $$.cc = $1.c;
                                                 }

EXPRESSION_LIST_AND_COMMA: EXPRESSION_LIST ',' {$$ = $1;}
EXPRESSION_LIST : EXPRESSION_LIST_AND_COMMA NONCOMMAEXPRESSION {
                                                  $$.number= $1.number+1;
                                                  $$.cc = code_append($1.cc, $2.c);
                                                  }
               
XX : %prec new2
NEW : "new" E XX MAYBE_PARAM_VALUES {
    typedcode_t v = node_read($2);
    $$.c = v.c;
    if($$.c->opcode == OPCODE_COERCE_A) $$.c = code_cutlast($$.c);
    
    code_t*paramcode = $4.cc;
    if($$.c->opcode == OPCODE_GETPROPERTY) {
        multiname_t*name = $$.c->data[0];$$.c->data[0]=0;
        $$.c = code_cutlast($$.c);
        $$.c = code_append($$.c, paramcode);
        $$.c = abc_constructprop2($$.c, name, $4.number);
        multiname_destroy(name);
    } else if(TYPE_IS_CLASS(v.t) && v.t->data) {
        code_free($$.c);
        classinfo_t*c = v.t->data;
        MULTINAME(m, c);
        $$.c = abc_findpropstrict2(0, &m);
        $$.c = code_append($$.c, paramcode);
        $$.c = abc_constructprop2($$.c, &m, $4.number);
    /*} else if($$.c->opcode == OPCODE_GETSLOT) {
        int slot = (int)(ptroff_t)$$.c->data[0];
        trait_t*t = traits_find_slotid(state->cls->abc->traits,slot);//FIXME
        multiname_t*name = t->name;
        $$.c = code_cutlast($$.c);
        $$.c = code_append($$.c, paramcode);
        $$.c = abc_constructprop2($$.c, name, $4.number);*/
    } else {
        $$.c = code_append($$.c, paramcode);
        $$.c = abc_construct($$.c, $4.number);
    }
   
    $$.t = TYPE_ANY;
    if(TYPE_IS_CLASS(v.t) && v.t->data) {
        $$.t = v.t->data;
    } else {
        $$.c = abc_coerce_a($$.c);
        $$.t = TYPE_ANY;
    }
}

/* TODO: use abc_call (for calling local variables),
         abc_callstatic (for calling own methods) 
         call (for closures)
*/
FUNCTIONCALL : E '(' MAYBE_EXPRESSION_LIST ')' {
   
    typedcode_t v = node_read($1);
    $$.c = v.c;
    if($$.c->opcode == OPCODE_COERCE_A) {
        $$.c = code_cutlast($$.c);
    }
    code_t*paramcode = $3.cc;

    $$.t = TYPE_ANY;
    if($$.c->opcode == OPCODE_GETPROPERTY) {
        multiname_t*name = $$.c->data[0];$$.c->data[0]=0;
        $$.c = code_cutlast($$.c);
        $$.c = code_append($$.c, paramcode);
        $$.c = abc_callproperty2($$.c, name, $3.number);
        multiname_destroy(name);
/*    } else if($$.c->opcode == OPCODE_GETSLOT && $$.c->prev->opcode != OPCODE_GETSCOPEOBJECT) {
        int slot = (int)(ptroff_t)$$.c->data[0];
        trait_t*t = traits_find_slotid(state->cls->abc->traits,slot);
        if(t->kind!=TRAIT_METHOD) {
            //ok: flash allows to assign closures to members.
        }
        multiname_t*name = t->name;
        $$.c = code_cutlast($$.c);
        $$.c = code_append($$.c, paramcode);
        //$$.c = abc_callmethod($$.c, t->method, len); //#1051 illegal early access binding
        $$.c = abc_callproperty2($$.c, name, $3.number);*/
    } else if($$.c->opcode == OPCODE_GETSUPER) {
        multiname_t*name = $$.c->data[0];$$.c->data[0]=0;
        $$.c = code_cutlast($$.c);
        $$.c = code_append($$.c, paramcode);
        $$.c = abc_callsuper2($$.c, name, $3.number);
        multiname_destroy(name);
    } else {
        $$.c = abc_getglobalscope($$.c);
        $$.c = code_append($$.c, paramcode);
        $$.c = abc_call($$.c, $3.number);
    }
   
    if(TYPE_IS_FUNCTION(v.t) && v.t->data) {
        $$.t = ((methodinfo_t*)(v.t->data))->return_type;
    } else if(TYPE_IS_CLASS(v.t) && v.t->data) {
        // calling a class is like a typecast
        $$.t = (classinfo_t*)v.t->data;
    } else {
        $$.t = TYPE_ANY;
        $$.c = abc_coerce_a($$.c);
    }
}

FUNCTIONCALL : "super" '(' MAYBE_EXPRESSION_LIST ')' {
    if(!state->cls) syntaxerror("super() not allowed outside of a class");
    if(!state->method) syntaxerror("super() not allowed outside of a function");
    if(!state->method->is_constructor) syntaxerror("super() not allowed outside of a constructor");

    $$.c = code_new();
    $$.c = abc_getlocal_0($$.c);

    $$.c = code_append($$.c, $3.cc);
    /*
    this is dependent on the control path, check this somewhere else
    if(state->method->has_super)
        syntaxerror("constructor may call super() only once");
    */
    state->method->has_super = 1;

    $$.c = abc_constructsuper($$.c, $3.number);
    $$.c = abc_pushundefined($$.c);
    $$.t = TYPE_ANY;
}

DELETE: "delete" E {
    typedcode_t v = node_read($2);
    $$.c = v.c;
    if($$.c->opcode == OPCODE_COERCE_A) {
        $$.c = code_cutlast($$.c);
    }
    multiname_t*name = 0;
    if($$.c->opcode == OPCODE_GETPROPERTY) {
        $$.c->opcode = OPCODE_DELETEPROPERTY;
    } else if($$.c->opcode == OPCODE_GETSLOT) {
        int slot = (int)(ptroff_t)$$.c->data[0];
        multiname_t*name = traits_find_slotid(state->cls->abc->traits,slot)->name;
        $$.c = code_cutlast($$.c);
        $$.c = abc_deleteproperty2($$.c, name);
    } else {
        $$.c = abc_getlocal_0($$.c);
        MULTINAME_LATE(m, v.t?v.t->access:ACCESS_PACKAGE, "");
        $$.c = abc_deleteproperty2($$.c, &m);
    }
    $$.t = TYPE_BOOLEAN;
}

RETURN: "return" %prec prec_none {
    $$ = abc_returnvoid(0);
}
RETURN: "return" EXPRESSION {
    $$ = $2.c;
    $$ = abc_returnvalue($$);
}

// ----------------------- expression types -------------------------------------

NONCOMMAEXPRESSION : E %prec below_lt {
    $$ = node_read($1);
}
EXPRESSION : COMMA_EXPRESSION {
    $$ = node_read($1);
}
COMMA_EXPRESSION : E %prec below_lt {
    $$ = mkmultinode(&node_comma, $1);
}
COMMA_EXPRESSION : COMMA_EXPRESSION ',' E %prec below_lt {
    $$ = multinode_extend($1, $3);
}
VOIDEXPRESSION : E %prec below_minus { 
    $$ = node_exec($1); 
}
VOIDEXPRESSION : VOIDEXPRESSION ',' E %prec below_lt { 
    $$ = $1;
    $$ = code_append($$, node_exec($3)); 
}

MAYBE_DICT_EXPRPAIR_LIST : {$$.cc=0;$$.number=0;}
MAYBE_DICT_EXPRPAIR_LIST : DICT_EXPRPAIR_LIST {$$=$1;}

DICTLH: T_IDENTIFIER {$$=abc_pushstring(0,$1);}
DICTLH: T_STRING     {$$=abc_pushstring2(0,&$1);}
DICTLH: T_INT {syntaxerror("dictionary keys must be strings");}
DICTLH: T_UINT {syntaxerror("dictionary keys must be strings");}
DICTLH: T_FLOAT {syntaxerror("dictionary keys must be strings");}

DICT_EXPRPAIR_LIST : DICTLH ':' NONCOMMAEXPRESSION {
    $$.cc = 0;
    $$.cc = code_append($$.cc, $1);
    $$.cc = code_append($$.cc, $3.c);
    $$.number = 2;
}
DICT_EXPRPAIR_LIST : DICT_EXPRPAIR_LIST ',' DICTLH ':' NONCOMMAEXPRESSION {
    $$.cc = $1.cc;
    $$.number = $1.number+2;
    $$.cc = code_append($$.cc, $3);
    $$.cc = code_append($$.cc, $5.c);
}

// ----------------------- expression evaluation -------------------------------------

E : INNERFUNCTION %prec prec_none {$$ = mkcodenode($1);}
E : MEMBER %prec '.'              {$$ = mkcodenode($1);}
E : NEW                           {$$ = mkcodenode($1);}
E : DELETE                        {$$ = mkcodenode($1);}
E : FUNCTIONCALL                  {$$ = mkcodenode($1);}
E : VAR_READ %prec T_IDENTIFIER   {$$ = $1;}

E : CONSTANT { 
    $$ = mkconstnode($1);
}

E : XML {
    $$ = $1;
}

/* regexp */
E : T_REGEXP {
    typedcode_t v;
    v.c = 0;
    multiname_t m = {QNAME, &stdns, 0, "RegExp"};
    if(!$1.options) {
        v.c = abc_getlex2(v.c, &m);
        v.c = abc_pushstring(v.c, $1.pattern);
        v.c = abc_construct(v.c, 1);
    } else {
        v.c = abc_getlex2(v.c, &m);
        v.c = abc_pushstring(v.c, $1.pattern);
        v.c = abc_pushstring(v.c, $1.options);
        v.c = abc_construct(v.c, 2);
    }
    v.t = TYPE_REGEXP;
    $$ = mkcodenode(v);
}

E : KW_ARGUMENTS {
    PASS1
    state->method->need_arguments = 1;
    PASS2
    typedcode_t v;
    v.c = abc_getlocal(0, state->method->need_arguments);
    v.t = TYPE_ARRAY;
    $$ = mkcodenode(v);
}

/* array */
E : '[' MAYBE_EXPRESSION_LIST ']' {
    typedcode_t v;
    v.c = code_new();
    v.c = code_append(v.c, $2.cc);
    v.c = abc_newarray(v.c, $2.number);
    v.t = registry_getarrayclass();
    $$ = mkcodenode(v);
}

/* dictionary */
E : "{ (dictionary)" MAYBE_DICT_EXPRPAIR_LIST '}' {
    typedcode_t v;
    v.c = code_new();
    v.c = code_append(v.c, $2.cc);
    v.c = abc_newobject(v.c, $2.number/2);
    v.t = registry_getobjectclass();
    $$ =  mkcodenode(v);
}

E : E '<' E {$$ = mknode2(&node_lt,$1,$3);}
E : E '>' E {$$ = mknode2(&node_gt,$1,$3);}
E : E "<=" E {$$ = mknode2(&node_le,$1,$3);}
E : E ">=" E {$$ = mknode2(&node_ge,$1,$3);}
E : E "==" E {$$ = mknode2(&node_eqeq,$1,$3);}
E : E "===" E {$$ = mknode2(&node_eqeqeq,$1,$3);}
E : E "!==" E {$$ = mknode2(&node_noteqeq,$1,$3);}
E : E "!=" E {$$ = mknode2(&node_noteq,$1,$3);}
E : E "||" E {$$ = mknode2(&node_oror,$1,$3);}
E : E "&&" E {$$ = mknode2(&node_andand,$1,$3);}
E : '!' E    {$$ = mknode1(&node_not, $2);}
E : '~' E    {$$ = mknode1(&node_bitnot, $2);}
E : E '&' E {$$ = mknode2(&node_bitand, $1, $3);}
E : E '^' E {$$ = mknode2(&node_bitxor, $1, $3);}
E : E '|' E {$$ = mknode2(&node_bitor, $1, $3);}
E : E ">>" E {$$ = mknode2(&node_shr, $1, $3);}
E : E ">>>" E {$$ = mknode2(&node_ushr, $1, $3);}
E : E "<<" E {$$ = mknode2(&node_shl, $1, $3);}
E : E '/' E {$$ = mknode2(&node_div, $1, $3);}
E : E '%' E {$$ = mknode2(&node_mod, $1, $3);}
E : E '+' E {$$ = mknode2(&node_plus, $1, $3);}
E : E '-' E {$$ = mknode2(&node_minus, $1, $3);}
E : E '*' E {$$ = mknode2(&node_multiply, $1, $3);}
E : E "in" E {$$ = mknode2(&node_in, $1, $3);}
E : E "as" E {$$ = mknode2(&node_as, $1, $3);}
E : E "instanceof" E {$$ = mknode2(&node_instanceof, $1, $3);}
E : E "is" E {$$ = mknode2(&node_is, $1, $3);}
E : "typeof" E  {$$ = mknode1(&node_typeof, $2);}
E : "void" E {$$ = mknode1(&node_void, $2);}
E : "void" { $$ = mkconstnode(constant_new_undefined());}
E : '(' COMMA_EXPRESSION ')' { $$=$2;}
E : '-' E {$$ = mknode1(&node_neg, $2);}
E : E '[' E ']' {$$ = mknode2(&node_arraylookup, $1,$3);}
E : E "*=" E {$$ = mknode2(&node_muleq, $1, $3);}
E : E "%=" E {$$ = mknode2(&node_modeq, $1, $3);}
E : E "<<=" E {$$ = mknode2(&node_shleq, $1, $3);}
E : E ">>=" E {$$ = mknode2(&node_shreq, $1, $3);}
E : E ">>>=" E {$$ = mknode2(&node_ushreq, $1, $3);}
E : E "/=" E { $$ = mknode2(&node_diveq, $1, $3);}
E : E "|=" E { $$ = mknode2(&node_bitoreq, $1, $3);}
E : E "^=" E { $$ = mknode2(&node_bitxoreq, $1, $3);}
E : E "&=" E { $$ = mknode2(&node_bitandeq, $1, $3);}
E : E "+=" E { $$ = mknode2(&node_pluseq, $1, $3);}
E : E "-=" E { $$ = mknode2(&node_minuseq, $1, $3);}
E : E '=' E { $$ = mknode2(&node_assign, $1, $3);}
E : E '?' E ':' E %prec below_assignment { $$ = mknode3(&node_tenary, $1, $3, $5);}

E : E "++" { $$ = mknode1(&node_rplusplus, $1);}
E : E "--" { $$ = mknode1(&node_rminusminus, $1);}
E : "++" %prec plusplus_prefix E {$$ = mknode1(&node_lplusplus, $2); }
E : "--" %prec minusminus_prefix E {$$ = mknode1(&node_lminusminus, $2); }

E : "super" '.' T_IDENTIFIER 
           { if(!state->cls->info)
                  syntaxerror("super keyword not allowed outside a class");
              classinfo_t*t = state->cls->info->superclass;
              if(!t) t = TYPE_OBJECT;
              memberinfo_t*f = findmember_nsset(t, $3, 1);
              MEMBER_MULTINAME(m, f, $3);
              typedcode_t v;
              v.c = 0;
              v.c = abc_getlocal_0(v.c);
              v.c = abc_getsuper2(v.c, &m);
              v.t = slotinfo_gettype((slotinfo_t*)f);
              $$ = mkcodenode(v);
           }

E : '@' T_IDENTIFIER {
    typedcode_t v;
    multiname_t m = {MULTINAMEA, 0, &nopackage_namespace_set, $2};
    v.c = abc_getlex2(0, &m);
    v.t = TYPE_STRING;
    $$ = mkcodenode(v);
}

E : E '.' '(' {PASS12 new_state();state->xmlfilter=1;} E ')' {
    PASS1 old_state();
    PASS2
    typedcode_t v = node_read($1);
    typedcode_t w = node_read($5);
    code_t*c = 0;
    int index = alloc_local();
    int result = alloc_local();
    int tmp = alloc_local();
    int xml = alloc_local();
    
    c = code_append(c, v.c);
    c = abc_checkfilter(c);
    c = abc_coerce_a(c); //hasnext2 converts to *
    c = abc_setlocal(c, xml);
    multiname_t m = {QNAME, &stdns, 0, "XMLList"};
    c = abc_getlex2(c, &m);
    c = abc_construct(c, 0);
    c = abc_setlocal(c, result);
    c = abc_pushbyte(c, 0);
    c = abc_setlocal(c, index);
    code_t*jmp = c = abc_jump(c, 0);
    code_t*loop = c = abc_label(c);
    c = abc_getlocal(c, xml);
    c = abc_getlocal(c, index);
    c = abc_nextvalue(c);
    c = abc_dup(c);
    c = abc_setlocal(c, tmp);
    c = abc_pushwith(c);
    c = code_append(c, w.c);
    c = abc_popscope(c);
    code_t*b = c = abc_iffalse(c, 0);
    c = abc_getlocal(c, result);
    c = abc_getlocal(c, index);
    c = abc_getlocal(c, tmp);
    multiname_t m2 = {MULTINAMEL, 0, &nopackage_namespace_set, 0};
    c = abc_setproperty2(c, &m2);
    c = b->branch = jmp->branch = abc_nop(c);
    c = abc_kill(c, tmp);
    c = abc_hasnext2(c, xml, index);
    c = abc_iftrue(c, loop);
    c = abc_getlocal(c, result);
    c = abc_kill(c, xml);
    c = abc_kill(c, result);
    c = abc_kill(c, index);
    
    c = var_block(c, state->vars);
    old_state();
    typedcode_t r;
    r.c = c;
    r.t = TYPE_XMLLIST;
    $$ = mkcodenode(r);
}

ID_OR_NS : T_IDENTIFIER {$$=$1;}
ID_OR_NS : '*' {$$="*";}
ID_OR_NS : T_NAMESPACE {$$=(char*)$1;}
SUBNODE: X_IDENTIFIER
       | '*' {$$="*";}

/*
MAYBE_NS: T_IDENTIFIER "::" {$$=$1;}
        | T_NAMESPACE "::" {$$=(char*)$1;}
        | '*' "::" {$$="*";}
        | {$$=0;}*/

E : E '.' ID_OR_NS "::" SUBNODE {
    typedcode_t v = node_read($1);
    typedcode_t w = node_read(resolve_identifier($3));
    v.c = code_append(v.c, w.c);
    if(!TYPE_IS_NAMESPACE(w.t)) {
        as3_softwarning("%s might not be a namespace", $3);
    }
    v.c = converttype(v.c, w.t, TYPE_NAMESPACE);
    multiname_t m = {RTQNAME, 0, 0, $5};
    v.c = abc_getproperty2(v.c, &m);
    if(TYPE_IS_XML(v.t)) {
        v.t = TYPE_XMLLIST;
    } else {
        v.c = abc_coerce_a(v.c);
        v.t = TYPE_ANY;
    }
    $$ = mkcodenode(v);
}
E : E ".." SUBNODE {
    typedcode_t v = node_read($1);
    multiname_t m = {MULTINAME, 0, &nopackage_namespace_set, $3};
    v.c = abc_getdescendants2(v.c, &m);
    v.t = TYPE_XMLLIST;
    $$ = mkcodenode(v);
}
E : E '.' '[' E ']' {
    typedcode_t v = node_read($1);
    typedcode_t w = node_read($4);
    multiname_t m = {MULTINAMEL, 0, &nopackage_namespace_set, 0};
    v.c = code_append(v.c, w.c);
    v.c = converttype(w.c, w.t, TYPE_STRING);
    v.c = abc_getproperty2(v.c, &m);
    v.t = TYPE_XMLLIST;
    $$ = mkcodenode(v);
}

E : E '.' '@' SUBNODE {
    typedcode_t v = node_read($1);
    multiname_t m = {MULTINAMEA, 0, &nopackage_namespace_set, $4};
    v.c = abc_getproperty2(v.c, &m);
    v.t = TYPE_STRING;
    $$ = mkcodenode(v);
}
E : E ".." '@' SUBNODE {
    typedcode_t v = node_read($1);
    multiname_t m = {MULTINAMEA, 0, &nopackage_namespace_set, $4};
    v.c = abc_getdescendants2(v.c, &m);
    v.t = TYPE_STRING;
    $$ = mkcodenode(v);
}
E : E '.' '@' '[' E ']' {
    typedcode_t v = node_read($1);
    typedcode_t w = node_read($5);
    multiname_t m = {MULTINAMELA, 0, &nopackage_namespace_set, 0};
    v.c = code_append(v.c, w.c);
    v.c = converttype(w.c, w.t, TYPE_STRING);
    v.c = abc_getproperty2(v.c, &m);
    v.t = TYPE_STRING;
    $$ = mkcodenode(v);
}
E : E ".." '@' '[' E ']' {
    typedcode_t v = node_read($1);
    typedcode_t w = node_read($5);
    multiname_t m = {MULTINAMELA, 0, &nopackage_namespace_set, 0};
    v.c = code_append(v.c, w.c);
    v.c = converttype(w.c, w.t, TYPE_STRING);
    v.c = abc_getdescendants2(v.c, &m);
    v.t = TYPE_STRING;
    $$ = mkcodenode(v);
}

MEMBER : E '.' SUBNODE {
    typedcode_t v1 = node_read($1);
    $$.c = v1.c;
    classinfo_t*t = v1.t;
    char is_static = 0;
    if(TYPE_IS_CLASS(t) && t->data) {
        t = t->data;
        is_static = 1;
    }
    if(TYPE_IS_XML(t)) {
        multiname_t m = {MULTINAME, 0, &nopackage_namespace_set, $3};
        $$.c = abc_getproperty2($$.c, &m);
        $$.c = abc_coerce_a($$.c);
        $$.t = TYPE_XMLLIST;
    } else if(t) {
        if(t->subtype==INFOTYPE_UNRESOLVED) {
            syntaxerror("syntaxerror: trying to resolve property '%s' on incomplete object '%s'", $3, t->name);
        }
        memberinfo_t*f = findmember_nsset(t, $3, 1);
        char noslot = 0;
        if(f && !is_static != !(f->flags&FLAG_STATIC))
           noslot=1;
        if(f && f->slot && !noslot) {
            $$.c = abc_getslot($$.c, f->slot);
        } else {
            if(!f) {
                if(!TYPE_IS_XMLLIST(t)) {
                    as3_softwarning("Access of undefined property '%s' in %s", $3, t->name);
                }
            }
            MEMBER_MULTINAME(m, f, $3);
            $$.c = abc_getproperty2($$.c, &m);
        }
        /* determine type */
        $$.t = slotinfo_gettype((slotinfo_t*)f);
        if(!$$.t)
           $$.c = abc_coerce_a($$.c);
        
    } else if(v1.c && v1.c->opcode == OPCODE___PUSHPACKAGE__) {
        string_t*package = v1.c->data[0];
        char*package2 = concat3(package->str, ".", $3);

        slotinfo_t*a = registry_find(package->str, $3);
        if(a) {
            $$ = push_class(a);
        } else if(dict_contains(state->import_toplevel_packages, package2) ||
                  registry_ispackage(package2)) {
            $$.c = v1.c;
            $$.c->data[0] = string_new4(package2);
            $$.t = 0;
        } else {
            syntaxerror("couldn't resolve %s", package2);
        }
    } else {
        /* when resolving a property on an unknown type, we do know the
           name of the property (and don't seem to need the package), but
           we need to make avm2 try out all access modes */
        as3_softwarning("Resolving %s on unknown type", $3);
        multiname_t m = {MULTINAME, 0, &nopackage_namespace_set, $3};
        $$.c = abc_getproperty2($$.c, &m);
        $$.c = abc_coerce_a($$.c);
        $$.t = TYPE_ANY;
    }
}

%code {
    node_t* resolve_identifier(char*name)
    {
        typedcode_t o;
        o.t = 0;
        o.c = 0;

        slotinfo_t*a = 0;
        memberinfo_t*f = 0;

        variable_t*v;
        /* look at variables */
        if((v = find_variable(state, name))) {
            // name is a local variable
            o.c = abc_getlocal(o.c, v->index);
            o.t = v->type;
            return mkcodenode(o);
        }
        if((v = find_slot(state->method, name))) {
            o.c = abc_getscopeobject(o.c, 1);
            o.c = abc_getslot(o.c, v->index);
            o.t = v->type;
            return mkcodenode(o);
        }

        int i_am_static = state->method->is_static;

        /* look at current class' members */
        if(!state->method->inner && 
           !state->xmlfilter &&
            state->cls && 
            (f = findmember_nsset(state->cls->info, name, 1)))
        {
            // name is a member or attribute in this class
            int var_is_static = (f->flags&FLAG_STATIC);

            if(f->kind == INFOTYPE_VAR && (f->flags&FLAG_CONST)) {
                /* if the variable is a constant (and we know what is evaluates to), we
                   can just use the value itself */
                varinfo_t*v = (varinfo_t*)f;
                if(v->value) {
                    return mkconstnode(v->value);
                }
            }
           
            if(var_is_static >= i_am_static) {
                if(f->kind == INFOTYPE_METHOD) {
                    o.t = TYPE_FUNCTION(f);
                } else {
                    o.t = f->type;
                }

                if(var_is_static && !i_am_static) {
                /* access to a static member from a non-static location.
                   do this via findpropstrict:
                   there doesn't seem to be any non-lookup way to access
                   static properties of a class */
                    state->method->late_binding = 1;
                    o.t = f->type;
                    namespace_t ns = {f->access, f->package};
                    multiname_t m = {QNAME, &ns, 0, name};
                    o.c = abc_findpropstrict2(o.c, &m);
                    o.c = abc_getproperty2(o.c, &m);
                    return mkcodenode(o);
                } else if(f->slot>0) {
                    o.c = abc_getlocal_0(o.c);
                    o.c = abc_getslot(o.c, f->slot);
                    return mkcodenode(o);
                } else {
                    MEMBER_MULTINAME(m, f, name);
                    o.c = abc_getlocal_0(o.c);
                    o.c = abc_getproperty2(o.c, &m);
                    return mkcodenode(o);
                }
            }
        } 
        
        /* look at actual classes, in the current package and imported */
        if(!state->xmlfilter && (a = find_class(name))) {
            if(state->cls && state->cls->info == (classinfo_t*)a && i_am_static) {
                o.c = abc_getlocal_0(0);
                o.t = TYPE_CLASS((classinfo_t*)a);
            } else {
                o = push_class(a);
            }
            return mkcodenode(o);
        }

        /* look through package prefixes */
        if(!state->xmlfilter && 
           (dict_contains(state->import_toplevel_packages, name) || 
            registry_ispackage(name))) {
            o.c = abc___pushpackage__(o.c, name);
            o.t = 0;
            return mkcodenode(o); //?
        }

        /* unknown object, let the avm2 resolve it */
        if(1) {
            if(!state->method->inner && !state->xmlfilter) {
                /* we really should make inner functions aware of the class context */
                as3_warning("Couldn't resolve '%s', doing late binding", name);
            }
            state->method->late_binding = 1;
                    
            multiname_t m = {MULTINAME, 0, &nopackage_namespace_set, name};

            o.t = 0;
            o.c = abc_findpropstrict2(o.c, &m);
            o.c = abc_getproperty2(o.c, &m);
            return mkcodenode(o);
        }
    }
};

VAR_READ : T_IDENTIFIER {
    PASS1
    /* Queue unresolved identifiers for checking against the parent
       function's variables.
       We consider everything which is not a local variable "unresolved".
       This encompasses class names, members of the surrounding class
       etc. which is *correct* because local variables of the parent function
       would shadow those.
       */

    if(!find_variable(state, $1)) {
        unknown_variable($1);
        /* let the compiler know that it might want to check the current directory/package
           for this identifier- maybe there's a file $1.as defining $1. */
        as3_schedule_class_noerror(state->package, $1);
    }
   
    $$ = 0;
    PASS2

    $$ = resolve_identifier($1);
}

// ----------------- namespaces -------------------------------------------------

%code {
    void add_active_url(const char*url)
    {
        NEW(namespace_t,n);
        n->name = url;
        list_append(state->active_namespace_urls, n);
    }
};

NAMESPACE_ID : "namespace" T_IDENTIFIER {
    PASS12
    NEW(namespace_decl_t,n);
    n->name = $2;
    n->url = $2;
    $$=n;
}
NAMESPACE_ID : "namespace" T_IDENTIFIER '=' T_IDENTIFIER {
    PASS12
    NEW(namespace_decl_t,n);
    n->name = $2;
    n->url = $4;
    $$=n;
}
NAMESPACE_ID : "namespace" T_IDENTIFIER '=' T_STRING {
    PASS12
    NEW(namespace_decl_t,n);
    n->name = $2;
    n->url = $4.str;
    $$=n;
}
NAMESPACE_DECLARATION : MAYBE_MODIFIERS NAMESPACE_ID {
    PASS12
    trie_put(active_namespaces, $2->name, (void*)$2->url);

    namespace_t access = modifiers2access(&$1);
    varinfo_t* var = varinfo_register_global(access.access, state->package, $2->name);
    var->type = TYPE_NAMESPACE;
    namespace_t ns;
    ns.access = ACCESS_NAMESPACE;
    ns.name = $2->url;
    var->value = constant_new_namespace(&ns);
      
    if(as3_pass==2) {
        MULTINAME(m, TYPE_NAMESPACE);
        trait_t*t = add_abc_slot(&$1, $2->name, 0, 0);
        t->value = var->value;
        t->type_name = multiname_clone(&m);
    }

    $$=0;
}

DEFAULT_NAMESPACE : "default xml" "namespace" '=' E 
{
    as3_warning("default xml namespaces not supported yet");
    $$ = 0;
}

USE_NAMESPACE : "use" "namespace" CLASS_SPEC {
    PASS12
    const char*url = $3->name;

    varinfo_t*s = (varinfo_t*)$3;
    if(s->kind == INFOTYPE_UNRESOLVED) {
        s = (varinfo_t*)registry_resolve((slotinfo_t*)s);
        if(!s)
            syntaxerror("Couldn't resolve namespace %s", $3->name);
    }

    if(!s || s->kind != INFOTYPE_VAR)
        syntaxerror("%s.%s is not a public namespace (%d)", $3->package, $3->name, s?s->kind:-1);
    if(!s->value || !NS_TYPE(s->value->type))
        syntaxerror("%s.%s is not a namespace", $3->package, $3->name);
    url = s->value->ns->name;

    trie_put(active_namespaces, $3->name, (void*)url);
    add_active_url(url);
    $$=0;
}

