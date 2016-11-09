/*************************************************************************
 * 
 * SENDENCE LLC CONFIDENTIAL
 * __________________
 * 
 *  [2016] Sendence LLC
 *  All Rights Reserved.
 *  Copyright (c) 2016 Sendence LLC All rights reserved.
 * 
 * NOTICE:  All information contained herein is, and remains
 * the property of Sendence LLC and its suppliers,
 * if any.  The intellectual and technical concepts contained
 * herein are proprietary to Sendence LLC and its suppliers 
 * and may be covered by U.S. and Foreign Patents, patents in 
 * process, and are protected by trade secret or copyright law.
 * Dissemination of this information or reproduction of this material
 * is strictly forbidden unless prior written permission is obtained
 * from Sendence LLC.
 *
 * Copyright (c) 2016 Sendence LLC All rights reserved.
 */


#ifndef __SERIALIZABLE_HPP__
#define __SERIALIZABLE_HPP__

#include <cstddef>
#include <stdlib.h>

namespace wallaroo
{
class Serializable
{
public:
  virtual void deserialize (char* bytes) {}
  virtual void serialize (char* bytes, size_t nsz_) {}
  virtual size_t serialize_get_size () { return 0; }
};
}
#endif // __SERIALIZABLE_HPP__
