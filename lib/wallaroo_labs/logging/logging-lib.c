/*

Copyright (C) 2016-2019, Wallaroo Labs
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*/

#include <ctype.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>

#define ENV_BUF_SIZE  1024
#define FMT_BUF_SIZE  1024
#define MAX_SEVERITY  8
#define MAX_CATEGORY  64

static int _labels_initialized = 0;

static char *_severity_labels[MAX_SEVERITY+1];
static char *_category_labels[MAX_CATEGORY+1];

static int _cat2sev_threshold[MAX_CATEGORY+1];

/*****************************/
/* Internal static functions */
/*****************************/

static int _w_now(char *dst, int dst_size)
{
  struct timeval tv;

  gettimeofday(&tv, NULL);
#ifdef  __APPLE__  
  return snprintf(dst, dst_size, "%ld.%06d", tv.tv_sec, tv.tv_usec);
#else
  return snprintf(dst, dst_size, "%ld.%06lu", tv.tv_sec, tv.tv_usec);
#endif
}

static int _w_vprintf(const char *fmt, va_list ap)
{
  char fmt2[FMT_BUF_SIZE];
  int fmt2_len;
  int ret;

  fmt2_len = _w_now(fmt2, sizeof(fmt2));
  if (strlen(fmt) > (sizeof(fmt2) - fmt2_len - 2 /* , & NUL */)) {
    /* Our static buffer isn't big enough, so call vprintf() as is. */
    ret = vprintf(fmt, ap);
  } else {
    fmt2[fmt2_len] = ',';
    memcpy(fmt2 + fmt2_len + 1, fmt, strlen(fmt) + 1);
    ret = vprintf(fmt2, ap);
  }
  va_end(ap);
  return ret;
}

static void _w_initialize_labels()
{
  int i;
  char buf[16];

  for (i = 0; i < MAX_SEVERITY+1; i++) {
    snprintf(buf, sizeof(buf), "sev-%d", i);
    _severity_labels[i] = strdup(buf);
  }
  for (i = 0; i < MAX_CATEGORY+1; i++) {
    snprintf(buf, sizeof(buf), "cat-%d", i);
    _category_labels[i] = strdup(buf);
    _cat2sev_threshold[i] = MAX_SEVERITY;
  }
  _labels_initialized = 1;
}


/********************/
/* Public functions */
/********************/

int printf(const char *fmt, ...)
{
  va_list ap;

  va_start(ap, fmt);
  return _w_vprintf(fmt, ap);
  // va_end() already done
}

/*
** le(), is logging enabled for a (severity, category) tuple
**
** severity - numeric severity from 0 to MAX_SEVERITY
** category - application category number from 0 to MAX_CATEGORY
**
** Return value: true if logging is enabled for this tuple,
**               otherwise false
*/

unsigned char le(unsigned char severity, unsigned char category)
{
  if (severity > _cat2sev_threshold[category]) {
    return 0;
  }
  return 1;
}

/*
** l(), the severity + category + format + variable-args logging function.
**
** severity - numeric severity from 0 to MAX_SEVERITY
** category - application category number from 0 to MAX_CATEGORY
** fmt - snprintf(3)-style formatting string
** 0 or or arguments - snprintf(3)-style arguments
**
** Return value: # of bytes written
*/

int l(unsigned char severity, unsigned char category, const char *fmt, ...)
{
  char fmt2[FMT_BUF_SIZE];
  va_list ap;

  if (severity > _cat2sev_threshold[category]) {
    return 0;
  }
  if (! _labels_initialized) {
    _w_initialize_labels();
  }

  va_start(ap, fmt);
  snprintf(fmt2, sizeof(fmt2), "%s,%s,%s\n",
    _severity_labels[severity], _category_labels[category], fmt);
  return _w_vprintf(fmt2, ap);
}


/*
** w_set_severity(), set the formatted label for a severity number
**
** severity - numeric severity from 0 to MAX_SEVERITY
*/

void w_set_severity(unsigned char severity, char *label)
{
  if (! _labels_initialized) {
    _w_initialize_labels();
  }
  if (severity < MAX_SEVERITY+1) {
    _severity_labels[severity] = strdup(label);
  }
}

/*
** w_set_category(), set the formatted label for a category number
**
** category - application category number from 0 to MAX_CATEGORY
*/

void w_set_category(unsigned char category, char *label)
{
  if (! _labels_initialized) {
    _w_initialize_labels();
  }
  if (category < MAX_CATEGORY+1) {
    _category_labels[category] = strdup(label);
  }
}

/*
** w_set_severity_threshold(), set the severity threshold for all categories
**
** severity - numeric severity from 0 to MAX_SEVERITY
*/

void w_severity_threshold(unsigned char severity)
{
  int i;

  if (severity < MAX_SEVERITY+1) {
    for (i = 0; i < MAX_CATEGORY+1; i++) {
      _cat2sev_threshold[i] = severity;
    }
  }
}

/*
** w_set_severity_cat_threshold(), set the severity threshold for a category
**
** severity - numeric severity from 0 to MAX_SEVERITY
** category - application category number from 0 to MAX_CATEGORY
*/

void w_severity_cat_threshold(unsigned char severity, unsigned char category)
{
  int i;

  if (severity < MAX_SEVERITY+1 && category < MAX_CATEGORY+1) {
    _cat2sev_threshold[category] = severity;
  }
}

/*
** w_process_category_overrides, process any env var overrides
**
** If the environment variable WALLAROO_THRESHOLDS exists, then
** parse that string and apply a set of overrides to the
** _cat2sev_thresholds.
**
** The string should contain a list of zero or more
** category.severity pairs, e.g, "22.5" for category 23 and
** severity 5 (which corresponds to Log.notice()).  The string
** "*" can be used to specify all categories.
**
** Items in the list are separated by commas and are processed
** in order.  The "*" for all categories, if used, probably ought
** to be first in the list.  For example, "*.1,22.5,3.7,4.0".
*/

void w_process_category_overrides()
{
  char *env = getenv("WALLAROO_THRESHOLDS");
  char buf[ENV_BUF_SIZE];
  char *p = buf, *start, *saveptr, *dot;
  unsigned char severity, category;
  int i;

  if (env != NULL) {
    if (strlen(env) < sizeof(buf) - 1) {
      strcpy(buf, env);

      for (start = strtok_r(buf, ",", &saveptr);
           start != NULL;
           start = strtok_r(NULL, ",", &saveptr)) {
        if ((dot = strchr(start, '.')) != NULL) {
          *dot = '\0';
          severity = atoi(dot + 1);
          if (*start == '*') {
            w_severity_threshold(severity);
          } else if ((category = atoi(start)) > 0) {
            w_severity_cat_threshold(severity, category);
          }
        }
      }
    }
  }
}

#ifdef MAIN
#include <assert.h>
int main(void)
{
  char *fmt1 = "Hello, world (with timestamp)!\n";
  char *fmt2 = "Hello, world (too big, no timestamp) Hello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, world!\n";

  assert(strlen(fmt1) < FMT_BUF_SIZE);
  printf("Hello, world (with timestamp)!\n");
  assert(strlen(fmt2) > FMT_BUF_SIZE);
  printf("Hello, world (too big, no timestamp) Hello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, world!\n");
}
#endif
