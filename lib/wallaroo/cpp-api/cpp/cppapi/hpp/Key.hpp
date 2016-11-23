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

#ifndef __KEY_HPP__
#define __KEY_HPP__

#include "ManagedObject.hpp"
#include <cstdint>

namespace wallaroo
{
class Key: public ManagedObject
{
public:
  virtual uint64_t hash() = 0;
  virtual bool eq(Key *other) = 0;
};
}

#endif // __KEY_HPP__
