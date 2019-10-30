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

static int _w_l(unsigned char severity, unsigned char category,
  const char *fmt, va_list ap)
{
  char fmt2[FMT_BUF_SIZE];

  if (severity > MAX_SEVERITY || category > MAX_CATEGORY ||
      severity > _cat2sev_threshold[category]) {
    return 0;
  }
  if (! _labels_initialized) {
    _w_initialize_labels();
  }

  snprintf(fmt2, sizeof(fmt2), "%s,%s,%s\n",
    _severity_labels[severity], _category_labels[category], fmt);
  return _w_vprintf(fmt2, ap);
}

unsigned char _w_true()
{
  return 1;
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
** l_enabled(), is logging enabled for a (severity, category) tuple
**
** severity - numeric severity from 0 to MAX_SEVERITY
** category - application category number from 0 to MAX_CATEGORY
**
** NOTE: In the interest of maximum speed, we only check severity threshold.
**       It's strongly recommended that labels and thresholds be set prior
**       to calling this function.
**
** Return value: true if logging is enabled for this tuple,
**               otherwise false
*/

unsigned char l_enabled(unsigned short severity16, unsigned short category16)
{
  unsigned char severity = severity16 & 0xFF;
  unsigned char category = (category16 >> 8) & 0xFF;

  if (severity > MAX_SEVERITY || category > MAX_CATEGORY ||
      severity > _cat2sev_threshold[category]) {
    return 0;
  }
  return 1;
}

/*
** ll_enabled(), is logging enabled for an unsigned short severity+category
**
** sev_cat: a mix of:
**     severity - numeric severity, bits 8-15
**     category - application category number, bits 0-7
**
** NOTE: In the interest of maximum speed, we only check severity threshold.
**       It's strongly recommended that labels and thresholds be set prior
**       to calling this function.
**
** Return value: true if logging is enabled for this tuple,
**               otherwise false
*/

unsigned char ll_enabled(unsigned short sev_cat)
{
  unsigned char severity = sev_cat & 0xFF;
  unsigned char category = (sev_cat >> 8) & 0xFF;

  if (severity > MAX_SEVERITY || category > MAX_CATEGORY ||
      severity > _cat2sev_threshold[category]) {
    return 0;
  }
  return 1;
}

/*
** l(), the severity + category + format + variable-args logging function.
**
** severity - numeric severity from 0 to MAX_SEVERITY
** category - application category number from 0 to MAX_CATEGORY
** fmt - snprintf(3)-style formatting string *without* trailing newline
** 0 or or arguments - snprintf(3)-style arguments
**
** NOTE: In the interest of maximum speed, we check severity threshold
**       first and only afterward check if the labels/default threshold/etc
**       have been initialized.  It's strongly recommended that labels
**       and thresholds be set prior to calling this function.
**
** Return value: # of bytes written
*/

int l(unsigned short severity16, unsigned short category16, const char *fmt, ...)
{
  unsigned char severity = severity16 & 0xFF;
  unsigned char category = (category16 >> 8) & 0xFF;
  va_list ap;

  if (severity > MAX_SEVERITY || category > MAX_CATEGORY ||
      severity > _cat2sev_threshold[category]) {
    return 0;
  }
  if (! _labels_initialized) {
    _w_initialize_labels();
  }

  va_start(ap, fmt);
  return _w_l(severity, category, fmt, ap);
}

/*
** ll(), the severity + category + format + variable-args logging function.
**
** sev_cat: a mix of:
**     severity - numeric severity, bits 8-15
**     category - application category number, bits 0-7
** fmt - snprintf(3)-style formatting string *without* trailing newline
** 0 or or arguments - snprintf(3)-style arguments
**
** NOTE: In the interest of maximum speed, we check severity threshold
**       first and only afterward check if the labels/default threshold/etc
**       have been initialized.  It's strongly recommended that labels
**       and thresholds be set prior to calling this function.
**
** Return value: # of bytes written
*/

int ll(unsigned short sev_cat, const char *fmt, ...)
{
  unsigned char severity = sev_cat & 0xFF;
  unsigned char category = (sev_cat >> 8) & 0xFF;
  va_list ap;

  if (severity > MAX_SEVERITY || category > MAX_CATEGORY ||
      severity > _cat2sev_threshold[category]) {
    return 0;
  }
  if (! _labels_initialized) {
    _w_initialize_labels();
  }

  va_start(ap, fmt);
  return _w_l(severity, category, fmt, ap);
}

/*
** w_set_severity_label(), set the formatted label for a severity number
**
** severity - numeric severity from 0 to MAX_SEVERITY
*/

void w_set_severity_label(unsigned short severity16, char *label)
{
  unsigned char severity = severity16 & 0xFF;

  if (! _labels_initialized) {
    _w_initialize_labels();
  }
  if (severity < MAX_SEVERITY+1) {
    _severity_labels[severity] = strdup(label);
  }
}

/*
** w_set_category_label(), set the formatted label for a category number
**
** category - application category number from 0 to MAX_CATEGORY
*/

void w_set_category_label(unsigned short category16, char *label)
{
  unsigned char category = (category16 >> 8) & 0xFF;

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

void w_set_severity_threshold(unsigned short severity16)
{
  unsigned char severity = severity16 & 0xFF;
  int i;

  if (! _labels_initialized) {
    _w_initialize_labels();
  }
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

void w_set_severity_cat_threshold(unsigned short severity16, unsigned short category16)
{
  unsigned char severity = severity16 & 0xFF;
  unsigned char category = (category16 >> 8) & 0xFF;
  int i;

  if (! _labels_initialized) {
    _w_initialize_labels();
  }
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
** category.severity pairs, e.g, "22.6" for category 22 and
** severity 6 (which corresponds to Log.notice()).  The string
** "*" can be used to specify all categories.
**
** Items in the list are separated by commas and are processed
** in order.  The "*" for all categories, if used, probably ought
** to be first in the list.  For example, "*.1,22.6,3.7,4.0".
*/

void w_process_category_overrides()
{
  char *env = getenv("WALLAROO_THRESHOLDS");
  char buf[ENV_BUF_SIZE];
  char *p = buf, *start, *saveptr, *dot;
  unsigned char severity, category;
  int i;

  if (! _labels_initialized) {
    _w_initialize_labels();
  }
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
            w_set_severity_threshold(severity);
          } else if ((category = atoi(start)) > 0) {
            w_set_severity_cat_threshold(severity, category);
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
  printf(fmt1);
  assert(strlen(fmt2) > FMT_BUF_SIZE);
  printf(fmt2);
}
#endif
