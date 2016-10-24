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
 * Created by Kevin A. Goldstein R.  on 10/4/16.
 * Copyright (c) 2016 Sendence LLC All rights reserved.
 */


#ifndef __DATA_HPP__
#define __DATA_HPP__


#include "Buffers.hpp"
#include "ManagedObject.hpp"

namespace wallaroo
{
class Data: public ManagedObject
{
public:
    virtual ~Data();

    virtual void deserialize (char* bytes) = 0;
    virtual void serialize (char* bytes, size_t nsz_) = 0;
    virtual size_t serialize_get_size () = 0;
};

}
#endif //__DATA_HPP__
