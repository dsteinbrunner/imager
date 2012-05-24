/*
=head1 NAME

error.c - error reporting code for Imager

=head1 SYNOPSIS

  // user code:
  int new_fatal; // non-zero if errors are fatal
  int old_fatal = i_set_failure_fatal(new_fatal);
  i_set_argv0("name of your program");
  extern void error_cb(char const *);
  i_error_cb old_ecb;
  old_ecb = i_set_error_cb(error_cb);
  i_failed_cb old_fcb;
  extern void failed_cb(char **errors);
  old_fcb = i_set_failed_cb(failed_cb);
  if (!i_something(...)) {
    char **errors = i_errors();
  }

  // imager code:
  undef_int i_something(...) {
    i_clear_error();
    if (!some_lower_func(...)) {
      return i_failed("could not something");
    }
    return 1;
  }
  undef_int some_lower_func(...) {
    if (somethingelse_failed()) {
      i_push_error("could not somethingelse");
      return 0;
    }
    return 1;
  }

=head1 DESCRIPTION

This module provides the C level error handling functionality for
Imager.

A few functions return or pass in an i_errmsg *, this is list of error
structures, terminated by an entry with a NULL msg value, each of
which contains a msg and an error code. Even though these aren't
passed as i_errmsg const * pointers, don't modify the strings
or the pointers.

The interface as currently defined isn't thread safe, unfortunately.

This code uses Imager's mymalloc() for memory allocation, so out of
memory errors are I<always> fatal.

=head1 INTERFACE

These functions form the interface that a user of Imager sees (from
C).  The Perl level won't use all of this.

=over

=cut
*/

#include "imageri.h"
#include <stdio.h>
#include <stdlib.h>

#if 0
static i_error_cb error_cb;
static i_failed_cb failed_cb;
static int failures_fatal;
static char *argv0;
/*
=item i_set_argv0(char const *program)

Sets the name of the program to be displayed in fatal error messages.

The simplest way to use this is just:

  i_set_argv0(argv[0]);

when your program starts.
*/
void i_set_argv0(char const *name) {
  char *dupl;
  if (!name)
    return;
  /* if the user has an existing string of MAXINT length then
     the system is broken anyway */
  dupl = mymalloc(strlen(name)+1); /* check 17jul05 tonyc */
  strcpy(dupl, name);
  if (argv0)
    myfree(argv0);
  argv0 = dupl;
}

/*
=item i_set_failure_fatal(int failure_fatal)

If failure_fatal is non-zero then any future failures will result in
Imager exiting your program with a message describing the failure.

Returns the previous setting.

=cut
*/
int i_set_failures_fatal(int fatal) {
  int old = failures_fatal;
  failures_fatal = fatal;

  return old;
}

/*
=item i_set_error_cb(i_error_cb)

Sets a callback function that is called each time an error is pushed
onto the error stack.

Returns the previous callback.

i_set_failed_cb() is probably more useful.

=cut
*/
i_error_cb i_set_error_cb(i_error_cb cb) {
  i_error_cb old = error_cb;
  error_cb = cb;

  return old;
}

/*
=item i_set_failed_cb(i_failed_cb cb)

Sets a callback function that is called each time an Imager function
fails.

Returns the previous callback.

=cut
*/
i_failed_cb i_set_failed_cb(i_failed_cb cb) {
  i_failed_cb old = failed_cb;
  failed_cb = cb;

  return old;
}

#endif

/*
=item i_errors()

Returns a pointer to the first element of an array of error messages,
terminated by a NULL pointer.  The highest level message is first.

=cut
*/
i_errmsg *im_errors(im_context_t ctx) {
  return ctx->error_stack + ctx->error_sp;
}

i_errmsg *i_errors(void) {
  return im_errors(im_get_context());
}

/*
=back

=head1 INTERNAL FUNCTIONS

These functions are called by Imager to report errors through the
above interface.

It may be desirable to have functions to mark the stack and reset to
the mark.

=over

=item i_clear_error()
=synopsis i_clear_error();
=category Error handling

Clears the error stack.

Called by any Imager function before doing any other processing.

=cut
*/

void
im_clear_error(im_context_t ctx) {
#ifdef IMAGER_DEBUG_MALLOC
  int i;

  for (i = 0; i < IM_ERROR_COUNT; ++i) {
    if (ctx->error_space[i]) {
      myfree(ctx->error_stack[i].msg);
      ctx->error_stack[i].msg = NULL;
      ctx->error_space[i] = 0;
    }
  }
#endif
  ctx->error_sp = IM_ERROR_COUNT-1;
}

