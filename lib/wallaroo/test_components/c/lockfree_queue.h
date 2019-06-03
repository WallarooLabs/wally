/* https://willnewton.name/2013/07/15/simple-lock-free-ring-buffer-implementation/ */
/*
 * Copyright (c) 2013, Linaro Limited
 *
 * Licensed under the 3 clause BSD license.
 */

#ifndef __LFQ_H__
#define __LFQ_H__

#include <sched.h>  // for sched_yield()
#include <unistd.h> // for usleep()

struct lfq {
  volatile unsigned int producer;
  volatile unsigned int consumer;
  unsigned int queue_size;
  void **data;
};

/* Initialize a struct lfq with a size and array of memory. */
inline void lfq_init(struct lfq *q, unsigned int queue_size,
          void **data)
{
  q->queue_size = queue_size;
  q->data = data;
  q->producer = 0;
  q->consumer = 0;
}

/* Internal function to backoff on contention. */
inline void __lfq_backoff(unsigned int i)
{
  if (i < 100) {
    sched_yield();
  } else {
    usleep(1000);
  }
}

/* Dequeue an item from the ring.
   Spin waiting if it is empty.
   Return NULL if fail_if_full is true and the queue is full.
*/
inline void *lfq_dequeue(struct lfq *q)//, int fail_if_full)
{
  void *ret;
  // unsigned int i = 0;
  // if (fail_if_full && (q->producer - q->consumer >= q->queue_size)) {
  //   return NULL;
  // }
  if (q->producer == q->consumer) {
    return NULL;
  }
  // while (q->producer == q->consumer) {
  //   __lfq_backoff(i++);
  // }
  ret = q->data[q->consumer % q->queue_size];
  q->consumer++;

  return ret;
}

/* Enqueue an item onto the ring.
   OLD: Spin waiting if it is full.
   NEW: Return 1 if enqueued, 0 if full.
*/
inline int lfq_enqueue(struct lfq *q, void *item)
{
  // unsigned int i = 0;

  // while (q->producer - q->consumer >= q->queue_size) {
  //   __lfq_backoff(i++);
  // }
  if (q->producer - q->consumer >= q->queue_size) {
    return 0;
  }
  q->data[q->producer % q->queue_size] = item;
  __sync_synchronize();
  q->producer++;
  return 1;
}

/* Test is the queue is empty. */
inline bool lfq_empty(struct lfq *q)
{
  return q->producer == q->consumer;
}

inline unsigned int lfq_size(struct lfq *q)
{
  return q->producer - q->consumer;
}

#endif
