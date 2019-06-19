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

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <ctype.h>

#define FMT_BUF_SIZE  1024
#define MAX_SEVERITY  8
#define MAX_CATEGORY  32

static int _labels_initialized = 0;
static char *_severity_labels[MAX_SEVERITY+1];
static char *_category_labels[MAX_CATEGORY+1];

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
  if (strlen(fmt) > (sizeof(fmt2) - fmt2_len - 1 /*,*/)) {
    /* Our static buffer isn't big enough, so call vprintf() as is. */
    ret = vprintf(fmt, ap);
  } else {
    fmt2[fmt2_len] = ',';
    memcpy(fmt2 + fmt2_len + 1, fmt, strlen(fmt));
    ret = vprintf(fmt2, ap);
  }
  va_end(ap);
  return ret;
}

int printf(const char *fmt, ...)
{
  va_list ap;

  va_start(ap, fmt);
  return _w_vprintf(fmt, ap);
  // va_end() already done
}

int l(char severity, char category, const char *fmt, ...)
{
  char fmt2[FMT_BUF_SIZE];
  va_list ap;

  va_start(ap, fmt);
  snprintf(fmt2, sizeof(fmt2), "%d,%d,%s", severity, category, fmt);
  return _w_vprintf(fmt2, ap);
}

void set_severity(char severity, char *label)
{
  if (! _labels_initialized) {
    _w_initialize_labels();
    _labels_initialized = 1;
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