/*
=item i_push_error(int code, char const *msg)
=synopsis i_push_error(0, "Yep, it's broken");
=synopsis i_push_error(errno, "Error writing");
=category Error handling

Called by an Imager function to push an error message onto the stack.

No message is pushed if the stack is full (since this means someone
forgot to call i_clear_error(), or that a function that doesn't do
error handling is calling function that does.).

=cut
*/
void
im_push_error(im_context_t ctx, int code, char const *msg) {
  size_t size = strlen(msg)+1;

  if (ctx->error_sp <= 0)
    /* bad, bad programmer */
    return;

  --ctx->error_sp;
  if (ctx->error_alloc[ctx->error_sp] < size) {
    if (ctx->error_stack[ctx->error_sp].msg)
      myfree(ctx->error_stack[ctx->error_sp].msg);
    /* memory allocated on the following line is only ever released when 
       we need a bigger string */
    /* size is size (len+1) of an existing string, overflow would mean
       the system is broken anyway */
    ctx->error_stack[ctx->error_sp].msg = mymalloc(size); /* checked 17jul05 tonyc */
    ctx->error_alloc[ctx->error_sp] = size;
  }
  strcpy(ctx->error_stack[ctx->error_sp].msg, msg);
  ctx->error_stack[ctx->error_sp].code = code;
}

#if 0

void
i_push_error(int code, char const *msg) {
  im_push_error(im_get_context(), code, msg);
}

#endif

/*
=item i_push_errorvf(int C<code>, char const *C<fmt>, va_list C<ap>)

=category Error handling

Intended for use by higher level functions, takes a varargs pointer
and a format to produce the finally pushed error message.

Does not support perl specific format codes.

=cut
*/
void 
im_push_errorvf(im_context_t ctx, int code, char const *fmt, va_list ap) {
  char buf[1024];
#if defined(IMAGER_VSNPRINTF)
  vsnprintf(buf, sizeof(buf), fmt, ap);
#elif defined(_MSC_VER)
  _vsnprintf(buf, sizeof(buf), fmt, ap);
#else
  /* is there a way to detect vsnprintf()? 
     for this and other functions we need some mechanism to handle 
     detection (like perl's Configure, or autoconf)
   */
  vsprintf(buf, fmt, ap);
#endif
  im_push_error(ctx, code, buf);
}

void
i_push_errorvf(int code, char const *fmt, va_list ap) {
  im_push_errorvf(im_get_context(), code, fmt, ap);
}

/*
=item i_push_errorf(int code, char const *fmt, ...)
=synopsis i_push_errorf(errno, "Cannot open file %s: %d", filename, errno);
=category Error handling

A version of i_push_error() that does printf() like formatting.

Does not support perl specific format codes.

=cut
*/
void
i_push_errorf(int code, char const *fmt, ...) {
  va_list ap;
  va_start(ap, fmt);
  i_push_errorvf(code, fmt, ap);
  va_end(ap);
}

void
im_push_errorf(im_context_t ctx, int code, char const *fmt, ...) {
  va_list ap;
  va_start(ap, fmt);
  im_push_errorvf(ctx, code, fmt, ap);
  va_end(ap);
}

#ifdef IMAGER_I_FAILED
#error "This isn't used and is untested"

/*
=item i_failed(char const *msg)

Called by Imager code to indicate that a top-level has failed.

msg can be NULL, in which case no error is pushed.

Calls the current failed callback, if any.

Aborts the program with an error, if failures have been set to be fatal.

Returns zero if it does not abort.

=cut
*/
int i_failed(int code, char const *msg) {
  if (msg)
    i_push_error(code, msg);
  if (failed_cb)
    failed_cb(error_stack + error_sp);
  if (failures_fatal) {
    int sp;
    size_t total; /* total length of error messages */
    char *full; /* full message for logging */
    if (argv0)
      fprintf(stderr, "%s: ", argv0);
    fputs("error:\n", stderr);
    sp = error_sp;
    while (error_stack[sp].msg) {
      fprintf(stderr, " %s\n", error_stack[sp].msg);
      ++sp;
    }
    /* we want to log the error too, build an error message to hand to
       i_fatal() */
    total = 1; /* remember the NUL */
    for (sp = error_sp; error_stack[sp].msg; ++sp) {
      size_t new_total += strlen(error_stack[sp].msg) + 2;
      if (new_total < total) {
	/* overflow, somehow */
	break;
      }
    }
    full = mymalloc(total);
    if (!full) {
      /* just quit, at least it's on stderr */
      exit(EXIT_FAILURE);
    }
    *full = 0;
    for (sp = error_sp; error_stack[sp].msg; ++sp) {
      strcat(full, error_stack[sp].msg);
      strcat(full, ": ");
    }
    /* lose the extra ": " */
    full[strlen(full)-2] = '\0';
    i_fatal(EXIT_FAILURE, "%s", full);
  }

  return 0;
}

#endif

/*
=item im_assert_fail(file, line, message)

Called when an im_assert() assertion fails.

=cut
*/

void
im_assert_fail(char const *file, int line, char const *message) {
  fprintf(stderr, "Assertion failed line %d file %s: %s\n", 
	  line, file, message);
  abort();
}

/*
=back

=head1 BUGS

This interface isn't thread safe.

=head1 AUTHOR

Tony Cook <tony@develop-help.com>

Stack concept by Arnar Mar Hrafnkelsson <addi@umich.edu>

=cut
*/
