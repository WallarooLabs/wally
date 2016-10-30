//
// Created by Kevin A. Goldstein R.  on 9/29/16.
//

#ifndef __CPPAPI_BUFFERS_HPP__
#define __CPPAPI_BUFFERS_HPP__





#include <string>





using std::string;

namespace wallaroo
{





//--------------------------------------------------------------------
//
//--------------------------------------------------------------------
class Buffer
{
protected:
    int _bodySize;
    char* _body;
    char* _read;
    char* _write;

protected:
    bool writeData (const void* data_, const int size_, const bool networkOrder_ = true);
    bool readData (void* data_, const int size_, const bool networkOrder_ = true);
    void setBody (const int size_ = 0);

protected:
    Buffer ();

public:
    virtual ~Buffer () = 0;
};




//--------------------------------------------------------------------
//
//--------------------------------------------------------------------
class BufferWriter : public Buffer
{
private:
    bool _internallyAllocatedBuffer;

public:
    BufferWriter (int sz_);
    BufferWriter (char* buff_, int sz_);
    BufferWriter (const BufferWriter& buff_);
    virtual ~BufferWriter ();

public:
    char* extractPointer ()
    {
      char* holder = _body;
      _body = NULL;
      _read = NULL;
      _write = NULL;
      _bodySize = 0;
      return holder;
    }


public:
    virtual BufferWriter& operator<< (const bool param_);
    virtual BufferWriter& operator<< (const char param_);
    virtual BufferWriter& operator<< (const unsigned short param_);
    virtual BufferWriter& operator<< (const short param_);
    virtual BufferWriter& operator<< (const unsigned int param_);
    virtual BufferWriter& operator<< (const int param_);
    virtual BufferWriter& operator<< (const unsigned long param_);
    virtual BufferWriter& operator<< (const long param_);
    virtual BufferWriter& operator<< (const double param_);
    virtual BufferWriter& operator<< (const string& str_);
};





//--------------------------------------------------------------------
//
//--------------------------------------------------------------------
class BufferReader : public Buffer
{
public:
    BufferReader();
    BufferReader (char* str_, int sz_);
    BufferReader (const BufferReader& rhs_);
    virtual ~BufferReader ();

public:
    virtual BufferReader& operator>> (bool& param_);
    virtual BufferReader& operator>> (char& param_);
    virtual BufferReader& operator>> (unsigned short& param_);
    virtual BufferReader& operator>> (short& param_);
    virtual BufferReader& operator>> (unsigned int& param_);
    virtual BufferReader& operator>> (int& param_);
    virtual BufferReader& operator>> (unsigned long& param_);
    virtual BufferReader& operator>> (long& param_);
    virtual BufferReader& operator>> (double& param_);
    virtual BufferReader& operator>> (string& param_);
};
}


#endif //__CPPAPI_BUFFERS_HPP__
