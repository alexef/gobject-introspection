/* -*- Mode: C -*-
/* GObject introspection: C lexer
 *
 * Copyright (c) 1997 Sandro Sigala  <ssigala@globalnet.it>
 * Copyright (c) 2007-2008 Jürg Billeter  <j@bitron.ch>
 *
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

%{
#include <ctype.h>
#include <stdio.h>

#include <glib.h>
#include "sourcescanner.h"
#include "scannerparser.h"
#include "grealpath.h"

int lineno;

extern int yylex (GISourceScanner *scanner);
#define YY_DECL int yylex (GISourceScanner *scanner)
static int yywrap (void);
static void parse_comment (GISourceScanner *scanner);
static void process_directive (GISourceScanner *scanner);
static int check_identifier (GISourceScanner *scanner, const char *);
%}

intsuffix				([uU][lL]?)|([lL][uU]?)
fracconst				([0-9]*\.[0-9]+)|([0-9]+\.)
exppart					[eE][-+]?[0-9]+
floatsuffix				[fFlL]
chartext				([^\'])|(\\.) 
stringtext				([^\"])|(\\.)

%%

"\n"					{ ++lineno; } /* " */
[\t\f\v\r ]+				{ /* Ignore whitespace. */ }

"/*"					{ parse_comment(scanner); }
"//".*					{ }

"#define "[a-zA-Z_][a-zA-Z_0-9]*"("	{ yyless (yyleng - 1); return FUNCTION_MACRO; }
"#define "[a-zA-Z_][a-zA-Z_0-9]*	{ return OBJECT_MACRO; }

"#"					{ process_directive(scanner); }

"{"					{ return '{'; }
"<%"					{ return '{'; }
"}"					{ return '}'; }
"%>"					{ return '}'; }
"["					{ return '['; }
"<:"					{ return '['; }
"]"					{ return ']'; }
":>"					{ return ']'; }
"("					{ return '('; }
")"					{ return ')'; }
";"					{ return ';'; }
":"					{ return ':'; }
"..."					{ return ELLIPSIS; }
"?"					{ return '?'; }
"."					{ return '.'; }
"+"					{ return '+'; }
"-"					{ return '-'; }
"*"					{ return '*'; }
"/"					{ return '/'; }
"%"					{ return '%'; }
"^"					{ return '^'; }
"&"					{ return '&'; }
"|"					{ return '|'; }
"~"					{ return '~'; }
"!"					{ return '!'; }
"="					{ return '='; }
"<"					{ return '<'; }
">"					{ return '>'; }
"+="					{ return ADDEQ; }
"-="					{ return SUBEQ; }
"*="					{ return MULEQ; }
"/="					{ return DIVEQ; }
"%="					{ return MODEQ; }
"^="					{ return XOREQ; }
"&="					{ return ANDEQ; }
"|="					{ return OREQ; }
"<<"					{ return SL; }
">>"					{ return SR; }
"<<="					{ return SLEQ; }
">>="					{ return SREQ; }
"=="					{ return EQ; }
"!="					{ return NOTEQ; }
"<="					{ return LTEQ; }
">="					{ return GTEQ; }
"&&"					{ return ANDAND; }
"||"					{ return OROR; }
"++"					{ return PLUSPLUS; }
"--"					{ return MINUSMINUS; }
","					{ return ','; }
"->"					{ return ARROW; }

[a-zA-Z_][a-zA-Z_0-9]*			{ if (scanner->macro_scan) return IDENTIFIER; else REJECT; }

"auto"					{ return AUTO; }
"_Bool"					{ return BOOL; }
"break"					{ return BREAK; }
"case"					{ return CASE; }
"char"					{ return CHAR; }
"const"					{ return CONST; }
"continue"				{ return CONTINUE; }
"default"				{ return DEFAULT; }
"do"					{ return DO; }
"double"				{ return DOUBLE; }
"else"					{ return ELSE; }
"enum"					{ return ENUM; }
"extern"				{ return EXTERN; }
"float"					{ return FLOAT; }
"for"					{ return FOR; }
"goto"					{ return GOTO; }
"if"					{ return IF; }
"inline"				{ return INLINE; }
"int"					{ return INT; }
"long"					{ return LONG; }
"register"				{ return REGISTER; }
"restrict"				{ return RESTRICT; }
"return"				{ return RETURN; }
"short"					{ return SHORT; }
"signed"				{ return SIGNED; }
"sizeof"				{ return SIZEOF; }
"static"				{ return STATIC; }
"struct"				{ return STRUCT; }
"switch"				{ return SWITCH; }
"typedef"				{ return TYPEDEF; }
"union"					{ return UNION; }
"unsigned"				{ return UNSIGNED; }
"void"					{ return VOID; }
"volatile"				{ return VOLATILE; }
"while"					{ return WHILE; }

[a-zA-Z_][a-zA-Z_0-9]*			{ return check_identifier(scanner, yytext); }

"0"[xX][0-9a-fA-F]+{intsuffix}?		{ return INTEGER; }
"0"[0-7]+{intsuffix}?			{ return INTEGER; }
[0-9]+{intsuffix}?			{ return INTEGER; }

{fracconst}{exppart}?{floatsuffix}?	{ return FLOATING; }
[0-9]+{exppart}{floatsuffix}?		{ return FLOATING; }

"'"{chartext}*"'"			{ return CHARACTER; }
"L'"{chartext}*"'"			{ return CHARACTER; }

