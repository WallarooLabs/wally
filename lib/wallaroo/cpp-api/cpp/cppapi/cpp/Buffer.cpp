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




//--------------------------------------------------------------------
//
//--------------------------------------------------------------------


//------------------------------------------------
Buffer::Buffer () : _bodySize(0), _body(nullptr), _read(nullptr), _write(nullptr)
{
}






Buffer::Buffer (char* body_, int bodySz_) : _body(body_), _read(body_), _write(nullptr), _bodySize(bodySz_)
{
#ifdef _LITTLE_ENDIAN
  _write = _body + bodySz_;
#else
  _write = _body - bodySz_;
#endif
}




//------------------------------------------------
Buffer::~Buffer ()
{
}





//------------------------------------------------
void Buffer::setBody (const int size_)
{
  if (_body != nullptr)
  {
    delete[] _body;
  }

  if (size_)
  {
    _body = new char[size_ + 1];
    _body[size_] = '\0';
  }
  else
  {
    _body = nullptr;
  }

  _read = _body;
  _write = _body;
  _bodySize = size_;
}





//--------------------------------------------------------------------
//
//--------------------------------------------------------------------
bool Buffer::writeData (const void* data_, const int size_, const bool networkOrder_)
{
  if (((_write - _body) + size_ > _bodySize))
  {
    Logger::getLogger()->error(
        "Buffer overflow while writing data! not continuing execution path. size={}, bodysize:{}",
        ((_write - _body) + size_), _bodySize);
    return false;
  }

  unsigned int count = size_;
  char* place = (char*) data_;

#if defined(_LITTLE_ENDIAN)
#if !defined(NDEBUG)
  Logger::getLogger()->debug("{}:LE:{}, sz:{}", __PRETTY_FUNCTION__, __LINE__, size_);
#endif
  if (networkOrder_)
  {
    place += size_ - 1;
    while (count--)
    {
      *(_write++) = *(place--);
    }
  }
  else
  {
    while (count--)
    {
      *(_write++) = *(place++);
    }
  }
#elif(_BIG_ENDIAN)
#if !defined(NDEBUG)
  Logger::getLogger()->debug("{}:BE:{}, sz:{}",__PRETTY_FUNCTION__, __LINE__ , size_);
#endif
  while (count--)
  *(_write++) = *(place++);
#endif
  return true;
}





//--------------------------------------------------------------------
//
//--------------------------------------------------------------------

bool Buffer::readData (void* data_, const int size_, const bool networkOrder_)
{
  if ((_write - _read < size_))
  {
    Logger::getLogger()->error(
        "Buffer overflow while reading data! not continuing execution path!, body:{}, size:{}",
        (_write - _read), size_);
    return false;
  }

  unsigned int count = size_;
  char* place = (char*) data_;

#if defined(_LITTLE_ENDIAN)
#if !defined(NDEBUG)
  Logger::getLogger()->debug("{}:LE:{}, sz:{}", __PRETTY_FUNCTION__, __LINE__, size_);
#endif
  if (networkOrder_)
  {
    place += size_ - 1;
    while (count--)
    {
      *(place--) = *(_read++);
    }
  }
  else
  {
    while (count--)
    {
      *(place++) = *(_read++);
    }
  }
#elif(_BIG_ENDIAN)
#if !defined(NDEBUG)
  Logger::getLogger()->debug("{}:BE:{}, sz:{}",__PRETTY_FUNCTION__, __LINE__, size_);
#endif
  while (count--)
  *(place++) = *(_read++);
#endif
  return true;
}





//------------------------------------------------
Buffer& Buffer::operator<< (const bool param_)
{
  writeData(&param_, sizeof(param_));
  return *this;
}





//------------------------------------------------
Buffer& Buffer::operator<< (const char param_)
{
  writeData(&param_, sizeof(param_));
  return *this;
}





//------------------------------------------------
Buffer& Buffer::operator<< (const unsigned short param_)
{
  writeData(&param_, sizeof(param_));
  return *this;
}





//------------------------------------------------
Buffer& Buffer::operator<< (const short param_)
{
  writeData(&param_, sizeof(param_));
  return *this;
}





//------------------------------------------------
Buffer& Buffer::operator<< (const unsigned int param_)
{
  writeData(&param_, sizeof(param_));
  return *this;
}





//------------------------------------------------
Buffer& Buffer::operator<< (const int param_)
{
  writeData(&param_, sizeof(param_));
  return *this;
}





//------------------------------------------------
Buffer& Buffer::operator<< (const double param_)
{
  writeData(&param_, sizeof(param_));
  return *this;
}





//------------------------------------------------
Buffer& Buffer::operator<< (const string& str_)
{
  short sz = (short)str_.size();
  writeData(&sz, sizeof(short));
  writeData(str_.c_str(), sz);
  return *this;
}





//------------------------------------------------
Buffer& Buffer::operator>> (bool& param_)
{
  readData(&param_, sizeof(param_));
  return *this;
}





//------------------------------------------------
Buffer& Buffer::operator>> (char& param_)
{
  readData(&param_, sizeof(param_));
  return *this;
}





//------------------------------------------------
Buffer& Buffer::operator>> (unsigned short& param_)
{
  readData(&param_, sizeof(param_));
  return *this;
}





//------------------------------------------------
Buffer& Buffer::operator>> (short& param_)
{
  readData(&param_, sizeof(param_));
  return *this;
}





//------------------------------------------------
Buffer& Buffer::operator>> (unsigned int& param_)
{
  readData(&param_, sizeof(param_));
  return *this;
}





//------------------------------------------------
Buffer& Buffer::operator>> (int& param_)
{
  readData(&param_, sizeof(param_));
  return *this;
}





//------------------------------------------------
Buffer& Buffer::operator>> (double& param_)
{
  readData(&param_, sizeof(param_));
  return *this;
}





//------------------------------------------------
Buffer& Buffer::operator>> (string& param_)
{
  short sz;
  readData(&sz,sizeof(short));

  char* newStrData = new char[sz+1];
  newStrData[sz]='\0';
  readData(newStrData, sz);

  param_.assign(newStrData, sz);
  delete[] newStrData;
  return *this;
}
}


