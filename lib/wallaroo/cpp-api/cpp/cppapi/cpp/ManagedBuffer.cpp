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





//------------------------------------------------
BufferWriter::BufferWriter(int sz_) :
        Buffer(),
        _internallyAllocatedBuffer(true)
{
  _bodySize = sz_;
  setBody(_bodySize);
}





//------------------------------------------------
BufferWriter::BufferWriter(char* buff_, int sz_) :
        Buffer(),
        _internallyAllocatedBuffer(false)
{
  _body = buff_;
  _bodySize = sz_;

  _read = _body + sz_;
  _write = _body; // + sz_;
}





//------------------------------------------------
BufferWriter::BufferWriter(const BufferWriter& buff_) :
        Buffer(),
        _internallyAllocatedBuffer(false)
{
  Logger::getLogger()->error("{}, Error:{}", __PRETTY_FUNCTION__, "not defined yet");
}





//------------------------------------------------
BufferWriter::~BufferWriter()
{
  if (_body != nullptr && _internallyAllocatedBuffer)
  {
    delete[] _body;
  }


  _body = nullptr;
  _read = nullptr;
  _write = nullptr;
  _bodySize = 0;
}





//------------------------------------------------
BufferWriter& BufferWriter::operator<<(const bool param_)
{
  writeData(&param_, sizeof(param_));
  return *this;
}





//------------------------------------------------
BufferWriter& BufferWriter::operator<<(const char param_)
{
  writeData(&param_, sizeof(param_));
  return *this;
}





//------------------------------------------------
BufferWriter& BufferWriter::operator<<(const unsigned short param_)
{
  writeData(&param_, sizeof(param_));
  return *this;
}





//------------------------------------------------
BufferWriter& BufferWriter::operator<<(const short param_)
{
  writeData(&param_, sizeof(param_));
  return *this;
}





//------------------------------------------------
BufferWriter& BufferWriter::operator<<(const unsigned int param_)
{
  writeData(&param_, sizeof(param_));
  return *this;
}





//------------------------------------------------
BufferWriter& BufferWriter::operator<<(const int param_)
{
  writeData(&param_, sizeof(param_));
  return *this;
}





//------------------------------------------------
BufferWriter& BufferWriter::operator<<(const unsigned long param_)
{
  writeData(&param_, sizeof(param_));
  return *this;
}





//------------------------------------------------
BufferWriter& BufferWriter::operator<<(const long param_)
{
  writeData(&param_, sizeof(param_));
  return *this;
}





//------------------------------------------------
BufferWriter& BufferWriter::operator<<(const double param_)
{
  writeData(&param_, sizeof(param_));
  return *this;
}





//------------------------------------------------
BufferWriter& BufferWriter::operator<<(const string& str_)
{
  short sz = (short) str_.size();
  writeData(&sz, sizeof(short));
  writeData(str_.c_str(), sz);
  return *this;
}







//------------------------------------------------
BufferWriter& BufferWriter::operator<<(const char* str_)
{
  short sz = (short) std::strlen(str_);
  writeData(&sz, sizeof(short));
  writeData(str_, sz);
  return *this;
}


}
