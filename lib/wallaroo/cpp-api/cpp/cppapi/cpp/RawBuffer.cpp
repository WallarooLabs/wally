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
#include <string>





using std::string;




namespace wallaroo
{


BufferReader::BufferReader () : Buffer()
{
}


//------------------------------------------------
BufferReader::BufferReader (char* str_, int sz_) : Buffer()
{
  _body = str_;
  _bodySize = sz_;


  _read = _body;
  _write = _body + sz_;

}




BufferReader::BufferReader (const BufferReader& rhs_) : Buffer()
{
  Logger::getLogger()->error("RawBuffer (const RawBuffer &cpy_) --> not defined yet");
}





//------------------------------------------------
BufferReader::~BufferReader ()
{
  _body = nullptr;
  _read = nullptr;
  _write = nullptr;
  _bodySize = 0;
}





//------------------------------------------------
BufferReader& BufferReader::operator>> (bool& param_)
{
  readData(&param_, sizeof(param_));
  return *this;
}





//------------------------------------------------
BufferReader& BufferReader::operator>> (char& param_)
{
  readData(&param_, sizeof(param_));
  return *this;
}





//------------------------------------------------
BufferReader& BufferReader::operator>> (unsigned short& param_)
{
  readData(&param_, sizeof(param_));
  return *this;
}





//------------------------------------------------
BufferReader& BufferReader::operator>> (short& param_)
{
  readData(&param_, sizeof(param_));
  return *this;
}





//------------------------------------------------
BufferReader& BufferReader::operator>> (unsigned int& param_)
{
  readData(&param_, sizeof(param_));
  return *this;
}





//------------------------------------------------
BufferReader& BufferReader::operator>> (int& param_)
{
  readData(&param_, sizeof(param_));
  return *this;
}





//------------------------------------------------
BufferReader& BufferReader::operator>> (unsigned long& param_)
{
  readData(&param_, sizeof(param_));
  return *this;
}





//------------------------------------------------
BufferReader& BufferReader::operator>> (long& param_)
{
  readData(&param_, sizeof(param_));
  return *this;
}





//------------------------------------------------
BufferReader& BufferReader::operator>> (double& param_)
{
  readData(&param_, sizeof(param_));
  return *this;
}





//------------------------------------------------
BufferReader& BufferReader::operator>> (string& param_)
{
  short sz;
  readData(&sz, sizeof(short));

  char* newStrData = new char[sz + 1];
  newStrData[sz] = '\0';
  readData(newStrData, sz);

  param_.assign(newStrData, sz);
  delete[] newStrData;
  return *this;
}

}