"\""{stringtext}*"\""			{ return STRING; }
"L\""{stringtext}*"\""			{ return STRING; }

.					{ fprintf(stderr, "%s:%d: unexpected character `%c'\n", scanner->current_filename, lineno, yytext[0]); }

%%

static int
yywrap (void)
{
  return 1;
}


static void
parse_gtkdoc (GISourceScanner *scanner,
	      gchar           *symbol,
	      int             *c1,
	      int             *c2)
{
  gboolean isline = FALSE;
  gchar line[256];
  int i;
  gchar **parts;
  GISourceDirective *directive;
  char *name,*value;
  GSList *directives;
  GSList *options = NULL;
  char *rname;

  i = 0;
  do 
    {
      *c1 = *c2;
      if (*c1 == '\n')
        {
          isline = TRUE;
          break;
        }
      if (i >= 256)
        break;
      line[i++] = *c1;
      *c2 = input();
    } while (*c2 != EOF && !(*c1 == '*' && *c2 == '/'));
  
  if (!isline)
    return;

  line[i] = '\0';

  parts = g_strsplit (line, ": ", 3);

  if (g_strv_length (parts) >= 2)
    {
      name = parts[0];

      if (g_strv_length (parts) == 3) 
        {
          char *ptr = parts[1];
          GString *current = NULL;
          gboolean open = (*ptr == '(');

          current = g_string_new ("");
          value = parts[2];

          while (*ptr++) 
            {
              if (*ptr == '(')
                 open = TRUE;
              else if (*ptr != ')' && open)
                g_string_append_c (current, *ptr);
              else if (*ptr == ')') {
                options = g_slist_prepend (options, g_strdup (current->str));
                open = FALSE;
              }
            }
          g_string_free (current, TRUE);
        } 
      else
        value = parts[1];
    }
  else /* parts == 1 */
    {
      name = parts[0];
      value = NULL;
    }

  /*
   * This is a special case for return values, name will only be
   * 'eturn' or a valid name, check the call site.
   * Context-sensitive parsing would probably be the right way to go
   */
  if (g_ascii_strncasecmp ("eturn", name, 5) == 0)
    rname = "return";
  else
    rname = name;

  directive = gi_source_directive_new (rname, value, options);
  directives = g_hash_table_lookup (scanner->directives_map, symbol);
  directives = g_slist_prepend (directives, directive);
  g_hash_table_replace (scanner->directives_map, 
			g_strdup (symbol), directives);

  g_strfreev (parts);
  
}


static void
parse_comment (GISourceScanner *scanner)
{
  GString *symbol = NULL;
  gboolean startofline = FALSE, have_symbol = FALSE, start1 = FALSE, start_symbol = FALSE;
  int c1, c2;

  c1 = input();
  c2 = input();

  while (c2 != EOF && !(c1 == '*' && c2 == '/'))
    {
      if (c1 == ':')
        have_symbol = TRUE;
      else if (c1 == '\n')
         start1 = TRUE;
      else if (c1 == '*' && start1)
         start_symbol = TRUE;
      else if (!have_symbol && start_symbol) 
        {
          if (!symbol)
            symbol = g_string_new ("");
          if (c1 != ' ')
            g_string_append_c (symbol, c1);
        }

      if (c1 == '\n') 
        {
          ++lineno;
          startofline = TRUE;
        }

      c1 = c2;
      c2 = input();

      if ((c1 != '*' && c1 != ' '))
          startofline = FALSE;

      if (startofline && (c1 == ' ') && (c2 == '@' || (c2 == 'r') || (c2 == 'R')))
        {
           c1 = c2;
           c2 = input();
           if (symbol)
             parse_gtkdoc (scanner, symbol->str, &c1, &c2);
        }
    }

  if (symbol)
    g_string_free (symbol, TRUE);
  
}

static int
check_identifier (GISourceScanner *scanner,
		  const char  *s)
{
	/*
	 * This function checks if `s' is a type name or an
	 * identifier.
	 */

	if (gi_source_scanner_is_typedef (scanner, s)) {
		return TYPEDEF_NAME;
	} else if (strcmp (s, "__builtin_va_list") == 0) {
		return TYPEDEF_NAME;
	}

	return IDENTIFIER;
}

static void
process_directive (GISourceScanner *scanner)
{
	/* extract current filename from #line directives */
	GString *filename_builder;
	gboolean in_string, found_filename;

	lineno = 0;
	found_filename = FALSE;
	in_string = FALSE;
	filename_builder = g_string_new ("");

	int c = input ();
	while (c != EOF && c != '\n') {
		if (!in_string) {
			if (c == '\"') {
				in_string = TRUE;
				found_filename = TRUE;
			} else if (c >= '0' && c <= '9') {
				if (!found_filename) {
					lineno = lineno * 10 + (c - '0');
				}
			}
		} else {
			if (c == '\"') {
				in_string = FALSE;
			} else if (c == '\\') {
				g_string_append_c (filename_builder, c);
				c = input ();
				g_string_append_c (filename_builder, c);
			} else {
				g_string_append_c (filename_builder, c);
			}
		}
		c = input ();
	}

	if (filename_builder->len > 0) {
		char *filename = g_strcompress (filename_builder->str);
		if (g_realpath (filename))
		  {
		    g_free (scanner->current_filename);
		    scanner->current_filename = g_realpath (filename);
		    g_assert (scanner->current_filename);
		    g_free(filename);
		  }
	}

	g_string_free (filename_builder, TRUE);
}
