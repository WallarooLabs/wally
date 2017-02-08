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

#ifndef __PARTITION_FUNCTION_HPP__
#define __PARTITION_FUNCTION_HPP__

#include "ManagedObject.hpp"
#include "Key.hpp"

namespace wallaroo
{
class PartitionFunction: public ManagedObject
{
public:
  virtual Key *partition(Data *data_) = 0;
};
class PartitionFunctionU64: public ManagedObject
{
public:
  virtual uint64_t partition(Data *data_) = 0;
};
}

#endif // __PARTITION_FUNCTION_HPP
