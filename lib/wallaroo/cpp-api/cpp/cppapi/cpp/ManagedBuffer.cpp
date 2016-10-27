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
 * Created by Kevin A. Goldstein R.  on 9/30/16.
 * Copyright (c) 2016 Sendence LLC All rights reserved.
 */


#include "Buffers.hpp"
#include "Logger.hpp"





namespace wallaroo
{




ManagedBuffer::ManagedBuffer (int sz_) : Buffer()
{
  _bodySize = sz_;
  setBody(_bodySize);
}




ManagedBuffer::ManagedBuffer (char* buff_, int sz_) : Buffer(buff_, sz_)
{

}



ManagedBuffer::ManagedBuffer (const ManagedBuffer& buff_)
{
  Logger::getLogger()->error("ManagedBuffer (const ManagedBuffer& cpy_) --> not defined yet");
}




ManagedBuffer::~ManagedBuffer ()
{
  if (_body != nullptr)
  {
    delete[] _body;
  }


  _body = nullptr;
  _read = nullptr;
  _write = nullptr;
  _bodySize = 0;
}

}
