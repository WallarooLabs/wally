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

#define FMT_BUF_SIZE 1024

int printf(const char *fmt, ...)
{
  char fmt2[FMT_BUF_SIZE];
  int fmt2_len;
  struct timeval tv;
  va_list ap;
  int ret;

  gettimeofday(&tv, NULL);
#ifdef  __APPLE__  
  snprintf(fmt2, sizeof(fmt2), "%ld.%06d ", tv.tv_sec, tv.tv_usec);
#else
  snprintf(fmt2, sizeof(fmt2), "%ld.%06lu ", tv.tv_sec, tv.tv_usec);
#endif

  va_start(ap, fmt);
  fmt2_len = strlen(fmt2);
  if (strlen(fmt) > (sizeof(fmt2) - fmt2_len)) {
    /* Our static buffer isn't big enough, so call vprintf() as is. */
    ret = vprintf(fmt, ap);
  } else {
    memcpy(fmt2 + fmt2_len, fmt, strlen(fmt));
    ret = vprintf(fmt2, ap);
  }
  va_end(ap);
  return ret;
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
